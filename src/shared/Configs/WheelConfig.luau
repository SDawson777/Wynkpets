--[[
    WheelConfig.luau
    Shared Lucky Wheel definition used by server and client.
]]

local WheelConfig = {
    SegmentCount = 8,
    PointerAngle = 270,
    WheelVisualOffset = 0,
    FullSpins = 6,
    SpinDuration = 4.25,
    SettleDuration = 0.35,
    DailyFreeSpins = 1,
    PaidSpinProductKey = "wheel_spin",
    DebugMode = false,
    Rewards = {
        {
            Id = "coins_small",
            DisplayName = "Coins",
            Type = "Currency",
            Currency = "Coins",
            Amount = 500,
            Weight = 35,
            Icon = "rbxassetid://133500357416108",
            Color = Color3.fromRGB(255, 210, 80),
        },
        {
            Id = "coins_big",
            DisplayName = "Big Coins",
            Type = "Currency",
            Currency = "Coins",
            Amount = 2500,
            Weight = 18,
            Icon = "rbxassetid://137915809387106",
            Color = Color3.fromRGB(255, 175, 50),
        },
        {
            Id = "gems_small",
            DisplayName = "Gems",
            Type = "Currency",
            Currency = "Gems",
            Amount = 25,
            Weight = 15,
            Icon = "rbxassetid://133090017846961",
            Color = Color3.fromRGB(80, 190, 255),
        },
        {
            Id = "luck_boost",
            DisplayName = "Luck Boost",
            Type = "Boost",
            BoostType = "Luck",
            Duration = 900,
            Multiplier = 2,
            Weight = 10,
            Icon = "rbxassetid://132504663967009",
            Color = Color3.fromRGB(160, 110, 255),
        },
        {
            Id = "coin_boost",
            DisplayName = "Coin Boost",
            Type = "Boost",
            BoostType = "Coins",
            Duration = 900,
            Multiplier = 2,
            Weight = 10,
            Icon = "rbxassetid://103237235431605",
            Color = Color3.fromRGB(255, 220, 90),
        },
        {
            Id = "shards",
            DisplayName = "Evolution Shards",
            Type = "Currency",
            Currency = "EvolutionShards",
            Amount = 40,
            Weight = 7,
            Icon = "rbxassetid://91551982483025",
            Color = Color3.fromRGB(90, 255, 210),
        },
        {
            Id = "rare_pet",
            DisplayName = "Rare Pet",
            Type = "Pet",
            PetId = "fluffnose",
            Variant = "Base",
            Weight = 4,
            Icon = "rbxassetid://122170094904983",
            Color = Color3.fromRGB(110, 210, 255),
        },
        {
            Id = "jackpot",
            DisplayName = "Jackpot",
            Type = "Currency",
            Currency = "Gems",
            Amount = 150,
            Weight = 1,
            Icon = "rbxassetid://96948247671201",
            Color = Color3.fromRGB(255, 90, 200),
        },
    },
}

function WheelConfig.GetRewardByIndex(index: number)
    return WheelConfig.Rewards[index]
end

function WheelConfig.GetTotalWeight(): number
    local total = 0
    for _, reward in ipairs(WheelConfig.Rewards) do
        if (reward.Weight or 0) > 0 then
            total += reward.Weight
        end
    end
    return total
end

function WheelConfig.Validate(): (boolean, string?)
    if WheelConfig.SegmentCount ~= #WheelConfig.Rewards then
        return false, "SegmentCount must equal number of rewards"
    end

    if WheelConfig.SegmentCount <= 0 then
        return false, "SegmentCount must be positive"
    end

    for index, reward in ipairs(WheelConfig.Rewards) do
        if type(reward.Id) ~= "string" or reward.Id == "" then
            return false, string.format("Reward %d is missing a valid Id", index)
        end
        if (reward.Weight or 0) <= 0 and not reward.Disabled then
            return false, string.format("Reward %s has non-positive weight without Disabled=true", reward.Id)
        end
    end

    if WheelConfig.GetTotalWeight() <= 0 then
        return false, "Total wheel weight must be greater than zero"
    end

    return true
end

return WheelConfig
