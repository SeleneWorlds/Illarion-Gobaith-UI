local UI = require("selene.ui")

local scene = UI:LoadUI({
    type = "Node",
    name = "Illarion",
    width = 1024,
    height = 768,
    children = {
        { type = "Image", name = "BottomFrame", anchor = UI.ANCHOR_BOTTOM_LEFT, x = 0, y = -512, attributes = { src = "client/textures/illarion/ui/gui_bottom.png" } },
        { type = "Image", name = "TopFrame", anchor = UI.ANCHOR_TOP_RIGHT, x = -256, y = 0, attributes = { src = "client/textures/illarion/ui/gui_top.png" } },
        { type = "Image", name = "ChatBackground", anchor = UI.ANCHOR_BOTTOM_LEFT, x = 0, y = -370, attributes = { src = "client/textures/illarion/ui/gui_chat.png" } },
    }
})
UI.Root:AddChild(UI:CreateUI(scene))

--local topFrame = mainContainer.image("client/textures/illarion/ui/gui_top.png")
--ui.addToTree(mainContainer)
--local counter = mainContainer.image("client/textures/illarion/ui/gui_counter.png")
--local statusBackground = mainContainer.image("client/textures/illarion/ui/gui_status.png")
--local statusHealth = statusBackground.image("client/textures/illarion/ui/status_health.png")
--local statusFood = statusBackground.image("client/textures/illarion/ui/status_food.png")
--local statusMana = statusBackground.image("client/textures/illarion/ui/status_mana.png")
--local rightShowcase = mainContainer.image("client/textures/illarion/ui/showcase_back.png")
--local leftShowcase = mainContainer.image("client/textures/illarion/ui/showcase_back.png")
--local speakNormal = mainContainer.image("client/textures/illarion/ui/speak_normal.png")