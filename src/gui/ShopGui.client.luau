--[[
    ShopGui.client.luau
    8-tab premium shop funnel:
      Featured | Limited | Boosts | Passes | Currency | VIP | Rewards | Event
    Mobile-first, high-conversion design with card-based layout.
    Extended with: Nudge popups, BoostRefill section, EventShop live data,
    weekly quest bar, subscription VIP tier, session milestone toasts.
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
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

-- ═══════════════════════════════════════
-- SCREEN GUI
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
shopFrame.Size = UDim2.new(0, 760, 0, 520)
shopFrame.Position = UDim2.new(0.5, -380, 0.5, -260)
shopFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
shopFrame.BorderSizePixel = 0
shopFrame.Parent = screenGui

local sfCorner = Instance.new("UICorner")
sfCorner.CornerRadius = UDim.new(0, 16)
sfCorner.Parent = shopFrame

local sfStroke = Instance.new("UIStroke")
sfStroke.Color = Color3.fromRGB(80, 200, 100)
sfStroke.Thickness = 2
sfStroke.Parent = shopFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 48)
titleBar.BorderSizePixel = 0
titleBar.Parent = shopFrame

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 16)
tbCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SHOP"
titleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 22
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -42, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 10)
closeBtnCorner.Parent = closeBtn

-- ═══════════════════════════════════════
-- TAB SYSTEM (8 tabs, scrollable row)
-- ═══════════════════════════════════════

local tabScroll = Instance.new("ScrollingFrame")
tabScroll.Name = "TabScroll"
tabScroll.Size = UDim2.new(1, -16, 0, 34)
tabScroll.Position = UDim2.new(0, 8, 0, 50)
tabScroll.BackgroundTransparency = 1
tabScroll.ScrollBarThickness = 0
tabScroll.CanvasSize = UDim2.new(0, 0, 0, 34)
tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
tabScroll.ScrollingDirection = Enum.ScrollingDirection.X
tabScroll.Parent = shopFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabScroll

local TAB_DEFS = {
    { Name = "Featured",  Color = Color3.fromRGB(255, 180, 30) },
    { Name = "Limited",   Color = Color3.fromRGB(200, 100, 255) },
    { Name = "Boosts",    Color = Color3.fromRGB(50, 200, 255) },
    { Name = "Passes",    Color = Color3.fromRGB(100, 255, 100) },
    { Name = "Currency",  Color = Color3.fromRGB(255, 215, 0) },
    { Name = "VIP",       Color = Color3.fromRGB(255, 100, 180) },
    { Name = "Rewards",   Color = Color3.fromRGB(100, 200, 255) },
    { Name = "Event",     Color = Color3.fromRGB(255, 120, 50) },
}

local tabButtons = {}
local activeTab = "Featured"

do
    -- Filter TAB_DEFS: hide VIP tab when Subscription is disabled, Event tab when Events is disabled
    local filteredDefs = {}
    for _, def in ipairs(TAB_DEFS) do
        if def.Name == "VIP" and not LaunchConfig.IsFeatureEnabled("Subscription") then
            continue
        end
        if def.Name == "Event" and not LaunchConfig.IsFeatureEnabled("Events") then
            continue
        end
        table.insert(filteredDefs, def)
    end
    TAB_DEFS = filteredDefs
end

for _, def in ipairs(TAB_DEFS) do
    local tb = Instance.new("TextButton")
    tb.Name = def.Name
    tb.Size = UDim2.new(0, 86, 0, 30)
    tb.BackgroundColor3 = Color3.fromRGB(38, 38, 56)
    tb.Text = def.Name
    tb.TextColor3 = Color3.fromRGB(160, 160, 180)
    tb.Font = Enum.Font.GothamBold
    tb.TextSize = 12
    tb.AutoButtonColor = true
    tb.Parent = tabScroll

    local tbcCorner = Instance.new("UICorner")
    tbcCorner.CornerRadius = UDim.new(0, 8)
    tbcCorner.Parent = tb

    tabButtons[def.Name] = { Button = tb, Color = def.Color }
end

-- Content area (scrolling)
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -16, 1, -100)
contentFrame.Position = UDim2.new(0, 8, 0, 92)
contentFrame.BackgroundTransparency = 1
contentFrame.ScrollBarThickness = 4
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.Parent = shopFrame

local contentLayout = Instance.new("UIGridLayout")
contentLayout.CellSize = UDim2.new(0, 220, 0, 195)
contentLayout.CellPadding = UDim2.new(0, 8, 0, 8)
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.Parent = contentFrame

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════

local ownedGamepasses = {}
local limitedShopData = {}
local currentPlayerData = nil
local activeBoosts = {}       -- [boostType] = expiryTimestamp
local eventShopData = nil     -- latest EventShopData payload
local subscriptionStatus = { Tier = "none", Perks = {} }

-- ═══════════════════════════════════════
-- CARD BUILDERS
-- ═══════════════════════════════════════

local function clearContent()
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function normalizeImageAsset(imageId: string?): string
    if not imageId or imageId == "" or imageId == "rbxassetid://0" then
        return "rbxassetid://0"
    end
    local numericId = string.match(imageId, "%d+")
    if not numericId then
        return imageId
    end
    return "rbxassetid://" .. numericId
end

