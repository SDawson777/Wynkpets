-- LeaderboardService.luau
-- Maintains in-game leaderboards via OrderedDataStore and Roblox leaderstats.
-- Three boards:
--   1. "MostCoins"    – total lifetime coins earned
--   2. "MostRebirths" – total rebirths completed
--   3. "MostPets"     – total pets hatched
--
-- Leaderstats (shown in Roblox's default player panel) display:
--   Coins (current balance), Rebirths, Pets (inventory size)

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local LEADERBOARD_UPDATE_INTERVAL = 60  -- seconds between full board refreshes

local coinsStore    = DataStoreService:GetOrderedDataStore("Leaderboard_Coins_v1")
local rebirthStore  = DataStoreService:GetOrderedDataStore("Leaderboard_Rebirths_v1")
local petsStore     = DataStoreService:GetOrderedDataStore("Leaderboard_Pets_v1")

local LeaderboardService = {}

-- ─── Cached top-10 tables ─────────────────────────────────────────────────────
-- Each entry: { rank, name, value }
LeaderboardService.TopCoins    = {}
LeaderboardService.TopRebirths = {}
LeaderboardService.TopPets     = {}

-- ─── leaderstats (Roblox player panel) ───────────────────────────────────────

local function createLeaderstats(player: Player)
    local ls          = Instance.new("Folder")
    ls.Name           = "leaderstats"
    ls.Parent         = player

    local coinsVal    = Instance.new("NumberValue")
    coinsVal.Name     = "Coins"
    coinsVal.Value    = 0
    coinsVal.Parent   = ls

    local rebirthVal  = Instance.new("NumberValue")
    rebirthVal.Name   = "Rebirths"
    rebirthVal.Value  = 0
    rebirthVal.Parent = ls

    local petsVal     = Instance.new("NumberValue")
    petsVal.Name      = "Pets"
    petsVal.Value     = 0
    petsVal.Parent    = ls
end

local function updateLeaderstats(player: Player)
    local data = DataService.get(player)
    if not data then return end

    local ls = player:FindFirstChild("leaderstats")
    if not ls then return end

    ls.Coins.Value    = data.Coins        or 0
    ls.Rebirths.Value = data.Rebirths     or 0
    ls.Pets.Value     = #(data.Pets or {})
end

-- ─── OrderedDataStore submission ─────────────────────────────────────────────

local function submitScore(player: Player)
    local data = DataService.get(player)
    if not data then return end

    local uid  = tostring(player.UserId)
    local ok1  = pcall(function() coinsStore:SetAsync(uid, math.floor(data.Stats.totalCoinsEarned or 0)) end)
    local ok2  = pcall(function() rebirthStore:SetAsync(uid, data.Stats.totalRebirths or 0) end)
    local ok3  = pcall(function() petsStore:SetAsync(uid, data.Stats.totalEggsHatched or 0) end)
    if not ok1 then warn("[LeaderboardService] coinsStore write failed for " .. player.Name) end
    if not ok2 then warn("[LeaderboardService] rebirthStore write failed for " .. player.Name) end
    if not ok3 then warn("[LeaderboardService] petsStore write failed for " .. player.Name) end
end

-- ─── Read top-10 from an OrderedDataStore ─────────────────────────────────────

local function fetchTop10(store): { { rank: number, name: string, value: number } }
    local results = {}
    local success, pages = pcall(function()
        return store:GetSortedAsync(false, 10)
    end)
    if not success then return results end

    local rank = 1
    local page = pages:GetCurrentPage()
    for _, entry in ipairs(page) do
        -- entry.key = userId string, entry.value = score
        local name = "[" .. entry.key .. "]"
        -- Try to resolve display name from Players service (may fail for offline users)
        pcall(function()
            name = game:GetService("Players"):GetNameFromUserIdAsync(tonumber(entry.key))
        end)
        table.insert(results, { rank = rank, name = name, value = entry.value })
        rank = rank + 1
    end
    return results
end

-- ─── Periodic leaderboard refresh ────────────────────────────────────────────

task.spawn(function()
    while true do
        -- Submit all current online players
        for _, player in ipairs(Players:GetPlayers()) do
            task.spawn(submitScore, player)
            task.spawn(updateLeaderstats, player)
        end
        -- Refresh cached top-10 boards
        LeaderboardService.TopCoins    = fetchTop10(coinsStore)
        LeaderboardService.TopRebirths = fetchTop10(rebirthStore)
        LeaderboardService.TopPets     = fetchTop10(petsStore)

        task.wait(LEADERBOARD_UPDATE_INTERVAL)
    end
end)

-- ─── GetLeaderboard RemoteFunction ────────────────────────────────────────────

task.defer(function()
    local rf = game.ReplicatedStorage.Shared.Remotes.Functions:WaitForChild("GetLeaderboard", 30)
    if not rf then
        warn("[LeaderboardService] GetLeaderboard RemoteFunction not found after 30s – leaderboard queries disabled.")
        return
    end
    rf.OnServerInvoke = function(_player: Player, boardName: string)
        if boardName == "Coins"    then return LeaderboardService.TopCoins    end
        if boardName == "Rebirths" then return LeaderboardService.TopRebirths end
        if boardName == "Pets"     then return LeaderboardService.TopPets     end
        return {}
    end
end)

-- ─── Hooks ────────────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
    createLeaderstats(player)
    -- Retry until DataService has loaded this player's data (avoids magic wait delay)
    task.spawn(function()
        local MAX_WAIT = 30  -- seconds
        local elapsed  = 0
        local interval = 0.5
        while elapsed < MAX_WAIT do
            if DataService.get(player) then
                updateLeaderstats(player)
                return
            end
            task.wait(interval)
            elapsed = elapsed + interval
        end
        warn("[LeaderboardService] Timed out waiting for data for " .. player.Name)
    end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    task.spawn(submitScore, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(createLeaderstats, player)
end

return LeaderboardService
