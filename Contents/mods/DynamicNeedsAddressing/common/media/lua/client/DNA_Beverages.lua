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
    if not p then print("[DNA] No player") return out end
    local sq = p:getSquare()
    if not sq then print("[DNA] No player square") return out end
    local cell = getCell()
    if not cell then print("[DNA] No cell") return out end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    print(string.format("[DNA] Checking beverages in 3x3 around (%d,%d,%d)", x, y, z))
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
    print(string.format("[DNA] Total collected beverages: %d", out:size()))
    return out
end

function DNA.isWaterSource(it)
    local v = (it and it.isWaterSource and it:isWaterSource()) or (it and it.IsWaterSource and it:IsWaterSource())
    return v and true or false
end

function DNA.isBeverageForNeed(it, needKey)
    if not DNA.isBeverage(it) then return false end
    local pts = DNA.needPoints and DNA.needPoints(it) or nil
    local h = pts and (pts.hunger or 0) or 0
    local t = pts and (pts.thirst or 0) or 0

    if needKey == "hunger" then
        if h > 0 then return true end
        local fc = nil
        if it.getFluidContainer then
            local ok, res = pcall(function() return it:getFluidContainer() end)
            if ok then fc = res end
        end
        if fc then
            local amt = nil
            local okA, vA = pcall(function() return fc.getAmount and fc:getAmount() end)
            if okA then amt = vA end
            local empty = nil
            local okB, vB = pcall(function() return fc.isEmpty and fc:isEmpty() end)
            if okB then empty = vB end
            if (amt and amt > 0) or (empty == false) then
                if not DNA.isWaterSource(it) then return true end
            end
        end
        return false
    end

    if needKey == "thirst" then
        if t > 0 then return true end
        local fc = nil
        if it.getFluidContainer then
            local ok, res = pcall(function() return it:getFluidContainer() end)
            if ok then fc = res end
        end
        if fc then
            local okB, vB = pcall(function() return fc.isEmpty and fc:isEmpty() end)
            if okB and vB == false then return true end
            local okA, vA = pcall(function() return fc.getAmount and fc:getAmount() end)
            if okA and vA and vA > 0 then return true end
        end
        return false
    end

    local v = pts and (pts[needKey] or 0) or 0
    return v > 0
end


function DNA.findBeveragesForNeed(inv, needKey)
    local all = DNA.findBeveragesInInventory(inv)
    local out = ArrayList.new()
    for i = 0, all:size()-1 do
        local it = all:get(i)
        if DNA.isBeverageForNeed(it, needKey or "thirst") then out:add(it) end
    end
    return out
end

function DNA._fluidHungerEffect(item)
    local fc = item.getFluidContainerFromSelfOrWorldItem and item:getFluidContainerFromSelfOrWorldItem() or (item.getFluidContainer and item:getFluidContainer() or nil)
    if not fc then print("[DNA] _fluidHungerEffect: no FluidContainer"); return nil end
    local fluid = fc.getPrimaryFluid and fc:getPrimaryFluid()
    if not fluid then print("[DNA] _fluidHungerEffect: no primary fluid"); return nil end
    local props = fluid.getProperties and fluid:getProperties()
    if not props then print("[DNA] _fluidHungerEffect: no properties"); return nil end
    local per1000 = props.getHungerChange and props:getHungerChange() or nil
    if not per1000 then print("[DNA] _fluidHungerEffect: no hungerChange"); return nil end
    local amount = fc.getPrimaryFluidAmount and fc:getPrimaryFluidAmount() or (fc.getAmount and fc:getAmount() or 0)
    local capacity = fc.getCapacity and fc:getCapacity() or 0
    local litersLike = capacity > 0 and capacity <= 10
    local volume_ml = litersLike and (amount * 1000) or amount
    local eff = math.abs(per1000) * (volume_ml / 1000)
    print("[DNA] _fluidHungerEffect per1000=", tostring(per1000), "amount=", tostring(amount), "capacity=", tostring(capacity), "volume_ml=", tostring(volume_ml), "eff=", tostring(eff))
    return eff
