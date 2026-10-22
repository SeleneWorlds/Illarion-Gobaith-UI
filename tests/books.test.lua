-- Run from bundles/illarion-client: lua tests/books.test.lua
package.path = "../?.lua;" .. package.path
local handlers, sent = {}, {}
package.loaded["selene.network"] = {
    handlePayload = function(id, handler) handlers[id] = handler end,
    sendToPlayer = function(player, id, payload)
        sent[#sent + 1] = { player = player, id = id, payload = payload }
    end
}
package.loaded["selene.entities"] = {}
local Books = require("illarion-script-loader.server.lua.lib.books")
local function makeUser()
    local data = {}
    local entity = { getRuntimeData = function(_, key)
        data[key] = data[key] or {}
        return data[key]
    end }
    local player = { getControlledEntity = function() return entity end }
    return { SeleneEntity = entity, SelenePlayer = player }
end
local user, other = makeUser(), makeUser()
Character = { fromSelenePlayer = function(player)
    assert(player == user.SelenePlayer)
    return user
end }
local reads = 0
Books.open(user, 300, function(page)
    reads = reads + 1
    return { text = "Page " .. page, itemId = 105 }
end)
assert(#sent == 1 and sent[1].id == "illarion:book_page")
local id = sent[1].payload.id
assert(sent[1].payload.page == 1 and sent[1].payload.pageCount == 300)
handlers["illarion:book_request_page"](user.SelenePlayer, { id = id, page = 300 })
assert(#sent == 2 and sent[2].payload.text == "Page 300")
for _, page in ipairs({ 0, -1, 301, 1.5, "2", math.huge }) do
    handlers["illarion:book_request_page"](user.SelenePlayer, { id = id, page = page })
end
handlers["illarion:book_request_page"](other.SelenePlayer, { id = id, page = 2 })
assert(reads == 2 and #sent == 2)
Books.show(user, "Druid report", 1008)
local report = sent[#sent].payload
assert(report.id ~= id and report.page == 1 and report.pageCount == 1 and report.itemId == 1008)
handlers["illarion:book_request_page"](user.SelenePlayer, { id = id, page = 2 })
assert(reads == 2)
handlers["illarion:book_close"](user.SelenePlayer, { id = id })
handlers["illarion:book_request_page"](user.SelenePlayer, { id = report.id, page = 1 })
assert(#sent == 4)
handlers["illarion:book_close"](user.SelenePlayer, { id = report.id })
handlers["illarion:book_request_page"](user.SelenePlayer, { id = report.id, page = 1 })
assert(#sent == 4)
user.SelenePlayer.getControlledEntity = function() return nil end
handlers["illarion:book_request_page"](user.SelenePlayer, { id = report.id, page = 1 })
assert(#sent == 4)
print("Book protocol tests passed")
