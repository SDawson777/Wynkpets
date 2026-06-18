--[[
    PetDefinitions.luau
    Canonical pet registry for runtime systems that need normalized
    metadata and variant-ready image records.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local PetAssetManifest = require(Shared:WaitForChild("Pets"):WaitForChild("PetAssetManifest"))

local PetDefinitions = {}

PetDefinitions.ById = {}
PetDefinitions.Ordered = {}

for sortOrder, pet in ipairs(PetConfig.GetAllPets()) do
    local assetRecord = PetAssetManifest.Get(pet.Id) or {}

    local definition = {
        id = pet.Id,
        displayName = pet.Name,
        rarity = pet.Rarity,
        imageAssetId = assetRecord.normal or "rbxassetid://0",
        variants = {
            Normal = {
                imageAssetId = assetRecord.normal or "rbxassetid://0",
                tint = nil,
                effect = nil,
            },
            Golden = {
                imageAssetId = assetRecord.golden or assetRecord.normal or "rbxassetid://0",
                tint = Color3.fromRGB(255, 205, 65),
                effect = "Golden",
            },
            Rainbow = {
                imageAssetId = assetRecord.rainbow or assetRecord.normal or "rbxassetid://0",
                tint = nil,
                effect = "Rainbow",
            },
        },
        basePower = pet.Power,
        description = pet.ShortLore or pet.Description or "",
        sortOrder = sortOrder,
        isTradable = true,
        sourceFile = assetRecord.sourceFile,
        sourceReason = assetRecord.sourceReason,
    }

    PetDefinitions.ById[pet.Id] = definition
    table.insert(PetDefinitions.Ordered, definition)
end

function PetDefinitions.Get(petId: string)
    return PetDefinitions.ById[petId]
end

function PetDefinitions.GetAllOrdered()
    return PetDefinitions.Ordered
end

function PetDefinitions.GetAllById()
    return PetDefinitions.ById
end

return PetDefinitions
