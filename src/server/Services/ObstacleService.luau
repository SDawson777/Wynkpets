--[[
    ObstacleService.luau
    Creates and manages zone obstacles. Touch = teleport back to zone center
    with brief invincibility. Kid-friendly: slow, bright, forgiving.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local ObstacleConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ObstacleConfig"))

local ObstacleService = {}
local CurrencyService

local invinciblePlayers = {} -- [Player] = expireTime (tick())

-- Teleport player back to zone center with invincibility
local function handleObstacleHit(player: Player, zoneId: string, zoneSpawnPos: Vector3)
    local now = tick()
    if invinciblePlayers[player] and now < invinciblePlayers[player] then
        return -- still invincible
    end

    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Grant invincibility
    invinciblePlayers[player] = now + ObstacleConfig.InvincibilityDuration

    -- Economic penalty: higher zones lose more coins when hit
    local zone = ZoneConfig.GetZone(zoneId)
    local penalty = zone and math.max(25, math.floor((zone.CoinValue or 50) * 0.5)) or 25
    local lostCoins = 0
    if CurrencyService then
        local currentCoins = CurrencyService.GetBalance(player, "Coins")
        lostCoins = math.min(currentCoins, penalty)
        if lostCoins > 0 then
            CurrencyService.Remove(player, "Coins", lostCoins)
        end
    end

    -- Teleport to zone center, slightly above ground
    root.CFrame = CFrame.new(zoneSpawnPos + Vector3.new(0, 5, 0))

    -- Notify client for visual effect
    Network.FireClient("ObstacleHit", player)
    local msg = ObstacleConfig.KnockbackMessage
    if lostCoins > 0 then
        msg = msg .. "  (-" .. tostring(lostCoins) .. " Coins)"
    end
    Network.FireClient("ShowNotification", player, msg, "Warning")

    -- Clear invincibility after duration
    task.delay(ObstacleConfig.InvincibilityDuration, function()
        if invinciblePlayers[player] and tick() >= invinciblePlayers[player] then
            invinciblePlayers[player] = nil
        end
    end)
end

-- Check if part was touched by a character and return the Player
local function getPlayerFromTouch(hit: BasePart): Player?
    local character = hit.Parent
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    return Players:GetPlayerFromCharacter(character)
end

-- Create a spinning bar obstacle
local function createSpinBar(zoneFolder: Folder, zoneId: string, zoneSpawnPos: Vector3, config)
    local length = config.Length or 18
    local height = 2 -- Y offset above ground

    -- The bar
    local bar = Instance.new("Part")
    bar.Name = "SpinBar"
    bar.Size = Vector3.new(length, 2, 2)
    bar.Anchored = true
    bar.CanCollide = false
    bar.Material = Enum.Material.Neon
    bar.Color = config.Color
    bar.CFrame = CFrame.new(zoneSpawnPos + config.Position + Vector3.new(0, height, 0))
    bar.Parent = zoneFolder

    -- Center pivot visual (small ball at the rotation center)
    local pivot = Instance.new("Part")
    pivot.Name = "SpinBarPivot"
    pivot.Shape = Enum.PartType.Ball
    pivot.Size = Vector3.new(3, 3, 3)
    pivot.Anchored = true
    pivot.CanCollide = false
    pivot.Material = Enum.Material.Neon
    pivot.Color = config.Color
    pivot.Transparency = 0.3
    pivot.Position = zoneSpawnPos + config.Position + Vector3.new(0, height, 0)
    pivot.Parent = zoneFolder

    -- Touch detection
    bar.Touched:Connect(function(hit)
        local player = getPlayerFromTouch(hit)
        if player then
            handleObstacleHit(player, zoneId, zoneSpawnPos)
        end
    end)

    -- Rotation animation — capped at 30fps (clients interpolate; 60fps gives no visual gain)
    local center = zoneSpawnPos + config.Position + Vector3.new(0, height, 0)
    local speed = math.rad(config.Speed) -- convert degrees/s to radians/s
    local angle = 0

    task.spawn(function()
        while bar.Parent do
            local dt = task.wait(1/30)
            angle = angle + speed * dt
            bar.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0)
        end
    end)
end

-- Create a bouncing orb obstacle
local function createBouncingOrb(zoneFolder: Folder, zoneId: string, zoneSpawnPos: Vector3, config)
    local worldStart = zoneSpawnPos + config.PathStart
    local worldEnd = zoneSpawnPos + config.PathEnd
    local size = config.Size or 4

    local orb = Instance.new("Part")
    orb.Name = "BouncingOrb"
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(size, size, size)
    orb.Anchored = true
    orb.CanCollide = false
    orb.Material = Enum.Material.Neon
    orb.Color = config.Color
    orb.Transparency = 0.1
    orb.Position = worldStart
    orb.Parent = zoneFolder

    -- Trail for visibility
    local attachment0 = Instance.new("Attachment")
    attachment0.Parent = orb
    local attachment1 = Instance.new("Attachment")
    attachment1.Position = Vector3.new(0, -size / 2, 0)
    attachment1.Parent = orb

    local trail = Instance.new("Trail")
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    trail.Lifetime = 0.5
    trail.MinLength = 0.1
    trail.Color = ColorSequence.new(config.Color)
    trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
    trail.WidthScale = NumberSequence.new(size * 0.8)
    trail.Parent = orb

    -- Touch detection
    orb.Touched:Connect(function(hit)
        local player = getPlayerFromTouch(hit)
        if player then
            handleObstacleHit(player, zoneId, zoneSpawnPos)
        end
    end)

    -- Ping-pong movement — capped at 30fps
    local pathLength = (worldEnd - worldStart).Magnitude
    local direction = (worldEnd - worldStart).Unit
    local speed = config.Speed or 8
    local progress = 0 -- 0 to 1
    local forward = true

    task.spawn(function()
        while orb.Parent do
            local dt = task.wait(1/30)
            local step = (speed * dt) / pathLength
            if forward then
                progress = progress + step
                if progress >= 1 then
                    progress = 1
                    forward = false
                end
            else
                progress = progress - step
                if progress <= 0 then
                    progress = 0
                    forward = true
                end
            end
            orb.Position = worldStart + direction * (pathLength * progress)
        end
    end)
end

-- Create a pulse zone obstacle (floor area that cycles safe/danger)
local function createPulseZone(zoneFolder: Folder, zoneId: string, zoneSpawnPos: Vector3, config)
    local radius = config.Radius or 10
    local diameter = radius * 2

    local zone = Instance.new("Part")
    zone.Name = "PulseZone"
    zone.Shape = Enum.PartType.Cylinder
    -- Cylinders in Roblox: X = height, Y = diameter, Z = diameter (when rotated)
    zone.Size = Vector3.new(1, diameter, diameter)
    zone.Anchored = true
    zone.CanCollide = false
    zone.Material = Enum.Material.Neon
    zone.Color = Color3.fromRGB(80, 200, 80) -- start safe (green)
    zone.Transparency = 0.7
    -- Lay flat: rotate 90 degrees on Z axis
    zone.CFrame = CFrame.new(zoneSpawnPos + config.Position - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
    zone:SetAttribute("Dangerous", false)
    zone.Parent = zoneFolder

    -- Touch detection (only active during danger phase)
    zone.Touched:Connect(function(hit)
        if not zone:GetAttribute("Dangerous") then return end
        local player = getPlayerFromTouch(hit)
        if player then
            handleObstacleHit(player, zoneId, zoneSpawnPos)
        end
    end)

    -- State machine: Safe → Warning → Danger → repeat
    local safeTime = config.SafeTime or 4
    local warnTime = config.WarnTime or 1
    local dangerTime = config.DangerTime or 2

    task.spawn(function()
        while zone.Parent do
            -- SAFE phase
            zone:SetAttribute("Dangerous", false)
            zone.Color = Color3.fromRGB(80, 200, 80)
            zone.Transparency = 0.7
            task.wait(safeTime)

            -- WARNING phase (flash yellow/red)
            zone:SetAttribute("Dangerous", false)
            local warnEnd = tick() + warnTime
            while tick() < warnEnd and zone.Parent do
                zone.Color = Color3.fromRGB(255, 220, 50)
                zone.Transparency = 0.4
                task.wait(0.2)
                zone.Color = Color3.fromRGB(255, 80, 50)
                zone.Transparency = 0.5
                task.wait(0.2)
            end

            -- DANGER phase
            zone:SetAttribute("Dangerous", true)
            zone.Color = Color3.fromRGB(255, 30, 30)
            zone.Transparency = 0.2
            task.wait(dangerTime)
        end
    end)
end

-- Build all obstacles for all zones
local function buildObstacles()
    local zonesFolder = Workspace:FindFirstChild("Zones")
    if not zonesFolder then
        warn("[ObstacleService] Zones folder not found in Workspace")
        return
    end

    for _, zone in ipairs(ZoneConfig.Zones) do
        local obstacles = ObstacleConfig.ZoneObstacles[zone.Id]
        if not obstacles or #obstacles == 0 then continue end

        local zoneFolder = zonesFolder:FindFirstChild(zone.Id)
        if not zoneFolder then
            warn("[ObstacleService] Zone folder not found: " .. zone.Id)
            continue
        end

        local obstacleFolder = Instance.new("Folder")
        obstacleFolder.Name = "Obstacles"
        obstacleFolder.Parent = zoneFolder

        for _, config in ipairs(obstacles) do
            if config.Type == "SpinBar" then
                createSpinBar(obstacleFolder, zone.Id, zone.SpawnPosition, config)
            elseif config.Type == "BouncingOrb" then
                createBouncingOrb(obstacleFolder, zone.Id, zone.SpawnPosition, config)
            elseif config.Type == "PulseZone" then
                createPulseZone(obstacleFolder, zone.Id, zone.SpawnPosition, config)
            else
                warn("[ObstacleService] Unknown obstacle type: " .. tostring(config.Type))
            end
        end
    end
end

function ObstacleService.Init(currencyService)
    CurrencyService = currencyService
    -- Wait a tick for zone platforms to be built by CoinSpawnerService
    task.defer(function()
        buildObstacles()
        print("[ObstacleService] Obstacles placed in all zones")
    end)
end

function ObstacleService.PlayerRemoving(player: Player)
    invinciblePlayers[player] = nil
end

return ObstacleService
