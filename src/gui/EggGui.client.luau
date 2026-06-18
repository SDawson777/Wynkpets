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
local PetVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("PetVisualUtil"))
local EggVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("EggVisualUtil"))

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
-- ═══════════════════════════════════════
-- LUCKY STREAK BAR (pity counter)
-- Shown below the title bar; updates as player hatches.
-- ═══════════════════════════════════════

local luckyBar = Instance.new("Frame")
luckyBar.Name = "LuckyBar"
luckyBar.Size = UDim2.new(1, 0, 0, 28)
luckyBar.Position = UDim2.new(0, 0, 0, 50)
luckyBar.BackgroundColor3 = Color3.fromRGB(18, 42, 18)
luckyBar.BackgroundTransparency = 0.1
luckyBar.BorderSizePixel = 0
luckyBar.ZIndex = 2
luckyBar.Parent = mainFrame

local lbStroke = Instance.new("UIStroke")
lbStroke.Color = Color3.fromRGB(45, 160, 45)
lbStroke.Thickness = 1
lbStroke.Parent = luckyBar

local luckyLabel = Instance.new("TextLabel")
luckyLabel.Name = "LuckyLabel"
luckyLabel.Size = UDim2.new(1, -20, 1, 0)
luckyLabel.Position = UDim2.new(0, 10, 0, 0)
luckyLabel.BackgroundTransparency = 1
luckyLabel.Text = "🍀 Keep hatching — luck builds up!"
luckyLabel.TextColor3 = Color3.fromRGB(90, 175, 90)
luckyLabel.Font = Enum.Font.GothamBold
luckyLabel.TextSize = 12
luckyLabel.TextXAlignment = Enum.TextXAlignment.Left
luckyLabel.ZIndex = 3
luckyLabel.Parent = luckyBar

local eggScroll = Instance.new("ScrollingFrame")
eggScroll.Size = UDim2.new(1, -20, 1, -132)
eggScroll.Position = UDim2.new(0, 10, 0, 122)
eggScroll.BackgroundTransparency = 1
eggScroll.ScrollBarThickness = 4
eggScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
eggScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
eggScroll.Parent = mainFrame

-- ═══════════════════════════════════════
-- TABS: "My Eggs" (collected) | "Egg Info" (browse all)
-- ═══════════════════════════════════════

local tabFrame = Instance.new("Frame")
tabFrame.Name = "TabFrame"
tabFrame.Size = UDim2.new(1, -20, 0, 30)
tabFrame.Position = UDim2.new(0, 10, 0, 86)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = mainFrame

local activeTab = "MyEggs"  -- "MyEggs" | "EggInfo"

local myEggsTab = Instance.new("TextButton")
myEggsTab.Name = "MyEggsTab"
myEggsTab.Size = UDim2.new(0.5, -4, 1, 0)
myEggsTab.Position = UDim2.new(0, 0, 0, 0)
myEggsTab.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
myEggsTab.TextColor3 = Color3.fromRGB(20, 20, 35)
myEggsTab.Text = "🥚 My Eggs"
myEggsTab.Font = Enum.Font.GothamBold
myEggsTab.TextSize = 14
myEggsTab.Parent = tabFrame
Instance.new("UICorner", myEggsTab).CornerRadius = UDim.new(0, 8)

local eggInfoTab = Instance.new("TextButton")
eggInfoTab.Name = "EggInfoTab"
eggInfoTab.Size = UDim2.new(0.5, -4, 1, 0)
eggInfoTab.Position = UDim2.new(0.5, 4, 0, 0)
eggInfoTab.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
eggInfoTab.TextColor3 = Color3.fromRGB(160, 160, 180)
eggInfoTab.Text = "📋 Egg Info"
eggInfoTab.Font = Enum.Font.GothamBold
eggInfoTab.TextSize = 14
eggInfoTab.Parent = tabFrame
Instance.new("UICorner", eggInfoTab).CornerRadius = UDim.new(0, 8)

local function updateTabVisuals()
    if activeTab == "MyEggs" then
        myEggsTab.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
        myEggsTab.TextColor3 = Color3.fromRGB(20, 20, 35)
        eggInfoTab.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        eggInfoTab.TextColor3 = Color3.fromRGB(160, 160, 180)
    else
        myEggsTab.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        myEggsTab.TextColor3 = Color3.fromRGB(160, 160, 180)
        eggInfoTab.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
        eggInfoTab.TextColor3 = Color3.fromRGB(20, 20, 35)
    end
end

local eggLayout = Instance.new("UIGridLayout")
eggLayout.CellSize = UDim2.new(0, 230, 0, 320)
eggLayout.CellPadding = UDim2.new(0, 10, 0, 10)
eggLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
eggLayout.Parent = eggScroll

-- ═══════════════════════════════════════
-- EGG TIER VISUALS
-- Eggs look different based on the zone order they belong to.
-- Zone 1-2 = Common, 3-4 = Rare, 5-6 = Epic, 7 = Legendary, 8 = Mythic/Secret
-- ═══════════════════════════════════════

local EGG_TIER_DEFS = {
    -- { zoneOrders={}, eggColor, strokeColor, strokeThick, glowColor, emblem, dots }
    {
        orders = {1, 2},
        eggColor  = Color3.fromRGB(255, 245, 215),
        strokeColor = Color3.fromRGB(200, 180, 130),
        strokeThick = 1.5,
        emblem = nil,
        dots = 0,
        shine = false,
    },
    {
        orders = {3, 4},
        eggColor  = Color3.fromRGB(190, 215, 255),
        strokeColor = Color3.fromRGB(80, 140, 255),
        strokeThick = 2,
        emblem = "✦",
        emblemColor = Color3.fromRGB(120, 180, 255),
        dots = 3,
        dotColor = Color3.fromRGB(100, 160, 255),
        shine = true,
    },
    {
        orders = {5, 6},
        eggColor  = Color3.fromRGB(225, 195, 255),
        strokeColor = Color3.fromRGB(180, 70, 255),
        strokeThick = 2.5,
        emblem = "★",
        emblemColor = Color3.fromRGB(210, 140, 255),
        dots = 4,
        dotColor = Color3.fromRGB(190, 100, 255),
        shine = true,
    },
    {
        orders = {7},
        eggColor  = Color3.fromRGB(255, 240, 150),
        strokeColor = Color3.fromRGB(255, 200, 30),
        strokeThick = 3,
        emblem = "⭐",
        emblemColor = Color3.fromRGB(255, 230, 60),
        dots = 5,
        dotColor = Color3.fromRGB(255, 200, 30),
        shine = true,
    },
    {
        orders = {8},
        eggColor  = Color3.fromRGB(30, 10, 50),
        strokeColor = Color3.fromRGB(255, 80, 200),
        strokeThick = 3.5,
        emblem = "👑",
        emblemColor = Color3.fromRGB(255, 80, 200),
        dots = 6,
        dotColor = Color3.fromRGB(255, 80, 200),
        shine = true,
    },
}

