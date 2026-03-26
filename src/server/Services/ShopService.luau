-- ShopService.luau
-- Handles in-game shop purchases (coins/gems for consumables),
-- gamepass effects, world unlocks, and tool purchases.

local Players           = game:GetService("Players")
local MarketplaceService= game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService    = require(script.Parent.DataService)
local ShopConfig     = require(ReplicatedStorage.Shared.Config.ShopConfig)
local GamepassConfig = require(ReplicatedStorage.Shared.Config.GamepassConfig)
local WorldConfig    = require(ReplicatedStorage.Shared.Config.WorldConfig)
local MiningConfig   = require(ReplicatedStorage.Shared.Config.MiningConfig)

local Events = ReplicatedStorage.Shared.Remotes.Events

-- Build world and tool lookups
local worldById = {}
for _, w in ipairs(WorldConfig.Worlds) do
    worldById[w.id] = w
end
local toolById = {}
for _, t in ipairs(MiningConfig.Tools) do
    toolById[t.id] = t
end

-- Build coin/gem shop lookups
local coinItemById = {}
for _, item in ipairs(ShopConfig.CoinItems) do
    coinItemById[item.id] = item
end
local gemItemById = {}
for _, item in ipairs(ShopConfig.GemItems) do
    gemItemById[item.id] = item
end

local ShopService = {}

-- ─── Apply timed boost to player data ────────────────────────────────────────

local function applyTimedBoost(data: {}, effect: {}, duration: number)
    if duration <= 0 then return end  -- permanent handled elsewhere
    local boost = {
        coinMult       = effect.coinMult       or 0,
        mineMult       = effect.mineMult       or 0,
        luckMult       = effect.luckMult       or 0,
        mineSpeedBoost = effect.mineSpeedBoost or 0,
        expiresAt      = os.time() + duration,
    }
    table.insert(data.ActiveBoosts, boost)
end

-- ─── Purchase shop item ──────────────────────────────────────────────────────

local function purchaseShopItem(player: Player, itemId: string)
    local data = DataService.get(player)
    if not data then return end

    -- Coin item?
    local coinItem = coinItemById[itemId]
    if coinItem then
        if data.Coins < coinItem.coinCost then
            Events.PurchaseResult:FireClient(player, false, "Not enough coins.")
            return
        end
        data.Coins = data.Coins - coinItem.coinCost
        applyTimedBoost(data, coinItem.effect, coinItem.duration)
        Events.CoinsUpdated:FireClient(player, data.Coins)
        Events.ActiveBoostsUpdated:FireClient(player, data.ActiveBoosts)
        Events.PurchaseResult:FireClient(player, true, "Boost activated!")
        return
    end

    -- Gem item?
    local gemItem = gemItemById[itemId]
    if gemItem then
        if data.Gems < gemItem.gemCost then
            Events.PurchaseResult:FireClient(player, false, "Not enough gems.")
            return
        end
        data.Gems = data.Gems - gemItem.gemCost
        if gemItem.duration == -1 then
            -- Permanent effect (e.g., inventory expansion)
            if gemItem.effect.inventoryExpansion then
                -- Handled client-side display; server just tracks via MaxInventorySize extension
                data._inventoryExpansions = (data._inventoryExpansions or 0) + gemItem.effect.inventoryExpansion
            end
        else
            applyTimedBoost(data, gemItem.effect, gemItem.duration)
        end
        Events.GemsUpdated:FireClient(player, data.Gems)
        Events.ActiveBoostsUpdated:FireClient(player, data.ActiveBoosts)
        Events.PurchaseResult:FireClient(player, true, "Boost activated!")
        return
    end

    -- Tool purchase?
    local toolDef = toolById[itemId]
    if toolDef then
        if table.find(data.OwnedTools, itemId) then
            Events.PurchaseResult:FireClient(player, false, "Already owned.")
            return
        end
        if toolDef.currency == "Coins" then
            if data.Coins < toolDef.price then
                Events.PurchaseResult:FireClient(player, false, "Not enough coins.")
                return
            end
            data.Coins = data.Coins - toolDef.price
            Events.CoinsUpdated:FireClient(player, data.Coins)
        elseif toolDef.currency == "Gems" then
            if data.Gems < toolDef.price then
                Events.PurchaseResult:FireClient(player, false, "Not enough gems.")
                return
            end
            data.Gems = data.Gems - toolDef.price
            Events.GemsUpdated:FireClient(player, data.Gems)
        end
        table.insert(data.OwnedTools, itemId)
        data.CurrentTool = itemId
        Events.PurchaseResult:FireClient(player, true, "Tool purchased and equipped!")
        return
    end

    Events.PurchaseResult:FireClient(player, false, "Unknown item.")
