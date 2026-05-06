--[[
    EventConfig.luau
    Live-ops content configuration.
    Add a new event by inserting an entry in Events.
    EventShopService reads this at runtime — no code surgery needed.
    
    EventCoins are earned by completing EventTasks during an event window.
    EventShop items are purchased with EventCoins.
]]

local EventConfig = {}

-- ── Active event override ──────────────────────────────────────────────────────
-- nil = auto-select based on current os.time() and event StartTime/EndTime windows.
-- Set to a specific event Id string to force that event live regardless of dates.
-- Set to "" to disable all events.
EventConfig.ActiveEventId = nil

-- Runtime admin override (set via AdminService commands; nil = use auto-select).
-- Resets on server restart; does not persist.
EventConfig.AdminOverrideId = nil

-- Returns the effective active event ID:
--   1. AdminOverrideId if set
--   2. ActiveEventId force-override if non-nil
--   3. Auto-detect from current time vs event StartTime/EndTime windows
function EventConfig.GetActiveEventId(): string?
    if EventConfig.AdminOverrideId ~= nil then
        return EventConfig.AdminOverrideId
    end
    if EventConfig.ActiveEventId ~= nil then
        return EventConfig.ActiveEventId
    end
    -- Auto time-gate: return the first event whose window contains now
    local now = os.time()
    for id, event in pairs(EventConfig.Events) do
        if now >= event.StartTime and now < event.EndTime then
            return id
        end
    end
    return nil
end

-- ── Events ────────────────────────────────────────────────────────────────────
--
-- Timestamps are UTC Unix seconds (os.time() compatible).
-- Use the helper below to convert:
--   python3 -c "from datetime import datetime,timezone; print(int(datetime(YYYY,MM,DD,tzinfo=timezone.utc).timestamp()))"
--
-- EVENT CALENDAR 2026
-- ──────────────────────────────────────────────────────────────────────────────
--  Valentine's Day  Feb  7 – Feb 18  (1770422400 – 1771459200)
--  Spring Hatch     Mar 28 – Apr  7  (1774656000 – 1775606400)
--  Summer Splash    Jun 15 – Sep  1  (1781481600 – 1788220800)
--  Haunted Harvest  Oct  1 – Nov  2  (1790812800 – 1793577600)
--  Black Friday     Nov 25 – Dec  2  (1795564800 – 1796169600)
--  Winter Holiday   Dec 15 – Jan  6  (1797292800 – 1799193600)
-- ──────────────────────────────────────────────────────────────────────────────

