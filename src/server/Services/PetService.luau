--[[
    PetService.luau
    Handles pet inventory, equipping, and management.
    Server-authoritative.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local RebirthConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RebirthConfig"))

local DataService -- Forward declaration

local PetService = {}

local MAX_PET_STORAGE = 200

-- Generate a unique pet UUID
local function generateUUID(): string
    return HttpService:GenerateGUID(false)
end

-- Create a new owned pet entry
function PetService.CreatePet(petId: string, golden: boolean?, rainbow: boolean?)
    local petInfo = PetConfig.GetPet(petId)
    if not petInfo then
        warn("[PetService] Unknown pet: " .. petId)
        return nil
    end

    return {
        UUID = generateUUID(),
        PetId = petId,
        Equipped = false,
        Golden = golden or false,
        Rainbow = rainbow or false,
        Level = 1,
    }
end

-- Add a pet to player's inventory
function PetService.AddPet(player: Player, petId: string, golden: boolean?, rainbow: boolean?)
    local data = DataService.GetData(player)
    if not data then return nil end

    if #data.Pets >= MAX_PET_STORAGE then
        Network.FireClient("ShowNotification", player, "Pet storage is full! Delete some pets.", "Warning")
        return nil
    end

    local pet = PetService.CreatePet(petId, golden, rainbow)
    if not pet then return nil end

    table.insert(data.Pets, pet)
    data.TotalPetsCollected = (data.TotalPetsCollected or 0) + 1

    -- Add to pet index (collection tracking)
    local indexKey = petId
    if golden then indexKey = petId .. "_golden" end
    if rainbow then indexKey = petId .. "_rainbow" end

    local found = false
    for _, entry in ipairs(data.PetIndex or {}) do
        if entry == indexKey then
            found = true
            break
        end
    end
    if not found then
        table.insert(data.PetIndex, indexKey)
    end

    Network.FireClient("PetsUpdated", player, data.Pets)
    return pet
end

-- Remove a pet from inventory
function PetService.RemovePet(player: Player, petUUID: string): boolean
    local data = DataService.GetData(player)
    if not data then return false end

    -- Unequip first if equipped
    PetService.UnequipPet(player, petUUID)

    for i, pet in ipairs(data.Pets) do
        if pet.UUID == petUUID then
            table.remove(data.Pets, i)
            Network.FireClient("PetsUpdated", player, data.Pets)
            return true
        end
    end
    return false
end

-- Equip a pet
function PetService.EquipPet(player: Player, petUUID: string): boolean
    local data = DataService.GetData(player)
    if not data then return false end

    -- Check max equip slots
    local maxSlots = data.MaxEquipSlots or RebirthConfig.BaseEquipSlots
    if data.Gamepasses and data.Gamepasses["vip"] then
        local GamepassConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GamepassConfig"))
        local vip = GamepassConfig.GetGamepass("vip")
        if vip then
            maxSlots = maxSlots + (vip.ExtraEquipSlots or 0)
        end
    end

    if #data.EquippedPets >= maxSlots then
        Network.FireClient("ShowNotification", player, "All pet slots are full! Unequip a pet first.", "Warning")
        return false
    end

    -- Check pet exists in inventory
    local found = false
    for _, pet in ipairs(data.Pets) do
        if pet.UUID == petUUID then
            found = true
            break
        end
    end
    if not found then return false end

    -- Check not already equipped
    for _, uuid in ipairs(data.EquippedPets) do
        if uuid == petUUID then
            return false -- Already equipped
        end
    end

    table.insert(data.EquippedPets, petUUID)

    -- Mark as equipped in pet data
    for _, pet in ipairs(data.Pets) do
        if pet.UUID == petUUID then
            pet.Equipped = true
            break
        end
    end

    Network.FireClient("PetEquipped", player, petUUID)
    Network.FireClient("PetsUpdated", player, data.Pets)
    return true
end

-- Unequip a pet
function PetService.UnequipPet(player: Player, petUUID: string): boolean
    local data = DataService.GetData(player)
    if not data then return false end

    local removed = false
    for i, uuid in ipairs(data.EquippedPets) do
        if uuid == petUUID then
            table.remove(data.EquippedPets, i)
            removed = true
            break
        end
    end

    if removed then
        for _, pet in ipairs(data.Pets) do
            if pet.UUID == petUUID then
                pet.Equipped = false
                break
            end
        end
        Network.FireClient("PetUnequipped", player, petUUID)
        Network.FireClient("PetsUpdated", player, data.Pets)
    end

    return removed
end

-- Get all owned pets
function PetService.GetPets(player: Player)
    local data = DataService.GetData(player)
    return data and data.Pets or {}
end

-- Get equipped pet UUIDs
function PetService.GetEquippedPets(player: Player)
    local data = DataService.GetData(player)
    return data and data.EquippedPets or {}
end

-- Initialize remote events
function PetService.Init(dataService)
    DataService = dataService

    Network.OnServerEvent("EquipPet", function(player: Player, petUUID: string)
        if type(petUUID) ~= "string" then return end
        PetService.EquipPet(player, petUUID)
    end)

    Network.OnServerEvent("UnequipPet", function(player: Player, petUUID: string)
        if type(petUUID) ~= "string" then return end
        PetService.UnequipPet(player, petUUID)
    end)

    Network.OnServerEvent("DeletePet", function(player: Player, petUUID: string)
        if type(petUUID) ~= "string" then return end
        PetService.RemovePet(player, petUUID)
    end)
end

return PetService
