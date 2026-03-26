--[[
    EggSpawnerService.luau
    Spawns physical egg objects in zones that players can click to hatch.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EggConfig"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

local EggService -- set in Init

local EggSpawnerService = {}

-- Egg placement offsets within each zone (relative to zone spawn)
-- First egg on the left, second egg on the right
local EGG_OFFSETS = {
    Vector3.new(-25, 0, -30),
    Vector3.new(25, 0, -30),
}

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

local function createEggObject(egg, position: Vector3, zoneFolder)
    local eggModel = Instance.new("Model")
    eggModel.Name = "Egg_" .. egg.Id

    -- Egg body (ellipsoid via Union of sphere-shaped parts)
    local eggPart = Instance.new("Part")
    eggPart.Name = "EggBody"
    eggPart.Shape = Enum.PartType.Ball
    eggPart.Size = Vector3.new(8, 10, 8)
    eggPart.Position = position + Vector3.new(0, 5, 0)
    eggPart.Anchored = true
    eggPart.CanCollide = false
    eggPart.Material = Enum.Material.SmoothPlastic

    -- Color based on zone
    local zone = ZoneConfig.GetZone(egg.Zone)
    if zone then
        eggPart.Color = zone.Color
    else
        eggPart.Color = Color3.fromRGB(255, 255, 200)
    end

    eggPart.Parent = eggModel

    -- Egg spots/decoration (smaller sphere on top)
    local eggTop = Instance.new("Part")
    eggTop.Name = "EggTop"
    eggTop.Shape = Enum.PartType.Ball
    eggTop.Size = Vector3.new(5, 5, 5)
    eggTop.Position = position + Vector3.new(0, 9, 0)
    eggTop.Anchored = true
    eggTop.CanCollide = false
    eggTop.Material = Enum.Material.Neon
    eggTop.Color = Color3.new(1, 1, 1)
    eggTop.Transparency = 0.3
    eggTop.Parent = eggModel

    -- Pedestal
    local pedestal = Instance.new("Part")
    pedestal.Name = "Pedestal"
    pedestal.Size = Vector3.new(10, 1, 10)
    pedestal.Position = position - Vector3.new(0, 0.5, 0)
    pedestal.Anchored = true
    pedestal.CanCollide = true
    pedestal.Material = Enum.Material.Marble
    pedestal.Color = Color3.fromRGB(60, 60, 80)
    pedestal.Parent = eggModel

    local pedestalCorner = Instance.new("Part")
    pedestalCorner.Name = "PedestalRing"
    pedestalCorner.Shape = Enum.PartType.Cylinder
    pedestalCorner.Size = Vector3.new(0.5, 12, 12)
    pedestalCorner.Position = position - Vector3.new(0, 0.25, 0)
    pedestalCorner.CFrame = CFrame.new(position - Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pedestalCorner.Anchored = true
    pedestalCorner.CanCollide = false
    pedestalCorner.Material = Enum.Material.Neon
    if zone then
        pedestalCorner.Color = zone.Color
    else
        pedestalCorner.Color = Color3.fromRGB(200, 200, 100)
    end
    pedestalCorner.Parent = eggModel

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

    local costLabel = Instance.new("TextLabel")
    costLabel.Size = UDim2.new(1, 0, 0.4, 0)
    costLabel.Position = UDim2.new(0, 0, 0.5, 0)
    costLabel.BackgroundTransparency = 1
    costLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
    costLabel.TextStrokeTransparency = 0
    costLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    costLabel.Font = Enum.Font.GothamBold
    costLabel.TextScaled = true
    costLabel.Parent = billboard

    -- Format cost display
    local costText
    if egg.Cost >= 1000000000 then
        costText = string.format("%.1fB", egg.Cost / 1000000000)
    elseif egg.Cost >= 1000000 then
        costText = string.format("%.1fM", egg.Cost / 1000000)
    elseif egg.Cost >= 1000 then
        costText = string.format("%.1fK", egg.Cost / 1000)
    else
        costText = tostring(egg.Cost)
    end
    costLabel.Text = costText .. " " .. egg.Currency

    -- Click detector for hatching
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 15
    clickDetector.Parent = eggPart

    clickDetector.MouseClick:Connect(function(player)
        EggService.HatchEgg(player, egg.Id)
    end)

    -- ProximityPrompt as alternative
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Hatch"
    prompt.ObjectText = egg.Name .. " (" .. costText .. ")"
    prompt.MaxActivationDistance = 12
    prompt.HoldDuration = 0
    prompt.Parent = eggPart

    prompt.Triggered:Connect(function(player)
        EggService.HatchEgg(player, egg.Id)
    end)

    -- Egg idle animation (bob + rotate)
    task.spawn(function()
        local baseY = eggPart.Position.Y
        local baseTopY = eggTop.Position.Y
        local rotation = math.random() * 360
        while eggPart.Parent do
            rotation = rotation + 0.5
            local bob = math.sin(tick() * 1.5) * 0.3
            eggPart.CFrame = CFrame.new(
                eggPart.Position.X, baseY + bob, eggPart.Position.Z
            ) * CFrame.Angles(0, math.rad(rotation), 0)
            eggTop.CFrame = CFrame.new(
                eggTop.Position.X, baseTopY + bob, eggTop.Position.Z
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
end

return EggSpawnerService