local function getEggTierDef(zoneOrder)
    for _, def in ipairs(EGG_TIER_DEFS) do
        for _, o in ipairs(def.orders) do
            if o == zoneOrder then return def end
        end
    end
    return EGG_TIER_DEFS[1]
end

-- Builds the visual egg shape inside `parent` (Frame, 80×100)
-- `eggImage` is an optional rbxassetid string; when provided, renders the real egg image.
local function buildEggVisual(parent, zone, isUnlocked, eggImage)
    local order = zone and zone.Order or 1
    local def = getEggTierDef(order)
    local resolvedEggImage = EggVisualUtil.NormalizeImage(eggImage)

    -- If we have a real image, show it directly instead of the procedural egg
    if resolvedEggImage ~= "rbxassetid://0" then
        local img = Instance.new("ImageLabel")
        img.Name = "EggBody"
        img.Size = UDim2.new(1, 0, 1, 0)
        img.BackgroundTransparency = 1
        img.Image = isUnlocked and resolvedEggImage or ""
        img.ScaleType = Enum.ScaleType.Fit
        img.Parent = parent

        if not isUnlocked then
            img.ImageTransparency = 0.7
            img.ImageColor3 = Color3.fromRGB(60, 60, 70)
            local lock = Instance.new("TextLabel")
            lock.Size = UDim2.new(1, 0, 1, 0)
            lock.BackgroundTransparency = 1
            lock.Text = "🔒"
            lock.TextSize = 24
            lock.Font = Enum.Font.GothamBold
            lock.ZIndex = 2
            lock.Parent = img
        end
        return
    end

    -- Fallback: procedural egg visual
    local eggBody = Instance.new("Frame")
    eggBody.Name = "EggBody"
    eggBody.Size = UDim2.new(1, 0, 1, 0)
    eggBody.BackgroundColor3 = isUnlocked and def.eggColor or Color3.fromRGB(55, 55, 65)
    eggBody.BorderSizePixel = 0
    eggBody.Parent = parent
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0.42, 0)  -- egg shape
        c.Parent = eggBody
        local s = Instance.new("UIStroke")
        s.Color = isUnlocked and def.strokeColor or Color3.fromRGB(70, 70, 80)
        s.Thickness = isUnlocked and def.strokeThick or 1
        s.Transparency = isUnlocked and 0 or 0.5
        s.Parent = eggBody
    end

    if not isUnlocked then
        -- Lock icon overlay
        local lock = Instance.new("TextLabel")
        lock.Size = UDim2.new(1, 0, 1, 0)
        lock.BackgroundTransparency = 1
        lock.Text = "🔒"
        lock.TextSize = 24
        lock.Font = Enum.Font.GothamBold
        lock.Parent = eggBody
        return
    end

    -- Top highlight (shine spot at top of egg)
    if def.shine then
        local shine = Instance.new("Frame")
        shine.Size = UDim2.new(0, 22, 0, 14)
        shine.Position = UDim2.new(0.5, -11, 0, 10)
        shine.BackgroundColor3 = Color3.new(1, 1, 1)
        shine.BackgroundTransparency = 0.45
        shine.BorderSizePixel = 0
        shine.ZIndex = 2
        shine.Parent = eggBody
        do
            local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(1, 0); sc.Parent = shine
        end
    end

    -- Emblem label in center of egg
    if def.emblem then
        local emblemLbl = Instance.new("TextLabel")
        emblemLbl.Size = UDim2.new(1, 0, 0.55, 0)
        emblemLbl.Position = UDim2.new(0, 0, 0.22, 0)
        emblemLbl.BackgroundTransparency = 1
        emblemLbl.Text = def.emblem
        emblemLbl.TextColor3 = def.emblemColor or Color3.new(1, 1, 1)
        emblemLbl.Font = Enum.Font.GothamBold
        emblemLbl.TextScaled = true
        emblemLbl.ZIndex = 2
        emblemLbl.Parent = eggBody
    end

    -- Dot ring (sparkle spots around the egg waist)
    if def.dots and def.dots > 0 then
        for i = 1, def.dots do
            local angle = math.rad((i / def.dots) * 360)
            -- Place dots around the egg center, inset by 12px
            local rx = 0.5 + math.cos(angle) * 0.32
            local ry = 0.5 + math.sin(angle) * 0.28
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 5, 0, 5)
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            dot.Position = UDim2.new(rx, 0, ry, 0)
            dot.BackgroundColor3 = def.dotColor or Color3.new(1, 1, 1)
            dot.BorderSizePixel = 0
            dot.ZIndex = 3
            dot.Parent = eggBody
            do local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot end
        end
    end

    -- Zone-color band across the egg middle (subtle)
    if zone and zone.Color then
        local band = Instance.new("Frame")
        band.Size = UDim2.new(0.8, 0, 0, 12)
        band.Position = UDim2.new(0.1, 0, 0.45, 0)
        band.BackgroundColor3 = zone.Color
        band.BackgroundTransparency = 0.55
        band.BorderSizePixel = 0
        band.ZIndex = 2
        band.Parent = eggBody
        do
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = band
        end
    end
end

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════
local unlockedZones = { "starter_meadow" }
local ownedGamepasses = {}
local autoHatchEggId = nil
local luckyStreak = 0  -- consecutive batches without Rare+
local coinBalance = 0  -- kept in sync with server via CurrencyUpdated
local collectedEggs = {}  -- { [eggId] = count } synced from server

-- Refs to live hatch buttons, keyed by egg.Id.
-- Populated in refreshEggs(); used by updateAllHatchButtons() so a
-- CurrencyUpdated event flips buttons between gold/gray in real time
-- without rebuilding the entire card list.
local hatchButtonRefs = {}  -- [eggId] = { btn: TextButton, egg: table }

