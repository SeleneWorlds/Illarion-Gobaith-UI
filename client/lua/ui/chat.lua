local UI = require("selene.ui.lml")
local Network = require("selene.network")

local m = {}

m.ChatModes = {
    "normal",
    "whisper",
    "shout",
    "ooc"
}

m.CurrentChatMode = "normal"

function m.Initialize(bindings, skin)
    m.Chat = bindings["Chat"]
    m.Skin = skin

    Network.HandlePayload("illarion:inform", function(Payload)
        m.Chat:AddChild(UI.CreateContainer(m.Skin, {
            width = m.Chat.Parent.Width,
            child = UI.CreateLabel(m.Skin, {
                style = "chat_inform",
                text = Payload.Message,
                wrap = true
            })
        }))
    end)
end

function m.cycleChatMode(widget)
    m.CurrentChatMode = m.ChatModes[(tablex.find(m.ChatModes, m.CurrentChatMode) % #m.ChatModes) + 1]
    widget:SetStyle(m.Skin, "speak_" .. m.CurrentChatMode)
end

return m