--[[
    Network.luau
    Centralized network event definitions.
    Creates all RemoteEvents/RemoteFunctions in ReplicatedStorage/Network folder.
    Both server and client reference this module.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = {}

-- All remote event names
Network.Events = {
    -- Currency
    "CurrencyUpdated",           -- Server -> Client: currency changed
    "CollectCoin",               -- Client -> Server: player clicked a coin
    
    -- Pets
    "PetEquipped",               -- Server -> Client: pet equip state changed
    "PetUnequipped",             -- Server -> Client: pet unequipped
    "PetsUpdated",               -- Server -> Client: pet inventory changed
    "EquipPet",                  -- Client -> Server: request equip
    "UnequipPet",                -- Client -> Server: request unequip
    "DeletePet",                 -- Client -> Server: request delete
    "LockPet",                   -- Client -> Server: lock pet (prevent deletion/trade)
    "UnlockPet",                 -- Client -> Server: unlock pet
    "PetLevelUp",               -- Server -> Client: pet leveled up
    "FusePets",                  -- Client -> Server: request pet fusion
    "FuseResult",                -- Server -> Client: fusion result

    -- Eggs / Hatching
    "CollectEgg",                -- Client -> Server: collect egg from field
    "CollectedEggsUpdated",      -- Server -> Client: updated { [eggId] = count }
    "HatchEgg",                  -- Client -> Server: hatch collected egg from inventory
    "HatchResult",               -- Server -> Client: hatch result (pet data)
    "AutoHatchToggle",           -- Client -> Server: toggle auto hatch
    
    -- Zones
    "UnlockZone",                -- Client -> Server: request zone unlock
    "ZoneUnlocked",              -- Server -> Client: zone was unlocked
    "TeleportToZone",            -- Client -> Server: request teleport
    
    -- Rebirth
    "RequestRebirth",            -- Client -> Server: request rebirth
    "RebirthCompleted",          -- Server -> Client: rebirth done
    
    -- Shop / Purchases
    "PurchaseGamepass",          -- Client -> Server: request gamepass purchase
    "PurchaseDevProduct",        -- Client -> Server: request dev product purchase
    "GamepassOwned",             -- Server -> Client: gamepass ownership confirmed
    
    -- Rewards
    "ClaimDailyReward",          -- Client -> Server: claim daily
    "DailyRewardResult",         -- Server -> Client: daily reward result
    "DailyRewardData",           -- Server -> Client: streak data after ProcessLogin
    "QuestUpdated",              -- Server -> Client: quest progress changed
    "ClaimQuestReward",          -- Client -> Server: claim quest reward
    
    -- Data
    "PlayerDataLoaded",          -- Server -> Client: initial data load
    "DataUpdated",               -- Server -> Client: data changed
    
    -- Boosts
    "BoostActivated",            -- Server -> Client: a boost was activated
    "BoostExpired",              -- Server -> Client: a boost expired
    
    -- Admin
    "AdminCommand",              -- Client -> Server: admin command
    
    -- Trading
    "TradeRequest",              -- Client -> Server / Server -> Client: trade request
    "TradeAccepted",             -- Client -> Server / Server -> Client: trade accepted
    "TradeDeclined",             -- Client -> Server: trade declined
    "TradeUpdated",              -- Client -> Server / Server -> Client: offer updated
    "TradeCancelled",            -- Client -> Server / Server -> Client: trade cancelled
    "TradeConfirmed",            -- Client -> Server: confirm trade
    "TradeCompleted",            -- Server -> Client: trade completed

    -- UI Notifications
    "ShowNotification",          -- Server -> Client: show a notification
    "CoinFloatText",             -- Server -> Client: floating coin text above collected coin

    -- NPC interactions (Server -> Client: open GUI)
    "OpenShop",
    "OpenTrade",
    "OpenFuse",
    "OpenRebirth",

    -- Leaderboards
    "RequestLeaderboard",        -- Client -> Server: request leaderboard data
    "LeaderboardData",           -- Server -> Client: leaderboard data

    -- Achievements
    "AchievementUnlocked",       -- Server -> Client: achievement unlocked

    -- Server Events
    "ServerEvent",               -- Server -> Client: event started
    "ServerEventEnded",          -- Server -> Client: event ended
    "RequestActiveEvent",        -- Client -> Server: check active event

    -- Daily Rotation
    "DailyRotation",             -- Server -> Client: today's rotation data
    "RequestDailyRotation",      -- Client -> Server: request current rotation

    -- Engagement
    "ServerAnnouncement",        -- Server -> Client: ticker announcements
    "ClaimProgressReward",       -- Client -> Server: claim hatch progress reward

    -- Special Eggs (rare random spawns)
    "SpecialEggSpawned",         -- Server -> Client: special egg appeared in zone
    "SpecialEggDespawned",       -- Server -> Client: special egg timed out
    "SpecialEggClaimed",         -- Server -> Client: someone claimed it

    -- Obstacles
    "ObstacleHit",               -- Server -> Client: player hit obstacle, show invincibility

    -- Secrets
    "SecretTokenCollected",      -- Server -> Client: token found
    "SecretTokenCount",          -- Server -> Client: current count on login
    "OrbSetCompleted",           -- Server -> Client: player completed a zone orb set, pet unlocked
    "OrbRespawned",              -- Server -> Client: an orb respawned globally
    "OrbSetProgress",            -- Server -> Client: updated per-zone orb collection progress
    "ZoneTeleported",            -- Server -> Client: player was teleported to a zone (for nav bar highlight)

    -- Monetization: Offers
    "OfferShown",                -- Server -> Client: show context-aware offer popup
    "AcceptOffer",               -- Client -> Server: accept an offer
    "DismissOffer",              -- Client -> Server: dismiss offer

    -- Monetization: Limited Shop
    "RequestLimitedShop",        -- Client -> Server: request today's limited items
    "LimitedShopData",           -- Server -> Client: today's limited shop items
    "LimitedShopUpdated",        -- Server -> Client: updated stock after purchase
    "PurchaseLimitedItem",       -- Client -> Server: buy a limited item

    -- Analytics
    "AnalyticsEvent",            -- Client -> Server: client-side telemetry event

    -- Boosts (HUD & refill)
    "BoostsUpdated",             -- Server -> Client: full active boosts snapshot
    "BoostRefillPrompt",         -- Server -> Client: prompt to refill an expiring boost
    "PurchaseBoostRefill",       -- Client -> Server: buy a refill pack directly

    -- Subscription / VIP
    "SubscriptionStatus",        -- Server -> Client: subscription state on load
    "PurchaseSubscription",      -- Client -> Server: prompt subscription gamepass

    -- Event Shop
    "RequestEventShop",          -- Client -> Server: request event shop data
    "EventShopData",             -- Server -> Client: current event shop listings
    "PurchaseEventItem",         -- Client -> Server: buy event shop item
    "EventShopUpdated",          -- Server -> Client: updated after purchase
    "EventCoinUpdated",          -- Server -> Client: player event currency changed

    -- LiveOps event scheduler
    "EventPhaseChanged",         -- Server -> Client: weekly phase/event type changed
    "EventScheduleRequest",      -- Client -> Server: request current schedule
    "EventScheduleData",         -- Server -> Client: full schedule snapshot

    -- Evolution system
    "RequestEvolutionData",      -- Client -> Server: refresh evolution state (on GUI open)
    "EvolutionData",             -- Server -> Client: materials + eligible pets + phase
    "EvolutionMaterialsUpdated", -- Server -> Client: incremental material balance update
    "RequestEvolve",             -- Client -> Server: attempt evolution (uuid, path)
    "EvolveResult",              -- Server -> Client: evolution outcome
    "EvolveIntentRegistered",    -- Server -> Client: paid intent accepted; client opens dev product

    -- Weekly Quests
    "WeeklyQuestUpdated",        -- Server -> Client: weekly quest progress changed
    "ClaimWeeklyQuestReward",    -- Client -> Server: claim weekly quest reward
    "RerollDailyQuest",          -- Client -> Server: spend gems to reroll a quest
    "QuestRerollResult",         -- Server -> Client: new quest after reroll

    -- Nudge System
    "NudgeShown",                -- Server -> Client: show a context nudge (upsell popup)
    "DismissNudge",              -- Client -> Server: dismiss a nudge

    -- Session / comeback
    "SessionMilestone",          -- Server -> Client: milestone reward popup (playtime reward)

    -- Evil Wizard
    "WizardSpawned",             -- Server -> All: wizard appeared (zoneId, zoneName, position)
    "WizardDespawned",           -- Server -> All: wizard vanished (cleared)
    "WizardChasing",             -- Server -> Client: wizard is targeting this player
    "WizardStole",               -- Server -> Client: wizard stole a pet (petName)
    "WizardSurvived",            -- Server -> Client: player survived, bonus coins (amount)

    -- Starter Pack (full-screen modal for new players)
    "StarterOfferShown",         -- Server -> Client: show full-screen starter pack modal
    "StarterOfferDismissed",     -- Client -> Server: player dismissed starter offer
    "StarterOfferPurchased",     -- Server -> Client: starter pack purchase confirmed

    -- First Session (fires exactly once per account on very first join)
    "FirstSessionReward",        -- Server -> Client: { Coins, Gems, PetId, PetUUID }

    -- Near-miss monetization
    "NearMissHatch",             -- Server -> Client: genuine near-miss detected, enhanced animation

    -- Economy pressure
    "SoftShortage",              -- Server -> Client: player is close to affording next action, nudge shop

    -- GamePass system
    "PromptPassPurchase",        -- Client -> Server: request a gamepass purchase prompt
    "GamepassStatus",            -- Server -> Client: full ownership snapshot { [passId]: bool }
    "UpsellTrigger",             -- Server -> Client: debounced contextual upsell (passId, context)

    -- Battle Pass (Season 1: Origins)
    "BattlePassData",           -- Server -> Client: full pass snapshot on join / GUI open
    "BattlePassXPGained",       -- Server -> Client: { XP, Tier, Added, Source }
    "BattlePassTierUp",         -- Server -> Client: { NewTier, Source }
    "RequestBattlePassData",    -- Client -> Server: refresh pass state (GUI open)
    "PurchaseBattlePass",       -- Client -> Server: buy premium track (triggers dev product)

    -- Auto release schedule
    "LaunchFeaturesSnapshot",   -- Server -> Client: { Phase, Features, Monetization } on join / flag change

    -- Pet Expeditions
    "RequestExpeditionData",     -- Client -> Server: request current expedition state
    "ExpeditionData",            -- Server -> Client: full expedition snapshot
    "StartExpedition",           -- Client -> Server: { zoneId, tierId, petUUID }
    "ClaimExpedition",           -- Client -> Server: { slotIndex }
    "SkipExpedition",            -- Client -> Server: { slotIndex } (gem skip)
    "ExpeditionUpdated",         -- Server -> Client: expedition state changed
}

-- All remote function names (for request-response patterns)
Network.Functions = {
    "GetPlayerData",             -- Client -> Server: request full player data
    "GetServerTime",             -- Client -> Server: request server time
}

local networkFolder = nil

-- Initialize all remotes (CALL ON SERVER ONLY)
function Network.InitServer()
    networkFolder = Instance.new("Folder")
    networkFolder.Name = "Network"
    networkFolder.Parent = ReplicatedStorage
    
    local eventsFolder = Instance.new("Folder")
    eventsFolder.Name = "Events"
    eventsFolder.Parent = networkFolder
    
    local functionsFolder = Instance.new("Folder")
    functionsFolder.Name = "Functions"
    functionsFolder.Parent = networkFolder
    
    for _, eventName in ipairs(Network.Events) do
        local remote = Instance.new("RemoteEvent")
        remote.Name = eventName
        remote.Parent = eventsFolder
    end
    
    for _, funcName in ipairs(Network.Functions) do
        local remote = Instance.new("RemoteFunction")
        remote.Name = funcName
        remote.Parent = functionsFolder
    end
    
    return networkFolder
end

-- Wait for network folder (CLIENT)
function Network.WaitForInit()
    networkFolder = ReplicatedStorage:WaitForChild("Network", 30)
    if not networkFolder then
        error("[Network] Failed to find Network folder in ReplicatedStorage")
    end
end

-- Get a RemoteEvent by name
function Network.GetEvent(eventName: string): RemoteEvent
    if not networkFolder then
        networkFolder = ReplicatedStorage:FindFirstChild("Network")
    end
    local eventsFolder = networkFolder and networkFolder:FindFirstChild("Events")
    if eventsFolder then
        return eventsFolder:FindFirstChild(eventName)
    end
    warn("[Network] Event not found: " .. eventName)
    return nil
end

-- Get a RemoteFunction by name
function Network.GetFunction(funcName: string): RemoteFunction
    if not networkFolder then
        networkFolder = ReplicatedStorage:FindFirstChild("Network")
    end
    local functionsFolder = networkFolder and networkFolder:FindFirstChild("Functions")
    if functionsFolder then
        return functionsFolder:FindFirstChild(funcName)
    end
    warn("[Network] Function not found: " .. funcName)
    return nil
end

-- Convenience: Fire event to specific client
function Network.FireClient(eventName: string, player: Player, ...)
    local event = Network.GetEvent(eventName)
    if event then
        event:FireClient(player, ...)
    end
end

-- Convenience: Fire event to all clients
function Network.FireAllClients(eventName: string, ...)
    local event = Network.GetEvent(eventName)
    if event then
        event:FireAllClients(...)
    end
end

-- Convenience: Connect to server event (CLIENT)
function Network.OnClientEvent(eventName: string, callback: (...any) -> ())
    local event = Network.GetEvent(eventName)
    if event then
        return event.OnClientEvent:Connect(callback)
    end
end

-- Convenience: Connect to client event (SERVER)
function Network.OnServerEvent(eventName: string, callback: (Player, ...any) -> ())
    local event = Network.GetEvent(eventName)
    if event then
        return event.OnServerEvent:Connect(callback)
    end
end

-- Convenience: Fire event to server (CLIENT)
function Network.FireServer(eventName: string, ...)
    local event = Network.GetEvent(eventName)
    if event then
        event:FireServer(...)
    end
end

return Network
