local Input = require("selene.input")
local GridMovement = require("selene.movement.grid")
local Grid = require("selene.grid")

local UseManager = require("illarion-gobaith-ui.client.lua.lib.useManager")

local North = Grid.GetDirectionByName("north")
local South = Grid.GetDirectionByName("south")
local East = Grid.GetDirectionByName("east")
local West = Grid.GetDirectionByName("west")

Input.BindContinuousAction("keyboard", "Up", function()
    GridMovement.SetMotion(North)
end)

Input.BindContinuousAction("keyboard", "Down", function()
    GridMovement.SetMotion(South)
end)

Input.BindContinuousAction("keyboard", "Left", function()
    GridMovement.SetMotion(West)
end)

Input.BindContinuousAction("keyboard", "Right", function()
    GridMovement.SetMotion(East)
end)

UseManager.RegisterInput()