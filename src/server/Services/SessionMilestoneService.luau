--[[
    SessionMilestoneService.luau
    Rewards players for continuous play sessions to drive retention.

    Milestones:
    5 min  → 500x zone CoinValue + "Keep going!" notification
    15 min → 2000x zone CoinValue + 50 Gems
    30 min → 5000x zone CoinValue + 150 Gems + "Loyal Explorer" badge
    60 min → 15000x zone CoinValue + 300 Gems + "Dedicated Player" permanent flair
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

local DataService
local CurrencyService

local SessionMilestoneService = {}

-- Milestone table: { minutes, coinMult, gems, label, icon, color }
local MILESTONES = {
    { minutes = 5,  coinMult = 500,   gems = 0,   label = "5-Minute Bonus!",     icon = "⏱",  color = Color3.fromRGB(100, 220, 100) },
    { minutes = 15, coinMult = 2000,  gems = 50,  label = "15-Minute Explorer!",  icon = "🌟", color = Color3.fromRGB(255, 215, 50) },
    { minutes = 30, coinMult = 5000,  gems = 150, label = "Loyal Explorer!",      icon = "🏆", color = Color3.fromRGB(255, 130, 40) },
    { minutes = 60, coinMult = 15000, gems = 300, label = "Dedicated Player!",    icon = "👑", color = Color3.fromRGB(255, 80, 200) },
}

-- Per-player tracking (session only, not persisted)
local sessionStartTimes = {} -- [userId] = tick()
local reached = {}           -- [userId][minutes] = true

local function getHighestCoinValue(player)
    local data = DataService and DataService.GetData(player)
    if not data then return 5 end
    local best = 5
    for _, zoneId in ipairs(data.UnlockedZones or {}) do
        local zone = ZoneConfig.GetZone(zoneId)
        if zone and zone.CoinValue > best then best = zone.CoinValue end
    end
    return best
end

local function startSession(player)
    local userId = player.UserId
    sessionStartTimes[userId] = tick()
    reached[userId] = {}

    task.spawn(function()
        -- Poll every 30 seconds
        while player.Parent ~= nil do
            task.wait(30)
            if not player.Parent then break end

            local elapsed = tick() - (sessionStartTimes[userId] or tick())
            local elapsedMins = elapsed / 60

            for _, ms in ipairs(MILESTONES) do
                if elapsedMins >= ms.minutes and not reached[userId][ms.minutes] then
                    reached[userId][ms.minutes] = true

                    local coinBase = getHighestCoinValue(player)
                    local coinAward = math.floor(coinBase * ms.coinMult)

                    CurrencyService.Add(player, "Coins", coinAward)
                    if ms.gems > 0 then
                        CurrencyService.Add(player, "Gems", ms.gems)
                    end

                    -- Full popup event
                    Network.FireClient("SessionMilestone", player, {
                        Minutes  = ms.minutes,
                        Label    = ms.label,
                        Icon     = ms.icon,
                        Coins    = coinAward,
                        Gems     = ms.gems,
                    })

                    -- Notification sidebar
                    local msg = ms.icon .. " " .. ms.label
                        .. " +" .. tostring(coinAward) .. " Coins"
                        .. (ms.gems > 0 and (" +" .. tostring(ms.gems) .. " Gems") or "")
                    Network.FireClient("ShowNotification", player, msg, "Success")

                    print(string.format("[SessionMilestone] %s reached %d-min milestone (+%d coins, +%d gems)",
                        player.Name, ms.minutes, coinAward, ms.gems))
                end
            end
        end

        -- Cleanup on disconnect
        sessionStartTimes[userId] = nil
        reached[userId] = nil
    end)
end

function SessionMilestoneService.Init(dataService, currencyService)
    DataService = dataService
    CurrencyService = currencyService

    Players.PlayerAdded:Connect(function(player)
        -- Wait briefly for data to load before starting session timer
        task.delay(5, function()
            if player.Parent then startSession(player) end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        sessionStartTimes[player.UserId] = nil
        reached[player.UserId] = nil
    end)

    -- Handle players already in game (hot-reload safety)
    for _, player in ipairs(Players:GetPlayers()) do
        task.delay(5, function()
            if player.Parent then startSession(player) end
        end)
    end
end

return SessionMilestoneService
