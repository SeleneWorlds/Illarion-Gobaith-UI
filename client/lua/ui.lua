local UI = require("selene.ui.lml")
local Loaders = require("selene.ui.coroutine")

local skin = require("illarion-gobaith-ui.client.lua.ui.skin")
local minimap = require("illarion-gobaith-ui.client.lua.ui.minimap")
local chat = require("illarion-gobaith-ui.client.lua.ui.chat")
local inventory = require("illarion-gobaith-ui.client.lua.ui.inventory")
local menu = require("illarion-gobaith-ui.client.lua.ui.menu")
local clock = require("illarion-gobaith-ui.client.lua.ui.clock")
local stats = require("illarion-gobaith-ui.client.lua.ui.stats")

UI.setup:connect(function()
    local theme = skin.LoadThemeRoutine()
    minimap.AddToSkin(theme)

    local hud = Loaders.loadUI("client/ui/illarion/hud.xml", {
        theme = theme,
        actions = {
            cycleChatMode = chat.cycleChatMode,
            chatKeyTyped = chat.keyTyped,
            slotClick = inventory.slotClick,
            slotDragListener = inventory.slotDragListener
        }
    })
    UI.addToRoot(hud)
    chat.Initialize(hud, theme)
    minimap.Initialize()
    clock.Initialize(hud)
    inventory.Initialize(hud, theme)
    menu.Initialize(theme)
    stats.Initialize(hud)
end)

return {}
