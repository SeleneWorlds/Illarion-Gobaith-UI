local Network = require("selene.network")

local m = {}

function m.Initialize(bindings)
    m.Health = bindings["Health"]
    m.Mana = bindings["Mana"]
    m.Food = bindings["Food"]

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