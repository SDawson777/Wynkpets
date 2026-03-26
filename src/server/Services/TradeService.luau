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

-- Validate all pets in an offer belong to the player and are not equipped
local function validateOffer(player, petUUIDs)
    local data = DataService.GetData(player)
    if not data then return false end

    for _, uuid in ipairs(petUUIDs) do
        local found = false
        for _, pet in ipairs(data.Pets or {}) do
            if pet.UUID == uuid then
                if pet.Equipped then return false end
                found = true
                break
            end
        end
        if not found then return false end
    end
    return true
end

function TradeService.Init(dataService, petService)
    DataService = dataService
    PetService = petService

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
        Network.FireClient("TradeUpdated", trade.player1, trade.offer1, trade.offer2, trade.gems1, trade.gems2, trade.accepted1, trade.accepted2)
        Network.FireClient("TradeUpdated", trade.player2, trade.offer1, trade.offer2, trade.gems1, trade.gems2, trade.accepted1, trade.accepted2)
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

            Network.FireClient("TradeUpdated", trade.player1, trade.offer1, trade.offer2, trade.gems1, trade.gems2, trade.accepted1, trade.accepted2)
            Network.FireClient("TradeUpdated", trade.player2, trade.offer1, trade.offer2, trade.gems1, trade.gems2, trade.accepted1, trade.accepted2)

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

            tradeCooldowns[trade.player1] = tick()
            tradeCooldowns[trade.player2] = tick()

            playerTrades[trade.player1] = nil
            playerTrades[trade.player2] = nil
            activeTrades[tradeId] = nil
        else
            Network.FireClient("TradeUpdated", trade.player1, trade.offer1, trade.offer2, trade.gems1, trade.gems2, trade.accepted1, trade.accepted2)
            Network.FireClient("TradeUpdated", trade.player2, trade.offer1, trade.offer2, trade.gems1, trade.gems2, trade.accepted1, trade.accepted2)
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
