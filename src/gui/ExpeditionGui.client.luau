--[[
    ExpeditionGui.client.luau
    Full UI for the Pet Expedition system.
    Two tabs: "Available" (browse expeditions) and "Active" (manage ongoing).
    Players pick an unequipped pet, choose a zone + tier, then send it off.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ExpeditionConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ExpeditionConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local PetLevelConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetLevelConfig"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
local PetVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("PetVisualUtil"))

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════

local expeditionData = { Active = {}, Completed = 0, MaxSlots = 1 }
local playerPets = {}
local equippedPets = {}
local selectedZone = nil
local selectedTier = nil
local activeTab = "available" -- "available" | "active"

-- ═══════════════════════════════════════
-- COLOURS / STYLE CONSTANTS
-- ═══════════════════════════════════════

local COLORS = {
    BG        = Color3.fromRGB(15, 12, 30),
    Panel     = Color3.fromRGB(25, 22, 45),
    Card      = Color3.fromRGB(35, 30, 55),
    CardHover = Color3.fromRGB(50, 42, 75),
    Accent    = Color3.fromRGB(120, 80, 255),
    AccentAlt = Color3.fromRGB(255, 170, 50),
    Success   = Color3.fromRGB(60, 200, 100),
    Danger    = Color3.fromRGB(220, 60, 60),
    Text      = Color3.fromRGB(240, 240, 255),
    TextDim   = Color3.fromRGB(160, 155, 180),
    Gold      = Color3.fromRGB(255, 215, 0),
    Gem       = Color3.fromRGB(100, 200, 255),
}

local RARITY_COLORS = {
    Common    = Color3.fromRGB(180, 180, 180),
    Rare      = Color3.fromRGB(50, 180, 255),
    Epic      = Color3.fromRGB(180, 50, 255),
    Legendary = Color3.fromRGB(255, 180, 0),
    Mythic    = Color3.fromRGB(255, 50, 100),
    Secret    = Color3.fromRGB(255, 255, 100),
}

-- ═══════════════════════════════════════
-- HELPER: effective power for a pet
-- ═══════════════════════════════════════

local function getEffectivePower(pet)
    local petInfo = PetConfig.GetPet(pet.PetId)
    if not petInfo then return 1 end
    local basePower = petInfo.Power or 1
    local levelMult = PetLevelConfig.GetPowerMultiplier(pet.Level or 1)
    local power = basePower * levelMult
    if pet.Golden then power = power * 2.5 end
    if pet.Rainbow then power = power * 5 end
    return math.floor(power)
end

local function formatDuration(seconds)
    if seconds <= 0 then return "Done!" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %dm", h, m)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", s)
    end
end

local function isPetOnExpedition(uuid)
    for _, e in ipairs(expeditionData.Active) do
        if e.PetUUID == uuid then return true end
    end
    return false
end

local function isPetEquipped(uuid)
    for _, id in ipairs(equippedPets) do
        if id == uuid then return true end
    end
    return false
end

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExpeditionGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 12
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
mainFrame.Size = UDim2.new(0, 800, 0, 540)
mainFrame.Position = UDim2.new(0.5, -400, 0.5, -270)
mainFrame.BackgroundColor3 = COLORS.BG
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)
local mfStroke = Instance.new("UIStroke", mainFrame)
mfStroke.Color = COLORS.Accent
mfStroke.Thickness = 2

-- ═══════════════════════════════════════
-- HEADER
-- ═══════════════════════════════════════

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = COLORS.Panel
header.BorderSizePixel = 0
header.Parent = mainFrame

Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 300, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🧭 Pet Expeditions"
titleLabel.TextColor3 = COLORS.Text
titleLabel.TextSize = 22
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local completedLabel = Instance.new("TextLabel")
completedLabel.Size = UDim2.new(0, 200, 1, 0)
completedLabel.Position = UDim2.new(0.5, -100, 0, 0)
completedLabel.BackgroundTransparency = 1
completedLabel.Text = "Completed: 0"
completedLabel.TextColor3 = COLORS.TextDim
completedLabel.TextSize = 14
completedLabel.Font = Enum.Font.Gotham
completedLabel.Parent = header

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.BackgroundColor3 = COLORS.Danger
closeBtn.Text = "✕"
closeBtn.TextColor3 = COLORS.Text
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- ═══════════════════════════════════════
-- TAB BAR
-- ═══════════════════════════════════════

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 38)
tabBar.Position = UDim2.new(0, 0, 0, 50)
tabBar.BackgroundColor3 = COLORS.Panel
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

Instance.new("UIPadding", tabBar).PaddingLeft = UDim.new(0, 12)

local tabButtons = {}

local function makeTabBtn(id, text)
    local btn = Instance.new("TextButton")
    btn.Name = id
    btn.Size = UDim2.new(0, 140, 0, 32)
    btn.BackgroundColor3 = COLORS.Card
    btn.Text = text
    btn.TextColor3 = COLORS.TextDim
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.Parent = tabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    tabButtons[id] = btn
    return btn
