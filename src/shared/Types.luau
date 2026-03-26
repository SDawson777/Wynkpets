--[[
    Types.luau
    Shared type definitions for Wynkpets
]]

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type PetData = {
    Id: string,
    Name: string,
    Rarity: Rarity,
    Power: number,
    Image: string,
    Golden: boolean,
    Rainbow: boolean,
}

export type OwnedPet = {
    UUID: string,
    PetId: string,
    Equipped: boolean,
    Golden: boolean,
    Rainbow: boolean,
    Level: number,
}

export type EggData = {
    Id: string,
    Name: string,
    Zone: string,
    Cost: number,
    Currency: string,
    HatchTime: number,
    Pets: { { PetId: string, Weight: number } },
}

export type ZoneData = {
    Id: string,
    Name: string,
    Order: number,
    UnlockCost: number,
    UnlockCurrency: string,
    CoinMultiplier: number,
    Description: string,
}

export type GamepassData = {
    Id: string,
    Name: string,
    ProductId: number,
    Price: number,
    Description: string,
    Icon: string,
}

export type DevProductData = {
    Id: string,
    Name: string,
    ProductId: number,
    Price: number,
    Description: string,
    Icon: string,
}

export type QuestData = {
    Id: string,
    Name: string,
    Description: string,
    Type: string,
    Target: number,
    RewardType: string,
    RewardAmount: number,
}

export type PlayerData = {
    Coins: number,
    Gems: number,
    Pets: { OwnedPet },
    EquippedPets: { string },
    UnlockedZones: { string },
    Rebirths: number,
    RebirthMultiplier: number,
    TotalCoinsEarned: number,
    TotalEggsHatched: number,
    TotalPetsCollected: number,
    MaxEquipSlots: number,
    Gamepasses: { [string]: boolean },
    LoginStreak: number,
    LastLogin: number,
    DailyRewardClaimed: boolean,
    Quests: { [string]: number },
    CompletedQuests: { string },
    PetIndex: { string },
    Settings: { [string]: any },
    JoinTime: number,
    PlayTime: number,
    FirstPurchaseClaimed: boolean,
    ActiveBoosts: { [string]: number },
}

export type RebirthTier = {
    Cost: number,
    Multiplier: number,
    BonusEquipSlots: number,
}

return nil
