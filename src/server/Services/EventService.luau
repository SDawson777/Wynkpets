--[[
    EventService.luau
    Server-wide timed events (2x coins, 2x luck, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService

local EventService = {}

-- Active server event state
local activeEvent = nil -- { Type, Multiplier, EndTime, Name }

local EVENT_TYPES = {
    {
        Type = "Coins2x",
        Name = "2x Coins!",
        Multiplier = 2.0,
        Duration = 600, -- 10 minutes
        Description = "All coins earned are doubled!",
    },
    {
        Type = "Luck2x",
        Name = "2x Luck!",
        Multiplier = 2.0,
        Duration = 600,
        Description = "Double chance for rare pets!",
    },
    {
        Type = "XP2x",
        Name = "2x XP!",
        Multiplier = 2.0,
        Duration = 600,
        Description = "Pets gain double XP!",
    },
}

function EventService.GetActiveEvent()
    if activeEvent and os.time() < activeEvent.EndTime then
        return activeEvent
    end
    activeEvent = nil
    return nil
end

function EventService.IsEventActive(eventType: string): boolean
    local event = EventService.GetActiveEvent()
    return event ~= nil and event.Type == eventType
end

function EventService.GetEventMultiplier(eventType: string): number
    local event = EventService.GetActiveEvent()
    if event and event.Type == eventType then
        return event.Multiplier
    end
    return 1.0
end

function EventService.StartEvent(eventType: string, durationOverride: number?)
    local config = nil
    for _, e in ipairs(EVENT_TYPES) do
        if e.Type == eventType then
            config = e
            break
        end
    end
    if not config then return end

    local duration = durationOverride or config.Duration
    activeEvent = {
        Type = config.Type,
        Name = config.Name,
        Multiplier = config.Multiplier,
        EndTime = os.time() + duration,
        Description = config.Description,
    }

    -- Notify all players
    Network.FireAllClients("ServerEvent", {
        Type = activeEvent.Type,
        Name = activeEvent.Name,
        EndTime = activeEvent.EndTime,
        Description = activeEvent.Description,
    })

    Network.FireAllClients("ShowNotification",
        "SERVER EVENT: " .. config.Name .. " (" .. math.floor(duration / 60) .. " min)", "Success")

    -- Schedule end notification
    task.delay(duration, function()
        if activeEvent and activeEvent.Type == config.Type then
            activeEvent = nil
            Network.FireAllClients("ServerEventEnded", config.Type)
            Network.FireAllClients("ShowNotification", config.Name .. " has ended!", "Info")
        end
    end)
end

function EventService.Init(dataService)
    DataService = dataService

    if not LaunchConfig.IsFeatureEnabled("Events") then
        print("[LaunchConfig] EventService disabled — skipping auto-trigger loop")
        return
    end

    -- Random event trigger based on player count
    task.spawn(function()
        while true do
            task.wait(900) -- Check every 15 minutes
            if not EventService.GetActiveEvent() then
                local playerCount = #Players:GetPlayers()
                -- Higher chance with more players (5% base + 2% per player, max 25%)
                local chance = math.min(0.05 + playerCount * 0.02, 0.25)
                if math.random() < chance then
                    local randomEvent = EVENT_TYPES[math.random(1, #EVENT_TYPES)]
                    EventService.StartEvent(randomEvent.Type)
                end
            end
        end
    end)

    -- Admin trigger
    Network.OnServerEvent("AdminCommand", function(player, command, ...)
        local data = DataService.GetData(player)
        if not data or not data.IsAdmin then return end

        if command == "StartEvent" then
            local eventType = ...
            if type(eventType) == "string" then
                EventService.StartEvent(eventType)
            end
        end
    end)

    -- Send active event to new players
    Network.OnServerEvent("RequestActiveEvent", function(player)
        local event = EventService.GetActiveEvent()
        if event then
            Network.FireClient("ServerEvent", player, {
                Type = event.Type,
                Name = event.Name,
                EndTime = event.EndTime,
                Description = event.Description,
            })
        end
    end)
end

return EventService
