local Textures = require("selene.textures")
local Map = require("selene.map")
local Camera = require("selene.camera")
local Game = require("selene.game")

local m = {}

local WORLD_MIN_X = -500
local WORLD_MIN_Y = -500
local WORLD_WIDTH = 2048
local WORLD_HEIGHT = 2048
local WORLD_MAX_X = WORLD_MIN_X + WORLD_WIDTH - 1
local WORLD_MAX_Y = WORLD_MIN_Y + WORLD_HEIGHT - 1
local MINIMAP_SIZE = 160
local WORLDMAP_PAINT_BUDGET = 256

-- We keep a CPU-side world texture and only upload the visible minimap texture.
m.worldmapTexture = Textures.create(WORLD_WIDTH, WORLD_HEIGHT)
m.worldmapTexture:fill("black")

m.minimapTexture = Textures.create(MINIMAP_SIZE, MINIMAP_SIZE)
m.minimapTexture:fill("black")
m.minimapTexture:update()

local MapColors = {
    [1] = "#b6d69e",
    [2] = "#9b785a",
    [3] = "#afb7a5",
    [4] = "#7ec1ee",
    [5] = "#ffff00",
    [6] = "#cd6565",
    [7] = "#ffffff",
    [8] = "#8ca064"
}

local dirtyRegions = {}
local minimapDirty = true
local lastMinimapCenter = nil

function m.AddToSkin(skin)
    skin:addTexture("minimap", m.minimapTexture)
end

local function isWithinWorldBounds(worldX, worldY)
    return worldX >= WORLD_MIN_X and worldX <= WORLD_MAX_X
        and worldY >= WORLD_MIN_Y and worldY <= WORLD_MAX_Y
end

local function getVisibleBounds(centerPos)
    local minimapRadius = MINIMAP_SIZE / 2
    return {
        minX = centerPos.x - minimapRadius,
        maxX = centerPos.x + minimapRadius - 1,
        minY = centerPos.y - minimapRadius,
        maxY = centerPos.y + minimapRadius - 1
    }
end

local function regionsOverlap(a, b)
    return a.maxX >= b.minX and a.minX <= b.maxX
        and a.maxY >= b.minY and a.minY <= b.maxY
end