end

local availableTab = makeTabBtn("available", "📋 Available")
local activeTabBtn = makeTabBtn("active", "⏱ Active (0)")

-- ═══════════════════════════════════════
-- CONTENT AREA
-- ═══════════════════════════════════════

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -16, 1, -100)
contentFrame.Position = UDim2.new(0, 8, 0, 92)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true
contentFrame.Parent = mainFrame

-- ── Available Panel ────────────────────

local availablePanel = Instance.new("Frame")
availablePanel.Size = UDim2.new(1, 0, 1, 0)
availablePanel.BackgroundTransparency = 1
availablePanel.Parent = contentFrame

-- Left: Zone picker
local zoneList = Instance.new("ScrollingFrame")
zoneList.Size = UDim2.new(0, 170, 1, 0)
zoneList.BackgroundColor3 = COLORS.Panel
zoneList.BorderSizePixel = 0
zoneList.ScrollBarThickness = 4
zoneList.CanvasSize = UDim2.new(0, 0, 0, 0)
zoneList.AutomaticCanvasSize = Enum.AutomaticSize.Y
zoneList.Parent = availablePanel
Instance.new("UICorner", zoneList).CornerRadius = UDim.new(0, 10)

local zoneLayout = Instance.new("UIListLayout")
zoneLayout.Padding = UDim.new(0, 4)
zoneLayout.Parent = zoneList
Instance.new("UIPadding", zoneList).PaddingTop = UDim.new(0, 6)

-- Right: Tier cards
local tierPanel = Instance.new("ScrollingFrame")
tierPanel.Size = UDim2.new(1, -180, 1, 0)
tierPanel.Position = UDim2.new(0, 178, 0, 0)
tierPanel.BackgroundTransparency = 1
tierPanel.BorderSizePixel = 0
tierPanel.ScrollBarThickness = 4
tierPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
tierPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
tierPanel.Parent = availablePanel

local tierLayout = Instance.new("UIListLayout")
tierLayout.Padding = UDim.new(0, 8)
tierLayout.Parent = tierPanel
Instance.new("UIPadding", tierPanel).PaddingTop = UDim.new(0, 4)

-- ── Active Panel ───────────────────────

local activePanel = Instance.new("Frame")
activePanel.Size = UDim2.new(1, 0, 1, 0)
activePanel.BackgroundTransparency = 1
activePanel.Visible = false
activePanel.Parent = contentFrame

local activeScroll = Instance.new("ScrollingFrame")
activeScroll.Size = UDim2.new(1, 0, 1, 0)
activeScroll.BackgroundTransparency = 1
activeScroll.BorderSizePixel = 0
activeScroll.ScrollBarThickness = 4
activeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
activeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
activeScroll.Parent = activePanel

local activeLayout = Instance.new("UIListLayout")
activeLayout.Padding = UDim.new(0, 10)
activeLayout.Parent = activeScroll
Instance.new("UIPadding", activeScroll).PaddingTop = UDim.new(0, 6)

-- ── Pet Selector Modal ─────────────────

local petModal = Instance.new("Frame")
petModal.Size = UDim2.new(0, 500, 0, 400)
petModal.Position = UDim2.new(0.5, -250, 0.5, -200)
petModal.BackgroundColor3 = COLORS.BG
petModal.BorderSizePixel = 0
petModal.Visible = false
petModal.ZIndex = 50
petModal.Parent = screenGui
Instance.new("UICorner", petModal).CornerRadius = UDim.new(0, 14)
local pmStroke = Instance.new("UIStroke", petModal)
pmStroke.Color = COLORS.AccentAlt
pmStroke.Thickness = 2

local petModalTitle = Instance.new("TextLabel")
petModalTitle.Size = UDim2.new(1, 0, 0, 40)
petModalTitle.BackgroundColor3 = COLORS.Panel
petModalTitle.Text = "Select a Pet"
petModalTitle.TextColor3 = COLORS.Text
petModalTitle.TextSize = 16
petModalTitle.Font = Enum.Font.GothamBold
petModalTitle.ZIndex = 51
petModalTitle.Parent = petModal
Instance.new("UICorner", petModalTitle).CornerRadius = UDim.new(0, 14)

local petModalClose = Instance.new("TextButton")
petModalClose.Size = UDim2.new(0, 30, 0, 30)
petModalClose.Position = UDim2.new(1, -36, 0, 5)
petModalClose.BackgroundColor3 = COLORS.Danger
petModalClose.Text = "✕"
petModalClose.TextColor3 = COLORS.Text
petModalClose.TextSize = 14
petModalClose.Font = Enum.Font.GothamBold
petModalClose.ZIndex = 52
petModalClose.Parent = petModal
Instance.new("UICorner", petModalClose).CornerRadius = UDim.new(0, 6)

