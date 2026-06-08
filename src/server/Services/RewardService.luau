--[[
    RewardService.luau
    Handles daily rewards, login streaks, and quest tracking.
    Server-authoritative.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local QuestConfig  = require(Shared:WaitForChild("Configs"):WaitForChild("QuestConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService
local CurrencyService
local EvolutionService  -- set via RewardService.SetEvolutionService
local BattlePassService -- set via RewardService.SetBattlePassService

-- ── Quest feature-gate filter ─────────────────────────────────────────────────
-- Maps each LaunchConfig feature flag to the quest Type strings it gates.
-- Add new mappings here when new features / quest types are introduced.
local FEATURE_QUEST_TYPES = {
    Fusion    = { "FusePets" },
    Trading   = { "Trade" },
    Evolution = { "Evolution" },
}

-- These quest types are part of the core loop and must always be available
-- as a fallback guarantee (players can never be left with zero eligible quests).
local FALLBACK_TYPES = { CollectCoins = true, HatchEggs = true, EquipPets = true }

-- Returns a filtered copy of `allQuests` that only contains quests whose Type
-- corresponds to a LaunchConfig-enabled feature (or has no gate at all).
-- Guarantee: if *every* quest would be filtered out, falls back to FALLBACK_TYPES
-- so players always receive at least the core-loop quests.
local function buildFilteredPool(allQuests: { any }): { any }
    local cfg = LaunchConfig.Get()

    -- Build set of blocked quest types from disabled features
    local disabledTypes = {}
    for feature, types in pairs(FEATURE_QUEST_TYPES) do
        if not cfg.Features[feature] then
            for _, t in ipairs(types) do
                disabledTypes[t] = true
            end
        end
    end

    local pool = {}
    for _, quest in ipairs(allQuests) do
        if not disabledTypes[quest.Type] then
            table.insert(pool, quest)
        end
    end

    -- Safety fallback: if all quests were gated out, keep core-loop types only
    if #pool == 0 then
        for _, quest in ipairs(allQuests) do
            if FALLBACK_TYPES[quest.Type] then
                table.insert(pool, quest)
            end
        end
    end

    return pool
end

local RewardService = {}

local ONE_DAY = 86400 -- seconds

-- Check and update login streak
function RewardService.ProcessLogin(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    local now = os.time()
    local lastLogin = data.LastLogin or 0

    if lastLogin == 0 then
        -- First time player
        data.LoginStreak = 1
        data.DailyRewardClaimed = false
        -- Ensure quest tables are clean for first assignment
        data.Quests = {}
        data.CompletedQuests = {}
        data.DailyQuestRerolls = 0
    else
        local daysSinceLast = math.floor((now - lastLogin) / ONE_DAY)
        if daysSinceLast >= 1 then
            -- New calendar day (consecutive or streak-broken)
            if daysSinceLast == 1 then
                data.LoginStreak = (data.LoginStreak or 0) + 1
                if data.LoginStreak > QuestConfig.MaxLoginStreak then
                    data.LoginStreak = 1
                end
            else
                data.LoginStreak = 1
            end
            data.DailyRewardClaimed = false
            -- Reset daily quests so fresh ones are assigned
            data.Quests = {}
            data.CompletedQuests = {}
            data.DailyQuestRerolls = 0
            data.DailyQuestRerollReset = 0
        end
        -- Same day: don't change streak or quests
    end

    data.LastLogin = now

    -- Assign daily quests
    RewardService.AssignDailyQuests(player)
    -- Assign weekly quests (noop if current week already assigned)
    RewardService.AssignWeeklyQuests(player)
end

-- Claim daily login reward
function RewardService.ClaimDailyReward(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    if data.DailyRewardClaimed then
        Network.FireClient("ShowNotification", player, "Already claimed today's reward!", "Warning")
        return
    end

    local streak = data.LoginStreak or 1
    local reward = nil

    for _, entry in ipairs(QuestConfig.LoginStreakRewards) do
        if entry.Day == streak then
            reward = entry
            break
        end
    end

    if not reward then
        -- Fallback to day 1 reward
        reward = QuestConfig.LoginStreakRewards[1]
    end

    if reward then
        CurrencyService.Add(player, reward.RewardType, reward.RewardAmount, false)
        data.DailyRewardClaimed = true
        -- Award Wynk Shards for daily login
        if EvolutionService then
            EvolutionService.TryAwardShards(player, "DailyLogin")
        end

        Network.FireClient("DailyRewardResult", player, {
            Day = streak,
            RewardType = reward.RewardType,
            RewardAmount = reward.RewardAmount,
        })
        Network.FireClient("ShowNotification", player,
            "Day " .. streak .. " reward: +" .. reward.RewardAmount .. " " .. reward.RewardType .. "!",
            "Success")
    end
end

-- Assign random daily quests
function RewardService.AssignDailyQuests(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    -- Only assign if quests are empty or it's a new day
    if data.Quests and next(data.Quests) ~= nil then
        return -- Already has quests
    end

    data.Quests = {}
    data.CompletedQuests = data.CompletedQuests or {}

    -- Shuffle and pick random quests (filtered to enabled LaunchConfig features)
    local available = buildFilteredPool(QuestConfig.DailyQuests)

    -- Simple shuffle
    for i = #available, 2, -1 do
        local j = math.random(1, i)
        available[i], available[j] = available[j], available[i]
    end

    -- Take first N quests
    local count = math.min(QuestConfig.DailyQuestCount, #available)
    for i = 1, count do
        local quest = available[i]
        data.Quests[quest.Id] = 0
    end

    Network.FireClient("QuestUpdated", player, data.Quests)
end

-- Update quest progress (called by other services) — handles both daily & weekly
function RewardService.UpdateQuestProgress(player: Player, questType: string, amount: number, extra: any?)
    local data = DataService.GetData(player)
    if not data then return end

    -- Daily quests
    if data.Quests then
        -- Build O(1) lookup set once instead of O(n) scan per quest
        local completedSet = {}
        for _, id in ipairs(data.CompletedQuests or {}) do
            completedSet[id] = true
        end

        local anyChanged = false
        for questId, progress in pairs(data.Quests) do
            local questInfo = QuestConfig.QuestById and QuestConfig.QuestById[questId]
            if not questInfo then
                for _, q in ipairs(QuestConfig.DailyQuests) do
                    if q.Id == questId then questInfo = q; break end
                end
            end

            if questInfo and questInfo.Type == questType and not completedSet[questId] then
                data.Quests[questId] = (progress or 0) + amount
                anyChanged = true
            end
        end

        if anyChanged then
            Network.FireClient("QuestUpdated", player, data.Quests)
        end
    end

    -- Weekly quests
    if data.WeeklyQuests then
        for questId, entry in pairs(data.WeeklyQuests) do
            if entry.Completed then continue end
            local questInfo = QuestConfig.QuestById and QuestConfig.QuestById[questId]
            if questInfo and questInfo.Type == questType then
                -- Honour rarity gate if defined
                if questInfo.TargetRarity and extra ~= questInfo.TargetRarity then
                    continue
                end
                entry.Progress = (entry.Progress or 0) + amount
                if entry.Progress >= questInfo.Target then
                    entry.Progress = questInfo.Target
                    entry.Completed = true
                end
                Network.FireClient("WeeklyQuestUpdated", player, data.WeeklyQuests)
            end
        end
    end
end

-- Claim a completed quest reward
function RewardService.ClaimQuestReward(player: Player, questId: string)
    local data = DataService.GetData(player)
    if not data or not data.Quests then return end

    local progress = data.Quests[questId]
    if not progress then
        Network.FireClient("ShowNotification", player, "Quest not found!", "Warning")
        return
    end

    -- Find quest config
    local questInfo = nil
    for _, q in ipairs(QuestConfig.DailyQuests) do
        if q.Id == questId then
            questInfo = q
            break
        end
    end

    if not questInfo then return end

    if progress < questInfo.Target then
        Network.FireClient("ShowNotification", player, "Quest not completed yet!", "Warning")
        return
    end

    -- Check not already claimed
    for _, completed in ipairs(data.CompletedQuests or {}) do
        if completed == questId then
            Network.FireClient("ShowNotification", player, "Already claimed!", "Warning")
            return
        end
    end

    -- Grant reward
    CurrencyService.Add(player, questInfo.RewardType, questInfo.RewardAmount, false)
    table.insert(data.CompletedQuests, questId)
    -- Award Wynk Shards for quest completion
    if EvolutionService then
        EvolutionService.TryAwardShards(player, "QuestComplete")
    end
    -- Battle Pass XP: +300 XP per daily quest claimed
    if BattlePassService then
        BattlePassService.AddXP(player, 300, "daily_quest")
    end

    Network.FireClient("ShowNotification", player,
        "Quest complete! +" .. questInfo.RewardAmount .. " " .. questInfo.RewardType .. "!", "Success")
    Network.FireClient("QuestUpdated", player, data.Quests)
end

-- Initialize
function RewardService.Init(dataService, currencyService)
    DataService = dataService
    CurrencyService = currencyService

    Network.OnServerEvent("ClaimDailyReward", function(player: Player)
        RewardService.ClaimDailyReward(player)
    end)

    Network.OnServerEvent("ClaimQuestReward", function(player: Player, questId: string)
        if type(questId) ~= "string" then return end
        RewardService.ClaimQuestReward(player, questId)
    end)

    Network.OnServerEvent("ClaimWeeklyQuestReward", function(player: Player, questId: string)
        if type(questId) ~= "string" then return end
        RewardService.ClaimWeeklyQuestReward(player, questId)
    end)

    Network.OnServerEvent("RerollDailyQuest", function(player: Player, questId: string)
        if type(questId) ~= "string" then return end
        RewardService.RerollDailyQuest(player, questId)
    end)
end

function RewardService.SetEvolutionService(es) EvolutionService = es end
function RewardService.SetBattlePassService(bps) BattlePassService = bps end

-- ── Weekly Quests ─────────────────────────────────────────────────────────────

-- Returns os.time() of the most recent Monday 00:00 UTC
local function getWeekStart()
    local now = os.time()
    local t = os.date("!*t", now)
    -- os.date wday: 1=Sun, 2=Mon … 7=Sat
    local dayOfWeek = t.wday -- 1-based, Sunday=1
    local daysSinceMon = (dayOfWeek - 2 + 7) % 7
    return now - daysSinceMon * 86400 - t.hour * 3600 - t.min * 60 - t.sec
end

function RewardService.AssignWeeklyQuests(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    local weekStart = getWeekStart()

    -- Already have current week's quests?
    if (data.WeeklyQuestReset or 0) >= weekStart and next(data.WeeklyQuests or {}) ~= nil then
        return
    end

    data.WeeklyQuests = {}
    data.WeeklyQuestReset = weekStart

    -- Shuffle pool (filtered to enabled LaunchConfig features)
    local pool = buildFilteredPool(QuestConfig.WeeklyQuests)
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local count = math.min(QuestConfig.WeeklyQuestCount, #pool)
    for i = 1, count do
        data.WeeklyQuests[pool[i].Id] = { Progress = 0, Completed = false, Claimed = false }
    end

    Network.FireClient("WeeklyQuestUpdated", player, data.WeeklyQuests)
end

function RewardService.ClaimWeeklyQuestReward(player: Player, questId: string)
    local data = DataService.GetData(player)
    if not data or not data.WeeklyQuests then return end

    local entry = data.WeeklyQuests[questId]
    if not entry then
        Network.FireClient("ShowNotification", player, "Weekly quest not found!", "Warning")
        return
    end

    if not entry.Completed then
        Network.FireClient("ShowNotification", player, "Quest not completed yet!", "Warning")
        return
    end

    if entry.Claimed then
        Network.FireClient("ShowNotification", player, "Already claimed!", "Warning")
        return
    end

    local questInfo = QuestConfig.QuestById and QuestConfig.QuestById[questId]
    if not questInfo then return end

    CurrencyService.Add(player, questInfo.RewardType, questInfo.RewardAmount, false)
    entry.Claimed = true
    -- Battle Pass XP: +1000 XP per weekly quest claimed
    if BattlePassService then
        BattlePassService.AddXP(player, 1000, "weekly_quest")
    end

    -- Check bonus: all quests completed and claimed
    local allDone = true
    local allClaimed = true
    for _, e in pairs(data.WeeklyQuests) do
        if not e.Completed then allDone = false end
        if not e.Claimed then allClaimed = false end
    end

    if allDone and allClaimed and not data.WeeklyBonusClaimed then
        data.WeeklyBonusClaimed = true
        local bonus = QuestConfig.WeeklyCompletionBonus
        CurrencyService.Add(player, bonus.RewardType, bonus.RewardAmount, false)
        Network.FireClient("ShowNotification", player,
            "🎉 All weekly quests done! Bonus: +" .. bonus.RewardAmount .. " " .. bonus.RewardType .. "!", "Success")
    end

    Network.FireClient("ShowNotification", player,
        "Weekly quest complete! +" .. questInfo.RewardAmount .. " " .. questInfo.RewardType .. "!", "Success")
    Network.FireClient("WeeklyQuestUpdated", player, data.WeeklyQuests)
end

-- ── Reroll ────────────────────────────────────────────────────────────────────

function RewardService.RerollDailyQuest(player: Player, questId: string)
    local data = DataService.GetData(player)
    if not data or not data.Quests then return end

    -- Rate-limit rerolls per calendar day
    local today = math.floor(os.time() / 86400)
    if (data.DailyQuestRerollReset or 0) < today then
        data.DailyQuestRerolls = 0
        data.DailyQuestRerollReset = today
    end

    if (data.DailyQuestRerolls or 0) >= QuestConfig.MaxDailyRerolls then
        Network.FireClient("ShowNotification", player,
            "Max " .. QuestConfig.MaxDailyRerolls .. " rerolls per day reached.", "Warning")
        return
    end

    -- Check player has the quest and it's not completed
    if not data.Quests[questId] then
        Network.FireClient("ShowNotification", player, "Quest not found.", "Warning")
        return
    end

    for _, completedId in ipairs(data.CompletedQuests or {}) do
        if completedId == questId then
            Network.FireClient("ShowNotification", player, "Can't reroll completed quests.", "Warning")
            return
        end
    end

    -- Charge gems
    local gemsCost = QuestConfig.RerollCostGems or 5
    local currentGems = data.Gems or 0
    if currentGems < gemsCost then
        Network.FireClient("ShowNotification", player,
            "Not enough Gems! Reroll costs " .. gemsCost .. " Gems.", "Warning")
        Network.FireClient("QuestRerollResult", player, nil, "not_enough_gems")
        return
    end

    CurrencyService.Remove(player, "Gems", gemsCost)
    data.DailyQuestRerolls = (data.DailyQuestRerolls or 0) + 1

    -- Pick a replacement quest not already active
    local activeIds = {}
    for id in pairs(data.Quests) do
        activeIds[id] = true
    end

    -- Reroll pool also respects feature flags so disabled quest types
    -- are never offered as replacement options.
    local pool = {}
    for _, q in ipairs(buildFilteredPool(QuestConfig.DailyQuests)) do
        if not activeIds[q.Id] then
            table.insert(pool, q)
        end
    end

    if #pool == 0 then
        -- All quests already assigned — nothing to reroll
        CurrencyService.Add(player, "Gems", gemsCost, false) -- refund
        data.DailyQuestRerolls = math.max(0, data.DailyQuestRerolls - 1)
        Network.FireClient("ShowNotification", player, "No quests available to replace!", "Warning")
        return
    end

    local replacement = pool[math.random(1, #pool)]
    data.Quests[questId] = nil
    data.Quests[replacement.Id] = 0

    Network.FireClient("QuestRerollResult", player, replacement.Id, "ok")
    Network.FireClient("QuestUpdated", player, data.Quests)
    Network.FireClient("ShowNotification", player, "Quest rerolled!", "Success")
end

return RewardService
