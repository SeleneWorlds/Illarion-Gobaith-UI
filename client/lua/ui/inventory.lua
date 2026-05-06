local Task = require("selene.task")
local Input = require("selene.input")
local UI = require("selene.ui.lml")
local Network = require("selene.network")
local Visuals = require("selene.visuals")
local Camera = require("selene.camera")
local Grid = require("selene.grid")
local Entities = require("selene.entities")

local UseManager = require("illarion-gobaith-ui.client.lua.lib.useManager")

local m = {}
local worldDragState = nil

local function CreateSlotReferenceName(viewId, slotId)
    return "slot:" .. viewId .. ":" .. slotId
end

local function ParseSlotReference(name)
    if not name then
        return nil
    end

    if not stringx.startsWith(name, "slot:") then
        return nil
    end

    local slotReference = stringx.removePrefix(name, "slot:")
    local separator = slotReference:match("^.*():")
    if not separator then
        return nil
    end

    local viewId = string.sub(slotReference, 1, separator - 1)
    local slotId = tonumber(string.sub(slotReference, separator + 1))
    if not viewId or not slotId then
        return nil
    end

    return {
        viewId = viewId,
        slotId = slotId
    }
end

local function GetCoordinateAtScreenPosition(screenX, screenY)
    local worldX, worldY = Camera.screenToWorld(screenX, screenY)
    local cameraCoordinate = Camera.getCoordinate()
    return Grid.screenToCoordinate(worldX, worldY, cameraCoordinate.Z)
end

local function GetSlotReferenceAtStagePosition(stageX, stageY)
    local hitActor = UI.root:getStage():hit(stageX, stageY)
    if not hitActor then
        return nil
    end

    return ParseSlotReference(hitActor:getName())
end

local function ResetWorldDragState()
    worldDragState = nil
end

local function RegisterWorldDragInput()
    if m.WorldDragRegistered then
        return
    end

    Input.bindPressAction(Input.MOUSE, "left", function(screenX, screenY)
        local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
        if isShiftPressed then
            return
        end

        local stageX, stageY = UI.root:getStage():screenToStage(screenX, screenY)
        if UI.root:getStage():hit(stageX, stageY) then
            return
        end

        local coordinate = GetCoordinateAtScreenPosition(screenX, screenY)
        local itemEntities = Entities.findEntitiesAt(coordinate, {
            tag = "illarion:item"
        })

        if #itemEntities == 0 then
            return
        end

        worldDragState = {
            sourceCoordinate = coordinate,
            startScreenX = screenX,
            startScreenY = screenY
        }
    end)

    Input.bindReleaseAction(Input.MOUSE, "left", function(screenX, screenY)
        if not worldDragState then
            return
        end

        local stageX, stageY = UI.root:getStage():screenToStage(screenX, screenY)
        local targetSlotRef = GetSlotReferenceAtStagePosition(stageX, stageY)
        if targetSlotRef then
            Network.sendToServer("illarion:move_coordinate_to_slot", {
                fromX = worldDragState.sourceCoordinate.x,
                fromY = worldDragState.sourceCoordinate.y,
                fromZ = worldDragState.sourceCoordinate.z,
                toViewId = targetSlotRef.viewId,
                toSlotId = targetSlotRef.slotId
            })
        end

        ResetWorldDragState()
    end)

    m.WorldDragRegistered = true
end

function m.Initialize(hud, skin)
    m.Hud = hud
    m.Skin = skin
    RegisterWorldDragInput()

    Network.handlePayload("illarion:update_slot", function(payload)
        local actor = m.Hud:getActor(CreateSlotReferenceName(payload.viewId, payload.slotId))
        if not actor then
            return
        end

        if payload.item then
            Task.launch(function()
                local visual = Visuals.create(payload.item.visual)
                local style = UI.createImageButtonStyle({
                    imageUp = visual:getDrawable():withoutOffset()
                }, skin)
                actor:setStyle(style)
            end)
        else
            actor:setStyle(m.Skin, "hidden")
        end
    end)
end

local useTarget = nil

function m.slotClick(widget)
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        local slotRef = ParseSlotReference(widget:getName())
        if not slotRef then
            return
        end

        useTarget = {
            type = "inventory",
            viewId = slotRef.viewId,
            slotId = slotRef.slotId,
            reset = function()
                useTarget = nil
            end
        }
        table.insert(UseManager.useTargets, useTarget)
    end
end

function m.slotDragListener(widget)
    return UI.createDragListener({
        onEnd = function(draggable, actor, stageX, stageY)
            local sourceSlotRef = ParseSlotReference(actor:getName())
            local targetSlotRef = GetSlotReferenceAtStagePosition(stageX, stageY)
            if not targetSlotRef then
                if sourceSlotRef then
                    local mouseX, mouseY = Input.getMousePosition()
                    local coordinate = GetCoordinateAtScreenPosition(mouseX, mouseY)
                    Network.sendToServer("illarion:move_slot_to_coordinate", {
                        fromViewId = sourceSlotRef.viewId,
                        fromSlotId = sourceSlotRef.slotId,
                        x = coordinate.x,
                        y = coordinate.y,
                        z = coordinate.z
                    })
                end
                return true
            end

            if sourceSlotRef and targetSlotRef and (
                sourceSlotRef.viewId ~= targetSlotRef.viewId or sourceSlotRef.slotId ~= targetSlotRef.slotId
            ) then
                Network.sendToServer("illarion:move_slot_to_slot", {
                    fromViewId = sourceSlotRef.viewId,
                    fromSlotId = sourceSlotRef.slotId,
                    toViewId = targetSlotRef.viewId,
                    toSlotId = targetSlotRef.slotId
                })
            end
            return true
        end
    })
end

return m
