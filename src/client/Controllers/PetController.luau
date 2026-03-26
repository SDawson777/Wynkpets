-- PetController.luau
-- Client-side pet inventory and egg hatching UI.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientData  = require(script.Parent.ClientData)
local UIController = require(script.Parent.UIController)
local PetConfig   = require(ReplicatedStorage.Shared.Config.PetConfig)
local EggConfig   = require(ReplicatedStorage.Shared.Config.EggConfig)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Events      = ReplicatedStorage.Shared.Remotes.Events

local PetController = {}

-- ─── Rarity colour map ────────────────────────────────────────────────────────

local function rarityColor(rarity: string): Color3
    local r = PetConfig.RarityById[rarity]
    return r and r.color or Color3.fromRGB(200, 200, 200)
end

-- ─── Build Pet Inventory GUI ──────────────────────────────────────────────────

local function buildPetGui()
    local screenGui          = Instance.new("ScreenGui")
    screenGui.Name           = "PetGui"
    screenGui.ResetOnSpawn   = false
    screenGui.Enabled        = false
    screenGui.Parent         = PlayerGui

    local mainFrame              = Instance.new("Frame")
    mainFrame.Name               = "MainFrame"
    mainFrame.Size               = UDim2.new(0, 500, 0, 420)
    mainFrame.Position           = UDim2.new(0.5, -250, 0.5, -210)
    mainFrame.BackgroundColor3   = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel    = 0
    mainFrame.Parent             = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

    -- Title
    local title       = Instance.new("TextLabel")
    title.Name        = "Title"
    title.Size        = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text        = "🐾 Pet Inventory"
    title.TextColor3  = Color3.fromRGB(255, 255, 255)
    title.TextScaled  = true
    title.Font        = Enum.Font.GothamBold
    title.Parent      = mainFrame

    -- Close button
    local closeBtn    = Instance.new("TextButton")
    closeBtn.Name     = "CloseBtn"
    closeBtn.Size     = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -40, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel  = 0
    closeBtn.Text     = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font     = Enum.Font.GothamBold
    closeBtn.Parent   = mainFrame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

    -- Scroll frame for pets
    local scroll        = Instance.new("ScrollingFrame")
    scroll.Name         = "PetScroll"
    scroll.Size         = UDim2.new(1, -16, 1, -48)
    scroll.Position     = UDim2.new(0, 8, 0, 44)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize   = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent       = mainFrame

    local grid          = Instance.new("UIGridLayout", scroll)
    grid.CellSize       = UDim2.new(0, 90, 0, 110)
    grid.CellPadding    = UDim2.new(0, 8, 0, 8)
    grid.SortOrder      = Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding", scroll).PaddingLeft = UDim.new(0, 6)

    PetController.petScroll = scroll
    PetController.petGui    = screenGui
end

-- ─── Refresh pet grid ────────────────────────────────────────────────────────

function PetController.refresh()
    local scroll = PetController.petScroll
    if not scroll then return end
    -- Clear existing cards
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local data = ClientData.data
    if not data then return end

    for _, petInst in ipairs(data.Pets) do
        local petDef  = PetConfig.ById[petInst.petId]
        local name    = petDef and petDef.name  or petInst.petId
        local rarity  = petInst.rarity
        local color   = rarityColor(rarity)
        local equipped= table.find(data.EquippedPets, petInst.uid) ~= nil

        local card     = Instance.new("Frame")
        card.Size      = UDim2.new(0, 90, 0, 110)
        card.BackgroundColor3 = equipped and Color3.fromRGB(60, 60, 100) or Color3.fromRGB(40, 40, 55)
        card.BorderSizePixel = 0
        card.Parent    = scroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        -- Rarity stripe
        local stripe   = Instance.new("Frame")
        stripe.Size    = UDim2.new(1, 0, 0, 6)
        stripe.BackgroundColor3 = color
        stripe.BorderSizePixel = 0
        stripe.Parent  = card
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 4)

        -- Pet icon placeholder
        local icon     = Instance.new("TextLabel")
        icon.Size      = UDim2.new(1, 0, 0, 50)
        icon.Position  = UDim2.new(0, 0, 0, 8)
        icon.BackgroundTransparency = 1
        icon.Text      = "🐾"
        icon.TextScaled = true
        icon.Font      = Enum.Font.Gotham
        icon.Parent    = card

        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size      = UDim2.new(1, 0, 0, 20)
        nameLabel.Position  = UDim2.new(0, 0, 0, 58)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = true
        nameLabel.Font      = Enum.Font.GothamBold
        nameLabel.Text      = name
        nameLabel.Parent    = card

        -- Rarity label
        local rarLabel = Instance.new("TextLabel")
        rarLabel.Size      = UDim2.new(1, 0, 0, 16)
        rarLabel.Position  = UDim2.new(0, 0, 0, 76)
        rarLabel.BackgroundTransparency = 1
        rarLabel.TextColor3 = color
        rarLabel.TextScaled = true
        rarLabel.Font      = Enum.Font.Gotham
        rarLabel.Text      = rarity
        rarLabel.Parent    = card

        -- Equip/unequip button
        local eqBtn    = Instance.new("TextButton")
        eqBtn.Size     = UDim2.new(1, -8, 0, 18)
        eqBtn.Position = UDim2.new(0, 4, 0, 90)
        eqBtn.BackgroundColor3 = equipped and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(50, 160, 50)
        eqBtn.BorderSizePixel = 0
        eqBtn.Text     = equipped and "Unequip" or "Equip"
        eqBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        eqBtn.TextScaled = true
        eqBtn.Font     = Enum.Font.GothamBold
        eqBtn.Parent   = card
        Instance.new("UICorner", eqBtn).CornerRadius = UDim.new(0, 4)

        local uid = petInst.uid
        eqBtn.MouseButton1Click:Connect(function()
            Events.EquipPet:FireServer(uid, not equipped)
        end)
    end
