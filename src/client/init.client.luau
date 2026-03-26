--[[
    Client Entry Point (init.client.luau)
    Initializes all client controllers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

-- Wait for network to be initialized by server
print("[Client] Waiting for network...")
Network.WaitForInit()
print("[Client] Network ready!")

-- Load controllers
local Controllers = script:WaitForChild("Controllers")
local CurrencyController = require(Controllers:WaitForChild("CurrencyController"))
local PetController = require(Controllers:WaitForChild("PetController"))
local HatchController = require(Controllers:WaitForChild("HatchController"))
local ZoneController = require(Controllers:WaitForChild("ZoneController"))
local ShopController = require(Controllers:WaitForChild("ShopController"))

-- Initialize controllers
print("[Client] Initializing controllers...")
CurrencyController.Init()
PetController.Init()
HatchController.Init()
ZoneController.Init()
ShopController.Init()

-- Make controllers globally accessible for GUI scripts
local clientModules = Instance.new("Folder")
clientModules.Name = "ClientModules"
clientModules.Parent = ReplicatedStorage

-- Store references (GUI scripts can require these from ReplicatedStorage)
local moduleRefs = {
    CurrencyController = CurrencyController,
    PetController = PetController,
    HatchController = HatchController,
    ZoneController = ZoneController,
    ShopController = ShopController,
}

-- Store in a BindableEvent so GUIs can access controllers
local controllerReady = Instance.new("BindableEvent")
controllerReady.Name = "ControllersReady"
controllerReady.Parent = player

-- Expose controllers via module value
local controllersModule = Instance.new("ObjectValue")
controllersModule.Name = "Controllers"
controllersModule.Parent = player

-- Notification system
Network.OnClientEvent("ShowNotification", function(message: string, notifType: string)
    -- This will be picked up by the MainHUD GUI
    local playerGui = player:WaitForChild("PlayerGui")
    local mainHud = playerGui:FindFirstChild("MainHUD")
    if mainHud then
        local notifEvent = mainHud:FindFirstChild("NotificationEvent")
        if notifEvent then
            notifEvent:Fire(message, notifType)
        end
    end
end)

-- Set up coin collection (clicking coins in the world)
local function setupCoinCollection()
    local Workspace = game:GetService("Workspace")
    local zonesFolder = Workspace:WaitForChild("Zones", 30)
    if not zonesFolder then return end

    -- Connect click detectors on coins
    local function connectCoin(coin)
        local clickDetector = coin:FindFirstChild("ClickDetector")
        local zoneValue = coin:FindFirstChild("ZoneId")
        if clickDetector and zoneValue then
            clickDetector.MouseClick:Connect(function()
                Network.FireServer("CollectCoin", zoneValue.Value)
            end)
        end
    end

    -- Connect existing coins
    for _, zoneFolder in ipairs(zonesFolder:GetChildren()) do
        local coinsFolder = zoneFolder:FindFirstChild("Coins")
        if coinsFolder then
            for _, coin in ipairs(coinsFolder:GetChildren()) do
                connectCoin(coin)
            end
            coinsFolder.ChildAdded:Connect(connectCoin)
        end
    end

    -- Connect future zones
    zonesFolder.ChildAdded:Connect(function(zoneFolder)
        local coinsFolder = zoneFolder:WaitForChild("Coins", 10)
        if coinsFolder then
            for _, coin in ipairs(coinsFolder:GetChildren()) do
                connectCoin(coin)
            end
            coinsFolder.ChildAdded:Connect(connectCoin)
        end
    end)
end

task.spawn(setupCoinCollection)

-- Signal that controllers are ready
controllerReady:Fire()

print("[Client] Wynkpets client ready!")

-- Return controllers table for direct require access
return moduleRefs
