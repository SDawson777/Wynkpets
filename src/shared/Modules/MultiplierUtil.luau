-- MultiplierUtil.luau
-- Calculates a player's effective multipliers from pets, gamepasses, and boosts.

local PetConfig      = require(script.Parent.Parent.Config.PetConfig)
local GamepassConfig = require(script.Parent.Parent.Config.GamepassConfig)
local EconomyConfig  = require(script.Parent.Parent.Config.EconomyConfig)

local MultiplierUtil = {}

-- Returns { coinMult, mineMult, luckMult, mineSpeedBoost } for a player's data.
function MultiplierUtil.calculate(data: {}): {}
    local coinMult       = 1
    local mineMult       = 1
    local luckMult       = 1
    local mineSpeedBoost = 0

    -- ── Rebirth bonus ─────────────────────────────────────────────────────────
    coinMult  = coinMult  + (data.RebirthBonus or 0)
    mineMult  = mineMult  + (data.RebirthBonus or 0)

    -- ── Equipped pets ─────────────────────────────────────────────────────────
    for _, uid in ipairs(data.EquippedPets or {}) do
        -- Find pet instance in inventory
        for _, petInst in ipairs(data.Pets or {}) do
            if petInst.uid == uid then
                local petDef = PetConfig.ById[petInst.petId]
                if petDef then
                    local rarityMults = PetConfig.RarityMultipliers[petDef.rarity]
                    if rarityMults then
                        coinMult = coinMult + rarityMults.coinMult
                        mineMult = mineMult + rarityMults.mineMult
                    end
                end
                break
            end
        end
    end

    -- ── Gamepasses ────────────────────────────────────────────────────────────
    for _, gpId in ipairs(data.OwnedGamepasses or {}) do
        local gp = GamepassConfig.PassById[gpId]
        if gp then
            coinMult       = coinMult       + (gp.effect.coinMult       or 0)
            mineMult       = mineMult       + (gp.effect.mineMult       or 0)
            luckMult       = luckMult       + (gp.effect.luckMult       or 0)
            mineSpeedBoost = mineSpeedBoost + (gp.effect.mineSpeedBoost or 0)
        end
    end

    -- ── Active timed boosts ───────────────────────────────────────────────────
    local now = os.time()
    for _, boost in ipairs(data.ActiveBoosts or {}) do
        if boost.expiresAt > now then
            coinMult       = coinMult       + (boost.coinMult       or 0)
            mineMult       = mineMult       + (boost.mineMult       or 0)
            luckMult       = luckMult       + (boost.luckMult       or 0)
            mineSpeedBoost = mineSpeedBoost + (boost.mineSpeedBoost or 0)
        end
    end

    -- ── Hard caps ─────────────────────────────────────────────────────────────
    coinMult = math.min(coinMult, EconomyConfig.MaxCoinMultiplier)
    mineMult = math.min(mineMult, EconomyConfig.MaxMineMultiplier)

    return {
        coinMult       = coinMult,
        mineMult       = mineMult,
        luckMult       = luckMult,
        mineSpeedBoost = mineSpeedBoost,
    }
end

-- Returns the total number of equip slots available to the player.
function MultiplierUtil.getEquipSlots(data: {}): number
    local slots = PetConfig.BaseEquipSlots
    for _, gpId in ipairs(data.OwnedGamepasses or {}) do
        local gp = GamepassConfig.PassById[gpId]
        if gp and gp.effect.extraPetSlots then
            slots = slots + gp.effect.extraPetSlots
        end
    end
    return math.min(slots, PetConfig.MaxEquipSlots)
end

return MultiplierUtil
