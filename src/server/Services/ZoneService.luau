--[[
    ZoneService.luau
    Handles zone unlocking and teleportation.
    Server-authoritative.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

local DataService
local CurrencyService
local RewardService
local AntiExploitService
local CoinSpawnerService          -- set via ZoneService.SetCoinSpawnerService
local AnalyticsService            -- set via ZoneService.SetAnalyticsService
local MonetizationPromptService   -- set via ZoneService.SetMonetizationPromptService

local ZoneService = {}

-- Track player's current zone for distance-based teleport pricing
local _playerCurrentZone: { [Player]: string } = {}
local TELEPORT_COST_PER_ZONE_JUMP = 150

-- UpsellTrigger rate-limit for zone-unlock shortage (3 min per player)
local _zoneShortageCooldown: { [Player]: number } = {}
local ZONE_SHORTAGE_UPSELL_CD = 180

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
            -- Coin shortage trigger: native prompt via MonetizationPromptService (300s gate).
            -- UpsellTrigger UI card debounced 3 min to avoid repeat noise.
            if zone.UnlockCurrency == "Coins" and MonetizationPromptService then
                MonetizationPromptService.TriggerPrompt(player, "DoubleCoins")
                local now = tick()
                local last = _zoneShortageCooldown[player]
                if not last or (now - last) >= ZONE_SHORTAGE_UPSELL_CD then
                    _zoneShortageCooldown[player] = now
                    Network.FireClient("UpsellTrigger", player, "coin_boost")
                end
            end
            return false
        end
        CurrencyService.Remove(player, zone.UnlockCurrency, zone.UnlockCost)
    end

    -- Unlock
    table.insert(data.UnlockedZones, zoneId)
    Network.FireClient("ZoneUnlocked", player, zoneId)
    Network.FireClient("ShowNotification", player, "Unlocked " .. zone.Name .. "!", "Success")
    -- Track analytics
    if AnalyticsService then
        AnalyticsService.TrackZoneUnlock(player, zoneId, zone.UnlockCost)
    end
    -- Invalidate coin zone cache so newly unlocked coins are collectible immediately
    if CoinSpawnerService then
        CoinSpawnerService.InvalidateZoneCache(player)
    end
    -- Zone 3+ upsell: coins per node jump significantly (65→200→600…), so DoubleCoins
    -- becomes far more valuable here than in Zone 1. Fire a lightweight toast nudge
    -- 5 s after unlock so it doesn't race with the zone-unlock notification banner.
    if zone.Order and zone.Order >= 3 then
        task.delay(5, function()
            if player.Parent then
                Network.FireClient("UpsellTrigger", player, "DoubleCoins")
            end
        end)
    end
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
function ZoneService.TeleportToZone(player: Player, zoneId: string, skipCost: boolean?)
    if not ZoneService.IsZoneUnlocked(player, zoneId) then
        Network.FireClient("ShowNotification", player, "You haven't unlocked this zone!", "Warning")
        return
    end

    local zone = ZoneConfig.GetZone(zoneId)
    if not zone then return end

    -- Optional teleport fee for manual long-distance jumps
    if not skipCost then
        local currentZoneId = _playerCurrentZone[player]
        if currentZoneId and currentZoneId ~= zoneId then
            local currentZone = ZoneConfig.GetZone(currentZoneId)
            if currentZone and currentZone.Order and zone.Order then
                local jumpDistance = math.abs(zone.Order - currentZone.Order)
                local teleportCost = jumpDistance * TELEPORT_COST_PER_ZONE_JUMP
                if teleportCost > 0 then
                    if not CurrencyService.CanAfford(player, "Coins", teleportCost) then
                        Network.FireClient("ShowNotification", player,
                            "Not enough Coins to teleport! Need " .. tostring(teleportCost), "Warning")
                        return
                    end
                    CurrencyService.Remove(player, "Coins", teleportCost)
                    Network.FireClient("ShowNotification", player,
                        "Teleported for " .. tostring(teleportCost) .. " Coins", "Info")
                end
            end
        end
    end

    local character = player.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            -- SpawnPosition.Y = 5 = floor top; offset +4 so HRP materialises above surface
            if AntiExploitService then
                AntiExploitService.NotifyTeleport(player)
            end
            humanoidRootPart.CFrame = CFrame.new(zone.SpawnPosition + Vector3.new(0, 4, 0))

            -- Update current zone for auto-collect optimization
            if CoinSpawnerService then
                CoinSpawnerService.SetPlayerZone(player, zoneId)
            end
            _playerCurrentZone[player] = zoneId

            -- Notify client so ZoneNavBar can highlight active zone
            Network.FireClient("ZoneTeleported", player, zoneId)

            -- Track quest progress
            if RewardService then
                RewardService.UpdateQuestProgress(player, "VisitZones", 1)
            end
        end
    end
end

-- Initialize
function ZoneService.Init(dataService, currencyService, rewardService, antiExploitService)
    DataService = dataService
    CurrencyService = currencyService
    RewardService = rewardService
    AntiExploitService = antiExploitService

    Players.PlayerAdded:Connect(function(player)
        _playerCurrentZone[player] = "starter_meadow"
    end)

    Players.PlayerRemoving:Connect(function(player)
        _zoneShortageCooldown[player] = nil
        _playerCurrentZone[player] = nil
    end)

    Network.OnServerEvent("UnlockZone", function(player: Player, zoneId: string)
        if type(zoneId) ~= "string" then return end
        if not AntiExploitService.CheckRateLimit(player, "UnlockZone") then return end
        ZoneService.UnlockZone(player, zoneId)
    end)

    Network.OnServerEvent("TeleportToZone", function(player: Player, zoneId: string)
        if type(zoneId) ~= "string" then return end
        ZoneService.TeleportToZone(player, zoneId)
    end)
end

function ZoneService.SetCoinSpawnerService(css) CoinSpawnerService = css end
function ZoneService.SetAnalyticsService(as) AnalyticsService = as end
function ZoneService.SetMonetizationPromptService(mps) MonetizationPromptService = mps end

return ZoneService