-- ─── Affordability palette ────────────────────────────────────────────────────
local HATCH_GOLD_BG = Color3.fromRGB(255, 200,  50)
local HATCH_GOLD_FG = Color3.fromRGB( 30,  30,  30)
local HATCH_GRAY_BG = Color3.fromRGB( 58,  58,  78)
local HATCH_GRAY_FG = Color3.fromRGB(165, 165, 175)

-- Update one hatch button's visual state based on the player's current balance.
-- effectiveCost must already include the triple_hatch gamepass multiplier.
local function applyHatchButtonState(btn, egg, balance, effectiveCost)
    if balance >= effectiveCost then
        btn.BackgroundColor3 = HATCH_GOLD_BG
        btn.TextColor3       = HATCH_GOLD_FG
        btn.AutoButtonColor  = true
        btn.Text = "🥚 Hatch - " .. NumberFormat.Abbreviate(egg.Cost) .. " " .. egg.Currency
        -- Remove any existing shortage hint
        local existingHint = btn.Parent and btn.Parent:FindFirstChild("__ShortfallHint_" .. egg.Id)
        if existingHint then existingHint:Destroy() end
    else
        local shortfall = effectiveCost - balance
        btn.BackgroundColor3 = HATCH_GRAY_BG
        btn.TextColor3       = HATCH_GRAY_FG
        btn.AutoButtonColor  = false
        btn.Text = "⚠ Need " .. NumberFormat.Abbreviate(shortfall) .. " more"
        -- Inline hint label: soft monetization nudge, no popup
        if btn.Parent then
            local hintKey = "__ShortfallHint_" .. egg.Id
            local hint = btn.Parent:FindFirstChild(hintKey)
            if not hint then
                hint = Instance.new("TextLabel")
                hint.Name = hintKey
                hint.Size = UDim2.new(0.85, 0, 0, 16)
                hint.AnchorPoint = Vector2.new(0.5, 0)
                -- Hatch button sits at (1, -44) h=36 → bottom edge at (1, -8).
                -- Place hint immediately below: (1, -6) gives a 2px gap.
                hint.Position = UDim2.new(0.5, 0, 1, -6)
                hint.BackgroundTransparency = 1
                hint.Font = Enum.Font.Gotham
                hint.TextSize = 10
                hint.TextColor3 = Color3.fromRGB(120, 180, 255)
                hint.ZIndex = btn.ZIndex
                hint.Parent = btn.Parent
            end
            -- Long form first; fall back to short form if it overflows the label
            hint.Text = "Need " .. NumberFormat.Abbreviate(shortfall) .. " more coins ⚡ Earn faster with boosts"
            if not hint.TextFits then
                hint.Text = "Need " .. NumberFormat.Abbreviate(shortfall) .. " more ⚡"
            end
        end
    end
end

-- Re-evaluate every live hatch button (O(n) over open egg cards only).
-- Called on CurrencyUpdated and after PlayerDataLoaded.
local function updateAllHatchButtons()
    for _, ref in pairs(hatchButtonRefs) do
        local effectiveCost = ref.egg.Cost * (ownedGamepasses["triple_hatch"] and 3 or 1)
        applyHatchButtonState(ref.btn, ref.egg, coinBalance, effectiveCost)
    end
end

-- ─── Hatch-spam detection (contextual auto-hatch nudge) ──────────────────────
-- Fires once per session after the player hits 5 hatches in ≤30 seconds.
-- Mirrors the "I wish this was automatic" friction moment the CEO describes.
local spamSessionShown    = false   -- only fires once per session
local spamHatchTimestamps = {}      -- ring of recent hatch tick() values

local function recordHatchForSpamDetect()
    if spamSessionShown then return end
    local now = tick()
    table.insert(spamHatchTimestamps, now)
    -- Trim entries older than 30 s
    while #spamHatchTimestamps > 0 and (now - spamHatchTimestamps[1]) > 30 do
        table.remove(spamHatchTimestamps, 1)
    end
    if #spamHatchTimestamps >= 5 then
        spamSessionShown = true
        -- Show contextual non-modal card (bottom center)
        showAutoHatchContextCard()
    end
end

-- ─── Auto-Hatch purchase modal ────────────────────────────────────────────────
-- A focused, single-purpose purchase modal.  No shop navigation required.
-- Shown when player clicks the locked inline button OR the contextual card CTA.

local autoHatchModal  -- forward declare; created lazily

