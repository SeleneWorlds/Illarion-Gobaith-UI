local Textures = require("selene.textures")
local Map = require("selene.map")
local Camera = require("selene.camera")

local m = {}

local WORLD_MIN_X = -500
local WORLD_MIN_Y = -500
local WORLD_WIDTH = 957
local WORLD_HEIGHT = 775
local WORLD_MAX_X = WORLD_MIN_X + WORLD_WIDTH - 1
local WORLD_MAX_Y = WORLD_MIN_Y + WORLD_HEIGHT - 1
local MINIMAP_SIZE = 160

-- We store a large texture holding the minimap data for the whole world (TODO: per floor).
-- That way, we can simply copy pixels from here instead of drawing tiles pixel by pixel on every move.
m.worldmapTexture = Textures.Create(WORLD_WIDTH, WORLD_HEIGHT)
m.worldmapTexture:Fill("black")
m.worldmapTexture:Update()

-- This is the texture that is actually rendered inside the UI.
m.minimapTexture = Textures.Create(MINIMAP_SIZE, MINIMAP_SIZE)
m.minimapTexture:Fill("black")
m.minimapTexture:Update()

function m.AddToSkin(skin)
    skin:AddTexture("minimap", m.minimapTexture)
    skin:AddTexture("worldmap", m.worldmapTexture)
end

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

function m.refreshWorldmapTexture(worldMinX, worldMinY, worldMaxX, worldMaxY, worldZ)
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
                
                m.worldmapTexture:SetPixel(textureX, textureY, color)
            end
        end
    end
    
    -- Updating the texture is required after any changes
    m.worldmapTexture:Update()
end

function m.updateMinimapDisplay(centerPos)
    local minimapRadius = MINIMAP_SIZE / 2
    
    -- Calculate the source region in world coordinates
    local worldSourceX = centerPos.x - minimapRadius
    local worldSourceY = centerPos.y - minimapRadius
    
    -- Convert to texture coordinates
    local textureSourceX = worldSourceX - WORLD_MIN_X
    local textureSourceY = worldSourceY - WORLD_MIN_Y
    
    -- Clear the minimap first
    m.minimapTexture:Fill("black")
    
    -- Check if the source area is within the texture bounds
    if textureSourceX >= 0 and textureSourceY >= 0 and 
       textureSourceX + MINIMAP_SIZE <= WORLD_WIDTH and textureSourceY + MINIMAP_SIZE <= WORLD_HEIGHT then
        m.minimapTexture:CopyFrom(m.worldmapTexture, textureSourceX, textureSourceY, MINIMAP_SIZE, MINIMAP_SIZE, 0, 0)
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
            
            m.minimapTexture:CopyFrom(m.worldmapTexture, copyStartX, copyStartY, copyWidth, copyHeight, destX, destY)
        end
    end
    
    m.minimapTexture:Update()
end

function m.Initialize()
    Camera.OnCoordinateChanged:Connect(function(pos)
        m.updateMinimapDisplay(pos)
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
            
            m.refreshWorldmapTexture(refreshMinX, refreshMinY, refreshMaxX, refreshMaxY, center.z)
            m.updateMinimapDisplay(center)
        end
    end)
end

return m