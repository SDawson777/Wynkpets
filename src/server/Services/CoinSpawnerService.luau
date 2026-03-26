--[[
    CoinSpawnerService.luau
    Spawns and manages collectible coins in each zone.
    Creates clickable coin parts that players can collect.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

local CoinSpawnerService = {}

local COINS_PER_ZONE = 20
local COIN_RESPAWN_TIME = 3 -- seconds after collection
local COIN_SIZE = Vector3.new(2, 2, 0.4)
local COIN_SPAWN_RADIUS = 50
local COIN_Y_HEIGHT = 3

-- Create a zone container folder in workspace
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

-- Create a single coin part
local function createCoin(zone, position: Vector3, index: number)
    local coin = Instance.new("Part")
    coin.Name = "Coin_" .. zone.Id .. "_" .. index
    coin.Size = COIN_SIZE
    coin.Shape = Enum.PartType.Cylinder
    coin.BrickColor = BrickColor.new("Bright yellow")
    coin.Material = Enum.Material.Neon
    coin.Anchored = true
    coin.CanCollide = false
    coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))

    -- Add click detector
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 15
    clickDetector.Parent = coin

    -- Add zone identifier
    local zoneValue = Instance.new("StringValue")
    zoneValue.Name = "ZoneId"
    zoneValue.Value = zone.Id
    zoneValue.Parent = coin

    -- Billboard GUI for visual appeal
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CoinLabel"
    billboard.Size = UDim2.new(0, 50, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent = coin

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "+" .. zone.CoinValue
    label.TextColor3 = Color3.fromRGB(255, 255, 100)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = billboard

    -- Spinning animation
    task.spawn(function()
        local rotation = math.random() * 360
        while coin.Parent do
            rotation = rotation + 2
            coin.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), math.rad(90))
            -- Bob up and down
            local bob = math.sin(tick() * 2 + index) * 0.5
            coin.CFrame = CFrame.new(position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, math.rad(rotation), math.rad(90))
            task.wait()
        end
    end)

    return coin
end

-- Spawn coins for a zone
function CoinSpawnerService.SpawnZoneCoins(zone)
    local zoneFolder = getOrCreateZoneFolder(zone.Id)

    local coinsFolder = Instance.new("Folder")
    coinsFolder.Name = "Coins"
    coinsFolder.Parent = zoneFolder

    for i = 1, COINS_PER_ZONE do
        local angle = (i / COINS_PER_ZONE) * math.pi * 2
        local radius = math.random(10, COIN_SPAWN_RADIUS)
        local x = zone.SpawnPosition.X + math.cos(angle) * radius
        local z = zone.SpawnPosition.Z + math.sin(angle) * radius
        local position = Vector3.new(x, zone.SpawnPosition.Y + COIN_Y_HEIGHT, z)

        local coin = createCoin(zone, position, i)
        coin.Parent = coinsFolder

        -- Set up click handler
        local clickDetector = coin:FindFirstChild("ClickDetector")
        if clickDetector then
            clickDetector.MouseClick:Connect(function(player)
                -- Coin collected - hide it
                coin.Transparency = 1
                coin.CanCollide = false
                local billboard = coin:FindFirstChild("CoinLabel")
                if billboard then billboard.Enabled = false end
                if clickDetector then clickDetector.MaxActivationDistance = 0 end

                -- Respawn after delay
                task.delay(COIN_RESPAWN_TIME, function()
                    if coin.Parent then
                        coin.Transparency = 0
                        if billboard then billboard.Enabled = true end
                        if clickDetector then clickDetector.MaxActivationDistance = 15 end
                    end
                end)

                -- Currency is granted via the client firing CollectCoin to the server,
                -- which CurrencyService handles. No server-side grant needed here.
            end)
        end
    end
end

