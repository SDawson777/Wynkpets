#!/usr/bin/env python3
"""
validate_balance.py
Core loop balance validator for WynkPets.

Simulates player progression across all 8 zones using real config data
and reports on progression speed, boredom cliffs, monetization gates,
and rarity rates. Run before shipping to QA or placing in front of CTO.

Usage:
    python tools/validate_balance.py [--verbose]
"""

import sys
import math

# ─────────────────────────────────────────────────────────────────────────────
# CONFIG DATA (mirrored from Luau config files)
# Update these if the corresponding .luau configs change.
# ─────────────────────────────────────────────────────────────────────────────

ZONES = [
    {"id": "starter_meadow",   "order": 1, "unlock_cost": 0,          "coin_value": 5,    "coin_spawn_rate": 1.0,  "coin_multiplier": 1.0},
    {"id": "forest_grove",     "order": 2, "unlock_cost": 750,        "coin_value": 18,   "coin_spawn_rate": 1.5,  "coin_multiplier": 3.0},
    {"id": "crystal_caves",    "order": 3, "unlock_cost": 15_000,     "coin_value": 65,   "coin_spawn_rate": 2.0,  "coin_multiplier": 10.0},
    {"id": "volcanic_ridge",   "order": 4, "unlock_cost": 100_000,    "coin_value": 200,  "coin_spawn_rate": 2.5,  "coin_multiplier": 25.0},
    {"id": "frozen_tundra",    "order": 5, "unlock_cost": 500_000,    "coin_value": 600,  "coin_spawn_rate": 3.0,  "coin_multiplier": 60.0},
    {"id": "celestial_garden", "order": 6, "unlock_cost": 2_500_000,  "coin_value": 2000, "coin_spawn_rate": 3.5,  "coin_multiplier": 150.0},
    {"id": "shadow_depths",    "order": 7, "unlock_cost": 15_000_000, "coin_value": 8000, "coin_spawn_rate": 4.0,  "coin_multiplier": 400.0},
    {"id": "cosmic_realm",     "order": 8, "unlock_cost": 100_000_000,"coin_value":40000, "coin_spawn_rate": 5.0,  "coin_multiplier": 1200.0},
]

