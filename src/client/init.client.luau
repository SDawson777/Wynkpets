-- init.client.luau
-- Client bootstrap: wait for remotes, then load all controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for server to create Remotes
local shared = ReplicatedStorage:WaitForChild("Shared", 30)
local remotes = shared:WaitForChild("Remotes", 30)
remotes:WaitForChild("Events", 30)
remotes:WaitForChild("Functions", 30)

-- Load controllers in order
require(script.Parent.Controllers.ClientData)
require(script.Parent.Controllers.UIController)
require(script.Parent.Controllers.MiningController)
require(script.Parent.Controllers.PetController)
require(script.Parent.Controllers.ShopController)

print("[Client] Crystal Pets Simulator – client ready.")
