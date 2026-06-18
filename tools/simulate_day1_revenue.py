#!/usr/bin/env python3
"""
simulate_day1_revenue.py
Comprehensive Monte Carlo simulation of Day 1 player behavior,
zone progression, offer triggers, and revenue for WynkPets soft-launch.

Run:  python3 tools/simulate_day1_revenue.py
"""

import random
import json
import math
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Optional

random.seed(42)

# ─────────────────────────────────────────────────────────────────────────────
# GAME CONFIG  (mirrors Luau configs)
# ─────────────────────────────────────────────────────────────────────────────

ZONES = [
    {"id": "starter_meadow",   "order": 1, "unlock_cost": 0,          "coin_value": 5},
    {"id": "forest_grove",     "order": 2, "unlock_cost": 750,        "coin_value": 25},
    {"id": "crystal_caves",    "order": 3, "unlock_cost": 7_000,      "coin_value": 65},
    {"id": "volcanic_ridge",   "order": 4, "unlock_cost": 100_000,    "coin_value": 200},
    {"id": "frozen_tundra",    "order": 5, "unlock_cost": 500_000,    "coin_value": 600},
    {"id": "celestial_garden", "order": 6, "unlock_cost": 2_500_000,  "coin_value": 2_000},
]

EGGS = [
    {"id": "basic_egg",        "zone": 1, "cost": 25,          "hatch_sec": 1.5},
    {"id": "spotted_egg",      "zone": 1, "cost": 120,         "hatch_sec": 2.0},
    {"id": "forest_egg",       "zone": 2, "cost": 500,         "hatch_sec": 2.5},
    {"id": "enchanted_egg",    "zone": 2, "cost": 2_500,       "hatch_sec": 3.0},
    {"id": "crystal_egg",      "zone": 3, "cost": 8_000,       "hatch_sec": 3.5},
    {"id": "mythic_egg",       "zone": 3, "cost": 40_000,      "hatch_sec": 4.0},
    {"id": "magma_egg",        "zone": 4, "cost": 150_000,     "hatch_sec": 4.0},
    {"id": "inferno_egg",      "zone": 4, "cost": 600_000,     "hatch_sec": 4.5},
    {"id": "frost_egg",        "zone": 5, "cost": 1_500_000,   "hatch_sec": 5.0},
]

# CoinSpawnerService constants
COINS_PER_ZONE     = 30      # live coins in zone
COIN_RESPAWN_SEC   = 2.0     # respawn interval
LUCKY_CHANCE       = 0.08    # 8% → 5× value
SUPER_LUCKY_CHANCE = 0.02    # 2% → 15× value

# Coin type distribution  (weights, value_multiplier)
COIN_TYPES = [
    (50, 0.5),   # Bronze
    (25, 1.0),   # Silver
    (15, 2.0),   # Gold
    ( 7, 5.0),   # Diamond
    ( 3, 10.0),  # Ruby
]
TOTAL_CT_WEIGHT  = sum(w for w, _ in COIN_TYPES)
EV_TYPE_MULTI    = sum((w / TOTAL_CT_WEIGHT) * v for w, v in COIN_TYPES)   # ≈ 1.45
EV_LUCKY_MULTI   = 0.90 * 1.0 + 0.08 * 5.0 + 0.02 * 15.0                 # = 1.60
EV_COIN_FULL     = EV_TYPE_MULTI * EV_LUCKY_MULTI                          # ≈ 2.32

# Base node collection rate (calibrated from prior simulation:
#   Zone1 → Zone2 at T=101s with 750 coins needed  → 750/101 = 7.43 coins/sec
#   gross = BASE_COLLECTION_RATE × CoinValue
#   7.43 = BASE × 5  →  BASE = 1.486 nodes/sec
# EV_COIN_FULL is already baked into the calibration (the 7.43 is the real
# observed rate including all value multipliers), so we use:
#   effective_gross_per_sec(zone) = 1.486 × zone.coin_value
BASE_COLLECT_RATE = 1.486  # effective nodes/sec collected (with all multipliers folded in)

def gross_rate(coin_value: int) -> float:
    return BASE_COLLECT_RATE * coin_value

# ── Monetization ──────────────────────────────────────────────────────────────
GAMEPASSES = [
    {"id": "DoubleCoins",      "robux": 199, "effect": "2x_coins"},
    {"id": "DoubleLuck",       "robux": 249, "effect": "2x_luck"},
    {"id": "DoubleHatchSpeed", "robux": 149, "effect": "2x_hatch"},
    # AdvancedPasses
    {"id": "auto_hatch",       "robux": 399, "effect": "auto_hatch",  "advanced": True},
    {"id": "triple_hatch",     "robux": 499, "effect": "triple_hatch","advanced": True},
    {"id": "extra_equip",      "robux": 349, "effect": "extra_equip", "advanced": True},
]

