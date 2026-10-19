-- Bar.lua — плавающая полоса самых частых действий.
local ADDON, ns = ...
local T, W = ns.Theme, ns.W

local Bar = {}
ns.Bar = Bar

-- Только то, что жмут постоянно. Переключатели подсвечиваются.
local ACTIONS = {
  { cmd = "revive",     ru = "Воскресить", icon = "Interface\\Icons\\Spell_Holy_Resurrection" },
  { cmd = "gm fly on",  ru = "Полёт",      toggle = "gm fly",
    icon = "Interface\\Icons\\Spell_Magic_FeatherFall" },
  { cmd = "cheat god on", ru = "Бессмертие", toggle = "cheat god",
    icon = "Interface\\Icons\\Spell_Holy_DevineAegis" },
  { cmd = "gm on",      ru = "Режим ГМ",   toggle = "gm",
    icon = "Interface\\Icons\\INV_Misc_Rune_06" },
  { cmd = "recall",     ru = "Назад",      icon = "Interface\\Icons\\Spell_Arcane_PortalStormWind" },
  { cmd = "gear repair", ru = "Починить",  icon = "Interface\\Icons\\Trade_BlackSmithing" },

  -- Скорость — не одна команда, а выбор из нескольких. Отдельная
  -- кнопка под каждое значение съела бы половину полосы, поэтому
  -- здесь выпадающий список: одно нажатие открывает, второе выбирает.
  { speed = true, ru = "Скорость", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
}

local SIZE, GAP, PADDING = 30, 3, 4

function ns.BuildBar()
  local f = CreateFrame("Frame", "GMCommanderBar", UIParent)
  Bar.frame = f
  f:SetPoint(ns.db.barPoint, UIParent, ns.db.barPoint, ns.db.barX, ns.db.barY)
  f:SetFrameStrata("MEDIUM")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")

  T:Fill(f, T.color.bg)
  T:Border(f)

  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, _, x, y = self:GetPoint()
    ns.db.barPoint, ns.db.barX, ns.db.barY = p, x, y
  end)

  local logo = CreateFrame("Button", nil, f)
  logo:SetWidth(SIZE); logo:SetHeight(SIZE)
  logo:SetPoint("LEFT", PADDING, 0)
  T:Fill(logo, T.color.accentDk)
  T:Border(logo)
  T:Hover(logo)
  local lt = T:Text(logo, "GM", 11)
  lt:SetPoint("CENTER")
  logo:SetScript("OnClick", ns.ToggleUI)
  W.Tooltip(logo, "GMCommander", "ЛКМ — открыть панель.\nПеретаскивание — переместить полосу.")

  Bar.buttons = {}
  for i, a in ipairs(ACTIONS) do
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(SIZE); b:SetHeight(SIZE)
    b:SetPoint("LEFT", PADDING + i * (SIZE + GAP), 0)
    local bg = T:Fill(b, T.color.bgLight)
    T:Border(b)
    T:Hover(b)

    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetPoint("TOPLEFT", 2, -2)
    ic:SetPoint("BOTTOMRIGHT", -2, 2)
    ic:SetTexture(a.icon)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    if a.speed then
      -- Подпись поверх иконки: множитель виден, не открывая список.
      local sp = T:Text(b, "", 10)
      sp:SetPoint("BOTTOMRIGHT", -1, 1)
      b._speedLabel = sp

      b:SetScript("OnClick", function(self)
        local items = {}
        for i, v in ipairs(ns.SPEED_STEPS) do
          items[i] = {
            text = "x" .. v,
            value = v,
            active = ns.GetSpeed() == v,
            tip = (v == 1 and "Вернуть обычную скорость."
                           or "Ускоряет бег, полёт и плавание разом.") ..
                  "\n\nКоманда: .modify speed " .. v,
          }
        end
        W:Dropdown(self, items, function(item)
          ns.SetSpeed(item.value)
        end, { width = 46, itemHeight = 20 })
      end)

      W.Tooltip(b, a.ru, "Выбор множителя: бег, полёт и плавание разом.")
    else
      b:SetScript("OnClick", function()
        ns.DoAction(a)
        Bar:Refresh()
      end)
      W.Tooltip(b, a.ru, a.toggle and "Переключатель — нажмите ещё раз, чтобы выключить." or nil)
    end

    b._bg, b._action = bg, a
    Bar.buttons[i] = b
  end

  f:SetWidth(PADDING * 2 + (#ACTIONS + 1) * (SIZE + GAP))
  f:SetHeight(SIZE + PADDING * 2)

  f:SetShown(ns.db.bar)
  Bar:Refresh()
end

function Bar:SetShown(v)
  if self.frame then self.frame:SetShown(v) end
end

--- Подсветить включённые режимы.
function Bar:Refresh()
  if not self.buttons then return end
  for _, b in ipairs(self.buttons) do
    local a = b._action
    if a.toggle then
      local on = ns.IsActionOn(a)
      b._bg:SetVertexColor(T.unpackc(on and T.color.accentDk or T.color.bgLight))
    elseif a.speed then
      -- Обычная скорость — состояние по умолчанию, подсвечивать нечего.
      local v = ns.GetSpeed()
      local fast = v ~= 1
      b._bg:SetVertexColor(T.unpackc(fast and T.color.accentDk or T.color.bgLight))
      if b._speedLabel then
        b._speedLabel:SetText(fast and ("x" .. v) or "")
      end
    end
  end
end
