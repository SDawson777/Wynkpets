--[[
    CoinSpawnerService.luau
    Spawns collectible coins in each zone.
    Touch-based collection with auto-collect, visual feedback, and lucky drops.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local Network = require(Shared:WaitForChild("Network"))

local DataService
local CurrencyService
local PetLevelService

local CoinSpawnerService = {}

local COINS_PER_ZONE = 45
local COIN_RESPAWN_TIME = 2
local COIN_SPAWN_RADIUS = 85
local COIN_Y_HEIGHT = 4
local AUTO_COLLECT_BASE_RADIUS = 7      -- reduced from 12; standing still won't hoover coins
local AUTO_COLLECT_PET_BONUS = 2       -- reduced from 4
local AUTO_COLLECT_INTERVAL = 0.3
local LUCKY_CHANCE = 0.08 -- 8% chance of lucky coin (5x)
local SUPER_LUCKY_CHANCE = 0.02 -- 2% chance of super lucky (15x)

-- Anti-idle constants
local IDLE_MOVEMENT_THRESHOLD = 2.0   -- studs/tick; below this = idle
local IDLE_TICKS_TO_SUSPEND = 30      -- ~9 seconds; after which auto-collect fully stops
local MAX_COINS_PER_MINUTE_MULT = 800 -- no player earns more than zone.CoinValue*800 per minute

-- Per-player idle + rate-cap tracking
local playerIdleInfo = {}  -- [userId] = { ticks=0, lastX, lastZ }
local playerMinuteCap = {} -- [userId] = { earned=0, windowStart=0 }

-- Debounce table: prevents double-collecting the same coin in the same tick
local coinDebounce = {}    -- [userId_coinName] = true while being processed

-- Per-player current zone tracking for O(1) autocollect zone lookup
local playerCurrentZone = {} -- [userId] = zoneId

-- Cached { zone, coins[] } list used by auto-collect to avoid GetChildren() every tick
local zoneCoinCache = {} -- { zone, coinsFolder, coins }[]
local zoneCoinCacheByZoneId = {} -- [zoneId] = { zone, coinsFolder, coins }

-- Coin type variety: different coins have different value multipliers and visuals
local COIN_TYPES = {
    { Name = "Bronze",  Weight = 50, ValueMulti = 0.5, Color = Color3.fromRGB(180, 120, 60),  Size = Vector3.new(0.3, 1.5, 1.5) },
    { Name = "Silver",  Weight = 25, ValueMulti = 1.0, Color = Color3.fromRGB(200, 200, 210), Size = Vector3.new(0.4, 2, 2) },
    { Name = "Gold",    Weight = 15, ValueMulti = 2.0, Color = Color3.fromRGB(255, 215, 0),   Size = Vector3.new(0.4, 2, 2) },
    { Name = "Diamond", Weight = 7,  ValueMulti = 5.0, Color = Color3.fromRGB(150, 220, 255), Size = Vector3.new(0.5, 2.5, 2.5) },
    { Name = "Ruby",    Weight = 3,  ValueMulti = 10,  Color = Color3.fromRGB(255, 50, 80),   Size = Vector3.new(0.6, 3, 3) },
}

local TOTAL_COIN_TYPE_WEIGHT = 0
for _, ct in ipairs(COIN_TYPES) do
    TOTAL_COIN_TYPE_WEIGHT = TOTAL_COIN_TYPE_WEIGHT + ct.Weight
end

-- O(1) name→type lookup (avoids linear scan inside every collectCoin call)
local COIN_TYPE_BY_NAME = {}
for _, ct in ipairs(COIN_TYPES) do
    COIN_TYPE_BY_NAME[ct.Name] = ct
end

local function pickCoinType()
    local roll = math.random() * TOTAL_COIN_TYPE_WEIGHT
    local cumulative = 0
    for _, ct in ipairs(COIN_TYPES) do
        cumulative = cumulative + ct.Weight
        if roll <= cumulative then return ct end
    end
    return COIN_TYPES[2] -- Silver fallback
end

-- Combo streak tracking per player
local playerCombos = {} -- [userId] = { count, lastCollectTime }
local COMBO_WINDOW = 2.0 -- seconds to maintain combo
local COMBO_BONUSES = { 1.0, 1.2, 1.5, 2.0, 2.5, 3.0 } -- multiplier at combo 1,2,3,4,5,6+
local COMBO_COLORS = {
    Color3.fromRGB(255, 255, 100),
    Color3.fromRGB(255, 200, 50),
    Color3.fromRGB(255, 150, 0),
    Color3.fromRGB(255, 100, 50),
    Color3.fromRGB(255, 50, 50),
    Color3.fromRGB(255, 50, 255),
}

-- Per-player zone unlock hash set ─ avoids O(n) array scan on every coin touch
local playerZoneSet = {} -- [userId] = { [zoneId] = true }

local function getPlayerZoneSet(player: Player, data)
    local uid = player.UserId
    if not playerZoneSet[uid] then
        local set = {}
        for _, zId in ipairs(data.UnlockedZones or {}) do set[zId] = true end
        playerZoneSet[uid] = set
    end
    return playerZoneSet[uid]
end

-- Invalidate when a zone is unlocked so it is rebuilt on next touch
function CoinSpawnerService.InvalidateZoneCache(player: Player)
    playerZoneSet[player.UserId] = nil
end

-- Called by ZoneService when a player teleports; keeps auto-collect scoped to one zone
function CoinSpawnerService.SetPlayerZone(player: Player, zoneId: string)
    playerCurrentZone[player.UserId] = zoneId
end

-- All active coins registered for the shared batch-spin loop
local spinningCoins = {} -- { coin, position, spinSpeed, bobAmplitude, index }

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

-- Get combo multiplier for a player and advance their streak
local function getComboMultiplier(player: Player): (number, number)
    local userId = player.UserId
    local now = tick()
    local combo = playerCombos[userId]

    if not combo or (now - combo.lastCollectTime) > COMBO_WINDOW then
        -- Start new combo
        playerCombos[userId] = { count = 1, lastCollectTime = now }
        return COMBO_BONUSES[1], 1
    end

    -- Continue combo
    combo.count = math.min(combo.count + 1, #COMBO_BONUSES)
    combo.lastCollectTime = now
    local bonus = COMBO_BONUSES[combo.count] or COMBO_BONUSES[#COMBO_BONUSES]
    return bonus, combo.count
end

-- Collect a coin for a player
local function collectCoin(player: Player, coin: Instance, zone)
    local key = player.UserId .. "_" .. coin.Name
    if coinDebounce[key] then return end
    coinDebounce[key] = true

    local data = DataService and DataService.GetData(player)
    if not data then
        coinDebounce[key] = nil
        return
    end

    -- Check zone access (O(1) hash-set lookup)
    local zoneSet = getPlayerZoneSet(player, data)
    if not zoneSet[zone.Id] then
        coinDebounce[key] = nil
        return
    end

    -- Read coin type from stored attribute (set in createCoin)
    local coinTypeName = coin:GetAttribute("CoinType") or "Silver"
    local coinType = COIN_TYPE_BY_NAME[coinTypeName] or COIN_TYPES[2]

    -- Lucky drop system (stacks on top of coin type)
    local luckyMultiplier = 1
    local luckyPrefix = ""
    local roll = math.random()

    if roll < SUPER_LUCKY_CHANCE then
        luckyMultiplier = 15
        luckyPrefix = "JACKPOT! "
    elseif roll < SUPER_LUCKY_CHANCE + LUCKY_CHANCE then
        luckyMultiplier = 5
        luckyPrefix = "LUCKY! "
    end

    -- Combo streak
    local comboMultiplier, comboCount = getComboMultiplier(player)

    -- Base value ± random variation (±25% spread)
    local variation = 0.75 + math.random() * 0.5 -- 0.75 to 1.25
    local baseAmount = math.floor(zone.CoinValue * coinType.ValueMulti * luckyMultiplier * comboMultiplier * variation)
    -- ── Per-minute earning cap ──────────────────────────────────────────
    local userId = player.UserId
    local cap = playerMinuteCap[userId]
    local now = tick()
    if not cap or (now - cap.windowStart) >= 60 then
        cap = { earned = 0, windowStart = now }
        playerMinuteCap[userId] = cap
    end
    local maxPerMin = zone.CoinValue * MAX_COINS_PER_MINUTE_MULT
    if cap.earned >= maxPerMin then
        coinDebounce[key] = nil
        return
    end

    local amount = CurrencyService.Add(player, "Coins", baseAmount, true)
    if amount > 0 then cap.earned = cap.earned + amount end

    -- Visual feedback (amount already added above)
    if amount > 0 then
        local displayAmount
        if amount >= 1000000 then
            displayAmount = string.format("%.1fM", amount / 1000000)
        elseif amount >= 1000 then
            displayAmount = string.format("%.1fK", amount / 1000)
        else
            displayAmount = tostring(amount)
        end

        -- Build prefix and pick color based on what happened
        local prefix = luckyPrefix
        local color = coinType.Color

        if comboCount >= 4 then
            prefix = prefix .. comboCount .. "x COMBO! +"
            color = COMBO_COLORS[math.min(comboCount, #COMBO_COLORS)]
        elseif comboCount >= 2 then
            prefix = prefix .. comboCount .. "x +"
        else
            prefix = prefix .. "+"
        end

        if luckyMultiplier >= 15 then
            color = Color3.fromRGB(255, 50, 255)
        elseif luckyMultiplier >= 5 then
            color = Color3.fromRGB(100, 255, 100)
        end

        -- Fire only to the collecting player (server-side Part creation replicates to ALL clients)
        Network.FireClient("CoinFloatText", player, coin.Position, prefix .. displayAmount, color)

        -- Combo notification at milestones
        if comboCount == 3 or comboCount == 5 then
            Network.FireClient("ShowNotification", player,
                comboCount .. "x Combo! Keep collecting!", "Success")
        end

        -- Grant XP to equipped pets
        if PetLevelService then
            PetLevelService.GrantXP(player, amount)
        end
    end

    -- Hide coin
    coin.Transparency = 1
    local billboard = coin:FindFirstChild("CoinLabel")
    if billboard then billboard.Enabled = false end

    -- Re-roll coin type on respawn for variety
    task.delay(COIN_RESPAWN_TIME, function()
        if coin.Parent then
            local newType = pickCoinType()
            coin:SetAttribute("CoinType", newType.Name)
            coin.Size = newType.Size
            coin.Color = newType.Color
            coin.Transparency = 0

            -- Update label
            local labelGui = coin:FindFirstChild("CoinLabel")
            if labelGui then
                labelGui.Enabled = true
                local lbl = labelGui:FindFirstChildOfClass("TextLabel")
                if lbl then
                    local displayVal = math.floor(zone.CoinValue * newType.ValueMulti)
                    if displayVal >= 1000 then
                        lbl.Text = "+" .. string.format("%.1fK", displayVal / 1000)
                    else
                        lbl.Text = "+" .. displayVal
                    end
                    lbl.TextColor3 = newType.Color
                end
            end
        end
        coinDebounce[key] = nil
    end)
end

-- Create a single coin part with randomized type
local function createCoin(zone, position: Vector3, index: number)
    local coinType = pickCoinType()

    local coin = Instance.new("Part")
    coin.Name = "Coin_" .. zone.Id .. "_" .. index
    coin.Size = coinType.Size
    coin.Shape = Enum.PartType.Cylinder
    coin.Color = coinType.Color
    coin.Material = (coinType.Name == "Diamond" or coinType.Name == "Ruby") and Enum.Material.Glass or Enum.Material.Neon
    coin.Anchored = true
    coin.CanCollide = false
    coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    coin:SetAttribute("CoinType", coinType.Name)

    -- Zone identifier
    local zoneValue = Instance.new("StringValue")
    zoneValue.Name = "ZoneId"
    zoneValue.Value = zone.Id
    zoneValue.Parent = coin

    -- Value label showing scaled amount
    local displayVal = math.floor(zone.CoinValue * coinType.ValueMulti)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CoinLabel"
    billboard.Size = UDim2.new(0, 60, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 1.5, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent = coin

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    if displayVal >= 1000 then
        label.Text = "+" .. string.format("%.1fK", displayVal / 1000)
    else
        label.Text = "+" .. displayVal
    end
    label.TextColor3 = coinType.Color
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(30, 20, 0)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = billboard

    -- Touch-based collection (walk through to collect)
    coin.Touched:Connect(function(hit)
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            collectCoin(player, coin, zone)
        end
    end)

    -- Spinning + bobbing animation — registered into shared 20fps batch loop (not a per-coin goroutine)
    local spinSpeed = 2 + coinType.ValueMulti * 0.5
    local bobAmplitude = 0.3 + (coinType.ValueMulti / 10) * 0.2
    local startRotation = math.random() * 360
    table.insert(spinningCoins, {
        coin = coin,
        position = position,
        rotation = startRotation,
        spinSpeed = spinSpeed,
        bobAmplitude = bobAmplitude,
        index = index,
    })

    return coin
end

-- Single shared 20fps loop that animates ALL coins ─ replaces 240 separate 60fps goroutines
local function startCoinAnimLoop()
    task.spawn(function()
        local FRAME_TIME = 1 / 20 -- 20 fps is visually indistinguishable from 60 fps for coin spin
        while true do
            task.wait(FRAME_TIME)
            local now = tick()
            local i = 1
            while i <= #spinningCoins do
                local entry = spinningCoins[i]
                if not entry.coin.Parent then
                    -- Coin was destroyed; remove from list
                    spinningCoins[i] = spinningCoins[#spinningCoins]
                    spinningCoins[#spinningCoins] = nil
                elseif entry.coin.Transparency == 0 then
                    -- Only animate visible coins
                    entry.rotation = entry.rotation + entry.spinSpeed
                    local bob = math.sin(now * 2.5 + entry.index) * entry.bobAmplitude
                    entry.coin.CFrame = CFrame.new(
                        entry.position + Vector3.new(0, bob, 0)
                    ) * CFrame.Angles(0, math.rad(entry.rotation), math.rad(90))
                    i += 1
                else
                    i += 1
                end
            end
        end
    end)
end

-- Spawn coins for a zone
function CoinSpawnerService.SpawnZoneCoins(zone)
    local zoneFolder = getOrCreateZoneFolder(zone.Id)

    local coinsFolder = zoneFolder:FindFirstChild("Coins")
    if not coinsFolder then
        coinsFolder = Instance.new("Folder")
        coinsFolder.Name = "Coins"
        coinsFolder.Parent = zoneFolder
    end

    local coins = {}
    for i = 1, COINS_PER_ZONE do
        local angle = (i / COINS_PER_ZONE) * math.pi * 2
        local radius = math.random(10, COIN_SPAWN_RADIUS)
        local x = zone.SpawnPosition.X + math.cos(angle) * radius
        local z = zone.SpawnPosition.Z + math.sin(angle) * radius
        local position = Vector3.new(x, zone.SpawnPosition.Y + COIN_Y_HEIGHT, z)

        local coin = createCoin(zone, position, i)
        coin.Parent = coinsFolder
        table.insert(coins, coin)
    end

    -- Cache for auto-collect loop (avoids GetChildren() every 0.3s × player)
    table.insert(zoneCoinCache, { zone = zone, coinsFolder = coinsFolder, coins = coins })
    zoneCoinCacheByZoneId[zone.Id] = zoneCoinCache[#zoneCoinCache]
end

-- Auto-collect: pets attract nearby coins
local function startAutoCollect()
    task.spawn(function()
        while true do
            task.wait(AUTO_COLLECT_INTERVAL)
            local now = tick()
            for _, player in ipairs(Players:GetPlayers()) do
                local character = player.Character
                if not character then continue end
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end

                local data = DataService and DataService.GetData(player)
                if not data then continue end

                local equippedCount = #(data.EquippedPets or {})
                if equippedCount == 0 then continue end

                -- ── Idle detection ────────────────────────────────────────
                local userId = player.UserId
                local pos = hrp.Position
                local idle = playerIdleInfo[userId]
                if not idle then
                    idle = { ticks = 0, lastX = pos.X, lastZ = pos.Z }
                    playerIdleInfo[userId] = idle
                end

                local moved = math.sqrt((pos.X - idle.lastX)^2 + (pos.Z - idle.lastZ)^2)
                if moved < IDLE_MOVEMENT_THRESHOLD then
                    idle.ticks = idle.ticks + 1
                else
                    idle.ticks = 0
                end
                idle.lastX = pos.X
                idle.lastZ = pos.Z

                -- Suspend auto-collect for idle players
                if idle.ticks >= IDLE_TICKS_TO_SUSPEND then continue end

                local radius = AUTO_COLLECT_BASE_RADIUS + equippedCount * AUTO_COLLECT_PET_BONUS
                local playerPos = hrp.Position

                -- Only check coins in the player's current zone (O(30) instead of O(240))
                local curZone = playerCurrentZone[userId]
                local entry = curZone and zoneCoinCacheByZoneId[curZone]
                if entry then
                    local zone = entry.zone
                    for _, coin in ipairs(entry.coins) do
                        if coin.Transparency > 0 then continue end
                        local dist = (coin.Position - playerPos).Magnitude
                        if dist <= radius then
                            collectCoin(player, coin, zone)
                        end
                    end
                end
            end
        end
    end)
end

-- Create zone ground platforms with themed environments
-- ── Ambient particle factory ──────────────────────────────────────────
-- Creates 4 invisible emitter anchors spread across the zone so particles
-- blanket the whole platform rather than originating from a single point.
local function createAmbientParticles(zoneFolder, zoneSpawnPos, particleDef)
    local emitterFolder = Instance.new("Folder")
    emitterFolder.Name = "Ambience"
    emitterFolder.Parent = zoneFolder

    local offsets = {
        Vector3.new(-50, 8, -50),
        Vector3.new(50, 8, -50),
        Vector3.new(-50, 8, 50),
        Vector3.new(50, 8, 50),
    }

    for i, off in ipairs(offsets) do
        local anchor = Instance.new("Part")
        anchor.Name = "Emitter_" .. i
        anchor.Size = Vector3.new(1, 1, 1)
        anchor.Position = zoneSpawnPos + off
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.Transparency = 1
        anchor.Parent = emitterFolder

        local pe = Instance.new("ParticleEmitter")
        pe.Rate = particleDef.Rate or 8
        pe.Lifetime = NumberRange.new(particleDef.LifetimeMin or 3, particleDef.LifetimeMax or 6)
        pe.Speed = NumberRange.new(particleDef.SpeedMin or 0.5, particleDef.SpeedMax or 2)
        pe.SpreadAngle = Vector2.new(particleDef.Spread or 40, particleDef.Spread or 40)
        pe.RotSpeed = NumberRange.new(-30, 30)
        pe.Color = ColorSequence.new(particleDef.Color)
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, particleDef.SizeStart or 0.3),
            NumberSequenceKeypoint.new(1, particleDef.SizeEnd or 0.1),
        })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(0.7, 0.5),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.LightEmission = particleDef.LightEmission or 0
        pe.LightInfluence = particleDef.LightInfluence or 1
        pe.Acceleration = particleDef.Acceleration or Vector3.new(0, 0, 0)
        pe.Parent = anchor

        -- Optional PointLight for glowing particles
        if particleDef.Glow then
            local light = Instance.new("PointLight")
            light.Color = particleDef.Color
            light.Range = 12
            light.Brightness = 0.4
            light.Parent = anchor
        end
    end
end

-- ── Centerpiece landmark factory ─────────────────────────────────────
-- Each zone gets a unique focal point at the center that draws the eye.
local function createCenterpiece(zoneFolder, zoneSpawnPos, def)
    local base = zoneSpawnPos + Vector3.new(0, 0, 0)

    if def.Type == "fountain" then
        -- Stone ring + water spray particle
        local ring = Instance.new("Part")
        ring.Name = "Centerpiece_Ring"
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(2, 12, 12)
        ring.CFrame = CFrame.new(base + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Anchored = true
        ring.CanCollide = true
        ring.Material = Enum.Material.Cobblestone
        ring.Color = Color3.fromRGB(180, 180, 160)
        ring.Parent = zoneFolder

        local spout = Instance.new("Part")
        spout.Name = "Centerpiece_Spout"
        spout.Size = Vector3.new(1, 1, 1)
        spout.Position = base + Vector3.new(0, 3, 0)
        spout.Anchored = true
        spout.CanCollide = false
        spout.Transparency = 1
        spout.Parent = zoneFolder

        local pe = Instance.new("ParticleEmitter")
        pe.Rate = 25
        pe.Lifetime = NumberRange.new(1, 2)
        pe.Speed = NumberRange.new(3, 6)
        pe.SpreadAngle = Vector2.new(15, 15)
        pe.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0.1),
        })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.Acceleration = Vector3.new(0, -8, 0)
        pe.LightEmission = 0.3
        pe.Parent = spout

    elseif def.Type == "ancient_tree" then
        -- Massive tree trunk + canopy + dangling vines
        local trunk = Instance.new("Part")
        trunk.Name = "Centerpiece_Trunk"
        trunk.Size = Vector3.new(6, 20, 6)
        trunk.Position = base + Vector3.new(0, 10, 0)
        trunk.Anchored = true
        trunk.CanCollide = true
        trunk.Material = Enum.Material.Wood
        trunk.Color = Color3.fromRGB(80, 55, 30)
        trunk.Parent = zoneFolder

        local canopy = Instance.new("Part")
        canopy.Name = "Centerpiece_Canopy"
        canopy.Shape = Enum.PartType.Ball
        canopy.Size = Vector3.new(22, 14, 22)
        canopy.Position = base + Vector3.new(0, 22, 0)
        canopy.Anchored = true
        canopy.CanCollide = false
        canopy.Material = Enum.Material.Grass
        canopy.Color = def.Color
        canopy.Parent = zoneFolder

    elseif def.Type == "crystal_cluster" then
        -- Central crystal formation: 5 angled crystals
        for i = 1, 5 do
            local angle = (i / 5) * math.pi * 2
            local cr = Instance.new("Part")
            cr.Name = "Centerpiece_Crystal_" .. i
            cr.Size = Vector3.new(2, math.random(8, 14), 2)
            cr.Anchored = true
            cr.CanCollide = true
            cr.Material = Enum.Material.Neon
            cr.Color = def.Color
            cr.CFrame = CFrame.new(base + Vector3.new(math.cos(angle) * 3, cr.Size.Y / 2, math.sin(angle) * 3))
                * CFrame.Angles(math.rad(math.random(-20, 20)), angle, math.rad(math.random(-10, 10)))
            cr.Parent = zoneFolder
        end

    elseif def.Type == "lava_pool" then
        -- Glowing circular lava pool at center
        local pool = Instance.new("Part")
        pool.Name = "Centerpiece_LavaPool"
        pool.Shape = Enum.PartType.Cylinder
        pool.Size = Vector3.new(1, 14, 14)
        pool.CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
        pool.Anchored = true
        pool.CanCollide = false
        pool.Material = Enum.Material.Neon
        pool.Color = Color3.fromRGB(255, 100, 20)
        pool.Parent = zoneFolder

        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 80, 10)
        light.Range = 20
        light.Brightness = 1.5
        light.Parent = pool

        -- Lava bubble particles
        local emitter = Instance.new("Part")
        emitter.Size = Vector3.new(1, 1, 1)
        emitter.Position = base + Vector3.new(0, 1, 0)
        emitter.Anchored = true
        emitter.CanCollide = false
        emitter.Transparency = 1
        emitter.Parent = zoneFolder

        local pe = Instance.new("ParticleEmitter")
        pe.Rate = 6
        pe.Lifetime = NumberRange.new(1, 2)
        pe.Speed = NumberRange.new(2, 4)
        pe.SpreadAngle = Vector2.new(20, 20)
        pe.Color = ColorSequence.new(Color3.fromRGB(255, 150, 30))
        pe.Size = NumberSequence.new(0.5)
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.LightEmission = 1
        pe.Acceleration = Vector3.new(0, -4, 0)
        pe.Parent = emitter

    elseif def.Type == "ice_arch" then
        -- Two pillars + a top bridge forming an arch
        for _, side in ipairs({ -5, 5 }) do
            local pillar = Instance.new("Part")
            pillar.Name = "Centerpiece_IcePillar"
            pillar.Size = Vector3.new(3, 16, 3)
            pillar.Position = base + Vector3.new(side, 8, 0)
            pillar.Anchored = true
            pillar.CanCollide = true
            pillar.Material = Enum.Material.Glacier
            pillar.Color = def.Color
            pillar.Parent = zoneFolder
        end
        local bridge = Instance.new("Part")
        bridge.Name = "Centerpiece_IceBridge"
        bridge.Size = Vector3.new(14, 3, 3)
        bridge.Position = base + Vector3.new(0, 16, 0)
        bridge.Anchored = true
        bridge.CanCollide = true
        bridge.Material = Enum.Material.Glacier
        bridge.Color = def.Color
        bridge.Parent = zoneFolder

    elseif def.Type == "star_obelisk" then
        -- Tall marble pillar with glowing tip
        local pillar = Instance.new("Part")
        pillar.Name = "Centerpiece_Obelisk"
        pillar.Size = Vector3.new(4, 18, 4)
        pillar.Position = base + Vector3.new(0, 9, 0)
        pillar.Anchored = true
        pillar.CanCollide = true
        pillar.Material = Enum.Material.Marble
        pillar.Color = Color3.fromRGB(240, 230, 255)
        pillar.Parent = zoneFolder

        local tip = Instance.new("Part")
        tip.Name = "Centerpiece_ObeliskTip"
        tip.Shape = Enum.PartType.Ball
        tip.Size = Vector3.new(5, 5, 5)
        tip.Position = base + Vector3.new(0, 19, 0)
        tip.Anchored = true
        tip.CanCollide = false
        tip.Material = Enum.Material.Neon
        tip.Color = def.Color
        tip.Parent = zoneFolder

        local light = Instance.new("PointLight")
        light.Color = def.Color
        light.Range = 24
        light.Brightness = 2
        light.Parent = tip

    elseif def.Type == "void_portal" then
        -- Dark ring with swirling particles
        local ring = Instance.new("Part")
        ring.Name = "Centerpiece_VoidRing"
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(1, 16, 16)
        ring.CFrame = CFrame.new(base + Vector3.new(0, 8, 0)) * CFrame.Angles(math.rad(90), 0, 0)
        ring.Anchored = true
        ring.CanCollide = false
        ring.Material = Enum.Material.Neon
        ring.Color = def.Color
        ring.Transparency = 0.4
        ring.Parent = zoneFolder

        local portalEmitter = Instance.new("Part")
        portalEmitter.Size = Vector3.new(1, 1, 1)
        portalEmitter.Position = base + Vector3.new(0, 8, 0)
        portalEmitter.Anchored = true
        portalEmitter.CanCollide = false
        portalEmitter.Transparency = 1
        portalEmitter.Parent = zoneFolder

        local pe = Instance.new("ParticleEmitter")
        pe.Rate = 20
        pe.Lifetime = NumberRange.new(1.5, 3)
        pe.Speed = NumberRange.new(1, 3)
        pe.SpreadAngle = Vector2.new(180, 180)
        pe.Color = ColorSequence.new(def.Color)
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.8),
            NumberSequenceKeypoint.new(1, 0),
        })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.LightEmission = 1
        pe.Parent = portalEmitter

        local light = Instance.new("PointLight")
        light.Color = def.Color
        light.Range = 28
        light.Brightness = 1.5
        light.Parent = ring

    elseif def.Type == "neon_spire" then
        -- Spiraling neon column
        for i = 0, 5 do
            local seg = Instance.new("Part")
            seg.Name = "Centerpiece_Spire_" .. i
            seg.Size = Vector3.new(3 - i * 0.4, 4, 3 - i * 0.4)
            seg.CFrame = CFrame.new(base + Vector3.new(0, 2 + i * 4, 0)) * CFrame.Angles(0, math.rad(i * 30), 0)
            seg.Anchored = true
            seg.CanCollide = true
            seg.Material = Enum.Material.Neon
            seg.Color = def.Color
            seg.Parent = zoneFolder
        end
        local topGlow = Instance.new("Part")
        topGlow.Name = "Centerpiece_SpireTop"
        topGlow.Shape = Enum.PartType.Ball
        topGlow.Size = Vector3.new(4, 4, 4)
        topGlow.Position = base + Vector3.new(0, 28, 0)
        topGlow.Anchored = true
        topGlow.CanCollide = false
        topGlow.Material = Enum.Material.Neon
        topGlow.Color = def.Color
        topGlow.Parent = zoneFolder

        local light = Instance.new("PointLight")
        light.Color = def.Color
        light.Range = 30
        light.Brightness = 2
        light.Parent = topGlow
    end
end

function CoinSpawnerService.CreateZonePlatforms()
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

    -- Ambient particle definitions per zone
    local zoneParticles = {
        starter_meadow = {
            Rate = 6, LifetimeMin = 4, LifetimeMax = 8, SpeedMin = 0.3, SpeedMax = 1.5,
            Spread = 60, Color = Color3.fromRGB(140, 200, 60), SizeStart = 0.4, SizeEnd = 0.1,
            Acceleration = Vector3.new(0, -0.5, 0), LightEmission = 0, LightInfluence = 1,
        },
        forest_grove = {
            Rate = 8, LifetimeMin = 3, LifetimeMax = 7, SpeedMin = 0.2, SpeedMax = 1.0,
            Spread = 50, Color = Color3.fromRGB(50, 160, 40), SizeStart = 0.5, SizeEnd = 0.15,
            Acceleration = Vector3.new(0.3, -0.8, 0), LightEmission = 0, LightInfluence = 1,
        },
        crystal_caves = {
            Rate = 5, LifetimeMin = 3, LifetimeMax = 6, SpeedMin = 0.3, SpeedMax = 1.0,
            Spread = 30, Color = Color3.fromRGB(150, 120, 255), SizeStart = 0.3, SizeEnd = 0.05,
            LightEmission = 0.8, LightInfluence = 0.2, Glow = true,
        },
        volcanic_ridge = {
            Rate = 10, LifetimeMin = 2, LifetimeMax = 4, SpeedMin = 1, SpeedMax = 4,
            Spread = 25, Color = Color3.fromRGB(255, 120, 20), SizeStart = 0.3, SizeEnd = 0,
            Acceleration = Vector3.new(0, 2, 0), LightEmission = 1, LightInfluence = 0, Glow = true,
        },
        frozen_tundra = {
            Rate = 12, LifetimeMin = 4, LifetimeMax = 9, SpeedMin = 0.2, SpeedMax = 0.8,
            Spread = 70, Color = Color3.fromRGB(220, 240, 255), SizeStart = 0.3, SizeEnd = 0.1,
            Acceleration = Vector3.new(0, -0.3, 0), LightEmission = 0.2, LightInfluence = 0.8,
        },
        celestial_garden = {
            Rate = 7, LifetimeMin = 3, LifetimeMax = 7, SpeedMin = 0.5, SpeedMax = 2,
            Spread = 50, Color = Color3.fromRGB(230, 200, 255), SizeStart = 0.25, SizeEnd = 0,
            Acceleration = Vector3.new(0, 0.5, 0), LightEmission = 1, LightInfluence = 0, Glow = true,
        },
        shadow_realm = {
            Rate = 6, LifetimeMin = 3, LifetimeMax = 6, SpeedMin = 0.3, SpeedMax = 1.5,
            Spread = 40, Color = Color3.fromRGB(100, 20, 160), SizeStart = 0.5, SizeEnd = 0.1,
            Acceleration = Vector3.new(0, 0.3, 0), LightEmission = 0.6, LightInfluence = 0.3,
        },
        cosmic_void = {
            Rate = 8, LifetimeMin = 2, LifetimeMax = 5, SpeedMin = 0.5, SpeedMax = 2,
            Spread = 60, Color = Color3.fromRGB(180, 50, 255), SizeStart = 0.35, SizeEnd = 0,
            Acceleration = Vector3.new(0, 0, 0), LightEmission = 1, LightInfluence = 0, Glow = true,
        },
    }

    -- Centerpiece landmark per zone
    local zoneCenterpieces = {
        starter_meadow   = { Type = "fountain" },
        forest_grove     = { Type = "ancient_tree", Color = Color3.fromRGB(30, 120, 25) },
        crystal_caves    = { Type = "crystal_cluster", Color = Color3.fromRGB(150, 100, 255) },
        volcanic_ridge   = { Type = "lava_pool" },
        frozen_tundra    = { Type = "ice_arch", Color = Color3.fromRGB(180, 230, 255) },
        celestial_garden = { Type = "star_obelisk", Color = Color3.fromRGB(220, 180, 255) },
        shadow_realm     = { Type = "void_portal", Color = Color3.fromRGB(120, 20, 180) },
        cosmic_void      = { Type = "neon_spire", Color = Color3.fromRGB(200, 50, 255) },
    }

    for _, zone in ipairs(ZoneConfig.Zones) do
        local zoneFolder = getOrCreateZoneFolder(zone.Id)
        local theme = zoneThemes[zone.Id]
        local material = theme and theme.Material or Enum.Material.Grass

        -- Main ground platform
        local ground = Instance.new("Part")
        ground.Name = "Ground"
        ground.Size = Vector3.new(240, 2, 240)
        ground.Position = zone.SpawnPosition - Vector3.new(0, 1, 0)
        ground.Anchored = true
        ground.Color = zone.Color
        ground.Material = material
        ground.TopSurface = Enum.SurfaceType.Smooth
        ground.BottomSurface = Enum.SurfaceType.Smooth
        ground.Parent = zoneFolder

        -- Invisible boundary walls (tall enough to prevent jumping out; contain zone)
        -- Zone ground is 160×160; walls sit at ±82 on each axis.
        -- Players can only enter/exit via TeleportToZone, not by walking out.
        local WALL_HEIGHT = 40
        local WALL_THICK = 4
        local WALL_HALF = 122
        local boundaryParts = {
            { Size = Vector3.new(248, WALL_HEIGHT, WALL_THICK), Offset = Vector3.new(0,   WALL_HEIGHT / 2,  WALL_HALF) },
            { Size = Vector3.new(248, WALL_HEIGHT, WALL_THICK), Offset = Vector3.new(0,   WALL_HEIGHT / 2, -WALL_HALF) },
            { Size = Vector3.new(WALL_THICK, WALL_HEIGHT, 248), Offset = Vector3.new( WALL_HALF, WALL_HEIGHT / 2, 0) },
            { Size = Vector3.new(WALL_THICK, WALL_HEIGHT, 248), Offset = Vector3.new(-WALL_HALF, WALL_HEIGHT / 2, 0) },
        }

        for i, border in ipairs(boundaryParts) do
            local wall = Instance.new("Part")
            wall.Name = "Boundary_" .. i
            wall.Size = border.Size
            wall.Position = zone.SpawnPosition + border.Offset + Vector3.new(0, 0.5, 0)
            wall.Anchored = true
            wall.CanCollide = true
            wall.Transparency = 0.85          -- nearly invisible; shows only a faint tinted shimmer
            wall.Material = Enum.Material.Neon
            wall.CastShadow = false
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

        -- Centerpiece landmark (at zone center, built first so props scatter around)
        local cpDef = zoneCenterpieces[zone.Id]
        if cpDef then
            createCenterpiece(zoneFolder, zone.SpawnPosition, cpDef)
        end

        -- Ambient particle emitters
        local pDef = zoneParticles[zone.Id]
        if pDef then
            createAmbientParticles(zoneFolder, zone.SpawnPosition, pDef)
        end

        -- Decorative props — scattered in clusters rather than a uniform ring.
        -- 3 clusters at 120° intervals + a few random stragglers = organic feel.
        if theme then
            local propsFolder = Instance.new("Folder")
            propsFolder.Name = "Props"
            propsFolder.Parent = zoneFolder

            local propColor = theme.PropColor

            -- Pre-compute scattered positions: 3 clusters of 3 + 3 random singles = 12
            local propPositions = {}
            local clusterAngles = { 0, math.pi * 2/3, math.pi * 4/3 }
            for ci, cAngle in ipairs(clusterAngles) do
                local cRadius = math.random(30, 50)
                local cx = math.cos(cAngle + math.random() * 0.4 - 0.2) * cRadius
                local cz = math.sin(cAngle + math.random() * 0.4 - 0.2) * cRadius
                for k = 1, 3 do
                    local ox = cx + math.random(-8, 8)
                    local oz = cz + math.random(-8, 8)
                    table.insert(propPositions, { x = zone.SpawnPosition.X + ox, z = zone.SpawnPosition.Z + oz })
                end
            end
            -- 3 random stragglers
            for _ = 1, 3 do
                local ra = math.random() * math.pi * 2
                local rr = math.random(20, 70)
                table.insert(propPositions, {
                    x = zone.SpawnPosition.X + math.cos(ra) * rr,
                    z = zone.SpawnPosition.Z + math.sin(ra) * rr,
                })
            end

            for j = 1, 12 do
                local pos = propPositions[j]
                local x = pos.x
                local z = pos.z
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
function CoinSpawnerService.Init(dataService, currencyService, petLevelService)
    DataService = dataService
    CurrencyService = currencyService
    PetLevelService = petLevelService

    CoinSpawnerService.CreateZonePlatforms()

    -- Debug: log first zone platform position
    local firstZone = ZoneConfig.Zones[1]
    if firstZone then
        local groundY = firstZone.SpawnPosition.Y - 1
        print(string.format("[CoinSpawnerService] Zone 1 ground center Y=%.1f, top Y=%.1f, coins at Y=%.1f",
            groundY, groundY + 1, firstZone.SpawnPosition.Y + COIN_Y_HEIGHT))
    end

    for _, zone in ipairs(ZoneConfig.Zones) do
        CoinSpawnerService.SpawnZoneCoins(zone)
    end

    -- Single shared animation loop replaces one goroutine per coin
    startCoinAnimLoop()

    -- Start auto-collect loop for players with equipped pets
    startAutoCollect()

    print("[CoinSpawnerService] Spawned " .. COINS_PER_ZONE .. " coins in " .. #ZoneConfig.Zones .. " zones with auto-collect")
end

function CoinSpawnerService.PlayerRemoving(player)
    local uid = player.UserId
    playerCombos[uid] = nil
    playerIdleInfo[uid] = nil
    playerMinuteCap[uid] = nil
    playerZoneSet[uid] = nil
    playerCurrentZone[uid] = nil
    -- Sweep stale coinDebounce entries for this player
    local prefix = tostring(uid) .. "_"
    for key in pairs(coinDebounce) do
        if string.sub(key, 1, #prefix) == prefix then
            coinDebounce[key] = nil
        end
    end
end

return CoinSpawnerService
