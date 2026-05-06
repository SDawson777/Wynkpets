--[[
    LuckyWheelGui.client.luau
    Deterministic Lucky Wheel client.
    Reward selection is server-authoritative; client only animates to server-provided index.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local WheelConfig = require(Shared:WaitForChild("Configs"):WaitForChild("WheelConfig"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LuckyWheelGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 25
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.fromScale(0.5, 0.5)
mainFrame.Size = UDim2.fromOffset(540, 650)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 18)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 209, 95)
mainStroke.Thickness = 3
mainStroke.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 50)
title.Position = UDim2.new(0, 20, 0, 10)
title.BackgroundTransparency = 1
title.Text = "Lucky Wheel"
title.Font = Enum.Font.GothamBold
title.TextSize = 30
title.TextColor3 = Color3.fromRGB(255, 236, 190)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(36, 36)
closeButton.Position = UDim2.new(1, -46, 0, 16)
closeButton.BackgroundColor3 = Color3.fromRGB(215, 76, 76)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.Parent = mainFrame
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local wheelArea = Instance.new("Frame")
wheelArea.Size = UDim2.fromOffset(430, 430)
wheelArea.Position = UDim2.new(0.5, -215, 0, 70)
wheelArea.BackgroundTransparency = 1
wheelArea.Parent = mainFrame

local pointer = Instance.new("Frame")
pointer.Name = "Pointer"
pointer.AnchorPoint = Vector2.new(0.5, 1)
pointer.Position = UDim2.new(0.5, 0, 0, 16)
pointer.Size = UDim2.fromOffset(38, 48)
pointer.BackgroundColor3 = Color3.fromRGB(255, 225, 120)
pointer.BorderSizePixel = 0
pointer.ZIndex = 10
pointer.Parent = wheelArea
local pointerCorner = Instance.new("UICorner")
pointerCorner.CornerRadius = UDim.new(0, 10)
pointerCorner.Parent = pointer

local wheelMask = Instance.new("Frame")
wheelMask.Size = UDim2.fromOffset(390, 390)
wheelMask.AnchorPoint = Vector2.new(0.5, 0.5)
wheelMask.Position = UDim2.new(0.5, 0, 0.5, 14)
wheelMask.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
wheelMask.BorderSizePixel = 0
wheelMask.ClipsDescendants = true
wheelMask.Parent = wheelArea
local maskCorner = Instance.new("UICorner")
maskCorner.CornerRadius = UDim.new(1, 0)
maskCorner.Parent = wheelMask
local maskStroke = Instance.new("UIStroke")
maskStroke.Color = Color3.fromRGB(255, 216, 110)
maskStroke.Thickness = 4
maskStroke.Parent = wheelMask

local wheel = Instance.new("Frame")
wheel.Name = "Wheel"
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.5)
wheel.Size = UDim2.fromScale(1, 1)
wheel.BackgroundTransparency = 1
wheel.Parent = wheelMask

local rewardList = Instance.new("Frame")
rewardList.Size = UDim2.new(1, -30, 0, 52)
rewardList.Position = UDim2.new(0, 15, 0, 515)
rewardList.BackgroundTransparency = 1
rewardList.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -30, 0, 30)
infoLabel.Position = UDim2.new(0, 15, 0, 572)
infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.GothamMedium
infoLabel.TextSize = 16
infoLabel.TextColor3 = Color3.fromRGB(205, 215, 232)
infoLabel.Text = "Spin to win rewards"
infoLabel.Parent = mainFrame

local spinButton = Instance.new("TextButton")
spinButton.Size = UDim2.new(1, -30, 0, 44)
spinButton.Position = UDim2.new(0, 15, 1, -58)
spinButton.BackgroundColor3 = Color3.fromRGB(255, 197, 72)
spinButton.TextColor3 = Color3.fromRGB(31, 24, 9)
spinButton.Font = Enum.Font.GothamBold
spinButton.TextSize = 20
spinButton.Text = "Spin"
spinButton.BorderSizePixel = 0
spinButton.Parent = mainFrame
local spinCorner = Instance.new("UICorner")
spinCorner.CornerRadius = UDim.new(0, 10)
spinCorner.Parent = spinButton

