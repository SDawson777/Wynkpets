--[[
    CurrencyService.luau
    Handles all currency operations (Coins, Gems).
    Server-authoritative: validates all transactions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local DataService -- Forward declaration, set in Init

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

    -- Gamepass multipliers
    if currency == "Coins" and data.Gamepasses and data.Gamepasses["2x_coins"] then
        multiplier = multiplier * 2.0
    end
    if currency == "Gems" and data.Gamepasses and data.Gamepasses["2x_gems"] then
        multiplier = multiplier * 2.0
    end

    -- VIP bonus
    if data.Gamepasses and data.Gamepasses["vip"] then
        multiplier = multiplier * 1.5
    end

    -- Active boosts
    if data.ActiveBoosts then
        local now = os.time()
        if currency == "Coins" and data.ActiveBoosts["Coins"] and data.ActiveBoosts["Coins"] > now then
            multiplier = multiplier * 2.0
        end
    end

    -- Pet power multiplier (sum of equipped pet powers)
    local petPower = CurrencyService.GetEquippedPetPower(player)
    if petPower > 0 then
        multiplier = multiplier * (1 + petPower / 100)
    end

    return amount * multiplier
end

-- Get total power of equipped pets
function CurrencyService.GetEquippedPetPower(player: Player): number
    local data = DataService.GetData(player)
    if not data then
        return 0
    end

    local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
    local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))
    local totalPower = 0

    for _, petUUID in ipairs(data.EquippedPets or {}) do
        for _, ownedPet in ipairs(data.Pets or {}) do
            if ownedPet.UUID == petUUID then
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
                break
            end
        end
    end

    return totalPower
end

-- Set up coin collection remote
function CurrencyService.Init(dataService)
    DataService = dataService

    Network.OnServerEvent("CollectCoin", function(player: Player, zoneId: string)
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

        -- Add coins based on zone value
        CurrencyService.Add(player, "Coins", zone.CoinValue, true)
    end)
end

return CurrencyService
