local UI = require("selene.ui.lml")
local Network = require("selene.network")

local m = {}

function m.Initialize(bindings, skin)
    m.Bindings = bindings
    m.Skin = skin

    Network.HandlePayload("illarion:update_slot", function(payload)
        if payload.viewId == 1 then
            local style = UI.CreateImageButtonStyle({
                imageUp = "client/textures/illarion/items/apple.png"
            }, skin)
            m.Bindings["inventory:" .. math.floor(payload.slotId)]:SetStyle(style)
        end
    end)
end

function m.slotClick(widget)
    print("test")
end

return m