--[[
    EntitlementService.luau
    Single source of truth for permanent gamepass ownership.
    Caches MarketplaceService:UserOwnsGamePassAsync results per-player so every
    downstream service (CurrencyService, EggService, ...) calls HasPass() rather
    than hitting the Roblox API on every tick or reading raw data tables.

    Multiplier helpers:
        GetCoinMultiplier(player)       → 2.0 if "DoubleCoins" else 1.0
        GetHatchCooldown(player)        → 0.25 if "DoubleHatchSpeed" else 0.5
        GetLuckWeightModifiers(player)  → per-rarity weight multiplier table

    Design principals:
        • Server-authoritative — no client can fake entitlement
        • No re-verification spam — refresh happens once on PlayerAdded, once on
          purchase confirm (via GavePass), never client-triggered
        • Safe: all MarketplaceService calls wrapped in pcall
]]

local MarketplaceService = game:GetService("MarketplaceService")
local GamepassConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("GamepassConfig"))
local Network = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Network"))

local EntitlementService = {}

-- Per-player entitlement cache: _cache[player][passId] = bool
local _cache: { [Player]: { [string]: boolean } } = {}

-- ── Constants ────────────────────────────────────────────────────────────────
local BASE_HATCH_COOLDOWN = 0.5  -- seconds
local FAST_HATCH_COOLDOWN = 0.25 -- seconds (50% reduction, minimum clamp)

-- DoubleLuck weight modifiers applied to selectPet() pools.
-- Keys align with RarityConfig tier names.
-- Common is reduced so the overall sum stays normalised after boosting rarer tiers.
local LUCK_MODIFIERS = {
    Common    = 0.70,
    Uncommon  = 1.00,
    Rare      = 1.50,
    Epic      = 2.00,
    Legendary = 3.00,
    Secret    = 5.00,
}

-- ── Internal helpers ─────────────────────────────────────────────────────────

local function ensureCache(player: Player)
    if not _cache[player] then
        _cache[player] = {}
    end
end

-- Refresh ownership for a single passId (pcall-safe).
local function refreshOne(player: Player, gp)
    if not gp.GamepassId or gp.GamepassId <= 0 then return end -- placeholder — skip API call
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.GamepassId)
    end)
    if ok then
        _cache[player][gp.Id] = owns
    end
    -- On failure leave existing cache value untouched (safe default: false on first load)
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- Refresh all pass entitlements for a player (call on PlayerAdded and after purchase).
function EntitlementService.Refresh(player: Player)
    ensureCache(player)
    for _, gp in ipairs(GamepassConfig.Gamepasses) do
        refreshOne(player, gp)
    end
end

--- Server-authoritative: grant a specific pass (called by GamepassService after confirmed purchase).
function EntitlementService.GavePass(player: Player, passId: string)
    ensureCache(player)
    _cache[player][passId] = true
end

--- Returns true if the player owns the pass with the given Id.
function EntitlementService.HasPass(player: Player, passId: string): boolean
    local playerCache = _cache[player]
    if not playerCache then return false end
    return playerCache[passId] == true
end

--- Returns the coin earn multiplier for the player (stacks with other multipliers in CurrencyService).
function EntitlementService.GetCoinMultiplier(player: Player): number
    return EntitlementService.HasPass(player, "DoubleCoins") and 2.0 or 1.0
end

--- Returns the minimum seconds between hatches for the player.
function EntitlementService.GetHatchCooldown(player: Player): number
    return EntitlementService.HasPass(player, "DoubleHatchSpeed") and FAST_HATCH_COOLDOWN or BASE_HATCH_COOLDOWN
end

--- Returns per-rarity weight modifier table for selectPet() when DoubleLuck is owned,
--- or nil if no luck pass is active (caller should skip modifier logic entirely).
function EntitlementService.GetLuckWeightModifiers(player: Player): { [string]: number }?
    if EntitlementService.HasPass(player, "DoubleLuck") then
        return LUCK_MODIFIERS
    end
    return nil
end

--- Returns a flat luck multiplier ≥ 1 for golden/rainbow variant rolls.
--- Used by EggService.determineVariant().
function EntitlementService.GetVariantLuckMultiplier(player: Player): number
    return EntitlementService.HasPass(player, "DoubleLuck") and 1.5 or 1.0
end

--- Returns bonus equip slots granted by gamepass (extra_equip grants +5).
function EntitlementService.GetExtraEquipSlots(player: Player): number
    return EntitlementService.HasPass(player, "extra_equip") and 5 or 0
end

--- Lifecycle: initialise cache slot on join.
function EntitlementService.PlayerAdded(player: Player)
    _cache[player] = {}
    -- Refresh in background so PlayerAdded doesn't block
    task.spawn(function()
        EntitlementService.Refresh(player)
        -- Send ownership snapshot to client so ShopGui can show correct Owned state
        local snapshot = {}
        for passId, owned in pairs(_cache[player] or {}) do
            snapshot[passId] = owned
        end
        Network.FireClient("GamepassStatus", player, snapshot)
    end)
end

--- Lifecycle: clean up on leave.
function EntitlementService.PlayerRemoving(player: Player)
    _cache[player] = nil
end

return EntitlementService
