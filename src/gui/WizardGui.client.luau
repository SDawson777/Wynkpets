--[[
    WizardGui.client.luau
    Client-side visuals for the Evil Wizard event:
    • Zone-wide warning banner  (top of screen)
    • Red vignette pulse when the wizard is targeting THIS player
    • "Pet Stolen!" dramatic overlay
    • "You Survived!" celebration overlay with coin bonus
    • Smoke arrival / departure screen flash
]]

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player      = Players.LocalPlayer
local playerGui   = player:WaitForChild("PlayerGui")

local Shared  = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

-- Feature gate: if Wizard is disabled, skip all UI and event listener setup
if not LaunchConfig.IsFeatureEnabled("Wizard") then return end

-- ═══════════════════════════════════════
-- ROOT SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "WizardGui"
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = true
screenGui.DisplayOrder    = 30    -- above most HUD, below critical modals
screenGui.Enabled         = true
screenGui.Parent          = playerGui

-- ═══════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════

local function tween(instance, info, props)
    local t = TweenService:Create(instance, info, props)
    t:Play()
    return t
end

local function later(delay, fn)
    task.delay(delay, fn)
end

-- ═══════════════════════════════════════
-- 1. WARNING BANNER  (slides down from top)
-- ═══════════════════════════════════════

local warningBanner = Instance.new("Frame")
warningBanner.Name             = "WizardWarningBanner"
warningBanner.Size             = UDim2.new(1, 0, 0, 72)
warningBanner.Position         = UDim2.new(0, 0, 0, -80)  -- hidden off-screen
warningBanner.BackgroundColor3 = Color3.fromRGB(30, 0, 50)
warningBanner.BorderSizePixel  = 0
warningBanner.ZIndex           = 20
warningBanner.Parent           = screenGui

do
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(200, 0, 255)
    stroke.Thickness = 3
    stroke.Parent = warningBanner

    -- icon
    local icon = Instance.new("TextLabel")
    icon.Size                 = UDim2.new(0, 72, 1, 0)
    icon.Position             = UDim2.new(0, 10, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text                 = "🧙"
    icon.TextScaled           = true
    icon.Font                 = Enum.Font.GothamBold
    icon.ZIndex               = 21
    icon.Parent               = warningBanner

    local label = Instance.new("TextLabel")
    label.Name                = "BannerLabel"
    label.Size                = UDim2.new(1, -90, 1, 0)
    label.Position            = UDim2.new(0, 86, 0, 0)
    label.BackgroundTransparency = 1
    label.Text                = "The Evil Wizard has appeared!"
    label.TextColor3          = Color3.fromRGB(255, 160, 255)
    label.TextScaled          = true
    label.Font                = Enum.Font.GothamBold
    label.TextXAlignment      = Enum.TextXAlignment.Left
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3    = Color3.fromRGB(0, 0, 0)
    label.ZIndex              = 21
    label.Parent              = warningBanner
end

local bannerLabel = warningBanner:FindFirstChild("BannerLabel")

local function showWarningBanner(zoneName)
    bannerLabel.Text = "⚠  The Evil Wizard has appeared in " .. zoneName .. "!  Protect your pets!"
    tween(warningBanner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    })
end

local function hideWarningBanner()
    tween(warningBanner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 0, 0, -80)
    })
end

-- ═══════════════════════════════════════
-- 2. RED VIGNETTE  (pulsing danger border)
-- ═══════════════════════════════════════

local vignette = Instance.new("Frame")
vignette.Name              = "WizardVignette"
vignette.Size              = UDim2.new(1, 0, 1, 0)
vignette.Position          = UDim2.new(0, 0, 0, 0)
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel   = 0
vignette.ZIndex            = 5
vignette.Parent            = screenGui

do
    -- four edge strips to create vignette
    local edges = {
        { name = "Top",    size = UDim2.new(1,0,0,60),  pos = UDim2.new(0,0,0,0)   },
        { name = "Bottom", size = UDim2.new(1,0,0,60),  pos = UDim2.new(0,0,1,-60) },
        { name = "Left",   size = UDim2.new(0,60,1,0),  pos = UDim2.new(0,0,0,0)   },
        { name = "Right",  size = UDim2.new(0,60,1,0),  pos = UDim2.new(1,-60,0,0) },
    }
    for _, e in ipairs(edges) do
        local f = Instance.new("Frame")
        f.Name = e.name
        f.Size = e.size
        f.Position = e.pos
        f.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ZIndex = 5
        f.Parent = vignette
    end
end

local vignetteActive  = false
local vignetteConn    = nil

local function setVignetteEdges(transparency)
    for _, f in ipairs(vignette:GetChildren()) do
        if f:IsA("Frame") then
            f.BackgroundTransparency = transparency
        end
    end
end

local function startVignettePulse()
    if vignetteActive then return end
    vignetteActive = true

    local function pulse()
        if not vignetteActive then
            setVignetteEdges(1)
            return
        end
        tween(vignette:FindFirstChild("Top"), TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.4})
        tween(vignette:FindFirstChild("Bottom"), TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.4})
        tween(vignette:FindFirstChild("Left"), TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.4})
        tween(vignette:FindFirstChild("Right"), TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.4})
        task.wait(0.5)
        if not vignetteActive then
            setVignetteEdges(1)
            return
        end
        tween(vignette:FindFirstChild("Top"), TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.85})
        tween(vignette:FindFirstChild("Bottom"), TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.85})
        tween(vignette:FindFirstChild("Left"), TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.85})
        tween(vignette:FindFirstChild("Right"), TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.85})
        task.wait(0.5)
        pulse()
    end

    task.spawn(pulse)
