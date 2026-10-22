-- Run from bundles/illarion-client: lua tests/movement.test.lua
local handlers, tick, motion, facing = {}, nil, {}, {}
package.loaded["selene.network"] = { handlePayload = function(id, callback) handlers[id] = callback end }
package.loaded["selene.movement.grid"] = {
    setMotion = function(direction) motion[#motion + 1] = direction end,
    setFacing = function(direction) facing[#facing + 1] = direction end
}
package.loaded["selene.grid"] = { getDirectionByName = function(name) return name end }
package.loaded["selene.game"] = { preTick = { connect = function(_, callback) tick = callback end } }
local coordinate = { x = 0, y = 0, z = 0 }
local entity = { getCoordinate = function() return coordinate end }
package.loaded["selene.entities"] = { getEntityByNetworkId = function() return entity end }
local Movement = dofile("illarion-client-core/client/lua/movement.lua")
local path = { networkId = 7, steps = { { fromX = 0, fromY = 0, fromZ = 0, x = 0, y = 1, z = 0, direction = "north" } } }
local blocked = true
Movement.suppressPathWhile(function() return blocked end)
handlers["illarion:walk_path"](path)
tick()
assert(#motion == 0)
blocked = false
handlers["illarion:walk_path"](path)
tick()
assert(motion[1] == "north")
Movement.move("east")
tick()
assert(#motion == 2 and motion[2] == "east")
handlers["illarion:walk_path"](path)
blocked = true
tick()
assert(#motion == 2)
blocked = false
handlers["illarion:walk_path"](path)
coordinate = { x = 9, y = 9, z = 0 }
tick()
assert(#motion == 2)
handlers["illarion:turn_to"]({ direction = "west" })
assert(facing[1] == "west")
print("Movement interruption tests passed")
