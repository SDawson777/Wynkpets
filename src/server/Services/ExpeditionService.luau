--[[
    ExpeditionService.luau
    Server-authoritative service for Pet Expeditions.
    Players send unequipped pets on timed missions for Coins, Gems, and XP.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ExpeditionConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ExpeditionConfig"))
local PetConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local PetLevelConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PetLevelConfig"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

local DataService
local CurrencyService
local PetService
local PetLevelService

local ExpeditionService = {}

-- ── Helpers ─────────────────────────────────────────────────────────────────

local function getExpeditions(player)
    local data = DataService.GetData(player)
    if not data then return nil end
    if not data.Expeditions then
        data.Expeditions = { Active = {}, Completed = 0 }
    end
    if not data.Expeditions.Active then
        data.Expeditions.Active = {}
    end
    return data.Expeditions
end

local function getMaxSlots(player)
    local data = DataService.GetData(player)
    if not data then return ExpeditionConfig.BaseSlots end
    local slots = ExpeditionConfig.BaseSlots
    local tier = data.SubscriptionTier or "none"
    if tier == "basic" or tier == "vip" then
        slots = slots + ExpeditionConfig.VIPBonusSlots
    end
    return math.min(slots, ExpeditionConfig.MaxSlots)
end

local function findPetByUUID(data, uuid)
    for _, pet in ipairs(data.Pets or {}) do
        if pet.UUID == uuid then
            return pet
        end
    end
    return nil
end

local function isPetOnExpedition(expeditions, uuid)
    for _, exp in ipairs(expeditions.Active) do
        if exp.PetUUID == uuid then
            return true
        end
    end
    return false
end

local function getEffectivePower(pet)
    local petInfo = PetConfig.GetPet(pet.PetId)
    if not petInfo then return 1 end
    local basePower = petInfo.Power or 1
    local levelMult = PetLevelConfig.GetPowerMultiplier(pet.Level or 1)
    local power = basePower * levelMult
    if pet.Golden then power = power * 2.5 end
    if pet.Rainbow then power = power * 5 end
    return math.floor(power)
end

local function getNextSlotIndex(expeditions, maxSlots)
    local used = {}
    for _, exp in ipairs(expeditions.Active) do
        used[exp.SlotIndex] = true
    end
    for i = 1, maxSlots do
        if not used[i] then return i end
    end
    return nil
end

local function sendExpeditionData(player)
    local expeditions = getExpeditions(player)
    if not expeditions then return end
    Network.FireClient("ExpeditionData", player, {
        Active = expeditions.Active,
        Completed = expeditions.Completed,
        MaxSlots = getMaxSlots(player),
    })
end

-- ── API ─────────────────────────────────────────────────────────────────────

function ExpeditionService.StartExpedition(player: Player, zoneId: string, tierId: string, petUUID: string): (boolean, string)
    local data = DataService.GetData(player)
    if not data then return false, "No data" end

    -- Validate zone
    local zoneData = ZoneConfig.ZoneById[zoneId]
    if not zoneData then return false, "Invalid zone" end
    local zoneScaling = ExpeditionConfig.ZoneScaling[zoneId]
    if not zoneScaling then return false, "Zone not available for expeditions" end

    -- Check zone unlocked
    local unlocked = false
    for _, z in ipairs(data.UnlockedZones or {}) do
        if z == zoneId then unlocked = true; break end
    end
    if not unlocked then return false, "Zone not unlocked" end

    -- Validate tier
    local tier = ExpeditionConfig.TierById[tierId]
    if not tier then return false, "Invalid expedition tier" end

    -- Validate pet exists and is not equipped
    local pet = findPetByUUID(data, petUUID)
    if not pet then return false, "Pet not found" end
    if pet.Equipped then return false, "Pet is currently equipped" end

    -- Check pet not already on expedition
    local expeditions = getExpeditions(player)
    if not expeditions then return false, "No data" end
    if isPetOnExpedition(expeditions, petUUID) then return false, "Pet is already on an expedition" end

    -- Check slot availability
    local maxSlots = getMaxSlots(player)
    local slotIndex = getNextSlotIndex(expeditions, maxSlots)
    if not slotIndex then return false, "No expedition slots available" end

    -- Calculate pet power at time of dispatch
    local petPower = getEffectivePower(pet)

    -- Create expedition entry
    local entry = {
        SlotIndex = slotIndex,
        ZoneId = zoneId,
        TierId = tierId,
        PetUUID = petUUID,
        PetPower = petPower,
        StartTime = os.time(),
        Duration = tier.Duration,
    }
    table.insert(expeditions.Active, entry)

    -- Notify client
    sendExpeditionData(player)
    Network.FireClient("ShowNotification", player,
        "Expedition started! Your pet is exploring " .. (zoneData.Name or zoneId) .. ".", "Success")

    return true, "Started"
end

function ExpeditionService.ClaimExpedition(player: Player, slotIndex: number): (boolean, { Coins: number, Gems: number, XP: number }?)
    local expeditions = getExpeditions(player)
    if not expeditions then return false, nil end

    -- Find expedition by slot
    local expIndex = nil
    local exp = nil
    for i, e in ipairs(expeditions.Active) do
        if e.SlotIndex == slotIndex then
            expIndex = i
            exp = e
            break
        end
    end
    if not exp then return false, nil end

    -- Check if finished
    local now = os.time()
    if now < exp.StartTime + exp.Duration then
        return false, nil
    end

    -- Calculate rewards
    local rewards = ExpeditionConfig.CalculateRewards(exp.ZoneId, exp.TierId, exp.PetPower)

    -- Grant rewards
    local data = DataService.GetData(player)
    if not data then return false, nil end

    if rewards.Coins > 0 then
        CurrencyService.Add(player, "Coins", rewards.Coins, false) -- no multiplier stacking on expedition rewards
    end
    if rewards.Gems > 0 then
        CurrencyService.Add(player, "Gems", rewards.Gems, false)
    end

    -- Grant XP to the pet that was on expedition
    if rewards.XP > 0 then
        local pet = findPetByUUID(data, exp.PetUUID)
        if pet then
            local level = pet.Level or 1
            if level < PetLevelConfig.MaxLevel then
                pet.XP = (pet.XP or 0) + rewards.XP
                -- Process level-ups
                while level < PetLevelConfig.MaxLevel do
                    local xpNeeded = PetLevelConfig.GetXPForLevel(level)
                    if xpNeeded <= 0 then break end
                    if pet.XP >= xpNeeded then
                        pet.XP = pet.XP - xpNeeded
                        level = level + 1
                        pet.Level = level
                    else
                        break
                    end
                end
                local petInfo = PetConfig.GetPet(pet.PetId)
                Network.FireClient("PetsUpdated", player, data.Pets)
            end
        end
    end

    -- Remove from active, increment completed
    table.remove(expeditions.Active, expIndex)
    expeditions.Completed = (expeditions.Completed or 0) + 1

    -- Notify
    sendExpeditionData(player)
    Network.FireClient("ExpeditionUpdated", player, {
        Type = "Claimed",
        SlotIndex = slotIndex,
        Rewards = rewards,
    })

    return true, rewards
end

function ExpeditionService.SkipExpedition(player: Player, slotIndex: number): (boolean, string)
    local expeditions = getExpeditions(player)
    if not expeditions then return false, "No data" end

    -- Find expedition
    local exp = nil
    for _, e in ipairs(expeditions.Active) do
        if e.SlotIndex == slotIndex then
            exp = e
            break
        end
    end
    if not exp then return false, "No expedition in that slot" end

    -- Already finished — just claim
    local now = os.time()
    if now >= exp.StartTime + exp.Duration then
        return false, "Expedition already complete — claim it!"
    end

    -- Check gem cost
    local tier = ExpeditionConfig.TierById[exp.TierId]
    if not tier then return false, "Invalid tier" end
    local cost = tier.SkipCost
    if not CurrencyService.CanAfford(player, "Gems", cost) then
        return false, "Not enough Gems"
    end

    -- Deduct gems and set expedition as instantly complete
    CurrencyService.Remove(player, "Gems", cost)
    exp.StartTime = now - exp.Duration -- make it look finished

    sendExpeditionData(player)
    Network.FireClient("ShowNotification", player,
        "Expedition completed early for " .. cost .. " Gems!", "Success")

    return true, "Skipped"
end

function ExpeditionService.GetExpeditionData(player: Player)
    local expeditions = getExpeditions(player)
    if not expeditions then return nil end
    return {
        Active = expeditions.Active,
        Completed = expeditions.Completed,
        MaxSlots = getMaxSlots(player),
    }
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function ExpeditionService.PlayerAdded(player: Player)
    -- Send expedition data to client on join
    task.defer(function()
        sendExpeditionData(player)
    end)
end

function ExpeditionService.PlayerRemoving(_player: Player)
    -- Data is auto-saved by DataService; nothing to clean up
end

function ExpeditionService.Init(dataService, currencyService, petService, petLevelService)
    DataService = dataService
    CurrencyService = currencyService
    PetService = petService
    PetLevelService = petLevelService

    -- Wire network events
    Network.OnServerEvent("RequestExpeditionData", function(player)
        sendExpeditionData(player)
    end)

    Network.OnServerEvent("StartExpedition", function(player, payload)
        if type(payload) ~= "table" then return end
        local zoneId = payload.ZoneId
        local tierId = payload.TierId
        local petUUID = payload.PetUUID
        if type(zoneId) ~= "string" or type(tierId) ~= "string" or type(petUUID) ~= "string" then return end
        ExpeditionService.StartExpedition(player, zoneId, tierId, petUUID)
    end)

    Network.OnServerEvent("ClaimExpedition", function(player, payload)
        if type(payload) ~= "table" then return end
        local slotIndex = payload.SlotIndex
        if type(slotIndex) ~= "number" then return end
        ExpeditionService.ClaimExpedition(player, slotIndex)
    end)

    Network.OnServerEvent("SkipExpedition", function(player, payload)
        if type(payload) ~= "table" then return end
        local slotIndex = payload.SlotIndex
        if type(slotIndex) ~= "number" then return end
        ExpeditionService.SkipExpedition(player, slotIndex)
    end)
end

return ExpeditionService
