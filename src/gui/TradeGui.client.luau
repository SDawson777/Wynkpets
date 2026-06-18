--[[
    TradeGui.client.luau
    Trading UI - shows trade offers from both sides.
    Players can request trades by clicking on other players.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
local TradeConfig = require(Shared:WaitForChild("Configs"):WaitForChild("TradeConfig"))
local PetVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("PetVisualUtil"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TradeGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.4
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 750, 0, 500)
mainFrame.Position = UDim2.new(0.5, -375, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 16)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(100, 200, 255)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "Trade"
title.TextColor3 = Color3.fromRGB(130, 210, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = mainFrame

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 16)
tCorner.Parent = title

-- Cancel button
local cancelBtn = Instance.new("TextButton")
cancelBtn.Size = UDim2.new(0, 80, 0, 36)
cancelBtn.Position = UDim2.new(1, -90, 0, 7)
cancelBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
cancelBtn.Text = "Cancel"
cancelBtn.TextColor3 = Color3.new(1, 1, 1)
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.TextSize = 14
cancelBtn.Parent = title

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 8)
cbCorner.Parent = cancelBtn

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 24)
statusLabel.Position = UDim2.new(0, 0, 0, 50)
statusLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.Parent = mainFrame

-- Two columns: Your Offer | Their Offer
local yourOffer = Instance.new("Frame")
yourOffer.Size = UDim2.new(0.5, -15, 0, 200)
yourOffer.Position = UDim2.new(0, 10, 0, 80)
yourOffer.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
yourOffer.BorderSizePixel = 0
yourOffer.Parent = mainFrame

local yoCorner = Instance.new("UICorner")
yoCorner.CornerRadius = UDim.new(0, 10)
yoCorner.Parent = yourOffer

local yourLabel = Instance.new("TextLabel")
yourLabel.Size = UDim2.new(1, 0, 0, 24)
yourLabel.BackgroundTransparency = 1
yourLabel.Text = "Your Offer"
yourLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
yourLabel.Font = Enum.Font.GothamBold
yourLabel.TextSize = 13
yourLabel.Parent = yourOffer

local theirOffer = Instance.new("Frame")
theirOffer.Size = UDim2.new(0.5, -15, 0, 200)
theirOffer.Position = UDim2.new(0.5, 5, 0, 80)
theirOffer.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
theirOffer.BorderSizePixel = 0
theirOffer.Parent = mainFrame

local toCorner = Instance.new("UICorner")
toCorner.CornerRadius = UDim.new(0, 10)
toCorner.Parent = theirOffer

local theirLabel = Instance.new("TextLabel")
theirLabel.Size = UDim2.new(1, 0, 0, 24)
theirLabel.BackgroundTransparency = 1
theirLabel.Text = "Their Offer"
theirLabel.TextColor3 = Color3.fromRGB(255, 150, 100)
theirLabel.Font = Enum.Font.GothamBold
theirLabel.TextSize = 13
theirLabel.Parent = theirOffer

-- Accept / Confirm button
local acceptBtn = Instance.new("TextButton")
acceptBtn.Size = UDim2.new(0, 200, 0, 44)
acceptBtn.Position = UDim2.new(0.5, -100, 0, 290)
acceptBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
acceptBtn.Text = "Accept"
acceptBtn.TextColor3 = Color3.new(1, 1, 1)
acceptBtn.Font = Enum.Font.GothamBold
acceptBtn.TextSize = 16
acceptBtn.Parent = mainFrame

local abCorner = Instance.new("UICorner")
abCorner.CornerRadius = UDim.new(0, 10)
abCorner.Parent = acceptBtn

-- Pet selector for your offer
local petScroll = Instance.new("ScrollingFrame")
petScroll.Size = UDim2.new(1, -20, 0, 140)
petScroll.Position = UDim2.new(0, 10, 0, 348)
petScroll.BackgroundTransparency = 1
petScroll.ScrollBarThickness = 4
petScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
petScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
petScroll.Parent = mainFrame

local petLayout = Instance.new("UIGridLayout")
petLayout.CellSize = UDim2.new(0, 70, 0, 80)
petLayout.CellPadding = UDim2.new(0, 4, 0, 4)
petLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
petLayout.SortOrder = Enum.SortOrder.LayoutOrder
petLayout.Parent = petScroll

-- State
local pets = {}
local myOffer = {}
local inTrade = false

local function close()
    if inTrade then
        Network.FireServer("TradeCancelled")
    end
    inTrade = false
    screenGui.Enabled = false
end

cancelBtn.MouseButton1Click:Connect(close)

acceptBtn.MouseButton1Click:Connect(function()
    if not inTrade then return end
    Network.FireServer("TradeConfirmed")
end)

