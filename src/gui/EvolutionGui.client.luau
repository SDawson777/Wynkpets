--[[
    EvolutionGui.client.luau
    Three-path evolution system UI.

    Layout:
        • Header — title, phase info, pity counter
        • Materials bar — WynkShards | MoonEssence | StormCrystal
        • Eligible pets panel (left) — scrollable pet cards
        • Evolution detail (right) — paths for selected pet, evolve button

    Network events:
        RequestEvolutionData   Client → Server  (refresh on open)
        RequestEvolve          Client → Server  (uuid, path)
        EvolutionData          Server → Client  snapshot
        EvolveResult           Server → Client  result
        EvolutionMaterialsUpdated  Server → Client  partial update
]]

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared        = ReplicatedStorage:WaitForChild("Shared")

local Network      = require(Shared:WaitForChild("Network"))
local PetConfig    = require(Shared:WaitForChild("Configs"):WaitForChild("PetConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── State ─────────────────────────────────────────────────────────────────────

local evoData       = nil   -- last EvolutionData snapshot
local selectedPet   = nil   -- eligible pet entry currently shown in detail panel

-- ── Colors ───────────────────────────────────────────────────────────────────

local COL_BG        = Color3.fromRGB(14, 18, 30)
local COL_PANEL     = Color3.fromRGB(20, 25, 42)
local COL_ACCENT    = Color3.fromRGB(130, 70, 220)
local COL_FREE      = Color3.fromRGB(60, 190, 100)
local COL_SPEED     = Color3.fromRGB(220, 165, 30)
local COL_DIRECT    = Color3.fromRGB(220, 60, 60)
local COL_LOCKED    = Color3.fromRGB(80, 80, 100)
local COL_WARN      = Color3.fromRGB(220, 100, 30)
local COL_SHARD     = Color3.fromRGB(160, 220, 255)
local COL_MOON      = Color3.fromRGB(180, 120, 255)
local COL_STORM     = Color3.fromRGB(100, 200, 255)

local MAT_META = {
    WynkShards   = { Label = "Wynk Shards",   Icon = "✨", Color = COL_SHARD },
    MoonEssence  = { Label = "Moon Essence",  Icon = "🌙", Color = COL_MOON  },
    StormCrystal = { Label = "Storm Crystal", Icon = "⚡", Color = COL_STORM },
}

-- ── Screen GUI ────────────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EvolutionGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 860, 0, 500)
mainFrame.Position = UDim2.new(0.5, -430, 0.5, -250)
mainFrame.BackgroundColor3 = COL_BG
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 18)
mfCorner.Parent = mainFrame

local mfStroke = Instance.new("UIStroke")
mfStroke.Color = COL_ACCENT
mfStroke.Thickness = 2.5
mfStroke.Parent = mainFrame

-- ── Header ────────────────────────────────────────────────────────────────────

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 62)
header.BackgroundColor3 = Color3.fromRGB(20, 12, 36)
header.BorderSizePixel = 0
header.Parent = mainFrame

local hStroke = Instance.new("UIStroke")
hStroke.Color = COL_ACCENT
hStroke.Thickness = 1
hStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
hStroke.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.55, 0, 0.65, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✨ Evolution Chamber"
titleLabel.TextColor3 = Color3.fromRGB(210, 160, 255)
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 22
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Size = UDim2.new(0.55, 0, 0.35, 0)
phaseLabel.Position = UDim2.new(0, 16, 0.65, 0)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Text = "Loading..."
phaseLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
phaseLabel.Font = Enum.Font.Gotham
phaseLabel.TextSize = 12
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseLabel.Parent = header

local pityLabel = Instance.new("TextLabel")
pityLabel.Size = UDim2.new(0.22, 0, 1, 0)
pityLabel.Position = UDim2.new(0.56, 0, 0, 0)
pityLabel.BackgroundTransparency = 1
pityLabel.Text = ""
pityLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
pityLabel.Font = Enum.Font.Gotham
pityLabel.TextSize = 12
pityLabel.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -44, 0, 15)
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 25, 70)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 8)
cbCorner.Parent = closeBtn

-- ── Materials Bar ─────────────────────────────────────────────────────────────

local matBar = Instance.new("Frame")
matBar.Size = UDim2.new(1, -32, 0, 44)
matBar.Position = UDim2.new(0, 16, 0, 70)
matBar.BackgroundColor3 = COL_PANEL
matBar.BorderSizePixel = 0
matBar.Parent = mainFrame

