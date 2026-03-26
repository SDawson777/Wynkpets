-- EventService.luau
-- Manages limited-time events (event tokens, event eggs).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local EventService = {}

-- ─── Active event state ───────────────────────────────────────────────────────
-- In production this would be driven by a remote config or DataStore flag.
-- For MVP, an admin can toggle isActive and update the server via AdminCommand.

EventService.ActiveEvent = {
    isActive    = false,
    name        = "Crystal Festival",
    description = "Mine crystals to earn Event Tokens and hatch the Event Egg!",
    tokenOreId  = "Crystal",   -- ore that drops event tokens
    tokenRate   = 0.1,         -- 10% chance per crystal mined to drop a token
    eggId       = "event_egg",
    endsAt      = 0,           -- Unix timestamp; 0 = no expiry (manual toggle)
}

-- ─── Grant token on mining (called by MiningService indirectly via hook) ──────

function EventService.onOreMined(player: Player, ore: string)
    if not EventService.ActiveEvent.isActive then return end
    local event = EventService.ActiveEvent
    if ore ~= event.tokenOreId then return end
    if math.random() > event.tokenRate then return end

    local data = DataService.get(player)
    if not data then return end

    data.Ores["EventTokens"] = (data.Ores["EventTokens"] or 0) + 1
end

-- ─── Admin command handler ────────────────────────────────────────────────────

local ADMIN_USER_IDS = {}  -- populate with developer UserIds

local Events = ReplicatedStorage.Shared.Remotes.Events

Events.AdminCommand.OnServerEvent:Connect(function(player: Player, command: string, arg)
    if not table.find(ADMIN_USER_IDS, player.UserId) then return end

    if command == "toggleEvent" then
        EventService.ActiveEvent.isActive = not EventService.ActiveEvent.isActive
        print(("[EventService] Event toggled to: %s"):format(tostring(EventService.ActiveEvent.isActive)))
    elseif command == "grantCoins" and type(arg) == "number" then
        local data = DataService.get(player)
        if data then
            data.Coins = data.Coins + arg
            Events.CoinsUpdated:FireClient(player, data.Coins)
        end
    elseif command == "grantGems" and type(arg) == "number" then
        local data = DataService.get(player)
        if data then
            data.Gems = data.Gems + arg
            Events.GemsUpdated:FireClient(player, data.Gems)
        end
    end
end)

return EventService
