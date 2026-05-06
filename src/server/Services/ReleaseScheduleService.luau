--[[
    ReleaseScheduleService.luau
    Reads ReleaseScheduleConfig and automatically enables LaunchConfig flags
    once their UTC timestamp has been reached.

    IMPORTANT: Init() must be called FIRST in init.server.luau, before all
    other services, so every downstream service initializes against the
    already-updated LaunchConfig.

    Behaviour:
      • Applies the schedule immediately on Init() (server startup).
      • Re-checks every 60 seconds — handles servers running past midnight.
      • Fires "LaunchFeaturesSnapshot" to every connected player whenever a
        flag changes, and to each new player as they join.
      • Never downgrades a phase (soft_launch → beta is rejected).
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared            = ReplicatedStorage:WaitForChild("Shared")

local LaunchConfig           = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))
local ReleaseScheduleConfig  = require(Shared:WaitForChild("Configs"):WaitForChild("ReleaseScheduleConfig"))
local Network                = require(Shared:WaitForChild("Network"))

local ReleaseScheduleService = {}

-- Only upgrade, never downgrade a phase.
local PHASE_ORDER = { beta = 1, soft_launch = 2, full_launch = 3 }

local function buildSnapshot()
    return {
        Phase        = LaunchConfig.Phase,
        Features     = LaunchConfig.Features,
        Monetization = LaunchConfig.Monetization,
    }
end

local function applySchedule()
    local now     = os.time()
    local changed = false

    -- Build hold sets for O(1) lookup
    local heldFeatures     = {}
    local heldMonetization = {}
    for _, k in ipairs(ReleaseScheduleConfig.HeldFeatures     or {}) do heldFeatures[k]     = true end
    for _, k in ipairs(ReleaseScheduleConfig.HeldMonetization or {}) do heldMonetization[k] = true end

    for _, entry in ipairs(ReleaseScheduleConfig.Schedule) do
        if now >= entry.UnlockAt then

            if entry.Feature then
                if heldFeatures[entry.Feature] then
                    -- Skip: operator has placed this feature on hold
                else
                if LaunchConfig.Features[entry.Feature] == false then
                    LaunchConfig.Features[entry.Feature] = true
                    print(string.format("[ReleaseScheduleService] ✅ Feature enabled: %s — %s",
                        entry.Feature, entry.Comment or ""))
                    changed = true
                end
                end  -- hold check

            elseif entry.Monetization then
                if heldMonetization[entry.Monetization] then
                    -- Skip: on hold
                else
                if LaunchConfig.Monetization[entry.Monetization] == false then
                    LaunchConfig.Monetization[entry.Monetization] = true
                    print(string.format("[ReleaseScheduleService] ✅ Monetization enabled: %s — %s",
                        entry.Monetization, entry.Comment or ""))
                    changed = true
                end
                end

            elseif entry.Phase then
                local currentOrder = PHASE_ORDER[LaunchConfig.Phase] or 0
                local newOrder     = PHASE_ORDER[entry.Phase] or 0
                if newOrder > currentOrder then
                    LaunchConfig.Phase = entry.Phase
                    print(string.format("[ReleaseScheduleService] 🚀 Phase → %s — %s",
                        entry.Phase, entry.Comment or ""))
                    changed = true
                end
            end
        end
    end

    -- Broadcast updated feature snapshot to all connected players
    if changed then
        local snapshot = buildSnapshot()
        for _, player in ipairs(Players:GetPlayers()) do
            Network.FireClient("LaunchFeaturesSnapshot", player, snapshot)
        end
    end

    return changed
end

function ReleaseScheduleService.Init()
    -- Apply immediately so all services that init after this see the updated config.
    local changed = applySchedule()
    if not changed then
        print("[ReleaseScheduleService] No new features unlocked at startup.")
    end

    -- Re-check every 60 seconds for long-running servers spanning date boundaries.
    task.spawn(function()
        while true do
            task.wait(60)
            applySchedule()
        end
    end)

    -- Send the current snapshot to each player as they join.
    Players.PlayerAdded:Connect(function(player)
        task.wait(2) -- brief delay so the client Network module is fully ready
        Network.FireClient("LaunchFeaturesSnapshot", player, buildSnapshot())
    end)

    print(string.format("[ReleaseScheduleService] Initialized — phase: %s", LaunchConfig.Phase))
end

return ReleaseScheduleService
