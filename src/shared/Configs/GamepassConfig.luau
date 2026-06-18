--[[
    GamepassConfig.luau
    Permanent one-time Gamepass purchases.

    Field conventions:
        GamepassId  — real Roblox Gamepass numeric ID (0 = not yet created)
        Id          — internal string key used by all services

    LAUNCH PASSES (6):
        DoubleCoins, DoubleLuck, DoubleHatchSpeed  — live IDs confirmed
        auto_hatch, triple_hatch, extra_equip      — pending IDs from Dashboard

    POSTPONED (not shipped at launch):
        auto_collect   — needs coin-collection system polish
        premium_daily  — superseded by SubscriptionConfig monthly VIP+

    NOTE: VIP is defined exclusively in SubscriptionConfig, not here.
]]

local GamepassConfig = {}

GamepassConfig.Gamepasses = {
    -- ─── Multiplier tier (live IDs) ──────────────────────────────────────────
    {
        Id          = "DoubleCoins",
        Name        = "2x Coins",
        GamepassId  = 1773683592,
        Price       = 199,
        Description = "Permanently earn 2× Coins from every source!",
        Icon = "rbxassetid://131905257032793",
        Multiplier  = 2.0,
        Category    = "Multiplier",
        SortOrder   = 1,
    },
    {
        Id          = "DoubleLuck",
        Name        = "2x Luck",
        GamepassId  = 1773893641,
        Price       = 249,
        Description = "Permanently double your luck for Rare, Epic, Legendary & Secret hatches!",
        Icon = "rbxassetid://111876966502602",
        Multiplier  = 2.0,
        Category    = "Multiplier",
        SortOrder   = 2,
    },
    {
        Id             = "DoubleHatchSpeed",
        Name           = "2x Hatch Speed",
        GamepassId     = 1776540888,
        Price          = 149,
        Description    = "Hatch eggs twice as fast — permanently!",
        Icon = "rbxassetid://128456345026392",
        SpeedMultiplier = 2.0,
        Category       = "Multiplier",
        SortOrder      = 3,
    },

    -- ─── Automation tier ─────────────────────────────────────────────────────
    {
        Id          = "auto_hatch",
        Name        = "Auto Hatch",
        GamepassId  = 1779424526,
        Price       = 399,
        Description = "Automatically hatch eggs when you have enough coins!",
        Icon = "rbxassetid://108283077310421",
        Category    = "Automation",
        SortOrder   = 4,
    },

    -- ─── Hatching tier ───────────────────────────────────────────────────────
    {
        Id         = "triple_hatch",
        Name       = "Triple Hatch",
        GamepassId = 1782856469,
        Price      = 499,
        Description = "Hatch 3 eggs at once for 3× the pets!",
        Icon = "rbxassetid://136471923154897",
        HatchCount = 3,
        Category   = "Hatching",
        SortOrder  = 5,
    },

    -- ─── Storage tier ────────────────────────────────────────────────────────
    {
        Id              = "extra_equip",
        Name            = "+5 Equip Slots",
        GamepassId      = 1781044517,
        Price           = 349,
        Description     = "Equip 5 more pets at once — permanently!",
        Icon = "rbxassetid://87855192926429",
        ExtraEquipSlots = 5,
        Category        = "Upgrade",
        SortOrder       = 6,
    },
}

-- ── Lookup tables ─────────────────────────────────────────────────────────────

-- By string Id  (e.g. "DoubleCoins")
GamepassConfig.GamepassById = {}
-- By numeric Roblox GamepassId
GamepassConfig.GamepassByGamepassId = {}

for _, gp in ipairs(GamepassConfig.Gamepasses) do
    GamepassConfig.GamepassById[gp.Id] = gp
    if gp.GamepassId and gp.GamepassId > 0 then
        GamepassConfig.GamepassByGamepassId[gp.GamepassId] = gp
    end
end

--- Fetch a pass definition by its internal string Id.
function GamepassConfig.GetGamepass(id: string)
    return GamepassConfig.GamepassById[id]
end

return GamepassConfig
