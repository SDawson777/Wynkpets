--[[
    TableUtil.luau
    Table utility functions
]]

local TableUtil = {}

function TableUtil.DeepCopy(original: any): any
    if type(original) ~= "table" then
        return original
    end

    local copy = {}
    for key, value in pairs(original) do
        copy[TableUtil.DeepCopy(key)] = TableUtil.DeepCopy(value)
    end
    return copy
end

function TableUtil.Merge(base: { [any]: any }, override: { [any]: any }): { [any]: any }
    local result = TableUtil.DeepCopy(base)
    for key, value in pairs(override) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = TableUtil.Merge(result[key], value)
        else
            result[key] = value
        end
    end
    return result
end

function TableUtil.Find(tbl: { any }, predicate: (any) -> boolean): any?
    for _, value in ipairs(tbl) do
        if predicate(value) then
            return value
        end
    end
    return nil
end

function TableUtil.Filter(tbl: { any }, predicate: (any) -> boolean): { any }
    local result = {}
    for _, value in ipairs(tbl) do
        if predicate(value) then
            table.insert(result, value)
        end
    end
    return result
end

function TableUtil.Map(tbl: { any }, transform: (any) -> any): { any }
    local result = {}
    for _, value in ipairs(tbl) do
        table.insert(result, transform(value))
    end
    return result
end

function TableUtil.Contains(tbl: { any }, item: any): boolean
    for _, value in ipairs(tbl) do
        if value == item then
            return true
        end
    end
    return false
end

function TableUtil.RemoveValue(tbl: { any }, item: any): boolean
    for i, value in ipairs(tbl) do
        if value == item then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

function TableUtil.Count(tbl: { [any]: any }): number
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function TableUtil.Keys(tbl: { [any]: any }): { any }
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys
end

function TableUtil.Values(tbl: { [any]: any }): { any }
    local values = {}
    for _, value in pairs(tbl) do
        table.insert(values, value)
    end
    return values
end

function TableUtil.Shuffle(tbl: { any }): { any }
    local shuffled = TableUtil.DeepCopy(tbl)
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end

return TableUtil
