--[[
    PortalService.luau
    Creates zone portals/gates between adjacent zones.
    Touching a portal teleports if unlocked, or prompts to unlock.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))

local DataService
local CurrencyService
local ZoneService

local PortalService = {}

local PORTAL_HEIGHT = 16
local PORTAL_WIDTH = 10
local PILLAR_SIZE = Vector3.new(2, PORTAL_HEIGHT, 2)

local portalCooldowns = {} -- [Player] = tick

local function getOrCreateZoneFolder(zoneId: string)
    local zonesFolder = Workspace:FindFirstChild("Zones")
    if not zonesFolder then
        zonesFolder = Instance.new("Folder")
        zonesFolder.Name = "Zones"
        zonesFolder.Parent = Workspace
    end

    local zoneFolder = zonesFolder:FindFirstChild(zoneId)
    if not zoneFolder then
        zoneFolder = Instance.new("Folder")
        zoneFolder.Name = zoneId
        zoneFolder.Parent = zonesFolder
    end

    return zoneFolder
end

local function formatCost(cost: number): string
    if cost >= 1000000000 then
        return string.format("%.1fB", cost / 1000000000)
    elseif cost >= 1000000 then
        return string.format("%.1fM", cost / 1000000)
    elseif cost >= 1000 then
        return string.format("%.1fK", cost / 1000)
    end
    return tostring(cost)
end

local function createPortal(fromZone, toZone)
    local zoneFolder = getOrCreateZoneFolder(fromZone.Id)
    local portalsFolder = zoneFolder:FindFirstChild("Portals")
    if not portalsFolder then
        portalsFolder = Instance.new("Folder")
        portalsFolder.Name = "Portals"
        portalsFolder.Parent = zoneFolder
    end

    -- Position portal at the edge facing the next zone
    local direction = (toZone.SpawnPosition - fromZone.SpawnPosition).Unit
    local portalPos = fromZone.SpawnPosition + direction * 65 -- near edge of zone

    local portalModel = Instance.new("Model")
    portalModel.Name = "Portal_" .. toZone.Id

    -- Left pillar
    local leftPillar = Instance.new("Part")
    leftPillar.Name = "LeftPillar"
    leftPillar.Size = PILLAR_SIZE
    leftPillar.Anchored = true
    leftPillar.CanCollide = true
    leftPillar.Material = Enum.Material.Marble
    leftPillar.Color = toZone.Color

    local perpendicular = Vector3.new(-direction.Z, 0, direction.X)
    leftPillar.Position = portalPos + perpendicular * (PORTAL_WIDTH / 2) + Vector3.new(0, PORTAL_HEIGHT / 2, 0)
    leftPillar.Parent = portalModel

    -- Right pillar
    local rightPillar = Instance.new("Part")
    rightPillar.Name = "RightPillar"
    rightPillar.Size = PILLAR_SIZE
    rightPillar.Anchored = true
    rightPillar.CanCollide = true
    rightPillar.Material = Enum.Material.Marble
    rightPillar.Color = toZone.Color
    rightPillar.Position = portalPos - perpendicular * (PORTAL_WIDTH / 2) + Vector3.new(0, PORTAL_HEIGHT / 2, 0)
    rightPillar.Parent = portalModel

    -- Arch (top bar)
    local arch = Instance.new("Part")
    arch.Name = "Arch"
    arch.Size = Vector3.new(PORTAL_WIDTH + 2, 2, 2)
    arch.Anchored = true
    arch.CanCollide = true
    arch.Material = Enum.Material.Marble
    arch.Color = toZone.Color
    arch.Position = portalPos + Vector3.new(0, PORTAL_HEIGHT, 0)
    -- Rotate to face perpendicular to travel direction
    arch.CFrame = CFrame.new(arch.Position) * CFrame.lookAt(Vector3.zero, direction)
    arch.Parent = portalModel

    -- Portal surface (semi-transparent, touch to teleport)
    local portalSurface = Instance.new("Part")
    portalSurface.Name = "PortalSurface"
    portalSurface.Size = Vector3.new(PORTAL_WIDTH - 1, PORTAL_HEIGHT - 2, 1)
    portalSurface.Anchored = true
    portalSurface.CanCollide = false
    portalSurface.Material = Enum.Material.Neon
    portalSurface.Color = toZone.Color
    portalSurface.Transparency = 0.5
    portalSurface.Position = portalPos + Vector3.new(0, PORTAL_HEIGHT / 2, 0)
    portalSurface.CFrame = CFrame.new(portalSurface.Position) * CFrame.lookAt(Vector3.zero, direction)
    portalSurface.Parent = portalModel

    -- Billboard GUI
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PortalInfo"
    billboard.Size = UDim2.new(0, 250, 0, 80)
    billboard.StudsOffset = Vector3.new(0, PORTAL_HEIGHT + 3, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent = portalSurface

    local zoneName = Instance.new("TextLabel")
    zoneName.Size = UDim2.new(1, 0, 0.5, 0)
    zoneName.BackgroundTransparency = 1
    zoneName.Text = toZone.Name
    zoneName.TextColor3 = toZone.Color
    zoneName.TextStrokeTransparency = 0
    zoneName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    zoneName.Font = Enum.Font.GothamBold
    zoneName.TextScaled = true
    zoneName.Parent = billboard

    local costInfo = Instance.new("TextLabel")
    costInfo.Size = UDim2.new(1, 0, 0.4, 0)
    costInfo.Position = UDim2.new(0, 0, 0.55, 0)
    costInfo.BackgroundTransparency = 1
    costInfo.TextStrokeTransparency = 0
    costInfo.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    costInfo.Font = Enum.Font.GothamBold
    costInfo.TextScaled = true
    costInfo.Parent = billboard

    if toZone.UnlockCost > 0 then
        costInfo.Text = formatCost(toZone.UnlockCost) .. " " .. toZone.UnlockCurrency
        costInfo.TextColor3 = Color3.fromRGB(255, 220, 80)
    else
        costInfo.Text = "Free"
        costInfo.TextColor3 = Color3.fromRGB(100, 255, 100)
    end

    -- Touch handler
    portalSurface.Touched:Connect(function(hit)
        local character = hit.Parent
        local player = game:GetService("Players"):GetPlayerFromCharacter(character)
        if not player then return end

        -- Cooldown
        local now = tick()
        if portalCooldowns[player] and (now - portalCooldowns[player]) < 2 then
            return
        end
        portalCooldowns[player] = now

        -- Check if zone is unlocked
        if ZoneService.IsZoneUnlocked(player, toZone.Id) then
            -- Teleport
            ZoneService.TeleportToZone(player, toZone.Id)
        else
            -- Try to unlock
            local success = ZoneService.UnlockZone(player, toZone.Id)
            if success then
                ZoneService.TeleportToZone(player, toZone.Id)
            end
        end
    end)

    -- Portal idle animation (pulsing glow)
    task.spawn(function()
        while portalSurface.Parent do
            for t = 0, 1, 0.02 do
                portalSurface.Transparency = 0.4 + math.sin(t * math.pi * 2) * 0.15
                task.wait()
            end
        end
    end)

    portalModel.Parent = portalsFolder
end

function PortalService.Init(dataService, currencyService, zoneService)
    DataService = dataService
    CurrencyService = currencyService
    ZoneService = zoneService

    local zones = ZoneConfig.Zones
    for i = 1, #zones - 1 do
        createPortal(zones[i], zones[i + 1])
    end

    print("[PortalService] Created " .. (#zones - 1) .. " portals")
end

function PortalService.PlayerRemoving(player: Player)
    portalCooldowns[player] = nil
end

return PortalService
