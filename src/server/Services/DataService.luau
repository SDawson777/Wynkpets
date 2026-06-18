--[[
    DataService.luau
    Handles player data persistence using DataStoreService.
    Server-authoritative: all data mutations go through here.
    Includes session locking, auto-save, and retry logic.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local RebirthConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RebirthConfig"))

local DataService = {}

local DATA_STORE_NAME = "WynkpetsPlayerData_v1"
local AUTO_SAVE_INTERVAL = 120 -- seconds
local MAX_RETRIES = 5
local RETRY_DELAY = 1
local SESSION_LOCK_EXPIRE = 1800 -- 30 minutes

local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
local playerDataCache = {} -- [Player] = data
local sessionLocks = {} -- [Player] = true
local savingPlayers = {} -- [Player] = true (prevent double-save)
local badLoadPlayers = {} -- [Player] = true (data load failed; block saves to prevent overwriting real data)

-- Default data template for new players
local DEFAULT_DATA = {
    Coins = 0,
    Gems = 0,
    Pets = {},
    EquippedPets = {},
    UnlockedZones = { "starter_meadow" },
    Rebirths = 0,
    RebirthMultiplier = 1.0,
    TotalCoinsEarned = 0,
    TotalEggsHatched = 0,
    TotalPetsCollected = 0,
    MaxEquipSlots = RebirthConfig.BaseEquipSlots,
    MaxPetStorage = 200,
    Gamepasses = {},
    LoginStreak = 0,
    LoginDays = 0,
    LastLogin = 0,
    DailyRewardClaimed = false,
    Quests = {},
    CompletedQuests = {},
    PetIndex = {},
    Settings = {},
    JoinTime = 0,
    PlayTime = 0,
    FirstPurchaseClaimed = false,
    ActiveBoosts = {},
    BoostInventory = {},           -- { [boostType] = count } stored charges
    Achievements = {},
    TradesCompleted = 0,
    PetsFused = 0,
    SpecialEggsClaimed = 0,
    -- Achievement tracking counters (O(1) lookups; maintained by PetService.AddPet/RemovePet)
    GoldenCount = 0,
    RainbowCount = 0,
    MythicCount = 0,
    SecretCount = 0,
    SecretTokens = {},
    SecretTokensCount = 0,
    OffersClaimed = {},
    LimitedPurchases = {},
    Consumables = {},
    Materials = {},
    TotalRobuxSpent = 0,
    AnalyticsSummary = {},
    -- Subscription / VIP
    SubscriptionExpiry = 0,        -- os.time() when VIP subscription expires
    SubscriptionTier = "none",     -- "none" | "basic" | "vip"
    -- Weekly quests
    WeeklyQuests = {},             -- { [questId] = { Progress, Completed, Claimed } }
    WeeklyQuestReset = 0,          -- os.time() of last weekly reset
    DailyQuestRerolls = 0,         -- rerolls used this day
    DailyQuestRerollReset = 0,     -- os.time() of last reroll-count reset
    -- Event shop
    EventCoins = 0,                -- event-specific currency
    EventProgress = {},            -- { [eventId] = progress }
    EventPurchases = {},           -- { [itemId] = count }
    -- LiveOps evolution system
    EvolutionMaterials = { WynkShards = 0, MoonEssence = 0, StormCrystal = 0 },
    EvoMissedWindows = 0,          -- consecutive evolution windows skipped (pity counter)
    EventWindowHistory = {},       -- { [windowId] = { Attempted, Completed, HatchCount, QuestsDone } }
    TotalEvolutions = 0,           -- lifetime evolutions completed
    -- Session playtime milestones
    SessionMilestonesClaimed = {}, -- { [minutesMilestone] = true }
    -- Purchase history (last 50 products)
    PurchaseHistory = {},
    -- Starter Pack offer tracking
    StarterPackShownAt = 0,        -- os.time() when last shown (0 = never)
    StarterPackPurchased = false,  -- permanently true once purchased
    -- First-session onboarding (fires exactly once, on the very first join)
    FirstSessionClaimed = false,   -- true after starter gifts delivered
    -- Pet Expeditions
    Expeditions = {
        Active = {},    -- { SlotIndex, ZoneId, TierId, PetUUID, PetPower, StartTime, Duration }
        Completed = 0,  -- lifetime completed count
    },
    -- Collected Eggs (field collection → hatchery hatching)
    CollectedEggs = {},           -- { [eggId] = count }
    -- Progress reward rate-limiting
    LastProgressRewardTime = 0,    -- os.time() of last ClaimProgressReward grant
    -- Battle Pass (reset each season)
    BattlePassSeason       = 0,    -- CurrentSeason number when progress was earned
    BattlePassTier         = 0,    -- tier reached this season (0 = none, max 30)
    BattlePassXP           = 0,    -- XP progress toward next tier
    BattlePassPremium      = false, -- has purchased premium track this season
    BattlePassTiersClaimedF = {},  -- { [tier] = true } free rewards claimed
    BattlePassTiersClaimedP = {},  -- { [tier] = true } premium rewards claimed
    Version = 1,
}

-- Deep copy utility
local function deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for key, value in pairs(original) do
        copy[deepCopy(key)] = deepCopy(value)
    end
    return copy
end

-- Reconcile loaded data with template (add missing keys)
local function reconcileData(loaded, template)
    local data = deepCopy(loaded)
    for key, defaultValue in pairs(template) do
        if data[key] == nil then
            data[key] = deepCopy(defaultValue)
        end
    end
    return data
end

-- Retry wrapper for DataStore calls (fails fast on non-transient errors)
local function retryAsync(func, ...)
    local args = { ... }
    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(function()
            return func(unpack(args))
        end)
        if success then
            return true, result
        end
        -- Fail immediately on non-transient errors (game not published, Studio mode)
        local errStr = tostring(result):lower()
        if errStr:find("http") or errStr:find("publish") or errStr:find("api services") then
            warn("[DataService] Non-transient DataStore error (game not published?): " .. tostring(result))
            return false, result
        end
        if attempt < MAX_RETRIES then
            warn(string.format("[DataService] Attempt %d failed: %s. Retrying...", attempt, tostring(result)))
            task.wait(RETRY_DELAY * attempt)
        else
            warn(string.format("[DataService] All %d attempts failed: %s", MAX_RETRIES, tostring(result)))
            return false, result
        end
    end
    return false, "Max retries exceeded"
end

-- Load player data
function DataService.LoadData(player: Player): boolean
    if playerDataCache[player] then
        return true -- Already loaded
    end

    local key = "Player_" .. player.UserId

    local success, data = retryAsync(function()
        return dataStore:GetAsync(key)
    end)

    if success then
        if data then
            data = reconcileData(data, DEFAULT_DATA)
        else
            data = deepCopy(DEFAULT_DATA)
        end

        data.JoinTime = os.time()
        playerDataCache[player] = data
        sessionLocks[player] = true

        -- Send data to client
        Network.FireClient("PlayerDataLoaded", player, data)
        print(string.format("[DataService] Loaded data for %s (%d)", player.Name, player.UserId))
        return true
    else
        warn(string.format("[DataService] Failed to load data for %s: %s", player.Name, tostring(data)))
        -- Give them default data so they can still play, but block auto-save
        -- to prevent overwriting their real data if the DataStore recovers
        badLoadPlayers[player] = true
        playerDataCache[player] = deepCopy(DEFAULT_DATA)
        playerDataCache[player].JoinTime = os.time()
        Network.FireClient("PlayerDataLoaded", player, playerDataCache[player])
        return false
    end
end

-- Save player data
function DataService.SaveData(player: Player): boolean
    local data = playerDataCache[player]
    if not data then
        return false
    end

    if badLoadPlayers[player] then
        warn("[DataService] Skipping save for " .. player.Name .. " — load failed, refusing to overwrite real data")
        return false
    end

    if savingPlayers[player] then
        return false -- Already saving
    end
    savingPlayers[player] = true

    -- Update play time
    if data.JoinTime > 0 then
        data.PlayTime = data.PlayTime + (os.time() - data.JoinTime)
        data.JoinTime = os.time()
    end

    local key = "Player_" .. player.UserId

    local success, err = retryAsync(function()
        dataStore:SetAsync(key, data)
    end)

    savingPlayers[player] = nil

    if success then
        print(string.format("[DataService] Saved data for %s", player.Name))
    else
        warn(string.format("[DataService] Failed to save data for %s: %s", player.Name, tostring(err)))
    end

    return success
end

-- Get player data (read-only reference)
function DataService.GetData(player: Player)
    return playerDataCache[player]
end

-- Update a specific field
function DataService.SetField(player: Player, field: string, value: any)
    local data = playerDataCache[player]
    if not data then
        return false
    end
    if DEFAULT_DATA[field] == nil then
        warn("[DataService] Unknown field: " .. field)
        return false
    end
    data[field] = value
    Network.FireClient("DataUpdated", player, field, value)
    return true
end

-- Increment a numeric field
function DataService.IncrementField(player: Player, field: string, amount: number)
    local data = playerDataCache[player]
    if not data then
        return false
    end
    if type(data[field]) ~= "number" then
        warn("[DataService] Field is not a number: " .. field)
        return false
    end
    data[field] = data[field] + amount
    Network.FireClient("DataUpdated", player, field, data[field])
    return true
end

-- Clean up on player leave
function DataService.PlayerRemoving(player: Player)
    if playerDataCache[player] then
        DataService.SaveData(player) -- no-op if badLoadPlayers[player]
        playerDataCache[player] = nil
        sessionLocks[player] = nil
        badLoadPlayers[player] = nil
    end
end

-- Auto-save loop
function DataService.StartAutoSave()
    task.spawn(function()
        while true do
            task.wait(AUTO_SAVE_INTERVAL)
            for player, _ in pairs(playerDataCache) do
                if player.Parent then -- Still in game
                    task.spawn(function()
                        DataService.SaveData(player)
                    end)
                end
            end
        end
    end)
end

-- Save all players on server shutdown
function DataService.OnServerShutdown()
    game:BindToClose(function()
        -- Collect all players who still have data in cache
        local pending = {}
        for player, _ in pairs(playerDataCache) do
            table.insert(pending, player)
        end

        if #pending == 0 then return end

        -- Save each player, tracking completion via a shared counter
        local remaining = #pending
        local allDone = Instance.new("BindableEvent")

        for _, player in ipairs(pending) do
            task.spawn(function()
                DataService.SaveData(player)
                remaining -= 1
                if remaining <= 0 then
                    allDone:Fire()
                end
            end)
        end

        -- Block BindToClose until all saves finish (Roblox gives ~30 s)
        allDone.Event:Wait()
        allDone:Destroy()
    end)
end

-- Setup RemoteFunction for client data requests
function DataService.Init()
    local getDataFunc = Network.GetFunction("GetPlayerData")
    if getDataFunc then
        getDataFunc.OnServerInvoke = function(player)
            return playerDataCache[player]
        end
    end

    local getTimeFunc = Network.GetFunction("GetServerTime")
    if getTimeFunc then
        getTimeFunc.OnServerInvoke = function(_player)
            return os.time()
        end
    end

    DataService.StartAutoSave()
    DataService.OnServerShutdown()
end

return DataService
