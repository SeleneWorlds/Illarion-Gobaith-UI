local Network = require("selene.network")

local m = {}

function m.Initialize(hud)
    m.Health = hud:getActor("Health")
    m.Mana = hud:getActor("Mana")
    m.Food = hud:getActor("Food")

    Network.handlePayload("illarion:health", function(payload)
        m.Health:setValue(payload.value)
    end)

    Network.handlePayload("illarion:food", function(payload)
        m.Food:setValue(payload.value)
    end)

    Network.handlePayload("illarion:mana", function(payload)
        m.Mana:setValue(payload.value)
    end)
end

return m