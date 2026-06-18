--[[
    ReleaseScheduleConfig.luau
    Date-based feature unlock schedule for phased rollout.

    ReleaseScheduleService reads this on server startup and every 60 seconds,
    automatically enabling LaunchConfig.Features / Monetization flags once the
    configured UTC timestamp is reached. No manual file edits required to ship
    a new wave — just wait for the timestamp to pass and the server will handle it.

    Timeline (UTC midnight on each date):
        2026-04-08  Soft launch  (already live — configured manually in LaunchConfig)
        2026-04-15  Day  7: Lucky Wheel (syncs with Day-7 streak reward)
        2026-04-19  Day 11: Fusion (split from Rebirth to fill D7-D14 gap)
        2026-04-22  Day 14: Rebirth / Prestige (infinite formula-based)
        2026-04-29  Day 21: Trading + Battle Pass Season 1: Origins
        2026-05-06  Day 28: Evolution + Events + Subscriptions → full_launch
        2026-05-13  Day 35: Wizard + Bundles

    CHANGING DATES:
        To move a feature forward:  reduce its UnlockAt timestamp and redeploy.
        To force-enable immediately: set UnlockAt = 0 (always in the past).
        To hold a feature indefinitely: add its Feature/Monetization key to HeldFeatures.

    EMERGENCY HOLD (override):
        Add the key to HeldFeatures below and redeploy.
        ReleaseScheduleService will skip that entry even if its timestamp has passed.
        To release the hold: remove it from HeldFeatures and redeploy.
        This works for already-deployed servers too — the 60-second re-check loop
        will pick up the removal and enable the feature automatically.

    RISK MITIGATION:
        If you need to delay a feature after its date has already passed on live
        servers, add it to HeldFeatures AND set LaunchConfig.Features[key] = false,
        then redeploy. Both changes are required because LaunchConfig may have
        already been set true by a running server.
]]

local ReleaseScheduleConfig = {}

-- ── Timestamp constants (UTC 00:00:00) ────────────────────────────────────────
-- Base: 2026-04-08 soft launch | each day = 86,400 s
--
-- Retention-optimised cadence: each content drop is a distinct return reason.
-- Fusion is split from Rebirth to give two separate "new feature" moments
-- in the critical Day 10-14 retention window (when the core hatch loop
-- begins to lose novelty for engaged players).
local T_APR15 = 1744675200  -- 2026-04-15 00:00 UTC  (Day  7 — first streak cycle completes)
local T_APR19 = 1745020800  -- 2026-04-19 00:00 UTC  (Day 11 — Fusion fills novelty gap)
local T_APR22 = 1745280000  -- 2026-04-22 00:00 UTC  (Day 14 — Rebirth prestige layer)
local T_APR29 = 1745884800  -- 2026-04-29 00:00 UTC  (Day 21 — social + seasonal)
local T_MAY06 = 1746489600  -- 2026-05-06 00:00 UTC  (Day 28 — full launch)
local T_MAY13 = 1747094400  -- 2026-05-13 00:00 UTC  (Day 35 — advanced content)

-- ── Unlock schedule ────────────────────────────────────────────────────────────
-- Each entry must have EXACTLY ONE of: Feature, Monetization, or Phase.
-- ReleaseScheduleService processes them against LaunchConfig at runtime.
--
--   Feature      → sets LaunchConfig.Features[key] = true
--   Monetization → sets LaunchConfig.Monetization[key] = true
--   Phase        → upgrades LaunchConfig.Phase (never downgrades)
--
ReleaseScheduleConfig.Schedule = {

    -- ── Week 1: Lucky Wheel (Day 7) ─────────────────────────────────────────
    -- Coincides with first streak calendar completion (100 Gems reward).
    -- Player just hit the first "big payoff" and Wheel gives them something
    -- new to spend Gems on — reduces hoarding behaviour.
    {
        Feature  = "Wheel",
        UnlockAt = T_APR15,
        Comment  = "Day 7 — Lucky Wheel goes live; syncs with Day-7 streak reward",
    },

    -- ── Day 11: Fusion (split from Rebirth) ──────────────────────────────────
    -- The hatch-collect loop stales around Day 8-10 for the average player.
    -- Fusion adds a new sink (3 pets → Golden/Rainbow) that retroactively
    -- gives value to duplicate pets the player has been accumulating.
    {
        Feature  = "Fusion",
        UnlockAt = T_APR19,
        Comment  = "Day 11 — Pet Fusion; fills novelty gap after Wheel",
    },

    -- ── Day 14: Rebirth ──────────────────────────────────────────────────────
    -- Separated from Fusion so the player experiences two distinct return
    -- reasons instead of one content dump. Rebirth adds an infinite prestige
    -- layer just as Fusion mastery is settling in.
    {
        Feature  = "Rebirth",
        UnlockAt = T_APR22,
        Comment  = "Day 14 — Rebirth / Prestige (infinite via formula)",
    },

    -- ── Day 21: Social + Seasonal ─────────────────────────────────────────────
    -- By Week 3 the player has depth systems and is ready for social features.
    -- Trading creates economy-driven retention; Battle Pass adds 30-tier season goals.
    {
        Feature  = "Trading",
        UnlockAt = T_APR29,
        Comment  = "Day 21 — Pet Trading between players",
    },
    {
        Feature  = "BattlePass",
        UnlockAt = T_APR29,
        Comment  = "Day 21 — Battle Pass Season 1: Origins (ends May 13)",
    },

    -- ── Day 28: Full launch ───────────────────────────────────────────────────
    -- All remaining gameplay systems unlock together with the phase upgrade.
    -- Evolution + Events provide the endgame loop; Subscriptions monetise
    -- players who are proven retained at 4 weeks.
    {
        Feature  = "Evolution",
        UnlockAt = T_MAY06,
        Comment  = "Day 28 — Pet Evolution paths (free/speed/instant)",
    },
    {
        Feature  = "Events",
        UnlockAt = T_MAY06,
        Comment  = "Day 28 — Live Events engine + Event Shop",
    },
    {
        Feature  = "Subscription",
        UnlockAt = T_MAY06,
        Comment  = "Day 28 — VIP & VIP+ native Roblox Subscriptions",
    },
    {
        Phase    = "full_launch",
        UnlockAt = T_MAY06,
        Comment  = "Phase upgrade: soft_launch → full_launch",
    },

    -- ── Day 35: Advanced content ──────────────────────────────────────────────
    -- The Wizard is a social threat event that adds community moments.
    -- Bundles unlock advanced monetisation for whales who stayed 5+ weeks.
    {
        Feature      = "Wizard",
        UnlockAt     = T_MAY13,
        Comment      = "Day 35 — Evil Wizard roaming events",
    },
    {
        Monetization = "Bundles",
        UnlockAt     = T_MAY13,
        Comment      = "Day 35 — Mega / Ultra packs and VIP+ bundles",
    },
}

-- ── Emergency hold overrides ──────────────────────────────────────────────────
-- List any Feature or Monetization keys here to block them from auto-enabling,
-- even if their UnlockAt timestamp has passed.
--
-- Examples:
--   ReleaseScheduleConfig.HeldFeatures = { "Trading", "BattlePass" }
--   ReleaseScheduleConfig.HeldMonetization = { "Bundles" }
--
-- To release: remove the key, redeploy. The 60-second loop will pick it up.
ReleaseScheduleConfig.HeldFeatures     = {}  -- e.g. { "Trading" } to delay trading
ReleaseScheduleConfig.HeldMonetization = {}  -- e.g. { "Bundles" } to delay bundles

return ReleaseScheduleConfig
