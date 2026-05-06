--[[
    PetDisplayService.luau
    Shows equipped pets orbiting around the player's character.
    Creates Part-based pet models that follow the player.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
local PetLevelConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetLevelConfig"))
local PetVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("PetVisualUtil"))

local DataService

local PetDisplayService = {}

local ORBIT_RADIUS = 5
local ORBIT_SPEED = 1.5
local ORBIT_HEIGHT = 2
local PET_SIZE = Vector3.new(2.5, 2.5, 2.5)

local playerPetModels = {} -- [Player] = { [UUID] = { model=Model, body=Part, sparkle=Part? } }
local characterConnections = {} -- [Player] = RBXScriptConnection
local playerVisualSignatures = {} -- [Player] = string signature of equipped pet visuals
local playerLastSyncAt = {} -- [Player] = tick() of last signature check

local VISUAL_SYNC_INTERVAL = 1.0

local RARITY_COLORS = {
    Common = Color3.fromRGB(180, 180, 180),
    Rare = Color3.fromRGB(80, 160, 255),
    Epic = Color3.fromRGB(180, 80, 255),
    Legendary = Color3.fromRGB(255, 200, 50),
    Mythic = Color3.fromRGB(255, 80, 80),
    Secret = Color3.fromRGB(255, 50, 200),
}

local function buildVisualSignature(data)
    local equippedUUIDs = data.EquippedPets or {}
    if #equippedUUIDs == 0 then
        return "none"
    end

    local petByUUID = {}
    for _, pet in ipairs(data.Pets or {}) do
        petByUUID[pet.UUID] = pet
    end

    local tokens = {}
    for _, uuid in ipairs(equippedUUIDs) do
        local pet = petByUUID[uuid]
        if pet then
            table.insert(tokens, table.concat({
                uuid,
                tostring(pet.PetId or ""),
                tostring(pet.Golden == true),
                tostring(pet.Rainbow == true),
            }, ":"))
        else
            table.insert(tokens, uuid .. ":missing")
        end
    end

    table.sort(tokens)
    return table.concat(tokens, "|")
end

local function createPetModel(petData, petInfo)
    local model = Instance.new("Model")
    model.Name = "EquippedPet_" .. petData.UUID

    -- Pet body
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = PET_SIZE
    body.Anchored = true
    body.CanCollide = false

    -- Use shared image resolver so orbit visuals match inventory/index/hatch visuals.
    local petImage = PetVisualUtil.GetImage(petInfo, petData)

    local hasImage = petImage ~= "rbxassetid://0"
    local rarityColor = RARITY_COLORS[petInfo.Rarity] or RARITY_COLORS.Common

    if hasImage then
        -- Image-based pet: invisible anchor part + billboard sprite.
        -- This avoids SurfaceGui face issues and keeps pets consistently 2D.
        body.Shape = Enum.PartType.Ball
        body.Material = Enum.Material.SmoothPlastic
        body.Transparency = 1
        body.Color = rarityColor

        PetVisualUtil.CreateWorldBillboardImage(body, petImage, Vector2.new(3.2, 3.2))
    else
        -- Fallback: colored ball
        body.Shape = Enum.PartType.Ball
        body.Material = Enum.Material.SmoothPlastic

        if petData.Rainbow then
            body.Material = Enum.Material.Neon
            body.Color = Color3.fromRGB(255, 100, 255)
        elseif petData.Golden then
            body.Material = Enum.Material.Neon
            body.Color = Color3.fromRGB(255, 215, 0)
        else
            body.Color = rarityColor
        end
    end

    body.Parent = model
    model.PrimaryPart = body

    -- Pet name label
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 35)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent = body

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = petInfo.Name
    nameLabel.TextColor3 = rarityColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextScaled = true
    nameLabel.Parent = billboard

    local powerLabel = Instance.new("TextLabel")
    powerLabel.Name = "PowerLabel"
    powerLabel.Size = UDim2.new(1, 0, 0.4, 0)
    powerLabel.Position = UDim2.new(0, 0, 0.6, 0)
    powerLabel.BackgroundTransparency = 1
    powerLabel.TextColor3 = Color3.fromRGB(255, 255, 200)
    powerLabel.TextStrokeTransparency = 0
    powerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    powerLabel.Font = Enum.Font.Gotham
    powerLabel.TextScaled = true
    powerLabel.Parent = billboard

    local power = petInfo.Power
    if petData.Golden then power = math.floor(power * (RarityConfig.GoldenMultiplier or 2)) end
    if petData.Rainbow then power = math.floor(power * (RarityConfig.RainbowMultiplier or 5)) end
    powerLabel.Text = "x" .. power

    -- Golden/Rainbow sparkle effect
    if petData.Golden or petData.Rainbow then
        local sparkle = Instance.new("Part")
        sparkle.Name = "Sparkle"
        sparkle.Shape = Enum.PartType.Ball
        sparkle.Size = PET_SIZE * 1.3
        sparkle.Anchored = true
        sparkle.CanCollide = false
        sparkle.Material = Enum.Material.Neon
        sparkle.Transparency = 0.6
        sparkle.Color = petData.Rainbow and Color3.fromRGB(255, 100, 255) or Color3.fromRGB(255, 215, 0)
        sparkle.Parent = model
    end

    -- Start hidden until first orbit tick positions it correctly
    body.CFrame = CFrame.new(0, -500, 0)

    -- Return model plus cached direct refs to avoid FindFirstChild in the orbit loop
    local sparkleRef = model:FindFirstChild("Sparkle")
    return model, body, sparkleRef
