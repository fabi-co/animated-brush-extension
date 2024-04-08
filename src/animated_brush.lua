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

-- Event code returned for deactivating
local listenerCode = -1

-- Flag to complete empty frames
local completeWithStatic = false

-- Returns false if there is no selection on canvas
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
                draw.drawAnimation(currentAnimBrush, completeWithStatic)
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

    -- If dialog already opened in draw mode, return.
    if drawMode then
        return -1
    end

    -- Set global draw mode
    drawMode = true
    activateAnimatedMode(tabData)

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

    dlg.bounds = Rectangle(0, 0, 300, 150)

    dlg:color{ id="col", label="color", color=app.Color}
       :combobox{ 
            id="animBrushCbbox",
            label="Animated sprite",
            option="None",
            options=brushesNames(tabData),
            onchange=function(a)
                currentAnimBrush = tabData[dlg.data["animBrushCbbox"]:gsub("%s+", "")]
                dlg:modify{ 
                    id="labelNbFramesAnim",
                    activated=true,
                    text=currentAnimBrush.nbCells
                }
                setAnimatedBrush(currentAnimBrush)
            end
        }
       :label{
            id="labelNbFramesAnim",
            label="Number of frames :",
            activated=currentAnimBrush~=nil,
            text=currentAnimBrush~=nil and tostring(currentAnimBrush.nbCells) or ""
        }
       :check{
            id="completeStaticAnim",
            label="Complete with static",
            text="Complete all frames from the layer with the first frame from the animation",
            selected=false,
            onclick=function() 
                completeWithStatic = dlg.data.completeStaticAnim
            end
       } 
       :shades{ 
            id="shadesAnimBrush",
            mode="sort",
            colors={Color{ r=58, g=120, b=135, a=255 }, Color{ r=110, g=35, b=195, a=255 }, Color{ r=15, g=190, b=130, a=255 }}
        }
       :show{ wait=false }

    
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