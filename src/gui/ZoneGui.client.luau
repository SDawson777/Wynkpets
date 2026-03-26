--[[
    ZoneGui.client.luau
    Zone selection, teleportation, and unlock UI.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local NumberFormat = require(Shared:WaitForChild("Utils"):WaitForChild("NumberFormat"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZoneGui"
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
mainFrame.Size = UDim2.new(0, 600, 0, 400)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 16)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(100, 180, 255)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "🗺️ Zones"
title.TextColor3 = Color3.fromRGB(100, 200, 255)
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

-- Zone scroll
local zoneScroll = Instance.new("ScrollingFrame")
zoneScroll.Size = UDim2.new(1, -20, 1, -70)
zoneScroll.Position = UDim2.new(0, 10, 0, 60)
zoneScroll.BackgroundTransparency = 1
zoneScroll.ScrollBarThickness = 4
zoneScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
zoneScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
zoneScroll.Parent = mainFrame

local zoneLayout = Instance.new("UIListLayout")
zoneLayout.Padding = UDim.new(0, 10)
zoneLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
zoneLayout.Parent = zoneScroll

local unlockedZones = { "starter_meadow" }

local function refreshZones()
    for _, child in ipairs(zoneScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    for _, zone in ipairs(ZoneConfig.Zones) do
        local isUnlocked = false
        for _, id in ipairs(unlockedZones) do
            if id == zone.Id then
                isUnlocked = true
                break
            end
        end

        local card = Instance.new("Frame")
        card.Name = zone.Id
        card.Size = UDim2.new(1, -20, 0, 90)
        card.BackgroundColor3 = isUnlocked and Color3.fromRGB(35, 40, 55) or Color3.fromRGB(25, 25, 35)
        card.BorderSizePixel = 0

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 12)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = isUnlocked and zone.Color or Color3.fromRGB(50, 50, 50)
        cStroke.Thickness = 2
        cStroke.Parent = card

        -- Color indicator
        local colorBar = Instance.new("Frame")
        colorBar.Size = UDim2.new(0, 8, 1, -10)
        colorBar.Position = UDim2.new(0, 8, 0, 5)
        colorBar.BackgroundColor3 = zone.Color
        colorBar.BorderSizePixel = 0
        colorBar.Parent = card

        local cbr = Instance.new("UICorner")
        cbr.CornerRadius = UDim.new(0, 4)
        cbr.Parent = colorBar

        -- Zone name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.5, 0, 0, 28)
        nameLabel.Position = UDim2.new(0, 28, 0, 8)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = zone.Name
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 18
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = card

        -- Description
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(0.6, 0, 0, 18)
        descLabel.Position = UDim2.new(0, 28, 0, 36)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = zone.Description
        descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 12
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextTruncate = Enum.TextTruncate.AtEnd
        descLabel.Parent = card

        -- Multiplier info
        local multLabel = Instance.new("TextLabel")
        multLabel.Size = UDim2.new(0.4, 0, 0, 16)
        multLabel.Position = UDim2.new(0, 28, 0, 58)
        multLabel.BackgroundTransparency = 1
        multLabel.Text = "💰 " .. zone.CoinMultiplier .. "x Coins"
        multLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
        multLabel.Font = Enum.Font.Gotham
        multLabel.TextSize = 12
        multLabel.TextXAlignment = Enum.TextXAlignment.Left
        multLabel.Parent = card

        -- Action button
        local actionBtn = Instance.new("TextButton")
        actionBtn.Size = UDim2.new(0, 140, 0, 40)
        actionBtn.Position = UDim2.new(1, -155, 0.5, -20)
        actionBtn.Font = Enum.Font.GothamBold
        actionBtn.TextSize = 14
        actionBtn.TextColor3 = Color3.new(1, 1, 1)
        actionBtn.AutoButtonColor = true
        actionBtn.Parent = card

        local abCorner = Instance.new("UICorner")
        abCorner.CornerRadius = UDim.new(0, 8)
        abCorner.Parent = actionBtn

        if isUnlocked then
            actionBtn.Text = "🚀 Teleport"
            actionBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)

            actionBtn.MouseButton1Click:Connect(function()
                Network.FireServer("TeleportToZone", zone.Id)
                -- Close the GUI
                screenGui.Enabled = false
            end)
        elseif zone.UnlockCost == 0 then
            actionBtn.Text = "✅ Free"
            actionBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
            actionBtn.MouseButton1Click:Connect(function()
                Network.FireServer("UnlockZone", zone.Id)
            end)
        else
            actionBtn.Text = "🔓 " .. NumberFormat.Abbreviate(zone.UnlockCost) .. " " .. zone.UnlockCurrency
            actionBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)

            actionBtn.MouseButton1Click:Connect(function()
                Network.FireServer("UnlockZone", zone.Id)
            end)
        end

        card.Parent = zoneScroll
    end
end

-- ═══════════════════════════════════════
-- OPEN/CLOSE
-- ═══════════════════════════════════════

local function open()
    refreshZones()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 600, 0, 400),
        Position = UDim2.new(0.5, -300, 0.5, -200),
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
            local zonesButton = sideButtons:WaitForChild("ZonesButton", 10)
            if zonesButton then
                zonesButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

-- Events
Network.OnClientEvent("ZoneUnlocked", function(zoneId)
    local found = false
    for _, id in ipairs(unlockedZones) do
        if id == zoneId then found = true break end
    end
    if not found then table.insert(unlockedZones, zoneId) end
    if screenGui.Enabled then refreshZones() end
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    unlockedZones = data.UnlockedZones or { "starter_meadow" }
end)

print("[GUI] ZoneGui loaded")
