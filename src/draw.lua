-- Draw Module --

local utils = require("src.utils")

if draw then return end

local draw = {}

-- Draw an image on a given cel
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

local function drawCompleteWithStatic(brushData)
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

    for i = 1, firstFrameNb - 1 do
        print("1st loop")
        print(i)
        local frame = app.sprite.frames[i]
        draw.drawImgOnCel(app.layer, frame, imgBytes, specs)
    end

    for i = lastFrameNb, #app.sprite.frames do
        print("2nd loop")
        local frame = app.sprite.frames[i]
        draw.drawImgOnCel(app.layer, frame, imgBytes, specs)
    end
end

-- Draw a brush animation on multiple cels from the current layer
function draw.drawAnimation(brushData, completeWithStatic)
    if brushData ~= nil then
        if utils.isNbFramesEnough(app.frame, brushData.nbCells) then

            local specDict  = brushData.specs
            for k, v in pairs(brushData.imgs) do
                local specs = ImageSpec{
                    width            = specDict[k].width,
                    height           = specDict[k].height,
                    colorMode        = specDict[k].colorMode,
                    transparentColor = specDict[k].transparentColor
                }
                local imgBytes = utils.decode(brushData.imgs[k])
                local frame    = app.sprite.frames[app.frame.frameNumber + k - 1]
                draw.drawImgOnCel(app.layer, frame, imgBytes, specs)
            end
            
            if completeWithStatic then
                drawCompleteWithStatic(brushData)
            end
        else
            app.alert("There is not enough frames left to draw the animation. Aborting.")
        end
    end
end

return draw