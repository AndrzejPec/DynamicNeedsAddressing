if _G.__SSHover_AddToUIPatched then return end
_G.__SSHover_AddToUIPatched = true

DNA.msg("[SSHover] start: tryb 'per-instancja' przez hook ISPanel:addToUIManager()")

----------------------------------------------------------------------
-- 1) Helper do wykrywania H-bara (poziomy) – jak wcześniej
----------------------------------------------------------------------
local function getHorizontalBarAt(panel, mx, my)
    if not panel or not panel.config or panel.config.isVertical then return nil end
    local px, py, pw, ph = panel.x, panel.y, panel.width, panel.height
    mx = mx or getMouseX(); my = my or getMouseY()
    if mx <= px or my <= py or mx >= px + pw or my >= py + ph then return nil end
    local x = mx - px
    local y = my - py
    local barWidth = panel.config.barWidth or 20
    local firstY, stride = 3, barWidth + 3
    local idx  = math.floor((y - firstY) / stride) + 1
    local barY = firstY + (idx - 1) * stride
    if idx >= 1 and panel.barInfo and idx <= #panel.barInfo
       and y >= barY and y <= barY + barWidth then
        return idx, x, y
    end
    return nil
end

----------------------------------------------------------------------
-- 2) Rozpoznawanie SSBar „po cechach” (działa na prawdziwej instancji – tabeli Lua)
----------------------------------------------------------------------
local function looksLikeSSBar(o)
    if type(o) ~= "table" then return false end
    if not o.barInfo then return false end
    if not o.config then return false end
    if type(o.prepareBarInfo) ~= "function" then return false end
    if type(o.renderHBars) ~= "function" and type(o.renderVBars) ~= "function" then return false end
    return true
end

----------------------------------------------------------------------
-- 3) Patch TYLKO TEJ instancji (bez ruszania klasy/wanilii)
----------------------------------------------------------------------
local function patchInstance(panel)
    if panel.__sshover_patched then return false end
    local orig_onMouseUp = panel.onMouseUp
    panel.__sshover_orig_onMouseUp = orig_onMouseUp

    panel.onMouseUp = function(self, x, y)
        local idx, bx, by = getHorizontalBarAt(self)
        if idx and self.barInfo and self.barInfo[idx] then
            local name  = tostring(self.barInfo[idx][6] or "")
            local title = tostring(self.barInfo[idx][1] or "")
            DNA.msg(string.format("[SSHover] CLICK HORIZONTAL #%d  name=%s  title=%s", idx, name, title))
            if name == "hunger" then
                local d = rawget(_G, "DNA")
                if d and type(d.openEdiblesMenu) == "function" then
                    d.openEdiblesMenu(getPlayer(), getMouseX() + 5, getMouseY() - 5)
                else
                    DNA.msg("[SSHover] DNA.openEdiblesMenu is not available")
                end
            end
            
        end
        if type(self.__sshover_orig_onMouseUp) == "function" then
            return self.__sshover_orig_onMouseUp(self, x, y)
        end
    end
    
    panel.__sshover_patched = true
    DNA.msg("[SSHover] spatchowano instancję SSBar przez addToUIManager().")
    return true
end

----------------------------------------------------------------------
-- 4) Hook: ISPanel:addToUIManager – wąsko i bezpiecznie
----------------------------------------------------------------------
local _orig_addToUI = ISPanel.addToUIManager
function ISPanel:addToUIManager(...)
    -- TUTAJ self to prawdziwa TABELA Lua (SSBar też), więc „po cechach” zadziała.
    if looksLikeSSBar(self) then
        patchInstance(self)
    end
    return _orig_addToUI(self, ...)
end 

DNA.msg("[SSHover] ISPanel:addToUIManager zhookowany – będę patchować SSBar per-instancja.")

----------------------------------------------------------------------
-- 5) Na wypadek, że SSBar już był w UI zanim włączył się nasz mod:
--    spróbujmy złapać istniejące instancje przez ISUIElement.instances (jeśli dostępne),
--    albo delikatnie zawołaj 'refresh' dodając/odejmując z UI (opcjonalne).
----------------------------------------------------------------------
-- Prosta próba: jeśli masz globalny wskaźnik do panelu (czasem mod go trzyma), można go tu podać ręcznie.
-- Zazwyczaj jednak wystarczy hook z pkt 4 i wszystko „łapie się” przy najbliższym dodaniu/odświeżeniu UI.
