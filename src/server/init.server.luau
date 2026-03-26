-- init.server.luau
-- Server bootstrap: create RemoteEvents/RemoteFunctions, then load all services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteConfig      = require(ReplicatedStorage.Shared.Config.RemoteConfig)

-- ─── Create Remotes folder structure ──────────────────────────────────────────

local remotesFolder = Instance.new("Folder")
remotesFolder.Name  = "Remotes"
remotesFolder.Parent = ReplicatedStorage.Shared

local eventsFolder = Instance.new("Folder")
eventsFolder.Name  = "Events"
eventsFolder.Parent = remotesFolder

local functionsFolder = Instance.new("Folder")
functionsFolder.Name  = "Functions"
functionsFolder.Parent = remotesFolder

for _, eventName in ipairs(RemoteConfig.Events) do
    local re = Instance.new("RemoteEvent")
    re.Name  = eventName
    re.Parent = eventsFolder
end

for _, funcName in ipairs(RemoteConfig.Functions) do
    local rf = Instance.new("RemoteFunction")
    rf.Name  = funcName
    rf.Parent = functionsFolder
end

print("[Server] Remotes created.")

-- ─── Load services (order matters for dependency injection) ───────────────────

local Services = script.Parent.Services

require(Services.DataService)
print("[Server] DataService loaded.")

require(Services.MiningService)
print("[Server] MiningService loaded.")

require(Services.PetService)
print("[Server] PetService loaded.")

require(Services.ShopService)
print("[Server] ShopService loaded.")

require(Services.RebirthService)
print("[Server] RebirthService loaded.")

require(Services.QuestService)
print("[Server] QuestService loaded.")

require(Services.TradeService)
print("[Server] TradeService loaded.")

require(Services.EventService)
print("[Server] EventService loaded.")

print("[Server] Crystal Pets Simulator – all services online.")
