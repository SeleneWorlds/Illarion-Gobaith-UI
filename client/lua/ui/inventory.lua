local Task = require("selene.task")
local Input = require("selene.input")
local UI = require("selene.ui.lml")
local Network = require("selene.network")
local Visuals = require("selene.visuals")
local Camera = require("selene.camera")
local Grid = require("selene.grid")

local UseManager = require("illarion-gobaith-ui.client.lua.lib.useManager")

local m = {}

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

function m.Initialize(hud, skin)
    m.Hud = hud
    m.Skin = skin

    Network.HandlePayload("illarion:update_slot", function(payload)
        local actor = m.Hud:GetActor(CreateSlotReferenceName(payload.viewId, payload.slotId))
        if not actor then
            return
        end

        if payload.item then
            Task.Launch(function()
                local visual = Visuals.Create(payload.item.visual)
                local style = UI.CreateImageButtonStyle({
                    imageUp = visual.Drawable:WithoutOffset()
                }, skin)
                actor:SetStyle(style)
            end)
        else
            actor:SetStyle(m.Skin, "hidden")
        end
    end)
end

local useTarget = nil

function m.slotClick(widget)
    local isShiftPressed = Input.IsKeyPressed("L-Shift") or Input.IsKeyPressed("R-Shift")
    if isShiftPressed then
        local slotRef = ParseSlotReference(widget.Name)
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
    return UI.CreateDragListener({
        onEnd = function(draggable, actor, stageX, stageY)
            local sourceSlotRef = ParseSlotReference(actor.Name)
            local hitActor = actor.Stage:Hit(stageX, stageY)
            if not hitActor then
                if sourceSlotRef then
                    local mouseX, mouseY = Input.GetMousePosition()
                    local worldX, worldY = Camera.ScreenToWorld(mouseX, mouseY)
                    local cameraCoordinate = Camera.GetCoordinate()
                    local coordinate = Grid.ScreenToCoordinate(worldX, worldY, cameraCoordinate.Z)
                    Network.SendToServer("illarion:move_slot_to_coordinate", {
                        fromViewId = sourceSlotRef.viewId,
                        fromSlotId = sourceSlotRef.slotId,
                        x = coordinate.x,
                        y = coordinate.y,
                        z = coordinate.z
                    })
                end
                return true
            end

            local targetSlotRef = ParseSlotReference(hitActor.Name)
            if sourceSlotRef and targetSlotRef and (
                sourceSlotRef.viewId ~= targetSlotRef.viewId or sourceSlotRef.slotId ~= targetSlotRef.slotId
            ) then
                Network.SendToServer("illarion:move_slot_to_slot", {
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
