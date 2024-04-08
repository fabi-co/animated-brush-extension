-- Utilities module

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
function utils.getFirstElement(table)
    assert(table ~= nil)
    for key, value in pairs(table) do
        return value
    end
    return nil
end

-- Check if the number of frames left < nbFrames
function utils.isNbFramesEnough(frame, nbFrames)
    return (#app.sprite.frames - frame.frameNumber + 1) >= nbFrames
end

return utils