local function createCard(name: string, desc: string, btnText: string, accentColor: Color3, onClick: (() -> ())?, iconImage: string?): Frame
    local card = Instance.new("Frame")
    card.Name = name
    card.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    card.BorderSizePixel = 0

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 12)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = accentColor or Color3.fromRGB(80, 80, 120)
    cardStroke.Thickness = 1.5
    cardStroke.Parent = card

    -- Product icon (if asset provided)
    local contentYOffset = 6
    if iconImage and iconImage ~= "" and iconImage ~= "rbxassetid://0" then
        local iconLabel = Instance.new("ImageLabel")
        iconLabel.Name = "ProductIcon"
        iconLabel.Size = UDim2.new(0, 50, 0, 50)
        iconLabel.Position = UDim2.new(0.5, -25, 0, 6)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Image = normalizeImageAsset(iconImage)
        iconLabel.ScaleType = Enum.ScaleType.Fit
        iconLabel.Parent = card
        contentYOffset = 60
    end

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -10, 0, 22)
    nameLabel.Position = UDim2.new(0, 5, 0, contentYOffset)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = card

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -12, 0, 55)
    descLabel.Position = UDim2.new(0, 6, 0, contentYOffset + 24)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = desc or ""
    descLabel.TextColor3 = Color3.fromRGB(170, 170, 195)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 11
    descLabel.TextWrapped = true
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.Parent = card

    -- Buy button
    local buyBtn = Instance.new("TextButton")
    buyBtn.Name = "BuyButton"
    buyBtn.Size = UDim2.new(0.85, 0, 0, 36)
    buyBtn.Position = UDim2.new(0.075, 0, 1, -46)
    buyBtn.BackgroundColor3 = accentColor or Color3.fromRGB(50, 200, 80)
    buyBtn.Font = Enum.Font.GothamBold
    buyBtn.TextSize = 14
    buyBtn.TextColor3 = Color3.new(1, 1, 1)
    buyBtn.Text = btnText
    buyBtn.AutoButtonColor = true
    buyBtn.Parent = card

    local buyCorner = Instance.new("UICorner")
    buyCorner.CornerRadius = UDim.new(0, 8)
    buyCorner.Parent = buyBtn

    if onClick then
        buyBtn.MouseButton1Click:Connect(onClick)
    end

    return card
end

local function addBannerToCard(card: Frame, text: string, color: Color3)
    local banner = Instance.new("Frame")
    banner.Size = UDim2.new(0, 90, 0, 20)
    banner.Position = UDim2.new(1, -95, 0, -2)
    banner.BackgroundColor3 = color
    banner.Parent = card

    local bannerCorner = Instance.new("UICorner")
    bannerCorner.CornerRadius = UDim.new(0, 6)
    bannerCorner.Parent = banner

    local bannerLabel = Instance.new("TextLabel")
    bannerLabel.Size = UDim2.new(1, 0, 1, 0)
    bannerLabel.BackgroundTransparency = 1
    bannerLabel.Text = text
    bannerLabel.TextColor3 = Color3.new(1, 1, 1)
    bannerLabel.Font = Enum.Font.GothamBlack
    bannerLabel.TextSize = 9
    bannerLabel.Parent = banner
end

-- ═══════════════════════════════════════
-- TAB RENDERERS
-- ═══════════════════════════════════════

local function renderFeatured()
    -- Starter pack (prominent)
    local starterCard = createCard(
        "Starter Pack", "10,000 Coins + 100 Gems + 30-min Coin Boost!\nBest value for new players!",
        "R$ 99", Color3.fromRGB(50, 200, 80),
        function() Network.FireServer("PurchaseDevProduct", "starter_pack") end
    )
    addBannerToCard(starterCard, "BEST VALUE", Color3.fromRGB(255, 180, 30))
    starterCard.Parent = contentFrame

    -- Mega pack
    if LaunchConfig.IsMonetizationEnabled("Bundles") then
        local megaCard = createCard(
            "Mega Pack", "100,000 Coins + 500 Gems + FREE Coin Boost!",
            "R$ 399", Color3.fromRGB(100, 150, 255),
            function() Network.FireServer("PurchaseDevProduct", "mega_pack") end
        )
        addBannerToCard(megaCard, "POPULAR", Color3.fromRGB(100, 150, 255))
        megaCard.Parent = contentFrame

        -- Ultra pack
        local ultraCard = createCard(
            "Ultra Pack", "1,000,000 Coins + 2,000 Gems + ALL Boosts!",
            "R$ 999", Color3.fromRGB(255, 100, 180),
            function() Network.FireServer("PurchaseDevProduct", "ultra_pack") end
        )
        addBannerToCard(ultraCard, "BEST DEAL", Color3.fromRGB(255, 100, 180))
        ultraCard.Parent = contentFrame

        -- Mega boost bundle
        local boostCard = createCard(
            "Mega Boost Bundle", "All 4 boosts for 30 min each!\nCoins + Luck + XP + Hatch Speed",
            "R$ 299", Color3.fromRGB(50, 200, 255),
            function() Network.FireServer("PurchaseDevProduct", "mega_boost_bundle") end
        )
        addBannerToCard(boostCard, "HOT", Color3.fromRGB(255, 80, 50))
        boostCard.Parent = contentFrame
    end

    -- VIP+ subscription promo (subscription-only; hide when already subscribed or Subscription disabled)
    if LaunchConfig.IsFeatureEnabled("Subscription") and subscriptionStatus.Tier ~= "vip" then
        local vipCard = createCard(
            "VIP+ Monthly", "25 daily Gems, +25% Coins, +15% Luck, +2 equip slots, exclusive perks!",
            "R$ 499 / month", Color3.fromRGB(255, 100, 180),
            function() Network.FireServer("PurchaseSubscription", "vip") end
        )
        addBannerToCard(vipCard, "PREMIUM", Color3.fromRGB(255, 100, 180))
        vipCard.Parent = contentFrame
    end
end

local function renderLimited()
    if #limitedShopData == 0 then
        Network.FireServer("RequestLimitedShop")
        local placeholder = Instance.new("TextLabel")
        placeholder.Size = UDim2.new(1, 0, 0, 40)
        placeholder.BackgroundTransparency = 1
        placeholder.Text = "Loading daily items..."
        placeholder.TextColor3 = Color3.fromRGB(150, 150, 170)
        placeholder.Font = Enum.Font.GothamBold
        placeholder.TextSize = 14
        placeholder.Parent = contentFrame
        return
    end

    for _, item in ipairs(limitedShopData) do
        local stockText = item.Stock .. "/" .. item.MaxStock .. " left"
        local btnText = item.Price .. " " .. item.Currency
        if item.Stock <= 0 then
            btnText = "SOLD OUT"
        end

        local card = createCard(
            item.Name,
            item.Description .. "\n" .. stockText,
            btnText,
            item.Stock > 0 and Color3.fromRGB(200, 100, 255) or Color3.fromRGB(80, 80, 100),
            item.Stock > 0 and function()
                Network.FireServer("PurchaseLimitedItem", item.Id)
            end or nil
        )

        if item.Stock <= 1 and item.Stock > 0 then
            addBannerToCard(card, "LAST ONE!", Color3.fromRGB(255, 50, 50))
        end

        card.Parent = contentFrame
    end
