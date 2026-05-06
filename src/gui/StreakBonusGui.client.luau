--[[
    StreakBonusGui.client.luau
    Ambient overlay providing:
    - Real server-broadcast hatch announcements (ticker)
    - Login streak reminder
    - Hatch progress reward bar (real server reward)
    - Achievement celebration popups
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local NumberFormat = require(Shared:WaitForChild("Utils"):WaitForChild("NumberFormat"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StreakBonusGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 30
screenGui.Parent = playerGui

-- ═══════════════════════════════════════
-- SOCIAL PROOF TICKER (Top of screen)
-- People hatching rare pets = makes you want to hatch too
-- ═══════════════════════════════════════

local tickerBar = Instance.new("Frame")
tickerBar.Size = UDim2.new(1, 0, 0, 22)
tickerBar.Position = UDim2.new(0, 0, 0, 0)
tickerBar.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
tickerBar.BackgroundTransparency = 0.3
tickerBar.BorderSizePixel = 0
tickerBar.ZIndex = 5
tickerBar.Parent = screenGui

local tickerLabel = Instance.new("TextLabel")
tickerLabel.Size = UDim2.new(2, 0, 1, 0)
tickerLabel.Position = UDim2.new(1, 0, 0, 0)
tickerLabel.BackgroundTransparency = 1
tickerLabel.Text = ""
tickerLabel.TextColor3 = Color3.new(1, 1, 1)
tickerLabel.Font = Enum.Font.GothamBold
tickerLabel.TextSize = 11
tickerLabel.TextXAlignment = Enum.TextXAlignment.Left
tickerLabel.ZIndex = 6
tickerLabel.Parent = tickerBar

local tickerQueue = {}
local isTickerAnimating = false

local function queueTicker(message)
    table.insert(tickerQueue, message)
end

-- Only real server-broadcast announcements populate the ticker.
Network.OnClientEvent("ServerAnnouncement", function(message)
    queueTicker(message)
end)

-- Animate ticker across screen
task.spawn(function()
    while true do
        if #tickerQueue > 0 and not isTickerAnimating then
            isTickerAnimating = true
            local msg = table.remove(tickerQueue, 1)
            tickerLabel.Text = msg
            tickerLabel.Position = UDim2.new(1, 0, 0, 0)

            local tween = TweenService:Create(tickerLabel, TweenInfo.new(8, Enum.EasingStyle.Linear), {
                Position = UDim2.new(-2, 0, 0, 0),
            })
            tween:Play()
            tween.Completed:Wait()
            isTickerAnimating = false
        end
        task.wait(0.5)
    end
end)

-- Flash sale popup removed: countdown timers for deals that had no
-- server-side fulfilment are a Roblox policy violation (deceptive advertising).

-- ═══════════════════════════════════════
-- STREAK RISK WARNING (Loss aversion)
-- "Your 7-day streak is at risk! Play now!"
-- ═══════════════════════════════════════

local streakWarning = Instance.new("Frame")
streakWarning.Size = UDim2.new(0, 300, 0, 50)
streakWarning.Position = UDim2.new(0.5, -150, 1, 10) -- Start offscreen bottom
streakWarning.BackgroundColor3 = Color3.fromRGB(255, 60, 20)
streakWarning.BorderSizePixel = 0
streakWarning.ZIndex = 15
streakWarning.Parent = screenGui

local swCorner = Instance.new("UICorner")
swCorner.CornerRadius = UDim.new(0, 10)
swCorner.Parent = streakWarning

local streakIcon = Instance.new("TextLabel")
streakIcon.Size = UDim2.new(0, 40, 1, 0)
streakIcon.BackgroundTransparency = 1
streakIcon.Text = "🔥"
streakIcon.TextSize = 24
streakIcon.ZIndex = 16
streakIcon.Parent = streakWarning

local streakText = Instance.new("TextLabel")
streakText.Size = UDim2.new(1, -50, 1, 0)
streakText.Position = UDim2.new(0, 40, 0, 0)
streakText.BackgroundTransparency = 1
streakText.Text = ""
streakText.TextColor3 = Color3.new(1, 1, 1)
streakText.Font = Enum.Font.GothamBold
streakText.TextSize = 12
streakText.TextWrapped = true
streakText.TextXAlignment = Enum.TextXAlignment.Left
streakText.ZIndex = 16
streakText.Parent = streakWarning

Network.OnClientEvent("DailyRewardData", function(data)
    local streak = data.LoginStreak or 0
    if streak >= 3 then
        streakText.Text = string.format("🔥 %d-day streak! Come back tomorrow to keep it!", streak)
        task.wait(5)
        -- Slide up
        TweenService:Create(streakWarning, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
            Position = UDim2.new(0.5, -150, 1, -60),
        }):Play()
        task.wait(6)
        -- Slide away
        TweenService:Create(streakWarning, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -150, 1, 10),
        }):Play()
    end
end)

-- ═══════════════════════════════════════
-- PROGRESS BAR THAT'S ALMOST FULL (Endowed progress effect)
-- "You're 87% to your next reward!" — makes them keep playing
-- ═══════════════════════════════════════

local progressPopup = Instance.new("Frame")
progressPopup.Size = UDim2.new(0, 260, 0, 65)
progressPopup.Position = UDim2.new(0, -270, 0.3, 0) -- Start offscreen left
progressPopup.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
progressPopup.BorderSizePixel = 0
progressPopup.ZIndex = 15
progressPopup.Parent = screenGui

local ppCorner = Instance.new("UICorner")
ppCorner.CornerRadius = UDim.new(0, 10)
ppCorner.Parent = progressPopup

local ppStroke = Instance.new("UIStroke")
ppStroke.Color = Color3.fromRGB(100, 255, 100)
ppStroke.Thickness = 1.5
ppStroke.Parent = progressPopup

local ppTitle = Instance.new("TextLabel")
ppTitle.Size = UDim2.new(1, -8, 0, 18)
ppTitle.Position = UDim2.new(0, 4, 0, 2)
ppTitle.BackgroundTransparency = 1
ppTitle.Text = "Next Reward Progress"
ppTitle.TextColor3 = Color3.fromRGB(100, 255, 100)
ppTitle.Font = Enum.Font.GothamBold
ppTitle.TextSize = 10
ppTitle.TextXAlignment = Enum.TextXAlignment.Left
ppTitle.ZIndex = 16
ppTitle.Parent = progressPopup

local ppBarBg = Instance.new("Frame")
ppBarBg.Size = UDim2.new(1, -16, 0, 16)
ppBarBg.Position = UDim2.new(0, 8, 0, 22)
ppBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
ppBarBg.BorderSizePixel = 0
ppBarBg.ZIndex = 16
ppBarBg.Parent = progressPopup

local ppBarCorner = Instance.new("UICorner")
ppBarCorner.CornerRadius = UDim.new(0, 6)
ppBarCorner.Parent = ppBarBg

local ppBarFill = Instance.new("Frame")
ppBarFill.Size = UDim2.new(0, 0, 1, 0)
ppBarFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
ppBarFill.BorderSizePixel = 0
ppBarFill.ZIndex = 17
ppBarFill.Parent = ppBarBg

local ppFillCorner = Instance.new("UICorner")
ppFillCorner.CornerRadius = UDim.new(0, 6)
ppFillCorner.Parent = ppBarFill

local ppPercent = Instance.new("TextLabel")
ppPercent.Size = UDim2.new(1, 0, 1, 0)
ppPercent.BackgroundTransparency = 1
ppPercent.Text = "0%"
ppPercent.TextColor3 = Color3.new(1, 1, 1)
ppPercent.Font = Enum.Font.GothamBold
ppPercent.TextSize = 10
ppPercent.ZIndex = 18
ppPercent.Parent = ppBarBg

local ppHint = Instance.new("TextLabel")
ppHint.Size = UDim2.new(1, -8, 0, 16)
ppHint.Position = UDim2.new(0, 4, 0, 42)
ppHint.BackgroundTransparency = 1
ppHint.Text = "Hatch 2 more eggs to claim!"
ppHint.TextColor3 = Color3.fromRGB(200, 200, 200)
ppHint.Font = Enum.Font.Gotham
ppHint.TextSize = 9
ppHint.TextXAlignment = Enum.TextXAlignment.Left
ppHint.ZIndex = 16
ppHint.Parent = progressPopup

-- Show progress popup after hatching (start high to make them feel close)
local eggsHatched = 0
local EGGS_FOR_REWARD = 5

Network.OnClientEvent("HatchResult", function()
    eggsHatched = eggsHatched + 1
    local progress = math.min(eggsHatched / EGGS_FOR_REWARD, 1)
    local percent = math.floor(progress * 100)

    ppPercent.Text = percent .. "%"
    ppHint.Text = eggsHatched >= EGGS_FOR_REWARD
        and "REWARD READY! Open inventory!"
        or string.format("Hatch %d more eggs to claim!", EGGS_FOR_REWARD - eggsHatched)

    -- Slide in
    TweenService:Create(progressPopup, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
        Position = UDim2.new(0, 10, 0.3, 0),
    }):Play()

    -- Animate bar fill
    TweenService:Create(ppBarFill, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(progress, 0, 1, 0),
    }):Play()

    if percent >= 100 then
        ppBarFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        ppPercent.TextColor3 = Color3.fromRGB(255, 215, 0)
        ppTitle.Text = "REWARD READY!"
        ppTitle.TextColor3 = Color3.fromRGB(255, 215, 0)

        -- Claim and reset
        task.delay(3, function()
            Network.FireServer("ClaimProgressReward")
            eggsHatched = 0
            ppBarFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
            ppTitle.Text = "Next Reward Progress"
            ppTitle.TextColor3 = Color3.fromRGB(100, 255, 100)
        end)
    end

    -- Slide out after delay
    task.delay(4, function()
        TweenService:Create(progressPopup, TweenInfo.new(0.3), {
            Position = UDim2.new(0, -270, 0.3, 0),
        }):Play()
    end)
