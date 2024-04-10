-- Animated Brush Extension
-- Made by Fabico
--
-- This file is released under the terms of the MIT license.
-- Read LICENSE.txt for more information.

local draw       = require("src.draw")
local utils      = require("src.utils")
local processing = require("src.processing")
local serializer = require("src.serializer")

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

-- Flag that determines if the data is reset on export
local resetOnExport = false

-- Use to monitor the name of last command used
local commandName = nil

-- Id of the use animation dialog
local useAnimDlg = nil

---If there is an active sprite and a selection, returns true to use
---add anim.
---@return boolean
local function enableAddAnimBrush()
    local spr = app.sprite
    if spr == nil or spr.selection == nil or spr.selection.isEmpty then
        return false
    end
    return true
end

---Set the tool to pencil and the brush image to the img of
---brushData.
---@param brushData Dict brush data dict
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

---Flip images from current brush horizontally
local function onClickFlipH()
    if not currentAnimBrush then return end

    local brushCopy = utils.deepCopyTable(currentAnimBrush)
    brushCopy.imgs = processing.flipBatch(
        brushCopy.imgs,
        brushCopy.specs,
        FlipType.HORIZONTAL
    )

    currentAnimBrush = brushCopy
    setAnimatedBrush(brushCopy)
end


---Flip images from current brush vertically
local function onClickFlipV()
    if not currentAnimBrush then return end

    local brushCopy = utils.deepCopyTable(currentAnimBrush)
    brushCopy.imgs = processing.flipBatch(
        brushCopy.imgs,
        brushCopy.specs,
        FlipType.VERTICAL
    )

    currentAnimBrush = brushCopy
    setAnimatedBrush(brushCopy)
end

--- Function called when event on sprite happened
---@param tabData Dict dict of brush data dict
---@return function
local function onChange(tabData)
    return function(ev)
        if ev == nil or ev.fromUndo then
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

---Called when a command begins. Used to keep trace of last command name.
---Catch flip brush event when use anim mode on.
---@param ev any
local function onCommandBegin(ev)
    commandName = ev.name
    if ev.name == "ChangeBrush" and useAnimDlg and currentAnimBrush then
        ev.stopPropagation()
        if ev.params.change == "flip-x" then
            onClickFlipH()
        elseif ev.params.change == "flip-y" then
            onClickFlipV()
        end
    end
end

---Called when a command ends.
---@param ev any
local function onCommandEnd(ev)
    commandName = nil
end

---Called when fg or bg color changed. Reinit currentanimBrush
---beause we don't want those cha,ges to apply on animated brush.
local function onFgBgColorChange()
    if currentAnimBrush ~= nil then
        setAnimatedBrush(currentAnimBrush)
    end
end

---Close useanimDlg when sprite is changed.
local function onSiteChange()
    if app.sprite == nil then
        if useAnimDlg ~= nil then
            useAnimDlg:close()
        end
    end
end

---Used to pick or change color from the animated brush.
---Left click pick, right click change.
---@param ev any
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

        local brushCopy = utils.deepCopyTable(currentAnimBrush)
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

---Save the changes made at currentAnimBrush in tabData.
---@param ev any
---@param tabData Dict dict of brush data dict
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

---When change selection in useanim dialog, update what needs to be updated.
---@param ev any
---@param tabData Dict dict of brush data dict
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

---Draw first frame from animation on canvas dialog.
---@param ev any
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

---Handle export to json file action
---@param tabData table
---@param fn string filename
local function onExport(tabData, fn, dlg)
    local ok, err = serializer.writeInFile(tabData, fn)
    if not ok then
        app.alert(err)
        return
    end

    if resetOnExport then
        utils.resetTab(tabData)
    end

    useAnimDlg:close()
    dlg:close()
end


local function onImport(tabData, count, fn, dlg)
    local data, err = serializer.readData(fn)
    if not data then
        app.alert(err)
        return
    end

    local nbAdded = utils.mergeTables(tabData, data)
    count[1] = count[1] + nbAdded
    useAnimDlg:close()
    dlg:close()
