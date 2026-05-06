local Input = require("selene.input")
local Camera = require("selene.camera")
local Grid = require("selene.grid")
local Game = require("selene.game")
local Entities = require("selene.entities")
local Network = require("selene.network")

local UseManager = require("illarion-gobaith-ui.client.lua.lib.useManager")

local Cursor = Entities.create("illarion:tile_cursor")
Cursor:spawn()

local wasChar = false
local useCursor = nil
local useTarget = nil

Game.preTick:connect(function()
    local mouseX, mouseY = Input.getMousePosition()
    local worldX, worldY = Camera.screenToWorld(mouseX, mouseY)
    local cameraCoordinate = Camera.getCoordinate()
    local coordinate = Grid.screenToCoordinate(worldX, worldY, cameraCoordinate:getZ())
    if (Cursor:getCoordinate() ~= coordinate) then
        local cursorShadow = Entities.create("illarion:tile_cursor_shadow")
        if wasChar then
            cursorShadow:addComponent("illarion:visual", {
                type = "visual",
                visual = "illarion:char_cursor"
            })
        end
        cursorShadow:setCoordinate(Cursor:getCoordinate())
        cursorShadow:spawn()

        Cursor:setCoordinate(coordinate)

        local isChar = #Entities.findEntitiesAt(coordinate, {
            tag = "illarion:character"
        }) > 0
        if isChar and not wasChar then
            Cursor:addComponent("illarion:visual", {
                type = "visual",
                visual = "illarion:char_cursor"
            })
        elseif not isChar and wasChar then
            Cursor:addComponent("illarion:visual", {
                type = "visual",
                visual = "illarion:tile_cursor"
            })
        end
        wasChar = isChar
    end
end)

Input.bindAction(Input.MOUSE, "left", function(screenX, screenY)
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        local worldX, worldY = Camera.screenToWorld(screenX, screenY)
        local cameraCoordinate = Camera.getCoordinate()
        local coordinate = Grid.screenToCoordinate(worldX, worldY, cameraCoordinate:getZ())
        if not useCursor then
            useCursor = Entities.create("illarion:use_cursor")
            useCursor:setCoordinate(coordinate)
            useCursor:spawn()
            useTarget = {
                type = "coordinate",
                coordinate = coordinate,
                reset = function()
                    if useCursor then
                        useCursor:despawn()
                    end
                    useCursor = nil
                    useTarget = nil
                end
            }
            table.insert(UseManager.useTargets, useTarget)
        else
            useTarget.coordinate = coordinate
            useCursor:setCoordinate(coordinate)
        end
    end
end)

