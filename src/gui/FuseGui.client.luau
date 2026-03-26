--[[
    FuseGui.client.luau
    Pet fusing/merging UI.
    Select 3 pets to fuse into a stronger pet.
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
local FuseConfig = require(Shared:WaitForChild("Configs"):WaitForChild("FuseConfig"))
local NumberFormat = require(Shared:WaitForChild("Utils"):WaitForChild("NumberFormat"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FuseGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
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
mainFrame.Size = UDim2.new(0, 700, 0, 500)
mainFrame.Position = UDim2.new(0.5, -350, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 16)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = Color3.fromRGB(255, 100, 200)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "🔮 Pet Fusion"
title.TextColor3 = Color3.fromRGB(255, 150, 230)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = mainFrame

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 16)
tCorner.Parent = title

-- Close
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = title

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 10)
cbCorner.Parent = closeBtn

-- Fuse slots area (top half)
local slotsFrame = Instance.new("Frame")
slotsFrame.Size = UDim2.new(1, -20, 0, 150)
slotsFrame.Position = UDim2.new(0, 10, 0, 60)
slotsFrame.BackgroundTransparency = 1
slotsFrame.Parent = mainFrame

local slotsLayout = Instance.new("UIListLayout")
slotsLayout.FillDirection = Enum.FillDirection.Horizontal
slotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
slotsLayout.Padding = UDim.new(0, 20)
slotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
slotsLayout.Parent = slotsFrame

-- Create 3 fuse slots
local selectedPets = {} -- array of UUIDs (max 3)
local slotFrames = {}

for i = 1, 3 do
    local slot = Instance.new("Frame")
    slot.Name = "Slot" .. i
    slot.Size = UDim2.new(0, 100, 0, 120)
    slot.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    slot.BorderSizePixel = 0
    slot.Parent = slotsFrame

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 12)
    sCorner.Parent = slot

    local sStroke = Instance.new("UIStroke")
    sStroke.Color = Color3.fromRGB(100, 100, 120)
    sStroke.Thickness = 2
    sStroke.Parent = slot

    local emptyLabel = Instance.new("TextLabel")
    emptyLabel.Name = "EmptyLabel"
    emptyLabel.Size = UDim2.new(1, 0, 1, 0)
    emptyLabel.BackgroundTransparency = 1
    emptyLabel.Text = "+"
    emptyLabel.TextColor3 = Color3.fromRGB(80, 80, 100)
    emptyLabel.Font = Enum.Font.GothamBold
    emptyLabel.TextSize = 40
    emptyLabel.Parent = slot

    slotFrames[i] = slot

    -- Plus sign between slots
    if i < 3 then
        local plus = Instance.new("TextLabel")
        plus.Size = UDim2.new(0, 30, 0, 30)
        plus.BackgroundTransparency = 1
        plus.Text = "+"
        plus.TextColor3 = Color3.fromRGB(200, 200, 200)
        plus.Font = Enum.Font.GothamBold
        plus.TextSize = 24
        plus.Parent = slotsFrame
    end
end

-- Fuse button
local fuseBtn = Instance.new("TextButton")
fuseBtn.Size = UDim2.new(0, 200, 0, 44)
fuseBtn.Position = UDim2.new(0.5, -100, 0, 220)
fuseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
fuseBtn.Text = "Select 3 pets"
fuseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
fuseBtn.Font = Enum.Font.GothamBold
fuseBtn.TextSize = 16
fuseBtn.AutoButtonColor = false
fuseBtn.Parent = mainFrame

local fbCorner = Instance.new("UICorner")
fbCorner.CornerRadius = UDim.new(0, 10)
fbCorner.Parent = fuseBtn

-- Pet selector (bottom half)
local selectorLabel = Instance.new("TextLabel")
selectorLabel.Size = UDim2.new(0, 200, 0, 20)
selectorLabel.Position = UDim2.new(0, 10, 0, 275)
selectorLabel.BackgroundTransparency = 1
selectorLabel.Text = "Select pets to fuse:"
selectorLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
selectorLabel.Font = Enum.Font.GothamBold
selectorLabel.TextSize = 12
selectorLabel.TextXAlignment = Enum.TextXAlignment.Left
selectorLabel.Parent = mainFrame

local petScroll = Instance.new("ScrollingFrame")
petScroll.Size = UDim2.new(1, -20, 0, 190)
petScroll.Position = UDim2.new(0, 10, 0, 298)
petScroll.BackgroundTransparency = 1
petScroll.ScrollBarThickness = 4
petScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
petScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
petScroll.Parent = mainFrame

local petLayout = Instance.new("UIGridLayout")
petLayout.CellSize = UDim2.new(0, 80, 0, 90)
petLayout.CellPadding = UDim2.new(0, 4, 0, 4)
petLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
petLayout.SortOrder = Enum.SortOrder.LayoutOrder
petLayout.Parent = petScroll

-- State
local pets = {}

local function isSelected(uuid)
    for _, id in ipairs(selectedPets) do
        if id == uuid then return true end
    end
    return false
end

local function updateSlots()
    for i = 1, 3 do
        local slot = slotFrames[i]
        -- Clear slot children except EmptyLabel
        for _, child in ipairs(slot:GetChildren()) do
            if child.Name ~= "EmptyLabel" and not child:IsA("UICorner") and not child:IsA("UIStroke") then
                child:Destroy()
            end
        end

        local emptyLabel = slot:FindFirstChild("EmptyLabel")
        local uuid = selectedPets[i]

        if uuid then
            if emptyLabel then emptyLabel.Visible = false end
            -- Find pet data
            for _, pet in ipairs(pets) do
                if pet.UUID == uuid then
                    local petInfo = PetConfig.GetPet(pet.PetId)
                    if petInfo then
                        local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]
                        local icon = Instance.new("Frame")
                        icon.Name = "Icon"
                        icon.Size = UDim2.new(0, 40, 0, 40)
                        icon.Position = UDim2.new(0.5, -20, 0, 10)
                        icon.Parent = slot

                        local iCorner = Instance.new("UICorner")
                        iCorner.CornerRadius = UDim.new(1, 0)
                        iCorner.Parent = icon

                        if pet.Golden then
                            icon.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                        elseif pet.Rainbow then
                            icon.BackgroundColor3 = Color3.fromRGB(255, 100, 255)
                        else
                            icon.BackgroundColor3 = rarityInfo and rarityInfo.Color or Color3.fromRGB(150, 150, 150)
                        end

                        local nameL = Instance.new("TextLabel")
                        nameL.Name = "Name"
                        nameL.Size = UDim2.new(1, -4, 0, 14)
                        nameL.Position = UDim2.new(0, 2, 0, 55)
                        nameL.BackgroundTransparency = 1
                        nameL.Text = petInfo.Name
                        nameL.TextColor3 = Color3.new(1, 1, 1)
                        nameL.Font = Enum.Font.GothamBold
                        nameL.TextSize = 9
                        nameL.TextTruncate = Enum.TextTruncate.AtEnd
                        nameL.Parent = slot

                        local rarL = Instance.new("TextLabel")
                        rarL.Name = "Rarity"
                        rarL.Size = UDim2.new(1, 0, 0, 12)
                        rarL.Position = UDim2.new(0, 0, 0, 70)
                        rarL.BackgroundTransparency = 1
                        rarL.Text = petInfo.Rarity
                        rarL.TextColor3 = rarityInfo and rarityInfo.TextColor or Color3.fromRGB(200, 200, 200)
                        rarL.Font = Enum.Font.Gotham
                        rarL.TextSize = 9
                        rarL.Parent = slot

                        -- Remove button
                        local removeBtn = Instance.new("TextButton")
                        removeBtn.Name = "Remove"
                        removeBtn.Size = UDim2.new(0, 18, 0, 18)
                        removeBtn.Position = UDim2.new(1, -20, 0, 2)
                        removeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                        removeBtn.Text = "x"
                        removeBtn.TextColor3 = Color3.new(1, 1, 1)
                        removeBtn.Font = Enum.Font.GothamBold
                        removeBtn.TextSize = 10
                        removeBtn.Parent = slot

                        local rbCorner = Instance.new("UICorner")
                        rbCorner.CornerRadius = UDim.new(1, 0)
                        rbCorner.Parent = removeBtn

                        removeBtn.MouseButton1Click:Connect(function()
                            for j, id in ipairs(selectedPets) do
                                if id == uuid then
                                    table.remove(selectedPets, j)
                                    break
                                end
                            end
                            updateSlots()
                            refreshSelector()
                        end)
                    end
                    break
                end
            end
        else
            if emptyLabel then emptyLabel.Visible = true end
        end
    end

    -- Update fuse button
    if #selectedPets == 3 then
        -- Determine cost from first selected pet
        local firstPet = nil
        for _, pet in ipairs(pets) do
            if pet.UUID == selectedPets[1] then firstPet = pet break end
        end
        local firstInfo = firstPet and PetConfig.GetPet(firstPet.PetId)
        local rarity = firstInfo and firstInfo.Rarity or "Common"
        local cost = FuseConfig.GetCost(rarity)

        fuseBtn.Text = "🔮 Fuse - " .. NumberFormat.Abbreviate(cost) .. " Coins"
        fuseBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 200)
        fuseBtn.TextColor3 = Color3.new(1, 1, 1)
        fuseBtn.AutoButtonColor = true
    else
        fuseBtn.Text = "Select " .. (3 - #selectedPets) .. " more pet(s)"
        fuseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        fuseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        fuseBtn.AutoButtonColor = false
    end
end

local function refreshSelector()
    for _, child in ipairs(petScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Sort by power descending
    local sortedPets = {}
    for _, pet in ipairs(pets) do
        if not pet.Equipped then -- Only non-equipped pets
            table.insert(sortedPets, pet)
        end
    end

    table.sort(sortedPets, function(a, b)
        local aInfo = PetConfig.GetPet(a.PetId)
        local bInfo = PetConfig.GetPet(b.PetId)
        return (aInfo and aInfo.Power or 0) > (bInfo and bInfo.Power or 0)
    end)

    for i, pet in ipairs(sortedPets) do
        local petInfo = PetConfig.GetPet(pet.PetId)
        if not petInfo then continue end
        local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]
        local selected = isSelected(pet.UUID)

        local card = Instance.new("Frame")
        card.Name = pet.UUID
        card.LayoutOrder = i
        card.BackgroundColor3 = selected and Color3.fromRGB(50, 40, 60) or Color3.fromRGB(35, 35, 55)
        card.BorderSizePixel = 0

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = selected and Color3.fromRGB(255, 100, 200) or (rarityInfo and rarityInfo.Color or Color3.fromRGB(80, 80, 80))
        cStroke.Thickness = selected and 2 or 1
        cStroke.Parent = card

        -- Icon
        local icon = Instance.new("Frame")
        icon.Size = UDim2.new(0, 36, 0, 36)
        icon.Position = UDim2.new(0.5, -18, 0, 6)
        icon.Parent = card

        local iCorner = Instance.new("UICorner")
        iCorner.CornerRadius = UDim.new(1, 0)
        iCorner.Parent = icon

        if pet.Golden then
            icon.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        elseif pet.Rainbow then
            icon.BackgroundColor3 = Color3.fromRGB(255, 100, 255)
        else
            icon.BackgroundColor3 = rarityInfo and rarityInfo.Color or Color3.fromRGB(150, 150, 150)
        end

        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -4, 0, 14)
        nameLabel.Position = UDim2.new(0, 2, 0, 46)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = petInfo.Name
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 9
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card

        -- Power
        local powerLabel = Instance.new("TextLabel")
        powerLabel.Size = UDim2.new(1, 0, 0, 12)
        powerLabel.Position = UDim2.new(0, 0, 0, 60)
        powerLabel.BackgroundTransparency = 1
        powerLabel.Text = "⚡" .. petInfo.Power
        powerLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        powerLabel.Font = Enum.Font.Gotham
        powerLabel.TextSize = 9
        powerLabel.Parent = card

        -- Click to select/deselect
        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.ZIndex = 5
        clickBtn.Parent = card

        clickBtn.MouseButton1Click:Connect(function()
            if selected then
                for j, id in ipairs(selectedPets) do
                    if id == pet.UUID then
                        table.remove(selectedPets, j)
                        break
                    end
                end
            else
                if #selectedPets < 3 then
                    table.insert(selectedPets, pet.UUID)
                end
            end
            updateSlots()
            refreshSelector()
        end)

        card.Parent = petScroll
    end
