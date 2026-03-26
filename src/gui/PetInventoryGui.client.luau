--[[
    PetInventoryGui.client.luau
    Pet inventory, equipping, and management UI.
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
local PetLevelConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetLevelConfig"))

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetInventoryGui"
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
mfStroke.Color = Color3.fromRGB(255, 150, 50)
mfStroke.Thickness = 2
mfStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
title.Text = "🐾 My Pets"
title.TextColor3 = Color3.fromRGB(255, 180, 80)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = mainFrame

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 16)
tCorner.Parent = title

-- Pet counter
local counterLabel = Instance.new("TextLabel")
counterLabel.Name = "Counter"
counterLabel.Size = UDim2.new(0, 200, 0, 20)
counterLabel.Position = UDim2.new(0, 10, 0, 52)
counterLabel.BackgroundTransparency = 1
counterLabel.Text = "Pets: 0/200 | Equipped: 0/3"
counterLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
counterLabel.Font = Enum.Font.Gotham
counterLabel.TextSize = 12
counterLabel.TextXAlignment = Enum.TextXAlignment.Left
counterLabel.Parent = mainFrame

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

-- Sort dropdown
local sortFrame = Instance.new("Frame")
sortFrame.Size = UDim2.new(0, 300, 0, 24)
sortFrame.Position = UDim2.new(1, -310, 0, 52)
sortFrame.BackgroundTransparency = 1
sortFrame.Parent = mainFrame

local sortLayout = Instance.new("UIListLayout")
sortLayout.FillDirection = Enum.FillDirection.Horizontal
sortLayout.Padding = UDim.new(0, 5)
sortLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
sortLayout.Parent = sortFrame

local sortOptions = { "Power", "Rarity", "Name" }
local currentSort = "Power"

for _, sortName in ipairs(sortOptions) do
    local sb = Instance.new("TextButton")
    sb.Name = sortName
    sb.Size = UDim2.new(0, 70, 0, 24)
    sb.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    sb.Text = sortName
    sb.TextColor3 = Color3.fromRGB(150, 150, 150)
    sb.Font = Enum.Font.GothamBold
    sb.TextSize = 11
    sb.Parent = sortFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = sb
end

-- Pet grid
local petScroll = Instance.new("ScrollingFrame")
petScroll.Size = UDim2.new(1, -20, 1, -90)
petScroll.Position = UDim2.new(0, 10, 0, 80)
petScroll.BackgroundTransparency = 1
petScroll.ScrollBarThickness = 4
petScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
petScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
petScroll.Parent = mainFrame

local petLayout = Instance.new("UIGridLayout")
petLayout.CellSize = UDim2.new(0, 100, 0, 120)
petLayout.CellPadding = UDim2.new(0, 6, 0, 6)
petLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
petLayout.SortOrder = Enum.SortOrder.LayoutOrder
petLayout.Parent = petScroll

-- State
local pets = {}
local equippedPets = {}
local maxEquipSlots = 3

local function refreshPets()
    for _, child in ipairs(petScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- Sort pets
    local sortedPets = {}
    for _, pet in ipairs(pets) do
        table.insert(sortedPets, pet)
    end

    if currentSort == "Power" then
        table.sort(sortedPets, function(a, b)
            local aInfo = PetConfig.GetPet(a.PetId)
            local bInfo = PetConfig.GetPet(b.PetId)
            return (aInfo and aInfo.Power or 0) > (bInfo and bInfo.Power or 0)
        end)
    elseif currentSort == "Rarity" then
        table.sort(sortedPets, function(a, b)
            local aInfo = PetConfig.GetPet(a.PetId)
            local bInfo = PetConfig.GetPet(b.PetId)
            local aOrder = aInfo and RarityConfig.Tiers[aInfo.Rarity] and RarityConfig.Tiers[aInfo.Rarity].Order or 0
            local bOrder = bInfo and RarityConfig.Tiers[bInfo.Rarity] and RarityConfig.Tiers[bInfo.Rarity].Order or 0
            return aOrder > bOrder
        end)
    elseif currentSort == "Name" then
        table.sort(sortedPets, function(a, b)
            local aInfo = PetConfig.GetPet(a.PetId)
            local bInfo = PetConfig.GetPet(b.PetId)
            return (aInfo and aInfo.Name or "") < (bInfo and bInfo.Name or "")
        end)
    end

    -- Count equipped
    local equippedCount = 0
    for _, pet in ipairs(pets) do
        if pet.Equipped then equippedCount = equippedCount + 1 end
    end
    counterLabel.Text = string.format("Pets: %d/200 | Equipped: %d/%d", #pets, equippedCount, maxEquipSlots)

    -- Create cards
    for index, pet in ipairs(sortedPets) do
        local petInfo = PetConfig.GetPet(pet.PetId)
        if not petInfo then continue end

        local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]

        local card = Instance.new("Frame")
        card.Name = pet.UUID
        card.LayoutOrder = index
        card.BackgroundColor3 = pet.Equipped and Color3.fromRGB(45, 55, 45) or Color3.fromRGB(35, 35, 55)
        card.BorderSizePixel = 0

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 10)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = pet.Equipped and Color3.fromRGB(100, 255, 100) or (rarityInfo and rarityInfo.Color or Color3.fromRGB(80, 80, 80))
        cStroke.Thickness = pet.Equipped and 2.5 or 1.5
        cStroke.Parent = card

        -- Pet icon (colored circle)
        local icon = Instance.new("Frame")
        icon.Size = UDim2.new(0, 50, 0, 50)
        icon.Position = UDim2.new(0.5, -25, 0, 8)
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
        nameLabel.Size = UDim2.new(1, -4, 0, 16)
        nameLabel.Position = UDim2.new(0, 2, 0, 62)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = petInfo.Name
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 11
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card

        -- Power
        local powerLabel = Instance.new("TextLabel")
        powerLabel.Size = UDim2.new(1, 0, 0, 14)
        powerLabel.Position = UDim2.new(0, 0, 0, 78)
        powerLabel.BackgroundTransparency = 1
        local effectivePower = math.floor(petInfo.Power * PetLevelConfig.GetPowerMultiplier(pet.Level or 1))
        powerLabel.Text = "⚡" .. effectivePower .. " Lv." .. (pet.Level or 1)
        powerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        powerLabel.Font = Enum.Font.Gotham
        powerLabel.TextSize = 10
        powerLabel.Parent = card

        -- Equip/Unequip button
        local actionBtn = Instance.new("TextButton")
        actionBtn.Size = UDim2.new(0.85, 0, 0, 22)
        actionBtn.Position = UDim2.new(0.075, 0, 1, -28)
        actionBtn.Font = Enum.Font.GothamBold
        actionBtn.TextSize = 11
        actionBtn.TextColor3 = Color3.new(1, 1, 1)
        actionBtn.Parent = card

        local abCorner = Instance.new("UICorner")
        abCorner.CornerRadius = UDim.new(0, 6)
        abCorner.Parent = actionBtn

        if pet.Equipped then
            actionBtn.Text = "Unequip"
            actionBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 50)
            actionBtn.MouseButton1Click:Connect(function()
                Network.FireServer("UnequipPet", pet.UUID)
            end)
        else
            actionBtn.Text = "Equip"
            actionBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
            actionBtn.MouseButton1Click:Connect(function()
                Network.FireServer("EquipPet", pet.UUID)
            end)
        end

        -- Delete button (only for non-equipped pets)
        if not pet.Equipped then
            local deleteBtn = Instance.new("TextButton")
            deleteBtn.Size = UDim2.new(0, 20, 0, 20)
            deleteBtn.Position = UDim2.new(1, -24, 0, 4)
            deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            deleteBtn.Text = "X"
            deleteBtn.TextColor3 = Color3.new(1, 1, 1)
            deleteBtn.Font = Enum.Font.GothamBold
            deleteBtn.TextSize = 10
            deleteBtn.ZIndex = 2
            deleteBtn.Parent = card

            local dbCorner = Instance.new("UICorner")
            dbCorner.CornerRadius = UDim.new(0, 6)
            dbCorner.Parent = deleteBtn

            deleteBtn.MouseButton1Click:Connect(function()
                -- Confirmation dialog
                local confirmGui = Instance.new("ScreenGui")
                confirmGui.Name = "DeleteConfirm"
                confirmGui.DisplayOrder = 50
                confirmGui.Parent = playerGui

                local confirmOverlay = Instance.new("TextButton")
                confirmOverlay.Size = UDim2.new(1, 0, 1, 0)
                confirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
                confirmOverlay.BackgroundTransparency = 0.5
                confirmOverlay.Text = ""
                confirmOverlay.AutoButtonColor = false
                confirmOverlay.Parent = confirmGui

                local confirmFrame = Instance.new("Frame")
                confirmFrame.Size = UDim2.new(0, 280, 0, 140)
                confirmFrame.Position = UDim2.new(0.5, -140, 0.5, -70)
                confirmFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
                confirmFrame.BorderSizePixel = 0
                confirmFrame.Parent = confirmGui

                local cfCorner = Instance.new("UICorner")
                cfCorner.CornerRadius = UDim.new(0, 12)
                cfCorner.Parent = confirmFrame

                local cfStroke = Instance.new("UIStroke")
                cfStroke.Color = Color3.fromRGB(200, 50, 50)
                cfStroke.Thickness = 2
                cfStroke.Parent = confirmFrame

                local confirmText = Instance.new("TextLabel")
                confirmText.Size = UDim2.new(1, -20, 0, 60)
                confirmText.Position = UDim2.new(0, 10, 0, 10)
                confirmText.BackgroundTransparency = 1
                confirmText.Text = "Delete " .. petInfo.Name .. "?"
                confirmText.TextColor3 = Color3.new(1, 1, 1)
                confirmText.Font = Enum.Font.GothamBold
                confirmText.TextSize = 18
                confirmText.TextWrapped = true
                confirmText.Parent = confirmFrame

                local yesBtn = Instance.new("TextButton")
                yesBtn.Size = UDim2.new(0, 100, 0, 36)
                yesBtn.Position = UDim2.new(0.5, -110, 1, -50)
                yesBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                yesBtn.Text = "Delete"
                yesBtn.TextColor3 = Color3.new(1, 1, 1)
                yesBtn.Font = Enum.Font.GothamBold
                yesBtn.TextSize = 14
                yesBtn.Parent = confirmFrame

                local ybCorner = Instance.new("UICorner")
                ybCorner.CornerRadius = UDim.new(0, 8)
                ybCorner.Parent = yesBtn

                local noBtn = Instance.new("TextButton")
                noBtn.Size = UDim2.new(0, 100, 0, 36)
                noBtn.Position = UDim2.new(0.5, 10, 1, -50)
                noBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
                noBtn.Text = "Cancel"
                noBtn.TextColor3 = Color3.new(1, 1, 1)
                noBtn.Font = Enum.Font.GothamBold
                noBtn.TextSize = 14
                noBtn.Parent = confirmFrame

                local nbCorner = Instance.new("UICorner")
                nbCorner.CornerRadius = UDim.new(0, 8)
                nbCorner.Parent = noBtn

                yesBtn.MouseButton1Click:Connect(function()
                    Network.FireServer("DeletePet", pet.UUID)
                    confirmGui:Destroy()
                end)

                noBtn.MouseButton1Click:Connect(function()
                    confirmGui:Destroy()
                end)

                confirmOverlay.MouseButton1Click:Connect(function()
                    confirmGui:Destroy()
                end)
            end)
        end

        card.Parent = petScroll
    end