end

local function updatePlayerPets(player)
    local data = DataService and DataService.GetData(player)
    if not data then return end

    -- Remove existing pet models
    if playerPetModels[player] then
        for _, entry in pairs(playerPetModels[player]) do
            entry.model:Destroy()
        end
    end
    playerPetModels[player] = {}

    -- Keep current signature in sync so stale visuals are auto-healed when pet IDs/variants change.
    playerVisualSignatures[player] = buildVisualSignature(data)

    -- Get equipped pets
    local equippedUUIDs = data.EquippedPets or {}
    if #equippedUUIDs == 0 then return end

    local petsFolder = Workspace:FindFirstChild("EquippedPets")
    if not petsFolder then
        petsFolder = Instance.new("Folder")
        petsFolder.Name = "EquippedPets"
        petsFolder.Parent = Workspace
    end

    -- Build UUID→pet lookup O(n) once
    local petByUUID = {}
    for _, pet in ipairs(data.Pets or {}) do
        petByUUID[pet.UUID] = pet
    end

    for _, uuid in ipairs(equippedUUIDs) do
        -- O(1) lookup via pre-built map instead of O(n×m) nested scan
        local ownedPet = petByUUID[uuid]
        if ownedPet then
            local petInfo = PetConfig.GetPet(ownedPet.PetId)
            if petInfo then
                local model, body, sparkle = createPetModel(ownedPet, petInfo)
                model.Parent = petsFolder
                playerPetModels[player][uuid] = { model = model, body = body, sparkle = sparkle }
            end
        end
    end
end

