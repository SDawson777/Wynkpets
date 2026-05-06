--[[
    WizardService.luau
    Evil Wizard – a roaming threat that spawns in random zones, chases players,
    and steals one equipped pet from anyone it catches.

    Behaviour summary:
    • Spawns globally once every SPAWN_INTERVAL_MIN to SPAWN_INTERVAL_MAX minutes
    • Picks a random zone that has at least one active player
    • Materialises from a smoke cloud at the zone centre
    • For CHASE_DURATION seconds the wizard moves toward the nearest un-caught player
    • Any player within CATCH_RADIUS studs for CATCH_LINGER seconds is "caught":
        – One random equipped pet is permanently removed
        – Client receives WizardStole with the pet name
    • Players that survive the full duration receive a small coin bonus
    • Wizard then dematerialises back into smoke
    • Only one wizard can be active at a time (global)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network   = require(Shared:WaitForChild("Network"))
local ZoneConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ZoneConfig"))
local PetConfig  = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

-- ── tunables ────────────────────────────────────────────────────────────────
local SPAWN_INTERVAL_MIN = 8 * 60   -- seconds between appearances (minimum)
local SPAWN_INTERVAL_MAX = 15 * 60  -- seconds between appearances (maximum)
local CHASE_DURATION     = 30       -- seconds the wizard is active per visit
local CHASE_SPEED        = 14       -- studs per second the wizard moves
local CATCH_RADIUS       = 5        -- studs to the wizard centre to be caught
local CATCH_LINGER       = 0.5      -- seconds player must stay within radius
local SURVIVE_BONUS_BASE = 500      -- base coins given for surviving

-- ── injected services ────────────────────────────────────────────────────────
local DataService    = nil
local PetService     = nil
local CurrencyService = nil

-- ── state ────────────────────────────────────────────────────────────────────
local wizardActive     = false
local wizardModel      = nil   -- the server-side wizard Parts folder
local wizardCFrame     = CFrame.new()
local wizardZoneId     = nil

-- per-player catch tracking (reset each visit)
-- caughtThisVisit[userId] = true
-- lingerStart[userId]     = time when they entered the radius (reset on exit)
local caughtThisVisit = {}
local lingerStart     = {}

local WizardService = {}

-- ── helpers ──────────────────────────────────────────────────────────────────

local function getPetName(petId: string): string
    for _, def in ipairs(PetConfig.Pets) do
        if def.Id == petId then
            return def.Name
        end
    end
    return petId
end

--- Return a random element from an array (nil if empty).
local function randomFrom(t)
    if #t == 0 then return nil end
    return t[math.random(1, #t)]
end

--- Players currently in a given zone (server-side position check).
local function playersInZone(zoneDef)
    local centre = zoneDef.SpawnPosition
    local result = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local ch = p.Character
        if ch then
            local root = ch:FindFirstChild("HumanoidRootPart")
            if root and math.abs(root.Position.X - centre.X) < 120 then
                table.insert(result, p)
            end
        end
    end
    return result
end

--- Build the wizard's Part-based model in the workspace at `pos`.
local function buildWizard(pos: Vector3)
    local folder = Instance.new("Folder")
    folder.Name = "EvilWizard"
    folder.Parent = Workspace

    -- Robe / body
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(2, 3.5, 1.5)
    body.CFrame = CFrame.new(pos + Vector3.new(0, 1.75, 0))
    body.Anchored = true
    body.CanCollide = false
    body.BrickColor = BrickColor.new("Dark indigo")
    body.Material = Enum.Material.Neon
    body.CastShadow = false
    body.Parent = folder

    local bodyCorner = Instance.new("SpecialMesh")
    bodyCorner.MeshType = Enum.MeshType.Cylinder
    bodyCorner.Parent = body

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(2, 2, 2)
    head.CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0))
    head.Anchored = true
    head.CanCollide = false
    head.BrickColor = BrickColor.new("Institutional white")
    head.Material = Enum.Material.SmoothPlastic
    head.CastShadow = false
    head.Parent = folder

    -- Hat brim
    local hatBrim = Instance.new("Part")
    hatBrim.Name = "HatBrim"
    hatBrim.Size = Vector3.new(2.6, 0.2, 2.6)
    hatBrim.CFrame = CFrame.new(pos + Vector3.new(0, 5.6, 0))
    hatBrim.Anchored = true
    hatBrim.CanCollide = false
    hatBrim.BrickColor = BrickColor.new("Black")
    hatBrim.Material = Enum.Material.SmoothPlastic
    hatBrim.CastShadow = false
    hatBrim.Parent = folder

    -- Hat cone
    local hatCone = Instance.new("Part")
    hatCone.Name = "HatCone"
    hatCone.Size = Vector3.new(1.4, 2.4, 1.4)
    hatCone.CFrame = CFrame.new(pos + Vector3.new(0, 6.8, 0))
    hatCone.Anchored = true
    hatCone.CanCollide = false
    hatCone.BrickColor = BrickColor.new("Black")
    hatCone.Material = Enum.Material.SmoothPlastic
    hatCone.CastShadow = false
    do
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.FileMesh
        m.MeshId   = "rbxasset://fonts/torso.mesh"   -- cone-ish shape
        m.Scale    = Vector3.new(0.7, 1.2, 0.7)
        m.Parent   = hatCone
    end
    hatCone.Parent = folder

    -- Eyes (neon red glow)
    for _, xOff in ipairs({-0.45, 0.45}) do
        local eye = Instance.new("Part")
        eye.Name = "Eye"
        eye.Shape = Enum.PartType.Ball
        eye.Size = Vector3.new(0.4, 0.4, 0.4)
        eye.CFrame = CFrame.new(pos + Vector3.new(xOff, 4.6, -0.85))
        eye.Anchored = true
        eye.CanCollide = false
        eye.Material = Enum.Material.Neon
        eye.BrickColor = BrickColor.new("Bright red")
        eye.CastShadow = false
        eye.Parent = folder
    end

    -- Staff
    local staff = Instance.new("Part")
    staff.Name = "Staff"
    staff.Size = Vector3.new(0.25, 5, 0.25)
    staff.CFrame = CFrame.new(pos + Vector3.new(1.4, 2.5, 0))
    staff.Anchored = true
    staff.CanCollide = false
    staff.BrickColor = BrickColor.new("Reddish brown")
    staff.Material = Enum.Material.Wood
    staff.CastShadow = false
    staff.Parent = folder

    local staffOrb = Instance.new("Part")
    staffOrb.Name = "StaffOrb"
    staffOrb.Shape = Enum.PartType.Ball
    staffOrb.Size = Vector3.new(0.7, 0.7, 0.7)
    staffOrb.CFrame = CFrame.new(pos + Vector3.new(1.4, 5.2, 0))
    staffOrb.Anchored = true
    staffOrb.CanCollide = false
    staffOrb.Material = Enum.Material.Neon
    staffOrb.BrickColor = BrickColor.new("Bright violet")
    staffOrb.CastShadow = false
    staffOrb.Parent = folder

    -- Billboard name tag
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 140, 0, 44)
    bb.StudsOffset = Vector3.new(0, 1.4, 0)
    bb.AlwaysOnTop = false
    bb.Parent = head

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "🧙 Evil Wizard"
    nameLabel.TextColor3 = Color3.fromRGB(255, 80, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = bb

    -- Smoke particles attached to body (using SelectionBox colour trick)
    local smokeAttach = Instance.new("Attachment")
    smokeAttach.Position = Vector3.new(0, 0, 0)
    smokeAttach.Parent = body

    local smoke = Instance.new("ParticleEmitter")
    smoke.Parent = smokeAttach
    smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
    smoke.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 0, 200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 120, 30)),
    })
    smoke.LightEmission = 0.5
    smoke.LightInfluence = 0.3
    smoke.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 2.5),
    })
    smoke.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    smoke.Lifetime = NumberRange.new(0.8, 1.4)
    smoke.Rate = 20
    smoke.Speed = NumberRange.new(4, 8)
    smoke.SpreadAngle = Vector2.new(40, 40)
    smoke.Rotation = NumberRange.new(0, 360)
    smoke.RotSpeed = NumberRange.new(-90, 90)

    return folder
