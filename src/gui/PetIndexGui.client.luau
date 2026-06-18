--[[
    PetIndexGui.client.luau
    Pokédex-style pet collection log.
    Left panel: filterable pet grid with zone + orb-set tabs.
    Right panel: detail view — lore, utility, rarity, power, variant ownership.

    Fixed vs. prior version:
    - petDiscovered is a hash-set built directly from data.Pets on PlayerDataLoaded
    - PetsUpdated now correctly populates new entries
    - Added detail panel showing full lore and ability text
    - Added Orb Sets tracker tab
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
local SecretConfig = require(Shared:WaitForChild("Configs"):WaitForChild("SecretConfig"))
local EggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EggConfig"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local PetVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("PetVisualUtil"))

-- ═══════════════════════════════════════
-- RARITY COLORS
-- ═══════════════════════════════════════
local RARITY_COLOR = {
    Common    = Color3.fromRGB(180, 180, 180),
    Rare      = Color3.fromRGB(80, 140, 255),
    Epic      = Color3.fromRGB(180, 70, 255),
    Legendary = Color3.fromRGB(255, 200, 30),
    Mythic    = Color3.fromRGB(255, 80, 160),
    Secret    = Color3.fromRGB(60, 255, 180),
}

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════
-- petDiscovered[petId] = true  (base variant)
-- petDiscovered[petId.."_golden"] = true
-- petDiscovered[petId.."_rainbow"] = true
local petDiscovered = {}
local orbSetProgress = {} -- zoneId -> { collected, required, rewardPetId, completed }
local currentTab = "all"
local selectedPetId = nil

-- ═══════════════════════════════════════
-- SCREEN GUI
-- Main window: 860 x 560
-- Left panel (520 px): tabs + pet grid
-- Right panel (310 px): pet detail
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
mainFrame.Size = UDim2.new(0, 860, 0, 560)
mainFrame.Position = UDim2.new(0.5, -430, 0.5, -280)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 16); c.Parent = mainFrame
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(160, 100, 255); s.Thickness = 2; s.Parent = mainFrame
end

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 16); c.Parent = titleBar end

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "📖  Pet Index"
titleLabel.TextColor3 = Color3.fromRGB(210, 170, 255)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 22
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "Progress"
progressLabel.Size = UDim2.new(0, 360, 0, 16)
progressLabel.Position = UDim2.new(0, 16, 0, 52)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Discovered: 0/0"
progressLabel.TextColor3 = Color3.fromRGB(150, 150, 190)
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextSize = 12
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 38, 0, 38)
closeBtn.Position = UDim2.new(1, -44, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = titleBar
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = closeBtn end

-- ─── LEFT panel ──────────────────────────────────────────────────────────────
local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0, 520, 1, -70)
leftPanel.Position = UDim2.new(0, 10, 0, 70)
leftPanel.BackgroundTransparency = 1
leftPanel.Parent = mainFrame

local tabRow = Instance.new("Frame")
tabRow.Size = UDim2.new(1, 0, 0, 28)
tabRow.BackgroundTransparency = 1
tabRow.Parent = leftPanel
do
    local tl = Instance.new("UIListLayout")
    tl.FillDirection = Enum.FillDirection.Horizontal
    tl.Padding = UDim.new(0, 4)
    tl.Parent = tabRow
end

local petScroll = Instance.new("ScrollingFrame")
petScroll.Size = UDim2.new(1, 0, 1, -34)
petScroll.Position = UDim2.new(0, 0, 0, 34)
petScroll.BackgroundTransparency = 1
petScroll.ScrollBarThickness = 4
petScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
petScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
petScroll.Parent = leftPanel
do
    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0, 100, 0, 122)
    gl.CellPadding = UDim2.new(0, 5, 0, 5)
    gl.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gl.SortOrder = Enum.SortOrder.LayoutOrder
    gl.Parent = petScroll
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingTop = UDim.new(0, 2)
    pad.Parent = petScroll
end