local mbCorner = Instance.new("UICorner")
mbCorner.CornerRadius = UDim.new(0, 10)
mbCorner.Parent = matBar

local mbStroke = Instance.new("UIStroke")
mbStroke.Color = COL_ACCENT
mbStroke.Thickness = 1
mbStroke.Parent = matBar

local matLabels = {}
local matKeys = { "WynkShards", "MoonEssence", "StormCrystal" }
for i, matId in ipairs(matKeys) do
    local meta = MAT_META[matId]
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.33, -8, 1, 0)
    lbl.Position = UDim2.new((i-1) * 0.333, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = meta.Icon .. " " .. meta.Label .. ": 0"
    lbl.TextColor3 = meta.Color
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.Parent = matBar
    matLabels[matId] = lbl
end

-- ── Left Panel: Eligible Pets ─────────────────────────────────────────────────

local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0, 260, 0, 350)
leftPanel.Position = UDim2.new(0, 16, 0, 124)
leftPanel.BackgroundColor3 = COL_PANEL
leftPanel.BorderSizePixel = 0
leftPanel.Parent = mainFrame

local lpCorner = Instance.new("UICorner")
lpCorner.CornerRadius = UDim.new(0, 12)
lpCorner.Parent = leftPanel

local lpStroke = Instance.new("UIStroke")
lpStroke.Color = COL_ACCENT
lpStroke.Thickness = 1
lpStroke.Parent = leftPanel

local lpTitle = Instance.new("TextLabel")
lpTitle.Size = UDim2.new(1, 0, 0, 30)
lpTitle.BackgroundColor3 = Color3.fromRGB(25, 15, 45)
lpTitle.Text = "Eligible Pets"
lpTitle.TextColor3 = Color3.fromRGB(200, 160, 255)
lpTitle.Font = Enum.Font.GothamBlack
lpTitle.TextSize = 14
lpTitle.BorderSizePixel = 0
lpTitle.Parent = leftPanel

local lpCorner2 = Instance.new("UICorner")
lpCorner2.CornerRadius = UDim.new(0, 12)
lpCorner2.Parent = lpTitle

local petScroll = Instance.new("ScrollingFrame")
petScroll.Size = UDim2.new(1, -10, 1, -38)
petScroll.Position = UDim2.new(0, 5, 0, 34)
petScroll.BackgroundTransparency = 1
petScroll.BorderSizePixel = 0
petScroll.ScrollBarThickness = 4
petScroll.ScrollBarImageColor3 = COL_ACCENT
petScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
petScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
petScroll.Parent = leftPanel

local petList = Instance.new("UIListLayout")
petList.SortOrder = Enum.SortOrder.LayoutOrder
petList.Padding = UDim.new(0, 6)
petList.Parent = petScroll

-- ── Right Panel: Evolution Detail ────────────────────────────────────────────

local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(1, -296, 0, 350)
rightPanel.Position = UDim2.new(0, 284, 0, 124)
rightPanel.BackgroundColor3 = COL_PANEL
rightPanel.BorderSizePixel = 0
rightPanel.Parent = mainFrame

local rpCorner = Instance.new("UICorner")
rpCorner.CornerRadius = UDim.new(0, 12)
rpCorner.Parent = rightPanel

local rpStroke = Instance.new("UIStroke")
rpStroke.Color = COL_ACCENT
rpStroke.Thickness = 1
rpStroke.Parent = rightPanel

-- No-selection placeholder
local noSelectLabel = Instance.new("TextLabel")
noSelectLabel.Size = UDim2.new(1, 0, 1, 0)
noSelectLabel.BackgroundTransparency = 1
noSelectLabel.Text = "← Select a pet to evolve"
noSelectLabel.TextColor3 = Color3.fromRGB(100, 100, 130)
noSelectLabel.Font = Enum.Font.GothamBold
noSelectLabel.TextSize = 18
noSelectLabel.Parent = rightPanel

-- Detail content (hidden until a pet is selected)
local detailFrame = Instance.new("Frame")
detailFrame.Size = UDim2.new(1, 0, 1, 0)
detailFrame.BackgroundTransparency = 1
detailFrame.Visible = false
detailFrame.Parent = rightPanel

