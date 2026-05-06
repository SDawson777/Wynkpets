--[[
    WorldBuilderService.luau
    Guarantees a SpawnLocation exists at the Zone 1 floor level (Y=5.5)
    and sets up Lighting/Atmosphere if not already configured.

    Zone geometry (platforms, walls, props, labels) is built by
    CoinSpawnerService.CreateZonePlatforms() which runs after this.
    All zone SpawnPositions have Y=5; platform top surfaces are at Y=5.
    SpawnLocation sits flush on top of the Zone 1 platform.
]]

local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")

local WorldBuilderService = {}

-- SpawnPosition.Y = 5 for all zones; platform top = Y=5.
-- SpawnLocation center at Y=5.5 puts its bottom exactly at Y=5 (flush with platform).
local SPAWN_Y = 5.5

-- Remove any Studio-generated terrain that could act as a phantom ground surface.
-- Terrain persists in the .rbxl file and Rojo does not manage it, so leftover
-- terrain at an unknown height would make every zone object appear underground.
local function clearTerrain()
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        terrain:Clear()
    end
end

-- Remove any stale baseplates that might sit above the zone platforms.
local function removeBaseplates()
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("BasePart") and (child.Name == "Baseplate" or child.Name == "Base") then
            child:Destroy()
        end
    end
end

local function ensureSpawnLocation()
    if Workspace:FindFirstChildOfClass("SpawnLocation") then
        -- Move existing SpawnLocation to the correct height if it's wrong
        local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
        if sp.Position.Y < 4 then
            sp.Position = Vector3.new(sp.Position.X, SPAWN_Y, sp.Position.Z)
        end
        return
    end

    local sp = Instance.new("SpawnLocation")
    sp.Name     = "SpawnLocation"
    sp.Size     = Vector3.new(6, 1, 6)
    sp.Position = Vector3.new(0, SPAWN_Y, 0)
    sp.Anchored = true
    sp.Neutral  = true
    sp.Color    = BrickColor.new("Bright green")
    sp.Parent   = Workspace
end

local function ensureLighting()
    if Lighting:FindFirstChildOfClass("Atmosphere") then return end

    local atmo = Instance.new("Atmosphere")
    atmo.Density  = 0.3
    atmo.Offset   = 0.1
    atmo.Color    = Color3.fromRGB(199, 199, 199)
    atmo.Decay    = Color3.fromRGB(94, 94, 94)
    atmo.Glare    = 0
    atmo.Haze     = 0
    atmo.Parent   = Lighting

    Lighting.ClockTime      = 14
    Lighting.Brightness     = 2
    Lighting.Ambient        = Color3.fromRGB(70, 70, 70)
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end

function WorldBuilderService.Init()
    clearTerrain()
    removeBaseplates()
    ensureSpawnLocation()
    ensureLighting()
    print("[WorldBuilderService] Environment ready — terrain cleared, baseplates removed, zones built by CoinSpawnerService")
end

return WorldBuilderService
