--[[
    DailyInfoGui.client.luau
    Shows today's rotating content: featured pets, daily theme, special egg, mutations.
    Opens from "Daily" button in MainHUD side panel.
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
local PetVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("PetVisualUtil"))
local NumberFormat = require(Shared:WaitForChild("Utils"):WaitForChild("NumberFormat"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DailyInfoGui"
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
mainFrame.Size = UDim2.new(0, 650, 0, 480)
mainFrame.Position = UDim2.new(0.5, -325, 0.5, -240)
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
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "Today's Rotation"
title.TextColor3 = Color3.fromRGB(255, 200, 80)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = mainFrame

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 16)
tCorner.Parent = title

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = title

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 10)
cbCorner.Parent = closeBtn

-- Countdown timer
local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "Countdown"
countdownLabel.Size = UDim2.new(0, 200, 0, 20)
countdownLabel.Position = UDim2.new(0, 10, 0, 52)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Text = "Resets in: --:--:--"
countdownLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
countdownLabel.Font = Enum.Font.Gotham
countdownLabel.TextSize = 12
countdownLabel.TextXAlignment = Enum.TextXAlignment.Left
countdownLabel.Parent = mainFrame

-- Content scroll
local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -20, 1, -80)
contentScroll.Position = UDim2.new(0, 10, 0, 76)
contentScroll.BackgroundTransparency = 1
contentScroll.ScrollBarThickness = 4
contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentScroll.Parent = mainFrame

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 12)
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.Parent = contentScroll

-- State
local rotationData = nil
local resetTime = 0

-- ═══════════════════════════════════════
-- SECTION BUILDERS
-- ═══════════════════════════════════════

local function createSectionHeader(parent, text, color)
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = color or Color3.fromRGB(40, 40, 60)
    header.Text = "  " .. text
    header.TextColor3 = Color3.new(1, 1, 1)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 14
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = parent

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 8)
    hCorner.Parent = header

    return header
end

local function buildThemeSection(theme)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -10, 0, 80)
    section.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    section.BorderSizePixel = 0
    section.Parent = contentScroll

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 10)
    sCorner.Parent = section

    local tintColor = Color3.fromRGB(
        theme.TintColor[1] * 255,
        theme.TintColor[2] * 255,
        theme.TintColor[3] * 255
    )

    local sStroke = Instance.new("UIStroke")
    sStroke.Color = tintColor
    sStroke.Thickness = 2
    sStroke.Parent = section

    createSectionHeader(section, "Daily Theme: " .. theme.Name, tintColor)

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -16, 0, 20)
    desc.Position = UDim2.new(0, 8, 0, 34)
    desc.BackgroundTransparency = 1
    desc.Text = theme.Description
    desc.TextColor3 = Color3.fromRGB(220, 220, 220)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 13
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = section

    local boostLabel = Instance.new("TextLabel")
    boostLabel.Size = UDim2.new(1, -16, 0, 18)
    boostLabel.Position = UDim2.new(0, 8, 0, 56)
    boostLabel.BackgroundTransparency = 1
    boostLabel.Text = "Active Boost: " .. theme.BoostMultiplier .. "x " .. theme.BoostType
    boostLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    boostLabel.Font = Enum.Font.GothamBold
    boostLabel.TextSize = 12
    boostLabel.TextXAlignment = Enum.TextXAlignment.Left
    boostLabel.Parent = section
end

local function buildFeaturedPetsSection(featuredPets)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -10, 0, 130)
    section.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    section.BorderSizePixel = 0
    section.Parent = contentScroll

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 10)
    sCorner.Parent = section

    local sStroke = Instance.new("UIStroke")
    sStroke.Color = Color3.fromRGB(255, 200, 80)
    sStroke.Thickness = 1.5
    sStroke.Parent = section

    createSectionHeader(section, "Featured Pets (2x Drop Rate!)", Color3.fromRGB(255, 200, 80))

    local petsRow = Instance.new("Frame")
    petsRow.Size = UDim2.new(1, -16, 0, 90)
    petsRow.Position = UDim2.new(0, 8, 0, 34)
    petsRow.BackgroundTransparency = 1
    petsRow.Parent = section

    local pLayout = Instance.new("UIListLayout")
    pLayout.FillDirection = Enum.FillDirection.Horizontal
    pLayout.Padding = UDim.new(0, 10)
    pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    pLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    pLayout.Parent = petsRow

    for _, petData in ipairs(featuredPets) do
        local petInfo = PetConfig.GetPet(petData.Id)
        if not petInfo then continue end

        local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 120, 0, 85)
        card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        card.BorderSizePixel = 0
        card.Parent = petsRow

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = rarityInfo and rarityInfo.Color or Color3.fromRGB(150, 150, 150)
        cStroke.Thickness = 1.5
        cStroke.Parent = card

        -- Pet icon
        local iconContainer = Instance.new("Frame")
        iconContainer.Size = UDim2.new(0, 36, 0, 36)
        iconContainer.Position = UDim2.new(0.5, -18, 0, 4)
        iconContainer.BackgroundTransparency = 1
        iconContainer.Parent = card

        PetVisualUtil.CreateIcon(iconContainer, petInfo, nil, UDim2.new(1, 0, 1, 0))

        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -4, 0, 14)
        nameLabel.Position = UDim2.new(0, 2, 0, 42)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = petInfo.Name
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 10
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card

        -- Rarity
        local rarLabel = Instance.new("TextLabel")
        rarLabel.Size = UDim2.new(1, 0, 0, 12)
        rarLabel.Position = UDim2.new(0, 0, 0, 56)
        rarLabel.BackgroundTransparency = 1
        rarLabel.Text = petInfo.Rarity
        rarLabel.TextColor3 = rarityInfo and rarityInfo.TextColor or Color3.fromRGB(200, 200, 200)
        rarLabel.Font = Enum.Font.Gotham
        rarLabel.TextSize = 9
        rarLabel.Parent = card

        -- 2x badge
        local badge = Instance.new("TextLabel")
        badge.Size = UDim2.new(0, 30, 0, 14)
        badge.Position = UDim2.new(1, -32, 0, 2)
        badge.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
        badge.Text = "2x"
        badge.TextColor3 = Color3.new(1, 1, 1)
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 9
        badge.Parent = card

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 4)
        bCorner.Parent = badge
    end
