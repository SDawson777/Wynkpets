--[[
    MonetizationPromptService.luau
    Debounced, server-authoritative gamepass purchase prompts.

    Responsibilities:
        • Prevent double-prompt spam (30-second player+pass debounce)
        • Skip prompt if player already owns the pass (EntitlementService check)
        • Expose Prompt(player, passId) for internal upsell callers
        • Handle "PromptPassPurchase" client → server remote securely

    Security notes:
        • All prompts are initiated server-side via MarketplaceService:PromptGamePassPurchase
        • Clients can only REQUEST a prompt, never claim ownership themselves
        • Ownership confirmation flows through GamepassService.PromptGamePassPurchaseFinished
          which calls EntitlementService.GavePass — clients have no authority
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Network = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Network"))
local GamepassConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("GamepassConfig"))

local MonetizationPromptService = {}

-- Late-bound from init.server.luau
local EntitlementService = nil

-- Debounce: _lastPrompt[player][passId] = tick()
local _lastPrompt: { [Player]: { [string]: number } } = {}
local DEBOUNCE_SECONDS = 30

-- Global trigger debounce: automated triggers share a single 5-minute gate per
-- player so the game never fires multiple monetization prompts back-to-back.
local _lastTrigger: { [Player]: number } = {}
local TRIGGER_DEBOUNCE = 300 -- 5 minutes

-- ── Internal helper ──────────────────────────────────────────────────────────

local function canPrompt(player: Player, passId: string): boolean
    local playerMap = _lastPrompt[player]
    if not playerMap then return true end
    local last = playerMap[passId]
    if not last then return true end
    return (tick() - last) >= DEBOUNCE_SECONDS
end

local function recordPrompt(player: Player, passId: string)
    if not _lastPrompt[player] then
        _lastPrompt[player] = {}
    end
    _lastPrompt[player][passId] = tick()
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- Prompt a player to purchase a gamepass.
--- Silently skips if: already owned, debounce active, or passId unknown.
function MonetizationPromptService.Prompt(player: Player, passId: string)
    -- Validate pass exists
    local gp = GamepassConfig.GetGamepass(passId)
    if not gp or not gp.GamepassId or gp.GamepassId <= 0 then return end

    -- Skip if already owned
    if EntitlementService and EntitlementService.HasPass(player, passId) then return end

    -- Debounce
    if not canPrompt(player, passId) then return end

    recordPrompt(player, passId)

    -- Issue prompt server-side (client receives native Roblox purchase dialog)
    local ok, err = pcall(function()
        MarketplaceService:PromptGamePassPurchase(player, gp.GamepassId)
    end)
    if not ok then
        warn("[MonetizationPromptService] PromptGamePassPurchase failed for", passId, ":", err)
    end
end

--- Automated trigger variant of Prompt() with a stricter 5-minute global
--- per-player debounce so contextual upsells never spam the player.
--- All three game-state triggers (coin shortage, bad streak, speed) call this.
function MonetizationPromptService.TriggerPrompt(player: Player, passId: string)
    -- Global gate: one automated prompt per player per 5 minutes
    local lastTrig = _lastTrigger[player]
    if lastTrig and (tick() - lastTrig) < TRIGGER_DEBOUNCE then return end
    _lastTrigger[player] = tick()
    MonetizationPromptService.Prompt(player, passId)
end

--- Wire network event: client requests a prompt (e.g., "Buy" button in ShopGui).
--- Client cannot grant ownership — it can only trigger the native prompt.
function MonetizationPromptService.Init()
    Network.OnServerEvent("PromptPassPurchase", function(player: Player, passId: string)
        -- Sanitise input type
        if type(passId) ~= "string" then return end
        MonetizationPromptService.Prompt(player, passId)
    end)
end

--- Late-bind
function MonetizationPromptService.SetEntitlementService(svc)
    EntitlementService = svc
end

--- Lifecycle cleanup
function MonetizationPromptService.PlayerRemoving(player: Player)
    _lastPrompt[player] = nil
    _lastTrigger[player] = nil
end

return MonetizationPromptService
