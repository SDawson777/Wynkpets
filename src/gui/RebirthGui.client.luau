--[[
    RebirthGui.client.luau
    Rebirth/prestige UI with clear progression display.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local RebirthConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RebirthConfig"))
local NumberFormat = require(Shared:WaitForChild("Utils"):WaitForChild("NumberFormat"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RebirthGui"
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
mfStroke.Color = Color3.fromRGB(255, 100, 150)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "⭐ Rebirth"
title.TextColor3 = Color3.fromRGB(255, 150, 200)
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

-- Current status
local statusFrame = Instance.new("Frame")
statusFrame.Size = UDim2.new(1, -40, 0, 100)
statusFrame.Position = UDim2.new(0, 20, 0, 65)
statusFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
statusFrame.BorderSizePixel = 0
statusFrame.Parent = mainFrame

local sfcCorner = Instance.new("UICorner")
sfcCorner.CornerRadius = UDim.new(0, 12)
sfcCorner.Parent = statusFrame

local currentRebirthLabel = Instance.new("TextLabel")
currentRebirthLabel.Name = "CurrentRebirth"
currentRebirthLabel.Size = UDim2.new(1, 0, 0, 30)
currentRebirthLabel.Position = UDim2.new(0, 0, 0, 10)
currentRebirthLabel.BackgroundTransparency = 1
currentRebirthLabel.Text = "Current Rebirth: 0"
currentRebirthLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
currentRebirthLabel.Font = Enum.Font.GothamBold
currentRebirthLabel.TextSize = 20
currentRebirthLabel.Parent = statusFrame

local multiplierLabel = Instance.new("TextLabel")
multiplierLabel.Name = "Multiplier"
multiplierLabel.Size = UDim2.new(0.5, 0, 0, 24)
multiplierLabel.Position = UDim2.new(0, 10, 0, 45)
multiplierLabel.BackgroundTransparency = 1
multiplierLabel.Text = "Multiplier: 1.0x"
multiplierLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
multiplierLabel.Font = Enum.Font.Gotham
multiplierLabel.TextSize = 14
multiplierLabel.TextXAlignment = Enum.TextXAlignment.Left
multiplierLabel.Parent = statusFrame

local slotsLabel = Instance.new("TextLabel")
slotsLabel.Name = "Slots"
slotsLabel.Size = UDim2.new(0.5, 0, 0, 24)
slotsLabel.Position = UDim2.new(0.5, 0, 0, 45)
slotsLabel.BackgroundTransparency = 1
slotsLabel.Text = "Pet Slots: 3"
slotsLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
slotsLabel.Font = Enum.Font.Gotham
slotsLabel.TextSize = 14
slotsLabel.TextXAlignment = Enum.TextXAlignment.Left
slotsLabel.Parent = statusFrame

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsNeeded"
coinsLabel.Size = UDim2.new(1, -20, 0, 20)
coinsLabel.Position = UDim2.new(0, 10, 0, 72)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "Coins: 0 / 10,000"
coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
coinsLabel.Font = Enum.Font.Gotham
coinsLabel.TextSize = 13
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Parent = statusFrame

-- Next rebirth rewards
local rewardFrame = Instance.new("Frame")
rewardFrame.Size = UDim2.new(1, -40, 0, 100)
rewardFrame.Position = UDim2.new(0, 20, 0, 180)
rewardFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
rewardFrame.BorderSizePixel = 0
rewardFrame.Parent = mainFrame

local rfCorner = Instance.new("UICorner")
rfCorner.CornerRadius = UDim.new(0, 12)
rfCorner.Parent = rewardFrame

local rewardTitle = Instance.new("TextLabel")
rewardTitle.Size = UDim2.new(1, 0, 0, 28)
rewardTitle.BackgroundTransparency = 1
rewardTitle.Text = "Next Rebirth Rewards:"
rewardTitle.TextColor3 = Color3.fromRGB(100, 255, 150)
rewardTitle.Font = Enum.Font.GothamBold
rewardTitle.TextSize = 15
rewardTitle.Parent = rewardFrame

local rewardMultLabel = Instance.new("TextLabel")
rewardMultLabel.Name = "RewardMult"
rewardMultLabel.Size = UDim2.new(1, -20, 0, 20)
rewardMultLabel.Position = UDim2.new(0, 10, 0, 35)
rewardMultLabel.BackgroundTransparency = 1
rewardMultLabel.Text = "• Multiplier: 1.5x"
rewardMultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
rewardMultLabel.Font = Enum.Font.Gotham
rewardMultLabel.TextSize = 13
rewardMultLabel.TextXAlignment = Enum.TextXAlignment.Left
rewardMultLabel.Parent = rewardFrame

local rewardSlotsLabel = Instance.new("TextLabel")
rewardSlotsLabel.Name = "RewardSlots"
rewardSlotsLabel.Size = UDim2.new(1, -20, 0, 20)
rewardSlotsLabel.Position = UDim2.new(0, 10, 0, 58)
rewardSlotsLabel.BackgroundTransparency = 1
rewardSlotsLabel.Text = "• +1 Pet Equip Slot"
rewardSlotsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
rewardSlotsLabel.Font = Enum.Font.Gotham
rewardSlotsLabel.TextSize = 13
rewardSlotsLabel.TextXAlignment = Enum.TextXAlignment.Left
rewardSlotsLabel.Parent = rewardFrame

-- Warning
local warningLabel = Instance.new("TextLabel")
warningLabel.Size = UDim2.new(1, -40, 0, 40)
warningLabel.Position = UDim2.new(0, 20, 0, 295)
warningLabel.BackgroundTransparency = 1
warningLabel.Text = "⚠️ Rebirth resets your Coins and Zone progress.\nYou keep Gems, Pets, and Gamepasses!"
warningLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
warningLabel.Font = Enum.Font.Gotham
warningLabel.TextSize = 12
warningLabel.TextWrapped = true
warningLabel.Parent = mainFrame

-- Rebirth button
local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Name = "RebirthButton"
rebirthBtn.Size = UDim2.new(0.7, 0, 0, 50)
rebirthBtn.Position = UDim2.new(0.15, 0, 1, -70)
rebirthBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
rebirthBtn.Text = "⭐ Rebirth ⭐"
rebirthBtn.TextColor3 = Color3.new(1, 1, 1)
rebirthBtn.Font = Enum.Font.GothamBold
rebirthBtn.TextSize = 22
rebirthBtn.AutoButtonColor = true
rebirthBtn.Parent = mainFrame

local rbCorner = Instance.new("UICorner")
rbCorner.CornerRadius = UDim.new(0, 12)
rbCorner.Parent = rebirthBtn

local rbStroke = Instance.new("UIStroke")
rbStroke.Color = Color3.fromRGB(255, 100, 150)
rbStroke.Thickness = 2
rbStroke.Parent = rebirthBtn

-- State
local playerRebirths = 0
local playerMultiplier = 1.0
local playerMaxSlots = 3
local playerCoins = 0

local function updateDisplay()
    currentRebirthLabel.Text = "Current Rebirth: " .. playerRebirths
    multiplierLabel.Text = "Multiplier: " .. playerMultiplier .. "x"
    slotsLabel.Text = "Pet Slots: " .. playerMaxSlots

    local nextTier = RebirthConfig.GetNextTier(playerRebirths)
    if nextTier then
        coinsLabel.Text = string.format("Coins: %s / %s",
            NumberFormat.Abbreviate(playerCoins),
            NumberFormat.Abbreviate(nextTier.Cost))
        rewardMultLabel.Text = "• Multiplier: " .. nextTier.Multiplier .. "x"
        rewardSlotsLabel.Text = "• +" .. nextTier.BonusEquipSlots .. " Pet Equip Slot(s)"

        if playerCoins >= nextTier.Cost then
            rebirthBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 130)
            rebirthBtn.Text = "⭐ REBIRTH NOW ⭐"
        else
            rebirthBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            rebirthBtn.Text = "⭐ Need " .. NumberFormat.Abbreviate(nextTier.Cost - playerCoins) .. " more Coins"
        end
    else
        coinsLabel.Text = "Max rebirth reached!"
        rewardMultLabel.Text = "• None"
        rewardSlotsLabel.Text = ""
        rebirthBtn.Text = "✅ Max Rebirth!"
        rebirthBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
        rebirthBtn.AutoButtonColor = false
    end
end

rebirthBtn.MouseButton1Click:Connect(function()
    local nextTier = RebirthConfig.GetNextTier(playerRebirths)
    if nextTier and playerCoins >= nextTier.Cost then
        Network.FireServer("RequestRebirth")
    end
end)

-- ═══════════════════════════════════════
-- OPEN/CLOSE
-- ═══════════════════════════════════════

local function open()
    updateDisplay()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 500, 0, 450),
        Position = UDim2.new(0.5, -250, 0.5, -225),
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
            local rebirthButton = sideButtons:WaitForChild("RebirthButton", 10)
            if rebirthButton then
                rebirthButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

-- Events
Network.OnClientEvent("CurrencyUpdated", function(currency, amount)
    if currency == "Coins" then
        playerCoins = amount
        if screenGui.Enabled then updateDisplay() end
    end
end)

Network.OnClientEvent("RebirthCompleted", function(data)
    playerRebirths = data.Rebirths or 0
    playerMultiplier = data.Multiplier or 1.0
    playerMaxSlots = data.MaxEquipSlots or 3
    playerCoins = 0
    if screenGui.Enabled then updateDisplay() end
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    playerRebirths = data.Rebirths or 0
    playerMultiplier = data.RebirthMultiplier or 1.0
    playerMaxSlots = data.MaxEquipSlots or 3
    playerCoins = data.Coins or 0
end)

print("[GUI] RebirthGui loaded")
