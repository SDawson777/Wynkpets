#!/usr/bin/env python3
"""
simulate_session_postpatch.py
─────────────────────────────
Monte-Carlo 10-minute new-player session simulation using the
post-patch configuration values.

Patch values in effect:
  forest_grove  CoinValue   = 25  (was 18)
  crystal_caves UnlockCost  = 7,000  (was 15,000)
  UpsellTrigger debounce    = 180 s per service

Derives earn model directly from CoinSpawnerService.luau and
CurrencyService.luau formulas.  Collection rate is swept across
three activity tiers (conservative / moderate / active) because
actual player movement is not observable server-side.

Calibration note
────────────────
The only hard anchor from the previous simulation is
"Zone 2 unlock at T≈1:39".  At Zone 1 CoinValue=5 (unchanged):

  earn_per_event = 5 × E[typeMulti] × E[lucky] × 2.10 (boost) × 1.00 (combo=1)
                 = 5 × 1.45 × 1.60 × 2.10
                 = 24.36 coins applied per event

  Needed to earn 250 more coins in 99 s (1.65 min):
    rate = 250 / (1.65 × 24.36) = 6.2 events/min

Moderate tier (8/min) ≈ player also manually running toward coins.
Active tier (12/min)  ≈ skilled mobile player sweeping the whole zone.
"""

import math
import random
import statistics
from typing import Optional

# ─── Zone config (post-patch) ────────────────────────────────────────────────
ZONES = [
    {"id": "starter_meadow", "order": 1, "unlock_cost":        0, "coin_value":  5},
    {"id": "forest_grove",   "order": 2, "unlock_cost":      750, "coin_value": 25},  # patched: was 18
    {"id": "crystal_caves",  "order": 3, "unlock_cost":    7_000, "coin_value": 65},  # patched: was 15_000
    {"id": "volcanic_ridge", "order": 4, "unlock_cost":  100_000, "coin_value": 200},
]

# ─── CoinSpawner: COIN_TYPES distribution ────────────────────────────────────
COIN_TYPES = [
    {"weight": 50, "multi": 0.5},   # Bronze
    {"weight": 25, "multi": 1.0},   # Silver
    {"weight": 15, "multi": 2.0},   # Gold
    {"weight":  7, "multi": 5.0},   # Diamond
    {"weight":  3, "multi": 10.0},  # Ruby
]
TOTAL_CT_WEIGHT = sum(c["weight"] for c in COIN_TYPES)
# Precompute E[typeMulti] = Σ(weight/total × multi)
E_TYPE_MULTI = sum(c["weight"] / TOTAL_CT_WEIGHT * c["multi"] for c in COIN_TYPES)  # = 1.45

# ─── CoinSpawner: lucky drop constants ───────────────────────────────────────
SUPER_LUCKY_CHANCE = 0.02   # 15×  (as in CoinSpawnerService)
LUCKY_CHANCE       = 0.08   # 5×
# E[lucky] = 0.02×15 + 0.08×5 + 0.90×1 = 1.60
E_LUCKY = SUPER_LUCKY_CHANCE * 15 + LUCKY_CHANCE * 5 + (1.0 - SUPER_LUCKY_CHANCE - LUCKY_CHANCE) * 1.0

# ─── CoinSpawner: combo system ───────────────────────────────────────────────
COMBO_BONUSES = [1.0, 1.2, 1.5, 2.0, 2.5, 3.0]
COMBO_WINDOW  = 2.0  # seconds; must collect within this window to keep combo

# ─── CurrencyService multiplier constants ────────────────────────────────────
REBIRTH_MULT            = 1.0       # new player, 0 rebirths
FIRST_SESSION_BOOST     = 2.0       # ActiveBoosts["Coins"] = 2× for 5 min
BOOST_DURATION          = 300.0     # 5 minutes
PET_POWER               = 5         # Fluffnose Power 5  →  1 + 5/100 = 1.05
PET_MULT                = 1 + PET_POWER / 100

# ─── Session constants ────────────────────────────────────────────────────────
STARTER_COINS  = 500
SIM_DURATION   = 600  # 10 minutes