local purchaseButton = Instance.new("TextButton")
purchaseButton.Size = UDim2.new(0.5, -20, 0, 34)
purchaseButton.Position = UDim2.new(1, -15, 0, 606)
purchaseButton.AnchorPoint = Vector2.new(1, 0)
purchaseButton.BackgroundColor3 = Color3.fromRGB(100, 148, 255)
purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
purchaseButton.Font = Enum.Font.GothamBold
purchaseButton.TextSize = 14
purchaseButton.Text = "Buy Spin"
purchaseButton.BorderSizePixel = 0
purchaseButton.Parent = mainFrame
local purchaseCorner = Instance.new("UICorner")
purchaseCorner.CornerRadius = UDim.new(0, 8)
purchaseCorner.Parent = purchaseButton

local popup = Instance.new("Frame")
popup.Size = UDim2.fromOffset(360, 170)
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.new(0.5, 0, 0.5, 0)
popup.BackgroundColor3 = Color3.fromRGB(26, 31, 42)
popup.Visible = false
popup.ZIndex = 20
popup.Parent = screenGui
local popupCorner = Instance.new("UICorner")
popupCorner.CornerRadius = UDim.new(0, 14)
popupCorner.Parent = popup
local popupStroke = Instance.new("UIStroke")
popupStroke.Color = Color3.fromRGB(255, 220, 120)
popupStroke.Thickness = 2
popupStroke.Parent = popup

local popupTitle = Instance.new("TextLabel")
popupTitle.Size = UDim2.new(1, -20, 0, 42)
popupTitle.Position = UDim2.new(0, 10, 0, 12)
popupTitle.BackgroundTransparency = 1
popupTitle.Font = Enum.Font.GothamBold
popupTitle.TextSize = 28
popupTitle.TextColor3 = Color3.fromRGB(255, 242, 196)
popupTitle.Text = "Reward Granted"
popupTitle.ZIndex = 21
popupTitle.Parent = popup

local popupBody = Instance.new("TextLabel")
popupBody.Size = UDim2.new(1, -20, 0, 72)
popupBody.Position = UDim2.new(0, 10, 0, 56)
popupBody.BackgroundTransparency = 1
popupBody.Font = Enum.Font.GothamMedium
popupBody.TextSize = 20
popupBody.TextColor3 = Color3.fromRGB(227, 235, 255)
popupBody.TextWrapped = true
popupBody.Text = ""
popupBody.ZIndex = 21
popupBody.Parent = popup

local popupClose = Instance.new("TextButton")
popupClose.Size = UDim2.new(0, 120, 0, 34)
popupClose.AnchorPoint = Vector2.new(0.5, 1)
popupClose.Position = UDim2.new(0.5, 0, 1, -12)
popupClose.BackgroundColor3 = Color3.fromRGB(255, 197, 72)
popupClose.TextColor3 = Color3.fromRGB(30, 24, 8)
popupClose.Font = Enum.Font.GothamBold
popupClose.TextSize = 16
popupClose.Text = "Claimed"
popupClose.BorderSizePixel = 0
popupClose.ZIndex = 21
popupClose.Parent = popup
local popupCloseCorner = Instance.new("UICorner")
popupCloseCorner.CornerRadius = UDim.new(0, 8)
popupCloseCorner.Parent = popupClose

local state = "Idle"
local currentWheelData = {
    LastFreeSpinDay = "",
    FreeSpinsUsedToday = 0,
    PaidSpinsAvailable = 0,
    TotalSpins = 0,
}
local pendingSpinResult = nil
local rewardBySpinId = {}
local segmentLabelByIndex = {}
local statusMessage = nil

