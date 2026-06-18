--[[
    BoostService.luau
    Server-authoritative boost lifecycle manager.
    Responsibilities:
      • Tick active boosts; fire BoostExpired / BoostsUpdated when timers lapse.
      • Accept boost inventory charges (stored charges -> activate on demand).
      • Auto-refill prompt: when a boost has ≤5 min left, prompt the player once.
      • Expose IsActive / GetMultiplier for CurrencyService / EggService to query.
      • Serialize/deserialize cleanly to DataService.ActiveBoosts & BoostInventory.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local DataService
local AnalyticsService

local BoostService = {}

-- Boost type metadata (multiplier, icon colour for HUD)
local BOOST_META = {
    Coins      = { mult = 2.0, color = Color3.fromRGB(255, 215, 0),  label = "2× Coins"     },
    Luck       = { mult = 2.0, color = Color3.fromRGB(173, 255, 47), label = "2× Luck"      },
    XP         = { mult = 2.0, color = Color3.fromRGB(100, 149, 237),label = "2× XP"        },
    HatchSpeed = { mult = 2.0, color = Color3.fromRGB(255, 165, 0),  label = "2× Hatch Spd" },
}

-- How many seconds before expiry we prompt a refill
local REFILL_PROMPT_THRESHOLD = 300  -- 5 minutes: standard reminder
local URGENT_REFILL_THRESHOLD = 120  -- 2 minutes: urgent "Refill Now" push

-- Track which boosts we have already sent each tier of prompt this session
-- [Player] = { [boostType] = true }
local refillPrompted       = {} -- standard (5-min) prompt
local urgentRefillPrompted = {} -- urgent  (2-min) prompt

-- Tick interval for checking expiry
local TICK_INTERVAL = 10 -- seconds

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function getSnapshot(data)
    -- Returns { [boostType] = expiryTimestamp } only for ACTIVE boosts
    local now = os.time()
    local active = {}
    if data.ActiveBoosts then
        for boostType, expiry in pairs(data.ActiveBoosts) do
            if expiry > now then
                active[boostType] = expiry
            end
        end
    end
    return active
end

local function pushSnapshot(player, data)
    Network.FireClient("BoostsUpdated", player, getSnapshot(data))
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Check whether a boost type is currently active for a player
function BoostService.IsActive(player: Player, boostType: string): boolean
    local data = DataService.GetData(player)
    if not data or not data.ActiveBoosts then return false end
    local expiry = data.ActiveBoosts[boostType]
    return expiry and expiry > os.time()
end

-- Return the current multiplier for a boost type (1.0 if inactive)
function BoostService.GetMultiplier(player: Player, boostType: string): number
    if BoostService.IsActive(player, boostType) then
        local meta = BOOST_META[boostType]
        return meta and meta.mult or 2.0
    end
    return 1.0
end

-- Activate a boost (stack-extend if already running)
function BoostService.Activate(player: Player, boostType: string, duration: number)
    local data = DataService.GetData(player)
    if not data then return end

    if not data.ActiveBoosts then data.ActiveBoosts = {} end
    local now = os.time()
    local current = data.ActiveBoosts[boostType] or 0
    if current > now then
        data.ActiveBoosts[boostType] = current + duration -- stack-extend
    else
        data.ActiveBoosts[boostType] = now + duration
    end

    -- Reset refill prompts so they can fire again when this new activation expires
    if refillPrompted[player] then
        refillPrompted[player][boostType] = nil
    end
    if urgentRefillPrompted[player] then
        urgentRefillPrompted[player][boostType] = nil
    end

    if AnalyticsService then
        AnalyticsService.LogEvent(player, "BoostActivated", {
            BoostType = boostType,
            Duration = duration,
            Expiry = data.ActiveBoosts[boostType],
        })
    end

    Network.FireClient("BoostActivated", player, boostType, data.ActiveBoosts[boostType])
    pushSnapshot(player, data)
end

-- Activate ALL boost types at once (mega bundle)
function BoostService.ActivateAll(player: Player, duration: number)
    for boostType in pairs(BOOST_META) do
        BoostService.Activate(player, boostType, duration)
    end
end

-- Use one charge from inventory to activate a boost
function BoostService.UseCharge(player: Player, boostType: string, duration: number): boolean
    local data = DataService.GetData(player)
    if not data then return false end

    if not data.BoostInventory then data.BoostInventory = {} end
    local charges = data.BoostInventory[boostType] or 0
    if charges < 1 then return false end

    data.BoostInventory[boostType] = charges - 1
    BoostService.Activate(player, boostType, duration)
    return true
end

-- Add charges to inventory (purchased multi-pack stored charges)
function BoostService.AddCharges(player: Player, boostType: string, count: number)
    local data = DataService.GetData(player)
    if not data then return end

    if not data.BoostInventory then data.BoostInventory = {} end
    data.BoostInventory[boostType] = (data.BoostInventory[boostType] or 0) + count

    Network.FireClient("DataUpdated", player, "BoostInventory", data.BoostInventory)
end

-- Send the current boost snapshot to a newly-joined player
function BoostService.PlayerAdded(player: Player)
    refillPrompted[player]       = {}
    urgentRefillPrompted[player] = {}

    -- Wait for data to load
    task.delay(2, function()
        if not player or not player.Parent then return end
        local data = DataService.GetData(player)
        if data then
            pushSnapshot(player, data)
        end
    end)
end

function BoostService.PlayerRemoving(player: Player)
    refillPrompted[player]       = nil
    urgentRefillPrompted[player] = nil
end

-- ── Tick Loop ─────────────────────────────────────────────────────────────────

local function tick()
    local now = os.time()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = DataService.GetData(player)
        if not data or not data.ActiveBoosts then continue end

        if not refillPrompted[player] then
            refillPrompted[player] = {}
        end

        local anyExpired = false
        for boostType, expiry in pairs(data.ActiveBoosts) do
            if expiry <= now then
                -- Boost just expired
                data.ActiveBoosts[boostType] = nil
                Network.FireClient("BoostExpired", player, boostType)
                anyExpired = true

                if AnalyticsService then
                    AnalyticsService.LogEvent(player, "BoostExpired", { BoostType = boostType })
                end
            elseif expiry - now <= URGENT_REFILL_THRESHOLD
                and not urgentRefillPrompted[player][boostType] then
                -- Urgent: 2 min left — fire with urgent=true flag
                urgentRefillPrompted[player][boostType] = true
                Network.FireClient("BoostRefillPrompt", player, boostType, expiry, true)
            elseif expiry - now <= REFILL_PROMPT_THRESHOLD
                and not refillPrompted[player][boostType] then
                -- Standard: 5 min left — fire normal reminder
                refillPrompted[player][boostType] = true
                Network.FireClient("BoostRefillPrompt", player, boostType, expiry, false)
            end
        end

        if anyExpired then
            pushSnapshot(player, data)
        end
    end
end

-- ── Remotes ───────────────────────────────────────────────────────────────────

local function setupRemotes()
    -- Client asks to activate a stored charge
    Network.OnServerEvent("PurchaseBoostRefill", function(player: Player, boostType: string)
        if type(boostType) ~= "string" then return end
        if not BOOST_META[boostType] then return end

        -- UseCharge from inventory; if no charge available, tell the client
        local used = BoostService.UseCharge(player, boostType, 1800)
        if not used then
            Network.FireClient("ShowNotification", player,
                "No " .. boostType .. " charges left! Buy more in the Shop.", "Warning")
        end
    end)
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function BoostService.Init(dataService, analyticsService)
    DataService = dataService
    AnalyticsService = analyticsService

    setupRemotes()

    -- Start tick loop
    task.spawn(function()
        while true do
            task.wait(TICK_INTERVAL)
            local ok, err = pcall(tick)
            if not ok then
                warn("[BoostService] Tick error: " .. tostring(err))
            end
        end
    end)

    -- Wire existing players (hot-reload safety)
    for _, player in ipairs(Players:GetPlayers()) do
        BoostService.PlayerAdded(player)
    end
end

return BoostService
