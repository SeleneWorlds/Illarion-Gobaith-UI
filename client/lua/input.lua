local Input = require("selene.input")
local GridMovement = require("selene.movement.grid")
local Grid = require("selene.grid")
local Game = require("selene.game")
local Entities = require("selene.entities")
local Network = require("selene.network")

local autoWalk = nil
local function keyboardMovementPressed()
    return Input.isKeyPressed("Up") or Input.isKeyPressed("Down")
        or Input.isKeyPressed("Left") or Input.isKeyPressed("Right")
end

Network.handlePayload("illarion:walk_path", function(payload)
    autoWalk = nil
    if keyboardMovementPressed() or not payload.steps or #payload.steps == 0 then
        return
    end
    autoWalk = { networkId = payload.networkId, steps = payload.steps, index = 1, progressTime = os.time() }
end)

Game.preTick:connect(function()
    if not autoWalk then
        return
    end
    if keyboardMovementPressed() then
        autoWalk = nil
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

Input.bindContinuousAction("keyboard", "Up", function()
    autoWalk = nil
    local North = Grid.getDirectionByName("north")
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.setFacing(North)
    else
        GridMovement.setMotion(North)
    end
end)

Input.bindContinuousAction("keyboard", "Down", function()
    autoWalk = nil
    local South = Grid.getDirectionByName("south")
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.setFacing(South)
    else
        GridMovement.setMotion(South)
    end
end)

Input.bindContinuousAction("keyboard", "Left", function()
    autoWalk = nil
    local West = Grid.getDirectionByName("west")
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.setFacing(West)
    else
        GridMovement.setMotion(West)
    end
end)

Input.bindContinuousAction("keyboard", "Right", function()
    autoWalk = nil
    local East = Grid.getDirectionByName("east")
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.setFacing(East)
    else
        GridMovement.setMotion(East)
    end
end)
