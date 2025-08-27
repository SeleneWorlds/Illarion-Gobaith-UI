local Input = require("selene.input")
local Network = require("selene.network")

local m = {}

m.useTargets = {}

local function OnShiftReleased()
    local useCoordinate = nil
    local useSlot = nil

    for _, useTarget in ipairs(m.useTargets) do
        if useTarget.type == "coordinate" then
            useCoordinate = useTarget.coordinate
        elseif useTarget.type == "inventory" then
            useSlot = {
                viewId = useTarget.viewId,
                slotId = useTarget.slotId
            }
        end
        if type(useTarget.reset) == "function" then
            useTarget:reset()
        end
    end

    m.useTargets = {}

    if useCoordinate then
        local coordinate = useCoordinate
        Network.SendToServer("illarion:use_at", {
            x = coordinate.x,
            y = coordinate.y,
            z = coordinate.z
        })
    elseif useSlot then
        Network.SendToServer("illarion:use_slot", {
            viewId = useSlot.viewId,
            slotId = useSlot.slotId
        })
    end
end

function m.RegisterInput()
    Input.BindReleaseAction(Input.KEYBOARD, "L-Shift", OnShiftReleased)
    Input.BindReleaseAction(Input.KEYBOARD, "R-Shift", OnShiftReleased)
end

return m