--[[
    Server Entry Point (init.server.luau)
    Initializes all server services in the correct order.
    This is the main server script that boots the game.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

-- Log active launch configuration
print("[LaunchConfig] Phase:", LaunchConfig.Phase)
print("[LaunchConfig] Features:", LaunchConfig.Features)
print("[LaunchConfig] Monetization:", LaunchConfig.Monetization)

-- Initialize network (creates all RemoteEvents/RemoteFunctions)
print("[Server] Initializing Network...")
Network.InitServer()

-- ── RELEASE SCHEDULE: must run first so all service inits see updated flags ──────
local Services = script:WaitForChild("Services")
local ReleaseScheduleService = require(Services:WaitForChild("ReleaseScheduleService"))
ReleaseScheduleService.Init()  -- updates LaunchConfig in-place, no safeInit wrapper needed

-- Load all services
local DataService = require(Services:WaitForChild("DataService"))
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local PetService = require(Services:WaitForChild("PetService"))
local EggService = require(Services:WaitForChild("EggService"))
local ZoneService = require(Services:WaitForChild("ZoneService"))
local RebirthService = require(Services:WaitForChild("RebirthService"))
local GamepassService = require(Services:WaitForChild("GamepassService"))
local ShopService = require(Services:WaitForChild("ShopService"))
local RewardService = require(Services:WaitForChild("RewardService"))
local AdminService = require(Services:WaitForChild("AdminService"))
local AntiExploitService = require(Services:WaitForChild("AntiExploitService"))
local CoinSpawnerService = require(Services:WaitForChild("CoinSpawnerService"))
local PetLevelService = require(Services:WaitForChild("PetLevelService"))
local FuseService = require(Services:WaitForChild("FuseService"))
local TradeService = require(Services:WaitForChild("TradeService"))
local EggSpawnerService = require(Services:WaitForChild("EggSpawnerService"))
local PortalService = require(Services:WaitForChild("PortalService"))
local NPCService = require(Services:WaitForChild("NPCService"))
local WorldBuilderService = require(Services:WaitForChild("WorldBuilderService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local AchievementService = require(Services:WaitForChild("AchievementService"))
local EventService = require(Services:WaitForChild("EventService"))
local PetDisplayService = require(Services:WaitForChild("PetDisplayService"))
local DailyRotationService = require(Services:WaitForChild("DailyRotationService"))
local WheelService = require(Services:WaitForChild("WheelService"))
local ObstacleService = require(Services:WaitForChild("ObstacleService"))
local SpecialEggService = require(Services:WaitForChild("SpecialEggService"))
local SecretService = require(Services:WaitForChild("SecretService"))
local AnalyticsService = require(Services:WaitForChild("AnalyticsService"))
local OfferService = require(Services:WaitForChild("OfferService"))
local LimitedShopService = require(Services:WaitForChild("LimitedShopService"))
local BoostService = require(Services:WaitForChild("BoostService"))
local SubscriptionService = require(Services:WaitForChild("SubscriptionService"))
local EventShopService = require(Services:WaitForChild("EventShopService"))
local NudgeService = require(Services:WaitForChild("NudgeService"))
local StarterPackService = require(Services:WaitForChild("StarterPackService"))
local FirstSessionService = require(Services:WaitForChild("FirstSessionService"))
local OfferManager = require(Services:WaitForChild("OfferManager"))
local PersonalizedOfferService = require(Services:WaitForChild("PersonalizedOfferService"))
local SessionBonusService = require(Services:WaitForChild("SessionBonusService"))
local SessionMilestoneService = require(Services:WaitForChild("SessionMilestoneService"))
local WizardService = require(Services:WaitForChild("WizardService"))
local EventSchedulerService = require(Services:WaitForChild("EventSchedulerService"))
local EvolutionService = require(Services:WaitForChild("EvolutionService"))
local EntitlementService = require(Services:WaitForChild("EntitlementService"))
local MonetizationPromptService = require(Services:WaitForChild("MonetizationPromptService"))
local BattlePassService = require(Services:WaitForChild("BattlePassService"))
local ExpeditionService = require(Services:WaitForChild("ExpeditionService"))

-- Safe init wrapper: logs errors but doesn't halt the chain
local function safeInit(name, func)
    local ok, err = pcall(func)
    if ok then
        print("[Server] " .. name .. " initialized")
    else
        warn("[Server] FAILED to init " .. name .. ": " .. tostring(err))
    end
end

-- Initialize services (order matters: dependencies first)
print("[Server] Initializing Services...")

safeInit("DataService", function() DataService.Init() end)
safeInit("WorldBuilderService", function() WorldBuilderService.Init() end)
safeInit("PetLevelService", function() PetLevelService.Init(DataService) end)
safeInit("AntiExploitService", function() AntiExploitService.Init() end)
safeInit("RewardService", function() RewardService.Init(DataService, CurrencyService) end)
safeInit("CurrencyService", function() CurrencyService.Init(DataService, RewardService, AntiExploitService, PetLevelService) end)
safeInit("PetService", function() PetService.Init(DataService, RewardService, AntiExploitService) end)
safeInit("DailyRotationService", function() DailyRotationService.Init(DataService) end)
safeInit("FuseService", function() FuseService.Init(DataService, CurrencyService, PetService, DailyRotationService, AntiExploitService) end)
safeInit("EggService", function() EggService.Init(DataService, CurrencyService, PetService, RewardService, AntiExploitService, DailyRotationService) end)
safeInit("ZoneService", function() ZoneService.Init(DataService, CurrencyService, RewardService, AntiExploitService) end)
safeInit("RebirthService", function() RebirthService.Init(DataService, CurrencyService, AntiExploitService) end)
safeInit("GamepassService", function() GamepassService.Init(DataService) end)
safeInit("AnalyticsService", function() AnalyticsService.Init(DataService, CurrencyService) end)
safeInit("BoostService", function() BoostService.Init(DataService, AnalyticsService) end)
safeInit("SubscriptionService", function() SubscriptionService.Init(DataService, CurrencyService, AnalyticsService) end)
safeInit("ShopService", function() ShopService.Init(DataService, CurrencyService, AnalyticsService, BoostService, SubscriptionService) end)
safeInit("OfferService", function() OfferService.Init(DataService, CurrencyService, ShopService, AnalyticsService) end)
safeInit("LimitedShopService", function() LimitedShopService.Init(DataService, CurrencyService, AnalyticsService) end)
safeInit("EventShopService", function() EventShopService.Init(DataService, CurrencyService, BoostService, AnalyticsService, PetService) end)
safeInit("NudgeService", function() NudgeService.Init(DataService) end)
safeInit("StarterPackService", function() StarterPackService.Init(DataService, AnalyticsService) end)
safeInit("FirstSessionService", function() FirstSessionService.Init(DataService, CurrencyService, PetService) end)
safeInit("OfferManager", function() OfferManager.Init(DataService, AnalyticsService) end)
safeInit("PersonalizedOfferService", function()
    PersonalizedOfferService.Init(
        DataService, NudgeService, StarterPackService,
        BoostService, OfferManager, AnalyticsService
    )
end)
safeInit("SessionBonusService", function() SessionBonusService.Init(DataService, CurrencyService) end)
safeInit("SessionMilestoneService", function() SessionMilestoneService.Init(DataService, CurrencyService) end)
safeInit("WizardService", function() WizardService.Init(DataService, PetService, CurrencyService) end)
safeInit("EventSchedulerService", function() EventSchedulerService.Init() end)
safeInit("EvolutionService", function() EvolutionService.Init(DataService, PetService, EventSchedulerService, AnalyticsService) end)
safeInit("EntitlementService", function()
    -- EntitlementService has no Init() — it is purely lifecycle-driven.
    -- MonetizationPromptService wires the PromptPassPurchase remote.
end)
safeInit("MonetizationPromptService", function() MonetizationPromptService.Init() end)
safeInit("BattlePassService", function()
    BattlePassService.Init(DataService, CurrencyService, PetService, AnalyticsService)
end)
safeInit("ExpeditionService", function()
    ExpeditionService.Init(DataService, CurrencyService, PetService, PetLevelService)
end)
safeInit("AdminService", function() AdminService.Init(DataService, CurrencyService, PetService, EggService) end)
safeInit("CoinSpawnerService", function() CoinSpawnerService.Init(DataService, CurrencyService, PetLevelService) end)
safeInit("EggSpawnerService", function() EggSpawnerService.Init(EggService) end)
safeInit("PortalService", function() PortalService.Init(DataService, CurrencyService, ZoneService) end)
safeInit("NPCService", function() NPCService.Init() end)
safeInit("TradeService", function() TradeService.Init(DataService, PetService) end)
safeInit("LeaderboardService", function() LeaderboardService.Init(DataService) end)
safeInit("AchievementService", function() AchievementService.Init(DataService, CurrencyService) end)
safeInit("EventService", function() EventService.Init(DataService) end)
safeInit("PetDisplayService", function() PetDisplayService.Init(DataService) end)
safeInit("WheelService", function()
    WheelService.Init(
        DataService,
        CurrencyService,
        AntiExploitService,
        BoostService,
        PetService,
        RewardService,
        AnalyticsService,
        EvolutionService
    )
end)
safeInit("ObstacleService", function() ObstacleService.Init(CurrencyService) end)
safeInit("SpecialEggService", function() SpecialEggService.Init(DataService, PetService, CurrencyService, RewardService) end)
safeInit("SecretService", function() SecretService.Init(DataService, CurrencyService, PetService, EggService, ZoneService, AntiExploitService) end)

-- Late-bind event/rotation into CurrencyService for multiplier stacking
CurrencyService.SetEventService(EventService)
CurrencyService.SetDailyRotationService(DailyRotationService)
CurrencyService.SetNudgeService(NudgeService)
CurrencyService.SetEntitlementService(EntitlementService)
PetLevelService.SetDailyRotationService(DailyRotationService)
PetLevelService.SetPetDisplayService(PetDisplayService)
-- Late-bind SubscriptionService into GamepassService
GamepassService.SetSubscriptionService(SubscriptionService)
GamepassService.SetEntitlementService(EntitlementService)
-- Late-bind SubscriptionService into PetService (ExtraSlot perk)
PetService.SetSubscriptionService(SubscriptionService)
-- Late-bind EntitlementService + MonetizationPromptService
MonetizationPromptService.SetEntitlementService(EntitlementService)
-- Late-bind StarterPackService into ShopService (purchase confirmation loop)
ShopService.SetStarterPackService(StarterPackService)
ShopService.SetPersonalizedOfferService(PersonalizedOfferService)
-- Late-bind EggService into EventShopService (needed for Egg-type shop items)
EventShopService.SetEggService(EggService)
-- Late-bind NudgeService/StarterPackService/PersonalizedOfferService into EggService
EggService.SetNudgeService(NudgeService)
EggService.SetStarterPackService(StarterPackService)
EggService.SetPersonalizedOfferService(PersonalizedOfferService)
-- Late-bind EvolutionService + EventSchedulerService into gameplay services
EggService.SetEvolutionService(EvolutionService)
EggService.SetEventSchedulerService(EventSchedulerService)
EggService.SetEntitlementService(EntitlementService)
RebirthService.SetEvolutionService(EvolutionService)
FuseService.SetEvolutionService(EvolutionService)
RewardService.SetEvolutionService(EvolutionService)
ShopService.SetEvolutionService(EvolutionService)
-- Late-bind CoinSpawnerService into ZoneService (zone cache invalidation)
ZoneService.SetCoinSpawnerService(CoinSpawnerService)

-- Late-bind AnalyticsService into all gameplay services
EggService.SetAnalyticsService(AnalyticsService)
ZoneService.SetAnalyticsService(AnalyticsService)
-- Late-bind MonetizationPromptService into trigger-aware services
EggService.SetMonetizationPromptService(MonetizationPromptService)
ZoneService.SetMonetizationPromptService(MonetizationPromptService)
RebirthService.SetAnalyticsService(AnalyticsService)
GamepassService.SetAnalyticsService(AnalyticsService)
FirstSessionService.SetAnalyticsService(AnalyticsService)
-- Late-bind BattlePassService into XP call-sites
EggService.SetBattlePassService(BattlePassService)
EggService.SetEventShopService(EventShopService)
RewardService.SetBattlePassService(BattlePassService)
RebirthService.SetBattlePassService(BattlePassService)
RebirthService.SetEntitlementService(EntitlementService)

-- Late-bind PersonalizedOfferService into AnalyticsService (session milestone ticker)
AnalyticsService.SetPersonalizedOfferService(PersonalizedOfferService)

-- Hatch progress reward handler
Network.OnServerEvent("ClaimProgressReward", function(player)
    -- Rate-limit: at most one claim per 60 seconds to prevent spam.
    local rData = DataService.GetData(player)
    if not rData then return end
    local now = os.time()
    if (rData.LastProgressRewardTime or 0) + 60 > now then return end
    rData.LastProgressRewardTime = now
    CurrencyService.Add(player, "Gems", 10)
    Network.FireClient("ShowNotification", player, "Progress reward: 10 Gems!", "Success")
end)

print("[Server] All services initialized!")

-- Player join handling
Players.PlayerAdded:Connect(function(player)
    print(string.format("[Server] %s joined (%d)", player.Name, player.UserId))

    -- Load player data
    local dataLoaded = DataService.LoadData(player)

    if dataLoaded then
        AnalyticsService.PlayerAdded(player)

        -- Verify gamepass ownership
        GamepassService.VerifyOwnership(player)
        EntitlementService.PlayerAdded(player)

        -- Process login streak / daily rewards
        RewardService.ProcessLogin(player)
        -- First-session onboarding: gift starter coins, gems, rare pet (once per account)
        FirstSessionService.PlayerAdded(player)
        OfferService.CheckComeback(player)

        -- New services lifecycle
        SubscriptionService.PlayerAdded(player)
        BoostService.PlayerAdded(player)
        EventShopService.PlayerAdded(player)
        NudgeService.PlayerAdded(player)
        StarterPackService.PlayerAdded(player)
        OfferManager.PlayerAdded(player)
        PersonalizedOfferService.PlayerAdded(player)
        BattlePassService.PlayerAdded(player)
        ExpeditionService.PlayerAdded(player)

        -- Send updated data to client AFTER ProcessLogin sets streak/claimed state
        local updatedData = DataService.GetData(player)
        if updatedData then
            Network.FireClient("DailyRewardData", player, {
                LoginStreak = updatedData.LoginStreak,
                DailyRewardClaimed = updatedData.DailyRewardClaimed,
            })
        end

        -- Show equipped pets orbiting player
        PetDisplayService.PlayerAdded(player)

        -- Send daily rotation data
        DailyRotationService.PlayerAdded(player)

        -- Send secret token count
        SecretService.PlayerAdded(player)
        SessionBonusService.PlayerAdded(player)

        -- Send LiveOps schedule + evolution state
        EventSchedulerService.PlayerAdded(player)
        EvolutionService.PlayerAdded(player)
    end

    -- Spawn character
    player.CharacterAdded:Connect(function(character)
        -- Teleport to starter zone (SpawnPosition.Y=5 for all zones; +5 to clear surface)
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
        if humanoidRootPart then
            AntiExploitService.NotifyTeleport(player)
            CoinSpawnerService.SetPlayerZone(player, "starter_meadow")
            humanoidRootPart.CFrame = CFrame.new(0, 10, 0) -- Starter meadow spawn
            print(string.format("[Server] Character spawned at Y=%.1f", humanoidRootPart.Position.Y))
        end
    end)
end)

-- Player leave handling
Players.PlayerRemoving:Connect(function(player)
    print(string.format("[Server] %s leaving (%d)", player.Name, player.UserId))
    DataService.PlayerRemoving(player)
    AnalyticsService.PlayerRemoving(player)
    OfferService.PlayerRemoving(player)
    BoostService.PlayerRemoving(player)
    SubscriptionService.PlayerRemoving(player)
    NudgeService.PlayerRemoving(player)
    StarterPackService.PlayerRemoving(player)
    OfferManager.PlayerRemoving(player)
    PersonalizedOfferService.PlayerRemoving(player)
    BattlePassService.PlayerRemoving(player)
    ExpeditionService.PlayerRemoving(player)
    EggService.PlayerRemoving(player)
    AntiExploitService.PlayerRemoving(player)
    EntitlementService.PlayerRemoving(player)
    MonetizationPromptService.PlayerRemoving(player)
    PortalService.PlayerRemoving(player)
    LeaderboardService.PlayerRemoving(player)
    PetDisplayService.PlayerRemoving(player)
    WheelService.PlayerRemoving(player)
    CoinSpawnerService.PlayerRemoving(player)
    ObstacleService.PlayerRemoving(player)
    SpecialEggService.PlayerRemoving(player)
    SecretService.PlayerRemoving(player)
    SessionBonusService.PlayerRemoving(player)
    EvolutionService.PlayerRemoving(player)
end)

-- Handle players who joined before script loaded
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        local dataLoaded = DataService.LoadData(player)
        if dataLoaded then
            AnalyticsService.PlayerAdded(player)
            GamepassService.VerifyOwnership(player)
            RewardService.ProcessLogin(player)
            OfferService.CheckComeback(player)

            local updatedData = DataService.GetData(player)
            if updatedData then
                Network.FireClient("DailyRewardData", player, {
                    LoginStreak = updatedData.LoginStreak,
                    DailyRewardClaimed = updatedData.DailyRewardClaimed,
                })
            end

            PetDisplayService.PlayerAdded(player)
            DailyRotationService.PlayerAdded(player)
            SecretService.PlayerAdded(player)
        end
    end)
end

print("[Server] Wynkpets server ready!")
