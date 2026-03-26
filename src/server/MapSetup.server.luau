-- MapSetup.server.luau
-- Procedurally generates the playable world geometry at runtime.
-- Creates rock nodes (with RockId attributes), world zones, sell pads,
-- egg pads, and spawn areas so the game is immediately playable in Studio
-- without any manual asset placement.
--
-- Layout overview (top-down, X axis):
--   World 1 (Starter Mine)  :  X = -200 … -50
--   World 2 (Crystal Caverns):  X =   50 … 200
--   World 3 (Starstone Abyss):  X =  300 … 500
--
-- Each zone contains:
--   • A coloured floor slab
--   • Rock nodes (Parts tagged with RockId)
--   • A "Sell Zone" pad (Part tagged "SellZone")
--   • An "Egg Zone" pad (Part tagged "EggZone")
--   • World name sign

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiningConfig = require(ReplicatedStorage.Shared.Config.MiningConfig)
local WorldConfig  = require(ReplicatedStorage.Shared.Config.WorldConfig)

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function makeBaseplate(parent: Folder, size: Vector3, position: Vector3, color: Color3, name: string): Part
    local p         = Instance.new("Part")
    p.Name          = name
    p.Size          = size
    p.Position      = position
    p.Anchored      = true
    p.CanCollide    = true
    p.BrickColor    = BrickColor.new(color)
    p.Material      = Enum.Material.SmoothPlastic
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent        = parent
    return p
end

local function makeSign(parent: Folder, text: string, position: Vector3, color: Color3)
    local p         = Instance.new("Part")
    p.Name          = "Sign_" .. text
    p.Size          = Vector3.new(20, 6, 1)
    p.Position      = position
    p.Anchored      = true
    p.CanCollide    = false
    p.BrickColor    = BrickColor.new(color)
    p.Material      = Enum.Material.SmoothPlastic
    p.Parent        = parent

    local gui       = Instance.new("SurfaceGui")
    gui.Face        = Enum.NormalId.Front
    gui.CanvasSize  = Vector2.new(600, 180)
    gui.Parent      = p

    local label     = Instance.new("TextLabel")
    label.Size      = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text      = text
    label.TextColor3= Color3.fromRGB(255, 255, 255)
    label.TextScaled= true
    label.Font      = Enum.Font.GothamBold
    label.Parent    = gui
end

