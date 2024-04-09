local draw       = require("src.draw")
local utils      = require("src.utils")
local processing = require("src.processing")

-- True if use animated mode is on
local drawMode = false

-- Id of the current anim brush if draw mode, nil otherwise
local currentAnimBrush = nil

-- Event code returned for deactivating
local listenerCode = -1

-- Flag to complete empty frames
local completeWithStatic = false

-- Flag for the animation to loop frame 1 if not enough frames left
local loopBack = false

-- Use to monitor the name of last command used
local commandName = nil

-- Id of the use animation dialog
local useAnimDlg = nil

-- Returns false if there is no selection on canvas
local function enableAddAnimBrush()
    local spr = app.sprite
    if spr == nil or spr.selection == nil or spr.selection.isEmpty then
        return false
    end
    return true
end

-- Set the tool to pencil and the brush image to the img of
-- brushData.
local function setAnimatedBrush(brushData)
    if brushData == nil then
        return
    end
    
    local specDict = brushData.specs
    local spec     = ImageSpec{
        width            = specDict[1].width,
        height           = specDict[1].height,
        colorMode        = specDict[1].colorMode,
        transparentColor = specDict[1].transparentColor
    }
    local imgBrush = Image(spec)

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

---------------------------------------------------
------------------ EVENTS -------------------------
---------------------------------------------------

-- Function called when event on sprite happened
local function onChange(tabData)
    return function(ev)
        if ev == nil then
            return -1
        end

        if ev.fromUndo then
            return -1
        end

        if commandName ~= nil and #commandName > 0 then
            return -1
        end

        if app.tool.id ~= "pencil" or app.brush.type ~= BrushType.IMAGE then
            if useAnimDlg ~= nil then
                useAnimDlg:close()
            end
        end

        if currentAnimBrush ~= nil then
            local error, msg = draw.drawAnimation(currentAnimBrush, completeWithStatic, loopBack)

            if error ~= 0 then
                app.alert(msg)
            end
        end

    end
end

local function onCommandBegin(ev)
    commandName = ev.name
end

local function onCommandEnd(ev)
    commandName = nil
end

local function onFgBgColorChange()
    if currentAnimBrush ~= nil then
        setAnimatedBrush(currentAnimBrush)
    end
end

local function onSiteChange()
    if app.sprite == nil then
        if useAnimDlg ~= nil then
            useAnimDlg:close()
        end
    end
end

local function onClickShade(ev)
    if ev.button == MouseButton.LEFT then
        app.fgColor = ev.color
    elseif ev.button == MouseButton.RIGHT then
        local colors = useAnimDlg.data.shadesAnimBrush
        utils.replaceColorInTab(ev.color, app.fgColor, colors)

        useAnimDlg:modify{
            id="shadesAnimBrush",
            colors=colors
        }

        brushCopy = utils.deepCopyTable(currentAnimBrush)
        brushCopy.imgs = processing.replaceColorBatch(
            brushCopy.imgs,
            brushCopy.specs,
            ev.color,
            app.fgColor
        )

        brushCopy.colors = utils.colorsToRGBAPixels(colors)
        currentAnimBrush = brushCopy
        setAnimatedBrush(brushCopy)
    end
end

local function onClickSave(ev, tabData)
    if currentAnimBrush == nil then
        return
    end

    local prevName    = currentAnimBrush.name
    local newName     = useAnimDlg.data.entryNameAnim
    local prevNameKey = prevName:gsub("%s+", "")
    local newNameKey  = newName:gsub("%s+", "")

    if prevName ~= newName or #newName < 3 then
        if utils.tabKeyExists(tabData, newNameKey) then
            app.alert("This name is not valid or already exists, chose another one.")
            return
        end
    end

    currentAnimBrush.name = newName
    tabData[prevNameKey]  = nil
    tabData[newNameKey]   = currentAnimBrush
    useAnimDlg:modify{
        id      = "animBrushCbbox",
        options = utils.getBrushesNames(tabData)
    }
end

local function onCbboxChange(ev, tabData)
    currentAnimBrush = tabData[useAnimDlg.data["animBrushCbbox"]:gsub("%s+", "")]
    useAnimDlg:modify{ 
        id="labelNbFramesAnim",
        activated=true,
        text=currentAnimBrush.nbCells
    }
    useAnimDlg:modify{
        id="shadesAnimBrush",
        colors=utils.colorsFromInts(currentAnimBrush.colors)
    }
    useAnimDlg:modify{
        id="entryNameAnim",
        text=currentAnimBrush.name
    }
    useAnimDlg:repaint()
    setAnimatedBrush(currentAnimBrush)
end

local function onCanvasPaint(ev)
    if currentAnimBrush == nil then
        return
    end
    
    local gc       = ev.context
    local prevData = currentAnimBrush.preview
    local specs    = ImageSpec{
        width            = prevData.width,
        height           = prevData.height,
        colorMode        = prevData.colorMode,
        transparentColor = prevData.transparentColor
    }
    local imgBytes = utils.decode(prevData.bytes)
    local img      = Image(specs)
    img.bytes      = imgBytes
    gc:drawImage(img, 0, 0)
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
    app.events:on("beforecommand", onCommandBegin)
    app.events:on("aftercommand", onCommandEnd)
    app.events:on("fgcolorchange", onFgBgColorChange)
    app.events:on("bgcolorchange", onFgBgColorChange)
    app.events:on("sitechange", onSiteChange)
end

-- Exit anim mode
local function exitAnimMode()
    drawMode         = false
    currentAnimBrush = nil

    if listenerCode > -1 then
        if app.sprite ~= nil then
            app.sprite.events:off(listenerCode)
        end
        app.events:off(onCommandBegin)
        app.events:off(onCommandEnd)
        app.events:off(onFgBgColorChange)
        app.events:off(onSiteChange)
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
    useAnimDlg = nil
