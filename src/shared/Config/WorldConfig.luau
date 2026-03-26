-- WorldConfig.luau
-- World/zone unlock configuration

local WorldConfig = {}

WorldConfig.Worlds = {
    {
        id          = 1,
        name        = "Starter Mine",
        description = "A cozy mine where every adventure begins.",
        unlockCost  = 0,          -- free starting world
        currency    = "Coins",
        colorTheme  = Color3.fromRGB(180, 140, 80),
        rebirthRequired = 0,
    },
    {
        id          = 2,
        name        = "Crystal Caverns",
        description = "Glittering caves filled with precious gems.",
        unlockCost  = 1000000,    -- 1M coins
        currency    = "Coins",
        colorTheme  = Color3.fromRGB(80, 200, 220),
        rebirthRequired = 1,
    },
    {
        id          = 3,
        name        = "Starstone Abyss",
        description = "An ancient void teeming with cosmic ore.",
        unlockCost  = 500,        -- 500 gems
        currency    = "Gems",
        colorTheme  = Color3.fromRGB(100, 60, 200),
        rebirthRequired = 3,
    },
}

return WorldConfig