local function mergeDirtyRegion(region)
    for index = #dirtyRegions, 1, -1 do
        local existing = dirtyRegions[index]
        if existing.z == region.z then
            local expandedExisting = {
                minX = existing.minX - 1,
                maxX = existing.maxX + 1,
                minY = existing.minY - 1,
                maxY = existing.maxY + 1
            }
            if regionsOverlap(expandedExisting, region) then
                existing.minX = math.min(existing.minX, region.minX)
                existing.maxX = math.max(existing.maxX, region.maxX)
                existing.minY = math.min(existing.minY, region.minY)
                existing.maxY = math.max(existing.maxY, region.maxY)
                existing.nextX = existing.minX
                existing.nextY = existing.minY
                return
            end
        end
    end

    region.nextX = region.minX
    region.nextY = region.minY
    dirtyRegions[#dirtyRegions + 1] = region
end

local function getGroundColor(worldX, worldY, worldZ)
    local tiles = Map.getTilesAt(worldX, worldY, worldZ)
    if tiles and #tiles > 0 then
        local groundTile = tiles[1]
        local visual = groundTile:getVisual()
        if visual then
            return MapColors[visual:getMetadata("mapColorIndex")] or "black"
        end
    end

    return "black"
end

local function paintWorldTile(worldX, worldY, worldZ)
    if not isWithinWorldBounds(worldX, worldY) then
        return
    end

    local textureX = worldX - WORLD_MIN_X
    local textureY = worldY - WORLD_MIN_Y
    m.worldmapTexture:setPixel(textureX, textureY, getGroundColor(worldX, worldY, worldZ))
end

local function repaintVisibleMinimap(centerPos)
    local minimapRadius = MINIMAP_SIZE / 2
    local worldSourceX = centerPos.x - minimapRadius
    local worldSourceY = centerPos.y - minimapRadius
    local textureSourceX = worldSourceX - WORLD_MIN_X
    local textureSourceY = worldSourceY - WORLD_MIN_Y

    m.minimapTexture:fill("black")

    if textureSourceX >= 0 and textureSourceY >= 0
        and textureSourceX + MINIMAP_SIZE <= WORLD_WIDTH
        and textureSourceY + MINIMAP_SIZE <= WORLD_HEIGHT then
        m.minimapTexture:copyFrom(
            m.worldmapTexture,
            textureSourceX,
            textureSourceY,
            MINIMAP_SIZE,
            MINIMAP_SIZE,
            0,
            0
        )
    else
        local copyStartX = math.max(0, textureSourceX)
        local copyStartY = math.max(0, textureSourceY)
        local copyEndX = math.min(WORLD_WIDTH, textureSourceX + MINIMAP_SIZE)
        local copyEndY = math.min(WORLD_HEIGHT, textureSourceY + MINIMAP_SIZE)

        if copyStartX < copyEndX and copyStartY < copyEndY then
            local copyWidth = copyEndX - copyStartX
            local copyHeight = copyEndY - copyStartY
            local destX = copyStartX - textureSourceX
            local destY = copyStartY - textureSourceY

            m.minimapTexture:copyFrom(
                m.worldmapTexture,
                copyStartX,
                copyStartY,
                copyWidth,
                copyHeight,
                destX,
                destY
            )
        end
    end

    m.minimapTexture:update()
    lastMinimapCenter = { x = centerPos.x, y = centerPos.y, z = centerPos.z }
    minimapDirty = false
end

local function regionIntersectsVisibleWindow(region, centerPos)
    if region.z ~= centerPos.z then
        return false
    end

    return regionsOverlap(region, getVisibleBounds(centerPos))
end

local function processDirtyRegions(centerPos)
    local budget = WORLDMAP_PAINT_BUDGET
    local visibleAreaUpdated = false

    while budget > 0 and #dirtyRegions > 0 do
        local region = dirtyRegions[1]

        if region.z ~= centerPos.z then
            table.remove(dirtyRegions, 1)
        else
            local visibleBounds = getVisibleBounds(centerPos)

            while budget > 0 and region.nextY <= region.maxY do
                paintWorldTile(region.nextX, region.nextY, region.z)
                if region.nextX >= visibleBounds.minX and region.nextX <= visibleBounds.maxX
                    and region.nextY >= visibleBounds.minY and region.nextY <= visibleBounds.maxY then
                    visibleAreaUpdated = true
                end

                budget = budget - 1
                region.nextX = region.nextX + 1
                if region.nextX > region.maxX then
                    region.nextX = region.minX
                    region.nextY = region.nextY + 1
                end
            end

            if region.nextY > region.maxY then
                table.remove(dirtyRegions, 1)
            else
                break
            end
        end
    end

    return visibleAreaUpdated
end

local function cameraCenterChanged(centerPos)
    return lastMinimapCenter == nil
        or lastMinimapCenter.x ~= centerPos.x
        or lastMinimapCenter.y ~= centerPos.y
        or lastMinimapCenter.z ~= centerPos.z
end

function m.Initialize()
    Camera.onCoordinateChanged:connect(function()
        minimapDirty = true
    end)

    Map.onChunkChanged:connect(function(pos, width, height)
        local center = Camera.getCoordinate()
        if pos.z ~= center.z then
            return
        end

        local chunkMinX = pos.x
        local chunkMaxX = pos.x + width - 1
        local chunkMinY = pos.y
        local chunkMaxY = pos.y + height - 1

        if chunkMaxX < WORLD_MIN_X or chunkMinX > WORLD_MAX_X
            or chunkMaxY < WORLD_MIN_Y or chunkMinY > WORLD_MAX_Y then
            return
        end

        local refreshRegion = {
            minX = math.max(chunkMinX, WORLD_MIN_X),
            maxX = math.min(chunkMaxX, WORLD_MAX_X),
            minY = math.max(chunkMinY, WORLD_MIN_Y),
            maxY = math.min(chunkMaxY, WORLD_MAX_Y),
            z = pos.z
        }

        mergeDirtyRegion(refreshRegion)
        if regionIntersectsVisibleWindow(refreshRegion, center) then
            minimapDirty = true
        end
    end)

    Game.preTick:connect(function()
        local center = Camera.getCoordinate()
        local centerChanged = cameraCenterChanged(center)
        local visibleAreaUpdated = processDirtyRegions(center)

        if centerChanged then
            minimapDirty = true
        end

        if minimapDirty and (centerChanged or visibleAreaUpdated or #dirtyRegions == 0) then
            repaintVisibleMinimap(center)
        end
    end)
end

return m