end

--- Move all parts of the wizard model so the body-root lands at `newPos`.
local function setWizardPosition(model, newPos: Vector3)
    local body = model:FindFirstChild("Body")
    if not body then return end
    local delta = newPos - Vector3.new(body.CFrame.X, newPos.Y, body.CFrame.Z)
    -- apply delta to every anchored part
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CFrame = part.CFrame + delta
        end
    end
end

--- Spawn a short-lived smoke burst at a position (used for arrival/departure).
local function spawnSmokePuff(pos: Vector3, colour: Color3)
    for i = 1, 8 do
        local puff = Instance.new("Part")
        puff.Name = "SmokePuff"
        puff.Shape = Enum.PartType.Ball
        puff.Size = Vector3.new(1.5, 1.5, 1.5)
        puff.CFrame = CFrame.new(
            pos + Vector3.new(math.random(-4, 4), math.random(0, 5), math.random(-4, 4))
        )
        puff.Anchored = true
        puff.CanCollide = false
        puff.Material = Enum.Material.Neon
        puff.Color = colour
        puff.Transparency = 0.35
        puff.CastShadow = false
        puff.Parent = Workspace

        -- fade and remove
        task.spawn(function()
            for step = 1, 12 do
                task.wait(0.06)
                if puff and puff.Parent then
                    puff.Transparency = 0.35 + (step / 12) * 0.65
                    puff.Size = puff.Size + Vector3.new(0.25, 0.25, 0.25)
                end
            end
            if puff and puff.Parent then puff:Destroy() end
        end)
    end
