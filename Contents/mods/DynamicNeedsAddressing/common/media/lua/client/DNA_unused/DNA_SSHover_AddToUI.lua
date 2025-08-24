-- -- media/lua/client/SSHover_AddToUI.lua

-- if _G.__SSHover_Loaded then return end
-- _G.__SSHover_Loaded = true

-- print("[SSHover] start: per-instancja hook na SSBar przez addToUIManager + chaining")

-- ----------------------------------------------------------------------
-- -- 0) Opcje
-- ----------------------------------------------------------------------
-- local ENABLE_RMB_LOG   = false   -- jeśli chcesz też logować PPM, ustaw true
-- local ENABLE_HOVER_TT  = false   -- jeśli chcesz tooltip na hover, ustaw true

-- ----------------------------------------------------------------------
-- -- 1) Helper do wykrywania H-bara (poziomy)
-- ----------------------------------------------------------------------
-- local function getHorizontalBarAt(panel, mx, my)
--     if not panel or not panel.config or panel.config.isVertical then return nil end
--     local px, py, pw, ph = panel.x, panel.y, panel.width, panel.height
--     mx = mx or getMouseX(); my = my or getMouseY()
--     if mx <= px or my <= py or mx >= px + pw or my >= py + ph then return nil end

--     local x = mx - px
--     local y = my - py

--     local barWidth = panel.config.barWidth or 20
--     local firstY, stride = 3, barWidth + 3

--     local idx  = math.floor((y - firstY) / stride) + 1
--     local barY = firstY + (idx - 1) * stride

--     if idx >= 1 and panel.barInfo and idx <= #panel.barInfo
--        and y >= barY and y <= barY + barWidth then
--         return idx, x, y
--     end
--     return nil
-- end

-- ----------------------------------------------------------------------
-- -- 2) Rozpoznawanie SSBar „po cechach” (na prawdziwej instancji - tabela Lua)
-- ----------------------------------------------------------------------
-- local function looksLikeSSBar(o)
--     if type(o) ~= "table" then return false end
--     if not o.barInfo then return false end
--     if not o.config then return false end
--     if type(o.prepareBarInfo) ~= "function" then return false end
--     if type(o.renderHBars) ~= "function" and type(o.renderVBars) ~= "function" then return false end
--     return true
-- end

-- ----------------------------------------------------------------------
-- -- 3) Patch TYLKO TEJ instancji (bez ruszania klasy/wanilii)
-- ----------------------------------------------------------------------
-- local function patchInstance(panel)
--     if panel.__sshover_patched then return false end

--     -- LPM
--     local orig_onMouseUp = panel.onMouseUp
--     panel.__sshover_orig_onMouseUp = orig_onMouseUp
--     panel.onMouseUp = function(self, x, y)
--         local idx = select(1, getHorizontalBarAt(self))
--         if idx and self.barInfo and self.barInfo[idx] then
--             local title = tostring(self.barInfo[idx][1] or "")
--             local name  = tostring(self.barInfo[idx][6] or "")
--             print(string.format("[SSHover] CLICK HORIZONTAL #%d  name=%s  title=%s", idx, name, title))
--         end
--         if type(orig_onMouseUp) == "function" then
--             return orig_onMouseUp(self, x, y)
--         end
--     end

--     -- PPM opcjonalnie
--     if ENABLE_RMB_LOG then
--         local orig_onRightMouseUp = panel.onRightMouseUp
--         panel.__sshover_orig_onRightMouseUp = orig_onRightMouseUp
--         panel.onRightMouseUp = function(self, x, y)
--             local idx = select(1, getHorizontalBarAt(self))
--             if idx and self.barInfo and self.barInfo[idx] then
--                 local title = tostring(self.barInfo[idx][1] or "")
--                 local name  = tostring(self.barInfo[idx][6] or "")
--                 print(string.format("[SSHover] RIGHT-CLICK HORIZONTAL #%d  name=%s  title=%s", idx, name, title))
--             end
--             if type(orig_onRightMouseUp) == "function" then
--                 return orig_onRightMouseUp(self, x, y)
--             end
--         end
--     end