DEV_PRODUCTS = {
    "starter_pack":        {"robux":  99, "coins": 10_000, "gems": 100},
    "mega_pack":           {"robux": 399, "coins": 100_000,"gems": 500},
    "ultra_pack":          {"robux": 999, "coins": 1_000_000,"gems": 2_000},
    "coin_boost":          {"robux":  49, "boost": "coins_30min"},
    "luck_boost":          {"robux":  49, "boost": "luck_30min"},
    "hatch_speed_boost":   {"robux":  49, "boost": "hatch_30min"},
    "coin_boost_3x":       {"robux": 119, "boost": "coins_3x"},
    "luck_boost_3x":       {"robux": 119, "boost": "luck_3x"},
    "mega_boost_bundle":   {"robux": 299, "boost": "all_30min"},
    "gems_small":          {"robux":  49, "gems":  50},
    "gems_medium":         {"robux":  99, "gems": 175},
    "gems_large":          {"robux": 249, "gems": 600},
    "gems_mega":           {"robux": 599, "gems": 2_000},
    "pet_storage_50":      {"robux": 149, "storage": 50},
    "pet_storage_200":     {"robux": 449, "storage": 200},
}

SUBSCRIPTION_VIP    = {"robux": 199, "monthly": True, "id": "vip_basic"}
SUBSCRIPTION_VIP_P  = {"robux": 499, "monthly": True, "id": "vip_plus"}

# ── LaunchConfig flags ────────────────────────────────────────────────────────
LAUNCH_CONFIG = {
    "CorePasses":     True,
    "AdvancedPasses": False,   # auto_hatch/triple_hatch/extra_equip off at soft_launch
    "DevProducts":    True,
    "Bundles":        False,   # mega/ultra packs off
    "Subscription":   False,   # VIP off
}

# ── Login streak rewards ──────────────────────────────────────────────────────
LOGIN_STREAK = [
    {"day": 1, "type": "Coins", "amount": 100},
    {"day": 2, "type": "Coins", "amount": 500},
    {"day": 3, "type": "Gems",  "amount": 10},
    {"day": 4, "type": "Coins", "amount": 2_500},
    {"day": 5, "type": "Gems",  "amount": 25},
    {"day": 6, "type": "Coins", "amount": 10_000},
    {"day": 7, "type": "Gems",  "amount": 100},
]

# ── Daily quests available at soft_launch ─────────────────────────────────────
# (fuse_pet + spin_wheel are filtered out by RewardService.buildFilteredPool)
ACTIVE_QUESTS = [
    {"id": "collect_500_coins",  "type": "CollectCoins", "target": 500,  "reward_coins": 750},
    {"id": "hatch_5_eggs",       "type": "HatchEggs",    "target": 5,    "reward_coins": 2_000},
    {"id": "equip_3_pets",       "type": "EquipPets",    "target": 3,    "reward_coins": 1_000},
    {"id": "collect_5000_coins", "type": "CollectCoins", "target": 5_000,"reward_gems": 20},
    {"id": "hatch_rare",         "type": "HatchRarity",  "target": 1,    "reward_coins": 5_000},
    {"id": "visit_2_zones",      "type": "VisitZones",   "target": 2,    "reward_coins": 2_500},
]

# ─────────────────────────────────────────────────────────────────────────────
# PLAYER ARCHETYPES
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class PlayerType:
    name:          str
    session_min:   float      # mean session length (minutes)
    session_sd:    float      # std dev of session length
    hatch_eagerness: float    # fraction of gross income spent hatching vs saving
    zone1_sprint:  bool       # True = sprint to Zone 2 before hatching
    # Conversion probabilities
    p_starter_offer:  float   # prob of buying starter_pack after 1st hatch offer
    p_gamepass_visit: float   # prob of buying any gamepass per shop visit
    p_boost_impulse:  float   # prob of buying a 49R boost when prompted
    p_subscription:   float   # prob of buying VIP (if enabled)
    p_advanced_pass:  float   # prob of buying auto_hatch (if enabled)
    weight:        float      # population weight (sums to 1)


PLAYER_TYPES = [
    PlayerType(
        name="casual",
        session_min=8,   session_sd=3,
        hatch_eagerness=0.45, zone1_sprint=True,
        p_starter_offer=0.04, p_gamepass_visit=0.008, p_boost_impulse=0.015,
        p_subscription=0.005, p_advanced_pass=0.01,
        weight=0.50,
    ),
    PlayerType(
        name="moderate",
        session_min=18,  session_sd=6,
        hatch_eagerness=0.55, zone1_sprint=True,
        p_starter_offer=0.09, p_gamepass_visit=0.020, p_boost_impulse=0.035,
        p_subscription=0.015, p_advanced_pass=0.025,
        weight=0.30,
    ),
    PlayerType(
        name="active",
        session_min=35,  session_sd=12,
        hatch_eagerness=0.65, zone1_sprint=True,
        p_starter_offer=0.16, p_gamepass_visit=0.045, p_boost_impulse=0.060,
        p_subscription=0.030, p_advanced_pass=0.060,
        weight=0.15,
    ),
    PlayerType(
        name="whale",
        session_min=45,  session_sd=15,
        hatch_eagerness=0.50, zone1_sprint=True,
        p_starter_offer=0.55, p_gamepass_visit=0.180, p_boost_impulse=0.200,
        p_subscription=0.120, p_advanced_pass=0.200,
        weight=0.05,
    ),
]

