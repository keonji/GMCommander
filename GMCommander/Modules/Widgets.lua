-- Widgets.lua — конструкторы элементов управления.
local ADDON, ns = ...

local T = ns.Theme
local W = {}
ns.W = W

local function tooltip(frame, title, body)
  if not title then return end
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title, 1, 1, 1)
    if body then GameTooltip:AddLine(body, 0.7, 0.75, 0.85, true) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
W.Tooltip = tooltip

--- Кнопка. opts = { text, width, height, onClick, tip, tipBody, accent, icon }
function W:Button(parent, opts)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(opts.width or 100)
  b:SetHeight(opts.height or 24)

  local bg = T:Fill(b, opts.accent and T.color.accentDk or T.color.bgLight)
  T:Border(b)
  T:Hover(b)

  local label
  if opts.icon then
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetTexture(opts.icon)
    ic:SetWidth(16); ic:SetHeight(16)
    ic:SetPoint("LEFT", b, "LEFT", 6, 0)
    -- Иконки WoW имеют рамку по краю; обрезаем её.
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b._icon = ic
    label = T:Text(b, opts.text, opts.fontSize or 11)
    label:SetPoint("LEFT", ic, "RIGHT", 5, 0)
    label:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
  else
    label = T:Text(b, opts.text, opts.fontSize or 11)
    label:SetPoint("CENTER")
  end
  b._label = label
  b._bg = bg

  if opts.onClick then b:SetScript("OnClick", opts.onClick) end
  tooltip(b, opts.tip, opts.tipBody)

  function b:SetLabel(t) label:SetText(t) end
  function b:SetAccent(on)
    bg:SetVertexColor(T.unpackc(on and T.color.accentDk or T.color.bgLight))
  end
  function b:SetEnabledLook(on)
    self:EnableMouse(on)
    label:SetTextColor(T.unpackc(on and T.color.text or T.color.textDim))
    self:SetAlpha(on and 1 or 0.5)
  end
  return b
end

--- Кнопка класса: галочка «участвует в доборе», цветная полоса, счётчик.
-- @param onClick  (classDef, mouseButton) — призыв/роспуск
-- @param onToggle (classDef, enabled) — переключение галочки
function W:ClassButton(parent, classDef, onClick, onToggle)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(134); b:SetHeight(26)
  T:Fill(b, T.color.bgLight)
  T:Border(b)

  local cc = T.classColor[classDef.token]

  -- Галочка слева — отдельная кликабельная зона: нажатие на неё меняет
  -- участие класса в автодоборе, нажатие на остальную кнопку призывает.
  local check = CreateFrame("Button", nil, b)
  check:SetWidth(20); check:SetHeight(24)
  check:SetPoint("LEFT", 1, 0)

  local box = check:CreateTexture(nil, "ARTWORK")
  box:SetTexture("Interface\\Buttons\\WHITE8X8")
  box:SetVertexColor(T.unpackc(T.color.bg))
  box:SetWidth(12); box:SetHeight(12)
  box:SetPoint("CENTER")

  local mark = check:CreateTexture(nil, "OVERLAY")
  mark:SetTexture("Interface\\Buttons\\WHITE8X8")
  mark:SetVertexColor(cc[1], cc[2], cc[3], 1)
  mark:SetWidth(8); mark:SetHeight(8)
  mark:SetPoint("CENTER")

  local stripe = b:CreateTexture(nil, "ARTWORK")
  stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
  stripe:SetVertexColor(cc[1], cc[2], cc[3], 1)
  stripe:SetWidth(2)
  stripe:SetPoint("TOPLEFT", 22, -1)
  stripe:SetPoint("BOTTOMLEFT", 22, 1)

  local name = T:Text(b, classDef.ru, 11)
  name:SetTextColor(cc[1], cc[2], cc[3], 1)
  name:SetPoint("LEFT", b, "LEFT", 29, 0)

  local count = T:Text(b, "", 11, T.color.textDim)
  count:SetPoint("RIGHT", b, "RIGHT", -7, 0)
  b._count = count

  -- Подсветка только правой части, чтобы галочка визуально отделялась.
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture("Interface\\Buttons\\WHITE8X8")
  hl:SetVertexColor(1, 1, 1, 0.08)
  hl:SetPoint("TOPLEFT", 22, -1)
  hl:SetPoint("BOTTOMRIGHT", -1, 1)

  b:SetScript("OnClick", function(self, btn) onClick(classDef, btn) end)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  tooltip(b, classDef.ru,
    "ЛКМ — призвать бота этого класса.\n" ..
    "ПКМ — распустить последнего призванного.\n\n" ..
    "Галочка слева: участвует ли класс в автодоборе и наборе рейда.")

  check:SetScript("OnClick", function()
    b:SetEnabledClass(not b._enabled)
    if onToggle then onToggle(classDef, b._enabled) end
  end)
  tooltip(check, "Участие в автодоборе",
    "Снимите галочку, чтобы этот класс не призывался кнопкой " ..
    "«Добрать» и при наборе рейда.")

  function b:SetCount(n)
    count:SetText(n and n > 0 and ("|cff00ccff" .. n .. "|r") or "")
  end

  function b:SetEnabledClass(on)
    self._enabled = on and true or false
    mark:SetShown(self._enabled)
    name:SetAlpha(self._enabled and 1 or 0.45)
    stripe:SetAlpha(self._enabled and 1 or 0.35)
  end

  b:SetEnabledClass(true)
  return b
end