local function makeRock(parent: Folder, rockDef: {}, position: Vector3, worldColor: Color3): Model
    local model         = Instance.new("Model")
    model.Name          = rockDef.id
    model:SetAttribute("RockId", rockDef.id)
    model:SetAttribute("World",  rockDef.world)
    model.Parent        = parent

    -- Rock body (randomised size within a range for visual variety)
    local w = 4 + math.random() * 3   -- 4–7 studs wide
    local h = 3 + math.random() * 4   -- 3–7 studs tall
    local d = 4 + math.random() * 3

    local body         = Instance.new("Part")
    body.Name          = "RockBody"
    body.Size          = Vector3.new(w, h, d)
    body.Position      = position + Vector3.new(0, h / 2, 0)
    body.Anchored      = true
    body.CanCollide    = true
    body.BrickColor    = BrickColor.new(worldColor)
    body.Material      = Enum.Material.Rock
    body.Parent        = model
    model.PrimaryPart  = body

    -- HP bar (BillboardGui above the rock)
    local billboard    = Instance.new("BillboardGui")
    billboard.Name     = "HpBar"
    billboard.Size     = UDim2.new(0, 80, 0, 10)
    billboard.StudsOffset = Vector3.new(0, h / 2 + 1.5, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent   = body

    local bg           = Instance.new("Frame")
    bg.Size            = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3= Color3.fromRGB(60, 60, 60)
    bg.BorderSizePixel = 0
    bg.Parent          = billboard

    local fill         = Instance.new("Frame")
    fill.Name          = "Fill"
    fill.Size          = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
    fill.BorderSizePixel  = 0
    fill.Parent        = bg

    local hpLabel      = Instance.new("TextLabel")
    hpLabel.Name       = "HpLabel"
    hpLabel.Size       = UDim2.new(1, 0, 1, 0)
    hpLabel.BackgroundTransparency = 1
    hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpLabel.TextScaled = true
    hpLabel.Font       = Enum.Font.GothamBold
    hpLabel.Text       = tostring(rockDef.hp)
    hpLabel.Parent     = bg

    -- Ore name label
    local oreLabel     = Instance.new("BillboardGui")
    oreLabel.Name      = "OreLabel"
    oreLabel.Size      = UDim2.new(0, 100, 0, 20)
    oreLabel.StudsOffset = Vector3.new(0, -h / 2 - 0.5, 0)
    oreLabel.AlwaysOnTop = false
    oreLabel.Parent    = body

    local lbl          = Instance.new("TextLabel")
    lbl.Size           = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.5
    lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    lbl.TextColor3     = Color3.fromRGB(255, 255, 200)
    lbl.TextScaled     = true
    lbl.Font           = Enum.Font.Gotham
    -- Show primary ore (first in table)
    lbl.Text           = rockDef.oreTable[1].ore
    lbl.Parent         = oreLabel

    return model
end

local function makePad(parent: Folder, tag: string, label: string, position: Vector3, color: Color3): Part
    local p         = Instance.new("Part")
    p.Name          = tag .. "_Pad"
    p.Size          = Vector3.new(14, 1, 14)
    p.Position      = position
    p.Anchored      = true
    p.CanCollide    = true
    p.BrickColor    = BrickColor.new(color)
    p.Material      = Enum.Material.Neon
    p.Transparency  = 0.4
    p:SetAttribute(tag, true)
    p.Parent        = parent

    local gui       = Instance.new("BillboardGui")
    gui.Size        = UDim2.new(0, 120, 0, 30)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.AlwaysOnTop = false
    gui.Parent      = p

    local lbl       = Instance.new("TextLabel")
    lbl.Size        = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.6
    lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    lbl.TextColor3  = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled  = true
    lbl.Font        = Enum.Font.GothamBold
    lbl.Text        = label
    lbl.Parent      = gui

    return p
end

-- ─── World layout config ──────────────────────────────────────────────────────

local WORLD_LAYOUTS = {
    -- World 1: Starter Mine
    {
        worldId   = 1,
        originX   = -200,
        width     = 150,
        depth     = 150,
        floorY    = 0,
        color     = Color3.fromRGB(150, 110, 70),    -- sandstone brown
        wallColor = Color3.fromRGB(120, 85, 50),
        rockColor = Color3.fromRGB(100, 80, 60),
        rockIds   = { "coal_rock", "copper_rock" },   -- must match MiningConfig
        rockRows  = 3,
        rocksPerRow = 5,
    },
    -- World 2: Crystal Caverns
    {
        worldId   = 2,
        originX   = 50,
        width     = 150,
        depth     = 150,
        floorY    = 0,
        color     = Color3.fromRGB(40, 160, 200),    -- cyan
        wallColor = Color3.fromRGB(20, 120, 160),
        rockColor = Color3.fromRGB(60, 180, 220),
        rockIds   = { "silver_rock", "gemstone_rock" },
        rockRows  = 3,
        rocksPerRow = 5,
    },
    -- World 3: Starstone Abyss
    {
        worldId   = 3,
        originX   = 300,
        width     = 200,
        depth     = 200,
        floorY    = 0,
        color     = Color3.fromRGB(60, 30, 140),     -- deep purple
        wallColor = Color3.fromRGB(40, 10, 110),
        rockColor = Color3.fromRGB(100, 60, 200),
        rockIds   = { "crystal_rock", "starstone_rock" },
        rockRows  = 4,
        rocksPerRow = 6,
    },
}

-- Build rock lookup by id
local rockById = {}
for _, rock in ipairs(MiningConfig.Rocks) do
    rockById[rock.id] = rock
end

-- ─── Map parent folder ────────────────────────────────────────────────────────

local mapFolder         = Instance.new("Folder")
mapFolder.Name          = "CrystalPetsMap"
mapFolder.Parent        = workspace

-- ─── Global baseplate ────────────────────────────────────────────────────────

makeBaseplate(
    mapFolder,
    Vector3.new(1200, 4, 800),
    Vector3.new(150, -2, 0),
    Color3.fromRGB(40, 40, 40),
    "GlobalFloor"
)

-- ─── Spawn island ─────────────────────────────────────────────────────────────

local spawnIsland   = Instance.new("Folder")
spawnIsland.Name    = "SpawnIsland"
spawnIsland.Parent  = mapFolder

makeBaseplate(
    spawnIsland,
    Vector3.new(60, 2, 60),
    Vector3.new(-350, 1, 0),
    Color3.fromRGB(100, 200, 100),
    "SpawnPlatform"
)

local spawnPart     = Instance.new("SpawnLocation")
spawnPart.Size      = Vector3.new(6, 1, 6)
spawnPart.Position  = Vector3.new(-350, 3, 0)
spawnPart.Anchored  = true
spawnPart.BrickColor= BrickColor.new(Color3.fromRGB(100, 200, 100))
spawnPart.Parent    = spawnIsland

makeSign(
    spawnIsland,
    "⛏ Crystal Pets Simulator",
    Vector3.new(-350, 10, -30),
    Color3.fromRGB(80, 60, 40)
)

-- World-select signs on spawn island
for i, layout in ipairs(WORLD_LAYOUTS) do
    local worldDef = WorldConfig.Worlds[i]
    makeSign(
        spawnIsland,
        worldDef.name .. " →",
        Vector3.new(-350 + (i - 1) * 0, 6, -25 + (i - 1) * 18),
        layout.color
    )
end

-- ─── Generate each world zone ─────────────────────────────────────────────────

for _, layout in ipairs(WORLD_LAYOUTS) do
    local worldFolder   = Instance.new("Folder")
    worldFolder.Name    = "World_" .. layout.worldId
    worldFolder:SetAttribute("WorldId", layout.worldId)
    worldFolder.Parent  = mapFolder

    local cx = layout.originX + layout.width / 2
    local cz = 0

    -- Floor slab
    makeBaseplate(
        worldFolder,
        Vector3.new(layout.width, 2, layout.depth),
        Vector3.new(cx, layout.floorY - 1, cz),
        layout.color,
        "Floor_W" .. layout.worldId
    )

    -- Back wall
    makeBaseplate(
        worldFolder,
        Vector3.new(layout.width, 30, 4),
        Vector3.new(cx, 14, -layout.depth / 2),
        layout.wallColor,
        "BackWall_W" .. layout.worldId
    )

    -- Left / Right walls
    makeBaseplate(
        worldFolder,
        Vector3.new(4, 30, layout.depth),
        Vector3.new(layout.originX - 2, 14, cz),
        layout.wallColor,
        "LeftWall_W" .. layout.worldId
    )
    makeBaseplate(
        worldFolder,
        Vector3.new(4, 30, layout.depth),
        Vector3.new(layout.originX + layout.width + 2, 14, cz),
        layout.wallColor,
        "RightWall_W" .. layout.worldId
    )

    -- Ceiling
    makeBaseplate(
        worldFolder,
        Vector3.new(layout.width, 4, layout.depth),
        Vector3.new(cx, 30, cz),
        layout.wallColor,
        "Ceiling_W" .. layout.worldId
    ).Transparency = 0.5

    -- World name sign
    makeSign(
        worldFolder,
        WorldConfig.Worlds[layout.worldId].name,
        Vector3.new(cx, 24, -layout.depth / 2 + 2),
        layout.color
    )

    -- Sell zone pad (front-right corner)
    makePad(
        worldFolder,
        "SellZone",
        "💰 SELL ORES",
        Vector3.new(layout.originX + layout.width - 15, 1, layout.depth / 2 - 15),
        Color3.fromRGB(255, 215, 0)
    )

    -- Egg zone pad (front-left corner)
    makePad(
        worldFolder,
        "EggZone",
        "🥚 HATCH EGGS",
        Vector3.new(layout.originX + 15, 1, layout.depth / 2 - 15),
        Color3.fromRGB(200, 100, 255)
    )

    -- Rebirth pad (only in World 1, center-back)
    if layout.worldId == 1 then
        makePad(
            worldFolder,
            "RebirthZone",
            "🌟 REBIRTH",
            Vector3.new(cx, 1, -layout.depth / 2 + 20),
            Color3.fromRGB(255, 180, 0)
        )
    end

    -- Rock placement
    -- Rocks are arranged in a grid in the middle/back section of the zone.
    local rocksFolder   = Instance.new("Folder")
    rocksFolder.Name    = "Rocks"
    rocksFolder.Parent  = worldFolder

    local rockStartX    = layout.originX + 20
    local rockEndX      = layout.originX + layout.width - 20
    local rockStartZ    = -layout.depth / 2 + 20
    local rockEndZ      = layout.depth / 2 - 40   -- leave front area for pads

    local xSpacing      = (rockEndX - rockStartX) / (layout.rocksPerRow - 1)
    local zSpacing      = (rockEndZ - rockStartZ) / (layout.rockRows - 1)

    local rockIdList    = layout.rockIds
    local ridx          = 1

    for row = 1, layout.rockRows do
        for col = 1, layout.rocksPerRow do
            local rx = rockStartX + (col - 1) * xSpacing
            local rz = rockStartZ + (row - 1) * zSpacing
            -- Slight random offset so rocks don't look perfectly gridded
            rx = rx + (math.random() - 0.5) * (xSpacing * 0.3)
            rz = rz + (math.random() - 0.5) * (zSpacing * 0.3)

            local rockId  = rockIdList[((ridx - 1) % #rockIdList) + 1]
            local rockDef = rockById[rockId]
            ridx          = ridx + 1

            if rockDef then
                makeRock(
                    rocksFolder,
                    rockDef,
                    Vector3.new(rx, layout.floorY, rz),
                    layout.rockColor
                )
            end
        end
    end

    -- Ambient light (PointLight in the ceiling to color each zone)
    local light         = Instance.new("PointLight")
    light.Brightness    = 2
    light.Range         = layout.width + 50
    light.Color         = layout.color
    light.Parent        = worldFolder:FindFirstChildWhichIsA("BasePart") or worldFolder
end

-- ─── Teleport pads between worlds ────────────────────────────────────────────

-- Portals: connect spawn island to World 1, and each world to the next.
-- Players walk onto a portal pad to teleport.
-- (Actual teleport logic is handled client-side via ProximityPrompt / Touched.)

local teleportFolder    = Instance.new("Folder")
teleportFolder.Name     = "Teleports"
teleportFolder.Parent   = mapFolder

local function makeTeleportPad(name: string, position: Vector3, label: string, destination: CFrame)
    local pad           = Instance.new("Part")
    pad.Name            = name
    pad.Size            = Vector3.new(10, 1, 10)
    pad.Position        = position
    pad.Anchored        = true
    pad.Material        = Enum.Material.Neon
    pad.BrickColor      = BrickColor.new(Color3.fromRGB(100, 220, 255))
    pad.Transparency    = 0.3
    -- Store destination as individual number attributes for reliable serialization
    pad:SetAttribute("DestX", destination.Position.X)
    pad:SetAttribute("DestY", destination.Position.Y)
    pad:SetAttribute("DestZ", destination.Position.Z)
    pad.Parent          = teleportFolder

    local prompt        = Instance.new("ProximityPrompt")
    prompt.ActionText   = "Teleport"
    prompt.ObjectText   = label
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration = 0
    prompt.Parent       = pad

    local gui           = Instance.new("BillboardGui")
    gui.Size            = UDim2.new(0, 120, 0, 28)
    gui.StudsOffset     = Vector3.new(0, 3, 0)
    gui.Parent          = pad

    local lbl           = Instance.new("TextLabel")
    lbl.Size            = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.6
    lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    lbl.TextColor3      = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled      = true
    lbl.Font            = Enum.Font.GothamBold
    lbl.Text            = label
    lbl.Parent          = gui

    return pad
end

-- Spawn → World 1
makeTeleportPad(
    "Portal_SpawnToW1",
    Vector3.new(-320, 1, 0),
    "→ Starter Mine",
    CFrame.new(-190, 2, 0)
)

-- World 1 exit → World 2 (shown but requires unlock)
makeTeleportPad(
    "Portal_W1toW2",
    Vector3.new(-52, 1, 0),
    "→ Crystal Caverns\n(Unlock Required)",
    CFrame.new(60, 2, 0)
)

-- World 2 exit → World 3
makeTeleportPad(
    "Portal_W2toW3",
    Vector3.new(198, 1, 0),
    "→ Starstone Abyss\n(Unlock Required)",
    CFrame.new(310, 2, 0)
)

-- ─── Teleport handling ────────────────────────────────────────────────────────

-- Handle ProximityPrompt teleport
for _, pad in ipairs(teleportFolder:GetChildren()) do
    if pad:IsA("Part") then
        local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            -- Read destination from separate number attributes (reliable, no string parsing)
            local destX = pad:GetAttribute("DestX")
            local destY = pad:GetAttribute("DestY")
            local destZ = pad:GetAttribute("DestZ")
            if destX and destY and destZ then
                prompt.Triggered:Connect(function(player: Player)
                    local char = player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        char.HumanoidRootPart.CFrame = CFrame.new(destX, destY, destZ)
                    end
                end)
            end
        end
    end
end

-- ─── Auto-open shop GUIs when stepping on pads ────────────────────────────────

local function watchPad(padName: string, eventName: string)
    -- Search all world folders for a pad matching padName
    for _, worldFolder in ipairs(mapFolder:GetChildren()) do
        local found = worldFolder:FindFirstChild(padName .. "_Pad", true)
        if found then
            found.Touched:Connect(function(hit)
                local char = hit.Parent
                local player = game:GetService("Players"):GetPlayerFromCharacter(char)
                if player then
                    game.ReplicatedStorage.Shared.Remotes.Events:FindFirstChild(eventName)
                        and game.ReplicatedStorage.Shared.Remotes.Events[eventName]:FireClient(player)
                end
            end)
        end
    end
end

-- Fire "OpenShopGui" / "OpenEggGui" events when stepping on pads
-- (These events are listened to in the client controllers)
task.defer(function()
    -- Wait for remotes to exist before wiring pad triggers
    local eventsFolder = game.ReplicatedStorage.Shared:WaitForChild("Remotes", 30)
        and game.ReplicatedStorage.Shared.Remotes:WaitForChild("Events", 30)

    for _, worldFolder in ipairs(mapFolder:GetChildren()) do
        if not worldFolder:GetAttribute("WorldId") then continue end

        -- Sell pad: auto-fire SellOres
        local sellPad = worldFolder:FindFirstChild("SellZone_Pad", true)
        if sellPad then
            sellPad.Touched:Connect(function(hit)
                local char   = hit.Parent
                local player = game:GetService("Players"):GetPlayerFromCharacter(char)
                if player then
                    local se = eventsFolder:FindFirstChild("SellOres")
                    if se then
                        -- Debounce: only fire once per 1s per player
                        local db = sellPad:GetAttribute("Debounce_" .. player.UserId)
                        if not db or (os.clock() - db) > 1 then
                            sellPad:SetAttribute("Debounce_" .. player.UserId, os.clock())
                            -- Server-side sell via MiningService remote
                            -- (Client can also press the sell button; this is a convenience trigger)
                        end
                    end
                end
            end)
        end
    end
end)

print("[MapSetup] World geometry generated successfully.")