local petModalInfo = Instance.new("TextLabel")
petModalInfo.Size = UDim2.new(1, -16, 0, 24)
petModalInfo.Position = UDim2.new(0, 8, 0, 42)
petModalInfo.BackgroundTransparency = 1
petModalInfo.Text = "Recommended Power: 0"
petModalInfo.TextColor3 = COLORS.TextDim
petModalInfo.TextSize = 12
petModalInfo.Font = Enum.Font.Gotham
petModalInfo.TextXAlignment = Enum.TextXAlignment.Left
petModalInfo.ZIndex = 51
petModalInfo.Parent = petModal

local petGrid = Instance.new("ScrollingFrame")
petGrid.Size = UDim2.new(1, -16, 1, -76)
petGrid.Position = UDim2.new(0, 8, 0, 70)
petGrid.BackgroundTransparency = 1
petGrid.BorderSizePixel = 0
petGrid.ScrollBarThickness = 4
petGrid.CanvasSize = UDim2.new(0, 0, 0, 0)
petGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
petGrid.ZIndex = 51
petGrid.Parent = petModal

local petGridLayout = Instance.new("UIGridLayout")
petGridLayout.CellSize = UDim2.new(0, 90, 0, 110)
petGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
petGridLayout.Parent = petGrid

-- ── Reward Popup ───────────────────────

local rewardPopup = Instance.new("Frame")
rewardPopup.Size = UDim2.new(0, 340, 0, 220)
rewardPopup.Position = UDim2.new(0.5, -170, 0.5, -110)
rewardPopup.BackgroundColor3 = COLORS.BG
rewardPopup.BorderSizePixel = 0
rewardPopup.Visible = false
rewardPopup.ZIndex = 60
rewardPopup.Parent = screenGui
Instance.new("UICorner", rewardPopup).CornerRadius = UDim.new(0, 14)
local rpStroke = Instance.new("UIStroke", rewardPopup)
rpStroke.Color = COLORS.Success
rpStroke.Thickness = 2

local rewardTitle = Instance.new("TextLabel")
rewardTitle.Size = UDim2.new(1, 0, 0, 40)
rewardTitle.BackgroundColor3 = COLORS.Success
rewardTitle.Text = "🎉 Expedition Complete!"
rewardTitle.TextColor3 = COLORS.Text
rewardTitle.TextSize = 18
rewardTitle.Font = Enum.Font.GothamBold
rewardTitle.ZIndex = 61
rewardTitle.Parent = rewardPopup
Instance.new("UICorner", rewardTitle).CornerRadius = UDim.new(0, 14)

local rewardBody = Instance.new("TextLabel")
rewardBody.Size = UDim2.new(1, -20, 0, 100)
rewardBody.Position = UDim2.new(0, 10, 0, 50)
rewardBody.BackgroundTransparency = 1
rewardBody.Text = ""
rewardBody.TextColor3 = COLORS.Text
rewardBody.TextSize = 16
rewardBody.Font = Enum.Font.Gotham
rewardBody.TextWrapped = true
rewardBody.ZIndex = 61
rewardBody.Parent = rewardPopup

local rewardOkBtn = Instance.new("TextButton")
rewardOkBtn.Size = UDim2.new(0, 120, 0, 36)
rewardOkBtn.Position = UDim2.new(0.5, -60, 1, -50)
rewardOkBtn.BackgroundColor3 = COLORS.Accent
rewardOkBtn.Text = "Awesome!"
rewardOkBtn.TextColor3 = COLORS.Text
rewardOkBtn.TextSize = 14
rewardOkBtn.Font = Enum.Font.GothamBold
rewardOkBtn.ZIndex = 62
rewardOkBtn.Parent = rewardPopup
Instance.new("UICorner", rewardOkBtn).CornerRadius = UDim.new(0, 8)

rewardOkBtn.MouseButton1Click:Connect(function()
    rewardPopup.Visible = false
end)

-- ═══════════════════════════════════════
-- TAB SWITCHING
-- ═══════════════════════════════════════

local function switchTab(tab)
    activeTab = tab
    availablePanel.Visible = (tab == "available")
    activePanel.Visible = (tab == "active")

    for id, btn in pairs(tabButtons) do
        if id == tab then
            btn.BackgroundColor3 = COLORS.Accent
            btn.TextColor3 = COLORS.Text
        else
            btn.BackgroundColor3 = COLORS.Card
            btn.TextColor3 = COLORS.TextDim
        end
    end
end

availableTab.MouseButton1Click:Connect(function() switchTab("available") end)
activeTabBtn.MouseButton1Click:Connect(function() switchTab("active") end)

-- ═══════════════════════════════════════
-- ZONE LIST (left sidebar)
-- ═══════════════════════════════════════

local zoneButtons = {}

