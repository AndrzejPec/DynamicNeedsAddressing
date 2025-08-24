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
    if raw == nil then return 0, nil end
    local eff = decrease_is_negative and -raw or raw
    if eff < 0 then return 0, eff end
    return eff, eff
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
    local h, hraw = dna_eff_from_raw(r.hunger,   DNA.HUNGER_DECREASE_IS_NEGATIVE)
    local t, traw = dna_eff_from_raw(r.thirst,   DNA.THIRST_DECREASE_IS_NEGATIVE)
    local b, braw = dna_eff_from_raw(r.boredom,  DNA.BOREDOM_DECREASE_IS_NEGATIVE)
    local u, uraw = dna_eff_from_raw(r.unhappy,  DNA.UNHAPPY_DECREASE_IS_NEGATIVE)
    local s, sraw = dna_eff_from_raw(r.stress,   DNA.STRESS_DECREASE_IS_NEGATIVE)
    local f, fraw = dna_eff_from_raw(r.fatigue,  DNA.FATIGUE_DECREASE_IS_NEGATIVE)
    local e, eraw = dna_eff_from_raw(r.endurance, not DNA.ENDURANCE_INCREASE_IS_POSITIVE)
    return {
        hunger=h, thirst=t, boredom=b, unhappy=u, stress=s, fatigue=f, endurance=e,
        _raw={h=hraw, t=traw, b=braw, u=uraw, s=sraw, f=fraw, e=eraw}
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

function Debug_PrintAllEdibles(playerObj)
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
        print(string.format(
            " - %s [%s] | hunger=%s eff=%s pts=%d | thirst=%s eff=%s pts=%d | boredom=%s eff=%s pts=%d | unhappy=%s eff=%s pts=%d | stress=%s eff=%s pts=%d | fatigue=%s eff=%s pts=%d | endurance=%s eff=%s pts=%d",
            it:getName(),
            it:getFullType(),
            tostring(raw.hunger), tostring(eff.hunger), pts.hunger or 0,
            tostring(raw.thirst), tostring(eff.thirst), pts.thirst or 0,
            tostring(raw.boredom), tostring(eff.boredom), pts.boredom or 0,
            tostring(raw.unhappy), tostring(eff.unhappy), pts.unhappy or 0,
            tostring(raw.stress), tostring(eff.stress), pts.stress or 0,
            tostring(raw.fatigue), tostring(eff.fatigue), pts.fatigue or 0,
            tostring(raw.endurance), tostring(eff.endurance), pts.endurance or 0
        ))
    end
end
