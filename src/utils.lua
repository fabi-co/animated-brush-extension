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
function utils.getFirstElement(table)
    assert(table ~= nil)
    for key, value in pairs(table) do
        return value
    end
    return nil
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
function nextFrame(k)
    local frameNb = (k % #app.sprite.frames)

    if frameNb == 0 then frameNb = #app.sprite.frames end
    return app.sprite.frames[frameNb]
end

return utils