end

function DNA.drinkItemPortion(item, portion)
    local p = getPlayer()
    if not p or not item or not portion then print("[DNA] missing player/item/portion"); return end
    print("[DNA] drinkItemPortion START", item:getFullType(), "portion=", tostring(portion))

    if portion == "satiety" then
        local hunger = p:getStats() and p:getStats():getHunger() or 0
        print("[DNA] current hunger=", tostring(hunger))
        local eff = nil
        local ok, _, hEff = DNA.edibleByHunger(item)
        print("[DNA] edibleByHunger ok=", tostring(ok), "hEff=", tostring(hEff))
        if ok and hEff and hEff > 0 then eff = hEff end
        if not eff or eff <= 0 then eff = DNA._fluidHungerEffect(item) end
        if not eff or eff <= 0 then print("[DNA] Cannot compute satiety portion for this item"); return end
        portion = math.min(1, hunger / eff)
        print("[DNA] computed portion=", tostring(portion))
        if portion <= 0 then print("[DNA] Already satiated"); return end
    end

    local fc = item.getFluidContainerFromSelfOrWorldItem and item:getFluidContainerFromSelfOrWorldItem() or (item.getFluidContainer and item:getFluidContainer() or nil)
    print("[DNA] final fc=", tostring(fc))
    if fc then
        print("[DNA] calling onDrinkFluid with portion=", tostring(portion))
        ISInventoryPaneContextMenu.onDrinkFluid(item, portion, p)
        return
    end

    print("[DNA] calling eatItemPortion with portion=", tostring(portion))
    DNA.eatItemPortion(item, portion)
end

function DNA.addDrinkPortionSubmenu(context, parentMenu, group, needKey)
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
        DNA.drinkItemPortion(first, "satiety")
    end)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(opt, sub)
    sub:addOption("Drink all",     context, function(selfCtx) if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end DNA.drinkItemPortion(first, 1.0) end)
    sub:addOption("Drink half",    context, function(selfCtx) if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end DNA.drinkItemPortion(first, 0.5) end)
    sub:addOption("Drink quarter", context, function(selfCtx) if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end DNA.drinkItemPortion(first, 0.25) end)
    local tex = (first.getTex and first:getTex()) or (first.getTexture and first:getTexture()) or nil
    if tex then opt.iconTexture = tex; opt.texture = tex end
end

--- DEBUG ---

function Debug_printBeverages()
    local p = getPlayer()
    if not p then print("[DNA] No player") return end
    local list = DNA.findBeveragesInInventory(p:getInventory())
    print(string.format("[DNA] Inventory beverages: %d", list:size()))
    for i=0,list:size()-1 do
        local it = list:get(i)
        local reasons = table.concat(DNA.beverageReasons(it), ",")
        print(string.format("Drink: %s [%s] | reasons=%s", it:getName(), it:getFullType(), reasons ~= "" and reasons or "none"))
    end
end

function Debug_PrintBeveragesForHunger()
    local p = getPlayer()
    if not p then print("[DNA] No player") return end
    local list = DNA.collectBeveragesFrom(p:getInventory())
    print(string.format("[DNA] Hunger beverages: %d", list:size()))
    for i=0,list:size()-1 do
        local it = list:get(i)
        local ok = DNA.isBeverageForNeed(it, "hunger")
        local reasons = table.concat(DNA.beverageReasons(it), ",")
        print(string.format("Probe: %s [%s] | hungerOK=%s | reasons=%s", it:getName(), it:getFullType(), tostring(ok), reasons ~= "" and reasons or "none"))
    end
end

local function _str(x) return tostring(x) end

