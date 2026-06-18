--[[
    PetController.luau (Client)
    Manages local pet data state and exposes callbacks for UI updates.
    3-D pet visuals are handled server-side by PetDisplayService so that
    all players can see each other's pets — no duplicate rendering here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local PetController = {}

local ownedPets = {}
local equippedPets = {}
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

-- Initialize
function PetController.Init()
    -- Keep local data in sync with server
    Network.OnClientEvent("PetsUpdated", function(pets)
        ownedPets = pets or {}
        equippedPets = {}
        for _, pet in ipairs(ownedPets) do
            if pet.Equipped then
                table.insert(equippedPets, pet.UUID)
            end
        end
        notifyUpdate()
    end)

    -- Load initial data
    Network.OnClientEvent("PlayerDataLoaded", function(data)
        ownedPets = data.Pets or {}
        equippedPets = {}
        for _, pet in ipairs(ownedPets) do
            if pet.Equipped then
                table.insert(equippedPets, pet.UUID)
            end
        end
        notifyUpdate()
    end)

    Network.OnClientEvent("RebirthCompleted", function(data)
        ownedPets = data.Pets or ownedPets
        equippedPets = {}
        for _, pet in ipairs(ownedPets) do
            if pet.Equipped then
                table.insert(equippedPets, pet.UUID)
            end
        end
        notifyUpdate()
    end)
end

return PetController
