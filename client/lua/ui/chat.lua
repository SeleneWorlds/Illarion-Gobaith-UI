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

function m.Initialize(hud, skin)
    m.Chat = hud:getActor("Chat")
    m.ChatInputContainer = hud:getActor("ChatInputContainer")
    m.ChatInput = hud:getActor("ChatInput")
    m.Skin = skin

    Game.preTick:connect(function()
        local prevHeight = m.ChatInputContainer:getHeight()
        local newHeight = string.len(m.ChatInput:getText()) > 0 and m.ChatInput:getPreferredHeight() or 0
        if prevHeight ~= newHeight then
            m.ChatInputContainer:setHeight(newHeight)
            m.Chat:invalidate()
        end
    end)

    Network.handlePayload("illarion:inform", function(Payload)
        m.Chat:addChildBefore(m.ChatInputContainer, UI.createContainer(m.Skin, {
            width = m.Chat:getParent():getWidth(),
            child = UI.createLabel(m.Skin, {
                style = "chat_inform",
                text = Payload.Message,
                wrap = true
            })
        }))
    end)

    Network.handlePayload("illarion:chat", function(payload)
        m.Chat:addChildBefore(m.ChatInputContainer, UI.createContainer(m.Skin, {
            width = m.Chat:getParent():getWidth(),
            child = UI.createLabel(m.Skin, {
                style = "chat_say",
                text = payload.authorName .. ": " .. payload.message,
                wrap = true
            })
        }))
    end)

    UI.addInputProcessor({
        KeyDown = function(event, key)
            local focus = UI.getFocus()
            m.ChatInput:focus()
            m.ChatInput:getInputListener():keyDown(event, key)
            UI.setFocus(focus)
            return false
        end,
        KeyTyped = function(event, char)
            local focus = UI.getFocus()
            m.ChatInput:focus()
            m.ChatInput:getInputListener():keyTyped(event, char)
            UI.setFocus(focus)
            return false
        end,
        KeyUp = function(event, key)
            m.ChatInput:getInputListener():keyUp(event, key)
            return false
        end
    })
end

function m.cycleChatMode(widget)
    m.CurrentChatMode = m.ChatModes[(tablex.find(m.ChatModes, m.CurrentChatMode) % #m.ChatModes) + 1]
    widget:setStyle(m.Skin, "speak_" .. m.CurrentChatMode)
end

function m.keyTyped(widget, char)
    if char == 10 then
        local text = stringx.trim(widget:getText())
        if string.len(text) > 0 then
            Network.sendToServer("illarion:chat", {
                mode = m.CurrentChatMode,
                message = text
            })
        end
        widget:setText("")
    end
end

return m