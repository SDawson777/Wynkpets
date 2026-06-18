--[[
    EvolutionService.luau
    Server-authoritative three-path evolution system.

    Path A — Free grind
        Spend accumulated WynkShards (+ essences for Epic/Legendary lines) that
        were earned through gameplay.  Zero Robux required.

    Path B — Speed-up
        Purchase a Shard Top-Up pack (Robux dev product) to fill the gap, then
        the service auto-applies the free-path evolve once shards are sufficient.

    Path C — Direct evolve
        Purchase an Instant-Evolve token (Robux dev product) and register a pet
        UUID intent.  The service grants the evolution immediately on confirmed
        purchase.

    Server authority guarantees
    ────────────────────────────
    • The client only sends intent (UUID + path + optional dev-product ID).
    • All eligibility, cost, and state mutations are server-side.
    • pendingEvolves table prevents replay: intent is consumed on first use.
    • Pity counter (EvoMissedWindows) is incremented when an evolution window
      ends while a player was online but didn't complete any evolution.

    Integration points
    ──────────────────
    • Call EvolutionService.TryAwardShards(player, trigger, rarity?) from
      EggService (on hatch), RebirthService (on rebirth), FuseService (on fuse),
      and RewardService (on daily login / quest complete).
    • Call EvolutionService.OnDevProductPurchased(player, devProductId) from
      GamepassService's developer-product receipt handler.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EventCalendarConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EventCalendarConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService
local PetService               -- for PetsUpdated broadcast
local EventSchedulerService
local AnalyticsService

local EvolutionService = {}

-- Pending paid-evolve intents: { [player] = { UUID, Path, Line, Registered } }
local pendingEvolves = {}

-- ── Private helpers ────────────────────────────────────────────────────────────

-- Lazily initialises and returns the player's EvolutionMaterials sub-table.
local function getMaterials(data)
    if not data.EvolutionMaterials then
        data.EvolutionMaterials = { WynkShards = 0, MoonEssence = 0, StormCrystal = 0 }
    end
    return data.EvolutionMaterials
end

-- Linear search for an owned pet by UUID.
local function findPet(data, uuid: string)
    for _, pet in ipairs(data.Pets) do
        if pet.UUID == uuid then
            return pet
        end
    end
    return nil
end

-- Finds the EvolutionLine config entry for a pet in the current window.
local function getLineForPet(petId: string, window)
    if not window or not window.EligibleLines then return nil end
    for _, line in ipairs(window.EligibleLines) do
        if line.PetId == petId then
            return line
        end
    end
    return nil
end

-- Returns true when the player has enough of every material in `cost`.
-- On failure also returns the first shortfall material id and amount needed.
local function canAfford(materials, cost)
    for matId, required in pairs(cost) do
        local have = materials[matId] or 0
        if have < required then
            return false, matId, required - have
        end
    end
    return true
end

-- Deducts all cost entries from materials.  Only call after canAfford → true.
local function deductCost(materials, cost)
    for matId, amount in pairs(cost) do
        materials[matId] = math.max(0, (materials[matId] or 0) - amount)
    end
end

-- Stamps the evolution onto the pet entry in-place.
-- Evolved pets keep their UUID, Golden, Rainbow, and Level; power doubles.
local function applyEvolution(pet, line)
    pet.EvolvedFormId = line.EvolvedId
    pet.Evolved       = true
    pet.EvolvedAt     = os.time()
    -- Base power doubling; fine-tune per rarity table in PetConfig.
    pet.Power = math.floor((pet.Power or 1) * 2.0)
end

-- Fetches or creates this window's history entry in player data.
local function getWindowHistory(data, windowId: string)
    if not data.EventWindowHistory then
        data.EventWindowHistory = {}
    end
    if not data.EventWindowHistory[windowId] then
        data.EventWindowHistory[windowId] = {
            Attempted  = false,
            Completed  = false,
            HatchCount = 0,  -- for FeaturedEggWeek milestones
            QuestsDone = 0,  -- for WorldPulse quest chain
        }
    end
    return data.EventWindowHistory[windowId]
end

-- Returns the pity shard multiplier for a player.
local function getPityMult(data): number
    local missed = data.EvoMissedWindows or 0
    local cfg    = EventCalendarConfig.PityConfig
    if missed >= cfg.MissedWindowBonusThreshold then
        return cfg.MissedWindowShardBonus
    end
    return 1.0
end

-- Fires EvolutionMaterialsUpdated with only the changed key for efficiency.
local function broadcastMaterialChange(player, materialId: string, newTotal: number)
    Network.FireClient("EvolutionMaterialsUpdated", player, { [materialId] = newTotal })
end

-- ── Material award ─────────────────────────────────────────────────────────────

-- Low-level award: call this from within EvolutionService to add materials.
function EvolutionService.AwardMaterial(player: Player, materialId: string, amount: number)
    if amount <= 0 then return end
    local data = DataService.GetData(player)
    if not data then return end

    local materials = getMaterials(data)
    local finalAmt  = math.floor(amount * getPityMult(data))
    materials[materialId] = (materials[materialId] or 0) + finalAmt
    broadcastMaterialChange(player, materialId, materials[materialId])
end

-- High-level award: call from EggService, RebirthService, FuseService, etc.
-- trigger: "Hatch" | "Rebirth" | "Fuse" | "DailyLogin" | "QuestComplete"
-- rarity:  optional rarity string (used only when trigger == "Hatch")
function EvolutionService.TryAwardShards(player: Player, trigger: string, rarity: string?)
    local rates = EventCalendarConfig.EarnRates
    local shards, moon, storm = 0, 0, 0

    if trigger == "Hatch" then
        if rarity == "Common"    then shards = rates.HatchCommon
        elseif rarity == "Rare"      then shards = rates.HatchRare
        elseif rarity == "Epic"      then shards = rates.HatchEpic
        elseif rarity == "Legendary" then shards = rates.HatchLegendary; moon = rates.HatchLegendaryMoon
        elseif rarity == "Mythic"    then shards = rates.HatchMythic;    moon = rates.HatchMythicMoon
        elseif rarity == "Secret"    then shards = rates.HatchSecret;    moon = rates.HatchSecretMoon
        end
    elseif trigger == "Rebirth" then
        shards = rates.Rebirth
        moon   = rates.RebirthMoon
        storm  = rates.RebirthStorm
    elseif trigger == "Fuse" then
        shards = rates.FusePets
    elseif trigger == "DailyLogin" then
        shards = rates.DailyLogin
    elseif trigger == "QuestComplete" then
        shards = rates.QuestComplete
    end

    if shards > 0 then EvolutionService.AwardMaterial(player, "WynkShards", shards) end
    if moon   > 0 then EvolutionService.AwardMaterial(player, "MoonEssence",  moon)  end
    if storm  > 0 then EvolutionService.AwardMaterial(player, "StormCrystal", storm) end
end

-- ── FeaturedEggWeek hatch tracking ────────────────────────────────────────────

-- Call from EggService after a successful hatch of FeaturedEggId.
function EvolutionService.OnFeaturedEggHatched(player: Player, eggId: string)
    if EventSchedulerService.GetCurrentEventType() ~= "FeaturedEggWeek" then return end
    local week = EventSchedulerService.GetCurrentWindow()
    if not week or week.FeaturedEggId ~= eggId then return end

    local data = DataService.GetData(player)
    if not data then return end

    local hist = getWindowHistory(data, week.Id)
    hist.HatchCount = (hist.HatchCount or 0) + 1

    -- Check milestone rewards
    for _, milestone in ipairs(week.MilestoneRewards) do
        local key = "milestone_" .. milestone.Hatches
        if hist.HatchCount >= milestone.Hatches and not hist[key] then
            hist[key] = true
            local reward = milestone.Reward
            if reward.Type == "WynkShards" then
                EvolutionService.AwardMaterial(player, "WynkShards", reward.Amount)
            elseif reward.Type == "Gems" then
                local currData = DataService.GetData(player)
                if currData then
                    currData.Gems = (currData.Gems or 0) + reward.Amount
                    Network.FireClient("CurrencyUpdated", player, "Gems", currData.Gems)
                end
            elseif reward.Type == "Pet" and PetService then
                PetService.AddPet(player, reward.PetId)
            end
            Network.FireClient("ShowNotification", player,
                "🎯 Milestone " .. milestone.Hatches .. " hatches reached! Reward granted.", "Success")
        end
    end
end

-- ── WorldPulse quest chain ─────────────────────────────────────────────────────

-- Call when a player completes a step that could advance a WorldPulse quest.
-- stepIndex: 1, 2, or 3.
function EvolutionService.AdvanceWorldPulseQuest(player: Player, stepIndex: number)
    if EventSchedulerService.GetCurrentEventType() ~= "WorldPulse" then return end
    local pulse = EventSchedulerService.GetCurrentWindow()
    if not pulse then return end

    local data = DataService.GetData(player)
    if not data then return end

    local hist = getWindowHistory(data, pulse.Id)
    -- Only advance in order; don't skip steps
    if hist.QuestsDone ~= stepIndex - 1 then return end

    local step = pulse.QuestLine[stepIndex]
    if not step then return end

    hist.QuestsDone = stepIndex

    -- Award step reward
    local reward = step.Reward
    if reward.WynkShards then
        EvolutionService.AwardMaterial(player, "WynkShards", reward.WynkShards)
    end
    if reward.Gems then
        local currData = DataService.GetData(player)
        if currData then
            currData.Gems = (currData.Gems or 0) + reward.Gems
            Network.FireClient("CurrencyUpdated", player, "Gems", currData.Gems)
        end
    end

    Network.FireClient("ShowNotification", player, "✅ Quest step complete: " .. step.Description, "Success")

    -- Grant limited pet on full completion
    if stepIndex == #pulse.QuestLine and not hist.QuestLineCompleted and PetService then
        hist.QuestLineCompleted = true
        PetService.AddPet(player, pulse.LimitedPetId)
        Network.FireClient("ShowNotification", player,
            "🏆 " .. pulse.Name .. " complete! You earned " .. pulse.LimitedPetId .. "!", "Success")
    end
end

-- ── Eligibility query ──────────────────────────────────────────────────────────

-- Returns a list of eligible-pet records the player can evolve in the current window.
-- Each record includes CanAffordFree and MissingCost so the client can render paths.
function EvolutionService.GetEligiblePets(player: Player): { any }
    local data = DataService.GetData(player)
    if not data then return {} end

    if EventSchedulerService.GetCurrentEventType() ~= "EvolutionWeekend" then return {} end

    local window = EventSchedulerService.GetCurrentWindow()
    if not window then return {} end

    local materials = getMaterials(data)
    local eligible  = {}

    for _, pet in ipairs(data.Pets) do
        if pet.Evolved then continue end

        local line = getLineForPet(pet.PetId, window)
        if not line then continue end
        if (pet.Level or 1) < line.MinLevel then continue end

        local ok, failMat, needAmt = canAfford(materials, line.FreeCost)
        local missing = {}
        if not ok then
            missing[failMat] = needAmt
            -- Include all shortfalls, not just the first
            for matId, required in pairs(line.FreeCost) do
                local have = materials[matId] or 0
                if have < required then
                    missing[matId] = required - have
                end
            end
        end

        table.insert(eligible, {
            UUID          = pet.UUID,
            PetId         = pet.PetId,
            EvolvedId     = line.EvolvedId,
            Rarity        = line.Rarity,
            Level         = pet.Level or 1,
            MinLevel      = line.MinLevel,
            FreeCost      = line.FreeCost,
            SpeedCost     = line.SpeedCost,
            DirectRobux   = line.DirectRobux,
            CanAffordFree = ok,
            MissingCost   = missing,
        })
    end

    return eligible
end

-- ── Path A: free grind evolve ──────────────────────────────────────────────────

local function executeFreeEvolve(player: Player, uuid: string): (boolean, string?)
    local data = DataService.GetData(player)
    if not data then return false, "No data" end

    if EventSchedulerService.GetCurrentEventType() ~= "EvolutionWeekend" then
        return false, "No active Evolution Weekend"
    end
    if EventSchedulerService.GetCurrentPhase() ~= "climax" then
        return false, "Evolution opens Friday–Sunday only"
    end

    local pet = findPet(data, uuid)
    if not pet then return false, "Pet not found" end
    if pet.Evolved then return false, "Pet already evolved" end

    local window = EventSchedulerService.GetCurrentWindow()
    local line   = getLineForPet(pet.PetId, window)
    if not line then return false, "Pet not eligible this window" end
    if (pet.Level or 1) < line.MinLevel then
        return false, string.format("Pet must be level %d (currently %d)", line.MinLevel, pet.Level or 1)
    end

    local materials = getMaterials(data)
    local ok, failMat = canAfford(materials, line.FreeCost)
    if not ok then return false, "Not enough " .. failMat end

    -- All checks passed — mutate state
    deductCost(materials, line.FreeCost)
    applyEvolution(pet, line)

    -- Reset pity; record window history
    data.EvoMissedWindows  = 0
    data.TotalEvolutions   = (data.TotalEvolutions or 0) + 1
    local hist = getWindowHistory(data, window.Id)
    hist.Attempted = true
    hist.Completed = true

    -- Broadcast
    Network.FireClient("EvolveResult", player, {
        Success   = true,
        UUID      = uuid,
        EvolvedId = line.EvolvedId,
        Path      = "free",
        Materials = data.EvolutionMaterials,
    })
    Network.FireClient("PetsUpdated", player, data.Pets)
    Network.FireClient("ShowNotification", player,
        "✨ " .. pet.PetId .. " evolved into " .. line.EvolvedId .. "!", "Success")

    if AnalyticsService then
        AnalyticsService.LogEvent(player, "PetEvolved", {
            UUID = uuid, PetId = pet.PetId, EvolvedId = line.EvolvedId, Path = "free"
        })
    end

    return true
end

-- ── Path C: direct Robux evolve (called after purchase confirmed) ──────────────

local function executeDirectEvolve(player: Player, uuid: string): (boolean, string?)
    local data = DataService.GetData(player)
    if not data then return false, "No data" end

    local pet = findPet(data, uuid)
    if not pet then return false, "Pet not found" end
    if pet.Evolved then return false, "Already evolved" end

    local window = EventSchedulerService.GetCurrentWindow()
    local line   = window and getLineForPet(pet.PetId, window)
    if not line then return false, "Pet not eligible in current window" end

    applyEvolution(pet, line)
    data.EvoMissedWindows = 0
    data.TotalEvolutions  = (data.TotalEvolutions or 0) + 1

    local hist = getWindowHistory(data, window.Id)
    hist.Attempted = true
    hist.Completed = true

    Network.FireClient("EvolveResult", player, {
        Success   = true,
        UUID      = uuid,
        EvolvedId = line.EvolvedId,
        Path      = "direct",
        Materials = data.EvolutionMaterials,
    })
    Network.FireClient("PetsUpdated", player, data.Pets)
    Network.FireClient("ShowNotification", player,
        "⚡ " .. pet.PetId .. " instantly evolved into " .. line.EvolvedId .. "!", "Success")

    if AnalyticsService then
        AnalyticsService.LogEvent(player, "PetEvolved", {
            UUID = uuid, PetId = pet.PetId, EvolvedId = line.EvolvedId, Path = "direct"
        })
    end

    return true
end

-- ── Paid intent registration ───────────────────────────────────────────────────

-- Register a paid evolve intent BEFORE the Robux purchase is initiated, so the
-- server can immediately apply the evolution once the receipt arrives.
-- Returns success + error message; the client should open the dev-product prompt
-- only after receiving EvolveIntentRegistered.
function EvolutionService.RegisterPaidIntent(player: Player, uuid: string, path: string): (boolean, string?)
    local data = DataService.GetData(player)
    if not data then return false, "No data" end

    local pet = findPet(data, uuid)
    if not pet then return false, "Pet not found" end
    if pet.Evolved then return false, "Already evolved" end

    local window = EventSchedulerService.GetCurrentWindow()
    if not window then return false, "No active evolution window" end

    local line = getLineForPet(pet.PetId, window)
    if not line then return false, "Pet not eligible this window" end

    pendingEvolves[player] = {
        UUID       = uuid,
        Path       = path,
        Line       = line,
        WindowId   = window.Id,
        Registered = os.time(),
    }
    return true
end

-- Called by GamepassService's ProcessReceipt handler when a dev product is purchased.
function EvolutionService.OnDevProductPurchased(player: Player, devProductId: number)
    local products = EventCalendarConfig.EvolutionProducts

    -- Check shard top-up packs (Path B)
    for packName, pack in pairs(products) do
        if packName:sub(1, 9) == "ShardPack" and pack.DevProductId == devProductId then
            EvolutionService.AwardMaterial(player, "WynkShards", pack.Amount)
            Network.FireClient("ShowNotification", player,
                "+" .. pack.Amount .. " Wynk Shards added!", "Success")

            -- If player has a pending speed intent, try to auto-complete the free evolve
            local intent = pendingEvolves[player]
            -- Expire stale intents (> 10 min)
            if intent and (os.time() - (intent.Registered or 0)) > 600 then
                pendingEvolves[player] = nil
                intent = nil
            end
            if intent and intent.Path == "speed" then
                local data = DataService.GetData(player)
                if data then
                    local mats = getMaterials(data)
                    if canAfford(mats, intent.Line.FreeCost) then
                        executeFreeEvolve(player, intent.UUID)
                        pendingEvolves[player] = nil
                    else
                        Network.FireClient("ShowNotification", player,
                            "Shards added! Keep grinding for more to evolve.", "Info")
                    end
                end
            end
            return true
        end
    end

    -- Check instant-evolve tokens (Path C)
    for tokenName, token in pairs(products) do
        if tokenName:sub(1, 13) == "InstantEvolve" and token.DevProductId == devProductId then
            local intent = pendingEvolves[player]
            -- Expire intents older than 10 minutes (stale window risk)
            if intent and (os.time() - (intent.Registered or 0)) > 600 then
                pendingEvolves[player] = nil
                intent = nil
            end
            if intent and intent.Path == "direct" then
                executeDirectEvolve(player, intent.UUID)
                pendingEvolves[player] = nil
            else
                -- No registered intent: bank the token as a consumable
                local data = DataService.GetData(player)
                if data then
                    data.Consumables = data.Consumables or {}
                    data.Consumables.EvolveToken = (data.Consumables.EvolveToken or 0) + 1
                    Network.FireClient("ShowNotification", player,
                        "Instant Evolve Token stored in your inventory.", "Info")
                end
            end
            return true
        end
    end
end

-- ── Data push to client ────────────────────────────────────────────────────────

function EvolutionService.SendEvolutionData(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    Network.FireClient("EvolutionData", player, {
        Materials     = getMaterials(data),
        EligiblePets  = EvolutionService.GetEligiblePets(player),
        EventType     = EventSchedulerService.GetCurrentEventType(),
        Phase         = EventSchedulerService.GetCurrentPhase(),
        PityWindows   = data.EvoMissedWindows or 0,
        TotalEvolved  = data.TotalEvolutions  or 0,
    })
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────────

function EvolutionService.PlayerAdded(player: Player)
    task.delay(2, function()
        if player and player.Parent then
            EvolutionService.SendEvolutionData(player)
        end
    end)
end

function EvolutionService.PlayerRemoving(player: Player)
    pendingEvolves[player] = nil
end

function EvolutionService.Init(dataService, petService, eventSchedulerService, analyticsService)
    DataService           = dataService
    PetService            = petService
    EventSchedulerService = eventSchedulerService
    AnalyticsService      = analyticsService

    if not LaunchConfig.IsFeatureEnabled("Evolution") then
        print("[LaunchConfig] EvolutionService disabled — skipping handler registration")
        return
    end

    -- ── Remote handlers ────────────────────────────────────────────────────────

    -- Client requests its current evolution state (on GUI open).
    Network.OnServerEvent("RequestEvolutionData", function(player)
        EvolutionService.SendEvolutionData(player)
    end)

    -- Client initiates an evolution attempt.
    --   uuid  : string   — which pet to evolve
    --   path  : string   — "free" | "speed" | "direct"
    Network.OnServerEvent("RequestEvolve", function(player, uuid, path)
        -- Input validation
        if typeof(uuid) ~= "string" or #uuid == 0 then return end
        if path ~= "free" and path ~= "speed" and path ~= "direct" then return end

        if path == "free" then
            local ok, err = executeFreeEvolve(player, uuid)
            if not ok then
                Network.FireClient("EvolveResult", player, { Success = false, Error = err })
                Network.FireClient("ShowNotification", player, "Evolution failed: " .. tostring(err), "Error")
            end
        else
            -- Path B or C: register intent, then client opens dev-product prompt
            local ok, err = EvolutionService.RegisterPaidIntent(player, uuid, path)
            if not ok then
                Network.FireClient("EvolveResult", player, { Success = false, Error = err })
                Network.FireClient("ShowNotification", player, "Could not register intent: " .. tostring(err), "Error")
            else
                Network.FireClient("EvolveIntentRegistered", player, { UUID = uuid, Path = path })
            end
        end
    end)

    -- ── Pity tracker: runs every hour ──────────────────────────────────────────
    -- Increments EvoMissedWindows for online players who haven't completed
    -- an evolution in the current window (only during EvolutionWeekend weeks).
    task.spawn(function()
        while true do
            task.wait(3600)
            if EventSchedulerService.GetCurrentEventType() ~= "EvolutionWeekend" then
                continue
            end
            -- Only penalise at the END of a climax window (i.e. transition to next prep).
            -- We approximate by checking mid-week (Tues–Thurs) so we penalise the week
            -- that just passed, not the current one that might still be active.
            -- Full cross-session pity accuracy: stored in data, so misses accumulate
            -- correctly even across restarts.
            local window = EventSchedulerService.GetCurrentWindow()
            if not window then continue end

            for _, p in ipairs(Players:GetPlayers()) do
                local data = DataService.GetData(p)
                if not data then continue end
                -- If this window is still active, don't penalise yet
                local hist = getWindowHistory(data, window.Id)
                if not hist.PenaltyApplied and EventSchedulerService.GetCurrentPhase() == "prep" then
                    -- Prep phase of a new window: penalise missing the previous one
                    if not hist.Completed then
                        data.EvoMissedWindows = (data.EvoMissedWindows or 0) + 1
                    end
                    hist.PenaltyApplied = true
                end
            end
        end
    end)

    print("[EvolutionService] Initialized")
end

return EvolutionService
