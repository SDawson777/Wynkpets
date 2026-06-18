--[[
    FirstSessionGui.client.luau
    Full-screen welcome reveal shown exactly once — on the player's very first join.
    Fired by FirstSessionService via "FirstSessionReward" {Coins, Gems, PetId, PetUUID}.

    Three beats:
        1.  "Welcome to Wynkpets!" — branded header with shimmer
        2.  Currency reward row   — 500 Coins + 50 Gems
        3.  Rare pet card reveal  — Fluffnose (Rare) with glow ring

    Players click "Claim & Play!" to dismiss; no server round-trip needed
    (rewards are already in inventories by the time the event arrives).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
Network.WaitForInit()
local PetVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("PetVisualUtil"))

-- ── Pet display metadata (read from PetConfig for authoritative image IDs) ─────
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))

local function getPetInfo(petId: string)
    for _, pet in ipairs(PetConfig.Pets) do
        if pet.Id == petId then
            return { Name = pet.Name, Rarity = pet.Rarity or "Rare", Image = pet.Image or "" }
        end
    end
    return { Name = petId, Rarity = "Rare", Image = "" }
end

local RARITY_COLOR = {
    Common    = Color3.fromRGB(180, 180, 180),
    Rare      = Color3.fromRGB(80, 160, 255),
    Epic      = Color3.fromRGB(180, 80, 255),
    Legendary = Color3.fromRGB(255, 200, 50),
}

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "FirstSessionGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 200  -- render above HUD
gui.Parent = playerGui

