--[[
    PetLevelConfig.luau
    Defines pet leveling requirements and power scaling.
]]

local PetLevelConfig = {}

PetLevelConfig.MaxLevel = 25

-- XP required to reach each level (cumulative from current level)
PetLevelConfig.XPPerLevel = {
    [1] = 100,
    [2] = 200,
    [3] = 350,
    [4] = 550,
    [5] = 800,
    [6] = 1100,
    [7] = 1500,
    [8] = 2000,
    [9] = 2600,
    [10] = 3400,
    [11] = 4400,
    [12] = 5600,
    [13] = 7000,
    [14] = 8800,
    [15] = 11000,
    [16] = 14000,
    [17] = 17500,
    [18] = 22000,
    [19] = 28000,
    [20] = 35000,
    [21] = 45000,
    [22] = 58000,
    [23] = 75000,
    [24] = 100000,
    [25] = 0, -- Max level, no more XP needed
}

-- Power bonus multiplier per level: level * this value
-- e.g. Level 5 pet gets 5 * 0.10 = 50% power bonus
PetLevelConfig.PowerBonusPerLevel = 0.10

-- Get XP needed to level up from a given level
function PetLevelConfig.GetXPForLevel(level: number): number
    if level >= PetLevelConfig.MaxLevel then return 0 end
    return PetLevelConfig.XPPerLevel[level] or 999999
end

-- Get power multiplier for a given level
function PetLevelConfig.GetPowerMultiplier(level: number): number
    return 1 + ((level - 1) * PetLevelConfig.PowerBonusPerLevel)
end

return PetLevelConfig