-- Display offer in "Your Offer" panel using UUIDs + local pet data
local function refreshMyOfferDisplay(frame, petUUIDs)
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local yOffset = 28
    for _, uuid in ipairs(petUUIDs) do
        local pet = nil
        for _, p in ipairs(pets) do
            if p.UUID == uuid then pet = p break end
        end
        if not pet then continue end
        local petInfo = PetConfig.GetPet(pet.PetId)
        if not petInfo then continue end
        local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]

        local entry = Instance.new("Frame")
        entry.Size = UDim2.new(1, -10, 0, 28)
        entry.Position = UDim2.new(0, 5, 0, yOffset)
        entry.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        entry.BorderSizePixel = 0
        entry.Parent = frame

        local eCorner = Instance.new("UICorner")
        eCorner.CornerRadius = UDim.new(0, 6)
        eCorner.Parent = entry

        local iconContainer = Instance.new("Frame")
        iconContainer.Size = UDim2.new(0, 20, 0, 20)
        iconContainer.Position = UDim2.new(0, 4, 0.5, -10)
        iconContainer.BackgroundTransparency = 1
        iconContainer.Parent = entry

        PetVisualUtil.CreateIcon(iconContainer, petInfo, pet, UDim2.new(1, 0, 1, 0))

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1, -30, 1, 0)
        nameL.Position = UDim2.new(0, 28, 0, 0)
        nameL.BackgroundTransparency = 1
        nameL.Text = petInfo.Name .. (pet.Golden and " [G]" or "") .. (pet.Rainbow and " [R]" or "")
        nameL.TextColor3 = Color3.new(1, 1, 1)
        nameL.Font = Enum.Font.Gotham
        nameL.TextSize = 11
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.Parent = entry

        yOffset = yOffset + 32
    end
end

-- Display offer in "Their Offer" panel using resolved pet data from server
local function refreshTheirOfferDisplay(frame, resolvedPets)
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local yOffset = 28
    for _, petData in ipairs(resolvedPets) do
        local petInfo = PetConfig.GetPet(petData.PetId)
        local rarityInfo = RarityConfig.Tiers[petData.Rarity]

        local entry = Instance.new("Frame")
        entry.Size = UDim2.new(1, -10, 0, 28)
        entry.Position = UDim2.new(0, 5, 0, yOffset)
        entry.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        entry.BorderSizePixel = 0
        entry.Parent = frame

        local eCorner = Instance.new("UICorner")
        eCorner.CornerRadius = UDim.new(0, 6)
        eCorner.Parent = entry

        local iconContainer = Instance.new("Frame")
        iconContainer.Size = UDim2.new(0, 20, 0, 20)
        iconContainer.Position = UDim2.new(0, 4, 0.5, -10)
        iconContainer.BackgroundTransparency = 1
        iconContainer.Parent = entry

        if petInfo then
            PetVisualUtil.CreateIcon(iconContainer, petInfo, petData, UDim2.new(1, 0, 1, 0))
        end

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1, -30, 1, 0)
        nameL.Position = UDim2.new(0, 28, 0, 0)
        nameL.BackgroundTransparency = 1
        nameL.Text = petData.Name .. (petData.Golden and " [G]" or "") .. (petData.Rainbow and " [R]" or "")
        nameL.TextColor3 = Color3.new(1, 1, 1)
        nameL.Font = Enum.Font.Gotham
        nameL.TextSize = 11
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.Parent = entry

        yOffset = yOffset + 32
    end
end

local function refreshMyPetSelector()
    for _, child in ipairs(petScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for i, pet in ipairs(pets) do
        if pet.Equipped then continue end
        local petInfo = PetConfig.GetPet(pet.PetId)
        if not petInfo then continue end
        local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]

        local inOffer = false
        for _, uuid in ipairs(myOffer) do
            if uuid == pet.UUID then inOffer = true break end
        end

        local card = Instance.new("Frame")
        card.Name = pet.UUID
        card.LayoutOrder = i
        card.BackgroundColor3 = inOffer and Color3.fromRGB(45, 55, 45) or Color3.fromRGB(35, 35, 55)
        card.BorderSizePixel = 0

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 6)
        cCorner.Parent = card

        if inOffer then
            local cStroke = Instance.new("UIStroke")
            cStroke.Color = Color3.fromRGB(100, 255, 100)
            cStroke.Thickness = 2
            cStroke.Parent = card
        end

        local icon = Instance.new("Frame")
        icon.Size = UDim2.new(0, 30, 0, 30)
        icon.Position = UDim2.new(0.5, -15, 0, 6)
        icon.BackgroundColor3 = pet.Golden and Color3.fromRGB(255, 215, 0) or (pet.Rainbow and Color3.fromRGB(255, 100, 255) or (rarityInfo and rarityInfo.Color or Color3.fromRGB(150, 150, 150)))
        icon.Parent = card
        local iCorner = Instance.new("UICorner")
        iCorner.CornerRadius = UDim.new(1, 0)
        iCorner.Parent = icon

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1, -4, 0, 12)
        nameL.Position = UDim2.new(0, 2, 0, 40)
        nameL.BackgroundTransparency = 1
        nameL.Text = petInfo.Name
        nameL.TextColor3 = Color3.new(1, 1, 1)
        nameL.Font = Enum.Font.GothamBold
        nameL.TextSize = 8
        nameL.TextTruncate = Enum.TextTruncate.AtEnd
        nameL.Parent = card

        local powerL = Instance.new("TextLabel")
        powerL.Size = UDim2.new(1, 0, 0, 10)
        powerL.Position = UDim2.new(0, 0, 0, 52)
        powerL.BackgroundTransparency = 1
        powerL.Text = "P:" .. petInfo.Power
        powerL.TextColor3 = Color3.fromRGB(180, 180, 180)
        powerL.Font = Enum.Font.Gotham
        powerL.TextSize = 8
        powerL.Parent = card

        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.ZIndex = 5
        clickBtn.Parent = card

        clickBtn.MouseButton1Click:Connect(function()
            if inOffer then
                for j, uuid in ipairs(myOffer) do
                    if uuid == pet.UUID then table.remove(myOffer, j) break end
                end
            else
                if #myOffer < TradeConfig.MaxPetsPerSide then
                    table.insert(myOffer, pet.UUID)
                end
            end
            Network.FireServer("TradeUpdated", myOffer, 0)
            refreshMyPetSelector()
            refreshMyOfferDisplay(yourOffer, myOffer)
        end)

        card.Parent = petScroll
    end