end

--- Cleanly remove the wizard model.
local function destroyWizard()
    if wizardModel then
        wizardModel:Destroy()
        wizardModel = nil
    end
end

-- ── main wizard loop ──────────────────────────────────────────────────────────

--- Execute a single wizard visit to `zoneDef`.
local function runWizardVisit(zoneDef)
    if wizardActive then return end
    wizardActive = true
    wizardZoneId = zoneDef.Id

    caughtThisVisit = {}
    lingerStart     = {}

    local spawnPos = zoneDef.SpawnPosition
    local smokeColour = Color3.fromRGB(120, 0, 200)

    -- 1. Arrival smoke
    spawnSmokePuff(spawnPos, smokeColour)
    task.wait(0.6)

    -- 2. Build wizard model
    wizardModel  = buildWizard(spawnPos)
    wizardCFrame = CFrame.new(spawnPos)

    -- 3. Alert all clients
    Network.FireAllClients("WizardSpawned", zoneDef.Id, zoneDef.Name, spawnPos)

    -- 4. Chase loop
    local elapsed = 0
    local tickRate = 0.1   -- seconds between AI updates
    local lastChaseAlert = {} -- [userId] = tick(); throttle WizardChasing to once per 2s

    while elapsed < CHASE_DURATION and wizardActive do
        task.wait(tickRate)
        elapsed += tickRate

        if not wizardModel then break end

        -- find players in this zone that haven't been caught
        local targets = {}
        for _, p in ipairs(playersInZone(zoneDef)) do
            if not caughtThisVisit[p.UserId] then
                table.insert(targets, p)
            end
        end

        if #targets == 0 then break end  -- no more targets; disappear early

        -- find nearest target
        local nearest     = nil
        local nearestDist = math.huge
        local wizPos      = Vector3.new(wizardCFrame.X, wizardCFrame.Y, wizardCFrame.Z)

        for _, p in ipairs(targets) do
            local ch = p.Character
            if ch then
                local root = ch:FindFirstChild("HumanoidRootPart")
                if root then
                    local d = (root.Position - wizPos).Magnitude
                    if d < nearestDist then
                        nearestDist = d
                        nearest     = p
                    end
                end
            end
        end

        if nearest then
            -- Fire chase warning to nearest target (throttled to once per 2s per player)
            if nearestDist < 30 and not caughtThisVisit[nearest.UserId] then
                local now = tick()
                if not lastChaseAlert[nearest.UserId] or (now - lastChaseAlert[nearest.UserId]) >= 2 then
                    lastChaseAlert[nearest.UserId] = now
                    Network.FireClient("WizardChasing", nearest)
                end
            end

            -- move wizard toward nearest
            local ch = nearest.Character
            if ch then
                local root = ch:FindFirstChild("HumanoidRootPart")
                if root then
                    local targetPos = root.Position
                    local dir = (Vector3.new(targetPos.X, wizPos.Y, targetPos.Z) - wizPos)
                    if dir.Magnitude > 0.1 then
                        local step  = math.min(CHASE_SPEED * tickRate, dir.Magnitude)
                        local newPos = wizPos + dir.Unit * step
                        wizardCFrame = CFrame.new(newPos)
                        setWizardPosition(wizardModel, newPos)
                    end
                end
            end

            -- linger / catch check for ALL targets in radius
            for _, p in ipairs(targets) do
                if not caughtThisVisit[p.UserId] then
                    local pch = p.Character
                    if pch then
                        local root = pch:FindFirstChild("HumanoidRootPart")
                        if root then
                            local dist = (root.Position - wizPos).Magnitude
                            if dist <= CATCH_RADIUS then
                                if not lingerStart[p.UserId] then
                                    lingerStart[p.UserId] = elapsed
                                elseif elapsed - lingerStart[p.UserId] >= CATCH_LINGER then
                                    -- ── STEAL ──────────────────────────────
                                    caughtThisVisit[p.UserId] = true
                                    lingerStart[p.UserId] = nil

                                    local data = DataService.GetData(p)
                                    if data then
                                        local equipped = PetService.GetEquippedPets(p)
                                        if #equipped > 0 then
                                            local uuid     = equipped[math.random(1, #equipped)]
                                            -- find pet id for name lookup
                                            local stolenName = "Unknown Pet"
                                            for _, pet in ipairs(data.Pets or {}) do
                                                if pet.UUID == uuid then
                                                    stolenName = getPetName(pet.PetId)
                                                    break
                                                end
                                            end
                                            PetService.RemovePet(p, uuid)
                                            Network.FireClient("WizardStole", p, stolenName)
                                        else
                                            -- no equipped pet; still mark caught so wizard moves on
                                            Network.FireClient("WizardStole", p, nil)
                                        end
                                    end
                                end
                            else
                                lingerStart[p.UserId] = nil  -- left the radius
                            end
                        end
                    end
                end
            end
        end
    end

    -- 5. Departure smoke
    if wizardModel then
        local body = wizardModel:FindFirstChild("Body")
        local pos  = body and Vector3.new(body.CFrame.X, body.CFrame.Y, body.CFrame.Z) or spawnPos
        spawnSmokePuff(pos, smokeColour)
    end

    task.wait(0.4)
    destroyWizard()

    -- 6. Survived bonus for every player in zone who wasn't caught
    local survivors = playersInZone(zoneDef)
    for _, p in ipairs(survivors) do
        if not caughtThisVisit[p.UserId] then
            -- scale bonus by zone order
            local bonus = math.floor(SURVIVE_BONUS_BASE * (zoneDef.Order or 1) * 0.8)
            CurrencyService.Add(p, "Coins", bonus)
            Network.FireClient("WizardSurvived", p, bonus)
        end
    end

    -- 7. All-clear broadcast
    Network.FireAllClients("WizardDespawned")

    wizardActive  = false
    wizardZoneId  = nil
end

-- ── spawn scheduler ───────────────────────────────────────────────────────────

local function pickZoneWithPlayers()
    -- shuffle zones so selection is random
    local zones = {}
    for _, z in ipairs(ZoneConfig.Zones) do
        table.insert(zones, z)
    end
    -- Fisher-Yates
    for i = #zones, 2, -1 do
        local j = math.random(1, i)
        zones[i], zones[j] = zones[j], zones[i]
    end
    for _, z in ipairs(zones) do
        if #playersInZone(z) > 0 then
            return z
        end
    end
    return nil   -- no players in any zone
end

local function scheduleLoop()
    while true do
        local delay = math.random(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
        task.wait(delay)

        if not wizardActive then
            local zone = pickZoneWithPlayers()
            if zone then
                task.spawn(function()
                    local ok, err = pcall(runWizardVisit, zone)
                    if not ok then
                        warn("[WizardService] visit error:", err)
                        destroyWizard()
                        Network.FireAllClients("WizardDespawned")
                        wizardActive = false
                    end
                end)
            end
        end
    end
end

-- ── public API ────────────────────────────────────────────────────────────────

--- Force a wizard visit right now (for admin/testing).
function WizardService.ForceSpawn(zoneId: string?)
    if wizardActive then
        warn("[WizardService] Already active – ignoring ForceSpawn")
        return
    end
    local zone
    if zoneId then
        for _, z in ipairs(ZoneConfig.Zones) do
            if z.Id == zoneId then zone = z; break end
        end
    else
        zone = pickZoneWithPlayers() or ZoneConfig.Zones[1]
    end
    if zone then
        task.spawn(function()
            local ok, err = pcall(runWizardVisit, zone)
            if not ok then
                warn("[WizardService] ForceSpawn error:", err)
                destroyWizard()
                Network.FireAllClients("WizardDespawned")
                wizardActive = false
            end
        end)
    end
end

function WizardService.Init(ds, ps, cs)
    DataService     = ds
    PetService      = ps
    CurrencyService = cs

    if not LaunchConfig.IsFeatureEnabled("Wizard") then
        print("[LaunchConfig] WizardService disabled — spawn loop not started")
        return
    end

    -- kick off the random-interval scheduler
    task.spawn(scheduleLoop)

    -- admin command hook: "spawnwizard [zoneId]"
    Network.OnServerEvent("AdminCommand", function(player, cmd, ...)
        -- AdminService also handles this; we only care about wizard commands
        if type(cmd) ~= "string" then return end
        local lower = cmd:lower()
        if lower == "spawnwizard" then
            local data = DataService and DataService.GetData(player)
            if data and data.IsAdmin then
                local args = {...}
                WizardService.ForceSpawn(args[1])
            end
        end
    end)
end

return WizardService