local function refreshZoneList()
    for _, child in ipairs(zoneList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    zoneButtons = {}

    for _, zone in ipairs(ZoneConfig.Zones) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 40)
        btn.BackgroundColor3 = COLORS.Card
        btn.Text = zone.Name
        btn.TextColor3 = COLORS.Text
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        btn.TextTruncate = Enum.TextTruncate.AtEnd
        btn.AutoButtonColor = true
        btn.LayoutOrder = zone.Order
        btn.Parent = zoneList
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        -- Dim locked zones
        local unlocked = false
        for _, z in ipairs(playerPets._unlockedZones or {}) do
            if z == zone.Id then unlocked = true; break end
        end

        if not unlocked then
            btn.BackgroundTransparency = 0.5
            btn.TextColor3 = COLORS.TextDim
            btn.Text = "🔒 " .. zone.Name
        end

        zoneButtons[zone.Id] = btn

        btn.MouseButton1Click:Connect(function()
            if not unlocked then return end
            selectedZone = zone.Id
            -- Highlight selected
            for _, b in pairs(zoneButtons) do
                b.BackgroundColor3 = COLORS.Card
            end
            btn.BackgroundColor3 = COLORS.Accent
            -- Refresh tier cards
            refreshTierCards()
        end)
    end
end

-- ═══════════════════════════════════════
-- TIER CARDS (right panel — available tab)
-- ═══════════════════════════════════════

function refreshTierCards()
    for _, child in ipairs(tierPanel:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    if not selectedZone then
        local hint = Instance.new("TextLabel")
        hint.Size = UDim2.new(1, 0, 0, 60)
        hint.BackgroundTransparency = 1
        hint.Text = "← Select a zone to see available expeditions"
        hint.TextColor3 = COLORS.TextDim
        hint.TextSize = 14
        hint.Font = Enum.Font.Gotham
        hint.Parent = tierPanel
        -- Wrap in a frame for layout
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 60)
        f.BackgroundTransparency = 1
        f.Parent = tierPanel
        hint.Parent = f
        return
    end

    local zone = ZoneConfig.ZoneById[selectedZone]
    local zoneScaling = ExpeditionConfig.ZoneScaling[selectedZone]
    if not zone or not zoneScaling then return end

    for i, tier in ipairs(ExpeditionConfig.Tiers) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -8, 0, 100)
        card.BackgroundColor3 = COLORS.Card
        card.LayoutOrder = i
        card.Parent = tierPanel
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

        -- Tier name + description
        local tierName = Instance.new("TextLabel")
        tierName.Size = UDim2.new(0.5, -8, 0, 22)
        tierName.Position = UDim2.new(0, 12, 0, 8)
        tierName.BackgroundTransparency = 1
        tierName.Text = tier.Name
        tierName.TextColor3 = COLORS.AccentAlt
        tierName.TextSize = 15
        tierName.Font = Enum.Font.GothamBold
        tierName.TextXAlignment = Enum.TextXAlignment.Left
        tierName.Parent = card

        local tierDesc = Instance.new("TextLabel")
        tierDesc.Size = UDim2.new(0.6, 0, 0, 16)
        tierDesc.Position = UDim2.new(0, 12, 0, 30)
        tierDesc.BackgroundTransparency = 1
        tierDesc.Text = tier.Description
        tierDesc.TextColor3 = COLORS.TextDim
        tierDesc.TextSize = 11
        tierDesc.Font = Enum.Font.Gotham
        tierDesc.TextXAlignment = Enum.TextXAlignment.Left
        tierDesc.TextTruncate = Enum.TextTruncate.AtEnd
        tierDesc.Parent = card

        -- Duration
        local durLabel = Instance.new("TextLabel")
        durLabel.Size = UDim2.new(0, 100, 0, 16)
        durLabel.Position = UDim2.new(1, -112, 0, 8)
        durLabel.BackgroundTransparency = 1
        durLabel.Text = "⏱ " .. formatDuration(tier.Duration)
        durLabel.TextColor3 = COLORS.Text
        durLabel.TextSize = 12
        durLabel.Font = Enum.Font.GothamBold
        durLabel.TextXAlignment = Enum.TextXAlignment.Right
        durLabel.Parent = card

        -- Recommended power
        local recPower = ExpeditionConfig.GetRecommendedPower(selectedZone, tier.Id)
        local powerLabel = Instance.new("TextLabel")
        powerLabel.Size = UDim2.new(0, 160, 0, 16)
        powerLabel.Position = UDim2.new(0, 12, 0, 50)
        powerLabel.BackgroundTransparency = 1
        powerLabel.Text = "⚡ Recommended Power: " .. recPower
        powerLabel.TextColor3 = COLORS.TextDim
        powerLabel.TextSize = 11
        powerLabel.Font = Enum.Font.Gotham
        powerLabel.TextXAlignment = Enum.TextXAlignment.Left
        powerLabel.Parent = card

        -- Preview rewards (at recommended power)
        local previewRewards = ExpeditionConfig.CalculateRewards(selectedZone, tier.Id, recPower)
        local rewardText = "💰 " .. tostring(previewRewards.Coins)
        if previewRewards.Gems > 0 then
            rewardText = rewardText .. "   💎 " .. tostring(previewRewards.Gems)
        end
        rewardText = rewardText .. "   ✨ " .. tostring(previewRewards.XP) .. " XP"

        local rewardLabel = Instance.new("TextLabel")
        rewardLabel.Size = UDim2.new(0.7, 0, 0, 16)
        rewardLabel.Position = UDim2.new(0, 12, 0, 68)
        rewardLabel.BackgroundTransparency = 1
        rewardLabel.Text = rewardText
        rewardLabel.TextColor3 = COLORS.Gold
        rewardLabel.TextSize = 12
        rewardLabel.Font = Enum.Font.GothamBold
        rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
        rewardLabel.Parent = card

        -- Send button
        local sendBtn = Instance.new("TextButton")
        sendBtn.Size = UDim2.new(0, 90, 0, 32)
        sendBtn.Position = UDim2.new(1, -100, 1, -42)
        sendBtn.BackgroundColor3 = COLORS.Accent
        sendBtn.Text = "Send Pet"
        sendBtn.TextColor3 = COLORS.Text
        sendBtn.TextSize = 13
        sendBtn.Font = Enum.Font.GothamBold
        sendBtn.Parent = card
        Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 8)

        sendBtn.MouseButton1Click:Connect(function()
            selectedTier = tier.Id
            openPetSelector()
        end)
    end
