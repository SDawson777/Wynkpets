--[[
    SpecialEggService.luau
    Spawns rare special eggs randomly in zones every 2-5 minutes.
    First-come-first-served: one player claims it, gets a free hatch.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
local SpecialEggConfig = require(Shared:WaitForChild("Configs"):WaitForChild("SpecialEggConfig"))

local DataService
local PetService
local CurrencyService
local RewardService

local SpecialEggService = {}

local currentEgg = nil -- { zoneId, zoneName, model, claimed }
local claimDebounce = {} -- [Player] = true

-- Weighted random selection from the special pet pool
local function selectPet(): string
    local pool = SpecialEggConfig.PetPool
    local totalWeight = 0
    for _, entry in ipairs(pool) do
        totalWeight = totalWeight + entry.Weight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(pool) do
        cumulative = cumulative + entry.Weight
        if roll <= cumulative then
            return entry.PetId
        end
    end
    return pool[#pool].PetId
end

-- Determine golden/rainbow variant with boosted chances
local function determineVariant(): (boolean, boolean)
    local rainbow = math.random() < SpecialEggConfig.RainbowChance
    if rainbow then
        return false, true
    end
    local golden = math.random() < SpecialEggConfig.GoldenChance
    return golden, false
end

-- Create the glowing egg model in the world

local function createEggModel(position: Vector3, zoneFolder: Instance): Model
    local model = Instance.new("Model")
    model.Name = "SpecialEgg"

    -- Main egg body (Sphere mesh scaled into egg shape)
    local body = Instance.new("Part")
    body.Name = "EggBody"
    body.Size = SpecialEggConfig.EggSize
    body.Anchored = true
    body.CanCollide = false
    body.Material = Enum.Material.Neon
    body.Color = SpecialEggConfig.GlowColor
    body.Transparency = 0.1
    body.Position = position + Vector3.new(0, SpecialEggConfig.EggSize.Y / 2 + 2.0, 0)
    local eggMesh = Instance.new("SpecialMesh")
    eggMesh.MeshType = Enum.MeshType.Sphere
    eggMesh.Scale = Vector3.new(1, 1.2, 1)
    eggMesh.Parent = body
    body.Parent = model

    -- Point light for glow
    local light = Instance.new("PointLight")
    light.Range = SpecialEggConfig.LightRange
    light.Brightness = SpecialEggConfig.LightBrightness
    light.Color = SpecialEggConfig.GlowColor
    light.Parent = body

    -- Sparkle particles
    local emitter = Instance.new("ParticleEmitter")
    emitter.Rate = SpecialEggConfig.ParticleRate
    emitter.Lifetime = NumberRange.new(0.5, 1.5)
    emitter.Speed = NumberRange.new(2, 5)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Color = ColorSequence.new(SpecialEggConfig.GlowColor, Color3.fromRGB(255, 255, 200))
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
    emitter.LightEmission = 1
    emitter.Parent = body

    -- Pedestal
    local pedestal = Instance.new("Part")
    pedestal.Name = "Pedestal"
    pedestal.Shape = Enum.PartType.Cylinder
    pedestal.Size = Vector3.new(1, 14, 14)
    pedestal.Anchored = true
    pedestal.CanCollide = false
    pedestal.Material = Enum.Material.Marble
    pedestal.Color = Color3.fromRGB(255, 230, 150)
    pedestal.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pedestal.Parent = model

    -- Billboard label
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 10, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = body

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.5, 0)
    label.BackgroundTransparency = 1
    label.Text = "SPECIAL EGG!"
    label.TextColor3 = Color3.fromRGB(255, 215, 0)
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 22
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(100, 50, 0)
    label.Parent = billboard

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, 0, 0.5, 0)
    subLabel.Position = UDim2.new(0, 0, 0.5, 0)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = "Walk up to claim!"
    subLabel.TextColor3 = Color3.fromRGB(255, 255, 200)
    subLabel.Font = Enum.Font.GothamBold
    subLabel.TextSize = 14
    subLabel.TextStrokeTransparency = 0.5
    subLabel.Parent = billboard

    -- ProximityPrompt for claiming
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Claim!"
    prompt.ObjectText = "Special Egg"
    prompt.MaxActivationDistance = 15
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.Parent = body

    model.Parent = zoneFolder

    -- Bob animation
    local baseY = body.Position.Y
    task.spawn(function()
        local t = 0
        while body.Parent do
            t = t + task.wait()
            body.Position = Vector3.new(body.Position.X, baseY + math.sin(t * 2) * 1.5, body.Position.Z)
        end
    end)

    return model
end

-- Handle a player claiming the special egg
local function handleClaim(player: Player)
    -- Race condition guard: immediately check and clear
    if not currentEgg or currentEgg.claimed then return end
    if claimDebounce[player] then return end
    claimDebounce[player] = true

    -- Mark as claimed immediately (prevents double-claim)
    currentEgg.claimed = true
    local zoneName = currentEgg.zoneName

    -- Clean up the model
    if currentEgg.model and currentEgg.model.Parent then
        currentEgg.model:Destroy()
    end

    -- Select pet and determine variant
    local petId = selectPet()
    local golden, rainbow = determineVariant()

    -- Add pet to player (free — no cost!)
    local newPet = PetService.AddPet(player, petId, golden, rainbow)
    if newPet then
        local petInfo = PetConfig.GetPet(petId)
        local results = {
            {
                UUID = newPet.UUID,
                PetId = petId,
                Name = petInfo and petInfo.Name or petId,
                Rarity = petInfo and petInfo.Rarity or "Common",
                Power = petInfo and petInfo.Power or 1,
                Golden = golden,
                Rainbow = rainbow,
            },
        }

        -- Fire hatch animation to the claiming player
        Network.FireClient("HatchResult", player, results, 1.5, nil)

        -- Track stats
        local data = DataService.GetData(player)
        if data then
            data.SpecialEggsClaimed = (data.SpecialEggsClaimed or 0) + 1
        end

        -- Server-wide announcement
        local claimMsg = string.format(SpecialEggConfig.ClaimAnnouncement, player.Name, zoneName)
        Network.FireAllClients("SpecialEggClaimed", player.Name, zoneName)
        Network.FireAllClients("ServerAnnouncement", claimMsg)
        Network.FireAllClients("ShowNotification", claimMsg, "Hatch")

        -- Quest tracking
        if RewardService then
            RewardService.UpdateQuestProgress(player, "ClaimSpecialEgg", 1)
        end
    end

    -- Clear current egg state
    currentEgg = nil
    claimDebounce[player] = nil
end

-- Main spawn loop
local function startSpawnLoop()
    task.spawn(function()
        -- Initial delay before first spawn
        task.wait(30)

        while true do
            -- Wait random interval
            local interval = math.random(SpecialEggConfig.SpawnIntervalMin, SpecialEggConfig.SpawnIntervalMax)
            task.wait(interval)

            -- Don't spawn if one already exists
            if currentEgg and not currentEgg.claimed then continue end

            -- Pick a random zone
            local zones = ZoneConfig.Zones
            local zone = zones[math.random(1, #zones)]

            -- Pick random position within zone (radius 15-50 from center)
            local angle = math.random() * math.pi * 2
            local radius = 15 + math.random() * 35
            local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            local position = zone.SpawnPosition + offset

            -- Get zone folder
            local zonesFolder = Workspace:FindFirstChild("Zones")
            if not zonesFolder then continue end
            local zoneFolder = zonesFolder:FindFirstChild(zone.Id)
            if not zoneFolder then continue end

            -- Create the egg
            local model = createEggModel(position, zoneFolder)

            currentEgg = {
                zoneId = zone.Id,
                zoneName = zone.Name,
                model = model,
                claimed = false,
            }

            -- Announce to all players
            local spawnMsg = string.format(SpecialEggConfig.SpawnAnnouncement, zone.Name)
            Network.FireAllClients("SpecialEggSpawned", zone.Id, zone.Name, position)
            Network.FireAllClients("ServerAnnouncement", spawnMsg)

            -- Connect the ProximityPrompt
            local body = model:FindFirstChild("EggBody")
            if body then
                local prompt = body:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    prompt.Triggered:Connect(function(player)
                        handleClaim(player)
                    end)
                end
            end

            -- Wait for duration or claim
            local startTime = tick()
            while tick() - startTime < SpecialEggConfig.Duration do
                task.wait(1)
                if not currentEgg or currentEgg.claimed then break end
            end

            -- If still unclaimed, despawn
            if currentEgg and not currentEgg.claimed then
                if currentEgg.model and currentEgg.model.Parent then
                    currentEgg.model:Destroy()
                end
                Network.FireAllClients("SpecialEggDespawned")
                currentEgg = nil
            end
        end
    end)
end

function SpecialEggService.Init(dataService, petService, currencyService, rewardService)
    DataService = dataService
    PetService = petService
    CurrencyService = currencyService
    RewardService = rewardService

    startSpawnLoop()
    print("[SpecialEggService] Initialized — eggs spawn every 2-5 minutes")
end

function SpecialEggService.PlayerRemoving(player: Player)
    claimDebounce[player] = nil
end

return SpecialEggService
