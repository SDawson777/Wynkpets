--[[
    WheelService.luau
    Server-authoritative Lucky Wheel system.
    Flow:
      1) Validate request
      2) Roll reward on server
      3) Fire WheelSpinResult (animation payload)
      4) Grant reward on server
      5) Fire WheelRewardGranted (for popup timing)
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local WheelConfig = require(Shared:WaitForChild("Configs"):WaitForChild("WheelConfig"))
local DevProductConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DevProductConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService
local CurrencyService
local AntiExploitService
local BoostService
local PetService
local RewardService
local AnalyticsService
local EvolutionService

local WheelService = {
    _spinning = {},
    _pending = {},
    _lastRequest = {},
}

local REQUEST_COOLDOWN_SECONDS = 5

local function utcDayKey(): string
    return os.date("!%Y-%m-%d")
end

local function getNextUtcDayTimestamp(nowTs: number): number
    local epochDay = math.floor(nowTs / 86400)
    return (epochDay + 1) * 86400
end

local function rewardPublicData(reward)
    return {
        Id = reward.Id,
        DisplayName = reward.DisplayName,
        Type = reward.Type,
        Currency = reward.Currency,
        Amount = reward.Amount,
        BoostType = reward.BoostType,
        Duration = reward.Duration,
        Multiplier = reward.Multiplier,
        PetId = reward.PetId,
        Variant = reward.Variant,
        Icon = reward.Icon,
        Color = reward.Color,
    }
end

local function ensureWheelData(data)
    data.Wheel = data.Wheel or {
        LastFreeSpinDay = "",
        FreeSpinsUsedToday = 0,
        PaidSpinsAvailable = 0,
        TotalSpins = 0,
    }

    if type(data.Wheel.LastFreeSpinDay) ~= "string" then
        data.Wheel.LastFreeSpinDay = ""
    end
    data.Wheel.FreeSpinsUsedToday = math.max(0, tonumber(data.Wheel.FreeSpinsUsedToday) or 0)
    data.Wheel.PaidSpinsAvailable = math.max(0, tonumber(data.Wheel.PaidSpinsAvailable) or 0)
    data.Wheel.TotalSpins = math.max(0, tonumber(data.Wheel.TotalSpins) or 0)
end

local function maybeResetDaily(wheelData)
    local today = utcDayKey()
    if wheelData.LastFreeSpinDay ~= today then
        wheelData.LastFreeSpinDay = today
        wheelData.FreeSpinsUsedToday = 0
    end
end

local function chooseWeightedReward(randomObj: Random)
    local totalWeight = WheelConfig.GetTotalWeight()
    local roll = randomObj:NextNumber(0, totalWeight)
    local cumulative = 0

    for index, reward in ipairs(WheelConfig.Rewards) do
        local weight = reward.Weight or 0
        if weight > 0 then
            cumulative += weight
            if roll <= cumulative then
                return index, reward
            end
        end
    end

    local fallbackIndex = #WheelConfig.Rewards
    return fallbackIndex, WheelConfig.Rewards[fallbackIndex]
end

local function track(player: Player, eventName: string, payload)
    if AnalyticsService and AnalyticsService.LogEvent then
        AnalyticsService.LogEvent(player, eventName, payload)
    end
end

local function grantReward(player: Player, reward): (boolean, string?)
    if reward.Type == "Currency" then
        if reward.Currency == "Coins" or reward.Currency == "Gems" then
            CurrencyService.Add(player, reward.Currency, reward.Amount or 0, false)
            return true
        end

        if reward.Currency == "EvolutionShards" then
            if EvolutionService and EvolutionService.AwardMaterial then
                EvolutionService.AwardMaterial(player, "WynkShards", reward.Amount or 0)
                return true
            end
            return false, "EvolutionService unavailable"
        end

        if RewardService and RewardService.GrantCurrency then
            RewardService.GrantCurrency(player, reward.Currency, reward.Amount or 0)
            return true
        end

        return false, "Unsupported currency type"
    end

    if reward.Type == "Boost" then
        if not BoostService then
            return false, "BoostService unavailable"
        end
        BoostService.Activate(player, reward.BoostType, reward.Duration or 0)
        return true
    end

    if reward.Type == "Pet" then
        if not PetService then
            return false, "PetService unavailable"
        end

        local golden = reward.Variant == "Golden"
        local rainbow = reward.Variant == "Rainbow"
        local created = PetService.AddPet(player, reward.PetId, golden, rainbow)
        if not created then
            return false, "Pet grant failed"
        end
        return true
    end

    return false, "Unsupported reward type"