end

local function openTrade()
    myOffer = {}
    inTrade = true
    screenGui.Enabled = true
    statusLabel.Text = "Select pets to offer, then click Accept"
    refreshMyPetSelector()
    refreshMyOfferDisplay(yourOffer, {})
    refreshTheirOfferDisplay(theirOffer, {})
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 750, 0, 500),
        Position = UDim2.new(0.5, -375, 0.5, -250),
    }):Play()
end

-- NPC Trade Master interaction
Network.OnClientEvent("OpenTrade", function()
    if not inTrade then
        openTrade()
        statusLabel.Text = "Find a nearby player to trade with!"
    end
end)

-- Trade request received (show accept/decline prompts)
Network.OnClientEvent("TradeRequest", function(senderName, senderId)
    -- Simple accept/decline via notification + auto-accept for now
    -- In a full implementation, show a modal dialog
    openTrade()
    statusLabel.Text = senderName .. " wants to trade with you!"
    Network.FireServer("TradeAccepted")
end)

Network.OnClientEvent("TradeAccepted", function()
    if not screenGui.Enabled then openTrade() end
    statusLabel.Text = "Trade active - select your offer"
end)

Network.OnClientEvent("TradeUpdated", function(data)
    -- Server sends per-player perspective: MyOffer (UUIDs), TheirOffer (resolved pet data)
    refreshMyOfferDisplay(yourOffer, data.MyOffer or {})
    refreshTheirOfferDisplay(theirOffer, data.TheirOffer or {})

    if data.MyAccepted and data.TheirAccepted then
        acceptBtn.Text = "Confirm Trade"
        acceptBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
        statusLabel.Text = "Both accepted! Click Confirm to complete."
    elseif data.MyAccepted or data.TheirAccepted then
        statusLabel.Text = "Waiting for both players to accept..."
    end
end)

Network.OnClientEvent("TradeCancelled", function(reason)
    inTrade = false
    screenGui.Enabled = false
    -- Notification handled by server
end)

Network.OnClientEvent("TradeCompleted", function()
    inTrade = false
    screenGui.Enabled = false
end)

-- Connect to side button for opening trade search
task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if mainHud then
        local sideButtons = mainHud:WaitForChild("SideButtons", 10)
        if sideButtons then
            local tradeButton = sideButtons:WaitForChild("TradeButton", 10)
            if tradeButton then
                tradeButton.MouseButton1Click:Connect(function()
                    -- Find nearest player to trade with
                    local myChar = player.Character
                    if not myChar then return end
                    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
                    if not myHRP then return end

                    local closest = nil
                    local closestDist = 30 -- Max trade distance

                    for _, otherPlayer in ipairs(Players:GetPlayers()) do
                        if otherPlayer ~= player then
                            local otherChar = otherPlayer.Character
                            if otherChar then
                                local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
                                if otherHRP then
                                    local dist = (myHRP.Position - otherHRP.Position).Magnitude
                                    if dist < closestDist then
                                        closest = otherPlayer
                                        closestDist = dist
                                    end
                                end
                            end
                        end
                    end

                    if closest then
                        Network.FireServer("TradeRequest", closest)
                    else
                        -- Show notification via the MainHUD notification system
                        local notifEvent = playerGui:FindFirstChild("MainHUD") and playerGui.MainHUD:FindFirstChild("NotificationEvent")
                        if notifEvent then
                            notifEvent:Fire("No players nearby to trade with!", "Warning")
                        end
                    end
                end)
            end
        end
    end
end)

-- Data listener
Network.OnClientEvent("PetsUpdated", function(newPets)
    pets = newPets or {}
    if screenGui.Enabled then
        refreshMyPetSelector()
    end
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    pets = data.Pets or {}
end)

print("[GUI] TradeGui loaded")
