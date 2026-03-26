-- ClientData.luau
-- Client-side player data cache. Updated whenever the server fires sync events.
-- Controllers read from here rather than calling remotes repeatedly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData = {}

-- Mutable data cache (shallow reference, updated in-place)
ClientData.data = nil  -- nil until DataLoaded fires

-- Callbacks registered by controllers: fn(data)
local listeners = {}

function ClientData.onUpdate(fn: (data: {}) -> ())
    table.insert(listeners, fn)
end

local function notify()
    for _, fn in ipairs(listeners) do
        task.spawn(fn, ClientData.data)
    end
end

-- ─── Wire up server sync events ───────────────────────────────────────────────

local function waitForRemote(name: string)
    return ReplicatedStorage.Shared.Remotes.Events:WaitForChild(name, 30)
end

task.spawn(function()
    local dataLoadedEvent = waitForRemote("DataLoaded")
    dataLoadedEvent.OnClientEvent:Connect(function(data)
        ClientData.data = data
        notify()
    end)

    local coinsUpdated = waitForRemote("CoinsUpdated")
    coinsUpdated.OnClientEvent:Connect(function(coins)
        if ClientData.data then
            ClientData.data.Coins = coins
            notify()
        end
    end)

    local gemsUpdated = waitForRemote("GemsUpdated")
    gemsUpdated.OnClientEvent:Connect(function(gems)
        if ClientData.data then
            ClientData.data.Gems = gems
            notify()
        end
    end)

    local petsUpdated = waitForRemote("PetsUpdated")
    petsUpdated.OnClientEvent:Connect(function(pets, equipped)
        if ClientData.data then
            ClientData.data.Pets         = pets
            ClientData.data.EquippedPets = equipped
            notify()
        end
    end)

    local boostsUpdated = waitForRemote("ActiveBoostsUpdated")
    boostsUpdated.OnClientEvent:Connect(function(boosts)
        if ClientData.data then
            ClientData.data.ActiveBoosts = boosts
            notify()
        end
    end)

    local rebirthCompleted = waitForRemote("RebirthCompleted")
    rebirthCompleted.OnClientEvent:Connect(function(rebirths, bonus)
        if ClientData.data then
            ClientData.data.Rebirths      = rebirths
            ClientData.data.RebirthBonus  = bonus
            notify()
        end
    end)

    local worldUnlocked = waitForRemote("WorldUnlocked")
    worldUnlocked.OnClientEvent:Connect(function(worldId)
        if ClientData.data then
            if not table.find(ClientData.data.UnlockedWorlds, worldId) then
                table.insert(ClientData.data.UnlockedWorlds, worldId)
            end
            ClientData.data.CurrentWorld = worldId
            notify()
        end
    end)
end)

return ClientData
