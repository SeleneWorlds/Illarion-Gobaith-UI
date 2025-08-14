local Game = require("selene.game")
local UI = require("selene.ui.lml")
local Network = require("selene.network")

local ChatModes = {
    "normal",
    "whisper",
    "shout",
    "ooc"
}
local CurrentChatMode = "normal"

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

return {}