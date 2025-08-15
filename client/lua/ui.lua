local Game = require("selene.game")
local UI = require("selene.ui.lml")
local Network = require("selene.network")
local Textures = require("selene.textures")
local Map = require("selene.map")
local Camera = require("selene.camera")

local ChatModes = {
    "normal",
    "whisper",
    "shout",
    "ooc"
}
local CurrentChatMode = "normal"

-- We store a large texture holding the minimap data for the whole world (TODO: per floor).
-- That way, we can simply copy pixels from here instead of drawing tiles pixel by pixel on every move.
local WORLD_MIN_X = -500
local WORLD_MIN_Y = -500
local WORLD_WIDTH = 957
local WORLD_HEIGHT = 775
local WORLD_MAX_X = WORLD_MIN_X + WORLD_WIDTH - 1
local WORLD_MAX_Y = WORLD_MIN_Y + WORLD_HEIGHT - 1
local worldmapTexture = Textures.Create(WORLD_WIDTH, WORLD_HEIGHT)
worldmapTexture:Fill("black")
worldmapTexture:Update()

-- This is the texture that is actually rendered inside the UI.
local MINIMAP_SIZE = 160
local minimapTexture = Textures.Create(MINIMAP_SIZE, MINIMAP_SIZE)
minimapTexture:Fill("black")
minimapTexture:Update()