# ─── Egg hatching model ───────────────────────────────────────────────────────
BASIC_EGG_COST  = 25   # starter_meadow basic_egg
FOREST_EGG_COST = 500  # forest_grove forest_egg
HATCH_INTERVAL  = 12.0 # seconds between hatch attempts (new player clicking)

# ─── Debounce constants (post-patch) ─────────────────────────────────────────
UPSELL_CD    = 180  # 3 min — CurrencyService / EggService / ZoneService
MKTPLACE_CD  = 300  # 5 min — MonetizationPromptService.TriggerPrompt gate
NUDGE_CD     = 120  # 2 min — NudgeService global gate

# ─── Monte Carlo ─────────────────────────────────────────────────────────────
N_RUNS = 5_000

# ─── Activity tiers (coin collection events/min) ─────────────────────────────
# Calibrated: "Zone 2 at T≈1:39" requires ~6.2 events/min in Zone 1.
ACTIVITY_TIERS = {
    "conservative (6/min)": 6.0,
    "moderate     (8/min)": 8.0,
    "active      (12/min)": 12.0,
}

# ─── Egg-spending behaviour ───────────────────────────────────────────────────
# "always"  — player hatches whenever affordable (worst case for Zone 3 savings)
# "saver"   — player throttles hatching once balance > ZONE_SAVE_FRACTION of
#             the next zone unlock cost  (models the NEXT GOAL badge effect)
ZONE_SAVE_FRACTION = 1.00   # don't hatch until balance EXCEEDS the full next-zone cost
                             # (models a player who saves completely before unlocking)


# ─── Helpers ─────────────────────────────────────────────────────────────────

def pick_coin_type(rng: random.Random) -> float:
    """Return a random coinType.ValueMulti, weighted by COIN_TYPES."""
    r = rng.random() * TOTAL_CT_WEIGHT
    c = 0.0
    for ct in COIN_TYPES:
        c += ct["weight"]
        if r <= c:
            return ct["multi"]
    return 1.0  # Silver fallback


def lucky_multiplier(rng: random.Random) -> float:
    r = rng.random()
    if r < SUPER_LUCKY_CHANCE:
        return 15.0
    if r < SUPER_LUCKY_CHANCE + LUCKY_CHANCE:
        return 5.0
    return 1.0


def earn_event(t: float, zone: dict, combo: dict, rng: random.Random) -> float:
    """
    Simulate one CoinSpawnerService.collectCoin event and return
    the effective coins added to the player's balance.
    Uses math.floor() exactly as Luau does.
    """
    # baseAmount = floor(CoinValue × typeMulti × lucky × combo × variation)
    type_multi  = pick_coin_type(rng)
    luck        = lucky_multiplier(rng)
    variation   = 0.75 + rng.random() * 0.5   # uniform [0.75, 1.25]

    # Combo: only maintained if last collection was within COMBO_WINDOW
    now = t
    if combo["last_t"] is None or (now - combo["last_t"]) > COMBO_WINDOW:
        combo["count"] = 1
    else:
        combo["count"] = min(combo["count"] + 1, len(COMBO_BONUSES))
    combo["last_t"] = now
    combo_mult = COMBO_BONUSES[combo["count"] - 1]

    base = math.floor(zone["coin_value"] * type_multi * luck * combo_mult * variation)

    # CurrencyService multiplier applied on CurrencyService.Add(player, "Coins", base, true)
    boost     = FIRST_SESSION_BOOST if t < BOOST_DURATION else 1.0
    total_mul = REBIRTH_MULT * boost * PET_MULT
    return base * total_mul


def egg_cost_for_zone(zone_id: str) -> int:
    if zone_id == "starter_meadow":
        return BASIC_EGG_COST
    elif zone_id == "forest_grove":
        return FOREST_EGG_COST
    return 2500  # enchanted_egg (forest_grove)


