--[[
    QuestGui.client.luau
    Daily quests, login streak, and rewards display.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local QuestConfig = require(Shared:WaitForChild("Configs"):WaitForChild("QuestConfig"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuestGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.4
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 550, 0, 450)
mainFrame.Position = UDim2.new(0.5, -275, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 16)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(200, 150, 255)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "📋 Daily Quests"
title.TextColor3 = Color3.fromRGB(220, 180, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = mainFrame

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 16)
tCorner.Parent = title

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = title

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 10)
cbCorner.Parent = closeBtn

-- Login streak section
local streakFrame = Instance.new("Frame")
streakFrame.Size = UDim2.new(1, -20, 0, 70)
streakFrame.Position = UDim2.new(0, 10, 0, 60)
streakFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
streakFrame.BorderSizePixel = 0
streakFrame.Parent = mainFrame

local sfCorner = Instance.new("UICorner")
sfCorner.CornerRadius = UDim.new(0, 12)
sfCorner.Parent = streakFrame

local streakTitle = Instance.new("TextLabel")
streakTitle.Size = UDim2.new(0.5, 0, 0, 24)
streakTitle.Position = UDim2.new(0, 10, 0, 5)
streakTitle.BackgroundTransparency = 1
streakTitle.Text = "🔥 Login Streak: Day 1"
streakTitle.TextColor3 = Color3.fromRGB(255, 180, 50)
streakTitle.Font = Enum.Font.GothamBold
streakTitle.TextSize = 15
streakTitle.TextXAlignment = Enum.TextXAlignment.Left
streakTitle.Parent = streakFrame

-- Streak day indicators
local streakDays = Instance.new("Frame")
streakDays.Size = UDim2.new(1, -20, 0, 34)
streakDays.Position = UDim2.new(0, 10, 0, 30)
streakDays.BackgroundTransparency = 1
streakDays.Parent = streakFrame

local streakLayout = Instance.new("UIListLayout")
streakLayout.FillDirection = Enum.FillDirection.Horizontal
streakLayout.Padding = UDim.new(0, 5)
streakLayout.Parent = streakDays

-- Claim daily button
local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 120, 0, 30)
claimBtn.Position = UDim2.new(1, -130, 0, 5)
claimBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
claimBtn.Text = "🎁 Claim!"
claimBtn.TextColor3 = Color3.new(1, 1, 1)
claimBtn.Font = Enum.Font.GothamBold
claimBtn.TextSize = 14
claimBtn.Parent = streakFrame

local clBtnCorner = Instance.new("UICorner")
clBtnCorner.CornerRadius = UDim.new(0, 8)
clBtnCorner.Parent = claimBtn

claimBtn.MouseButton1Click:Connect(function()
    Network.FireServer("ClaimDailyReward")
end)

-- Quest list
local questScroll = Instance.new("ScrollingFrame")
questScroll.Size = UDim2.new(1, -20, 1, -155)
questScroll.Position = UDim2.new(0, 10, 0, 145)
questScroll.BackgroundTransparency = 1
questScroll.ScrollBarThickness = 4
questScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
questScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
questScroll.Parent = mainFrame

local questLayout = Instance.new("UIListLayout")
questLayout.Padding = UDim.new(0, 8)
questLayout.Parent = questScroll

-- State
local quests = {}
local completedQuests = {}
local loginStreak = 1
local dailyClaimed = false

local function refreshStreakDays()
    for _, child in ipairs(streakDays:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for i = 1, 7 do
        local reward = QuestConfig.LoginStreakRewards[i]
        local dayFrame = Instance.new("Frame")
        dayFrame.Size = UDim2.new(0, 58, 0, 34)
        dayFrame.Parent = streakDays

        local dfCorner = Instance.new("UICorner")
        dfCorner.CornerRadius = UDim.new(0, 6)
        dfCorner.Parent = dayFrame

        if i < loginStreak then
            dayFrame.BackgroundColor3 = Color3.fromRGB(50, 180, 80) -- Past days (claimed)
        elseif i == loginStreak then
            dayFrame.BackgroundColor3 = Color3.fromRGB(255, 180, 50) -- Current day
        else
            dayFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60) -- Future days
        end

        local dayLabel = Instance.new("TextLabel")
        dayLabel.Size = UDim2.new(1, 0, 0.5, 0)
        dayLabel.BackgroundTransparency = 1
        dayLabel.Text = "Day " .. i
        dayLabel.TextColor3 = Color3.new(1, 1, 1)
        dayLabel.Font = Enum.Font.GothamBold
        dayLabel.TextSize = 9
        dayLabel.Parent = dayFrame

        local rewardLabel = Instance.new("TextLabel")
        rewardLabel.Size = UDim2.new(1, 0, 0.5, 0)
        rewardLabel.Position = UDim2.new(0, 0, 0.5, 0)
        rewardLabel.BackgroundTransparency = 1
        rewardLabel.Text = reward and (reward.RewardAmount .. " " .. (reward.RewardType == "Coins" and "🪙" or "💎")) or ""
        rewardLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        rewardLabel.Font = Enum.Font.Gotham
        rewardLabel.TextSize = 9
        rewardLabel.Parent = dayFrame
    end

    streakTitle.Text = "🔥 Login Streak: Day " .. loginStreak

    if dailyClaimed then
        claimBtn.Text = "✅ Claimed"
        claimBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        claimBtn.AutoButtonColor = false
    else
        claimBtn.Text = "🎁 Claim!"
        claimBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
        claimBtn.AutoButtonColor = true
    end
end

local function refreshQuests()
    for _, child in ipairs(questScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for questId, progress in pairs(quests) do
        -- Find quest config
        local questInfo = nil
        for _, q in ipairs(QuestConfig.DailyQuests) do
            if q.Id == questId then
                questInfo = q
                break
            end
        end
        if not questInfo then continue end

        local isCompleted = false
        for _, c in ipairs(completedQuests) do
            if c == questId then isCompleted = true break end
        end
        local isReady = progress >= questInfo.Target and not isCompleted

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 70)
        card.BackgroundColor3 = isCompleted and Color3.fromRGB(30, 50, 30) or Color3.fromRGB(35, 35, 55)
        card.BorderSizePixel = 0

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 10)
        cCorner.Parent = card

        -- Quest name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.6, 0, 0, 22)
        nameLabel.Position = UDim2.new(0, 12, 0, 8)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = questInfo.Name
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 15
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = card

        -- Description
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(0.6, 0, 0, 16)
        descLabel.Position = UDim2.new(0, 12, 0, 30)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = questInfo.Description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 12
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Parent = card

        -- Progress bar
        local progressBg = Instance.new("Frame")
        progressBg.Size = UDim2.new(0.5, 0, 0, 8)
        progressBg.Position = UDim2.new(0, 12, 0, 52)
        progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        progressBg.BorderSizePixel = 0
        progressBg.Parent = card

        local pbCorner = Instance.new("UICorner")
        pbCorner.CornerRadius = UDim.new(0, 4)
        pbCorner.Parent = progressBg

        local fillPct = math.clamp(progress / questInfo.Target, 0, 1)
        local progressFill = Instance.new("Frame")
        progressFill.Size = UDim2.new(fillPct, 0, 1, 0)
        progressFill.BackgroundColor3 = isReady and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(100, 150, 255)
        progressFill.BorderSizePixel = 0
        progressFill.Parent = progressBg

        local pfCorner = Instance.new("UICorner")
        pfCorner.CornerRadius = UDim.new(0, 4)
        pfCorner.Parent = progressFill

        -- Progress text
        local progLabel = Instance.new("TextLabel")
        progLabel.Size = UDim2.new(0.2, 0, 0, 14)
        progLabel.Position = UDim2.new(0.52, 0, 0, 49)
        progLabel.BackgroundTransparency = 1
        progLabel.Text = math.min(progress, questInfo.Target) .. "/" .. questInfo.Target
        progLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
        progLabel.Font = Enum.Font.Gotham
        progLabel.TextSize = 11
        progLabel.TextXAlignment = Enum.TextXAlignment.Left
        progLabel.Parent = card

        -- Reward / Claim button
        local rewardBtn = Instance.new("TextButton")
        rewardBtn.Size = UDim2.new(0, 110, 0, 40)
        rewardBtn.Position = UDim2.new(1, -120, 0.5, -20)
        rewardBtn.Font = Enum.Font.GothamBold
        rewardBtn.TextSize = 12
        rewardBtn.TextColor3 = Color3.new(1, 1, 1)
        rewardBtn.Parent = card

        local rbCorner = Instance.new("UICorner")
        rbCorner.CornerRadius = UDim.new(0, 8)
        rbCorner.Parent = rewardBtn

        if isCompleted then
            rewardBtn.Text = "✅ Claimed"
            rewardBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            rewardBtn.AutoButtonColor = false
        elseif isReady then
            rewardBtn.Text = "🎁 Claim " .. questInfo.RewardAmount .. (questInfo.RewardType == "Coins" and " 🪙" or " 💎")
            rewardBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
            rewardBtn.MouseButton1Click:Connect(function()
                Network.FireServer("ClaimQuestReward", questId)
            end)
        else
            rewardBtn.Text = questInfo.RewardAmount .. (questInfo.RewardType == "Coins" and " 🪙" or " 💎")
            rewardBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            rewardBtn.AutoButtonColor = false
        end

        card.Parent = questScroll
    end
end

-- ═══════════════════════════════════════
-- OPEN/CLOSE
-- ═══════════════════════════════════════

local function open()
    refreshStreakDays()
    refreshQuests()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 550, 0, 450),
        Position = UDim2.new(0.5, -275, 0.5, -225),
    }):Play()
end

local function close()
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    })
    tween:Play()
    tween.Completed:Wait()
    screenGui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(close)
overlay.MouseButton1Click:Connect(close)

-- Connect to side button
task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if mainHud then
        local sideButtons = mainHud:WaitForChild("SideButtons", 10)
        if sideButtons then
            local questButton = sideButtons:WaitForChild("QuestsButton", 10)
            if questButton then
                questButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

-- Events
Network.OnClientEvent("QuestUpdated", function(questData)
    quests = questData or {}
    if screenGui.Enabled then refreshQuests() end
end)

Network.OnClientEvent("DailyRewardResult", function(result)
    dailyClaimed = true
    refreshStreakDays()
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    quests = data.Quests or {}
    completedQuests = data.CompletedQuests or {}
    loginStreak = data.LoginStreak or 1
    dailyClaimed = data.DailyRewardClaimed or false
end)

print("[GUI] QuestGui loaded")
