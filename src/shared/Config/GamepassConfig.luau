-- GamepassConfig.luau
-- All gamepass/developer product definitions

local GamepassConfig = {}

-- ─── Gamepasses ───────────────────────────────────────────────────────────────
-- Replace the assetId values with your published Roblox gamepass IDs before launch.
GamepassConfig.Gamepasses = {
    {
        id          = "double_coins",
        name        = "2× Coins",
        description = "Permanently doubles all coin earnings.",
        assetId     = 0,   -- TODO: replace with Roblox asset ID
        robux       = 199,
        effect      = { coinMult = 1.0 },  -- +1.0 additive coin multiplier
    },
    {
        id          = "double_mining",
        name        = "2× Mining Power",
        description = "Permanently doubles your mining damage.",
        assetId     = 0,
        robux       = 199,
        effect      = { mineMult = 1.0 },
    },
    {
        id          = "extra_pet_slots",
        name        = "Extra Pet Slots",
        description = "Unlock 3 additional pet equip slots (max 6 total).",
        assetId     = 0,
        robux       = 299,
        effect      = { extraPetSlots = 3 },
    },
    {
        id          = "auto_sell",
        name        = "Auto-Sell",
        description = "Automatically sell mined ores every few seconds.",
        assetId     = 0,
        robux       = 149,
        effect      = { autoSell = true },
    },
    {
        id          = "auto_hatch",
        name        = "Auto-Hatch",
        description = "Automatically hatch eggs from a selected egg type.",
        assetId     = 0,
        robux       = 149,
        effect      = { autoHatch = true },
    },
    {
        id          = "vip",
        name        = "VIP",
        description = "VIP badge, VIP-only zone access, and +10% to all gains.",
        assetId     = 0,
        robux       = 499,
        effect      = { coinMult = 0.1, mineMult = 0.1, vipZone = true },
    },
    {
        id          = "speed_boost",
        name        = "Speed Boost",
        description = "Permanently increases mining speed by 25%.",
        assetId     = 0,
        robux       = 99,
        effect      = { mineSpeedBoost = 0.25 },
    },
    {
        id          = "max_luck",
        name        = "Max Luck",
        description = "Permanently increases egg hatch luck by 2×.",
        assetId     = 0,
        robux       = 399,
        effect      = { luckMult = 1.0 },
    },
}

-- ─── Developer Products (consumables) ────────────────────────────────────────
GamepassConfig.DevProducts = {
    {
        id          = "luck_boost_1h",
        name        = "1-Hour Luck Boost",
        description = "2× luck on all egg hatches for 1 hour.",
        assetId     = 0,
        robux       = 25,
        duration    = 3600,
        effect      = { luckMult = 1.0 },
    },
    {
        id          = "coin_boost_1h",
        name        = "1-Hour Coin Boost",
        description = "2× coin gain for 1 hour.",
        assetId     = 0,
        robux       = 25,
        duration    = 3600,
        effect      = { coinMult = 1.0 },
    },
    {
        id          = "speed_boost_1h",
        name        = "1-Hour Speed Boost",
        description = "2× mining speed for 1 hour.",
        assetId     = 0,
        robux       = 25,
        duration    = 3600,
        effect      = { mineSpeedBoost = 1.0 },
    },
    {
        id          = "starter_pack",
        name        = "Starter Pack",
        description = "500 gems + 2× coins gamepass + rare pet. One-time only!",
        assetId     = 0,
        robux       = 299,
        oneTimeOnly = true,
        grant       = { gems = 500, gamepasses = { "double_coins" }, pets = { "gold_lion" } },
    },
}

-- Build lookups
local passById = {}
for _, gp in ipairs(GamepassConfig.Gamepasses) do
    passById[gp.id] = gp
end
GamepassConfig.PassById = passById

local productById = {}
for _, dp in ipairs(GamepassConfig.DevProducts) do
    productById[dp.id] = dp
end
GamepassConfig.ProductById = productById

return GamepassConfig
