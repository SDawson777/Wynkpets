--[[
    RebirthService.luau
    Handles the rebirth/prestige system.
    Server-authoritative.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local RebirthConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RebirthConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService
local CurrencyService
local AntiExploitService
local EvolutionService      -- set via RebirthService.SetEvolutionService
local AnalyticsService      -- set via RebirthService.SetAnalyticsService
local BattlePassService     -- set via RebirthService.SetBattlePassService
local EntitlementService    -- set via RebirthService.SetEntitlementService

local RebirthService = {}

-- Perform a rebirth for a player
function RebirthService.Rebirth(player: Player): boolean
    local data = DataService.GetData(player)
    if not data then return false end

    local currentRebirths = data.Rebirths or 0
    local nextTier = RebirthConfig.GetNextTier(currentRebirths)

    if not nextTier then
        Network.FireClient("ShowNotification", player, "You've reached the maximum rebirth level!", "Warning")
        return false
    end

    -- Check if player can afford rebirth
    if not CurrencyService.CanAfford(player, "Coins", nextTier.Cost) then
        Network.FireClient("ShowNotification", player,
            "Not enough Coins! Need " .. tostring(nextTier.Cost), "Warning")
        return false
    end

    -- === Perform Rebirth ===

    -- Reset coins
    data.Coins = 0

    -- Reset unlocked zones (keep starter)
    data.UnlockedZones = { "starter_meadow" }

    -- Increment rebirth level
    data.Rebirths = currentRebirths + 1

    -- Set new multiplier
    data.RebirthMultiplier = nextTier.Multiplier

    -- Update equip slots (base from rebirth tiers + extra_equip gamepass bonus)
    local extraSlots = EntitlementService and EntitlementService.GetExtraEquipSlots(player) or 0
    data.MaxEquipSlots = RebirthConfig.GetTotalEquipSlots(data.Rebirths) + extraSlots

    -- Track analytics
    if AnalyticsService then
        AnalyticsService.TrackRebirth(player, data.Rebirths)
    end

    -- Notify client
    Network.FireClient("CurrencyUpdated", player, "Coins", data.Coins)
    Network.FireClient("RebirthCompleted", player, {
        Rebirths = data.Rebirths,
        Multiplier = data.RebirthMultiplier,
        MaxEquipSlots = data.MaxEquipSlots,
    })
    Network.FireClient("ShowNotification", player,
        "Rebirth " .. data.Rebirths .. "! " .. nextTier.Multiplier .. "x multiplier!", "Success")

    -- Award evolution materials for rebirth
    if EvolutionService then
        EvolutionService.TryAwardShards(player, "Rebirth")
    end
    -- Battle Pass XP: +2,000 XP per rebirth (major commitment reward)
    if BattlePassService then
        BattlePassService.AddXP(player, 2000, "rebirth")
    end

    return true
end

-- Get rebirth info for display
function RebirthService.GetRebirthInfo(player: Player)
    local data = DataService.GetData(player)
    if not data then return nil end

    local currentRebirths = data.Rebirths or 0
    local nextTier = RebirthConfig.GetNextTier(currentRebirths)

    return {
        CurrentRebirths = currentRebirths,
        CurrentMultiplier = data.RebirthMultiplier or 1.0,
        CurrentEquipSlots = data.MaxEquipSlots or RebirthConfig.BaseEquipSlots,
        NextTier = nextTier,
        CanRebirth = nextTier and CurrencyService.CanAfford(player, "Coins", nextTier.Cost),
    }
end

-- Initialize
function RebirthService.Init(dataService, currencyService, antiExploitService)
    DataService = dataService
    CurrencyService = currencyService
    AntiExploitService = antiExploitService

    if not LaunchConfig.IsFeatureEnabled("Rebirth") then
        print("[LaunchConfig] RebirthService disabled — skipping handler registration")
        return
    end

    Network.OnServerEvent("RequestRebirth", function(player: Player)
        if not AntiExploitService.CheckRateLimit(player, "RequestRebirth") then return end
        RebirthService.Rebirth(player)
    end)
end

function RebirthService.SetEvolutionService(es) EvolutionService = es end
function RebirthService.SetAnalyticsService(as) AnalyticsService = as end
function RebirthService.SetBattlePassService(bps) BattlePassService = bps end
function RebirthService.SetEntitlementService(ents) EntitlementService = ents end

return RebirthService