local function _safe_call(obj, m)
    if not obj or not m or not obj[m] then return nil end
    local ok, res = pcall(function() return obj[m](obj) end)
    if ok then return res end
    return nil
end

local function _first_non_nil(...)
    local t = {...}
    for i=1,#t do
        if t[i] ~= nil then return t[i] end
    end
    return nil
end

function Debug_ProbeFluid(fullType)
    local p = getPlayer()
    if not p then print("[DNA] No player") return end
    local inv = p:getInventory()
    local it = inv and inv:FindAndReturn(fullType) or nil
    if not it then print("[DNA] Item not found: ".._str(fullType)) return end
    print(string.format("[DNA] Probe item: %s [%s]", it:getName(), it:getFullType()))

    local fc = _safe_call(it, "getFluidContainer")
    if not fc then
        print("[DNA] No FluidContainer")
        return
    end
    print("[DNA] FluidContainer present = true")

    local cap = _first_non_nil(_safe_call(it,"getFluidContainerCapacity"), _safe_call(fc,"getCapacity"))
    local amt = _safe_call(fc,"getAmount")
    local rem = _safe_call(fc,"getRemaining")
    local pct = _safe_call(fc,"getPercent")
    local empty = _safe_call(fc,"isEmpty")
    print(string.format("[DNA] capacity=%s amount=%s remaining=%s percent=%s empty=%s",
        _str(cap), _str(amt), _str(rem), _str(pct), _str(empty)))

    local ftype = _first_non_nil(_safe_call(fc,"getFluidFullType"), _safe_call(fc,"getFluidType"), _safe_call(fc,"getFluid"))
    print("[DNA] fluid-type=".._str(ftype))

    local contentItem = _first_non_nil(_safe_call(fc,"getContentItem"), _safe_call(fc,"getItem"))
    if contentItem then
        print(string.format("[DNA] content item: %s [%s]", _safe_call(contentItem,"getName") or "?", _safe_call(contentItem,"getFullType") or "?"))
        local h = _safe_call(contentItem,"getHungerChange")
        local t = _safe_call(contentItem,"getThirstChange")
        print(string.format("[DNA] content hunger=%s thirst=%s", _str(h), _str(t)))
        local tags = {}
        local list = _safe_call(contentItem,"getTags")
        if list then
            for i=0, list:size()-1 do table.insert(tags, tostring(list:get(i))) end
        end
        print("[DNA] content tags="..table.concat(tags, ","))
        local sndD = _safe_call(contentItem,"getCustomDrinkSound")
        local sndE = _safe_call(contentItem,"getCustomEatSound")
        print(string.format("[DNA] content sounds drink=%s eat=%s", _str(sndD), _str(sndE)))
    else
        print("[DNA] no direct content item API")
    end
end

function DNA.debugFluidHT(itemType)
    local p = getPlayer()
    if not p then print("[DNA] no player"); return end
    local inv = p:getInventory()
    local item = inv:FindAndReturn(itemType)
    if not item then print("[DNA] not found item:", itemType); return end

    local fc = item.getFluidContainerFromSelfOrWorldItem and item:getFluidContainerFromSelfOrWorldItem()
    if not fc then print("[DNA] no fluidContainer for", itemType); return end

    local fluid = fc.getPrimaryFluid and fc:getPrimaryFluid()
    if not fluid then print("[DNA] no primary fluid for", itemType); return end

    local props = fluid.getProperties and fluid:getProperties()
    if not props then print("[DNA] no properties for", itemType); return end

    local hunger = props.getHungerChange and props:getHungerChange() or nil
    local thirst = props.getThirstChange and props:getThirstChange() or nil
    if hunger == nil or thirst == nil then
        print("[DNA] missing HT values for", itemType)
        return
    end

    -- print("[DNA] fluid:", tostring(fluid:getName()))
    print("[DNA] hungerPer1000ml:", tostring(hunger))
    print("[DNA] thirstPer1000ml:", tostring(thirst))
end