end

local function renderBoosts()
    -- Active boosts summary row
    local now = os.time()
    local hasActive = false
    for _, expiry in pairs(activeBoosts) do
        if expiry > now then hasActive = true; break end
    end

    if hasActive then
        local summaryFrame = Instance.new("Frame")
        summaryFrame.Name = "ActiveBoostsSummary"
        summaryFrame.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
        summaryFrame.BorderSizePixel = 0

        local sCorner = Instance.new("UICorner")
        sCorner.CornerRadius = UDim.new(0, 10)
        sCorner.Parent = summaryFrame

        local sStroke = Instance.new("UIStroke")
        sStroke.Color = Color3.fromRGB(50, 200, 100)
        sStroke.Thickness = 1.5
        sStroke.Parent = summaryFrame

        local sTitle = Instance.new("TextLabel")
        sTitle.Size = UDim2.new(1, -10, 0, 22)
        sTitle.Position = UDim2.new(0, 6, 0, 4)
        sTitle.BackgroundTransparency = 1
        sTitle.Text = "⚡ Active Boosts"
        sTitle.TextColor3 = Color3.fromRGB(100, 255, 100)
        sTitle.Font = Enum.Font.GothamBold
        sTitle.TextSize = 13
        sTitle.TextXAlignment = Enum.TextXAlignment.Left
        sTitle.Parent = summaryFrame

        local lines = {}
        for boostType, expiry in pairs(activeBoosts) do
            if expiry > now then
                local remaining = expiry - now
                local min = math.floor(remaining / 60)
                local sec = remaining % 60
                table.insert(lines, boostType .. ": " .. min .. "m " .. sec .. "s left")
            end
        end

        local sBody = Instance.new("TextLabel")
        sBody.Size = UDim2.new(1, -12, 1, -32)
        sBody.Position = UDim2.new(0, 6, 0, 28)
        sBody.BackgroundTransparency = 1
        sBody.Text = table.concat(lines, "\n")
        sBody.TextColor3 = Color3.fromRGB(180, 255, 180)
        sBody.Font = Enum.Font.Gotham
        sBody.TextSize = 11
        sBody.TextWrapped = true
        sBody.TextYAlignment = Enum.TextYAlignment.Top
        sBody.Parent = summaryFrame

        summaryFrame.Parent = contentFrame
    end

    -- Boost products (single + bundles)
    local boosts = DevProductConfig.GetByCategory("Boost")
    for _, product in ipairs(boosts) do
        local card = createCard(
            product.Name, product.Description,
            "R$ " .. product.Price, Color3.fromRGB(50, 200, 255),
            function() Network.FireServer("PurchaseDevProduct", product.Id) end,
            product.Icon
        )
        if product.BoostCount and product.BoostCount > 1 then
            local savings = product.BoostCount * 49 - product.Price
            if savings > 0 then
                addBannerToCard(card, "SAVE " .. savings .. " R$", Color3.fromRGB(50, 200, 80))
            end
        end
        if product.AllBoosts then
            addBannerToCard(card, "ALL-IN-ONE", Color3.fromRGB(255, 180, 30))
        end
        card.Parent = contentFrame
    end

    -- Boost refill packs
    local refills = DevProductConfig.GetByCategory("BoostRefill")
    for _, product in ipairs(refills) do
        local card = createCard(
            product.Name, product.Description,
            "R$ " .. product.Price, Color3.fromRGB(255, 160, 40),
            function() Network.FireServer("PurchaseDevProduct", product.Id) end,
            product.Icon
        )
        addBannerToCard(card, "REFILL", Color3.fromRGB(255, 120, 30))
        card.Parent = contentFrame
    end
end

