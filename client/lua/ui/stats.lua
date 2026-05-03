local Network = require("selene.network")

local m = {}

function m.Initialize(hud)
    m.Health = hud:GetActor("Health")
    m.Mana = hud:GetActor("Mana")
    m.Food = hud:GetActor("Food")

    Network.HandlePayload("illarion:health", function(payload)
        m.Health.Value = payload.value
    end)

    Network.HandlePayload("illarion:food", function(payload)
        m.Food.Value = payload.value
    end)

    Network.HandlePayload("illarion:mana", function(payload)
        m.Mana.Value = payload.value
    end)
end

return m