end

-- ═══════════════════════════════════════
-- PET SELECTOR MODAL
-- ═══════════════════════════════════════

function openPetSelector()
    petModal.Visible = true
    local recPower = ExpeditionConfig.GetRecommendedPower(selectedZone or "", selectedTier or "")
    petModalInfo.Text = "Recommended Power: " .. recPower .. "  •  Only unequipped pets shown"

    -- Clear grid
    for _, child in ipairs(petGrid:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    -- Populate with unequipped, non-expedition pets
    local sortedPets = {}
    for _, pet in ipairs(playerPets) do
        if not isPetEquipped(pet.UUID) and not isPetOnExpedition(pet.UUID) then
            table.insert(sortedPets, pet)
        end
    end

    -- Sort by power descending
    table.sort(sortedPets, function(a, b)
        return getEffectivePower(a) > getEffectivePower(b)
    end)

    if #sortedPets == 0 then
        local noLabel = Instance.new("TextLabel")
        noLabel.Size = UDim2.new(1, 0, 0, 50)
        noLabel.BackgroundTransparency = 1
        noLabel.Text = "No available pets! Unequip a pet first."
        noLabel.TextColor3 = COLORS.TextDim
        noLabel.TextSize = 13
        noLabel.Font = Enum.Font.Gotham
        noLabel.ZIndex = 52
        noLabel.Parent = petGrid
        return
    end

    for _, pet in ipairs(sortedPets) do
        local petInfo = PetConfig.GetPet(pet.PetId)
        if not petInfo then continue end

        local power = getEffectivePower(pet)
        local rarity = petInfo.Rarity or "Common"
        local rarityColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common

        local cell = Instance.new("TextButton")
        cell.Size = UDim2.new(0, 90, 0, 110)
        cell.BackgroundColor3 = COLORS.Card
        cell.Text = ""
        cell.AutoButtonColor = true
        cell.ZIndex = 52
        cell.Parent = petGrid
        Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 8)

        local cellStroke = Instance.new("UIStroke", cell)
        cellStroke.Color = rarityColor
        cellStroke.Thickness = 1

        -- Pet image
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(0, 60, 0, 60)
        img.Position = UDim2.new(0.5, -30, 0, 4)
        img.BackgroundTransparency = 1
        img.ZIndex = 53
        img.Parent = cell

        img.Image = PetVisualUtil.GetPetImage(petInfo, pet)

        -- Pet name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -4, 0, 14)
        nameLabel.Position = UDim2.new(0, 2, 0, 66)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = petInfo.Name
        nameLabel.TextColor3 = rarityColor
        nameLabel.TextSize = 10
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.ZIndex = 53
        nameLabel.Parent = cell

        -- Power
        local powerLbl = Instance.new("TextLabel")
        powerLbl.Size = UDim2.new(1, -4, 0, 14)
        powerLbl.Position = UDim2.new(0, 2, 0, 80)
        powerLbl.BackgroundTransparency = 1
        powerLbl.Text = "⚡ " .. tostring(power)
        powerLbl.TextColor3 = (power >= recPower) and COLORS.Success or COLORS.Danger
        powerLbl.TextSize = 11
        powerLbl.Font = Enum.Font.GothamBold
        powerLbl.ZIndex = 53
        powerLbl.Parent = cell

        -- Variant badge
        if pet.Rainbow then
            local badge = Instance.new("TextLabel")
            badge.Size = UDim2.new(0, 14, 0, 14)
            badge.Position = UDim2.new(1, -16, 0, 2)
            badge.BackgroundTransparency = 1
            badge.Text = "🌈"
            badge.TextSize = 10
            badge.ZIndex = 54
            badge.Parent = cell
        elseif pet.Golden then
            local badge = Instance.new("TextLabel")
            badge.Size = UDim2.new(0, 14, 0, 14)
            badge.Position = UDim2.new(1, -16, 0, 2)
            badge.BackgroundTransparency = 1
            badge.Text = "⭐"
            badge.TextSize = 10
            badge.ZIndex = 54
            badge.Parent = cell
        end

        -- Level badge
        local lvlBadge = Instance.new("TextLabel")
        lvlBadge.Size = UDim2.new(0, 28, 0, 14)
        lvlBadge.Position = UDim2.new(0, 2, 0, 2)
        lvlBadge.BackgroundColor3 = COLORS.Panel
        lvlBadge.Text = "Lv" .. (pet.Level or 1)
        lvlBadge.TextColor3 = COLORS.TextDim
        lvlBadge.TextSize = 9
        lvlBadge.Font = Enum.Font.GothamBold
        lvlBadge.ZIndex = 54
        lvlBadge.Parent = cell
        Instance.new("UICorner", lvlBadge).CornerRadius = UDim.new(0, 4)

        cell.MouseButton1Click:Connect(function()
            petModal.Visible = false
            -- Send expedition request to server
            local event = Network.GetEvent("StartExpedition")
            if event then
                event:FireServer({
                    ZoneId = selectedZone,
                    TierId = selectedTier,
                    PetUUID = pet.UUID,
                })
            end
        end)
    end