local function buildAutoHatchModal()
    if autoHatchModal then return end  -- singleton

    autoHatchModal = Instance.new("ScreenGui")
    autoHatchModal.Name = "AutoHatchModal"
    autoHatchModal.ResetOnSpawn = false
    autoHatchModal.DisplayOrder = 30
    autoHatchModal.Enabled = false
    autoHatchModal.Parent = playerGui

    local overlay = Instance.new("TextButton")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = autoHatchModal

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 320, 0, 380)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.BackgroundColor3 = Color3.fromRGB(16, 14, 30)
    panel.BorderSizePixel = 0
    panel.Parent = autoHatchModal

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 18)
    panelCorner.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(255, 200, 50)
    panelStroke.Thickness = 2.5
    panelStroke.Parent = panel

    -- "MOST POPULAR" badge
    local badge = Instance.new("Frame")
    badge.Size = UDim2.new(0, 130, 0, 24)
    badge.AnchorPoint = Vector2.new(0.5, 0)
    badge.Position = UDim2.new(0.5, 0, 0, -14)
    badge.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    badge.BorderSizePixel = 0
    badge.ZIndex = 5
    badge.Parent = panel
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 12)
    badgeCorner.Parent = badge
    local badgeLabel = Instance.new("TextLabel")
    badgeLabel.Size = UDim2.new(1, 0, 1, 0)
    badgeLabel.BackgroundTransparency = 1
    badgeLabel.Text = "⭐ MOST POPULAR"
    badgeLabel.TextColor3 = Color3.fromRGB(40, 20, 0)
    badgeLabel.Font = Enum.Font.GothamBlack
    badgeLabel.TextSize = 11
    badgeLabel.ZIndex = 6
    badgeLabel.Parent = badge

    -- Animated egg icon (pulsing glow)
    local eggIcon = Instance.new("TextLabel")
    eggIcon.Size = UDim2.new(0, 80, 0, 80)
    eggIcon.AnchorPoint = Vector2.new(0.5, 0)
    eggIcon.Position = UDim2.new(0.5, 0, 0, 24)
    eggIcon.BackgroundColor3 = Color3.fromRGB(30, 28, 50)
    eggIcon.TextColor3 = Color3.fromRGB(255, 230, 80)
    eggIcon.Text = "🥚"
    eggIcon.Font = Enum.Font.GothamBold
    eggIcon.TextSize = 44
    eggIcon.BorderSizePixel = 0
    eggIcon.ZIndex = 3
    eggIcon.Parent = panel
    do
        local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(1, 0); ec.Parent = eggIcon
        local es = Instance.new("UIStroke"); es.Color = Color3.fromRGB(255, 200, 50); es.Thickness = 2; es.Parent = eggIcon
    end
    -- Continuous pulse tween
    task.spawn(function()
        while eggIcon.Parent do
            TweenService:Create(eggIcon, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundColor3 = Color3.fromRGB(60, 50, 90),
            }):Play()
            task.wait(1.0)
            TweenService:Create(eggIcon, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundColor3 = Color3.fromRGB(30, 28, 50),
            }):Play()
            task.wait(1.0)
        end
    end)

    -- Title
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 30)
    titleLbl.Position = UDim2.new(0, 10, 0, 114)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "Auto Hatch"
    titleLbl.TextColor3 = Color3.new(1, 1, 1)
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 22
    titleLbl.Parent = panel

    -- Subtitle
    local subtitleLbl = Instance.new("TextLabel")
    subtitleLbl.Size = UDim2.new(1, -20, 0, 20)
    subtitleLbl.Position = UDim2.new(0, 10, 0, 144)
    subtitleLbl.BackgroundTransparency = 1
    subtitleLbl.Text = "Hatch eggs automatically — no clicking"
    subtitleLbl.TextColor3 = Color3.fromRGB(170, 170, 200)
    subtitleLbl.Font = Enum.Font.Gotham
    subtitleLbl.TextSize = 13
    subtitleLbl.Parent = panel

    -- Value bullets
    local bullets = {
        "🔁  Fully automatic",
        "⚡  Faster progression",
        "🎯  Perfect for farming",
    }
    for i, bullet in ipairs(bullets) do
        local bl = Instance.new("TextLabel")
        bl.Size = UDim2.new(1, -30, 0, 20)
        bl.Position = UDim2.new(0, 15, 0, 170 + (i - 1) * 22)
        bl.BackgroundTransparency = 1
        bl.Text = bullet
        bl.TextColor3 = Color3.fromRGB(140, 220, 140)
        bl.Font = Enum.Font.GothamBold
        bl.TextSize = 13
        bl.TextXAlignment = Enum.TextXAlignment.Left
        bl.Parent = panel
    end

    -- Price block
    local priceLbl = Instance.new("TextLabel")
    priceLbl.Size = UDim2.new(1, -20, 0, 32)
    priceLbl.Position = UDim2.new(0, 10, 0, 240)
    priceLbl.BackgroundTransparency = 1
    priceLbl.Text = "399 R$"
    priceLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    priceLbl.Font = Enum.Font.GothamBlack
    priceLbl.TextSize = 26
    priceLbl.Parent = panel

    -- "Unlock" buy button
    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Size = UDim2.new(0.85, 0, 0, 44)
    unlockBtn.AnchorPoint = Vector2.new(0.5, 0)
    unlockBtn.Position = UDim2.new(0.5, 0, 0, 282)
    unlockBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    unlockBtn.Text = "🔓 Unlock Auto Hatch"
    unlockBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
    unlockBtn.Font = Enum.Font.GothamBlack
    unlockBtn.TextSize = 16
    unlockBtn.AutoButtonColor = true
    unlockBtn.Parent = panel
    do
        local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0, 10); uc.Parent = unlockBtn
    end

    unlockBtn.MouseButton1Click:Connect(function()
        Network.FireServer("PurchaseGamepass", "auto_hatch")
        autoHatchModal.Enabled = false
    end)

    -- 'Maybe later' dismiss
    local laterBtn = Instance.new("TextButton")
    laterBtn.Size = UDim2.new(0.85, 0, 0, 28)
    laterBtn.AnchorPoint = Vector2.new(0.5, 0)
    laterBtn.Position = UDim2.new(0.5, 0, 0, 334)
    laterBtn.BackgroundTransparency = 1
    laterBtn.Text = "Maybe later"
    laterBtn.TextColor3 = Color3.fromRGB(110, 110, 140)
    laterBtn.Font = Enum.Font.Gotham
    laterBtn.TextSize = 12
    laterBtn.AutoButtonColor = false
    laterBtn.Parent = panel

    laterBtn.MouseButton1Click:Connect(function()
        autoHatchModal.Enabled = false
    end)
    overlay.MouseButton1Click:Connect(function()
        autoHatchModal.Enabled = false
    end)
end

function showAutoHatchPurchaseModal()
    if ownedGamepasses["auto_hatch"] then return end
    buildAutoHatchModal()
    autoHatchModal.Enabled = true
    -- Bounce-in animation
    local panel = autoHatchModal:FindFirstChild("Panel")
    if panel then
        panel.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Size = UDim2.new(0, 320, 0, 380),
        }):Play()
    end
end

-- ─── Contextual bottom-center card (non-modal, fades after 5s) ───────────────
local autoHatchContextCard  -- lazily created

