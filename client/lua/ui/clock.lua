local Game = require("selene.game")

local m = {}

function m.Initialize(bindings)
    m.CounterTime = bindings["CounterTime"]

    -- TODO selene.timer could provide a Minute event that fires every full minute instead
    Game.PreTick:Connect(function()
        local time = os.date("*t")
        local hour = string.format("%02d", time.hour)
        local min = string.format("%02d", time.min)
        m.CounterTime.Text = hour .. ":" .. min
    end)
end

return m