--[[
    EggService.luau
    Handles egg hatching with weighted random selection.
    Server-authoritative: validates cost, zone access, and determines results.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EggConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local GamepassConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GamepassConfig"))
local DailyRotationConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DailyRotationConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService -- Forward declarations
local CurrencyService
local PetService
local RewardService
local AntiExploitService
local DailyRotationService
local NudgeService          -- set via EggService.SetNudgeService
local StarterPackService    -- set via EggService.SetStarterPackService
local PersonalizedOfferService -- set via EggService.SetPersonalizedOfferService
local EvolutionService      -- set via EggService.SetEvolutionService
local EventSchedulerService -- set via EggService.SetEventSchedulerService
local EntitlementService    -- set via EggService.SetEntitlementService
local AnalyticsService          -- set via EggService.SetAnalyticsService
local MonetizationPromptService -- set via EggService.SetMonetizationPromptService
local BattlePassService         -- set via EggService.SetBattlePassService
local EventShopService          -- set via EggService.SetEventShopService

local EggService = {}

-- Rate limiting per player
local lastHatchTime = {} -- [Player] = tick
local HATCH_COOLDOWN = 0.5 -- Minimum seconds between hatches
local autoHatchPlayers = {} -- [Player] = { enabled: boolean, eggId: string }
local autoHatchBusy = {}   -- [Player] = true when a hatch/collect task is in-flight

-- ── Monetization trigger tracking ────────────────────────────────────────────
-- Ring buffer: last 10 hatch rarities per player for bad-streak detection.
local _hatchHistory: { [Player]: { string } } = {}
local HISTORY_SIZE    = 10   -- sliding window length
local COMMON_STREAK   = 8    -- ≥ N commons out of HISTORY_SIZE → DoubleLuck prompt
-- Timestamps of completed hatch batches for rapid-fire speed detection.
local _hatchTimes: { [Player]: { number } } = {}
local SPEED_WINDOW    = 30   -- seconds
local SPEED_THRESHOLD = 5    -- hatch batches within SPEED_WINDOW → DoubleHatchSpeed prompt
-- Coin shortage UpsellTrigger: debounced 3 minutes so new players aren't spammed
local _coinShortageCooldown: { [Player]: number } = {}
local COIN_SHORTAGE_UPSELL_CD = 180

-- Select a pet from an egg's hatch table using weighted random
-- Returns: petId (string), nearMissRarity (string?) — genuine near-miss based on RNG
-- luckMultiplier: scalar ≥ 1 (event/boost-based)
-- luckModifiers:  per-rarity weight modifier table from EntitlementService (DoubleLuck pass) or nil
local function selectPet(egg, luckMultiplier: number, luckModifiers: { [string]: number }?): (string, string?)
    local pets = egg.Pets
    if not pets or #pets == 0 then
        return nil
    end

    -- Get today's featured pet IDs for weight boost
    local featuredIds = {}
    if DailyRotationService then
        featuredIds = DailyRotationService.GetFeaturedPetIds()
    end
    local featuredMultiplier = DailyRotationConfig.FeaturedWeightMultiplier or 2.0

    -- Apply luck multiplier and featured pet boost
    local adjustedPets = {}
    local totalWeight = 0

    for _, entry in ipairs(pets) do
        local petInfo = PetConfig.GetPet(entry.PetId)
        local weight = entry.Weight

        if petInfo and luckMultiplier > 1 then
            local rarityOrder = RarityConfig.Tiers[petInfo.Rarity] and RarityConfig.Tiers[petInfo.Rarity].Order or 1
            if rarityOrder >= 3 then -- Epic or higher
                weight = weight * luckMultiplier
            end
        end

        -- DoubleLuck pass: per-rarity weight modifier (boosts Rare+, reduces Common)
        if petInfo and luckModifiers then
            local modifier = luckModifiers[petInfo.Rarity]
            if modifier then
                weight = weight * modifier
            end
        end

        -- Featured pet daily boost
        if featuredIds[entry.PetId] then
            weight = weight * featuredMultiplier
        end

        table.insert(adjustedPets, { PetId = entry.PetId, Weight = weight })
        totalWeight = totalWeight + weight
    end

    -- Weighted random selection
    local roll = math.random() * totalWeight
    local cumulative = 0
    local selectedPetId = nil

    for _, entry in ipairs(adjustedPets) do
        cumulative = cumulative + entry.Weight
        if not selectedPetId and roll <= cumulative then
            selectedPetId = entry.PetId
        end
    end

    -- Fallback to last pet
    if not selectedPetId then
        selectedPetId = adjustedPets[#adjustedPets].PetId
    end

    -- ── Genuine near-miss detection ───────────────────────────────────────────
    -- Simulate a 15% luckier roll (roll * 0.85) and check if it would have
    -- selected a Legendary+ pet instead. If so, signal a near-miss.
    local nearMissRarity = nil
    local selectedInfo = PetConfig.GetPet(selectedPetId)
    local selectedOrder = selectedInfo
        and RarityConfig.Tiers[selectedInfo.Rarity]
        and RarityConfig.Tiers[selectedInfo.Rarity].Order or 1

    if selectedOrder <= 2 then
        -- Near-miss: fires when the roll landed within 15% of totalWeight below
        -- the lower weight-boundary of the first Legendary+ pet in the pool.
        -- Replaces the old "roll * 0.85" approach which was mathematically
        -- impossible to trigger on eggs where Legendary weight is < 15% of total.
        local NEAR_MISS_WINDOW = totalWeight * 0.15
        local cumCheck = 0
        for _, entry in ipairs(adjustedPets) do
            cumCheck = cumCheck + entry.Weight
            local entryInfo = PetConfig.GetPet(entry.PetId)
            local entryOrder = entryInfo
                and RarityConfig.Tiers[entryInfo.Rarity]
                and RarityConfig.Tiers[entryInfo.Rarity].Order or 1
            if entryOrder >= 4 then
                -- lowerBound is the cumulative weight just before this Legendary+ entry
                local lowerBound = cumCheck - entry.Weight
                if roll >= (lowerBound - NEAR_MISS_WINDOW) then
                    nearMissRarity = entryInfo.Rarity
                end
                break  -- only check the first (lowest-rarity) Legendary+ pet
            end
        end
    end

    return selectedPetId, nearMissRarity
end

-- Select a Rare+ pet from the egg pool (pity fallback for new-player guarantee).
-- Returns nil if the egg has no pets of at least minOrder rarity (rare edge case).
local function selectPetMinRarity(egg, minOrder: number): string?
    local pool = {}
    local totalWeight = 0
    for _, entry in ipairs(egg.Pets) do
        local petInfo = PetConfig.GetPet(entry.PetId)
        if petInfo then
            local order = RarityConfig.Tiers[petInfo.Rarity]
                and RarityConfig.Tiers[petInfo.Rarity].Order or 1
            if order >= minOrder then
                table.insert(pool, { PetId = entry.PetId, Weight = entry.Weight })
                totalWeight = totalWeight + entry.Weight
            end
        end
    end
    if #pool == 0 or totalWeight == 0 then return nil end
    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(pool) do
        cumulative = cumulative + entry.Weight
        if roll <= cumulative then return entry.PetId end
    end
    return pool[#pool].PetId
end

-- Determine if pet should be golden or rainbow.
-- goldenMult / rainbowMult are applied during ShinyAuraSurge events.
local function determineVariant(luckMultiplier: number, goldenMult: number?, rainbowMult: number?): (boolean, boolean)
    local golden = false
    local rainbow = false

    local rainbowChance = RarityConfig.RainbowChance * luckMultiplier * (rainbowMult or 1.0)
    local goldenChance = RarityConfig.GoldenChance * luckMultiplier * (goldenMult or 1.0)

    if math.random() < rainbowChance then
        rainbow = true
    elseif math.random() < goldenChance then
        golden = true
    end

    return golden, rainbow
end

-- Get player's luck multiplier (from boosts, gamepasses)
local function getLuckMultiplier(player: Player): number
    local data = DataService.GetData(player)
    if not data then return 1 end

    local multiplier = 1.0

    -- Luck boost (player-specific timed boost)
    if data.ActiveBoosts and data.ActiveBoosts["Luck"] then
        if data.ActiveBoosts["Luck"] > os.time() then
            multiplier = multiplier * 2.0
        end
    end

    -- Daily rotation Luck theme boost
    if DailyRotationService then
        local theme = DailyRotationService.GetDailyTheme()
        if theme and theme.BoostType == "Luck" then
            multiplier = multiplier * theme.BoostMultiplier
        end
    end

    return math.min(multiplier, 8.0)
end

-- Return per-rarity weight modifiers for DoubleLuck pass (or nil if not owned).
local function getLuckWeightModifiers(player: Player): { [string]: number }?
    if EntitlementService then
        return EntitlementService.GetLuckWeightModifiers(player)
    end
    return nil
end

-- Return the minimum hatch cooldown for the player (DoubleHatchSpeed halves it).
local function getHatchCooldown(player: Player): number
    if EntitlementService then
        return EntitlementService.GetHatchCooldown(player)
    end
    return HATCH_COOLDOWN
end

-- Get hatch count based on gamepasses
local function getHatchCount(player: Player): number
    if not LaunchConfig.IsMonetizationEnabled("AdvancedPasses") then return 1 end
    if EntitlementService and EntitlementService.HasPass(player, "triple_hatch") then
        return 3
    end
    return 1
end

-- Collect an egg from the field (deducts currency, adds to inventory)
function EggService.CollectEgg(player: Player, eggId: string)
    -- Rate limit
    local now = tick()
    if lastHatchTime[player] and (now - lastHatchTime[player]) < getHatchCooldown(player) then
        return
    end
    lastHatchTime[player] = now

    -- Validate egg exists
    local egg = EggConfig.GetEgg(eggId)
    if not egg then
        warn("[EggService] Unknown egg: " .. tostring(eggId))
        return
    end

    local data = DataService.GetData(player)
    if not data then return end

    -- Validate zone access
    local hasZoneAccess = false
    for _, zoneId in ipairs(data.UnlockedZones or {}) do
        if zoneId == egg.Zone then
            hasZoneAccess = true
            break
        end
    end
    if not hasZoneAccess then
        Network.FireClient("ShowNotification", player, "You need to unlock this zone first!", "Warning")
        return
    end

    -- Roblox compliance: check ArePaidRandomItemsRestricted for Robux-priced eggs.
    if egg.Currency == "Robux" or egg.PaidWithRobux then
        local PolicyService = game:GetService("PolicyService")
        local ok, policy = pcall(function()
            return PolicyService:GetPolicyInfoForPlayerAsync(player)
        end)
        if ok and policy.ArePaidRandomItemsRestricted then
            Network.FireClient("ShowNotification", player,
                "Paid eggs are not available in your region.", "Warning")
            return
        end
    end

    -- Check and deduct currency (single egg cost — no triple multiplier on collection)
    local cost = egg.Cost
    if not CurrencyService.CanAfford(player, egg.Currency, cost) then
        Network.FireClient("ShowNotification", player, "Not enough " .. egg.Currency .. "!", "Warning")
        -- Coin shortage monetization trigger
        if egg.Currency == "Coins" and MonetizationPromptService then
            MonetizationPromptService.TriggerPrompt(player, "DoubleCoins")
            local cooldownNow = tick()
            local last = _coinShortageCooldown[player]
            if not last or (cooldownNow - last) >= COIN_SHORTAGE_UPSELL_CD then
                _coinShortageCooldown[player] = cooldownNow
                Network.FireClient("UpsellTrigger", player, "coin_boost")
            end
        end
        return
    end

    CurrencyService.Remove(player, egg.Currency, cost)

    -- Add egg to collected inventory
    if not data.CollectedEggs then data.CollectedEggs = {} end
    data.CollectedEggs[eggId] = (data.CollectedEggs[eggId] or 0) + 1

    -- Notify client
    Network.FireClient("CollectedEggsUpdated", player, data.CollectedEggs)
    Network.FireClient("ShowNotification", player, "Collected " .. egg.Name .. "!", "Success")

    -- Analytics
    if AnalyticsService then
        AnalyticsService.TrackHatch(player, eggId, "collected", "Collected")
    end
end

-- Hatch an egg from collected inventory (main function)
function EggService.HatchEgg(player: Player, eggId: string)
    -- Rate limit (per-player cooldown respects DoubleHatchSpeed pass)
    local now = tick()
    if lastHatchTime[player] and (now - lastHatchTime[player]) < getHatchCooldown(player) then
        return
    end
    lastHatchTime[player] = now

    -- Validate egg exists
    local egg = EggConfig.GetEgg(eggId)
    if not egg then
        warn("[EggService] Unknown egg: " .. tostring(eggId))
        return
    end

    local data = DataService.GetData(player)
    if not data then return end

    -- Determine how many to hatch (triple hatch hatches up to 3 from inventory)
    local hatchCount = getHatchCount(player)

    -- Consume eggs from collected inventory
    if not data.CollectedEggs then data.CollectedEggs = {} end
    local available = data.CollectedEggs[eggId] or 0
    if available <= 0 then
        Network.FireClient("ShowNotification", player, "You don't have any " .. egg.Name .. " to hatch!", "Warning")
        return
    end
    -- Clamp hatch count to available eggs
    hatchCount = math.min(hatchCount, available)
    data.CollectedEggs[eggId] = available - hatchCount
    if data.CollectedEggs[eggId] <= 0 then
        data.CollectedEggs[eggId] = nil
    end

    -- Notify client of updated inventory
    Network.FireClient("CollectedEggsUpdated", player, data.CollectedEggs)

    -- Record this hatch batch timestamp for speed-trigger tracking
    do
        local now = tick()
        local times = _hatchTimes[player] or {}
        table.insert(times, now)
        -- Prune entries outside the detection window
        local pruned = {}
        for _, t in ipairs(times) do
            if (now - t) <= SPEED_WINDOW then
                table.insert(pruned, t)
            end
        end
        _hatchTimes[player] = pruned
    end

    -- Determine results
    local luckMultiplier = getLuckMultiplier(player)
    -- Featured egg luck bonus from LiveOps calendar
    if EventSchedulerService then
        luckMultiplier = luckMultiplier * (1 + EventSchedulerService.GetFeaturedEggBonus(eggId))
    end
    -- DoubleLuck pass: per-rarity weight modifiers (nil if pass not owned)
    local luckModifiers = getLuckWeightModifiers(player)
    -- Variant luck multiplier for golden/rainbow rolls (DoubleLuck also boosts these)
    local variantLuckMult = EntitlementService and EntitlementService.GetVariantLuckMultiplier(player) or 1.0
    -- Shiny/Aura surge multipliers (applied once per batch, not per roll)
    local gMult = (EventSchedulerService and EventSchedulerService.GetGoldenMultiplier() or 1.0) * variantLuckMult
    local rMult = (EventSchedulerService and EventSchedulerService.GetRainbowMultiplier() or 1.0) * variantLuckMult
    -- Pity guarantee: first 5 hatch batches are guaranteed Rare+ to hook new players.
    -- Captured before the loop because TotalEggsHatched is updated at the end.
    local preBatchHatches = data.TotalEggsHatched or 0
    local results = {}
    local anyNearMissRarity = nil  -- track first genuine near-miss across batch

    for _ = 1, hatchCount do
        local petId, nearMissRarity = selectPet(egg, luckMultiplier, luckModifiers)
        -- Pity: if this is one of the first 5 hatch batches and result is below Rare,
        -- re-select from Rare+ pool only (keeps the same loot table feel).
        if preBatchHatches < 5 then
            local petInfo = petId and PetConfig.GetPet(petId)
            local order = petInfo and RarityConfig.Tiers[petInfo.Rarity]
                and RarityConfig.Tiers[petInfo.Rarity].Order or 1
            if order < 2 then
                petId = selectPetMinRarity(egg, 2) or petId
            end
        end
        if nearMissRarity and not anyNearMissRarity then
            anyNearMissRarity = nearMissRarity
        end
        if petId then
            local golden, rainbow = determineVariant(luckMultiplier, gMult, rMult)
            local newPet = PetService.AddPet(player, petId, golden, rainbow)
            if newPet then
                local petInfo = PetConfig.GetPet(petId)
                table.insert(results, {
                    UUID = newPet.UUID,
                    PetId = petId,
                    Name = petInfo and petInfo.Name or petId,
                    Rarity = petInfo and petInfo.Rarity or "Common",
                    Power = petInfo and petInfo.Power or 1,
                    Golden = golden,
                    Rainbow = rainbow,
                })

                -- Track hatch analytics
                if AnalyticsService then
                    AnalyticsService.TrackHatch(player, eggId, petId, petInfo and petInfo.Rarity or "Common")
                end

                -- Server-wide announcement for rare+ hatches (social proof)
                if petInfo then
                    local rarityOrder = RarityConfig.Tiers[petInfo.Rarity] and RarityConfig.Tiers[petInfo.Rarity].Order or 1
                    if rarityOrder >= 4 or golden or rainbow then
                        local variant = rainbow and " RAINBOW " or (golden and " GOLDEN " or " ")
                        local msg = player.Name .. " hatched a" .. variant .. petInfo.Rarity .. " " .. petInfo.Name .. "!"
                        Network.FireAllClients("ShowNotification", msg, "Hatch")
                        Network.FireAllClients("ServerAnnouncement", msg)
                    end
                end
                -- Award Wynk Shards for evolution system
                if EvolutionService then
                    local rarity = petInfo and petInfo.Rarity or "Common"
                    EvolutionService.TryAwardShards(player, "Hatch", rarity)
                end
            end
        end
    end

    -- Update stats
    data.TotalEggsHatched = (data.TotalEggsHatched or 0) + hatchCount

    -- Event shop task progress: track egg hatches for event quests
    if EventShopService and #results > 0 then
        EventShopService.TrackAction(player, "HatchEggs", hatchCount)
    end

    -- Battle Pass XP: 100 XP per hatch batch
    if BattlePassService and #results > 0 then
        BattlePassService.AddXP(player, hatchCount * 100, "hatch")
    end

    -- ── Hatch-pattern monetization triggers ───────────────────────────────────
    if MonetizationPromptService and #results > 0 then
        -- Update rarity history ring buffer
        local history = _hatchHistory[player] or {}
        for _, result in ipairs(results) do
            table.insert(history, result.Rarity)
            if #history > HISTORY_SIZE then
                table.remove(history, 1)
            end
        end
        _hatchHistory[player] = history

        -- Bad-luck streak: ≥ COMMON_STREAK commons in the last HISTORY_SIZE hatches
        if #history >= HISTORY_SIZE then
            local commonCount = 0
            for _, rarity in ipairs(history) do
                if rarity == "Common" then
                    commonCount += 1
                end
            end
            if commonCount >= COMMON_STREAK then
                MonetizationPromptService.TriggerPrompt(player, "DoubleLuck")
            end
        end

        -- Rapid-fire trigger: ≥ SPEED_THRESHOLD batches within SPEED_WINDOW seconds
        if _hatchTimes[player] and #_hatchTimes[player] >= SPEED_THRESHOLD then
            MonetizationPromptService.TriggerPrompt(player, "DoubleHatchSpeed")
        end
    end

    -- Featured egg hatch milestone (LiveOps calendar tracker)
    if EvolutionService and #results > 0 then
        EvolutionService.OnFeaturedEggHatched(player, eggId)
    end

    -- ── Monetization hooks ────────────────────────────────────────────────────
    -- Genuine near-miss: trigger luck boost nudge
    if anyNearMissRarity and NudgeService then
        NudgeService.Trigger(player, "near_rare", { Rarity = anyNearMissRarity })
        -- DoubleLuck upsell: if near-miss was Legendary/Secret and player doesn't own it
        local nearMissOrder = RarityConfig.Tiers[anyNearMissRarity] and RarityConfig.Tiers[anyNearMissRarity].Order or 1
        if nearMissOrder >= 4 and EntitlementService and not EntitlementService.HasPass(player, "DoubleLuck") then
            Network.FireClient("UpsellTrigger", player, "DoubleLuck")
        end
    end

    -- Legendary+ hatch: upsell Luck Boost while excitement is high
    if NudgeService then
        for _, result in ipairs(results) do
            local rarityOrder = RarityConfig.Tiers[result.Rarity] and RarityConfig.Tiers[result.Rarity].Order or 1
            if rarityOrder >= 4 then
                NudgeService.Trigger(player, "rare_hatch", { Rarity = result.Rarity })
                break
            end
        end
    end

    -- First hatch ever: show starter pack and welcome nudge
    if data.TotalEggsHatched == hatchCount and StarterPackService then
        -- TotalEggsHatched was 0 before this hatch (hatchCount was just added)
        StarterPackService.OnFirstHatch(player)
        if NudgeService then
            NudgeService.Trigger(player, "first_hatch")
        end
    end

    -- Personalized offer engine: track hatch batch
    if PersonalizedOfferService then
        local resultsSummary = {}
        for _, r in ipairs(results) do
            local ro = RarityConfig.Tiers[r.Rarity] and RarityConfig.Tiers[r.Rarity].Order or 1
            table.insert(resultsSummary, { RarityOrder = ro })
        end
        PersonalizedOfferService.OnHatch(player, resultsSummary)
    end

    -- Track quest progress
    if RewardService then
        RewardService.UpdateQuestProgress(player, "HatchEggs", hatchCount)
        -- Check for rare+ hatches
        for _, result in ipairs(results) do
            local rarityOrder = RarityConfig.Tiers[result.Rarity] and RarityConfig.Tiers[result.Rarity].Order or 1
            if rarityOrder >= 2 then -- Rare or better
                RewardService.UpdateQuestProgress(player, "HatchRarity", 1)
            end
        end
    end

    -- Send results to client for animation
    if #results > 0 then
        -- Near-miss psychology: prefer genuine near-miss if detected,
        -- otherwise fall back to 30%-random "almost" for social nudge.
        local nearMissLabel = nil
        if anyNearMissRarity then
            -- Use genuine near-miss rarity label
            nearMissLabel = anyNearMissRarity .. " (so close!)"
            Network.FireClient("NearMissHatch", player, anyNearMissRarity)
        elseif #results == 1 then
            local result = results[1]
            local rarityOrder = RarityConfig.Tiers[result.Rarity] and RarityConfig.Tiers[result.Rarity].Order or 1
            if rarityOrder <= 2 and math.random() < 0.3 then
                local rarestPet = nil
                local rarestOrder = 0
                for _, entry in ipairs(egg.Pets) do
                    local pInfo = PetConfig.GetPet(entry.PetId)
                    if pInfo then
                        local ro = RarityConfig.Tiers[pInfo.Rarity] and RarityConfig.Tiers[pInfo.Rarity].Order or 1
                        if ro > rarestOrder then
                            rarestOrder = ro
                            rarestPet = pInfo
                        end
                    end
                end
                if rarestPet and rarestOrder >= 4 then
                    nearMissLabel = rarestPet.Name .. " (" .. rarestPet.Rarity .. ")"
                end
            end
        end
        -- Apply HatchSpeed boost from daily rotation theme
        local hatchTime = egg.HatchTime
        if DailyRotationService then
            local theme = DailyRotationService.GetDailyTheme()
            if theme and theme.BoostType == "HatchSpeed" and theme.BoostMultiplier > 0 then
                hatchTime = hatchTime / theme.BoostMultiplier
            end
        end
        Network.FireClient("HatchResult", player, results, hatchTime, nearMissLabel, eggId)
    end
end

-- Initialize
function EggService.Init(dataService, currencyService, petService, rewardService, antiExploitService, dailyRotationService)
    DataService = dataService
    CurrencyService = currencyService
    PetService = petService
    RewardService = rewardService
    AntiExploitService = antiExploitService
    DailyRotationService = dailyRotationService

    Network.OnServerEvent("HatchEgg", function(player: Player, eggId: string)
        if type(eggId) ~= "string" then return end
        if not AntiExploitService.CheckRateLimit(player, "HatchEgg") then return end
        EggService.HatchEgg(player, eggId)
    end)

    Network.OnServerEvent("CollectEgg", function(player: Player, eggId: string)
        if type(eggId) ~= "string" then return end
        if not AntiExploitService.CheckRateLimit(player, "CollectEgg") then return end
        EggService.CollectEgg(player, eggId)
    end)

    Network.OnServerEvent("AutoHatchToggle", function(player: Player, eggId: string)
        if type(eggId) ~= "string" then return end
        if not LaunchConfig.IsMonetizationEnabled("AdvancedPasses") then
            Network.FireClient("ShowNotification", player, "Auto Hatch is not yet available.", "Info")
            return
        end
        if not (EntitlementService and EntitlementService.HasPass(player, "auto_hatch")) then
            Network.FireClient("ShowNotification", player, "You need the Auto Hatch gamepass!", "Warning")
            return
        end
        if autoHatchPlayers[player] and autoHatchPlayers[player].enabled then
            autoHatchPlayers[player] = nil
            Network.FireClient("ShowNotification", player, "Auto Hatch disabled", "Info")
        else
            autoHatchPlayers[player] = { enabled = true, eggId = eggId }
            Network.FireClient("ShowNotification", player, "Auto Hatch enabled!", "Success")
        end
    end)

    -- Auto-hatch loop: auto-collect from field + immediately hatch
    -- Serialized per-player: only one operation in-flight at a time to prevent
    -- flooding the client with HatchResult events and causing freezes.
    task.spawn(function()
        while true do
            task.wait(1)
            for plr, state in pairs(autoHatchPlayers) do
                if state.enabled and plr.Parent and not autoHatchBusy[plr] then
                    local egg = EggConfig.GetEgg(state.eggId)
                    if not egg then continue end

                    local data = DataService.GetData(plr)
                    if not data then continue end
                    if not data.CollectedEggs then data.CollectedEggs = {} end
                    local available = data.CollectedEggs[state.eggId] or 0

                    autoHatchBusy[plr] = true
                    if available > 0 then
                        task.spawn(function()
                            EggService.HatchEgg(plr, state.eggId)
                            autoHatchBusy[plr] = nil
                        end)
                    else
                        if not CurrencyService.CanAfford(plr, egg.Currency, egg.Cost) then
                            autoHatchBusy[plr] = nil
                            continue
                        end
                        task.spawn(function()
                            EggService.CollectEgg(plr, state.eggId)
                            autoHatchBusy[plr] = nil
                        end)
                    end
                end
            end
        end
    end)
end

-- Clean up on player leave
function EggService.PlayerRemoving(player: Player)
    lastHatchTime[player] = nil
    autoHatchPlayers[player] = nil
    autoHatchBusy[player] = nil
    _hatchHistory[player] = nil
    _hatchTimes[player] = nil
    _coinShortageCooldown[player] = nil
end

-- Late-bind setters (called from init.server.luau after all services are initialized)
function EggService.SetNudgeService(ns) NudgeService = ns end
function EggService.SetStarterPackService(sps) StarterPackService = sps end
function EggService.SetPersonalizedOfferService(pos) PersonalizedOfferService = pos end
function EggService.SetEvolutionService(es) EvolutionService = es end
function EggService.SetEventSchedulerService(ess) EventSchedulerService = ess end
function EggService.SetEntitlementService(ents) EntitlementService = ents end
function EggService.SetAnalyticsService(as) AnalyticsService = as end
function EggService.SetMonetizationPromptService(mps) MonetizationPromptService = mps end
function EggService.SetBattlePassService(bps) BattlePassService = bps end
function EggService.SetEventShopService(ess) EventShopService = ess end

return EggService