local petNameLabel = Instance.new("TextLabel")
petNameLabel.Size = UDim2.new(1, -20, 0, 32)
petNameLabel.Position = UDim2.new(0, 10, 0, 10)
petNameLabel.BackgroundTransparency = 1
petNameLabel.Text = "Pet Name"
petNameLabel.TextColor3 = Color3.new(1, 1, 1)
petNameLabel.Font = Enum.Font.GothamBlack
petNameLabel.TextSize = 20
petNameLabel.TextXAlignment = Enum.TextXAlignment.Left
petNameLabel.Parent = detailFrame

local arrowLabel = Instance.new("TextLabel")
arrowLabel.Size = UDim2.new(1, -20, 0, 24)
arrowLabel.Position = UDim2.new(0, 10, 0, 44)
arrowLabel.BackgroundTransparency = 1
arrowLabel.Text = "→ Evolved Form"
arrowLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
arrowLabel.Font = Enum.Font.GothamBold
arrowLabel.TextSize = 14
arrowLabel.TextXAlignment = Enum.TextXAlignment.Left
arrowLabel.Parent = detailFrame

-- Path A: Free
local freePathFrame = Instance.new("Frame")
freePathFrame.Size = UDim2.new(1, -20, 0, 76)
freePathFrame.Position = UDim2.new(0, 10, 0, 78)
freePathFrame.BackgroundColor3 = Color3.fromRGB(22, 40, 28)
freePathFrame.BorderSizePixel = 0
freePathFrame.Parent = detailFrame

local fpcCorner = Instance.new("UICorner")
fpcCorner.CornerRadius = UDim.new(0, 10)
fpcCorner.Parent = freePathFrame

local fpStroke = Instance.new("UIStroke")
fpStroke.Color = COL_FREE
fpStroke.Thickness = 1.5
fpStroke.Parent = freePathFrame

local freePathTitle = Instance.new("TextLabel")
freePathTitle.Size = UDim2.new(1, -10, 0, 20)
freePathTitle.Position = UDim2.new(0, 8, 0, 5)
freePathTitle.BackgroundTransparency = 1
freePathTitle.Text = "✨ Path A — Free Grind"
freePathTitle.TextColor3 = COL_FREE
freePathTitle.Font = Enum.Font.GothamBold
freePathTitle.TextSize = 13
freePathTitle.TextXAlignment = Enum.TextXAlignment.Left
freePathTitle.Parent = freePathFrame

local freeCostLabel = Instance.new("TextLabel")
freeCostLabel.Size = UDim2.new(0.65, 0, 0, 18)
freeCostLabel.Position = UDim2.new(0, 8, 0, 26)
freeCostLabel.BackgroundTransparency = 1
freeCostLabel.Text = "Cost: —"
freeCostLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
freeCostLabel.Font = Enum.Font.Gotham
freeCostLabel.TextSize = 12
freeCostLabel.TextXAlignment = Enum.TextXAlignment.Left
freeCostLabel.Parent = freePathFrame

local freeEvolveBtn = Instance.new("TextButton")
freeEvolveBtn.Size = UDim2.new(0, 110, 0, 28)
freeEvolveBtn.Position = UDim2.new(1, -118, 0.5, -14)
freeEvolveBtn.Text = "Evolve Free"
freeEvolveBtn.Font = Enum.Font.GothamBlack
freeEvolveBtn.TextSize = 12
freeEvolveBtn.TextColor3 = Color3.new(1, 1, 1)
freeEvolveBtn.BorderSizePixel = 0
freeEvolveBtn.Parent = freePathFrame

local febCorner = Instance.new("UICorner")
febCorner.CornerRadius = UDim.new(0, 8)
febCorner.Parent = freeEvolveBtn

local missingLabel = Instance.new("TextLabel")
missingLabel.Size = UDim2.new(0.65, 0, 0, 18)
missingLabel.Position = UDim2.new(0, 8, 0, 46)
missingLabel.BackgroundTransparency = 1
missingLabel.Text = ""
missingLabel.TextColor3 = Color3.fromRGB(255, 120, 80)
missingLabel.Font = Enum.Font.Gotham
missingLabel.TextSize = 11
missingLabel.TextXAlignment = Enum.TextXAlignment.Left
missingLabel.Parent = freePathFrame

-- Path C: Direct Robux
local directPathFrame = Instance.new("Frame")
directPathFrame.Size = UDim2.new(1, -20, 0, 56)
directPathFrame.Position = UDim2.new(0, 10, 0, 166)
directPathFrame.BackgroundColor3 = Color3.fromRGB(38, 18, 18)
directPathFrame.BorderSizePixel = 0
directPathFrame.Parent = detailFrame

