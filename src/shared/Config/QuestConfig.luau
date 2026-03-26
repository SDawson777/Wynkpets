-- QuestConfig.luau
-- Quest and achievement definitions

local QuestConfig = {}

-- ─── Quest Types ─────────────────────────────────────────────────────────────
-- "daily"   – resets at midnight UTC
-- "weekly"  – resets every Monday UTC
-- "achievement" – one-time permanent unlock

QuestConfig.Quests = {
    -- ── Daily Quests ───────────────────────────────────────────────────────────
    {
        id          = "mine_100",
        name        = "Mine 100 Ores",
        description = "Mine 100 ores of any type today.",
        type        = "daily",
        goal        = { stat = "oresMinedToday", amount = 100 },
        reward      = { coins = 1000, gems = 0 },
    },
    {
        id          = "sell_5000_coins",
        name        = "Earn 5,000 Coins",
        description = "Sell ores to earn at least 5,000 coins today.",
        type        = "daily",
        goal        = { stat = "coinsEarnedToday", amount = 5000 },
        reward      = { coins = 2000, gems = 0 },
    },
    {
        id          = "hatch_3_eggs",
        name        = "Hatch 3 Eggs",
        description = "Hatch 3 eggs today.",
        type        = "daily",
        goal        = { stat = "eggsHatchedToday", amount = 3 },
        reward      = { coins = 0, gems = 5 },
    },

    -- ── Weekly Quests ──────────────────────────────────────────────────────────
    {
        id          = "mine_1000_weekly",
        name        = "Mine 1,000 Ores This Week",
        description = "Mine 1,000 ores this week.",
        type        = "weekly",
        goal        = { stat = "oresMinedWeekly", amount = 1000 },
        reward      = { coins = 25000, gems = 20 },
    },
    {
        id          = "hatch_25_weekly",
        name        = "Hatch 25 Eggs This Week",
        description = "Hatch 25 eggs this week.",
        type        = "weekly",
        goal        = { stat = "eggsHatchedWeekly", amount = 25 },
        reward      = { coins = 0, gems = 50 },
    },

    -- ── Achievements ──────────────────────────────────────────────────────────
    {
        id          = "first_hatch",
        name        = "First Hatch!",
        description = "Hatch your very first pet.",
        type        = "achievement",
        goal        = { stat = "totalEggsHatched", amount = 1 },
        reward      = { coins = 100, gems = 0 },
    },
    {
        id          = "collector_10",
        name        = "Collector I",
        description = "Own 10 different pets.",
        type        = "achievement",
        goal        = { stat = "uniquePetsOwned", amount = 10 },
        reward      = { coins = 5000, gems = 10 },
    },
    {
        id          = "collector_25",
        name        = "Collector II",
        description = "Own all 30 pets.",
        type        = "achievement",
        goal        = { stat = "uniquePetsOwned", amount = 30 },
        reward      = { coins = 50000, gems = 100 },
    },
    {
        id          = "first_rebirth",
        name        = "Born Again",
        description = "Complete your first rebirth.",
        type        = "achievement",
        goal        = { stat = "totalRebirths", amount = 1 },
        reward      = { coins = 0, gems = 50 },
    },
    {
        id          = "rebirth_5",
        name        = "Seasoned Miner",
        description = "Complete 5 rebirths.",
        type        = "achievement",
        goal        = { stat = "totalRebirths", amount = 5 },
        reward      = { coins = 0, gems = 250 },
    },
    {
        id          = "mined_1m",
        name        = "Million Miner",
        description = "Mine a total of 1,000,000 ores.",
        type        = "achievement",
        goal        = { stat = "totalOresMined", amount = 1000000 },
        reward      = { coins = 0, gems = 500 },
    },
    {
        id          = "secret_pet",
        name        = "Secret Discovery",
        description = "Hatch a Secret rarity pet.",
        type        = "achievement",
        goal        = { stat = "secretPetsHatched", amount = 1 },
        reward      = { coins = 1000000, gems = 1000 },
    },
}

-- Build lookup by id
local questById = {}
for _, q in ipairs(QuestConfig.Quests) do
    questById[q.id] = q
end
QuestConfig.ById = questById

return QuestConfig
