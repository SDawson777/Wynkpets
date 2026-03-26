-- ShopController.luau
-- Client-side shop UI: in-game items, tools, world unlocks, daily reward.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData    = require(script.Parent.ClientData)
local FormatNumber  = require(ReplicatedStorage.Shared.Modules.FormatNumber)
local ShopConfig    = require(ReplicatedStorage.Shared.Config.ShopConfig)
local MiningConfig  = require(ReplicatedStorage.Shared.Config.MiningConfig)
local WorldConfig   = require(ReplicatedStorage.Shared.Config.WorldConfig)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Events      = ReplicatedStorage.Shared.Remotes.Events

local ShopController = {}

-- ─── Build Shop GUI ──────────────────────────────────────────────────────────

local function buildShopGui()
    local screenGui        = Instance.new("ScreenGui")
    screenGui.Name         = "ShopGui"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled      = false
    screenGui.Parent       = PlayerGui

    local mainFrame            = Instance.new("Frame")
    mainFrame.Name             = "MainFrame"
    mainFrame.Size             = UDim2.new(0, 540, 0, 460)
    mainFrame.Position         = UDim2.new(0.5, -270, 0.5, -230)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel  = 0
    mainFrame.Parent           = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

    local title       = Instance.new("TextLabel")
    title.Size        = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text        = "🏪 Shop"
    title.TextColor3  = Color3.fromRGB(255, 255, 255)
    title.TextScaled  = true
    title.Font        = Enum.Font.GothamBold
    title.Parent      = mainFrame

    local closeBtn    = Instance.new("TextButton")
    closeBtn.Size     = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -40, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text     = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font     = Enum.Font.GothamBold
    closeBtn.Parent   = mainFrame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

    -- Tab buttons
    local tabs = { "Tools", "Boosts", "Worlds" }
    local tabFrames = {}
    local tabBtns   = {}

    local tabBar = Instance.new("Frame")
    tabBar.Size  = UDim2.new(1, 0, 0, 36)
    tabBar.Position = UDim2.new(0, 0, 0, 42)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = mainFrame

    local tabLayout = Instance.new("UIListLayout", tabBar)
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 4)

    for _, tabName in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size  = UDim2.new(0, 110, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        btn.BorderSizePixel = 0
        btn.Text  = tabName
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextScaled = true
        btn.Font  = Enum.Font.GothamBold
        btn.Parent = tabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        tabBtns[tabName] = btn

        local frame = Instance.new("ScrollingFrame")
        frame.Name  = tabName .. "Frame"
        frame.Size  = UDim2.new(1, -16, 1, -88)
        frame.Position = UDim2.new(0, 8, 0, 84)
        frame.BackgroundTransparency = 1
        frame.ScrollBarThickness = 6
        frame.CanvasSize = UDim2.new(0, 0, 0, 0)
        frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        frame.Visible = false
        frame.Parent  = mainFrame
        local listLayout = Instance.new("UIListLayout", frame)
        listLayout.Padding = UDim.new(0, 6)
        Instance.new("UIPadding", frame).PaddingLeft = UDim.new(0, 4)
        tabFrames[tabName] = frame
    end

    -- Show first tab
    local function showTab(name: string)
        for t, f in pairs(tabFrames) do
            f.Visible = (t == name)
            tabBtns[t].BackgroundColor3 = (t == name)
                and Color3.fromRGB(100, 60, 200)
                or  Color3.fromRGB(50, 50, 70)
        end
    end
    showTab("Tools")

    for tabName, btn in pairs(tabBtns) do
        btn.MouseButton1Click:Connect(function() showTab(tabName) end)
    end

    -- ── Tools tab ─────────────────────────────────────────────────────────────
    local toolsFrame = tabFrames["Tools"]
    for _, tool in ipairs(MiningConfig.Tools) do
        if tool.price == 0 then continue end  -- skip free starting tool
        local row = Instance.new("Frame")
        row.Size  = UDim2.new(1, -8, 0, 58)
        row.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        row.BorderSizePixel = 0
        row.Parent = toolsFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local nameL = Instance.new("TextLabel")
        nameL.Size  = UDim2.new(0.6, 0, 0.5, 0)
        nameL.Position = UDim2.new(0, 8, 0, 4)
        nameL.BackgroundTransparency = 1
        nameL.Text  = tool.name .. " (⛏×" .. tool.damage .. ")"
        nameL.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameL.TextScaled = true
        nameL.Font  = Enum.Font.GothamBold
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.Parent = row

        local costL = Instance.new("TextLabel")
        costL.Size  = UDim2.new(0.6, 0, 0.4, 0)
        costL.Position = UDim2.new(0, 8, 0.5, 2)
        costL.BackgroundTransparency = 1
        local costIcon = tool.currency == "Gems" and "💎" or "🪙"
        costL.Text  = costIcon .. " " .. FormatNumber.format(tool.price)
        costL.TextColor3 = Color3.fromRGB(180, 220, 255)
        costL.TextScaled = true
        costL.Font  = Enum.Font.Gotham
        costL.TextXAlignment = Enum.TextXAlignment.Left
        costL.Parent = row

        local buyBtn = Instance.new("TextButton")
        buyBtn.Size  = UDim2.new(0, 90, 0, 34)
        buyBtn.Position = UDim2.new(1, -98, 0.5, -17)
        buyBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 50)
        buyBtn.BorderSizePixel  = 0
        buyBtn.Text  = "Buy"
        buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyBtn.TextScaled = true
        buyBtn.Font  = Enum.Font.GothamBold
        buyBtn.Parent = row
        Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 6)

        local toolId = tool.id
        buyBtn.MouseButton1Click:Connect(function()
            Events.PurchaseShopItem:FireServer(toolId)
        end)
    end

    -- ── Boosts tab ────────────────────────────────────────────────────────────
    local boostsFrame = tabFrames["Boosts"]
    local allBoosts   = {}
    for _, item in ipairs(ShopConfig.CoinItems) do table.insert(allBoosts, item) end
    for _, item in ipairs(ShopConfig.GemItems)  do table.insert(allBoosts, item) end

    for _, item in ipairs(allBoosts) do
        local row = Instance.new("Frame")
        row.Size  = UDim2.new(1, -8, 0, 58)
        row.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        row.BorderSizePixel  = 0
        row.Parent = boostsFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local nameL = Instance.new("TextLabel")
        nameL.Size  = UDim2.new(0.6, 0, 0.5, 0)
        nameL.Position = UDim2.new(0, 8, 0, 4)
        nameL.BackgroundTransparency = 1
        nameL.Text  = item.name
        nameL.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameL.TextScaled = true
        nameL.Font  = Enum.Font.GothamBold
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.Parent = row

        local costL = Instance.new("TextLabel")
        costL.Size  = UDim2.new(0.6, 0, 0.4, 0)
        costL.Position = UDim2.new(0, 8, 0.5, 2)
        costL.BackgroundTransparency = 1
        local costText = item.coinCost and ("🪙 " .. FormatNumber.format(item.coinCost))
            or ("💎 " .. FormatNumber.format(item.gemCost))
        costL.Text  = costText
        costL.TextColor3 = Color3.fromRGB(180, 220, 255)
        costL.TextScaled = true
        costL.Font  = Enum.Font.Gotham
        costL.TextXAlignment = Enum.TextXAlignment.Left
        costL.Parent = row

        local buyBtn = Instance.new("TextButton")
        buyBtn.Size  = UDim2.new(0, 90, 0, 34)
        buyBtn.Position = UDim2.new(1, -98, 0.5, -17)
        buyBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 220)
        buyBtn.BorderSizePixel  = 0
        buyBtn.Text  = "Buy"
        buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyBtn.TextScaled = true
        buyBtn.Font  = Enum.Font.GothamBold
        buyBtn.Parent = row
        Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 6)

        local itemId = item.id
        buyBtn.MouseButton1Click:Connect(function()
            Events.PurchaseShopItem:FireServer(itemId)
        end)
    end

    -- ── Worlds tab ────────────────────────────────────────────────────────────
    local worldsFrame = tabFrames["Worlds"]
    for _, world in ipairs(WorldConfig.Worlds) do
        if world.id == 1 then continue end  -- skip starter, always free
        local row = Instance.new("Frame")
        row.Size  = UDim2.new(1, -8, 0, 68)
        row.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        row.BorderSizePixel  = 0
        row.Parent = worldsFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        -- Color stripe
        local stripe = Instance.new("Frame")
        stripe.Size  = UDim2.new(0, 6, 1, 0)
        stripe.BackgroundColor3 = world.colorTheme
        stripe.BorderSizePixel  = 0
        stripe.Parent = row
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 4)

        local nameL = Instance.new("TextLabel")
        nameL.Size  = UDim2.new(0.6, 0, 0.45, 0)
        nameL.Position = UDim2.new(0, 14, 0, 4)
        nameL.BackgroundTransparency = 1
        nameL.Text  = world.name
        nameL.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameL.TextScaled = true
        nameL.Font  = Enum.Font.GothamBold
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.Parent = row

        local descL = Instance.new("TextLabel")
        descL.Size  = UDim2.new(0.6, 0, 0.35, 0)
        descL.Position = UDim2.new(0, 14, 0.45, 2)
        descL.BackgroundTransparency = 1
        descL.Text  = world.description
        descL.TextColor3 = Color3.fromRGB(160, 160, 190)
        descL.TextScaled = true
        descL.Font  = Enum.Font.Gotham
        descL.TextXAlignment = Enum.TextXAlignment.Left
        descL.Parent = row

        local costIcon = world.currency == "Gems" and "💎" or "🪙"
        local costL = Instance.new("TextLabel")
        costL.Size  = UDim2.new(0.6, 0, 0.25, 0)
        costL.Position = UDim2.new(0, 14, 0.75, 0)
        costL.BackgroundTransparency = 1
        costL.Text  = costIcon .. " " .. FormatNumber.format(world.unlockCost)
            .. "  (Rebirth " .. world.rebirthRequired .. "+)"
        costL.TextColor3 = Color3.fromRGB(180, 220, 255)
        costL.TextScaled = true
        costL.Font  = Enum.Font.Gotham
        costL.TextXAlignment = Enum.TextXAlignment.Left
        costL.Parent = row

        local unlockBtn = Instance.new("TextButton")
        unlockBtn.Size  = UDim2.new(0, 90, 0, 40)
        unlockBtn.Position = UDim2.new(1, -98, 0.5, -20)
        unlockBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 200)
        unlockBtn.BorderSizePixel  = 0
        unlockBtn.Text  = "Unlock"
        unlockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        unlockBtn.TextScaled = true
        unlockBtn.Font  = Enum.Font.GothamBold
        unlockBtn.Parent = row
        Instance.new("UICorner", unlockBtn).CornerRadius = UDim.new(0, 6)

        local worldId = world.id
        unlockBtn.MouseButton1Click:Connect(function()
            Events.UnlockWorld:FireServer(worldId)
        end)
    end

    ShopController.shopGui = screenGui
