--[[
    AdminService.luau
    Admin commands for testing and balancing.
    Only works for authorized user IDs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local DataService
local CurrencyService
local PetService
local EggService

local AdminService = {}

-- Add your Roblox User IDs here
local ADMIN_IDS = {
    -- 12345678, -- Replace with your user ID
}

local function isAdmin(player: Player): boolean
    for _, id in ipairs(ADMIN_IDS) do
        if player.UserId == id then
            return true
        end
    end
    return false
end

-- Available commands
local commands = {}

commands["addcoins"] = function(player, args)
    local amount = tonumber(args[1]) or 1000
    CurrencyService.Add(player, "Coins", amount, false)
    return "Added " .. amount .. " Coins"
end

commands["addgems"] = function(player, args)
    local amount = tonumber(args[1]) or 100
    CurrencyService.Add(player, "Gems", amount, false)
    return "Added " .. amount .. " Gems"
end

commands["setcoins"] = function(player, args)
    local amount = tonumber(args[1]) or 0
    local data = DataService.GetData(player)
    if data then
        data.Coins = math.max(0, amount)
        Network.FireClient("CurrencyUpdated", player, "Coins", data.Coins)
    end
    return "Coins set to " .. amount
end

commands["givepet"] = function(player, args)
    local petId = args[1]
    local golden = args[2] == "golden"
    local rainbow = args[2] == "rainbow"
    if petId then
        local pet = PetService.AddPet(player, petId, golden, rainbow)
        if pet then
            return "Gave pet: " .. petId .. (golden and " (Golden)" or "") .. (rainbow and " (Rainbow)" or "")
        end
    end
    return "Failed to give pet. Usage: givepet <petId> [golden|rainbow]"
end

commands["unlockall"] = function(player, _args)
    local data = DataService.GetData(player)
    if data then
        local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
        data.UnlockedZones = {}
        for _, zone in ipairs(ZoneConfig.Zones) do
            table.insert(data.UnlockedZones, zone.Id)
            Network.FireClient("ZoneUnlocked", player, zone.Id)
        end
    end
    return "All zones unlocked"
end

commands["resetdata"] = function(player, _args)
    local data = DataService.GetData(player)
    if data then
        -- Reset to defaults
        data.Coins = 0
        data.Gems = 0
        data.Pets = {}
        data.EquippedPets = {}
        data.UnlockedZones = { "starter_meadow" }
        data.Rebirths = 0
        data.RebirthMultiplier = 1.0
        data.TotalCoinsEarned = 0
        data.TotalEggsHatched = 0
        data.TotalPetsCollected = 0
        data.MaxEquipSlots = 3
        Network.FireClient("PlayerDataLoaded", player, data)
    end
    return "Data reset"
end

commands["givegamepass"] = function(player, args)
    local gamepassId = args[1]
    if gamepassId then
        local data = DataService.GetData(player)
        if data then
            if not data.Gamepasses then data.Gamepasses = {} end
            data.Gamepasses[gamepassId] = true
            Network.FireClient("GamepassOwned", player, gamepassId)
            return "Gave gamepass: " .. gamepassId
        end
    end
    return "Usage: givegamepass <gamepassId>"
end

commands["setrebirth"] = function(player, args)
    local level = tonumber(args[1]) or 0
    local data = DataService.GetData(player)
    if data then
        local RebirthConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RebirthConfig"))
        data.Rebirths = level
        local tier = RebirthConfig.GetTier(level)
        data.RebirthMultiplier = tier and tier.Multiplier or 1.0
        data.MaxEquipSlots = RebirthConfig.GetTotalEquipSlots(level)
        Network.FireClient("RebirthCompleted", player, {
            Rebirths = data.Rebirths,
            Multiplier = data.RebirthMultiplier,
            MaxEquipSlots = data.MaxEquipSlots,
        })
    end
    return "Rebirth set to " .. level
end

commands["boost"] = function(player, args)
    local boostType = args[1] or "Luck"
    local duration = tonumber(args[2]) or 1800
    local data = DataService.GetData(player)
    if data then
        if not data.ActiveBoosts then data.ActiveBoosts = {} end
        data.ActiveBoosts[boostType] = os.time() + duration
        Network.FireClient("BoostActivated", player, boostType, data.ActiveBoosts[boostType])
    end
    return "Activated " .. boostType .. " boost for " .. duration .. "s"
end

commands["help"] = function(_player, _args)
    local cmds = {}
    for name in pairs(commands) do
        table.insert(cmds, name)
    end
    table.sort(cmds)
    return "Commands: " .. table.concat(cmds, ", ")
end

-- Process an admin command
function AdminService.ProcessCommand(player: Player, input: string)
    if not isAdmin(player) then
        Network.FireClient("ShowNotification", player, "You are not an admin.", "Warning")
        return
    end

    local parts = string.split(input, " ")
    local commandName = string.lower(parts[1] or "")
    local args = {}
    for i = 2, #parts do
        table.insert(args, parts[i])
    end

    local handler = commands[commandName]
    if handler then
        local result = handler(player, args)
        Network.FireClient("ShowNotification", player, "[Admin] " .. (result or "Done"), "Info")
    else
        Network.FireClient("ShowNotification", player, "[Admin] Unknown command. Type 'help'.", "Warning")
    end
end

-- Initialize
function AdminService.Init(dataService, currencyService, petService, eggService)
    DataService = dataService
    CurrencyService = currencyService
    PetService = petService
    EggService = eggService

    Network.OnServerEvent("AdminCommand", function(player: Player, input: string)
        if type(input) ~= "string" then return end
        AdminService.ProcessCommand(player, input)
    end)
end

return AdminService