local function setState(newState)
    state = newState
    local busy = (state == "WaitingForServer" or state == "Spinning")
    spinButton.AutoButtonColor = not busy
    spinButton.Active = not busy
    if busy then
        spinButton.BackgroundColor3 = Color3.fromRGB(145, 145, 160)
    else
        spinButton.BackgroundColor3 = Color3.fromRGB(255, 197, 72)
    end
end

local function getTodayUtcDay()
    return os.date("!%Y-%m-%d")
end

local function freeSpinsRemaining()
    local used = currentWheelData.FreeSpinsUsedToday or 0
    local today = getTodayUtcDay()
    if currentWheelData.LastFreeSpinDay ~= today then
        used = 0
    end
    return math.max(0, WheelConfig.DailyFreeSpins - used)
end

local function updateInfo()
    local freeLeft = freeSpinsRemaining()
    local paid = currentWheelData.PaidSpinsAvailable or 0
    infoLabel.Text = statusMessage or string.format("Free: %d  |  Paid: %d", freeLeft, paid)
    if state == "Spinning" then
        spinButton.Text = "Spinning..."
    elseif freeLeft > 0 then
        spinButton.Text = "Spin Free"
    elseif paid > 0 then
        spinButton.Text = "Use Paid Spin"
    else
        spinButton.Text = "No Spins Available"
    end
end

local function formatRewardText(reward)
    if reward.Type == "Currency" then
        return string.format("%s +%d", reward.DisplayName or reward.Currency or "Currency", reward.Amount or 0)
    end
    if reward.Type == "Boost" then
        local minutes = math.floor((reward.Duration or 0) / 60)
        return string.format("%s x%d for %d min", reward.BoostType or "Boost", reward.Multiplier or 2, minutes)
    end
    if reward.Type == "Pet" then
        return string.format("Pet unlocked: %s", reward.PetId or "Pet")
    end
    return reward.DisplayName or "Reward"
end

local function createWheelVisuals()
    for _, child in ipairs(wheel:GetChildren()) do
        child:Destroy()
    end
    table.clear(segmentLabelByIndex)

    local segmentCount = WheelConfig.SegmentCount
    local segmentAngle = 360 / segmentCount
    local stripsPerSegment = 4
    local subAngle = segmentAngle / stripsPerSegment
    local radius = 196
    local stripWidth = math.ceil(2 * radius * math.sin(math.rad(subAngle / 2)) * 1.1)

    for i, reward in ipairs(WheelConfig.Rewards) do
        local color = reward.Color or Color3.fromRGB(210, 210, 210)
        local startAngle = ((i - 1) * segmentAngle) + (WheelConfig.WheelVisualOffset or 0)

        for s = 1, stripsPerSegment do
            local angle = startAngle + (s - 0.5) * subAngle
            local strip = Instance.new("Frame")
            strip.Size = UDim2.fromOffset(stripWidth, radius)
            strip.AnchorPoint = Vector2.new(0.5, 1)
            strip.Position = UDim2.fromScale(0.5, 0.5)
            strip.BackgroundColor3 = color
            strip.BorderSizePixel = 0
            strip.Rotation = angle
            strip.Parent = wheel
        end

        local centerAngle = math.rad(startAngle + (segmentAngle / 2))
        local labelRadius = 122
        local lx = math.sin(centerAngle) * labelRadius
        local ly = -math.cos(centerAngle) * labelRadius

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromOffset(88, 38)
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.new(0.5, lx, 0.5, ly)
        label.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
        label.BackgroundTransparency = 0.1
        label.BorderSizePixel = 0
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextWrapped = true
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Text = reward.DisplayName or reward.Id
        label.Parent = wheel
        local labelCorner = Instance.new("UICorner")
        labelCorner.CornerRadius = UDim.new(0, 8)
        labelCorner.Parent = label

        segmentLabelByIndex[i] = label

        if WheelConfig.DebugMode then
            local indexLabel = Instance.new("TextLabel")
            indexLabel.Size = UDim2.fromOffset(30, 20)
            indexLabel.AnchorPoint = Vector2.new(0.5, 0.5)
            indexLabel.Position = UDim2.new(0.5, lx * 0.75, 0.5, ly * 0.75)
            indexLabel.BackgroundTransparency = 1
            indexLabel.Font = Enum.Font.GothamBlack
            indexLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            indexLabel.TextSize = 14
            indexLabel.Text = tostring(i)
            indexLabel.Parent = wheel
        end
    end

    for i = 0, segmentCount - 1 do
        local divider = Instance.new("Frame")
        divider.Size = UDim2.fromOffset(2, 196)
        divider.AnchorPoint = Vector2.new(0.5, 1)
        divider.Position = UDim2.fromScale(0.5, 0.5)
        divider.BackgroundColor3 = Color3.fromRGB(255, 235, 145)
        divider.BackgroundTransparency = 0.15
        divider.BorderSizePixel = 0
        divider.Rotation = (i * segmentAngle) + (WheelConfig.WheelVisualOffset or 0)
        divider.Parent = wheel
    end

    local centerHub = Instance.new("Frame")
    centerHub.Size = UDim2.fromOffset(88, 88)
    centerHub.AnchorPoint = Vector2.new(0.5, 0.5)
    centerHub.Position = UDim2.fromScale(0.5, 0.5)
    centerHub.BackgroundColor3 = Color3.fromRGB(17, 20, 31)
    centerHub.BorderSizePixel = 0
    centerHub.Parent = wheel
    local hubCorner = Instance.new("UICorner")
    hubCorner.CornerRadius = UDim.new(1, 0)
    hubCorner.Parent = centerHub
    local hubStroke = Instance.new("UIStroke")
    hubStroke.Color = Color3.fromRGB(255, 221, 121)
    hubStroke.Thickness = 3
    hubStroke.Parent = centerHub
