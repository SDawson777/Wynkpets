--[[
    ObstacleConfig.luau
    Defines per-zone obstacles. Zone 1 (starter_meadow) has none.
    All positions are offsets from zone SpawnPosition.
    Obstacles are slow, bright, and forgiving — designed for 7-year-olds.
]]

local ObstacleConfig = {}

ObstacleConfig.InvincibilityDuration = 3 -- seconds of invincibility after being hit
ObstacleConfig.KnockbackMessage = "Oops! Back to the start!"

-- Obstacle types:
--   SpinBar: Neon bar rotating around Y axis. Jumpable (Y=2).
--   BouncingOrb: Neon ball bouncing between PathStart and PathEnd.
--   PulseZone: Floor circle cycling safe→warning→danger.

ObstacleConfig.ZoneObstacles = {
    starter_meadow = {}, -- Zone 1: completely safe!

    forest_grove = { -- Zone 2: 2 gentle spinning bars
        {
            Type = "SpinBar",
            Position = Vector3.new(15, 0, 15),
            Speed = 25,
            Length = 18,
            Color = Color3.fromRGB(255, 120, 50),
        },
        {
            Type = "SpinBar",
            Position = Vector3.new(-30, 0, -25),
            Speed = 22,
            Length = 16,
            Color = Color3.fromRGB(200, 150, 50),
        },
    },

    crystal_caves = { -- Zone 3: 3 spinning bars + 1 orb
        {
            Type = "SpinBar",
            Position = Vector3.new(-20, 0, 10),
            Speed = 28,
            Length = 20,
            Color = Color3.fromRGB(200, 50, 255),
        },
        {
            Type = "SpinBar",
            Position = Vector3.new(25, 0, -20),
            Speed = 25,
            Length = 16,
            Color = Color3.fromRGB(150, 220, 255),
        },
        {
            Type = "SpinBar",
            Position = Vector3.new(-40, 0, -40),
            Speed = 20,
            Length = 20,
            Color = Color3.fromRGB(180, 100, 255),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(-50, 3, 30),
            PathEnd = Vector3.new(50, 3, 30),
            Speed = 7,
            Size = 3.5,
            Color = Color3.fromRGB(130, 80, 255),
        },
    },

    volcanic_ridge = { -- Zone 4: 2 spin bars + 2 bouncing orbs
        {
            Type = "SpinBar",
            Position = Vector3.new(0, 0, 25),
            Speed = 30,
            Length = 20,
            Color = Color3.fromRGB(255, 80, 30),
        },
        {
            Type = "SpinBar",
            Position = Vector3.new(-35, 0, -30),
            Speed = 26,
            Length = 18,
            Color = Color3.fromRGB(255, 140, 20),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(-40, 3, 0),
            PathEnd = Vector3.new(40, 3, 0),
            Speed = 8,
            Size = 4,
            Color = Color3.fromRGB(255, 60, 20),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(0, 3, -45),
            PathEnd = Vector3.new(0, 3, 45),
            Speed = 7,
            Size = 3.5,
            Color = Color3.fromRGB(255, 120, 40),
        },
    },

    frozen_tundra = { -- Zone 5: 2 spin bars + 3 bouncing orbs
        {
            Type = "SpinBar",
            Position = Vector3.new(10, 0, -20),
            Speed = 28,
            Length = 18,
            Color = Color3.fromRGB(100, 200, 255),
        },
        {
            Type = "SpinBar",
            Position = Vector3.new(-35, 0, 35),
            Speed = 24,
            Length = 20,
            Color = Color3.fromRGB(150, 220, 255),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(0, 3, -40),
            PathEnd = Vector3.new(0, 3, 40),
            Speed = 9,
            Size = 4,
            Color = Color3.fromRGB(180, 230, 255),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(-40, 3, 10),
            PathEnd = Vector3.new(40, 3, 10),
            Speed = 7,
            Size = 3.5,
            Color = Color3.fromRGB(100, 180, 255),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(30, 3, -30),
            PathEnd = Vector3.new(-30, 3, 30),
            Speed = 8,
            Size = 4,
            Color = Color3.fromRGB(200, 240, 255),
        },
    },

    celestial_garden = { -- Zone 6: 2 orbs + 2 pulse zones + 1 spin bar
        {
            Type = "SpinBar",
            Position = Vector3.new(35, 0, -35),
            Speed = 26,
            Length = 18,
            Color = Color3.fromRGB(220, 180, 255),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(-40, 3, -40),
            PathEnd = Vector3.new(40, 3, 40),
            Speed = 9,
            Size = 4,
            Color = Color3.fromRGB(200, 150, 255),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(40, 3, -10),
            PathEnd = Vector3.new(-40, 3, -10),
            Speed = 8,
            Size = 3.5,
            Color = Color3.fromRGB(255, 200, 255),
        },
        {
            Type = "PulseZone",
            Position = Vector3.new(0, 0, 0),
            Radius = 10,
            SafeTime = 4,
            WarnTime = 1,
            DangerTime = 2,
        },
        {
            Type = "PulseZone",
            Position = Vector3.new(-40, 0, 30),
            Radius = 8,
            SafeTime = 3.5,
            WarnTime = 1,
            DangerTime = 2,
        },
    },

    shadow_realm = { -- Zone 7: 2 spin bars + 2 orbs + 3 pulse zones
        {
            Type = "SpinBar",
            Position = Vector3.new(-15, 0, -15),
            Speed = 32,
            Length = 20,
            Color = Color3.fromRGB(150, 50, 200),
        },
        {
            Type = "SpinBar",
            Position = Vector3.new(40, 0, 30),
            Speed = 28,
            Length = 18,
            Color = Color3.fromRGB(120, 30, 180),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(-50, 3, 15),
            PathEnd = Vector3.new(50, 3, 15),
            Speed = 10,
            Size = 4.5,
            Color = Color3.fromRGB(100, 0, 150),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(15, 3, -50),
            PathEnd = Vector3.new(15, 3, 50),
            Speed = 9,
            Size = 4,
            Color = Color3.fromRGB(130, 20, 180),
        },
        {
            Type = "PulseZone",
            Position = Vector3.new(20, 0, -20),
            Radius = 8,
            SafeTime = 4,
            WarnTime = 1,
            DangerTime = 2,
        },
        {
            Type = "PulseZone",
            Position = Vector3.new(-35, 0, 35),
            Radius = 8,
            SafeTime = 3.5,
            WarnTime = 1,
            DangerTime = 2,
        },
        {
            Type = "PulseZone",
            Position = Vector3.new(-50, 0, -40),
            Radius = 7,
            SafeTime = 3,
            WarnTime = 1,
            DangerTime = 2.5,
        },
    },

    cosmic_void = { -- Zone 8: 2 spin bars + 3 orbs + 2 pulse zones
        {
            Type = "SpinBar",
            Position = Vector3.new(0, 0, 0),
            Speed = 35,
            Length = 22,
            Color = Color3.fromRGB(100, 0, 200),
        },
        {
            Type = "SpinBar",
            Position = Vector3.new(-45, 0, -40),
            Speed = 30,
            Length = 20,
            Color = Color3.fromRGB(80, 0, 160),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(-50, 3, -20),
            PathEnd = Vector3.new(50, 3, 20),
            Speed = 10,
            Size = 4,
            Color = Color3.fromRGB(150, 50, 255),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(20, 3, -50),
            PathEnd = Vector3.new(20, 3, 50),
            Speed = 9,
            Size = 4,
            Color = Color3.fromRGB(80, 0, 180),
        },
        {
            Type = "BouncingOrb",
            PathStart = Vector3.new(-45, 3, 35),
            PathEnd = Vector3.new(45, 3, -35),
            Speed = 11,
            Size = 4.5,
            Color = Color3.fromRGB(130, 20, 255),
        },
        {
            Type = "PulseZone",
            Position = Vector3.new(-15, 0, 15),
            Radius = 10,
            SafeTime = 3.5,
            WarnTime = 1,
            DangerTime = 2,
        },
        {
            Type = "PulseZone",
            Position = Vector3.new(40, 0, -35),
            Radius = 9,
            SafeTime = 3,
            WarnTime = 1,
            DangerTime = 2.5,
        },
    },
}

return ObstacleConfig