-- Orb sets panel (shown when "Orb Sets" tab is active)
local orbSetFrame = Instance.new("ScrollingFrame")
orbSetFrame.Name = "OrbSetFrame"
orbSetFrame.Size = UDim2.new(1, 0, 1, -34)
orbSetFrame.Position = UDim2.new(0, 0, 0, 34)
orbSetFrame.BackgroundTransparency = 1
orbSetFrame.ScrollBarThickness = 4
orbSetFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
orbSetFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
orbSetFrame.Visible = false
orbSetFrame.Parent = leftPanel
do
    local ol = Instance.new("UIListLayout")
    ol.SortOrder = Enum.SortOrder.LayoutOrder
    ol.Padding = UDim.new(0, 8)
    ol.Parent = orbSetFrame
    local op = Instance.new("UIPadding")
    op.PaddingLeft = UDim.new(0, 4)
    op.PaddingTop = UDim.new(0, 4)
    op.Parent = orbSetFrame
end

-- ─── RIGHT panel (detail) ─────────────────────────────────────────────────────
local detailPanel = Instance.new("Frame")
detailPanel.Name = "DetailPanel"
detailPanel.Size = UDim2.new(0, 310, 1, -70)
detailPanel.Position = UDim2.new(0, 540, 0, 70)
detailPanel.BackgroundColor3 = Color3.fromRGB(24, 24, 42)
detailPanel.BorderSizePixel = 0
detailPanel.Parent = mainFrame
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = detailPanel
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(100, 60, 180); s.Thickness = 1; s.Parent = detailPanel
end

local detailPlaceholder = Instance.new("TextLabel")
detailPlaceholder.Name = "Placeholder"
detailPlaceholder.Size = UDim2.new(1, 0, 1, 0)
detailPlaceholder.BackgroundTransparency = 1
detailPlaceholder.Text = "Click a pet to\nview its lore"
detailPlaceholder.TextColor3 = Color3.fromRGB(80, 80, 120)
detailPlaceholder.Font = Enum.Font.Gotham
detailPlaceholder.TextSize = 14
detailPlaceholder.Parent = detailPanel

local detailScroll = Instance.new("ScrollingFrame")
detailScroll.Name = "DetailScroll"
detailScroll.Size = UDim2.new(1, -8, 1, -8)
detailScroll.Position = UDim2.new(0, 4, 0, 4)
detailScroll.BackgroundTransparency = 1
detailScroll.ScrollBarThickness = 3
detailScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
detailScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
detailScroll.Visible = false
detailScroll.Parent = detailPanel
do
    local dl = Instance.new("UIListLayout")
    dl.SortOrder = Enum.SortOrder.LayoutOrder
    dl.Padding = UDim.new(0, 6)
    dl.Parent = detailScroll
    local dp = Instance.new("UIPadding")
    dp.PaddingLeft = UDim.new(0, 10)
    dp.PaddingRight = UDim.new(0, 10)
    dp.PaddingTop = UDim.new(0, 10)
    dp.Parent = detailScroll
end

-- ═══════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════

local function isDiscovered(petId)
    return petDiscovered[petId] == true
end

local function isGoldenDiscovered(petId)
    return petDiscovered[petId .. "_golden"] == true
end

local function isRainbowDiscovered(petId)
    return petDiscovered[petId .. "_rainbow"] == true
end

local function discoveredCount()
    local n = 0
    for petId, _ in pairs(petDiscovered) do
        if not petId:find("_golden", 1, true) and not petId:find("_rainbow", 1, true) then
            n = n + 1
        end
    end
    return n
end

-- Build petDiscovered set from the Pets array in player save data
local function applyPetsData(pets)
    if type(pets) ~= "table" then return end
    for _, entry in ipairs(pets) do
        local id = entry.PetId
        if id then
            petDiscovered[id] = true
            if entry.Golden then petDiscovered[id .. "_golden"] = true end
            if entry.Rainbow then petDiscovered[id .. "_rainbow"] = true end
        end
    end
end

local function getEggForPet(petId)
    for _, egg in ipairs(EggConfig.Eggs) do
        for _, entry in ipairs(egg.Pets) do
            if entry.PetId == petId then return egg end
        end
    end
    return nil
end

