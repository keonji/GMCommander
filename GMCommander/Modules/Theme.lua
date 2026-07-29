-- Theme.lua — палитра и общие приёмы отрисовки.
-- Всё оформление собрано здесь, чтобы менять вид в одном месте.

local ADDON, ns = ...

local T = {}
ns.Theme = T

T.font      = "Fonts\\FRIZQT__.TTF"
T.fontRu    = "Fonts\\ARIALN.TTF"  -- узкий, лучше держит кириллицу в плотных списках

T.color = {
  bg       = { 0.05, 0.06, 0.09, 0.94 },
  bgLight  = { 0.10, 0.12, 0.16, 0.90 },
  panel    = { 0.08, 0.09, 0.13, 0.85 },
  border   = { 0.22, 0.26, 0.34, 1.00 },
  accent   = { 0.00, 0.80, 1.00, 1.00 },
  accentDk = { 0.00, 0.42, 0.58, 1.00 },
  text     = { 0.92, 0.94, 0.98, 1.00 },
  textDim  = { 0.58, 0.62, 0.70, 1.00 },
  good     = { 0.35, 0.85, 0.45, 1.00 },
  warn     = { 1.00, 0.78, 0.20, 1.00 },
  bad      = { 0.95, 0.35, 0.35, 1.00 },
}

-- Цвета классов: RAID_CLASS_COLORS есть в 3.3.5a, но подстрахуемся.
T.classColor = setmetatable({}, {
  __index = function(_, token)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if c then return { c.r, c.g, c.b, 1 } end
    return { 0.7, 0.7, 0.7, 1 }
  end
})

local function unpackc(c) return c[1], c[2], c[3], c[4] end
T.unpackc = unpackc

--- Escape-последовательность цвета класса для вставки в текст: "|cffRRGGBB".
-- Округление обязательно: string.format("%x") не принимает дробные числа.
function T:ColorCode(classToken)
  local c = self.classColor[classToken]
  return string.format("|cff%02x%02x%02x",
    math.floor(c[1] * 255 + 0.5),
    math.floor(c[2] * 255 + 0.5),
    math.floor(c[3] * 255 + 0.5))
end

--- Плоская заливка как текстура — базовый строительный блок.
function T:Fill(frame, color, layer)
  local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
  tex:SetTexture("Interface\\Buttons\\WHITE8X8")
  tex:SetVertexColor(unpackc(color))
  tex:SetAllPoints(frame)
  return tex
end

--- Тонкая рамка в 1 пиксель — четыре текстуры, без BackdropTemplate
--- (в 3.3.5a его нет, а SetBackdrop даёт мыльные углы).
function T:Border(frame, color, inset)
  inset = inset or 0
  local c = color or self.color.border
  local t = {}
  local sides = {
    { "TOPLEFT", "TOPRIGHT", 0, 1 },
    { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
    { "TOPLEFT", "BOTTOMLEFT", 1, 0 },
    { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 },
  }
  for i, s in ipairs(sides) do
    local tex = frame:CreateTexture(nil, "BORDER")
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetVertexColor(unpackc(c))
    tex:SetPoint(s[1], frame, s[1], inset, -inset)
    tex:SetPoint(s[2], frame, s[2], -inset, inset)
    if s[3] == 1 then tex:SetWidth(1) else tex:SetHeight(1) end
    t[i] = tex
  end
  frame._border = t
  return t
end

function T:SetBorderColor(frame, color)
  if not frame._border then return end
  for _, tex in ipairs(frame._border) do tex:SetVertexColor(unpackc(color)) end
end

--- Панель: заливка + рамка одним вызовом.
function T:Panel(parent, color, borderColor)
  local f = CreateFrame("Frame", nil, parent)
  self:Fill(f, color or self.color.panel)
  self:Border(f, borderColor)
  return f
end

--- Текст с настройками по умолчанию.
function T:Text(parent, text, size, color, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(self.font, size or 12, flags)
  fs:SetTextColor(unpackc(color or self.color.text))
  fs:SetText(text or "")
  return fs
end

--- Горизонтальный разделитель, гаснущий к краям.
function T:Divider(parent)
  local tex = parent:CreateTexture(nil, "ARTWORK")
  tex:SetTexture("Interface\\Buttons\\WHITE8X8")
  tex:SetHeight(1)
  tex:SetVertexColor(unpackc(self.color.border))
  tex:SetAlpha(0.6)
  return tex
end

--- Мягкая подсветка при наведении.
function T:Hover(frame, color)
  local hl = frame:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture("Interface\\Buttons\\WHITE8X8")
  hl:SetVertexColor(unpackc(color or { 1, 1, 1, 0.08 }))
  hl:SetAllPoints(frame)
  return hl
end
