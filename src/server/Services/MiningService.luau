-- MiningService.luau
-- Handles mining rock hits, ore drops, and auto-mine for gamepass holders.

local Players      = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService    = require(script.Parent.DataService)
local MiningConfig   = require(ReplicatedStorage.Shared.Config.MiningConfig)
local EconomyConfig  = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local WeightedRandom = require(ReplicatedStorage.Shared.Modules.WeightedRandom)
local MultiplierUtil = require(ReplicatedStorage.Shared.Modules.MultiplierUtil)

local Events = ReplicatedStorage.Shared.Remotes.Events

-- Build rock lookup by id
local rockById = {}
for _, rock in ipairs(MiningConfig.Rocks) do
    rockById[rock.id] = rock
end

-- Build tool lookup by id
local toolById = {}
for _, tool in ipairs(MiningConfig.Tools) do
    toolById[tool.id] = tool
end

-- Per-player mining cooldown tracker: [userId] = last swing timestamp
local lastSwing = {}

-- Per-player active rock HP: [userId][rockId] = currentHp
local rockHp = {}

local MiningService = {}

-- ─── Validate swing timing ────────────────────────────────────────────────────

local function canSwing(player: Player, data: {}): boolean
    local userId = player.UserId
    local now    = tick()
    local last   = lastSwing[userId] or 0

    local mults    = MultiplierUtil.calculate(data)
    local speedPct = mults.mineSpeedBoost   -- e.g. 0.25 = 25% faster
    local interval = MiningConfig.BaseMineInterval / (1 + speedPct)
    interval       = math.max(interval, MiningConfig.MinMineInterval)

    if now - last < interval - 0.05 then   -- 50 ms tolerance for latency
        return false
    end
    lastSwing[userId] = now
    return true
end

-- ─── Loot roll ────────────────────────────────────────────────────────────────

local function rollOre(rockDef: {}): string
    local entry = WeightedRandom.pick(rockDef.oreTable, 1)
    return entry.ore
end

-- ─── Process a mine hit ───────────────────────────────────────────────────────

local function processMineHit(player: Player, rockId: string)
    local data = DataService.get(player)
    if not data then return end

    -- Check the rock is in the player's current world
    local rockDef = rockById[rockId]
    if not rockDef then return end
    if rockDef.world ~= data.CurrentWorld then return end

    -- Timing check (anti-exploit)
    if not canSwing(player, data) then return end

    -- Get tool damage
    local toolDef = toolById[data.CurrentTool]
    local damage  = toolDef and toolDef.damage or 1

    -- Apply mine multiplier
    local mults = MultiplierUtil.calculate(data)
    damage = math.floor(damage * mults.mineMult)

    -- Damage the rock
    local userId = player.UserId
    if not rockHp[userId] then rockHp[userId] = {} end
    if rockHp[userId][rockId] == nil then
        rockHp[userId][rockId] = rockDef.hp
    end

    rockHp[userId][rockId] = rockHp[userId][rockId] - damage

    -- Reward ore on break
    if rockHp[userId][rockId] <= 0 then
        rockHp[userId][rockId] = rockDef.hp  -- respawn for this player

        local ore = rollOre(rockDef)
        data.Ores[ore] = (data.Ores[ore] or 0) + 1

        -- Update mining stats
        data.Stats.totalOresMined    = data.Stats.totalOresMined    + 1
        data.Stats.oresMinedToday    = data.Stats.oresMinedToday    + 1
        data.Stats.oresMinedWeekly   = data.Stats.oresMinedWeekly   + 1

        -- Notify client
        Events.OreAdded:FireClient(player, ore, 1)
        Events.RockBroken:FireClient(player, rockId, ore)
    end
end

-- ─── Sell all ores ────────────────────────────────────────────────────────────

local function sellOres(player: Player)
    local data = DataService.get(player)
    if not data then return end

    local totalCoins = 0
    local mults      = MultiplierUtil.calculate(data)

    for ore, count in pairs(data.Ores) do
        local baseValue = EconomyConfig.OreValues[ore] or 0
        totalCoins = totalCoins + math.floor(baseValue * count * mults.coinMult)
    end

    if totalCoins <= 0 then return end

    data.Ores = {}
    data.Coins = data.Coins + totalCoins
    data.Stats.totalCoinsEarned  = data.Stats.totalCoinsEarned  + totalCoins
    data.Stats.coinsEarnedToday  = data.Stats.coinsEarnedToday  + totalCoins

    Events.CoinsUpdated:FireClient(player, data.Coins)
end

-- ─── RemoteEvent handlers ─────────────────────────────────────────────────────

Events.MineRock.OnServerEvent:Connect(function(player: Player, rockId: string)
    if type(rockId) ~= "string" then return end
    processMineHit(player, rockId)
end)

Events.SellOres.OnServerEvent:Connect(function(player: Player)
    sellOres(player)
end)

-- ─── Auto-sell loop (for gamepass holders) ────────────────────────────────────

task.spawn(function()
    while true do
        task.wait(5)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataService.get(player)
            if data then
                local hasAutoSell = table.find(data.OwnedGamepasses, "auto_sell") ~= nil
                if hasAutoSell then
                    local hasOres = next(data.Ores) ~= nil
                    if hasOres then
                        sellOres(player)
                    end
                end
            end
        end
    end
end)

-- ─── Clean up on player leave ─────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player: Player)
    lastSwing[player.UserId] = nil
    rockHp[player.UserId]    = nil
end)

return MiningService
