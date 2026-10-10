local Input = require("selene.input")
local Camera = require("selene.camera")
local Grid = require("selene.grid")
local Game = require("selene.game")
local Entities = require("selene.entities")
local Network = require("selene.network")
local Timelines = require("selene.timelines")

local Cursor = Entities.create("illarion:tile_cursor")
Cursor:spawn()

local wasChar = false
local useCursor = nil
local attackCursor = nil
local attackTargetId = nil
local magicMode = false
local magicTarget = nil
local magicTargetId = nil

local function isMagicPressed()
    return Input.isKeyPressed("L-Alt") or Input.isKeyPressed("R-Alt")
end

local function clearMagicTarget()
    if magicTarget then
        magicTarget:despawn()
        magicTarget = nil
    end
    magicTargetId = nil
end

local function clearUseTarget()
    if useCursor then
        useCursor:despawn()
        useCursor = nil
    end
end

Input.bindReleaseAction(Input.KEYBOARD, "L-Shift", clearUseTarget)
Input.bindReleaseAction(Input.KEYBOARD, "R-Shift", clearUseTarget)

Network.handlePayload("illarion:set_combat_target", function(payload)
    if attackCursor then
        attackCursor:despawn()
        attackCursor = nil
    end

    attackTargetId = nil
    if payload.networkId == -1 then
        return
    end

    attackTargetId = payload.networkId
end)

Game.preTick:connect(function()
    local magicPressed = isMagicPressed()
    if magicPressed ~= magicMode then
        magicMode = magicPressed
        if not magicMode then
            clearMagicTarget()
        end
    end

    if attackTargetId then
        local attackTarget = Entities.getEntityByNetworkId(attackTargetId)
        if attackTarget then
            if not attackCursor then
                attackCursor = Entities.create("illarion:attack_cursor")
                attackCursor:setCoordinate(attackTarget:getCoordinate())
                attackCursor:attachTo(attackTarget:getNetworkId())
                attackCursor:spawn()
            end
        elseif attackCursor then
            attackCursor:despawn()
            attackCursor = nil
        end
    end

    if magicTarget and magicTargetId then
        local target = Entities.getEntityByNetworkId(magicTargetId)
        if target then
            magicTarget:attachTo(target:getNetworkId())
        else
            clearMagicTarget()
        end
    end

    local mouseX, mouseY = Input.getMousePosition()
    local worldX, worldY = Camera.screenToWorld(mouseX, mouseY)
    local cameraCoordinate = Camera.getCoordinate()
    local coordinate = Grid.screenToCoordinate(worldX, worldY, cameraCoordinate:getZ())
    local cursorCoordinate = Cursor:getCoordinate()
    local cursorMoved = cursorCoordinate.x ~= coordinate.x
        or cursorCoordinate.y ~= coordinate.y
        or cursorCoordinate.z ~= coordinate.z
    if cursorMoved then
        Timelines.playAt(
            cursorCoordinate,
            wasChar and "illarion:char_cursor_shadow" or "illarion:tile_cursor_shadow"
        )

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
    local worldX, worldY = Camera.screenToWorld(screenX, screenY)
    local cameraCoordinate = Camera.getCoordinate()
    local coordinate = Grid.screenToCoordinate(worldX, worldY, cameraCoordinate:getZ())

    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    local isCtrlPressed = Input.isKeyPressed("L-Ctrl") or Input.isKeyPressed("R-Ctrl")
    if isMagicPressed() then
        clearMagicTarget()
        magicTarget = Entities.create("illarion:magic_target")
        magicTarget:setCoordinate(coordinate)
        magicTarget:spawn()
        local entities = Entities.findEntitiesAt(coordinate, {
            tag = "illarion:character"
        })
        if #entities == 0 then
            entities = Entities.findEntitiesAt(coordinate, {
                tag = "illarion:item"
            })
        end
        if #entities > 0 then
            magicTargetId = entities[#entities]:getNetworkId()
        end
    elseif isShiftPressed then
        if not useCursor then
            useCursor = Entities.create("illarion:use_cursor")
            useCursor:setCoordinate(coordinate)
            useCursor:spawn()
        else
            useCursor:setCoordinate(coordinate)
        end
    elseif isCtrlPressed then
        local entities = Entities.findEntitiesAt(coordinate, {
            tag = "illarion:character"
        })
        local entity = entities[#entities]
        if entity then
            local networkId = entity:getNetworkId()
            Network.sendToServer("illarion:set_combat_target", {
                networkId = networkId == attackTargetId and -1 or networkId
            })
        end
    else
        local entities = Entities.findEntitiesAt(coordinate, {
            tag = "illarion:supports_look_at"
        })
        local entity = entities[#entities]
        if entity then
            Network.sendToServer("illarion:look_at_entity", {
                networkId = entity:getNetworkId()
            })
        else
            Network.sendToServer("illarion:look_at", {
                x = coordinate.x,
                y = coordinate.y,
                z = coordinate.z
            })
        end
    end
end)
