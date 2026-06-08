--[[
    BillboardPetRenderer.luau
    Shared 2D world renderer for pet sprites.

    Exposes:
    - createPetModel(petId, variant, options)
    - applyGoldenEffect(imageLabel, rootPart)
    - applyRainbowEffect(imageLabel)
    - cleanupEffects(model)
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetDefinitions = require(Shared:WaitForChild("Pets"):WaitForChild("PetDefinitions"))

local BillboardPetRenderer = {}
local activeRainbowEffects = {}

local DEBUG_PET_IMAGES = RunService:IsStudio()

local INVALID_IMAGE = "rbxassetid://0"
local RAINBOW_COLORS = {
    Color3.fromRGB(255, 80, 80),
    Color3.fromRGB(255, 205, 65),
    Color3.fromRGB(120, 230, 120),
    Color3.fromRGB(90, 180, 255),
    Color3.fromRGB(180, 100, 255),
    Color3.fromRGB(255, 90, 200),
}

local function normalizeVariantName(variant: string?): string
    local token = variant or "Normal"
    if token == "Golden" or token == "Rainbow" then
        return token
    end
    return "Normal"
end

local function extractAssetId(imageAssetId: string?): string
    if not imageAssetId or imageAssetId == "" then
        return INVALID_IMAGE
    end

    local numericId = string.match(imageAssetId, "%d+")
    if not numericId then
        return INVALID_IMAGE
    end

    return "rbxassetid://" .. numericId
end

local function buildRootPart(): Part
    local root = Instance.new("Part")
    root.Name = "Root"
    root.Size = Vector3.new(0.35, 0.35, 0.35)
    root.Anchored = true
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.CastShadow = false
    root.Transparency = 1
    return root
end

local function buildBillboard(rootPart: BasePart, options)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PetBillboard"
    billboard.Adornee = rootPart
    billboard.AlwaysOnTop = options.alwaysOnTop == true
    billboard.LightInfluence = 0
    billboard.StudsOffset = Vector3.new(0, options.studsOffsetY, 0)
    billboard.Size = UDim2.fromScale(options.widthStuds, options.heightStuds)
    billboard.MaxDistance = options.maxDistance

    pcall(function()
        billboard.DistanceLowerLimit = options.distanceLowerLimit
        billboard.DistanceUpperLimit = options.distanceUpperLimit
    end)

    local frame = Instance.new("Frame")
    frame.Name = "Container"
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundTransparency = 1
    frame.Parent = billboard

    local image = Instance.new("ImageLabel")
    image.Name = "PetImage"
    image.Size = UDim2.fromScale(1, 1)
    image.Position = UDim2.fromScale(0, 0)
    image.BackgroundTransparency = 1
    image.ScaleType = Enum.ScaleType.Fit
    image.Parent = frame

    return billboard, image
end

local function addTextLabel(parent: Instance, name: string, text: string, yOffset: number, color: Color3)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Size = UDim2.new(1, 0, 0, 18)
    label.Position = UDim2.new(0, 0, 1, yOffset)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = parent
    return label
end

local function setRainbowStep(imageLabel: ImageLabel, stepNumberValue: NumberValue)
    local step = math.floor(stepNumberValue.Value)
    local colorIndex = ((step - 1) % #RAINBOW_COLORS) + 1
    imageLabel.ImageColor3 = RAINBOW_COLORS[colorIndex]
end

function BillboardPetRenderer.applyGoldenEffect(imageLabel: ImageLabel, rootPart: BasePart)
    imageLabel.ImageColor3 = Color3.fromRGB(255, 205, 65)

    local sparkle = Instance.new("ParticleEmitter")
    sparkle.Name = "GoldenSparkle"
    sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 223, 130), Color3.fromRGB(255, 180, 40))
    sparkle.LightEmission = 0.5
    sparkle.Rate = 3
    sparkle.Lifetime = NumberRange.new(0.45, 0.9)
    sparkle.Speed = NumberRange.new(0.2, 0.5)
    sparkle.SpreadAngle = Vector2.new(180, 180)
    sparkle.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.06),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparkle.Parent = rootPart

    return sparkle
