--[[
    Server Entry Point (init.server.luau)
    Initializes all server services in the correct order.
    This is the main server script that boots the game.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

-- Initialize network (creates all RemoteEvents/RemoteFunctions)
print("[Server] Initializing Network...")
Network.InitServer()

-- Load all services
local Services = script:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local PetService = require(Services:WaitForChild("PetService"))
local EggService = require(Services:WaitForChild("EggService"))
local ZoneService = require(Services:WaitForChild("ZoneService"))
local RebirthService = require(Services:WaitForChild("RebirthService"))
local GamepassService = require(Services:WaitForChild("GamepassService"))
local ShopService = require(Services:WaitForChild("ShopService"))
local RewardService = require(Services:WaitForChild("RewardService"))
local AdminService = require(Services:WaitForChild("AdminService"))
local AntiExploitService = require(Services:WaitForChild("AntiExploitService"))
local CoinSpawnerService = require(Services:WaitForChild("CoinSpawnerService"))

-- Initialize services (order matters: dependencies first)
print("[Server] Initializing Services...")

DataService.Init()
CurrencyService.Init(DataService)
PetService.Init(DataService)
EggService.Init(DataService, CurrencyService, PetService)
ZoneService.Init(DataService, CurrencyService)
RebirthService.Init(DataService, CurrencyService)
GamepassService.Init(DataService)
ShopService.Init(DataService, CurrencyService)
RewardService.Init(DataService, CurrencyService)
AdminService.Init(DataService, CurrencyService, PetService, EggService)
AntiExploitService.Init()
CoinSpawnerService.Init()

print("[Server] All services initialized!")

-- Player join handling
Players.PlayerAdded:Connect(function(player)
    print(string.format("[Server] %s joined (%d)", player.Name, player.UserId))

    -- Load player data
    local dataLoaded = DataService.LoadData(player)

    if dataLoaded then
        -- Verify gamepass ownership
        GamepassService.VerifyOwnership(player)

        -- Process login streak / daily rewards
        RewardService.ProcessLogin(player)
    end

    -- Spawn character
    player.CharacterAdded:Connect(function(character)
        -- Teleport to starter zone
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
        if humanoidRootPart then
            humanoidRootPart.CFrame = CFrame.new(0, 10, 0) -- Starter meadow spawn
        end
    end)
end)

-- Player leave handling
Players.PlayerRemoving:Connect(function(player)
    print(string.format("[Server] %s leaving (%d)", player.Name, player.UserId))
    DataService.PlayerRemoving(player)
    EggService.PlayerRemoving(player)
    AntiExploitService.PlayerRemoving(player)
end)

-- Handle players who joined before script loaded
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        DataService.LoadData(player)
        GamepassService.VerifyOwnership(player)
        RewardService.ProcessLogin(player)
    end)
end

print("[Server] Wynkpets server ready!")
