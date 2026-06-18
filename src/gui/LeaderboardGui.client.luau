--[[
    LeaderboardGui.client.luau
    Tabbed leaderboard showing top players and your rank.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LeaderboardGui"
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
mainFrame.Size = UDim2.new(0, 500, 0, 450)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 16)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(255, 200, 50)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 44)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "Leaderboards"
title.TextColor3 = Color3.fromRGB(255, 200, 50)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = mainFrame

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 16)
tCorner.Parent = title

-- Close button
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

-- Tabs
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, -20, 0, 30)
tabFrame.Position = UDim2.new(0, 10, 0, 48)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 5)
tabLayout.Parent = tabFrame

local CATEGORIES = {
    { Id = "TotalCoinsEarned", Name = "Coins" },
    { Id = "TotalEggsHatched", Name = "Eggs" },
    { Id = "Rebirths", Name = "Rebirths" },
    { Id = "BestPetPower", Name = "Power" },
}

local currentCategory = CATEGORIES[1].Id

-- Scrolling list
local listScroll = Instance.new("ScrollingFrame")
listScroll.Size = UDim2.new(1, -20, 1, -95)
listScroll.Position = UDim2.new(0, 10, 0, 85)
listScroll.BackgroundTransparency = 1
listScroll.ScrollBarThickness = 4
listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
listScroll.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.Parent = listScroll

-- State
local leaderboardData = {}

local function refreshList()
    for _, child in ipairs(listScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local data = leaderboardData[currentCategory] or {}

    for _, entry in ipairs(data) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = entry.UserId == player.UserId
            and Color3.fromRGB(50, 60, 40) or Color3.fromRGB(30, 30, 50)
        row.BackgroundTransparency = 0.3
        row.BorderSizePixel = 0
        row.Parent = listScroll

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 6)
        rCorner.Parent = row

        -- Rank
        local rankLabel = Instance.new("TextLabel")
        rankLabel.Size = UDim2.new(0, 40, 1, 0)
        rankLabel.BackgroundTransparency = 1
        rankLabel.Text = "#" .. entry.Rank
        rankLabel.Font = Enum.Font.GothamBold
        rankLabel.TextSize = 14
        rankLabel.Parent = row

        if entry.Rank == 1 then
            rankLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        elseif entry.Rank == 2 then
            rankLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        elseif entry.Rank == 3 then
            rankLabel.TextColor3 = Color3.fromRGB(205, 127, 50)
        else
            rankLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        end

        -- Name (use UserId, real name fetched async)
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -140, 1, 0)
        nameLabel.Position = UDim2.new(0, 45, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = "Player " .. tostring(entry.UserId)
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 13
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = row

        -- Try to get display name
        task.spawn(function()
            local success, name = pcall(function()
                return Players:GetNameFromUserIdAsync(entry.UserId)
            end)
            if success and name then
                nameLabel.Text = name
            end
        end)

        -- Value
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0, 90, 1, 0)
        valueLabel.Position = UDim2.new(1, -95, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 13
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = row

        local v = entry.Value
        if v >= 1000000000 then
            valueLabel.Text = string.format("%.1fB", v / 1000000000)
        elseif v >= 1000000 then
            valueLabel.Text = string.format("%.1fM", v / 1000000)
        elseif v >= 1000 then
            valueLabel.Text = string.format("%.1fK", v / 1000)
        else
            valueLabel.Text = tostring(v)
        end
    end

    if #data == 0 then
        local emptyLabel = Instance.new("Frame")
        emptyLabel.Size = UDim2.new(1, 0, 0, 40)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Parent = listScroll

        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = "No data yet..."
        txt.TextColor3 = Color3.fromRGB(120, 120, 140)
        txt.Font = Enum.Font.Gotham
        txt.TextSize = 14
        txt.Parent = emptyLabel
    end
end

-- Create tabs
for _, cat in ipairs(CATEGORIES) do
    local tab = Instance.new("TextButton")
    tab.Name = cat.Id
    tab.Size = UDim2.new(0, 110, 0, 28)
    tab.BackgroundColor3 = cat.Id == currentCategory
        and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(40, 40, 60)
    tab.Text = cat.Name
    tab.TextColor3 = cat.Id == currentCategory
        and Color3.fromRGB(20, 20, 35) or Color3.fromRGB(150, 150, 150)
    tab.Font = Enum.Font.GothamBold
    tab.TextSize = 12
    tab.Parent = tabFrame

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 6)
    tc.Parent = tab

    tab.MouseButton1Click:Connect(function()
        currentCategory = cat.Id
        -- Update tab visuals
        for _, btn in ipairs(tabFrame:GetChildren()) do
            if btn:IsA("TextButton") then
                if btn.Name == currentCategory then
                    btn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
                    btn.TextColor3 = Color3.fromRGB(20, 20, 35)
                else
                    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
                end
            end
        end
        refreshList()
        Network.FireServer("RequestLeaderboard", currentCategory)
    end)
end

-- Open/Close
local function open()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 500, 0, 450),
        Position = UDim2.new(0.5, -250, 0.5, -225),
    }):Play()
    Network.FireServer("RequestLeaderboard", currentCategory)
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

-- Network listeners
Network.OnClientEvent("LeaderboardData", function(category, data)
    leaderboardData[category] = data
    if category == currentCategory then
        refreshList()
    end
end)

-- Connect to side button
task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if mainHud then
        local sideButtons = mainHud:WaitForChild("SideButtons", 10)
        if sideButtons then
            local ranksButton = sideButtons:WaitForChild("RanksButton", 10)
            if ranksButton then
                ranksButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

print("[GUI] LeaderboardGui loaded")
