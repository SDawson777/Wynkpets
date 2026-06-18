--[[
    SessionBonusService.luau
    Rewards players for sustained play sessions.
    Fires SessionMilestone event at 5 / 15 / 30 / 60 / 120 minute marks.
    Retention loop: the longer you stay, the bigger the reward.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local DataService
local CurrencyService

local SessionBonusService = {}

-- Milestone definitions: { seconds, coinReward, gemReward, message }
local MILESTONES = {
    { seconds = 300,   coins = 0,      gems = 5,   label = "5 min",   msg = "5 min session! ⭐ +5 Gems!" },
    { seconds = 900,   coins = 0,      gems = 15,  label = "15 min",  msg = "15 min session! ⭐ +15 Gems!" },
    { seconds = 1800,  coins = 0,      gems = 30,  label = "30 min",  msg = "30 min legend! ⭐ +30 Gems!" },
    { seconds = 3600,  coins = 0,      gems = 75,  label = "60 min",  msg = "1 HOUR! 🔥 +75 Gems!" },
    { seconds = 7200,  coins = 0,      gems = 200, label = "2 hours", msg = "2 HOURS! 🏆 +200 Gems!" },
}

-- Per-player state
local sessionStart = {}   -- [userId] = tick() of join time
local nextMilestone = {}  -- [userId] = index into MILESTONES (next unclaimed)

-- Award a milestone to a player
local function grantMilestone(player, milestone)
    local uid = player.UserId

    if milestone.coins > 0 then
        CurrencyService.Add(player, "Coins", milestone.coins)
    end
    if milestone.gems > 0 then
        CurrencyService.Add(player, "Gems", milestone.gems)
    end

    -- Tell client to show the popup
    Network.FireClient("SessionMilestone", player, {
        Label   = milestone.label,
        Coins   = milestone.coins,
        Gems    = milestone.gems,
        Message = milestone.msg,
    })

    -- Also show a standard notification
    Network.FireClient("ShowNotification", player, milestone.msg, "Success")

    nextMilestone[uid] = (nextMilestone[uid] or 1) + 1
end

-- Main tick loop (runs every 10 seconds to keep it cheap)
local function startMilestoneLoop()
    task.spawn(function()
        while true do
            task.wait(10)
            local now = tick()
            for _, player in ipairs(Players:GetPlayers()) do
                local uid = player.UserId
                local start = sessionStart[uid]
                if not start then continue end
                local elapsed = now - start
                local idx = nextMilestone[uid] or 1
                local milestone = MILESTONES[idx]
                if milestone and elapsed >= milestone.seconds then
                    grantMilestone(player, milestone)
                end
            end
        end
    end)
end

function SessionBonusService.PlayerAdded(player)
    local uid = player.UserId
    sessionStart[uid] = tick()
    nextMilestone[uid] = 1
end

function SessionBonusService.PlayerRemoving(player)
    local uid = player.UserId
    sessionStart[uid] = nil
    nextMilestone[uid] = nil
end

function SessionBonusService.Init(dataService, currencyService)
    DataService = dataService
    CurrencyService = currencyService
    startMilestoneLoop()
    print("[SessionBonusService] Loaded")
end

return SessionBonusService
