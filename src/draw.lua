-- Draw Module --

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

return draw