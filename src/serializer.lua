
local serializer = {}

-- Serialize lua table
function serializer.serialize(tbl)
    local str = "{"
    local first = true
    for k, v in pairs(tbl) do
        if not first then
            str = str .. ","
        else
            first = false
        end
        str = str .. "[" .. string.format("%q", k) .. "]=" .. (type(v) == "table" and serializer.serialize(v) or string.format("%q", v))
    end
    return str .. "}"
end

-- Deserialize lua table
function serializer.deserialize(str)
    return assert(load("return " .. str))()
end

return serializer