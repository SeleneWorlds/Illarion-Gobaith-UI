local Input = require("selene.input")
local Camera = require("selene.camera")
local Grid = require("selene.grid")
local Game = require("selene.game")
local Entities = require("selene.entities")

local Cursor = Entities.Create("illarion:tile_cursor")
Cursor:Spawn()

local wasChar = false

Game.PreTick:Connect(function()
    local mouseX, mouseY = Input.GetMousePosition()
    local worldX, worldY = Camera.ScreenToWorld(mouseX, mouseY)
    local coordinate = Grid.ScreenToCoordinate(worldX, worldY)
    if (Cursor.Coordinate ~= coordinate) then
        local cursorShadow = Entities.Create("illarion:tile_cursor_shadow")
        if wasChar then
            cursorShadow:AddComponent("illarion:visual", {
                type = "visual",
                visual = "illarion:char_cursor"
            })
        end
        cursorShadow:SetCoordinate(Cursor.Coordinate)
        cursorShadow:Spawn()

        Cursor:SetCoordinate(coordinate)

        local isChar = #Entities.GetEntitiesAt(coordinate) > 0
        if isChar and not wasChar then
            Cursor:AddComponent("illarion:visual", {
                type = "visual",
                visual = "illarion:char_cursor"
            })
            Cursor:UpdateVisual()
        elseif not isChar and wasChar then
            Cursor:AddComponent("illarion:visual", {
                type = "visual",
                visual = "illarion:tile_cursor"
            })
            Cursor:UpdateVisual()
        end
        wasChar = isChar
    end
end)