EGGS = [
    # zone_id, egg_id, cost, hatchtime, pets[(weight, rarity)]
    {"zone": "starter_meadow",   "id": "basic_egg",      "cost": 25,        "hatch_time": 1.5,
     "pets": [(40,"Common"),(30,"Common"),(20,"Rare"),(8,"Epic"),(2,"Legendary")]},
    {"zone": "starter_meadow",   "id": "spotted_egg",    "cost": 120,       "hatch_time": 2.0,
     "pets": [(35,"Common"),(25,"Common"),(20,"Rare"),(12,"Epic"),(6,"Legendary"),(2,"Mythic")]},
    {"zone": "forest_grove",     "id": "forest_egg",     "cost": 500,       "hatch_time": 2.5,
     "pets": [(35,"Common"),(30,"Common"),(20,"Rare"),(10,"Epic"),(5,"Legendary")]},
    {"zone": "forest_grove",     "id": "enchanted_egg",  "cost": 2_500,     "hatch_time": 3.0,
     "pets": [(30,"Common"),(22,"Common"),(20,"Rare"),(15,"Epic"),(10,"Legendary"),(3,"Mythic")]},
    {"zone": "crystal_caves",    "id": "crystal_egg",    "cost": 10_000,    "hatch_time": 3.5,
     "pets": [(30,"Common"),(25,"Rare"),(20,"Rare"),(15,"Epic"),(8,"Legendary"),(2,"Mythic")]},
    {"zone": "crystal_caves",    "id": "arcane_egg",     "cost": 45_000,    "hatch_time": 4.0,
     "pets": [(25,"Rare"),(22,"Rare"),(20,"Epic"),(18,"Epic"),(12,"Legendary"),(3,"Mythic")]},
    {"zone": "volcanic_ridge",   "id": "magma_egg",      "cost": 150_000,   "hatch_time": 4.5,
     "pets": [(30,"Rare"),(25,"Epic"),(20,"Epic"),(15,"Legendary"),(8,"Mythic"),(2,"Secret")]},
    {"zone": "volcanic_ridge",   "id": "inferno_egg",    "cost": 500_000,   "hatch_time": 5.0,
     "pets": [(25,"Epic"),(22,"Epic"),(20,"Legendary"),(18,"Legendary"),(10,"Mythic"),(5,"Secret")]},
    {"zone": "frozen_tundra",    "id": "frost_egg",      "cost": 1_000_000, "hatch_time": 5.5,
     "pets": [(30,"Epic"),(25,"Legendary"),(20,"Legendary"),(15,"Mythic"),(8,"Mythic"),(2,"Secret")]},
    {"zone": "frozen_tundra",    "id": "blizzard_egg",   "cost": 4_000_000, "hatch_time": 6.0,
     "pets": [(25,"Legendary"),(22,"Legendary"),(20,"Mythic"),(18,"Mythic"),(10,"Secret"),(5,"Secret")]},
    {"zone": "celestial_garden", "id": "celestial_egg",  "cost": 10_000_000,"hatch_time": 6.5,
     "pets": [(30,"Legendary"),(25,"Mythic"),(20,"Mythic"),(15,"Secret"),(10,"Secret")]},
    {"zone": "celestial_garden", "id": "divine_egg",     "cost": 30_000_000,"hatch_time": 7.0,
     "pets": [(30,"Mythic"),(25,"Mythic"),(25,"Secret"),(20,"Secret")]},
    {"zone": "shadow_depths",    "id": "shadow_egg",     "cost": 75_000_000,"hatch_time": 7.5,
     "pets": [(40,"Mythic"),(35,"Secret"),(25,"Secret")]},
    {"zone": "shadow_depths",    "id": "void_egg",       "cost": 200_000_000,"hatch_time": 8.0,
     "pets": [(50,"Secret"),(50,"Secret")]},
    {"zone": "cosmic_realm",     "id": "cosmic_egg",     "cost": 500_000_000,"hatch_time": 8.5,
     "pets": [(50,"Secret"),(50,"Secret")]},
    {"zone": "cosmic_realm",     "id": "omniversal_egg", "cost": 2_000_000_000,"hatch_time": 9.0,
     "pets": [(50,"Secret"),(50,"Secret")]},
]

# Coin spawner: coins spawn in clusters; model = rate × value × 60 per minute
# Actual in-game: CoinSpawnerService creates collectible coins, player walks into them.
# Conservative assumption: player collects ~70% of spawned coins.
COLLECTION_EFFICIENCY = 0.70
SPAWNS_PER_MINUTE = 60  # spawner fires ~ once per second

# Assumptions for a free player (no boosts, no gamepasses)
BASE_HATCH_COOLDOWN = 0.8  # seconds (base)

RARITY_ORDER = {"Common": 1, "Rare": 2, "Epic": 3, "Legendary": 4, "Mythic": 5, "Secret": 6}

# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def coins_per_minute(zone: dict) -> float:
    """Estimate coins earned per minute standing in `zone`."""
    return zone["coin_value"] * zone["coin_spawn_rate"] * SPAWNS_PER_MINUTE * COLLECTION_EFFICIENCY

def time_to_accumulate_coins(target: float, zone: dict) -> float:
    """Minutes needed to farm `target` coins while standing in `zone`."""
    rate = coins_per_minute(zone)
    if rate <= 0:
        return float("inf")
    return target / rate

def egg_rarity_probs(egg: dict) -> dict:
    """Returns {rarity: probability} for an egg."""
    total = sum(w for w, _ in egg["pets"])
    grouped: dict[str, float] = {}
    for weight, rarity in egg["pets"]:
        grouped[rarity] = grouped.get(rarity, 0) + weight / total
    return grouped

def expected_hatches_for_rarity(egg: dict, target_rarity: str) -> float:
    """Mean hatches required to see at least one pet of `target_rarity` or higher."""
    probs = egg_rarity_probs(egg)
    p_at_least = sum(
        p for r, p in probs.items()
        if RARITY_ORDER.get(r, 0) >= RARITY_ORDER.get(target_rarity, 99)
    )
    if p_at_least <= 0:
        return float("inf")
    return 1.0 / p_at_least

