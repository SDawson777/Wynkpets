--[[
    MainHUD.client.luau
    Main heads-up display: currency bars, minimap indicators, notification system.
    This is the primary always-visible UI.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local NumberFormat = require(Shared:WaitForChild("Utils"):WaitForChild("NumberFormat"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 1
screenGui.Parent = playerGui

-- ═══════════════════════════════════════
-- CURRENCY DISPLAY (Top center)
-- ═══════════════════════════════════════

local currencyFrame = Instance.new("Frame")
currencyFrame.Name = "CurrencyFrame"
currencyFrame.Size = UDim2.new(0, 400, 0, 50)
currencyFrame.Position = UDim2.new(0.5, -200, 0, 10)
currencyFrame.BackgroundTransparency = 1
currencyFrame.Parent = screenGui

-- Coins display
local coinsFrame = Instance.new("Frame")
coinsFrame.Name = "CoinsFrame"
coinsFrame.Size = UDim2.new(0, 180, 0, 44)
coinsFrame.Position = UDim2.new(0, 0, 0, 0)
coinsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
coinsFrame.BorderSizePixel = 0
coinsFrame.Parent = currencyFrame

local coinsCorner = Instance.new("UICorner")
coinsCorner.CornerRadius = UDim.new(0, 22)
coinsCorner.Parent = coinsFrame

local coinsStroke = Instance.new("UIStroke")
coinsStroke.Color = Color3.fromRGB(255, 200, 0)
coinsStroke.Thickness = 2
coinsStroke.Parent = coinsFrame

local coinsIcon = Instance.new("TextLabel")
coinsIcon.Name = "Icon"
coinsIcon.Size = UDim2.new(0, 36, 0, 36)
coinsIcon.Position = UDim2.new(0, 4, 0.5, -18)
coinsIcon.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
coinsIcon.Text = ""
coinsIcon.Parent = coinsFrame

local coinsIconCorner = Instance.new("UICorner")
coinsIconCorner.CornerRadius = UDim.new(1, 0)
coinsIconCorner.Parent = coinsIcon

local coinsIconLabel = Instance.new("TextLabel")
coinsIconLabel.Size = UDim2.new(1, 0, 1, 0)
coinsIconLabel.BackgroundTransparency = 1
coinsIconLabel.Text = "🪙"
coinsIconLabel.TextSize = 20
coinsIconLabel.Font = Enum.Font.GothamBold
coinsIconLabel.Parent = coinsIcon

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "Amount"
coinsLabel.Size = UDim2.new(1, -46, 1, 0)
coinsLabel.Position = UDim2.new(0, 44, 0, 0)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "0"
coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
coinsLabel.Font = Enum.Font.GothamBold
coinsLabel.TextSize = 20
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Parent = coinsFrame

-- Gems display
local gemsFrame = Instance.new("Frame")
gemsFrame.Name = "GemsFrame"
gemsFrame.Size = UDim2.new(0, 180, 0, 44)
gemsFrame.Position = UDim2.new(0, 200, 0, 0)
gemsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
gemsFrame.BorderSizePixel = 0
gemsFrame.Parent = currencyFrame

local gemsCorner = Instance.new("UICorner")
gemsCorner.CornerRadius = UDim.new(0, 22)
gemsCorner.Parent = gemsFrame

local gemsStroke = Instance.new("UIStroke")
gemsStroke.Color = Color3.fromRGB(100, 200, 255)
gemsStroke.Thickness = 2
gemsStroke.Parent = gemsFrame

local gemsIcon = Instance.new("TextLabel")
gemsIcon.Name = "Icon"
gemsIcon.Size = UDim2.new(0, 36, 0, 36)
gemsIcon.Position = UDim2.new(0, 4, 0.5, -18)
gemsIcon.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
gemsIcon.Text = ""
gemsIcon.Parent = gemsFrame

local gemsIconCorner = Instance.new("UICorner")
gemsIconCorner.CornerRadius = UDim.new(1, 0)
gemsIconCorner.Parent = gemsIcon

local gemsIconLabel = Instance.new("TextLabel")
gemsIconLabel.Size = UDim2.new(1, 0, 1, 0)
gemsIconLabel.BackgroundTransparency = 1
gemsIconLabel.Text = "💎"
gemsIconLabel.TextSize = 18
gemsIconLabel.Font = Enum.Font.GothamBold
gemsIconLabel.Parent = gemsIcon

local gemsLabel = Instance.new("TextLabel")
gemsLabel.Name = "Amount"
gemsLabel.Size = UDim2.new(1, -46, 1, 0)
gemsLabel.Position = UDim2.new(0, 44, 0, 0)
gemsLabel.BackgroundTransparency = 1
gemsLabel.Text = "0"
gemsLabel.TextColor3 = Color3.fromRGB(120, 210, 255)
gemsLabel.Font = Enum.Font.GothamBold
gemsLabel.TextSize = 20
gemsLabel.TextXAlignment = Enum.TextXAlignment.Left
gemsLabel.Parent = gemsFrame

-- ═══════════════════════════════════════
-- SIDE MENU BUTTONS (Right side)
-- ═══════════════════════════════════════

local sideButtons = Instance.new("Frame")
sideButtons.Name = "SideButtons"
sideButtons.Size = UDim2.new(0, 60, 0, 500)
sideButtons.Position = UDim2.new(1, -70, 0.5, -250)
sideButtons.BackgroundTransparency = 1
sideButtons.Parent = screenGui

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 8)
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Parent = sideButtons

local buttonConfigs = {
    { Name = "Pets",    Icon = "🐾", Color = Color3.fromRGB(255, 150, 50) },
    { Name = "Shop",    Icon = "🛒", Color = Color3.fromRGB(50, 200, 100) },
    { Name = "Eggs",    Icon = "🥚", Color = Color3.fromRGB(255, 230, 100) },
    { Name = "Zones",   Icon = "🗺️", Color = Color3.fromRGB(100, 180, 255) },
    { Name = "Rebirth", Icon = "⭐", Color = Color3.fromRGB(255, 100, 150) },
    { Name = "Quests",  Icon = "📋", Color = Color3.fromRGB(200, 150, 255) },
    { Name = "Fuse",    Icon = "🔮", Color = Color3.fromRGB(255, 100, 200) },
    { Name = "Index",   Icon = "📖", Color = Color3.fromRGB(180, 130, 255) },
    { Name = "Trade",   Icon = "🤝", Color = Color3.fromRGB(100, 200, 255) },
    { Name = "Daily",   Icon = "📅", Color = Color3.fromRGB(255, 180, 50) },
    { Name = "Spin",    Icon = "🎰", Color = Color3.fromRGB(255, 50, 80) },
    { Name = "Ranks",   Icon = "🏆", Color = Color3.fromRGB(255, 200, 50) },
    { Name = "Achieve",    Icon = "🎖️", Color = Color3.fromRGB(255, 180, 50) },
    { Name = "BattlePass", Icon = "⚔️",  Color = Color3.fromRGB(70, 45, 160) },
    { Name = "Evolution",  Icon = "✨",  Color = Color3.fromRGB(200, 80, 200) },
    { Name = "Expedition", Icon = "🧭", Color = Color3.fromRGB(80, 180, 140) },
}

for _, config in ipairs(buttonConfigs) do
    local btn = Instance.new("TextButton")
    btn.Name = config.Name .. "Button"
    btn.Size = UDim2.new(0, 54, 0, 54)
    btn.BackgroundColor3 = config.Color
    btn.Text = ""
    btn.AutoButtonColor = true
    btn.Parent = sideButtons

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 12)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.new(1, 1, 1)
    btnStroke.Thickness = 2
    btnStroke.Transparency = 0.5
    btnStroke.Parent = btn

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, 0, 0.65, 0)
    icon.BackgroundTransparency = 1
    icon.Text = config.Icon
    icon.TextSize = 22
    icon.Font = Enum.Font.GothamBold
    icon.Parent = btn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.35, 0)
    label.Position = UDim2.new(0, 0, 0.65, 0)
    label.BackgroundTransparency = 1
    label.Text = config.Name
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 9
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0
    label.Parent = btn

    -- Button hover/click effects
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            Size = UDim2.new(0, 58, 0, 58)
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            Size = UDim2.new(0, 54, 0, 54)
        }):Play()
    end)
