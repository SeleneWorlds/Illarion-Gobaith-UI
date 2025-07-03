local Input = require("selene.input")
local Camera = require("selene.camera")
local Grid = require("selene.grid")
local Game = require("selene.game")
local Entities = require("selene.entities")

local Cursor = Entities.Create("illarion:tile_cursor")
Cursor:SetCoordinate(-97, -109, 0)
Cursor:Spawn()

Game.PreTick:Connect(function()
    local mouseX, mouseY = Input.GetMousePosition()
    local worldX, worldY = Camera.ScreenToWorld(mouseX, mouseY)
    local coordinate = Grid.ScreenToCoordinate(worldX, worldY)
    if (Cursor.Coordinate ~= coordinate) then
        local cursorShadow = Entities.Create("illarion:tile_cursor_shadow")
        cursorShadow:SetCoordinate(Cursor.Coordinate)
        cursorShadow:Spawn()
        Cursor:SetCoordinate(coordinate)
    end
end)