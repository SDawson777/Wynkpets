--[[
    SpawnAllBillboardPets.server.luau
    Studio-only visual checker for 2D billboard pet sprites.

    Disabled by default. Toggle ENABLE_DEV_SPAWN to true when needed.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ENABLE_DEV_SPAWN = false

if not RunService:IsStudio() or not ENABLE_DEV_SPAWN then
    return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetDefinitions = require(Shared:WaitForChild("Pets"):WaitForChild("PetDefinitions"))
local BillboardPetRenderer = require(Shared:WaitForChild("Pets"):WaitForChild("BillboardPetRenderer"))

local PREVIEW_FOLDER_NAME = "BillboardPetPreview"
local START_POSITION = Vector3.new(0, 6, 0)
local COLUMN_COUNT = 12
local CELL_SPACING = 8

local previewFolder = Workspace:FindFirstChild(PREVIEW_FOLDER_NAME)
if previewFolder then
    previewFolder:Destroy()
end

previewFolder = Instance.new("Folder")
previewFolder.Name = PREVIEW_FOLDER_NAME
previewFolder.Parent = Workspace

local orderedPets = PetDefinitions.GetAllOrdered()

for index, petDef in ipairs(orderedPets) do
    local row = math.floor((index - 1) / COLUMN_COUNT)
    local col = (index - 1) % COLUMN_COUNT

    local x = START_POSITION.X + (col * CELL_SPACING)
    local z = START_POSITION.Z + (row * CELL_SPACING)
    local y = START_POSITION.Y

    local model = BillboardPetRenderer.createPetModel(petDef.id, "Normal", {
        widthStuds = 3.2,
        heightStuds = 3.2,
        studsOffsetY = 0,
        maxDistance = 500,
        showName = true,
        showRarity = true,
    })

    if model and model.PrimaryPart then
        model.Parent = previewFolder
        model:PivotTo(CFrame.new(x, y, z))
    end
end

-- Spawn variant sample strip so effects can be validated quickly.
local sampleCount = math.min(10, #orderedPets)
local sampleStart = START_POSITION + Vector3.new(0, 0, -CELL_SPACING * 2)

for i = 1, sampleCount do
    local petDef = orderedPets[i]
    local baseX = sampleStart.X + ((i - 1) * CELL_SPACING)

    local golden = BillboardPetRenderer.createPetModel(petDef.id, "Golden", {
        widthStuds = 3,
        heightStuds = 3,
        studsOffsetY = 0,
        maxDistance = 500,
        showName = true,
        showRarity = false,
    })
    if golden and golden.PrimaryPart then
        golden.Parent = previewFolder
        golden:PivotTo(CFrame.new(baseX, sampleStart.Y, sampleStart.Z))
    end

    local rainbow = BillboardPetRenderer.createPetModel(petDef.id, "Rainbow", {
        widthStuds = 3,
        heightStuds = 3,
        studsOffsetY = 0,
        maxDistance = 500,
        showName = true,
        showRarity = false,
    })
    if rainbow and rainbow.PrimaryPart then
        rainbow.Parent = previewFolder
        rainbow:PivotTo(CFrame.new(baseX, sampleStart.Y, sampleStart.Z - CELL_SPACING))
    end
end

print(string.format("[SpawnAllBillboardPets] Spawned %d normal pets and %d golden/rainbow samples.", #orderedPets, sampleCount))