local function renderPasses()
    -- CEO-specified render order:
    --  1. auto_hatch   (⭐ MOST POPULAR)  — only when AdvancedPasses enabled
    --  2. triple_hatch (💎 BEST VALUE)    — only when AdvancedPasses enabled
    --  3. DoubleCoins
    --  4. DoubleLuck
    --  5. DoubleHatchSpeed
    --  6. extra_equip + any remaining advanced passes

    local advancedEnabled = LaunchConfig.IsMonetizationEnabled("AdvancedPasses")

    -- Build full pass lookup table
    local passById = {}
    for _, gp in ipairs(GamepassConfig.Gamepasses) do
        passById[gp.Id] = gp
    end

    local PASS_ACCENT = {
        auto_hatch       = Color3.fromRGB(255, 190, 0),
        triple_hatch     = Color3.fromRGB(120, 230, 120),
        DoubleCoins      = Color3.fromRGB(255, 215, 0),
        DoubleLuck       = Color3.fromRGB(100, 255, 100),
        DoubleHatchSpeed = Color3.fromRGB(50, 180, 255),
    }
    local PASS_ICON = {
        auto_hatch       = "🔁",
        triple_hatch     = "🥚",
        DoubleCoins      = "💰",
        DoubleLuck       = "🍀",
        DoubleHatchSpeed = "⚡",
        extra_equip      = "🐾",
    }
    local PASS_BANNER = {
        auto_hatch   = { text = "⭐ MOST POPULAR", color = Color3.fromRGB(255, 170, 0) },
        triple_hatch = { text = "💎 BEST VALUE",   color = Color3.fromRGB(80, 210, 80) },
        DoubleCoins  = { text = "FEATURED",        color = Color3.fromRGB(255, 215, 0) },
        DoubleLuck   = { text = "FEATURED",        color = Color3.fromRGB(100, 255, 100) },
        DoubleHatchSpeed = { text = "FEATURED",    color = Color3.fromRGB(50, 180, 255) },
    }

    -- Ordered list: advanced first (if enabled), then core, then everything else
    local orderedIds = {}
    if advancedEnabled then
        table.insert(orderedIds, "auto_hatch")
        table.insert(orderedIds, "triple_hatch")
    end
    table.insert(orderedIds, "DoubleCoins")
    table.insert(orderedIds, "DoubleLuck")
    table.insert(orderedIds, "DoubleHatchSpeed")

    -- Track rendered so we can append remaining advanced passes below
    local rendered = {}
    for _, id in ipairs(orderedIds) do rendered[id] = true end

    -- Render in order
    for _, passId in ipairs(orderedIds) do
        local gp = passById[passId]
        if not gp then continue end

        local owned  = ownedGamepasses[passId]
        local accent = owned and Color3.fromRGB(60, 60, 80) or (PASS_ACCENT[passId] or Color3.fromRGB(255, 215, 0))
        local btnText = owned and "✅ OWNED" or ("R$ " .. gp.Price)
        local icon   = PASS_ICON[passId] or ""

        local card = createCard(
            icon .. " " .. gp.Name, gp.Description,
            btnText, accent,
            not owned and function()
                Network.FireServer("PurchaseGamepass", passId)
            end or nil,
            gp.Icon
        )

        local bannerInfo = PASS_BANNER[passId]
        if not owned and bannerInfo then
            addBannerToCard(card, bannerInfo.text, bannerInfo.color)
        end

        card.Parent = contentFrame
    end

    -- Append any remaining advanced passes not already rendered (e.g. extra_equip)
    if advancedEnabled then
        for _, gp in ipairs(GamepassConfig.Gamepasses) do
            if rendered[gp.Id] then continue end
            local owned   = ownedGamepasses[gp.Id]
            local btnText = owned and "✅ OWNED" or ("R$ " .. gp.Price)
            local icon    = PASS_ICON[gp.Id] or ""
            local accent  = owned and Color3.fromRGB(60, 60, 80) or Color3.fromRGB(100, 200, 255)

            local card = createCard(
                icon .. " " .. gp.Name, gp.Description,
                btnText, accent,
                not owned and function()
                    Network.FireServer("PurchaseGamepass", gp.Id)
                end or nil,
                gp.Icon
            )

            card.Parent = contentFrame
        end
    end
end

local function renderCurrency()
    local gemPacks = DevProductConfig.GetByCategory("Currency")
    for _, product in ipairs(gemPacks) do
        local card = createCard(
            product.Name, product.Description,
            "R$ " .. product.Price, Color3.fromRGB(255, 215, 0),
            function() Network.FireServer("PurchaseDevProduct", product.Id) end,
            product.Icon
        )
        if product.BonusLabel then
            addBannerToCard(card, product.BonusLabel, Color3.fromRGB(50, 200, 80))
        end
        card.Parent = contentFrame
    end
end

local function renderVIP()
    -- Active subscription status card
    local tier = subscriptionStatus.Tier or "none"
    if tier ~= "none" then
        local statusCard = Instance.new("Frame")
        statusCard.Name = "SubStatus"
        statusCard.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
        statusCard.BorderSizePixel = 0

        local ssCorner = Instance.new("UICorner")
        ssCorner.CornerRadius = UDim.new(0, 12)
        ssCorner.Parent = statusCard

        local ssStroke = Instance.new("UIStroke")
        ssStroke.Color = Color3.fromRGB(180, 100, 255)
        ssStroke.Thickness = 2
        ssStroke.Parent = statusCard

        local ssTitle = Instance.new("TextLabel")
        ssTitle.Size = UDim2.new(1, -10, 0, 26)
        ssTitle.Position = UDim2.new(0, 5, 0, 6)
        ssTitle.BackgroundTransparency = 1
        ssTitle.Text = "✅ " .. (subscriptionStatus.TierName or "VIP") .. " Active"
        ssTitle.TextColor3 = Color3.fromRGB(200, 150, 255)
        ssTitle.Font = Enum.Font.GothamBold
        ssTitle.TextSize = 14
        ssTitle.TextXAlignment = Enum.TextXAlignment.Left
        ssTitle.Parent = statusCard

        local perkLines = {}
        local perks = subscriptionStatus.Perks or {}
        if perks.DailyGems and perks.DailyGems > 0 then
            table.insert(perkLines, "💎 " .. perks.DailyGems .. " daily Gems")
        end
        if perks.CoinBonus and perks.CoinBonus > 0 then
            table.insert(perkLines, "💰 +" .. math.floor(perks.CoinBonus * 100) .. "% Coins")
        end
        if perks.LuckBonus and perks.LuckBonus > 0 then
            table.insert(perkLines, "🍀 +" .. math.floor(perks.LuckBonus * 100) .. "% Luck")
        end
        if perks.ExtraSlot and perks.ExtraSlot > 0 then
            table.insert(perkLines, "🐾 +" .. perks.ExtraSlot .. " equip slot(s)")
        end

        local ssBody = Instance.new("TextLabel")
        ssBody.Size = UDim2.new(1, -12, 1, -36)
        ssBody.Position = UDim2.new(0, 6, 0, 34)
        ssBody.BackgroundTransparency = 1
        ssBody.Text = table.concat(perkLines, "\n")
        ssBody.TextColor3 = Color3.fromRGB(180, 180, 200)
        ssBody.Font = Enum.Font.Gotham
        ssBody.TextSize = 11
        ssBody.TextWrapped = true
        ssBody.TextYAlignment = Enum.TextYAlignment.Top
        ssBody.Parent = statusCard

        statusCard.Parent = contentFrame
    end

    -- VIP+ monthly subscription
    if tier ~= "vip" then
        local vipPlusCard = createCard(
            "💜 VIP+ Monthly",
            "25 daily Gems, +25% Coins, +15% Luck, +2 equip slots, exclusive pet!\n30 days.",
            "R$ 499 / month", Color3.fromRGB(180, 100, 255),
            function() Network.FireServer("PurchaseSubscription", "vip") end
        )
        addBannerToCard(vipPlusCard, "BEST VALUE", Color3.fromRGB(180, 100, 255))
        vipPlusCard.Parent = contentFrame
    end

