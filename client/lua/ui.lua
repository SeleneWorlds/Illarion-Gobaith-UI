local UI = require("selene.ui.lml")

local skin = UI.CreateSkin()
skin:AddTexture("gui_bottom", "client/textures/illarion/ui/gui_bottom.png")
skin:AddTexture("gui_top", "client/textures/illarion/ui/gui_top.png")
skin:AddTexture("gui_chat", "client/textures/illarion/ui/gui_chat.png")
local hud = UI.LoadUI("client/ui/illarion/hud.xml", {
    skin = skin
})
for i, widget in ipairs(hud) do
    UI.Root:AddChild(widget)
end
