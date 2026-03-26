--[[
    PetLevelService.luau
    Handles pet XP gain and leveling up.
    Equipped pets gain XP when the player earns coins.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PetLevelConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetLevelConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))

local DataService
local PetLevelService = {}

-- Grant XP to all equipped pets
function PetLevelService.GrantXP(player: Player, amount: number)
    local data = DataService.GetData(player)
    if not data or amount <= 0 then return end

    local equippedPets = data.EquippedPets or {}
    if #equippedPets == 0 then return end

    -- Split XP evenly among equipped pets
    local xpPerPet = math.floor(amount / #equippedPets)
    if xpPerPet <= 0 then return end

    for _, petUUID in ipairs(equippedPets) do
        for _, pet in ipairs(data.Pets or {}) do
            if pet.UUID == petUUID then
                local level = pet.Level or 1
                if level >= PetLevelConfig.MaxLevel then break end

                pet.XP = (pet.XP or 0) + xpPerPet

                -- Check for level up(s)
                local leveled = false
                while level < PetLevelConfig.MaxLevel do
                    local xpNeeded = PetLevelConfig.GetXPForLevel(level)
                    if xpNeeded <= 0 then break end
                    if pet.XP >= xpNeeded then
                        pet.XP = pet.XP - xpNeeded
                        level = level + 1
                        pet.Level = level
                        leveled = true
                    else
                        break
                    end
                end

                if leveled then
                    local petInfo = PetConfig.GetPet(pet.PetId)
                    local petName = petInfo and petInfo.Name or pet.PetId
                    Network.FireClient("PetLevelUp", player, pet.UUID, pet.Level, petName)
                    Network.FireClient("ShowNotification", player,
                        petName .. " leveled up to " .. pet.Level .. "!", "Success")
                end

                break
            end
        end
    end

    -- Update client with new pet data
    Network.FireClient("PetsUpdated", player, data.Pets)
end

-- Get the effective power of a pet (base power * level multiplier * variant multiplier)
function PetLevelService.GetEffectivePower(pet, petInfo)
    if not pet or not petInfo then return 0 end
    local basePower = petInfo.Power
    local levelMultiplier = PetLevelConfig.GetPowerMultiplier(pet.Level or 1)
    return math.floor(basePower * levelMultiplier)
end

-- Initialize
function PetLevelService.Init(dataService)
    DataService = dataService
end

return PetLevelService
