--[[
    PetController.luau (Client)
    Manages local pet display, following, and inventory state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))

local player = Players.LocalPlayer

local PetController = {}

local ownedPets = {}
local equippedPets = {}
local petModels = {} -- [UUID] = Model (visual representations)
local updateCallbacks = {}

-- Get owned pets list
function PetController.GetPets()
    return ownedPets
end

-- Get equipped pet UUIDs
function PetController.GetEquipped()
    return equippedPets
end

-- Register update callback
function PetController.OnUpdate(callback: () -> ())
    table.insert(updateCallbacks, callback)
end

local function notifyUpdate()
    for _, callback in ipairs(updateCallbacks) do
        task.spawn(callback)
    end
end

-- Request equip
function PetController.Equip(petUUID: string)
    Network.FireServer("EquipPet", petUUID)
end

-- Request unequip
function PetController.Unequip(petUUID: string)
    Network.FireServer("UnequipPet", petUUID)
end

-- Request delete
function PetController.Delete(petUUID: string)
    Network.FireServer("DeletePet", petUUID)
end

-- Create a visual pet model that follows the player
local function createPetVisual(petUUID: string, petId: string, golden: boolean, rainbow: boolean)
    -- Remove existing model
    if petModels[petUUID] then
        petModels[petUUID]:Destroy()
    end

    local petInfo = PetConfig.GetPet(petId)
    if not petInfo then return end

    local character = player.Character
    if not character then return end

    -- Create a simple visual representation (sphere with name)
    local model = Instance.new("Model")
    model.Name = "Pet_" .. petUUID

    local body = Instance.new("Part")
    body.Name = "Body"
    body.Shape = Enum.PartType.Ball
    body.Size = Vector3.new(2, 2, 2)
    body.Anchored = true
    body.CanCollide = false
    body.Material = Enum.Material.SmoothPlastic

    -- Color based on rarity
    local rarityInfo = RarityConfig.Tiers[petInfo.Rarity]
    if golden then
        body.Color = Color3.fromRGB(255, 215, 0)
        body.Material = Enum.Material.Neon
    elseif rainbow then
        body.Color = Color3.fromRGB(255, 100, 255)
        body.Material = Enum.Material.Neon
    elseif rarityInfo then
        body.Color = rarityInfo.Color
    else
        body.Color = Color3.fromRGB(200, 200, 200)
    end

    body.Parent = model

    -- Name billboard
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent = body

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextScaled = true
    nameLabel.TextColor3 = rarityInfo and rarityInfo.TextColor or Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)

    local prefix = ""
    if rainbow then
        prefix = "🌈 "
    elseif golden then
        prefix = "✨ "
    end
    nameLabel.Text = prefix .. petInfo.Name
    nameLabel.Parent = billboard

    model.Parent = character

    petModels[petUUID] = model
    return model
end

-- Remove pet visual
local function removePetVisual(petUUID: string)
    if petModels[petUUID] then
        petModels[petUUID]:Destroy()
        petModels[petUUID] = nil
    end
end

-- Update pet positions (following player)
local function updatePetPositions()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local basePos = hrp.Position
    local index = 0

    for uuid, model in pairs(petModels) do
        local body = model:FindFirstChild("Body")
        if body then
            index = index + 1
            local angle = (index / math.max(#equippedPets, 1)) * math.pi * 2
            local orbitRadius = 4
            local bob = math.sin(tick() * 2 + index * 1.5) * 0.3
            local targetPos = basePos + Vector3.new(
                math.cos(angle + tick() * 0.5) * orbitRadius,
                1.5 + bob,
                math.sin(angle + tick() * 0.5) * orbitRadius
            )
            body.CFrame = body.CFrame:Lerp(CFrame.new(targetPos), 0.1)
        end
    end
end

-- Initialize
function PetController.Init()
    -- Listen for pet updates
    Network.OnClientEvent("PetsUpdated", function(pets)
        ownedPets = pets or {}

        -- Update equipped list
        equippedPets = {}
        for _, pet in ipairs(ownedPets) do
            if pet.Equipped then
                table.insert(equippedPets, pet.UUID)
            end
        end

        notifyUpdate()
    end)

    -- Listen for equip events
    Network.OnClientEvent("PetEquipped", function(petUUID: string)
        -- Create visual for equipped pet
        for _, pet in ipairs(ownedPets) do
            if pet.UUID == petUUID then
                createPetVisual(petUUID, pet.PetId, pet.Golden, pet.Rainbow)
                break
            end
        end
    end)

    Network.OnClientEvent("PetUnequipped", function(petUUID: string)
        removePetVisual(petUUID)
    end)

    -- Load initial data
    Network.OnClientEvent("PlayerDataLoaded", function(data)
        ownedPets = data.Pets or {}
        equippedPets = {}

        for _, pet in ipairs(ownedPets) do
            if pet.Equipped then
                table.insert(equippedPets, pet.UUID)
                createPetVisual(pet.UUID, pet.PetId, pet.Golden, pet.Rainbow)
            end
        end

        notifyUpdate()
    end)

    -- Update pet positions every frame
    RunService.Heartbeat:Connect(updatePetPositions)

    -- Recreate pets when character respawns
    player.CharacterAdded:Connect(function()
        task.wait(1) -- Wait for character to load
        for _, pet in ipairs(ownedPets) do
            if pet.Equipped then
                createPetVisual(pet.UUID, pet.PetId, pet.Golden, pet.Rainbow)
            end
        end
    end)
end

return PetController
