--[[
    DailyRewardGui.client.luau
    Auto-popup daily reward calendar with streak bonuses.
    Uses loss aversion and escalating rewards to drive daily logins.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
Network.WaitForInit()

local gui = Instance.new("ScreenGui")
gui.Name = "DailyRewardGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- State
local isOpen = false

-- Day reward definitions (matches QuestConfig.LoginStreakRewards)
local REWARDS = {
    { Day = 1, Amount = 100,    Currency = "Coins", Label = "100 Coins" },
    { Day = 2, Amount = 500,    Currency = "Coins", Label = "500 Coins" },
    { Day = 3, Amount = 10,     Currency = "Gems",  Label = "10 Gems" },
    { Day = 4, Amount = 2500,   Currency = "Coins", Label = "2.5K Coins" },
    { Day = 5, Amount = 25,     Currency = "Gems",  Label = "25 Gems" },
    { Day = 6, Amount = 10000,  Currency = "Coins", Label = "10K Coins" },
    { Day = 7, Amount = 100,    Currency = "Gems",  Label = "100 Gems!" },
}

local function createUI()
    -- Overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.4
    overlay.BorderSizePixel = 0
    overlay.Visible = false
    overlay.Parent = gui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 520, 0, 380)
    main.Position = UDim2.new(0.5, -260, 0.5, -190)
    main.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    main.BorderSizePixel = 0
    main.Parent = overlay

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 16)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(255, 200, 50)
    mainStroke.Thickness = 2
    mainStroke.Parent = main

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "DAILY REWARDS"
    title.TextColor3 = Color3.fromRGB(255, 220, 80)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 28
    title.Parent = main

    -- Streak label
    local streakLabel = Instance.new("TextLabel")
    streakLabel.Name = "StreakLabel"
    streakLabel.Size = UDim2.new(1, 0, 0, 25)
    streakLabel.Position = UDim2.new(0, 0, 0, 45)
    streakLabel.BackgroundTransparency = 1
    streakLabel.Text = "Come back daily to keep your streak!"
    streakLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    streakLabel.Font = Enum.Font.Gotham
    streakLabel.TextSize = 14
    streakLabel.Parent = main

    -- Days grid
    local grid = Instance.new("Frame")
    grid.Name = "Grid"
    grid.Size = UDim2.new(1, -40, 0, 180)
    grid.Position = UDim2.new(0, 20, 0, 80)
    grid.BackgroundTransparency = 1
    grid.Parent = main

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 62, 0, 80)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.Parent = grid

    for i, reward in ipairs(REWARDS) do
        local card = Instance.new("Frame")
        card.Name = "Day" .. i
        card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        card.BorderSizePixel = 0
        card.Parent = grid

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Name = "Stroke"
        cardStroke.Color = Color3.fromRGB(80, 80, 100)
        cardStroke.Thickness = 1
        cardStroke.Parent = card

        local dayLabel = Instance.new("TextLabel")
        dayLabel.Size = UDim2.new(1, 0, 0, 20)
        dayLabel.BackgroundTransparency = 1
        dayLabel.Text = "Day " .. i
        dayLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        dayLabel.Font = Enum.Font.GothamBold
        dayLabel.TextSize = 11
        dayLabel.Parent = card

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(1, 0, 0, 30)
        icon.Position = UDim2.new(0, 0, 0, 18)
        icon.BackgroundTransparency = 1
        icon.Text = reward.Currency == "Gems" and "💎" or "💰"
        icon.TextColor3 = Color3.new(1, 1, 1)
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 24
        icon.Parent = card

        local amountLabel = Instance.new("TextLabel")
        amountLabel.Size = UDim2.new(1, 0, 0, 18)
        amountLabel.Position = UDim2.new(0, 0, 1, -20)
        amountLabel.BackgroundTransparency = 1
        amountLabel.Text = reward.Label
        amountLabel.TextColor3 = reward.Currency == "Gems" and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(255, 220, 80)
        amountLabel.Font = Enum.Font.GothamBold
        amountLabel.TextSize = 10
        amountLabel.Parent = card

        -- Checkmark overlay for collected days
        local check = Instance.new("TextLabel")
        check.Name = "Check"
        check.Size = UDim2.new(1, 0, 1, 0)
        check.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        check.BackgroundTransparency = 0.5
        check.Text = "✓"
        check.TextColor3 = Color3.fromRGB(100, 255, 100)
        check.TextSize = 30
        check.Font = Enum.Font.GothamBold
        check.Visible = false
        check.Parent = card

        local checkCorner = Instance.new("UICorner")
        checkCorner.CornerRadius = UDim.new(0, 8)
        checkCorner.Parent = check
    end

    -- Claim button
    local claimBtn = Instance.new("TextButton")
    claimBtn.Name = "ClaimBtn"
    claimBtn.Size = UDim2.new(0, 200, 0, 50)
    claimBtn.Position = UDim2.new(0.5, -100, 1, -70)
    claimBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    claimBtn.Text = "CLAIM REWARD!"
    claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimBtn.Font = Enum.Font.GothamBold
    claimBtn.TextSize = 18
    claimBtn.Parent = main

    local claimCorner = Instance.new("UICorner")
    claimCorner.CornerRadius = UDim.new(0, 12)
    claimCorner.Parent = claimBtn

    -- FOMO warning at bottom
    local warningLabel = Instance.new("TextLabel")
    warningLabel.Name = "Warning"
    warningLabel.Size = UDim2.new(1, -20, 0, 20)
    warningLabel.Position = UDim2.new(0, 10, 1, -25)
    warningLabel.BackgroundTransparency = 1
    warningLabel.Text = "⚠ Missing a day resets your streak!"
    warningLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    warningLabel.Font = Enum.Font.Gotham
    warningLabel.TextSize = 12
    warningLabel.Parent = main

    -- Claim button handler
    claimBtn.MouseButton1Click:Connect(function()
        Network.FireServer("ClaimDailyReward")
        claimBtn.Text = "CLAIMED!"
        claimBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        task.delay(1.5, function()
            overlay.Visible = false
            isOpen = false
        end)
    end)

    -- Close on overlay click
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local pos = input.Position
            local mainAbsPos = main.AbsolutePosition
            local mainAbsSize = main.AbsoluteSize
            if pos.X < mainAbsPos.X or pos.X > mainAbsPos.X + mainAbsSize.X
                or pos.Y < mainAbsPos.Y or pos.Y > mainAbsPos.Y + mainAbsSize.Y then
                overlay.Visible = false
                isOpen = false
            end
        end
    end)

    return overlay
