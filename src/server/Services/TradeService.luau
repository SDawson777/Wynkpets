-- TradeService.luau
-- Peer-to-peer pet trading between players.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local PetConfig   = require(ReplicatedStorage.Shared.Config.PetConfig)

local Events = ReplicatedStorage.Shared.Remotes.Events

local TradeService = {}

-- Active trades: key = sorted "userId1_userId2"
local activeTrades = {}

local function tradeKey(a: number, b: number): string
    if a < b then return a .. "_" .. b end
    return b .. "_" .. a
end

local function newTrade(p1: Player, p2: Player)
    return {
        players   = { p1, p2 },
        offers    = { [p1.UserId] = {}, [p2.UserId] = {} },
        coins     = { [p1.UserId] = 0,  [p2.UserId] = 0  },
        confirmed = { [p1.UserId] = false, [p2.UserId] = false },
    }
end

-- ─── Send trade request ───────────────────────────────────────────────────────

local pendingRequests = {}  -- [targetUserId] = requesterPlayer

local function sendTradeRequest(from: Player, toName: string)
    local target: Player? = Players:FindFirstChild(toName)
    if not target or target == from then
        Events.PurchaseResult:FireClient(from, false, "Player not found.")
        return
    end

    pendingRequests[target.UserId] = from
    Events.TradeRequestReceived:FireClient(target, from.Name)
end

-- ─── Accept trade ─────────────────────────────────────────────────────────────

local function acceptTrade(player: Player)
    local requester = pendingRequests[player.UserId]
    if not requester or not requester.Parent then
        Events.PurchaseResult:FireClient(player, false, "Trade request expired.")
        return
    end
    pendingRequests[player.UserId] = nil

    local key   = tradeKey(requester.UserId, player.UserId)
    local trade = newTrade(requester, player)
    activeTrades[key] = trade

    Events.TradeUpdate:FireClient(requester, "started", trade.offers, trade.coins)
    Events.TradeUpdate:FireClient(player,    "started", trade.offers, trade.coins)
end

-- ─── Add/remove item from trade offer ────────────────────────────────────────

local function updateOffer(player: Player, petUid: string?, coinAmount: number?)
    -- Find an active trade involving this player
    local myTrade, key
    for k, t in pairs(activeTrades) do
        if t.players[1] == player or t.players[2] == player then
            myTrade = t; key = k; break
        end
    end
    if not myTrade then return end
    if myTrade.confirmed[player.UserId] then return end  -- locked in

    local data = DataService.get(player)
    if not data then return end

    if petUid ~= nil then
        -- Toggle pet in offer
        local offer = myTrade.offers[player.UserId]
        local idx   = table.find(offer, petUid)
        if idx then
            table.remove(offer, idx)
        else
            -- Validate ownership
            local owned = false
            for _, inst in ipairs(data.Pets) do
                if inst.uid == petUid then owned = true; break end
            end
            if not owned then return end
            if #offer >= 4 then return end  -- max 4 pets per offer
            table.insert(offer, petUid)
        end
    end

    if coinAmount ~= nil then
        local coins = math.max(0, math.floor(coinAmount))
        if coins > data.Coins then coins = data.Coins end
        myTrade.coins[player.UserId] = coins
    end

    -- Reset confirmations on any change
    for uid in pairs(myTrade.confirmed) do
        myTrade.confirmed[uid] = false
    end

    for _, p in ipairs(myTrade.players) do
        Events.TradeUpdate:FireClient(p, "updated", myTrade.offers, myTrade.coins)
    end
end

-- ─── Confirm trade ────────────────────────────────────────────────────────────

local function confirmTrade(player: Player)
    local myTrade, key
    for k, t in pairs(activeTrades) do
        if t.players[1] == player or t.players[2] == player then
            myTrade = t; key = k; break
        end
    end
    if not myTrade then return end

    myTrade.confirmed[player.UserId] = true

    -- Check if both confirmed
    local allConfirmed = true
    for _, confirmed in pairs(myTrade.confirmed) do
        if not confirmed then allConfirmed = false; break end
    end

    if not allConfirmed then
        for _, p in ipairs(myTrade.players) do
            Events.TradeUpdate:FireClient(p, "confirm_pending", myTrade.offers, myTrade.coins)
        end
        return
    end

    -- Execute trade
    local p1, p2   = myTrade.players[1], myTrade.players[2]
    local d1, d2   = DataService.get(p1), DataService.get(p2)
    if not d1 or not d2 then
        activeTrades[key] = nil
        return
    end

    -- Transfer coins
    local coins1 = myTrade.coins[p1.UserId]
    local coins2 = myTrade.coins[p2.UserId]
    d1.Coins = d1.Coins - coins1 + coins2
    d2.Coins = d2.Coins - coins2 + coins1

    -- Transfer pets
    local function transferPets(fromData, toData, petUids)
        for _, uid in ipairs(petUids) do
            for i, inst in ipairs(fromData.Pets) do
                if inst.uid == uid then
                    table.remove(fromData.Pets, i)
                    -- Remove from equipped if needed
                    local eq = table.find(fromData.EquippedPets, uid)
                    if eq then table.remove(fromData.EquippedPets, eq) end
                    table.insert(toData.Pets, inst)
                    break
                end
            end
        end
    end

    transferPets(d1, d2, myTrade.offers[p1.UserId])
    transferPets(d2, d1, myTrade.offers[p2.UserId])

    -- Notify both players
    Events.CoinsUpdated:FireClient(p1, d1.Coins)
    Events.CoinsUpdated:FireClient(p2, d2.Coins)
    Events.TradeCompleted:FireClient(p1, myTrade.offers, myTrade.coins)
    Events.TradeCompleted:FireClient(p2, myTrade.offers, myTrade.coins)
    Events.PetsUpdated:FireClient(p1, d1.Pets, d1.EquippedPets)
    Events.PetsUpdated:FireClient(p2, d2.Pets, d2.EquippedPets)

    activeTrades[key] = nil
end

-- ─── Cancel trade ─────────────────────────────────────────────────────────────

local function cancelTrade(player: Player)
    for key, t in pairs(activeTrades) do
        if t.players[1] == player or t.players[2] == player then
            for _, p in ipairs(t.players) do
                Events.TradeCancelled:FireClient(p)
            end
            activeTrades[key] = nil
            return
        end
    end
end

-- ─── Clean up on leave ────────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player: Player)
    pendingRequests[player.UserId] = nil
    cancelTrade(player)
end)

-- ─── RemoteEvent handlers ─────────────────────────────────────────────────────

Events.SendTradeRequest.OnServerEvent:Connect(function(player: Player, targetName: string)
    if type(targetName) ~= "string" then return end
    sendTradeRequest(player, targetName)
end)

Events.TradeUpdate.OnServerEvent:Connect(function(player: Player, action: string, petUid, coinAmount)
    if action == "accept" then
        acceptTrade(player)
    elseif action == "offer" then
        updateOffer(player, typeof(petUid) == "string" and petUid or nil, typeof(coinAmount) == "number" and coinAmount or nil)
    elseif action == "confirm" then
        confirmTrade(player)
    elseif action == "cancel" then
        cancelTrade(player)
    end
end)

return TradeService
