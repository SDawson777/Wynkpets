-- UIController.luau
-- Manages the main HUD: coins, gems, ore backpack, active boosts, notifications.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData   = require(script.Parent.ClientData)
local FormatNumber = require(ReplicatedStorage.Shared.Modules.FormatNumber)

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

local UIController = {}

-- ─── Build HUD ────────────────────────────────────────────────────────────────

local function buildHUD()
    local screenGui       = Instance.new("ScreenGui")
    screenGui.Name        = "HUD"
    screenGui.ResetOnSpawn= false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent      = PlayerGui

    -- ── Top bar (coins + gems) ──────────────────────────────────────────────

    local topBar = Instance.new("Frame")
    topBar.Name            = "TopBar"
    topBar.Size            = UDim2.new(0, 320, 0, 50)
    topBar.Position        = UDim2.new(0.5, -160, 0, 10)
    topBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    topBar.BackgroundTransparency = 0.3
    topBar.BorderSizePixel = 0
    topBar.Parent          = screenGui
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

    local coinsLabel = Instance.new("TextLabel")
    coinsLabel.Name            = "CoinsLabel"
    coinsLabel.Size            = UDim2.new(0.5, 0, 1, 0)
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.TextColor3      = Color3.fromRGB(255, 215, 0)
    coinsLabel.TextScaled      = true
    coinsLabel.Font            = Enum.Font.GothamBold
    coinsLabel.Text            = "🪙 0"
    coinsLabel.Parent          = topBar

    local gemsLabel = Instance.new("TextLabel")
    gemsLabel.Name             = "GemsLabel"
    gemsLabel.Size             = UDim2.new(0.5, 0, 1, 0)
    gemsLabel.Position         = UDim2.new(0.5, 0, 0, 0)
    gemsLabel.BackgroundTransparency = 1
    gemsLabel.TextColor3       = Color3.fromRGB(130, 220, 255)
    gemsLabel.TextScaled       = true
    gemsLabel.Font             = Enum.Font.GothamBold
    gemsLabel.Text             = "💎 0"
    gemsLabel.Parent           = topBar

    -- ── Sell button ────────────────────────────────────────────────────────

    local sellBtn = Instance.new("TextButton")
    sellBtn.Name             = "SellButton"
    sellBtn.Size             = UDim2.new(0, 140, 0, 50)
    sellBtn.Position         = UDim2.new(0, 10, 1, -60)
    sellBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    sellBtn.BorderSizePixel  = 0
    sellBtn.Text             = "SELL ALL ORES"
    sellBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    sellBtn.TextScaled       = true
    sellBtn.Font             = Enum.Font.GothamBold
    sellBtn.Parent           = screenGui
    Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 8)

    sellBtn.MouseButton1Click:Connect(function()
        ReplicatedStorage.Shared.Remotes.Events.SellOres:FireServer()
    end)

    -- ── Notifications ─────────────────────────────────────────────────────

    local notifFrame = Instance.new("Frame")
    notifFrame.Name                   = "Notifications"
    notifFrame.Size                   = UDim2.new(0, 280, 0, 200)
    notifFrame.Position               = UDim2.new(1, -290, 0.5, -100)
    notifFrame.BackgroundTransparency = 1
    notifFrame.Parent                 = screenGui
    local notifLayout = Instance.new("UIListLayout", notifFrame)
    notifLayout.SortOrder      = Enum.SortOrder.LayoutOrder
    notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notifLayout.Padding        = UDim.new(0, 4)

    -- ── Active boosts label ──────────────────────────────────────────────

    local boostsLabel = Instance.new("TextLabel")
    boostsLabel.Name             = "BoostsLabel"
    boostsLabel.Size             = UDim2.new(0, 200, 0, 24)
    boostsLabel.Position         = UDim2.new(0, 10, 0, 70)
    boostsLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    boostsLabel.BackgroundTransparency = 0.4
    boostsLabel.BorderSizePixel  = 0
    boostsLabel.TextColor3       = Color3.fromRGB(200, 255, 200)
    boostsLabel.TextScaled       = true
    boostsLabel.Font             = Enum.Font.Gotham
    boostsLabel.Text             = ""
    boostsLabel.Parent           = screenGui
    Instance.new("UICorner", boostsLabel).CornerRadius = UDim.new(0, 4)

    UIController.gui = {
        coinsLabel  = coinsLabel,
        gemsLabel   = gemsLabel,
        notifFrame  = notifFrame,
        boostsLabel = boostsLabel,
    }