# ─────────────────────────────────────────────────────────────────────────────
# SIMULATION CORE
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class PlayerState:
    ptype:           PlayerType
    session_secs:    float          # total session length in seconds
    coins:           float = 0.0
    gems:            int   = 0
    zone:            int   = 1      # current zone (1-indexed)
    zones_unlocked:  list  = field(default_factory=lambda: [1])
    pets_hatched:    int   = 0
    eggs_hatched:    int   = 0
    storage:         int   = 50     # base storage slots
    # Timestamps
    zone_unlock_time: dict = field(default_factory=dict)  # {zone: t_seconds}
    first_hatch_time: Optional[float] = None
    # Offer/purchase tracking
    starter_offer_shown:  bool  = False
    starter_offer_bought: bool  = False
    storage_nudge_shown:  int   = 0   # count of times shown
    low_coins_nudge_shown: int  = 0
    # Revenue
    purchases:        list  = field(default_factory=list)  # [{prod, robux, t}]
    total_robux:      int   = 0
    # Boosts
    coin_boost_active: float = 0.0   # remaining seconds of 2x coin boost
    firstsession_boost_remaining: float = 300.0  # first 5 minutes = 2x
    # Quest progress
    quests_completed: list = field(default_factory=list)
    coins_collected_total: float = 0.0
    # Shortages
    shortage_events:  int = 0
    low_balance_blocked_hatches: int = 0
    # Upsell triggers
    offer_trigger_count: int = 0


def pick_player_type() -> PlayerType:
    r = random.random()
    cumulative = 0.0
    for pt in PLAYER_TYPES:
        cumulative += pt.weight
        if r <= cumulative:
            return pt
    return PLAYER_TYPES[-1]


def best_egg_for_zone(zone: int) -> Optional[dict]:
    """Return the most expensive egg available in the player's current zone."""
    candidates = [e for e in EGGS if e["zone"] <= zone]
    if not candidates:
        return None
    return max(candidates, key=lambda e: e["cost"])


def cheapest_egg_in_zone(zone: int) -> Optional[dict]:
    """Return the cheapest egg available in the zone (for shortage check)."""
    candidates = [e for e in EGGS if e["zone"] <= zone]
    if not candidates:
        return None
    return min(candidates, key=lambda e: e["cost"])


# Primary hatch target per zone: affordable, zone-appropriate egg.
# Data matches what a real player naturally gravitates to in each zone.
ZONE_PRIMARY_EGG = {
    1: "spotted_egg",    # 120 coins  (upgrade from basic after first few hatches)
    2: "forest_egg",     # 500 coins  (bread-and-butter Zone 2 egg)
    3: "crystal_egg",    # 8,000 coins
    4: "magma_egg",      # 150,000 coins
    5: "frost_egg",      # 1,500,000 coins
    6: None,             # Zone 6+ unreachable in Day 1 — no primary egg
    7: None,
    8: None,
}

def primary_egg_for_zone(zone: int) -> Optional[dict]:
    """Return the zone-appropriate primary hatch target, or None if not applicable."""
    eid = ZONE_PRIMARY_EGG.get(zone)
    if eid is None:
        return None   # Zone 6+ not reachable on Day 1; prevents cheap-egg fallback
    by_id = {e["id"]: e for e in EGGS}
    return by_id.get(eid)


def next_zone_unlock_cost(zone: int) -> Optional[int]:
    nz = zone + 1
    for z in ZONES:
        if z["order"] == nz:
            return z["unlock_cost"]
    return None


