--[[
    EggService.luau
    Handles egg hatching with weighted random selection.
    Server-authoritative: validates cost, zone access, and determines results.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EggConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local GamepassConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GamepassConfig"))

local DataService -- Forward declarations
local CurrencyService
local PetService

local EggService = {}

-- Rate limiting per player
local lastHatchTime = {} -- [Player] = tick
local HATCH_COOLDOWN = 0.5 -- Minimum seconds between hatches

-- Select a pet from an egg's hatch table using weighted random
local function selectPet(egg, luckMultiplier: number): string
    local pets = egg.Pets
    if not pets or #pets == 0 then
        return nil
    end

    -- Apply luck multiplier: increase weight of rarer pets
    local adjustedPets = {}
    local totalWeight = 0

    for _, entry in ipairs(pets) do
        local petInfo = PetConfig.GetPet(entry.PetId)
        local weight = entry.Weight

        if petInfo and luckMultiplier > 1 then
            local rarityOrder = RarityConfig.Tiers[petInfo.Rarity] and RarityConfig.Tiers[petInfo.Rarity].Order or 1
            if rarityOrder >= 3 then -- Epic or higher
                weight = weight * luckMultiplier
            end
        end

        table.insert(adjustedPets, { PetId = entry.PetId, Weight = weight })
        totalWeight = totalWeight + weight
    end

    -- Weighted random selection
    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, entry in ipairs(adjustedPets) do
        cumulative = cumulative + entry.Weight
        if roll <= cumulative then
            return entry.PetId
        end
    end

    -- Fallback to last pet
    return adjustedPets[#adjustedPets].PetId
end

-- Determine if pet should be golden or rainbow
local function determineVariant(luckMultiplier: number): (boolean, boolean)
    local golden = false
    local rainbow = false

    local rainbowChance = RarityConfig.RainbowChance * luckMultiplier
    local goldenChance = RarityConfig.GoldenChance * luckMultiplier

    if math.random() < rainbowChance then
        rainbow = true
    elseif math.random() < goldenChance then
        golden = true
    end

    return golden, rainbow
end

-- Get player's luck multiplier (from boosts, gamepasses)
local function getLuckMultiplier(player: Player): number
    local data = DataService.GetData(player)
    if not data then return 1 end

    local multiplier = 1.0

    -- Luck boost
    if data.ActiveBoosts and data.ActiveBoosts["Luck"] then
        if data.ActiveBoosts["Luck"] > os.time() then
            multiplier = multiplier * 2.0
        end
    end

    return multiplier
end

-- Get hatch count based on gamepasses
local function getHatchCount(player: Player): number
    local data = DataService.GetData(player)
    if not data then return 1 end

    if data.Gamepasses and data.Gamepasses["triple_hatch"] then
        return 3
    end

    return 1
end

-- Hatch an egg (main function)
function EggService.HatchEgg(player: Player, eggId: string)
    -- Rate limit
    local now = tick()
    if lastHatchTime[player] and (now - lastHatchTime[player]) < HATCH_COOLDOWN then
        return
    end
    lastHatchTime[player] = now

    -- Validate egg exists
    local egg = EggConfig.GetEgg(eggId)
    if not egg then
        warn("[EggService] Unknown egg: " .. tostring(eggId))
        return
    end

    local data = DataService.GetData(player)
    if not data then return end

    -- Validate zone access
    local hasZoneAccess = false
    for _, zoneId in ipairs(data.UnlockedZones or {}) do
        if zoneId == egg.Zone then
            hasZoneAccess = true
            break
        end
    end
    if not hasZoneAccess then
        Network.FireClient("ShowNotification", player, "You need to unlock this zone first!", "Warning")
        return
    end

    -- Calculate total cost (hatch count * egg cost)
    local hatchCount = getHatchCount(player)
    local totalCost = egg.Cost * hatchCount

    -- Check and deduct currency
    if not CurrencyService.CanAfford(player, egg.Currency, totalCost) then
        Network.FireClient("ShowNotification", player, "Not enough " .. egg.Currency .. "!", "Warning")
        return
    end

    CurrencyService.Remove(player, egg.Currency, totalCost)

    -- Determine results
    local luckMultiplier = getLuckMultiplier(player)
    local results = {}

    for _ = 1, hatchCount do
        local petId = selectPet(egg, luckMultiplier)
        if petId then
            local golden, rainbow = determineVariant(luckMultiplier)
            local newPet = PetService.AddPet(player, petId, golden, rainbow)
            if newPet then
                local petInfo = PetConfig.GetPet(petId)
                table.insert(results, {
                    UUID = newPet.UUID,
                    PetId = petId,
                    Name = petInfo and petInfo.Name or petId,
                    Rarity = petInfo and petInfo.Rarity or "Common",
                    Power = petInfo and petInfo.Power or 1,
                    Golden = golden,
                    Rainbow = rainbow,
                })
            end
        end
    end

    -- Update stats
    data.TotalEggsHatched = (data.TotalEggsHatched or 0) + hatchCount

    -- Send results to client for animation
    if #results > 0 then
        Network.FireClient("HatchResult", player, results, egg.HatchTime)
    end
end

-- Initialize
function EggService.Init(dataService, currencyService, petService)
    DataService = dataService
    CurrencyService = currencyService
    PetService = petService

    Network.OnServerEvent("HatchEgg", function(player: Player, eggId: string)
        if type(eggId) ~= "string" then return end
        EggService.HatchEgg(player, eggId)
    end)
end

-- Clean up on player leave
function EggService.PlayerRemoving(player: Player)
    lastHatchTime[player] = nil
end

return EggService