end

-- ─── Update HUD from data ─────────────────────────────────────────────────────

local function updateHUD(data)
    if not UIController.gui then return end
    if not data then return end

    UIController.gui.coinsLabel.Text = "🪙 " .. FormatNumber.format(data.Coins or 0)
    UIController.gui.gemsLabel.Text  = "💎 " .. FormatNumber.format(data.Gems  or 0)

    -- Active boosts
    local now    = os.time()
    local active = {}
    for _, boost in ipairs(data.ActiveBoosts or {}) do
        if boost.expiresAt > now then
            local remaining = boost.expiresAt - now
            local mins      = math.floor(remaining / 60)
            local secs      = remaining % 60
            if (boost.coinMult or 0) > 0 then
                table.insert(active, ("🪙×%.1f (%dm%ds)"):format(1 + boost.coinMult, mins, secs))
            end
            if (boost.luckMult or 0) > 0 then
                table.insert(active, ("🍀×%.1f (%dm%ds)"):format(1 + boost.luckMult, mins, secs))
            end
        end
    end
    UIController.gui.boostsLabel.Text = table.concat(active, "  ")
end

-- ─── Toast notifications ─────────────────────────────────────────────────────

function UIController.showNotification(message: string, color: Color3?)
    local gui = UIController.gui
    if not gui then return end

    local label       = Instance.new("TextLabel")
    label.Size        = UDim2.new(1, 0, 0, 36)
    label.BackgroundColor3 = color or Color3.fromRGB(40, 40, 40)
    label.BackgroundTransparency = 0.2
    label.BorderSizePixel = 0
    label.TextColor3  = Color3.fromRGB(255, 255, 255)
    label.TextScaled  = true
    label.Font        = Enum.Font.Gotham
    label.Text        = message
    label.Parent      = gui.notifFrame
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)

    task.spawn(function()
        task.wait(3)
        for t = 0, 1, 0.05 do
            label.BackgroundTransparency = 0.2 + t * 0.8
            label.TextTransparency       = t
            task.wait(0.05)
        end
        label:Destroy()
    end)
end

-- ─── Wire events ─────────────────────────────────────────────────────────────

local function wireEvents()
    local Events = ReplicatedStorage.Shared.Remotes.Events

    -- Purchase result toasts
    Events:WaitForChild("PurchaseResult", 30).OnClientEvent:Connect(function(success, msg)
        local color = success and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(200, 50, 50)
        UIController.showNotification(msg or (success and "Success!" or "Failed"), color)
    end)

    -- Pet hatch animation
    Events:WaitForChild("PetHatched", 30).OnClientEvent:Connect(function(petInstance)
        local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
        local petDef    = PetConfig.ById[petInstance.petId]
        local name      = petDef and petDef.name or petInstance.petId
        local rarity    = petDef and petDef.rarity or "?"
        UIController.showNotification(
            ("✨ Hatched: %s [%s]"):format(name, rarity),
            Color3.fromRGB(120, 60, 200)
        )
    end)

    -- Quest completed
    Events:WaitForChild("QuestCompleted", 30).OnClientEvent:Connect(function(questId, reward)
        local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
        local q = QuestConfig.ById[questId]
        local name = q and q.name or questId
        UIController.showNotification("🏆 Quest Complete: " .. name, Color3.fromRGB(50, 150, 200))
    end)

    -- Rock broken
    Events:WaitForChild("RockBroken", 30).OnClientEvent:Connect(function(rockId, ore)
        UIController.showNotification("⛏ Got " .. ore, Color3.fromRGB(80, 80, 80))
    end)

    -- Rebirth completed
    Events:WaitForChild("RebirthCompleted", 30).OnClientEvent:Connect(function(rebirths, bonus)
        UIController.showNotification(
            ("🌟 Rebirth #%d! Bonus: +%.1f×"):format(rebirths, bonus),
            Color3.fromRGB(255, 180, 0)
        )
    end)
end

-- ─── Bootstrap ───────────────────────────────────────────────────────────────

buildHUD()

-- Wait for remotes to be ready before wiring events
task.spawn(function()
    ReplicatedStorage.Shared.Remotes:WaitForChild("Events", 30)
    wireEvents()
end)

-- Subscribe to data updates
ClientData.onUpdate(updateHUD)

return UIController
