--[[
    PetIndexGui.client.luau
    Pet collection log / index UI.
    Shows all discoverable pets and which ones the player has found.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
local EggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EggConfig"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetIndexGui"
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
mainFrame.Size = UDim2.new(0, 750, 0, 520)
mainFrame.Position = UDim2.new(0.5, -375, 0.5, -260)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 16)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(180, 130, 255)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "📖 Pet Index"
title.TextColor3 = Color3.fromRGB(200, 170, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = mainFrame

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 16)
tCorner.Parent = title

-- Progress counter
local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "Progress"
progressLabel.Size = UDim2.new(0, 300, 0, 20)
progressLabel.Position = UDim2.new(0, 10, 0, 52)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Discovered: 0/0 (0%)"
progressLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextSize = 12
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Parent = mainFrame

-- Close
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

-- Zone tabs
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, -20, 0, 30)
tabFrame.Position = UDim2.new(0, 10, 0, 76)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabFrame

local currentZoneTab = "all"

-- Pet grid
local petScroll = Instance.new("ScrollingFrame")
petScroll.Size = UDim2.new(1, -20, 1, -120)
petScroll.Position = UDim2.new(0, 10, 0, 112)
petScroll.BackgroundTransparency = 1
petScroll.ScrollBarThickness = 4
petScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
petScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
petScroll.Parent = mainFrame

local petLayout = Instance.new("UIGridLayout")
petLayout.CellSize = UDim2.new(0, 110, 0, 130)
petLayout.CellPadding = UDim2.new(0, 6, 0, 6)
petLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
petLayout.SortOrder = Enum.SortOrder.LayoutOrder
petLayout.Parent = petScroll

-- State
local petIndex = {} -- array of discovered pet keys

-- Build zone-to-pets mapping from EggConfig
local function getPetsForZone(zoneId)
    local petIds = {}
    local seen = {}
    for _, egg in ipairs(EggConfig.Eggs) do
        if egg.Zone == zoneId then
            for _, entry in ipairs(egg.Pets) do
                if not seen[entry.PetId] then
                    seen[entry.PetId] = true
                    table.insert(petIds, entry.PetId)
                end
            end
        end
    end
    return petIds
end

local function isDiscovered(petId, variant)
    local key = petId
    if variant == "golden" then key = petId .. "_golden" end
    if variant == "rainbow" then key = petId .. "_rainbow" end
    for _, entry in ipairs(petIndex) do
        if entry == key then return true end
    end
    return false
end

