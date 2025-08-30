local Registries = require("selene.registries")
local Network = require("selene.network")
local Sounds = require("selene.sounds")

local OverrideTrack = nil
local CombatTrack = nil
local CurrentDefaultTrack = nil

local CurrentTrack = nil

local function SetSoundTrack(sound)
    if CurrentTrack == sound then
        return
    end

    if sound ~= nil then
        Sounds.PlayLocalSound(sound)
    else
        Sounds.StopSound(CurrentTrack)
    end
    CurrentTrack = sound
end

Network.HandlePayload("illarion:music", function(payload)
    if payload.musicId == 0 then
        OverrideTrack = nil
    else
        local sound = Registries.FindByMetadata("sounds", "musicId", payload.musicId)
        if sound then
            OverrideTrack = sound
        else
            print("Music not found: " .. payload.musicId)
            OverrideTrack = nil
        end
    end
end)

Game.PreTick:Connect(function()
    local isInCombat = false
    if isInCombat then
        if CombatTrack == nil then
            CombatTrack = Registries.FindByMetadata("sounds", "musicId", 1)
        end
        SetSoundTrack(CombatTrack)
    elseif OverrideTrack ~= nil then
        SetSoundTrack(OverrideTrack)
    else
        SetSoundTrack(CurrentDefaultTrack)
    end
end)