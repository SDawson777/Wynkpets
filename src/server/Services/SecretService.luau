--[[
    SecretService.luau
    Manages secret tokens, secret portals (bonus rooms), and the hidden zone.
    Tokens are per-player (visible to all, collectible once per player).
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local SecretConfig = require(Shared:WaitForChild("Configs"):WaitForChild("SecretConfig"))

local DataService
local CurrencyService
local PetService
local EggService
local ZoneService
local AntiExploitService

local SecretService = {}

local activeBonusRooms = {} -- [Player] = { returnTime, returnPosition }
local bonusRoomPlatforms = {} -- [portalIndex] = { platform, folder }

-- Track all live token Parts for respawn management
-- tokenParts[zoneId][index] = { part, prompt, light, emitter, isHidden, respawnAt }
local tokenParts = {} -- [zoneId] = { [index] = tokenData }

-----------------------------------------------------
-- Secret Tokens
-----------------------------------------------------

local function getTokenKey(zoneId: string, index: number): string
    return zoneId .. "_" .. tostring(index)
end

-- Returns how many orbs of a zone a player has collected
local function countZoneOrbs(data, zoneId: string): number
    if not data.SecretTokens then return 0 end
    local count = 0
    for i = 1, SecretConfig.TokensPerZone do
        local key = getTokenKey(zoneId, i)
        if data.SecretTokens[key] then
            count = count + 1
        end
    end
    return count
end

-- Build per-zone orb progress table for the client: { zoneId = { collected, required, setRewardPetId } }
local function buildOrbSetProgress(data)
    local progress = {}
    for _, zoneId in ipairs(SecretConfig.ZoneOrder) do
        local setConfig = SecretConfig.OrbSets[zoneId]
        if setConfig then
            progress[zoneId] = {
                collected = countZoneOrbs(data, zoneId),
                required = setConfig.RequiredCount,
                rewardPetId = setConfig.RewardPetId,
                completed = (data.CompletedOrbSets and data.CompletedOrbSets[zoneId]) or false,
            }
        end
    end
    return progress
end

-- Hide an orb globally and queue its respawn
local function hideToken(tokenData, zoneId: string, index: number)
    local part = tokenData.part
    if not part or not part.Parent then return end

    tokenData.isHidden = true
    tokenData.respawnAt = tick() + SecretConfig.RespawnDelay

    -- Visually hide & disable prompt
    part.Transparency = 1
    tokenData.light.Enabled = false
    tokenData.emitter.Enabled = false
    tokenData.prompt.Enabled = false
end

-- Restore an orb globally
local function revealToken(tokenData, zoneId: string, index: number)
    local part = tokenData.part
    if not part or not part.Parent then return end

    tokenData.isHidden = false
    tokenData.respawnAt = nil

    part.Transparency = 0.2
    tokenData.light.Enabled = true
    tokenData.emitter.Enabled = true
    tokenData.prompt.Enabled = true

    -- Notify all clients
    Network.FireAllClients("OrbRespawned", zoneId, index)
end

local function createToken(zoneFolder: Instance, zoneSpawnPos: Vector3, zoneId: string, index: number, offset: Vector3)
    local position = zoneSpawnPos + offset
    local orbColor = SecretConfig.ZoneOrbColors[zoneId] or Color3.fromRGB(255, 215, 0)

    local token = Instance.new("Part")
    token.Name = "SecretToken_" .. zoneId .. "_" .. index
    token.Shape = Enum.PartType.Ball
    token.Size = SecretConfig.TokenSize
    token.Anchored = true
    token.CanCollide = false
    token.Material = Enum.Material.Neon
    token.Color = orbColor
    token.Transparency = 0.2
    token.Position = position
    token.Parent = zoneFolder

    -- Glow matching zone color
    local light = Instance.new("PointLight")
    light.Range = SecretConfig.TokenLightRange
    light.Brightness = SecretConfig.TokenLightBrightness
    light.Color = orbColor
    light.Parent = token

    -- Sparkle particles in zone color
    local emitter = Instance.new("ParticleEmitter")
    emitter.Rate = 5
    emitter.Lifetime = NumberRange.new(0.8, 1.5)
    emitter.Speed = NumberRange.new(1, 3)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Color = ColorSequence.new(orbColor, Color3.fromRGB(255, 255, 255))
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
    emitter.LightEmission = 1
    emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
    emitter.Parent = token

    -- ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Collect Orb!"
    prompt.ObjectText = "Secret Orb"
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.Parent = token

    -- Register in tokenParts for respawn management
    if not tokenParts[zoneId] then
        tokenParts[zoneId] = {}
    end
    local tokenData = {
        part   = token,
        prompt = prompt,
        light  = light,
        emitter = emitter,
        isHidden = false,
        respawnAt = nil,
    }
    tokenParts[zoneId][index] = tokenData

    -- Handle collection
    prompt.Triggered:Connect(function(player)
        local data = DataService.GetData(player)
        if not data then return end

        local key = getTokenKey(zoneId, index)

        -- Already collected by this player?
        if data.SecretTokens and data.SecretTokens[key] then
            Network.FireClient("ShowNotification", player, "You already found this orb!", "Info")
            return
        end

        -- Collect it
        if not data.SecretTokens then data.SecretTokens = {} end
        if not data.CompletedOrbSets then data.CompletedOrbSets = {} end

        data.SecretTokens[key] = true
        data.SecretTokensCount = (data.SecretTokensCount or 0) + 1

        -- Reward gems
        CurrencyService.Add(player, "Gems", SecretConfig.TokenReward)

        -- Hide orb globally and queue respawn
        hideToken(tokenData, zoneId, index)
        task.delay(SecretConfig.RespawnDelay, function()
            if tokenData.isHidden then
                revealToken(tokenData, zoneId, index)
            end
        end)

        -- Notify collector
        Network.FireClient("SecretTokenCollected", player, zoneId, index, data.SecretTokensCount)
        Network.FireClient("ShowNotification", player,
            "SECRET ORB FOUND! (" .. data.SecretTokensCount .. "/" .. SecretConfig.TotalTokens .. ")", "Success")
        Network.FireAllClients("ServerAnnouncement", player.Name .. " found a " .. zoneId:gsub("_", " ") .. " orb!")

        -- Check Orb Set completion for this zone
        local setConfig = SecretConfig.OrbSets[zoneId]
        if setConfig and not data.CompletedOrbSets[zoneId] then
            local zoneCount = countZoneOrbs(data, zoneId)
            if zoneCount >= setConfig.RequiredCount then
                data.CompletedOrbSets[zoneId] = true

                -- Directly grant the secret pet
                local petResult = PetService.AddPet(player, setConfig.RewardPetId)
                Network.FireClient("OrbSetCompleted", player, zoneId, setConfig.RewardPetId, petResult)
                Network.FireClient("ShowNotification", player,
                    "ORB SET COMPLETE! Unlocked: " .. setConfig.RewardPetId:gsub("_", " "):upper() .. "!", "Success")
                Network.FireAllClients("ServerAnnouncement",
                    player.Name .. " completed the " .. zoneId:gsub("_", " ") .. " orb set!")
            end
        end

        -- Send updated orb set progress
        local progress = buildOrbSetProgress(data)
        Network.FireClient("OrbSetProgress", player, progress)

        -- Check if hidden zone should unlock
        if data.SecretTokensCount >= SecretConfig.HiddenZoneTokenThreshold then
            local alreadyUnlocked = false
            for _, z in ipairs(data.UnlockedZones or {}) do
                if z == SecretConfig.HiddenZone.Id then
                    alreadyUnlocked = true
                    break
                end
            end
            if not alreadyUnlocked then
                table.insert(data.UnlockedZones, SecretConfig.HiddenZone.Id)
                Network.FireClient("ZoneUnlocked", player, SecretConfig.HiddenZone.Id)
                Network.FireClient("ShowNotification", player,
                    "SECRET ZONE UNLOCKED: " .. SecretConfig.HiddenZone.Name .. "!", "Success")
                Network.FireAllClients("ServerAnnouncement",
                    player.Name .. " unlocked the " .. SecretConfig.HiddenZone.Name .. "!")
            end
        end
    end)

    -- Gentle bob animation
    local baseY = position.Y
    task.spawn(function()
        local t = math.random() * math.pi * 2
        while token.Parent do
            t = t + task.wait()
            token.Position = Vector3.new(position.X, baseY + math.sin(t * 1.5) * 0.5, position.Z)
        end
    end)
end

local function createAllTokens()
    local zonesFolder = Workspace:FindFirstChild("Zones")
    if not zonesFolder then
        warn("[SecretService] Zones folder not found")
        return
    end

    for _, zone in ipairs(ZoneConfig.Zones) do
        local locations = SecretConfig.TokenLocations[zone.Id]
        if not locations then continue end

        local zoneFolder = zonesFolder:FindFirstChild(zone.Id)
        if not zoneFolder then continue end

        local secretsFolder = Instance.new("Folder")
        secretsFolder.Name = "Secrets"
        secretsFolder.Parent = zoneFolder

        for i, offset in ipairs(locations) do
            createToken(secretsFolder, zone.SpawnPosition, zone.Id, i, offset)
        end
    end
end

-----------------------------------------------------
-- Secret Portals & Bonus Rooms
-----------------------------------------------------

local function createBonusRoom(portalIndex: number, portalConfig)
    -- Build at Y=500 to keep it above the main world
    local roomY = 500 + portalIndex * 100
    local roomCenter = Vector3.new(portalIndex * 200, roomY, 0)
    local size = 40

    local folder = Instance.new("Folder")
    folder.Name = "BonusRoom_" .. portalConfig.BonusRoomName
    folder.Parent = Workspace

    -- Platform
    local platform = Instance.new("Part")
    platform.Name = "BonusPlatform"
    platform.Size = Vector3.new(size, 2, size)
    platform.Anchored = true
    platform.Position = roomCenter - Vector3.new(0, 1, 0)
    platform.Material = Enum.Material.Neon
    platform.Color = portalConfig.RoomColor
    platform.Parent = folder

    local corner = Instance.new("UICorner") -- doesn't apply to Parts, harmless
    -- Border walls
    for _, wallData in ipairs({
        { size = Vector3.new(size + 4, 6, 2), offset = Vector3.new(0, 2, size / 2 + 1) },
        { size = Vector3.new(size + 4, 6, 2), offset = Vector3.new(0, 2, -size / 2 - 1) },
        { size = Vector3.new(2, 6, size + 4), offset = Vector3.new(size / 2 + 1, 2, 0) },
        { size = Vector3.new(2, 6, size + 4), offset = Vector3.new(-size / 2 - 1, 2, 0) },
    }) do
        local wall = Instance.new("Part")
        wall.Size = wallData.size
        wall.Anchored = true
        wall.Position = roomCenter + wallData.offset
        wall.Material = Enum.Material.Glass
        wall.Color = portalConfig.RoomColor
        wall.Transparency = 0.5
        wall.Parent = folder
    end

    -- Billboard label
    local labelPart = Instance.new("Part")
    labelPart.Anchored = true
    labelPart.CanCollide = false
    labelPart.Transparency = 1
    labelPart.Position = roomCenter + Vector3.new(0, 15, 0)
    labelPart.Parent = folder

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 250, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.Parent = labelPart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = portalConfig.BonusRoomName
    nameLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextSize = 24
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.Parent = billboard

    -- Spawn bonus coins
    local sourceZone = ZoneConfig.GetZone(portalConfig.SourceZone)
    local coinValue = sourceZone and (sourceZone.CoinValue * portalConfig.CoinMultiplier) or 500
    local coinsFolder = Instance.new("Folder")
    coinsFolder.Name = "BonusCoins"
    coinsFolder.Parent = folder

    for i = 1, portalConfig.BonusCoins do
        local angle = (i / portalConfig.BonusCoins) * math.pi * 2
        local radius = 5 + math.random() * 12
        local coinPos = roomCenter + Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)

        local coin = Instance.new("Part")
        coin.Name = "BonusCoin_" .. i
        coin.Shape = Enum.PartType.Cylinder
        coin.Size = Vector3.new(0.4, 3, 3)
        coin.Anchored = true
        coin.CanCollide = false
        coin.Material = Enum.Material.Neon
        coin.Color = Color3.fromRGB(255, 200, 50)
        coin.CFrame = CFrame.new(coinPos) * CFrame.Angles(0, 0, math.rad(90))
        coin.Parent = coinsFolder

        local coinBillboard = Instance.new("BillboardGui")
        coinBillboard.Size = UDim2.new(0, 80, 0, 20)
        coinBillboard.StudsOffset = Vector3.new(0, 2, 0)
        coinBillboard.Parent = coin

        local coinLabel = Instance.new("TextLabel")
        coinLabel.Size = UDim2.new(1, 0, 1, 0)
        coinLabel.BackgroundTransparency = 1
        coinLabel.Text = tostring(coinValue)
        coinLabel.TextColor3 = Color3.fromRGB(255, 215, 50)
        coinLabel.Font = Enum.Font.GothamBold
        coinLabel.TextSize = 14
        coinLabel.TextStrokeTransparency = 0.5
        coinLabel.Parent = coinBillboard

        -- Touch collection
        local collected = {}
        coin.Touched:Connect(function(hit)
            local character = hit.Parent
            if not character then return end
            local player = Players:GetPlayerFromCharacter(character)
            if not player or collected[player] then return end
            collected[player] = true

            CurrencyService.Add(player, "Coins", coinValue, true)
            coin.Transparency = 1
            coinBillboard.Enabled = false

            -- Respawn after 3 seconds (bonus room is timed, keep it lively)
            task.delay(3, function()
                if coin.Parent then
                    coin.Transparency = 0
                    coinBillboard.Enabled = true
                    collected[player] = nil
                end
            end)
        end)

        -- Spin animation
        task.spawn(function()
            while coin.Parent do
                local dt = task.wait()
                coin.CFrame = coin.CFrame * CFrame.Angles(0, dt * 3, 0)
            end
        end)
    end

    bonusRoomPlatforms[portalIndex] = { center = roomCenter, folder = folder }
    return roomCenter
end

local function createSecretPortal(zoneFolder: Instance, zoneSpawnPos: Vector3, portalIndex: number, portalConfig)
    local position = zoneSpawnPos + portalConfig.Position

    -- Shimmering portal frame
    local portal = Instance.new("Part")
    portal.Name = "SecretPortal"
    portal.Size = Vector3.new(6, 8, 1)
    portal.Anchored = true
    portal.CanCollide = false
    portal.Material = Enum.Material.Neon
    portal.Color = portalConfig.RoomColor
    portal.Transparency = 0.4
    portal.Position = position + Vector3.new(0, 4, 0)
    portal.Parent = zoneFolder

    -- Shimmer particles
    local emitter = Instance.new("ParticleEmitter")
    emitter.Rate = 10
    emitter.Lifetime = NumberRange.new(1, 2)
    emitter.Speed = NumberRange.new(1, 3)
    emitter.SpreadAngle = Vector2.new(30, 180)
    emitter.Color = ColorSequence.new(portalConfig.RoomColor, Color3.fromRGB(255, 255, 200))
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
    emitter.LightEmission = 1
    emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
    emitter.Parent = portal

    -- Light
    local light = Instance.new("PointLight")
    light.Range = 15
    light.Brightness = 2
    light.Color = portalConfig.RoomColor
    light.Parent = portal

    -- Label
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 160, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = portal

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "??? Secret ???"
    label.TextColor3 = Color3.fromRGB(255, 215, 80)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextStrokeTransparency = 0.4
    label.Parent = billboard

    -- ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Enter Secret Area"
    prompt.ObjectText = portalConfig.BonusRoomName
    prompt.MaxActivationDistance = 10
    prompt.HoldDuration = 0.5
    prompt.RequiresLineOfSight = false
    prompt.Parent = portal

    -- Pre-build the bonus room
    local roomCenter = createBonusRoom(portalIndex, portalConfig)

    -- Handle portal entry
    prompt.Triggered:Connect(function(player)
        -- Check zone access
        local data = DataService.GetData(player)
        if not data then return end
        local hasAccess = false
        for _, z in ipairs(data.UnlockedZones or {}) do
            if z == portalConfig.SourceZone then hasAccess = true break end
        end
        if not hasAccess then
            Network.FireClient("ShowNotification", player, "Unlock this zone first!", "Warning")
            return
        end

        -- Already in a bonus room?
        if activeBonusRooms[player] then
            return
        end

        -- Teleport to bonus room
        local character = player.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        activeBonusRooms[player] = {
            returnTime = tick() + portalConfig.Duration,
            returnPosition = zoneSpawnPos + Vector3.new(0, 5, 0),
        }

        if AntiExploitService then AntiExploitService.NotifyTeleport(player) end
        root.CFrame = CFrame.new(roomCenter + Vector3.new(0, 5, 0))
        Network.FireClient("ShowNotification", player,
            "Welcome to " .. portalConfig.BonusRoomName .. "! " .. portalConfig.Duration .. " seconds!", "Success")
    end)

    -- Shimmer animation
    task.spawn(function()
        local t = 0
        while portal.Parent do
            t = t + task.wait()
            portal.Transparency = 0.3 + math.sin(t * 2) * 0.15
        end
    end)
end

local function createAllSecretPortals()
    local zonesFolder = Workspace:FindFirstChild("Zones")
    if not zonesFolder then return end

    for i, portalConfig in ipairs(SecretConfig.SecretPortals) do
        local zone = ZoneConfig.GetZone(portalConfig.SourceZone)
        if not zone then continue end

        local zoneFolder = zonesFolder:FindFirstChild(zone.Id)
        if not zoneFolder then continue end

        local secretsFolder = zoneFolder:FindFirstChild("Secrets")
        if not secretsFolder then
            secretsFolder = Instance.new("Folder")
            secretsFolder.Name = "Secrets"
            secretsFolder.Parent = zoneFolder
        end

        createSecretPortal(secretsFolder, zone.SpawnPosition, i, portalConfig)
    end
end

-----------------------------------------------------
-- Hidden 9th Zone
-----------------------------------------------------

local function createHiddenZone()
    local config = SecretConfig.HiddenZone
    local zonesFolder = Workspace:FindFirstChild("Zones")
    if not zonesFolder then return end

    local folder = Instance.new("Folder")
    folder.Name = config.Id
    folder.Parent = zonesFolder

    -- Platform
    local size = config.PlatformSize
    local platform = Instance.new("Part")
    platform.Name = "Ground"
    platform.Size = Vector3.new(size, 2, size)
    platform.Anchored = true
    platform.Position = config.SpawnPosition - Vector3.new(0, 1, 0)
    platform.Material = config.Material
    platform.Color = config.Color
    platform.Parent = folder

    -- Border walls
    for _, wallData in ipairs({
        { size = Vector3.new(size + 4, 5, 2), offset = Vector3.new(0, 1.5, size / 2 + 1) },
        { size = Vector3.new(size + 4, 5, 2), offset = Vector3.new(0, 1.5, -size / 2 - 1) },
        { size = Vector3.new(2, 5, size + 4), offset = Vector3.new(size / 2 + 1, 1.5, 0) },
        { size = Vector3.new(2, 5, size + 4), offset = Vector3.new(-size / 2 - 1, 1.5, 0) },
    }) do
        local wall = Instance.new("Part")
        wall.Size = wallData.size
        wall.Anchored = true
        wall.Position = config.SpawnPosition + wallData.offset
        wall.Material = Enum.Material.Glass
        wall.Color = Color3.fromRGB(255, 230, 150)
        wall.Transparency = 0.4
        wall.Parent = folder
    end

    -- Zone label billboard
    local labelPart = Instance.new("Part")
    labelPart.Anchored = true
    labelPart.CanCollide = false
    labelPart.Transparency = 1
    labelPart.Position = config.SpawnPosition + Vector3.new(0, 20, 0)
    labelPart.Parent = folder

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 300, 0, 60)
    billboard.AlwaysOnTop = true
    billboard.Parent = labelPart

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = config.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextSize = 28
    nameLabel.TextStrokeTransparency = 0.2
    nameLabel.Parent = billboard

    -- Spawn high-value coins
    local coinsFolder = Instance.new("Folder")
    coinsFolder.Name = "Coins"
    coinsFolder.Parent = folder

    for i = 1, config.CoinCount do
        local angle = (i / config.CoinCount) * math.pi * 2
        local radius = 8 + math.random() * (size / 2 - 12)
        local coinPos = config.SpawnPosition + Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)

        local coin = Instance.new("Part")
        coin.Name = "SecretCoin_" .. i
        coin.Shape = Enum.PartType.Cylinder
        coin.Size = Vector3.new(0.5, 3.5, 3.5)
        coin.Anchored = true
        coin.CanCollide = false
        coin.Material = Enum.Material.Neon
        coin.Color = Color3.fromRGB(255, 200, 50)
        coin.CFrame = CFrame.new(coinPos) * CFrame.Angles(0, 0, math.rad(90))
        coin.Parent = coinsFolder

        local coinBillboard = Instance.new("BillboardGui")
        coinBillboard.Size = UDim2.new(0, 80, 0, 20)
        coinBillboard.StudsOffset = Vector3.new(0, 2.5, 0)
        coinBillboard.Parent = coin

        local coinLabel = Instance.new("TextLabel")
        coinLabel.Size = UDim2.new(1, 0, 1, 0)
        coinLabel.BackgroundTransparency = 1
        coinLabel.Text = tostring(config.CoinValue)
        coinLabel.TextColor3 = Color3.fromRGB(255, 215, 50)
        coinLabel.Font = Enum.Font.GothamBold
        coinLabel.TextSize = 14
        coinLabel.TextStrokeTransparency = 0.5
        coinLabel.Parent = coinBillboard

        -- Touch collection (per player, respawns)
        local collected = {}
        coin.Touched:Connect(function(hit)
            local character = hit.Parent
            if not character then return end
            local plr = Players:GetPlayerFromCharacter(character)
            if not plr or collected[plr] then return end

            -- Verify zone access
            local data = DataService.GetData(plr)
            if not data then return end
            local hasAccess = false
            for _, z in ipairs(data.UnlockedZones or {}) do
                if z == config.Id then hasAccess = true break end
            end
            if not hasAccess then return end

            collected[plr] = true
            CurrencyService.Add(plr, "Coins", config.CoinValue, true)
            coin.Transparency = 1
            coinBillboard.Enabled = false

            task.delay(3, function()
                if coin.Parent then
                    coin.Transparency = 0
                    coinBillboard.Enabled = true
                    collected[plr] = nil
                end
            end)
        end)

        -- Spin
        task.spawn(function()
            while coin.Parent do
                local dt = task.wait()
                coin.CFrame = coin.CFrame * CFrame.Angles(0, dt * 3, 0)
            end
        end)
    end

    -- Decorative props: floating golden orbs
    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2
        local radius = size / 2 - 5
        local orbPos = config.SpawnPosition + Vector3.new(math.cos(angle) * radius, 6, math.sin(angle) * radius)

        local orb = Instance.new("Part")
        orb.Shape = Enum.PartType.Ball
        orb.Size = Vector3.new(3, 3, 3)
        orb.Anchored = true
        orb.CanCollide = false
        orb.Material = Enum.Material.Neon
        orb.Color = config.Color
        orb.Transparency = 0.3
        orb.Position = orbPos
        orb.Parent = folder

        local orbLight = Instance.new("PointLight")
        orbLight.Range = 12
        orbLight.Brightness = 1.5
        orbLight.Color = config.Color
        orbLight.Parent = orb

        -- Float animation
        task.spawn(function()
            local t = i * 0.5
            while orb.Parent do
                t = t + task.wait()
                orb.Position = Vector3.new(orbPos.X, orbPos.Y + math.sin(t) * 2, orbPos.Z)
            end
        end)
    end

    -- Return portal (back to zone 1)
    local returnPortal = Instance.new("Part")
    returnPortal.Name = "ReturnPortal"
    returnPortal.Size = Vector3.new(6, 8, 1)
    returnPortal.Anchored = true
    returnPortal.CanCollide = false
    returnPortal.Material = Enum.Material.Neon
    returnPortal.Color = Color3.fromRGB(100, 200, 255)
    returnPortal.Transparency = 0.3
    returnPortal.Position = config.SpawnPosition + Vector3.new(0, 4, -size / 2 + 3)
    returnPortal.Parent = folder

    local returnLight = Instance.new("PointLight")
    returnLight.Range = 15
    returnLight.Brightness = 2
    returnLight.Color = Color3.fromRGB(100, 200, 255)
    returnLight.Parent = returnPortal

    local returnBillboard = Instance.new("BillboardGui")
    returnBillboard.Size = UDim2.new(0, 150, 0, 30)
    returnBillboard.StudsOffset = Vector3.new(0, 5, 0)
    returnBillboard.AlwaysOnTop = true
    returnBillboard.Parent = returnPortal

    local returnLabel = Instance.new("TextLabel")
    returnLabel.Size = UDim2.new(1, 0, 1, 0)
    returnLabel.BackgroundTransparency = 1
    returnLabel.Text = "Return Home"
    returnLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
    returnLabel.Font = Enum.Font.GothamBold
    returnLabel.TextSize = 14
    returnLabel.TextStrokeTransparency = 0.4
    returnLabel.Parent = returnBillboard

    local returnPrompt = Instance.new("ProximityPrompt")
    returnPrompt.ActionText = "Return"
    returnPrompt.ObjectText = "Starter Meadow"
    returnPrompt.MaxActivationDistance = 10
    returnPrompt.HoldDuration = 0
    returnPrompt.Parent = returnPortal

    returnPrompt.Triggered:Connect(function(player)
        local character = player.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if AntiExploitService then AntiExploitService.NotifyTeleport(player) end
        root.CFrame = CFrame.new(0, 10, 0)
    end)
