--[[
    RebirthConfig.luau
    Rebirth/prestige tiers and requirements
]]

local RebirthConfig = {}

-- Each rebirth tier: cost to rebirth, permanent multiplier gained, bonus equip slots
RebirthConfig.Tiers = {
    { Level = 1,  Cost = 10000,            Multiplier = 1.5,   BonusEquipSlots = 1 },
    { Level = 2,  Cost = 50000,            Multiplier = 2.0,   BonusEquipSlots = 1 },
    { Level = 3,  Cost = 200000,           Multiplier = 3.0,   BonusEquipSlots = 2 },
    { Level = 4,  Cost = 750000,           Multiplier = 4.0,   BonusEquipSlots = 2 },
    { Level = 5,  Cost = 2500000,          Multiplier = 5.5,   BonusEquipSlots = 3 },
    { Level = 6,  Cost = 8000000,          Multiplier = 7.0,   BonusEquipSlots = 3 },
    { Level = 7,  Cost = 25000000,         Multiplier = 9.0,   BonusEquipSlots = 4 },
    { Level = 8,  Cost = 75000000,         Multiplier = 12.0,  BonusEquipSlots = 4 },
    { Level = 9,  Cost = 200000000,        Multiplier = 15.0,  BonusEquipSlots = 5 },
    { Level = 10, Cost = 500000000,        Multiplier = 20.0,  BonusEquipSlots = 5 },
    { Level = 11, Cost = 1000000000,       Multiplier = 25.0,  BonusEquipSlots = 6 },
    { Level = 12, Cost = 2500000000,       Multiplier = 30.0,  BonusEquipSlots = 6 },
    { Level = 13, Cost = 5000000000,       Multiplier = 36.0,  BonusEquipSlots = 7 },
    { Level = 14, Cost = 10000000000,      Multiplier = 42.0,  BonusEquipSlots = 7 },
    { Level = 15, Cost = 25000000000,      Multiplier = 50.0,  BonusEquipSlots = 8 },
    { Level = 16, Cost = 50000000000,      Multiplier = 58.0,  BonusEquipSlots = 8 },
    { Level = 17, Cost = 100000000000,     Multiplier = 66.0,  BonusEquipSlots = 9 },
    { Level = 18, Cost = 250000000000,     Multiplier = 74.0,  BonusEquipSlots = 9 },
    { Level = 19, Cost = 500000000000,     Multiplier = 82.0,  BonusEquipSlots = 10 },
    { Level = 20, Cost = 1000000000000,    Multiplier = 90.0,  BonusEquipSlots = 10 },
    { Level = 21, Cost = 5000000000000,    Multiplier = 100.0, BonusEquipSlots = 11 },
    { Level = 22, Cost = 10000000000000,   Multiplier = 120.0, BonusEquipSlots = 11 },
    { Level = 23, Cost = 25000000000000,   Multiplier = 150.0, BonusEquipSlots = 12 },
    { Level = 24, Cost = 50000000000000,   Multiplier = 200.0, BonusEquipSlots = 12 },
    { Level = 25, Cost = 100000000000000,  Multiplier = 300.0, BonusEquipSlots = 13 },
}

-- What gets reset on rebirth
RebirthConfig.ResetOnRebirth = {
    "Coins",           -- Coins reset to 0
    "UnlockedZones",   -- Zones re-lock (except starter)
}

-- What is kept on rebirth
RebirthConfig.KeptOnRebirth = {
    "Gems",
    "Pets",
    "EquippedPets",
    "Gamepasses",
    "PetIndex",
    "Rebirths",
    "RebirthMultiplier",
    "MaxEquipSlots",
    "TotalCoinsEarned",
    "TotalEggsHatched",
    "TotalPetsCollected",
}

-- Base equip slots
RebirthConfig.BaseEquipSlots = 3

function RebirthConfig.GetTier(level: number)
    for _, tier in ipairs(RebirthConfig.Tiers) do
        if tier.Level == level then
            return tier
        end
    end
    return nil
end

function RebirthConfig.GetNextTier(currentRebirths: number)
    return RebirthConfig.GetTier(currentRebirths + 1)
end

function RebirthConfig.GetTotalEquipSlots(rebirths: number): number
    local total = RebirthConfig.BaseEquipSlots
    for _, tier in ipairs(RebirthConfig.Tiers) do
        if tier.Level <= rebirths then
            total = total + tier.BonusEquipSlots
        end
    end
    return total
end

return RebirthConfig
