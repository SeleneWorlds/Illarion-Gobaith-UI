local Task = require("selene.task")
local Input = require("selene.input")
local UI = require("selene.ui.lml")
local Network = require("selene.network")
local Visuals = require("selene.visuals")

local UseManager = require("illarion-gobaith-ui.client.lua.lib.useManager")

local m = {}

function m.Initialize(hud, skin)
    m.Hud = hud
    m.Skin = skin

    Network.HandlePayload("illarion:update_slot", function(payload)
        if payload.viewId ~= "inventory" then
            return
        end

        if payload.item then
            Task.Launch(function()
                local visual = Visuals.Create(payload.item.visual)
                local style = UI.CreateImageButtonStyle({
                    imageUp = visual.Drawable:WithoutOffset()
                }, skin)
                m.Hud:GetActor("inventory:" .. payload.slotId):SetStyle(style)
            end)
        else
            m.Hud:GetActor("inventory:" .. payload.slotId):SetStyle(m.Skin, "hidden")
        end
    end)
end

local useTarget = nil

function m.slotClick(widget)
    local isShiftPressed = Input.IsKeyPressed("L-Shift") or Input.IsKeyPressed("R-Shift")
    if isShiftPressed then
        useTarget = {
            type = "inventory",
            viewId = "belt",
            slotId = widget.Name,
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
            local actor = actor.Stage:Hit(stageX, stageY)
            if stringx.startsWith(actor.Name, "inventory:") then
                local slotId = tonumber(stringx.removePrefix(actor.Name, "inventory:"))
                print(slotId)
            end
            return true
        end
    })
end

return m