local function refreshIndex()
    -- Clear existing
    for _, child in ipairs(petScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Clear tabs
    for _, child in ipairs(tabFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    -- Create "All" tab
    local allTab = Instance.new("TextButton")
    allTab.Name = "all"
    allTab.Size = UDim2.new(0, 60, 0, 26)
    allTab.BackgroundColor3 = currentZoneTab == "all" and Color3.fromRGB(180, 130, 255) or Color3.fromRGB(40, 40, 60)
    allTab.Text = "All"
    allTab.TextColor3 = currentZoneTab == "all" and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)
    allTab.Font = Enum.Font.GothamBold
    allTab.TextSize = 11
    allTab.Parent = tabFrame

    local atCorner = Instance.new("UICorner")
    atCorner.CornerRadius = UDim.new(0, 6)
    atCorner.Parent = allTab

    allTab.MouseButton1Click:Connect(function()
        currentZoneTab = "all"
        refreshIndex()
    end)

    -- Create zone tabs
    for _, zone in ipairs(ZoneConfig.Zones) do
        local tab = Instance.new("TextButton")
        tab.Name = zone.Id
        tab.Size = UDim2.new(0, 90, 0, 26)
        tab.BackgroundColor3 = currentZoneTab == zone.Id and zone.Color or Color3.fromRGB(40, 40, 60)
        tab.Text = zone.Name
        tab.TextColor3 = currentZoneTab == zone.Id and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)
        tab.Font = Enum.Font.GothamBold
        tab.TextSize = 10
        tab.Parent = tabFrame

        local tCorn = Instance.new("UICorner")
        tCorn.CornerRadius = UDim.new(0, 6)
        tCorn.Parent = tab

        tab.MouseButton1Click:Connect(function()
            currentZoneTab = zone.Id
            refreshIndex()
        end)
    end

    -- Get pets to show
    local petsToShow = {}
    local totalPets = 0
    local discoveredCount = 0

    if currentZoneTab == "all" then
        for _, zone in ipairs(ZoneConfig.Zones) do
            local zonePets = getPetsForZone(zone.Id)
            for _, petId in ipairs(zonePets) do
                table.insert(petsToShow, { petId = petId, zoneId = zone.Id })
            end
        end
    else
        local zonePets = getPetsForZone(currentZoneTab)
        for _, petId in ipairs(zonePets) do
            table.insert(petsToShow, { petId = petId, zoneId = currentZoneTab })
        end
    end

    -- Count all pets for progress (base + golden + rainbow = 3 variants each)
    for _, zone in ipairs(ZoneConfig.Zones) do
        local zonePets = getPetsForZone(zone.Id)
        totalPets = totalPets + #zonePets * 3
    end
    for _, entry in ipairs(petIndex) do
        discoveredCount = discoveredCount + 1
    end

    local pct = totalPets > 0 and math.floor(discoveredCount / totalPets * 100) or 0
    progressLabel.Text = string.format("Discovered: %d/%d (%d%%)", discoveredCount, totalPets, pct)

    -- Create pet cards
    for i, entry in ipairs(petsToShow) do
        local petInfo = PetConfig.GetPet(entry.petId)
        if not petInfo then continue end

        local discovered = isDiscovered(entry.petId, nil)
        local goldenDiscovered = isDiscovered(entry.petId, "golden")
        local rainbowDiscovered = isDiscovered(entry.petId, "rainbow")
        local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]

        local card = Instance.new("Frame")
        card.Name = entry.petId
        card.LayoutOrder = i
        card.BackgroundColor3 = discovered and Color3.fromRGB(35, 35, 55) or Color3.fromRGB(18, 18, 28)
        card.BorderSizePixel = 0

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 10)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = discovered and (rarityInfo and rarityInfo.Color or Color3.fromRGB(100, 100, 100)) or Color3.fromRGB(40, 40, 40)
        cStroke.Thickness = discovered and 1.5 or 1
        cStroke.Parent = card

        -- Pet icon
        local icon = Instance.new("Frame")
        icon.Size = UDim2.new(0, 50, 0, 50)
        icon.Position = UDim2.new(0.5, -25, 0, 8)
        icon.BackgroundColor3 = discovered and (rarityInfo and rarityInfo.Color or Color3.fromRGB(150, 150, 150)) or Color3.fromRGB(40, 40, 40)
        icon.Parent = card

        local iCorner = Instance.new("UICorner")
        iCorner.CornerRadius = UDim.new(1, 0)
        iCorner.Parent = icon

        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -4, 0, 16)
        nameLabel.Position = UDim2.new(0, 2, 0, 62)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = discovered and petInfo.Name or "???"
        nameLabel.TextColor3 = discovered and Color3.new(1, 1, 1) or Color3.fromRGB(80, 80, 80)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 10
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card

        -- Rarity
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size = UDim2.new(1, 0, 0, 14)
        rarityLabel.Position = UDim2.new(0, 0, 0, 78)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = discovered and petInfo.Rarity or "???"
        rarityLabel.TextColor3 = discovered and (rarityInfo and rarityInfo.TextColor or Color3.fromRGB(200, 200, 200)) or Color3.fromRGB(60, 60, 60)
        rarityLabel.Font = Enum.Font.Gotham
        rarityLabel.TextSize = 9
        rarityLabel.Parent = card

        -- Power
        local powerLabel = Instance.new("TextLabel")
        powerLabel.Size = UDim2.new(1, 0, 0, 12)
        powerLabel.Position = UDim2.new(0, 0, 0, 92)
        powerLabel.BackgroundTransparency = 1
        powerLabel.Text = discovered and ("⚡" .. petInfo.Power) or ""
        powerLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
        powerLabel.Font = Enum.Font.Gotham
        powerLabel.TextSize = 9
        powerLabel.Parent = card

        -- Variant indicators (bottom of card)
        local variantFrame = Instance.new("Frame")
        variantFrame.Size = UDim2.new(1, -8, 0, 16)
        variantFrame.Position = UDim2.new(0, 4, 0, 108)
        variantFrame.BackgroundTransparency = 1
        variantFrame.Parent = card

        local vLayout = Instance.new("UIListLayout")
        vLayout.FillDirection = Enum.FillDirection.Horizontal
        vLayout.Padding = UDim.new(0, 2)
        vLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        vLayout.Parent = variantFrame

        -- Base variant dot
        local baseDot = Instance.new("Frame")
        baseDot.Size = UDim2.new(0, 12, 0, 12)
        baseDot.BackgroundColor3 = discovered and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(50, 50, 50)
        baseDot.Parent = variantFrame
        local bdCorner = Instance.new("UICorner")
        bdCorner.CornerRadius = UDim.new(1, 0)
        bdCorner.Parent = baseDot

        -- Golden variant dot
        local goldDot = Instance.new("Frame")
        goldDot.Size = UDim2.new(0, 12, 0, 12)
        goldDot.BackgroundColor3 = goldenDiscovered and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(50, 50, 50)
        goldDot.Parent = variantFrame
        local gdCorner = Instance.new("UICorner")
        gdCorner.CornerRadius = UDim.new(1, 0)
        gdCorner.Parent = goldDot

        -- Rainbow variant dot
        local rainbowDot = Instance.new("Frame")
        rainbowDot.Size = UDim2.new(0, 12, 0, 12)
        rainbowDot.BackgroundColor3 = rainbowDiscovered and Color3.fromRGB(255, 100, 255) or Color3.fromRGB(50, 50, 50)
        rainbowDot.Parent = variantFrame
        local rdCorner = Instance.new("UICorner")
        rdCorner.CornerRadius = UDim.new(1, 0)
        rdCorner.Parent = rainbowDot

        card.Parent = petScroll
    end
end

-- ═══════════════════════════════════════
-- OPEN/CLOSE
-- ═══════════════════════════════════════

local function open()
    refreshIndex()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 750, 0, 520),
        Position = UDim2.new(0.5, -375, 0.5, -260),
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
            local indexButton = sideButtons:WaitForChild("IndexButton", 10)
            if indexButton then
                indexButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

-- Data listeners
Network.OnClientEvent("PetsUpdated", function()
    if screenGui.Enabled then
        refreshIndex()
    end
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    petIndex = data.PetIndex or {}
end)

print("[GUI] PetIndexGui loaded")
