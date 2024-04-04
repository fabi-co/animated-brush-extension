local draw  = require("src.draw")
local utils = require("src.utils")

-- Snippet
    -- for pix in img:pixels() do
    --     print(pix.x, pix.y)
    --     print(app.pixelColor.rgbaR(pix()))
    --     print(app.pixelColor.rgbaG(pix()))
    --     print(app.pixelColor.rgbaB(pix()))
    --     print(app.pixelColor.rgbaA(pix()))
    -- end

-- True if use animated mode is on
local drawMode = false

-- Id of the current anim brush if draw mode, nil otherwise
local currentAnimBrush = nil

-- Use for 
local listenerCode = -1

-- Select an area from the image
local function selectedArea()
    if app.brush == nil then return end
 
    local brush            = app.brush
    local transformedImage = brush.image

    if brush.image ~= nil then
        for pixel in brush.image:pixels() do
            transformedImage:drawPixel(pixel.x, pixel.y, app.pixelColor.rgba(255, 0, 0))
        end
    end

    -- transformedImage:resize(brush.image.width + 1, brush.image.height + 1)

    app.brush = Brush {
        type = brush.type,
        size = brush.size + 2,
        angle = brush.angle,
        center = brush.center,
        pattern = brush.pattern,
        patternOrigin = brush.patternOrigin,
        image = transformedImage
    }

end

-- Return false if there is no selection on canvas
local function enableAddAnimBrush()
    local spr = app.sprite
    if spr == nil or spr.selection == nil or spr.selection.isEmpty then
        return false
    end
    return true
end



-- Copy a selection from a Cel into a new image.
local function getAreaFromCel(selection, celNb)
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

-- Set the tool to pencil and the brush image to the img of
-- brushData.
local function setAnimatedBrush(brushData)
    if brushData == nil then
        return
    end
    
    local specDict  = brushData.specs
    local spec      = ImageSpec{
        width            = specDict[1].width,
        height           = specDict[1].height,
        colorMode        = specDict[1].colorMode,
        transparentColor = specDict[1].transparentColor
    }
    local imgBrush  = Image(spec)

    imgBrush.bytes = utils.decode(brushData.imgs[1])

    app.tool = "pencil"
    app.brush = Brush {
        type          = BrushType.IMAGE ,
        size          = app.brush.size,
        angle         = app.brush.angle,
        center        = app.brush.center,
        pattern       = BrushPattern.NONE,
        patternOrigin = nil,
        image         = imgBrush
    }
end

