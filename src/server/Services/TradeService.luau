--[[
    TradeService.luau
    Handles peer-to-peer pet trading.
    Two-phase confirmation: both accept, then both confirm.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local TradeConfig = require(Shared:WaitForChild("Configs"):WaitForChild("TradeConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService
local PetService

local TradeService = {}

-- Active trades: [tradeId] = { player1, player2, offer1 = {petUUIDs}, offer2 = {petUUIDs}, gems1, gems2, accepted1, accepted2, confirmed1, confirmed2 }
local activeTrades = {}
local playerTrades = {} -- [Player] = tradeId
local tradeCooldowns = {} -- [Player] = tick()
local tradeCounter = 0

local function generateTradeId()
    tradeCounter = tradeCounter + 1
    return "trade_" .. tradeCounter
end

local function cancelTrade(tradeId, reason)
    local trade = activeTrades[tradeId]
    if not trade then return end

    if trade.player1 and trade.player1.Parent then
        Network.FireClient("TradeCancelled", trade.player1, reason or "Trade cancelled")
        playerTrades[trade.player1] = nil
    end
    if trade.player2 and trade.player2.Parent then
        Network.FireClient("TradeCancelled", trade.player2, reason or "Trade cancelled")
        playerTrades[trade.player2] = nil
    end

    activeTrades[tradeId] = nil
end

local function getOtherPlayer(trade, player)
    if trade.player1 == player then return trade.player2 end
    return trade.player1
end

local function getPlayerSide(trade, player)
    if trade.player1 == player then return 1 end
    return 2
end

-- Update PetIndex for recipient when a pet arrives via trade
local function updatePetIndex(data, pet)
    local indexKey = pet.PetId
    if pet.Golden then indexKey = pet.PetId .. "_golden" end
    if pet.Rainbow then indexKey = pet.PetId .. "_rainbow" end
    for _, entry in ipairs(data.PetIndex or {}) do
        if entry == indexKey then return end
    end
    table.insert(data.PetIndex, indexKey)
end

-- Validate all pets in an offer belong to the player, are not equipped, and are not locked
local function validateOffer(player, petUUIDs)
    local data = DataService.GetData(player)
    if not data then return false end

    for _, uuid in ipairs(petUUIDs) do
        local found = false
        for _, pet in ipairs(data.Pets or {}) do
            if pet.UUID == uuid then
                if pet.Equipped then return false end
                if pet.Locked  then return false end
                found = true
                break
            end
        end
        if not found then return false end
    end
    return true
end

-- Resolve UUIDs to pet info for display on the other player's client
local function resolveOfferPets(player, petUUIDs)
    local data = DataService.GetData(player)
    if not data then return {} end
    local resolved = {}
    for _, uuid in ipairs(petUUIDs) do
        for _, pet in ipairs(data.Pets or {}) do
            if pet.UUID == uuid then
                local petInfo = PetConfig.GetPet(pet.PetId)
                table.insert(resolved, {
                    UUID = uuid,
                    PetId = pet.PetId,
                    Name = petInfo and petInfo.Name or pet.PetId,
                    Rarity = petInfo and petInfo.Rarity or "Common",
                    Power = petInfo and petInfo.Power or 1,
                    Golden = pet.Golden,
                    Rainbow = pet.Rainbow,
                })
                break
            end
        end
    end
    return resolved
end

-- Send trade state to both players with per-player perspective
local function broadcastTradeState(trade)
    -- Player1 gets: myOffer = offer1 UUIDs, theirOffer = resolved offer2 pets
    local offer2Resolved = resolveOfferPets(trade.player2, trade.offer2)
    local offer1Resolved = resolveOfferPets(trade.player1, trade.offer1)

    Network.FireClient("TradeUpdated", trade.player1, {
        MyOffer = trade.offer1,       -- UUIDs (client has own pet data)
        TheirOffer = offer2Resolved,  -- Full pet info from other player
        MyGems = trade.gems1,
        TheirGems = trade.gems2,
        MyAccepted = trade.accepted1,
        TheirAccepted = trade.accepted2,
    })
    Network.FireClient("TradeUpdated", trade.player2, {
        MyOffer = trade.offer2,       -- UUIDs
        TheirOffer = offer1Resolved,  -- Full pet info from other player
        MyGems = trade.gems2,
        TheirGems = trade.gems1,
        MyAccepted = trade.accepted2,
        TheirAccepted = trade.accepted1,
    })
end

function TradeService.Init(dataService, petService)
    DataService = dataService
    PetService = petService

    if not LaunchConfig.IsFeatureEnabled("Trading") then
        print("[LaunchConfig] TradeService disabled — skipping handler registration")
        return
    end

    -- Request to trade with another player
    Network.OnServerEvent("TradeRequest", function(player: Player, targetPlayer: Player)
        if not targetPlayer or not targetPlayer.Parent then
            Network.FireClient("ShowNotification", player, "Player not found!", "Warning")
            return
        end
        if targetPlayer == player then return end

        -- Check cooldown
        if tradeCooldowns[player] and (tick() - tradeCooldowns[player]) < TradeConfig.TradeCooldown then
            Network.FireClient("ShowNotification", player, "Please wait before trading again!", "Warning")
            return
        end

        -- Check not already in a trade
        if playerTrades[player] then
            Network.FireClient("ShowNotification", player, "You're already in a trade!", "Warning")
            return
        end
        if playerTrades[targetPlayer] then
            Network.FireClient("ShowNotification", player, "That player is already trading!", "Warning")
            return
        end

        -- Roblox compliance: check IsPaidItemTradingAllowed for both parties.
        -- Players in restricted regions must not participate in paid item trading.
        -- Wrap each call in pcall per Roblox API documentation.
        local PolicyService = game:GetService("PolicyService")
        local ok1, pol1 = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(player) end)
        local ok2, pol2 = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(targetPlayer) end)
        if (ok1 and not pol1.IsPaidItemTradingAllowed) or (ok2 and not pol2.IsPaidItemTradingAllowed) then
            Network.FireClient("ShowNotification", player,
                "Paid item trading is not available in your region or your target's region.", "Warning")
            return
        end

        local tradeId = generateTradeId()
        activeTrades[tradeId] = {
            player1 = player,
            player2 = targetPlayer,
            offer1 = {},
            offer2 = {},
            gems1 = 0,
            gems2 = 0,
            accepted1 = false,
            accepted2 = false,
            confirmed1 = false,
            confirmed2 = false,
            startTime = tick(),
        }
        playerTrades[player] = tradeId
        playerTrades[targetPlayer] = tradeId

        Network.FireClient("TradeRequest", targetPlayer, player.Name, player.UserId)
        Network.FireClient("ShowNotification", player, "Trade request sent to " .. targetPlayer.Name, "Info")

        -- Auto-cancel after timeout
        task.delay(TradeConfig.TradeTimeout, function()
            if activeTrades[tradeId] then
                cancelTrade(tradeId, "Trade timed out")
            end
        end)
    end)

    -- Accept trade request
    Network.OnServerEvent("TradeAccepted", function(player: Player)
        local tradeId = playerTrades[player]
        if not tradeId then return end
        local trade = activeTrades[tradeId]
        if not trade then return end

        Network.FireClient("TradeAccepted", trade.player1)
        Network.FireClient("TradeAccepted", trade.player2)
    end)

    -- Decline trade request
    Network.OnServerEvent("TradeDeclined", function(player: Player)
        local tradeId = playerTrades[player]
        if not tradeId then return end
        cancelTrade(tradeId, "Trade declined")
    end)

    -- Update trade offer (add/remove pets)
    Network.OnServerEvent("TradeUpdated", function(player: Player, petUUIDs, gems)
        local tradeId = playerTrades[player]
        if not tradeId then return end
        local trade = activeTrades[tradeId]
        if not trade then return end

        if type(petUUIDs) ~= "table" then return end
        if #petUUIDs > TradeConfig.MaxPetsPerSide then return end

        local gemsAmount = type(gems) == "number" and math.clamp(math.floor(gems), 0, TradeConfig.MaxGemsPerTrade) or 0

        local side = getPlayerSide(trade, player)
        if side == 1 then
            trade.offer1 = petUUIDs
            trade.gems1 = gemsAmount
        else
            trade.offer2 = petUUIDs
            trade.gems2 = gemsAmount
        end

        -- Reset acceptances when offer changes
        trade.accepted1 = false
        trade.accepted2 = false
        trade.confirmed1 = false
        trade.confirmed2 = false

        -- Notify both players
        local other = getOtherPlayer(trade, player)
        broadcastTradeState(trade)
    end)

    -- Accept (phase 1)
    Network.OnServerEvent("TradeConfirmed", function(player: Player)
        local tradeId = playerTrades[player]
        if not tradeId then return end
        local trade = activeTrades[tradeId]
        if not trade then return end

        local side = getPlayerSide(trade, player)

        -- Phase 1: Accept
        if not (side == 1 and trade.accepted1 or side == 2 and trade.accepted2) then
            if side == 1 then trade.accepted1 = true else trade.accepted2 = true end

            broadcastTradeState(trade)

            -- If both accepted, move to confirm phase
            if trade.accepted1 and trade.accepted2 then
                Network.FireClient("ShowNotification", trade.player1, "Both accepted! Confirm to complete trade.", "Info")
                Network.FireClient("ShowNotification", trade.player2, "Both accepted! Confirm to complete trade.", "Info")
            end
            return
        end

        -- Phase 2: Confirm (only if both accepted)
        if not (trade.accepted1 and trade.accepted2) then return end

        if side == 1 then trade.confirmed1 = true else trade.confirmed2 = true end

        if trade.confirmed1 and trade.confirmed2 then
            -- Execute trade!
            -- Guard: both players must still be in-game
            if not trade.player1.Parent or not trade.player2.Parent then
                cancelTrade(tradeId, "Trade failed: a player disconnected")
                return
            end
            -- Final validation
            if not validateOffer(trade.player1, trade.offer1) or not validateOffer(trade.player2, trade.offer2) then
                cancelTrade(tradeId, "Trade failed: invalid items")
                return
            end

            -- Check gems
            local data1 = DataService.GetData(trade.player1)
            local data2 = DataService.GetData(trade.player2)
            if not data1 or not data2 then
                cancelTrade(tradeId, "Trade failed: player data error")
                return
            end

            if (data1.Gems or 0) < trade.gems1 or (data2.Gems or 0) < trade.gems2 then
                cancelTrade(tradeId, "Trade failed: insufficient gems")
                return
            end

            -- Transfer pets player1 -> player2
            for _, uuid in ipairs(trade.offer1) do
                for i, pet in ipairs(data1.Pets) do
                    if pet.UUID == uuid then
                        table.remove(data1.Pets, i)
                        table.insert(data2.Pets, pet)
                        updatePetIndex(data2, pet)
                        break
                    end
                end
            end

            -- Transfer pets player2 -> player1
            for _, uuid in ipairs(trade.offer2) do
                for i, pet in ipairs(data2.Pets) do
                    if pet.UUID == uuid then
                        table.remove(data2.Pets, i)
                        table.insert(data1.Pets, pet)
                        updatePetIndex(data1, pet)
                        break
                    end
                end
            end

            -- Transfer gems
            if trade.gems1 > 0 then
                data1.Gems = (data1.Gems or 0) - trade.gems1
                data2.Gems = (data2.Gems or 0) + trade.gems1
            end
            if trade.gems2 > 0 then
                data2.Gems = (data2.Gems or 0) - trade.gems2
                data1.Gems = (data1.Gems or 0) + trade.gems2
            end

            -- Update clients
            Network.FireClient("PetsUpdated", trade.player1, data1.Pets)
            Network.FireClient("PetsUpdated", trade.player2, data2.Pets)
            Network.FireClient("CurrencyUpdated", trade.player1, "Gems", data1.Gems)
            Network.FireClient("CurrencyUpdated", trade.player2, "Gems", data2.Gems)

            Network.FireClient("TradeCompleted", trade.player1)
            Network.FireClient("TradeCompleted", trade.player2)
            Network.FireClient("ShowNotification", trade.player1, "Trade completed!", "Success")
            Network.FireClient("ShowNotification", trade.player2, "Trade completed!", "Success")

            -- Track trade stats
            data1.TradesCompleted = (data1.TradesCompleted or 0) + 1
            data2.TradesCompleted = (data2.TradesCompleted or 0) + 1

            tradeCooldowns[trade.player1] = tick()
            tradeCooldowns[trade.player2] = tick()

            playerTrades[trade.player1] = nil
            playerTrades[trade.player2] = nil
            activeTrades[tradeId] = nil
        else
            broadcastTradeState(trade)
        end
    end)

    -- Cancel
    Network.OnServerEvent("TradeCancelled", function(player: Player)
        local tradeId = playerTrades[player]
        if tradeId then
            cancelTrade(tradeId, player.Name .. " cancelled the trade")
        end
    end)

    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        local tradeId = playerTrades[player]
        if tradeId then
            cancelTrade(tradeId, player.Name .. " left the game")
        end
        tradeCooldowns[player] = nil
    end)
end

return TradeService