local skin = UI.CreateSkin()
skin:AddTexture("gui_bottom", "client/textures/illarion/ui/gui_bottom.png")
skin:AddTexture("gui_top", "client/textures/illarion/ui/gui_top.png")
skin:AddTexture("gui_chat", "client/textures/illarion/ui/gui_chat.png")
skin:AddTexture("gui_counter", "client/textures/illarion/ui/gui_counter.png")
skin:AddTexture("gui_status", "client/textures/illarion/ui/gui_status.png")
skin:AddTexture("speak_normal", "client/textures/illarion/ui/speak_normal.png")
skin:AddTexture("speak_ooc", "client/textures/illarion/ui/speak_ooc.png")
skin:AddTexture("speak_shout", "client/textures/illarion/ui/speak_shout.png")
skin:AddTexture("speak_whisper", "client/textures/illarion/ui/speak_whisper.png")
skin:AddTexture("inv_slot", "client/textures/illarion/ui/inv_slot-0.png")
skin:AddTexture("inv_slot_anim", "client/textures/illarion/ui/inv_slot-7.png")
skin:AddTexture("status_food", "client/textures/illarion/ui/status_food.png")
skin:AddTexture("status_health", "client/textures/illarion/ui/status_health.png")
skin:AddTexture("status_mana", "client/textures/illarion/ui/status_mana.png")
skin:AddTexture("minimap", minimapTexture)
skin:AddTexture("worldmap", worldmapTexture)
skin:AddImageButtonStyle("speak_normal", {
    up = "speak_normal"
})
skin:AddImageButtonStyle("speak_ooc", {
    up = "speak_ooc"
})
skin:AddImageButtonStyle("speak_shout", {
    up = "speak_shout"
})
skin:AddImageButtonStyle("speak_whisper", {
    up = "speak_whisper"
})
skin:AddImageButtonStyle("inv_slot", {
    up = "inv_slot",
    over = "inv_slot_anim"
})
skin:AddLabelStyle("gui_counter_time", {
    font = "default",
    fontColor = "#B2CCFF"
})
skin:AddLabelStyle("chat_say", {
    font = "default",
    fontColor = "#FFFFFF"
})
skin:AddLabelStyle("chat_ooc", {
    font = "default",
    fontColor = "#999999"
})
skin:AddLabelStyle("chat_whisper", {
    font = "default",
    fontColor = "#999999"
})
skin:AddLabelStyle("chat_emote", {
    font = "default",
    fontColor = "#FFFF33"
})
skin:AddLabelStyle("chat_inform", {
    font = "default",
    fontColor = "#B2CCFF"
})
skin:AddTextFieldStyle("chat_shout", {
    font = "default",
    fontColor = "#FF4C4C"
})
skin:AddTextFieldStyle("gui_counter_value", {
    font = "default"
})
skin:AddProgressBarStyle("status_health", {
    knobBefore = "status_health"
})
skin:AddProgressBarStyle("status_food", {
    knobBefore = "status_food"
})
skin:AddProgressBarStyle("status_mana", {
    knobBefore = "status_mana"
})
local hud, bindings = UI.LoadUI("client/ui/illarion/hud.xml", {
    skin = skin,
    actions = {
        toggleChatMode = function(widget)
            CurrentChatMode = ChatModes[(table.find(ChatModes, CurrentChatMode) % #ChatModes) + 1]
            widget:SetStyle(skin, "speak_" .. CurrentChatMode)
        end
    }
})
UI.AddToRoot(hud)

local CounterTime = bindings["CounterTime"]
local Chat = bindings["Chat"]
local Health = bindings["Health"]
local Mana = bindings["Mana"]
local Food = bindings["Food"]

Health.Value = 1.0
Food.Value = 1.0

-- TODO selene.timer could provide a Minute event that fires every full minute instead
Game.PreTick:Connect(function()
    local time = os.date("*t")
    local hour = string.format("%02d", time.hour)
    local min = string.format("%02d", time.min)
    CounterTime.Text = hour .. ":" .. min
end)

Network.HandlePayload("moonlight:inform", function(Payload)
    Chat:AddChild(UI.CreateContainer(skin, {
        width = Chat.Parent.Width,
        child = UI.CreateLabel(skin, {
            style = "chat_inform",
            text = Payload.Message,
            wrap = true
        })
    }))
end)

local TileColors = {
    ["illarion:stones"] = "#9b785a",
    ["illarion:farmland"] = "#9b785a",
    ["illarion:dirt"] = "#9b785a",
    ["illarion:forestGround"] = "#8ca064",
    ["illarion:sand1"] = "#ffff00",
    ["illarion:dungeonFloor"] = "#9b785a",
    ["illarion:street1"] = "#afb7a5",
    ["illarion:roof"] = "#cd6565",
    ["illarion:roof2"] = "#cd6565",
    ["illarion:roof3"] = "#cd6565",
    ["illarion:wall"] = "#afb7a5",
    ["illarion:carpet1"] = "#ffffcc",
    ["illarion:carpet2"] = "#ffffcc",
    ["illarion:carpet3"] = "#ffffcc",
    ["illarion:carpet4"] = "#ffffcc",
    ["illarion:carpet5"] = "#ffffcc",
    ["illarion:carpet6"] = "#ffffcc",
    ["illarion:carpet7"] = "#ffffcc",
    ["illarion:carpet8"] = "#ffffcc",
    ["illarion:carpet9"] = "#ffffcc",
    ["illarion:parquet1"] = "#cd6565",
    ["illarion:marble"] = "#ffffcc",
    ["illarion:lava"] = "#cd6565",
    ["illarion:snow"] = "#ffffff",
    ["illarion:grass"] = "#b6d69e",
    ["illarion:water"] = "#7ec1ee"
}

local function refreshWorldmapTexture(worldMinX, worldMinY, worldMaxX, worldMaxY, worldZ)
    for worldX = worldMinX, worldMaxX do
        for worldY = worldMinY, worldMaxY do
            -- Only if inside world bounds
            if worldX >= WORLD_MIN_X and worldX <= WORLD_MAX_X and 
               worldY >= WORLD_MIN_Y and worldY <= WORLD_MAX_Y then
                -- Convert world coordinates to texture coordinates
                local textureX = worldX - WORLD_MIN_X
                local textureY = worldY - WORLD_MIN_Y
                
                -- TODO Map.GetTileAt with index since we only care about the ground?
                local tiles = Map.GetTilesAt(worldX, worldY, worldZ)
                local color = "black"
                if tiles and #tiles > 0 then
                    local groundTile = tiles[1]
                    color = TileColors[groundTile.Name] or "black"
                end
                
                worldmapTexture:SetPixel(textureX, textureY, color)
            end
        end
    end
    
    -- Updating the texture is required after any changes
    worldmapTexture:Update()
end

local function updateMinimapDisplay(centerPos)
    local minimapRadius = MINIMAP_SIZE / 2
    
    -- Calculate the source region in world coordinates
    local worldSourceX = centerPos.x - minimapRadius
    local worldSourceY = centerPos.y - minimapRadius
    
    -- Convert to texture coordinates
    local textureSourceX = worldSourceX - WORLD_MIN_X
    local textureSourceY = worldSourceY - WORLD_MIN_Y
    
    -- Clear the minimap first
    minimapTexture:Fill("black")
    
    -- Check if the source area is within the texture bounds
    if textureSourceX >= 0 and textureSourceY >= 0 and 
       textureSourceX + MINIMAP_SIZE <= WORLD_WIDTH and textureSourceY + MINIMAP_SIZE <= WORLD_HEIGHT then
        minimapTexture:CopyFrom(worldmapTexture, textureSourceX, textureSourceY, MINIMAP_SIZE, MINIMAP_SIZE, 0, 0)
    else
        -- Handle partial copying when source area extends beyond world bounds
        local copyStartX = math.max(0, textureSourceX)
        local copyStartY = math.max(0, textureSourceY)
        local copyEndX = math.min(WORLD_WIDTH, textureSourceX + MINIMAP_SIZE)
        local copyEndY = math.min(WORLD_HEIGHT, textureSourceY + MINIMAP_SIZE)
        
        if copyStartX < copyEndX and copyStartY < copyEndY then
            local copyWidth = copyEndX - copyStartX
            local copyHeight = copyEndY - copyStartY
            local destX = copyStartX - textureSourceX
            local destY = copyStartY - textureSourceY
            
            minimapTexture:CopyFrom(worldmapTexture, copyStartX, copyStartY, copyWidth, copyHeight, destX, destY)
        end
    end
    
    minimapTexture:Update()
end

Camera.OnCoordinateChanged:Connect(function(pos)
    updateMinimapDisplay(pos)
end)

Map.OnChunkChanged:Connect(function(pos, width, height)
    local center = Camera.GetCoordinate()
    
    -- Check if the changed chunk overlaps with the world bounds
    local chunkMinX = pos.x
    local chunkMaxX = pos.x + width - 1
    local chunkMinY = pos.y
    local chunkMaxY = pos.y + height - 1
    local chunkZ = pos.z

    -- Check if chunk overlaps with actual world bounds and is on the same Z level
    if chunkZ == center.z and
       chunkMaxX >= WORLD_MIN_X and chunkMinX <= WORLD_MAX_X and
       chunkMaxY >= WORLD_MIN_Y and chunkMinY <= WORLD_MAX_Y then
        
        -- Calculate the intersection area to refresh (clamp to world bounds)
        local refreshMinX = math.max(chunkMinX, WORLD_MIN_X)
        local refreshMaxX = math.min(chunkMaxX, WORLD_MAX_X)
        local refreshMinY = math.max(chunkMinY, WORLD_MIN_Y)
        local refreshMaxY = math.min(chunkMaxY, WORLD_MAX_Y)
        
        refreshWorldmapTexture(refreshMinX, refreshMinY, refreshMaxX, refreshMaxY, center.z)
        updateMinimapDisplay(center)
    end
end)

return {}