end

local overlay = createUI()

local function showDailyReward(data)
    if isOpen then return end
    isOpen = true

    local streak = data.LoginStreak or 1
    local claimed = data.DailyRewardClaimed or false
    local main = overlay:FindFirstChild("Main")
    if not main then return end

    -- Update streak label
    local streakLabel = main:FindFirstChild("StreakLabel")
    if streakLabel then
        if streak >= 7 then
            streakLabel.Text = "🔥 AMAZING " .. streak .. "-DAY STREAK! Don't break it!"
        elseif streak >= 3 then
            streakLabel.Text = "🔥 " .. streak .. "-day streak! Keep it going!"
        else
            streakLabel.Text = "Come back tomorrow to build your streak!"
        end
    end

    -- Update day cards
    local grid = main:FindFirstChild("Grid")
    if grid then
        for i = 1, 7 do
            local card = grid:FindFirstChild("Day" .. i)
            if card then
                local check = card:FindFirstChild("Check")
                local stroke = card:FindFirstChild("Stroke")
                if i < streak then
                    -- Past day (collected)
                    if check then check.Visible = true end
                    card.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
                elseif i == streak then
                    -- Current day (highlight)
                    card.BackgroundColor3 = Color3.fromRGB(60, 50, 20)
                    if stroke then
                        stroke.Color = Color3.fromRGB(255, 200, 50)
                        stroke.Thickness = 2
                    end
                    if check then check.Visible = claimed end
                else
                    -- Future day
                    card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                end
            end
        end
    end

    -- Update claim button
    local claimBtn = main:FindFirstChild("ClaimBtn")
    if claimBtn then
        if claimed then
            claimBtn.Text = "COME BACK TOMORROW!"
            claimBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        else
            claimBtn.Text = "CLAIM DAY " .. streak .. " REWARD!"
            claimBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)

            -- Pulsing animation for unclaimed
            task.spawn(function()
                while overlay.Visible and not claimed do
                    for t = 0, 1, 0.02 do
                        if not overlay.Visible then break end
                        local s = 1 + math.sin(t * math.pi * 2) * 0.05
                        claimBtn.Size = UDim2.new(0, 200 * s, 0, 50 * s)
                        claimBtn.Position = UDim2.new(0.5, -100 * s, 1, -70)
                        task.wait()
                    end
                end
            end)
        end
    end

    overlay.Visible = true
end

-- Show daily reward popup when streak data arrives (after ProcessLogin has run)
Network.OnClientEvent("DailyRewardData", function(data)
    task.delay(1.5, function()
        showDailyReward(data)
    end)
end)

-- Fallback: also listen on PlayerDataLoaded for reconnects
Network.OnClientEvent("PlayerDataLoaded", function(data)
    task.delay(3, function()
        if not isOpen then
            showDailyReward(data)
        end
    end)
end)

-- Also update when data changes
Network.OnClientEvent("DailyRewardResult", function(result)
    -- Flash a celebratory text
    local celebGui = Instance.new("ScreenGui")
    celebGui.Name = "DailyCelebration"
    celebGui.Parent = playerGui

    local celebLabel = Instance.new("TextLabel")
    celebLabel.Size = UDim2.new(1, 0, 0, 60)
    celebLabel.Position = UDim2.new(0, 0, 0.3, 0)
    celebLabel.BackgroundTransparency = 1
    celebLabel.Text = "DAY " .. result.Day .. " REWARD: +" .. result.RewardAmount .. " " .. result.RewardType .. "!"
    celebLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
    celebLabel.TextStrokeTransparency = 0
    celebLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    celebLabel.Font = Enum.Font.GothamBold
    celebLabel.TextSize = 32
    celebLabel.Parent = celebGui

    task.spawn(function()
        task.wait(2)
        for i = 0, 10 do
            celebLabel.TextTransparency = i / 10
            celebLabel.TextStrokeTransparency = i / 10
            task.wait(0.05)
        end
        celebGui:Destroy()
    end)
end)
