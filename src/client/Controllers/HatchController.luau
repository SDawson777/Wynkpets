--[[
    HatchController.luau (Client)
    Handles hatch requests, dopamine-maximizing animations, and result displays.
    Every hatch should feel exciting — rarer pets = bigger spectacle.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EggConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local PetVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("PetVisualUtil"))
local EggVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("EggVisualUtil"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HatchController = {}

local isHatching = false
local resultCallbacks = {}
local autoHatchEnabled = false
local autoHatchEggId = nil

-- Rarity-specific celebration configs
local RARITY_CELEBRATIONS = {
    Common = {
        FlashColor = Color3.fromRGB(200, 200, 200),
        FlashDuration = 0.3,
        CardScale = 1.0,
        ScreenShake = 0,
        ConfettiCount = 0,
        GlowPulses = 0,
        Title = "",
        TitleColor = Color3.fromRGB(200, 200, 200),
        HoldTime = 2.5,
    },
    Rare = {
        FlashColor = Color3.fromRGB(80, 170, 255),
        FlashDuration = 0.4,
        CardScale = 1.05,
        ScreenShake = 2,
        ConfettiCount = 8,
        GlowPulses = 1,
        Title = "RARE!",
        TitleColor = Color3.fromRGB(80, 170, 255),
        HoldTime = 3,
    },
    Epic = {
        FlashColor = Color3.fromRGB(180, 50, 255),
        FlashDuration = 0.5,
        CardScale = 1.1,
        ScreenShake = 4,
        ConfettiCount = 15,
        GlowPulses = 2,
        Title = "EPIC!",
        TitleColor = Color3.fromRGB(200, 80, 255),
        HoldTime = 3.5,
    },
    Legendary = {
        FlashColor = Color3.fromRGB(255, 200, 0),
        FlashDuration = 0.6,
        CardScale = 1.15,
        ScreenShake = 6,
        ConfettiCount = 25,
        GlowPulses = 3,
        Title = "LEGENDARY!",
        TitleColor = Color3.fromRGB(255, 215, 50),
        HoldTime = 4,
    },
    Mythic = {
        FlashColor = Color3.fromRGB(255, 50, 100),
        FlashDuration = 0.7,
        CardScale = 1.2,
        ScreenShake = 8,
        ConfettiCount = 40,
        GlowPulses = 4,
        Title = "MYTHIC!!!",
        TitleColor = Color3.fromRGB(255, 80, 120),
        HoldTime = 5,
    },
    Secret = {
        FlashColor = Color3.fromRGB(255, 100, 255),
        FlashDuration = 0.8,
        CardScale = 1.25,
        ScreenShake = 10,
        ConfettiCount = 60,
        GlowPulses = 5,
        Title = "??? SECRET ???",
        TitleColor = Color3.fromRGB(255, 130, 255),
        HoldTime = 6,
    },
}

-- Register callback for hatch results
function HatchController.OnResult(callback: (any) -> ())
    table.insert(resultCallbacks, callback)
end

-- Request to hatch an egg
function HatchController.Hatch(eggId: string)
    if isHatching then return end
    isHatching = true
    Network.FireServer("HatchEgg", eggId)

    -- Timeout protection
    task.delay(10, function()
        isHatching = false
    end)
end

-- Confetti burst effect
local function spawnConfetti(parent, count, color)
    for _ = 1, count do
        local confetti = Instance.new("Frame")
        confetti.Size = UDim2.new(0, math.random(4, 10), 0, math.random(8, 16))
        confetti.BackgroundColor3 = Color3.fromHSV(math.random() * 1, 0.8, 1)
        if color then
            -- Mix in the rarity color 50% of the time
            if math.random() < 0.5 then
                confetti.BackgroundColor3 = color
            end
        end
        confetti.BorderSizePixel = 0
        confetti.Rotation = math.random(-45, 45)
        confetti.AnchorPoint = Vector2.new(0.5, 0.5)
        confetti.ZIndex = 15

        -- Start from center-ish
        local startX = 0.4 + math.random() * 0.2
        local startY = 0.3 + math.random() * 0.2
        confetti.Position = UDim2.new(startX, 0, startY, 0)
        confetti.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 2)
        corner.Parent = confetti

        -- Explode outward and fall
        local endX = math.random() * 1
        local endY = 1.2 + math.random() * 0.3
        local duration = 1 + math.random() * 1.5

        TweenService:Create(confetti, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(endX, 0, endY, 0),
            Rotation = math.random(-360, 360),
            BackgroundTransparency = 0.8,
        }):Play()

        task.delay(duration, function()
            confetti:Destroy()
        end)
    end
