--[[
    QuestConfig.luau
    Daily and special quest definitions
]]

local QuestConfig = {}

QuestConfig.DailyQuests = {
    {
        Id = "collect_500_coins",
        Name = "Coin Collector",
        Description = "Collect 500 Coins",
        Type = "CollectCoins",
        Target = 500,
        RewardType = "Gems",
        RewardAmount = 5,
    },
    {
        Id = "hatch_5_eggs",
        Name = "Egg Hunter",
        Description = "Hatch 5 Eggs",
        Type = "HatchEggs",
        Target = 5,
        RewardType = "Gems",
        RewardAmount = 10,
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
        RewardType = "Gems",
        RewardAmount = 15,
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
}

-- Number of daily quests to assign per day
QuestConfig.DailyQuestCount = 3

-- Login streak rewards
QuestConfig.LoginStreakRewards = {
    { Day = 1,  RewardType = "Coins", RewardAmount = 100 },
    { Day = 2,  RewardType = "Coins", RewardAmount = 250 },
    { Day = 3,  RewardType = "Gems",  RewardAmount = 5 },
    { Day = 4,  RewardType = "Coins", RewardAmount = 500 },
    { Day = 5,  RewardType = "Gems",  RewardAmount = 15 },
    { Day = 6,  RewardType = "Coins", RewardAmount = 1000 },
    { Day = 7,  RewardType = "Gems",  RewardAmount = 50 },
}

QuestConfig.MaxLoginStreak = 7 -- Resets after 7 days

return QuestConfig