end

----------------------------------------------------
------------------ Dialogs -------------------------
----------------------------------------------------

local function showAddAnimDlg(tabData, count)

    if not(enableAddAnimBrush()) then
        print("No selected area")
        return
    end

    if useAnimDlg ~= nil then
        useAnimDlg:close()
    end

    local frameNb  = app.frame.frameNumber
    local nbFrames = #app.range.frames
    local frames   = app.range.frames
    local selArea  = app.sprite.selection

    local data =
        Dialog("ADD AN ANIMATED BRUSH"):label{id="addAnimLabel", text="ADD AN ANIMATED BRUSH."}
                :separator()
                :label{id="nameAddAnimBrushLabel", text="Name of the animated brush."}
                :entry{id="nameAddAnimBrush", text="Animation " ..tostring(count[1])}
                :button{id="addAnimBrush", text="Add brush", focus=true}
                :show().data

    if data.addAnimBrush then
        local name = data.nameAddAnimBrush
        if  name == nil or #name < 3 then
            app.alert("You must enter a name.")
            return
        end

        local imgs   = {}
        local specs  = {}
        local colors = {}

        for i, frame in ipairs(frames) do
            local img = processing.getAreaFromCel(selArea, frame.frameNumber)
            
            processing.colorsFromImg(img, colors)
            imgs[i] = utils.encode(img.bytes)
            specs[i] = {
                ["width"]            = img.spec.width, 
                ["height"]           = img.spec.height,
                ["colorMode"]        = img.spec.colorMode, 
                ["transparentColor"] = img.spec.transparentColor
            }
        end

        local previewImg = processing.createPreview(imgs[1], specs[1])
        local preview    = {
            ["width"]            = previewImg.spec.width, 
            ["height"]           = previewImg.spec.height,
            ["colorMode"]        = previewImg.spec.colorMode, 
            ["transparentColor"] = previewImg.spec.transparentColor,
            ["bytes"]            = utils.encode(previewImg.bytes)
    }

        count[1] = count[1] + 1
        tabData[name:gsub("%s+", "")] = {
            ["imgs"]    = imgs,
            ["specs"]   = specs,
            ["nbCells"] = nbFrames,
            ["name"]    = name,
            ["colors"]  = utils.getKeys(colors),
            ["preview"] = preview
        }
    end
end

local function showUseAnimDlg(tabData, count)
    -- If dialog already opened in draw mode, return.
    if drawMode then
        return -1
    end

    -- Set global draw mode
    drawMode = true
    activateAnimatedMode(tabData)

    useAnimDlg = Dialog{
        title="USE AN ANIMATED BRUSH",
        onclose=exitAnimMode
    }

    useAnimDlg.bounds = Rectangle(0, 0, 220, 300)

    useAnimDlg
       :combobox{ 
            id="animBrushCbbox",
            label="Animated brush :",
            option="None",
            options=utils.getBrushesNames(tabData),
            onchange=function(ev)
                onCbboxChange(ev, tabData)
            end
        }
       :check{
            id="completeStaticAnim",
            label="Draw anim 1 on other frames:",
            -- text="Complete other frames with animation frame 1.",
            selected=false,
            onclick=function() 
                completeWithStatic = useAnimDlg.data.completeStaticAnim
            end
       } 
       :check{
            id="loopBackAnim",
            label="Return frame 1 if not enough:",
            -- text="Returns frame 1 if not enough frames left",
            selected=false,
            onclick=function() 
                loopBack = useAnimDlg.data.loopBackAnim
            end
       }
       :separator{
            text="Brush"
       }
       :entry{
            id="entryNameAnim",
            label="name",
            activated=currentAnimBrush~=nil,
            text=currentAnimBrush~=nil and tostring(currentAnimBrush.name) or ""
       }
       :label{
            id="labelNbFramesAnim",
            label="Number of frames:",
            activated=currentAnimBrush~=nil,
            text=currentAnimBrush~=nil and tostring(currentAnimBrush.nbCells) or ""
        }
       :shades{ 
            id="shadesAnimBrush",
            label="colors",
            mode="sort",
            colors=currentAnimBrush~=nil and utils.colorsFromInts(currentAnimBrush.colors) or {},
            onclick=onClickShade
        }
       :button{
        id="saveChangeAnim",
        text="Save",
        selected="false",
        focus="false",
        activated=currentAnimBrush~=nil,
        onclick=function(ev)
            onClickSave(ev, tabData)
        end
       }
       :separator{
            text="Preview 1st frame"
        }
       :canvas{
        id="canvasPreview",
        width=100,
        height=100,
        hexpand=false,
        vexpand=false,
        onpaint=onCanvasPaint
       }
       :show{ wait=false }
       
end

function init(plugin)  
    -- we can use "plugin.preferences" as a table with fields for
    -- our plugin (these fields are saved between sessions)

    if plugin.preferences.data == nil then
        plugin.preferences.data  = {}
        plugin.preferences.count = {0}
    end

    --
    plugin:newCommand{
      id="new_animated_brush",
      title="New animated brush",
      group="edit_new",
      onenabled=enableAddAnimBrush,
      onclick=function()
        showAddAnimDlg(plugin.preferences.data, plugin.preferences.count)
      end
    }

    --
    plugin:newCommand{
      id="use_animated_brush",
      title="Use animated brush",
      group="edit_new",
      onenabled=app.sprite~=nil,
      onclick=function()
        showUseAnimDlg(plugin.preferences.data, plugin.preferences.count)
      end
    }

  end
  
  function exit(plugin)
    if useAnimDlg ~= nil then
        useAnimDlg:close()
    end
  end