def simulate_player(config: dict) -> PlayerState:
    """
    Simulate a single Day 1 player session.
    Tick resolution: 1 second.

    Coin model:
      - Each tick: gross_dt = gross_rate(zone.coin_value) * boost_multi
      - save_dt   = gross_dt * save_fraction   → added to ps.coins (zone-unlock savings)
      - hatch_dt  = gross_dt * hatch_eagerness → consumed by hatching eggs
      - Zone-unlock costs are deducted from ps.coins on unlock.
      - save_fraction = 1.0 in Zone 1 sprint (no hatching while unlocking Zone 2).
    """
    pt = pick_player_type()
    session_secs = max(30.0, random.gauss(pt.session_min * 60, pt.session_sd * 60))
    ps = PlayerState(ptype=pt, session_secs=session_secs)

    # Login streak Day 1 reward (instantly on login)
    day1_reward = LOGIN_STREAK[0]
    if day1_reward["type"] == "Coins":
        ps.coins += day1_reward["amount"]
    else:
        ps.gems += day1_reward["amount"]

    # Assign 3 random quests from the active pool
    assigned_quests = random.sample(ACTIVE_QUESTS, min(3, len(ACTIVE_QUESTS)))
    quest_progress  = {q["id"]: 0 for q in assigned_quests}
    quests_done     = set()

    # Zone config lookups
    zone_costs = {z["order"]: z["unlock_cost"] for z in ZONES}
    zone_cvals  = {z["order"]: z["coin_value"] for z in ZONES}

    # Hatch accumulation: track fractional egg progress
    # (each tick contributes hatch_dt coins worth of hatch budget)
    hatch_budget_acc = 0.0   # accumulated coins toward next egg hatch

    last_low_nudge      = -999.0
    last_storage_nudge  = -999.0
    shop_visit_timer    = 300.0   # first shop visit opportunity at T=5 min
    double_coins_owned  = False

    t = 0.0
    while t < session_secs:
        dt = 1.0  # 1-second tick

        # ── Multipliers ──────────────────────────────────────────────────────
        boost_multi = 1.0
        if ps.firstsession_boost_remaining > 0:
            boost_multi *= 2.0
            ps.firstsession_boost_remaining -= dt
        if ps.coin_boost_active > 0:
            boost_multi *= 2.0
            ps.coin_boost_active -= dt
        if double_coins_owned:
            boost_multi *= 2.0

        # ── Coin collection (continuous-flow model) ──────────────────────────
        raw_gross = gross_rate(zone_cvals[ps.zone])
        gross_dt  = raw_gross * boost_multi * dt
        ps.coins_collected_total += gross_dt

        # In Zone 1 sprint: all coins go to savings (no hatch spending)
        sprinting = (ps.zone == 1 and 2 not in ps.zones_unlocked and pt.zone1_sprint)
        if sprinting:
            save_fraction  = 1.0
            hatch_fraction = 0.0
        else:
            save_fraction  = 1.0 - pt.hatch_eagerness
            hatch_fraction = pt.hatch_eagerness

        save_dt  = gross_dt * save_fraction
        hatch_dt = gross_dt * hatch_fraction

        ps.coins += save_dt

        # ── Quest: CollectCoins (counts total gross income) ──────────────────
        for q in assigned_quests:
            if q["id"] not in quests_done and q["type"] == "CollectCoins":
                quest_progress[q["id"]] = quest_progress.get(q["id"], 0) + gross_dt
                if quest_progress[q["id"]] >= q["target"]:
                    quests_done.add(q["id"])
                    ps.quests_completed.append(q["id"])
                    ps.coins += q.get("reward_coins", 0)

        # ── Zone unlock check ────────────────────────────────────────────────
        next_zone = ps.zone + 1
        if next_zone <= len(ZONES):
            unlock_cost = zone_costs.get(next_zone, 0)
            if unlock_cost > 0 and ps.coins >= unlock_cost and next_zone not in ps.zones_unlocked:
                ps.coins -= unlock_cost          # deduct cost (server-authoritative)
                ps.zones_unlocked.append(next_zone)
                ps.zone = next_zone
                ps.zone_unlock_time[next_zone] = t
                # Quest: VisitZones
                for q in assigned_quests:
                    if q["id"] not in quests_done and q["type"] == "VisitZones":
                        quest_progress[q["id"]] = quest_progress.get(q["id"], 0) + 1
                        if quest_progress[q["id"]] >= q["target"]:
                            quests_done.add(q["id"])
                            ps.quests_completed.append(q["id"])
                            ps.coins += q.get("reward_coins", 0)

        # ── Hatch accumulation ───────────────────────────────────────────────
        # Players "virtually" spend hatch_dt coins per tick on hatching.
        # When budget crosses an egg's cost, one hatch event fires.
        if not sprinting:
            hatch_budget_acc += hatch_dt
            target_egg = primary_egg_for_zone(ps.zone)
            if target_egg:
                _loop_guard = 0
                while hatch_budget_acc >= target_egg["cost"] and _loop_guard < 2000:
                    _loop_guard += 1
                    hatch_budget_acc -= target_egg["cost"]
                    ps.eggs_hatched += 1
                    ps.pets_hatched += 1

                    if ps.first_hatch_time is None:
                        ps.first_hatch_time = t
                        # Starter offer fires after first hatch
                        ps.starter_offer_shown = True
                        ps.offer_trigger_count += 1
                        if random.random() < pt.p_starter_offer:
                            ps.starter_offer_bought = True
                            prod = DEV_PRODUCTS["starter_pack"]
                            ps.purchases.append({"prod": "starter_pack", "robux": prod["robux"], "t": t})
                            ps.total_robux += prod["robux"]
                            ps.coins += prod["coins"]
                            ps.gems  += prod["gems"]

                    # Quests: HatchEggs
                    for q in assigned_quests:
                        if q["id"] not in quests_done and q["type"] == "HatchEggs":
                            quest_progress[q["id"]] = quest_progress.get(q["id"], 0) + 1
                            if quest_progress[q["id"]] >= q["target"]:
                                quests_done.add(q["id"])
                                ps.quests_completed.append(q["id"])
                                ps.coins += q.get("reward_coins", 0)

                    # HatchRarity: ~35% of hatches are Rare+
                    for q in assigned_quests:
                        if q["id"] not in quests_done and q["type"] == "HatchRarity":
                            if random.random() < 0.35:
                                quest_progress[q["id"]] = quest_progress.get(q["id"], 0) + 1
                                if quest_progress[q["id"]] >= q["target"]:
                                    quests_done.add(q["id"])
                                    ps.quests_completed.append(q["id"])
                                    ps.coins += q.get("reward_coins", 0)

                    # EquipPets: auto-equip first 5 pets
                    for q in assigned_quests:
                        if q["id"] not in quests_done and q["type"] == "EquipPets":
                            if ps.pets_hatched <= 5:
                                quest_progress[q["id"]] = quest_progress.get(q["id"], 0) + 1
                                if quest_progress[q["id"]] >= q["target"]:
                                    quests_done.add(q["id"])
                                    ps.quests_completed.append(q["id"])
                                    ps.coins += q.get("reward_coins", 0)

                    # Storage full
                    if ps.pets_hatched >= ps.storage and t - last_storage_nudge > 600:
                        last_storage_nudge = t
                        ps.storage_nudge_shown += 1
                        ps.offer_trigger_count += 1
                        if random.random() < 0.08:
                            ps.purchases.append({"prod": "pet_storage_50", "robux": 149, "t": t})
                            ps.total_robux += 149
                            ps.storage += 50

                    # Bump target egg in case zone changed mid-loop
                    target_egg = primary_egg_for_zone(ps.zone)
                    if not target_egg:
                        break

        # ── Low-coin nudge (real balance below cheapest egg) ─────────────────
        # This fires when the SAVINGS balance is too low to even hatch the
        # cheapest egg (i.e. hatch budget alone isn't keeping up).
        cheap = cheapest_egg_in_zone(ps.zone)
        if cheap and ps.coins < cheap["cost"] * 0.25 and t - last_low_nudge > 300:
            if not sprinting:
                ps.shortage_events += 1
                ps.low_balance_blocked_hatches += 1
                last_low_nudge = t
                ps.low_coins_nudge_shown += 1
                ps.offer_trigger_count += 1
                if random.random() < 0.04:
                    prod = DEV_PRODUCTS["starter_pack"]
                    ps.purchases.append({"prod": "starter_pack_lowcoins", "robux": prod["robux"], "t": t})
                    ps.total_robux += prod["robux"]
                    ps.coins += prod["coins"]
                    ps.gems  += prod["gems"]

        # ── Shop visit (T=5 min, T=15 min, every 10 min after) ───────────────
        if t >= shop_visit_timer and shop_visit_timer < session_secs:
            shop_visit_timer += 600.0

            # Core gamepasses
            if not double_coins_owned and random.random() < pt.p_gamepass_visit:
                double_coins_owned = True
                ps.purchases.append({"prod": "DoubleCoins", "robux": 199, "t": t})
                ps.total_robux += 199
            if random.random() < pt.p_gamepass_visit * 1.2:
                if not any(p["prod"] == "DoubleHatchSpeed" for p in ps.purchases):
                    ps.purchases.append({"prod": "DoubleHatchSpeed", "robux": 149, "t": t})
                    ps.total_robux += 149
            if random.random() < pt.p_gamepass_visit * 0.8:
                if not any(p["prod"] == "DoubleLuck" for p in ps.purchases):
                    ps.purchases.append({"prod": "DoubleLuck", "robux": 249, "t": t})
                    ps.total_robux += 249

            # Advanced passes (if enabled)
            if config.get("AdvancedPasses"):
                if random.random() < pt.p_advanced_pass:
                    if not any(p["prod"] == "auto_hatch" for p in ps.purchases):
                        ps.purchases.append({"prod": "auto_hatch", "robux": 399, "t": t})
                        ps.total_robux += 399
                if random.random() < pt.p_advanced_pass * 0.6:
                    if not any(p["prod"] == "triple_hatch" for p in ps.purchases):
                        ps.purchases.append({"prod": "triple_hatch", "robux": 499, "t": t})
                        ps.total_robux += 499

            # Boost impulse
            if random.random() < pt.p_boost_impulse:
                ps.purchases.append({"prod": "coin_boost", "robux": 49, "t": t})
                ps.total_robux += 49
                ps.coin_boost_active += 1800

            # Subscription (if enabled)
            if config.get("Subscription") and random.random() < pt.p_subscription:
                if not any(p["prod"] == "vip_basic" for p in ps.purchases):
                    ps.purchases.append({"prod": "vip_basic", "robux": 199, "t": t})
                    ps.total_robux += 199

        t += dt

    return ps


