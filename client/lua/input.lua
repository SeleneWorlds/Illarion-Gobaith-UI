local Input = require("selene.input")
local GridMovement = require("selene.movement.grid")
local Grid = require("selene.grid")

local UseManager = require("illarion-gobaith-ui.client.lua.lib.useManager")

local North = Grid.getDirectionByName("north")
local South = Grid.getDirectionByName("south")
local East = Grid.getDirectionByName("east")
local West = Grid.getDirectionByName("west")

Input.bindContinuousAction("keyboard", "Up", function()
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.setFacing(North)
    else
        GridMovement.setMotion(North)
    end
end)

Input.bindContinuousAction("keyboard", "Down", function()
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.setFacing(South)
    else
        GridMovement.setMotion(South)
    end
end)

Input.bindContinuousAction("keyboard", "Left", function()
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.setFacing(West)
    else
        GridMovement.setMotion(West)
    end
end)

Input.bindContinuousAction("keyboard", "Right", function()
    local isShiftPressed = Input.isKeyPressed("L-Shift") or Input.isKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.setFacing(East)
    else
        GridMovement.setMotion(East)
    end
end)

UseManager.RegisterInput()