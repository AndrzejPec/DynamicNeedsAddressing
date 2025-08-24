----------------------------------------------------------------------
-- DynamicNeedsAddressing: Edibles scanner (bez rotten/burnt) + debug
----------------------------------------------------------------------

DNA = DNA or {}

DNA.HUNGER_DECREASE_IS_NEGATIVE = true

function DNA.isFoodLike(item) -- if item is not food-like, it is definately not edible, but if it is food-like, it is not necessarily edible (eg. cigarettes)
    if not item then return false end
    if item.IsFood and item:IsFood() then return true end
    if item.getCategory and item:getCategory() == "Food" then return true end
    return false
end

function DNA.isRotten(item)
    local v = (item.isRotten and item:isRotten())
          or (item.IsRotten and item:IsRotten())
    return v and true or false
end

function DNA.isCooked(item) -- if item is not cookable, it is considered cooked thus edible
    if not item then return true end
    if not (item.isCookable and item:isCookable()) then
        return true
    end
    local v = (item.isCooked and item:isCooked())
           or (item.IsCooked and item:IsCooked())
    return v and true or false
end

function DNA.isBurnt(item)
    local v = (item.isBurnt and item:isBurnt())
          or (item.IsBurnt and item:IsBurnt())
    return v and true or false
end

function DNA.edibleByHunger(item) -- here's where cigarettes and such are handled (they don't satiate hunger)
    local h = item.getHungerChange and item:getHungerChange() or nil
    if h == nil then return true, nil, nil end
    local eff = DNA.HUNGER_DECREASE_IS_NEGATIVE and -h or h
    return eff > 0, h, eff
end

function DNA.isEdible(item)
    if not DNA.isFoodLike(item) then return false end
    if DNA.isRotten(item) or DNA.isBurnt(item) then return false end
    if not DNA.isCooked(item) then return false end
    local ok = DNA.edibleByHunger(item)
    return ok
end

local function collectEdiblesFrom(inv)
    local out = ArrayList.new()

    if inv and inv.getAllEvalRecurse then
        inv:getAllEvalRecurse(function(it) return DNA.isEdible(it) end, out)
    end

    local p = getPlayer()
    if not p then print("[DNA] No player") return out end
    local sq = p:getSquare()
    if not sq then print("[DNA] No player square") return out end
    local cell = getCell()
    if not cell then print("[DNA] No cell") return out end

    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    print(string.format("[DNA] Checking 3x3 squares around (%d,%d,%d)", x, y, z))

    for dx = -1, 1 do
        for dy = -1, 1 do
            local gs = cell:getGridSquare(x + dx, y + dy, z)
            if gs then
                -- 1) WorldObjects na ziemi
                local wobs = gs:getWorldObjects()
                if wobs then
                    for i = 0, wobs:size() - 1 do
                        local wo = wobs:get(i)
                        local item = wo and wo.getItem and wo:getItem() or nil
                        if item then
                            print(string.format("[DNA] floor item: %s [%s]", item:getName(), item:getFullType()))
                            if DNA.isEdible(item) then out:add(item) end
                        end
                        if wo and wo.getItems and wo:getItems() then
                            local stack = wo:getItems()
                            for k = 0, stack:size() - 1 do
                                local it = stack:get(k)
                                if it then
                                    print(string.format("[DNA] floor stack: %s [%s]", it:getName(), it:getFullType()))
                                    if DNA.isEdible(it) then out:add(it) end
                                end
                            end
                        end
                    end
                end

                -- 2) Obiekty ze square (np. lodówki, szafki)
                local objs = gs:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        if o and o.getContainer and o:getContainer() then
                            local c = o:getContainer()
                            print(string.format("[DNA] container found: %s at (%d,%d,%d) with %d items",
                                tostring(o:getSprite() and o:getSprite():getName() or o:getName() or "unknown"),
                                x+dx, y+dy, z, c:getItems():size()))
                            local items = c:getItems()
                            for k = 0, items:size() - 1 do
                                local it = items:get(k)
                                if it then
                                    print(string.format("    container item: %s [%s]", it:getName(), it:getFullType()))
                                    if DNA.isEdible(it) then
                                        print("    -> edible, adding")
                                        out:add(it)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    print(string.format("[DNA] Total collected edibles: %d", out:size()))
    return out
end