local function buildAutoHatchContextCard()
    if autoHatchContextCard then return end

    local cardGui = Instance.new("ScreenGui")
    cardGui.Name = "AutoHatchContextCard"
    cardGui.ResetOnSpawn = false
    cardGui.DisplayOrder = 20
    cardGui.Enabled = false
    cardGui.Parent = playerGui

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(0, 300, 0, 80)
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.Position = UDim2.new(0.5, 0, 1, -80)
    card.BackgroundColor3 = Color3.fromRGB(18, 16, 32)
    card.BorderSizePixel = 0
    card.Parent = cardGui

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 14)
    cCorner.Parent = card

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = Color3.fromRGB(255, 200, 50)
    cStroke.Thickness = 2
    cStroke.Parent = card

    local msgLbl = Instance.new("TextLabel")
    msgLbl.Size = UDim2.new(1, -12, 0, 36)
    msgLbl.Position = UDim2.new(0, 6, 0, 6)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Text = "You're hatching fast ⚡\nGo hands-free with Auto Hatch"
    msgLbl.TextColor3 = Color3.fromRGB(220, 220, 240)
    msgLbl.Font = Enum.Font.GothamBold
    msgLbl.TextSize = 12
    msgLbl.TextWrapped = true
    msgLbl.TextYAlignment = Enum.TextYAlignment.Top
    msgLbl.Parent = card

    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Size = UDim2.new(0, 130, 0, 26)
    unlockBtn.Position = UDim2.new(0, 8, 1, -32)
    unlockBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    unlockBtn.Text = "Unlock 399 R$"
    unlockBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
    unlockBtn.Font = Enum.Font.GothamBold
    unlockBtn.TextSize = 12
    unlockBtn.AutoButtonColor = true
    unlockBtn.Parent = card
    do local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0, 7); uc.Parent = unlockBtn end

    local laterBtn = Instance.new("TextButton")
    laterBtn.Size = UDim2.new(0, 60, 0, 26)
    laterBtn.Position = UDim2.new(1, -68, 1, -32)
    laterBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    laterBtn.Text = "Later"
    laterBtn.TextColor3 = Color3.fromRGB(150, 150, 170)
    laterBtn.Font = Enum.Font.Gotham
    laterBtn.TextSize = 12
    laterBtn.AutoButtonColor = true
    laterBtn.Parent = card
    do local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, 7); lc.Parent = laterBtn end

    unlockBtn.MouseButton1Click:Connect(function()
        cardGui.Enabled = false
        showAutoHatchPurchaseModal()
    end)
    laterBtn.MouseButton1Click:Connect(function()
        cardGui.Enabled = false
    end)

    autoHatchContextCard = cardGui
end

function showAutoHatchContextCard()
    if ownedGamepasses["auto_hatch"] then return end
    buildAutoHatchContextCard()
    autoHatchContextCard.Enabled = true
    -- Slide up from bottom
    local card = autoHatchContextCard:FindFirstChild("Card")
    if card then
        card.Position = UDim2.new(0.5, 0, 1, 20)
        TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
            Position = UDim2.new(0.5, 0, 1, -80),
        }):Play()
    end
    -- Auto-dismiss after 5 s
    task.delay(5, function()
        if autoHatchContextCard and autoHatchContextCard.Enabled then
            local c = autoHatchContextCard:FindFirstChild("Card")
            if c then
                TweenService:Create(c, TweenInfo.new(0.3), {
                    Position = UDim2.new(0.5, 0, 1, 20),
                }):Play()
                task.wait(0.35)
            end
            autoHatchContextCard.Enabled = false
        end
    end)
end

-- ─── Post-purchase chain upsell: Auto Hatch → Triple Hatch ────────────────────
-- Appears 2 seconds after `auto_hatch` purchase; bottom-card, 8 s auto-dismiss.
local tripleHatchChainCard  -- lazily created

local function buildTripleHatchChainCard()
    if tripleHatchChainCard then return end

    local cardGui = Instance.new("ScreenGui")
    cardGui.Name = "TripleHatchChainCard"
    cardGui.ResetOnSpawn = false
    cardGui.DisplayOrder = 21
    cardGui.Enabled = false
    cardGui.Parent = playerGui

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(0, 320, 0, 88)
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.Position = UDim2.new(0.5, 0, 1, -80)
    card.BackgroundColor3 = Color3.fromRGB(16, 24, 16)
    card.BorderSizePixel = 0
    card.Parent = cardGui

    local cCorner = Instance.new("UICorner"); cCorner.CornerRadius = UDim.new(0, 14); cCorner.Parent = card
    local cStroke = Instance.new("UIStroke")
    cStroke.Color = Color3.fromRGB(100, 220, 100)
    cStroke.Thickness = 2
    cStroke.Parent = card

    local msgLbl = Instance.new("TextLabel")
    msgLbl.Size = UDim2.new(1, -12, 0, 40)
    msgLbl.Position = UDim2.new(0, 6, 0, 6)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Text = "🔁 Auto Hatch activated!\nNow hatch 3 at once → Triple Hatch"
    msgLbl.TextColor3 = Color3.fromRGB(200, 240, 200)
    msgLbl.Font = Enum.Font.GothamBold
    msgLbl.TextSize = 12
    msgLbl.TextWrapped = true
    msgLbl.TextYAlignment = Enum.TextYAlignment.Top
    msgLbl.Parent = card

    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Size = UDim2.new(0, 150, 0, 26)
    unlockBtn.Position = UDim2.new(0, 8, 1, -33)
    unlockBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    unlockBtn.Text = "Triple Hatch  499 R$"
    unlockBtn.TextColor3 = Color3.fromRGB(10, 30, 10)
    unlockBtn.Font = Enum.Font.GothamBold
    unlockBtn.TextSize = 12
    unlockBtn.AutoButtonColor = true
    unlockBtn.Parent = card
    do local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0, 7); uc.Parent = unlockBtn end

    local laterBtn = Instance.new("TextButton")
    laterBtn.Size = UDim2.new(0, 60, 0, 26)
    laterBtn.Position = UDim2.new(1, -68, 1, -33)
    laterBtn.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
    laterBtn.Text = "Later"
    laterBtn.TextColor3 = Color3.fromRGB(120, 180, 120)
    laterBtn.Font = Enum.Font.Gotham
    laterBtn.TextSize = 12
    laterBtn.AutoButtonColor = true
    laterBtn.Parent = card
    do local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, 7); lc.Parent = laterBtn end

    unlockBtn.MouseButton1Click:Connect(function()
        Network.FireServer("PurchaseGamepass", "triple_hatch")
        cardGui.Enabled = false
    end)
    laterBtn.MouseButton1Click:Connect(function()
        cardGui.Enabled = false
    end)

    tripleHatchChainCard = cardGui
end

