--[[
    CurrencyService.luau
    Handles all currency operations (Coins, Gems).
    Server-authoritative: validates all transactions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))

local DataService -- Forward declaration, set in Init
local RewardService
local AntiExploitService

-- UpsellTrigger rate-limiting: at most one shortage UI push per 3 minutes per player
-- to avoid spamming new players with purchase prompts in their first session.
local _upsellCooldown: { [Player]: number } = {}
local UPSELL_COOLDOWN = 180  -- 3 minutes
local PetLevelService
local EventService
local DailyRotationService
local NudgeService -- set via SetNudgeService (late-bind)
local EntitlementService -- set via SetEntitlementService (late-bind)

local CurrencyService = {}

local VALID_CURRENCIES = { Coins = true, Gems = true }

-- Get a player's balance
function CurrencyService.GetBalance(player: Player, currency: string): number
    local data = DataService.GetData(player)
    if not data or not VALID_CURRENCIES[currency] then
        return 0
    end
    return data[currency] or 0
end

-- Add currency (applies multipliers from gamepasses, VIP, boosts, rebirth)
function CurrencyService.Add(player: Player, currency: string, baseAmount: number, applyMultipliers: boolean?): number
    local data = DataService.GetData(player)
    if not data or not VALID_CURRENCIES[currency] then
        return 0
    end
    if baseAmount <= 0 then
        return 0
    end

    local amount = baseAmount

    if applyMultipliers ~= false then
        amount = CurrencyService.ApplyMultipliers(player, currency, amount)
    end

    data[currency] = (data[currency] or 0) + math.floor(amount)

    -- Track total coins earned
    if currency == "Coins" then
        data.TotalCoinsEarned = (data.TotalCoinsEarned or 0) + math.floor(amount)
    end

    -- Notify client
    Network.FireClient("CurrencyUpdated", player, currency, data[currency])

    return math.floor(amount)
end

