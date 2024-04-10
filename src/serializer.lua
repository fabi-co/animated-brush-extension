-- Animated Brush Extension
-- Made by Fabico
--
-- This file is released under the terms of the MIT license.
-- Read LICENSE.txt for more information.

-- Serializer module

local json = require("libs.json")

local serializer = {}

-- Serialize lua table
function serializer.serialize(tabData)
   return json.encode(tabData)
end

-- Deserialize lua table
function serializer.deserialize(str)
    return json.decode(str)
end

---Write tabData in json file.
---@param tabData table
---@param fn string filename
---@return boolean error
---@return string error message
function serializer.writeInFile(tabData, fn)
    if app.fs.fileExtension(fn) ~= "json" and app.fs.fileExtension(fn) ~= "JSON" then
        return false, "This is not a json file"
    end

    local file, err = io.open(fn, "w")
    if not file then
        return false, "Error opening the file : " .. err
    end

    local jsoned  = serializer.serialize(tabData) 
    local ok, err = file:write(jsoned)
    if not ok then
        file:close()  -- Close the file before returning
        return false, "Error writing to file:" .. err
    end

    file:close()
    return true, ""
end

---Read a json file representing a tabData.
---@param fn string Filename
---@return table - deserialized json table
---@return string - Msg error
function serializer.readData(fn)
    if app.fs.fileExtension(fn) ~= "json" and app.fs.fileExtension(fn) ~= "JSON" then
        return nil, "This is not a json file"
    end

    local file, err = io.open(fn, "r")
    if not file then
        return nil, "Error opening the file : " .. err
    end

    local strData = file:read("a")
    if not strData then
        file:close()
        return nil, "A problem occured to read the file"
    end
    file:close()

    return serializer.deserialize(strData), ""
end

return serializer