-- Check if the number of frames left < nbFrames
local function isNbFramesEnough(frame, nbFrames)
    return (#app.sprite.frames - frame.frameNumber + 1) >= nbFrames
end

-- Draw a brush animation on multiple cels from the current layer
local function drawAnimation(brushData)
    if brushData ~= nil then
        if isNbFramesEnough(app.frame, brushData.nbCells) then
            for k, v in pairs(brushData.imgs) do
                local brushName = brushData.name
                local specDict  = brushData.specs
                local spec      = ImageSpec{
                    width            = specDict[k].width,
                    height           = specDict[k].height,
                    colorMode        = specDict[k].colorMode,
                    transparentColor = specDict[k].transparentColor
                }
                local imgBytes = utils.decode(brushData.imgs[k])
                local frame    = app.sprite.frames[app.frame.frameNumber + k - 1]
                draw.drawImgOnCel(app.layer, frame, imgBytes, spec)
                
            end
        end
    end
end

-- Function called when event on sprite happened
local function onChange(tabData)
    return function(ev)
        if ev == nil then
            return 2
        end
        if ev.fromUndo then
            return 1
        end

        if app.tool.id == "pencil" and app.brush.type == BrushType.IMAGE then
            if currentAnimBrush ~= nil then
                drawAnimation(currentAnimBrush)
            end
        end
    end
end

------------- ENTER / EXIT ANIM MODE ----------

-- Activate anim mode
local function activateAnimatedMode(tabData)
    local brushData  = utils.getFirstElement(tabData)
    currentAnimBrush = brushData
    if tabData == nil or brushData == nil then
        return 0
    end
    
    setAnimatedBrush(brushData)
    listenerCode = app.sprite.events:on('change', onChange(tabData))
end

-- Exit anim mode
local function exitAnimMode()
    drawMode         = false
    currentAnimBrush = nil

    if listenerCode > -1 then
        app.sprite.events:off(listenerCode)
        listenerCode = -1
    end

    app.tool = "pencil"
    app.brush = Brush {
        type =  BrushType.CIRCLE,
        size = app.brush.size,
        angle = app.brush.angle,
        center = app.brush.center,
        pattern = app.brush.pattern,
        patternOrigin = app.brush.patternOrigin,
        image = nil
    }
end
----------------------------------------------------
------------------ Dialogs -------------------------
----------------------------------------------------

local function showAddAnimDlg(tabData)

    if not(enableAddAnimBrush()) then
        print("No selected area")
        return
    end

    local frameNb  = app.frame.frameNumber
    local nbFrames = #app.range.frames
    local frames   = app.range.frames
    local selArea  = app.sprite.selection

    local data =
        Dialog("ADD AN ANIMATED BRUSH"):label{id="addAnimLabel", text="ADD AN ANIMATED BRUSH."}
                :separator()
                :label{id="nameAddAnimBrushLabel", text="Name of the animated brush."}
                :entry{id="nameAddAnimBrush", text = ""}
                :button{id="addAnimBrush", text="Add brush"}
                :show().data

    if data.addAnimBrush then
        local name = data.nameAddAnimBrush
        if  name == nil or #name < 3 then
            app.alert("You must enter a name.")
            return
        end

        local imgs  = {}
        local specs = {}
        for i, frame in ipairs(frames) do
            local img = getAreaFromCel(selArea, frame.frameNumber)
            imgs[i] = utils.encode(img.bytes)
            specs[i] = {
                ["width"]            = img.spec.width, 
                ["height"]           = img.spec.height,
                ["colorMode"]        = img.spec.colorMode, 
                ["transparentColor"] = img.spec.transparentColor
            }
        end

        tabData[name:gsub("%s+", "")] = {
            ["imgs"]    = imgs,
            ["specs"]   = specs,
            ["nbCells"] = nbFrames,
            ["name"]    = name
        }

    end
end

local function showUseAnimDlg(tabData)

    -- Local utility to display brushes names
    local function brushesNames(tab)
        local names = {}
        for key, value in pairs(tab) do
            table.insert(names, value.name)
        end
        return names
    end

    local dlg = Dialog{
        title="USE AN ANIMATED BRUSH",
        onclose=exitAnimMode
    }

    dlg:color{ id="col", label="color", color=app.Color}
       :combobox{ 
            id="animBrushCbbox",
            label="Animated sprite",
            option="None",
            options=brushesNames(tabData),
            onchange=function(a)
                currentAnimBrush = tabData[dlg.data["animBrushCbbox"]:gsub("%s+", "")]
                setAnimatedBrush(currentAnimBrush)
            end
        }
        :shades{ }
        :show{ wait=false }

    -- Set global draw mode
    drawMode = true
    activateAnimatedMode(tabData)

    
end

function init(plugin)  
    -- we can use "plugin.preferences" as a table with fields for
    -- our plugin (these fields are saved between sessions)

    if plugin.preferences.data == nil then
        plugin.preferences.data = {}
    end

    --
    plugin:newCommand{
      id="new_animated_brush",
      title="New animated brush",
      group="edit_new",
      onenabled=enableAddAnimBrush,
      onclick=function()
        showAddAnimDlg(plugin.preferences.data)
      end
    }

    --
    plugin:newCommand{
      id="use_animated_brush",
      title="Use animated brush",
      group="edit_new",
      onclick=function()
        showUseAnimDlg(plugin.preferences.data)
      end
    }

  end
  
  function exit(plugin)
  end