def run_session(events_per_min: float, saver_mode: bool = False,
                seed: Optional[int] = None) -> dict:
    """
    Simulate a single 10-minute new-player session.

    saver_mode=False  → player always hatches eggs when affordable (coin sink)
    saver_mode=True   → player throttles egg hatching once savings exceed
                        ZONE_SAVE_FRACTION × next_zone_cost  (zone-priority
                        behaviour that the NEXT GOAL badge incentivises)

    Returns a dict of metrics.
    """
    rng = random.Random(seed)

    t           = 0.0
    coins       = float(STARTER_COINS)
    zone_idx    = 0                   # currently in starter_meadow
    unlocked    = {"starter_meadow"}

    zone_unlock_at = {"starter_meadow": 0.0}

    # Debounce timestamps (−999 means "never fired")
    last_upsell_egg   = -9999.0
    last_upsell_zone  = -9999.0
    last_mktplace     = -9999.0
    last_nudge        = -9999.0

    prompts = {
        "egg_upsell":           0,  # Network.FireClient("UpsellTrigger") from EggService
        "zone_upsell":          0,  # Network.FireClient("UpsellTrigger") from ZoneService
        "total_upsell":         0,  # combined
        "mktplace_native":      0,  # MonetizationPromptService.TriggerPrompt
        "soft_shortage":        0,  # NudgeService.Trigger("near_cost") path
        "show_notification":    0,  # "Not enough …!" toast from EggService
    }

    combo = {"count": 0, "last_t": None}

    # Stagger events with ±20% jitter
    dt_coin  = 60.0 / events_per_min
    dt_hatch = HATCH_INTERVAL
    next_coin  = rng.uniform(0, dt_coin)
    next_hatch = rng.uniform(2, dt_hatch)

    snapshots = {}
    snap_times = {60, 120, 180, 300, 480, 540, 600}

    while t < SIM_DURATION:
        # Next event
        next_t = min(next_coin, next_hatch, SIM_DURATION)

        # Record balance at snapshot boundaries
        for st in list(snap_times):
            if t < st <= next_t:
                snapshots[st] = coins
                snap_times.discard(st)

        t = next_t

        if t >= SIM_DURATION:
            break

        zone = ZONES[zone_idx]

        # ── Coin collection event ────────────────────────────────────────
        if t == next_coin:
            earned = earn_event(t, zone, combo, rng)
            coins += earned

            # Auto-unlock next zone as soon as affordable (player would
            # notice the "UNLOCK" button lighting up and click it)
            nz_idx = zone_idx + 1
            if nz_idx < len(ZONES):
                nz = ZONES[nz_idx]
                if nz["id"] not in unlocked and coins >= nz["unlock_cost"]:
                    coins -= nz["unlock_cost"]
                    unlocked.add(nz["id"])
                    zone_idx = nz_idx
                    zone_unlock_at[nz["id"]] = t

            next_coin = t + dt_coin * (0.80 + rng.random() * 0.40)  # ±20% jitter

        # ── Egg hatch attempt ────────────────────────────────────────────
        elif t == next_hatch:
            cost = egg_cost_for_zone(ZONES[zone_idx]["id"])

            # In saver_mode, skip hatching if it would eat into zone-unlock savings
            nz_idx_check = zone_idx + 1
            skip_for_saving = False
            if saver_mode and nz_idx_check < len(ZONES):
                nz_check = ZONES[nz_idx_check]
                if nz_check["id"] not in unlocked:
                    save_target = nz_check["unlock_cost"] * ZONE_SAVE_FRACTION
                    # Only hatch if we're well above the savings target
                    if coins <= save_target:
                        skip_for_saving = True

            if skip_for_saving:
                # No hatch, just reschedule
                next_hatch = t + dt_hatch * (0.7 + rng.random() * 0.6)
            elif coins >= cost:
                # Can afford — hatch succeeds, no upsell
                coins -= cost
            else:
                # SHORTAGE PATH (mirrors EggService.HatchEgg)
                prompts["show_notification"] += 1  # always fires

                # MonetizationPromptService.TriggerPrompt (300s gate shared)
                if (t - last_mktplace) >= MKTPLACE_CD:
                    last_mktplace = t
                    prompts["mktplace_native"] += 1

                # EggService UpsellTrigger (180s debounce)
                if (t - last_upsell_egg) >= UPSELL_CD:
                    last_upsell_egg = t
                    prompts["egg_upsell"]   += 1
                    prompts["total_upsell"] += 1

            # Also check if zone unlock is within reach: try to unlock
            nz_idx = zone_idx + 1
            if nz_idx < len(ZONES):
                nz = ZONES[nz_idx]
                if nz["id"] not in unlocked:
                    if coins >= nz["unlock_cost"]:
                        coins -= nz["unlock_cost"]
                        unlocked.add(nz["id"])
                        zone_idx = nz_idx
                        zone_unlock_at[nz["id"]] = t
                    else:
                        # ZONE SHORTAGE PATH (mirrors ZoneService.UnlockZone)
                        # Only fires when player is "close" — model: within 50% of cost
                        shortfall = nz["unlock_cost"] - coins
                        if shortfall < nz["unlock_cost"] * 0.50:
                            if (t - last_mktplace) >= MKTPLACE_CD:
                                last_mktplace = t
                                prompts["mktplace_native"] += 1
                            if (t - last_upsell_zone) >= UPSELL_CD:
                                last_upsell_zone = t
                                prompts["zone_upsell"]   += 1
                                prompts["total_upsell"]  += 1

                            # NudgeService.Trigger("near_cost") from CurrencyService.Remove
                            # fires when 0 < remaining < amount (shortage path in Remove)
                            if (t - last_nudge) >= NUDGE_CD:
                                last_nudge = t
                                prompts["soft_shortage"] += 1

            next_hatch = t + dt_hatch * (0.7 + rng.random() * 0.6)  # ±30% jitter

    # Flush remaining snapshots
    for st in snap_times:
        snapshots[st] = coins

    return {
        "final_coins":      coins,
        "snapshots":        snapshots,
        "zone_unlock_at":   zone_unlock_at,
        "prompts":          prompts,
        "reached_zone3":    "crystal_caves" in unlocked,
    }