--     -- tooltip na hover opcjonalnie
--     if ENABLE_HOVER_TT and not panel.__sshover_prerender_patched then
--         panel.__sshover_prerender_patched = true
--         local orig_prerender = panel.prerender
--         panel.prerender = function(self)
--             if type(orig_prerender) == "function" then orig_prerender(self) end
--             if self.config and not self.config.isVertical then
--                 local idx = select(1, getHorizontalBarAt(self))
--                 if idx and self.barInfo and self.barInfo[idx] then
--                     local title = tostring(self.barInfo[idx][1] or "")
--                     local value = tostring(self.barInfo[idx][2] or "-")
--                     local mx, my = getMouseX() - self.x, getMouseY() - self.y
--                     self:drawTextWithShadow(title .. " : " .. value,
--                         mx - 5, my - (self.config.barWidth or 20) - 5)
--                 end
--             end
--         end
--     end

--     panel.__sshover_patched = true
--     print("[SSHover] spatchowano instancję SSBar przez addToUIManager().")
--     return true
-- end

-- ----------------------------------------------------------------------
-- -- 4) Kooperacyjny wrapper z „samołańcuszkowaniem”
-- ----------------------------------------------------------------------
-- local function wrap_method(tbl, key)
--     local prev = tbl[key]
--     if type(prev) == "function" and prev.__sshover_wrapped then
--         return
--     end

--     local function wrapped(self, ...)
--         if looksLikeSSBar(self) then
--             patchInstance(self)
--         end
--         if type(prev) == "function" then
--             return prev(self, ...)
--         end
--     end
--     wrapped.__sshover_wrapped = true
--     wrapped.__sshover_prev = prev

--     tbl[key] = wrapped
-- end

-- -- Pierwsze owinięcie
-- wrap_method(ISPanel, "addToUIManager")
-- print("[SSHover] ISPanel:addToUIManager zhookowany – patch per-instancja ready.")

-- -- Self-heal: jeśli ktoś nadpisze później, owijamy go też (zachowujemy łańcuszek)
-- if not _G.__SSHover_selfHeal then
--     _G.__SSHover_selfHeal = true
--     local last = ISPanel.addToUIManager
--     Events.OnTick.Add(function()
--         if ISPanel.addToUIManager ~= last and not (ISPanel.addToUIManager.__sshover_wrapped) then
--             wrap_method(ISPanel, "addToUIManager")
--             last = ISPanel.addToUIManager
--             print("[SSHover] re-wrap addToUIManager (chaining) – koegzystencja zachowana.")
--         end
--     end)
-- end

-- ----------------------------------------------------------------------
-- -- 5) Dodatkowy „łapacz” – gdy SSBar był dodany zanim włączył się nasz plik
-- -- Skanujemy bieżące UI i jeśli któraś instancja jest już tabelą Lua i wygląda jak SSBar,
-- -- patchujemy od razu.
-- ----------------------------------------------------------------------
-- local function tryPatchExisting()
--     local list = UIManager.getUI()
--     if not list then return end
--     local n = list:size() - 1
--     local hit = 0
--     for i = 0, n do
--         local ui = list:get(i)
--         if looksLikeSSBar(ui) and patchInstance(ui) then
--             hit = hit + 1
--         end
--         -- dzieci – czasem SSBar bywa childem innego panelu
--         if type(ui)=="table" and ui.children then
--             for j=1,#ui.children do
--                 local ch = ui.children[j]
--                 if looksLikeSSBar(ch) and patchInstance(ch) then
--                     hit = hit + 1
--                 end
--             end
--         end
--     end
--     if hit > 0 then
--         print(string.format("[SSHover] tryPatchExisting: spatchowano %d istniejących instancji.", hit))
--     end
-- end

-- Events.OnGameStart.Add(function()
--     -- spróbuj złapać już istniejące
--     tryPatchExisting()
--     -- przez chwilę agresywnie łap nowo dodawane panele na starcie
--     local ticks = 120
--     Events.OnTick.Add(function()
--         if ticks <= 0 then return end
--         ticks = ticks - 1
--         tryPatchExisting()
--     end)
-- end)

-- print("[SSHover] gotowe – klikaj LPM w poziome paski, będzie log z name/title.")