end

local function renderRewards()
    -- Quick info card (no purchase, just info)
    local infoCard = Instance.new("Frame")
    infoCard.Name = "RewardsInfo"
    infoCard.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    infoCard.BorderSizePixel = 0

    local iCorner = Instance.new("UICorner")
    iCorner.CornerRadius = UDim.new(0, 12)
    iCorner.Parent = infoCard

    local iStroke = Instance.new("UIStroke")
    iStroke.Color = Color3.fromRGB(100, 200, 255)
    iStroke.Thickness = 1.5
    iStroke.Parent = infoCard

    local iTitle = Instance.new("TextLabel")
    iTitle.Size = UDim2.new(1, -10, 0, 28)
    iTitle.Position = UDim2.new(0, 5, 0, 6)
    iTitle.BackgroundTransparency = 1
    iTitle.Text = "Daily Login Rewards"
    iTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
    iTitle.Font = Enum.Font.GothamBold
    iTitle.TextSize = 14
    iTitle.TextXAlignment = Enum.TextXAlignment.Left
    iTitle.Parent = infoCard

    local streakText = "Current streak: "
    if currentPlayerData then
        streakText = streakText .. (currentPlayerData.LoginStreak or 0) .. " days"
    else
        streakText = streakText .. "loading..."
    end

    local iText = Instance.new("TextLabel")
    iText.Size = UDim2.new(1, -12, 1, -36)
    iText.Position = UDim2.new(0, 6, 0, 34)
    iText.BackgroundTransparency = 1
    iText.Text = streakText .. "\nLog in every day for escalating rewards!\nDay 7: 100 Gems!"
    iText.TextColor3 = Color3.fromRGB(170, 170, 195)
    iText.Font = Enum.Font.Gotham
    iText.TextSize = 11
    iText.TextWrapped = true
    iText.TextYAlignment = Enum.TextYAlignment.Top
    iText.Parent = infoCard

    infoCard.Parent = contentFrame

end

local function renderEvent()
    if not eventShopData then
        -- Request fresh data
        Network.FireServer("RequestEventShop")

        local placeholder = Instance.new("TextLabel")
        placeholder.Size = UDim2.new(1, 0, 0, 60)
        placeholder.BackgroundTransparency = 1
        placeholder.Text = "Loading event shop..."
        placeholder.TextColor3 = Color3.fromRGB(150, 150, 170)
        placeholder.Font = Enum.Font.GothamBold
        placeholder.TextSize = 14
        placeholder.TextWrapped = true
        placeholder.Parent = contentFrame
        return
    end

    if eventShopData == "none" then
        local placeholder = Instance.new("TextLabel")
        placeholder.Size = UDim2.new(1, 0, 0, 60)
        placeholder.BackgroundTransparency = 1
        placeholder.Text = "No event active right now.\nCheck back soon for limited-time items! 🎉"
        placeholder.TextColor3 = Color3.fromRGB(150, 150, 170)
        placeholder.Font = Enum.Font.GothamBold
        placeholder.TextSize = 14
        placeholder.TextWrapped = true
        placeholder.Parent = contentFrame
        return
    end

    -- Event header
    local headerFrame = Instance.new("Frame")
    headerFrame.Name = "EventHeader"
    headerFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
    headerFrame.BorderSizePixel = 0

    local ehCorner = Instance.new("UICorner")
    ehCorner.CornerRadius = UDim.new(0, 12)
    ehCorner.Parent = headerFrame

    local tc = eventShopData.ThemeColor
    local themeColor3 = tc and Color3.fromRGB(
        math.floor((tc.R or 0) * 255),
        math.floor((tc.G or 0) * 255),
        math.floor((tc.B or 0) * 255)) or Color3.fromRGB(50, 180, 255)

    local ehStroke = Instance.new("UIStroke")
    ehStroke.Color = themeColor3
    ehStroke.Thickness = 2
    ehStroke.Parent = headerFrame

    local ehTitle = Instance.new("TextLabel")
    ehTitle.Size = UDim2.new(1, -10, 0, 26)
    ehTitle.Position = UDim2.new(0, 5, 0, 5)
    ehTitle.BackgroundTransparency = 1
    ehTitle.Text = (eventShopData.Icon or "") .. " " .. (eventShopData.EventName or "Event")
    ehTitle.TextColor3 = themeColor3
    ehTitle.Font = Enum.Font.GothamBold
    ehTitle.TextSize = 16
    ehTitle.TextXAlignment = Enum.TextXAlignment.Left
    ehTitle.Parent = headerFrame

    local coinsLabel = Instance.new("TextLabel")
    coinsLabel.Size = UDim2.new(1, -10, 0, 22)
    coinsLabel.Position = UDim2.new(0, 5, 0, 32)
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.Text = (eventShopData.CurrencyIcon or "🪙") .. " " ..
        (eventShopData.PlayerCoins or 0) .. " " .. (eventShopData.CurrencyName or "Event Coins")
    coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    coinsLabel.Font = Enum.Font.GothamBold
    coinsLabel.TextSize = 13
    coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
    coinsLabel.Parent = headerFrame

    headerFrame.Parent = contentFrame

    -- Shop items
    for _, item in ipairs(eventShopData.Items or {}) do
        local canBuy = item.CanBuy and (eventShopData.PlayerCoins or 0) >= item.Cost
        local btnText = item.Cost .. " " .. (eventShopData.CurrencyName or "Coins")
        if not item.CanBuy then
            btnText = "LIMIT REACHED"
        end

        local card = createCard(
            item.Name,
            item.Description .. "\n(" .. item.Purchased .. "/" .. item.MaxPurchases .. " owned)",
            btnText,
            canBuy and themeColor3 or Color3.fromRGB(70, 70, 90),
            canBuy and function()
                Network.FireServer("PurchaseEventItem", item.Id)
            end or nil
        )

        if item.Exclusive then
            addBannerToCard(card, "EXCLUSIVE", Color3.fromRGB(255, 80, 80))
        end
        if item.MaxPurchases == 1 and item.Purchased == 1 then
            addBannerToCard(card, "OWNED", Color3.fromRGB(50, 200, 80))
        end

        card.Parent = contentFrame
    end
