-- Animated Brush Extension
-- Made by Fabico
--
-- This file is released under the terms of the MIT license.
-- Read LICENSE.txt for more information.

-- Processing module

local utils = require("src.utils")

if processing then return end

local processing = {}

---Copy a selection from a Cel into a new image.
---@param selection Selection
---@param celNb int
---@return Image
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

---Add new colors found in the image to colors table
---@param img any
---@param colors any
function processing.colorsFromImg(img, colors)
    for pix in img:pixels() do
        if app.pixelColor.rgbaA(pix()) ~= 0 then
            colors[pix()] = 0
        end
    end
end

---Replace color from an image
---@param img Image
---@param old Color
---@param new Color
function processing.replaceColor(img, old, new)
    for pix in img:pixels() do
        if pix() == old.rgbaPixel then
            pix(new.rgbaPixel)
        end
    end
end

---Replace color from multiple images at once. Take an imgs dict bytes string
---in parameter.
---@param imgs any
---@param specDict any
---@param old any
---@param new any
---@return table
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

---Flip all images horizontally or vertically
---@param imgs any
---@param specDict any
---@param flipT FlipType
---@return table
function processing.flipBatch(imgs, specDict, flipT)
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
        img:flip(flipT)
        imgsBytesReplaced[k] = utils.encode(img.bytes)
    end
    return imgsBytesReplaced
end

---Create a preview image which is the 1st frame from the animation.
---If width or height > 100, the image is resized.
---@param imgBytesEnc any
---@param specDict any
---@return unknown
function processing.createPreview(imgBytesEnc, specDict)
    local specs = ImageSpec{
        width            = specDict.width,
        height           = specDict.height,
        colorMode        = specDict.colorMode,
        transparentColor = specDict.transparentColor
    }
    local imgBytes = utils.decode(imgBytesEnc)
    local img      = Image(specs)
    img.bytes      = imgBytes

    local preview = img:clone()
    if preview.width > 100 or preview.height > 100 then
        local w = math.min(preview.width, 100)
        local h = math.min(preview.height, 100)
        preview:resize(w, h)
    end
    return preview
end

return processing