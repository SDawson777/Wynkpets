--[[
    FuseService.luau
    Handles pet fusing/merging.
    3 same pets -> golden variant
    3 golden -> rainbow variant
    3 same rarity -> chance at next rarity
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local FuseConfig = require(Shared:WaitForChild("Configs"):WaitForChild("FuseConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))

local DataService
local CurrencyService
local PetService

local FuseService = {}

function FuseService.FusePets(player: Player, petUUIDs: {string})
    if not petUUIDs or #petUUIDs ~= FuseConfig.RequiredPets then
        Network.FireClient("ShowNotification", player, "You need exactly " .. FuseConfig.RequiredPets .. " pets to fuse!", "Warning")
        return
    end

    local data = DataService.GetData(player)
    if not data then return end

    -- Validate all pets exist and are not equipped
    local fusePets = {}
    for _, uuid in ipairs(petUUIDs) do
        if type(uuid) ~= "string" then return end

        local found = false
        for _, pet in ipairs(data.Pets or {}) do
            if pet.UUID == uuid then
                -- Check not equipped
                if pet.Equipped then
                    Network.FireClient("ShowNotification", player, "Unequip pets before fusing!", "Warning")
                    return
                end
                table.insert(fusePets, pet)
                found = true
                break
            end
        end
        if not found then
            Network.FireClient("ShowNotification", player, "Pet not found in inventory!", "Warning")
            return
        end
    end

    -- Check for duplicate UUIDs
    local uuidSet = {}
    for _, uuid in ipairs(petUUIDs) do
        if uuidSet[uuid] then
            Network.FireClient("ShowNotification", player, "Cannot use the same pet twice!", "Warning")
            return
        end
        uuidSet[uuid] = true
    end

    -- Get pet info for the first pet
    local firstPet = fusePets[1]
    local firstPetInfo = PetConfig.GetPet(firstPet.PetId)
    if not firstPetInfo then return end

    -- Determine fuse type and cost
    local rarity = firstPetInfo.Rarity
    local cost = FuseConfig.GetCost(rarity)

    -- Check can afford
    if not CurrencyService.CanAfford(player, "Coins", cost) then
        Network.FireClient("ShowNotification", player, "Not enough Coins! Need " .. cost, "Warning")
        return
    end

    -- Determine result
    local resultPetId = firstPet.PetId
    local resultGolden = false
    local resultRainbow = false

    -- Check if all same pet
    local allSamePet = true
    local allGolden = true
    local allNormal = true
    for _, pet in ipairs(fusePets) do
        if pet.PetId ~= firstPet.PetId then allSamePet = false end
        if not pet.Golden then allGolden = false end
        if pet.Golden or pet.Rainbow then allNormal = false end
    end

    if allSamePet and allGolden and not firstPet.Rainbow then
        -- 3 golden same pet -> rainbow
        resultRainbow = true
    elseif allSamePet and allNormal then
        -- 3 normal same pet -> golden
        resultGolden = true
    else
        -- 3 same-rarity pets -> chance at next rarity
        -- Verify all same rarity
        local allSameRarity = true
        for _, pet in ipairs(fusePets) do
            local info = PetConfig.GetPet(pet.PetId)
            if info and info.Rarity ~= rarity then
                allSameRarity = false
                break
            end
        end

        if allSameRarity then
            local nextRarity = FuseConfig.GetNextRarity(rarity)
            if nextRarity and math.random() < FuseConfig.RarityUpgradeChance then
                -- Find a random pet of the next rarity
                local candidates = {}
                for _, petData in ipairs(PetConfig.Pets) do
                    if petData.Rarity == nextRarity then
                        table.insert(candidates, petData.Id)
                    end
                end
                if #candidates > 0 then
                    resultPetId = candidates[math.random(1, #candidates)]
                end
            end
            -- If no upgrade, keep first pet (normal fusion)
        else
            Network.FireClient("ShowNotification", player, "Pets must be the same rarity to fuse!", "Warning")
            return
        end
    end

    -- Deduct cost
    CurrencyService.Remove(player, "Coins", cost)

    -- Remove input pets
    for _, uuid in ipairs(petUUIDs) do
        PetService.RemovePet(player, uuid)
    end

    -- Create result pet
    local newPet = PetService.AddPet(player, resultPetId, resultGolden, resultRainbow)

    -- Send result to client
    if newPet then
        local resultInfo = PetConfig.GetPet(resultPetId)
        Network.FireClient("FuseResult", player, {
            UUID = newPet.UUID,
            PetId = resultPetId,
            Name = resultInfo and resultInfo.Name or resultPetId,
            Rarity = resultInfo and resultInfo.Rarity or "Common",
            Power = resultInfo and resultInfo.Power or 1,
            Golden = resultGolden,
            Rainbow = resultRainbow,
        })
        Network.FireClient("ShowNotification", player, "Fuse successful!", "Success")
    end
end

function FuseService.Init(dataService, currencyService, petService)
    DataService = dataService
    CurrencyService = currencyService
    PetService = petService

    Network.OnServerEvent("FusePets", function(player: Player, petUUIDs)
        if type(petUUIDs) ~= "table" then return end
        FuseService.FusePets(player, petUUIDs)
    end)
end

return FuseService