end

local TAB_RENDERERS = {
    Featured = renderFeatured,
    Limited = renderLimited,
    Boosts = renderBoosts,
    Passes = renderPasses,
    Currency = renderCurrency,
    VIP = renderVIP,
    Rewards = renderRewards,
    Event = renderEvent,
}

-- ═══════════════════════════════════════
-- TAB SWITCHING
-- ═══════════════════════════════════════

local function refreshContent()
    clearContent()

    -- Update tab styles
    for name, def in pairs(tabButtons) do
        if name == activeTab then
            def.Button.BackgroundColor3 = def.Color
            def.Button.TextColor3 = Color3.new(1, 1, 1)
        else
            def.Button.BackgroundColor3 = Color3.fromRGB(38, 38, 56)
            def.Button.TextColor3 = Color3.fromRGB(160, 160, 180)
        end
    end

    local renderer = TAB_RENDERERS[activeTab]
    if renderer then
        renderer()
    end

    -- Analytics
    Network.FireServer("AnalyticsEvent", "ShopTabChanged", { Tab = activeTab })
end

for name, def in pairs(tabButtons) do
    def.Button.MouseButton1Click:Connect(function()
        activeTab = name
        refreshContent()
    end)
end

-- ═══════════════════════════════════════
-- OPEN / CLOSE
-- ═══════════════════════════════════════

local function openShop()
    activeTab = "Featured"
    refreshContent()
    screenGui.Enabled = true
    shopFrame.Size = UDim2.new(0, 0, 0, 0)
    shopFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(shopFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 760, 0, 520),
        Position = UDim2.new(0.5, -380, 0.5, -260),
    }):Play()
    Network.FireServer("AnalyticsEvent", "ShopOpened", {})
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

-- NPC Shopkeeper interaction
Network.OnClientEvent("OpenShop", function()
    openShop()
end)

-- ═══════════════════════════════════════
-- DATA LISTENERS
-- ═══════════════════════════════════════

Network.OnClientEvent("GamepassOwned", function(gamepassId: string)
    ownedGamepasses[gamepassId] = true
    if screenGui.Enabled then
        refreshContent()
    end
end)

-- Full ownership snapshot sent on join (from EntitlementService.PlayerAdded)
Network.OnClientEvent("GamepassStatus", function(statusMap: { [string]: boolean })
    for passId, owned in pairs(statusMap) do
        ownedGamepasses[passId] = owned
    end
    if screenGui.Enabled and activeTab == "Passes" then
        refreshContent()
    end
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    currentPlayerData = data
    ownedGamepasses = data.Gamepasses or {}
end)

Network.OnClientEvent("LimitedShopData", function(data)
    limitedShopData = data or {}
    if screenGui.Enabled and activeTab == "Limited" then
        refreshContent()
    end
end)

Network.OnClientEvent("LimitedShopUpdated", function(data)
    limitedShopData = data or {}
    if screenGui.Enabled and activeTab == "Limited" then
        refreshContent()
    end
end)

Network.OnClientEvent("BoostsUpdated", function(snapshot)
    activeBoosts = snapshot or {}
    if screenGui.Enabled and activeTab == "Boosts" then
        refreshContent()
    end
end)

Network.OnClientEvent("SubscriptionStatus", function(status)
    subscriptionStatus = status or { Tier = "none", Perks = {} }
    if screenGui.Enabled and activeTab == "VIP" then
        refreshContent()
    end
end)

Network.OnClientEvent("EventShopData", function(data)
    eventShopData = data or "none"
    if screenGui.Enabled and activeTab == "Event" then
        refreshContent()
    end
end)

Network.OnClientEvent("EventShopUpdated", function(data)
    if eventShopData and type(eventShopData) == "table" then
        eventShopData.PlayerCoins = data.PlayerCoins
        eventShopData.Items = data.Items
    end
    if screenGui.Enabled and activeTab == "Event" then
        refreshContent()
    end
end)

Network.OnClientEvent("EventCoinUpdated", function(coins)
    if eventShopData and type(eventShopData) == "table" then
        eventShopData.PlayerCoins = coins
    end
end)

-- Session milestone toast
Network.OnClientEvent("SessionMilestone", function(info)
    if not info or type(info) ~= "table" then return end

    -- Build text from whichever fields the sender included
    local text
    if info.Message then
        text = info.Message
    elseif info.Minutes then
        local parts = {"⏱ " .. tostring(info.Minutes) .. " min played!"}
        if info.Coins and info.Coins > 0 then table.insert(parts, "+" .. tostring(info.Coins) .. " Coins") end
        if info.Gems and info.Gems > 0 then table.insert(parts, "+" .. tostring(info.Gems) .. " Gems") end
        text = table.concat(parts, " ")
    elseif info.Label then
        text = info.Label
    else
        return
    end

    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 260, 0, 56)
    toast.Position = UDim2.new(0.5, -130, 0, -60)
    toast.BackgroundColor3 = Color3.fromRGB(20, 50, 30)
    toast.BorderSizePixel = 0
    toast.Parent = playerGui:FindFirstChild("ScreenGui") or screenGui

    local toastCorner = Instance.new("UICorner")
    toastCorner.CornerRadius = UDim.new(0, 10)
    toastCorner.Parent = toast

    local toastLabel = Instance.new("TextLabel")
    toastLabel.Size = UDim2.new(1, -10, 1, 0)
    toastLabel.Position = UDim2.new(0, 5, 0, 0)
    toastLabel.BackgroundTransparency = 1
    toastLabel.Text = text
    toastLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    toastLabel.Font = Enum.Font.GothamBold
    toastLabel.TextSize = 13
    toastLabel.TextWrapped = true
    toastLabel.Parent = toast

    TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -130, 0, 20)
    }):Play()

    task.delay(3.5, function()
        TweenService:Create(toast, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -130, 0, -70)
        }):Play()
        task.wait(0.4)
        if toast and toast.Parent then toast:Destroy() end
    end)
end)

