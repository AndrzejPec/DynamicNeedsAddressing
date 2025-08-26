DNA = DNA or {}

local function _hasFluidComponent(it)
    if not it then return false end
    local ok1, fc = pcall(function() return it.getFluidContainer and it:getFluidContainer() end)
    if ok1 and fc then return true end
    local ok2, cap = pcall(function() return it.getFluidContainerCapacity and it:getFluidContainerCapacity() end)
    if ok2 and cap and cap > 0 then return true end
    local ok3, v3 = pcall(function() return it.isFluidContainer and it:isFluidContainer() end)
    if ok3 and v3 then return true end
    return false
end

function DNA.beverageReasons(it)
    if not it then return {} end
    local reasons = {}
    local function add(r) if r then table.insert(reasons, r) end end
    if _hasFluidComponent(it) then add("component:FluidContainer") end
    local cm = nil
    if it.getCustomMenuOption then local ok,v=pcall(function() return it:getCustomMenuOption() end); if ok then cm=v end end
    if not cm and it.getCustomContextMenu then local ok2,v2=pcall(function() return it:getCustomContextMenu() end); if ok2 then cm=v2 end end
    if type(cm)=="string" and string.lower(cm)=="drink" then add("customMenu:Drink") end
    local sndEat = it.getCustomEatSound and it:getCustomEatSound() or nil
    if type(sndEat)=="string" and string.find(string.lower(sndEat),"drink",1,true) then add("sound:drinking(eat)") end
    local sndDrink = it.getCustomDrinkSound and it:getCustomDrinkSound() or nil
    if type(sndDrink)=="string" and string.find(string.lower(sndDrink),"drink",1,true) then add("sound:drinking(drink)") end
    return reasons
end

function DNA.beverageReason(it)
    local r = DNA.beverageReasons(it)
    return r[1]
end

function DNA.isBeverage(it)
    return DNA.beverageReason(it) ~= nil
end

function DNA.findBeveragesInInventory(inv)
    local out = ArrayList.new()
    if inv and inv.getAllEvalRecurse then
        inv:getAllEvalRecurse(function(it) return DNA.isBeverage(it) end, out)
    end
    return out
end

function DNA.collectBeveragesFrom(inv)
    local out = DNA.findBeveragesInInventory(inv)
    local p = getPlayer()
    if not p then DNA.msg("[DNA] No player") return out end
    local sq = p:getSquare()
    if not sq then DNA.msg("[DNA] No player square") return out end
    local cell = getCell()
    if not cell then DNA.msg("[DNA] No cell") return out end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    DNA.msg(string.format("[DNA] Checking beverages in 3x3 around (%d,%d,%d)", x, y, z))
    for dx=-1,1 do
        for dy=-1,1 do
            local gs = cell:getGridSquare(x+dx, y+dy, z)
            if gs then
                local wobs = gs:getWorldObjects()
                if wobs then
                    for i=0,wobs:size()-1 do
                        local wo = wobs:get(i)
                        local item = wo and wo.getItem and wo:getItem() or nil
                        if item and DNA.isBeverage(item) then out:add(item) end
                        if wo and wo.getItems and wo:getItems() then
                            local stack = wo:getItems()
                            for k=0,stack:size()-1 do
                                local it = stack:get(k)
                                if it and DNA.isBeverage(it) then out:add(it) end
                            end
                        end
                    end
                end
                local objs = gs:getObjects()
                if objs then
                    for i=0,objs:size()-1 do
                        local o = objs:get(i)
                        if o and o.getContainer and o:getContainer() then
                            local c = o:getContainer()
                            local items = c and c:getItems() or nil
                            if items then
                                for k=0,items:size()-1 do
                                    local it = items:get(k)
                                    if it and DNA.isBeverage(it) then out:add(it) end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    DNA.msg(string.format("[DNA] Total collected beverages: %d", out:size()))
    return out
end

function DNA.isBeverageForNeed(it, needKey)
    if not DNA.isBeverage(it) then return false end
    local pts = DNA.needPoints and DNA.needPoints(it) or nil
    if not pts then return false end
    local v = pts[needKey] or 0
    return v > 0
end

function DNA.findBeveragesForNeed(inv, needKey)
    local all = DNA.findBeveragesInInventory(inv)
    local out = ArrayList.new()
    for i=0, all:size()-1 do
        local it = all:get(i)
        if DNA.isBeverageForNeed(it, needKey or "thirst") then out:add(it) end
    end
    return out
end

-- function DNA.drinkItemPortion(item, portion)
--     local p = getPlayer()
--     if not p or not item or not portion then return end
--     if portion == "satiety" then
--         local hunger = p:getStats() and p:getStats():getHunger() or 0
--         local ok, _, eff = DNA.edibleByHunger(item)
--         if not ok or not eff or eff <= 0 then
--             print("[DNA] Cannot compute satiety portion for this drink")
--             return
--         end
--         portion = math.min(1, hunger / eff)
--         if portion <= 0 then
--             print("[DNA] Already satiated")
--             return
--         end
--     end
--     if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
--         local done = false
--         local ok1 = pcall(function() ISInventoryPaneContextMenu.transferIfNeeded(p, item) end)
--         if ok1 then done = true end
--         if not done then pcall(function() ISInventoryPaneContextMenu.transferIfNeeded(item) end) end
--     end
--     if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.eatItem then
--         ISInventoryPaneContextMenu.eatItem(item, portion, 0)
--         return
--     end
--     print("[DNA] No drink action available")
-- end

local function addDrinkPortionSubmenu(context, parentMenu, group, needKey)
    needKey = needKey or "hunger"
    local first = group.items and group.items[1]
    if not first then
        parentMenu:addOption("No items", nil, nil)
        return
    end
    local pl = getPlayer()
    local label = first:getName() .. " " .. (DNA.parenLabel(pl, first, needKey) or "")
    local opt = parentMenu:addOption(label ~= "" and label or first:getName(), context, function(selfCtx)
        if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end
        DNA.eatItemPortion(first, "satiety")
    end)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(opt, sub)
    sub:addOption("Drink all",     context, function(selfCtx) if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end DNA.eatItemPortion(first, 1.0) end)
    sub:addOption("Drink half",    context, function(selfCtx) if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end DNA.eatItemPortion(first, 0.5) end)
    sub:addOption("Drink quarter", context, function(selfCtx) if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end DNA.eatItemPortion(first, 0.25) end)
    local tex = (first.getTex and first:getTex()) or (first.getTexture and first:getTexture()) or nil
    if tex then opt.iconTexture = tex; opt.texture = tex end
end

function Debug_DNA.msgBeverages()
    local p = getPlayer()
    if not p then DNA.msg("[DNA] No player") return end
    local list = DNA.findBeveragesInInventory(p:getInventory())
    DNA.msg(string.format("[DNA] Inventory beverages: %d", list:size()))
    for i=0,list:size()-1 do
        local it = list:get(i)
        local reasons = table.concat(DNA.beverageReasons(it), ",")
        DNA.msg(string.format("Drink: %s [%s] | reasons=%s", it:getName(), it:getFullType(), reasons ~= "" and reasons or "none"))
    end
end