function showTripleHatchChainUpsell()
    if ownedGamepasses["triple_hatch"] then return end
    buildTripleHatchChainCard()
    tripleHatchChainCard.Enabled = true
    local card = tripleHatchChainCard:FindFirstChild("Card")
    if card then
        card.Position = UDim2.new(0.5, 0, 1, 20)
        TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
            Position = UDim2.new(0.5, 0, 1, -80),
        }):Play()
    end
    -- Auto-dismiss after 8 s
    task.delay(8, function()
        if tripleHatchChainCard and tripleHatchChainCard.Enabled then
            local c = tripleHatchChainCard:FindFirstChild("Card")
            if c then
                TweenService:Create(c, TweenInfo.new(0.3), {
                    Position = UDim2.new(0.5, 0, 1, 20),
                }):Play()
                task.wait(0.35)
            end
            tripleHatchChainCard.Enabled = false
        end
    end)
end

-- Populate eggs
local function refreshEggs()
    -- Clear stale button refs before rebuilding cards.
    -- The old TextButton instances will be GC'd when their parent cards are destroyed.
    hatchButtonRefs = {}
    for _, child in ipairs(eggScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    updateTabVisuals()

    if activeTab == "MyEggs" then
        -- ═══════════════════════════════════════
        -- MY EGGS TAB: Show collected eggs with Hatch buttons
        -- ═══════════════════════════════════════
        local hasAny = false
        for eggId, count in pairs(collectedEggs) do
            if count > 0 then
                hasAny = true
                local egg = EggConfig.GetEgg(eggId)
                if not egg then continue end
                local zone = ZoneConfig.GetZone(egg.Zone)

                local card = Instance.new("Frame")
                card.Name = egg.Id
                card.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
                card.BorderSizePixel = 0
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

                local cStroke = Instance.new("UIStroke")
                cStroke.Color = zone and zone.Color or Color3.fromRGB(100, 100, 100)
                cStroke.Thickness = 2
                cStroke.Parent = card

                -- Egg visual
                local eggVisual = Instance.new("Frame")
                eggVisual.Name = "EggVisual"
                eggVisual.Size = UDim2.new(0, 80, 0, 100)
                eggVisual.Position = UDim2.new(0.5, -40, 0, 10)
                eggVisual.BackgroundTransparency = 1
                eggVisual.Parent = card
                buildEggVisual(eggVisual, zone, true, egg.Image)

                -- Count badge
                local countBadge = Instance.new("TextLabel")
                countBadge.Size = UDim2.new(0, 36, 0, 24)
                countBadge.Position = UDim2.new(1, -44, 0, 8)
                countBadge.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
                countBadge.Text = "x" .. count
                countBadge.TextColor3 = Color3.fromRGB(20, 20, 35)
                countBadge.Font = Enum.Font.GothamBold
                countBadge.TextSize = 14
                countBadge.Parent = card
                Instance.new("UICorner", countBadge).CornerRadius = UDim.new(0, 6)

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
                for _, entry in ipairs(egg.Pets) do totalWeight = totalWeight + entry.Weight end
                for _, entry in ipairs(egg.Pets) do
                    local petInfo = PetConfig.GetPet(entry.PetId)
                    if petInfo then
                        local chance = (entry.Weight / totalWeight) * 100
                        local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]
                        local petRow = Instance.new("Frame")
                        petRow.Size = UDim2.new(1, -16, 0, 16)
                        petRow.Position = UDim2.new(0, 8, 0, chanceY)
                        petRow.BackgroundTransparency = 1
                        petRow.Parent = card
                        local thumbContainer = Instance.new("Frame")
                        thumbContainer.Size = UDim2.new(0, 14, 0, 14)
                        thumbContainer.Position = UDim2.new(0, 0, 0, 1)
                        thumbContainer.BackgroundTransparency = 1
                        thumbContainer.Parent = petRow
                        PetVisualUtil.CreateIcon(thumbContainer, petInfo, nil, UDim2.new(1, 0, 1, 0))
                        local petLine = Instance.new("TextLabel")
                        petLine.Size = UDim2.new(1, -18, 0, 14)
                        petLine.Position = UDim2.new(0, 18, 0, 1)
                        petLine.BackgroundTransparency = 1
                        petLine.Text = string.format("%s - %.1f%%", petInfo.Name, chance)
                        petLine.TextColor3 = rarityInfo and rarityInfo.TextColor or Color3.fromRGB(200, 200, 200)
                        petLine.Font = Enum.Font.Gotham
                        petLine.TextSize = 10
                        petLine.TextXAlignment = Enum.TextXAlignment.Left
                        petLine.Parent = petRow
                        chanceY = chanceY + 17
                    end
                end

                -- Hatch button (from inventory)
                local hatchBtn = Instance.new("TextButton")
                hatchBtn.Size = UDim2.new(0.85, 0, 0, 36)
                hatchBtn.Position = UDim2.new(0.075, 0, 1, -44)
                hatchBtn.Font = Enum.Font.GothamBold
                hatchBtn.TextSize = 14
                hatchBtn.TextColor3 = Color3.new(1, 1, 1)
                hatchBtn.AutoButtonColor = true
                hatchBtn.Text = "🥚 Hatch"
                hatchBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                hatchBtn.Parent = card
                Instance.new("UICorner", hatchBtn).CornerRadius = UDim.new(0, 8)

                hatchBtn.MouseButton1Click:Connect(function()
                    Network.FireServer("HatchEgg", egg.Id)
                end)

                -- Auto-Hatch inline button
                local autoBtn = Instance.new("TextButton")
                autoBtn.Size = UDim2.new(0.85, 0, 0, 30)
                autoBtn.Position = UDim2.new(0.075, 0, 1, -80)
                autoBtn.Font = Enum.Font.GothamBold
                autoBtn.TextSize = 12
                autoBtn.Parent = card
                Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 7)

                if ownedGamepasses["auto_hatch"] then
                    if autoHatchEggId == egg.Id then
                        autoBtn.Text = "🔁 Auto Hatch: ON"
                        autoBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
                        autoBtn.TextColor3 = Color3.new(1, 1, 1)
                    else
                        autoBtn.Text = "🔁 Auto Hatch"
                        autoBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
                        autoBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
                    end
                    autoBtn.AutoButtonColor = true
                    autoBtn.MouseButton1Click:Connect(function()
                        if autoHatchEggId == egg.Id then
                            autoHatchEggId = nil
                        else
                            autoHatchEggId = egg.Id
                        end
                        Network.FireServer("AutoHatchToggle", egg.Id)
                        if screenGui.Enabled then refreshEggs() end
                    end)
                else
                    autoBtn.Text = "🔒 Auto Hatch (Unlock)"
                    autoBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
                    autoBtn.TextColor3 = Color3.fromRGB(130, 130, 160)
                    autoBtn.AutoButtonColor = true
                    autoBtn.MouseButton1Click:Connect(function()
                        showAutoHatchPurchaseModal()
                    end)
                end

                card.Parent = eggScroll
            end
        end

        -- Empty state
        if not hasAny then
            local emptyLabel = Instance.new("Frame")
            emptyLabel.Name = "EmptyState"
            emptyLabel.Size = UDim2.new(1, 0, 0, 120)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.Parent = eggScroll

            local emptyText = Instance.new("TextLabel")
            emptyText.Size = UDim2.new(1, -40, 1, 0)
            emptyText.Position = UDim2.new(0, 20, 0, 0)
            emptyText.BackgroundTransparency = 1
            emptyText.Text = "🥚 No eggs collected yet!\n\nVisit zones and collect eggs from the field,\nthen come back here to hatch them!"
            emptyText.TextColor3 = Color3.fromRGB(140, 140, 160)
            emptyText.Font = Enum.Font.GothamBold
            emptyText.TextSize = 16
            emptyText.TextWrapped = true
            emptyText.Parent = emptyLabel
        end
    else
        -- ═══════════════════════════════════════
        -- EGG INFO TAB: Browse all eggs by zone (informational)
        -- ═══════════════════════════════════════
        for _, egg in ipairs(EggConfig.Eggs) do
            local zone = ZoneConfig.GetZone(egg.Zone)
            local isUnlocked = false
            for _, zId in ipairs(unlockedZones) do
                if zId == egg.Zone then isUnlocked = true break end
            end

            local card = Instance.new("Frame")
            card.Name = egg.Id
            card.BackgroundColor3 = isUnlocked and Color3.fromRGB(35, 35, 55) or Color3.fromRGB(25, 25, 35)
            card.BorderSizePixel = 0
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

            local cStroke = Instance.new("UIStroke")
            cStroke.Color = isUnlocked and (zone and zone.Color or Color3.fromRGB(100, 100, 100)) or Color3.fromRGB(50, 50, 50)
            cStroke.Thickness = 2
            cStroke.Parent = card

            -- Egg visual
            local eggVisual = Instance.new("Frame")
            eggVisual.Name = "EggVisual"
            eggVisual.Size = UDim2.new(0, 80, 0, 100)
            eggVisual.Position = UDim2.new(0.5, -40, 0, 10)
            eggVisual.BackgroundTransparency = 1
            eggVisual.Parent = card
            buildEggVisual(eggVisual, zone, isUnlocked, egg.Image)

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

            -- Cost label
            local costLabel = Instance.new("TextLabel")
            costLabel.Size = UDim2.new(1, 0, 0, 16)
            costLabel.Position = UDim2.new(0, 0, 0, 153)
            costLabel.BackgroundTransparency = 1
            costLabel.Text = "💰 " .. NumberFormat.Abbreviate(egg.Cost) .. " " .. egg.Currency
            costLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
            costLabel.Font = Enum.Font.GothamBold
            costLabel.TextSize = 11
            costLabel.Parent = card

            -- Pet chances list
            local chanceY = 174
            local totalWeight = 0
            for _, entry in ipairs(egg.Pets) do totalWeight = totalWeight + entry.Weight end
            for _, entry in ipairs(egg.Pets) do
                local petInfo = PetConfig.GetPet(entry.PetId)
                if petInfo then
                    local chance = (entry.Weight / totalWeight) * 100
                    local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]
                    local petRow = Instance.new("Frame")
                    petRow.Size = UDim2.new(1, -16, 0, 16)
                    petRow.Position = UDim2.new(0, 8, 0, chanceY)
                    petRow.BackgroundTransparency = 1
                    petRow.Parent = card
                    local thumbContainer = Instance.new("Frame")
                    thumbContainer.Size = UDim2.new(0, 14, 0, 14)
                    thumbContainer.Position = UDim2.new(0, 0, 0, 1)
                    thumbContainer.BackgroundTransparency = 1
                    thumbContainer.Parent = petRow
                    PetVisualUtil.CreateIcon(thumbContainer, petInfo, nil, UDim2.new(1, 0, 1, 0))
                    local petLine = Instance.new("TextLabel")
                    petLine.Size = UDim2.new(1, -18, 0, 14)
                    petLine.Position = UDim2.new(0, 18, 0, 1)
                    petLine.BackgroundTransparency = 1
                    petLine.Text = string.format("%s - %.1f%%", petInfo.Name, chance)
                    petLine.TextColor3 = rarityInfo and rarityInfo.TextColor or Color3.fromRGB(200, 200, 200)
                    petLine.Font = Enum.Font.Gotham
                    petLine.TextSize = 10
                    petLine.TextXAlignment = Enum.TextXAlignment.Left
                    petLine.Parent = petRow
                    chanceY = chanceY + 17
                end
            end

            -- Status label (no hatch button on info tab)
            local statusBtn = Instance.new("TextLabel")
            statusBtn.Size = UDim2.new(0.85, 0, 0, 36)
            statusBtn.Position = UDim2.new(0.075, 0, 1, -44)
            statusBtn.Font = Enum.Font.GothamBold
            statusBtn.TextSize = 14
            statusBtn.Parent = card
            Instance.new("UICorner", statusBtn).CornerRadius = UDim.new(0, 8)

            if isUnlocked then
                local owned = collectedEggs[egg.Id] or 0
                if owned > 0 then
                    statusBtn.Text = "✅ " .. owned .. " collected"
                    statusBtn.TextColor3 = Color3.fromRGB(80, 255, 120)
                    statusBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 40)
                else
                    statusBtn.Text = "Collect in zone"
                    statusBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
                    statusBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
                end
            else
                statusBtn.Text = "🔒 Locked"
                statusBtn.TextColor3 = Color3.new(1, 1, 1)
                statusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            end

            card.Parent = eggScroll
        end
    end