-- ═══════════════════════════════════════
-- NUDGE POPUP
-- ═══════════════════════════════════════

local nudgeFrame = Instance.new("Frame")
nudgeFrame.Name = "NudgePopup"
nudgeFrame.Size = UDim2.new(0, 290, 0, 170)
nudgeFrame.Position = UDim2.new(0.5, -145, 0.5, -85)
nudgeFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
nudgeFrame.Visible = false
nudgeFrame.ZIndex = 50
nudgeFrame.Parent = screenGui

local nudgeCorner = Instance.new("UICorner")
nudgeCorner.CornerRadius = UDim.new(0, 14)
nudgeCorner.Parent = nudgeFrame

local nudgeStroke = Instance.new("UIStroke")
nudgeStroke.Color = Color3.fromRGB(100, 200, 255)
nudgeStroke.Thickness = 2
nudgeStroke.Parent = nudgeFrame

local nudgeTitle = Instance.new("TextLabel")
nudgeTitle.Name = "NudgeTitle"
nudgeTitle.Size = UDim2.new(1, -10, 0, 30)
nudgeTitle.Position = UDim2.new(0, 5, 0, 8)
nudgeTitle.BackgroundTransparency = 1
nudgeTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
nudgeTitle.Font = Enum.Font.GothamBlack
nudgeTitle.TextSize = 16
nudgeTitle.Parent = nudgeFrame

local nudgeBody = Instance.new("TextLabel")
nudgeBody.Name = "NudgeBody"
nudgeBody.Size = UDim2.new(1, -16, 0, 58)
nudgeBody.Position = UDim2.new(0, 8, 0, 42)
nudgeBody.BackgroundTransparency = 1
nudgeBody.TextColor3 = Color3.fromRGB(190, 190, 210)
nudgeBody.Font = Enum.Font.Gotham
nudgeBody.TextSize = 12
nudgeBody.TextWrapped = true
nudgeBody.TextYAlignment = Enum.TextYAlignment.Top
nudgeBody.Parent = nudgeFrame

local nudgeCTABtn = Instance.new("TextButton")
nudgeCTABtn.Name = "NudgeCTA"
nudgeCTABtn.Size = UDim2.new(0.5, -6, 0, 34)
nudgeCTABtn.Position = UDim2.new(0.02, 0, 1, -42)
nudgeCTABtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
nudgeCTABtn.Text = "View"
nudgeCTABtn.TextColor3 = Color3.new(1, 1, 1)
nudgeCTABtn.Font = Enum.Font.GothamBold
nudgeCTABtn.TextSize = 14
nudgeCTABtn.Parent = nudgeFrame

local nudgeCTACorner = Instance.new("UICorner")
nudgeCTACorner.CornerRadius = UDim.new(0, 8)
nudgeCTACorner.Parent = nudgeCTABtn

local nudgeDismissBtn = Instance.new("TextButton")
nudgeDismissBtn.Name = "NudgeDismiss"
nudgeDismissBtn.Size = UDim2.new(0.44, 0, 0, 34)
nudgeDismissBtn.Position = UDim2.new(0.54, 0, 1, -42)
nudgeDismissBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
nudgeDismissBtn.Text = "Later"
nudgeDismissBtn.TextColor3 = Color3.fromRGB(170, 170, 190)
nudgeDismissBtn.Font = Enum.Font.GothamBold
nudgeDismissBtn.TextSize = 13
nudgeDismissBtn.Parent = nudgeFrame

local nudgeDismissCorner = Instance.new("UICorner")
nudgeDismissCorner.CornerRadius = UDim.new(0, 8)
nudgeDismissCorner.Parent = nudgeDismissBtn

local currentNudgeId = nil
local currentNudgeTab = nil

Network.OnClientEvent("NudgeShown", function(payload)
    currentNudgeId = payload.Id
    currentNudgeTab = payload.Tab
    nudgeTitle.Text = payload.Title or "Special Offer"
    nudgeBody.Text = payload.Body or ""
    nudgeCTABtn.Text = payload.CTA or "View"
    nudgeFrame.Visible = true

    Network.FireServer("AnalyticsEvent", "NudgeShown", { NudgeId = payload.Id })

    -- Auto-dismiss after 12 seconds
    task.delay(12, function()
        if nudgeFrame.Visible and currentNudgeId == payload.Id then
            nudgeFrame.Visible = false
        end
    end)
end)

nudgeCTABtn.MouseButton1Click:Connect(function()
    nudgeFrame.Visible = false
    if currentNudgeTab then
        activeTab = currentNudgeTab
        openShop()
    end
    if currentNudgeId then
        Network.FireServer("AnalyticsEvent", "NudgeCTAClicked", { NudgeId = currentNudgeId })
    end
end)

nudgeDismissBtn.MouseButton1Click:Connect(function()
    if currentNudgeId then
        Network.FireServer("DismissNudge", currentNudgeId)
        Network.FireServer("AnalyticsEvent", "NudgeDismissed", { NudgeId = currentNudgeId })
    end
    nudgeFrame.Visible = false
end)

-- ═══════════════════════════════════════
-- OFFER POPUP (context-aware offers overlay)
-- ═══════════════════════════════════════

local offerFrame = Instance.new("Frame")
offerFrame.Name = "OfferPopup"
offerFrame.Size = UDim2.new(0, 320, 0, 200)
offerFrame.Position = UDim2.new(0.5, -160, 0.5, -100)
offerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
offerFrame.Visible = false
offerFrame.Parent = screenGui

local ofCorner = Instance.new("UICorner")
ofCorner.CornerRadius = UDim.new(0, 14)
ofCorner.Parent = offerFrame

local ofStroke = Instance.new("UIStroke")
ofStroke.Color = Color3.fromRGB(255, 200, 50)
ofStroke.Thickness = 2
ofStroke.Parent = offerFrame

local ofTitle = Instance.new("TextLabel")
ofTitle.Name = "OfferTitle"
ofTitle.Size = UDim2.new(1, -10, 0, 30)
ofTitle.Position = UDim2.new(0, 5, 0, 8)
ofTitle.BackgroundTransparency = 1
ofTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
ofTitle.Font = Enum.Font.GothamBlack
ofTitle.TextSize = 18
ofTitle.Parent = offerFrame

