-- RemoteConfig.luau
-- Centralised list of all RemoteEvent and RemoteFunction names.
-- Server init creates them; clients reference them by name from here.

local RemoteConfig = {}

-- ─── RemoteEvents (fire-and-forget) ──────────────────────────────────────────
RemoteConfig.Events = {
    -- Mining
    "MineRock",           -- Client → Server: player hit a rock
    "RockBroken",         -- Server → Client: rock fully mined (gives loot)
    "OreAdded",           -- Server → Client: ore added to inventory

    -- Economy
    "SellOres",           -- Client → Server: sell all ores
    "CoinsUpdated",       -- Server → Client: updated coin balance
    "GemsUpdated",        -- Server → Client: updated gem balance

    -- Pets / Eggs
    "HatchEgg",           -- Client → Server: hatch one egg
    "PetHatched",         -- Server → Client: pet result
    "EquipPet",           -- Client → Server: equip/unequip pet
    "PetsUpdated",        -- Server → Client: full pet inventory sync
    "ReleasePet",         -- Client → Server: release (delete) a pet

    -- Shop / Gamepasses
    "PurchaseShopItem",   -- Client → Server: buy shop item
    "PurchaseResult",     -- Server → Client: success or failure message
    "ActiveBoostsUpdated",-- Server → Client: current active timed boosts

    -- World
    "UnlockWorld",        -- Client → Server: request to unlock a world
    "WorldUnlocked",      -- Server → Client: confirmation + new world data

    -- Rebirth
    "RequestRebirth",     -- Client → Server
    "RebirthCompleted",   -- Server → Client: new rebirth count + bonuses

    -- Quests
    "QuestsUpdated",      -- Server → Client: refreshed quest list
    "QuestCompleted",     -- Server → Client: a quest was completed

    -- Data
    "DataLoaded",         -- Server → Client: initial player data ready
    "DataSaved",          -- Server → Client: periodic save confirmation

    -- Daily reward
    "ClaimDailyReward",   -- Client → Server
    "DailyRewardResult",  -- Server → Client: reward payload or "already claimed"

    -- Trading
    "SendTradeRequest",   -- Client → Server: initiate trade
    "TradeRequestReceived",-- Server → Client: trade invite
    "TradeUpdate",        -- Server ↔ Client: trade state changes
    "TradeCompleted",     -- Server → Client: trade finalised
    "TradeCancelled",     -- Server → Client: trade cancelled

    -- Admin
    "AdminCommand",       -- Client → Server (admin only)
}

-- ─── RemoteFunctions (request-response) ──────────────────────────────────────
RemoteConfig.Functions = {
    "GetPlayerData",      -- Client → Server: returns full player data snapshot
    "GetLeaderboard",     -- Client → Server: returns top-N leaderboard
}

return RemoteConfig
