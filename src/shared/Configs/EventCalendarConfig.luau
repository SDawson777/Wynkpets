--[[
    EventCalendarConfig.luau
    Master calendar for the WynkPets LiveOps event system.

    Architecture
    ────────────
    • A 4-week monthly rotation drives which Event Type runs each week.
    • Each week has a Prep phase (Mon–Thu UTC) and a Climax phase (Fri–Sun UTC).
    • All five event types are config-driven; adding a new instance is just a
      table insert — no service code changes required.
    • Materials (WynkShards, essences) are earned through gameplay only;
      Robux purchases via Path B/C go through EvolutionService.

    Studio responsibilities (NOT in this file)
    ──────────────────────────────────────────
    Event maps, portals, themed UI assets, limited-time egg models, VFX/SFX,
    badges, icons, thumbnails, evolved pet model IDs.
]]

local EventCalendarConfig = {}

-- ── Event Type identifiers ─────────────────────────────────────────────────────
EventCalendarConfig.EventTypes = {
    EVOLUTION_WEEKEND = "EvolutionWeekend",
    FEATURED_EGG      = "FeaturedEggWeek",
    SHINY_SURGE       = "ShinyAuraSurge",
    WORLD_PULSE       = "WorldPulse",
}

-- ── Calendar anchor ────────────────────────────────────────────────────────────
-- Monday April 13 2026 00:00 UTC (1776038400) is defined as the start of
-- rotation week 0 (= Week-of-month 1 → FeaturedEggWeek).
-- All week-of-month calculations in EventSchedulerService use this anchor so
-- the rotation stays perfectly aligned across months regardless of how many
-- days are in the month.
--
-- To shift the entire schedule forward or backward, change this one constant.
-- Formula used by EventSchedulerService:
--   weeksSinceAnchor = math.floor((os.time() - CalendarStartEpoch) / 604800)
--   weekOfMonth      = weeksSinceAnchor % 4 + 1   --> 1-4 rotation
EventCalendarConfig.CalendarStartEpoch = 1776038400  -- Mon Apr 13 2026 00:00 UTC

-- ── Monthly rotation (week-of-month 1–4 → event type) ─────────────────────────
-- Week 1 = new limited egg; Week 2 = evolution climax; Week 3 = shiny surge;
-- Week 4 = themed world event + leaderboard payout.
EventCalendarConfig.MonthlyRotation = {
    [1] = "FeaturedEggWeek",
    [2] = "EvolutionWeekend",
    [3] = "ShinyAuraSurge",
    [4] = "WorldPulse",
}

-- ── Phase schedule ─────────────────────────────────────────────────────────────
-- UTC os.date("%w"): 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
-- Prep     Mon–Thu  → players grind materials / milestones
-- Climax   Fri–Sun  → evolution window opens; bigger spend moments; leaderboard push
EventCalendarConfig.PrepWdays   = { [1]=true, [2]=true, [3]=true, [4]=true }
EventCalendarConfig.ClimaxWdays = { [5]=true, [6]=true, [0]=true }

-- ── Material definitions ───────────────────────────────────────────────────────
EventCalendarConfig.Materials = {
    {
        Id          = "WynkShards",
        Name        = "Wynk Shards",
        Icon        = "✨",
        Description = "Earned by hatching, rebirths, fusing, and quests. Primary evolution currency.",
    },
    {
        Id          = "MoonEssence",
        Name        = "Moon Essence",
        Icon        = "🌙",
        Description = "Rare material from Legendary hatches and rebirths. Required for Epic+ evolutions.",
    },
    {
        Id          = "StormCrystal",
        Name        = "Storm Crystal",
        Icon        = "⚡",
        Description = "Very rare material earned from rebirths. Required for Legendary-line evolutions.",
    },
}

-- Lookup by Id
EventCalendarConfig.MaterialById = {}
for _, mat in ipairs(EventCalendarConfig.Materials) do
    EventCalendarConfig.MaterialById[mat.Id] = mat
end

