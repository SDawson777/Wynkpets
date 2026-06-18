--[[
    StarterPackGui.client.luau
    Full-screen blocking starter pack modal for new players.

    Triggered by StarterOfferShown (server → client).
    Dismissed by pressing "No Thanks" or the X button → fires StarterOfferDismissed.
    Purchase button → fires PurchaseDevProduct with starter_pack product ID.
    Closed automatically on StarterOfferPurchased confirmation.
]]

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared  = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
Network.WaitForInit()
local PetConfig     = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local PetVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("PetVisualUtil"))

-- ── Build GUI ──────────────────────────────────────────────────────────────────

local function buildGui()
    -- Root ScreenGui (always on top via DisplayOrder)
    local screenGui          = Instance.new("ScreenGui")
    screenGui.Name           = "StarterPackGui"
    screenGui.DisplayOrder   = 200
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn   = false
    screenGui.Enabled        = false
    screenGui.Parent         = playerGui

    -- Dimmer overlay
    local dim           = Instance.new("Frame")
    dim.Name            = "Dim"
    dim.Size            = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 0.45
    dim.BorderSizePixel = 0
    dim.ZIndex          = 1
    dim.Parent          = screenGui

    -- Main card
    local card           = Instance.new("Frame")
    card.Name            = "Card"
    card.AnchorPoint     = Vector2.new(0.5, 0.5)
    card.Position        = UDim2.fromScale(0.5, 0.5)
    card.Size            = UDim2.fromOffset(480, 560)
    card.BackgroundColor3 = Color3.fromRGB(20, 18, 36)
    card.BorderSizePixel = 0
    card.ZIndex          = 2
    card.Parent          = screenGui

    -- Rounded corners
    local corner      = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent      = card

    -- Gold gradient border
    local stroke           = Instance.new("UIStroke")
    stroke.Color           = Color3.fromRGB(255, 200, 50)
    stroke.Thickness       = 3
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent          = card

    -- "EXCLUSIVE OFFER" banner at top
    local banner           = Instance.new("Frame")
    banner.Size            = UDim2.new(1, 0, 0, 36)
    banner.Position        = UDim2.new(0, 0, 0, 0)
    banner.BackgroundColor3 = Color3.fromRGB(220, 170, 20)
    banner.BorderSizePixel = 0
    banner.ZIndex          = 3
    banner.Parent          = card

    local bannerCorner         = Instance.new("UICorner")
    bannerCorner.CornerRadius  = UDim.new(0, 16)
    bannerCorner.Parent        = banner

    -- Mask bottom corners of banner so it looks flush
    local bannerMask           = Instance.new("Frame")
    bannerMask.Size            = UDim2.new(1, 0, 0.5, 0)
    bannerMask.Position        = UDim2.new(0, 0, 0.5, 0)
    bannerMask.BackgroundColor3 = Color3.fromRGB(220, 170, 20)
    bannerMask.BorderSizePixel = 0
    bannerMask.ZIndex          = 3
    bannerMask.Parent          = banner

    local bannerLabel          = Instance.new("TextLabel")
    bannerLabel.Size           = UDim2.fromScale(1, 1)
    bannerLabel.BackgroundTransparency = 1
    bannerLabel.Text           = "⭐  NEW PLAYER EXCLUSIVE  ⭐"
    bannerLabel.TextColor3     = Color3.fromRGB(33, 20, 0)
    bannerLabel.TextScaled     = true
    bannerLabel.Font           = Enum.Font.GothamBold
    bannerLabel.ZIndex         = 4
    bannerLabel.Parent         = banner

    -- Pet preview placeholder (replace ImageId with actual pet asset)
    local petFrame             = Instance.new("Frame")
    petFrame.AnchorPoint       = Vector2.new(0.5, 0)
    petFrame.Position          = UDim2.new(0.5, 0, 0, 44)
    petFrame.Size              = UDim2.fromOffset(120, 120)
    petFrame.BackgroundColor3  = Color3.fromRGB(40, 35, 60)
    petFrame.BorderSizePixel   = 0
    petFrame.ZIndex            = 3
    petFrame.Parent            = card

    local petCorner        = Instance.new("UICorner")
    petCorner.CornerRadius = UDim.new(0, 12)
    petCorner.Parent       = petFrame

    local petIcon             = Instance.new("ImageLabel")
    petIcon.Name              = "PetIcon"
    petIcon.Size              = UDim2.fromScale(0.85, 0.85)
    petIcon.AnchorPoint       = Vector2.new(0.5, 0.5)
    petIcon.Position          = UDim2.fromScale(0.5, 0.5)
    petIcon.BackgroundTransparency = 1
    petIcon.Image             = ""
    petIcon.ZIndex            = 4
    petIcon.Parent            = petFrame

    local petLabel            = Instance.new("TextLabel")
    petLabel.Name             = "PetLabel"
    petLabel.Size             = UDim2.new(1, 0, 0, 24)
    petLabel.AnchorPoint      = Vector2.new(0.5, 0)
    petLabel.Position         = UDim2.new(0.5, 0, 0, 170)
    petLabel.BackgroundTransparency = 1
    petLabel.Text             = "🐰 Starter Bunny"
    petLabel.TextColor3       = Color3.fromRGB(255, 220, 100)
    petLabel.TextScaled       = true
    petLabel.Font             = Enum.Font.GothamBold
    petLabel.ZIndex           = 3
    petLabel.Parent           = card

    -- Title
    local title               = Instance.new("TextLabel")
    title.Name                = "Title"
    title.Size                = UDim2.new(1, -24, 0, 36)
    title.AnchorPoint         = Vector2.new(0.5, 0)
    title.Position            = UDim2.new(0.5, 0, 0, 200)
    title.BackgroundTransparency = 1
    title.Text                = "Starter Pack"
    title.TextColor3          = Color3.fromRGB(255, 255, 255)
    title.TextScaled          = true
    title.Font                = Enum.Font.GothamBold
    title.ZIndex              = 3
    title.Parent              = card

    -- Value breakdown
    local rewardsLabel        = Instance.new("TextLabel")
    rewardsLabel.Name         = "Rewards"
    rewardsLabel.Size         = UDim2.new(1, -32, 0, 80)
    rewardsLabel.AnchorPoint  = Vector2.new(0.5, 0)
    rewardsLabel.Position     = UDim2.new(0.5, 0, 0, 244)
    rewardsLabel.BackgroundColor3 = Color3.fromRGB(35, 30, 55)
    rewardsLabel.BackgroundTransparency = 0.3
    rewardsLabel.BorderSizePixel = 0
    rewardsLabel.Text         = "🪙  10,000 Coins\n💎  100 Gems\n⚡  30-min Coin Boost"
    rewardsLabel.TextColor3   = Color3.fromRGB(210, 210, 255)
    rewardsLabel.TextScaled   = true
    rewardsLabel.Font         = Enum.Font.Gotham
    rewardsLabel.ZIndex       = 3
    rewardsLabel.Parent       = card

    local rewardsCorner       = Instance.new("UICorner")
    rewardsCorner.CornerRadius = UDim.new(0, 10)
    rewardsCorner.Parent      = rewardsLabel

    -- Value comparison banner
    local valueLabel          = Instance.new("TextLabel")
    valueLabel.Name           = "ValueLabel"
    valueLabel.Size           = UDim2.new(1, -32, 0, 28)
    valueLabel.AnchorPoint    = Vector2.new(0.5, 0)
    valueLabel.Position       = UDim2.new(0.5, 0, 0, 332)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text           = "Worth 300+ R$ of value — only 99 R$!"
    valueLabel.TextColor3     = Color3.fromRGB(100, 240, 120)
    valueLabel.TextScaled     = true
    valueLabel.Font           = Enum.Font.GothamSemibold
    valueLabel.ZIndex         = 3
    valueLabel.Parent         = card

    -- Buy button
    local buyBtn              = Instance.new("TextButton")
    buyBtn.Name               = "BuyButton"
    buyBtn.Size               = UDim2.new(1, -48, 0, 52)
    buyBtn.AnchorPoint        = Vector2.new(0.5, 0)
    buyBtn.Position           = UDim2.new(0.5, 0, 0, 370)
    buyBtn.BackgroundColor3   = Color3.fromRGB(30, 185, 85)
    buyBtn.BorderSizePixel    = 0
    buyBtn.Text               = "Get Starter Pack — 99 R$"
    buyBtn.TextColor3         = Color3.fromRGB(255, 255, 255)
    buyBtn.TextScaled         = true
    buyBtn.Font               = Enum.Font.GothamBold
    buyBtn.ZIndex             = 3
    buyBtn.Parent             = card

    local buyCorner           = Instance.new("UICorner")
    buyCorner.CornerRadius    = UDim.new(0, 12)
    buyCorner.Parent          = buyBtn

    -- Dismiss button
    -- Countdown timer label (e.g. "⏳ Offer expires in 14:59")
    local countdownLabel          = Instance.new("TextLabel")
    countdownLabel.Name           = "CountdownLabel"
    countdownLabel.Size           = UDim2.new(1, -48, 0, 26)
    countdownLabel.AnchorPoint    = Vector2.new(0.5, 0)
    countdownLabel.Position       = UDim2.new(0.5, 0, 0, 472)
    countdownLabel.BackgroundTransparency = 1
    countdownLabel.Text           = ""
    countdownLabel.TextColor3     = Color3.fromRGB(255, 160, 60)
    countdownLabel.TextScaled     = true
    countdownLabel.Font           = Enum.Font.GothamSemibold
    countdownLabel.ZIndex         = 3
    countdownLabel.Parent         = card

    local dismissBtn          = Instance.new("TextButton")
    dismissBtn.Name           = "DismissButton"
    dismissBtn.Size           = UDim2.new(1, -48, 0, 36)
    dismissBtn.AnchorPoint    = Vector2.new(0.5, 0)
    dismissBtn.Position       = UDim2.new(0.5, 0, 0, 502)
    dismissBtn.BackgroundTransparency = 1
    dismissBtn.BorderSizePixel = 0
    dismissBtn.Text           = "No thanks"
    dismissBtn.TextColor3     = Color3.fromRGB(130, 120, 160)
    dismissBtn.TextScaled     = true
    dismissBtn.Font           = Enum.Font.Gotham
    dismissBtn.ZIndex         = 3
    dismissBtn.Parent         = card

    -- X close button
    local closeBtn            = Instance.new("TextButton")
    closeBtn.Name             = "CloseButton"
    closeBtn.Size             = UDim2.fromOffset(32, 32)
    closeBtn.AnchorPoint      = Vector2.new(1, 0)
    closeBtn.Position         = UDim2.new(1, -8, 0, 8)
    closeBtn.BackgroundTransparency = 1
    closeBtn.BorderSizePixel  = 0
    closeBtn.Text             = "✕"
    closeBtn.TextColor3       = Color3.fromRGB(200, 190, 220)
    closeBtn.TextScaled       = true
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.ZIndex           = 5
    closeBtn.Parent           = card

    return screenGui, card, buyBtn, dismissBtn, closeBtn, petLabel, title, rewardsLabel, countdownLabel, petIcon