end

function BillboardPetRenderer.applyRainbowEffect(imageLabel: ImageLabel)
    local stepValue = Instance.new("NumberValue")
    stepValue.Name = "RainbowStep"
    stepValue.Value = 1

    local tweenInfo = TweenInfo.new(5.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
    local tween = TweenService:Create(stepValue, tweenInfo, { Value = 1 + #RAINBOW_COLORS })

    local connection = stepValue:GetPropertyChangedSignal("Value"):Connect(function()
        setRainbowStep(imageLabel, stepValue)
    end)

    setRainbowStep(imageLabel, stepValue)
    tween:Play()

    return {
        value = stepValue,
        tween = tween,
        connection = connection,
    }
end

function BillboardPetRenderer.cleanupEffects(model: Model)
    local rainbowState = activeRainbowEffects[model]
    if rainbowState then
        if rainbowState.connection then
            rainbowState.connection:Disconnect()
        end
        if rainbowState.tween then
            rainbowState.tween:Cancel()
        end
        if rainbowState.value and rainbowState.value.Parent then
            rainbowState.value:Destroy()
        end
        activeRainbowEffects[model] = nil
    end

    local sparkle = model:FindFirstChild("GoldenSparkle", true)
    if sparkle and sparkle:IsA("ParticleEmitter") then
        sparkle.Enabled = false
        sparkle:Destroy()
    end
end

function BillboardPetRenderer.createPetModel(petId: string, variant: string?, options)
    local definition = PetDefinitions.Get(petId)
    if not definition then
        return nil
    end

    local resolvedVariant = normalizeVariantName(variant)
    local variantDef = definition.variants[resolvedVariant] or definition.variants.Normal

    local resolvedOptions = {
        widthStuds = (options and options.widthStuds) or 3.2,
        heightStuds = (options and options.heightStuds) or 3.2,
        studsOffsetY = (options and options.studsOffsetY) or 0.1,
        maxDistance = (options and options.maxDistance) or 220,
        distanceLowerLimit = (options and options.distanceLowerLimit) or 6,
        distanceUpperLimit = (options and options.distanceUpperLimit) or 90,
        alwaysOnTop = (options and options.alwaysOnTop) or false,
        showName = (options and options.showName) == true,
        showRarity = (options and options.showRarity) == true,
    }

    local model = Instance.new("Model")
    model.Name = "BillboardPet_" .. petId

    local root = buildRootPart()
    root.Parent = model
    model.PrimaryPart = root

    local billboard, image = buildBillboard(root, resolvedOptions)
    billboard.Parent = root

    local imageAssetId = extractAssetId(variantDef.imageAssetId)
    if DEBUG_PET_IMAGES then
        print(string.format(
            "[PetImage] BillboardPetRenderer: petId=%s variant=%s rawImageAssetId=%s → ImageLabel.Image=%s",
            tostring(petId),
            tostring(resolvedVariant),
            tostring(variantDef.imageAssetId),
            tostring(imageAssetId)
        ))
    end
    image.Image = imageAssetId

    if resolvedOptions.showName then
        addTextLabel(billboard.Container, "NameLabel", definition.displayName, 0, Color3.new(1, 1, 1))
    end
    if resolvedOptions.showRarity then
        addTextLabel(billboard.Container, "RarityLabel", definition.rarity, 16, Color3.fromRGB(230, 230, 230))
    end

    if resolvedVariant == "Golden" then
        BillboardPetRenderer.applyGoldenEffect(image, root)
    elseif resolvedVariant == "Rainbow" then
        local rainbow = BillboardPetRenderer.applyRainbowEffect(image)
        rainbow.value.Parent = model
        activeRainbowEffects[model] = rainbow
    end

    model.Destroying:Connect(function()
        BillboardPetRenderer.cleanupEffects(model)
    end)

    return model
end

return BillboardPetRenderer