end

-- Fuse button handler
fuseBtn.MouseButton1Click:Connect(function()
    if #selectedPets ~= 3 then return end
    Network.FireServer("FusePets", selectedPets)
    selectedPets = {}
    updateSlots()
    refreshSelector()
end)

-- ═══════════════════════════════════════
-- OPEN/CLOSE
-- ═══════════════════════════════════════

local function open()
    selectedPets = {}
    updateSlots()
    refreshSelector()
    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 700, 0, 500),
        Position = UDim2.new(0.5, -350, 0.5, -250),
    }):Play()
end

local function close()
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    })
    tween:Play()
    tween.Completed:Wait()
    screenGui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(close)
overlay.MouseButton1Click:Connect(close)

-- Connect to side button
task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if mainHud then
        local sideButtons = mainHud:WaitForChild("SideButtons", 10)
        if sideButtons then
            local fuseButton = sideButtons:WaitForChild("FuseButton", 10)
            if fuseButton then
                fuseButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

-- Data listeners
Network.OnClientEvent("PetsUpdated", function(newPets)
    pets = newPets or {}
    if screenGui.Enabled then
        updateSlots()
        refreshSelector()
    end
end)

Network.OnClientEvent("FuseResult", function(result)
    -- Could add a fuse animation here in the future
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    pets = data.Pets or {}
end)

print("[GUI] FuseGui loaded")