end

local function reject(player: Player, reason: string, nextFreeSpinAt: number?)
    local payload = { Reason = reason }
    if nextFreeSpinAt then
        payload.NextFreeSpinAt = nextFreeSpinAt
    end
    Network.FireClient("WheelSpinRejected", player, payload)
end

local function handlePurchaseWheelSpin(player: Player)
    local product = DevProductConfig.GetProduct(WheelConfig.PaidSpinProductKey)
    if not product then
        reject(player, "Wheel product is not configured.")
        Network.FireClient("ShowNotification", player, "Lucky Wheel purchase is not configured yet.", "Warning")
        return
    end

    if (product.ProductId or 0) <= 0 then
        reject(player, "Wheel product is not published yet.")
        Network.FireClient("ShowNotification", player, "Wheel spin product is not live yet.", "Warning")
        return
    end

    MarketplaceService:PromptProductPurchase(player, product.ProductId)
end

function WheelService.Init(dataService, currencyService, antiExploitService, boostService, petService, rewardService, analyticsService, evolutionService)
    DataService = dataService
    CurrencyService = currencyService
    AntiExploitService = antiExploitService
    BoostService = boostService
    PetService = petService
    RewardService = rewardService
    AnalyticsService = analyticsService
    EvolutionService = evolutionService

    local valid, err = WheelConfig.Validate()
    if not valid then
        error("[WheelService] Invalid WheelConfig: " .. tostring(err))
    end

    if not LaunchConfig.IsFeatureEnabled("Wheel") then
        print("[LaunchConfig] WheelService disabled - skipping handler registration")
        return
    end

    Network.OnServerEvent("PurchaseWheelSpin", function(player: Player)
        handlePurchaseWheelSpin(player)
    end)

    Network.OnServerEvent("RequestWheelSpin", function(player: Player, payload)
        if not AntiExploitService.CheckRateLimit(player, "ClaimWheelSpin") then
            return
        end

        if type(payload) ~= "table" then
            reject(player, "Invalid spin request.")
            return
        end

        local spinType = payload.SpinType
        if spinType ~= "Free" and spinType ~= "Paid" then
            reject(player, "Invalid spin type.")
            return
        end

        local now = os.time()
        local lastRequest = WheelService._lastRequest[player] or 0
        if now - lastRequest < REQUEST_COOLDOWN_SECONDS then
            reject(player, "Please wait before spinning again.")
            track(player, "WheelSpinRejected", {
                Reason = "RateLimit",
                SpinType = spinType,
                UserId = player.UserId,
            })
            return
        end
        WheelService._lastRequest[player] = now

        if WheelService._spinning[player] then
            reject(player, "A spin is already in progress.")
            return
        end

        local data = DataService.GetData(player)
        if not data then
            reject(player, "Data is still loading.")
            return
        end

        ensureWheelData(data)
        maybeResetDaily(data.Wheel)

        track(player, "WheelSpinRequested", {
            SpinType = spinType,
            UserId = player.UserId,
            PaidSpinsAvailable = data.Wheel.PaidSpinsAvailable,
            FreeSpinsUsedToday = data.Wheel.FreeSpinsUsedToday,
        })

        if spinType == "Free" then
            if data.Wheel.FreeSpinsUsedToday >= WheelConfig.DailyFreeSpins then
                reject(player, "Free spin used - come back tomorrow!", getNextUtcDayTimestamp(now))
                track(player, "WheelSpinRejected", {
                    Reason = "NoFreeSpins",
                    SpinType = spinType,
                    UserId = player.UserId,
                })
                return
            end
            data.Wheel.FreeSpinsUsedToday += 1
            data.Wheel.LastFreeSpinDay = utcDayKey()
        else
            if data.Wheel.PaidSpinsAvailable <= 0 then
                reject(player, "No paid spins available.")
                track(player, "WheelSpinRejected", {
                    Reason = "NoPaidSpins",
                    SpinType = spinType,
                    UserId = player.UserId,
                })
                return
            end
            data.Wheel.PaidSpinsAvailable -= 1
        end

        WheelService._spinning[player] = true

        local spinId = HttpService:GenerateGUID(false)
        local randomObj = Random.new()
        local rewardIndex, reward = chooseWeightedReward(randomObj)

        WheelService._pending[spinId] = {
            Player = player,
            Reward = reward,
            RewardIndex = rewardIndex,
            CreatedAt = now,
        }

        data.Wheel.TotalSpins += 1
        data.WheelSpins = (data.WheelSpins or 0) + 1

        local resultPayload = {
            SpinId = spinId,
            RewardIndex = rewardIndex,
            RewardId = reward.Id,
            Reward = rewardPublicData(reward),
            ServerTime = now,
            SpinDuration = WheelConfig.SpinDuration,
            FullSpins = WheelConfig.FullSpins,
            PointerAngle = WheelConfig.PointerAngle,
            SegmentCount = WheelConfig.SegmentCount,
        }

        Network.FireClient("WheelSpinResult", player, resultPayload)

        track(player, "WheelSpinGranted", {
            SpinId = spinId,
            SpinType = spinType,
            RewardId = reward.Id,
            RewardIndex = rewardIndex,
            UserId = player.UserId,
        })

        local success, grantErr = pcall(function()
            local granted, grantReason = grantReward(player, reward)
            if not granted then
                error(grantReason or "Grant failed")
            end
        end)

        if not success then
            reject(player, "Reward delivery failed. Please rejoin and contact support.")
            track(player, "WheelSpinRejected", {
                Reason = "GrantFailed",
                SpinType = spinType,
                RewardId = reward.Id,
                UserId = player.UserId,
                Error = tostring(grantErr),
            })
            WheelService._pending[spinId] = nil
            WheelService._spinning[player] = nil
            return
        end

        track(player, "WheelRewardGranted", {
            SpinId = spinId,
            SpinType = spinType,
            RewardId = reward.Id,
            RewardIndex = rewardIndex,
            UserId = player.UserId,
        })

        local grantedPayload = {
            SpinId = spinId,
            Reward = rewardPublicData(reward),
        }

        task.delay(WheelConfig.SpinDuration, function()
            if player.Parent then
                Network.FireClient("WheelRewardGranted", player, grantedPayload)
            end
            WheelService._pending[spinId] = nil
        end)

        Network.FireClient("DataUpdated", player, "Wheel", data.Wheel)
        WheelService._spinning[player] = nil

        if RewardService and RewardService.UpdateQuestProgress then
            RewardService.UpdateQuestProgress(player, "WheelSpins", 1)
        end
    end)

    task.spawn(function()
        while true do
            task.wait(120)
            local nowTs = os.time()
            for spinId, pending in pairs(WheelService._pending) do
                if nowTs - (pending.CreatedAt or nowTs) > 600 then
                    WheelService._pending[spinId] = nil
                end
            end
        end
    end)

    print("[WheelService] initialized")
end

function WheelService.PlayerRemoving(player: Player)
    WheelService._spinning[player] = nil
    WheelService._lastRequest[player] = nil

    for spinId, pending in pairs(WheelService._pending) do
        if pending.Player == player then
            WheelService._pending[spinId] = nil
        end
    end
end

return WheelService