end

-- ─── Build Rebirth GUI ────────────────────────────────────────────────────────

local function buildRebirthGui()
    local screenGui        = Instance.new("ScreenGui")
    screenGui.Name         = "RebirthGui"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled      = false
    screenGui.Parent       = PlayerGui

    local mainFrame            = Instance.new("Frame")
    mainFrame.Size             = UDim2.new(0, 380, 0, 260)
    mainFrame.Position         = UDim2.new(0.5, -190, 0.5, -130)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel  = 0
    mainFrame.Parent           = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size  = UDim2.new(1, 0, 0, 44)
    title.BackgroundTransparency = 1
    title.Text  = "🌟 Rebirth"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.TextScaled = true
    title.Font  = Enum.Font.GothamBold
    title.Parent = mainFrame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size  = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -40, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel  = 0
    closeBtn.Text  = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font  = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name  = "InfoLabel"
    infoLabel.Size  = UDim2.new(1, -16, 0, 80)
    infoLabel.Position = UDim2.new(0, 8, 0, 50)
    infoLabel.BackgroundTransparency = 1
    infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    infoLabel.TextScaled = true
    infoLabel.Font  = Enum.Font.Gotham
    infoLabel.TextWrapped = true
    infoLabel.Text  = "Rebirths reset your world & coins\nbut keep pets, gems, and gamepasses.\nEach rebirth gives +0.1× permanent bonus."
    infoLabel.Parent = mainFrame

    local costLabel = Instance.new("TextLabel")
    costLabel.Name  = "CostLabel"
    costLabel.Size  = UDim2.new(1, -16, 0, 36)
    costLabel.Position = UDim2.new(0, 8, 0, 136)
    costLabel.BackgroundTransparency = 1
    costLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    costLabel.TextScaled = true
    costLabel.Font  = Enum.Font.GothamBold
    costLabel.Text  = "Cost: calculating..."
    costLabel.Parent = mainFrame

    local rebirthBtn = Instance.new("TextButton")
    rebirthBtn.Size  = UDim2.new(0, 200, 0, 50)
    rebirthBtn.Position = UDim2.new(0.5, -100, 1, -62)
    rebirthBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
    rebirthBtn.BorderSizePixel  = 0
    rebirthBtn.Text  = "REBIRTH NOW"
    rebirthBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
    rebirthBtn.TextScaled = true
    rebirthBtn.Font  = Enum.Font.GothamBold
    rebirthBtn.Parent = mainFrame
    Instance.new("UICorner", rebirthBtn).CornerRadius = UDim.new(0, 8)

    rebirthBtn.MouseButton1Click:Connect(function()
        Events.RequestRebirth:FireServer()
    end)

    -- Update cost label from data
    ClientData.onUpdate(function(data)
        if not data then return end
        local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
        local cost = math.floor(
            EconomyConfig.BaseRebirthCost * (EconomyConfig.RebirthCostScale ^ data.Rebirths)
        )
        costLabel.Text = "Cost: 🪙 " .. FormatNumber.format(cost)
            .. "   (Rebirth #" .. (data.Rebirths + 1) .. ")"
    end)
