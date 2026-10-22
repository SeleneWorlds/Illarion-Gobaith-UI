local Network = require("selene.network")
local Combat = {}
local targetId = nil

Network.handlePayload("illarion:set_combat_target", function(payload)
    targetId = payload.networkId ~= -1 and payload.networkId or nil
end)

function Combat.getTargetId()
    return targetId
end

function Combat.setTarget(networkId)
    Network.sendToServer("illarion:set_combat_target", { networkId = networkId or -1 })
end

return Combat