end

-- ── Controller ─────────────────────────────────────────────────────────────

local screenGui, card, buyBtn, dismissBtn, closeBtn, petLabel, title, rewardsLabel, countdownLabel, petIcon = buildGui()

local countdownThread = nil  -- running coroutine for the countdown ticker

local function stopCountdown()
    if countdownThread then
        task.cancel(countdownThread)
        countdownThread = nil
    end
    countdownLabel.Text = ""
end

local function startCountdown(secondsRemaining: number)
    stopCountdown()
    local endAt = tick() + secondsRemaining
    countdownThread = task.spawn(function()
        while true do
            local remaining = math.max(0, math.floor(endAt - tick()))
            local mins = math.floor(remaining / 60)
            local secs = remaining % 60
            countdownLabel.Text = string.format("⏳ Offer expires in %d:%02d", mins, secs)
            if remaining <= 0 then
                task.wait(0.5)
                -- Auto-dismiss when timer runs out
                if screenGui.Enabled then
                    hideModal("dismiss")
                end
                break
            end
            task.wait(1)
        end
    end)
end

local function showModal(offerData)
    -- Update dynamic content from offer payload
    if offerData then
        if offerData.Name   then title.Text = offerData.Name end
        if offerData.PetPreview then
            local previewInfo = PetConfig.GetPet(offerData.PetPreview)
            if previewInfo then
                petIcon.Image = PetVisualUtil.GetPetImage(previewInfo, nil)
                petLabel.Text = "🐰 " .. previewInfo.Name
            else
                petLabel.Text = "🐰 Exclusive Pet: " .. offerData.PetPreview
            end
        end
        if offerData.Rewards then
            local lines = {}
            if offerData.Rewards.Coins then
                table.insert(lines, "🪙  " .. tostring(offerData.Rewards.Coins) .. " Coins")
            end
            if offerData.Rewards.Gems then
                table.insert(lines, "💎  " .. tostring(offerData.Rewards.Gems) .. " Gems")
            end
            table.insert(lines, "⚡  30-min Coin Boost")
            rewardsLabel.Text = table.concat(lines, "\n")
        end
    end

    screenGui.Enabled = true
    card.Size = UDim2.fromOffset(480, 0)
    TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(480, 560)
    }):Play()

    -- Start urgency countdown
    local secs = offerData and offerData.SecondsRemaining or 900
    startCountdown(secs)
end

local function hideModal(reason: string)
    stopCountdown()
    local tween = TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.fromOffset(480, 0)
    })
    tween:Play()
    tween.Completed:Connect(function()
        screenGui.Enabled = false
    end)

    if reason == "dismiss" then
        Network.FireServer("StarterOfferDismissed")
    end
end

-- ── Events ────────────────────────────────────────────────────────────────────

Network.OnClientEvent("StarterOfferShown", function(offerData)
    showModal(offerData)
end)

Network.OnClientEvent("StarterOfferPurchased", function()
    hideModal("purchased")
end)

buyBtn.Activated:Connect(function()
    Network.FireServer("PurchaseDevProduct", "starter_pack")
end)

dismissBtn.Activated:Connect(function()
    hideModal("dismiss")
end)

closeBtn.Activated:Connect(function()
    hideModal("dismiss")
end)