end)

-- ═══════════════════════════════════════
-- ACHIEVEMENT POPUP (Big celebration)
-- ═══════════════════════════════════════

local achievePopup = Instance.new("Frame")
achievePopup.Size = UDim2.new(0, 350, 0, 80)
achievePopup.Position = UDim2.new(0.5, -175, 0, -90) -- Start offscreen top
achievePopup.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
achievePopup.BorderSizePixel = 0
achievePopup.ZIndex = 25
achievePopup.Parent = screenGui

local apCorner = Instance.new("UICorner")
apCorner.CornerRadius = UDim.new(0, 12)
apCorner.Parent = achievePopup

local apStroke = Instance.new("UIStroke")
apStroke.Color = Color3.fromRGB(255, 215, 0)
apStroke.Thickness = 2
apStroke.Parent = achievePopup

local apTitle = Instance.new("TextLabel")
apTitle.Size = UDim2.new(1, 0, 0, 28)
apTitle.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
apTitle.Text = "ACHIEVEMENT UNLOCKED!"
apTitle.TextColor3 = Color3.fromRGB(20, 20, 40)
apTitle.Font = Enum.Font.GothamBold
apTitle.TextSize = 14
apTitle.ZIndex = 26
apTitle.Parent = achievePopup

local apCorner2 = Instance.new("UICorner")
apCorner2.CornerRadius = UDim.new(0, 12)
apCorner2.Parent = apTitle

local apDesc = Instance.new("TextLabel")
apDesc.Size = UDim2.new(1, -10, 0, 40)
apDesc.Position = UDim2.new(0, 5, 0, 32)
apDesc.BackgroundTransparency = 1
apDesc.Text = ""
apDesc.TextColor3 = Color3.new(1, 1, 1)
apDesc.Font = Enum.Font.GothamBold
apDesc.TextSize = 16
apDesc.ZIndex = 26
apDesc.Parent = achievePopup

Network.OnClientEvent("AchievementUnlocked", function(name, description)
    apDesc.Text = (name or "Achievement") .. "\n" .. (description or "")

    -- Slide down
    TweenService:Create(achievePopup, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -175, 0, 30),
    }):Play()

    task.wait(4)

    -- Slide up
    TweenService:Create(achievePopup, TweenInfo.new(0.3), {
        Position = UDim2.new(0.5, -175, 0, -90),
    }):Play()
end)

print("[GUI] StreakBonusGui loaded")