local function startOrbitLoop()
    -- Run at ~10 fps instead of 60 fps to dramatically reduce CFrame replication
    -- traffic to all clients. Orbiting pets at 10 fps is still visually smooth.
    task.spawn(function()
        while true do
            task.wait(0.1)
            local now = tick()
            for player, petModels in pairs(playerPetModels) do
                local character = player.Character
                if not character then continue end
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end

                -- Self-heal stale orbit visuals when equipped pet IDs/variants change via
                -- non-equip flows (e.g., evolution/fuse/trade replacements).
                local lastSync = playerLastSyncAt[player] or 0
                if (now - lastSync) >= VISUAL_SYNC_INTERVAL then
                    playerLastSyncAt[player] = now
                    local data = DataService and DataService.GetData(player)
                    if data then
                        local currentSig = buildVisualSignature(data)
                        if currentSig ~= playerVisualSignatures[player] then
                            updatePlayerPets(player)
                            petModels = playerPetModels[player] or {}
                        end
                    end
                end

                local basePos = hrp.Position
                local totalPets = 0
                for _ in pairs(petModels) do totalPets += 1 end
                local petCount = 0

                for uuid, entry in pairs(petModels) do
                    local body = entry.body
                    local sparkle = entry.sparkle
                    local angleOffset = (petCount / math.max(totalPets, 1)) * math.pi * 2
                    local angle = now * ORBIT_SPEED + angleOffset
                    local bob = math.sin(now * 2 + petCount) * 0.3

                    local orbitPos = basePos + Vector3.new(
                        math.cos(angle) * ORBIT_RADIUS,
                        ORBIT_HEIGHT + bob,
                        math.sin(angle) * ORBIT_RADIUS
                    )

                    if body then
                        body.CFrame = CFrame.new(orbitPos)
                    end

                    if sparkle then
                        sparkle.CFrame = CFrame.new(orbitPos)
                        sparkle.Transparency = 0.5 + math.sin(now * 4 + petCount) * 0.2
                    end

                    petCount += 1
                end
            end
        end
    end)
end

-- Update a single pet's power label without rebuilding all models
function PetDisplayService.UpdatePetPower(player: Player, petUUID: string, newLevel: number)
    local models = playerPetModels[player]
    if not models then return end
    local entry = models[petUUID]
    if not entry or not entry.body then return end

    local billboard = entry.body:FindFirstChildOfClass("BillboardGui")
    if not billboard then return end

    local powerLabel = billboard:FindFirstChild("PowerLabel")
    if not powerLabel then return end

    -- Find the pet data to recalculate power
    local data = DataService and DataService.GetData(player)
    if not data then return end
    for _, pet in ipairs(data.Pets or {}) do
        if pet.UUID == petUUID then
            local petInfo = PetConfig.GetPet(pet.PetId)
            if not petInfo then return end
            local power = PetLevelConfig.GetPowerMultiplier(newLevel) * petInfo.Power
            if pet.Golden then power = power * (RarityConfig.GoldenMultiplier or 2) end
            if pet.Rainbow then power = power * (RarityConfig.RainbowMultiplier or 5) end
            powerLabel.Text = "x" .. math.floor(power)
            return
        end
    end
end

function PetDisplayService.RefreshPets(player)
    updatePlayerPets(player)
end

function PetDisplayService.Init(dataService)
    DataService = dataService

    -- Listen for pet equip/unequip to refresh display
    Network.OnServerEvent("EquipPet", function(player)
        task.delay(0.2, function() updatePlayerPets(player) end)
    end)
    Network.OnServerEvent("UnequipPet", function(player)
        task.delay(0.2, function() updatePlayerPets(player) end)
    end)

    -- Start orbit animation loop
    startOrbitLoop()

    print("[PetDisplayService] Pet orbit display active")
end

function PetDisplayService.PlayerAdded(player)
    local function onCharacterAdded(character)
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not hrp then return end

        -- Poll until DataService has this player's data (up to 30 s)
        task.spawn(function()
            local data = nil
            for _ = 1, 60 do
                data = DataService and DataService.GetData(player)
                if data then break end
                task.wait(0.5)
            end
            -- Guard against player leaving during the wait
            if data and player.Parent then
                updatePlayerPets(player)
            end
        end)
    end

    if characterConnections[player] then
        characterConnections[player]:Disconnect()
    end
    characterConnections[player] = player.CharacterAdded:Connect(onCharacterAdded)

    if player.Character then
        onCharacterAdded(player.Character)
    end
end

function PetDisplayService.PlayerRemoving(player)
    if playerPetModels[player] then
        for _, entry in pairs(playerPetModels[player]) do
            entry.model:Destroy()
        end
        playerPetModels[player] = nil
    end
    playerVisualSignatures[player] = nil
    playerLastSyncAt[player] = nil
    if characterConnections[player] then
        characterConnections[player]:Disconnect()
        characterConnections[player] = nil
    end
end

return PetDisplayService