end

petModalClose.MouseButton1Click:Connect(function()
    petModal.Visible = false
end)

-- ═══════════════════════════════════════
-- ACTIVE EXPEDITIONS (active tab)
-- ═══════════════════════════════════════

local function refreshActivePanel()
    for _, child in ipairs(activeScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    activeTabBtn.Text = "⏱ Active (" .. #expeditionData.Active .. "/" .. expeditionData.MaxSlots .. ")"
    completedLabel.Text = "Completed: " .. (expeditionData.Completed or 0)

    -- Show empty slots message if none active
    if #expeditionData.Active == 0 then
        local emptyFrame = Instance.new("Frame")
        emptyFrame.Size = UDim2.new(1, 0, 0, 80)
        emptyFrame.BackgroundTransparency = 1
        emptyFrame.Parent = activeScroll

        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 1, 0)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "No active expeditions.\nGo to Available tab to send a pet!"
        emptyLabel.TextColor3 = COLORS.TextDim
        emptyLabel.TextSize = 14
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextWrapped = true
        emptyLabel.Parent = emptyFrame
        return
    end

    for i, exp in ipairs(expeditionData.Active) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -8, 0, 90)
        card.BackgroundColor3 = COLORS.Card
        card.LayoutOrder = i
        card.Parent = activeScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

        -- Pet info
        local pet = nil
        for _, p in ipairs(playerPets) do
            if p.UUID == exp.PetUUID then pet = p; break end
        end

        local petInfo = pet and PetConfig.GetPet(pet.PetId) or nil
        local petName = petInfo and petInfo.Name or "Unknown"
        local petRarity = petInfo and petInfo.Rarity or "Common"

        -- Pet image
        local petImg = Instance.new("ImageLabel")
        petImg.Size = UDim2.new(0, 60, 0, 60)
        petImg.Position = UDim2.new(0, 10, 0.5, -30)
        petImg.BackgroundTransparency = 1
        petImg.Parent = card
        if petInfo then
            petImg.Image = PetVisualUtil.GetPetImage(petInfo, pet)
        end

        -- Pet name + zone
        local zone = ZoneConfig.ZoneById[exp.ZoneId]
        local tier = ExpeditionConfig.TierById[exp.TierId]

        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(0, 250, 0, 20)
        infoLabel.Position = UDim2.new(0, 80, 0, 10)
        infoLabel.BackgroundTransparency = 1
        infoLabel.Text = petName .. " — " .. (tier and tier.Name or exp.TierId)
        infoLabel.TextColor3 = RARITY_COLORS[petRarity] or COLORS.Text
        infoLabel.TextSize = 14
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = card

        local zoneLabel = Instance.new("TextLabel")
        zoneLabel.Size = UDim2.new(0, 250, 0, 16)
        zoneLabel.Position = UDim2.new(0, 80, 0, 32)
        zoneLabel.BackgroundTransparency = 1
        zoneLabel.Text = "📍 " .. (zone and zone.Name or exp.ZoneId) .. "  ⚡ " .. exp.PetPower
        zoneLabel.TextColor3 = COLORS.TextDim
        zoneLabel.TextSize = 11
        zoneLabel.Font = Enum.Font.Gotham
        zoneLabel.TextXAlignment = Enum.TextXAlignment.Left
        zoneLabel.Parent = card

        -- Timer
        local now = os.time()
        local endTime = exp.StartTime + exp.Duration
        local remaining = math.max(0, endTime - now)
        local isComplete = remaining <= 0

        local timerLabel = Instance.new("TextLabel")
        timerLabel.Name = "Timer"
        timerLabel.Size = UDim2.new(0, 120, 0, 20)
        timerLabel.Position = UDim2.new(0, 80, 0, 52)
        timerLabel.BackgroundTransparency = 1
        timerLabel.TextColor3 = isComplete and COLORS.Success or COLORS.Text
        timerLabel.TextSize = 13
        timerLabel.Font = Enum.Font.GothamBold
        timerLabel.TextXAlignment = Enum.TextXAlignment.Left
        timerLabel.Parent = card

        if isComplete then
            timerLabel.Text = "✅ Ready to claim!"
        else
            timerLabel.Text = "⏱ " .. formatDuration(remaining)
        end

        -- Store endTime for live countdown
        timerLabel:SetAttribute("EndTime", endTime)

        -- Progress bar
        local progressBG = Instance.new("Frame")
        progressBG.Size = UDim2.new(0, 200, 0, 6)
        progressBG.Position = UDim2.new(0, 80, 0, 74)
        progressBG.BackgroundColor3 = COLORS.Panel
        progressBG.Parent = card
        Instance.new("UICorner", progressBG).CornerRadius = UDim.new(0, 3)

        local progressFill = Instance.new("Frame")
        progressFill.Name = "Fill"
        progressFill.BackgroundColor3 = isComplete and COLORS.Success or COLORS.Accent
        progressFill.Parent = progressBG
        Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 3)

        local elapsed = math.min(exp.Duration, now - exp.StartTime)
        local pct = if exp.Duration > 0 then math.clamp(elapsed / exp.Duration, 0, 1) else 1
        progressFill.Size = UDim2.new(pct, 0, 1, 0)

        progressFill:SetAttribute("Duration", exp.Duration)
        progressFill:SetAttribute("StartTime", exp.StartTime)

        -- Buttons
        if isComplete then
            local claimBtn = Instance.new("TextButton")
            claimBtn.Size = UDim2.new(0, 90, 0, 34)
            claimBtn.Position = UDim2.new(1, -100, 0.5, -17)
            claimBtn.BackgroundColor3 = COLORS.Success
            claimBtn.Text = "Claim!"
            claimBtn.TextColor3 = COLORS.Text
            claimBtn.TextSize = 14
            claimBtn.Font = Enum.Font.GothamBold
            claimBtn.Parent = card
            Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 8)

            claimBtn.MouseButton1Click:Connect(function()
                local claimEvent = Network.GetEvent("ClaimExpedition")
                if claimEvent then
                    claimEvent:FireServer({ SlotIndex = exp.SlotIndex })
                end
            end)
        else
            local skipCost = tier and tier.SkipCost or 0
            local skipBtn = Instance.new("TextButton")
            skipBtn.Size = UDim2.new(0, 90, 0, 34)
            skipBtn.Position = UDim2.new(1, -100, 0.5, -17)
            skipBtn.BackgroundColor3 = COLORS.Gem
            skipBtn.Text = "Skip " .. skipCost .. "💎"
            skipBtn.TextColor3 = COLORS.BG
            skipBtn.TextSize = 12
            skipBtn.Font = Enum.Font.GothamBold
            skipBtn.Parent = card
            Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 8)

            skipBtn.MouseButton1Click:Connect(function()
                local skipEvent = Network.GetEvent("SkipExpedition")
                if skipEvent then
                    skipEvent:FireServer({ SlotIndex = exp.SlotIndex })
                end
            end)
        end
    end

    -- Show empty slot indicators
    local usedSlots = #expeditionData.Active
    for s = usedSlots + 1, expeditionData.MaxSlots do
        local emptySlot = Instance.new("Frame")
        emptySlot.Size = UDim2.new(1, -8, 0, 60)
        emptySlot.BackgroundColor3 = COLORS.Panel
        emptySlot.BackgroundTransparency = 0.5
        emptySlot.LayoutOrder = 100 + s
        emptySlot.Parent = activeScroll
        Instance.new("UICorner", emptySlot).CornerRadius = UDim.new(0, 10)

        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, 0, 1, 0)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Text = "Empty Slot #" .. s .. "  —  Send a pet on an expedition!"
        emptyLbl.TextColor3 = COLORS.TextDim
        emptyLbl.TextSize = 12
        emptyLbl.Font = Enum.Font.Gotham
        emptyLbl.Parent = emptySlot
    end
