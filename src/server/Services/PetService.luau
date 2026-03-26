-- PetService.luau
-- Handles egg hatching, pet equipping/unequipping, and pet releasing.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local DataService    = require(script.Parent.DataService)
local PetConfig      = require(ReplicatedStorage.Shared.Config.PetConfig)
local EggConfig      = require(ReplicatedStorage.Shared.Config.EggConfig)
local WeightedRandom = require(ReplicatedStorage.Shared.Modules.WeightedRandom)
local MultiplierUtil = require(ReplicatedStorage.Shared.Modules.MultiplierUtil)

local Events = ReplicatedStorage.Shared.Remotes.Events

local PetService = {}

-- ─── Internal ────────────────────────────────────────────────────────────────

local function generateUID(): string
    return HttpService:GenerateGUID(false)
end

local function firePetsUpdate(player: Player, data: {})
    Events.PetsUpdated:FireClient(player, data.Pets, data.EquippedPets)
end

-- ─── Hatch one egg ────────────────────────────────────────────────────────────

local function hatchEgg(player: Player, eggId: string)
    local data = DataService.get(player)
    if not data then return end

    local eggDef = EggConfig.ById[eggId]
    if not eggDef then
        Events.PurchaseResult:FireClient(player, false, "Unknown egg.")
        return
    end

    -- World / rebirth gate
    if eggDef.worldRequired > data.CurrentWorld then
        Events.PurchaseResult:FireClient(player, false, "Unlock the required world first.")
        return
    end
    if eggDef.rebirthRequired > data.Rebirths then
        Events.PurchaseResult:FireClient(player, false, "More rebirths required.")
        return
    end

    -- Deduct cost
    if eggDef.coinCost > 0 then
        if data.Coins < eggDef.coinCost then
            Events.PurchaseResult:FireClient(player, false, "Not enough coins.")
            return
        end
        data.Coins = data.Coins - eggDef.coinCost
        Events.CoinsUpdated:FireClient(player, data.Coins)
    elseif eggDef.gemCost > 0 then
        if data.Gems < eggDef.gemCost then
            Events.PurchaseResult:FireClient(player, false, "Not enough gems.")
            return
        end
        data.Gems = data.Gems - eggDef.gemCost
        Events.GemsUpdated:FireClient(player, data.Gems)
    elseif eggDef.isLimited and eggDef.eventCurrency then
        local have = (data.Ores[eggDef.eventCurrency] or 0)
        if have < (eggDef.eventCost or 0) then
            Events.PurchaseResult:FireClient(player, false, "Not enough event tokens.")
            return
        end
        data.Ores[eggDef.eventCurrency] = have - eggDef.eventCost
    end

    -- Check inventory cap
    if #data.Pets >= PetConfig.MaxInventorySize then
        Events.PurchaseResult:FireClient(player, false, "Inventory full! Release some pets first.")
        return
    end

    -- Pick pet from pool using luck multiplier
    local mults     = MultiplierUtil.calculate(data)
    local poolEntry = WeightedRandom.pick(eggDef.pool, mults.luckMult)
    local petId     = poolEntry.petId
    local petDef    = PetConfig.ById[petId]

    -- Create pet instance
    local petInstance = {
        uid   = generateUID(),
        petId = petId,
        rarity= petDef and petDef.rarity or "Common",
    }
    table.insert(data.Pets, petInstance)

    -- Update stats
    data.Stats.totalEggsHatched  = data.Stats.totalEggsHatched  + 1
    data.Stats.eggsHatchedToday  = data.Stats.eggsHatchedToday  + 1
    data.Stats.eggsHatchedWeekly = data.Stats.eggsHatchedWeekly + 1
    if petInstance.rarity == "Secret" then
        data.Stats.secretPetsHatched = data.Stats.secretPetsHatched + 1
    end

    -- Recalculate unique pets
    local unique = {}
    for _, inst in ipairs(data.Pets) do
        unique[inst.petId] = true
    end
    data.Stats.uniquePetsOwned = 0
    for _ in pairs(unique) do
        data.Stats.uniquePetsOwned = data.Stats.uniquePetsOwned + 1
    end

    -- Notify client
    Events.PetHatched:FireClient(player, petInstance)
    firePetsUpdate(player, data)
end

-- ─── Equip / unequip pet ──────────────────────────────────────────────────────

local function equipPet(player: Player, uid: string, equip: boolean)
    local data = DataService.get(player)
    if not data then return end

    -- Validate uid exists in inventory
    local found = false
    for _, inst in ipairs(data.Pets) do
        if inst.uid == uid then found = true; break end
    end
    if not found then return end

    local maxSlots = MultiplierUtil.getEquipSlots(data)

    if equip then
        if table.find(data.EquippedPets, uid) then return end  -- already equipped
        if #data.EquippedPets >= maxSlots then
            Events.PurchaseResult:FireClient(player, false, "No equip slots available.")
            return
        end
        table.insert(data.EquippedPets, uid)
    else
        local idx = table.find(data.EquippedPets, uid)
        if idx then
            table.remove(data.EquippedPets, idx)
        end
    end

    firePetsUpdate(player, data)
end

-- ─── Release pet ─────────────────────────────────────────────────────────────

local function releasePet(player: Player, uid: string)
    local data = DataService.get(player)
    if not data then return end

    -- Remove from equipped list if present
    local eqIdx = table.find(data.EquippedPets, uid)
    if eqIdx then table.remove(data.EquippedPets, eqIdx) end

    -- Remove from inventory
    for i, inst in ipairs(data.Pets) do
        if inst.uid == uid then
            table.remove(data.Pets, i)
            break
        end
    end

    -- Recalculate unique pets
    local unique = {}
    for _, inst in ipairs(data.Pets) do unique[inst.petId] = true end
    data.Stats.uniquePetsOwned = 0
    for _ in pairs(unique) do
        data.Stats.uniquePetsOwned = data.Stats.uniquePetsOwned + 1
    end

    firePetsUpdate(player, data)
end

-- ─── Auto-hatch loop ─────────────────────────────────────────────────────────

local autoHatchQueue = {}  -- [userId] = eggId to auto-hatch

function PetService.setAutoHatch(player: Player, eggId: string?)
    autoHatchQueue[player.UserId] = eggId
end

task.spawn(function()
    while true do
        task.wait(EggConfig.AutoHatchInterval)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataService.get(player)
            if data then
                local hasAutoHatch = table.find(data.OwnedGamepasses, "auto_hatch") ~= nil
                local eggId        = autoHatchQueue[player.UserId]
                if hasAutoHatch and eggId then
                    task.spawn(hatchEgg, player, eggId)
                end
            end
        end
    end
end)

-- ─── RemoteEvent handlers ─────────────────────────────────────────────────────

Events.HatchEgg.OnServerEvent:Connect(function(player: Player, eggId: string)
    if type(eggId) ~= "string" then return end
    hatchEgg(player, eggId)
end)

Events.EquipPet.OnServerEvent:Connect(function(player: Player, uid: string, equip: boolean)
    if type(uid) ~= "string" then return end
    equipPet(player, uid, equip == true)
end)

Events.ReleasePet.OnServerEvent:Connect(function(player: Player, uid: string)
    if type(uid) ~= "string" then return end
    releasePet(player, uid)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    autoHatchQueue[player.UserId] = nil
end)

return PetService