# ─────────────────────────────────────────────────────────────────────────────
# RUN SIMULATION
# ─────────────────────────────────────────────────────────────────────────────

def run_simulation(n_players: int, config: dict, label: str) -> dict:
    """
    Run n_players Monte Carlo sessions.
    Returns aggregated metrics dict.
    """
    results = []
    per_type = defaultdict(list)

    for _ in range(n_players):
        ps = simulate_player(config)
        results.append(ps)
        per_type[ps.ptype.name].append(ps)

    # ── Aggregate ─────────────────────────────────────────────────────────────
    def pct(lst, p):
        s = sorted(lst)
        if not s:
            return 0
        idx = int(len(s) * p / 100)
        return s[min(idx, len(s)-1)]

    def mean(lst):
        return sum(lst) / len(lst) if lst else 0

    # Zone unlock timing
    z2_times = [ps.zone_unlock_time.get(2) for ps in results if 2 in ps.zone_unlock_time]
    z3_times = [ps.zone_unlock_time.get(3) for ps in results if 3 in ps.zone_unlock_time]
    z4_times = [ps.zone_unlock_time.get(4) for ps in results if 4 in ps.zone_unlock_time]

    z2_rate = len(z2_times) / n_players
    z3_rate = len(z3_times) / n_players
    z4_rate = len(z4_times) / n_players

    # Revenue
    all_robux   = [ps.total_robux for ps in results]
    spenders    = [ps for ps in results if ps.total_robux > 0]
    spend_rate  = len(spenders) / n_players

    total_robux = sum(all_robux)
    total_usd   = total_robux * 0.0035  # dev revenue

    # Per-product breakdown
    prod_revenue = defaultdict(lambda: {"count": 0, "robux": 0})
    for ps in results:
        for p in ps.purchases:
            prod_revenue[p["prod"]]["count"] += 1
            prod_revenue[p["prod"]]["robux"] += p["robux"]

    # Offer triggers
    offer_triggers = [ps.offer_trigger_count for ps in results]
    starter_show   = sum(1 for ps in results if ps.starter_offer_shown)
    starter_conv   = sum(1 for ps in results if ps.starter_offer_bought)
    storage_shown  = sum(ps.storage_nudge_shown for ps in results)
    low_coin_shown = sum(ps.low_coins_nudge_shown for ps in results)
    shortage_total = sum(ps.shortage_events for ps in results)

    # Quest completions
    total_quests_done = sum(len(ps.quests_completed) for ps in results)
    quests_per_player = mean([len(ps.quests_completed) for ps in results])

    # Eggs hatched
    eggs = [ps.eggs_hatched for ps in results]
    pets = [ps.pets_hatched for ps in results]

    # Session lengths
    sess = [ps.session_secs / 60 for ps in results]

    # Per-cohort revenue
    cohort_revenue = {}
    for name, players in per_type.items():
        cohort_revenue[name] = {
            "count":        len(players),
            "mean_session_min": mean([ps.session_secs/60 for ps in players]),
            "spend_rate":   sum(1 for ps in players if ps.total_robux > 0) / len(players),
            "mean_robux":   mean([ps.total_robux for ps in players]),
            "total_robux":  sum(ps.total_robux for ps in players),
            "z2_rate":      sum(1 for ps in players if 2 in ps.zones_unlocked) / len(players),
            "z3_rate":      sum(1 for ps in players if 3 in ps.zones_unlocked) / len(players),
            "mean_eggs":    mean([ps.eggs_hatched for ps in players]),
        }

    return {
        "label":                label,
        "n_players":            n_players,

        # Session
        "session_min_mean":     mean(sess),
        "session_min_p25":      pct(sess, 25),
        "session_min_p50":      pct(sess, 50),
        "session_min_p75":      pct(sess, 75),
        "session_min_p95":      pct(sess, 95),

        # Zone progression
        "z2_reach_rate":        z2_rate,
        "z3_reach_rate":        z3_rate,
        "z4_reach_rate":        z4_rate,
        "z2_mean_t_sec":        mean(z2_times),
        "z2_p50_t_sec":         pct(z2_times, 50),
        "z2_p25_t_sec":         pct(z2_times, 25),
        "z2_p75_t_sec":         pct(z2_times, 75),
        "z3_mean_t_sec":        mean(z3_times),
        "z3_p50_t_sec":         pct(z3_times, 50),
        "z3_p25_t_sec":         pct(z3_times, 25),
        "z3_p75_t_sec":         pct(z3_times, 75),

        # Eggs / pets
        "eggs_mean":            mean(eggs),
        "eggs_p50":             pct(eggs, 50),
        "eggs_p75":             pct(eggs, 75),
        "eggs_p95":             pct(eggs, 95),
        "pets_mean":            mean(pets),

        # Quest completions
        "quest_completions_per_player": quests_per_player,
        "total_quests_completed": total_quests_done,

        # Revenue
        "spend_rate":           spend_rate,
        "mean_robux_per_player":mean(all_robux),
        "mean_robux_spender":   mean([ps.total_robux for ps in spenders]) if spenders else 0,
        "total_robux_1k":       total_robux,
        "total_usd_1k":         total_usd,
        "arpu_usd":             total_usd / n_players,
        "arppu_usd":            (total_usd / len(spenders)) if spenders else 0,

        # Product breakdown
        "product_revenue":      dict(prod_revenue),

        # Offer / nudge triggers
        "offer_triggers_mean":  mean(offer_triggers),
        "offer_triggers_max":   max(offer_triggers) if offer_triggers else 0,
        "starter_offer_shown":  starter_show,
        "starter_offer_conv":   starter_conv,
        "starter_conv_rate":    starter_conv / starter_show if starter_show > 0 else 0,
        "storage_nudges_total": storage_shown,
        "low_coin_nudges_total":low_coin_shown,
        "shortage_events_total":shortage_total,

        # Per-cohort
        "cohort_revenue":       cohort_revenue,
    }