end

-- ═══════════════════════════════════════
-- LIVE COUNTDOWN TICK
-- ═══════════════════════════════════════

local tickConnection = nil

local function startTick()
    if tickConnection then return end
    tickConnection = RunService.Heartbeat:Connect(function()
        if not screenGui.Enabled or activeTab ~= "active" then return end
        local now = os.time()
        for _, child in ipairs(activeScroll:GetChildren()) do
            if not child:IsA("Frame") then continue end
            local timerLabel = child:FindFirstChild("Timer")
            if not timerLabel then continue end
            local endTime = timerLabel:GetAttribute("EndTime")
            if not endTime then continue end
            local remaining = math.max(0, endTime - now)
            if remaining <= 0 then
                timerLabel.Text = "✅ Ready to claim!"
                timerLabel.TextColor3 = COLORS.Success
            else
                timerLabel.Text = "⏱ " .. formatDuration(remaining)
            end

            -- Update progress bar
            local progressBG = child:FindFirstChildWhichIsA("Frame")
            if progressBG then
                local fill = progressBG:FindFirstChild("Fill")
                if fill then
                    local dur = fill:GetAttribute("Duration") or 1
                    local startTime = fill:GetAttribute("StartTime") or now
                    local elapsed = math.min(dur, now - startTime)
                    local pct = if dur > 0 then math.clamp(elapsed / dur, 0, 1) else 1
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    fill.BackgroundColor3 = (pct >= 1) and COLORS.Success or COLORS.Accent
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════
-- OPEN / CLOSE
-- ═══════════════════════════════════════

local function open()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 800, 0, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 800, 0, 540),
        Position = UDim2.new(0.5, -400, 0.5, -270),
    }):Play()
    switchTab("available")
    refreshZoneList()
    refreshTierCards()
    refreshActivePanel()
    startTick()

    -- Request latest data
    local reqEvent = Network.GetEvent("RequestExpeditionData")
    if reqEvent then reqEvent:FireServer() end
