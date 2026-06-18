--[[
    EggVisualUtil.luau
    Canonical egg image resolver for GUI, hatch reveals, and world displays.
]]

local EggVisualUtil = {}

local INVALID_IMAGE = "rbxassetid://0"

function EggVisualUtil.IsValidAssetId(imageId: string?): boolean
    if not imageId or imageId == "" or imageId == INVALID_IMAGE then
        return false
    end
    return string.match(imageId, "%d+") ~= nil
end

function EggVisualUtil.NormalizeImage(imageId: string?): string
    if not EggVisualUtil.IsValidAssetId(imageId) then
        return INVALID_IMAGE
    end
    local numericId = string.match(imageId, "%d+")
    if not numericId then
        return INVALID_IMAGE
    end
    return "rbxassetid://" .. numericId
end

function EggVisualUtil.GetEggImage(eggInfo): string
    if not eggInfo then
        return INVALID_IMAGE
    end
    return EggVisualUtil.NormalizeImage(eggInfo.Image)
end

function EggVisualUtil.ApplyImageToLabel(imageLabel: ImageLabel, eggInfo)
    imageLabel.Image = EggVisualUtil.GetEggImage(eggInfo)
end

return EggVisualUtil