local dpcCorner = Instance.new("UICorner")
dpcCorner.CornerRadius = UDim.new(0, 10)
dpcCorner.Parent = directPathFrame

local dpStroke = Instance.new("UIStroke")
dpStroke.Color = COL_DIRECT
dpStroke.Thickness = 1.5
dpStroke.Parent = directPathFrame

local directPathTitle = Instance.new("TextLabel")
directPathTitle.Size = UDim2.new(0.65, 0, 0, 20)
directPathTitle.Position = UDim2.new(0, 8, 0, 5)
directPathTitle.BackgroundTransparency = 1
directPathTitle.Text = "⚡ Path C — Instant Evolve"
directPathTitle.TextColor3 = COL_DIRECT
directPathTitle.Font = Enum.Font.GothamBold
directPathTitle.TextSize = 13
directPathTitle.TextXAlignment = Enum.TextXAlignment.Left
directPathTitle.Parent = directPathFrame

local directRobuxLabel = Instance.new("TextLabel")
directRobuxLabel.Size = UDim2.new(0.65, 0, 0, 16)
directRobuxLabel.Position = UDim2.new(0, 8, 0, 28)
directRobuxLabel.BackgroundTransparency = 1
directRobuxLabel.Text = ""
directRobuxLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
directRobuxLabel.Font = Enum.Font.Gotham
directRobuxLabel.TextSize = 11
directRobuxLabel.TextXAlignment = Enum.TextXAlignment.Left
directRobuxLabel.Parent = directPathFrame

local directEvolveBtn = Instance.new("TextButton")
directEvolveBtn.Size = UDim2.new(0, 110, 0, 28)
directEvolveBtn.Position = UDim2.new(1, -118, 0.5, -14)
directEvolveBtn.Text = "Buy & Evolve"
directEvolveBtn.Font = Enum.Font.GothamBlack
directEvolveBtn.TextSize = 11
directEvolveBtn.TextColor3 = Color3.new(1, 1, 1)
directEvolveBtn.BackgroundColor3 = COL_DIRECT
directEvolveBtn.BorderSizePixel = 0
directEvolveBtn.Parent = directPathFrame

local debCorner = Instance.new("UICorner")
debCorner.CornerRadius = UDim.new(0, 8)
debCorner.Parent = directEvolveBtn

-- Phase warning (shown when not climax phase)
local phaseWarnFrame = Instance.new("Frame")
phaseWarnFrame.Size = UDim2.new(1, -20, 0, 48)
phaseWarnFrame.Position = UDim2.new(0, 10, 0, 234)
phaseWarnFrame.BackgroundColor3 = Color3.fromRGB(40, 30, 10)
phaseWarnFrame.BorderSizePixel = 0
phaseWarnFrame.Visible = false
phaseWarnFrame.Parent = detailFrame

local pwCorner = Instance.new("UICorner")
pwCorner.CornerRadius = UDim.new(0, 10)
pwCorner.Parent = phaseWarnFrame

local phaseWarnLabel = Instance.new("TextLabel")
phaseWarnLabel.Size = UDim2.new(1, -16, 1, 0)
phaseWarnLabel.Position = UDim2.new(0, 8, 0, 0)
phaseWarnLabel.BackgroundTransparency = 1
phaseWarnLabel.Text = "⏳ Evolution opens Friday–Sunday (Climax phase).\nGrind shards now to be ready!"
phaseWarnLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
phaseWarnLabel.Font = Enum.Font.Gotham
phaseWarnLabel.TextSize = 12
phaseWarnLabel.TextWrapped = true
phaseWarnLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseWarnLabel.Parent = phaseWarnFrame

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function formatCost(costTable): string
    if not costTable then return "None" end
    local parts = {}
    for matId, amt in pairs(costTable) do
        local meta = MAT_META[matId]
        table.insert(parts, (meta and meta.Icon or "") .. amt .. " " .. (meta and meta.Label or matId))
    end
    return table.concat(parts, "  |  ")
end

-- ── Populate Detail Panel ─────────────────────────────────────────────────────

