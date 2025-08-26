-- -- media/lua/client/SSHover.lua

-- -- Żeby nie ładować drugi raz przy hotloadach
-- if _G.__SSHover_Loaded then
--     print("[SSHover] już załadowany – pomijam.")
--     return
-- end
-- _G.__SSHover_Loaded = true

-- print("[SSHover] Start – instaluję helper i hook na klik LPM dla SSBar (poziome paski).")

-- ----------------------------------------------------------------------
-- -- KROK 1: helper – znajdź który POZIOMY pasek jest pod myszą
-- ----------------------------------------------------------------------
-- _G.SSHover = _G.SSHover or {}

-- function SSHover_getHorizontalBarAt(panel, mx, my)
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

-- print("[SSHover] KROK 1: helper załadowany.")

-- ----------------------------------------------------------------------
-- -- KROK 2: hook na ISPanel:onMouseUp – tylko dla paneli typu SSBar
-- -- (nie ruszamy nic w oryginalnym modzie)
-- ----------------------------------------------------------------------
-- if not _G.__SSHover_ISPanelPatched then
--     _G.__SSHover_ISPanelPatched = true

--     local _orig_onMouseUp = ISPanel.onMouseUp
--     function ISPanel:onMouseUp(x, y)
--         -- tylko nasze słupki
--         if self and self.Type == "SSBar" then
--             local idx = select(1, SSHover_getHorizontalBarAt(self))
--             if idx and self.barInfo and self.barInfo[idx] then
--                 local title = tostring(self.barInfo[idx][1] or "")
--                 local name  = tostring(self.barInfo[idx][6] or "")
--                 print(string.format("[SSHover] CLICK HORIZONTAL #%d  name=%s  title=%s", idx, name, title))
--             end
--         end
--         return _orig_onMouseUp(self, x, y)
--     end

--     print("[SSHover] KROK 2: ISPanel:onMouseUp spatchowany dla SSBar (click-logger).")
-- else
--     print("[SSHover] KROK 2: patch już był aktywny.")
-- end

-- ----------------------------------------------------------------------
-- -- (OPCJONALNIE) KROK 3: tooltip przy HOVERZE nad poziomym paskiem
-- -- Jeżeli chcesz też podgląd najechanego paska jak w pionie – odkomentuj.
-- ----------------------------------------------------------------------

-- --[[
-- if not _G.__SSHover_PrerenPatched then
--     _G.__SSHover_PrerenPatched = true

--     local _orig_prerender = ISPanel.prerender
--     function ISPanel:prerender()
--         _orig_prerender(self)
--         if self and self.Type == "SSBar" and self.config and not self.config.isVertical then
--             local idx, lx, ly = SSHover_getHorizontalBarAt(self)
--             if idx and self.barInfo and self.barInfo[idx] then
--                 local title = tostring(self.barInfo[idx][1] or "")
--                 local value = tostring(self.barInfo[idx][2] or "-")
--                 -- prosty tooltip nad myszą
--                 local mx, my = getMouseX() - self.x, getMouseY() - self.y
--                 self:drawTextWithShadow(title .. " : " .. value, mx - 5, my - (self.config.barWidth or 20) - 5)
--                 if self.__lastHoverIdx ~= idx then
--                     self.__lastHoverIdx = idx
--                     print(string.format("[SSHover] HOVER #%d  title=%s", idx, title))
--                 end
--             else
--                 self.__lastHoverIdx = nil
--             end
--         end
--     end

--     print("[SSHover] KROK 3: tooltip hover (poziom) – WŁĄCZONY.")
-- else
--     print("[SSHover] KROK 3: tooltip hover już był włączony.")
-- end
-- ]]

-- print("[SSHover] Gotowe. Klikaj LPM w poziome paski – w konsoli polecą name/title.")
