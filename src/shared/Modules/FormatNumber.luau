-- FormatNumber.luau
-- Utility: human-readable number formatting with K/M/B/T suffixes

local EconomyConfig = require(script.Parent.Parent.Config.EconomyConfig)

local FormatNumber = {}

function FormatNumber.format(n: number): string
    if n ~= n then return "0" end -- NaN guard
    n = math.floor(n)

    for _, abbr in ipairs(EconomyConfig.CurrencyAbbreviations) do
        if n >= abbr.threshold then
            local formatted = string.format("%.2f", n / abbr.threshold)
            -- Trim trailing zeros: "1.00" → "1", "1.50" → "1.5"
            formatted = formatted:gsub("%.?0+$", "")
            return formatted .. abbr.suffix
        end
    end

    return tostring(n)
end

return FormatNumber
