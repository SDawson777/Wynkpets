--[[
    EggSpawnerService.luau
    Spawns physical egg objects in zones that players can collect.
    Hatching happens in the Egg Hatchery GUI, not in the field.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EggConfig"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local EggVisualUtil = require(Shared:WaitForChild("Utils"):WaitForChild("EggVisualUtil"))

local EggService -- set in Init

local EggSpawnerService = {}

-- Egg placement offsets within each zone (relative to zone spawn)
-- First egg on the left, second egg on the right
local EGG_OFFSETS = {
    Vector3.new(-25, 0, -30),
    Vector3.new(25, 0, -30),
}

local EGG_MESH_ID = "rbxassetid://97120883795006"
local EGG_SIZE = Vector3.new(4, 5, 4)

local function getOrCreateZoneFolder(zoneId: string)
    local zonesFolder = Workspace:FindFirstChild("Zones")
    if not zonesFolder then
        zonesFolder = Instance.new("Folder")
        zonesFolder.Name = "Zones"
        zonesFolder.Parent = Workspace
    end

    local zoneFolder = zonesFolder:FindFirstChild(zoneId)
    if not zoneFolder then
        zoneFolder = Instance.new("Folder")
        zoneFolder.Name = zoneId
        zoneFolder.Parent = zonesFolder
    end

    return zoneFolder
end

local function formatCost(cost: number): string
    if cost >= 1000000000 then
        return string.format("%.1fB", cost / 1000000000)
    elseif cost >= 1000000 then
        return string.format("%.1fM", cost / 1000000)
    elseif cost >= 1000 then
        return string.format("%.1fK", cost / 1000)
    end
    return tostring(cost)
end

local function applyEggTexture(eggPart, imageId: string)
    -- BillboardGui renders correctly regardless of mesh type (unlike SurfaceGui
    -- which cannot render on SpecialMesh Sphere geometry).
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EggTexture"
    billboard.Size = UDim2.new(4, 0, 5, 0)   -- studs-scale: 4 wide × 5 tall to match egg body
    billboard.StudsOffset = Vector3.new(0, 0, 0)
    billboard.AlwaysOnTop = false
    billboard.LightInfluence = 1
    billboard.Parent = eggPart

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(1, 0, 1, 0)
    img.BackgroundTransparency = 1
    img.Image = imageId
    img.ScaleType = Enum.ScaleType.Fit
    img.Parent = billboard
end

local function createEggObject(egg, position: Vector3, zoneFolder)
    local eggModel = Instance.new("Model")
    eggModel.Name = "Egg_" .. egg.Id

    -- Egg body: smooth sphere scaled into egg shape (avoids MeshPart.MeshId restriction)
    local eggPart = Instance.new("Part")
    eggPart.Name = "EggBody"
    eggPart.Size = EGG_SIZE
    eggPart.Position = position + Vector3.new(0, EGG_SIZE.Y / 2 + 2.0, 0)
    eggPart.Anchored = true
    eggPart.CanCollide = false
    eggPart.Material = Enum.Material.SmoothPlastic
    local eggMesh = Instance.new("SpecialMesh")
    eggMesh.MeshType = Enum.MeshType.Sphere
    eggMesh.Scale = Vector3.new(1, 1.2, 1)
    eggMesh.Parent = eggPart

    -- Tint based on zone
    local zone = ZoneConfig.GetZone(egg.Zone)
    if zone then
        eggPart.Color = zone.Color
    else
        eggPart.Color = Color3.fromRGB(255, 255, 200)
    end

    -- Apply egg-specific texture on all visible faces
    local eggImage = EggVisualUtil.GetEggImage(egg)
    if eggImage ~= "rbxassetid://0" then
        applyEggTexture(eggPart, eggImage)
    end

    eggPart.Parent = eggModel

    -- Pedestal
    local pedestal = Instance.new("Part")
    pedestal.Name = "Pedestal"
    pedestal.Size = Vector3.new(10, 1, 10)
    pedestal.Position = position + Vector3.new(0, 0.5, 0)
    pedestal.Anchored = true
    pedestal.CanCollide = true
    pedestal.Material = Enum.Material.Marble
    pedestal.Color = Color3.fromRGB(60, 60, 80)
    pedestal.Parent = eggModel

    local pedestalRing = Instance.new("Part")
    pedestalRing.Name = "PedestalRing"
    pedestalRing.Shape = Enum.PartType.Cylinder
    pedestalRing.Size = Vector3.new(0.5, 12, 12)
    pedestalRing.CFrame = CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pedestalRing.Anchored = true
    pedestalRing.CanCollide = false
    pedestalRing.Material = Enum.Material.Neon
    if zone then
        pedestalRing.Color = zone.Color
    else
        pedestalRing.Color = Color3.fromRGB(200, 200, 100)
    end
    pedestalRing.Parent = eggModel

    -- Billboard GUI with egg info
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EggInfo"
    billboard.Size = UDim2.new(0, 200, 0, 80)
    billboard.StudsOffset = Vector3.new(0, 12, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent = eggPart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = egg.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextScaled = true
    nameLabel.Parent = billboard

    local costText = formatCost(egg.Cost)
    local costLabel = Instance.new("TextLabel")
    costLabel.Size = UDim2.new(1, 0, 0.4, 0)
    costLabel.Position = UDim2.new(0, 0, 0.5, 0)
    costLabel.BackgroundTransparency = 1
    costLabel.Text = costText .. " " .. egg.Currency
    costLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
    costLabel.TextStrokeTransparency = 0
    costLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    costLabel.Font = Enum.Font.GothamBold
    costLabel.TextScaled = true
    costLabel.Parent = billboard

    -- Click detector for collecting
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 15
    clickDetector.Parent = eggPart

    clickDetector.MouseClick:Connect(function(player)
        EggService.CollectEgg(player, egg.Id)
    end)

    -- ProximityPrompt as alternative
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect"
    prompt.ObjectText = egg.Name .. " (" .. costText .. ")"
    prompt.MaxActivationDistance = 12
    prompt.HoldDuration = 0
    prompt.Parent = eggPart

    prompt.Triggered:Connect(function(player)
        EggService.CollectEgg(player, egg.Id)
    end)

    -- Egg idle animation (gentle bob + slow rotate)
    task.spawn(function()
        local baseY = eggPart.Position.Y
        local rotation = math.random() * 360
        while eggPart.Parent do
            rotation = rotation + 0.5
            local bob = math.sin(tick() * 1.5) * 0.3
            eggPart.CFrame = CFrame.new(
                eggPart.Position.X, baseY + bob, eggPart.Position.Z
            ) * CFrame.Angles(0, math.rad(rotation), 0)
            task.wait()
        end
    end)

    eggModel.Parent = zoneFolder
end

function EggSpawnerService.Init(eggService)
    EggService = eggService

    -- Group eggs by zone
    for _, zone in ipairs(ZoneConfig.Zones) do
        local zoneFolder = getOrCreateZoneFolder(zone.Id)
        local eggsFolder = Instance.new("Folder")
        eggsFolder.Name = "Eggs"
        eggsFolder.Parent = zoneFolder

        local zoneEggs = EggConfig.GetEggsByZone(zone.Id)
        for i, egg in ipairs(zoneEggs) do
            local offset = EGG_OFFSETS[i] or Vector3.new((i - 1) * 20 - 10, 0, -30)
            local position = zone.SpawnPosition + offset
            createEggObject(egg, position, eggsFolder)
        end
    end

    print("[EggSpawnerService] Spawned egg objects in " .. #ZoneConfig.Zones .. " zones")

    -- Debug: log first egg position
    local fz = ZoneConfig.Zones[1]
    if fz then
        local eggY = fz.SpawnPosition.Y + EGG_SIZE.Y / 2 + 2.0
        print(string.format("[EggSpawnerService] Zone 1 egg center Y=%.1f, ground top Y=%.1f", eggY, fz.SpawnPosition.Y))
    end
end

return EggSpawnerService
