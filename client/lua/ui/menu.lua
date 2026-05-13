local Task = require("selene.task")
local UI = require("selene.ui.lml")
local Loaders = require("selene.ui.coroutine")
local Network = require("selene.network")
local Visuals = require("selene.visuals")

local m = {}

local MENU_SLOT_COUNT = 20

local function GetSlotName(index)
    return "menu_slot:" .. index
end

local function HideMenu()
    if m.Root then
        m.Root:setVisible(false)
    end
    m.ActiveItems = {}
    m.MenuId = nil
end

local function ApplyItem(slotIndex, item)
    local actor = m.Hud:getActor(GetSlotName(slotIndex))
    if not actor then
        return
    end

    if not item then
        actor:setStyle(m.Theme, "hidden")
        actor:setVisible(false)
        m.ActiveItems[GetSlotName(slotIndex)] = nil
        return
    end

    m.ActiveItems[GetSlotName(slotIndex)] = item.id
    actor:setVisible(true)

    Task.launch(function()
        local visual = Visuals.create(item.visual)
        local style = UI.createImageButtonStyle({
            over = "menu_select",
            imageUp = visual:getDrawable():withoutOffset()
        }, m.Theme)
        actor:setStyle(style)
    end)
end

function m.Initialize(theme)
    m.Theme = theme
    m.ActiveItems = {}
    m.Hud = Loaders.loadUI("client/ui/illarion/menu.xml", {
        theme = theme,
        actions = {
            menuClick = m.menuClick
        }
    })
    UI.addToRoot(m.Hud)

    m.Root = m.Hud:getActor("MenuStruct")
    HideMenu()

    Network.handlePayload("illarion:menu_struct", function(payload)
        m.MenuId = payload.id
        m.Root:setVisible(true)

        local items = payload.items or {}
        for index = 1, MENU_SLOT_COUNT do
            ApplyItem(index, items[index])
        end
    end)
end

function m.menuClick(widget)
    local itemId = m.ActiveItems[widget:getName()]
    if not m.MenuId or not itemId then
        return
    end

    Network.sendToServer("illarion:menu_struct", {
        id = m.MenuId,
        itemId = itemId
    })
    HideMenu()
end

return m