local function getZoneName(zoneId)
    if not zoneId then return "Unknown" end
    local zone = ZoneConfig.GetZone and ZoneConfig.GetZone(zoneId)
    if zone then return zone.Name or zoneId end
    return zoneId:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
end

local function makeDivider(parent, layoutOrder)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(55, 55, 90)
    d.BorderSizePixel = 0
    d.LayoutOrder = layoutOrder
    d.Parent = parent
end

local function makeTextRow(parent, labelText, valueText, layoutOrder, valueColor)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.BackgroundTransparency = 1
    row.LayoutOrder = layoutOrder
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Text = "<b>" .. labelText .. "</b>  " .. tostring(valueText)
    lbl.TextColor3 = valueColor or Color3.fromRGB(190, 190, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.RichText = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
end

local function makeSectionHeader(parent, headerText, layoutOrder, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = headerText
    lbl.TextColor3 = color or Color3.fromRGB(200, 160, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.LayoutOrder = layoutOrder
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
end

local function makeBodyText(parent, bodyText, layoutOrder, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Text = bodyText
    lbl.TextColor3 = color or Color3.fromRGB(165, 165, 205)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = layoutOrder
    lbl.Parent = lbl
    lbl.Parent = parent
    return lbl
end

-- ═══════════════════════════════════════
-- DETAIL PANEL
-- ═══════════════════════════════════════

local function showPetDetail(petInfo)
    selectedPetId = petInfo.Id
    local discovered = isDiscovered(petInfo.Id)

    for _, child in ipairs(detailScroll:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
    detailPlaceholder.Visible = false
    detailScroll.Visible = true

    local rarityColor = RARITY_COLOR[petInfo.Rarity] or Color3.fromRGB(200, 200, 200)

    -- Icon frame
    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.new(1, 0, 0, 90)
    iconFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 52)
    iconFrame.BorderSizePixel = 0
    iconFrame.LayoutOrder = 1
    iconFrame.Parent = detailScroll
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = iconFrame
        local s = Instance.new("UIStroke"); s.Color = rarityColor; s.Thickness = 2; s.Parent = iconFrame
    end

    local iconImg = Instance.new("ImageLabel")
    iconImg.Size = UDim2.new(0, 70, 0, 70)
    iconImg.Position = UDim2.new(0.5, -35, 0.5, -35)
    iconImg.BackgroundTransparency = 1
    iconImg.Image = discovered and PetVisualUtil.GetPetImage(petInfo, nil) or "rbxassetid://0"
    iconImg.ImageColor3 = discovered and Color3.new(1, 1, 1) or Color3.fromRGB(35, 35, 35)
    iconImg.Parent = iconFrame

    -- Name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 20)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = discovered and petInfo.Name or "???"
    nameLbl.TextColor3 = discovered and Color3.new(1, 1, 1) or Color3.fromRGB(80, 80, 90)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 16
    nameLbl.LayoutOrder = 2
    nameLbl.Parent = detailScroll

    -- Rarity badge
    local rarityLbl = Instance.new("TextLabel")
    rarityLbl.Size = UDim2.new(1, 0, 0, 16)
    rarityLbl.BackgroundTransparency = 1
    rarityLbl.Text = discovered and petInfo.Rarity or "???"
    rarityLbl.TextColor3 = discovered and rarityColor or Color3.fromRGB(55, 55, 70)
    rarityLbl.Font = Enum.Font.GothamBold
    rarityLbl.TextSize = 12
    rarityLbl.LayoutOrder = 3
    rarityLbl.Parent = detailScroll

    makeDivider(detailScroll, 4)

    if discovered then
        -- Stats
        makeTextRow(detailScroll, "⚡ Power:", tostring(petInfo.Power), 5)

        local egg = getEggForPet(petInfo.Id)
        if egg then
            makeTextRow(detailScroll, "🥚 Egg:", egg.Name, 6)
            if egg.Zone then
                makeTextRow(detailScroll, "📍 Zone:", getZoneName(egg.Zone), 7)
            end
        elseif petInfo.OrbSet then
            makeTextRow(detailScroll, "🔮 Source:", "Orb Set — " .. getZoneName(petInfo.OrbSet), 7,
                Color3.fromRGB(60, 255, 180))
        end

        -- Variant ownership
        local varStr =
            (isDiscovered(petInfo.Id)        and "◉ Base  " or "◌ Base  ")
            .. (isGoldenDiscovered(petInfo.Id)  and "◉ Golden  " or "◌ Golden  ")
            .. (isRainbowDiscovered(petInfo.Id) and "◉ Rainbow" or "◌ Rainbow")
        makeTextRow(detailScroll, "✨ Variants:", varStr, 8)
        makeDivider(detailScroll, 9)

        -- Description
        if petInfo.Description and petInfo.Description ~= "" then
            makeBodyText(detailScroll, petInfo.Description, 10, Color3.fromRGB(185, 225, 185))
            makeDivider(detailScroll, 11)
        end

        -- Lore
        if petInfo.Lore and petInfo.Lore ~= "" then
            makeSectionHeader(detailScroll, "📜  Lore", 12, Color3.fromRGB(200, 160, 255))
            makeBodyText(detailScroll, petInfo.Lore, 13, Color3.fromRGB(165, 165, 205))
            makeDivider(detailScroll, 14)
        end

        -- Utility / ability
        if petInfo.Utility and petInfo.Utility ~= "" then
            makeSectionHeader(detailScroll, "⚙️  Ability", 15, Color3.fromRGB(255, 200, 80))
            makeBodyText(detailScroll, petInfo.Utility, 16, Color3.fromRGB(255, 230, 140))
        end
    else
        local notFound = Instance.new("TextLabel")
        notFound.Size = UDim2.new(1, 0, 0, 0)
        notFound.AutomaticSize = Enum.AutomaticSize.Y
        notFound.BackgroundTransparency = 1
        notFound.Text = "Not yet discovered.\n\nFind this creature to\nunlock its lore and\nabilities."
        notFound.TextColor3 = Color3.fromRGB(80, 80, 110)
        notFound.Font = Enum.Font.Gotham
        notFound.TextSize = 13
        notFound.TextWrapped = true
        notFound.LayoutOrder = 5
        notFound.Parent = detailScroll
    end

    detailScroll.CanvasPosition = Vector2.new(0, 0)
end

-- ═══════════════════════════════════════
-- ORB SETS PANEL
-- ═══════════════════════════════════════

local function refreshOrbSetPanel()
    for _, child in ipairs(orbSetFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for _, zoneId in ipairs(SecretConfig.ZoneOrder) do
        local setConfig = SecretConfig.OrbSets[zoneId]
        local prog = orbSetProgress[zoneId] or { collected = 0, required = 3, completed = false }
        local orbColor = SecretConfig.ZoneOrbColors[zoneId] or Color3.fromRGB(255, 215, 0)

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 62)
        row.BackgroundColor3 = Color3.fromRGB(26, 26, 46)
        row.BorderSizePixel = 0
        row.Parent = orbSetFrame
        do
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = row
            local s = Instance.new("UIStroke")
            s.Color = orbColor
            s.Thickness = prog.completed and 2 or 1
            s.Transparency = prog.completed and 0 or 0.55
            s.Parent = row
        end

        -- Color swatch
        local swatch = Instance.new("Frame")
        swatch.Size = UDim2.new(0, 14, 0, 14)
        swatch.Position = UDim2.new(0, 10, 0.5, -7)
        swatch.BackgroundColor3 = orbColor
        swatch.BorderSizePixel = 0
        swatch.Parent = row
        do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = swatch end

        -- Zone label
        local zoneLbl = Instance.new("TextLabel")
        zoneLbl.Size = UDim2.new(0, 200, 0, 20)
        zoneLbl.Position = UDim2.new(0, 32, 0, 8)
        zoneLbl.BackgroundTransparency = 1
        zoneLbl.Text = getZoneName(zoneId)
        zoneLbl.TextColor3 = prog.completed and Color3.fromRGB(60, 255, 180) or Color3.fromRGB(200, 200, 225)
        zoneLbl.Font = Enum.Font.GothamBold
        zoneLbl.TextSize = 13
        zoneLbl.TextXAlignment = Enum.TextXAlignment.Left
        zoneLbl.Parent = row

        -- Orb dots
        local dotsFrame = Instance.new("Frame")
        dotsFrame.Size = UDim2.new(0, 70, 0, 14)
        dotsFrame.Position = UDim2.new(0, 32, 0, 36)
        dotsFrame.BackgroundTransparency = 1
        dotsFrame.Parent = row
        do
            local dl = Instance.new("UIListLayout")
            dl.FillDirection = Enum.FillDirection.Horizontal
            dl.Padding = UDim.new(0, 4)
            dl.Parent = dotsFrame
        end

        local required = setConfig and setConfig.RequiredCount or 3
        for i = 1, required do
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 14, 0, 14)
            dot.BackgroundColor3 = (i <= (prog.collected or 0)) and orbColor or Color3.fromRGB(45, 45, 65)
            dot.BorderSizePixel = 0
            dot.Parent = dotsFrame
            do local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot end
        end

        -- Status text
        local statusStr
        if prog.completed then
            statusStr = "✓ Pet unlocked!"
        else
            statusStr = (prog.collected or 0) .. "/" .. required .. " orbs collected"
        end
        local statusLbl = Instance.new("TextLabel")
        statusLbl.Size = UDim2.new(0, 200, 0, 14)
        statusLbl.Position = UDim2.new(0, 115, 0, 38)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Text = statusStr
        statusLbl.TextColor3 = prog.completed and Color3.fromRGB(60, 255, 160) or Color3.fromRGB(130, 130, 165)
        statusLbl.Font = Enum.Font.Gotham
        statusLbl.TextSize = 11
        statusLbl.TextXAlignment = Enum.TextXAlignment.Left
        statusLbl.Parent = row
    end
end

-- ═══════════════════════════════════════
-- TABS
-- ═══════════════════════════════════════

local tabButtons = {}

local function setTab(tabId)
    currentTab = tabId
    for id, btn in pairs(tabButtons) do
        if id == tabId then
            btn.BackgroundColor3 = Color3.fromRGB(110, 55, 210)
            btn.TextColor3 = Color3.new(1, 1, 1)
        else
            btn.BackgroundColor3 = Color3.fromRGB(38, 38, 62)
            btn.TextColor3 = Color3.fromRGB(155, 155, 195)
        end
    end
    if tabId == "orbsets" then
        petScroll.Visible = false
        orbSetFrame.Visible = true
        refreshOrbSetPanel()
    else
        petScroll.Visible = true
        orbSetFrame.Visible = false
    end
end

local function makeTab(id, labelText, sortOrder)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 0, 0, 26)
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.BackgroundColor3 = Color3.fromRGB(38, 38, 62)
    btn.Text = " " .. labelText .. " "
    btn.TextColor3 = Color3.fromRGB(155, 155, 195)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.LayoutOrder = sortOrder
    btn.Parent = tabRow
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn end
    tabButtons[id] = btn
    btn.MouseButton1Click:Connect(function() setTab(id) end)
    return btn
end

-- ═══════════════════════════════════════
-- PET GRID
-- ═══════════════════════════════════════

local function getPetsForTab(tabId)
    if tabId == "all" then
        return PetConfig.Pets
    elseif tabId == "secret" then
        local result = {}
        for _, p in ipairs(PetConfig.Pets) do
            if p.Rarity == "Secret" then table.insert(result, p) end
        end
        return result
    elseif tabId == "orbsets" then
        return {}
    else
        -- Zone tab
        local result, seen = {}, {}
        -- Include orb-set secret pets for this zone
        for _, p in ipairs(PetConfig.Pets) do
            if p.OrbSet == tabId and not seen[p.Id] then
                seen[p.Id] = true
                table.insert(result, p)
            end
        end
        -- Include egg hatched pets for this zone
        for _, egg in ipairs(EggConfig.Eggs) do
            if egg.Zone == tabId then
                for _, entry in ipairs(egg.Pets) do
                    if not seen[entry.PetId] then
                        seen[entry.PetId] = true
                        local petInfo = PetConfig.GetPet(entry.PetId)
                        if petInfo then table.insert(result, petInfo) end
                    end
                end
            end
        end
        return result
    end
end

local function refreshGrid()
    for _, child in ipairs(petScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
    end

    local total = #PetConfig.Pets
    local found = discoveredCount()
    progressLabel.Text = "Discovered: " .. found .. "/" .. total
        .. " (" .. math.floor(found / math.max(total, 1) * 100) .. "%)"

    local petsToShow = getPetsForTab(currentTab)
    for idx, petInfo in ipairs(petsToShow) do
        local discovered  = isDiscovered(petInfo.Id)
        local goldenOwned = isGoldenDiscovered(petInfo.Id)
        local rainbowOwned = isRainbowDiscovered(petInfo.Id)
        local rarityColor = RARITY_COLOR[petInfo.Rarity] or Color3.fromRGB(180, 180, 180)

        local card = Instance.new("TextButton")
        card.Size = UDim2.new(0, 100, 0, 122)
        card.BackgroundColor3 = discovered and Color3.fromRGB(28, 28, 50) or Color3.fromRGB(16, 16, 26)
        card.AutoButtonColor = false
        card.Text = ""
        card.LayoutOrder = idx
        card.Parent = petScroll
        do
            local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 8); cc.Parent = card
            local cs = Instance.new("UIStroke")
            cs.Color = discovered and rarityColor or Color3.fromRGB(38, 38, 58)
            cs.Thickness = discovered and 2 or 1
            cs.Transparency = discovered and 0 or 0.5
            cs.Parent = card
        end

        -- Icon
        local iconImg = Instance.new("ImageLabel")
        iconImg.Size = UDim2.new(0, 62, 0, 62)
        iconImg.Position = UDim2.new(0.5, -31, 0, 5)
        iconImg.BackgroundTransparency = 1
        iconImg.Image = PetVisualUtil.GetPetImage(petInfo, nil)
        iconImg.ImageColor3 = discovered and Color3.new(1, 1, 1) or Color3.fromRGB(18, 18, 28)
        iconImg.Parent = card

        if not discovered then
            local silFrame = Instance.new("Frame")
            silFrame.Size = UDim2.new(0, 62, 0, 62)
            silFrame.Position = UDim2.new(0.5, -31, 0, 5)
            silFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
            silFrame.BorderSizePixel = 0
            silFrame.Parent = card
            do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = silFrame end
            local qm = Instance.new("TextLabel")
            qm.Size = UDim2.new(1, 0, 1, 0)
            qm.BackgroundTransparency = 1
            qm.Text = "?"
            qm.TextColor3 = Color3.fromRGB(50, 50, 68)
            qm.Font = Enum.Font.GothamBlack
            qm.TextSize = 28
            qm.Parent = silFrame
        end

        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -4, 0, 14)
        nameLabel.Position = UDim2.new(0, 2, 0, 70)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = discovered and petInfo.Name or "???"
        nameLabel.TextColor3 = discovered and Color3.new(1, 1, 1) or Color3.fromRGB(52, 52, 65)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 10
        nameLabel.TextWrapped = true
        nameLabel.Parent = card

        -- Rarity
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size = UDim2.new(1, -4, 0, 11)
        rarityLabel.Position = UDim2.new(0, 2, 0, 85)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = discovered and petInfo.Rarity or "???"
        rarityLabel.TextColor3 = discovered and rarityColor or Color3.fromRGB(45, 45, 60)
        rarityLabel.Font = Enum.Font.GothamBold
        rarityLabel.TextSize = 9
        rarityLabel.Parent = card

        -- Variant dots (base, golden, rainbow)
        local dotsFrame = Instance.new("Frame")
        dotsFrame.Size = UDim2.new(1, -8, 0, 11)
        dotsFrame.Position = UDim2.new(0, 4, 0, 99)
        dotsFrame.BackgroundTransparency = 1
        dotsFrame.Parent = card
        do
            local dl = Instance.new("UIListLayout")
            dl.FillDirection = Enum.FillDirection.Horizontal
            dl.Padding = UDim.new(0, 3)
            dl.HorizontalAlignment = Enum.HorizontalAlignment.Center
            dl.Parent = dotsFrame
        end
        for _, dotColor in ipairs({
            discovered    and Color3.fromRGB(90, 210, 90)  or Color3.fromRGB(35, 35, 48),
            goldenOwned   and Color3.fromRGB(255, 215, 0)  or Color3.fromRGB(35, 35, 48),
            rainbowOwned  and Color3.fromRGB(255, 100, 255) or Color3.fromRGB(35, 35, 48),
        }) do
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 11, 0, 11)
            dot.BackgroundColor3 = dotColor
            dot.BorderSizePixel = 0
            dot.Parent = dotsFrame
            do local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot end
        end

        -- Hover highlight
        card.MouseEnter:Connect(function()
            if petInfo.Id ~= selectedPetId then
                card.BackgroundColor3 = Color3.fromRGB(36, 36, 60)
            end
        end)
        card.MouseLeave:Connect(function()
            if petInfo.Id ~= selectedPetId then
                card.BackgroundColor3 = discovered and Color3.fromRGB(28, 28, 50) or Color3.fromRGB(16, 16, 26)
            end
        end)

        card.MouseButton1Click:Connect(function()
            showPetDetail(petInfo)
        end)
    end
