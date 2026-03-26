--[[
    RewardService.luau
    Handles daily rewards, login streaks, and quest tracking.
    Server-authoritative.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local QuestConfig = require(Shared:WaitForChild("Configs"):WaitForChild("QuestConfig"))

local DataService
local CurrencyService

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
    else
        local daysSinceLast = math.floor((now - lastLogin) / ONE_DAY)
        if daysSinceLast == 1 then
            -- Consecutive day
            data.LoginStreak = (data.LoginStreak or 0) + 1
            if data.LoginStreak > QuestConfig.MaxLoginStreak then
                data.LoginStreak = 1
            end
            data.DailyRewardClaimed = false
        elseif daysSinceLast > 1 then
            -- Streak broken
            data.LoginStreak = 1
            data.DailyRewardClaimed = false
        end
        -- Same day: don't change streak
    end

    data.LastLogin = now

    -- Assign daily quests
    RewardService.AssignDailyQuests(player)
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

    -- Shuffle and pick random quests
    local available = {}
    for _, quest in ipairs(QuestConfig.DailyQuests) do
        table.insert(available, quest)
    end

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

-- Update quest progress (called by other services)
function RewardService.UpdateQuestProgress(player: Player, questType: string, amount: number, extra: any?)
    local data = DataService.GetData(player)
    if not data or not data.Quests then return end

    for questId, progress in pairs(data.Quests) do
        -- Find quest config
        local questInfo = nil
        for _, q in ipairs(QuestConfig.DailyQuests) do
            if q.Id == questId then
                questInfo = q
                break
            end
        end

        if questInfo and questInfo.Type == questType then
            -- Check if already completed
            local alreadyCompleted = false
            for _, completed in ipairs(data.CompletedQuests or {}) do
                if completed == questId then
                    alreadyCompleted = true
                    break
                end
            end

            if not alreadyCompleted then
                data.Quests[questId] = (progress or 0) + amount
                Network.FireClient("QuestUpdated", player, data.Quests)
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
end

return RewardService