end

-- Tab click handlers
myEggsTab.MouseButton1Click:Connect(function()
    if activeTab ~= "MyEggs" then
        activeTab = "MyEggs"
        refreshEggs()
    end
end)

eggInfoTab.MouseButton1Click:Connect(function()
    if activeTab ~= "EggInfo" then
        activeTab = "EggInfo"
        refreshEggs()
    end
end)

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
    ownedGamepasses = data.Gamepasses or {}
    coinBalance = data.Coins or 0
    collectedEggs = data.CollectedEggs or {}
    if screenGui.Enabled then refreshEggs() end
end)

-- Live coin balance: update hatch buttons on every credit/debit without
-- requiring a full refreshEggs() rebuild.
Network.OnClientEvent("CurrencyUpdated", function(currency: string, amount: number)
    if currency == "Coins" then
        coinBalance = amount
        updateAllHatchButtons()
    end
end)

-- Sync collected egg inventory from server
Network.OnClientEvent("CollectedEggsUpdated", function(eggs)
    collectedEggs = eggs or {}
    if screenGui.Enabled then refreshEggs() end
end)

Network.OnClientEvent("GamepassOwned", function(gamepassId)
    ownedGamepasses[gamepassId] = true
    if screenGui.Enabled then
        refreshEggs()
    end
    -- Chain upsell: bought Auto Hatch → suggest Triple Hatch after 2 s
    if gamepassId == "auto_hatch" and not ownedGamepasses["triple_hatch"] then
        task.delay(2, function()
            if ownedGamepasses["triple_hatch"] then return end
            if autoHatchContextCard then autoHatchContextCard.Enabled = false end
            if autoHatchModal then autoHatchModal.Enabled = false end
            showTripleHatchChainUpsell()
        end)
    end
end)

