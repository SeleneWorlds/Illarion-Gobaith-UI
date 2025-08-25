local UI = require("selene.ui.lml")

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
skin:AddButtonStyle("inv_slot", {
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

return skin