end

local function stopVignettePulse()
    vignetteActive = false
    setVignetteEdges(1)
end

-- ═══════════════════════════════════════
-- 3. BIG OVERLAY HELPER  (stolen / survived)
-- ═══════════════════════════════════════

local overlay = Instance.new("Frame")
overlay.Name               = "WizardOverlay"
overlay.Size               = UDim2.new(0, 500, 0, 200)
overlay.Position           = UDim2.new(0.5, -250, 0.5, -100)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel    = 0
overlay.AnchorPoint        = Vector2.new(0.5, 0.5)
overlay.ZIndex             = 25
overlay.Parent             = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Name               = "Title"
titleLabel.Size               = UDim2.new(1, 0, 0.55, 0)
titleLabel.Position           = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text               = ""
titleLabel.TextColor3         = Color3.fromRGB(255, 80, 80)
titleLabel.TextScaled         = true
titleLabel.Font               = Enum.Font.GothamBold
titleLabel.TextStrokeTransparency = 0
titleLabel.TextStrokeColor3   = Color3.fromRGB(0, 0, 0)
titleLabel.ZIndex             = 26
titleLabel.Parent             = overlay

local subLabel = Instance.new("TextLabel")
subLabel.Name                 = "Sub"
subLabel.Size                 = UDim2.new(1, 0, 0.4, 0)
subLabel.Position             = UDim2.new(0, 0, 0.58, 0)
subLabel.BackgroundTransparency = 1
subLabel.Text                 = ""
subLabel.TextColor3           = Color3.fromRGB(255, 220, 255)
subLabel.TextScaled           = true
subLabel.Font                 = Enum.Font.Gotham
subLabel.TextStrokeTransparency = 0.3
subLabel.TextStrokeColor3     = Color3.fromRGB(0, 0, 0)
subLabel.ZIndex               = 26
subLabel.Parent               = overlay

local function showOverlay(title, sub, titleColour, duration)
    titleLabel.Text       = title
    titleLabel.TextColor3 = titleColour
    subLabel.Text         = sub
    overlay.Size          = UDim2.new(0, 100, 0, 40)
    overlay.BackgroundTransparency = 1

    tween(overlay, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 500, 0, 200)
    })

    later(duration or 3, function()
        tween(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 100, 0, 40)
        })
        later(0.35, function()
            titleLabel.Text = ""
            subLabel.Text   = ""
        end)
    end)
end

-- ═══════════════════════════════════════
-- 4. SMOKE FLASH  (arrival / departure)
-- ═══════════════════════════════════════

local smokeFlash = Instance.new("Frame")
smokeFlash.Name              = "SmokeFlash"
smokeFlash.Size              = UDim2.new(1, 0, 1, 0)
smokeFlash.Position          = UDim2.new(0, 0, 0, 0)
smokeFlash.BackgroundColor3  = Color3.fromRGB(80, 0, 120)
smokeFlash.BackgroundTransparency = 1
smokeFlash.BorderSizePixel   = 0
smokeFlash.ZIndex            = 18
smokeFlash.Parent            = screenGui

local function doSmokeFlash()
    tween(smokeFlash, TweenInfo.new(0.15), {BackgroundTransparency = 0.5})
    later(0.15, function()
        tween(smokeFlash, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
    end)
end

-- ═══════════════════════════════════════
-- 5. NETWORK LISTENERS
-- ═══════════════════════════════════════

Network.OnClientEvent("WizardSpawned", function(zoneId, zoneName, position)
    doSmokeFlash()
    showWarningBanner(zoneName or zoneId)
end)

Network.OnClientEvent("WizardDespawned", function()
    doSmokeFlash()
    hideWarningBanner()
    stopVignettePulse()
end)

Network.OnClientEvent("WizardChasing", function()
    -- Only fire if vignette not already running (avoids spam)
    startVignettePulse()
end)

Network.OnClientEvent("WizardStole", function(petName)
    stopVignettePulse()
    if petName then
        showOverlay(
            "🧙  Pet Stolen!",
            "The Evil Wizard stole your " .. tostring(petName) .. "!",
            Color3.fromRGB(255, 60, 60),
            4
        )
    else
        -- Wizard caught the player but had nothing to steal
        showOverlay(
            "🧙  Wizard Caught You!",
            "Lucky – you had no equipped pets to steal.",
            Color3.fromRGB(255, 180, 60),
            3.5
        )
    end
end)

Network.OnClientEvent("WizardSurvived", function(bonusCoins)
    local coinText = bonusCoins and ("+" .. tostring(bonusCoins) .. " coins") or ""
    showOverlay(
        "✔  You Survived!",
        "You escaped the Evil Wizard!  " .. coinText,
        Color3.fromRGB(80, 255, 120),
        3.5
    )
end)
