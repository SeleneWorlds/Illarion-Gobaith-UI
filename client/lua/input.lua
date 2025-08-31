local Input = require("selene.input")
local GridMovement = require("selene.movement.grid")
local Grid = require("selene.grid")

local UseManager = require("illarion-gobaith-ui.client.lua.lib.useManager")

local North = Grid.GetDirectionByName("north")
local South = Grid.GetDirectionByName("south")
local East = Grid.GetDirectionByName("east")
local West = Grid.GetDirectionByName("west")

Input.BindContinuousAction("keyboard", "Up", function()
    local isShiftPressed = Input.IsKeyPressed("L-Shift") or Input.IsKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.SetFacing(North)
    else
        GridMovement.SetMotion(North)
    end
end)

Input.BindContinuousAction("keyboard", "Down", function()
    local isShiftPressed = Input.IsKeyPressed("L-Shift") or Input.IsKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.SetFacing(South)
    else
        GridMovement.SetMotion(South)
    end
end)

Input.BindContinuousAction("keyboard", "Left", function()
    local isShiftPressed = Input.IsKeyPressed("L-Shift") or Input.IsKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.SetFacing(West)
    else
        GridMovement.SetMotion(West)
    end
end)

Input.BindContinuousAction("keyboard", "Right", function()
    local isShiftPressed = Input.IsKeyPressed("L-Shift") or Input.IsKeyPressed("R-Shift")
    if isShiftPressed then
        GridMovement.SetFacing(East)
    else
        GridMovement.SetMotion(East)
    end
end)

UseManager.RegisterInput()