local ofDesc = Instance.new("TextLabel")
ofDesc.Name = "OfferDesc"
ofDesc.Size = UDim2.new(1, -16, 0, 60)
ofDesc.Position = UDim2.new(0, 8, 0, 42)
ofDesc.BackgroundTransparency = 1
ofDesc.TextColor3 = Color3.fromRGB(200, 200, 220)
ofDesc.Font = Enum.Font.Gotham
ofDesc.TextSize = 12
ofDesc.TextWrapped = true
ofDesc.TextYAlignment = Enum.TextYAlignment.Top
ofDesc.Parent = offerFrame

local ofTimer = Instance.new("TextLabel")
ofTimer.Name = "OfferTimer"
ofTimer.Size = UDim2.new(1, 0, 0, 20)
ofTimer.Position = UDim2.new(0, 0, 0, 104)
ofTimer.BackgroundTransparency = 1
ofTimer.TextColor3 = Color3.fromRGB(255, 100, 100)
ofTimer.Font = Enum.Font.GothamBold
ofTimer.TextSize = 11
ofTimer.Parent = offerFrame

local ofBuyBtn = Instance.new("TextButton")
ofBuyBtn.Name = "OfferBuy"
ofBuyBtn.Size = UDim2.new(0.45, 0, 0, 36)
ofBuyBtn.Position = UDim2.new(0.03, 0, 1, -48)
ofBuyBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
ofBuyBtn.Text = "BUY"
ofBuyBtn.TextColor3 = Color3.new(1, 1, 1)
ofBuyBtn.Font = Enum.Font.GothamBold
ofBuyBtn.TextSize = 16
ofBuyBtn.Parent = offerFrame

local ofBuyCorner = Instance.new("UICorner")
ofBuyCorner.CornerRadius = UDim.new(0, 8)
ofBuyCorner.Parent = ofBuyBtn

local ofDismissBtn = Instance.new("TextButton")
ofDismissBtn.Name = "OfferDismiss"
ofDismissBtn.Size = UDim2.new(0.45, 0, 0, 36)
ofDismissBtn.Position = UDim2.new(0.52, 0, 1, -48)
ofDismissBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
ofDismissBtn.Text = "No Thanks"
ofDismissBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
ofDismissBtn.Font = Enum.Font.GothamBold
ofDismissBtn.TextSize = 13
ofDismissBtn.Parent = offerFrame

local ofDismissCorner = Instance.new("UICorner")
ofDismissCorner.CornerRadius = UDim.new(0, 8)
ofDismissCorner.Parent = ofDismissBtn

local currentOfferId = nil

Network.OnClientEvent("OfferShown", function(offerData)
    currentOfferId = offerData.Id
    ofTitle.Text = offerData.Name or "Special Offer"
    ofDesc.Text = offerData.Description or ""
    ofBuyBtn.Text = "R$ " .. (offerData.Robux or "?")

    if offerData.BannerColor then
        ofStroke.Color = offerData.BannerColor
    end

    offerFrame.Visible = true

    -- Countdown timer
    local expiresIn = offerData.ExpiresIn or 300
    local startTime = tick()
    task.spawn(function()
        while offerFrame.Visible do
            local remaining = math.max(0, expiresIn - (tick() - startTime))
            local min = math.floor(remaining / 60)
            local sec = math.floor(remaining % 60)
            ofTimer.Text = string.format("Expires in %d:%02d", min, sec)
            if remaining <= 0 then
                offerFrame.Visible = false
                break
            end
            task.wait(1)
        end
    end)
end)

ofBuyBtn.MouseButton1Click:Connect(function()
    if currentOfferId then
        Network.FireServer("AcceptOffer", currentOfferId)
        offerFrame.Visible = false
    end
end)

ofDismissBtn.MouseButton1Click:Connect(function()
    if currentOfferId then
        Network.FireServer("DismissOffer", currentOfferId)
    end
    offerFrame.Visible = false
end)

-- ═══════════════════════════════════════
-- UPSELL TRIGGER (contextual gamepass upsell popup)
-- ═══════════════════════════════════════

-- Reuses the nudge popup with gamepass-specific copy.
-- Debounced server-side; client only displays.
local UPSELL_COPY = {
    DoubleCoins      = { Title = "💰 2x Coins Pass", Body  = "You're close! With 2x Coins you earn double from every source, permanently." },
    DoubleLuck       = { Title = "🍀 2x Luck — So Close!", Body  = "You nearly hatched a Legendary! Grab 2x Luck to double your rare pet chances forever." },
    DoubleHatchSpeed = { Title = "⚡ Hatch Faster!", Body  = "Unlock 2x Hatch Speed and cut your cooldown in half — permanently." },
    auto_hatch       = { Title = "🔁 You're hatching a lot!", Body  = "Go hands-free with Auto Hatch — hatch eggs automatically, no clicking needed." },
    triple_hatch     = { Title = "🥚 Triple Hatch — 3x Output!", Body = "Hatch 3 eggs at once. Stack with Auto Hatch for maximum farming." },
}

Network.OnClientEvent("UpsellTrigger", function(passId: string)
    if ownedGamepasses[passId] then return end  -- already owned, skip
    local gp = GamepassConfig.GetGamepass(passId)
    if not gp then return end

    local copy = UPSELL_COPY[passId] or { Title = gp.Name, Body = gp.Description }

    -- Reuse the nudge popup UI
    currentNudgeId = "__upsell_" .. passId
    currentNudgeTab = "Passes"
    nudgeTitle.Text = copy.Title
    nudgeBody.Text = copy.Body .. "\n\nR$ " .. gp.Price
    nudgeCTABtn.Text = "View in Shop"
    nudgeFrame.Visible = true

    task.delay(10, function()
        if nudgeFrame.Visible and currentNudgeId == "__upsell_" .. passId then
            nudgeFrame.Visible = false
        end
    end)
end)

print("[GUI] ShopGui loaded (8-tab funnel)")
