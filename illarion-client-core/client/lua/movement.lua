local GridMovement = require("selene.movement.grid")
local Grid = require("selene.grid")
local Game = require("selene.game")
local Entities = require("selene.entities")
local Network = require("selene.network")

local Movement = {}
local autoWalk = nil
local pathBlocked = function() return false end
Network.handlePayload("illarion:turn_to", function(payload)
    local direction = Grid.getDirectionByName(payload.direction)
    if not direction then
        return
    end
    GridMovement.setFacing(direction)
end)

Network.handlePayload("illarion:walk_path", function(payload)
    autoWalk = nil
    if pathBlocked() or not payload.steps or #payload.steps == 0 then
        return
    end
    autoWalk = { networkId = payload.networkId, steps = payload.steps, index = 1, progressTime = os.time() }
end)

Game.preTick:connect(function()
    if pathBlocked() then autoWalk = nil end
    if not autoWalk then
        return
    end
    local entity = Entities.getEntityByNetworkId(autoWalk.networkId)
    if not entity then
        autoWalk = nil
        return
    end
    local coordinate = entity:getCoordinate()
    local step = autoWalk.steps[autoWalk.index]
    if coordinate.x == step.x and coordinate.y == step.y and coordinate.z == step.z then
        autoWalk.index = autoWalk.index + 1
        autoWalk.progressTime = os.time()
        step = autoWalk.steps[autoWalk.index]
        if not step then
            autoWalk = nil
            return
        end
    end
    -- Stop after a rejected/blocked step or an unexpected relocation.
    if coordinate.x ~= step.fromX or coordinate.y ~= step.fromY or coordinate.z ~= step.fromZ
            or os.time() - autoWalk.progressTime >= 5 then
        autoWalk = nil
        return
    end
    local direction = Grid.getDirectionByName(step.direction)
    -- Movement sets facing when the next step starts. A separate turn request
    -- would turn early because the tile coordinate advances mid-animation.
    GridMovement.setMotion(direction)
end)

function Movement.suppressPathWhile(predicate)
    pathBlocked = predicate
end

function Movement.cancelPath()
    autoWalk = nil
end

function Movement.move(direction)
    Movement.cancelPath()
    GridMovement.setMotion(direction)
end

function Movement.face(direction)
    GridMovement.setFacing(direction)
end

return Movement
