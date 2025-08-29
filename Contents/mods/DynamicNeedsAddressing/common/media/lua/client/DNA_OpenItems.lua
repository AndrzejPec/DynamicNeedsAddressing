function DNA.boolcall(obj, m)
    if not obj or not m or not obj[m] then return nil end
    local ok, v = pcall(function() return obj[m](obj) end)
    if not ok then return nil end
    if type(v) == "boolean" then return v end
    return v
end

function _strcall(obj, m)
    if not obj or not m or not obj[m] then return nil end
    local ok, v = pcall(function() return obj[m](obj) end)
    if ok and v and type(v) == "string" and v ~= "" then return v end
    return nil
end

function _getReplaceOnUseOn(it)
    return _strcall(it, "getReplaceOnUseOn") or _strcall(it, "getReplaceOnUse")
end

function _isSealedByItem(it)
    if not it then return false end
    local sealed = DNA.boolcall(it, "isSealed")
    if sealed ~= nil then return sealed and true or false end
    local canOpen = DNA.boolcall(it, "canBeOpened")
    local opened  = DNA.boolcall(it, "isOpened")
    if canOpen == true and opened == false then return true end
    return false
end

function _isSealedByFluid(it)
    local fc = _tryGetFluidContainer(it)
    if not fc then return false end
    local sealed = DNA.boolcall(fc, "isSealed")
    if sealed ~= nil then return sealed and true or false end
    local canOpen = DNA.boolcall(fc, "canBeOpened") or DNA.boolcall(fc, "canOpen")
    local opened  = DNA.boolcall(fc, "isOpened")
    if canOpen == true and opened == false then return true end
    return false
end

function _isSealed(it)
    return _isSealedByItem(it) or _isSealedByFluid(it)
end

function _openItem(playerObj, it)
    print("[DNA] Opening sealed item:", it:getFullType())
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.onOpenItem then
        return ISInventoryPaneContextMenu.onOpenItem(it, playerObj)
    end
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.onOpen then
        return ISInventoryPaneContextMenu.onOpen(it, playerObj)
    end
    print("[DNA] No open handler found")
end

function _findOpenedAfterReplace(inv, it)
    local rep = _getReplaceOnUseOn(it)
    if rep then
        local opened = inv:FindAndReturn(rep)
        if opened then return opened end
    end
    local same = inv:FindAndReturn(it:getFullType())
    if same and _isSealed(same) == false then return same end
    return nil
end

function _afterOpenThenDrink(playerObj, originalItem, portion, triesMax)
    local tries = 0
    local id = {}
    function tick()
        tries = tries + 1
        local inv = playerObj and playerObj:getInventory() or nil
        if not inv then
            print("[DNA] No inventory during open-wait")
            Events.OnPlayerUpdate.Remove(tick)
            return
        end
        local candidate = _findOpenedAfterReplace(inv, originalItem) or originalItem
        if _isSealed(candidate) == false then
            print("[DNA] Open complete, proceeding to drink")
            local argItem = _itemForDrinkAction(candidate)
            ISInventoryPaneContextMenu.onDrinkFluid(argItem, portion, playerObj)
            Events.OnPlayerUpdate.Remove(tick)
            return
        end
        if tries >= (triesMax or 180) then
            print("[DNA] Open wait timed out")
            Events.OnPlayerUpdate.Remove(tick)
        end
    end
    Events.OnPlayerUpdate.Add(tick)
end
