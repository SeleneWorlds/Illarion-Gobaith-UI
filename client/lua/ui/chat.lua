local Game = require("selene.game")
local UI = require("selene.ui.lml")
local Network = require("selene.network")
local Input = require("selene.input")

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
    m.ChatInputContainer = bindings["ChatInputContainer"]
    m.ChatInput = bindings["ChatInput"]
    m.Skin = skin

    Game.PreTick:Connect(function()
        local prevHeight = m.ChatInputContainer.Height
        local newHeight = string.len(m.ChatInput.Text) > 0 and m.ChatInput.PreferredHeight or 0
        if prevHeight ~= newHeight then
            m.ChatInputContainer.Height = newHeight
            m.Chat:Invalidate()
        end
    end)

    Network.HandlePayload("illarion:inform", function(Payload)
        m.Chat:AddChildBefore(m.ChatInputContainer, UI.CreateContainer(m.Skin, {
            width = m.Chat.Parent.Width,
            child = UI.CreateLabel(m.Skin, {
                style = "chat_inform",
                text = Payload.Message,
                wrap = true
            })
        }))
    end)

    Network.HandlePayload("illarion:chat", function(payload)
        m.Chat:AddChildBefore(m.ChatInputContainer, UI.CreateContainer(m.Skin, {
            width = m.Chat.Parent.Width,
            child = UI.CreateLabel(m.Skin, {
                style = "chat_say",
                text = payload.authorName .. ": " .. payload.message,
                wrap = true
            })
        }))
    end)

    UI.AddInputProcessor({
        KeyDown = function(event, key)
            local focus = UI.GetFocus()
            m.ChatInput:Focus()
            m.ChatInput.InputListener:KeyDown(event, key)
            UI.SetFocus(focus)
            return false
        end,
        KeyTyped = function(event, char)
            local focus = UI.GetFocus()
            m.ChatInput:Focus()
            m.ChatInput.InputListener:KeyTyped(event, char)
            UI.SetFocus(focus)
            return false
        end,
        KeyUp = function(event, key)
            m.ChatInput.InputListener:KeyUp(event, key)
            return false
        end
    })
end

function m.cycleChatMode(widget)
    m.CurrentChatMode = m.ChatModes[(tablex.find(m.ChatModes, m.CurrentChatMode) % #m.ChatModes) + 1]
    widget:SetStyle(m.Skin, "speak_" .. m.CurrentChatMode)
end

function m.keyTyped(widget, char)
    if char == 10 then
        local text = stringx.trim(widget.Text)
        if string.len(text) > 0 then
            Network.SendToServer("illarion:chat", {
                mode = m.CurrentChatMode,
                message = text
            })
        end
        widget.Text = ""
    end
end

return m