end

-- ─── Build Egg Hatch GUI ─────────────────────────────────────────────────────

local function buildEggGui()
    local screenGui        = Instance.new("ScreenGui")
    screenGui.Name         = "EggGui"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled      = false
    screenGui.Parent       = PlayerGui

    local mainFrame            = Instance.new("Frame")
    mainFrame.Name             = "MainFrame"
    mainFrame.Size             = UDim2.new(0, 520, 0, 380)
    mainFrame.Position         = UDim2.new(0.5, -260, 0.5, -190)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel  = 0
    mainFrame.Parent           = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

    local title       = Instance.new("TextLabel")
    title.Size        = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text        = "🥚 Egg Shop"
    title.TextColor3  = Color3.fromRGB(255, 255, 255)
    title.TextScaled  = true
    title.Font        = Enum.Font.GothamBold
    title.Parent      = mainFrame

    local closeBtn    = Instance.new("TextButton")
    closeBtn.Size     = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -40, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text     = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font     = Enum.Font.GothamBold
    closeBtn.Parent   = mainFrame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

    local scroll        = Instance.new("ScrollingFrame")
    scroll.Size         = UDim2.new(1, -16, 1, -48)
    scroll.Position     = UDim2.new(0, 8, 0, 44)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize   = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent       = mainFrame

    local layout        = Instance.new("UIListLayout", scroll)
    layout.Padding      = UDim.new(0, 8)
    Instance.new("UIPadding", scroll).PaddingLeft = UDim.new(0, 6)

    -- Populate eggs
    for _, eggDef in ipairs(EggConfig.Eggs) do
        local row      = Instance.new("Frame")
        row.Size       = UDim2.new(1, -12, 0, 70)
        row.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        row.BorderSizePixel = 0
        row.Parent     = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size  = UDim2.new(0.55, 0, 0.5, 0)
        nameLabel.Position = UDim2.new(0, 8, 0, 4)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text  = eggDef.name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = true
        nameLabel.Font  = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row

        local costLabel = Instance.new("TextLabel")
        costLabel.Size  = UDim2.new(0.55, 0, 0.4, 0)
        costLabel.Position = UDim2.new(0, 8, 0.5, 2)
        costLabel.BackgroundTransparency = 1
        local costText  = eggDef.coinCost > 0 and ("🪙 " .. tostring(eggDef.coinCost))
            or eggDef.gemCost > 0 and ("💎 " .. tostring(eggDef.gemCost))
            or (eggDef.isLimited and ("🎟 " .. tostring(eggDef.eventCost or 0) .. " tokens"))
            or "Free"
        costLabel.Text  = costText
        costLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
        costLabel.TextScaled = true
        costLabel.Font  = Enum.Font.Gotham
        costLabel.TextXAlignment = Enum.TextXAlignment.Left
        costLabel.Parent = row

        local hatchBtn  = Instance.new("TextButton")
        hatchBtn.Size   = UDim2.new(0, 100, 0, 38)
        hatchBtn.Position = UDim2.new(1, -110, 0.5, -19)
        hatchBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 220)
        hatchBtn.BorderSizePixel  = 0
        hatchBtn.Text   = "Hatch"
        hatchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        hatchBtn.TextScaled = true
        hatchBtn.Font   = Enum.Font.GothamBold
        hatchBtn.Parent = row
        Instance.new("UICorner", hatchBtn).CornerRadius = UDim.new(0, 6)

        local eggId = eggDef.id
        hatchBtn.MouseButton1Click:Connect(function()
            Events.HatchEgg:FireServer(eggId)
        end)
    end

    PetController.eggGui = screenGui
end

-- ─── HUD navigation buttons ──────────────────────────────────────────────────

local function buildNavButtons()
    local screenGui        = Instance.new("ScreenGui")
    screenGui.Name         = "NavButtons"
    screenGui.ResetOnSpawn = false
    screenGui.Parent       = PlayerGui

    local btnData = {
        { text = "🐾 Pets",  x = 0,   gui = "PetGui"   },
        { text = "🥚 Eggs",  x = 110, gui = "EggGui"   },
        { text = "🏪 Shop",  x = 220, gui = "ShopGui"  },
        { text = "🌟 Rebirth", x = 330, gui = "RebirthGui" },
        { text = "📋 Quests", x = 440, gui = "QuestGui" },
    }

    for _, item in ipairs(btnData) do
        local btn = Instance.new("TextButton")
        btn.Size            = UDim2.new(0, 100, 0, 40)
        btn.Position        = UDim2.new(0, item.x + 10, 1, -50)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        btn.BorderSizePixel  = 0
        btn.Text             = item.text
        btn.TextColor3       = Color3.fromRGB(255, 255, 255)
        btn.TextScaled       = true
        btn.Font             = Enum.Font.GothamBold
        btn.Parent           = screenGui
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local guiName = item.gui
        btn.MouseButton1Click:Connect(function()
            local targetGui = PlayerGui:FindFirstChild(guiName)
            if targetGui then
                targetGui.Enabled = not targetGui.Enabled
            end
        end)
    end
end

-- ─── Subscribe to pet updates ─────────────────────────────────────────────────

ClientData.onUpdate(function()
    PetController.refresh()
end)

-- ─── Bootstrap ───────────────────────────────────────────────────────────────

buildPetGui()
buildEggGui()
buildNavButtons()

return PetController
