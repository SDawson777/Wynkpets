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
    GoldenImage: string?,
    RainbowImage: string?,
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
    MutationId: string?,
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
    MaxPetStorage: number,
    Gamepasses: { [string]: boolean },
    LoginStreak: number,
    LoginDays: number,
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
    BoostInventory: { [string]: number },
    BoostExpiry: number,
    SpecialEggsClaimed: number,
    SecretTokens: { [string]: boolean },
    SecretTokensCount: number,
    OffersClaimed: { [string]: boolean },
    LimitedPurchases: { [string]: any },
    Consumables: { [string]: number },
    Materials: { [string]: number },
    TotalRobuxSpent: number,
    AnalyticsSummary: { [string]: number },
    Achievements: { [string]: any },
    TradesCompleted: number,
    PetsFused: number,
    WheelSpins: number,
    Wheel: {
        LastFreeSpinDay: string,
        FreeSpinsUsedToday: number,
        PaidSpinsAvailable: number,
        TotalSpins: number,
    },
    -- Subscription / VIP
    SubscriptionExpiry: number,
    SubscriptionTier: string,
    -- Weekly quests
    WeeklyQuests: { [string]: { Progress: number, Completed: boolean, Claimed: boolean } },
    WeeklyQuestReset: number,
    WeeklyBonusClaimed: boolean?,
    DailyQuestRerolls: number,
    DailyQuestRerollReset: number,
    -- Event shop
    EventCoins: number,
    EventProgress: { [string]: any },
    EventPurchases: { [string]: number },
    -- Session milestones
    SessionMilestonesClaimed: { [number]: boolean },
    -- Purchase history
    PurchaseHistory: { any },
    -- Starter pack
    StarterPackShownAt: number,
    StarterPackPurchased: boolean,
    -- First-session onboarding
    FirstSessionClaimed: boolean,
    -- Pet Expeditions
    Expeditions: {
        Active: { {
            SlotIndex: number,
            ZoneId: string,
            TierId: string,
            PetUUID: string,
            PetPower: number,
            StartTime: number,
            Duration: number,
        } },
        Completed: number,
    },
    -- Collected Eggs (field collection → hatchery hatching)
    CollectedEggs: { [string]: number },  -- { [eggId] = count }
    Version: number,
}

export type RebirthTier = {
    Cost: number,
    Multiplier: number,
    BonusEquipSlots: number,
}

return nil