# ─────────────────────────────────────────────────────────────────────────────
# SCENARIOS
# ─────────────────────────────────────────────────────────────────────────────

N = 5_000  # runs per scenario

CONFIG_BASELINE = dict(LAUNCH_CONFIG)  # current soft_launch state

CONFIG_OPTIMIZED = dict(LAUNCH_CONFIG)
CONFIG_OPTIMIZED["Subscription"]    = True
CONFIG_OPTIMIZED["AdvancedPasses"]  = True

print("=" * 70)
print("WYNKPETS  —  DAY 1 REVENUE SIMULATION  (5,000 Monte Carlo runs each)")
print("=" * 70)

random.seed(42)
baseline  = run_simulation(N, CONFIG_BASELINE,  "BASELINE (current soft_launch)")

random.seed(42)
optimized = run_simulation(N, CONFIG_OPTIMIZED, "OPTIMIZED (Sub+AdvancedPasses on)")

# ─────────────────────────────────────────────────────────────────────────────
# REPORTING
# ─────────────────────────────────────────────────────────────────────────────

def fmt_t(seconds: float) -> str:
    if seconds == 0:
        return "N/A"
    m, s = divmod(int(seconds), 60)
    return f"{m}:{s:02d}"

def fmt_pct(v: float) -> str:
    return f"{v*100:.1f}%"

