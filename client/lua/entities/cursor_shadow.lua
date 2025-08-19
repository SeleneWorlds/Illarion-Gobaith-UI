local m = {}

function m.TickEntity(Entity, Data, Delta)
    Data.TimePassed = (Data.TimePassed or 0) + Delta
    local visual = Entity:GetComponent("illarion:visual")
    if visual then
        visual.Alpha = 1 - (Data.TimePassed / 0.1)
        if Data.TimePassed > 0.1 then
            Entity:Despawn()
        end
    end
end

return m