--- Чекбокс.
function W:Check(parent, label, checked, onToggle, tip)
  local f = CreateFrame("Button", nil, parent)
  f:SetHeight(20)

  local box = CreateFrame("Frame", nil, f)
  box:SetWidth(14); box:SetHeight(14)
  box:SetPoint("LEFT", 0, 0)
  T:Fill(box, T.color.bg)
  T:Border(box)

  local mark = box:CreateTexture(nil, "OVERLAY")
  mark:SetTexture("Interface\\Buttons\\WHITE8X8")
  mark:SetVertexColor(T.unpackc(T.color.accent))
  mark:SetPoint("TOPLEFT", 3, -3)
  mark:SetPoint("BOTTOMRIGHT", -3, 3)
  mark:SetShown(checked and true or false)

  local fs = T:Text(f, label, 11)
  fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
  f:SetWidth(math.max(120, fs:GetStringWidth() + 26))

  f._checked = checked and true or false
  f:SetScript("OnClick", function(self)
    self._checked = not self._checked
    mark:SetShown(self._checked)
    if onToggle then onToggle(self._checked) end
  end)
  tooltip(f, label, tip)
  return f
end

--- Слайдер с подписью значения.
function W:Slider(parent, label, minv, maxv, step, value, onChange, fmt)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetHeight(38)

  local cap = T:Text(holder, label, 11, T.color.textDim)
  cap:SetPoint("TOPLEFT", 0, 0)

  local val = T:Text(holder, "", 11, T.color.accent)
  val:SetPoint("TOPRIGHT", 0, 0)

  local s = CreateFrame("Slider", nil, holder)
  s:SetPoint("TOPLEFT", 0, -16)
  s:SetPoint("TOPRIGHT", 0, -16)
  s:SetHeight(14)
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(minv, maxv)
  s:SetValueStep(step)
  s:SetValue(value)

  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetTexture("Interface\\Buttons\\WHITE8X8")
  track:SetVertexColor(T.unpackc(T.color.bg))
  track:SetHeight(4)
  track:SetPoint("LEFT"); track:SetPoint("RIGHT")

  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
  thumb:SetVertexColor(T.unpackc(T.color.accent))
  thumb:SetWidth(8); thumb:SetHeight(14)
  s:SetThumbTexture(thumb)

  local function render(v)
    val:SetText(fmt and string.format(fmt, v) or tostring(v))
  end
  render(value)

  s:SetScript("OnValueChanged", function(self, v)
    -- Шаг не всегда квантует ровно; округляем сами.
    v = math.floor(v / step + 0.5) * step
    render(v)
    if onChange then onChange(v) end
  end)

  holder._slider = s
  return holder
end

--- Скроллируемый контейнер. Возвращает (scrollFrame, content).
function W:ScrollArea(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local content = CreateFrame("Frame", nil, sf)
  content:SetWidth(1); content:SetHeight(1)
  sf:SetScrollChild(content)

  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    local new = math.min(max, math.max(0, cur - delta * 28))
    self:SetVerticalScroll(new)
  end)

  return sf, content
end

--- Поле ввода одной строкой.
function W:EditBox(parent, placeholder, onEnter)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetHeight(24)
  T:Fill(holder, T.color.bg)
  T:Border(holder)

  local eb = CreateFrame("EditBox", nil, holder)
  eb:SetPoint("TOPLEFT", 6, 0)
  eb:SetPoint("BOTTOMRIGHT", -6, 0)
  eb:SetFontObject("GameFontHighlightSmall")
  eb:SetAutoFocus(false)
  eb:SetTextColor(T.unpackc(T.color.text))

  local ph = T:Text(holder, placeholder or "", 11, T.color.textDim)
  ph:SetPoint("LEFT", 7, 0)

  local function refreshPH()
    ph:SetShown(eb:GetText() == "" and not eb:HasFocus())
  end
  eb:SetScript("OnTextChanged", refreshPH)
  eb:SetScript("OnEditFocusGained", function() ph:Hide(); T:SetBorderColor(holder, T.color.accent) end)
  eb:SetScript("OnEditFocusLost", function() refreshPH(); T:SetBorderColor(holder, T.color.border) end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self)
    local txt = self:GetText()
    if onEnter and txt ~= "" then onEnter(txt) end
    self:SetText("")
    self:ClearFocus()
  end)

  holder._edit = eb
  return holder
end

--- Диалог подтверждения. Используем свой, а не StaticPopup: нужен свой стиль.
function W:Confirm(title, body, onYes)
  local f = ns._confirm
  if not f then
    f = CreateFrame("Frame", "BotCommanderConfirm", UIParent)
    f:SetWidth(330); f:SetHeight(140)
    f:SetPoint("CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    T:Fill(f, T.color.bg)
    T:Border(f, T.color.warn)

    f._title = T:Text(f, "", 13, T.color.warn)
    f._title:SetPoint("TOP", 0, -14)

    f._body = T:Text(f, "", 11)
    f._body:SetPoint("TOPLEFT", 16, -40)
    f._body:SetPoint("TOPRIGHT", -16, -40)
    f._body:SetJustifyH("LEFT")
    f._body:SetJustifyV("TOP")

    f._yes = self:Button(f, { text = "Выполнить", width = 120, accent = true })
    f._yes:SetPoint("BOTTOMLEFT", 16, 14)

    f._no = self:Button(f, { text = "Отмена", width = 120 })
    f._no:SetPoint("BOTTOMRIGHT", -16, 14)
    f._no:SetScript("OnClick", function() f:Hide() end)

    ns._confirm = f
  end

  f._title:SetText(title)
  f._body:SetText(body)
  f._yes:SetScript("OnClick", function()
    f:Hide()
    if onYes then onYes() end
  end)
  f:Show()
end
