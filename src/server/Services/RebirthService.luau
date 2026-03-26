-- RebirthService.luau
-- Handles rebirth (prestige) progression.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService   = require(script.Parent.DataService)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

local Events = ReplicatedStorage.Shared.Remotes.Events

local RebirthService = {}

-- ─── Calculate rebirth cost ──────────────────────────────────────────────────

function RebirthService.getRebirthCost(rebirthCount: number): number
    return math.floor(
        EconomyConfig.BaseRebirthCost * (EconomyConfig.RebirthCostScale ^ rebirthCount)
    )
end

-- ─── Process rebirth ─────────────────────────────────────────────────────────

local function doRebirth(player: Player)
    local data = DataService.get(player)
    if not data then return end

    local cost = RebirthService.getRebirthCost(data.Rebirths)
    if data.Coins < cost then
        Events.PurchaseResult:FireClient(player, false,
            ("Need %d coins to rebirth (you have %d)."):format(cost, data.Coins))
        return
    end

    -- Consume coins
    data.Coins = data.Coins - cost

    -- Increment rebirth count
    data.Rebirths        = data.Rebirths        + 1
    data.Stats.totalRebirths = data.Stats.totalRebirths + 1

    -- Calculate new rebirth bonus
    -- Each rebirth adds +0.1 additive multiplier (so 10 rebirths = +1× bonus = 2× total base)
    data.RebirthBonus = data.Rebirths * 0.1

    -- Reset progression (keep pets, gems, gamepasses)
    data.Ores         = {}
    data.CurrentWorld = 1
    data.CurrentTool  = "wooden_pickaxe"
    data.OwnedTools   = { "wooden_pickaxe" }
    -- Keep UnlockedWorlds so they see their old worlds but reset current to 1
    data.UnlockedWorlds = { 1 }

    -- Notify client
    Events.CoinsUpdated:FireClient(player, data.Coins)
    Events.RebirthCompleted:FireClient(player, data.Rebirths, data.RebirthBonus)
end

-- ─── RemoteEvent handler ─────────────────────────────────────────────────────

Events.RequestRebirth.OnServerEvent:Connect(function(player: Player)
    doRebirth(player)
end)

return RebirthService
