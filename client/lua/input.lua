local Input = require("selene.input")
local GridMovement = require("selene.movement.grid")
local IllarionGrid = require("illarion-gobaith-ui.client.lua.grid")

Input.BindContinuousAction("keyboard", "Up", function()
    GridMovement.SetMotion(IllarionGrid.North)
end)

Input.BindContinuousAction("keyboard", "Down", function()
    GridMovement.SetMotion(IllarionGrid.South)
end)

Input.BindContinuousAction("keyboard", "Left", function()
    GridMovement.SetMotion(IllarionGrid.West)
end)

Input.BindContinuousAction("keyboard", "Right", function()
    GridMovement.SetMotion(IllarionGrid.East)
end)