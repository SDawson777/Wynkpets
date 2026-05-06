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
local RewardService
local AntiExploitService
local SubscriptionService -- set via PetService.SetSubscriptionService

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
        UUID     = generateUUID(),
        PetId    = petId,
        Equipped = false,
        Golden   = golden  or false,
        Rainbow  = rainbow or false,
        Level    = 1,
        Locked   = false,
    }
end

-- Add a pet to player's inventory
-- skipCapacityCheck: set true when the caller has already verified net capacity (e.g. FuseService removes N pets while adding 1)
function PetService.AddPet(player: Player, petId: string, golden: boolean?, rainbow: boolean?, skipCapacityCheck: boolean?)
    local data = DataService.GetData(player)
    if not data then return nil end

    if not skipCapacityCheck and #data.Pets >= MAX_PET_STORAGE then
        Network.FireClient("ShowNotification", player, "Pet storage is full! Delete some pets.", "Warning")
        return nil
    end

    local pet = PetService.CreatePet(petId, golden, rainbow)
    if not pet then return nil end

    table.insert(data.Pets, pet)
    data.TotalPetsCollected = (data.TotalPetsCollected or 0) + 1

    -- Update variant/rarity counters (O(1) reads for AchievementService)
    if golden then data.GoldenCount = (data.GoldenCount or 0) + 1 end
    if rainbow then data.RainbowCount = (data.RainbowCount or 0) + 1 end
    local petData = PetConfig.GetPet(petId)
    if petData then
        if petData.Rarity == "Mythic" then data.MythicCount = (data.MythicCount or 0) + 1 end
        if petData.Rarity == "Secret" then data.SecretCount = (data.SecretCount or 0) + 1 end
    end

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
            -- Locked pets cannot be deleted
            if pet.Locked then
                Network.FireClient("ShowNotification", player, "🔒 This pet is locked! Unlock it first.", "Warning")
                return false
            end
            -- Update variant/rarity counters before removing
            if pet.Golden then data.GoldenCount = math.max(0, (data.GoldenCount or 0) - 1) end
            if pet.Rainbow then data.RainbowCount = math.max(0, (data.RainbowCount or 0) - 1) end
            local petData = PetConfig.GetPet(pet.PetId)
            if petData then
                if petData.Rarity == "Mythic" then data.MythicCount = math.max(0, (data.MythicCount or 0) - 1) end
                if petData.Rarity == "Secret" then data.SecretCount = math.max(0, (data.SecretCount or 0) - 1) end
            end
            table.remove(data.Pets, i)
            Network.FireClient("PetsUpdated", player, data.Pets)
            return true
        end
    end
    return false
end

-- Lock a pet to prevent accidental deletion or trading.
function PetService.LockPet(player: Player, petUUID: string): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    for _, pet in ipairs(data.Pets) do
        if pet.UUID == petUUID then
            pet.Locked = true
            Network.FireClient("PetsUpdated", player, data.Pets)
            return true
        end
    end
    return false
end

-- Unlock a previously locked pet.
function PetService.UnlockPet(player: Player, petUUID: string): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    for _, pet in ipairs(data.Pets) do
        if pet.UUID == petUUID then
            pet.Locked = false
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

    -- Check max equip slots (base from data + subscription perk, dynamically checked)
    local baseSlots = data.MaxEquipSlots or RebirthConfig.BaseEquipSlots
    local subExtraSlots = SubscriptionService and SubscriptionService.GetPerk(player, "ExtraSlot") or 0
    local maxSlots = baseSlots + subExtraSlots

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

    -- Track quest progress
    if RewardService then
        RewardService.UpdateQuestProgress(player, "EquipPets", 1)
    end

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
function PetService.Init(dataService, rewardService, antiExploitService)
    DataService = dataService
    RewardService = rewardService
    AntiExploitService = antiExploitService

    Network.OnServerEvent("EquipPet", function(player: Player, petUUID: string)
        if type(petUUID) ~= "string" then return end
        if not AntiExploitService.CheckRateLimit(player, "EquipPet") then return end
        PetService.EquipPet(player, petUUID)
    end)

    Network.OnServerEvent("UnequipPet", function(player: Player, petUUID: string)
        if type(petUUID) ~= "string" then return end
        if not AntiExploitService.CheckRateLimit(player, "PetManage") then return end
        PetService.UnequipPet(player, petUUID)
    end)

    Network.OnServerEvent("DeletePet", function(player: Player, petUUID: string)
        if type(petUUID) ~= "string" then return end
        if not AntiExploitService.CheckRateLimit(player, "PetManage") then return end
        PetService.RemovePet(player, petUUID)
    end)

    Network.OnServerEvent("LockPet", function(player: Player, petUUID: string)
        if type(petUUID) ~= "string" then return end
        if not AntiExploitService.CheckRateLimit(player, "PetManage") then return end
        PetService.LockPet(player, petUUID)
    end)

    Network.OnServerEvent("UnlockPet", function(player: Player, petUUID: string)
        if type(petUUID) ~= "string" then return end
        if not AntiExploitService.CheckRateLimit(player, "PetManage") then return end
        PetService.UnlockPet(player, petUUID)
    end)
end

function PetService.SetSubscriptionService(svc)
    SubscriptionService = svc
end

return PetService
