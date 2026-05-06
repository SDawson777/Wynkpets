--[[
    BattlePassService.luau
    Season 1: Origins battle pass — server-authoritative.

    Public API:
        BattlePassService.AddXP(player, amount, source)
            Award XP and auto-tier up, granting rewards along the way.
            Called by EggService (hatch), RewardService (quests), RebirthService (rebirth).

        BattlePassService.GetPassData(player) → table
            Returns { Season, Tier, XP, Premium, TiersClaimedFree, TiersClaimedPremium }

        BattlePassService.OnPassPurchased(player)
            Called by ShopService when the premium pass dev product is redeemed.
            Retroactively grants all premium rewards for tiers already reached.

        BattlePassService.PlayerAdded(player)
        BattlePassService.PlayerRemoving(player)

    Data fields used (must exist in DataService DEFAULT_DATA):
        BattlePassSeason          number  — season number when progress was earned
        BattlePassTier            number  — current tier (0 = not started, max 30)
        BattlePassXP              number  — XP progress toward next tier (0..XPPerTier-1)
        BattlePassPremium         bool    — has purchased premium track
        BattlePassTiersClaimedF   table   — { [tier] = true } free rewards collected
        BattlePassTiersClaimedP   table   — { [tier] = true } premium rewards collected

    Season reset:
        When a player joins and their BattlePassSeason < BattlePassConfig.CurrentSeason,
        their tier/XP/claimed data is wiped and they start the new season fresh.
        Premium status also resets (it is per-season).
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared            = ReplicatedStorage:WaitForChild("Shared")

local Network          = require(Shared:WaitForChild("Network"))
local BattlePassConfig = require(Shared:WaitForChild("Configs"):WaitForChild("BattlePassConfig"))
local LaunchConfig     = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService
local CurrencyService
local PetService
local AnalyticsService

local BattlePassService = {}

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function ensureData(data)
    if not data then return false end
    if data.BattlePassSeason           == nil then data.BattlePassSeason          = 0     end
    if data.BattlePassTier             == nil then data.BattlePassTier             = 0     end
    if data.BattlePassXP               == nil then data.BattlePassXP               = 0     end
    if data.BattlePassPremium          == nil then data.BattlePassPremium          = false end
    if data.BattlePassTiersClaimedF    == nil then data.BattlePassTiersClaimedF    = {}    end
    if data.BattlePassTiersClaimedP    == nil then data.BattlePassTiersClaimedP    = {}    end
    return true
end

-- Reset player progress for a new season.
local function resetForSeason(data)
    data.BattlePassSeason       = BattlePassConfig.CurrentSeason
    data.BattlePassTier         = 0
    data.BattlePassXP           = 0
    data.BattlePassPremium      = false
    data.BattlePassTiersClaimedF = {}
    data.BattlePassTiersClaimedP = {}
end

-- Grant a single reward entry to a player.
local function grantReward(player: Player, data, reward)
    if not reward then return end

    if reward.Type == "Coins" then
        CurrencyService.Add(player, "Coins", reward.Amount, false)

    elseif reward.Type == "Gems" then
        CurrencyService.Add(player, "Gems", reward.Amount, false)

    elseif reward.Type == "Pet" then
        if PetService then
            PetService.AddPet(player, reward.PetId, { Source = "BattlePass" })
        end
        Network.FireClient("ShowNotification", player,
            "🎁 Battle Pass reward: " .. (reward.Label or reward.PetId) .. "!", "Success")

    elseif reward.Type == "EvolutionMaterial" then
        local mats = data.EvolutionMaterials or {}
        mats[reward.MaterialId] = (mats[reward.MaterialId] or 0) + reward.Amount
        data.EvolutionMaterials = mats
        Network.FireClient("ShowNotification", player,
            "🎁 Battle Pass: +" .. reward.Amount .. " " .. reward.MaterialId .. "!", "Success")

    elseif reward.Type == "Badge" then
        -- Badge grants are metadata only; client UI shows the badge label
        Network.FireClient("ShowNotification", player,
            "🏆 Badge unlocked: " .. (reward.Label or reward.BadgeId) .. "!", "Success")
    end
end

-- Award all due free (and premium if owned) rewards for tiers up to currentTier.
local function claimPendingRewards(player: Player, data, fromTier: number, toTier: number)
    for level = fromTier + 1, toTier do
        local tierDef = BattlePassConfig.TierByLevel[level]
        if not tierDef then continue end

        -- Free reward
        if not data.BattlePassTiersClaimedF[level] then
            data.BattlePassTiersClaimedF[level] = true
            grantReward(player, data, tierDef.FreeReward)
        end

        -- Premium reward (only if player owns the pass)
        if data.BattlePassPremium and not data.BattlePassTiersClaimedP[level] then
            data.BattlePassTiersClaimedP[level] = true
            grantReward(player, data, tierDef.PremiumReward)
        end
    end
end

-- Build the pass-state snapshot sent to the client.
local function buildSnapshot(data)
    return {
        Season            = data.BattlePassSeason,
        Tier              = data.BattlePassTier,
        XP                = data.BattlePassXP,
        Premium           = data.BattlePassPremium,
        TiersClaimedFree  = data.BattlePassTiersClaimedF,
        TiersClaimedPrem  = data.BattlePassTiersClaimedP,
        XPPerTier         = BattlePassConfig.XPPerTier,
        MaxTier           = #BattlePassConfig.Tiers,
        SeasonName        = BattlePassConfig.SeasonName,
        SeasonEndTime     = BattlePassConfig.SeasonEndTime,
        PremiumProductId  = BattlePassConfig.PremiumProductId,
    }
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Award XP to a player and handle tier-ups.
function BattlePassService.AddXP(player: Player, amount: number, source: string)
    if not LaunchConfig.IsFeatureEnabled("BattlePass") then return end
    if amount <= 0 then return end

    local data = DataService.GetData(player)
    if not ensureData(data) then return end

    -- Season mismatch check (handled on PlayerAdded but guard here too)
    if data.BattlePassSeason ~= BattlePassConfig.CurrentSeason then return end

    local maxTier = #BattlePassConfig.Tiers

    -- Already maxed
    if data.BattlePassTier >= maxTier then return end

    local prevTier = data.BattlePassTier
    data.BattlePassXP = data.BattlePassXP + amount

    -- Tier-up loop
    local tieredUp = false
    while data.BattlePassXP >= BattlePassConfig.XPPerTier
        and data.BattlePassTier < maxTier do

        data.BattlePassXP   = data.BattlePassXP - BattlePassConfig.XPPerTier
        data.BattlePassTier = data.BattlePassTier + 1
        tieredUp = true

        -- Notify client of each individual tier-up
        Network.FireClient("BattlePassTierUp", player, {
            NewTier = data.BattlePassTier,
            Source  = source,
        })
    end

    -- Grant rewards for any newly reached tiers
    if tieredUp then
        claimPendingRewards(player, data, prevTier, data.BattlePassTier)
    end

    -- Fire incremental XP update every time
    Network.FireClient("BattlePassXPGained", player, {
        XP      = data.BattlePassXP,
        Tier    = data.BattlePassTier,
        Added   = amount,
        Source  = source,
    })

    if AnalyticsService then
        AnalyticsService.LogEvent(player, "battlepass_xp_added", {
            Source = source,
            Amount = amount,
            Tier   = data.BattlePassTier,
        })
    end
end

-- Called by ShopService when the premium pass is purchased.
function BattlePassService.OnPassPurchased(player: Player)
    if not LaunchConfig.IsFeatureEnabled("BattlePass") then return end

    local data = DataService.GetData(player)
    if not ensureData(data) then return end
    if data.BattlePassSeason ~= BattlePassConfig.CurrentSeason then return end

    -- Idempotent: don't double-grant
    if data.BattlePassPremium then return end

    data.BattlePassPremium = true

    -- Retroactively grant all premium rewards for tiers already reached
    for level = 1, data.BattlePassTier do
        local tierDef = BattlePassConfig.TierByLevel[level]
        if tierDef and not data.BattlePassTiersClaimedP[level] then
            data.BattlePassTiersClaimedP[level] = true
            grantReward(player, data, tierDef.PremiumReward)
        end
    end

    Network.FireClient("BattlePassData", player, buildSnapshot(data))
    Network.FireClient("ShowNotification", player,
        "🌟 Battle Pass Premium unlocked! Retroactive rewards granted!", "Success")

    if AnalyticsService then
        AnalyticsService.LogEvent(player, "battlepass_premium_purchased", {
            AtTier = data.BattlePassTier,
        })
    end
end

-- Returns the full pass state for a player (used by GetPlayerData remote).
function BattlePassService.GetPassData(player: Player)
    local data = DataService.GetData(player)
    if not ensureData(data) then return nil end
    return buildSnapshot(data)
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function BattlePassService.PlayerAdded(player: Player)
    if not LaunchConfig.IsFeatureEnabled("BattlePass") then return end

    local data = DataService.GetData(player)
    if not ensureData(data) then return end

    -- Reset for new season
    if data.BattlePassSeason ~= BattlePassConfig.CurrentSeason then
        resetForSeason(data)
        print(string.format("[BattlePassService] %s: new season reset → Season %d",
            player.Name, BattlePassConfig.CurrentSeason))
    end

    -- Send current state to client
    task.wait(1) -- brief delay so client GUI is ready
    if player and player.Parent then
        Network.FireClient("BattlePassData", player, buildSnapshot(data))
    end
end

function BattlePassService.PlayerRemoving(player: Player)
    -- No in-memory state to clean up; data is in DataService cache
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function BattlePassService.Init(dataService, currencyService, petService, analyticsService)
    DataService      = dataService
    CurrencyService  = currencyService
    PetService       = petService
    AnalyticsService = analyticsService

    if not LaunchConfig.IsFeatureEnabled("BattlePass") then
        print("[LaunchConfig] BattlePassService disabled — handlers skipped")
        return
    end

    -- Client requesting full pass state (e.g., on GUI open)
    Network.OnServerEvent("RequestBattlePassData", function(player: Player)
        local data = DataService.GetData(player)
        if not ensureData(data) then return end
        Network.FireClient("BattlePassData", player, buildSnapshot(data))
    end)

    -- Premium track purchase (triggered by PurchaseBattlePass → ShopService processReceipt)
    -- ShopService will call BattlePassService.OnPassPurchased after receipt verification.

    print("[BattlePassService] Initialized — Season " .. BattlePassConfig.CurrentSeason
        .. ": " .. BattlePassConfig.SeasonName)
end

-- Late-bind setter (called from init.server.luau)
function BattlePassService.SetAnalyticsService(as) AnalyticsService = as end
function BattlePassService.SetPetService(ps) PetService = ps end

return BattlePassService
