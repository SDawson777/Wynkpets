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

                -- The actual currency addition is handled by CurrencyService via the CollectCoin event
                -- We fire from client side, but we also need to fire here for the server
                local Network = require(Shared:WaitForChild("Network"))
                Network.FireClient("CollectCoin", player, zone.Id)
            end)
        end
    end
end

-- Create zone ground platforms
function CoinSpawnerService.CreateZonePlatforms()
    for _, zone in ipairs(ZoneConfig.Zones) do
        local zoneFolder = getOrCreateZoneFolder(zone.Id)

        -- Ground platform
        local ground = Instance.new("Part")
        ground.Name = "Ground"
        ground.Size = Vector3.new(150, 1, 150)
        ground.Position = zone.SpawnPosition - Vector3.new(0, 0.5, 0)
        ground.Anchored = true
        ground.BrickColor = BrickColor.new(zone.Color)
        ground.Material = Enum.Material.Grass
        ground.TopSurface = Enum.SurfaceType.Smooth
        ground.BottomSurface = Enum.SurfaceType.Smooth
        ground.Parent = zoneFolder

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