# ─── Reporting helpers ────────────────────────────────────────────────────────

def fmt_t(secs: float) -> str:
    m = int(secs) // 60
    s = int(secs) % 60
    return f"{m}:{s:02d}"


def pct(n: int, total: int) -> str:
    return f"{100 * n / total:.1f}%"


def report(label: str, events_per_min: float, saver_mode: bool = False):
    mode_tag = "saver=ON" if saver_mode else "saver=OFF"
    results = [run_session(events_per_min, saver_mode=saver_mode, seed=i)
               for i in range(N_RUNS)]

    z2 = sorted([r["zone_unlock_at"].get("forest_grove")
                 for r in results if "forest_grove" in r["zone_unlock_at"]])
    z3 = sorted([r["zone_unlock_at"].get("crystal_caves")
                 for r in results if "crystal_caves" in r["zone_unlock_at"]])

    print()
    print("═" * 70)
    print(f"  ACTIVITY: {label}  •  {mode_tag}  ({N_RUNS:,} runs)")
    print("═" * 70)

    # Zone unlock table
    def zone_stats(times, name, cost):
        if not times:
            print(f"  {name}: ⚠  never reached in 10 min")
            return
        n    = len(times)
        mean = statistics.mean(times)
        med  = statistics.median(times)
        sd   = statistics.stdev(times) if n > 1 else 0
        p10  = times[max(0, int(0.10 * n))]
        p90  = times[min(n - 1, int(0.90 * n))]
        print(f"  {name}  (costs {cost:,}):")
        print(f"    reached by {pct(n, N_RUNS)} of players within 10 min")
        print(f"    mean {fmt_t(mean)}  |  median {fmt_t(med)}  |  σ={sd:.0f}s")
        print(f"    P10 {fmt_t(p10)}  –  P90 {fmt_t(p90)}")

    print()
    print("── ZONE UNLOCK TIMING ──────────────────────────────────────────────")
    zone_stats(z2, "Zone 2 forest_grove", 750)
    print()
    zone_stats(z3, "Zone 3 crystal_caves", 7_000)

    # Balance over time
    print()
    print("── BALANCE OVER TIME (coins) ───────────────────────────────────────")
    header = f"  {'Time':>5}   {'Median':>8}   {'P25':>8}   {'P75':>8}"
    print(header)
    for st in [60, 120, 180, 300, 480, 540, 600]:
        vals = sorted([r["snapshots"].get(st, 0) for r in results])
        med  = statistics.median(vals)
        p25  = vals[N_RUNS // 4]
        p75  = vals[3 * N_RUNS // 4]
        print(f"  T={fmt_t(st)}   {med:>8,.0f}   {p25:>8,.0f}   {p75:>8,.0f}")

    # Prompt frequency
    print()
    print("── MONETIZATION PROMPT FREQUENCY (per 10-min session) ──────────────")
    prompt_keys = [
        ("egg_upsell",        "EggService UpsellTrigger (debounced 3 min)"),
        ("zone_upsell",       "ZoneService UpsellTrigger (debounced 3 min)"),
        ("total_upsell",      "Total UpsellTrigger fires"),
        ("mktplace_native",   "MonetizationPromptService.TriggerPrompt (gated 5 min)"),
        ("soft_shortage",     "NudgeService.Trigger near_cost (gated 2 min)"),
        ("show_notification", "ShowNotification toast (ungated, always fires)"),
    ]
    for key, desc in prompt_keys:
        vals  = sorted([r["prompts"][key] for r in results])
        mean  = statistics.mean(vals)
        med   = statistics.median(vals)
        p75   = vals[3 * N_RUNS // 4]
        mx    = vals[-1]
        print(f"  {mean:4.1f} mean  P75={p75:.0f}  max={mx:.0f}    {desc}")

    # Zone 3 window check
    print()
    print("── ZONE 3 TIMING WINDOW (target 8–12 min) ──────────────────────────")
    if z3:
        too_early = sum(1 for t in z3 if t < 480)
        in_window = sum(1 for t in z3 if 480 <= t <= 720)
        too_late  = sum(1 for t in z3 if t > 720)
        not_reached = N_RUNS - len(z3)
        print(f"  < 8 min   (too fast):  {pct(too_early, N_RUNS)}")
        print(f"  8–12 min  (TARGET ✓):  {pct(in_window, N_RUNS)}")
        print(f"  >12 min   (wall risk): {pct(too_late + not_reached, N_RUNS)}")
        mean_z3 = statistics.mean(z3)
        verdict = "✅ MEAN IN WINDOW" if 480 <= mean_z3 <= 720 else \
                  "⚡ MEAN BEFORE WINDOW (too fast)" if mean_z3 < 480 else \
                  "⚠️  MEAN AFTER WINDOW (wall risk)"
        print(f"  Mean Zone 3 T={fmt_t(mean_z3)}  →  {verdict}")
    else:
        print("  ⚠️  Zone 3 NOT reached in 10 min by any simulated player!")

    print()


def main():
    print()
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║  WYNKPETS — POST-PATCH SESSION SIMULATION                        ║")
    print("║  forest_grove CoinValue=25  •  crystal_caves cost=7,000          ║")
    print("║  UpsellTrigger debounce=180s  •  Mktplace prompt gate=300s       ║")
    print("╚══════════════════════════════════════════════════════════════════╝")

    print()
    print("Coin-earn formula (from CoinSpawnerService + CurrencyService):")
    print("  baseAmount = floor(zone.CoinValue × typeMulti × lucky × combo × variation)")
    print("  effective  = baseAmount × rebirthMult × boostMult × petMult")
    print()
    print("  E[typeMulti] = 1.45  (Bronze50/Silver25/Gold15/Diamond7/Ruby3)")
    print("  E[lucky]     = 1.60  (2% jackpot×15  +  8% lucky×5  +  90% ×1)")
    print("  combo        = 1.00  (at ≤12 events/min, always resets; COMBO_WINDOW=2s)")
    print("  boostMult    = 2.0   for T<300s  (FirstSessionService 5-min boost)")
    print("               = 1.0   for T≥300s")
    print("  petMult      = 1.05  (Fluffnose Power 5)")
    print()
    print(f"  E[effective per event, Zone 2 boosted]   ≈ 25 × 1.45 × 1.60 × 1.0 × 2.10 = {25*1.45*1.60*1.0*2.10:.1f}")
    print(f"  E[effective per event, Zone 2 unboosted] ≈ 25 × 1.45 × 1.60 × 1.0 × 1.05 = {25*1.45*1.60*1.0*1.05:.1f}")
    print()
    print("Calibration: T≈1:39 Zone 2 unlock  →  ~6.2 events/min in Zone 1")
    print("  (250 coins needed / (1.65 min × 24.4 coins/event) = 6.2 ev/min)")

    for label, rate in ACTIVITY_TIERS.items():
        # saver=OFF: player always hatches → pessimistic zone timing, realistic egg spend
        report(label, rate, saver_mode=False)
    print()
    print("── NOTE ON SAVER MODE ──────────────────────────────────────────────")
    print("  The runs above show 'always-hatching' behaviour.  Egg spending in")
    print("  Zone 2 (500 coins/hatch) completely prevents reaching Zone 3 in")
    print("  10 min.  The next block reruns with 'saver' mode: player throttles")
    print(f"  hatching once coins exceed {int(ZONE_SAVE_FRACTION*100)}% of the next zone unlock cost.")
    print("  This models the NEXT GOAL badge incentivising deliberate saving.")

    for label, rate in ACTIVITY_TIERS.items():
        # saver=ON: player prioritises zone unlock → optimistic zone timing
        report(label, rate, saver_mode=True)

    # Summary table across all tiers and modes
    print()
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║  CROSS-TIER SUMMARY  (Z3 target = 8–12 min)                     ║")
    print("╠══════════════════════════════════════════════════════════════════╣")
    print(f"  {'Activity':25}  {'Mode':10}  {'Z2 mean':>8}  {'Z3 mean':>8}  {'In window':>10}  {'Upsells (med)':>13}")
    print("  " + "─" * 78)

    for saver in [False, True]:
        mode_lbl = "saver=ON " if saver else "saver=OFF"
        for label, rate in ACTIVITY_TIERS.items():
            results = [run_session(rate, saver_mode=saver, seed=20_000 + i)
                       for i in range(N_RUNS)]
            z2 = [r["zone_unlock_at"].get("forest_grove") for r in results
                  if "forest_grove" in r["zone_unlock_at"]]
            z3 = [r["zone_unlock_at"].get("crystal_caves") for r in results
                  if "crystal_caves" in r["zone_unlock_at"]]
            in_w = sum(1 for t in z3 if 480 <= t <= 720)
            upsl = statistics.median([r["prompts"]["total_upsell"] for r in results])
            z2_s = fmt_t(statistics.mean(z2)) if z2 else "—"
            z3_s = fmt_t(statistics.mean(z3)) if z3 else "never"
            wnd  = pct(in_w, N_RUNS) if z3 else "0%"
            print(f"  {label:25}  {mode_lbl:10}  {z2_s:>8}  {z3_s:>8}  {wnd:>10}  {upsl:>13.0f}")
        print()

    print("╚══════════════════════════════════════════════════════════════════╝")
    print()
    print("Model assumptions:")
    print("  • zone.CoinMultiplier and zone.CoinSpawnRate are defined in ZoneConfig")
    print("    but NOT used in CoinSpawnerService server code — excluded.")
    print("  • No DoubleCoins gamepass, no wheel BoostExpiry, no VIP subscription.")
    print("  • DailyRotationService: neutral theme (no active bonus).")
    print("  • EventService: no active 2x coin event.")
    print("  • Zone unlock attempted after every coin event (player would notice")
    print("    the unlock button becoming active).")
    print("  • Zone upsell only fires when shortfall < 50% of unlock cost")
    print("    (player is close enough that the button is visible).")
    print()


if __name__ == "__main__":
    main()
