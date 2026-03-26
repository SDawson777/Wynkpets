--[[
    Network.luau
    Centralized network event definitions.
    Creates all RemoteEvents/RemoteFunctions in ReplicatedStorage/Network folder.
    Both server and client reference this module.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = {}

-- All remote event names
Network.Events = {
    -- Currency
    "CurrencyUpdated",           -- Server -> Client: currency changed
    "CollectCoin",               -- Client -> Server: player clicked a coin
    
    -- Pets
    "PetEquipped",               -- Server -> Client: pet equip state changed
    "PetUnequipped",             -- Server -> Client: pet unequipped
    "PetsUpdated",               -- Server -> Client: pet inventory changed
    "EquipPet",                  -- Client -> Server: request equip
    "UnequipPet",                -- Client -> Server: request unequip
    "DeletePet",                 -- Client -> Server: request delete
    
    -- Eggs / Hatching
    "HatchEgg",                  -- Client -> Server: request hatch
    "HatchResult",               -- Server -> Client: hatch result (pet data)
    "AutoHatchToggle",           -- Client -> Server: toggle auto hatch
    
    -- Zones
    "UnlockZone",                -- Client -> Server: request zone unlock
    "ZoneUnlocked",              -- Server -> Client: zone was unlocked
    "TeleportToZone",            -- Client -> Server: request teleport
    
    -- Rebirth
    "RequestRebirth",            -- Client -> Server: request rebirth
    "RebirthCompleted",          -- Server -> Client: rebirth done
    
    -- Shop / Purchases
    "PurchaseGamepass",          -- Client -> Server: request gamepass purchase
    "PurchaseDevProduct",        -- Client -> Server: request dev product purchase
    "GamepassOwned",             -- Server -> Client: gamepass ownership confirmed
    
    -- Rewards
    "ClaimDailyReward",          -- Client -> Server: claim daily
    "DailyRewardResult",         -- Server -> Client: daily reward result
    "QuestUpdated",              -- Server -> Client: quest progress changed
    "ClaimQuestReward",          -- Client -> Server: claim quest reward
    
    -- Data
    "PlayerDataLoaded",          -- Server -> Client: initial data load
    "DataUpdated",               -- Server -> Client: data changed
    
    -- Boosts
    "BoostActivated",            -- Server -> Client: a boost was activated
    "BoostExpired",              -- Server -> Client: a boost expired
    
    -- Admin
    "AdminCommand",              -- Client -> Server: admin command
    
    -- UI Notifications
    "ShowNotification",          -- Server -> Client: show a notification
}

-- All remote function names (for request-response patterns)
Network.Functions = {
    "GetPlayerData",             -- Client -> Server: request full player data
    "GetServerTime",             -- Client -> Server: request server time
}

local networkFolder = nil

-- Initialize all remotes (CALL ON SERVER ONLY)
function Network.InitServer()
    networkFolder = Instance.new("Folder")
    networkFolder.Name = "Network"
    networkFolder.Parent = ReplicatedStorage
    
    local eventsFolder = Instance.new("Folder")
    eventsFolder.Name = "Events"
    eventsFolder.Parent = networkFolder
    
    local functionsFolder = Instance.new("Folder")
    functionsFolder.Name = "Functions"
    functionsFolder.Parent = networkFolder
    
    for _, eventName in ipairs(Network.Events) do
        local remote = Instance.new("RemoteEvent")
        remote.Name = eventName
        remote.Parent = eventsFolder
    end
    
    for _, funcName in ipairs(Network.Functions) do
        local remote = Instance.new("RemoteFunction")
        remote.Name = funcName
        remote.Parent = functionsFolder
    end
    
    return networkFolder
end

-- Wait for network folder (CLIENT)
function Network.WaitForInit()
    networkFolder = ReplicatedStorage:WaitForChild("Network", 30)
    if not networkFolder then
        error("[Network] Failed to find Network folder in ReplicatedStorage")
    end
end

-- Get a RemoteEvent by name
function Network.GetEvent(eventName: string): RemoteEvent
    if not networkFolder then
        networkFolder = ReplicatedStorage:FindFirstChild("Network")
    end
    local eventsFolder = networkFolder and networkFolder:FindFirstChild("Events")
    if eventsFolder then
        return eventsFolder:FindFirstChild(eventName)
    end
    warn("[Network] Event not found: " .. eventName)
    return nil
end

-- Get a RemoteFunction by name
function Network.GetFunction(funcName: string): RemoteFunction
    if not networkFolder then
        networkFolder = ReplicatedStorage:FindFirstChild("Network")
    end
    local functionsFolder = networkFolder and networkFolder:FindFirstChild("Functions")
    if functionsFolder then
        return functionsFolder:FindFirstChild(funcName)
    end
    warn("[Network] Function not found: " .. funcName)
    return nil
end

-- Convenience: Fire event to specific client
function Network.FireClient(eventName: string, player: Player, ...)
    local event = Network.GetEvent(eventName)
    if event then
        event:FireClient(player, ...)
    end
end

-- Convenience: Fire event to all clients
function Network.FireAllClients(eventName: string, ...)
    local event = Network.GetEvent(eventName)
    if event then
        event:FireAllClients(...)
    end
end

-- Convenience: Connect to server event (CLIENT)
function Network.OnClientEvent(eventName: string, callback: (...any) -> ())
    local event = Network.GetEvent(eventName)
    if event then
        return event.OnClientEvent:Connect(callback)
    end
end

-- Convenience: Connect to client event (SERVER)
function Network.OnServerEvent(eventName: string, callback: (Player, ...any) -> ())
    local event = Network.GetEvent(eventName)
    if event then
        return event.OnServerEvent:Connect(callback)
    end
end

-- Convenience: Fire event to server (CLIENT)
function Network.FireServer(eventName: string, ...)
    local event = Network.GetEvent(eventName)
    if event then
        event:FireServer(...)
    end
end

return Network
