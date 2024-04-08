local utils = require("src.utils")

if processing then return end

local processing = {}

-- Copy a selection from a Cel into a new image.
function processing.getAreaFromCel(selection, celNb)
    local img

    if not(app.layer.isImage) or app.layer:cel(celNb) == nil or
       selection.isEmpty then
        img = Image(selection.bounds)
        return img
    end

    local cel        = app.layer:cel(celNb)
    local rectSelect = selection.bounds

    rectSelect.x = rectSelect.x - cel.bounds.x
    rectSelect.y = rectSelect.y - cel.bounds.y

    img = Image(cel.image, rectSelect)
    return img
end

-- Add new colors found in the image to colors table
function processing.colorsFromImg(img, colors)
    for pix in img:pixels() do
        colors[pix()] = 0
    end
end

-- Replace color from an image
function processing.replaceColor(img, old, new)
    for pix in img:pixels() do
        if pix() == old.rgbaPixel then
            pix(new.rgbaPixel)
        end
    end
end

function processing.replaceColorBatch(imgs, specDict, old, new)
    local imgsBytesReplaced = {}
    for k, v in pairs(imgs) do
        local specs = ImageSpec{
            width            = specDict[k].width,
            height           = specDict[k].height,
            colorMode        = specDict[k].colorMode,
            transparentColor = specDict[k].transparentColor
        }
        local imgBytes = utils.decode(imgs[k])
        local img      = Image(specs)
        img.bytes      = imgBytes
        processing.replaceColor(img, old, new)
        imgsBytesReplaced[k] = utils.encode(img.bytes)
    end
    return imgsBytesReplaced
end

return processing