-- ── Shard / material earn rates ────────────────────────────────────────────────
-- EvolutionService.TryAwardShards reads these on every trigger call.
EventCalendarConfig.EarnRates = {
    -- WynkShards per trigger
    HatchCommon    = 3,
    HatchRare      = 8,
    HatchEpic      = 20,
    HatchLegendary = 50,
    HatchMythic    = 100,
    HatchSecret    = 200,
    Rebirth        = 200,
    FusePets       = 10,
    DailyLogin     = 15,
    QuestComplete  = 25,

    -- MoonEssence per trigger
    HatchLegendaryMoon = 1,
    HatchMythicMoon    = 3,
    HatchSecretMoon    = 5,
    RebirthMoon        = 5,

    -- StormCrystal per trigger
    RebirthStorm       = 1,
}

-- ── Evolution Windows (rotating) ──────────────────────────────────────────────
-- Rotated by: windowIndex = (weekOfYear % #EvolutionWindows) + 1
--
-- EligibleLine fields:
--   PetId        string   base pet ID
--   EvolvedId    string   evolved form ID (asset set up in Studio/PetConfig)
--   Rarity       string   for UI display and material gate
--   MinLevel     number   minimum pet level required
--   FreeCost     table    { materialId = amount } — Path A cost
--   SpeedCost    table    { materialId = amount } — extra shards bought via Path B
--   DirectRobux  number   Robux price for Path C (matched to a dev product)
--
EventCalendarConfig.EvolutionWindows = {
    -- Rotation 1: Forest Friends
    {
        Id          = "evo_forest",
        Name        = "🌿 Forest Evolution Weekend",
        Description = "Bunny, Fox, and Wolf can evolve this weekend!",
        EligibleLines = {
            {
                PetId       = "bunny",   EvolvedId   = "mega_bunny",
                Rarity      = "Common",  MinLevel    = 5,
                FreeCost    = { WynkShards = 80 },
                SpeedCost   = { WynkShards = 40 },
                DirectRobux = 79,
            },
            {
                PetId       = "fox",     EvolvedId   = "mega_fox",
                Rarity      = "Rare",    MinLevel    = 10,
                FreeCost    = { WynkShards = 200 },
                SpeedCost   = { WynkShards = 100 },
                DirectRobux = 149,
            },
            {
                PetId       = "wolf",    EvolvedId   = "mega_wolf",
                Rarity      = "Epic",    MinLevel    = 20,
                FreeCost    = { WynkShards = 500, MoonEssence = 2 },
                SpeedCost   = { WynkShards = 250, MoonEssence = 1 },
                DirectRobux = 399,
            },
        },
    },

    -- Rotation 2: Sky Spirits
    {
        Id          = "evo_sky",
        Name        = "☁️ Sky Evolution Weekend",
        Description = "Bird, Dragon, and Phoenix can evolve this weekend!",
        EligibleLines = {
            {
                PetId       = "bird",    EvolvedId   = "mega_bird",
                Rarity      = "Common",  MinLevel    = 5,
                FreeCost    = { WynkShards = 80 },
                SpeedCost   = { WynkShards = 40 },
                DirectRobux = 79,
            },
            {
                PetId       = "dragon",  EvolvedId   = "mega_dragon",
                Rarity      = "Rare",    MinLevel    = 10,
                FreeCost    = { WynkShards = 200 },
                SpeedCost   = { WynkShards = 100 },
                DirectRobux = 149,
            },
            {
                PetId       = "phoenix", EvolvedId   = "mega_phoenix",
                Rarity      = "Legendary", MinLevel  = 30,
                FreeCost    = { WynkShards = 1000, MoonEssence = 5, StormCrystal = 1 },
                SpeedCost   = { WynkShards = 500,  MoonEssence = 2 },
                DirectRobux = 899,
            },
        },
    },

    -- Rotation 3: Ocean Depths
    {
        Id          = "evo_ocean",
        Name        = "🌊 Ocean Evolution Weekend",
        Description = "Seal, Shark, and Leviathan can evolve this weekend!",
        EligibleLines = {
            {
                PetId       = "seal",       EvolvedId   = "mega_seal",
                Rarity      = "Common",     MinLevel    = 5,
                FreeCost    = { WynkShards = 80 },
                SpeedCost   = { WynkShards = 40 },
                DirectRobux = 79,
            },
            {
                PetId       = "shark",      EvolvedId   = "mega_shark",
                Rarity      = "Epic",       MinLevel    = 20,
                FreeCost    = { WynkShards = 500, MoonEssence = 2 },
                SpeedCost   = { WynkShards = 250, MoonEssence = 1 },
                DirectRobux = 399,
            },
            {
                PetId       = "leviathan",  EvolvedId   = "mega_leviathan",
                Rarity      = "Legendary",  MinLevel    = 30,
                FreeCost    = { WynkShards = 1000, MoonEssence = 5, StormCrystal = 1 },
                SpeedCost   = { WynkShards = 500,  MoonEssence = 2 },
                DirectRobux = 899,
            },
        },
    },

    -- Rotation 4: Ember Realm
    {
        Id          = "evo_ember",
        Name        = "🔥 Ember Evolution Weekend",
        Description = "Cat, Tiger, and Inferno Bear evolve this weekend!",
        EligibleLines = {
            {
                PetId       = "cat",    EvolvedId   = "mega_cat",
                Rarity      = "Common", MinLevel    = 5,
                FreeCost    = { WynkShards = 80 },
                SpeedCost   = { WynkShards = 40 },
                DirectRobux = 79,
            },
            {
                PetId       = "tiger",  EvolvedId   = "mega_tiger",
                Rarity      = "Epic",   MinLevel    = 20,
                FreeCost    = { WynkShards = 500, MoonEssence = 2 },
                SpeedCost   = { WynkShards = 250, MoonEssence = 1 },
                DirectRobux = 399,
            },
            {
                PetId       = "inferno_bear", EvolvedId = "mega_inferno_bear",
                Rarity      = "Legendary",    MinLevel  = 30,
                FreeCost    = { WynkShards = 1000, MoonEssence = 5, StormCrystal = 1 },
                SpeedCost   = { WynkShards = 500,  MoonEssence = 2 },
                DirectRobux = 899,
            },
        },
    },
}

-- ── Featured Egg Week definitions ──────────────────────────────────────────────
-- Rotated by the same weekIndex logic.
-- MilestoneRewards trigger when the player hatches the FeaturedEggId N times
-- during the active window.  Progress is stored in EventWindowHistory[windowId].HatchCount.
EventCalendarConfig.FeaturedEggWeeks = {
    {
        Id             = "egg_week_forest",
        Name           = "🌿 Forest Egg Week",
        FeaturedEggId  = "forest_egg",
        LuckBonus      = 0.25,   -- +25% luck on this egg
        MilestoneRewards = {
            { Hatches = 10,  Reward = { Type = "WynkShards", Amount = 50  } },
            { Hatches = 50,  Reward = { Type = "WynkShards", Amount = 200 } },
            { Hatches = 100, Reward = { Type = "Gems",        Amount = 25  } },
            { Hatches = 250, Reward = { Type = "Pet",         PetId  = "golden_bunny" } },
        },
    },
    {
        Id             = "egg_week_sky",
        Name           = "☁️ Sky Egg Week",
        FeaturedEggId  = "sky_egg",
        LuckBonus      = 0.25,
        MilestoneRewards = {
            { Hatches = 10,  Reward = { Type = "WynkShards", Amount = 50  } },
            { Hatches = 50,  Reward = { Type = "WynkShards", Amount = 200 } },
            { Hatches = 100, Reward = { Type = "Gems",        Amount = 25  } },
            { Hatches = 250, Reward = { Type = "Pet",         PetId  = "golden_dragon" } },
        },
    },
    {
        Id             = "egg_week_ocean",
        Name           = "🌊 Ocean Egg Week",
        FeaturedEggId  = "ocean_egg",
        LuckBonus      = 0.25,
        MilestoneRewards = {
            { Hatches = 10,  Reward = { Type = "WynkShards", Amount = 50  } },
            { Hatches = 50,  Reward = { Type = "WynkShards", Amount = 200 } },
            { Hatches = 100, Reward = { Type = "Gems",        Amount = 25  } },
            { Hatches = 250, Reward = { Type = "Pet",         PetId  = "golden_shark" } },
        },
    },
    {
        Id             = "egg_week_ember",
        Name           = "🔥 Ember Egg Week",
        FeaturedEggId  = "ember_egg",
        LuckBonus      = 0.25,
        MilestoneRewards = {
            { Hatches = 10,  Reward = { Type = "WynkShards", Amount = 50  } },
            { Hatches = 50,  Reward = { Type = "WynkShards", Amount = 200 } },
            { Hatches = 100, Reward = { Type = "Gems",        Amount = 25  } },
            { Hatches = 250, Reward = { Type = "Pet",         PetId  = "golden_cat" } },
        },
    },
}

-- ── Shiny / Aura Surge definitions ────────────────────────────────────────────
-- Runs 48 hours (Fri–Sun) during ShinyAuraSurge weeks.
EventCalendarConfig.ShinyAuraSurges = {
    {
        Id                = "surge_moonlit",
        Name              = "🌙 Moonlit Surge",
        GoldenMultiplier  = 3.0,
        RainbowMultiplier = 3.0,
        AuraMultiplier    = 5.0,
        DurationHours     = 48,
    },
    {
        Id                = "surge_starfall",
        Name              = "⭐ Starfall Surge",
        GoldenMultiplier  = 4.0,
        RainbowMultiplier = 2.0,
        AuraMultiplier    = 3.0,
        DurationHours     = 48,
    },
    {
        Id                = "surge_prismatic",
        Name              = "🌈 Prismatic Surge",
        GoldenMultiplier  = 2.0,
        RainbowMultiplier = 5.0,
        AuraMultiplier    = 4.0,
        DurationHours     = 48,
    },
}

-- ── World Pulse definitions ────────────────────────────────────────────────────
-- Each pulse has a 3-quest chain. Completing all 3 earns LimitedPetId.
-- QuestLine progress stored in EventWindowHistory[windowId].QuestsDone (0–3).
EventCalendarConfig.WorldPulses = {
    {
        Id          = "pulse_ember",
        Name        = "🔥 Ember Week",
        Theme       = "Fire",
        QuestLine   = {
            { Description = "Hatch any egg 5 times",         Reward = { WynkShards = 30 } },
            { Description = "Collect 5,000 coins",           Reward = { WynkShards = 20 } },
            { Description = "Earn a Legendary or higher pet", Reward = { Gems = 10        } },
        },
        LimitedPetId = "ember_wisp",
        ShopBundle   = {
            Name       = "Ember Bundle",
            Items      = { { Type = "Coins", Amount = 50000 }, { Type = "WynkShards", Amount = 100 } },
            RobuxPrice = 199,
        },
    },
    {
        Id          = "pulse_bloom",
        Name        = "🌸 Bloom Week",
        Theme       = "Nature",
        QuestLine   = {
            { Description = "Hatch any egg 5 times",   Reward = { WynkShards = 30 } },
            { Description = "Fuse 2 pets",             Reward = { WynkShards = 30 } },
            { Description = "Complete 3 daily quests", Reward = { Gems = 10        } },
        },
        LimitedPetId = "bloom_sprite",
        ShopBundle   = {
            Name       = "Bloom Bundle",
            Items      = { { Type = "Coins", Amount = 50000 }, { Type = "WynkShards", Amount = 100 } },
            RobuxPrice = 199,
        },
    },
    {
        Id          = "pulse_storm",
        Name        = "⚡ Storm Week",
        Theme       = "Electric",
        QuestLine   = {
            { Description = "Hatch any egg 5 times",        Reward = { WynkShards = 30 } },
            { Description = "Collect 10,000 coins",         Reward = { WynkShards = 30 } },
            { Description = "Rebirth (or reach level 15+)", Reward = { Gems = 15        } },
        },
        LimitedPetId = "storm_pup",
        ShopBundle   = {
            Name       = "Storm Bundle",
            Items      = { { Type = "Coins", Amount = 75000 }, { Type = "WynkShards", Amount = 150 } },
            RobuxPrice = 249,
        },
    },
    {
        Id          = "pulse_frost",
        Name        = "❄️ Frost Week",
        Theme       = "Ice",
        QuestLine   = {
            { Description = "Hatch any egg 5 times",    Reward = { WynkShards = 30 } },
            { Description = "Collect 8,000 coins",      Reward = { WynkShards = 30 } },
            { Description = "Equip 3 or more pets",     Reward = { Gems = 10        } },
        },
        LimitedPetId = "frost_cub",
        ShopBundle   = {
            Name       = "Frost Bundle",
            Items      = { { Type = "Coins", Amount = 50000 }, { Type = "WynkShards", Amount = 100 } },
            RobuxPrice = 199,
        },
    },
}

-- ── Pity system ────────────────────────────────────────────────────────────────
-- After MissedWindowBonusThreshold consecutive evolution windows are missed
-- (i.e. no evolution completed), apply a shard bonus multiplier.
-- Resets to 0 the moment a player completes any evolution.
EventCalendarConfig.PityConfig = {
    MissedWindowBonusThreshold = 2,
    MissedWindowShardBonus     = 1.25,  -- +25% shards while pity is active
}

-- ── Dev product IDs for paid evolution paths ───────────────────────────────────
-- Replace DevProductId = 0 with your real Roblox DevProduct IDs before shipping.
-- Path B = shard top-up packs; Path C = instant-evolve tokens per rarity.
EventCalendarConfig.EvolutionProducts = {
    -- Shard top-up packs (Path B speed-up)
    ShardPackSmall  = { DevProductId = 3566241535, Amount = 50,  Robux = 29  },
    ShardPackMedium = { DevProductId = 3566242422, Amount = 150, Robux = 79  },
    ShardPackLarge  = { DevProductId = 3566243126, Amount = 400, Robux = 199 },

    -- Instant-evolve tokens (Path C direct)
    InstantEvolveCommon    = { DevProductId = 3566235304, Robux = 79  },
    InstantEvolveRare      = { DevProductId = 3566238971, Robux = 149 },
    InstantEvolveEpic      = { DevProductId = 3566239844, Robux = 399 },
    InstantEvolveLegendary = { DevProductId = 3566236661, Robux = 899 },
}

-- ── Lookup helpers ─────────────────────────────────────────────────────────────

-- Returns the EvolutionWindow for a given 0-based week-of-year index.
function EventCalendarConfig.GetEvolutionWindow(weekIndex: number)
    local w = EventCalendarConfig.EvolutionWindows
    return w[(weekIndex % #w) + 1]
end

-- Returns the FeaturedEggWeek for a given 0-based week-of-year index.
function EventCalendarConfig.GetFeaturedEggWeek(weekIndex: number)
    local w = EventCalendarConfig.FeaturedEggWeeks
    return w[(weekIndex % #w) + 1]
end

-- Returns the ShinyAuraSurge for a given 0-based week-of-year index.
function EventCalendarConfig.GetShinyAuraSurge(weekIndex: number)
    local w = EventCalendarConfig.ShinyAuraSurges
    return w[(weekIndex % #w) + 1]
end

-- Returns the WorldPulse for a given 0-based week-of-year index.
function EventCalendarConfig.GetWorldPulse(weekIndex: number)
    local w = EventCalendarConfig.WorldPulses
    return w[(weekIndex % #w) + 1]
end

-- Returns the week-of-month (1–4) for the given UTC epoch timestamp,
-- derived from CalendarStartEpoch so the rotation is calendar-accurate.
-- Falls back to the day-based calculation if t is before the anchor.
function EventCalendarConfig.GetWeekOfMonthFromEpoch(t: number): number
    if t >= EventCalendarConfig.CalendarStartEpoch then
        local weeksSinceAnchor = math.floor((t - EventCalendarConfig.CalendarStartEpoch) / 604800)
        return weeksSinceAnchor % 4 + 1
    end
    -- Fallback: day-of-month based (used only in Studio / before go-live)
    local d = os.date("!*t", t) :: any
    return math.min(4, math.ceil(d.day / 7))
end

-- Returns the event type string for week-of-month (1–4), wrapping safely.
function EventCalendarConfig.GetEventTypeForWeek(weekOfMonth: number): string
    return EventCalendarConfig.MonthlyRotation[(weekOfMonth - 1) % 4 + 1]
end

return EventCalendarConfig
