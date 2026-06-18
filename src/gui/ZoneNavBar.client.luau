--[[
    ZoneNavBar.client.luau
    Persistent bottom navigation bar showing all unlocked zones.
    Click any zone button to teleport instantly — no menu required.
    Replaces "no way to go back" UX problem.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

-- ═══════════════════════════════════════
-- SCREEN GUI (always on top)
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZoneNavBar"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5   -- below menus but above game UI
screenGui.Enabled = true
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ── Backdrop bar ────────────────────────────────────────────────────
local bar = Instance.new("Frame")
bar.Name = "NavBar"
bar.Size = UDim2.new(1, 0, 0, 56)
bar.Position = UDim2.new(0, 0, 1, -56)
bar.BackgroundColor3 = Color3.fromRGB(10, 10, 22)
bar.BackgroundTransparency = 0.18
bar.BorderSizePixel = 0
bar.Parent = screenGui
do
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(80, 60, 160)
    s.Thickness = 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = bar
end

-- Layout for the buttons
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = bar

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = bar

-- Zone label floater (shows above nav bar when a zone is hovered)
local hoverLabel = Instance.new("Frame")
hoverLabel.Name = "HoverLabel"
hoverLabel.Size = UDim2.new(0, 180, 0, 30)
hoverLabel.AnchorPoint = Vector2.new(0.5, 1)
hoverLabel.Position = UDim2.new(0.5, 0, 1, -60)
hoverLabel.BackgroundColor3 = Color3.fromRGB(14, 14, 30)
hoverLabel.BackgroundTransparency = 0.15
hoverLabel.BorderSizePixel = 0
hoverLabel.ZIndex = 20
hoverLabel.Visible = false
hoverLabel.Parent = screenGui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = hoverLabel
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(160, 120, 255); s.Thickness = 1; s.Parent = hoverLabel
end

local hoverText = Instance.new("TextLabel")
hoverText.Size = UDim2.new(1, 0, 1, 0)
hoverText.BackgroundTransparency = 1
hoverText.Text = ""
hoverText.TextColor3 = Color3.new(1, 1, 1)
hoverText.Font = Enum.Font.GothamBold
hoverText.TextSize = 13
hoverText.Parent = hoverLabel

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════
local unlockedZones = { "starter_meadow" }
local currentZoneId = "starter_meadow"
local zoneButtons = {} -- [zoneId] = button frame

-- ═══════════════════════════════════════
-- BUILD BAR
-- ═══════════════════════════════════════

local function makeZoneButton(zone, isUnlocked)
    -- Remove existing if rebuild
    local existing = zoneButtons[zone.Id]
    if existing then existing:Destroy() end

    local btn = Instance.new("TextButton")
    btn.Name = zone.Id
    btn.Size = UDim2.new(0, 0, 0, 42)
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.BackgroundColor3 = isUnlocked
        and (zone.Id == currentZoneId and Color3.fromRGB(100, 60, 220) or Color3.fromRGB(28, 28, 48))
        or Color3.fromRGB(18, 18, 28)
    btn.BackgroundTransparency = isUnlocked and 0 or 0.3
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.LayoutOrder = zone.Order
    btn.Parent = bar
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = btn
        local s = Instance.new("UIStroke")
        s.Color = isUnlocked
            and (zone.Id == currentZoneId and Color3.fromRGB(180, 100, 255) or zone.Color)
            or Color3.fromRGB(50, 50, 70)
        s.Thickness = zone.Id == currentZoneId and 2 or 1
        s.Transparency = isUnlocked and 0 or 0.5
        s.Parent = btn
    end

    -- Inner layout
    local innerPad = Instance.new("UIPadding")
    innerPad.PaddingLeft = UDim.new(0, 10)
    innerPad.PaddingRight = UDim.new(0, 10)
    innerPad.Parent = btn

    -- Color dot
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, 10, 0.5, -5)
    dot.BackgroundColor3 = isUnlocked and zone.Color or Color3.fromRGB(50, 50, 60)
    dot.BorderSizePixel = 0
    dot.Parent = btn
    do local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot end

    -- Zone name
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 0, 1, 0)
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Position = UDim2.new(0, 24, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = isUnlocked and zone.Name or ("🔒 " .. zone.Name)
    label.TextColor3 = isUnlocked
        and (zone.Id == currentZoneId and Color3.fromRGB(220, 180, 255) or Color3.new(1, 1, 1))
        or Color3.fromRGB(70, 70, 90)
    label.Font = zone.Id == currentZoneId and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    -- Hover interactions
    btn.MouseEnter:Connect(function()
        if not isUnlocked then
            hoverText.Text = "🔒 Unlock: " .. zone.Name
            hoverText.TextColor3 = Color3.fromRGB(200, 150, 80)
        else
            hoverText.Text = "✈ " .. zone.Name .. "  (💰 " .. tostring(zone.CoinMultiplier) .. "x)"
            hoverText.TextColor3 = Color3.new(1, 1, 1)
        end
        -- Center tooltip above button
        local btnAbsPos = btn.AbsolutePosition
        local btnAbsSize = btn.AbsoluteSize
        hoverLabel.Position = UDim2.new(0, btnAbsPos.X + btnAbsSize.X / 2, 1, -60)
        hoverLabel.Visible = true
        if zone.Id ~= currentZoneId then
            TweenService:Create(btn, TweenInfo.new(0.12), {
                BackgroundColor3 = Color3.fromRGB(42, 42, 70),
            }):Play()
        end
    end)

    btn.MouseLeave:Connect(function()
        hoverLabel.Visible = false
        if zone.Id ~= currentZoneId then
            TweenService:Create(btn, TweenInfo.new(0.12), {
                BackgroundColor3 = isUnlocked and Color3.fromRGB(28, 28, 48) or Color3.fromRGB(18, 18, 28),
            }):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if not isUnlocked then
            Network.FireServer("UnlockZone", zone.Id)
        else
            Network.FireServer("TeleportToZone", zone.Id)
            currentZoneId = zone.Id
            rebuildBar()
        end
    end)

    zoneButtons[zone.Id] = btn
    return btn
end

function rebuildBar()
    -- Clear existing buttons
    for _, child in ipairs(bar:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    zoneButtons = {}

    for _, zone in ipairs(ZoneConfig.Zones) do
        local isUnlocked = false
        for _, id in ipairs(unlockedZones) do
            if id == zone.Id then isUnlocked = true break end
        end
        makeZoneButton(zone, isUnlocked)
    end
end

-- ═══════════════════════════════════════
-- NETWORK LISTENERS
-- ═══════════════════════════════════════

Network.OnClientEvent("PlayerDataLoaded", function(data)
    unlockedZones = data.UnlockedZones or { "starter_meadow" }
    -- Set current zone to highest unlocked
    if data.HighestZone then
        local zone = ZoneConfig.GetZoneByOrder(data.HighestZone)
        if zone then currentZoneId = zone.Id end
    end
    rebuildBar()
end)

Network.OnClientEvent("ZoneUnlocked", function(zoneId)
    local found = false
    for _, id in ipairs(unlockedZones) do
        if id == zoneId then found = true break end
    end
    if not found then table.insert(unlockedZones, zoneId) end
    rebuildBar()
end)

Network.OnClientEvent("ZoneTeleported", function(zoneId)
    currentZoneId = zoneId
    rebuildBar()
end)

-- ═══════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════
rebuildBar()

print("[GUI] ZoneNavBar loaded")
