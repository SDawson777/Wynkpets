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
local DailyRotationConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DailyRotationConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService
local CurrencyService
local PetService
local DailyRotationService
local AntiExploitService
local EvolutionService  -- set via FuseService.SetEvolutionService

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
        -- Guard against excessively long UUID strings (server-generated GUIDs are 36 chars)
        if #uuid > 40 then return end

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
    local resultMutationId = nil

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
        -- 3 normal same pet -> golden (or mutation chance)
        -- Check for daily mutation availability
        local mutationChance = DailyRotationConfig.MutationChance or 0.10
        local dailyMutations = DailyRotationService and DailyRotationService.GetDailyMutationIds() or {}
        local mutation = dailyMutations[firstPet.PetId]

        if mutation and math.random() < mutationChance then
            -- Mutation result!
            resultGolden = false
            resultMutationId = mutation.MutationId
        else
            resultGolden = true
        end
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

    -- Construct the result pet FIRST before touching coins or inventory.
    -- This ensures all side-effects are rolled back cleanly if the result cannot be created.
    -- Net-capacity pre-check: fusing removes RequiredPets and adds 1, so net count = (current - RequiredPets + 1).
    -- Pass skipCapacityCheck so AddPet doesn't double-count the input pets that are still present.
    local maxStorage = data.MaxPetStorage or 200
    if (#data.Pets - FuseConfig.RequiredPets + 1) > maxStorage then
        Network.FireClient("ShowNotification", player, "Pet storage is too full to fuse!", "Warning")
        return
    end
    local newPet = PetService.AddPet(player, resultPetId, resultGolden, resultRainbow, true)
    if not newPet then
        -- Pet config missing or inventory full — abort with no currency/pet loss
        Network.FireClient("ShowNotification", player, "Fuse failed: unable to create result pet!", "Warning")
        return
    end

    -- Apply mutation if applicable
    if resultMutationId then
        newPet.MutationId = resultMutationId
    end

    -- Deduct cost now that we know the result pet was successfully created
    CurrencyService.Remove(player, "Coins", cost)

    -- Remove input pets
    for _, uuid in ipairs(petUUIDs) do
        PetService.RemovePet(player, uuid)
    end

    -- Send result to client
    data.PetsFused = (data.PetsFused or 0) + 1
    -- Award Wynk Shards for evolution system
    if EvolutionService then
        EvolutionService.TryAwardShards(player, "Fuse")
    end
    local resultInfo = PetConfig.GetPet(resultPetId)

    -- Bonus coin reward for special fuse results (dopamine hit)
    local bonusCoins = 0
    if resultRainbow then
        bonusCoins = cost * 5  -- Rainbow fuse = 5x cost back in coins
    elseif resultGolden then
        bonusCoins = cost * 2  -- Golden fuse = 2x cost back
    elseif resultMutationId then
        bonusCoins = cost * 3  -- Mutation fuse = 3x cost back
    end
    if bonusCoins > 0 then
        CurrencyService.Add(player, "Coins", bonusCoins, false)
        Network.FireClient("ShowNotification", player,
            "BONUS! +" .. bonusCoins .. " Coins from fusing!", "Success")
    end

    Network.FireClient("FuseResult", player, {
        UUID = newPet.UUID,
        PetId = resultPetId,
        Name = resultInfo and resultInfo.Name or resultPetId,
        Rarity = resultInfo and resultInfo.Rarity or "Common",
        Power = resultInfo and resultInfo.Power or 1,
        Golden = resultGolden,
        Rainbow = resultRainbow,
        MutationId = resultMutationId,
    })
    local msg = resultMutationId and "Mutation fuse successful!" or "Fuse successful!"
    Network.FireClient("ShowNotification", player, msg, "Success")
end

function FuseService.Init(dataService, currencyService, petService, dailyRotationService, antiExploitService)
    DataService = dataService
    CurrencyService = currencyService
    PetService = petService
    DailyRotationService = dailyRotationService
    AntiExploitService = antiExploitService

    if not LaunchConfig.IsFeatureEnabled("Fusion") then
        print("[LaunchConfig] FuseService disabled — skipping handler registration")
        return
    end

    Network.OnServerEvent("FusePets", function(player: Player, petUUIDs)
        if type(petUUIDs) ~= "table" then return end
        if not AntiExploitService.CheckRateLimit(player, "FusePets") then return end
        FuseService.FusePets(player, petUUIDs)
    end)
end

function FuseService.SetEvolutionService(es) EvolutionService = es end

return FuseService
