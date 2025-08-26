DNA = DNA or {}

DNA.HUNGER_DECREASE_IS_NEGATIVE = true
DNA.THIRST_DECREASE_IS_NEGATIVE = true
DNA.BOREDOM_DECREASE_IS_NEGATIVE = true
DNA.UNHAPPY_DECREASE_IS_NEGATIVE = true
DNA.STRESS_DECREASE_IS_NEGATIVE = true
DNA.FATIGUE_DECREASE_IS_NEGATIVE = true
DNA.ENDURANCE_INCREASE_IS_POSITIVE = true

local function dna_raw_delta(it, getter)
    if not it or not getter then return nil end
    local f = it[getter]
    if not f then return nil end
    local ok, v = pcall(function() return f(it) end)
    if not ok then return nil end
    return v
end

local function dna_eff_from_raw(raw, decrease_is_negative)
    if raw == nil then return 0, 0 end
    local signed = decrease_is_negative and -raw or raw
    local eff = signed > 0 and signed or 0
    return eff, signed
end

function DNA.needRaw(it)
    local h = dna_raw_delta(it, "getHungerChange")
    local t = dna_raw_delta(it, "getThirstChange")
    local b = dna_raw_delta(it, "getBoredomChange")
    local u = dna_raw_delta(it, "getUnhappyChange")
    local s = dna_raw_delta(it, "getStressChange")
    local f = dna_raw_delta(it, "getFatigueChange")
    local e = dna_raw_delta(it, "getEnduranceChange")
    return { hunger=h, thirst=t, boredom=b, unhappy=u, stress=s, fatigue=f, endurance=e }
end

function DNA.needEff(it)
    local r = DNA.needRaw(it)
    local h, hsgn = dna_eff_from_raw(r.hunger,   DNA.HUNGER_DECREASE_IS_NEGATIVE)
    local t, tsgn = dna_eff_from_raw(r.thirst,   DNA.THIRST_DECREASE_IS_NEGATIVE)
    local b, bsgn = dna_eff_from_raw(r.boredom,  DNA.BOREDOM_DECREASE_IS_NEGATIVE)
    local u, usgn = dna_eff_from_raw(r.unhappy,  DNA.UNHAPPY_DECREASE_IS_NEGATIVE)
    local s, ssgn = dna_eff_from_raw(r.stress,   DNA.STRESS_DECREASE_IS_NEGATIVE)
    local f, fsgn = dna_eff_from_raw(r.fatigue,  DNA.FATIGUE_DECREASE_IS_NEGATIVE)
    local e, esgn = dna_eff_from_raw(r.endurance, not DNA.ENDURANCE_INCREASE_IS_POSITIVE)
    return {
        hunger=h, thirst=t, boredom=b, unhappy=u, stress=s, fatigue=f, endurance=e,
        _signed={h=hsgn, t=tsgn, b=bsgn, u=usgn, s=ssgn, f=fsgn, e=esgn}
    }
end

function DNA.needPoints(it)
    local e = DNA.needEff(it)
    local function P(x) return math.floor((x or 0) * 100 + 0.5) end
    return {
        hunger=P(e.hunger),
        thirst=P(e.thirst),
        boredom=P(e.boredom),
        unhappy=P(e.unhappy),
        stress=P(e.stress),
        fatigue=P(e.fatigue),
        endurance=P(e.endurance),
    }
end

function DNA.pointsForNeed(it, needKey)
    local pts = DNA.needPoints(it)
    return (pts and pts[needKey]) or 0
end

local function dna_stat(player, key)
    if not player then return nil end
    local st = player.getStats and player:getStats() or nil
    if not st then return nil end
    if key == "hunger"   and st.getHunger   then return st:getHunger() end
    if key == "thirst"   and st.getThirst   then return st:getThirst() end
    if key == "boredom"  and st.getBoredom  then return st:getBoredom() end
    if key == "unhappy"  and st.getUnhappyness then return st:getUnhappyness() end
    if key == "stress"   and st.getStress   then return st:getStress() end
    if key == "fatigue"  and st.getFatigue  then return st:getFatigue() end
    if key == "endurance" and st.getEndurance then return 1 - st:getEndurance() end
    return nil
end

function DNA.currentNeedPoints(player, needKey)
    local v = dna_stat(player or getPlayer(), needKey)
    if not v then return 0 end
    return math.floor(v * 100 + 0.5)
end

function DNA.parenLabel(player, it, needKey)
    local have = DNA.pointsForNeed(it, needKey)
    local need = DNA.currentNeedPoints(player or getPlayer(), needKey)
    if have >= need and need > 0 then return "" end
    if have <= 0 then return "" end
    return string.format("(%d)", have)
end

function DNA.isStale(it)
    if not it then return false end
    local fresh = it.isFresh and it:isFresh() or nil
    if fresh ~= nil then
        local rotten = it.isRotten and it:isRotten() or false
        return (fresh == false) and (not rotten)
    end
    local age = it.getAge and it:getAge() or nil
    local off = it.getOffAge and it:getOffAge() or nil
    if age and off then return age > 0 and age < off end
    return false
end

function Debug_printAllEdibles(playerObj)
    playerObj = playerObj or getPlayer()
    if not playerObj then print("[DynamicNeedsAddressing] [Edibles] No player") return end
    local inv = playerObj:getInventory()
    local foods = DNA.collectEdiblesFrom(inv)
    print(string.format("[Edibles] found %d edible items", foods:size()))
    for i = 0, foods:size() - 1 do
        local it = foods:get(i)
        local raw = DNA.needRaw(it)
        local eff = DNA.needEff(it)
        local pts = DNA.needPoints(it)
        local spice = it.isSpice and it:isSpice() or false
        local poison = it.isPoison and it:isPoison() or false
        local frozen = it.isFrozen and it:isFrozen() or false
        local stale = DNA.isStale(it)
        print(string.format(
            " - %s [%s] | hunger=%s eff=%s pts=%d | thirst=%s eff=%s pts=%d | boredom=%s eff=%s pts=%d | unhappy=%s eff=%s pts=%d | stress=%s eff=%s pts=%d | fatigue=%s eff=%s pts=%d | endurance=%s eff=%s pts=%d | spice=%s | poison=%s | frozen=%s | stale=%s",
            it:getName(),
            it:getFullType(),
            tostring(raw.hunger), tostring(eff.hunger), pts.hunger or 0,
            tostring(raw.thirst), tostring(eff.thirst), pts.thirst or 0,
            tostring(raw.boredom), tostring(eff.boredom), pts.boredom or 0,
            tostring(raw.unhappy), tostring(eff.unhappy), pts.unhappy or 0,
            tostring(raw.stress), tostring(eff.stress), pts.stress or 0,
            tostring(raw.fatigue), tostring(eff.fatigue), pts.fatigue or 0,
            tostring(raw.endurance), tostring(eff.endurance), pts.endurance or 0,
            tostring(spice),
            tostring(poison),
            tostring(frozen),
            tostring(stale)
        ))
    end
end
