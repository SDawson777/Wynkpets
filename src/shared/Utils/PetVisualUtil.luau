--[[
    PetVisualUtil.luau
    Centralized pet visual creation for all UI surfaces.
    Creates ImageLabel-based pet icons with variant effects,
    or procedurally unique fallback icons when images are placeholders.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RarityConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RarityConfig"))

local PetVisualUtil = {}

local INVALID_IMAGE = "rbxassetid://0"

local RARITY_COLORS = {
    Common = Color3.fromRGB(180, 180, 180),
    Rare = Color3.fromRGB(80, 160, 255),
    Epic = Color3.fromRGB(180, 80, 255),
    Legendary = Color3.fromRGB(255, 200, 50),
    Mythic = Color3.fromRGB(255, 80, 80),
    Secret = Color3.fromRGB(255, 50, 200),
}

-- Emoji per zone/pet-type for visual identity (deterministic from pet name)
local PET_EMOJIS = {
    "🐱", "🐶", "🦊", "🐰", "🐸", "🦋", "🐼", "🐨",
    "🦁", "🐯", "🐮", "🐷", "🐲", "🦅", "🐺", "🐍",
    "🦄", "🐙", "🦎", "🐝", "🐬", "🦇", "🦉", "🐢",
    "🦈", "🐠", "🦜", "🦚", "🐉", "🐋", "🌟", "💎",
    "🔥", "❄️", "⚡", "🌙", "☀️", "💀", "👻", "🌸",
}

-- Generate a deterministic hash from a string (for seeded visual properties)
local function hashString(str: string): number
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end
    return hash
end

-- Get a unique emoji for a pet based on its ID
local function getPetEmoji(petId: string): string
    local hash = hashString(petId)
    return PET_EMOJIS[(hash % #PET_EMOJIS) + 1]
end

-- Generate a unique accent color for a pet (distinct from rarity color)
local function getPetAccentColor(petId: string): Color3
    local hash = hashString(petId .. "_accent")
    local hue = (hash % 360) / 360
    return Color3.fromHSV(hue, 0.6, 0.9)
end

-- Normalize asset IDs to a render-safe URI for ImageLabel/SurfaceGui.
-- Assets are uploaded as Decals; use rbxassetid:// directly to bypass the
-- thumbnail pipeline which returns Pending for recently uploaded Decals.
function PetVisualUtil.IsValidAssetId(imageId: string?): boolean
    if not imageId or imageId == "" or imageId == INVALID_IMAGE then
        return false
    end
    return string.match(imageId, "%d+") ~= nil
end

function PetVisualUtil.NormalizeImage(imageId: string?): string
    if not PetVisualUtil.IsValidAssetId(imageId) then
        return INVALID_IMAGE
    end
    -- Use rbxassetid:// directly so the engine loads the texture from the Decal
    -- asset without going through the thumbnail pipeline (which returns "Pending"
    -- for newly uploaded decals and shows a placeholder instead of the real image).
    local numericId = string.match(imageId, "%d+")
    if not numericId then
        return INVALID_IMAGE
    end
    return "rbxassetid://" .. numericId
end

function PetVisualUtil.NormalizeVariant(ownedPet)
    if not ownedPet then
        return "Normal"
    end
    if ownedPet.Rainbow then
        return "Rainbow"
    end
    if ownedPet.Golden then
        return "Golden"
    end
    return "Normal"
end

function PetVisualUtil.GetPetImage(petInfo, ownedPet): string
    if not petInfo then
        return INVALID_IMAGE
    end

    local variant = PetVisualUtil.NormalizeVariant(ownedPet)
    local chosenImage = petInfo.Image

    if variant == "Rainbow" and PetVisualUtil.IsValidAssetId(petInfo.RainbowImage) then
        chosenImage = petInfo.RainbowImage
    elseif variant == "Golden" and PetVisualUtil.IsValidAssetId(petInfo.GoldenImage) then
        chosenImage = petInfo.GoldenImage
    end

    if not PetVisualUtil.IsValidAssetId(chosenImage) then
        chosenImage = petInfo.Image
    end

    return PetVisualUtil.NormalizeImage(chosenImage)
end

-- Determine the correct image for a pet based on variants
function PetVisualUtil.GetImage(petInfo, ownedPet): string
    return PetVisualUtil.GetPetImage(petInfo, ownedPet)
end

-- Check if an image is a real asset (not placeholder)
function PetVisualUtil.HasImage(petInfo): boolean
    return petInfo and PetVisualUtil.IsValidAssetId(petInfo.Image)
end

function PetVisualUtil.ApplyImageToLabel(imageLabel: ImageLabel, imageId: string?)
    imageLabel.Image = PetVisualUtil.NormalizeImage(imageId)
end

function PetVisualUtil.CreateWorldBillboardImage(parentPart: BasePart, imageId: string, sizeStuds: Vector2?): BillboardGui?
    local normalized = PetVisualUtil.NormalizeImage(imageId)
    if normalized == INVALID_IMAGE then
        return nil
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PetImageBillboard"
    local visualSize = sizeStuds or Vector2.new(3.2, 3.2)
    billboard.Size = UDim2.fromScale(visualSize.X, visualSize.Y)
    billboard.StudsOffset = Vector3.new(0, 0.15, 0)
    billboard.AlwaysOnTop = false
    billboard.LightInfluence = 1
    billboard.Parent = parentPart

    local image = Instance.new("ImageLabel")
    image.Size = UDim2.new(1, 0, 1, 0)
    image.BackgroundTransparency = 1
    image.Image = normalized
    image.ScaleType = Enum.ScaleType.Fit
    image.Parent = billboard

    return billboard
end

-- Build the procedural fallback icon (gradient + emoji + initial)
local function buildProceduralIcon(parent: GuiObject, petInfo, ownedPet, iconSize: UDim2, rarityColor: Color3): Frame
    local icon = Instance.new("Frame")
    icon.Name = "PetIcon"
    icon.Size = iconSize
    icon.BorderSizePixel = 0
    icon.ClipsDescendants = true
    icon.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.35, 0)
    corner.Parent = icon

    local baseColor
    if ownedPet and ownedPet.Rainbow then
        baseColor = Color3.fromRGB(255, 100, 255)
    elseif ownedPet and ownedPet.Golden then
        baseColor = Color3.fromRGB(255, 215, 0)
    else
        baseColor = rarityColor
    end
    icon.BackgroundColor3 = baseColor

    local accentColor = getPetAccentColor(petInfo.Id)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(baseColor, accentColor)
    gradient.Rotation = hashString(petInfo.Id .. "_rot") % 360
    gradient.Parent = icon

    local emoji = Instance.new("TextLabel")
    emoji.Size = UDim2.new(1, 0, 0.7, 0)
    emoji.Position = UDim2.new(0, 0, 0, 0)
    emoji.BackgroundTransparency = 1
    emoji.Text = getPetEmoji(petInfo.Id)
    emoji.TextSize = 100
    emoji.TextScaled = true
    emoji.Font = Enum.Font.GothamBold
    emoji.Parent = icon

    local initial = Instance.new("TextLabel")
    initial.Size = UDim2.new(1, 0, 0.35, 0)
    initial.Position = UDim2.new(0, 0, 0.65, 0)
    initial.BackgroundTransparency = 1
    initial.Text = string.sub(petInfo.Name, 1, 1)
    initial.TextColor3 = Color3.new(1, 1, 1)
    initial.TextStrokeTransparency = 0
    initial.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    initial.TextSize = 100
    initial.TextScaled = true
    initial.Font = Enum.Font.GothamBold
    initial.Parent = icon

    return icon
end

-- Add rarity border and variant badge to an icon
local function addIconDecorations(icon: GuiObject, petInfo, ownedPet)
    local stroke = Instance.new("UIStroke")
    local rarityTier = RarityConfig.Tiers[petInfo.Rarity]
    stroke.Color = rarityTier and rarityTier.GlowColor or Color3.fromRGB(150, 150, 150)
    stroke.Thickness = 2
    stroke.Parent = icon

    if ownedPet and (ownedPet.Golden or ownedPet.Rainbow) then
        local badge = Instance.new("Frame")
        badge.Size = UDim2.new(0, 16, 0, 16)
        badge.Position = UDim2.new(1, -14, 0, -2)
        badge.BorderSizePixel = 0
        badge.ZIndex = 5
        badge.Parent = icon

        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = UDim.new(1, 0)
        badgeCorner.Parent = badge

        if ownedPet.Rainbow then
            badge.BackgroundColor3 = Color3.fromRGB(255, 100, 255)
        else
            badge.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        end
    end
end

--[[
    Create a pet icon (ImageLabel or procedural fallback icon).
    parent: GuiObject to parent to
    petInfo: PetConfig entry (Id, Name, Rarity, Image, etc.)
    ownedPet: OwnedPet data (UUID, Golden, Rainbow, etc.) or nil for config-only display
    size: UDim2 size for the icon
    Returns the created icon GuiObject
]]
function PetVisualUtil.CreateIcon(parent: GuiObject, petInfo, ownedPet, size: UDim2?): GuiObject
    local iconSize = size or UDim2.new(0, 60, 0, 60)
    local rarityColor = RARITY_COLORS[petInfo.Rarity] or RARITY_COLORS.Common
    local image = PetVisualUtil.GetImage(petInfo, ownedPet)

    -- Always create procedural icon as the base layer so something is always visible
    local icon = buildProceduralIcon(parent, petInfo, ownedPet, iconSize, rarityColor)

    if image ~= INVALID_IMAGE then
        -- Overlay real image on top of procedural — Roblox auto-resolves Decal IDs
        -- in ImageLabel.Image. If the image loads it covers the procedural base;
        -- if it doesn't, the procedural base shows through.
        local overlay = Instance.new("ImageLabel")
        overlay.Name = "PetImageOverlay"
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundTransparency = 1
        overlay.Image = image
        overlay.ScaleType = Enum.ScaleType.Fit
        overlay.ZIndex = icon.ZIndex + 1
        overlay.Parent = icon
    end

    addIconDecorations(icon, petInfo, ownedPet)

    return icon
end

--[[
    Create a silhouette icon for undiscovered pets in the Pet Index.
    Gradient shape with "?" overlay — same shape as real icon but obscured.
]]
function PetVisualUtil.CreateSilhouette(parent: GuiObject, petInfo, size: UDim2?): GuiObject
    local iconSize = size or UDim2.new(0, 60, 0, 60)
    local image = PetVisualUtil.GetPetImage(petInfo, nil)

    local icon

    if image ~= INVALID_IMAGE then
        icon = Instance.new("ImageLabel")
        icon.Name = "PetSilhouette"
        icon.Size = iconSize
        icon.BackgroundTransparency = 1
        icon.Image = image
        icon.ImageColor3 = Color3.fromRGB(30, 30, 40) -- Dark tint
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = parent
    else
        -- Silhouette: dark rounded square matching the icon shape
        icon = Instance.new("Frame")
        icon.Name = "PetSilhouette"
        icon.Size = iconSize
        icon.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        icon.BorderSizePixel = 0
        icon.ClipsDescendants = true
        icon.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.35, 0)
        corner.Parent = icon

        -- Subtle gradient hint of the pet's rarity
        local rarityColor = RARITY_COLORS[petInfo.Rarity] or RARITY_COLORS.Common
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new(Color3.fromRGB(30, 30, 45), Color3.fromRGB(
            math.floor(rarityColor.R * 40),
            math.floor(rarityColor.G * 40),
            math.floor(rarityColor.B * 40)
        ))
        gradient.Rotation = hashString(petInfo.Id .. "_rot") % 360
        gradient.Parent = icon
    end

    -- Question mark overlay
    local mystery = Instance.new("TextLabel")
    mystery.Size = UDim2.new(1, 0, 1, 0)
    mystery.BackgroundTransparency = 1
    mystery.Text = "?"
    mystery.TextColor3 = Color3.fromRGB(80, 80, 100)
    mystery.Font = Enum.Font.GothamBold
    mystery.TextSize = 24
    mystery.Parent = icon

    return icon
end

return PetVisualUtil
