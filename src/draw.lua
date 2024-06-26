-- Animated Brush Extension
-- Made by Fabico
--
-- This file is released under the terms of the MIT license.
-- Read LICENSE.txt for more information.

-- Draw Module
-- Contains functions to handle drawing on a cell or multiple cells at once
-- with multiple options.

local utils = require("src.utils")

if draw then return end

local draw = {}

---Draw an image on a given cel
---@param layer Layer
---@param frame Frame
---@param imgBytes Dict[str]
---@param imgSpec Dict[str]
function draw.drawImgOnCel(layer, frame, imgBytes, imgSpec)
    -- Gérer si nbFrames < cel + nbCels

    local imgBrush  = Image(imgSpec)
    imgBrush.bytes  = imgBytes
    
    local prevBrush = app.brush

    local brush = Brush {
        type =  BrushType.IMAGE ,
        size = app.brush.size,
        angle = app.brush.angle,
        center = app.brush.center,
        pattern = app.brush.pattern,
        patternOrigin = app.brush.patternOrigin,
        image = imgBrush
    }

    app.useTool{
        tool   = 'pencil',
        brush  = brush,
        frame  = frame,
        layer  = layer,
        points = {app.editor.spritePos},
        color  = app.fgColor
    }

    app.tool  = 'pencil'
    app.brush = prevBrush
end

---Draw first frame of animationsFrames on all frames from layer that aren't 
---part of the animation.
---@param brushData any
local function drawCompleteWithStatic(brushData)
    -- All cells filled already, nothing to do
    if #app.sprite.frames == brushData.nbCells then
        return
    end
    
    local specDict = brushData.specs
    local specs    = ImageSpec{
        width            = specDict[1].width,
        height           = specDict[1].height,
        colorMode        = specDict[1].colorMode,
        transparentColor = specDict[1].transparentColor
    }
    local imgBytes = utils.decode(brushData.imgs[1])

    local firstFrameNb = app.frame.frameNumber
    local lastFrameNb  = app.frame.frameNumber + brushData.nbCells
    local beginIt      = 1

    if not(utils.isNbFramesLeftOk(app.frame, brushData.nbCells)) then
        beginIt     = lastFrameNb % #app.sprite.frames
        lastFrameNb = #app.sprite.frames + 1
    end

    for i = beginIt, firstFrameNb - 1 do
        local frame = app.sprite.frames[i]
        draw.drawImgOnCel(app.layer, frame, imgBytes, specs)
    end

    for i = lastFrameNb, #app.sprite.frames do
        local frame = app.sprite.frames[i]
        draw.drawImgOnCel(app.layer, frame, imgBytes, specs)
    end
end

---Draw a brush animation on multiple cels from the current layer
---@param brushData Dict
---@param completeWithStatic boolean
---@param loopBack boolean
---@return integer, string
function draw.drawAnimation(brushData, completeWithStatic, loopBack)

    -- No brush
    if brushData == nil then
        return -1, "No brush available"
    end

    -- Not enough frames
    if not(utils.isTotalNbFramesOk(brushData.nbCells)) then
        return -1, "There is not enough frames to draw the animation. Aborting."
    end

    -- Not enough frames left and not loop back
    if not(utils.isNbFramesLeftOk(app.frame, brushData.nbCells)) and not(loopBack) then
        return -1, "There is not enough frames left to draw the animation. Aborting."
    end

    local specDict  = brushData.specs
    for k, v in pairs(brushData.imgs) do
        local specs = ImageSpec{
            width            = specDict[k].width,
            height           = specDict[k].height,
            colorMode        = specDict[k].colorMode,
            transparentColor = specDict[k].transparentColor
        }
        local imgBytes = utils.decode(brushData.imgs[k])
        local frame    = utils.nextFrame(app.frame.frameNumber + k - 1)
        draw.drawImgOnCel(app.layer, frame, imgBytes, specs)
    end
    
    if completeWithStatic then
        drawCompleteWithStatic(brushData)
    end

    return 0, nil
end

return draw