end

-- Screen shake effect
local function screenShake(parent, intensity, duration)
    if intensity <= 0 then return end
    local original = parent.Position
    task.spawn(function()
        local elapsed = 0
        while elapsed < duration do
            local dx = (math.random() - 0.5) * intensity * 2
            local dy = (math.random() - 0.5) * intensity * 2
            parent.Position = UDim2.new(original.X.Scale, original.X.Offset + dx, original.Y.Scale, original.Y.Offset + dy)
            task.wait()
            elapsed = elapsed + (1 / 60)
        end
        parent.Position = original
    end)
end

-- Radial glow pulse effect
local function glowPulse(parent, color, pulseCount)
    for i = 1, pulseCount do
        task.delay((i - 1) * 0.4, function()
            local glow = Instance.new("Frame")
            glow.Size = UDim2.new(0, 50, 0, 50)
            glow.Position = UDim2.new(0.5, -25, 0.5, -25)
            glow.AnchorPoint = Vector2.new(0, 0)
            glow.BackgroundColor3 = color
            glow.BackgroundTransparency = 0.3
            glow.BorderSizePixel = 0
            glow.ZIndex = 8
            glow.Parent = parent

            local glowCorner = Instance.new("UICorner")
            glowCorner.CornerRadius = UDim.new(1, 0)
            glowCorner.Parent = glow

            TweenService:Create(glow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(2, 0, 2, 0),
                Position = UDim2.new(-0.5, 0, -0.5, 0),
                BackgroundTransparency = 1,
            }):Play()

            task.delay(0.8, function()
                glow:Destroy()
            end)
        end)
    end
end

-- Get best rarity from results
local function getBestRarity(results)
    local bestOrder = 0
    local bestRarity = "Common"
    for _, result in ipairs(results) do
        local tier = RarityConfig.Tiers[result.Rarity]
        local order = tier and tier.Order or 1
        if order > bestOrder then
            bestOrder = order
            bestRarity = result.Rarity
        end
    end
    -- Golden/Rainbow override to higher spectacle
    for _, result in ipairs(results) do
        if result.Rainbow then
            return "Secret" -- Max spectacle for rainbow
        elseif result.Golden and bestOrder < 4 then
            bestRarity = "Legendary" -- At minimum legendary spectacle for golden
        end
    end
    return bestRarity
end