-- Create zone ground platforms with themed environments
function CoinSpawnerService.CreateZonePlatforms()
    -- Zone-specific materials and props
    local zoneThemes = {
        starter_meadow = {
            Material = Enum.Material.Grass,
            PropColor = Color3.fromRGB(60, 140, 40),
            Props = { "tree", "flower", "bush" },
        },
        forest_grove = {
            Material = Enum.Material.LeafyGrass,
            PropColor = Color3.fromRGB(30, 100, 30),
            Props = { "bigtree", "mushroom", "vine" },
        },
        crystal_caves = {
            Material = Enum.Material.Slate,
            PropColor = Color3.fromRGB(120, 80, 220),
            Props = { "crystal", "stalagmite", "gem" },
        },
        volcanic_ridge = {
            Material = Enum.Material.Basalt,
            PropColor = Color3.fromRGB(200, 60, 20),
            Props = { "lavarock", "ember", "vent" },
        },
        frozen_tundra = {
            Material = Enum.Material.Glacier,
            PropColor = Color3.fromRGB(180, 220, 255),
            Props = { "icespike", "snowdrift", "frostcrystal" },
        },
        celestial_garden = {
            Material = Enum.Material.Marble,
            PropColor = Color3.fromRGB(200, 150, 255),
            Props = { "starflower", "moonpillar", "cloudpuff" },
        },
        shadow_realm = {
            Material = Enum.Material.Slate,
            PropColor = Color3.fromRGB(80, 30, 100),
            Props = { "darkthorn", "voidcrystal", "shadowpillar" },
        },
        cosmic_void = {
            Material = Enum.Material.Neon,
            PropColor = Color3.fromRGB(30, 0, 60),
            Props = { "neonpillar", "voidorb", "stargate" },
        },
    }

    for _, zone in ipairs(ZoneConfig.Zones) do
        local zoneFolder = getOrCreateZoneFolder(zone.Id)
        local theme = zoneThemes[zone.Id]
        local material = theme and theme.Material or Enum.Material.Grass

        -- Main ground platform (larger)
        local ground = Instance.new("Part")
        ground.Name = "Ground"
        ground.Size = Vector3.new(160, 2, 160)
        ground.Position = zone.SpawnPosition - Vector3.new(0, 1, 0)
        ground.Anchored = true
        ground.BrickColor = BrickColor.new(zone.Color)
        ground.Material = material
        ground.TopSurface = Enum.SurfaceType.Smooth
        ground.BottomSurface = Enum.SurfaceType.Smooth
        ground.Parent = zoneFolder

        -- Raised border ring
        local borderParts = {
            { Size = Vector3.new(164, 3, 2), Offset = Vector3.new(0, 0, 81) },
            { Size = Vector3.new(164, 3, 2), Offset = Vector3.new(0, 0, -81) },
            { Size = Vector3.new(2, 3, 164), Offset = Vector3.new(81, 0, 0) },
            { Size = Vector3.new(2, 3, 164), Offset = Vector3.new(-81, 0, 0) },
        }

        for i, border in ipairs(borderParts) do
            local wall = Instance.new("Part")
            wall.Name = "Border_" .. i
            wall.Size = border.Size
            wall.Position = zone.SpawnPosition + border.Offset + Vector3.new(0, 0.5, 0)
            wall.Anchored = true
            wall.CanCollide = true
            wall.Material = Enum.Material.Marble
            wall.Color = zone.Color
            wall.Parent = zoneFolder
        end

        -- Zone label
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ZoneLabel"
        billboard.Size = UDim2.new(0, 300, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 20, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = ground

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = zone.Name
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        label.Parent = billboard

        -- Spawn decorative props
        if theme then
            local propsFolder = Instance.new("Folder")
            propsFolder.Name = "Props"
            propsFolder.Parent = zoneFolder

            local propColor = theme.PropColor
            for j = 1, 12 do
                local angle = (j / 12) * math.pi * 2
                local radius = math.random(25, 65)
                local x = zone.SpawnPosition.X + math.cos(angle) * radius
                local z = zone.SpawnPosition.Z + math.sin(angle) * radius

                local propType = theme.Props[((j - 1) % #theme.Props) + 1]

                if propType == "tree" or propType == "bigtree" then
                    local trunk = Instance.new("Part")
                    trunk.Name = "Trunk_" .. j
                    trunk.Size = Vector3.new(2, propType == "bigtree" and 12 or 8, 2)
                    trunk.Position = Vector3.new(x, zone.SpawnPosition.Y + trunk.Size.Y / 2, z)
                    trunk.Anchored = true
                    trunk.CanCollide = true
                    trunk.Material = Enum.Material.Wood
                    trunk.Color = Color3.fromRGB(100, 70, 40)
                    trunk.Parent = propsFolder

                    local canopy = Instance.new("Part")
                    canopy.Name = "Canopy_" .. j
                    canopy.Shape = Enum.PartType.Ball
                    canopy.Size = Vector3.new(8, 6, 8) * (propType == "bigtree" and 1.5 or 1)
                    canopy.Position = Vector3.new(x, zone.SpawnPosition.Y + trunk.Size.Y + 2, z)
                    canopy.Anchored = true
                    canopy.CanCollide = false
                    canopy.Material = Enum.Material.Grass
                    canopy.Color = propColor
                    canopy.Parent = propsFolder

                elseif propType == "crystal" or propType == "icespike" or propType == "frostcrystal" or propType == "darkthorn" or propType == "neonpillar" then
                    local spike = Instance.new("Part")
                    spike.Name = "Crystal_" .. j
                    spike.Size = Vector3.new(1.5, math.random(4, 10), 1.5)
                    spike.Position = Vector3.new(x, zone.SpawnPosition.Y + spike.Size.Y / 2, z)
                    spike.Anchored = true
                    spike.CanCollide = true
                    spike.Material = Enum.Material.Neon
                    spike.Color = propColor
                    spike.CFrame = CFrame.new(spike.Position) * CFrame.Angles(
                        math.rad(math.random(-15, 15)), math.rad(math.random(0, 360)), math.rad(math.random(-15, 15))
                    )
                    spike.Parent = propsFolder

                elseif propType == "flower" or propType == "starflower" then
                    local stem = Instance.new("Part")
                    stem.Name = "Flower_" .. j
                    stem.Size = Vector3.new(0.3, 2, 0.3)
                    stem.Position = Vector3.new(x, zone.SpawnPosition.Y + 1, z)
                    stem.Anchored = true
                    stem.CanCollide = false
                    stem.Material = Enum.Material.Grass
                    stem.Color = Color3.fromRGB(50, 150, 50)
                    stem.Parent = propsFolder

                    local bloom = Instance.new("Part")
                    bloom.Name = "Bloom_" .. j
                    bloom.Shape = Enum.PartType.Ball
                    bloom.Size = Vector3.new(1.5, 1, 1.5)
                    bloom.Position = Vector3.new(x, zone.SpawnPosition.Y + 2.5, z)
                    bloom.Anchored = true
                    bloom.CanCollide = false
                    bloom.Material = propType == "starflower" and Enum.Material.Neon or Enum.Material.SmoothPlastic
                    bloom.Color = propColor
                    bloom.Parent = propsFolder

                elseif propType == "mushroom" then
                    local mStem = Instance.new("Part")
                    mStem.Name = "MushStem_" .. j
                    mStem.Size = Vector3.new(1, 3, 1)
                    mStem.Position = Vector3.new(x, zone.SpawnPosition.Y + 1.5, z)
                    mStem.Anchored = true
                    mStem.CanCollide = false
                    mStem.Material = Enum.Material.SmoothPlastic
                    mStem.Color = Color3.fromRGB(230, 220, 200)
                    mStem.Parent = propsFolder

                    local cap = Instance.new("Part")
                    cap.Name = "MushCap_" .. j
                    cap.Shape = Enum.PartType.Ball
                    cap.Size = Vector3.new(3, 2, 3)
                    cap.Position = Vector3.new(x, zone.SpawnPosition.Y + 3.5, z)
                    cap.Anchored = true
                    cap.CanCollide = false
                    cap.Material = Enum.Material.SmoothPlastic
                    cap.Color = propColor
                    cap.Parent = propsFolder

                elseif propType == "lavarock" or propType == "stalagmite" then
                    local rock = Instance.new("Part")
                    rock.Name = "Rock_" .. j
                    rock.Size = Vector3.new(math.random(2, 4), math.random(2, 5), math.random(2, 4))
                    rock.Position = Vector3.new(x, zone.SpawnPosition.Y + rock.Size.Y / 2, z)
                    rock.Anchored = true
                    rock.CanCollide = true
                    rock.Material = Enum.Material.Basalt
                    rock.Color = propColor
                    rock.Parent = propsFolder

                elseif propType == "ember" or propType == "voidorb" then
                    local orb = Instance.new("Part")
                    orb.Name = "Orb_" .. j
                    orb.Shape = Enum.PartType.Ball
                    orb.Size = Vector3.new(2, 2, 2)
                    orb.Position = Vector3.new(x, zone.SpawnPosition.Y + 4, z)
                    orb.Anchored = true
                    orb.CanCollide = false
                    orb.Material = Enum.Material.Neon
                    orb.Color = propColor
                    orb.Transparency = 0.3
                    orb.Parent = propsFolder

                else
                    local pillar = Instance.new("Part")
                    pillar.Name = "Prop_" .. j
                    pillar.Size = Vector3.new(2, math.random(3, 8), 2)
                    pillar.Position = Vector3.new(x, zone.SpawnPosition.Y + pillar.Size.Y / 2, z)
                    pillar.Anchored = true
                    pillar.CanCollide = true
                    pillar.Material = Enum.Material.SmoothPlastic
                    pillar.Color = propColor
                    pillar.Parent = propsFolder
                end
            end
        end
    end
end

-- Initialize all zones
function CoinSpawnerService.Init()
    CoinSpawnerService.CreateZonePlatforms()

    for _, zone in ipairs(ZoneConfig.Zones) do
        CoinSpawnerService.SpawnZoneCoins(zone)
    end

    print("[CoinSpawnerService] Spawned coins in " .. #ZoneConfig.Zones .. " zones")
end

return CoinSpawnerService