def fmt_robux(r: float) -> str:
    return f"{r:.1f} R$"

def fmt_usd(u: float) -> str:
    return f"${u:.4f}"

def print_section(title: str):
    print()
    print(f"── {title} {'─'*(65 - len(title))}")

for res in [baseline, optimized]:
    print()
    print(f"{'━'*70}")
    print(f"  SCENARIO:  {res['label']}")
    print(f"{'━'*70}")

    print_section("SESSION LENGTH  (minutes)")
    print(f"  Mean: {res['session_min_mean']:.1f}     P25: {res['session_min_p25']:.1f}     "
          f"P50: {res['session_min_p50']:.1f}     P75: {res['session_min_p75']:.1f}     "
          f"P95: {res['session_min_p95']:.1f}")

    print_section("ZONE PROGRESSION")
    print(f"  Zone 2 Reach Rate    : {fmt_pct(res['z2_reach_rate'])}   "
          f"mean={fmt_t(res['z2_mean_t_sec'])}   "
          f"P25={fmt_t(res['z2_p25_t_sec'])}   P50={fmt_t(res['z2_p50_t_sec'])}   "
          f"P75={fmt_t(res['z2_p75_t_sec'])}")
    print(f"  Zone 3 Reach Rate    : {fmt_pct(res['z3_reach_rate'])}   "
          f"mean={fmt_t(res['z3_mean_t_sec'])}   "
          f"P25={fmt_t(res['z3_p25_t_sec'])}   P50={fmt_t(res['z3_p50_t_sec'])}   "
          f"P75={fmt_t(res['z3_p75_t_sec'])}")
    print(f"  Zone 4 Reach Rate    : {fmt_pct(res['z4_reach_rate'])}")

    print_section("HATCHING & PETS")
    print(f"  Eggs hatched  — mean: {res['eggs_mean']:.1f}   P50: {res['eggs_p50']}   "
          f"P75: {res['eggs_p75']}   P95: {res['eggs_p95']}")
    print(f"  Pets total    — mean: {res['pets_mean']:.1f}")

    print_section("QUESTS")
    print(f"  Quests completed/player  : {res['quest_completions_per_player']:.2f}")
    print(f"  Total across {res['n_players']} players: {res['total_quests_completed']}")

    print_section("OFFER & NUDGE TRIGGERS")
    print(f"  Offer trigger events/player  : {res['offer_triggers_mean']:.2f}  "
          f"(max={res['offer_triggers_max']})")
    print(f"  Starter offer shown          : {res['starter_offer_shown']}  "
          f"({fmt_pct(res['starter_offer_shown']/res['n_players'])} of players)")
    print(f"  Starter offer converted      : {res['starter_offer_conv']}  "
          f"(conv rate = {fmt_pct(res['starter_conv_rate'])})")
    print(f"  Low-coin nudges (total)      : {res['low_coin_nudges_total']}")
    print(f"  Storage nudges (total)       : {res['storage_nudges_total']}")
    print(f"  Currency shortage events     : {res['shortage_events_total']}")

    print_section("REVENUE  (per 1,000 Day-1 players, scaled from N=5,000)")
    scale = 1000.0 / res["n_players"]
    print(f"  Spending rate      : {fmt_pct(res['spend_rate'])}")
    print(f"  ARPU               : {fmt_robux(res['mean_robux_per_player'])}  "
          f"({fmt_usd(res['arpu_usd'])})")
    print(f"  ARPPU              : {fmt_robux(res['mean_robux_spender'])}  "
          f"({fmt_usd(res['arppu_usd'])})")
    print(f"  Total Robux (1000 players)  : {res['total_robux_1k']*scale:.0f} R$")
    print(f"  Total USD   (1000 players)  : ${res['total_usd_1k']*scale:.2f}")

    print_section("PRODUCT REVENUE BREAKDOWN  (across all simulated players)")
    prods = sorted(res["product_revenue"].items(), key=lambda x: -x[1]["robux"])
    print(f"  {'Product':<28} {'Sales':>6}  {'Total R$':>10}  {'R$/sale':>8}")
    print(f"  {'-'*56}")
    for prod, data in prods:
        if data["count"] > 0:
            print(f"  {prod:<28} {data['count']:>6}  {data['robux']:>10}  "
                  f"{data['robux']/data['count']:>8.0f}")

    print_section("COHORT BREAKDOWN")
    print(f"  {'Type':<10} {'N':>6} {'Session':>8} {'SpendRate':>10} {'AvgR$':>8} "
          f"{'TotalR$':>10} {'Z2%':>6} {'Z3%':>6} {'Eggs':>6}")
    print(f"  {'-'*80}")
    for name, c in res["cohort_revenue"].items():
        print(f"  {name:<10} {c['count']:>6} {c['mean_session_min']:>7.1f}m "
              f"{fmt_pct(c['spend_rate']):>10} {c['mean_robux']:>8.1f} "
              f"{c['total_robux']:>10}  {fmt_pct(c['z2_rate']):>6} "
              f"{fmt_pct(c['z3_rate']):>6} {c['mean_eggs']:>6.1f}")

