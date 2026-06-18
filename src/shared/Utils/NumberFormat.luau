--[[
    NumberFormat.luau
    Utility for formatting large numbers with abbreviations
]]

local NumberFormat = {}

local SUFFIXES = {
    "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
    "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}

function NumberFormat.Abbreviate(value: number): string
    if value < 1000 then
        return tostring(math.floor(value))
    end

    local index = 1
    while value >= 1000 and index < #SUFFIXES do
        value = value / 1000
        index = index + 1
    end

    if value >= 100 then
        return string.format("%.0f%s", value, SUFFIXES[index])
    elseif value >= 10 then
        return string.format("%.1f%s", value, SUFFIXES[index])
    else
        return string.format("%.2f%s", value, SUFFIXES[index])
    end
end

function NumberFormat.AddCommas(value: number): string
    local formatted = tostring(math.floor(value))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then
            break
        end
    end
    return formatted
end

function NumberFormat.FormatTime(seconds: number): string
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%dh %dm %ds", hours, mins, secs)
    elseif mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

return NumberFormat
