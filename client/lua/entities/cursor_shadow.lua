local m = {}

local FadeDuration = 0.1

function m.TickEntity(Entity, Data, Delta)
    Data.TimePassed = (Data.TimePassed or 0) + Delta
    local component = Entity:getComponent("illarion:visual")
    if component then
        component:setAlpha(1 - (Data.TimePassed / FadeDuration))
        if Data.TimePassed > FadeDuration then
            Entity:despawn()
        end
    end
end

return m