end

local function refreshAll()
    -- Rebuild tabs
    for _, child in ipairs(tabRow:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    tabButtons = {}

    makeTab("all", "All", 1)
    local order = 2
    for _, zone in ipairs(ZoneConfig.Zones) do
        makeTab(zone.Id, zone.Name or zone.Id, order)
        order = order + 1
    end
    makeTab("secret", "★ Secret", order)
    makeTab("orbsets", "🔮 Orb Sets", order + 1)

    setTab(currentTab)
    refreshGrid()
end

-- ═══════════════════════════════════════
-- OPEN / CLOSE
-- ═══════════════════════════════════════

local function open()
    refreshAll()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 860, 0, 560),
        Position = UDim2.new(0.5, -430, 0.5, -280),
    }):Play()
end

local function close()
    local t = TweenService:Create(mainFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    })
    t:Play()
    t.Completed:Wait()
    screenGui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(close)
overlay.MouseButton1Click:Connect(close)

-- ═══════════════════════════════════════
-- SIDE BUTTON
-- ═══════════════════════════════════════

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

-- ═══════════════════════════════════════
-- NETWORK LISTENERS
-- ═══════════════════════════════════════

-- Full data on login — rebuild discovered set from actual data.Pets
Network.OnClientEvent("PlayerDataLoaded", function(data)
    petDiscovered = {}
    applyPetsData(data.Pets)
    if data.CompletedOrbSets then
        for zoneId, completed in pairs(data.CompletedOrbSets) do
            if not orbSetProgress[zoneId] then orbSetProgress[zoneId] = {} end
            orbSetProgress[zoneId].completed = completed
        end
    end
    if screenGui.Enabled then
        refreshGrid()
    end
end)

-- Pet inventory updated (hatches, trades, etc.)
Network.OnClientEvent("PetsUpdated", function(pets)
    applyPetsData(pets)
    if screenGui.Enabled then
        refreshGrid()
        if selectedPetId and isDiscovered(selectedPetId) then
            local petInfo = PetConfig.GetPet(selectedPetId)
            if petInfo then showPetDetail(petInfo) end
        end
    end
end)

-- Orb set progress from server
Network.OnClientEvent("OrbSetProgress", function(progress)
    orbSetProgress = progress or {}
    if screenGui.Enabled and currentTab == "orbsets" then
        refreshOrbSetPanel()
    end
end)

-- Orb set completed — pet gifted
Network.OnClientEvent("OrbSetCompleted", function(zoneId, _rewardPetId)
    if not orbSetProgress[zoneId] then orbSetProgress[zoneId] = {} end
    orbSetProgress[zoneId].completed = true
    if screenGui.Enabled then
        if currentTab == "orbsets" then refreshOrbSetPanel() end
        refreshGrid()
    end
end)

print("[GUI] PetIndexGui loaded")
