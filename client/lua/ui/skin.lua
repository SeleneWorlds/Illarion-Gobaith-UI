local UI = require("selene.ui.lml")
local Loaders = require("selene.ui.coroutine")

return {
    LoadThemeRoutine = function()
        local atlas = Loaders.CreateAtlas({
            gui_bottom = "client/textures/illarion/ui/gui_bottom.png",
            gui_top = "client/textures/illarion/ui/gui_top.png",
            gui_chat = "client/textures/illarion/ui/gui_chat.png",
            gui_counter = "client/textures/illarion/ui/gui_counter.png",
            gui_status = "client/textures/illarion/ui/gui_status.png",
            speak_normal = "client/textures/illarion/ui/speak_normal.png",
            speak_ooc = "client/textures/illarion/ui/speak_ooc.png",
            speak_shout = "client/textures/illarion/ui/speak_shout.png",
            speak_whisper = "client/textures/illarion/ui/speak_whisper.png",
            inv_slot = "client/textures/illarion/ui/inv_slot-0.png",
            inv_slot_anim = "client/textures/illarion/ui/inv_slot-7.png",
            status_food = "client/textures/illarion/ui/status_food.png",
            status_health = "client/textures/illarion/ui/status_health.png",
            status_mana = "client/textures/illarion/ui/status_mana.png"
        })
        return Loaders.LoadTheme({
            ImageButton = {
                speak_normal = {
                    up = "speak_normal"
                },
                speak_ooc = {
                    up = "speak_ooc"
                },
                speak_shout = {
                    up = "speak_shout"
                },
                speak_whisper = {
                    up = "speak_whisper"
                }
            },
            Button = {
                inv_slot = {
                    up = "inv_slot",
                    over = "inv_slot_anim"
                }
            },
            Label = {
                gui_counter_time = {
                    font = "default",
                    fontColor = "#B2CCFF"
                },
                chat_say = {
                    font = "default",
                    fontColor = "#FFFFFF"
                },
                chat_ooc = {
                    font = "default",
                    fontColor = "#999999"
                },
                chat_whisper = {
                    font = "default",
                    fontColor = "#999999"
                },
                chat_emote = {
                    font = "default",
                    fontColor = "#FFFF33"
                },
                chat_inform = {
                    font = "default",
                    fontColor = "#B2CCFF"
                },
            },
            TextField = {
                default = {
                    font = "default"
                },
                chat_shout = {
                    font = "default",
                    fontColor = "#FF4C4C"
                },
                gui_counter_value = {
                    font = "default"
                }
            },
            ProgressBar = {
                status_health = {
                    knobBefore = "status_health"
                },
                status_food = {
                    knobBefore = "status_food"
                },
                status_mana = {
                    knobBefore = "status_mana"
                }
            }
        }, atlas)
    end
}