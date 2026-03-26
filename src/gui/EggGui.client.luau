--[[
    EggGui.client.luau
    Egg selection and hatching UI.
    Shows available eggs per zone with hatch chances.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EggConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local NumberFormat = require(Shared:WaitForChild("Utils"):WaitForChild("NumberFormat"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggGui"
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
mainFrame.Size = UDim2.new(0, 750, 0, 500)
mainFrame.Position = UDim2.new(0.5, -375, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 16)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(255, 230, 100)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "🥚 Egg Hatchery"
title.TextColor3 = Color3.fromRGB(255, 230, 100)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = mainFrame

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 16)
tCorner.Parent = title

-- Close button
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

-- Egg scroll area
local eggScroll = Instance.new("ScrollingFrame")
eggScroll.Size = UDim2.new(1, -20, 1, -70)
eggScroll.Position = UDim2.new(0, 10, 0, 60)
eggScroll.BackgroundTransparency = 1
eggScroll.ScrollBarThickness = 4
eggScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
eggScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
eggScroll.Parent = mainFrame

local eggLayout = Instance.new("UIGridLayout")
eggLayout.CellSize = UDim2.new(0, 230, 0, 320)
eggLayout.CellPadding = UDim2.new(0, 10, 0, 10)
eggLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
eggLayout.Parent = eggScroll

local unlockedZones = { "starter_meadow" }

-- Populate eggs
local function refreshEggs()
    for _, child in ipairs(eggScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    for _, egg in ipairs(EggConfig.Eggs) do
        local zone = ZoneConfig.GetZone(egg.Zone)
        local isUnlocked = false
        for _, zId in ipairs(unlockedZones) do
            if zId == egg.Zone then
                isUnlocked = true
                break
            end
        end

        local card = Instance.new("Frame")
        card.Name = egg.Id
        card.BackgroundColor3 = isUnlocked and Color3.fromRGB(35, 35, 55) or Color3.fromRGB(25, 25, 35)
        card.BorderSizePixel = 0

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 12)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = isUnlocked and (zone and zone.Color or Color3.fromRGB(100, 100, 100)) or Color3.fromRGB(50, 50, 50)
        cStroke.Thickness = 2
        cStroke.Parent = card

        -- Egg visual
        local eggVisual = Instance.new("Frame")
        eggVisual.Size = UDim2.new(0, 80, 0, 100)
        eggVisual.Position = UDim2.new(0.5, -40, 0, 10)
        eggVisual.BackgroundColor3 = isUnlocked and Color3.fromRGB(255, 240, 200) or Color3.fromRGB(80, 80, 80)
        eggVisual.Parent = card

        local evCorner = Instance.new("UICorner")
        evCorner.CornerRadius = UDim.new(0.35, 0)
        evCorner.Parent = eggVisual

        -- Egg name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 24)
        nameLabel.Position = UDim2.new(0, 0, 0, 115)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = egg.Name
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 16
        nameLabel.Parent = card

        -- Zone label
        local zoneLabel = Instance.new("TextLabel")
        zoneLabel.Size = UDim2.new(1, 0, 0, 16)
        zoneLabel.Position = UDim2.new(0, 0, 0, 137)
        zoneLabel.BackgroundTransparency = 1
        zoneLabel.Text = zone and zone.Name or egg.Zone
        zoneLabel.TextColor3 = zone and zone.Color or Color3.fromRGB(150, 150, 150)
        zoneLabel.Font = Enum.Font.Gotham
        zoneLabel.TextSize = 11
        zoneLabel.Parent = card

        -- Pet chances list
        local chanceY = 158
        local totalWeight = 0
        for _, entry in ipairs(egg.Pets) do
            totalWeight = totalWeight + entry.Weight
        end

        for _, entry in ipairs(egg.Pets) do
            local petInfo = PetConfig.GetPet(entry.PetId)
            if petInfo then
                local chance = (entry.Weight / totalWeight) * 100
                local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]

                local petLine = Instance.new("TextLabel")
                petLine.Size = UDim2.new(1, -16, 0, 14)
                petLine.Position = UDim2.new(0, 8, 0, chanceY)
                petLine.BackgroundTransparency = 1
                petLine.Text = string.format("%s - %.1f%%", petInfo.Name, chance)
                petLine.TextColor3 = rarityInfo and rarityInfo.TextColor or Color3.fromRGB(200, 200, 200)
                petLine.Font = Enum.Font.Gotham
                petLine.TextSize = 10
                petLine.TextXAlignment = Enum.TextXAlignment.Left
                petLine.Parent = card

                chanceY = chanceY + 15
            end
        end

        -- Hatch button
        local hatchBtn = Instance.new("TextButton")
        hatchBtn.Size = UDim2.new(0.85, 0, 0, 36)
        hatchBtn.Position = UDim2.new(0.075, 0, 1, -44)
        hatchBtn.Font = Enum.Font.GothamBold
        hatchBtn.TextSize = 14
        hatchBtn.TextColor3 = Color3.new(1, 1, 1)
        hatchBtn.AutoButtonColor = true
        hatchBtn.Parent = card

        local hbCorner = Instance.new("UICorner")
        hbCorner.CornerRadius = UDim.new(0, 8)
        hbCorner.Parent = hatchBtn

        if isUnlocked then
            hatchBtn.Text = "🥚 Hatch - " .. NumberFormat.Abbreviate(egg.Cost) .. " " .. egg.Currency
            hatchBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
            hatchBtn.TextColor3 = Color3.fromRGB(30, 30, 30)

            hatchBtn.MouseButton1Click:Connect(function()
                Network.FireServer("HatchEgg", egg.Id)
            end)
        else
            hatchBtn.Text = "🔒 Locked"
            hatchBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            hatchBtn.AutoButtonColor = false
        end

        card.Parent = eggScroll
    end
end

-- ═══════════════════════════════════════
-- OPEN/CLOSE
-- ═══════════════════════════════════════

local function open()
    refreshEggs()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 750, 0, 500),
        Position = UDim2.new(0.5, -375, 0.5, -250),
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
            local eggsButton = sideButtons:WaitForChild("EggsButton", 10)
            if eggsButton then
                eggsButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

-- Update on zone unlock
Network.OnClientEvent("ZoneUnlocked", function(zoneId)
    local found = false
    for _, id in ipairs(unlockedZones) do
        if id == zoneId then found = true break end
    end
    if not found then
        table.insert(unlockedZones, zoneId)
    end
    if screenGui.Enabled then
        refreshEggs()
    end
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    unlockedZones = data.UnlockedZones or { "starter_meadow" }
end)

print("[GUI] EggGui loaded")