def time_per_hatch(egg: dict) -> float:
    """Seconds elapsed per hatch (hatch time + cooldown)."""
    return egg["hatch_time"] + BASE_HATCH_COOLDOWN

def coins_needed_for_n_hatches(egg: dict, n: float) -> float:
    """Total coin cost for `n` hatches from `egg`."""
    return egg["cost"] * n


# ─────────────────────────────────────────────────────────────────────────────
# THRESHOLDS (pass/fail benchmarks)
# ─────────────────────────────────────────────────────────────────────────────

class Check:
    PASS = "PASS"
    WARN = "WARN"
    FAIL = "FAIL"

    def __init__(self, name, status, value, threshold, note=""):
        self.name = name
        self.status = status
        self.value = value
        self.threshold = threshold
        self.note = note

    def __str__(self):
        icon = {"PASS": "✅", "WARN": "⚠️ ", "FAIL": "❌"}[self.status]
        return f"  {icon} {self.name}: {self.value}  [{self.threshold}]" + (f"  ← {self.note}" if self.note else "")


def check(name, value, warn_thresh, fail_thresh, higher_is_worse=True, unit="", note=""):
    """Create a Check comparing value to warn/fail thresholds."""
    if higher_is_worse:
        if value >= fail_thresh:
            status = Check.FAIL
        elif value >= warn_thresh:
            status = Check.WARN
        else:
            status = Check.PASS
    else:
        if value <= fail_thresh:
            status = Check.FAIL
        elif value <= warn_thresh:
            status = Check.WARN
        else:
            status = Check.PASS

    formatted = f"{value:.1f}{unit}" if isinstance(value, float) else f"{value}{unit}"
    return Check(name, status, formatted, f"warn≥{warn_thresh}{unit}, fail≥{fail_thresh}{unit}" if higher_is_worse
                 else f"warn≤{warn_thresh}{unit}, fail≤{fail_thresh}{unit}", note)


# ─────────────────────────────────────────────────────────────────────────────
# SIMULATION
# ─────────────────────────────────────────────────────────────────────────────