end

-- Hide buttons for features disabled by LaunchConfig
local FEATURE_BUTTON_MAP = {
    RebirthButton    = "Rebirth",
    FuseButton       = "Fusion",
    SpinButton       = "Wheel",
    TradeButton      = "Trading",
    BattlePassButton = "BattlePass",
    EvolutionButton  = "Evolution",
    ExpeditionButton = "Expedition",
}
for btnName, featureId in pairs(FEATURE_BUTTON_MAP) do
    local btn = sideButtons:FindFirstChild(btnName)
    if btn and not LaunchConfig.IsFeatureEnabled(featureId) then
        btn.Visible = false
    end
end

-- ═══════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ═══════════════════════════════════════

local notifContainer = Instance.new("Frame")
notifContainer.Name = "Notifications"
notifContainer.Size = UDim2.new(0, 350, 0, 300)
notifContainer.Position = UDim2.new(0.5, -175, 0, 70)
notifContainer.BackgroundTransparency = 1
notifContainer.ClipsDescendants = true
notifContainer.Parent = screenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.Padding = UDim.new(0, 5)
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Parent = notifContainer

local notifColors = {
    Success = Color3.fromRGB(50, 180, 80),
    Warning = Color3.fromRGB(230, 160, 30),
    Info = Color3.fromRGB(80, 150, 255),
    Error = Color3.fromRGB(230, 50, 50),
}