-- ── Build UI ──────────────────────────────────────────────────────────────────
local function buildUI(payload)
    local petInfo = getPetInfo(payload.PetId)
    local rarityColor = RARITY_COLOR[petInfo.Rarity] or RARITY_COLOR.Rare

    -- Full-screen semi-transparent overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.45
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 10
    overlay.Parent = gui

    -- Main card
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(0, 480, 0, 520)
    card.Position = UDim2.new(0.5, -240, 0.6, -260)   -- start below centre
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
    card.BorderSizePixel = 0
    card.ZIndex = 11
    card.Parent = overlay

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 20)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = rarityColor
    cardStroke.Thickness = 3
    cardStroke.Parent = card

    -- ── Header ─────────────────────────────────────────────────────────────────
    local headerBg = Instance.new("Frame")
    headerBg.Size = UDim2.new(1, 0, 0, 70)
    headerBg.BackgroundColor3 = Color3.fromRGB(28, 28, 52)
    headerBg.BorderSizePixel = 0
    headerBg.ZIndex = 12
    headerBg.Parent = card

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 20)
    headerCorner.Parent = headerBg

    -- Square off bottom corners of header so it fills card top
    local headerSquare = Instance.new("Frame")
    headerSquare.Size = UDim2.new(1, 0, 0.5, 0)
    headerSquare.Position = UDim2.new(0, 0, 0.5, 0)
    headerSquare.BackgroundColor3 = Color3.fromRGB(28, 28, 52)
    headerSquare.BorderSizePixel = 0
    headerSquare.ZIndex = 12
    headerSquare.Parent = headerBg

    local headerTitle = Instance.new("TextLabel")
    headerTitle.Size = UDim2.new(1, 0, 1, 0)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "🎉  Welcome to Wynkpets!"
    headerTitle.TextColor3 = Color3.fromRGB(255, 230, 80)
    headerTitle.Font = Enum.Font.GothamBold
    headerTitle.TextSize = 26
    headerTitle.ZIndex = 13
    headerTitle.Parent = headerBg

    local subTitle = Instance.new("TextLabel")
    subTitle.Size = UDim2.new(1, -20, 0, 22)
    subTitle.Position = UDim2.new(0, 0, 0, 72)
    subTitle.BackgroundTransparency = 1
    subTitle.Text = "Here are your starter gifts — on us!"
    subTitle.TextColor3 = Color3.fromRGB(180, 180, 210)
    subTitle.Font = Enum.Font.Gotham
    subTitle.TextSize = 14
    subTitle.ZIndex = 12
    subTitle.Parent = card

    -- ── Currency row ───────────────────────────────────────────────────────────
    local currencyRow = Instance.new("Frame")
    currencyRow.Name = "CurrencyRow"
    currencyRow.Size = UDim2.new(1, -40, 0, 80)
    currencyRow.Position = UDim2.new(0, 20, 0, 102)
    currencyRow.BackgroundTransparency = 1
    currencyRow.ZIndex = 12
    currencyRow.Parent = card

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Padding = UDim.new(0, 20)
    rowLayout.Parent = currencyRow

    local function currencyPill(icon, label, color)
        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 175, 0, 62)
        pill.BackgroundColor3 = Color3.fromRGB(30, 30, 52)
        pill.BorderSizePixel = 0
        pill.ZIndex = 13
        pill.Parent = currencyRow

        local pillCorner = Instance.new("UICorner")
        pillCorner.CornerRadius = UDim.new(0, 12)
        pillCorner.Parent = pill

        local pillStroke = Instance.new("UIStroke")
        pillStroke.Color = color
        pillStroke.Thickness = 2
        pillStroke.Parent = pill

        local iconLabel = Instance.new("TextLabel")
        iconLabel.Size = UDim2.new(0, 40, 1, 0)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Text = icon
        iconLabel.TextSize = 30
        iconLabel.Font = Enum.Font.GothamBold
        iconLabel.ZIndex = 14
        iconLabel.Parent = pill

        local amtLabel = Instance.new("TextLabel")
        amtLabel.Size = UDim2.new(1, -44, 1, 0)
        amtLabel.Position = UDim2.new(0, 44, 0, 0)
        amtLabel.BackgroundTransparency = 1
        amtLabel.Text = label
        amtLabel.TextColor3 = color
        amtLabel.Font = Enum.Font.GothamBold
        amtLabel.TextSize = 20
        amtLabel.TextXAlignment = Enum.TextXAlignment.Left
        amtLabel.ZIndex = 14
        amtLabel.Parent = pill
    end

    currencyPill("🪙", "+" .. tostring(payload.Coins) .. " Coins", Color3.fromRGB(255, 210, 60))
    currencyPill("💎", "+" .. tostring(payload.Gems)  .. " Gems",  Color3.fromRGB(100, 200, 255))

    -- ── Pet card ───────────────────────────────────────────────────────────────
    local petSection = Instance.new("Frame")
    petSection.Name = "PetSection"
    petSection.Size = UDim2.new(1, -40, 0, 240)
    petSection.Position = UDim2.new(0, 20, 0, 200)
    petSection.BackgroundColor3 = Color3.fromRGB(24, 24, 44)
    petSection.BorderSizePixel = 0
    petSection.ZIndex = 12
    petSection.Parent = card

    local petCorner = Instance.new("UICorner")
    petCorner.CornerRadius = UDim.new(0, 14)
    petCorner.Parent = petSection

    local petStroke = Instance.new("UIStroke")
    petStroke.Color = rarityColor
    petStroke.Thickness = 2
    petStroke.Parent = petSection

    -- Rarity badge
    local rarityBadge = Instance.new("Frame")
    rarityBadge.Size = UDim2.new(0, 90, 0, 26)
    rarityBadge.Position = UDim2.new(0.5, -45, 0, 10)
    rarityBadge.BackgroundColor3 = rarityColor
    rarityBadge.BorderSizePixel = 0
    rarityBadge.ZIndex = 13
    rarityBadge.Parent = petSection

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 8)
    badgeCorner.Parent = rarityBadge

    local badgeLabel = Instance.new("TextLabel")
    badgeLabel.Size = UDim2.new(1, 0, 1, 0)
    badgeLabel.BackgroundTransparency = 1
    badgeLabel.Text = petInfo.Rarity:upper()
    badgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    badgeLabel.Font = Enum.Font.GothamBold
    badgeLabel.TextSize = 13
    badgeLabel.ZIndex = 14
    badgeLabel.Parent = rarityBadge

    -- Pet image
    local petImage = Instance.new("ImageLabel")
    petImage.Name = "PetImage"
    petImage.Size = UDim2.new(0, 130, 0, 130)
    petImage.Position = UDim2.new(0.5, -65, 0, 44)
    petImage.BackgroundTransparency = 1
    petImage.Image = PetVisualUtil.GetPetImage(petInfo, nil)
    petImage.ScaleType = Enum.ScaleType.Fit
    petImage.ZIndex = 13
    petImage.Parent = petSection

    -- Glow ring behind pet image
    local glowRing = Instance.new("Frame")
    glowRing.Name = "GlowRing"
    glowRing.Size = UDim2.new(0, 144, 0, 144)
    glowRing.Position = UDim2.new(0.5, -72, 0, 37)
    glowRing.BackgroundColor3 = rarityColor
    glowRing.BackgroundTransparency = 0.6
    glowRing.BorderSizePixel = 0
    glowRing.ZIndex = 12
    glowRing.Parent = petSection

    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0.5, 0)  -- full circle
    glowCorner.Parent = glowRing

    -- Pet name
    local petName = Instance.new("TextLabel")
    petName.Size = UDim2.new(1, 0, 0, 30)
    petName.Position = UDim2.new(0, 0, 0, 180)
    petName.BackgroundTransparency = 1
    petName.Text = petInfo.Name
    petName.TextColor3 = Color3.fromRGB(255, 255, 255)
    petName.Font = Enum.Font.GothamBold
    petName.TextSize = 22
    petName.ZIndex = 13
    petName.Parent = petSection

    -- "Auto-equipped!" sub-label
    local equippedLabel = Instance.new("TextLabel")
    equippedLabel.Size = UDim2.new(1, 0, 0, 22)
    equippedLabel.Position = UDim2.new(0, 0, 0, 210)
    equippedLabel.BackgroundTransparency = 1
    equippedLabel.Text = "✅  Auto-equipped and orbiting you!"
    equippedLabel.TextColor3 = Color3.fromRGB(120, 220, 120)
    equippedLabel.Font = Enum.Font.Gotham
    equippedLabel.TextSize = 13
    equippedLabel.ZIndex = 13
    equippedLabel.Parent = petSection

    -- ── Claim button ──────────────────────────────────────────────────────────
    local claimBtn = Instance.new("TextButton")
    claimBtn.Name = "ClaimBtn"
    claimBtn.Size = UDim2.new(1, -40, 0, 52)
    claimBtn.Position = UDim2.new(0, 20, 0, 455)
    claimBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
    claimBtn.BorderSizePixel = 0
    claimBtn.Text = "Claim & Play! 🎮"
    claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimBtn.Font = Enum.Font.GothamBold
    claimBtn.TextSize = 22
    claimBtn.ZIndex = 13
    claimBtn.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 12)
    btnCorner.Parent = claimBtn

    -- ── Entrance animation ────────────────────────────────────────────────────
    card.Position = UDim2.new(0.5, -240, 0.65, -260)   -- start lower
    card.BackgroundTransparency = 1

    local tweenIn = TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -240, 0.5, -260),
        BackgroundTransparency = 0,
    })
    tweenIn:Play()

    -- Pulse glow ring
    local function pulseGlow()
        TweenService:Create(glowRing, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            BackgroundTransparency = 0.85
        }):Play()
    end
    tweenIn.Completed:Connect(pulseGlow)

    -- ── Button interaction ────────────────────────────────────────────────────
    claimBtn.MouseButton1Click:Connect(function()
        local tweenOut = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -240, 0.35, -260),
            BackgroundTransparency = 1,
        })
        tweenOut:Play()
        TweenService:Create(overlay, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1
        }):Play()
        tweenOut.Completed:Connect(function()
            gui:Destroy()
        end)
    end)

    -- Hover glow on button
    claimBtn.MouseEnter:Connect(function()
        TweenService:Create(claimBtn, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(100, 230, 120)
        }):Play()
    end)
    claimBtn.MouseLeave:Connect(function()
        TweenService:Create(claimBtn, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(80, 200, 100)
        }):Play()
    end)
end

-- ── Server event listener ─────────────────────────────────────────────────────
Network.OnClientEvent("FirstSessionReward", function(payload)
    -- Small delay so the world loads first, making the reveal feel earned
    task.wait(1.8)
    buildUI(payload)
end)