local function showPetDetail(ent)
    selectedPet = ent
    noSelectLabel.Visible = false
    detailFrame.Visible   = true

    local petInfo  = PetConfig.GetPet(ent.PetId)
    local evoInfo  = PetConfig.GetPet(ent.EvolvedId)

    petNameLabel.Text = (petInfo and petInfo.Name or ent.PetId) .. " (Lv." .. ent.Level .. ")"
    arrowLabel.Text   = "→ " .. (evoInfo and evoInfo.Name or ent.EvolvedId)

    -- Free path cost
    freeCostLabel.Text = "Cost: " .. formatCost(ent.FreeCost)

    if ent.CanAffordFree then
        freeEvolveBtn.BackgroundColor3 = COL_FREE
        freeEvolveBtn.Text = "Evolve Free"
        freeEvolveBtn.Active = true
        missingLabel.Text = ""
    else
        freeEvolveBtn.BackgroundColor3 = COL_LOCKED
        freeEvolveBtn.Text = "Can't Afford"
        freeEvolveBtn.Active = false
        local missing = {}
        for matId, needed in pairs(ent.MissingCost or {}) do
            local meta = MAT_META[matId]
            table.insert(missing, "Need +" .. needed .. " " .. (meta and meta.Icon or "") .. (meta and meta.Label or matId))
        end
        missingLabel.Text = #missing > 0 and table.concat(missing, "  ") or ""
    end

    -- Direct path cost
    if ent.DirectRobux and ent.DirectRobux > 0 then
        directPathFrame.Visible = true
        directRobuxLabel.Text = "Instant evolution — R$" .. ent.DirectRobux
    else
        directPathFrame.Visible = false
    end

    -- Phase warning (only Free path available during prep; Direct is always available)
    local phase = evoData and evoData.Phase or "prep"
    phaseWarnFrame.Visible = (phase ~= "climax")
    if phase ~= "climax" then
        freeEvolveBtn.Active = false
        freeEvolveBtn.BackgroundColor3 = COL_WARN
        freeEvolveBtn.Text = "Fri–Sun Only"
    end
end

-- ── Button Handlers ───────────────────────────────────────────────────────────

freeEvolveBtn.MouseButton1Click:Connect(function()
    if not selectedPet then return end
    if not evoData or evoData.Phase ~= "climax" then
        -- Already shown in warning but guard anyway
        return
    end
    freeEvolveBtn.Active = false
    freeEvolveBtn.Text = "Evolving…"
    Network.FireServer("RequestEvolve", selectedPet.UUID, "free")
end)

directEvolveBtn.MouseButton1Click:Connect(function()
    if not selectedPet then return end
    Network.FireServer("RequestEvolve", selectedPet.UUID, "direct")
end)

-- ── Eligible Pet Cards ────────────────────────────────────────────────────────

local function clearPetList()
    for _, child in ipairs(petScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    selectedPet = nil
    noSelectLabel.Visible = true
    detailFrame.Visible   = false
end

local function buildPetCards(eligible)
    clearPetList()

    if #eligible == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 50)
        empty.BackgroundTransparency = 1
        empty.Text = "No pets eligible\nthis window"
        empty.TextColor3 = Color3.fromRGB(120, 120, 140)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 13
        empty.TextWrapped = true
        empty.TextXAlignment = Enum.TextXAlignment.Center
        empty.Parent = petScroll
        return
    end

    for i, ent in ipairs(eligible) do
        local petInfo = PetConfig.GetPet(ent.PetId)

        local card = Instance.new("TextButton")
        card.Size = UDim2.new(1, -8, 0, 56)
        card.LayoutOrder = i
        card.BackgroundColor3 = ent.CanAffordFree and Color3.fromRGB(25, 42, 30) or Color3.fromRGB(28, 28, 44)
        card.BorderSizePixel = 0
        card.Text = ""
        card.AutoButtonColor = false
        card.Parent = petScroll

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = ent.CanAffordFree and COL_FREE or Color3.fromRGB(80, 80, 110)
        cStroke.Thickness = 1
        cStroke.Parent = card

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -8, 0, 20)
        nameLabel.Position = UDim2.new(0, 6, 0, 6)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = (petInfo and petInfo.Name or ent.PetId) .. " → " .. ent.EvolvedId
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card

        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(1, -8, 0, 16)
        statusLabel.Position = UDim2.new(0, 6, 0, 28)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = ent.CanAffordFree and "✅ Ready to evolve!" or "⚠️ Need more materials"
        statusLabel.TextColor3 = ent.CanAffordFree and COL_FREE or COL_WARN
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.TextSize = 11
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.Parent = card

        card.MouseButton1Click:Connect(function()
            -- Highlight selected card
            for _, c in ipairs(petScroll:GetChildren()) do
                if c:IsA("TextButton") then
                    c.BackgroundColor3 = Color3.fromRGB(28, 28, 44)
                end
            end
            card.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
            showPetDetail(ent)
        end)
    end