-- Remove currency (returns true if successful, false if insufficient)
function CurrencyService.Remove(player: Player, currency: string, amount: number): boolean
    local data = DataService.GetData(player)
    if not data or not VALID_CURRENCIES[currency] then
        return false
    end
    if amount <= 0 then
        return false
    end

    local current = data[currency] or 0
    if current < amount then
        return false -- Insufficient funds
    end

    data[currency] = current - amount
    Network.FireClient("CurrencyUpdated", player, currency, data[currency])

    -- Economy pressure: soft shortage detection
    -- If the remaining balance is less than the cost they just paid (can't afford another),
    -- but they still have some currency left, nudge them toward the shop.
    local remaining = data[currency]
    if remaining > 0 and remaining < amount and NudgeService then
        local now = tick()
        local lastUpsell = _upsellCooldown[player]
        if not lastUpsell or (now - lastUpsell) >= UPSELL_COOLDOWN then
            _upsellCooldown[player] = now
            NudgeService.Trigger(player, "near_cost")
            Network.FireClient("SoftShortage", player, {
                Currency = currency,
                Balance  = remaining,
                Shortfall = amount - remaining,
            })
            -- Contextual upsell: once per 3 minutes so new players aren't spammed
            if currency == "Coins" and EntitlementService and not EntitlementService.HasPass(player, "DoubleCoins") then
                Network.FireClient("UpsellTrigger", player, "DoubleCoins")
            end
        end
    end

    return true
end

-- Check if player can afford
function CurrencyService.CanAfford(player: Player, currency: string, amount: number): boolean
    return CurrencyService.GetBalance(player, currency) >= amount
end

-- Apply all active multipliers to an amount
function CurrencyService.ApplyMultipliers(player: Player, currency: string, amount: number): number
    local data = DataService.GetData(player)
    if not data then
        return amount
    end

    local multiplier = 1.0

    -- Rebirth multiplier
    multiplier = multiplier * (data.RebirthMultiplier or 1.0)

    -- Gamepass multipliers (EntitlementService is the authority; fall back to data cache if not yet wired)
    if currency == "Coins" then
        if EntitlementService then
            multiplier = multiplier * EntitlementService.GetCoinMultiplier(player)
        elseif data.Gamepasses and data.Gamepasses["DoubleCoins"] then
            multiplier = multiplier * 2.0
        end
    end

    -- Active boosts (wheel boost)
    if data.ActiveBoosts then
        local now = os.time()
        if currency == "Coins" and data.ActiveBoosts["Coins"] and data.ActiveBoosts["Coins"] > now then
            multiplier = multiplier * 2.0
        end
    end

    -- Wheel luck boost (BoostExpiry)
    if data.BoostExpiry and data.BoostExpiry > os.time() then
        multiplier = multiplier * 1.5
    end

    -- Server event multiplier (2x Coins event, 2x Gems event)
    if EventService then
        if currency == "Coins" then
            multiplier = multiplier * EventService.GetEventMultiplier("Coins2x")
        end
    end

    -- Daily rotation theme boost
    if DailyRotationService then
        local theme = DailyRotationService.GetDailyTheme()
        if theme and theme.BoostType == "Coins" and currency == "Coins" then
            multiplier = multiplier * theme.BoostMultiplier
        elseif theme and theme.BoostType == "Gems" and currency == "Gems" then
            multiplier = multiplier * theme.BoostMultiplier
        end
    end

    -- Pet power multiplier (sum of equipped pet powers)
    local petPower = CurrencyService.GetEquippedPetPower(player)
    if petPower > 0 then
        multiplier = multiplier * (1 + petPower / 100)
    end

    -- Hard cap to prevent runaway inflation (Rebirth25 × DoubleCoins × boost headroom)
    local COIN_MULTIPLIER_CAP = 1500
    multiplier = math.min(multiplier, COIN_MULTIPLIER_CAP)

    return amount * multiplier
end

-- Get total power of equipped pets
function CurrencyService.GetEquippedPetPower(player: Player): number
    local data = DataService.GetData(player)
    if not data then
        return 0
    end

    -- Build UUID→pet map O(n) once to avoid O(n²) nested loops
    local petByUUID = {}
    for _, pet in ipairs(data.Pets or {}) do
        petByUUID[pet.UUID] = pet
    end

    local totalPower = 0
    for _, petUUID in ipairs(data.EquippedPets or {}) do
        local ownedPet = petByUUID[petUUID]
        if ownedPet then
            local petInfo = PetConfig.GetPet(ownedPet.PetId)
            if petInfo then
                local power = petInfo.Power
                if ownedPet.Golden then
                    power = power * RarityConfig.GoldenMultiplier
                end
                if ownedPet.Rainbow then
                    power = power * RarityConfig.RainbowMultiplier
                end
                totalPower = totalPower + power
            end
        end
    end

    return totalPower
end

-- Set up coin collection remote
-- Maximum studs a player may be from a zone's SpawnPosition to claim that zone's coins.
-- Zones are 200 studs apart; 150 studs covers all legitimate play areas for a zone.
local ZONE_RADIUS = 150

function CurrencyService.Init(dataService, rewardService, antiExploitService, petLevelService)
    DataService = dataService
    RewardService = rewardService
    AntiExploitService = antiExploitService
    PetLevelService = petLevelService

    -- Clean up per-player upsell cooldown on leave
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        _upsellCooldown[player] = nil
    end)

    Network.OnServerEvent("CollectCoin", function(player: Player, zoneId: string)
        if not AntiExploitService.CheckRateLimit(player, "CollectCoin") then return end

        -- Validate zone access
        local data = DataService.GetData(player)
        if not data then return end

        local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
        local zone = ZoneConfig.GetZone(zoneId)
        if not zone then return end

        -- Check zone is unlocked
        local unlocked = false
        for _, unlockedZone in ipairs(data.UnlockedZones or {}) do
            if unlockedZone == zoneId then
                unlocked = true
                break
            end
        end
        if not unlocked then return end

        -- Server-side proximity guard: verify player character is actually inside this zone.
        -- Prevents clients from spoofing a high-value late-game zone while standing in starter area.
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local dist = (hrp.Position - zone.SpawnPosition).Magnitude
        if dist > ZONE_RADIUS then
            warn(string.format("[AntiExploit] Zone spoof: %s claimed zone '%s' but character is %.0f studs away (limit %d)",
                player.Name, zoneId, dist, ZONE_RADIUS))
            return
        end

        -- Add coins based on zone value
        local amount = CurrencyService.Add(player, "Coins", zone.CoinValue, true)

        -- Track quest progress
        if amount > 0 and RewardService then
            RewardService.UpdateQuestProgress(player, "CollectCoins", amount)
        end

        -- Grant XP to equipped pets
        if amount > 0 and PetLevelService then
            PetLevelService.GrantXP(player, amount)
        end
    end)
end

-- Late-bind services that init after CurrencyService
function CurrencyService.SetEventService(eventService)
    EventService = eventService
end

function CurrencyService.SetDailyRotationService(dailyRotationService)
    DailyRotationService = dailyRotationService
end

function CurrencyService.SetNudgeService(nudgeService)
    NudgeService = nudgeService
end

function CurrencyService.SetEntitlementService(entitlementService)
    EntitlementService = entitlementService
end

return CurrencyService
