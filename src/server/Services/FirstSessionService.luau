--[[
    FirstSessionService.luau
    Fires exactly once per account — on the player's very first session.

    Three pillars:
        • Immediate reward  — 500 Coins + 50 Gems gifted on data-load
        • Early rare pet    — "fluffnose" (Rare, Power 5) gifted + auto-equipped
        • Early win feeling — "FirstSessionReward" fires a dedicated reveal GUI

    Gate: data.FirstSessionClaimed (bool, persisted in DataStore).
    The flag is written BEFORE rewards are delivered so a disconnect mid-grant
    never double-awards (idempotent pattern).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

-- Late-bound dependencies (set via Init)
local DataService
local CurrencyService
local PetService
local AnalyticsService  -- set via SetAnalyticsService

-- The starter rare pet every new player receives
local STARTER_PET_ID = "fluffnose"   -- Rare, Power 5, basic_egg zone 1

-- Immediate currency gift (chosen to be generous but below Day-7 streak value)
local STARTER_COINS = 500
local STARTER_GEMS  = 50

local FirstSessionService = {}

-- Returns true if this player has never completed first-session onboarding.
local function isFirstSession(data): boolean
    return data.FirstSessionClaimed ~= true
end

-- Main entry point — called from PlayerAdded AFTER data is loaded and
-- AFTER RewardService.ProcessLogin so LoginStreak is already set.
function FirstSessionService.PlayerAdded(player: Player)
    local data = DataService.GetData(player)
    if not data then return end
    if not isFirstSession(data) then return end

    -- ── Claim flag first (idempotent) ─────────────────────────────────────────
    data.FirstSessionClaimed = true

    -- ── 1. Immediate reward ───────────────────────────────────────────────────
    CurrencyService.Add(player, "Coins", STARTER_COINS, false)
    CurrencyService.Add(player, "Gems",  STARTER_GEMS,  false)

    -- ── 2. Early rare pet ─────────────────────────────────────────────────────
    local newPet = PetService.AddPet(player, STARTER_PET_ID, false, false)

    -- Auto-equip the gifted pet so the player sees it orbiting them immediately
    if newPet then
        PetService.EquipPet(player, newPet.UUID)
    end

    -- ── 3. Early acceleration boost (5 minutes of 2x Coins) ──────────────────
    -- Helps new players reach Zone 2 (costs 750 coins) within ~3 minutes so
    -- they experience the gameplay loop before the initial excitement fades.
    local EARLY_BOOST_SECONDS = 300  -- 5 minutes
    if not data.ActiveBoosts then data.ActiveBoosts = {} end
    data.ActiveBoosts["Coins"] = os.time() + EARLY_BOOST_SECONDS
    Network.FireClient("BoostActivated", player, "Coins", data.ActiveBoosts["Coins"])

    -- ── 4. Early win — fire the reveal GUI ───────────────────────────────────
    Network.FireClient("FirstSessionReward", player, {
        Coins    = STARTER_COINS,
        Gems     = STARTER_GEMS,
        PetId    = STARTER_PET_ID,
        PetUUID  = newPet and newPet.UUID or nil,
        CoinBoostSeconds = EARLY_BOOST_SECONDS,
    })

    -- ── Analytics ─────────────────────────────────────────────────────────────
    if AnalyticsService then
        AnalyticsService.LogEvent(player, "FirstSessionClaimed", {
            StarterPet = STARTER_PET_ID,
            Coins      = STARTER_COINS,
            Gems       = STARTER_GEMS,
        })
    end
end

-- ── Dependency injection ──────────────────────────────────────────────────────

function FirstSessionService.Init(dataService, currencyService, petService)
    DataService    = dataService
    CurrencyService = currencyService
    PetService     = petService
end

function FirstSessionService.SetAnalyticsService(as)
    AnalyticsService = as
end

return FirstSessionService
