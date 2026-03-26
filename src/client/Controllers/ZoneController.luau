--[[
    ZoneController.luau (Client)
    Manages zone state, teleportation, and zone UI triggers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

local ZoneController = {}

local unlockedZones = {}
local currentZone = "starter_meadow"
local updateCallbacks = {}

function ZoneController.GetUnlockedZones()
    return unlockedZones
end

function ZoneController.GetCurrentZone(): string
    return currentZone
end

function ZoneController.IsUnlocked(zoneId: string): boolean
    for _, id in ipairs(unlockedZones) do
        if id == zoneId then
            return true
        end
    end
    return false
end

function ZoneController.OnUpdate(callback: () -> ())
    table.insert(updateCallbacks, callback)
end

local function notifyUpdate()
    for _, callback in ipairs(updateCallbacks) do
        task.spawn(callback)
    end
end

-- Request zone unlock
function ZoneController.Unlock(zoneId: string)
    Network.FireServer("UnlockZone", zoneId)
end

-- Request teleport to zone
function ZoneController.TeleportTo(zoneId: string)
    if ZoneController.IsUnlocked(zoneId) then
        currentZone = zoneId
        Network.FireServer("TeleportToZone", zoneId)
        notifyUpdate()
    end
end

-- Initialize
function ZoneController.Init()
    Network.OnClientEvent("ZoneUnlocked", function(zoneId: string)
        -- Add to unlocked list if not already there
        local found = false
        for _, id in ipairs(unlockedZones) do
            if id == zoneId then
                found = true
                break
            end
        end
        if not found then
            table.insert(unlockedZones, zoneId)
        end
        notifyUpdate()
    end)

    Network.OnClientEvent("PlayerDataLoaded", function(data)
        unlockedZones = data.UnlockedZones or { "starter_meadow" }
        notifyUpdate()
    end)
end

return ZoneController
