local function _kindToPredicate(kind)
    if type(kind) == "function" then return kind end
    local s = tostring(kind or "")
    if s == "edible" then return DNA.isEdible end
    if s == "beverage" then return DNA.isBeverage end
    return function() return false end
end

local function _getItemContainerFromItem(it)
    if not it then return nil end
    local ok1, c1 = pcall(function() return it.getItemContainer and it:getItemContainer() end)
    if ok1 and c1 then return c1 end
    local ok2, c2 = pcall(function() return it.getInventory and it:getInventory() end)
    if ok2 and c2 then return c2 end
    return nil
end

local function _visitAllItemContainersOnObject(o, fn)
    if not o or not fn then return end
    if o.getContainer and o:getContainer() then fn(o:getContainer()) end
    if o.getContainerCount and o.getContainerByIndex then
        local n = o:getContainerCount()
        if n and n > 0 then
            for ci = 0, n - 1 do
                local c = o:getContainerByIndex(ci)
                if c then fn(c) end
            end
        end
    end
end

function DNA.collectItems(kind)
    local pred = _kindToPredicate(kind)
    local out = ArrayList.new()
    local p = getPlayer()
    if not p then print("[DNA] No player") return out end
    local inv = p:getInventory()
    if inv and inv.getAllEvalRecurse then
        inv:getAllEvalRecurse(function(it) return pred(it) end, out)
    end
    local sq = p:getSquare()
    if not sq then print("[DNA] No player square") return out end
    local cell = getCell()
    if not cell then print("[DNA] No cell") return out end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    print(string.format("[DNA] Scanning 3x3 around (%d,%d,%d)", x, y, z))
    for dx = -1, 1 do
        for dy = -1, 1 do
            local gs = cell:getGridSquare(x + dx, y + dy, z)
            if gs then
                local wobs = gs:getWorldObjects()
                if wobs then
                    for i = 0, wobs:size() - 1 do
                        local wo = wobs:get(i)
                        local item = wo and wo.getItem and wo:getItem() or nil
                        if item and pred(item) then out:add(item) end
                        if item then
                            local bag = _getItemContainerFromItem(item)
                            if bag and bag.getItems then
                                local items = bag:getItems()
                                for k = 0, items:size() - 1 do
                                    local it = items:get(k)
                                    if it and pred(it) then out:add(it) end
                                end
                            end
                        end
                        if wo and wo.getItems and wo:getItems() then
                            local stack = wo:getItems()
                            for k = 0, stack:size() - 1 do
                                local it = stack:get(k)
                                if it and pred(it) then out:add(it) end
                                if it then
                                    local bag = _getItemContainerFromItem(it)
                                    if bag and bag.getItems then
                                        local items = bag:getItems()
                                        for j = 0, items:size() - 1 do
                                            local it2 = items:get(j)
                                            if it2 and pred(it2) then out:add(it2) end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                local objs = gs:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        _visitAllItemContainersOnObject(o, function(c)
                            local items = c and c.getItems and c:getItems() or nil
                            if items then
                                for k = 0, items:size() - 1 do
                                    local it = items:get(k)
                                    if it and pred(it) then out:add(it) end
                                end
                            end
                        end)
                    end
                end
            end
        end
    end
    print(string.format("[DNA] Total collected items: %d", out:size()))
    return out
end

function DNA.collectEdibles()
    return DNA.collectItems("edible")
end

function DNA.collectBeverages()
    return DNA.collectItems("beverage")
end

function DNA.collectEdiblesFrom(_)
    return DNA.collectItems("edible")
end

function DNA.collectBeveragesFrom(_)
    return DNA.collectItems("beverage")
end
