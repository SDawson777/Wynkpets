--[[
    DailyRotationService.luau
    Deterministic daily content rotation.
    All functions use a day-based seed so every server agrees on today's content.
    No persistence needed — same seed = same result.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local DailyRotationConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DailyRotationConfig"))

local DataService

local DailyRotationService = {}

-- Deterministic seed based on UTC day
function DailyRotationService.GetDailySeed(): number
    return math.floor(os.time() / 86400)
end

-- Seconds until next rotation (midnight UTC)
function DailyRotationService.GetSecondsUntilReset(): number
    local now = os.time()
    local nextDay = (math.floor(now / 86400) + 1) * 86400
    return nextDay - now
end

-- Seeded pseudo-random number generator (deterministic)
local function seededRandom(seed: number, index: number): number
    -- Simple LCG-based hash for determinism
    local hash = (seed * 1103515245 + index * 12345) % 2147483647
    return (hash % 10000) / 10000
end

-- Seeded shuffle of an array (returns new array)
local function seededShuffle(arr, seed: number)
    local shuffled = {}
    for i, v in ipairs(arr) do
        shuffled[i] = v
    end
    for i = #shuffled, 2, -1 do
        local j = math.floor(seededRandom(seed, i) * i) + 1
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end

-- Get today's featured pets (deterministic pick of N pets from all pets)
function DailyRotationService.GetFeaturedPets(): { any }
    local seed = DailyRotationService.GetDailySeed()
    local allPets = PetConfig.GetAllPets()
    local count = DailyRotationConfig.FeaturedPetCount

    local shuffled = seededShuffle(allPets, seed + 100)
    local featured = {}
    for i = 1, math.min(count, #shuffled) do
        featured[i] = shuffled[i]
    end
    return featured
end

-- Get today's featured pet IDs (for fast lookup)
function DailyRotationService.GetFeaturedPetIds(): { [string]: boolean }
    local featured = DailyRotationService.GetFeaturedPets()
    local ids = {}
    for _, pet in ipairs(featured) do
        ids[pet.Id] = true
    end
    return ids
end

-- Get today's theme
function DailyRotationService.GetDailyTheme()
    local seed = DailyRotationService.GetDailySeed()
    local themes = DailyRotationConfig.Themes
    local index = (seed % #themes) + 1
    return themes[index]
end

-- Get today's special egg
function DailyRotationService.GetSpecialEgg()
    local seed = DailyRotationService.GetDailySeed()
    local eggs = DailyRotationConfig.SpecialEggs
    local index = (seed % #eggs) + 1
    return eggs[index]
end

-- Get today's available mutations
function DailyRotationService.GetDailyMutations(): { any }
    local seed = DailyRotationService.GetDailySeed()
    local pool = DailyRotationConfig.MutationPool
    local count = DailyRotationConfig.MutationCount

    local shuffled = seededShuffle(pool, seed + 200)
    local mutations = {}
    for i = 1, math.min(count, #shuffled) do
        mutations[i] = shuffled[i]
    end
    return mutations
end

-- Get today's mutation IDs for fast lookup
function DailyRotationService.GetDailyMutationIds(): { [string]: any }
    local mutations = DailyRotationService.GetDailyMutations()
    local ids = {}
    for _, mutation in ipairs(mutations) do
        ids[mutation.BasePetId] = mutation
    end
    return ids
end

-- Get full rotation data for client display
function DailyRotationService.GetRotationData()
    local featured = DailyRotationService.GetFeaturedPets()
    local theme = DailyRotationService.GetDailyTheme()
    local specialEgg = DailyRotationService.GetSpecialEgg()
    local mutations = DailyRotationService.GetDailyMutations()

    -- Simplify featured pet data for network transfer
    local featuredData = {}
    for _, pet in ipairs(featured) do
        table.insert(featuredData, {
            Id = pet.Id,
            Name = pet.Name,
            Rarity = pet.Rarity,
            Power = pet.Power,
            Image = pet.Image,
        })
    end

    -- Simplify mutation data
    local mutationData = {}
    for _, mut in ipairs(mutations) do
        table.insert(mutationData, {
            BasePetId = mut.BasePetId,
            MutationId = mut.MutationId,
            MutationName = mut.MutationName,
            PowerMultiplier = mut.PowerMultiplier,
            Image = mut.Image,
        })
    end

    return {
        Theme = {
            Id = theme.Id,
            Name = theme.Name,
            TintColor = { theme.TintColor.R, theme.TintColor.G, theme.TintColor.B },
            BoostType = theme.BoostType,
            BoostMultiplier = theme.BoostMultiplier,
            Description = theme.Description,
        },
        FeaturedPets = featuredData,
        SpecialEgg = {
            Id = specialEgg.Id,
            Name = specialEgg.Name,
            Cost = specialEgg.Cost,
            Currency = specialEgg.Currency,
            HatchTime = specialEgg.HatchTime,
        },
        Mutations = mutationData,
        SecondsUntilReset = DailyRotationService.GetSecondsUntilReset(),
    }
end

function DailyRotationService.Init(dataService)
    DataService = dataService

    -- Handle client requests for daily rotation data
    Network.OnServerEvent("RequestDailyRotation", function(player)
        local rotationData = DailyRotationService.GetRotationData()
        Network.FireClient("DailyRotation", player, rotationData)
    end)

    -- Log today's rotation
    local theme = DailyRotationService.GetDailyTheme()
    local featured = DailyRotationService.GetFeaturedPets()
    local featuredNames = {}
    for _, pet in ipairs(featured) do
        table.insert(featuredNames, pet.Name)
    end

    print(string.format(
        "[DailyRotationService] initialized — Theme: %s | Featured: %s",
        theme.Name,
        table.concat(featuredNames, ", ")
    ))
end

-- Send rotation data to a player on join
function DailyRotationService.PlayerAdded(player)
    local rotationData = DailyRotationService.GetRotationData()
    Network.FireClient("DailyRotation", player, rotationData)
end

return DailyRotationService
