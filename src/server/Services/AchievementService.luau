--[[
    AchievementService.luau
    Checks achievement conditions and grants rewards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local AchievementConfig = require(Shared:WaitForChild("Configs"):WaitForChild("AchievementConfig"))

local DataService
local CurrencyService

local AchievementService = {}

-- Check and grant achievements for a specific type
function AchievementService.CheckAchievements(player: Player, achievementType: string, currentValue: number)
    local data = DataService.GetData(player)
    if not data then return end

    if not data.Achievements then
        data.Achievements = {}
    end

    local achievements = AchievementConfig.GetAchievementsByType(achievementType)
    for _, achievement in ipairs(achievements) do
        if not data.Achievements[achievement.Id] and currentValue >= achievement.Goal then
            -- Grant achievement
            data.Achievements[achievement.Id] = true

            -- Grant reward
            if achievement.Reward then
                CurrencyService.Add(player, achievement.Reward.Currency, achievement.Reward.Amount)
            end

            -- Notify
            Network.FireClient("AchievementUnlocked", player, achievement.Id)
            Network.FireClient("ShowNotification", player,
                "Achievement: " .. achievement.Name .. "! +" .. achievement.Reward.Amount .. " " .. achievement.Reward.Currency,
                "Success"
            )
        end
    end
end

-- Convenience: check multiple types from player data
function AchievementService.CheckAllForPlayer(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    AchievementService.CheckAchievements(player, "HatchEggs", data.TotalEggsHatched or 0)
    AchievementService.CheckAchievements(player, "Rebirths", data.Rebirths or 0)
    AchievementService.CheckAchievements(player, "TotalCoinsEarned", data.TotalCoinsEarned or 0)
    AchievementService.CheckAchievements(player, "ZonesUnlocked", data.UnlockedZones and #data.UnlockedZones or 1)
    AchievementService.CheckAchievements(player, "LoginDays", data.LoginDays or 0)
    AchievementService.CheckAchievements(player, "TradesCompleted", data.TradesCompleted or 0)
    AchievementService.CheckAchievements(player, "PetsFused", data.PetsFused or 0)
    AchievementService.CheckAchievements(player, "SpecialEggsClaimed", data.SpecialEggsClaimed or 0)
    AchievementService.CheckAchievements(player, "SecretTokensFound", data.SecretTokensCount or 0)

    -- Secret zone unlocked check
    local secretZoneUnlocked = 0
    for _, z in ipairs(data.UnlockedZones or {}) do
        if z == "secret_garden" then secretZoneUnlocked = 1 break end
    end
    AchievementService.CheckAchievements(player, "SecretZoneUnlocked", secretZoneUnlocked)

    -- Unique pets
    if data.PetIndex then
        local count = 0
        for _ in pairs(data.PetIndex) do
            count = count + 1
        end
        AchievementService.CheckAchievements(player, "UniquePets", count)
    end

    -- Golden / Rainbow / Mythic / Secret pet counts
    -- Use O(1) counters maintained by PetService.AddPet/RemovePet instead of scanning all pets
    if data.Pets then
        AchievementService.CheckAchievements(player, "GoldenPets", data.GoldenCount or 0)
        AchievementService.CheckAchievements(player, "RainbowPets", data.RainbowCount or 0)
        AchievementService.CheckAchievements(player, "MythicPets", data.MythicCount or 0)
        AchievementService.CheckAchievements(player, "SecretPets", data.SecretCount or 0)
        -- BestPetPower requires a scan (hard to track decrementally)
        local PetConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("PetConfig"))
        local bestPower = 0
        for _, pet in ipairs(data.Pets) do
            local petInfo = PetConfig.GetPet(pet.PetId)
            if petInfo then
                local power = petInfo.Power
                if pet.Golden then power = power * 2.5 end
                if pet.Rainbow then power = power * 5.0 end
                if power > bestPower then bestPower = power end
            end
        end
        AchievementService.CheckAchievements(player, "BestPetPower", bestPower)
    end
end

function AchievementService.Init(dataService, currencyService)
    DataService = dataService
    CurrencyService = currencyService

    -- Check achievements periodically for all players
    task.spawn(function()
        while true do
            task.wait(30)
            for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
                task.spawn(function()
                    AchievementService.CheckAllForPlayer(player)
                end)
            end
        end
    end)
end

return AchievementService
