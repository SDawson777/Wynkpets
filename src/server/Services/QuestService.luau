-- QuestService.luau
-- Manages daily/weekly quest resets and achievement checking.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService  = require(script.Parent.DataService)
local QuestConfig  = require(ReplicatedStorage.Shared.Config.QuestConfig)

local Events = ReplicatedStorage.Shared.Remotes.Events

local QuestService = {}

-- ─── Date helpers ────────────────────────────────────────────────────────────

local function dateString(): string
    return os.date("!%Y-%m-%d")  -- UTC YYYY-MM-DD
end

local function weekString(): string
    -- ISO week: year + week number
    return os.date("!%Y-W%W")
end

-- ─── Reset quest progress if stale ───────────────────────────────────────────

local function resetDailyIfNeeded(data: {})
    local today = dateString()
    if data.LastDailyQuestReset ~= today then
        data.LastDailyQuestReset = today
        -- Clear daily quest progress
        for _, q in ipairs(QuestConfig.Quests) do
            if q.type == "daily" then
                data.QuestProgress[q.id] = 0
            end
        end
        -- Reset daily stats
        data.Stats.oresMinedToday   = 0
        data.Stats.coinsEarnedToday = 0
        data.Stats.eggsHatchedToday = 0
    end
end

local function resetWeeklyIfNeeded(data: {})
    local week = weekString()
    if data.LastWeeklyQuestReset ~= week then
        data.LastWeeklyQuestReset = week
        for _, q in ipairs(QuestConfig.Quests) do
            if q.type == "weekly" then
                data.QuestProgress[q.id] = 0
            end
        end
        data.Stats.oresMinedWeekly   = 0
        data.Stats.eggsHatchedWeekly = 0
    end
end

-- ─── Evaluate quests and grant rewards ────────────────────────────────────────

function QuestService.evaluateAll(player: Player)
    local data = DataService.get(player)
    if not data then return end

    resetDailyIfNeeded(data)
    resetWeeklyIfNeeded(data)

    for _, q in ipairs(QuestConfig.Quests) do
        -- Skip already-completed achievements
        if q.type == "achievement" and data.AchievementsCompleted[q.id] then
            continue
        end

        -- Map quest stat to data.Stats field
        local current = data.Stats[q.goal.stat] or 0
        local goal    = q.goal.amount

        -- Update quest progress mirror (for UI)
        if q.type ~= "achievement" then
            data.QuestProgress[q.id] = current
        end

        -- Grant reward if just reached goal
        local alreadyGranted = (q.type == "achievement") and data.AchievementsCompleted[q.id]
            or (q.type ~= "achievement" and (data.QuestProgress[q.id .. "_rewarded"] == true))

        if not alreadyGranted and current >= goal then
            -- Grant reward
            data.Coins = data.Coins + (q.reward.coins or 0)
            data.Gems  = data.Gems  + (q.reward.gems  or 0)
            Events.CoinsUpdated:FireClient(player, data.Coins)
            Events.GemsUpdated:FireClient(player, data.Gems)
            Events.QuestCompleted:FireClient(player, q.id, q.reward)

            if q.type == "achievement" then
                data.AchievementsCompleted[q.id] = true
            else
                data.QuestProgress[q.id .. "_rewarded"] = true
            end
        end
    end

    Events.QuestsUpdated:FireClient(player, data.QuestProgress, data.AchievementsCompleted)
end

-- ─── Evaluate on data load and periodically ───────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
    -- Wait a moment for DataService to load data
    task.wait(3)
    QuestService.evaluateAll(player)
end)

task.spawn(function()
    while true do
        task.wait(30)  -- evaluate quests every 30 s
        for _, player in ipairs(Players:GetPlayers()) do
            QuestService.evaluateAll(player)
        end
    end
end)

-- ─── Daily Reward ─────────────────────────────────────────────────────────────

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)

local function claimDaily(player: Player)
    local data = DataService.get(player)
    if not data then return end

    local today = dateString()
    if data.LastDailyClaimDate == today then
        Events.DailyRewardResult:FireClient(player, false, "Already claimed today.")
        return
    end

    -- Increment streak (reset if more than 1 day gap)
    -- Simplified: just increment, no gap detection for MVP
    data.DailyStreak = (data.DailyStreak or 0) + 1
    if data.DailyStreak > ShopConfig.DailyRewardMaxStreak then
        data.DailyStreak = 1
    end

    local reward = ShopConfig.DailyRewards[data.DailyStreak]
    if not reward then
        reward = ShopConfig.DailyRewards[1]
    end

    data.Coins = data.Coins + (reward.coins or 0)
    data.Gems  = data.Gems  + (reward.gems  or 0)
    data.LastDailyClaimDate = today

    Events.CoinsUpdated:FireClient(player, data.Coins)
    Events.GemsUpdated:FireClient(player, data.Gems)
    Events.DailyRewardResult:FireClient(player, true, reward)
end

Events.ClaimDailyReward.OnServerEvent:Connect(function(player: Player)
    claimDaily(player)
end)

return QuestService
