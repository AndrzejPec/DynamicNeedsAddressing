DNA = DNA or {}

DNA.OpenRecipeKind = {
    OpenCannedFood = "eat",
    OpenCannedFood2 = "eat",
    OpenCannedFoodWithKnifeOrSharpStoneFlake = "eat",
    OpenBottleOfBeer = "drink",
    OpenBottleOfChampagne = "drink",
    OpenBottleOfWine = "drink",
    OpenCanOfBeverage = "drink",
}

DNA._consumeQ = DNA._consumeQ or {first=1,last=0,data={}}
function DNA._qpush(x) local q=DNA._consumeQ q.last=q.last+1 q.data[q.last]=x end
function DNA._qpop() local q=DNA._consumeQ if q.first>q.last then return nil end local v=q.data[q.first] q.data[q.first]=nil q.first=q.first+1 return v end
function DNA._qclear() local q=DNA._consumeQ q.first=1 q.last=0 q.data={} end
function DNA._qempty() local q=DNA._consumeQ return q.first>q.last end

if not DNA.__Actions_addOrDropItem__ then
    DNA.__Actions_addOrDropItem__ = Actions.addOrDropItem
    function Actions.addOrDropItem(playerObj, item)
        DNA.__Actions_addOrDropItem__(playerObj, item)
        if not DNA._qempty() then
            local percent = DNA._qpop()
            ISInventoryPaneContextMenu.eatItem(item, percent, playerObj:getPlayerNum())
        end
    end
end

if not DNA.__ISHandcraftAction_stop__ then
    DNA.__ISHandcraftAction_stop__ = ISHandcraftAction.stop
    function ISHandcraftAction:stop()
        DNA.__ISHandcraftAction_stop__(self)
        DNA._qclear()
    end
end

local function _walkToContainerIfNeeded(item, player)
    local playerInv = getPlayerInventory(player).inventory
    local parent = item:getContainer()
    if parent ~= playerInv then
        if not luautils.walkToContainer(parent, player) then
            return false
        end
    end
    return true
end

function DNA.onOpenThenEat(item, func, recipe, player, all, percent)
    if not _walkToContainerIfNeeded(item, player) then return end
    DNA._qpush(percent or 1)
    func(item, recipe, player, all)
end

function DNA.onOpenThenDrink(item, func, recipe, player, all, percent)
    if not _walkToContainerIfNeeded(item, player) then return end
    local playerObj = getSpecificPlayer(player)
    func(item, recipe, player, all)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(ISDrinkFluidAction:new(playerObj, item:getWorldItem() or item, percent or 1))
end

function DNA._injectOpeners(player, context, items)
    for i,v in ipairs(context.options) do
        if instanceof(v.param1, "CraftRecipe") then
            local item = v.target
            local func = v.onSelect
            local recipe = v.param1
            local pnum = v.param2
            local all = v.param3
            local kind = DNA.OpenRecipeKind[recipe:getName()]
            if kind == "eat" then
                local opt = context:insertOptionAfter(v.name, "Open then Eat", item, nil)
                opt.iconTexture = v.iconTexture
                local sub = ISContextMenu:getNew(context)
                context:addSubMenu(opt, sub)
                sub:addOption("Eat all", item, DNA.onOpenThenEat, func, recipe, pnum, all, 1.0)
                sub:addOption("Eat half", item, DNA.onOpenThenEat, func, recipe, pnum, all, 0.5)
                sub:addOption("Eat quarter", item, DNA.onOpenThenEat, func, recipe, pnum, all, 0.25)
            elseif kind == "drink" then
                local opt = context:insertOptionAfter(v.name, "Open then Drink", item, nil)
                opt.iconTexture = v.iconTexture
                local sub = ISContextMenu:getNew(context)
                context:addSubMenu(opt, sub)
                sub:addOption("Drink all", item, DNA.onOpenThenDrink, func, recipe, pnum, all, 1.0)
                sub:addOption("Drink half", item, DNA.onOpenThenDrink, func, recipe, pnum, all, 0.5)
                sub:addOption("Drink quarter", item, DNA.onOpenThenDrink, func, recipe, pnum, all, 0.25)
            end
        end
    end
end

if not DNA.__OpenersHooked__ then
    Events.OnFillInventoryObjectContextMenu.Add(DNA._injectOpeners)
    DNA.__OpenersHooked__ = true
    print("[DNA] Openers injected")
end
