local UI = require("selene.ui.lml")

local skin = require("illarion-gobaith-ui.client.lua.ui.skin")
local minimap = require("illarion-gobaith-ui.client.lua.ui.minimap")
local chat = require("illarion-gobaith-ui.client.lua.ui.chat")
local inventory = require("illarion-gobaith-ui.client.lua.ui.inventory")
local clock = require("illarion-gobaith-ui.client.lua.ui.clock")

minimap.AddToSkin(skin)
local hud, bindings = UI.LoadUI("client/ui/illarion/hud.xml", {
    skin = skin,
    actions = {
        cycleChatMode = chat.cycleChatMode,
        slotClick = inventory.slotClick,
    }
})
UI.AddToRoot(hud)
chat.Initialize(bindings, skin)
minimap.Initialize()
clock.Initialize(bindings)
inventory.Initialize(bindings, skin)

local Health = bindings["Health"]
local Mana = bindings["Mana"]
local Food = bindings["Food"]
Health.Value = 1.0
Food.Value = 1.0

return {}