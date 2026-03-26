--[[
    ShopGui.client.luau
    Premium shop UI with gamepasses and dev products.
    High-conversion design with bundle presentation.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local GamepassConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GamepassConfig"))
local DevProductConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DevProductConfig"))

-- ═══════════════════════════════════════
-- SHOP SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 10
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Background overlay
local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.4
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

-- Main shop frame
local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Size = UDim2.new(0, 700, 0, 480)
shopFrame.Position = UDim2.new(0.5, -350, 0.5, -240)
shopFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
shopFrame.BorderSizePixel = 0
shopFrame.Parent = screenGui

local sfCorner = Instance.new("UICorner")
sfCorner.CornerRadius = UDim.new(0, 16)
sfCorner.Parent = shopFrame

local sfStroke = Instance.new("UIStroke")
sfStroke.Color = Color3.fromRGB(100, 200, 100)
sfStroke.Thickness = 2
sfStroke.Parent = shopFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = shopFrame

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 16)
tbCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🛒 Premium Shop"
titleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 24
titleLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 10)
closeBtnCorner.Parent = closeBtn

-- Tab buttons
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, -20, 0, 36)
tabFrame.Position = UDim2.new(0, 10, 0, 55)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = shopFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabFrame

local tabs = { "Gamepasses", "Boosts", "Packs" }
local tabButtons = {}
local activeTab = "Gamepasses"

for _, tabName in ipairs(tabs) do
    local tb = Instance.new("TextButton")
    tb.Name = tabName
    tb.Size = UDim2.new(0, 120, 0, 36)
    tb.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    tb.Text = tabName
    tb.TextColor3 = Color3.fromRGB(180, 180, 180)
    tb.Font = Enum.Font.GothamBold
    tb.TextSize = 14
    tb.AutoButtonColor = true
    tb.Parent = tabFrame

    local tbcCorner = Instance.new("UICorner")
    tbcCorner.CornerRadius = UDim.new(0, 8)
    tbcCorner.Parent = tb

    tabButtons[tabName] = tb
end

-- Content area (scrolling)
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -20, 1, -110)
contentFrame.Position = UDim2.new(0, 10, 0, 100)
contentFrame.BackgroundTransparency = 1
contentFrame.ScrollBarThickness = 4
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.Parent = shopFrame

local contentLayout = Instance.new("UIGridLayout")
contentLayout.CellSize = UDim2.new(0, 210, 0, 180)
contentLayout.CellPadding = UDim2.new(0, 10, 0, 10)
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.Parent = contentFrame

-- Create a shop item card
local ownedGamepasses = {}

local function createShopCard(data, purchaseType: string)
    local card = Instance.new("Frame")
    card.Name = data.Id
    card.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    card.BorderSizePixel = 0

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 12)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(80, 80, 120)
    cardStroke.Thickness = 1.5
    cardStroke.Parent = card

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -10, 0, 30)
    nameLabel.Position = UDim2.new(0, 5, 0, 8)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = data.Name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 15
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -16, 0, 60)
    descLabel.Position = UDim2.new(0, 8, 0, 40)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = data.Description or ""
    descLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 11
    descLabel.TextWrapped = true
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.Parent = card

    -- Purchase button
    local buyBtn = Instance.new("TextButton")
    buyBtn.Name = "BuyButton"
    buyBtn.Size = UDim2.new(0.8, 0, 0, 36)
    buyBtn.Position = UDim2.new(0.1, 0, 1, -46)
    buyBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    buyBtn.Font = Enum.Font.GothamBold
    buyBtn.TextSize = 14
    buyBtn.TextColor3 = Color3.new(1, 1, 1)
    buyBtn.AutoButtonColor = true
    buyBtn.Parent = card

    local buyCorner = Instance.new("UICorner")
    buyCorner.CornerRadius = UDim.new(0, 8)
    buyCorner.Parent = buyBtn

    if purchaseType == "gamepass" then
        if ownedGamepasses[data.Id] then
            buyBtn.Text = "✅ Owned"
            buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
            buyBtn.AutoButtonColor = false
        else
            buyBtn.Text = "R$ " .. (data.Price or "?")
            buyBtn.MouseButton1Click:Connect(function()
                Network.FireServer("PurchaseGamepass", data.Id)
            end)
        end
    else
        buyBtn.Text = "R$ " .. (data.Price or "?")
        buyBtn.MouseButton1Click:Connect(function()
            Network.FireServer("PurchaseDevProduct", data.Id)
        end)
    end

    return card
end

-- Populate content based on active tab
local function refreshContent()
    -- Clear existing
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- Update tab button styles
    for tabName, btn in pairs(tabButtons) do
        if tabName == activeTab then
            btn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
            btn.TextColor3 = Color3.new(1, 1, 1)
        else
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            btn.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end

    if activeTab == "Gamepasses" then
        for _, gp in ipairs(GamepassConfig.Gamepasses) do
            local card = createShopCard(gp, "gamepass")
            card.Parent = contentFrame
        end
    elseif activeTab == "Boosts" then
        for _, product in ipairs(DevProductConfig.Products) do
            if product.Category == "Boost" then
                local card = createShopCard(product, "devproduct")
                card.Parent = contentFrame
            end
        end
    elseif activeTab == "Packs" then
        for _, product in ipairs(DevProductConfig.Products) do
            if product.Category == "Pack" then
                local card = createShopCard(product, "devproduct")
                card.Parent = contentFrame
            end
        end
    end
end

-- Tab click handlers
for tabName, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        activeTab = tabName
        refreshContent()
    end)
end

-- ═══════════════════════════════════════
-- OPEN/CLOSE LOGIC
-- ═══════════════════════════════════════

local function openShop()
    refreshContent()
    screenGui.Enabled = true
    shopFrame.Size = UDim2.new(0, 0, 0, 0)
    shopFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(shopFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 700, 0, 480),
        Position = UDim2.new(0.5, -350, 0.5, -240),
    }):Play()
end

local function closeShop()
    local tween = TweenService:Create(shopFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    })
    tween:Play()
    tween.Completed:Wait()
    screenGui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(closeShop)
overlay.MouseButton1Click:Connect(closeShop)

-- Connect to main HUD shop button
task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if mainHud then
        local sideButtons = mainHud:WaitForChild("SideButtons", 10)
        if sideButtons then
            local shopButton = sideButtons:WaitForChild("ShopButton", 10)
            if shopButton then
                shopButton.MouseButton1Click:Connect(openShop)
            end
        end
    end
end)

-- Update owned gamepasses
Network.OnClientEvent("GamepassOwned", function(gamepassId: string)
    ownedGamepasses[gamepassId] = true
    if screenGui.Enabled and activeTab == "Gamepasses" then
        refreshContent()
    end
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    ownedGamepasses = data.Gamepasses or {}
end)

print("[GUI] ShopGui loaded")