end

-- Sort button handlers
for _, child in ipairs(sortFrame:GetChildren()) do
    if child:IsA("TextButton") then
        child.MouseButton1Click:Connect(function()
            currentSort = child.Name
            -- Update button visuals
            for _, btn in ipairs(sortFrame:GetChildren()) do
                if btn:IsA("TextButton") then
                    if btn.Name == currentSort then
                        btn.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
                        btn.TextColor3 = Color3.new(1, 1, 1)
                    else
                        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                        btn.TextColor3 = Color3.fromRGB(150, 150, 150)
                    end
                end
            end
            refreshPets()
        end)
    end
end

-- ═══════════════════════════════════════
-- OPEN/CLOSE
-- ═══════════════════════════════════════

local function open()
    refreshPets()
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
            local petsButton = sideButtons:WaitForChild("PetsButton", 10)
            if petsButton then
                petsButton.MouseButton1Click:Connect(open)
            end
        end
    end
end)

-- Data listeners
Network.OnClientEvent("PetsUpdated", function(newPets)
    pets = newPets or {}
    if screenGui.Enabled then
        refreshPets()
    end
end)

Network.OnClientEvent("PlayerDataLoaded", function(data)
    pets = data.Pets or {}
    maxEquipSlots = data.MaxEquipSlots or 3
end)

Network.OnClientEvent("RebirthCompleted", function(data)
    maxEquipSlots = data.MaxEquipSlots or maxEquipSlots
end)

print("[GUI] PetInventoryGui loaded")
