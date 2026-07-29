-- UI_Main.lua — каркас окна: шапка, вкладки, подвал, переключение страниц.
local ADDON, ns = ...
local T, W = ns.Theme, ns.W

local UI = { pages = {} }
ns.UI = UI

local WIDTH, HEIGHT = 460, 520
local HEADER, TABBAR, FOOTER = 34, 28, 26

--- Страницы регистрируются модулями UI_*.lua до вызова BuildUI.
function ns.RegisterPage(def)
  table.insert(UI.pages, def)
end

local function styleCloseButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(20); b:SetHeight(20)
  local x = T:Text(b, "×", 18, T.color.textDim)
  x:SetPoint("CENTER", 0, 1)
  b:SetScript("OnEnter", function() x:SetTextColor(T.unpackc(T.color.bad)) end)
  b:SetScript("OnLeave", function() x:SetTextColor(T.unpackc(T.color.textDim)) end)
  b:SetScript("OnClick", function() parent:Hide() end)
  return b
end

function ns.BuildUI()
  local f = CreateFrame("Frame", "GMCommanderFrame", UIParent)
  UI.frame = f
  f:SetWidth(WIDTH); f:SetHeight(HEIGHT)
  f:SetPoint(ns.db.point, UIParent, ns.db.point, ns.db.x, ns.db.y)
  f:SetScale(ns.db.scale)
  f:SetAlpha(ns.db.alpha)
  f:SetFrameStrata("MEDIUM")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:Hide()

  T:Fill(f, T.color.bg)
  T:Border(f, T.color.border)

  -- Esc закрывает окно.
  tinsert(UISpecialFrames, "GMCommanderFrame")

  ---------------------------------------------------------------- шапка
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT")
  head:SetHeight(HEADER)
  T:Fill(head, T.color.bgLight)

  local accentLine = head:CreateTexture(nil, "ARTWORK")
  accentLine:SetTexture("Interface\\Buttons\\WHITE8X8")
  accentLine:SetVertexColor(T.unpackc(T.color.accent))
  accentLine:SetHeight(2)
  accentLine:SetPoint("BOTTOMLEFT"); accentLine:SetPoint("BOTTOMRIGHT")

  local title = T:Text(head, "|cffffcc00GM|rCommander", 14)
  title:SetPoint("LEFT", 12, 0)

  local close = styleCloseButton(f)
  close:SetPoint("TOPRIGHT", -6, -7)

  -- Перетаскивание за шапку.
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function()
    if not ns.db.locked then f:StartMoving() end
  end)
  head:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, _, x, y = f:GetPoint()
    ns.db.point, ns.db.x, ns.db.y = point, x, y
  end)

  ------------------------------------------------------------- вкладки
  local tabbar = CreateFrame("Frame", nil, f)
  tabbar:SetPoint("TOPLEFT", 0, -HEADER)
  tabbar:SetPoint("TOPRIGHT", 0, -HEADER)
  tabbar:SetHeight(TABBAR)
  T:Fill(tabbar, T.color.panel)

  UI.tabs = {}

  --------------------------------------------------------------- подвал
  local foot = CreateFrame("Frame", nil, f)
  foot:SetPoint("BOTTOMLEFT"); foot:SetPoint("BOTTOMRIGHT")
  foot:SetHeight(FOOTER)
  T:Fill(foot, T.color.panel)

  local footLine = foot:CreateTexture(nil, "ARTWORK")
  footLine:SetTexture("Interface\\Buttons\\WHITE8X8")
  footLine:SetVertexColor(T.unpackc(T.color.border))
  footLine:SetHeight(1)
  footLine:SetPoint("TOPLEFT"); footLine:SetPoint("TOPRIGHT")

  UI.status = T:Text(foot, "", 10, T.color.textDim)
  UI.status:SetPoint("LEFT", 10, 0)

  UI.queueText = T:Text(foot, "", 10, T.color.accent)
  UI.queueText:SetPoint("RIGHT", -10, 0)

  ------------------------------------------------- контейнер страниц
  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", 0, -(HEADER + TABBAR))
  body:SetPoint("BOTTOMRIGHT", 0, FOOTER)
  UI.body = body

  -- Сначала контейнеры и кнопки вкладок целиком, и только потом
  -- содержимое страниц: ошибка в одной странице не должна оставить
  -- UI.tabs недозаполненным и уронить Select.
  local x = 4
  for i, page in ipairs(UI.pages) do
    local container = CreateFrame("Frame", nil, body)
    container:SetAllPoints(body)
    container:Hide()
    page.frame = container

    local tab = CreateFrame("Button", nil, tabbar)
    tab:SetHeight(TABBAR - 6)
    local label = T:Text(tab, page.title, 11, T.color.textDim)
    label:SetPoint("CENTER")
    tab:SetWidth(label:GetStringWidth() + 22)
    tab:SetPoint("LEFT", x, 0)
    x = x + tab:GetWidth() + 2

    local underline = tab:CreateTexture(nil, "OVERLAY")
    underline:SetTexture("Interface\\Buttons\\WHITE8X8")
    underline:SetVertexColor(T.unpackc(T.color.accent))
    underline:SetHeight(2)
    underline:SetPoint("BOTTOMLEFT", 4, -1)
    underline:SetPoint("BOTTOMRIGHT", -4, -1)
    underline:Hide()

    tab._label, tab._underline, tab._index = label, underline, i
    tab:SetScript("OnClick", function() UI:Select(i) end)
    tab:SetScript("OnEnter", function(self)
      if UI.current ~= i then label:SetTextColor(T.unpackc(T.color.text)) end
    end)
    tab:SetScript("OnLeave", function(self)
      if UI.current ~= i then label:SetTextColor(T.unpackc(T.color.textDim)) end
    end)

    UI.tabs[i] = tab
  end

  for _, page in ipairs(UI.pages) do
    page.build(page.frame)
  end

  UI:Select(ns.db.lastTab or 1)
