--[[
    SpecialEggGui.client.luau
    Shows announcements when special eggs spawn, a countdown while active,
    and claim notifications.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Main ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpecialEggGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- Spawn banner (slides down from top)
local banner = Instance.new("Frame")
banner.Name = "SpawnBanner"
banner.Size = UDim2.new(0, 400, 0, 60)
banner.Position = UDim2.new(0.5, -200, 0, -70) -- starts offscreen
banner.BackgroundColor3 = Color3.fromRGB(40, 20, 5)
banner.BackgroundTransparency = 0.1
banner.Visible = false
banner.Parent = screenGui

local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 12)
bannerCorner.Parent = banner

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(255, 200, 50)
bannerStroke.Thickness = 2
bannerStroke.Parent = banner

local bannerIcon = Instance.new("TextLabel")
bannerIcon.Size = UDim2.new(0, 40, 1, 0)
bannerIcon.Position = UDim2.new(0, 5, 0, 0)
bannerIcon.BackgroundTransparency = 1
bannerIcon.Text = "🥚"
bannerIcon.TextSize = 28
bannerIcon.Font = Enum.Font.GothamBold
bannerIcon.Parent = banner

local bannerText = Instance.new("TextLabel")
bannerText.Name = "BannerText"
bannerText.Size = UDim2.new(1, -50, 1, 0)
bannerText.Position = UDim2.new(0, 45, 0, 0)
bannerText.BackgroundTransparency = 1
bannerText.Text = ""
bannerText.TextColor3 = Color3.fromRGB(255, 215, 0)
bannerText.Font = Enum.Font.GothamBlack
bannerText.TextSize = 16
bannerText.TextWrapped = true
bannerText.TextXAlignment = Enum.TextXAlignment.Left
bannerText.Parent = banner

-- Corner indicator (shows while egg is active with countdown)
local indicator = Instance.new("Frame")
indicator.Name = "EggIndicator"
indicator.Size = UDim2.new(0, 180, 0, 36)
indicator.Position = UDim2.new(1, -190, 0, 100)
indicator.BackgroundColor3 = Color3.fromRGB(40, 20, 5)
indicator.BackgroundTransparency = 0.2
indicator.Visible = false
indicator.Parent = screenGui

local indicatorCorner = Instance.new("UICorner")
indicatorCorner.CornerRadius = UDim.new(0, 8)
indicatorCorner.Parent = indicator

local indicatorStroke = Instance.new("UIStroke")
indicatorStroke.Color = Color3.fromRGB(255, 180, 30)
indicatorStroke.Thickness = 1
indicatorStroke.Parent = indicator

local indicatorLabel = Instance.new("TextLabel")
indicatorLabel.Name = "IndicatorLabel"
indicatorLabel.Size = UDim2.new(1, -10, 1, 0)
indicatorLabel.Position = UDim2.new(0, 5, 0, 0)
indicatorLabel.BackgroundTransparency = 1
indicatorLabel.Text = ""
indicatorLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
indicatorLabel.Font = Enum.Font.GothamBold
indicatorLabel.TextSize = 13
indicatorLabel.TextXAlignment = Enum.TextXAlignment.Left
indicatorLabel.Parent = indicator

-- State
local eggActive = false
local eggZoneName = ""
local eggSpawnTime = 0
local EGG_DURATION = 45

-- Show the spawn banner with slide-in animation
local function showBanner(zoneName: string)
    bannerText.Text = "Special Egg in " .. zoneName .. "! Hurry!"
    banner.Visible = true
    banner.Position = UDim2.new(0.5, -200, 0, -70)

    -- Slide down
    TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -200, 0, 10),
    }):Play()

    -- Auto-hide after 5 seconds
    task.delay(5, function()
        TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -200, 0, -70),
        }):Play()
        task.delay(0.3, function()
            banner.Visible = false
        end)
    end)
end

-- Update countdown on the indicator
local function startCountdown()
    task.spawn(function()
        while eggActive do
            local remaining = math.max(0, EGG_DURATION - (tick() - eggSpawnTime))
            indicatorLabel.Text = "🥚 " .. eggZoneName .. " - " .. math.ceil(remaining) .. "s"

            -- Pulse effect when running low
            if remaining <= 10 then
                indicatorStroke.Color = Color3.fromRGB(255, 50, 50)
            else
                indicatorStroke.Color = Color3.fromRGB(255, 180, 30)
            end

            if remaining <= 0 then
                eggActive = false
                indicator.Visible = false
                break
            end
            task.wait(1)
        end
    end)
end

-- Network listeners
Network.OnClientEvent("SpecialEggSpawned", function(zoneId: string, zoneName: string, _position)
    eggActive = true
    eggZoneName = zoneName
    eggSpawnTime = tick()

    showBanner(zoneName)

    indicator.Visible = true
    startCountdown()
end)

Network.OnClientEvent("SpecialEggDespawned", function()
    eggActive = false
    indicator.Visible = false
end)

Network.OnClientEvent("SpecialEggClaimed", function(playerName: string, zoneName: string)
    eggActive = false
    indicator.Visible = false

    -- Quick "claimed!" banner
    if playerName == player.Name then
        bannerText.Text = "You got the Special Egg!"
    else
        bannerText.Text = playerName .. " claimed the Special Egg!"
    end
    banner.Visible = true
    banner.Position = UDim2.new(0.5, -200, 0, -70)
    TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -200, 0, 10),
    }):Play()
    task.delay(3, function()
        TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -200, 0, -70),
        }):Play()
        task.delay(0.3, function()
            banner.Visible = false
        end)
    end)
end)
