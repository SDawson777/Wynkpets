--[[
    NPCService.luau
    Spawns Part-based NPC merchants with BillboardGui names and ProximityPrompts.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

local NPCService = {}

local NPC_CONFIGS = {
    {
        Id = "shop_npc",
        Name = "Shopkeeper",
        Zone = "starter_meadow",
        Offset = Vector3.new(15, 0, 15),
        Color = Color3.fromRGB(50, 200, 100),
        Action = "OpenShop",
        ActionText = "Shop",
        ObjectText = "Shopkeeper",
    },
    {
        Id = "trade_npc",
        Name = "Trade Master",
        Zone = "starter_meadow",
        Offset = Vector3.new(-15, 0, 15),
        Color = Color3.fromRGB(100, 200, 255),
        Action = "OpenTrade",
        ActionText = "Trade",
        ObjectText = "Trade Master",
    },
    {
        Id = "fuse_npc",
        Name = "Fusion Expert",
        Zone = "crystal_caves",
        Offset = Vector3.new(0, 0, 20),
        Color = Color3.fromRGB(255, 100, 200),
        Action = "OpenFuse",
        ActionText = "Fuse Pets",
        ObjectText = "Fusion Expert",
    },
    {
        Id = "rebirth_npc",
        Name = "Rebirth Sage",
        Zone = "forest_grove",
        Offset = Vector3.new(0, 0, 20),
        Color = Color3.fromRGB(255, 100, 150),
        Action = "OpenRebirth",
        ActionText = "Rebirth",
        ObjectText = "Rebirth Sage",
    },
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

local function createNPC(config)
    local zone = ZoneConfig.GetZone(config.Zone)
    if not zone then return end

    local zoneFolder = getOrCreateZoneFolder(config.Zone)
    local npcFolder = zoneFolder:FindFirstChild("NPCs")
    if not npcFolder then
        npcFolder = Instance.new("Folder")
        npcFolder.Name = "NPCs"
        npcFolder.Parent = zoneFolder
    end

    local position = zone.SpawnPosition + config.Offset

    local npcModel = Instance.new("Model")
    npcModel.Name = "NPC_" .. config.Id

    -- Body (torso) — wider and taller for visibility
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(3, 3.5, 2)
    body.Position = position + Vector3.new(0, 3.25, 0)
    body.Anchored = true
    body.CanCollide = true
    body.Material = Enum.Material.SmoothPlastic
    body.Color = config.Color
    body.Parent = npcModel

    -- Outfit front panel (apron / badge area)
    local apron = Instance.new("Part")
    apron.Name = "Apron"
    apron.Size = Vector3.new(2.4, 2.2, 0.15)
    apron.Position = position + Vector3.new(0, 3.2, -1.05)
    apron.Anchored = true
    apron.CanCollide = false
    apron.Material = Enum.Material.SmoothPlastic
    apron.Color = Color3.fromRGB(
        math.clamp(math.floor(config.Color.R * 255 * 0.7), 0, 255),
        math.clamp(math.floor(config.Color.G * 255 * 0.7), 0, 255),
        math.clamp(math.floor(config.Color.B * 255 * 0.7), 0, 255)
    )
    apron.Parent = npcModel

    -- Role label on the apron
    local apronGui = Instance.new("SurfaceGui")
    apronGui.Face = Enum.NormalId.Front
    apronGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    apronGui.PixelsPerStud = 60
    apronGui.Parent = apron

    local roleLabel = Instance.new("TextLabel")
    roleLabel.Size = UDim2.new(1, 0, 1, 0)
    roleLabel.BackgroundTransparency = 1
    roleLabel.Text = config.ActionText
    roleLabel.TextColor3 = Color3.new(1, 1, 1)
    roleLabel.Font = Enum.Font.GothamBold
    roleLabel.TextScaled = true
    roleLabel.Parent = apronGui

    -- Head — slightly larger
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(2.6, 2.6, 2.6)
    head.Position = position + Vector3.new(0, 6.1, 0)
    head.Anchored = true
    head.CanCollide = false
    head.Material = Enum.Material.SmoothPlastic
    head.Color = Color3.fromRGB(255, 210, 170)
    head.Parent = npcModel

    -- Face decal (simple smiley using SurfaceGui)
    local faceGui = Instance.new("SurfaceGui")
    faceGui.Face = Enum.NormalId.Front
    faceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    faceGui.PixelsPerStud = 50
    faceGui.Parent = head

    local faceLabel = Instance.new("TextLabel")
    faceLabel.Size = UDim2.new(1, 0, 1, 0)
    faceLabel.BackgroundTransparency = 1
    faceLabel.Text = "😊"
    faceLabel.TextScaled = true
    faceLabel.Parent = faceGui

    -- Hat (color-coded cylinder on top of head)
    local hat = Instance.new("Part")
    hat.Name = "Hat"
    hat.Shape = Enum.PartType.Cylinder
    hat.Size = Vector3.new(0.8, 3, 3)
    hat.CFrame = CFrame.new(position + Vector3.new(0, 7.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
    hat.Anchored = true
    hat.CanCollide = false
    hat.Material = Enum.Material.SmoothPlastic
    hat.Color = config.Color
    hat.Parent = npcModel

    -- Hat brim
    local brim = Instance.new("Part")
    brim.Name = "Brim"
    brim.Shape = Enum.PartType.Cylinder
    brim.Size = Vector3.new(0.2, 3.8, 3.8)
    brim.CFrame = CFrame.new(position + Vector3.new(0, 7.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
    brim.Anchored = true
    brim.CanCollide = false
    brim.Material = Enum.Material.SmoothPlastic
    brim.Color = config.Color
    brim.Parent = npcModel

    -- Left arm
    local leftArm = Instance.new("Part")
    leftArm.Name = "LeftArm"
    leftArm.Size = Vector3.new(1, 2.8, 1)
    leftArm.Position = position + Vector3.new(-2, 3, 0)
    leftArm.Anchored = true
    leftArm.CanCollide = false
    leftArm.Material = Enum.Material.SmoothPlastic
    leftArm.Color = config.Color
    leftArm.Parent = npcModel

    -- Right arm
    local rightArm = Instance.new("Part")
    rightArm.Name = "RightArm"
    rightArm.Size = Vector3.new(1, 2.8, 1)
    rightArm.Position = position + Vector3.new(2, 3, 0)
    rightArm.Anchored = true
    rightArm.CanCollide = false
    rightArm.Material = Enum.Material.SmoothPlastic
    rightArm.Color = config.Color
    rightArm.Parent = npcModel

    -- Left leg
    local leftLeg = Instance.new("Part")
    leftLeg.Name = "LeftLeg"
    leftLeg.Size = Vector3.new(1.2, 2, 1.2)
    leftLeg.Position = position + Vector3.new(-0.7, 1, 0)
    leftLeg.Anchored = true
    leftLeg.CanCollide = false
    leftLeg.Material = Enum.Material.SmoothPlastic
    leftLeg.Color = Color3.fromRGB(50, 50, 80)
    leftLeg.Parent = npcModel

    -- Right leg
    local rightLeg = Instance.new("Part")
    rightLeg.Name = "RightLeg"
    rightLeg.Size = Vector3.new(1.2, 2, 1.2)
    rightLeg.Position = position + Vector3.new(0.7, 1, 0)
    rightLeg.Anchored = true
    rightLeg.CanCollide = false
    rightLeg.Material = Enum.Material.SmoothPlastic
    rightLeg.Color = Color3.fromRGB(50, 50, 80)
    rightLeg.Parent = npcModel

    -- Name billboard
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "NPCLabel"
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent = head

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = config.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextScaled = true
    nameLabel.Parent = billboard

    -- Proximity prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = config.ActionText
    prompt.ObjectText = config.ObjectText
    prompt.MaxActivationDistance = 10
    prompt.HoldDuration = 0
    prompt.Parent = body

    prompt.Triggered:Connect(function(player)
        Network.FireClient(config.Action, player)
    end)

    npcModel.Parent = npcFolder
end

function NPCService.Init()
    for _, config in ipairs(NPC_CONFIGS) do
        createNPC(config)
    end

    print("[NPCService] Spawned " .. #NPC_CONFIGS .. " NPCs")
end

return NPCService
