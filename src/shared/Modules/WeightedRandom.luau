-- WeightedRandom.luau
-- Utility: pick a random entry from a weighted table

local WeightedRandom = {}

-- items: array of { weight = number, [any other fields] }
-- Returns the selected item (the full table entry).
function WeightedRandom.pick(items: { { weight: number } }, luckMultiplier: number?): any
    local luck = luckMultiplier or 1

    -- Build cumulative weights, applying luck to non-first-tier entries
    -- (luck shifts weight away from the lowest weight items toward higher ones)
    local totalWeight = 0
    local adjusted = {}
    for i, item in ipairs(items) do
        -- Luck scaling: scale rare entries up by luckMultiplier
        -- We sort by weight descending so index 1 = most common.
        -- Simple approach: multiply rarer items' weights by luck.
        local w = item.weight
        if luck > 1 and i > 1 then
            -- gradually apply luck more to rarer tiers
            w = w * (luck ^ (i / #items))
        end
        totalWeight = totalWeight + w
        adjusted[i] = { item = item, w = w }
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(adjusted) do
        cumulative = cumulative + entry.w
        if roll <= cumulative then
            return entry.item
        end
    end

    -- Fallback to last item
    return adjusted[#adjusted].item
end

return WeightedRandom
