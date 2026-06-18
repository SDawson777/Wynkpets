--[[
    SpecialEggConfig.luau
    Defines the rare special eggs that spawn randomly in zones.
    First-come-first-served, free hatch from premium pool.
]]

local SpecialEggConfig = {}

-- Timing
SpecialEggConfig.SpawnIntervalMin = 120  -- 2 minutes min between spawns
SpecialEggConfig.SpawnIntervalMax = 300  -- 5 minutes max
SpecialEggConfig.Duration = 45           -- seconds before despawn

-- Announcement templates
SpecialEggConfig.SpawnAnnouncement = "A Special Egg appeared in %s! Hurry!"
SpecialEggConfig.ClaimAnnouncement = "%s claimed the Special Egg in %s!"

-- Visual
SpecialEggConfig.EggSize = Vector3.new(10, 12, 10)
SpecialEggConfig.GlowColor = Color3.fromRGB(255, 215, 0)
SpecialEggConfig.LightRange = 30
SpecialEggConfig.LightBrightness = 3
SpecialEggConfig.ParticleRate = 20

-- Premium pet pool (better odds than normal eggs)
SpecialEggConfig.PetPool = {
    { PetId = "sparkletail", Weight = 25 },      -- Epic
    { PetId = "glimmer_kitten", Weight = 20 },    -- Epic
    { PetId = "ember_fox", Weight = 18 },          -- Epic
    { PetId = "crystal_wolf", Weight = 15 },       -- Legendary
    { PetId = "frost_bunny", Weight = 15 },        -- Legendary
    { PetId = "shadow_panther", Weight = 12 },     -- Legendary
    { PetId = "nova_phoenix", Weight = 8 },        -- Mythic
    { PetId = "astral_unicorn", Weight = 6 },      -- Mythic
    { PetId = "void_dragon", Weight = 4 },         -- Mythic
    { PetId = "cosmicnova", Weight = 2 },          -- Secret!
}

-- Boosted variant chances (5x normal for special eggs)
SpecialEggConfig.GoldenChance = 0.05   -- 5% (normal is 1%)
SpecialEggConfig.RainbowChance = 0.005 -- 0.5% (normal is 0.1%)

return SpecialEggConfig
