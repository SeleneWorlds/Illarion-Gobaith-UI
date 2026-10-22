local Input = require("selene.input")
local Grid = require("selene.grid")
local Movement = require("illarion-client-core.client.lua.movement")

Movement.suppressPathWhile(function()
    if Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift") then return false end
    return Input.isKeyPressed("Up") or Input.isKeyPressed("Down")
        or Input.isKeyPressed("Left") or Input.isKeyPressed("Right")
end)

Input.bindContinuousAction("keyboard", "Up", function()
    local North = Grid.getDirectionByName("north")
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        Movement.face(North)
    else
        Movement.move(North)
    end
end)

Input.bindContinuousAction("keyboard", "Down", function()
    local South = Grid.getDirectionByName("south")
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        Movement.face(South)
    else
        Movement.move(South)
    end
end)

Input.bindContinuousAction("keyboard", "Left", function()
    local West = Grid.getDirectionByName("west")
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        Movement.face(West)
    else
        Movement.move(West)
    end
end)

Input.bindContinuousAction("keyboard", "Right", function()
    local East = Grid.getDirectionByName("east")
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        Movement.face(East)
    else
        Movement.move(East)
    end
end)