-- ═══════════════════════════════════════
-- LUCKY STREAK: track consecutive non-Rare hatches
-- Mirrors Pet Simulator-style pity counters so players
-- feel momentum building toward their next rare pet.
-- ═══════════════════════════════════════

-- Rarity threshold: order >= RARE_ORDER resets the streak.
-- Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5 ...
local RARE_ORDER = 3

local function setLuckyBarIdle()
    luckyBar.BackgroundColor3 = Color3.fromRGB(18, 42, 18)
    lbStroke.Color = Color3.fromRGB(45, 160, 45)
    luckyLabel.TextColor3 = Color3.fromRGB(90, 175, 90)
    luckyLabel.Text = "🍀 Keep hatching — luck builds up!"
end

Network.OnClientEvent("HatchResult", function(results, hatchTime, nearMissLabel, eggId)
    if not results or #results == 0 then return end
    -- Hatch-spam detection: 5 hatches in 30 s triggers Auto Hatch contextual nudge
    recordHatchForSpamDetect()

    -- Hatch reveal animation handled by HatchController

    -- Determine the best rarity order across all hatched pets in this batch.
    local bestOrder = 0
    for _, result in ipairs(results) do
        local tier = RarityConfig.Tiers[result.Rarity]
        local order = tier and tier.Order or 1
        if order > bestOrder then bestOrder = order end
        if result.Rainbow then bestOrder = math.max(bestOrder, 7) end  -- max spectacular
    end

    if bestOrder < RARE_ORDER then
        -- Dry hatch (Common/Uncommon) — increment streak.
        luckyStreak = luckyStreak + 1
        local streakText
        if luckyStreak >= 20 then
            streakText = "🔥 " .. luckyStreak .. " hatches — RARE IS COMING!!"
            luckyLabel.TextColor3 = Color3.fromRGB(255, 120, 30)
            lbStroke.Color = Color3.fromRGB(255, 140, 40)
            luckyBar.BackgroundColor3 = Color3.fromRGB(50, 28, 10)
            -- Urgent pulse animation
            TweenService:Create(luckyBar, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), {
                BackgroundColor3 = Color3.fromRGB(80, 50, 15),
            }):Play()
        elseif luckyStreak >= 10 then
            streakText = "✨ Lucky Streak: " .. luckyStreak .. " — Getting warmer!"
            luckyLabel.TextColor3 = Color3.fromRGB(255, 220, 70)
            lbStroke.Color = Color3.fromRGB(210, 185, 50)
            luckyBar.BackgroundColor3 = Color3.fromRGB(38, 34, 10)
        else
            streakText = "🍀 Lucky Streak: " .. luckyStreak
            luckyLabel.TextColor3 = Color3.fromRGB(100, 210, 100)
            lbStroke.Color = Color3.fromRGB(50, 160, 50)
            luckyBar.BackgroundColor3 = Color3.fromRGB(18, 42, 18)
        end
        luckyLabel.Text = streakText
    else
        -- Rare or better — reset streak.
        if luckyStreak > 0 then
            local captured = luckyStreak
            luckyStreak = 0
            -- Brief gold celebration flash on bar
            luckyBar.BackgroundColor3 = Color3.fromRGB(70, 55, 10)
            lbStroke.Color = Color3.fromRGB(255, 200, 50)
            luckyLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
            luckyLabel.Text = "⭐ Rare after " .. captured .. " hatches! Lucky!"
            TweenService:Create(luckyBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(50, 40, 8),
            }):Play()
            task.delay(3.5, function()
                if luckyStreak == 0 then
                    setLuckyBarIdle()
                end
            end)
        else
            luckyStreak = 0
        end
    end
end)

-- ═══════════════════════════════════════
-- NEAR-MISS HANDLER: screen-edge glow pulse
-- Reinforces "so close!" feeling with a rarity-colored
-- border flash on the reveal overlay.
-- ═══════════════════════════════════════
Network.OnClientEvent("NearMissHatch", function(nearMissRarity)
    local tier = RarityConfig.Tiers[nearMissRarity]
    local glowColor = tier and tier.GlowColor or Color3.fromRGB(255, 200, 50)

    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(1, 0, 1, 0)
    glow.BackgroundTransparency = 1
    glow.BorderSizePixel = 0
    glow.ZIndex = 100
    glow.Parent = screenGui

    local glowStroke = Instance.new("UIStroke")
    glowStroke.Color = glowColor
    glowStroke.Thickness = 0
    glowStroke.Parent = glow

    TweenService:Create(glowStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Thickness = 8,
    }):Play()
    task.delay(0.5, function()
        TweenService:Create(glowStroke, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Thickness = 0,
        }):Play()
        task.delay(1.1, function()
            if glow.Parent then glow:Destroy() end
        end)
    end)
end)

print("[GUI] EggGui loaded")
