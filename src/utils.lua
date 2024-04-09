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

-- Encode bytes to hexadecimal
function utils.encode(bytes)
    return bytes:gsub(".", function(byte)
        return string.format("%02X", string.byte(byte))
    end)
end

-- Decode hexadecimal back to bytes
function utils.decode(hex)
    return hex:gsub("..", function(twoChars)
        return string.char(tonumber(twoChars, 16))
    end)
end

-- Utility, lua hasn't one one those -_-
function utils.getFirstElement(t)
    assert(t ~= nil)
    for key, value in pairs(t) do
        return value
    end
    return nil
end

-- Returns only the keys from a lua table
function utils.getKeys(t)
    local keys = {}
    for k, _ in pairs(t) do table.insert(keys, k) end
    return keys
end

-- Deep copy of a table
function utils.deepCopyTable(t)
    local tCopied={}
    if type(t)=="table" then
        for k, v in pairs(t) do tCopied[k] = utils.deepCopyTable(v) end
    else
        tCopied=t
    end
    return tCopied
end

-- Check if a value already exists in a table
function utils.tabKeyExists(t, val)
    for k, _ in pairs(t) do
        if k == val then return true end
    end
    return false
end

-- Local utility to display brushes names
function utils.getBrushesNames(tab)
    local names = {}
    for key, value in pairs(tab) do
        table.insert(names, value.name)
    end
    return names
end

-- Check if the number of frames left < nbFrames
function utils.isNbFramesLeftOk(frame, nbFrames)
    return (#app.sprite.frames - frame.frameNumber + 1) >= nbFrames
end

-- check if total #frames <= #animationsFrames
function utils.isTotalNbFramesOk(nbFrames)
    return #app.sprite.frames >= nbFrames
end

-- Returns frame corresponding to frame number. If k > #nbFrames, 
-- loop frame 1.
function utils.nextFrame(k)
    local frameNb = (k % #app.sprite.frames)

    if frameNb == 0 then frameNb = #app.sprite.frames end
    return app.sprite.frames[frameNb]
end

function utils.colorsFromInts(tab)
    colors = {}
    for _, val in pairs(tab) do
        table.insert(colors, Color(val))
    end
    return colors
end

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

function utils.colorsToRGBAPixels(colors)
    local rgbaPixels = {}

    for k, v in pairs(colors) do
        rgbaPixels[k] = v.rgbaPixel
    end

    return rgbaPixels
end
  
return utils