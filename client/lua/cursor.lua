local Input = require("selene.input")
local Camera = require("selene.camera")
local Grid = require("selene.grid")
local Game = require("selene.game")
local Entities = require("selene.entities")
local Network = require("selene.network")

local UseManager = require("illarion-gobaith-ui.client.lua.lib.useManager")

local Cursor = Entities.Create("illarion:tile_cursor")
Cursor:Spawn()

local wasChar = false
local useCursor = nil
local useTarget = nil

Game.PreTick:Connect(function()
    local mouseX, mouseY = Input.GetMousePosition()
    local worldX, worldY = Camera.ScreenToWorld(mouseX, mouseY)
    local cameraCoordinate = Camera.GetCoordinate()
    local coordinate = Grid.ScreenToCoordinate(worldX, worldY, cameraCoordinate.Z)
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

        local isChar = #Entities.FindEntitiesAt(coordinate, {
            tag = "illarion:character"
        }) > 0
        if isChar and not wasChar then
            Cursor:AddComponent("illarion:visual", {
                type = "visual",
                visual = "illarion:char_cursor"
            })
        elseif not isChar and wasChar then
            Cursor:AddComponent("illarion:visual", {
                type = "visual",
                visual = "illarion:tile_cursor"
            })
        end
        wasChar = isChar
    end
end)

Input.BindAction(Input.MOUSE, "left", function(screenX, screenY)
    local isShiftPressed = Input.IsKeyPressed("L-Shift") or Input.IsKeyPressed("R-Shift")
    if isShiftPressed then
        local worldX, worldY = Camera.ScreenToWorld(screenX, screenY)
        local cameraCoordinate = Camera.GetCoordinate()
        local coordinate = Grid.ScreenToCoordinate(worldX, worldY, cameraCoordinate.Z)
        if not useCursor then
            useCursor = Entities.Create("illarion:use_cursor")
            useCursor:SetCoordinate(coordinate)
            useCursor:Spawn()
            useTarget = {
                type = "coordinate",
                coordinate = coordinate,
                reset = function()
                    if useCursor then
                        useCursor:Despawn()
                    end
                    useCursor = nil
                    useTarget = nil
                end
            }
            table.insert(UseManager.useTargets, useTarget)
        else
            useTarget.coordinate = coordinate
            useCursor:SetCoordinate(coordinate)
        end
    end
end)