# ─────────────────────────────────────────────────────────────────────────────
# DELTA REPORT
# ─────────────────────────────────────────────────────────────────────────────
print()
print(f"{'━'*70}")
print("  DELTA:  OPTIMIZED vs BASELINE  (per 1,000 Day-1 players)")
print(f"{'━'*70}")
scale = 1000.0 / N
baseline_usd  = baseline["total_usd_1k"]  * scale
optimized_usd = optimized["total_usd_1k"] * scale
delta_usd     = optimized_usd - baseline_usd
delta_pct     = delta_usd / baseline_usd * 100 if baseline_usd > 0 else 0

baseline_rob  = baseline["total_robux_1k"]  * scale
optimized_rob = optimized["total_robux_1k"] * scale

print(f"  Revenue baseline    : ${baseline_usd:.2f} ({baseline_rob:.0f} R$)")
print(f"  Revenue optimized   : ${optimized_usd:.2f} ({optimized_rob:.0f} R$)")
print(f"  Revenue delta       : +${delta_usd:.2f}  (+{delta_pct:.1f}%)")
print(f"  Spend rate delta    : {fmt_pct(baseline['spend_rate'])} → {fmt_pct(optimized['spend_rate'])}")
print(f"  Z3 funnel delta     : {fmt_pct(baseline['z3_reach_rate'])} → {fmt_pct(optimized['z3_reach_rate'])}")
print()

# ─────────────────────────────────────────────────────────────────────────────
# PER-ZONE TIMING TABLE (fine-grained)
# ─────────────────────────────────────────────────────────────────────────────
print(f"{'━'*70}")
print("  RAW ZONE TIMING  (seconds) — BASELINE")
print(f"{'━'*70}")
for zone_n, label in [(2,"Forest Grove"), (3,"Crystal Caves"), (4,"Volcanic Ridge")]:
    key_rate = f"z{zone_n}_reach_rate"
    key_mean = f"z{zone_n}_mean_t_sec"
    key_p25  = f"z{zone_n}_p25_t_sec"
    key_p50  = f"z{zone_n}_p50_t_sec"
    key_p75  = f"z{zone_n}_p75_t_sec"
    mean_val = baseline.get(key_mean) or 0
    p25_val  = baseline.get(key_p25)  or 0
    p50_val  = baseline.get(key_p50)  or 0
    p75_val  = baseline.get(key_p75)  or 0
    print(f"  Zone {zone_n} ({label:<16}) "
          f"reach={fmt_pct(baseline[key_rate])}  "
          f"mean={fmt_t(mean_val)}  "
          f"P25={fmt_t(p25_val)}  "
          f"P50={fmt_t(p50_val)}  "
          f"P75={fmt_t(p75_val)}")

print()
print("[Done]")