end

local function buildSpecialEggSection(eggData)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -10, 0, 80)
    section.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    section.BorderSizePixel = 0
    section.Parent = contentScroll

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 10)
    sCorner.Parent = section

    local sStroke = Instance.new("UIStroke")
    sStroke.Color = Color3.fromRGB(100, 200, 255)
    sStroke.Thickness = 1.5
    sStroke.Parent = section

    createSectionHeader(section, "Special Egg: " .. eggData.Name, Color3.fromRGB(100, 200, 255))

    local costLabel = Instance.new("TextLabel")
    costLabel.Size = UDim2.new(1, -16, 0, 18)
    costLabel.Position = UDim2.new(0, 8, 0, 34)
    costLabel.BackgroundTransparency = 1
    costLabel.Text = "Cost: " .. NumberFormat.Abbreviate(eggData.Cost) .. " " .. eggData.Currency
    costLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    costLabel.Font = Enum.Font.Gotham
    costLabel.TextSize = 12
    costLabel.TextXAlignment = Enum.TextXAlignment.Left
    costLabel.Parent = section

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -16, 0, 18)
    infoLabel.Position = UDim2.new(0, 8, 0, 54)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Limited edition! Only available today!"
    infoLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
    infoLabel.Font = Enum.Font.GothamBold
    infoLabel.TextSize = 11
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = section
end

local function buildMutationsSection(mutations)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -10, 0, 80)
    section.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    section.BorderSizePixel = 0
    section.Parent = contentScroll

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 10)
    sCorner.Parent = section

    local sStroke = Instance.new("UIStroke")
    sStroke.Color = Color3.fromRGB(255, 100, 255)
    sStroke.Thickness = 1.5
    sStroke.Parent = section

    createSectionHeader(section, "Today's Mutations", Color3.fromRGB(255, 100, 255))

    local yPos = 34
    for _, mutation in ipairs(mutations) do
        local mutLabel = Instance.new("TextLabel")
        mutLabel.Size = UDim2.new(1, -16, 0, 16)
        mutLabel.Position = UDim2.new(0, 8, 0, yPos)
        mutLabel.BackgroundTransparency = 1
        mutLabel.Text = mutation.MutationName .. " (" .. mutation.PowerMultiplier .. "x Power) — Fuse 3 " .. mutation.BasePetId:gsub("_", " ") .. "s!"
        mutLabel.TextColor3 = Color3.fromRGB(255, 180, 255)
        mutLabel.Font = Enum.Font.Gotham
        mutLabel.TextSize = 11
        mutLabel.TextXAlignment = Enum.TextXAlignment.Left
        mutLabel.Parent = section
        yPos = yPos + 18
    end
end

local function refreshContent()
    -- Clear existing content
    for _, child in ipairs(contentScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    if not rotationData then return end

    -- Build sections
    buildThemeSection(rotationData.Theme)
    buildFeaturedPetsSection(rotationData.FeaturedPets)
    buildSpecialEggSection(rotationData.SpecialEgg)
    if rotationData.Mutations and #rotationData.Mutations > 0 then
        buildMutationsSection(rotationData.Mutations)
    end
end

-- ═══════════════════════════════════════
-- COUNTDOWN TIMER
-- ═══════════════════════════════════════

task.spawn(function()
    while true do
        task.wait(1)
        if resetTime > 0 then
            resetTime = resetTime - 1
            local hours = math.floor(resetTime / 3600)
            local mins = math.floor((resetTime % 3600) / 60)
            local secs = resetTime % 60
            countdownLabel.Text = string.format("Resets in: %d:%02d:%02d", hours, mins, secs)
        end
    end
end)

-- ═══════════════════════════════════════
-- OPEN/CLOSE
-- ═══════════════════════════════════════

local function open()
    -- Request latest rotation data
    Network.FireServer("RequestDailyRotation")
    refreshContent()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 650, 0, 480),
        Position = UDim2.new(0.5, -325, 0.5, -240),
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
            local dailyButton = sideButtons:WaitForChild("DailyButton", 10)
            if dailyButton then
                dailyButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

-- Data listeners
Network.OnClientEvent("DailyRotation", function(data)
    rotationData = data
    resetTime = data.SecondsUntilReset or 0
    if screenGui.Enabled then
        refreshContent()
    end
end)

print("[GUI] DailyInfoGui loaded")
