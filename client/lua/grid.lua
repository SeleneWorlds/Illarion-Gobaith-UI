local Grid = require("selene.grid")

local North = Grid.DefineDirection("north", 0, -1, 0)
local South = Grid.DefineDirection("south", 0, 1, 0)
local East = Grid.DefineDirection("east", 1, 0, 0)
local West = Grid.DefineDirection("west", -1, 0, 0)

return {
    North = North,
    South = South,
    East = East,
    West = West
}