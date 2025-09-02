local m = {}

local FadeDuration = 0.1

function m.TickEntity(Entity, Data, Delta)
    Data.TimePassed = (Data.TimePassed or 0) + Delta
    local component = Entity:GetComponent("illarion:visual")
    if component then
        component.Alpha = 1 - (Data.TimePassed / FadeDuration)
        if Data.TimePassed > FadeDuration then
            Entity:Despawn()
        end
    end
end

return m