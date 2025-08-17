local Input = require("selene.input")
local Camera = require("selene.camera")
local Grid = require("selene.grid")
local Game = require("selene.game")
local Entities = require("selene.entities")
local Network = require("selene.network")

local Cursor = Entities.Create("illarion:tile_cursor")
Cursor:Spawn()

local wasChar = false
local useCursor = nil

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

Input.BindAction(Input.MOUSE, "left", function(screenX, screenY)
    local isShiftPressed = Input.IsKeyPressed("L-Shift") or Input.IsKeyPressed("R-Shift")
    if isShiftPressed then
        local worldX, worldY = Camera.ScreenToWorld(screenX, screenY)
        local coordinate = Grid.ScreenToCoordinate(worldX, worldY)
        if not useCursor then
            useCursor = Entities.Create("illarion:use_cursor")
            useCursor:SetCoordinate(coordinate)
            useCursor:Spawn()
        else
            useCursor:SetCoordinate(coordinate)
        end
    end
end)

function OnShiftReleased()
    if useCursor then
        local coordinate = useCursor.Coordinate
        Network.SendToServer("illarion:use_at", {
            x = coordinate.x,
            y = coordinate.y,
            z = coordinate.z
        })

        useCursor:Despawn()
        useCursor = nil
    end
end
Input.BindUpAction(Input.KEYBOARD, "L-Shift", OnShiftReleased)
Input.BindUpAction(Input.KEYBOARD, "R-Shift", OnShiftReleased)