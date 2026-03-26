--[[
    AchievementConfig.luau
    Defines all achievements and their requirements.
]]

local AchievementConfig = {}

AchievementConfig.Achievements = {
    -- Hatching milestones
    {
        Id = "first_hatch",
        Name = "First Steps",
        Description = "Hatch your first egg",
        Type = "HatchEggs",
        Goal = 1,
        Reward = { Currency = "Gems", Amount = 5 },
    },
    {
        Id = "hatch_50",
        Name = "Egg Enthusiast",
        Description = "Hatch 50 eggs",
        Type = "HatchEggs",
        Goal = 50,
        Reward = { Currency = "Gems", Amount = 25 },
    },
    {
        Id = "hatch_250",
        Name = "Egg Expert",
        Description = "Hatch 250 eggs",
        Type = "HatchEggs",
        Goal = 250,
        Reward = { Currency = "Gems", Amount = 75 },
    },
    {
        Id = "hatch_1000",
        Name = "Egg Master",
        Description = "Hatch 1,000 eggs",
        Type = "HatchEggs",
        Goal = 1000,
        Reward = { Currency = "Gems", Amount = 200 },
    },
    {
        Id = "hatch_5000",
        Name = "Egg Legend",
        Description = "Hatch 5,000 eggs",
        Type = "HatchEggs",
        Goal = 5000,
        Reward = { Currency = "Gems", Amount = 500 },
    },

    -- Collection milestones
    {
        Id = "collect_5",
        Name = "Pet Collector",
        Description = "Discover 5 unique pets",
        Type = "UniquePets",
        Goal = 5,
        Reward = { Currency = "Gems", Amount = 10 },
    },
    {
        Id = "collect_20",
        Name = "Pet Researcher",
        Description = "Discover 20 unique pets",
        Type = "UniquePets",
        Goal = 20,
        Reward = { Currency = "Gems", Amount = 50 },
    },
    {
        Id = "collect_50",
        Name = "Pet Scholar",
        Description = "Discover 50 unique pets",
        Type = "UniquePets",
        Goal = 50,
        Reward = { Currency = "Gems", Amount = 150 },
    },
    {
        Id = "collect_all",
        Name = "Pet Completionist",
        Description = "Discover every pet in the game",
        Type = "UniquePets",
        Goal = 80,
        Reward = { Currency = "Gems", Amount = 1000 },
    },

    -- Rebirth milestones
    {
        Id = "rebirth_1",
        Name = "Reborn",
        Description = "Rebirth for the first time",
        Type = "Rebirths",
        Goal = 1,
        Reward = { Currency = "Gems", Amount = 50 },
    },
    {
        Id = "rebirth_5",
        Name = "Experienced",
        Description = "Reach Rebirth 5",
        Type = "Rebirths",
        Goal = 5,
        Reward = { Currency = "Gems", Amount = 150 },
    },
    {
        Id = "rebirth_10",
        Name = "Veteran",
        Description = "Reach Rebirth 10",
        Type = "Rebirths",
        Goal = 10,
        Reward = { Currency = "Gems", Amount = 500 },
    },
    {
        Id = "rebirth_25",
        Name = "Transcendent",
        Description = "Reach Rebirth 25",
        Type = "Rebirths",
        Goal = 25,
        Reward = { Currency = "Gems", Amount = 2000 },
    },

    -- Zone milestones
    {
        Id = "zone_3",
        Name = "Explorer",
        Description = "Unlock 3 zones",
        Type = "ZonesUnlocked",
        Goal = 3,
        Reward = { Currency = "Gems", Amount = 15 },
    },
    {
        Id = "zone_5",
        Name = "Adventurer",
        Description = "Unlock 5 zones",
        Type = "ZonesUnlocked",
        Goal = 5,
        Reward = { Currency = "Gems", Amount = 75 },
    },
    {
        Id = "zone_all",
        Name = "World Traveler",
        Description = "Unlock all 8 zones",
        Type = "ZonesUnlocked",
        Goal = 8,
        Reward = { Currency = "Gems", Amount = 500 },
    },

    -- Coin milestones
    {
        Id = "coins_10k",
        Name = "Getting Rich",
        Description = "Earn 10,000 total coins",
        Type = "TotalCoinsEarned",
        Goal = 10000,
        Reward = { Currency = "Gems", Amount = 10 },
    },
    {
        Id = "coins_1m",
        Name = "Millionaire",
        Description = "Earn 1,000,000 total coins",
        Type = "TotalCoinsEarned",
        Goal = 1000000,
        Reward = { Currency = "Gems", Amount = 100 },
    },
    {
        Id = "coins_1b",
        Name = "Billionaire",
        Description = "Earn 1,000,000,000 total coins",
        Type = "TotalCoinsEarned",
        Goal = 1000000000,
        Reward = { Currency = "Gems", Amount = 500 },
    },

    -- Rarity milestones
    {
        Id = "first_golden",
        Name = "Golden Touch",
        Description = "Hatch a Golden pet",
        Type = "GoldenPets",
        Goal = 1,
        Reward = { Currency = "Gems", Amount = 50 },
    },
    {
        Id = "first_rainbow",
        Name = "Over the Rainbow",
        Description = "Hatch a Rainbow pet",
        Type = "RainbowPets",
        Goal = 1,
        Reward = { Currency = "Gems", Amount = 200 },
    },
    {
        Id = "first_mythic",
        Name = "Mythic Discovery",
        Description = "Hatch a Mythic pet",
        Type = "MythicPets",
        Goal = 1,
        Reward = { Currency = "Gems", Amount = 100 },
    },
    {
        Id = "first_secret",
        Name = "Top Secret",
        Description = "Hatch a Secret pet",
        Type = "SecretPets",
        Goal = 1,
        Reward = { Currency = "Gems", Amount = 500 },
    },

    -- Trading milestones
    {
        Id = "first_trade",
        Name = "Fair Trade",
        Description = "Complete your first trade",
        Type = "TradesCompleted",
        Goal = 1,
        Reward = { Currency = "Gems", Amount = 10 },
    },
    {
        Id = "trade_25",
        Name = "Merchant",
        Description = "Complete 25 trades",
        Type = "TradesCompleted",
        Goal = 25,
        Reward = { Currency = "Gems", Amount = 75 },
    },

    -- Fuse milestones
    {
        Id = "first_fuse",
        Name = "Fusion Beginner",
        Description = "Fuse pets for the first time",
        Type = "PetsFused",
        Goal = 1,
        Reward = { Currency = "Gems", Amount = 10 },
    },
    {
        Id = "fuse_50",
        Name = "Fusion Master",
        Description = "Fuse 50 times",
        Type = "PetsFused",
        Goal = 50,
        Reward = { Currency = "Gems", Amount = 150 },
    },

    -- Pet power milestones
    {
        Id = "power_1000",
        Name = "Getting Stronger",
        Description = "Have a pet with 1,000+ power",
        Type = "BestPetPower",
        Goal = 1000,
        Reward = { Currency = "Gems", Amount = 25 },
    },
    {
        Id = "power_100k",
        Name = "Powerhouse",
        Description = "Have a pet with 100,000+ power",
        Type = "BestPetPower",
        Goal = 100000,
        Reward = { Currency = "Gems", Amount = 200 },
    },
    {
        Id = "power_1m",
        Name = "Ultimate Power",
        Description = "Have a pet with 1,000,000+ power",
        Type = "BestPetPower",
        Goal = 1000000,
        Reward = { Currency = "Gems", Amount = 1000 },
    },

    -- Login streak
    {
        Id = "login_7",
        Name = "Dedicated",
        Description = "Log in for 7 days",
        Type = "LoginDays",
        Goal = 7,
        Reward = { Currency = "Gems", Amount = 25 },
    },
    {
        Id = "login_30",
        Name = "Committed",
        Description = "Log in for 30 days",
        Type = "LoginDays",
        Goal = 30,
        Reward = { Currency = "Gems", Amount = 150 },
    },
}

-- Build lookup
AchievementConfig.AchievementById = {}
for _, achievement in ipairs(AchievementConfig.Achievements) do
    AchievementConfig.AchievementById[achievement.Id] = achievement
end

function AchievementConfig.GetAchievement(id: string)
    return AchievementConfig.AchievementById[id]
end

function AchievementConfig.GetAchievementsByType(achievementType: string)
    local results = {}
    for _, achievement in ipairs(AchievementConfig.Achievements) do
        if achievement.Type == achievementType then
            table.insert(results, achievement)
        end
    end
    return results
end

return AchievementConfig
