--[[
    ZoneAmbience.client.luau
    Client-side zone atmosphere, unlock celebrations, and ambient sound.

    Features:
    1. Per-zone Lighting/Atmosphere tweens (ClockTime, fog, ambient color)
    2. Zone unlock celebration (screen flash + particle burst + welcome text)
    3. Ambient sound loops that crossfade between zones
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

-- ═══════════════════════════════════════
-- 1. PER-ZONE ATMOSPHERE / LIGHTING
-- ═══════════════════════════════════════

local TWEEN_TIME = 1.2

-- Each zone defines its lighting mood. Missing fields use defaults.
local zoneLighting = {
    starter_meadow = {
        ClockTime = 14,
        Brightness = 2,
        Ambient = Color3.fromRGB(80, 80, 70),
        OutdoorAmbient = Color3.fromRGB(140, 140, 120),
        FogEnd = 1000,
        FogColor = Color3.fromRGB(180, 210, 230),
        AtmoDensity = 0.25,
        AtmoColor = Color3.fromRGB(200, 220, 230),
    },
    forest_grove = {
        ClockTime = 12,
        Brightness = 1.5,
        Ambient = Color3.fromRGB(40, 60, 35),
        OutdoorAmbient = Color3.fromRGB(80, 100, 70),
        FogEnd = 500,
        FogColor = Color3.fromRGB(80, 120, 60),
        AtmoDensity = 0.4,
        AtmoColor = Color3.fromRGB(100, 140, 80),
    },
    crystal_caves = {
        ClockTime = 20,
        Brightness = 0.8,
        Ambient = Color3.fromRGB(50, 30, 80),
        OutdoorAmbient = Color3.fromRGB(60, 40, 100),
        FogEnd = 400,
        FogColor = Color3.fromRGB(40, 20, 70),
        AtmoDensity = 0.5,
        AtmoColor = Color3.fromRGB(80, 50, 140),
    },
    volcanic_ridge = {
        ClockTime = 16,
        Brightness = 1.8,
        Ambient = Color3.fromRGB(100, 50, 20),
        OutdoorAmbient = Color3.fromRGB(140, 70, 30),
        FogEnd = 600,
        FogColor = Color3.fromRGB(120, 60, 20),
        AtmoDensity = 0.35,
        AtmoColor = Color3.fromRGB(180, 80, 30),
    },
    frozen_tundra = {
        ClockTime = 10,
        Brightness = 2.5,
        Ambient = Color3.fromRGB(100, 120, 140),
        OutdoorAmbient = Color3.fromRGB(160, 180, 200),
        FogEnd = 350,
        FogColor = Color3.fromRGB(200, 220, 240),
        AtmoDensity = 0.45,
        AtmoColor = Color3.fromRGB(210, 230, 250),
    },
    celestial_garden = {
        ClockTime = 22,
        Brightness = 1,
        Ambient = Color3.fromRGB(80, 60, 120),
        OutdoorAmbient = Color3.fromRGB(120, 100, 160),
        FogEnd = 700,
        FogColor = Color3.fromRGB(100, 80, 150),
        AtmoDensity = 0.3,
        AtmoColor = Color3.fromRGB(150, 120, 200),
    },
    shadow_realm = {
        ClockTime = 1,
        Brightness = 0.5,
        Ambient = Color3.fromRGB(20, 10, 30),
        OutdoorAmbient = Color3.fromRGB(30, 15, 50),
        FogEnd = 300,
        FogColor = Color3.fromRGB(20, 10, 40),
        AtmoDensity = 0.55,
        AtmoColor = Color3.fromRGB(40, 15, 60),
    },
    cosmic_void = {
        ClockTime = 0,
        Brightness = 0.3,
        Ambient = Color3.fromRGB(15, 5, 30),
        OutdoorAmbient = Color3.fromRGB(20, 10, 40),
        FogEnd = 250,
        FogColor = Color3.fromRGB(10, 0, 25),
        AtmoDensity = 0.6,
        AtmoColor = Color3.fromRGB(30, 10, 60),
    },
}

local atmosphere: Atmosphere? = nil

local function getOrCreateAtmosphere(): Atmosphere
    if atmosphere then return atmosphere end
    atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end
    return atmosphere
end

local activeLightingTween: Tween? = nil
local activeAtmoTween: Tween? = nil

local function tweenToZoneLighting(zoneId: string)
    local def = zoneLighting[zoneId]
    if not def then return end

    local info = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- Tween Lighting properties
    if activeLightingTween then activeLightingTween:Cancel() end
    activeLightingTween = TweenService:Create(Lighting, info, {
        ClockTime = def.ClockTime,
        Brightness = def.Brightness,
        Ambient = def.Ambient,
        OutdoorAmbient = def.OutdoorAmbient,
        FogEnd = def.FogEnd,
        FogColor = def.FogColor,
    })
    activeLightingTween:Play()

    -- Tween Atmosphere
    local atmo = getOrCreateAtmosphere()
    if activeAtmoTween then activeAtmoTween:Cancel() end
    activeAtmoTween = TweenService:Create(atmo, info, {
        Density = def.AtmoDensity,
        Color = def.AtmoColor,
    })
    activeAtmoTween:Play()
end

-- ═══════════════════════════════════════
-- 2. ZONE UNLOCK CELEBRATION
-- ═══════════════════════════════════════

local celebrationGui = Instance.new("ScreenGui")
celebrationGui.Name = "ZoneCelebration"
celebrationGui.ResetOnSpawn = false
celebrationGui.DisplayOrder = 100
celebrationGui.IgnoreGuiInset = true
celebrationGui.Enabled = false
celebrationGui.Parent = playerGui

-- Full-screen flash overlay
local flash = Instance.new("Frame")
flash.Size = UDim2.new(1, 0, 1, 0)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = celebrationGui

-- Welcome text
local welcomeLabel = Instance.new("TextLabel")
welcomeLabel.Size = UDim2.new(0.8, 0, 0, 80)
welcomeLabel.Position = UDim2.new(0.1, 0, 0.35, 0)
welcomeLabel.BackgroundTransparency = 1
welcomeLabel.Text = ""
welcomeLabel.TextColor3 = Color3.new(1, 1, 1)
welcomeLabel.Font = Enum.Font.GothamBlack
welcomeLabel.TextSize = 48
welcomeLabel.TextStrokeTransparency = 0
welcomeLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
welcomeLabel.TextTransparency = 1
welcomeLabel.Parent = celebrationGui

-- Zone description subtitle
local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Size = UDim2.new(0.6, 0, 0, 30)
subtitleLabel.Position = UDim2.new(0.2, 0, 0.35, 80)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = ""
subtitleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
subtitleLabel.Font = Enum.Font.GothamBold
subtitleLabel.TextSize = 22
subtitleLabel.TextStrokeTransparency = 0
subtitleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
subtitleLabel.TextTransparency = 1
subtitleLabel.Parent = celebrationGui

local function playCelebration(zoneId: string)
    local zone = ZoneConfig.GetZone(zoneId)
    if not zone then return end

    celebrationGui.Enabled = true

    -- Flash: white flash that fades quickly
    flash.BackgroundColor3 = zone.Color
    flash.BackgroundTransparency = 0.3
    TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {
        BackgroundTransparency = 1,
    }):Play()

    -- Welcome text fade in, hold, fade out
    welcomeLabel.Text = "Welcome to " .. zone.Name .. "!"
    welcomeLabel.TextColor3 = zone.Color
    subtitleLabel.Text = "💰 " .. zone.CoinMultiplier .. "x Coins"

    -- Fade in
    welcomeLabel.TextTransparency = 1
    subtitleLabel.TextTransparency = 1
    welcomeLabel.Position = UDim2.new(0.1, 0, 0.38, 0)
    subtitleLabel.Position = UDim2.new(0.2, 0, 0.38, 80)

    local fadeIn = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(welcomeLabel, fadeIn, {
        TextTransparency = 0,
        Position = UDim2.new(0.1, 0, 0.35, 0),
    }):Play()
    task.delay(0.15, function()
        TweenService:Create(subtitleLabel, fadeIn, {
            TextTransparency = 0,
            Position = UDim2.new(0.2, 0, 0.35, 80),
        }):Play()
    end)

    -- Hold, then fade out
    task.delay(2.5, function()
        local fadeOut = TweenInfo.new(0.6, Enum.EasingStyle.Quad)
        TweenService:Create(welcomeLabel, fadeOut, { TextTransparency = 1 }):Play()
        TweenService:Create(subtitleLabel, fadeOut, { TextTransparency = 1 }):Play()
        task.delay(0.7, function()
            celebrationGui.Enabled = false
        end)
    end)

    -- Burst particles around the player camera
    local camera = workspace.CurrentCamera
    if camera then
        local burstPart = Instance.new("Part")
        burstPart.Size = Vector3.new(1, 1, 1)
        burstPart.Position = camera.CFrame.Position + camera.CFrame.LookVector * 5
        burstPart.Anchored = true
        burstPart.CanCollide = false
        burstPart.Transparency = 1
        burstPart.Parent = workspace

        local pe = Instance.new("ParticleEmitter")
        pe.Rate = 0 -- use :Emit() burst
        pe.Lifetime = NumberRange.new(1, 2)
        pe.Speed = NumberRange.new(8, 15)
        pe.SpreadAngle = Vector2.new(180, 180)
        pe.Color = ColorSequence.new(zone.Color)
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.LightEmission = 1
        pe.Parent = burstPart

        pe:Emit(40) -- burst of 40 particles

        task.delay(3, function()
            burstPart:Destroy()
        end)
    end
end

-- ═══════════════════════════════════════
-- 3. AMBIENT SOUND CROSSFADE
-- ═══════════════════════════════════════

-- Soundscape IDs per zone (Roblox library ambient loops)
-- Using built-in sound IDs that work without uploading custom audio
local zoneSounds = {
    starter_meadow   = { Id = "rbxassetid://9113088834", Volume = 0.3 }, -- gentle nature
    forest_grove     = { Id = "rbxassetid://9113088834", Volume = 0.35 }, -- forest birds
    crystal_caves    = { Id = "rbxassetid://9114488453", Volume = 0.25 }, -- cave drips
    volcanic_ridge   = { Id = "rbxassetid://9114229022", Volume = 0.3 }, -- rumble
    frozen_tundra    = { Id = "rbxassetid://9114229022", Volume = 0.2 }, -- wind howl
    celestial_garden = { Id = "rbxassetid://9114488453", Volume = 0.2 }, -- ethereal
    shadow_realm     = { Id = "rbxassetid://9114488453", Volume = 0.15 }, -- dark ambient
    cosmic_void      = { Id = "rbxassetid://9114488453", Volume = 0.1 }, -- void hum
}

local currentSound: Sound? = nil
local soundFolder = Instance.new("Folder")
soundFolder.Name = "ZoneAmbience"
soundFolder.Parent = SoundService

local function crossfadeToZone(zoneId: string)
    local def = zoneSounds[zoneId]

    -- Fade out current
    if currentSound then
        local old = currentSound
        TweenService:Create(old, TweenInfo.new(1), { Volume = 0 }):Play()
        task.delay(1.1, function()
            old:Destroy()
        end)
        currentSound = nil
    end

    if not def then return end

    -- Create + fade in new
    local sound = Instance.new("Sound")
    sound.SoundId = def.Id
    sound.Volume = 0
    sound.Looped = true
    sound.Parent = soundFolder
    sound:Play()

    TweenService:Create(sound, TweenInfo.new(1.5), { Volume = def.Volume }):Play()
    currentSound = sound
end

-- ═══════════════════════════════════════
-- EVENT WIRING
-- ═══════════════════════════════════════

local currentZoneId = "starter_meadow"

-- Zone teleport: tween atmosphere + crossfade sound
Network.OnClientEvent("ZoneTeleported", function(zoneId)
    currentZoneId = zoneId
    tweenToZoneLighting(zoneId)
    crossfadeToZone(zoneId)
end)

-- Zone unlock: celebration + atmosphere + sound
Network.OnClientEvent("ZoneUnlocked", function(zoneId)
    playCelebration(zoneId)
end)

-- Initial data: set atmosphere for starting zone
Network.OnClientEvent("PlayerDataLoaded", function(data)
    local startZone = "starter_meadow"
    if data.HighestZone then
        local zone = ZoneConfig.GetZoneByOrder(data.HighestZone)
        if zone then startZone = zone.Id end
    end
    currentZoneId = startZone
    tweenToZoneLighting(startZone)
    crossfadeToZone(startZone)
end)

print("[GUI] ZoneAmbience loaded — atmosphere, celebrations, ambient sound")
