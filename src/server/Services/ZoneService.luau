--[[
    ZoneService.luau
    Handles zone unlocking and teleportation.
    Server-authoritative.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

local DataService
local CurrencyService

local ZoneService = {}

-- Unlock a zone for a player
function ZoneService.UnlockZone(player: Player, zoneId: string): boolean
    local zone = ZoneConfig.GetZone(zoneId)
    if not zone then
        warn("[ZoneService] Unknown zone: " .. tostring(zoneId))
        return false
    end

    local data = DataService.GetData(player)
    if not data then return false end

    -- Check if already unlocked
    for _, unlockedZone in ipairs(data.UnlockedZones or {}) do
        if unlockedZone == zoneId then
            return true -- Already unlocked
        end
    end

    -- Check prerequisite (must have previous zone unlocked)
    if zone.Order > 1 then
        local prevZone = ZoneConfig.GetZoneByOrder(zone.Order - 1)
        if prevZone then
            local hasPrev = false
            for _, unlockedZone in ipairs(data.UnlockedZones or {}) do
                if unlockedZone == prevZone.Id then
                    hasPrev = true
                    break
                end
            end
            if not hasPrev then
                Network.FireClient("ShowNotification", player, "Unlock the previous zone first!", "Warning")
                return false
            end
        end
    end

    -- Check cost
    if zone.UnlockCost > 0 then
        if not CurrencyService.CanAfford(player, zone.UnlockCurrency, zone.UnlockCost) then
            Network.FireClient("ShowNotification", player,
                "Not enough " .. zone.UnlockCurrency .. "! Need " .. tostring(zone.UnlockCost), "Warning")
            return false
        end
        CurrencyService.Remove(player, zone.UnlockCurrency, zone.UnlockCost)
    end

    -- Unlock
    table.insert(data.UnlockedZones, zoneId)
    Network.FireClient("ZoneUnlocked", player, zoneId)
    Network.FireClient("ShowNotification", player, "Unlocked " .. zone.Name .. "!", "Success")
    return true
end

-- Check if player has zone unlocked
function ZoneService.IsZoneUnlocked(player: Player, zoneId: string): boolean
    local data = DataService.GetData(player)
    if not data then return false end

    for _, unlockedZone in ipairs(data.UnlockedZones or {}) do
        if unlockedZone == zoneId then
            return true
        end
    end
    return false
end

-- Teleport player to zone
function ZoneService.TeleportToZone(player: Player, zoneId: string)
    if not ZoneService.IsZoneUnlocked(player, zoneId) then
        Network.FireClient("ShowNotification", player, "You haven't unlocked this zone!", "Warning")
        return
    end

    local zone = ZoneConfig.GetZone(zoneId)
    if not zone then return end

    local character = player.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            humanoidRootPart.CFrame = CFrame.new(zone.SpawnPosition)
        end
    end
end

-- Initialize
function ZoneService.Init(dataService, currencyService)
    DataService = dataService
    CurrencyService = currencyService

    Network.OnServerEvent("UnlockZone", function(player: Player, zoneId: string)
        if type(zoneId) ~= "string" then return end
        ZoneService.UnlockZone(player, zoneId)
    end)

    Network.OnServerEvent("TeleportToZone", function(player: Player, zoneId: string)
        if type(zoneId) ~= "string" then return end
        ZoneService.TeleportToZone(player, zoneId)
    end)
end

return ZoneService
