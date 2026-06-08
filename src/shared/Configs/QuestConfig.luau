--[[
    QuestConfig.luau
    Daily and weekly quest definitions, login streak rewards.
    Add new quest types here — no changes to RewardService needed.
]]

local QuestConfig = {}

QuestConfig.DailyQuests = {
    {
        Id = "collect_500_coins",
        Name = "Coin Collector",
        Description = "Collect 500 Coins",
        Type = "CollectCoins",
        Target = 500,
        RewardType = "Coins",
        RewardAmount = 750,
    },
    {
        Id = "hatch_5_eggs",
        Name = "Egg Hunter",
        Description = "Hatch 5 Eggs",
        Type = "HatchEggs",
        Target = 5,
        RewardType = "Coins",
        RewardAmount = 2000,
    },
    {
        Id = "equip_3_pets",
        Name = "Pet Parade",
        Description = "Equip 3 different pets",
        Type = "EquipPets",
        Target = 3,
        RewardType = "Coins",
        RewardAmount = 1000,
    },
    {
        Id = "collect_5000_coins",
        Name = "Big Spender",
        Description = "Collect 5,000 Coins",
        Type = "CollectCoins",
        Target = 5000,
        RewardType = "Gems",
        RewardAmount = 20,
    },
    {
        Id = "hatch_rare",
        Name = "Lucky Hatcher",
        Description = "Hatch a Rare pet or better",
        Type = "HatchRarity",
        Target = 1,
        TargetRarity = "Rare",
        RewardType = "Coins",
        RewardAmount = 5000,
    },
    {
        Id = "visit_2_zones",
        Name = "Explorer",
        Description = "Visit 2 different zones",
        Type = "VisitZones",
        Target = 2,
        RewardType = "Coins",
        RewardAmount = 2500,
    },
    {
        Id = "fuse_pet",
        Name = "Fusion Master",
        Description = "Fuse any pet",
        Type = "FusePets",
        Target = 1,
        RewardType = "Coins",
        RewardAmount = 3000,
    },
}

-- Number of daily quests to assign per day
QuestConfig.DailyQuestCount = 3

-- Login streak rewards (escalating — big Day 7 hook for retention)
QuestConfig.LoginStreakRewards = {
    { Day = 1,  RewardType = "Coins", RewardAmount = 500 },   -- bumped from 100; players earn ~7c/s, 100 felt trivial
    { Day = 2,  RewardType = "Coins", RewardAmount = 500 },
    { Day = 3,  RewardType = "Gems",  RewardAmount = 10 },
    { Day = 4,  RewardType = "Coins", RewardAmount = 2500 },
    { Day = 5,  RewardType = "Gems",  RewardAmount = 25 },
    { Day = 6,  RewardType = "Coins", RewardAmount = 10000 },
    { Day = 7,  RewardType = "Gems",  RewardAmount = 100 },
}

QuestConfig.MaxLoginStreak = 7 -- Resets after 7 days

-- ── Reroll ────────────────────────────────────────────────────────────────────
QuestConfig.RerollCostGems    = 5    -- Gems to reroll one daily quest
QuestConfig.MaxDailyRerolls   = 2    -- Maximum rerolls per calendar day

-- ── Weekly Quests ─────────────────────────────────────────────────────────────
-- 3 weekly quests are assigned every Monday (server UTC).
-- Completing all 3 unlocks the bonus jackpot reward.
QuestConfig.WeeklyQuestCount = 3

QuestConfig.WeeklyQuests = {
    {
        Id          = "weekly_hatch_30",
        Name        = "Mass Hatcher",
        Description = "Hatch 30 eggs this week",
        Type        = "HatchEggs",
        Target      = 30,
        RewardType  = "Gems",
        RewardAmount = 50,
    },
    {
        Id          = "weekly_collect_50k",
        Name        = "Coin Mogul",
        Description = "Collect 50,000 Coins this week",
        Type        = "CollectCoins",
        Target      = 50000,
        RewardType  = "Gems",
        RewardAmount = 40,
    },
    {
        Id          = "weekly_fuse_5",
        Name        = "Fusion Expert",
        Description = "Fuse 5 pets this week",
        Type        = "FusePets",
        Target      = 5,
        RewardType  = "Gems",
        RewardAmount = 30,
    },
    {
        Id          = "weekly_hatch_legendary",
        Name        = "Legend Seeker",
        Description = "Hatch 3 Legendary or better pets",
        Type        = "HatchRarity",
        Target      = 3,
        TargetRarity = "Legendary",
        RewardType  = "Gems",
        RewardAmount = 60,
    },
    {
        Id          = "weekly_visit_zones",
        Name        = "World Traveller",
        Description = "Visit 5 different zones",
        Type        = "VisitZones",
        Target      = 5,
        RewardType  = "Gems",
        RewardAmount = 35,
    },
}

-- Bonus reward for completing ALL weekly quests
QuestConfig.WeeklyCompletionBonus = {
    RewardType   = "Gems",
    RewardAmount = 100,
}

-- Quest ID lookup (all quests combined)
QuestConfig.QuestById = {}
for _, q in ipairs(QuestConfig.DailyQuests) do
    QuestConfig.QuestById[q.Id] = q
end
for _, q in ipairs(QuestConfig.WeeklyQuests) do
    QuestConfig.QuestById[q.Id] = q
end

return QuestConfig
