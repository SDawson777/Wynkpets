--[[
    AchievementGui.client.luau
    Shows achievement cards with progress tracking.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local AchievementConfig = require(Shared:WaitForChild("Configs"):WaitForChild("AchievementConfig"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AchievementGui"
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
mainFrame.Size = UDim2.new(0, 600, 0, 480)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 16)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(255, 180, 50)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 44)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "Achievements"
title.TextColor3 = Color3.fromRGB(255, 180, 50)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = mainFrame

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 16)
tCorner.Parent = title

-- Progress counter
local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "Progress"
progressLabel.Size = UDim2.new(0, 200, 0, 20)
progressLabel.Position = UDim2.new(0, 10, 0, 46)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "0/0 Completed"
progressLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextSize = 12
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Parent = mainFrame

-- Close
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -40, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = title

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 10)
cbCorner.Parent = closeBtn

-- Achievement grid
local achieveScroll = Instance.new("ScrollingFrame")
achieveScroll.Size = UDim2.new(1, -20, 1, -80)
achieveScroll.Position = UDim2.new(0, 10, 0, 70)
achieveScroll.BackgroundTransparency = 1
achieveScroll.ScrollBarThickness = 4
achieveScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
achieveScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
achieveScroll.Parent = mainFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 275, 0, 70)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = achieveScroll

-- State
local playerAchievements = {}

local function refreshAchievements()
    for _, child in ipairs(achieveScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local completedCount = 0
    local totalCount = #AchievementConfig.Achievements

    for i, achievement in ipairs(AchievementConfig.Achievements) do
        local completed = playerAchievements[achievement.Id] == true
        if completed then completedCount = completedCount + 1 end

        local card = Instance.new("Frame")
        card.Name = achievement.Id
        card.LayoutOrder = completed and (1000 + i) or i -- uncompleted first
        card.BackgroundColor3 = completed and Color3.fromRGB(35, 50, 35) or Color3.fromRGB(35, 35, 55)
        card.BorderSizePixel = 0
        card.Parent = achieveScroll

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = completed and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(80, 80, 100)
        cStroke.Thickness = completed and 2 or 1
        cStroke.Parent = card

        -- Checkmark / lock icon
        local statusIcon = Instance.new("TextLabel")
        statusIcon.Size = UDim2.new(0, 24, 0, 24)
        statusIcon.Position = UDim2.new(0, 6, 0, 6)
        statusIcon.BackgroundTransparency = 1
        statusIcon.Text = completed and "✓" or "○"
        statusIcon.TextColor3 = completed and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(100, 100, 120)
        statusIcon.Font = Enum.Font.GothamBold
        statusIcon.TextSize = 18
        statusIcon.Parent = card

        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -40, 0, 18)
        nameLabel.Position = UDim2.new(0, 34, 0, 4)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = achievement.Name
        nameLabel.TextColor3 = completed and Color3.fromRGB(100, 255, 100) or Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 13
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card

        -- Description
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -40, 0, 14)
        descLabel.Position = UDim2.new(0, 34, 0, 22)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = achievement.Description
        descLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 10
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextTruncate = Enum.TextTruncate.AtEnd
        descLabel.Parent = card

        -- Reward
        local rewardLabel = Instance.new("TextLabel")
        rewardLabel.Size = UDim2.new(1, -10, 0, 16)
        rewardLabel.Position = UDim2.new(0, 5, 1, -20)
        rewardLabel.BackgroundTransparency = 1
        rewardLabel.Text = "+" .. achievement.Reward.Amount .. " " .. achievement.Reward.Currency
        rewardLabel.TextColor3 = completed and Color3.fromRGB(100, 180, 100) or Color3.fromRGB(120, 210, 255)
        rewardLabel.Font = Enum.Font.GothamBold
        rewardLabel.TextSize = 11
        rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
        rewardLabel.Parent = card
    end

    progressLabel.Text = completedCount .. "/" .. totalCount .. " Completed"
end

-- Open/Close
local function open()
    refreshAchievements()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 600, 0, 480),
        Position = UDim2.new(0.5, -300, 0.5, -240),
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

-- Network
Network.OnClientEvent("PlayerDataLoaded", function(data)
    playerAchievements = data.Achievements or {}
end)

Network.OnClientEvent("AchievementUnlocked", function(achievementId)
    playerAchievements[achievementId] = true
    if screenGui.Enabled then
        refreshAchievements()
    end
end)

-- Connect to side button
task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if mainHud then
        local sideButtons = mainHud:WaitForChild("SideButtons", 10)
        if sideButtons then
            local achieveButton = sideButtons:WaitForChild("AchieveButton", 10)
            if achieveButton then
                achieveButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

print("[GUI] AchievementGui loaded")
