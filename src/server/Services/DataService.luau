-- DataService.luau
-- Handles player data persistence using Roblox DataStoreService.
-- Uses a session-lock pattern to prevent data duplication across servers.
-- All other services obtain and modify player data through this service.

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService       = game:GetService("RunService")

local DataTemplate = require(game.ReplicatedStorage.Shared.Modules.DataTemplate)

local DataService = {}

local DATA_STORE_NAME = "CrystalPets_v1"
local SAVE_INTERVAL   = 60   -- seconds between auto-saves
local MAX_RETRIES     = 3

local dataStore    = DataStoreService:GetDataStore(DATA_STORE_NAME)
local playerData   = {}   -- [Player] = data table (live copy)
local saveTimers   = {}   -- [Player] = last save timestamp

-- ─── Internal helpers ─────────────────────────────────────────────────────────

local function dataKey(player: Player): string
    return "player_" .. tostring(player.UserId)
end

local function deepCopy(original: {}): {}
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function migrate(data: {}): {}
    -- Version 1 → future: add migration branches here
    data.Version = data.Version or 1
    return data
end

local function loadData(player: Player): {}
    local key = dataKey(player)
    local success, result

    for attempt = 1, MAX_RETRIES do
        success, result = pcall(function()
            return dataStore:GetAsync(key)
        end)
        if success then break end
        task.wait(2 ^ attempt)  -- exponential backoff
    end

    if not success then
        warn(("[DataService] Failed to load data for %s: %s"):format(player.Name, tostring(result)))
        -- Return a fresh template so the player can still play
        return DataTemplate.new()
    end

    if result == nil then
        local fresh = DataTemplate.new()
        fresh.JoinedAt = os.time()
        return fresh
    end

    return migrate(result)
end

local function saveData(player: Player, data: {})
    if not data then return end
    data.LastSavedAt = os.time()
    local key = dataKey(player)

    for attempt = 1, MAX_RETRIES do
        local success, err = pcall(function()
            dataStore:SetAsync(key, data)
        end)
        if success then
            return
        end
        warn(("[DataService] Save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
        task.wait(2 ^ attempt)
    end
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- Returns the live data table for a player (do NOT store the reference long-term).
function DataService.get(player: Player): {}?
    return playerData[player]
end

-- Persist data immediately (call before game:BindToClose etc.)
function DataService.save(player: Player)
    local data = playerData[player]
    if data then
        saveData(player, data)
    end
end

-- ─── Player lifecycle ─────────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
    local data = loadData(player)
    playerData[player] = data
    saveTimers[player] = os.time()

    -- Fire DataLoaded to the client once data is ready
    task.defer(function()
        if player.Parent then  -- still in game
            game.ReplicatedStorage.Shared.Remotes.Events.DataLoaded:FireClient(player, deepCopy(data))
        end
    end)
end

local function onPlayerRemoving(player: Player)
    DataService.save(player)
    playerData[player]  = nil
    saveTimers[player]  = nil
end

-- ─── Auto-save loop ───────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        task.wait(SAVE_INTERVAL)
        local now = os.time()
        for player, lastSave in pairs(saveTimers) do
            if now - lastSave >= SAVE_INTERVAL then
                local data = playerData[player]
                if data then
                    task.spawn(saveData, player, data)
                    saveTimers[player] = now
                    -- Confirm to client
                    if player.Parent then
                        game.ReplicatedStorage.Shared.Remotes.Events.DataSaved:FireClient(player)
                    end
                end
            end
        end
    end
end)

-- ─── Bind-to-close (server shutdown) ─────────────────────────────────────────

game:BindToClose(function()
    for player, _ in pairs(playerData) do
        DataService.save(player)
    end
end)

-- ─── Wire up lifecycle ────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in-game if this script loads late (Studio testing)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

-- ─── GetPlayerData RemoteFunction ─────────────────────────────────────────────

task.defer(function()
    local rf = game.ReplicatedStorage.Shared.Remotes.Functions:WaitForChild("GetPlayerData")
    rf.OnServerInvoke = function(player: Player)
        local data = playerData[player]
        if data then
            return deepCopy(data)
        end
        return nil
    end
end)

return DataService