end

-----------------------------------------------------
-- Bonus Room Timer
-----------------------------------------------------

local function startBonusRoomTimer()
    task.spawn(function()
        while true do
            task.wait(1)
            for player, roomData in pairs(activeBonusRooms) do
                if not player.Parent then
                    activeBonusRooms[player] = nil
                    continue
                end
                if tick() >= roomData.returnTime then
                    -- Teleport back
                    local character = player.Character
                    if character then
                        local root = character:FindFirstChild("HumanoidRootPart")
                        if root then
                            if AntiExploitService then AntiExploitService.NotifyTeleport(player) end
                            root.CFrame = CFrame.new(roomData.returnPosition)
                        end
                    end
                    Network.FireClient("ShowNotification", player, "Time's up! Back to the zone!", "Info")
                    activeBonusRooms[player] = nil
                end
            end
        end
    end)
end

-----------------------------------------------------
-- Public API
-----------------------------------------------------

function SecretService.PlayerAdded(player: Player)
    local data = DataService.GetData(player)
    if data then
        Network.FireClient("SecretTokenCount", player, data.SecretTokensCount or 0)
        local progress = buildOrbSetProgress(data)
        Network.FireClient("OrbSetProgress", player, progress)
    end
end

function SecretService.PlayerRemoving(player: Player)
    activeBonusRooms[player] = nil
end

function SecretService.Init(dataService, currencyService, petService, eggService, zoneService, antiExploitService)
    DataService = dataService
    CurrencyService = currencyService
    PetService = petService
    EggService = eggService
    ZoneService = zoneService
    AntiExploitService = antiExploitService

    -- Wait a tick for zone platforms to be built
    task.defer(function()
        createAllTokens()
        createAllSecretPortals()
        createHiddenZone()
        startBonusRoomTimer()
        print("[SecretService] Initialized — " .. SecretConfig.TotalTokens .. " tokens, "
            .. #SecretConfig.SecretPortals .. " portals, hidden zone ready")
    end)
end

return SecretService
