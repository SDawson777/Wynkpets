--[[
    BoostHUD.client.luau
    Persistent overlay showing active boost timers.
    Floats in the top-right corner of the screen.
    Tapping/clicking a boost icon opens the Boosts tab of the Shop.
    Responds to BoostsUpdated, BoostActivated, BoostExpired server events.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

-- ── GUI Construction ──────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BoostHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 8  -- below shop (10) but above world
screenGui.Parent = playerGui

-- Container anchored to top-right
local hudFrame = Instance.new("Frame")
hudFrame.Name = "HUDFrame"
hudFrame.Size = UDim2.new(0, 150, 0, 0)                      -- height driven by AutomaticSize
hudFrame.Position = UDim2.new(1, -158, 0, 80)
hudFrame.BackgroundTransparency = 1
hudFrame.AutomaticSize = Enum.AutomaticSize.Y
hudFrame.Parent = screenGui

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Parent = hudFrame

-- ── State ─────────────────────────────────────────────────────────────────────

local activeBoosts = {}   -- [boostType] = expiryTimestamp
local boostRows   = {}    -- [boostType] = Frame row

-- Boost meta (mirrors BoostService BOOST_META for display)
local BOOST_META = {
    Coins      = { label = "💰 Coins",      color = Color3.fromRGB(255, 215, 0)   },
    Luck       = { label = "🍀 Luck",        color = Color3.fromRGB(100, 255, 80)  },
    XP         = { label = "⭐ XP",          color = Color3.fromRGB(100, 149, 237) },
    HatchSpeed = { label = "🥚 Hatch",       color = Color3.fromRGB(255, 165, 0)   },
}

-- ── Row builder ───────────────────────────────────────────────────────────────

local function createRow(boostType: string)
    local meta = BOOST_META[boostType] or { label = boostType, color = Color3.fromRGB(180, 180, 200) }

    local row = Instance.new("Frame")
    row.Name = boostType
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
    row.BackgroundTransparency = 0.1
    row.BorderSizePixel = 0
    row.Parent = hudFrame

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 7)
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = meta.color
    rowStroke.Thickness = 1.5
    rowStroke.Parent = row

    local icon = Instance.new("TextLabel")
    icon.Name = "Label"
    icon.Size = UDim2.new(0.62, 0, 1, 0)
    icon.Position = UDim2.new(0, 5, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = meta.label
    icon.TextColor3 = meta.color
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 10
    icon.TextXAlignment = Enum.TextXAlignment.Left
    icon.Parent = row

    local timer = Instance.new("TextLabel")
    timer.Name = "Timer"
    timer.Size = UDim2.new(0.36, 0, 1, 0)
    timer.Position = UDim2.new(0.62, 0, 0, 0)
    timer.BackgroundTransparency = 1
    timer.Text = "--:--"
    timer.TextColor3 = Color3.fromRGB(200, 200, 200)
    timer.Font = Enum.Font.GothamBold
    timer.TextSize = 10
    timer.TextXAlignment = Enum.TextXAlignment.Right
    timer.Parent = row

    -- Click to open boost shop tab
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = row
    button.MouseButton1Click:Connect(function()
        -- Signal ShopGui to open on Boosts tab via a BindableEvent / Network shim
        -- Since we can't directly call ShopGui functions, fire a local AnalyticsEvent
        -- and let ShopGui listen (or the main HUD button can open it)
        Network.FireServer("AnalyticsEvent", "BoostHUDClicked", { BoostType = boostType })
        -- Try to find and invoke the ShopGui open function
        local shopGui = playerGui:FindFirstChild("ShopGui")
        if shopGui then
            shopGui.Enabled = true
        end
    end)

    return row
end

-- ── Display logic ─────────────────────────────────────────────────────────────

local function formatTime(seconds: number): string
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end

local function updateRowTimer(boostType: string)
    local row = boostRows[boostType]
    if not row then return end

    local expiry = activeBoosts[boostType]
    if not expiry then return end

    local remaining = math.max(0, expiry - os.time())
    local timerLabel = row:FindFirstChild("Timer")
    if timerLabel then
        timerLabel.Text = formatTime(remaining)

        -- Pulse red when < 5 minutes
        if remaining < 300 then
            timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        else
            timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
end

local function rebuildHUD()
    local now = os.time()

    -- Remove expired rows
    for boostType, row in pairs(boostRows) do
        if not activeBoosts[boostType] or activeBoosts[boostType] <= now then
            TweenService:Create(row, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
            task.delay(0.25, function()
                if row and row.Parent then row:Destroy() end
            end)
            boostRows[boostType] = nil
        end
    end

    -- Add new rows for active boosts
    for boostType, expiry in pairs(activeBoosts) do
        if expiry > now and not boostRows[boostType] then
            local row = createRow(boostType)
            boostRows[boostType] = row
            -- Pop-in animation
            row.BackgroundTransparency = 1
            TweenService:Create(row, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
                BackgroundTransparency = 0.1
            }):Play()
        end
    end
end

-- ── Tick ─────────────────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        task.wait(1)
        local now = os.time()
        for boostType, expiry in pairs(activeBoosts) do
            if expiry <= now then
                activeBoosts[boostType] = nil
                if boostRows[boostType] then
                    local row = boostRows[boostType]
                    boostRows[boostType] = nil
                    TweenService:Create(row, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
                    task.delay(0.25, function()
                        if row and row.Parent then row:Destroy() end
                    end)
                end
            else
                updateRowTimer(boostType)
            end
        end
    end
end)

-- ── Network listeners ────────────────────────────────────────────────────────

Network.OnClientEvent("BoostsUpdated", function(snapshot)
    activeBoosts = snapshot or {}
    rebuildHUD()
end)

Network.OnClientEvent("BoostActivated", function(boostType: string, expiry: number)
    activeBoosts[boostType] = expiry
    rebuildHUD()
end)

Network.OnClientEvent("BoostExpired", function(boostType: string)
    activeBoosts[boostType] = nil
    if boostRows[boostType] then
        local row = boostRows[boostType]
        boostRows[boostType] = nil
        TweenService:Create(row, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        task.delay(0.25, function()
            if row and row.Parent then row:Destroy() end
        end)
    end
end)

-- Refill prompt: flash the whole HUD
Network.OnClientEvent("BoostRefillPrompt", function(boostType: string, expiry: number)
    local row = boostRows[boostType]
    if not row then return end

    -- Flash the stroke red 3 times
    local stroke = row:FindFirstChildWhichIsA("UIStroke")
    if stroke then
        for _ = 1, 3 do
            TweenService:Create(stroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 50, 50) }):Play()
            task.wait(0.25)
            local meta = BOOST_META[boostType]
            TweenService:Create(stroke, TweenInfo.new(0.2), {
                Color = meta and meta.color or Color3.fromRGB(180, 180, 200)
            }):Play()
            task.wait(0.25)
        end
    end
end)

print("[GUI] BoostHUD loaded")