end

local function close()
    petModal.Visible = false
    rewardPopup.Visible = false
    TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 800, 0, 0),
    }):Play()
    task.delay(0.15, function()
        screenGui.Enabled = false
    end)
end

closeBtn.MouseButton1Click:Connect(close)
overlay.MouseButton1Click:Connect(close)

-- ═══════════════════════════════════════
-- NETWORK LISTENERS
-- ═══════════════════════════════════════

Network.OnClientEvent("ExpeditionData", function(data)
    if type(data) ~= "table" then return end
    expeditionData.Active = data.Active or {}
    expeditionData.Completed = data.Completed or 0
    expeditionData.MaxSlots = data.MaxSlots or 1
    if screenGui.Enabled then
        refreshActivePanel()
    end
end)

Network.OnClientEvent("ExpeditionUpdated", function(data)
    if type(data) ~= "table" then return end
    -- If a claim happened, show reward popup
    if data.Type == "Claimed" and data.Rewards then
        local r = data.Rewards
        local text = "💰 Coins: " .. tostring(r.Coins or 0)
        if (r.Gems or 0) > 0 then
            text = text .. "\n💎 Gems: " .. tostring(r.Gems)
        end
        text = text .. "\n✨ Pet XP: " .. tostring(r.XP or 0)
        rewardBody.Text = text
        rewardPopup.Visible = true
    end
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    playerPets = data.Pets or {}
    equippedPets = data.EquippedPets or {}
    playerPets._unlockedZones = data.UnlockedZones or { "starter_meadow" }
end)

Network.OnClientEvent("PetsUpdated", function(newPets)
    playerPets = newPets or {}
    -- Preserve unlocked zones
    if not playerPets._unlockedZones then
        playerPets._unlockedZones = { "starter_meadow" }
    end
end)

Network.OnClientEvent("DataUpdated", function(data)
    if type(data) ~= "table" then return end
    if data.Pets then playerPets = data.Pets end
    if data.EquippedPets then equippedPets = data.EquippedPets end
    if data.UnlockedZones then playerPets._unlockedZones = data.UnlockedZones end
    if data.Expeditions then
        expeditionData.Active = data.Expeditions.Active or expeditionData.Active
        expeditionData.Completed = data.Expeditions.Completed or expeditionData.Completed
    end
end)

Network.OnClientEvent("ZoneUnlocked", function()
    -- Refresh zone list when a new zone is unlocked
    if screenGui.Enabled then
        refreshZoneList()
    end
end)

-- ═══════════════════════════════════════
-- CONNECT TO MAIN HUD BUTTON
-- ═══════════════════════════════════════

task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if mainHud then
        local sideButtons = mainHud:WaitForChild("SideButtons", 10)
        if sideButtons then
            local expeditionBtn = sideButtons:WaitForChild("ExpeditionButton", 10)
            if expeditionBtn then
                expeditionBtn.MouseButton1Click:Connect(open)
            end
        end
    end
end)

print("[GUI] ExpeditionGui loaded")