end

-- ─── Unlock world ─────────────────────────────────────────────────────────────

local function unlockWorld(player: Player, worldId: number)
    local data = DataService.get(player)
    if not data then return end

    local worldDef = worldById[worldId]
    if not worldDef then
        Events.PurchaseResult:FireClient(player, false, "Unknown world.")
        return
    end
    if table.find(data.UnlockedWorlds, worldId) then
        Events.PurchaseResult:FireClient(player, false, "World already unlocked.")
        return
    end
    if worldDef.rebirthRequired > data.Rebirths then
        Events.PurchaseResult:FireClient(player, false, "More rebirths required.")
        return
    end

    if worldDef.currency == "Coins" then
        if data.Coins < worldDef.unlockCost then
            Events.PurchaseResult:FireClient(player, false, "Not enough coins.")
            return
        end
        data.Coins = data.Coins - worldDef.unlockCost
        Events.CoinsUpdated:FireClient(player, data.Coins)
    elseif worldDef.currency == "Gems" then
        if data.Gems < worldDef.unlockCost then
            Events.PurchaseResult:FireClient(player, false, "Not enough gems.")
            return
        end
        data.Gems = data.Gems - worldDef.unlockCost
        Events.GemsUpdated:FireClient(player, data.Gems)
    end

    table.insert(data.UnlockedWorlds, worldId)
    data.CurrentWorld = worldId
    Events.WorldUnlocked:FireClient(player, worldId)
    Events.PurchaseResult:FireClient(player, true, "World unlocked!")
end

-- ─── MarketplaceService: gamepass grant ──────────────────────────────────────

local function grantGamepass(player: Player, assetId: number)
    local data = DataService.get(player)
    if not data then return end

    -- Find gamepass by assetId
    for _, gp in ipairs(GamepassConfig.Gamepasses) do
        if gp.assetId == assetId then
            if not table.find(data.OwnedGamepasses, gp.id) then
                table.insert(data.OwnedGamepasses, gp.id)
            end
            Events.PurchaseResult:FireClient(player, true, gp.name .. " activated!")
            return
        end
    end
end

-- ─── Developer Product: consumable grants ─────────────────────────────────────

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    local data = DataService.get(player)
    if not data then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    for _, dp in ipairs(GamepassConfig.DevProducts) do
        if dp.assetId == receiptInfo.ProductId then
            -- Starter pack (one-time)
            if dp.oneTimeOnly and data.StarterPackClaimed then
                return Enum.ProductPurchaseDecision.PurchaseGranted  -- refund silently
            end
            if dp.grant then
                local g = dp.grant
                data.Gems = data.Gems + (g.gems or 0)
                Events.GemsUpdated:FireClient(player, data.Gems)
                for _, gpId in ipairs(g.gamepasses or {}) do
                    if not table.find(data.OwnedGamepasses, gpId) then
                        table.insert(data.OwnedGamepasses, gpId)
                    end
                end
                -- Grant pets
                for _, petId in ipairs(g.pets or {}) do
                    local HttpService = game:GetService("HttpService")
                    table.insert(data.Pets, { uid = HttpService:GenerateGUID(false), petId = petId, rarity = "Rare" })
                end
            end
            if dp.oneTimeOnly then
                data.StarterPackClaimed = true
            end
            if dp.duration then
                applyTimedBoost(data, dp.effect, dp.duration)
                Events.ActiveBoostsUpdated:FireClient(player, data.ActiveBoosts)
            end
            Events.PurchaseResult:FireClient(player, true, dp.name .. " granted!")
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end

    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Grant gamepasses on join (for players who already own them)
local function checkGamepassesOnJoin(player: Player)
    task.defer(function()
        local data = DataService.get(player)
        if not data then return end
        for _, gp in ipairs(GamepassConfig.Gamepasses) do
            if gp.assetId ~= 0 then
                local success, owns = pcall(function()
                    return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.assetId)
                end)
                if success and owns then
                    if not table.find(data.OwnedGamepasses, gp.id) then
                        table.insert(data.OwnedGamepasses, gp.id)
                    end
                end
            end
        end
    end)
end

Players.PlayerAdded:Connect(checkGamepassesOnJoin)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(checkGamepassesOnJoin, p)
end

-- ─── RemoteEvent handlers ─────────────────────────────────────────────────────

Events.PurchaseShopItem.OnServerEvent:Connect(function(player: Player, itemId: string)
    if type(itemId) ~= "string" then return end
    purchaseShopItem(player, itemId)
end)

Events.UnlockWorld.OnServerEvent:Connect(function(player: Player, worldId)
    if type(worldId) ~= "number" then return end
    unlockWorld(player, worldId)
end)

return ShopService