end

-- ── Refresh UI from evoData ───────────────────────────────────────────────────

local function refreshUI()
    if not evoData then return end

    -- Materials bar
    local mats = evoData.Materials or {}
    for matId, lbl in pairs(matLabels) do
        local meta = MAT_META[matId]
        lbl.Text = meta.Icon .. " " .. meta.Label .. ": " .. (mats[matId] or 0)
    end

    -- Phase / pity
    local phase    = evoData.Phase or "prep"
    local evType   = evoData.EventType or "none"
    local pity     = evoData.PityWindows or 0

    if evType == "EvolutionWeekend" then
        if phase == "climax" then
            phaseLabel.Text = "🟢 Evolution Weekend OPEN — Fri–Sun"
        else
            phaseLabel.Text = "🟡 Evolution Weekend (Prep phase — weekend opens Friday)"
        end
    else
        phaseLabel.Text = "⏳ No Evolution Window active right now"
    end

    if pity > 0 then
        pityLabel.Text = "🔥 Pity ×" .. (1 + pity * 0.5) .. " shard boost!"
    else
        pityLabel.Text = ""
    end

    buildPetCards(evoData.EligiblePets or {})
end

-- ── Open / Close ──────────────────────────────────────────────────────────────

local function open()
    if not LaunchConfig.IsFeatureEnabled("Evolution") then
        local toast = Instance.new("ScreenGui")
        toast.DisplayOrder = 100
        toast.Parent = playerGui
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 380, 0, 48)
        lbl.Position = UDim2.new(0.5, -190, 0.8, 0)
        lbl.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
        lbl.TextColor3 = Color3.fromRGB(200, 160, 255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 15
        lbl.Text = "✨ Evolution Chamber unlocks May 6!"
        lbl.BorderSizePixel = 0
        lbl.Parent = toast
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = lbl
        task.delay(3, function() toast:Destroy() end)
        return
    end

    screenGui.Enabled = true
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 860, 0, 500),
        Position = UDim2.new(0.5, -430, 0.5, -250),
    }):Play()
    Network.FireServer("RequestEvolutionData")
end

local function close()
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    })
    tween:Play()
    tween.Completed:Wait()
    screenGui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(close)
overlay.MouseButton1Click:Connect(close)

-- ── Network Handlers ──────────────────────────────────────────────────────────

Network.OnClientEvent("EvolutionData", function(snapshot)
    evoData = snapshot
    if screenGui.Enabled then refreshUI() end
end)

Network.OnClientEvent("EvolutionMaterialsUpdated", function(partial)
    if not evoData then evoData = { Materials = {} } end
    evoData.Materials = evoData.Materials or {}
    for matId, val in pairs(partial) do
        evoData.Materials[matId] = val
    end
    -- Update material labels live (even when GUI is closed)
    for matId, lbl in pairs(matLabels) do
        local meta = MAT_META[matId]
        lbl.Text = meta.Icon .. " " .. meta.Label .. ": " .. (evoData.Materials[matId] or 0)
    end
end)

Network.OnClientEvent("EvolveResult", function(result)
    if result.Success then
        -- Re-request fresh data (pet list changed)
        task.delay(0.2, function()
            if screenGui.Enabled then
                Network.FireServer("RequestEvolutionData")
            end
        end)
        -- Reset button state
        freeEvolveBtn.Text = "Evolve Free"
        freeEvolveBtn.Active = true
    else
        freeEvolveBtn.Text = "Evolve Free"
        freeEvolveBtn.Active = true
    end
end)

-- ── Side Button Wiring ────────────────────────────────────────────────────────

task.spawn(function()
    local mainHud = playerGui:WaitForChild("MainHUD", 30)
    if not mainHud then return end
    local sideButtons = mainHud:WaitForChild("SideButtons", 10)
    if not sideButtons then return end
    local btn = sideButtons:FindFirstChild("EvolutionButton")
    if btn then
        btn.MouseButton1Click:Connect(open)
    end
end)

print("[GUI] EvolutionGui loaded")
