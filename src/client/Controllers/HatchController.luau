--[[
    HatchController.luau (Client)
    Handles hatch requests, animations, and result displays.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EggConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HatchController = {}

local isHatching = false
local resultCallbacks = {}

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

-- Create hatch animation screen
local function playHatchAnimation(results, hatchTime: number)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HatchAnimation"
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 100
    screenGui.Parent = playerGui

    -- Dark overlay
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.4
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui

    -- Egg visual
    local eggFrame = Instance.new("Frame")
    eggFrame.Size = UDim2.new(0, 150, 0, 180)
    eggFrame.Position = UDim2.new(0.5, -75, 0.5, -90)
    eggFrame.BackgroundTransparency = 1
    eggFrame.Parent = screenGui

    local eggImage = Instance.new("Frame")
    eggImage.Size = UDim2.new(1, 0, 1, 0)
    eggImage.BackgroundColor3 = Color3.fromRGB(255, 240, 200)
    eggImage.Parent = eggFrame

    local eggCorner = Instance.new("UICorner")
    eggCorner.CornerRadius = UDim.new(0.4, 0)
    eggCorner.Parent = eggImage

    -- "Hatching..." text
    local hatchText = Instance.new("TextLabel")
    hatchText.Size = UDim2.new(0, 300, 0, 50)
    hatchText.Position = UDim2.new(0.5, -150, 0.3, -60)
    hatchText.BackgroundTransparency = 1
    hatchText.Text = "Hatching..."
    hatchText.TextColor3 = Color3.new(1, 1, 1)
    hatchText.Font = Enum.Font.GothamBold
    hatchText.TextSize = 36
    hatchText.TextStrokeTransparency = 0
    hatchText.Parent = screenGui

    -- Shaking animation
    local shakeCount = math.floor(hatchTime / 0.3)
    task.spawn(function()
        for i = 1, shakeCount do
            local intensity = i / shakeCount * 15
            local tween = TweenService:Create(eggFrame, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Rotation = intensity
            })
            tween:Play()
            tween.Completed:Wait()

            tween = TweenService:Create(eggFrame, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Rotation = -intensity
            })
            tween:Play()
            tween.Completed:Wait()
        end

        -- Crack open - flash
        local flash = Instance.new("Frame")
        flash.Size = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3 = Color3.new(1, 1, 1)
        flash.BackgroundTransparency = 0
        flash.BorderSizePixel = 0
        flash.ZIndex = 10
        flash.Parent = screenGui

        local fadeTween = TweenService:Create(flash, TweenInfo.new(0.5), {
            BackgroundTransparency = 1
        })
        fadeTween:Play()

        -- Hide egg
        eggFrame.Visible = false
        hatchText.Text = ""

        -- Show results
        task.wait(0.3)

        local resultContainer = Instance.new("Frame")
        resultContainer.Size = UDim2.new(0, #results * 200, 0, 280)
        resultContainer.Position = UDim2.new(0.5, -(#results * 200) / 2, 0.5, -140)
        resultContainer.BackgroundTransparency = 1
        resultContainer.Parent = screenGui

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Padding = UDim.new(0, 20)
        layout.Parent = resultContainer

        for _, result in ipairs(results) do
            local card = Instance.new("Frame")
            card.Size = UDim2.new(0, 170, 0, 260)
            card.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
            card.BorderSizePixel = 0
            card.Parent = resultContainer

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 12)
            cardCorner.Parent = card

            -- Rarity glow border
            local rarityInfo = RarityConfig.Tiers[result.Rarity]
            local stroke = Instance.new("UIStroke")
            stroke.Color = rarityInfo and rarityInfo.GlowColor or Color3.new(1, 1, 1)
            stroke.Thickness = 3
            stroke.Parent = card

            -- Pet visual placeholder
            local petVisual = Instance.new("Frame")
            petVisual.Size = UDim2.new(0.8, 0, 0, 100)
            petVisual.Position = UDim2.new(0.1, 0, 0, 20)
            petVisual.BackgroundColor3 = rarityInfo and rarityInfo.Color or Color3.new(0.5, 0.5, 0.5)
            petVisual.Parent = card

            local pvCorner = Instance.new("UICorner")
            pvCorner.CornerRadius = UDim.new(0.5, 0)
            pvCorner.Parent = petVisual

            -- Variant indicator
            if result.Golden or result.Rainbow then
                local variantLabel = Instance.new("TextLabel")
                variantLabel.Size = UDim2.new(1, 0, 0, 20)
                variantLabel.Position = UDim2.new(0, 0, 0, 125)
                variantLabel.BackgroundTransparency = 1
                variantLabel.Font = Enum.Font.GothamBold
                variantLabel.TextSize = 14
                variantLabel.TextStrokeTransparency = 0
                variantLabel.Parent = card

                if result.Rainbow then
                    variantLabel.Text = "🌈 RAINBOW 🌈"
                    variantLabel.TextColor3 = Color3.fromRGB(255, 100, 255)
                elseif result.Golden then
                    variantLabel.Text = "✨ GOLDEN ✨"
                    variantLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                end
            end

            -- Pet name
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0, 30)
            nameLabel.Position = UDim2.new(0, 0, 0, 150)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = result.Name
            nameLabel.TextColor3 = Color3.new(1, 1, 1)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextSize = 18
            nameLabel.TextStrokeTransparency = 0
            nameLabel.Parent = card

            -- Rarity label
            local rarityLabel = Instance.new("TextLabel")
            rarityLabel.Size = UDim2.new(1, 0, 0, 24)
            rarityLabel.Position = UDim2.new(0, 0, 0, 180)
            rarityLabel.BackgroundTransparency = 1
            rarityLabel.Text = result.Rarity
            rarityLabel.TextColor3 = rarityInfo and rarityInfo.TextColor or Color3.new(1, 1, 1)
            rarityLabel.Font = Enum.Font.GothamBold
            rarityLabel.TextSize = 16
            rarityLabel.TextStrokeTransparency = 0
            rarityLabel.Parent = card

            -- Power label
            local powerLabel = Instance.new("TextLabel")
            powerLabel.Size = UDim2.new(1, 0, 0, 20)
            powerLabel.Position = UDim2.new(0, 0, 0, 210)
            powerLabel.BackgroundTransparency = 1
            powerLabel.Text = "Power: " .. tostring(result.Power)
            powerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            powerLabel.Font = Enum.Font.Gotham
            powerLabel.TextSize = 14
            powerLabel.Parent = card

            -- Pop-in animation
            card.Size = UDim2.new(0, 0, 0, 0)
            local popTween = TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 170, 0, 260)
            })
            popTween:Play()
        end

        -- Tap to close text
        local closeText = Instance.new("TextLabel")
        closeText.Size = UDim2.new(0, 300, 0, 30)
        closeText.Position = UDim2.new(0.5, -150, 0.85, 0)
        closeText.BackgroundTransparency = 1
        closeText.Text = "Tap anywhere to close"
        closeText.TextColor3 = Color3.fromRGB(200, 200, 200)
        closeText.Font = Enum.Font.Gotham
        closeText.TextSize = 18
        closeText.Parent = screenGui

        -- Close on click
        local closeButton = Instance.new("TextButton")
        closeButton.Size = UDim2.new(1, 0, 1, 0)
        closeButton.BackgroundTransparency = 1
        closeButton.Text = ""
        closeButton.ZIndex = 5
        closeButton.Parent = screenGui

        closeButton.MouseButton1Click:Connect(function()
            screenGui:Destroy()
        end)

        -- Auto close after 5 seconds
        task.delay(5, function()
            if screenGui.Parent then
                screenGui:Destroy()
            end
        end)
    end)
end

-- Initialize
function HatchController.Init()
    Network.OnClientEvent("HatchResult", function(results, hatchTime: number)
        isHatching = false

        if results and #results > 0 then
            playHatchAnimation(results, hatchTime or 2)

            for _, callback in ipairs(resultCallbacks) do
                task.spawn(callback, results)
            end
        end
    end)
end

return HatchController
