local Registries = require("selene.registries")
local Network = require("selene.network")
local Sounds = require("selene.sounds")
local Game = require("selene.game")

local OverrideTrack = nil
local CombatTrack = nil
local CurrentDefaultTrack = nil

local CurrentTrack = nil
local Combat = require("illarion-client-core.client.lua.combat")

local function SetSoundTrack(sound)
    if CurrentTrack == sound then
        return
    end

    if CurrentTrack ~= nil then
        Sounds.stopSound(CurrentTrack)
    end
    if sound ~= nil then
        Sounds.playLocalSound(sound)
    end
    CurrentTrack = sound
end

Network.handlePayload("illarion:music", function(payload)
    if payload.musicId == 0 then
        OverrideTrack = nil
    else
        local sound = Registries.findByMetadata("sounds", "songId", payload.musicId)
        if sound then
            OverrideTrack = sound
        else
            print("Music not found: " .. payload.musicId)
            OverrideTrack = nil
        end
    end
end)

Game.preTick:connect(function()
    if Combat.getTargetId() then
        if CombatTrack == nil then
            CombatTrack = Registries.findByMetadata("sounds", "songId", 1)
        end
        SetSoundTrack(CombatTrack)
    elseif OverrideTrack ~= nil then
        SetSoundTrack(OverrideTrack)
    else
        SetSoundTrack(CurrentDefaultTrack)
    end
end)