def simulate():
    checks: list[Check] = []
    verbose = "--verbose" in sys.argv

    sep = "─" * 72

    print(sep)
    print("  WYNKPETS — CORE LOOP BALANCE REPORT")
    print(sep)

    # ── 1. Zone progression timeline ─────────────────────────────────────────
    print("\n▸ ZONE UNLOCK PROGRESSION (free-to-play, no boosts)\n")
    cumulative_playtime_min = 0.0
    prev_zone = ZONES[0]

    zone_timeline: list[tuple[dict, float]] = []  # (zone, unlock_time_cumulative)
    zone_timeline.append((ZONES[0], 0.0))

    for zone in ZONES[1:]:
        # Player farms coins in the previous zone until they can afford this one
        farm_time = time_to_accumulate_coins(zone["unlock_cost"], prev_zone)
        cumulative_playtime_min += farm_time
        zone_timeline.append((zone, cumulative_playtime_min))

        name = zone["id"].replace("_", " ").title()
        unlock_cost_str = f"{zone['unlock_cost']:,}"
        cpm = coins_per_minute(prev_zone)

        if verbose:
            print(f"  Zone {zone['order']}: {name}")
            print(f"    Unlock cost : {unlock_cost_str} coins")
            print(f"    Farm rate   : {cpm:,.0f} coins/min in {prev_zone['id'].replace('_',' ').title()}")
            print(f"    Farm time   : {farm_time:.1f} min  ({farm_time/60:.1f} hrs)")
            print(f"    Cumulative  : {cumulative_playtime_min:.1f} min  ({cumulative_playtime_min/60:.1f} hrs)\n")
        else:
            hrs = cumulative_playtime_min / 60
            print(f"  Zone {zone['order']:1d} {name:<22} unlock at {cumulative_playtime_min:>8.0f} min ({hrs:.1f} hrs cumulative)")

        prev_zone = zone

    # Zone 2 should unlock in ~5 min (tutorial-length hook)
    z2_time = zone_timeline[1][1]
    checks.append(check("Zone 2 unlock time", z2_time, 8, 15, higher_is_worse=True, unit=" min",
                         note="Should unlock in ≤8 min for strong early-game hook"))

    # Zone 3 (mid-game gate) ideally ~30-90 min
    z3_time = zone_timeline[2][1]
    checks.append(check("Zone 3 unlock time", z3_time, 90, 180, higher_is_worse=True, unit=" min",
                         note="Mid-game gate; >90 min risks early dropout"))

    # Zone 5 (first major prestige gate) should be reachable in a day of casual play
    z5_time = zone_timeline[4][1]
    checks.append(check("Zone 5 unlock time", z5_time, 480, 1440, higher_is_worse=True, unit=" min",
                         note="First prestige gate; should be reachable in ≤8 hrs"))

    # ── 2. Monetization gate analysis ────────────────────────────────────────
    print(f"\n{sep}")
    print("\n▸ MONETIZATION GATE ANALYSIS\n")

    # Zone 2 monetization tap window: time between zone 1 and zone 2
    # This is the best window for the "Starter Pack" upsell
    zone1_cpm = coins_per_minute(ZONES[0])
    time_to_750 = time_to_accumulate_coins(750, ZONES[0])
    starter_pack_value_mins = 10_000 / zone1_cpm  # Starter Pack gives 10k coins
    print(f"  Starter Pack (R$99):")
    print(f"    Organic time to Zone 2: {time_to_750:.1f} min")
    print(f"    Pack coin value equiv : {starter_pack_value_mins:.0f} min of Zone 1 farming")
    print(f"    Perceived value       : {starter_pack_value_mins/time_to_750:.1f}x farm savings")

    # DoubleCoin pass ROI vs free play progression
    # If a player buys DoubleLuck (R$249), how much sooner do they see Legendary?
    basic_egg = next(e for e in EGGS if e["id"] == "basic_egg")
    expected_for_leg = expected_hatches_for_rarity(basic_egg, "Legendary")
    with_double_luck = expected_for_leg / 2.0
    print(f"\n  DoubleLuck Pass (R$249) on basic_egg:")
    print(f"    Avg hatches to first Legendary (base)      : {expected_for_leg:.0f} hatches")
    print(f"    Avg hatches to first Legendary (2x luck)   : {with_double_luck:.0f} hatches")
    print(f"    Hatch savings                              : {expected_for_leg - with_double_luck:.0f} hatches")

    # ── 3. Rarity rate audit ─────────────────────────────────────────────────
    print(f"\n{sep}")
    print("\n▸ RARITY RATE AUDIT  (expected hatches to first occurrence)\n")
    print(f"  {'Egg':<22} {'Cost':>10}  {'→Rare':>8} {'→Epic':>8} {'→Leg':>8} {'→Mythic':>9} {'→Secret':>9}")
    print(f"  {'─'*22} {'─'*10}  {'─'*8} {'─'*8} {'─'*8} {'─'*9} {'─'*9}")

    for egg in EGGS:
        e_rare  = expected_hatches_for_rarity(egg, "Rare")
        e_epic  = expected_hatches_for_rarity(egg, "Epic")
        e_leg   = expected_hatches_for_rarity(egg, "Legendary")
        e_myth  = expected_hatches_for_rarity(egg, "Mythic")
        e_sec   = expected_hatches_for_rarity(egg, "Secret")

        def fmt(v):
            if v == float("inf"): return "   —"
            if v > 9999: return f"{v/1000:>6.0f}k"
            return f"{v:>8.0f}"

        cost_str = f"{egg['cost']:>10,}"
        print(f"  {egg['id']:<22} {cost_str}  {fmt(e_rare)} {fmt(e_epic)} {fmt(e_leg)} {fmt(e_myth)} {fmt(e_sec)}")

    # Rarity rate checks (basic_egg benchmark)
    e_leg_basic = expected_hatches_for_rarity(basic_egg, "Legendary")
    checks.append(check("Basic Egg: hatches to first Legendary", e_leg_basic,
                         warn_thresh=75, fail_thresh=150, higher_is_worse=True,
                         note=">75 hatches to Legendary on starter egg risks early boredom"))

    # ── 4. Boredom cliff analysis ─────────────────────────────────────────────
    print(f"\n{sep}")
    print("\n▸ BOREDOM CLIFF ANALYSIS  (session benchmarks)\n")

    # Idle coin rate in Zone 1 over a session
    zone1 = ZONES[0]
    z1_cpm = coins_per_minute(zone1)

    def minutes_stats(minutes):
        coins = z1_cpm * minutes
        # How many basic eggs can be hatched?
        hatches = int(coins / basic_egg["cost"])
        # Probability of seeing Legendary in `hatches` hatches
        probs = egg_rarity_probs(basic_egg)
        p_leg = sum(p for r, p in probs.items() if RARITY_ORDER.get(r, 0) >= 4)
        p_at_least_one_leg = 1 - (1 - p_leg) ** hatches if hatches > 0 else 0
        return coins, hatches, p_at_least_one_leg

    for mins in [5, 10, 15, 30, 60]:
        coins, hatches, p_leg = minutes_stats(mins)
        can_unlock_z2 = "✓ Zone 2 unlocked" if coins >= 750 else f"  {750-coins:.0f} short of Zone 2"
        print(f"  {mins:>3} min │ {coins:>9,.0f} coins │ ~{hatches:>5} hatches │ "
              f"P(≥1 Leg): {p_leg*100:>5.1f}%  {can_unlock_z2}")

    # 5-min check: player should have meaningful progress by 5 min
    coins_5min, hatches_5min, p_leg_5min = minutes_stats(5)
    checks.append(check("5-min hatches (engagement hook)", hatches_5min,
                         warn_thresh=5, fail_thresh=2, higher_is_worse=False, unit="",
                         note="<5 hatches in first 5 min = weak engagement hook"))

    checks.append(check("30-min P(Legendary) %", p_leg_5min * 100,
                         warn_thresh=5, fail_thresh=1, higher_is_worse=False, unit="%",
                         note="P(seeing a Legendary in 30min) should be >5%"))

    # ── 5. Session milestone / engagement loop timing ─────────────────────────
    print(f"\n{sep}")
    print("\n▸ SESSION MILESTONE TIMING  (reward triggers)\n")
    milestones = [
        (5,  "Coin bonus",          "Zone 2 now reachable — critical retention window"),
        (15, "Coins + 50 Gems",     "Gem economy introduction"),
        (30, "Coins + 150 Gems",    "Mid-session paycheck"),
        (60, "Coins + 300 Gems + Badge", "Power-user reward; first hour completion"),
    ]
    for mins, reward, context in milestones:
        coins, hatches, p_leg = minutes_stats(mins)
        print(f"  T+{mins:>2} min │ {reward:<28} │ {coins:>12,.0f} coins farmed by now")
        if verbose:
            print(f"          │ Context: {context}")

    # ── 6. Overall pass/fail summary ──────────────────────────────────────────
    print(f"\n{sep}")
    print("\n▸ AUTOMATED CHECKS\n")

    fails = [c for c in checks if c.status == Check.FAIL]
    warns = [c for c in checks if c.status == Check.WARN]
    passes = [c for c in checks if c.status == Check.PASS]

    for c in checks:
        print(c)

    print(f"\n  Result: {len(passes)} PASS  /  {len(warns)} WARN  /  {len(fails)} FAIL")

    if fails:
        print("\n  ⛔  LAUNCH BLOCKER — Fix FAIL items before shipping:")
        for c in fails:
            print(f"     • {c.name}: {c.note}")
    elif warns:
        print("\n  ⚠️   Review WARN items — address before wide launch.")
    else:
        print("\n  ✅  All balance checks pass — safe to proceed.")

    print(f"\n{sep}\n")
    return len(fails) == 0


if __name__ == "__main__":
    ok = simulate()
    sys.exit(0 if ok else 1)
