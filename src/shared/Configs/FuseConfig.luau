--[[
    FuseConfig.luau
    Defines pet fusing rules and costs.
]]

local FuseConfig = {}

-- Number of pets required to fuse
FuseConfig.RequiredPets = 3

-- Fuse 3 normal -> 1 golden (same pet)
-- Fuse 3 golden -> 1 rainbow (same pet)
-- Fuse 3 same-rarity -> chance at next rarity tier

-- Coin cost per rarity tier
FuseConfig.CoinCost = {
    Common = 500,
    Rare = 2000,
    Epic = 10000,
    Legendary = 50000,
    Mythic = 250000,
    Secret = 1000000,
}

-- Chance to upgrade to next rarity when fusing 3 same-rarity pets
FuseConfig.RarityUpgradeChance = 0.25 -- 25%

-- Rarity order for upgrades
FuseConfig.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

function FuseConfig.GetNextRarity(currentRarity: string): string?
    for i, rarity in ipairs(FuseConfig.RarityOrder) do
        if rarity == currentRarity and i < #FuseConfig.RarityOrder then
            return FuseConfig.RarityOrder[i + 1]
        end
    end
    return nil
end

function FuseConfig.GetCost(rarity: string): number
    return FuseConfig.CoinCost[rarity] or 1000
end

return FuseConfig
