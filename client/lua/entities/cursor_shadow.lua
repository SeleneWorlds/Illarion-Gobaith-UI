local m = {}

function m.TickEntity(Entity, Data, Delta)
    Data.TimePassed = (Data.TimePassed or 0) + Delta
    local visual = Entity:GetComponent("illarion:visual")
    if visual then
        local alpha = 1 - (Data.TimePassed / 0.1)
        visual:SetColor(1, 1, 1, alpha)
    end
end

return m