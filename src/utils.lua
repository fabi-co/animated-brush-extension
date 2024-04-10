-- Animated Brush Extension
-- Made by Fabico
--
-- This file is released under the terms of the MIT license.
-- Read LICENSE.txt for more information.

-- Utilities module

-- Snippet
    -- for pix in img:pixels() do
    --     print(pix.x, pix.y)
    --     print(app.pixelColor.rgbaR(pix()))
    --     print(app.pixelColor.rgbaG(pix()))
    --     print(app.pixelColor.rgbaB(pix()))
    --     print(app.pixelColor.rgbaA(pix()))
    -- end


if utils then return end

local utils = {}


---Encode bytes to hexadecimal str
---@param bytes bytes
---@return string representation of bytes
function utils.encode(bytes)
    return bytes:gsub(".", function(byte)
        return string.format("%02X", string.byte(byte))
    end)
end


---Decode hexadecimal back to bytes
---@param hex string
---@return bytes
function utils.decode(hex)
    return hex:gsub("..", function(twoChars)
        return string.char(tonumber(twoChars, 16))
    end)
end


---Get 1st element from table
---@param t any
---@return unknown
function utils.getFirstElement(t)
    assert(t ~= nil)
    for key, value in pairs(t) do
        return value
    end
    return nil
end


---Returns only the keys from a lua table
---@param t table
---@return table
function utils.getKeys(t)
    local keys = {}
    for k, _ in pairs(t) do table.insert(keys, k) end
    return keys
end


---Deep copy a table
---@param t table
---@return table
function utils.deepCopyTable(t)
    local tCopied={}
    if type(t)=="table" then
        for k, v in pairs(t) do tCopied[k] = utils.deepCopyTable(v) end
    else
        tCopied=t
    end
    return tCopied
end


---Check if a value already exists in a table
---@param t table
---@param val any
---@return boolean
function utils.tabKeyExists(t, val)
    for k, _ in pairs(t) do
        if k == val then return true end
    end
    return false
end


---Local utility to display brushes names
---@param tab table
---@return table
function utils.getBrushesNames(tab)
    local names = {}
    for key, value in pairs(tab) do
        table.insert(names, value.name)
    end
    return names
end


---Check if the number of frames left < nbFrames
---@param frame any
---@param nbFrames any
---@return boolean
function utils.isNbFramesLeftOk(frame, nbFrames)
    return (#app.sprite.frames - frame.frameNumber + 1) >= nbFrames
end


---Check if total #frames <= #animationsFrames
---@param nbFrames any
---@return boolean
function utils.isTotalNbFramesOk(nbFrames)
    return #app.sprite.frames >= nbFrames
end


---Returns frame corresponding to frame number. If k > #nbFrames, 
---loop frame 1.
---@param k any
---@return unknown
function utils.nextFrame(k)
    local frameNb = (k % #app.sprite.frames)

    if frameNb == 0 then frameNb = #app.sprite.frames end
    return app.sprite.frames[frameNb]
end


---Get transform color to ints
---@param tab any
---@return table[Color]
function utils.colorsFromInts(tab)
    colors = {}
    for _, val in pairs(tab) do
        table.insert(colors, Color(val))
    end
    return colors
end


---Replace all colors in table
---@param old Color
---@param new Color
---@param tab table
function utils.replaceColorInTab(old, new, tab)
    assert(tab ~= nil)
    local e
    for k, v in pairs(tab) do
        if v.rgbaPixel == old.rgbaPixel then
            e = k
            break
        end
    end
    tab[e] = new
end


---Get rgbapixels from colors
---@param colors table[Color]
---@return table[PixelColor]
function utils.colorsToRGBAPixels(colors)
    local rgbaPixels = {}

    for k, v in pairs(colors) do
        rgbaPixels[k] = v.rgbaPixel
    end

    return rgbaPixels
end
  
return utils