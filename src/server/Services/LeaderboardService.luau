--[[
    LeaderboardService.luau
    Uses OrderedDataStore for persistent leaderboards.
    Tracks: TotalCoinsEarned, TotalEggsHatched, Rebirths, BestPetPower
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local DataService

local LeaderboardService = {}

local LEADERBOARD_CATEGORIES = {
    "TotalCoinsEarned",
    "TotalEggsHatched",
    "Rebirths",
    "BestPetPower",
}

local UPDATE_INTERVAL = 300 -- 5 minutes
local CACHE_DURATION = 60 -- 1 minute
local TOP_ENTRIES = 50

local cachedLeaderboards = {} -- [category] = { data = {}, lastFetch = 0 }
local datastores = {} -- [category] = OrderedDataStore
local playerRequestCooldown = {} -- [Player] = last request tick (rate-limit leaderboard requests)

function LeaderboardService.Init(dataService)
    DataService = dataService

    -- Create OrderedDataStores for each category
    for _, category in ipairs(LEADERBOARD_CATEGORIES) do
        local success, store = pcall(function()
            return DataStoreService:GetOrderedDataStore("Leaderboard_" .. category)
        end)
        if success then
            datastores[category] = store
        else
            warn("[LeaderboardService] Failed to get DataStore for " .. category)
        end
        cachedLeaderboards[category] = { data = {}, lastFetch = 0 }
    end

    -- Periodic update loop
    task.spawn(function()
        while true do
            task.wait(UPDATE_INTERVAL)
            LeaderboardService.UpdateAllPlayers()
        end
    end)

    -- Listen for leaderboard requests (rate-limited: 1 request per 5 s per player)
    Network.OnServerEvent("RequestLeaderboard", function(player, category)
        if type(category) ~= "string" then return end
        local now = tick()
        local last = playerRequestCooldown[player] or 0
        if (now - last) < 5 then return end
        playerRequestCooldown[player] = now
        local data = LeaderboardService.GetLeaderboard(category)
        Network.FireClient("LeaderboardData", player, category, data)
    end)
end

-- Update leaderboard entries for all online players
function LeaderboardService.UpdateAllPlayers()
    local Players = game:GetService("Players")
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            LeaderboardService.UpdatePlayer(player)
        end)
    end
end

-- Update a single player's leaderboard entries
function LeaderboardService.UpdatePlayer(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    local entries = {
        TotalCoinsEarned = data.TotalCoinsEarned or 0,
        TotalEggsHatched = data.TotalEggsHatched or 0,
        Rebirths = data.Rebirths or 0,
        BestPetPower = LeaderboardService.GetBestPetPower(data),
    }

    for category, value in pairs(entries) do
        local store = datastores[category]
        if store and value > 0 then
            local success, err = pcall(function()
                store:SetAsync(tostring(player.UserId), math.floor(value))
            end)
            if not success then
                warn("[LeaderboardService] Failed to update " .. category .. " for " .. player.Name .. ": " .. tostring(err))
            end
        end
    end
end

-- Calculate best pet power from player data
function LeaderboardService.GetBestPetPower(data): number
    local best = 0
    if data.Pets then
        local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("PetConfig"))
        local RarityConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("RarityConfig"))
        local PetLevelConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("PetLevelConfig"))

        for _, pet in ipairs(data.Pets) do
            local petInfo = PetConfig.GetPet(pet.PetId)
            if petInfo then
                local power = petInfo.Power * PetLevelConfig.GetPowerMultiplier(pet.Level or 1)
                if pet.Golden then
                    power = power * RarityConfig.GoldenMultiplier
                elseif pet.Rainbow then
                    power = power * RarityConfig.RainbowMultiplier
                end
                if power > best then
                    best = power
                end
            end
        end
    end
    return math.floor(best)
end

-- Get leaderboard data (cached)
function LeaderboardService.GetLeaderboard(category: string)
    local cached = cachedLeaderboards[category]
    if not cached then return {} end

    local now = os.time()
    if (now - cached.lastFetch) < CACHE_DURATION and #cached.data > 0 then
        return cached.data
    end

    -- Fetch fresh data
    local store = datastores[category]
    if not store then return cached.data end

    local success, pages = pcall(function()
        return store:GetSortedAsync(false, TOP_ENTRIES)
    end)

    if not success or not pages then
        return cached.data
    end

    local entries = {}
    local success2, page = pcall(function()
        return pages:GetCurrentPage()
    end)

    if success2 and page then
        for rank, entry in ipairs(page) do
            table.insert(entries, {
                Rank = rank,
                UserId = tonumber(entry.key),
                Value = entry.value,
            })
        end
    end

    cached.data = entries
    cached.lastFetch = now
    return entries
end

-- Called when player leaves
function LeaderboardService.PlayerRemoving(player: Player)
    playerRequestCooldown[player] = nil
    task.spawn(function()
        LeaderboardService.UpdatePlayer(player)
    end)
end

return LeaderboardService
