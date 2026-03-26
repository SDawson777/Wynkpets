-- DataTemplate.luau
-- Default save-data structure for a new player.
-- NEVER modify existing keys without a migration path.

local DataTemplate = {}

function DataTemplate.new(): {}
    return {
        -- ─── Currency ───────────────────────────────────────────────────────
        Coins = 0,
        Gems  = 0,

        -- ─── Ores in backpack (key = ore name, value = count) ────────────────
        Ores = {},

        -- ─── Pets ─────────────────────────────────────────────────────────────
        -- Each pet instance: { uid, petId, rarity }
        -- uid is a unique string so duplicate pets can coexist.
        Pets         = {},
        EquippedPets = {},   -- array of uids currently equipped (max 6)

        -- ─── Progression ──────────────────────────────────────────────────────
        CurrentWorld    = 1,
        UnlockedWorlds  = { 1 },
        CurrentTool     = "wooden_pickaxe",
        OwnedTools      = { "wooden_pickaxe" },
        Rebirths        = 0,
        RebirthBonus    = 0,   -- cumulative additive multiplier from rebirths

        -- ─── Gamepasses & Purchases ────────────────────────────────────────────
        OwnedGamepasses = {},  -- array of gamepass ids
        StarterPackClaimed = false,

        -- ─── Active Timed Boosts ───────────────────────────────────────────────
        -- { boostType, multiplier, expiresAt (Unix timestamp) }
        ActiveBoosts = {},

        -- ─── Daily Reward ─────────────────────────────────────────────────────
        LastDailyClaimDate = "",  -- "YYYY-MM-DD"
        DailyStreak        = 0,

        -- ─── Quests ───────────────────────────────────────────────────────────
        -- Daily/weekly quest progress: { questId → progress }
        QuestProgress    = {},
        -- Achievement completion: { questId → true }
        AchievementsCompleted = {},
        -- Date strings for quest resets
        LastDailyQuestReset  = "",
        LastWeeklyQuestReset = "",

        -- ─── Lifetime Stats ────────────────────────────────────────────────────
        Stats = {
            totalOresMined      = 0,
            totalCoinsEarned    = 0,
            totalEggsHatched    = 0,
            uniquePetsOwned     = 0,   -- recalculated server-side
            totalRebirths       = 0,
            secretPetsHatched   = 0,
            -- Daily / weekly rolling counters (reset by QuestService)
            oresMinedToday      = 0,
            coinsEarnedToday    = 0,
            eggsHatchedToday    = 0,
            oresMinedWeekly     = 0,
            eggsHatchedWeekly   = 0,
        },

        -- ─── Trading ──────────────────────────────────────────────────────────
        TradeHistory = {},   -- last 20 trades (rolling)

        -- ─── Meta ─────────────────────────────────────────────────────────────
        Version       = 1,   -- data schema version; increment on breaking changes
        JoinedAt      = 0,   -- Unix timestamp of first join (set once)
        LastSavedAt   = 0,
    }
end

return DataTemplate
