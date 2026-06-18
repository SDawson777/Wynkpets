--[[
    LimitedShopService.luau
    Daily rotating limited-stock shop.
    3 items per day (4 on weekends), per-player stock tracking.
    Server-authoritative: stock validated on server, no client trust.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local MonetizationConfig = require(Shared:WaitForChild("Configs"):WaitForChild("MonetizationConfig"))

local DataService
local CurrencyService
local AnalyticsService

local LimitedShopService = {}

-- Get today's day seed for deterministic rotation
local function getDaySeed(): number
    return math.floor(os.time() / 86400)
end

-- ── Global stock & velocity tracking ─────────────────────────────────────────
-- globalStockToday[itemId] = total purchases by ALL players today
-- Resets when daySeed changes (new calendar day).
local globalStockToday   = {}  -- [itemId] = count
local globalStockDaySeed = -1  -- track which day globalStockToday belongs to

-- purchaseVelocity[itemId] = purchases in the last velocity window
local purchaseVelocity    = {}  -- [itemId] = count
local velocityWindowStart = os.time()
local VELOCITY_WINDOW     = 3600  -- 1 hour window
local SELLING_FAST_THRESHOLD = 3  -- purchases/hour to show "Selling fast" tag
local GLOBAL_STOCK_CAP    = 100   -- max global purchases per item per day

local function resetGlobalStockIfNewDay()
    local seed = getDaySeed()
    if seed ~= globalStockDaySeed then
        globalStockToday   = {}
        globalStockDaySeed = seed
    end
end

local function resetVelocityIfExpired()
    if os.time() - velocityWindowStart >= VELOCITY_WINDOW then
        purchaseVelocity  = {}
        velocityWindowStart = os.time()
    end
end

local function incrementGlobalStock(itemId: string)
    resetGlobalStockIfNewDay()
    globalStockToday[itemId]  = (globalStockToday[itemId] or 0) + 1
    resetVelocityIfExpired()
    purchaseVelocity[itemId]  = (purchaseVelocity[itemId] or 0) + 1
end

local function getGlobalRemaining(itemId: string): number
    resetGlobalStockIfNewDay()
    local bought = globalStockToday[itemId] or 0
    return math.max(0, GLOBAL_STOCK_CAP - bought)
end

local function isSellingFast(itemId: string): boolean
    resetVelocityIfExpired()
    return (purchaseVelocity[itemId] or 0) >= SELLING_FAST_THRESHOLD
end

-- Check if today is a weekend (Sat=7, Sun=1)
local function isWeekend(): boolean
    local dayOfWeek = tonumber(os.date("!%w"))
    return dayOfWeek == 0 or dayOfWeek == 6
end

-- Get today's limited shop items (deterministic selection)
function LimitedShopService.GetDailyItems(): { any }
    local seed = getDaySeed()
    local rng = Random.new(seed)
    local pool = MonetizationConfig.LimitedShop.Items
    local slotCount = isWeekend()
        and MonetizationConfig.LimitedShop.WeekendSlotCount
        or MonetizationConfig.LimitedShop.DailySlotCount

    -- Shuffle indices deterministically
    local indices = {}
    for i = 1, #pool do
        table.insert(indices, i)
    end
    for i = #indices, 2, -1 do
        local j = rng:NextInteger(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    local items = {}
    for i = 1, math.min(slotCount, #indices) do
        table.insert(items, pool[indices[i]])
    end
    return items
end

-- Get a player's remaining stock for a limited item today
local function getPlayerStock(player: Player, itemId: string): number
    local data = DataService.GetData(player)
    if not data then return 0 end

    if not data.LimitedPurchases then
        data.LimitedPurchases = {}
    end

    local daySeed = getDaySeed()
    -- Reset if day changed
    if data.LimitedPurchases._daySeed ~= daySeed then
        data.LimitedPurchases = { _daySeed = daySeed }
    end

    local item = MonetizationConfig.LimitedItemById[itemId]
    if not item then return 0 end

    local bought = data.LimitedPurchases[itemId] or 0
    return math.max(0, item.Stock - bought)
end

-- Purchase a limited item
function LimitedShopService.PurchaseItem(player: Player, itemId: string): boolean
    if type(itemId) ~= "string" then return false end

    local item = MonetizationConfig.LimitedItemById[itemId]
    if not item then return false end

    -- Verify it's in today's rotation
    local todayItems = LimitedShopService.GetDailyItems()
    local inRotation = false
    for _, todayItem in ipairs(todayItems) do
        if todayItem.Id == itemId then
            inRotation = true
            break
        end
    end
    if not inRotation then
        Network.FireClient("ShowNotification", player, "This item is not available today!", "Warning")
        return false
    end

    -- Check global stock cap
    resetGlobalStockIfNewDay()
    if (globalStockToday[item.Id] or 0) >= GLOBAL_STOCK_CAP then
        Network.FireClient("ShowNotification", player, "Global stock depleted for today!", "Warning")
        return false
    end

    -- Check stock
    local remaining = getPlayerStock(player, itemId)
    if remaining <= 0 then
        Network.FireClient("ShowNotification", player, "Sold out for today!", "Warning")
        return false
    end

    -- Check currency
    local data = DataService.GetData(player)
    if not data then return false end

    if not CurrencyService.CanAfford(player, item.Currency, item.Price) then
        Network.FireClient("ShowNotification", player, "Not enough " .. item.Currency .. "!", "Warning")
        return false
    end

    -- Deduct currency
    CurrencyService.Remove(player, item.Currency, item.Price)

    -- Record purchase
    if not data.LimitedPurchases then data.LimitedPurchases = {} end
    data.LimitedPurchases[itemId] = (data.LimitedPurchases[itemId] or 0) + 1

    -- Update global stock and velocity counters
    incrementGlobalStock(itemId)

    -- Grant item reward
    LimitedShopService.GrantLimitedItem(player, item)

    -- Track
    if AnalyticsService then
        AnalyticsService.TrackLimitedPurchase(player, itemId, item.Price)
        AnalyticsService.TrackCurrencySpent(player, item.Currency, item.Price, "LimitedShop")
    end

    -- Notify
    Network.FireClient("ShowNotification", player, "Purchased " .. item.Name .. "!", "Success")
    Network.FireClient("LimitedShopUpdated", player, LimitedShopService.GetPlayerShopData(player))

    -- Broadcast updated global stock to ALL players (social proof / urgency)
    for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
        if plr ~= player then
            Network.FireClient("LimitedShopUpdated", plr, LimitedShopService.GetPlayerShopData(plr))
        end
    end

    return true
end

-- Grant the reward for a limited item
function LimitedShopService.GrantLimitedItem(player: Player, item)
    local data = DataService.GetData(player)
    if not data then return end

    if item.Category == "Consumable" then
        -- Store in consumable inventory
        if not data.Consumables then data.Consumables = {} end
        data.Consumables[item.Id] = (data.Consumables[item.Id] or 0) + 1

    elseif item.Category == "Material" then
        if not data.Materials then data.Materials = {} end
        data.Materials[item.Id] = (data.Materials[item.Id] or 0) + 1

    elseif item.Category == "Boost" then
        -- Activate boost immediately (or add to inventory)
        if not data.ActiveBoosts then data.ActiveBoosts = {} end
        local boostType = "Coins" -- default
        if item.Id:find("luck") then boostType = "Luck" end
        local now = os.time()
        local currentExpiry = data.ActiveBoosts[boostType] or 0
        if currentExpiry > now then
            data.ActiveBoosts[boostType] = currentExpiry + 1800
        else
            data.ActiveBoosts[boostType] = now + 1800
        end
        Network.FireClient("BoostActivated", player, boostType, data.ActiveBoosts[boostType])
    end
end

-- Get serialized shop data for a player (items + remaining stock + global scarcity)
function LimitedShopService.GetPlayerShopData(player: Player)
    local items = LimitedShopService.GetDailyItems()
    local result = {}
    for _, item in ipairs(items) do
        table.insert(result, {
            Id              = item.Id,
            Name            = item.Name,
            Description     = item.Description,
            Currency        = item.Currency,
            Price           = item.Price,
            Stock           = getPlayerStock(player, item.Id),
            MaxStock        = item.Stock,
            GlobalRemaining = getGlobalRemaining(item.Id),
            GlobalCap       = GLOBAL_STOCK_CAP,
            SellingFast     = isSellingFast(item.Id),
            Category        = item.Category,
        })
    end
    return result
end

function LimitedShopService.Init(dataService, currencyService, analyticsService)
    DataService = dataService
    CurrencyService = currencyService
    AnalyticsService = analyticsService

    Network.OnServerEvent("PurchaseLimitedItem", function(player: Player, itemId: string)
        LimitedShopService.PurchaseItem(player, itemId)
    end)

    Network.OnServerEvent("RequestLimitedShop", function(player: Player)
        Network.FireClient("LimitedShopData", player, LimitedShopService.GetPlayerShopData(player))
    end)

    print("[LimitedShopService] Initialized")
end

return LimitedShopService
