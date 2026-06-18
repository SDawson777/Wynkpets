--[[
    SubscriptionConfig.luau
    VIP subscription tiers and their perks.

    Two tiers at launch:
        "basic"  — Recurring Roblox Subscription (VIP).
                   Identified by SubscriptionId (string).
                   Status checked via MarketplaceService:IsSubscribed.

        "vip"    — Monthly native Roblox Subscription (VIP+).
                   Identified by SubscriptionId (string, e.g. "EXP-12345").
                   Prompted via MarketplaceService:PromptSubscriptionPurchase.
                   Status checked via MarketplaceService:IsSubscribed.

    NOTE: VIP is NOT duplicated in GamepassConfig. Single source of truth here.
]]

local SubscriptionConfig = {}

-- ── Tiers ─────────────────────────────────────────────────────────────────────
SubscriptionConfig.Tiers = {
    basic = {
        Id             = "basic",
        Name           = "VIP",
        Description    = "Permanent perks for loyal fans",
        Type           = "Subscription",      -- native Roblox recurring subscription
        SubscriptionId = "EXP-8689637302206595569",
        Price          = 199,                 -- Robux (display only)
        DurationDays   = 30,                  -- renewed monthly; expiry stamped server-side
        Color          = Color3.fromRGB(255, 215, 0),
        Icon           = "⭐",
        IconImage = "rbxassetid://97408656051077",       -- upload via tools/upload_ui_icons.py (basic.png)
        Perks = {
            DailyGems    = 10,                -- free gems per day on login
            CoinBonus    = 0.10,              -- +10% coin earn rate (additive)
            LuckBonus    = 0.05,              -- +5% luck (additive)
            ExtraSlot    = 1,                 -- extra pet equip slot
            VIPBadge     = true,              -- chat badge / leaderboard icon
            ShopDiscount = 0.05,              -- 5% off gem packs
        },
    },
    vip = {
        Id             = "vip",
        Name           = "VIP+",
        Description    = "Monthly subscription — maximum perks",
        Type           = "Subscription",      -- native Roblox recurring subscription
        SubscriptionId = "EXP-5465364052693877225",
        Price          = 499,                 -- Robux per month (display only)
        Color          = Color3.fromRGB(180, 100, 255),
        Icon           = "💜",
        IconImage = "rbxassetid://111466557130930",       -- upload via tools/upload_ui_icons.py (vip.png)
        DurationDays   = 30,
        Perks = {
            DailyGems      = 25,
            CoinBonus      = 0.25,
            LuckBonus      = 0.15,
            ExtraSlot      = 2,
            VIPBadge       = true,
            ShopDiscount   = 0.10,            -- 10% off gem packs
            ExclusivePet   = true,            -- monthly subscriber exclusive pet
        },
    },
}

-- ── Lookup tables ─────────────────────────────────────────────────────────────

-- By tier string Id ("basic", "vip")
SubscriptionConfig.TierById = {}
-- Alias — consistent naming with other configs
SubscriptionConfig.SubscriptionById = {}

-- By numeric Roblox GamepassId (basic tier)
SubscriptionConfig.TierByGamepassId = {}

-- By Roblox Subscription string Id (vip tier)
SubscriptionConfig.TierBySubscriptionId = {}

for id, tier in pairs(SubscriptionConfig.Tiers) do
    SubscriptionConfig.TierById[id] = tier
    SubscriptionConfig.SubscriptionById[id] = tier
    if tier.Type == "Gamepass" and tier.GamepassId and tier.GamepassId > 0 then
        SubscriptionConfig.TierByGamepassId[tier.GamepassId] = tier
    end
    if tier.Type == "Subscription" and tier.SubscriptionId and tier.SubscriptionId ~= "" then
        SubscriptionConfig.TierBySubscriptionId[tier.SubscriptionId] = tier
    end
end

return SubscriptionConfig