EventConfig.Events = {

    -- ── Valentine's Day ───────────────────────────────────────────────────────
    valentines_2026 = {
        Id          = "valentines_2026",
        Name        = "💕 Love & Luck",
        Description = "Hatch adorable pets and earn Heart Tokens with your favourite pals!",
        ThemeColor  = Color3.fromRGB(255, 80, 130),
        Icon        = "💕",
        StartTime   = 1770422400,   -- Feb  7 2026 00:00 UTC
        EndTime     = 1771459200,   -- Feb 19 2026 00:00 UTC
        CurrencyName = "Heart Tokens",
        CurrencyIcon = "💖",

        Tasks = {
            { Id = "hatch_eggs",     Description = "Hatch any egg",               Reward = 5,  Type = "HatchEggs",    Target = 1    },
            { Id = "collect_coins",  Description = "Collect 2,000 Coins",         Reward = 4,  Type = "CollectCoins", Target = 2000 },
            { Id = "fuse_pets",      Description = "Fuse any two pets",           Reward = 20, Type = "FusePets",     Target = 1    },
            { Id = "wheel_spin",     Description = "Spin the Lucky Wheel",        Reward = 10, Type = "WheelSpins",   Target = 1    },
            { Id = "hatch_10_eggs",  Description = "Hatch 10 eggs",               Reward = 40, Type = "HatchEggs",    Target = 10   },
            { Id = "fuse_5_pets",    Description = "Fuse 5 pairs of pets",        Reward = 80, Type = "FusePets",     Target = 5    },
        },

        Shop = {
            {
                Id          = "val_luck_boost",
                Name        = "2× Luck Boost (30 min)",
                Description = "Doubles your hatch luck for 30 minutes",
                Cost        = 55,
                Type        = "Boost",
                BoostType   = "Luck",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "🍀",
            },
            {
                Id          = "val_coin_boost",
                Name        = "2× Coin Boost (30 min)",
                Description = "Doubles coin earnings for 30 minutes",
                Cost        = 45,
                Type        = "Boost",
                BoostType   = "Coins",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "💰",
            },
            {
                Id          = "val_gem_pack",
                Name        = "Gem Pack (50)",
                Description = "50 premium Gems",
                Cost        = 100,
                Type        = "Currency",
                Gems        = 50,
                MaxPurchases = 3,
                Icon        = "💎",
            },
            {
                Id          = "val_exclusive_pet",
                Name        = "💕 Lovebun (Exclusive)",
                Description = "Valentine's exclusive pastel bunny pet!",
                Cost        = 500,
                Type        = "Pet",
                PetId       = "lovebun",
                MaxPurchases = 1,
                Icon        = "🐰",
                Exclusive   = true,
            },
            {
                Id          = "val_hatch_speed",
                Name        = "2× Hatch Speed (1 hr)",
                Description = "Hatches eggs twice as fast for 1 hour",
                Cost        = 80,
                Type        = "Boost",
                BoostType   = "HatchSpeed",
                Duration    = 3600,
                MaxPurchases = 3,
                Icon        = "🥚",
            },
        },
    },

    -- ── Spring Hatch Festival ─────────────────────────────────────────────────
    spring_hatch_2026 = {
        Id          = "spring_hatch_2026",
        Name        = "🌸 Spring Hatch Festival",
        Description = "Easter eggs are everywhere — hatch rare pets and earn Flower Petals!",
        ThemeColor  = Color3.fromRGB(120, 210, 100),
        Icon        = "🌸",
        StartTime   = 1774656000,   -- Mar 28 2026 00:00 UTC
        EndTime     = 1775606400,   -- Apr  8 2026 00:00 UTC
        CurrencyName = "Flower Petals",
        CurrencyIcon = "🌼",

        Tasks = {
            { Id = "hatch_eggs",     Description = "Hatch any egg",               Reward = 6,  Type = "HatchEggs",    Target = 1    },
            { Id = "collect_coins",  Description = "Collect 1,500 Coins",         Reward = 3,  Type = "CollectCoins", Target = 1500 },
            { Id = "fuse_pets",      Description = "Fuse any two pets",           Reward = 18, Type = "FusePets",     Target = 1    },
            { Id = "wheel_spin",     Description = "Spin the Lucky Wheel",        Reward = 10, Type = "WheelSpins",   Target = 1    },
            { Id = "hatch_5_eggs",   Description = "Hatch 5 eggs in one session", Reward = 30, Type = "HatchEggs",    Target = 5    },
            { Id = "rebirth",        Description = "Perform a Rebirth",           Reward = 60, Type = "Rebirth",      Target = 1    },
        },

        Shop = {
            {
                Id          = "spring_luck_boost",
                Name        = "3× Luck Boost (20 min)",
                Description = "Triple your hatch luck for 20 minutes",
                Cost        = 70,
                Type        = "Boost",
                BoostType   = "Luck",
                Duration    = 1200,
                MaxPurchases = 5,
                Icon        = "🍀",
            },
            {
                Id          = "spring_coin_boost",
                Name        = "2× Coin Boost (30 min)",
                Description = "Doubles coin earnings for 30 minutes",
                Cost        = 45,
                Type        = "Boost",
                BoostType   = "Coins",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "💰",
            },
            {
                Id          = "spring_gem_pack",
                Name        = "Gem Pack (50)",
                Description = "50 premium Gems",
                Cost        = 100,
                Type        = "Currency",
                Gems        = 50,
                MaxPurchases = 3,
                Icon        = "💎",
            },
            {
                Id          = "spring_exclusive_pet",
                Name        = "🌸 Petalfox (Exclusive)",
                Description = "Spring Festival exclusive floral fox pet!",
                Cost        = 500,
                Type        = "Pet",
                PetId       = "petalfox",
                MaxPurchases = 1,
                Icon        = "🦊",
                Exclusive   = true,
            },
            {
                Id          = "spring_hatch_speed",
                Name        = "2× Hatch Speed (1 hr)",
                Description = "Hatches eggs twice as fast for 1 hour",
                Cost        = 80,
                Type        = "Boost",
                BoostType   = "HatchSpeed",
                Duration    = 3600,
                MaxPurchases = 3,
                Icon        = "🥚",
            },
        },
    },

    -- ── Summer Splash ─────────────────────────────────────────────────────────
    summer_splash_2026 = {
        Id          = "summer_splash_2026",
        Name        = "☀️ Summer Splash",
        Description = "Hatch eggs and earn Splash Coins all summer long!",
        ThemeColor  = Color3.fromRGB(0, 180, 255),
        Icon        = "☀️",
        StartTime   = 1781481600,   -- Jun 15 2026 00:00 UTC
        EndTime     = 1788220800,   -- Sep  1 2026 00:00 UTC
        CurrencyName = "Splash Coins",
        CurrencyIcon = "🌊",

        Tasks = {
            { Id = "hatch_eggs",     Description = "Hatch any egg",               Reward = 5,  Type = "HatchEggs",    Target = 1    },
            { Id = "collect_coins",  Description = "Collect 1,000 Coins",         Reward = 3,  Type = "CollectCoins", Target = 1000 },
            { Id = "fuse_pets",      Description = "Fuse any two pets",           Reward = 15, Type = "FusePets",     Target = 1    },
            { Id = "wheel_spin",     Description = "Spin the Lucky Wheel",        Reward = 10, Type = "WheelSpins",   Target = 1    },
            { Id = "hatch_25_eggs",  Description = "Hatch 25 eggs",               Reward = 80, Type = "HatchEggs",    Target = 25   },
            { Id = "fuse_10_pets",   Description = "Fuse 10 pairs of pets",       Reward = 100, Type = "FusePets",    Target = 10   },
        },

        Shop = {
            {
                Id          = "summer_coin_boost",
                Name        = "2× Coin Boost (30 min)",
                Description = "Doubles coin earnings for 30 minutes",
                Cost        = 50,
                Type        = "Boost",
                BoostType   = "Coins",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "💰",
            },
            {
                Id          = "summer_luck_boost",
                Name        = "2× Luck Boost (30 min)",
                Description = "Doubles luck for 30 minutes",
                Cost        = 60,
                Type        = "Boost",
                BoostType   = "Luck",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "🍀",
            },
            {
                Id          = "summer_gem_pack",
                Name        = "Gem Pack (50)",
                Description = "50 premium Gems",
                Cost        = 100,
                Type        = "Currency",
                Gems        = 50,
                MaxPurchases = 3,
                Icon        = "💎",
            },
            {
                Id          = "summer_exclusive_pet",
                Name        = "☀️ Sunpup (Exclusive)",
                Description = "Summer Splash exclusive solar puppy!",
                Cost        = 500,
                Type        = "Pet",
                PetId       = "sunpup",
                MaxPurchases = 1,
                Icon        = "🐶",
                Exclusive   = true,
            },
            {
                Id          = "summer_hatch_speed",
                Name        = "2× Hatch Speed (1 hr)",
                Description = "Hatches eggs twice as fast",
                Cost        = 80,
                Type        = "Boost",
                BoostType   = "HatchSpeed",
                Duration    = 3600,
                MaxPurchases = 3,
                Icon        = "🥚",
            },
        },
    },

    -- ── Haunted Harvest ───────────────────────────────────────────────────────
    haunted_harvest_2026 = {
        Id          = "haunted_harvest_2026",
        Name        = "🎃 Haunted Harvest",
        Description = "Collect Candy Corn and haunt the leaderboards all October!",
        ThemeColor  = Color3.fromRGB(255, 100, 0),
        Icon        = "🎃",
        StartTime   = 1790812800,   -- Oct  1 2026 00:00 UTC
        EndTime     = 1793577600,   -- Nov  2 2026 00:00 UTC
        CurrencyName = "Candy Corn",
        CurrencyIcon = "🍬",

        Tasks = {
            { Id = "hatch_eggs",     Description = "Hatch any egg",               Reward = 5,  Type = "HatchEggs",    Target = 1    },
            { Id = "collect_coins",  Description = "Collect 2,000 Coins",         Reward = 4,  Type = "CollectCoins", Target = 2000 },
            { Id = "fuse_pets",      Description = "Fuse any two pets",           Reward = 20, Type = "FusePets",     Target = 1    },
            { Id = "wheel_spin",     Description = "Spin the Lucky Wheel",        Reward = 10, Type = "WheelSpins",   Target = 1    },
            { Id = "hatch_13_eggs",  Description = "Hatch 13 spooky eggs",        Reward = 55, Type = "HatchEggs",    Target = 13   },
            { Id = "fuse_5_pets",    Description = "Fuse 5 ghostly pairs",        Reward = 75, Type = "FusePets",     Target = 5    },
            { Id = "rebirth",        Description = "Perform a Rebirth",           Reward = 80, Type = "Rebirth",      Target = 1    },
        },

        Shop = {
            {
                Id          = "halloween_coin_boost",
                Name        = "2× Coin Boost (30 min)",
                Description = "Doubles coin earnings for 30 minutes",
                Cost        = 50,
                Type        = "Boost",
                BoostType   = "Coins",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "💰",
            },
            {
                Id          = "halloween_luck_boost",
                Name        = "2× Luck Boost (30 min)",
                Description = "Doubles hatch luck for 30 minutes",
                Cost        = 60,
                Type        = "Boost",
                BoostType   = "Luck",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "🍀",
            },
            {
                Id          = "halloween_xp_boost",
                Name        = "2× XP Boost (30 min)",
                Description = "Doubles pet XP gain for 30 minutes",
                Cost        = 55,
                Type        = "Boost",
                BoostType   = "XP",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "⭐",
            },
            {
                Id          = "halloween_gem_pack",
                Name        = "Gem Pack (50)",
                Description = "50 premium Gems",
                Cost        = 100,
                Type        = "Currency",
                Gems        = 50,
                MaxPurchases = 3,
                Icon        = "💎",
            },
            {
                Id          = "halloween_exclusive_pet",
                Name        = "🎃 Phantomcat (Exclusive)",
                Description = "Halloween exclusive spectral cat — only available this October!",
                Cost        = 600,
                Type        = "Pet",
                PetId       = "phantomcat",
                MaxPurchases = 1,
                Icon        = "🐱",
                Exclusive   = true,
            },
            {
                Id          = "halloween_dusk_egg",
                Name        = "🌑 Dusk Egg Pull",
                Description = "One hatch from the Dusk Egg — shadow realm pets await inside!",
                Cost        = 250,
                Type        = "Egg",
                EggId       = "dusk_egg",
                MaxPurchases = 3,
                Icon        = "🥚",
            },
            {
                Id          = "halloween_hatch_speed",
                Name        = "2× Hatch Speed (1 hr)",
                Description = "Hatches eggs twice as fast",
                Cost        = 80,
                Type        = "Boost",
                BoostType   = "HatchSpeed",
                Duration    = 3600,
                MaxPurchases = 3,
                Icon        = "🥚",
            },
        },
    },

    -- ── Black Friday Bonanza ──────────────────────────────────────────────────
    -- Pure monetization event: heavy discounts, bonus gems, limited packs.
    -- No exclusive pets — this event is about value, not exclusives.
    black_friday_2026 = {
        Id          = "black_friday_2026",
        Name        = "🖤 Black Friday Bonanza",
        Description = "The biggest deals of the year — stock up on Gems and Boosts!",
        ThemeColor  = Color3.fromRGB(30, 30, 30),
        Icon        = "🖤",
        StartTime   = 1795564800,   -- Nov 25 2026 00:00 UTC
        EndTime     = 1796169600,   -- Dec  2 2026 00:00 UTC
        CurrencyName = "Black Chips",
        CurrencyIcon = "🖤",

        Tasks = {
            { Id = "hatch_eggs",     Description = "Hatch any egg",               Reward = 8,  Type = "HatchEggs",    Target = 1    },
            { Id = "collect_coins",  Description = "Collect 3,000 Coins",         Reward = 6,  Type = "CollectCoins", Target = 3000 },
            { Id = "fuse_pets",      Description = "Fuse any two pets",           Reward = 25, Type = "FusePets",     Target = 1    },
            { Id = "wheel_spin",     Description = "Spin the Lucky Wheel",        Reward = 15, Type = "WheelSpins",   Target = 1    },
        },

        Shop = {
            {
                Id          = "bf_mega_coin_boost",
                Name        = "3× Coin Boost (1 hr)",
                Description = "Triple coin earnings for 1 hour — best value!",
                Cost        = 60,
                Type        = "Boost",
                BoostType   = "Coins",
                Duration    = 3600,
                MaxPurchases = 5,
                Icon        = "💰",
            },
            {
                Id          = "bf_mega_luck_boost",
                Name        = "3× Luck Boost (1 hr)",
                Description = "Triple your hatch luck for 1 hour",
                Cost        = 70,
                Type        = "Boost",
                BoostType   = "Luck",
                Duration    = 3600,
                MaxPurchases = 5,
                Icon        = "🍀",
            },
            {
                Id          = "bf_gem_pack_small",
                Name        = "Gem Pack (100)",
                Description = "100 premium Gems — Black Friday value!",
                Cost        = 100,
                Type        = "Currency",
                Gems        = 100,
                MaxPurchases = 5,
                Icon        = "💎",
            },
            {
                Id          = "bf_gem_pack_large",
                Name        = "Mega Gem Pack (500)",
                Description = "500 premium Gems — Holiday stash!",
                Cost        = 400,
                Type        = "Currency",
                Gems        = 500,
                MaxPurchases = 2,
                Icon        = "💎",
            },
            {
                Id          = "bf_hatch_speed_mega",
                Name        = "3× Hatch Speed (1 hr)",
                Description = "Hatch eggs three times as fast for 1 hour",
                Cost        = 90,
                Type        = "Boost",
                BoostType   = "HatchSpeed",
                Duration    = 3600,
                MaxPurchases = 5,
                Icon        = "🥚",
            },
        },
    },

    -- ── Winter Holiday ────────────────────────────────────────────────────────
    winter_holiday_2026 = {
        Id          = "winter_holiday_2026",
        Name        = "❄️ Winter Wonderland",
        Description = "Hatch frosty pets and earn Snowflakes during the holiday season!",
        ThemeColor  = Color3.fromRGB(100, 180, 255),
        Icon        = "❄️",
        StartTime   = 1797292800,   -- Dec 15 2026 00:00 UTC
        EndTime     = 1799193600,   -- Jan  6 2027 00:00 UTC
        CurrencyName = "Snowflakes",
        CurrencyIcon = "❄️",

        Tasks = {
            { Id = "hatch_eggs",     Description = "Hatch any egg",               Reward = 5,  Type = "HatchEggs",    Target = 1    },
            { Id = "collect_coins",  Description = "Collect 1,000 Coins",         Reward = 3,  Type = "CollectCoins", Target = 1000 },
            { Id = "fuse_pets",      Description = "Fuse any two pets",           Reward = 15, Type = "FusePets",     Target = 1    },
            { Id = "wheel_spin",     Description = "Spin the Lucky Wheel",        Reward = 10, Type = "WheelSpins",   Target = 1    },
            { Id = "hatch_25_eggs",  Description = "Hatch 25 frosty eggs",        Reward = 80, Type = "HatchEggs",    Target = 25   },
            { Id = "fuse_10_pets",   Description = "Fuse 10 pairs of pets",       Reward = 100, Type = "FusePets",    Target = 10   },
            { Id = "rebirth",        Description = "Perform a Winter Rebirth",    Reward = 90, Type = "Rebirth",      Target = 1    },
        },

        Shop = {
            {
                Id          = "winter_coin_boost",
                Name        = "2× Coin Boost (30 min)",
                Description = "Doubles coin earnings for 30 minutes",
                Cost        = 50,
                Type        = "Boost",
                BoostType   = "Coins",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "💰",
            },
            {
                Id          = "winter_luck_boost",
                Name        = "2× Luck Boost (30 min)",
                Description = "Doubles hatch luck for 30 minutes",
                Cost        = 60,
                Type        = "Boost",
                BoostType   = "Luck",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "🍀",
            },
            {
                Id          = "winter_xp_boost",
                Name        = "2× XP Boost (30 min)",
                Description = "Doubles pet XP gain for 30 minutes",
                Cost        = 55,
                Type        = "Boost",
                BoostType   = "XP",
                Duration    = 1800,
                MaxPurchases = 5,
                Icon        = "⭐",
            },
            {
                Id          = "winter_gem_pack",
                Name        = "Gem Pack (50)",
                Description = "50 premium Gems",
                Cost        = 100,
                Type        = "Currency",
                Gems        = 50,
                MaxPurchases = 3,
                Icon        = "💎",
            },
            {
                Id          = "winter_exclusive_pet",
                Name        = "❄️ Frostpaw (Exclusive)",
                Description = "Winter Wonderland exclusive icy bear cub - only available this holiday!",
                Cost        = 600,
                Type        = "Pet",
                PetId       = "frostpaw",
                MaxPurchases = 1,
                Icon        = "🐻",
                Exclusive   = true,
            },
            {
                Id          = "winter_frost_egg",
                Name        = "🎄 Frost Egg",
                Description = "A special egg filled with rare winter pets!",
                Cost        = 275,
                Type        = "Egg",
                EggId       = "frost_egg",
                MaxPurchases = 3,
                Icon        = "🥚",
            },
            {
                Id          = "winter_hatch_speed",
                Name        = "2× Hatch Speed (1 hr)",
                Description = "Hatches eggs twice as fast",
                Cost        = 80,
                Type        = "Boost",
                BoostType   = "HatchSpeed",
                Duration    = 3600,
                MaxPurchases = 3,
                Icon        = "🥚",
            },
        },
    },
}

-- ── Lookups ───────────────────────────────────────────────────────────────────

EventConfig.EventById = {}
for id, event in pairs(EventConfig.Events) do
    EventConfig.EventById[id] = event
end

-- Build shop item lookup per event
EventConfig.ShopItemById = {} -- [eventId][itemId] = item
for eventId, event in pairs(EventConfig.Events) do
    EventConfig.ShopItemById[eventId] = {}
    for _, item in ipairs(event.Shop) do
        EventConfig.ShopItemById[eventId][item.Id] = item
    end
end

-- Task lookup per event
EventConfig.TaskById = {} -- [eventId][taskId] = task
for eventId, event in pairs(EventConfig.Events) do
    EventConfig.TaskById[eventId] = {}
    for _, task in ipairs(event.Tasks) do
        EventConfig.TaskById[eventId][task.Id] = task
    end
end

return EventConfig