end

-- ─── Build Quest GUI ─────────────────────────────────────────────────────────

local function buildQuestGui()
    local screenGui        = Instance.new("ScreenGui")
    screenGui.Name         = "QuestGui"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled      = false
    screenGui.Parent       = PlayerGui

    local mainFrame            = Instance.new("Frame")
    mainFrame.Size             = UDim2.new(0, 460, 0, 440)
    mainFrame.Position         = UDim2.new(0.5, -230, 0.5, -220)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel  = 0
    mainFrame.Parent           = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size  = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text  = "📋 Quests & Achievements"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font  = Enum.Font.GothamBold
    title.Parent = mainFrame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size  = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -40, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text  = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font  = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name  = "QuestScroll"
    scroll.Size  = UDim2.new(1, -16, 1, -48)
    scroll.Position = UDim2.new(0, 8, 0, 44)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = mainFrame
    local listLayout = Instance.new("UIListLayout", scroll)
    listLayout.Padding = UDim.new(0, 6)
    Instance.new("UIPadding", scroll).PaddingLeft = UDim.new(0, 4)

    ShopController.questScroll = scroll
    ShopController.questGui    = screenGui

    -- Subscribe to quest updates
    local function updateQuests()
        local data = ClientData.data
        if not data then return end

        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
        for _, q in ipairs(QuestConfig.Quests) do
            local completed = (q.type == "achievement" and data.AchievementsCompleted[q.id])
                or (q.type ~= "achievement" and
                    (data.Stats[q.goal.stat] or 0) >= q.goal.amount and
                    data.QuestProgress[q.id .. "_rewarded"])

            local row = Instance.new("Frame")
            row.Size  = UDim2.new(1, -8, 0, 60)
            row.BackgroundColor3 = completed
                and Color3.fromRGB(30, 60, 30)
                or  Color3.fromRGB(40, 40, 55)
            row.BorderSizePixel = 0
            row.Parent = scroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

            local typeIcon = q.type == "daily" and "📅"
                or q.type == "weekly" and "📆"
                or "🏆"

            local nameL = Instance.new("TextLabel")
            nameL.Size  = UDim2.new(0.75, 0, 0.5, 0)
            nameL.Position = UDim2.new(0, 8, 0, 4)
            nameL.BackgroundTransparency = 1
            nameL.Text  = typeIcon .. " " .. q.name
            nameL.TextColor3 = completed
                and Color3.fromRGB(100, 220, 100)
                or  Color3.fromRGB(255, 255, 255)
            nameL.TextScaled = true
            nameL.Font  = Enum.Font.GothamBold
            nameL.TextXAlignment = Enum.TextXAlignment.Left
            nameL.Parent = row

            local progress = data.Stats[q.goal.stat] or 0
            local progL = Instance.new("TextLabel")
            progL.Size  = UDim2.new(0.75, 0, 0.4, 0)
            progL.Position = UDim2.new(0, 8, 0.5, 2)
            progL.BackgroundTransparency = 1
            progL.Text  = completed
                and "✅ Complete"
                or  ("%d / %d"):format(math.min(progress, q.goal.amount), q.goal.amount)
            progL.TextColor3 = Color3.fromRGB(180, 180, 220)
            progL.TextScaled = true
            progL.Font  = Enum.Font.Gotham
            progL.TextXAlignment = Enum.TextXAlignment.Left
            progL.Parent = row

            local rewardL = Instance.new("TextLabel")
            rewardL.Size  = UDim2.new(0.25, -8, 1, 0)
            rewardL.Position = UDim2.new(0.75, 4, 0, 0)
            rewardL.BackgroundTransparency = 1
            local rewardParts = {}
            if (q.reward.coins or 0) > 0 then
                table.insert(rewardParts, "🪙" .. FormatNumber.format(q.reward.coins))
            end
            if (q.reward.gems or 0) > 0 then
                table.insert(rewardParts, "💎" .. tostring(q.reward.gems))
            end
            rewardL.Text  = table.concat(rewardParts, "\n")
            rewardL.TextColor3 = Color3.fromRGB(255, 215, 0)
            rewardL.TextScaled = true
            rewardL.Font  = Enum.Font.GothamBold
            rewardL.Parent = row
        end
    end

    ClientData.onUpdate(updateQuests)

    -- Daily reward button
    local dailyBtn = Instance.new("TextButton")
    dailyBtn.Size  = UDim2.new(0, 180, 0, 40)
    dailyBtn.Position = UDim2.new(0.5, -90, 1, 4)
    dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 160, 0)
    dailyBtn.BorderSizePixel  = 0
    dailyBtn.Text  = "🎁 Claim Daily Reward"
    dailyBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
    dailyBtn.TextScaled = true
    dailyBtn.Font  = Enum.Font.GothamBold
    dailyBtn.Parent = mainFrame
    Instance.new("UICorner", dailyBtn).CornerRadius = UDim.new(0, 8)

    dailyBtn.MouseButton1Click:Connect(function()
        Events.ClaimDailyReward:FireServer()
    end)

    -- Daily reward result toast
    Events:WaitForChild("DailyRewardResult", 30).OnClientEvent:Connect(function(success, data_or_msg)
        local UICtrl = require(script.Parent.UIController)
        if success then
            local reward = data_or_msg
            local parts  = {}
            if (reward.coins or 0) > 0 then table.insert(parts, "🪙" .. FormatNumber.format(reward.coins)) end
            if (reward.gems  or 0) > 0 then table.insert(parts, "💎" .. tostring(reward.gems)) end
            UICtrl.showNotification("🎁 Daily: " .. table.concat(parts, " + "), Color3.fromRGB(255, 160, 0))
        else
            UICtrl.showNotification(data_or_msg or "Already claimed.", Color3.fromRGB(180, 80, 80))
        end
    end)
end

-- ─── Bootstrap ───────────────────────────────────────────────────────────────

buildShopGui()
buildRebirthGui()
buildQuestGui()

return ShopController
