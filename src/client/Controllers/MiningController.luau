-- MiningController.luau
-- Handles player input for mining (click/tap on rocks) and sends MineRock events.

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData  = require(script.Parent.ClientData)
local MiningConfig = require(ReplicatedStorage.Shared.Config.MiningConfig)

local Events      = ReplicatedStorage.Shared.Remotes.Events
local MineRockEvent = Events:WaitForChild("MineRock", 30)

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

local MiningController = {}

-- ─── Mining cooldown (client-side prediction) ─────────────────────────────────
local lastSwing = 0
local BASE_INTERVAL = MiningConfig.BaseMineInterval

local function canSwing(): boolean
    local now = tick()
    if now - lastSwing < BASE_INTERVAL - 0.05 then return false end
    lastSwing = now
    return true
end

-- ─── Raycast to find the clicked rock ────────────────────────────────────────

local function tryMineRock()
    if not canSwing() then return end

    local data = ClientData.data
    if not data then return end

    -- Raycast from camera through mouse
    local camera  = workspace.CurrentCamera
    local unitRay = camera:ScreenPointToRay(Mouse.X, Mouse.Y)
    local params  = RaycastParams.new()
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
    if not result then return end

    local hit = result.Instance
    -- Walk up to find a rock model (tagged with Attribute "RockId")
    local model = hit
    while model and not model:GetAttribute("RockId") do
        model = model.Parent
    end
    if not model then return end

    local rockId = model:GetAttribute("RockId")
    if not rockId then return end

    -- Validate rock is in current world
    for _, rock in ipairs(MiningConfig.Rocks) do
        if rock.id == rockId and rock.world == data.CurrentWorld then
            MineRockEvent:FireServer(rockId)
            -- Client-side visual feedback (shake/flash the part)
            task.spawn(function()
                local originalCFrame = model:IsA("Model") and model.PrimaryPart and model.PrimaryPart.CFrame
                if not originalCFrame then return end
                for i = 1, 3 do
                    model.PrimaryPart.CFrame = originalCFrame + Vector3.new(
                        math.random(-2, 2) * 0.05,
                        math.random(-2, 2) * 0.05,
                        0
                    )
                    task.wait(0.03)
                end
                model.PrimaryPart.CFrame = originalCFrame
            end)
            return
        end
    end
end

-- ─── Input handling ───────────────────────────────────────────────────────────

Mouse.Button1Down:Connect(tryMineRock)

UserInputService.TouchTap:Connect(function(positions)
    -- Mobile tap: simulate a mouse click at the tap position
    local pos = positions[1]
    if pos then
        local camera  = workspace.CurrentCamera
        local unitRay = camera:ScreenPointToRay(pos.X, pos.Y)
        local params  = RaycastParams.new()
        params.FilterDescendantsInstances = { LocalPlayer.Character }
        params.FilterType = Enum.RaycastFilterType.Exclude

        local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
        if not result then return end
        local hit   = result.Instance
        local model = hit
        while model and not model:GetAttribute("RockId") do
            model = model.Parent
        end
        if not model then return end
        local rockId = model:GetAttribute("RockId")
        if rockId then
            MineRockEvent:FireServer(rockId)
        end
    end
end)

return MiningController