end

------------- ENTER / EXIT ANIM MODE ----------

---Activate animation mode. Set all events and currentAnimBrush.
---@param tabData Dict dict of brush data dict
---@return integer
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

---Exit animation mode. Remove all events and reinit global vars.
---Set the brush to pencil point.
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
    useAnimDlg         = nil
    completeWithStatic = false
    loopBack           = false
end

----------------------------------------------------
------------------ Dialogs -------------------------
----------------------------------------------------

---Handle Add anim dialog. Available only if there is a selection and an active sprite.
---Copy the images from the selected cells in tabData.
---@param tabData Dict dict of brush data dict
---@param count Dict dict containing 1 entry -> count (for reference passage)
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

        if utils.tabKeyExists(tabData, name:gsub("%s+", "")) then
            app.alert("This name is not valid or already exists, chose another one.")
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

---Settings fialog for import / export
---@param tabData any
---@param count any
local function showConfigDlg(tabData, count)
    local dlg = Dialog("Config")
    dlg.bounds = Rectangle(50, 50, 200, 100)
    dlg:separator{
            text=" CONFIG "
        }
        :check{
            id="checkExportReset",
            label="Reset local data when export :",
            selected=false,
            onclick=function()
                resetOnExport = dlg.data.checkExportReset
            end
        }
        :file{ id="animExport",
          label="Export animated brushes : ",
          title="Export",
          open=false,
          save=true,
          filename="exported_anim.json",
          filetypes={ "json" },
          onchange=function() onExport(tabData, dlg.data.animExport, dlg) end
        }
        :file{ id="animImport",
          label="Import animated brushes : ",
          title="Import",
          open=true,
          save=false,
          filename="exported_anim.json",
          filetypes={ "json" },
          onchange=function() onImport(tabData, count, dlg.data.animImport, dlg) end
        }
        :show()
end

---Use anim dialog.
---@param tabData Dict dict of brush data dict
---@param count any Dict dict containing 1 entry -> count (for reference passage)
local function showUseAnimDlg(tabData, count)
    -- If dialog already opened in draw mode, return.
    if drawMode then
        return
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
       :button{
            id="animSettings",
            text="Config",
            onclick=function() showConfigDlg(tabData, count) end
       }
       :separator{
            text=" Animation Settings"
       }
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
            selected=false,
            onclick=function() 
                completeWithStatic = useAnimDlg.data.completeStaticAnim
            end
       } 
       :check{
            id="loopBackAnim",
            label="Return frame 1 if not enough:",
            selected=false,
            onclick=function() 
                loopBack = useAnimDlg.data.loopBackAnim
            end
       }
       :separator{
            text=" Brush Settings"
       }
       :entry{
            id="entryNameAnim",
            label="Name:",
            activated=currentAnimBrush~=nil,
            text=currentAnimBrush~=nil and tostring(currentAnimBrush.name) or ""
       }
       :label{
            id="labelNbFramesAnim",
            label="Number of frames:",
            activated=currentAnimBrush~=nil,
            text=currentAnimBrush~=nil and tostring(currentAnimBrush.nbCells) or ""
        }
       :button{
            id="flipBrushH",
            text="Flip H",
            onclick=function() onClickFlipH() end
       }
       :button{
            id="flipBrushH",
            text="Flip V",
            onclick=function() onClickFlipV() end
       }
       :shades{ 
            id="shadesAnimBrush",
            label="Colors:",
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
       :button{
        id="deleteAnim",
        text="Delete",
        selected="false",
        focus="false",
        activated=currentAnimBrush~=nil,
        onclick=function(ev)
            if currentAnimBrush == nil then
                return
            end
            local dlg = Dialog("Confirm"):button{id="confirm", text="Confirm the delete ? No backward."}
                        :show()

            if dlg.data.confirm then
                local nameKey     = currentAnimBrush.name:gsub("%s+", "")
                tabData[nameKey]  = nil
                useAnimDlg:close()
                showUseAnimDlg(tabData, count)
            end
        end
       }
       :separator{
            text=" Preview 1st frame "
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