local function showNotification(message: string, notifType: string)
    local color = notifColors[notifType] or notifColors.Info

    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, 36)
    notif.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    notif.BackgroundTransparency = 0.2
    notif.BorderSizePixel = 0
    notif.Parent = notifContainer

    local nCorner = Instance.new("UICorner")
    nCorner.CornerRadius = UDim.new(0, 8)
    nCorner.Parent = notif

    local nStroke = Instance.new("UIStroke")
    nStroke.Color = color
    nStroke.Thickness = 1.5
    nStroke.Parent = notif

    local nText = Instance.new("TextLabel")
    nText.Size = UDim2.new(1, -16, 1, 0)
    nText.Position = UDim2.new(0, 8, 0, 0)
    nText.BackgroundTransparency = 1
    nText.Text = message
    nText.TextColor3 = Color3.new(1, 1, 1)
    nText.Font = Enum.Font.GothamBold
    nText.TextSize = 14
    nText.TextXAlignment = Enum.TextXAlignment.Left
    nText.TextTruncate = Enum.TextTruncate.AtEnd
    nText.Parent = notif

    -- Slide in animation
    notif.Position = UDim2.new(1, 50, 0, 0)
    TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()

    -- Fade out and remove
    task.delay(3, function()
        local fadeOut = TweenService:Create(notif, TweenInfo.new(0.5), {
            BackgroundTransparency = 1,
        })
        TweenService:Create(nText, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
        TweenService:Create(nStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
        fadeOut:Play()
        fadeOut.Completed:Wait()
        notif:Destroy()
    end)
end

-- ═══════════════════════════════════════
-- REBIRTH INFO BAR (Below currency)
-- ═══════════════════════════════════════

local rebirthBar = Instance.new("Frame")
rebirthBar.Name = "RebirthBar"
rebirthBar.Size = UDim2.new(0, 200, 0, 24)
rebirthBar.Position = UDim2.new(0.5, -100, 0, 58)
rebirthBar.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
rebirthBar.BorderSizePixel = 0
rebirthBar.Parent = screenGui

local rbCorner = Instance.new("UICorner")
rbCorner.CornerRadius = UDim.new(0, 12)
rbCorner.Parent = rebirthBar

local rbStroke = Instance.new("UIStroke")
rbStroke.Color = Color3.fromRGB(255, 100, 150)
rbStroke.Thickness = 1.5
rbStroke.Parent = rebirthBar

local rebirthLabel = Instance.new("TextLabel")
rebirthLabel.Name = "RebirthLabel"
rebirthLabel.Size = UDim2.new(1, 0, 1, 0)
rebirthLabel.BackgroundTransparency = 1
rebirthLabel.Text = "⭐ Rebirth 0 | 1.0x"
rebirthLabel.TextColor3 = Color3.fromRGB(255, 150, 200)
rebirthLabel.Font = Enum.Font.GothamBold
rebirthLabel.TextSize = 13
rebirthLabel.Parent = rebirthBar

-- ═══════════════════════════════════════
-- BOOST TIMER DISPLAY (Top left)
-- ═══════════════════════════════════════

local boostFrame = Instance.new("Frame")
boostFrame.Name = "BoostTimers"
boostFrame.Size = UDim2.new(0, 200, 0, 80)
boostFrame.Position = UDim2.new(0, 10, 0, 10)
boostFrame.BackgroundTransparency = 1
boostFrame.Parent = screenGui

local boostLayout = Instance.new("UIListLayout")
boostLayout.Padding = UDim.new(0, 4)
boostLayout.Parent = boostFrame

local activeBoosts = {}
local boostLabels = {}

local boostDisplayNames = {
    Luck = "🍀 Luck x2",
    Coins = "🪙 Coins x2",
    XP = "⚡ XP x2",
    HatchSpeed = "🥚 Hatch x2",
}

local function updateBoostTimers()
    local now = os.time()
    for boostType, expiry in pairs(activeBoosts) do
        local remaining = expiry - now
        if remaining <= 0 then
            activeBoosts[boostType] = nil
            if boostLabels[boostType] then
                boostLabels[boostType]:Destroy()
                boostLabels[boostType] = nil
            end
        else
            if not boostLabels[boostType] then
                local label = Instance.new("Frame")
                label.Size = UDim2.new(1, 0, 0, 24)
                label.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
                label.BackgroundTransparency = 0.3
                label.BorderSizePixel = 0
                label.Parent = boostFrame

                local lCorner = Instance.new("UICorner")
                lCorner.CornerRadius = UDim.new(0, 8)
                lCorner.Parent = label

                local lStroke = Instance.new("UIStroke")
                lStroke.Color = Color3.fromRGB(100, 255, 100)
                lStroke.Thickness = 1
                lStroke.Parent = label

                local lText = Instance.new("TextLabel")
                lText.Name = "Text"
                lText.Size = UDim2.new(1, -10, 1, 0)
                lText.Position = UDim2.new(0, 5, 0, 0)
                lText.BackgroundTransparency = 1
                lText.TextColor3 = Color3.fromRGB(150, 255, 150)
                lText.Font = Enum.Font.GothamBold
                lText.TextSize = 11
                lText.TextXAlignment = Enum.TextXAlignment.Left
                lText.Parent = label

                boostLabels[boostType] = label
            end

            local displayName = boostDisplayNames[boostType] or boostType
            local mins = math.floor(remaining / 60)
            local secs = remaining % 60
            local timeText = string.format("%d:%02d", mins, secs)
            local textLabel = boostLabels[boostType]:FindFirstChild("Text")
            if textLabel then
                textLabel.Text = displayName .. " - " .. timeText
            end
        end
    end
end

-- ═══════════════════════════════════════
-- EVENT CONNECTIONS
-- ═══════════════════════════════════════

-- Create a BindableEvent for internal notification forwarding
local notifBindable = Instance.new("BindableEvent")
notifBindable.Name = "NotificationEvent"
notifBindable.Parent = screenGui

notifBindable.Event:Connect(function(message, notifType)
    showNotification(message, notifType)
end)

-- Listen for network notifications
Network.OnClientEvent("ShowNotification", function(message: string, notifType: string)
    showNotification(message, notifType or "Info")
end)

-- Update currency displays
Network.OnClientEvent("CurrencyUpdated", function(currency: string, amount: number)
    if currency == "Coins" then
        coinsLabel.Text = NumberFormat.Abbreviate(amount)
        -- Flash effect
        TweenService:Create(coinsLabel, TweenInfo.new(0.1), {
            TextSize = 24
        }):Play()
        task.delay(0.1, function()
            TweenService:Create(coinsLabel, TweenInfo.new(0.2), {
                TextSize = 20
            }):Play()
        end)
    elseif currency == "Gems" then
        gemsLabel.Text = NumberFormat.Abbreviate(amount)
        TweenService:Create(gemsLabel, TweenInfo.new(0.1), {
            TextSize = 24
        }):Play()
        task.delay(0.1, function()
            TweenService:Create(gemsLabel, TweenInfo.new(0.2), {
                TextSize = 20
            }):Play()
        end)
    end
end)

-- Update rebirth display
Network.OnClientEvent("RebirthCompleted", function(data)
    rebirthLabel.Text = "⭐ Rebirth " .. (data.Rebirths or 0) .. " | " .. (data.Multiplier or 1) .. "x"
end)

-- Boost timer events
Network.OnClientEvent("BoostActivated", function(boostType, expiry)
    activeBoosts[boostType] = expiry
    updateBoostTimers()
end)

Network.OnClientEvent("BoostExpired", function(boostType)
    activeBoosts[boostType] = nil
    if boostLabels[boostType] then
        boostLabels[boostType]:Destroy()
        boostLabels[boostType] = nil
    end
end)

-- Boost timer update loop
task.spawn(function()
    while true do
        task.wait(1)
        updateBoostTimers()
    end
end)

-- Initial data load
Network.OnClientEvent("PlayerDataLoaded", function(data)
    coinsLabel.Text = NumberFormat.Abbreviate(data.Coins or 0)
    gemsLabel.Text = NumberFormat.Abbreviate(data.Gems or 0)
    rebirthLabel.Text = "⭐ Rebirth " .. (data.Rebirths or 0) .. " | " .. (data.RebirthMultiplier or 1) .. "x"

    -- Hydrate active boosts
    if data.ActiveBoosts then
        for boostType, expiry in pairs(data.ActiveBoosts) do
            if expiry > os.time() then
                activeBoosts[boostType] = expiry
            end
        end
        updateBoostTimers()
    end
end)

print("[GUI] MainHUD loaded")

-- ═══════════════════════════════════════
-- SCROLLING ANNOUNCEMENT TICKER (top of screen)
-- ═══════════════════════════════════════

local tickerFrame = Instance.new("Frame")
tickerFrame.Name = "Ticker"
tickerFrame.Size = UDim2.new(1, 0, 0, 22)
tickerFrame.Position = UDim2.new(0, 0, 0, 0)
tickerFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
tickerFrame.BackgroundTransparency = 0.3
tickerFrame.BorderSizePixel = 0
tickerFrame.ClipsDescendants = true
tickerFrame.Parent = screenGui

local tickerQueue = {}
local tickerRunning = false

local function addTickerMessage(msg: string, color: Color3?)
    table.insert(tickerQueue, { Text = msg, Color = color or Color3.fromRGB(255, 220, 80) })
    if not tickerRunning then
        tickerRunning = true
        task.spawn(function()
            while #tickerQueue > 0 do
                local item = table.remove(tickerQueue, 1)
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(0, 600, 1, 0)
                label.Position = UDim2.new(1, 0, 0, 0)
                label.BackgroundTransparency = 1
                label.Text = item.Text
                label.TextColor3 = item.Color
                label.Font = Enum.Font.GothamBold
                label.TextSize = 13
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = tickerFrame

                -- Scroll from right to left
                local tween = TweenService:Create(label, TweenInfo.new(8, Enum.EasingStyle.Linear), {
                    Position = UDim2.new(-1, -600, 0, 0)
                })
                tween:Play()
                task.delay(3, function()
                    -- Allow next message after 3 seconds
                end)
                tween.Completed:Wait()
                label:Destroy()
            end
            tickerRunning = false
        end)
    end
end

-- Pipe hatch announcements to ticker
Network.OnClientEvent("ShowNotification", function(message: string, notifType: string)
    if notifType == "Hatch" then
        addTickerMessage(message, Color3.fromRGB(255, 180, 50))
    end
end)

-- ═══════════════════════════════════════
-- MILESTONE POPUP SYSTEM
-- ═══════════════════════════════════════

local lastMilestones = {}

local function checkMilestones(data)
    local coins = data.Coins or 0
    local eggs = data.TotalEggsHatched or 0
    local pets = data.TotalPetsCollected or 0

    local milestones = {
        { Key = "coins_1000", Check = coins >= 1000, Text = "MILESTONE: 1,000 Coins earned!" },
        { Key = "coins_10000", Check = coins >= 10000, Text = "MILESTONE: 10,000 Coins earned!" },
        { Key = "coins_100000", Check = coins >= 100000, Text = "MILESTONE: 100K Coins! You're getting rich!" },
        { Key = "coins_1000000", Check = coins >= 1000000, Text = "MILESTONE: 1 MILLION Coins!" },
        { Key = "eggs_10", Check = eggs >= 10, Text = "MILESTONE: 10 Eggs Hatched!" },
        { Key = "eggs_50", Check = eggs >= 50, Text = "MILESTONE: 50 Eggs Hatched! Egg master!" },
        { Key = "eggs_100", Check = eggs >= 100, Text = "MILESTONE: 100 Eggs Hatched!" },
        { Key = "pets_10", Check = pets >= 10, Text = "MILESTONE: 10 Pets Collected!" },
        { Key = "pets_25", Check = pets >= 25, Text = "MILESTONE: 25 Pets! Growing collection!" },
    }

    for _, m in ipairs(milestones) do
        if m.Check and not lastMilestones[m.Key] then
            lastMilestones[m.Key] = true
            showNotification(m.Text, "Success")
            addTickerMessage(m.Text, Color3.fromRGB(100, 255, 100))
        end
    end
end

-- Check milestones when data updates
Network.OnClientEvent("DataUpdated", function(field, value)
    -- We'll check on currency updates as a proxy
end)

Network.OnClientEvent("CurrencyUpdated", function(currency: string, amount: number)
    -- Trigger milestone check with approximate data
    if currency == "Coins" then
        checkMilestones({ Coins = amount, TotalEggsHatched = 0, TotalPetsCollected = 0 })
    end
end)

-- Obstacle hit: golden invincibility highlight for 3 seconds
Network.OnClientEvent("ObstacleHit", function()
    local character = player.Character
    if not character then return end
    -- Remove any existing highlight first
    local existing = character:FindFirstChild("InvincibilityHighlight")
    if existing then existing:Destroy() end

    local highlight = Instance.new("Highlight")
    highlight.Name = "InvincibilityHighlight"
    highlight.FillColor = Color3.fromRGB(255, 220, 50)
    highlight.OutlineColor = Color3.fromRGB(255, 180, 0)
    highlight.FillTransparency = 0.5
    highlight.Parent = character
    task.delay(3, function()
        if highlight.Parent then
            highlight:Destroy()
        end
    end)
end)

-- Secret token counter display
local secretFrame = Instance.new("Frame")
secretFrame.Name = "SecretCounter"
secretFrame.Size = UDim2.new(0, 140, 0, 22)
secretFrame.Position = UDim2.new(0.5, -70, 0, 95)
secretFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
secretFrame.BackgroundTransparency = 0.3
secretFrame.Parent = screenGui

local secretCorner = Instance.new("UICorner")
secretCorner.CornerRadius = UDim.new(0, 8)
secretCorner.Parent = secretFrame

local secretStroke = Instance.new("UIStroke")
secretStroke.Color = Color3.fromRGB(255, 200, 50)
secretStroke.Thickness = 1
secretStroke.Parent = secretFrame

local secretLabel = Instance.new("TextLabel")
secretLabel.Size = UDim2.new(1, 0, 1, 0)
secretLabel.BackgroundTransparency = 1
secretLabel.Text = "Secrets: 0/24"
secretLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
secretLabel.Font = Enum.Font.GothamBold
secretLabel.TextSize = 13
secretLabel.Parent = secretFrame

Network.OnClientEvent("SecretTokenCollected", function(_zoneId, _tokenIndex, count)
    secretLabel.Text = "Secrets: " .. tostring(count) .. "/24"
end)

Network.OnClientEvent("SecretTokenCount", function(count)
    secretLabel.Text = "Secrets: " .. tostring(count) .. "/24"
end)
