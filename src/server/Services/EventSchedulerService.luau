--[[
    EventSchedulerService.luau
    Drives the WynkPets weekly LiveOps calendar.

    Responsibilities
    ────────────────
    • Computes the current week-of-year → event type (via MonthlyRotation)
    • Tracks the current phase: "prep" (Mon–Thu) | "climax" (Fri–Sun)
    • Broadcasts EventPhaseChanged to all clients on every transition
    • Sends EventScheduleData to newly joined players
    • Provides multiplier helpers consumed by EggService and PetService

    This service is orthogonal to EventService, which handles random
    10-minute server-boost events (2× coins, luck, xp).
    Both can be active simultaneously.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EventCalendarConfig = require(Shared:WaitForChild("Configs"):WaitForChild("EventCalendarConfig"))

local EventSchedulerService = {}

-- ── State ──────────────────────────────────────────────────────────────────────
local currentPhase     = nil   -- "prep" | "climax"
local currentEventType = nil   -- e.g. "EvolutionWeekend"
local currentWeekIndex = nil   -- 0-based week-of-year

-- ── Internal helpers ───────────────────────────────────────────────────────────

-- 0-based week-of-year from a UTC epoch timestamp.
local function weekOfYear(t: number): number
    local d = os.date("!*t", t) :: any
    -- yday is 1-based; divide by 7 and floor for 0-based week number
    return math.floor((d.yday - 1) / 7)
end

-- 1-based week-of-month driven by CalendarStartEpoch anchor (exact rotation).
local function weekOfMonth(t: number): number
    return EventCalendarConfig.GetWeekOfMonthFromEpoch(t)
end

-- "prep" for Mon–Thu, "climax" for Fri–Sun (UTC weekday 0 = Sunday).
local function computePhase(t: number): string
    local wday = tonumber(os.date("!%w", t)) :: number
    return EventCalendarConfig.ClimaxWdays[wday] and "climax" or "prep"
end

-- Full state snapshot payload broadcast to clients.
local function buildPayload(t: number)
    local wi   = weekOfYear(t)
    local wom  = weekOfMonth(t)
    local etype = EventCalendarConfig.GetEventTypeForWeek(wom)
    local phase = computePhase(t)

    local window = nil
    if etype == "EvolutionWeekend" then
        window = EventCalendarConfig.GetEvolutionWindow(wi)
    elseif etype == "FeaturedEggWeek" then
        window = EventCalendarConfig.GetFeaturedEggWeek(wi)
    elseif etype == "ShinyAuraSurge" then
        window = EventCalendarConfig.GetShinyAuraSurge(wi)
    elseif etype == "WorldPulse" then
        window = EventCalendarConfig.GetWorldPulse(wi)
    end

    return {
        EventType  = etype,
        Phase      = phase,
        WeekIndex  = wi,
        WindowId   = window and window.Id   or nil,
        WindowName = window and window.Name or nil,
        WindowData = window,
        Timestamp  = t,
    }
end

-- ── Public API ─────────────────────────────────────────────────────────────────

function EventSchedulerService.GetCurrentPhase(): string
    return currentPhase or computePhase(os.time())
end

function EventSchedulerService.GetCurrentEventType(): string
    if currentEventType then return currentEventType end
    return EventCalendarConfig.GetEventTypeForWeek(weekOfMonth(os.time()))
end

function EventSchedulerService.GetCurrentWeekIndex(): number
    if currentWeekIndex ~= nil then return currentWeekIndex end
    return weekOfYear(os.time())
end

-- Returns the active window config table (EvolutionWindow, FeaturedEggWeek, etc.)
function EventSchedulerService.GetCurrentWindow()
    local etype = EventSchedulerService.GetCurrentEventType()
    local wi    = EventSchedulerService.GetCurrentWeekIndex()
    if etype == "EvolutionWeekend" then
        return EventCalendarConfig.GetEvolutionWindow(wi)
    elseif etype == "FeaturedEggWeek" then
        return EventCalendarConfig.GetFeaturedEggWeek(wi)
    elseif etype == "ShinyAuraSurge" then
        return EventCalendarConfig.GetShinyAuraSurge(wi)
    elseif etype == "WorldPulse" then
        return EventCalendarConfig.GetWorldPulse(wi)
    end
    return nil
end

-- Golden/Rainbow multipliers during ShinyAuraSurge climax (1.0 otherwise).
function EventSchedulerService.GetGoldenMultiplier(): number
    if EventSchedulerService.GetCurrentEventType() == "ShinyAuraSurge"
       and EventSchedulerService.GetCurrentPhase() == "climax" then
        local surge = EventSchedulerService.GetCurrentWindow()
        return surge and (surge.GoldenMultiplier or 1.0) or 1.0
    end
    return 1.0
end

function EventSchedulerService.GetRainbowMultiplier(): number
    if EventSchedulerService.GetCurrentEventType() == "ShinyAuraSurge"
       and EventSchedulerService.GetCurrentPhase() == "climax" then
        local surge = EventSchedulerService.GetCurrentWindow()
        return surge and (surge.RainbowMultiplier or 1.0) or 1.0
    end
    return 1.0
end

-- +luck bonus fraction for a specific egg during FeaturedEggWeek (0 otherwise).
function EventSchedulerService.GetFeaturedEggBonus(eggId: string): number
    if EventSchedulerService.GetCurrentEventType() == "FeaturedEggWeek" then
        local week = EventSchedulerService.GetCurrentWindow()
        if week and week.FeaturedEggId == eggId then
            return week.LuckBonus or 0
        end
    end
    return 0
end

-- Milestone reward table for the current FeaturedEggWeek (empty table otherwise).
function EventSchedulerService.GetFeaturedEggMilestones(): { any }
    if EventSchedulerService.GetCurrentEventType() ~= "FeaturedEggWeek" then return {} end
    local week = EventSchedulerService.GetCurrentWindow()
    return week and week.MilestoneRewards or {}
end

-- Whether an Evolution Weekend Climax is currently active.
function EventSchedulerService.IsEvolutionClimaxActive(): boolean
    return EventSchedulerService.GetCurrentEventType() == "EvolutionWeekend"
        and EventSchedulerService.GetCurrentPhase() == "climax"
end

function EventSchedulerService.PlayerAdded(player: Player)
    task.delay(1, function()
        if player and player.Parent then
            Network.FireClient("EventScheduleData", player, buildPayload(os.time()))
        end
    end)
end

function EventSchedulerService.Init()
    local now = os.time()
    currentPhase     = computePhase(now)
    currentEventType = EventCalendarConfig.GetEventTypeForWeek(weekOfMonth(now))
    currentWeekIndex = weekOfYear(now)

    print(string.format("[EventScheduler] Week %d | %s | %s",
        currentWeekIndex, currentEventType, currentPhase))

    -- Phase-transition watcher: polls every 10 minutes.
    -- A phase boundary typically moves once per 3–4 days; 10-min polling is cheap.
    task.spawn(function()
        while true do
            task.wait(600)
            local t     = os.time()
            local nPhase = computePhase(t)
            local nWeek  = weekOfYear(t)
            local nType  = EventCalendarConfig.GetEventTypeForWeek(weekOfMonth(t))

            if nPhase ~= currentPhase or nWeek ~= currentWeekIndex or nType ~= currentEventType then
                currentPhase     = nPhase
                currentWeekIndex = nWeek
                currentEventType = nType

                local payload = buildPayload(t)
                Network.FireAllClients("EventPhaseChanged", payload)

                local label = payload.WindowName or payload.EventType
                Network.FireAllClients("ShowNotification",
                    "🗓 " .. label .. " — " .. nPhase .. " phase begins!", "Info")

                print(string.format("[EventScheduler] Phase → Week %d | %s | %s",
                    nWeek, nType, nPhase))
            end
        end
    end)

    -- Client can request the current schedule at any point (e.g. on GUI open).
    Network.OnServerEvent("EventScheduleRequest", function(player)
        Network.FireClient("EventScheduleData", player, buildPayload(os.time()))
    end)
end

return EventSchedulerService