end

function UI:Select(index)
  if not self.pages[index] then index = 1 end
  self.current = index
  ns.db.lastTab = index

  for i, page in ipairs(self.pages) do
    local on = (i == index)
    page.frame:SetShown(on)
    local tab = self.tabs[i]
    tab._underline:SetShown(on)
    tab._label:SetTextColor(T.unpackc(on and T.color.accent or T.color.textDim))
  end

  self:Refresh()
end

function UI:Refresh()
  if not self.frame or not self.frame:IsShown() then return end

  local page = self.pages[self.current]
  if page and page.refresh then page.refresh() end

  -- В подвале — на кого подействует следующая команда. Это самая
  -- частая причина ошибки: нажать «Убить», забыв про выделение.
  local target = ns.TargetName()
  if target and ns.db.applyToTarget then
    self.status:SetText("Цель: |cffffcc00" .. target .. "|r")
  elseif target then
    self.status:SetText("Цель: " .. target ..
      " |cff808080(команды идут вам — переключите в настройках)|r")
  else
    self.status:SetText("Цель не выбрана — команды применятся к вам")
  end

  self:RefreshQueue()
end

function UI:RefreshQueue()
  if not self.queueText then return end
  local n = ns.Comm:Pending()
  self.queueText:SetText(n > 0 and ("в очереди: " .. n) or "")
end

-- Подвал обновляем раз в секунду: смена цели ловится событием, но
-- очередь команд убывает сама по себе.
do
  local ticker, acc = CreateFrame("Frame"), 0
  ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.5 then return end
    acc = 0
    if UI.frame and UI.frame:IsShown() then
      UI:RefreshQueue()
    end
  end)
end

-- Смена выделения меняет адресата команд — обновляем сразу.
do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_TARGET_CHANGED")
  ev:SetScript("OnEvent", function() UI:Refresh() end)
end

function ns.ToggleUI()
  local f = ns.UI.frame
  if not f then return end
  if f:IsShown() then f:Hide() else f:Show(); ns.UI:Refresh() end
end