function DNA.eatItemPortion(item, portion)
    local p = getPlayer()
    if not p or not item or not portion then return end
    if portion == "satiety" then
        local hunger = p:getStats() and p:getStats():getHunger() or 0
        local ok, _, eff = DNA.edibleByHunger(item)
        if not ok or not eff or eff <= 0 then
            print("[DNA] Cannot compute satiety portion for this item")
            return
        end
        portion = math.min(1, hunger / eff)
        if portion <= 0 then
            print("[DNA] Already satiated")
            return
        end
    end
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
        local done = false
        local ok1 = pcall(function() ISInventoryPaneContextMenu.transferIfNeeded(p, item) end)
        if ok1 then done = true end
        if not done then pcall(function() ISInventoryPaneContextMenu.transferIfNeeded(item) end) end
    end
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.eatItem then
        ISInventoryPaneContextMenu.eatItem(item, portion, 0)
        return
    end
    print("[DNA] No eat action available")
end

local function ediblePoints(it)
    local ok, _, eff = DNA.edibleByHunger(it)
    if not ok or not eff then return 0 end
    return math.floor(eff * 100 + 0.5)
end

--- MENU ---

function fmtGroupLabel(g)
    local base = g.name
    if g.points and g.points ~= 0 then
        base = string.format("%s (%d)", base, g.points)
    end
    if #g.items > 1 then
        return string.format("[%d] %s", #g.items, base)
    end
    return base
end

local function groupEdibles(list)
    local map, groups = {}, {}
    for i = 0, list:size() - 1 do
        local it = list:get(i)
        local name = it:getName() or it:getType()
        local pts = ediblePoints(it)
        local key = tostring(name) .. "|" .. tostring(pts)
        local g = map[key]
        if not g then
            g = { name = name, points = pts, items = {} }
            map[key] = g
            table.insert(groups, g)
        end
        table.insert(g.items, it)
    end
    table.sort(groups, function(a, b)
        if a.points ~= b.points then return a.points > b.points end
        return a.name < b.name
    end)
    return groups
end

local function addPortionSubmenu(context, parentMenu, group)
    local first = group.items and group.items[1]
    if not first then
        parentMenu:addOption("No items", nil, nil)
        return
    end

    local opt = parentMenu:addOption(fmtGroupLabel(group), context, function(selfCtx)
        if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end
        DNA.eatItemPortion(first, "satiety")
    end)

    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(opt, sub)

    sub:addOption("Eat all",     context, function(selfCtx) if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end DNA.eatItemPortion(first, 1.0) end)
    sub:addOption("Eat half",    context, function(selfCtx) if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end DNA.eatItemPortion(first, 0.5) end)
    sub:addOption("Eat quarter", context, function(selfCtx) if selfCtx and selfCtx.closeAll then selfCtx:closeAll() end DNA.eatItemPortion(first, 0.25) end)

    local tex = (first.getTex and first:getTex()) or (first.getTexture and first:getTexture()) or nil
    if tex then opt.iconTexture = tex; opt.texture = tex end
end


function DNA.openEdiblesMenu(playerObj, x, y)
    playerObj = playerObj or getPlayer()
    if not playerObj then return end

    local inv = playerObj:getInventory()
    local foods = collectEdiblesFrom(inv)
    local px = playerObj:getPlayerNum() or 0

    local mx = (x or getMouseX())
    local my = (y or getMouseY())

    local groups = groupEdibles(foods)
    local context = ISContextMenu.get(px, mx, my)
    context.x = mx + 5
    context.y = my + 15

    if not groups or #groups == 0 then
        context:addOption("No edible items", nil, nil)
        return
    end

    local rootOpt = context:addOption("Eat...")
    local rootSub = ISContextMenu:getNew(context)
    context:addSubMenu(rootOpt, rootSub)

    for _, g in ipairs(groups) do
        addPortionSubmenu(context, rootSub, g)
    end
end

--- DEBUG ---

function Debug_PrintAllEdibles(playerObj)
    playerObj = playerObj or getPlayer()
    if not playerObj then print("[DynamicNeedsAddressing] [Edibles] No player") return end
    local inv = playerObj:getInventory()
    local foods = collectEdiblesFrom(inv)
    print(string.format("[Edibles] found %d edible items", foods:size()))
    for i = 0, foods:size() - 1 do
        local it = foods:get(i)
        local ok, hRaw, hEff = DNA.edibleByHunger(it)
        local d_isFood    = DNA.isFoodLike(it)
        local d_catIsFood = (it.getCategory and it:getCategory() == "Food") or false
        local d_isRotten  = DNA.isRotten(it)
        local d_isBurnt   = DNA.isBurnt(it)
        print(string.format(
            " - %s [%s] | hungerChange=%s | hungerEff=%s | isFood=%s | cat=='Food'=%s | IsRotten=%s | isBurnt=%s",
            it:getName(),
            it:getFullType(),
            tostring(hRaw),
            tostring(hEff),
            tostring(d_isFood),
            tostring(d_catIsFood),
            tostring(d_isRotten),
            tostring(d_isBurnt)
        ))
    end
end
