local Input = require("selene.input")
local UI = require("selene.ui.lml")
local Network = require("selene.network")

local UseManager = require("illarion-gobaith-ui.client.lua.lib.useManager")

local m = {}

function m.Initialize(bindings, skin)
    m.Bindings = bindings
    m.Skin = skin

    Network.HandlePayload("illarion:update_slot", function(payload)
        if payload.viewId ~= 1 then
            return
        end

        if payload.item then
            local style = UI.CreateImageButtonStyle({
                imageUp = "client/textures/illarion/items/apple.png"
            }, skin)
            m.Bindings["inventory:" .. math.floor(payload.slotId)]:SetStyle(style)
        else
            m.Bindings["inventory:" .. math.floor(payload.slotId)]:SetStyle(m.Skin, "hidden")
        end
    end)
end

local useTarget = nil

function m.slotClick(widget)
    local isShiftPressed = Input.IsKeyPressed("L-Shift") or Input.IsKeyPressed("R-Shift")
    if isShiftPressed then
        local slotId = tonumber(stringx.substringAfter(widget.Name, "inventory:"))
        useTarget = {
            type = "inventory",
            viewId = 1,
            slotId = slotId,
            reset = function()
                useTarget = nil
            end
        }
        table.insert(UseManager.useTargets, useTarget)
    end
end

return m