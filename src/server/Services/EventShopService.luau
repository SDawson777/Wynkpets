--[[
    EventShopService.luau
    Manages live-ops events and the event shop.
    Handles:
      • Checking which event is currently active (from EventConfig)
      • Awarding EventCoins when players complete event tasks
      • Serving the event shop listing (remaining stock per player)
      • Processing event shop purchases (boosts, currency, pets)
      • Broadcasting event start/end to all clients
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EventConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EventConfig"))

local DataService
local CurrencyService
local BoostService
local AnalyticsService
local PetService
local EggService

local EventShopService = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getActiveEvent()
    local id = EventConfig.GetActiveEventId()
    if not id or id == "" then return nil end
    local event = EventConfig.EventById[id]
    if not event then return nil end
    local now = os.time()
    if event.StartTime > now or event.EndTime < now then return nil end
    return event
end

local function getPlayerPurchases(data, eventId)
    if not data.EventPurchases then data.EventPurchases = {} end
    if not data.EventPurchases[eventId] then data.EventPurchases[eventId] = {} end
    return data.EventPurchases[eventId]
end

local function buildShopListing(event, data)
    local purchases = getPlayerPurchases(data, event.Id)
    local listing = {}
    for _, item in ipairs(event.Shop) do
        local bought = purchases[item.Id] or 0
        table.insert(listing, {
            Id            = item.Id,
            Name          = item.Name,
            Description   = item.Description,
            Cost          = item.Cost,
            Type          = item.Type,
            Icon          = item.Icon,
            MaxPurchases  = item.MaxPurchases or 1,
            Purchased     = bought,
            CanBuy        = bought < (item.MaxPurchases or 1),
            Exclusive     = item.Exclusive or false,
        })
    end
    return listing
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Award EventCoins from a task completion (called by other services)
function EventShopService.AwardCoins(player: Player, amount: number, reason: string?)
    local event = getActiveEvent()
    if not event then return end

    local data = DataService.GetData(player)
    if not data then return end

    data.EventCoins = (data.EventCoins or 0) + amount
    Network.FireClient("EventCoinUpdated", player, data.EventCoins)

    if AnalyticsService then
        AnalyticsService.LogEvent(player, "EventCoinsAwarded", {
            EventId = event.Id,
            Amount  = amount,
            Reason  = reason or "task",
        })
    end
end

-- Called by other services when a player completes an event-trackable action
-- taskType matches EventConfig.Tasks[n].Type values
function EventShopService.TrackAction(player: Player, taskType: string, amount: number?)
    local event = getActiveEvent()
    if not event then return end

    local data = DataService.GetData(player)
    if not data then return end

    -- Check each task that matches this type
    for _, task in ipairs(event.Tasks) do
        if task.Type == taskType then
            -- Simple completion-triggered coin award (no per-player progress stored for events)
            local threshold = task.Target or 1
            -- Track incremental progress per task in session (not persisted; resets on rejoin)
            if not data.EventProgress then data.EventProgress = {} end
            if not data.EventProgress[event.Id] then data.EventProgress[event.Id] = {} end
            local prog = data.EventProgress[event.Id]

            prog[task.Id] = (prog[task.Id] or 0) + (amount or 1)
            while prog[task.Id] >= threshold do
                prog[task.Id] = prog[task.Id] - threshold
                EventShopService.AwardCoins(player, task.Reward, task.Id)
            end
        end
    end
end

-- Get event info public (called by EventService / other services)
function EventShopService.GetActiveEvent()
    return getActiveEvent()
end

-- ── Remotes ───────────────────────────────────────────────────────────────────

local function setupRemotes()
    -- Client requests current event shop data
    Network.OnServerEvent("RequestEventShop", function(player: Player)
        local event = getActiveEvent()
        local data = DataService.GetData(player)
        if not event or not data then
            Network.FireClient("EventShopData", player, nil)
            return
        end

        Network.FireClient("EventShopData", player, {
            EventId      = event.Id,
            EventName    = event.Name,
            Description  = event.Description,
            ThemeColor   = { R = event.ThemeColor.R, G = event.ThemeColor.G, B = event.ThemeColor.B },
            Icon         = event.Icon,
            CurrencyName = event.CurrencyName,
            CurrencyIcon = event.CurrencyIcon,
            PlayerCoins  = data.EventCoins or 0,
            Items        = buildShopListing(event, data),
        })
    end)

    -- Client purchases an event shop item
    Network.OnServerEvent("PurchaseEventItem", function(player: Player, itemId: string)
        if type(itemId) ~= "string" then return end

        local event = getActiveEvent()
        if not event then
            Network.FireClient("ShowNotification", player, "No active event!", "Warning")
            return
        end

        local item = EventConfig.ShopItemById[event.Id] and EventConfig.ShopItemById[event.Id][itemId]
        if not item then
            Network.FireClient("ShowNotification", player, "Item not found.", "Warning")
            return
        end

        local data = DataService.GetData(player)
        if not data then return end

        -- Check purchase limit
        local purchases = getPlayerPurchases(data, event.Id)
        local bought = purchases[itemId] or 0
        if bought >= (item.MaxPurchases or 1) then
            Network.FireClient("ShowNotification", player, "Purchase limit reached.", "Warning")
            return
        end

        -- Check EventCoins
        local coins = data.EventCoins or 0
        if coins < item.Cost then
            Network.FireClient("ShowNotification", player,
                "Not enough " .. event.CurrencyName .. "! Need " .. item.Cost .. ", have " .. coins .. ".", "Warning")
            return
        end

        -- Deduct
        data.EventCoins = coins - item.Cost
        purchases[itemId] = bought + 1
        Network.FireClient("EventCoinUpdated", player, data.EventCoins)

        -- Grant reward
        if item.Type == "Boost" then
            if BoostService then
                BoostService.Activate(player, item.BoostType, item.Duration or 1800)
            end
        elseif item.Type == "Currency" then
            if item.Gems and item.Gems > 0 then
                CurrencyService.Add(player, "Gems", item.Gems, false)
            end
            if item.Coins and item.Coins > 0 then
                CurrencyService.Add(player, "Coins", item.Coins, false)
            end
        elseif item.Type == "Pet" then
            if PetService and item.PetId and item.PetId ~= "" then
                PetService.AddPet(player, item.PetId)
            end
            Network.FireClient("ShowNotification", player,
                "🐾 " .. item.Name .. " added to your collection!", "Success")
        elseif item.Type == "Egg" then
            -- Auto-hatch: grant the player one pull from this egg's pet pool
            if EggService and item.EggId and item.EggId ~= "" then
                EggService.HatchEgg(player, item.EggId)
            end
        end

        if AnalyticsService then
            AnalyticsService.LogEvent(player, "EventShopPurchase", {
                EventId    = event.Id,
                ItemId     = itemId,
                Cost       = item.Cost,
                CoinsLeft  = data.EventCoins,
            })
        end

        -- Push updated listing
        Network.FireClient("EventShopUpdated", player, {
            PlayerCoins = data.EventCoins,
            Items       = buildShopListing(event, data),
        })

        Network.FireClient("ShowNotification", player, item.Name .. " purchased!", "Success")
    end)
end

-- ── PlayerAdded ───────────────────────────────────────────────────────────────

function EventShopService.PlayerAdded(player: Player)
    -- Send current event status
    task.delay(2, function()
        if not player.Parent then return end
        local event = getActiveEvent()
        if event then
            Network.FireClient("ServerEvent", player, {
                EventId = event.Id,
                Name    = event.Name,
                Icon    = event.Icon,
            })
        end
    end)
end

-- ── Init ──────────────────────────────────────────────────────────────────────

-- Late-bind EggService to avoid circular dependency (call after EventShopService.Init)
function EventShopService.SetEggService(es)
    EggService = es
end

function EventShopService.Init(dataService, currencyService, boostService, analyticsService, petService)
    DataService    = dataService
    CurrencyService = currencyService
    BoostService   = boostService
    AnalyticsService = analyticsService
    PetService     = petService

    setupRemotes()

    for _, player in ipairs(Players:GetPlayers()) do
        EventShopService.PlayerAdded(player)
    end
end

return EventShopService
