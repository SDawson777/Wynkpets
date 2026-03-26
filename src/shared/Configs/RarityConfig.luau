--[[
    RarityConfig.luau
    Defines rarity tiers, colors, and weights
]]

local RarityConfig = {}

RarityConfig.Tiers = {
    Common = {
        Order = 1,
        Color = Color3.fromRGB(180, 180, 180),
        TextColor = Color3.fromRGB(200, 200, 200),
        GlowColor = Color3.fromRGB(150, 150, 150),
        DisplayName = "Common",
        Abbreviation = "C",
    },
    Rare = {
        Order = 2,
        Color = Color3.fromRGB(50, 150, 255),
        TextColor = Color3.fromRGB(80, 170, 255),
        GlowColor = Color3.fromRGB(30, 120, 220),
        DisplayName = "Rare",
        Abbreviation = "R",
    },
    Epic = {
        Order = 3,
        Color = Color3.fromRGB(180, 50, 255),
        TextColor = Color3.fromRGB(200, 80, 255),
        GlowColor = Color3.fromRGB(150, 30, 220),
        DisplayName = "Epic",
        Abbreviation = "E",
    },
    Legendary = {
        Order = 4,
        Color = Color3.fromRGB(255, 200, 0),
        TextColor = Color3.fromRGB(255, 215, 50),
        GlowColor = Color3.fromRGB(220, 170, 0),
        DisplayName = "Legendary",
        Abbreviation = "L",
    },
    Mythic = {
        Order = 5,
        Color = Color3.fromRGB(255, 50, 100),
        TextColor = Color3.fromRGB(255, 80, 120),
        GlowColor = Color3.fromRGB(220, 30, 80),
        DisplayName = "Mythic",
        Abbreviation = "M",
    },
    Secret = {
        Order = 6,
        Color = Color3.fromRGB(255, 100, 255),
        TextColor = Color3.fromRGB(255, 130, 255),
        GlowColor = Color3.fromRGB(200, 50, 200),
        DisplayName = "??? Secret ???",
        Abbreviation = "S",
    },
}

-- Golden variant multiplier
RarityConfig.GoldenMultiplier = 2.5
RarityConfig.GoldenChance = 0.01 -- 1% chance

-- Rainbow variant multiplier
RarityConfig.RainbowMultiplier = 5.0
RarityConfig.RainbowChance = 0.001 -- 0.1% chance

return RarityConfig