end

local function showPopup(reward)
    popupBody.Text = formatRewardText(reward)
    popup.Visible = true
end

local function hidePopup()
    popup.Visible = false
end

local function playSpin(spinResult)
    setState("Spinning")

    local segmentCount = spinResult.SegmentCount
    local rewardIndex = spinResult.RewardIndex
    local fullSpins = spinResult.FullSpins
    local pointerAngle = spinResult.PointerAngle
    local segmentAngle = 360 / segmentCount
    local segmentCenterAngle = ((rewardIndex - 1) * segmentAngle) + (segmentAngle / 2) + (WheelConfig.WheelVisualOffset or 0)

    local current = wheel.Rotation % 360
    local targetDelta = (pointerAngle - segmentCenterAngle - current) % 360
    local targetRotation = wheel.Rotation + (fullSpins * 360) + targetDelta

    if WheelConfig.DebugMode then
        print("[WheelDebug] rewardIndex=", rewardIndex)
        print("[WheelDebug] segmentAngle=", segmentAngle)
        print("[WheelDebug] segmentCenterAngle=", segmentCenterAngle)
        print("[WheelDebug] targetRotation=", targetRotation)
    end

    local selectedLabel = segmentLabelByIndex[rewardIndex]
    if selectedLabel then
        selectedLabel.BackgroundTransparency = 0
    end

    local tween = TweenService:Create(
        wheel,
        TweenInfo.new(spinResult.SpinDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Rotation = targetRotation }
    )
    tween:Play()
    tween.Completed:Wait()

    local settleAmount = 2
    if WheelConfig.SettleDuration > 0 then
        local settle1 = TweenService:Create(
            wheel,
            TweenInfo.new(WheelConfig.SettleDuration * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            { Rotation = targetRotation + settleAmount }
        )
        settle1:Play()
        settle1.Completed:Wait()

        local settle2 = TweenService:Create(
            wheel,
            TweenInfo.new(WheelConfig.SettleDuration * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
            { Rotation = targetRotation }
        )
        settle2:Play()
        settle2.Completed:Wait()
    end

    if WheelConfig.DebugMode then
        print("[WheelDebug] finalRotationMod=", wheel.Rotation % 360)
    end

    if selectedLabel then
        selectedLabel.BackgroundTransparency = 0.1
    end

    setState("Result")
end

local function requestSpin()
    local freeLeft = freeSpinsRemaining()
    local paid = currentWheelData.PaidSpinsAvailable or 0

    if freeLeft > 0 then
        statusMessage = nil
        setState("WaitingForServer")
        Network.FireServer("RequestWheelSpin", { SpinType = "Free" })
        return
    end

    if paid > 0 then
        statusMessage = nil
        setState("WaitingForServer")
        Network.FireServer("RequestWheelSpin", { SpinType = "Paid" })
        return
    end

    statusMessage = "No paid spins available. Buy one to continue."
    updateInfo()
end

spinButton.MouseButton1Click:Connect(function()
    if state ~= "Idle" and state ~= "Result" then
        return
    end
    hidePopup()
    requestSpin()
end)

purchaseButton.MouseButton1Click:Connect(function()
    Network.FireServer("PurchaseWheelSpin")
end)

popupClose.MouseButton1Click:Connect(function()
    hidePopup()
    if state == "Result" then
        setState("Idle")
        updateInfo()
    end
end)

local function closeGui()
    if state == "Spinning" then
        return
    end
    screenGui.Enabled = false
end

closeButton.MouseButton1Click:Connect(closeGui)
overlay.MouseButton1Click:Connect(closeGui)

local function openGui()
    screenGui.Enabled = true
    updateInfo()
end

Network.OnClientEvent("PlayerDataLoaded", function(data)
    if type(data) == "table" and type(data.Wheel) == "table" then
        currentWheelData = data.Wheel
        updateInfo()
    end
end)

Network.OnClientEvent("DataUpdated", function(key, value)
    if key == "Wheel" and type(value) == "table" then
        currentWheelData = value
        updateInfo()
    end
end)

Network.OnClientEvent("WheelSpinRejected", function(payload)
    setState("Idle")
    local reason = (type(payload) == "table" and payload.Reason) or "Spin rejected."
    statusMessage = reason

    if type(payload) == "table" and payload.NextFreeSpinAt then
        local nowTs = os.time()
        local remain = math.max(0, payload.NextFreeSpinAt - nowTs)
        local hrs = math.floor(remain / 3600)
        local mins = math.floor((remain % 3600) / 60)
        statusMessage = string.format("%s Next free spin in %dh %02dm", reason, hrs, mins)
    end

    updateInfo()
end)

Network.OnClientEvent("WheelSpinResult", function(payload)
    if type(payload) ~= "table" then
        setState("Idle")
        updateInfo()
        return
    end

    pendingSpinResult = payload
    rewardBySpinId[payload.SpinId] = nil

    task.spawn(function()
        playSpin(payload)

        local granted = rewardBySpinId[payload.SpinId]
        if granted then
            showPopup(granted)
        else
            local fallbackReward = payload.Reward
            if fallbackReward then
                showPopup(fallbackReward)
            end
        end

        setState("Idle")
        statusMessage = nil
        updateInfo()
    end)
end)

Network.OnClientEvent("WheelRewardGranted", function(payload)
    if type(payload) ~= "table" then
        return
    end
    if payload.SpinId and payload.Reward then
        rewardBySpinId[payload.SpinId] = payload.Reward
        if pendingSpinResult and pendingSpinResult.SpinId == payload.SpinId and state ~= "Spinning" then
            showPopup(payload.Reward)
        end
    end
end)

createWheelVisuals()
updateInfo()

task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if not mainHud then return end

    local sideButtons = mainHud:WaitForChild("SideButtons", 10)
    if not sideButtons then return end

    local spinHudButton = sideButtons:WaitForChild("SpinButton", 10)
    if spinHudButton and spinHudButton:IsA("GuiButton") then
        spinHudButton.MouseButton1Click:Connect(openGui)
    end
end)

print("[GUI] LuckyWheelGui loaded")