-- Create the full hatch animation
local function playHatchAnimation(results, hatchTime: number, eggId: string?)
    local bestRarity = getBestRarity(results)
    local celebration = RARITY_CELEBRATIONS[bestRarity] or RARITY_CELEBRATIONS.Common

    -- Resolve egg image from config
    local eggImageId = nil
    if eggId then
        local eggData = EggConfig.GetEgg(eggId)
        if eggData then
            local resolvedEggImage = EggVisualUtil.GetEggImage(eggData)
            if resolvedEggImage ~= "rbxassetid://0" then
                eggImageId = resolvedEggImage
            end
        end
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HatchAnimation"
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 100
    screenGui.Parent = playerGui

    -- Dark overlay
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.3
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui

    -- Container for shake
    local shakeContainer = Instance.new("Frame")
    shakeContainer.Size = UDim2.new(1, 0, 1, 0)
    shakeContainer.Position = UDim2.new(0, 0, 0, 0)
    shakeContainer.BackgroundTransparency = 1
    shakeContainer.Parent = screenGui

    -- Egg visual (centered, themed)
    local eggFrame = Instance.new("Frame")
    eggFrame.Size = UDim2.new(0, 120, 0, 160)
    eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    eggFrame.Position = UDim2.new(0.5, 0, 0.45, 0)
    eggFrame.BackgroundTransparency = 1
    eggFrame.Parent = shakeContainer

    -- eggBody / eggGlow declared here so shake-phase code can access them
    local eggBody: GuiObject
    local eggGlow: UIStroke

    -- Use real egg image when available, otherwise fall back to generic egg
    if eggImageId then
        local eggImg = Instance.new("ImageLabel")
        eggImg.Name = "EggBody"
        eggImg.Size = UDim2.new(1, 0, 1, 0)
        eggImg.BackgroundTransparency = 1
        eggImg.Image = eggImageId
        eggImg.ScaleType = Enum.ScaleType.Fit
        eggImg.Parent = eggFrame

        eggBody = eggImg

        eggGlow = Instance.new("UIStroke")
        eggGlow.Color = Color3.fromRGB(255, 230, 150)
        eggGlow.Thickness = 3
        eggGlow.Transparency = 0.3
        eggGlow.Parent = eggImg
    else
        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, 0, 1, 0)
        body.BackgroundColor3 = Color3.fromRGB(255, 245, 220)
        body.BorderSizePixel = 0
        body.Parent = eggFrame

        local eggCorner = Instance.new("UICorner")
        eggCorner.CornerRadius = UDim.new(0.45, 0)
        eggCorner.Parent = body

        eggBody = body

        eggGlow = Instance.new("UIStroke")
        eggGlow.Color = Color3.fromRGB(255, 230, 150)
        eggGlow.Thickness = 3
        eggGlow.Transparency = 0.3
        eggGlow.Parent = body

        -- Egg spots/decoration
        local spot1 = Instance.new("Frame")
        spot1.Size = UDim2.new(0, 20, 0, 20)
        spot1.Position = UDim2.new(0.25, 0, 0.3, 0)
        spot1.BackgroundColor3 = Color3.fromRGB(230, 210, 170)
        spot1.BorderSizePixel = 0
        spot1.Parent = body
        local s1c = Instance.new("UICorner")
        s1c.CornerRadius = UDim.new(1, 0)
        s1c.Parent = spot1

        local spot2 = Instance.new("Frame")
        spot2.Size = UDim2.new(0, 15, 0, 15)
        spot2.Position = UDim2.new(0.6, 0, 0.5, 0)
        spot2.BackgroundColor3 = Color3.fromRGB(230, 210, 170)
        spot2.BorderSizePixel = 0
        spot2.Parent = body
        local s2c = Instance.new("UICorner")
        s2c.CornerRadius = UDim.new(1, 0)
        s2c.Parent = spot2
    end

    -- "Hatching..." text with pulsing dots
    local hatchText = Instance.new("TextLabel")
    hatchText.Size = UDim2.new(0, 300, 0, 50)
    hatchText.AnchorPoint = Vector2.new(0.5, 0.5)
    hatchText.Position = UDim2.new(0.5, 0, 0.22, 0)
    hatchText.BackgroundTransparency = 1
    hatchText.Text = "Hatching..."
    hatchText.TextColor3 = Color3.new(1, 1, 1)
    hatchText.Font = Enum.Font.GothamBold
    hatchText.TextSize = 32
    hatchText.TextStrokeTransparency = 0
    hatchText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    hatchText.Parent = shakeContainer

    -- ═══════════════════════════════════════
    -- PHASE 1: EGG SHAKING (builds anticipation)
    -- ═══════════════════════════════════════
    local shakeCount = math.floor(hatchTime / 0.25)
    task.spawn(function()
        -- Pulse the glow during shaking
        task.spawn(function()
            while eggFrame.Parent do
                TweenService:Create(eggGlow, TweenInfo.new(0.5), { Thickness = 6, Transparency = 0 }):Play()
                task.wait(0.5)
                if not eggFrame.Parent then break end
                TweenService:Create(eggGlow, TweenInfo.new(0.5), { Thickness = 3, Transparency = 0.3 }):Play()
                task.wait(0.5)
            end
        end)

        for i = 1, shakeCount do
            local progress = i / shakeCount
            local intensity = progress * 20  -- Escalating shake
            local speed = math.max(0.08, 0.15 - progress * 0.07) -- Gets faster

            -- Shake right
            local tween = TweenService:Create(eggFrame, TweenInfo.new(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Rotation = intensity
            })
            tween:Play()
            tween.Completed:Wait()

            -- Shake left
            tween = TweenService:Create(eggFrame, TweenInfo.new(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Rotation = -intensity
            })
            tween:Play()
            tween.Completed:Wait()

            -- Crack effects at 60% and 80%
            if progress > 0.6 and progress < 0.62 then
                eggBody.BackgroundColor3 = Color3.fromRGB(255, 255, 240)
                -- Small flash
                local miniFlash = Instance.new("Frame")
                miniFlash.Size = UDim2.new(1, 0, 1, 0)
                miniFlash.BackgroundColor3 = Color3.new(1, 1, 1)
                miniFlash.BackgroundTransparency = 0.5
                miniFlash.BorderSizePixel = 0
                miniFlash.ZIndex = 9
                miniFlash.Parent = screenGui
                TweenService:Create(miniFlash, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
                task.delay(0.2, function() miniFlash:Destroy() end)
            end
            if progress > 0.8 and progress < 0.82 then
                eggGlow.Color = celebration.FlashColor
                eggGlow.Thickness = 8
                -- Bigger flash
                local miniFlash = Instance.new("Frame")
                miniFlash.Size = UDim2.new(1, 0, 1, 0)
                miniFlash.BackgroundColor3 = celebration.FlashColor
                miniFlash.BackgroundTransparency = 0.6
                miniFlash.BorderSizePixel = 0
                miniFlash.ZIndex = 9
                miniFlash.Parent = screenGui
                TweenService:Create(miniFlash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
                task.delay(0.3, function() miniFlash:Destroy() end)
            end
        end

        -- ═══════════════════════════════════════
        -- PHASE 2: CRACK OPEN — BIG FLASH + EFFECTS
        -- ═══════════════════════════════════════

        -- Screen shake for rare+
        screenShake(shakeContainer, celebration.ScreenShake, 0.5)

        -- Full screen flash (rarity-colored)
        local flash = Instance.new("Frame")
        flash.Size = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3 = celebration.FlashColor
        flash.BackgroundTransparency = 0
        flash.BorderSizePixel = 0
        flash.ZIndex = 10
        flash.Parent = screenGui

        TweenService:Create(flash, TweenInfo.new(celebration.FlashDuration, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1
        }):Play()

        -- Confetti explosion
        if celebration.ConfettiCount > 0 then
            spawnConfetti(screenGui, celebration.ConfettiCount, celebration.FlashColor)
        end

        -- Glow pulses
        if celebration.GlowPulses > 0 then
            glowPulse(screenGui, celebration.FlashColor, celebration.GlowPulses)
        end

        -- Hide egg
        eggFrame:Destroy()
        hatchText.Text = ""

        -- ═══════════════════════════════════════
        -- PHASE 3: RARITY TITLE SLAM (for Rare+)
        -- ═══════════════════════════════════════
        if celebration.Title ~= "" then
            local rarityTitle = Instance.new("TextLabel")
            rarityTitle.Size = UDim2.new(0, 500, 0, 80)
            rarityTitle.AnchorPoint = Vector2.new(0.5, 0.5)
            rarityTitle.Position = UDim2.new(0.5, 0, 0.35, 0)
            rarityTitle.BackgroundTransparency = 1
            rarityTitle.Text = celebration.Title
            rarityTitle.TextColor3 = celebration.TitleColor
            rarityTitle.Font = Enum.Font.GothamBold
            rarityTitle.TextSize = 60
            rarityTitle.TextStrokeTransparency = 0
            rarityTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            rarityTitle.TextTransparency = 1
            rarityTitle.ZIndex = 12
            rarityTitle.Parent = screenGui

            -- Slam in: start huge and transparent, shrink to size with bounce
            rarityTitle.TextSize = 100
            TweenService:Create(rarityTitle, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                TextSize = 52,
                TextTransparency = 0,
            }):Play()

            -- Second shake on title slam
            screenShake(shakeContainer, celebration.ScreenShake * 0.5, 0.3)

            task.delay(1.2, function()
                TweenService:Create(rarityTitle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    TextTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0.28, 0),
                }):Play()
                task.delay(0.5, function() rarityTitle:Destroy() end)
            end)
        end

        task.wait(0.4)

        -- ═══════════════════════════════════════
        -- PHASE 4: PET REVEAL CARDS (staggered for suspense)
        -- ═══════════════════════════════════════
        local resultContainer = Instance.new("Frame")
        resultContainer.Size = UDim2.new(0, #results * 200, 0, 300)
        resultContainer.AnchorPoint = Vector2.new(0.5, 0.5)
        resultContainer.Position = UDim2.new(0.5, 0, 0.52, 0)
        resultContainer.BackgroundTransparency = 1
        resultContainer.Parent = shakeContainer

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 20)
        layout.Parent = resultContainer

        for idx, result in ipairs(results) do
            -- Stagger each card
            task.delay((idx - 1) * 0.3, function()
                local rarityInfo = RarityConfig.Tiers[result.Rarity]
                local rarityColor = rarityInfo and rarityInfo.Color or Color3.new(0.5, 0.5, 0.5)
                local glowColor = rarityInfo and rarityInfo.GlowColor or Color3.new(1, 1, 1)
                local textColor = rarityInfo and rarityInfo.TextColor or Color3.new(1, 1, 1)

                -- Card container
                local card = Instance.new("Frame")
                card.Size = UDim2.new(0, 0, 0, 0) -- start invisible for pop-in
                card.AnchorPoint = Vector2.new(0.5, 0.5)
                card.BackgroundColor3 = Color3.fromRGB(20, 18, 35)
                card.BorderSizePixel = 0
                card.Parent = resultContainer

                local cardCorner = Instance.new("UICorner")
                cardCorner.CornerRadius = UDim.new(0, 16)
                cardCorner.Parent = card

                -- Rarity glow border (thicker for rarer)
                local rarityOrder = rarityInfo and rarityInfo.Order or 1
                local stroke = Instance.new("UIStroke")
                stroke.Color = glowColor
                stroke.Thickness = 2 + rarityOrder
                stroke.Parent = card

                -- Inner gradient overlay
                local gradient = Instance.new("Frame")
                gradient.Size = UDim2.new(1, 0, 0.4, 0)
                gradient.Position = UDim2.new(0, 0, 0, 0)
                gradient.BackgroundColor3 = rarityColor
                gradient.BackgroundTransparency = 0.85
                gradient.BorderSizePixel = 0
                gradient.ZIndex = 2
                gradient.Parent = card

                local gradCorner = Instance.new("UICorner")
                gradCorner.CornerRadius = UDim.new(0, 16)
                gradCorner.Parent = gradient

                -- Pet visual (ImageLabel if available, fallback to colored orb)
                local petInfo = PetConfig.GetPet(result.PetId)
                local petImage = PetVisualUtil.GetImage(petInfo, result)
                local petVisual

                if petImage ~= "rbxassetid://0" then
                    petVisual = Instance.new("ImageLabel")
                    petVisual.Size = UDim2.new(0, 80, 0, 80)
                    petVisual.AnchorPoint = Vector2.new(0.5, 0)
                    petVisual.Position = UDim2.new(0.5, 0, 0, 20)
                    petVisual.BackgroundColor3 = rarityColor
                    petVisual.BackgroundTransparency = 0.85
                    petVisual.Image = petImage
                    petVisual.ScaleType = Enum.ScaleType.Fit
                    petVisual.ZIndex = 3
                    petVisual.Parent = card
                    petVisual.BackgroundTransparency = 1
                else
                    petVisual = Instance.new("Frame")
                    petVisual.Size = UDim2.new(0, 80, 0, 80)
                    petVisual.AnchorPoint = Vector2.new(0.5, 0)
                    petVisual.Position = UDim2.new(0.5, 0, 0, 20)
                    petVisual.BackgroundColor3 = rarityColor
                    petVisual.BorderSizePixel = 0
                    petVisual.ZIndex = 3
                    petVisual.Parent = card

                    local pvCorner = Instance.new("UICorner")
                    pvCorner.CornerRadius = UDim.new(1, 0)
                    pvCorner.Parent = petVisual

                    -- Inner highlight on orb
                    local highlight = Instance.new("Frame")
                    highlight.Size = UDim2.new(0, 30, 0, 30)
                    highlight.Position = UDim2.new(0.2, 0, 0.1, 0)
                    highlight.BackgroundColor3 = Color3.new(1, 1, 1)
                    highlight.BackgroundTransparency = 0.6
                    highlight.BorderSizePixel = 0
                    highlight.ZIndex = 4
                    highlight.Parent = petVisual

                    local hlCorner = Instance.new("UICorner")
                    hlCorner.CornerRadius = UDim.new(1, 0)
                    hlCorner.Parent = highlight
                end

                -- Variant indicator (Golden/Rainbow)
                if result.Golden or result.Rainbow then
                    local variantBadge = Instance.new("Frame")
                    variantBadge.Size = UDim2.new(1, 10, 0, 22)
                    variantBadge.AnchorPoint = Vector2.new(0.5, 0)
                    variantBadge.Position = UDim2.new(0.5, 0, 0, 105)
                    variantBadge.BorderSizePixel = 0
                    variantBadge.ZIndex = 5
                    variantBadge.Parent = card

                    local vbCorner = Instance.new("UICorner")
                    vbCorner.CornerRadius = UDim.new(0, 6)
                    vbCorner.Parent = variantBadge

                    local variantLabel = Instance.new("TextLabel")
                    variantLabel.Size = UDim2.new(1, 0, 1, 0)
                    variantLabel.BackgroundTransparency = 1
                    variantLabel.Font = Enum.Font.GothamBold
                    variantLabel.TextSize = 12
                    variantLabel.TextStrokeTransparency = 0
                    variantLabel.ZIndex = 6
                    variantLabel.Parent = variantBadge

                    if result.Rainbow then
                        variantBadge.BackgroundColor3 = Color3.fromRGB(200, 50, 200)
                        variantLabel.Text = "RAINBOW"
                        variantLabel.TextColor3 = Color3.fromRGB(255, 200, 255)
                        -- Rainbow shimmer on the orb
                        petVisual.BackgroundColor3 = Color3.fromRGB(255, 100, 255)
                        task.spawn(function()
                            local hue = 0
                            while card.Parent do
                                hue = (hue + 0.01) % 1
                                petVisual.BackgroundColor3 = Color3.fromHSV(hue, 0.8, 1)
                                task.wait()
                            end
                        end)
                    elseif result.Golden then
                        variantBadge.BackgroundColor3 = Color3.fromRGB(180, 150, 0)
                        variantLabel.Text = "GOLDEN"
                        variantLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
                        petVisual.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                    end
                end

                -- Pet name
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -10, 0, 28)
                nameLabel.AnchorPoint = Vector2.new(0.5, 0)
                nameLabel.Position = UDim2.new(0.5, 0, 0, 130)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = result.Name
                nameLabel.TextColor3 = Color3.new(1, 1, 1)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 18
                nameLabel.TextStrokeTransparency = 0
                nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                nameLabel.ZIndex = 3
                nameLabel.Parent = card

                -- Rarity label
                local rarityLabel = Instance.new("TextLabel")
                rarityLabel.Size = UDim2.new(1, 0, 0, 22)
                rarityLabel.AnchorPoint = Vector2.new(0.5, 0)
                rarityLabel.Position = UDim2.new(0.5, 0, 0, 158)
                rarityLabel.BackgroundTransparency = 1
                rarityLabel.Text = result.Rarity
                rarityLabel.TextColor3 = textColor
                rarityLabel.Font = Enum.Font.GothamBold
                rarityLabel.TextSize = 15
                rarityLabel.TextStrokeTransparency = 0
                rarityLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                rarityLabel.ZIndex = 3
                rarityLabel.Parent = card

                -- Power display
                local power = result.Power
                if result.Golden then power = math.floor(power * 2.5) end
                if result.Rainbow then power = math.floor(power * 5) end

                local powerLabel = Instance.new("TextLabel")
                powerLabel.Size = UDim2.new(1, 0, 0, 20)
                powerLabel.AnchorPoint = Vector2.new(0.5, 0)
                powerLabel.Position = UDim2.new(0.5, 0, 0, 182)
                powerLabel.BackgroundTransparency = 1
                powerLabel.Text = "Power: " .. tostring(power)
                powerLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
                powerLabel.Font = Enum.Font.Gotham
                powerLabel.TextSize = 13
                powerLabel.ZIndex = 3
                powerLabel.Parent = card

                -- "NEW!" badge
                local newBadge = Instance.new("TextLabel")
                newBadge.Size = UDim2.new(0, 40, 0, 18)
                newBadge.Position = UDim2.new(1, -5, 0, -5)
                newBadge.AnchorPoint = Vector2.new(1, 0)
                newBadge.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
                newBadge.Text = "NEW!"
                newBadge.TextColor3 = Color3.new(1, 1, 1)
                newBadge.Font = Enum.Font.GothamBold
                newBadge.TextSize = 10
                newBadge.ZIndex = 6
                newBadge.Parent = card

                local newCorner = Instance.new("UICorner")
                newCorner.CornerRadius = UDim.new(0, 6)
                newCorner.Parent = newBadge

                -- POP-IN animation with scale bounce
                local targetSize = UDim2.new(0, math.floor(170 * celebration.CardScale), 0, math.floor(220 * celebration.CardScale))
                card.Size = UDim2.new(0, 0, 0, 0)

                TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = targetSize
                }):Play()

                -- Per-card mini confetti for Epic+
                if rarityOrder >= 3 then
                    spawnConfetti(screenGui, math.floor(rarityOrder * 3), glowColor)
                end

                -- Floating pet orb idle animation (gentle bob)
                task.spawn(function()
                    local startY = petVisual.Position.Y.Offset
                    while card.Parent do
                        TweenService:Create(petVisual, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                            Position = UDim2.new(0.5, 0, 0, startY - 5)
                        }):Play()
                        task.wait(0.8)
                        if not card.Parent then break end
                        TweenService:Create(petVisual, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                            Position = UDim2.new(0.5, 0, 0, startY + 3)
                        }):Play()
                        task.wait(0.8)
                    end
                end)
            end)
        end

        -- Wait for all cards to appear
        task.wait(#results * 0.3 + 0.5)

        -- ═══════════════════════════════════════
        -- PHASE 5: REWARD SUMMARY + CLOSE
        -- ═══════════════════════════════════════

        -- "Tap to close" text
        local closeText = Instance.new("TextLabel")
        closeText.Size = UDim2.new(0, 300, 0, 30)
        closeText.AnchorPoint = Vector2.new(0.5, 0)
        closeText.Position = UDim2.new(0.5, 0, 0.88, 0)
        closeText.BackgroundTransparency = 1
        closeText.Text = "Tap anywhere to close"
        closeText.TextColor3 = Color3.fromRGB(180, 180, 200)
        closeText.Font = Enum.Font.Gotham
        closeText.TextSize = 16
        closeText.Parent = screenGui

        -- Pulsing close text
        task.spawn(function()
            while closeText.Parent do
                TweenService:Create(closeText, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    TextTransparency = 0.5
                }):Play()
                task.wait(1)
                if not closeText.Parent then break end
                TweenService:Create(closeText, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    TextTransparency = 0
                }):Play()
                task.wait(1)
            end
        end)

        -- Close on click
        local closeButton = Instance.new("TextButton")
        closeButton.Size = UDim2.new(1, 0, 1, 0)
        closeButton.BackgroundTransparency = 1
        closeButton.Text = ""
        closeButton.ZIndex = 5
        closeButton.Parent = screenGui

        closeButton.MouseButton1Click:Connect(function()
            -- Quick fade out
            TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            for _, child in ipairs(shakeContainer:GetDescendants()) do
                if child:IsA("GuiObject") then
                    pcall(function()
                        TweenService:Create(child, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
                    end)
                end
                if child:IsA("TextLabel") then
                    pcall(function()
                        TweenService:Create(child, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
                    end)
                end
            end
            task.delay(0.3, function() screenGui:Destroy() end)
        end)

        -- Auto close after hold time
        task.delay(celebration.HoldTime + 2, function()
            if screenGui.Parent then
                screenGui:Destroy()
            end
        end)
    end)
end

function HatchController.ToggleAutoHatch(eggId: string)
    autoHatchEnabled = not autoHatchEnabled
    autoHatchEggId = autoHatchEnabled and eggId or nil
    Network.FireServer("AutoHatchToggle", eggId)
end

function HatchController.IsAutoHatching(): boolean
    return autoHatchEnabled
end

function HatchController.GetAutoHatchEggId(): string?
    return autoHatchEggId
end

-- Initialize
function HatchController.Init()
    Network.OnClientEvent("HatchResult", function(results, hatchTime: number, nearMiss: string?, eggId: string?)
        isHatching = false

        if results and #results > 0 then
            playHatchAnimation(results, hatchTime or 1.5, eggId)

            for _, callback in ipairs(resultCallbacks) do
                task.spawn(callback, results)
            end

            -- Near-miss popup: "SO CLOSE to [Legendary Pet]!"
            if nearMiss then
                task.delay((hatchTime or 1.5) + 2, function()
                    local nmGui = Instance.new("ScreenGui")
                    nmGui.Name = "NearMiss"
                    nmGui.DisplayOrder = 110
                    nmGui.IgnoreGuiInset = true
                    nmGui.Parent = playerGui

                    local nmFrame = Instance.new("Frame")
                    nmFrame.Size = UDim2.new(0, 380, 0, 50)
                    nmFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                    nmFrame.Position = UDim2.new(0.5, 0, 0.7, 0)
                    nmFrame.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
                    nmFrame.BackgroundTransparency = 0.1
                    nmFrame.BorderSizePixel = 0
                    nmFrame.Parent = nmGui

                    local nmCorner = Instance.new("UICorner")
                    nmCorner.CornerRadius = UDim.new(0, 12)
                    nmCorner.Parent = nmFrame

                    local nmStroke = Instance.new("UIStroke")
                    nmStroke.Color = Color3.fromRGB(255, 180, 50)
                    nmStroke.Thickness = 2
                    nmStroke.Parent = nmFrame

                    local nmLabel = Instance.new("TextLabel")
                    nmLabel.Size = UDim2.new(1, -20, 1, 0)
                    nmLabel.Position = UDim2.new(0, 10, 0, 0)
                    nmLabel.BackgroundTransparency = 1
                    nmLabel.Text = "SO CLOSE to " .. nearMiss .. "! Try again!"
                    nmLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
                    nmLabel.TextStrokeTransparency = 0
                    nmLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    nmLabel.Font = Enum.Font.GothamBold
                    nmLabel.TextSize = 16
                    nmLabel.Parent = nmFrame

                    -- Slide in from below
                    nmFrame.Position = UDim2.new(0.5, 0, 0.75, 0)
                    nmFrame.BackgroundTransparency = 1
                    nmLabel.TextTransparency = 1
                    nmStroke.Transparency = 1

                    TweenService:Create(nmFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0.5, 0, 0.7, 0),
                        BackgroundTransparency = 0.1,
                    }):Play()
                    TweenService:Create(nmLabel, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
                    TweenService:Create(nmStroke, TweenInfo.new(0.3), { Transparency = 0 }):Play()

                    -- Fade out after 3 seconds
                    task.delay(3, function()
                        TweenService:Create(nmFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
                        TweenService:Create(nmLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
                        TweenService:Create(nmStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
                        task.delay(0.5, function() nmGui:Destroy() end)
                    end)
                end)
            end
        end
    end)
end

return HatchController
