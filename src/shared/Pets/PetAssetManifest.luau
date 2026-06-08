--[[
    PetAssetManifest.luau
    Canonical image manifest for all pet sprite assets.
    Uses direct rbxassetid:// URIs to avoid thumbnail caching issues.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))

local PetAssetManifest = {}

local INVALID_IMAGE = "rbxassetid://0"
local SOURCE_FILE_OVERRIDES = {
    -- These canonical pet IDs have valid uploaded runtime IDs but no same-name
    -- PNG file in assets/pets after final art cleanup.
    cat = {
        sourceFile = nil,
        sourceReason = "No same-name PNG in assets/pets; uses canonical uploaded asset ID from pet registry.",
    },
    cinderkit = {
        sourceFile = nil,
        sourceReason = "No same-name PNG in assets/pets; uses canonical uploaded asset ID from pet registry.",
    },
    ember_wisp = {
        sourceFile = nil,
        sourceReason = "No same-name PNG in assets/pets; uses canonical uploaded asset ID from pet registry.",
    },
    emeraldwyrm = {
        sourceFile = nil,
        sourceReason = "No same-name PNG in assets/pets; uses canonical uploaded asset ID from pet registry.",
    },
    oblivionserpent = {
        sourceFile = nil,
        sourceReason = "No same-name PNG in assets/pets; uses canonical uploaded asset ID from pet registry.",
    },
}

PetAssetManifest.ArchivedBonusSourceFiles = {
    "blazing_frost_bunny.png",
    "celestial_void_dragon.png",
    "fire_glimmer_kitten.png",
    "frost_lava_serpent.png",
    "frost_whiskerling.png",
    "golden_shadow_panther.png",
    "ice_ember_fox.png",
    "lava_crystal_wolf.png",
    "shadow_celestial_stag.png",
    "shadow_whiskerling.png",
    "void_ember_fox.png",
    "void_nova_phoenix.png",
}

local function normalizeAssetId(imageId: string?): string
    if not imageId or imageId == "" then
        return INVALID_IMAGE
    end

    local numericId = string.match(imageId, "%d+")
    if not numericId then
        return INVALID_IMAGE
    end

    return "rbxassetid://" .. numericId
end

local function makeTodoAssetId(petId: string, variantLabel: string): string
    local upperPetId = string.upper(string.gsub(petId, "[^%w]", "_"))
    return "rbxassetid://TODO_UPLOAD_" .. upperPetId .. "_" .. variantLabel
end

PetAssetManifest.ByPetId = {}
PetAssetManifest.OrderedPetIds = {}

for _, pet in ipairs(PetConfig.GetAllPets()) do
    local normal = normalizeAssetId(pet.Image)
    local golden = normalizeAssetId(pet.GoldenImage)
    local rainbow = normalizeAssetId(pet.RainbowImage)

    if normal == INVALID_IMAGE then
        normal = makeTodoAssetId(pet.Id, "NORMAL")
    end
    if golden == INVALID_IMAGE then
        golden = normal
    end
    if rainbow == INVALID_IMAGE then
        rainbow = normal
    end

    local sourceMeta = SOURCE_FILE_OVERRIDES[pet.Id]

    PetAssetManifest.ByPetId[pet.Id] = {
        normal = normal,
        golden = golden,
        rainbow = rainbow,
        sourceFile = if sourceMeta then sourceMeta.sourceFile else (pet.Id .. ".png"),
        sourceReason = if sourceMeta then sourceMeta.sourceReason else nil,
    }

    table.insert(PetAssetManifest.OrderedPetIds, pet.Id)
end

function PetAssetManifest.Get(petId: string)
    return PetAssetManifest.ByPetId[petId]
end

function PetAssetManifest.GetAll()
    return PetAssetManifest.ByPetId
end

return PetAssetManifest
