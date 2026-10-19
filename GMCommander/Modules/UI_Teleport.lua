-- UI_Teleport.lua — вкладка «Телепорт»: города, подземелья, рейды, квесты.
local ADDON, ns = ...
local T, W = ns.Theme, ns.W

local page = { title = "Телепорт" }

-- Квестов в списке нет: прыжки по квестам — это ввод ID, а не выбор
-- из перечня, поэтому им отведена постоянная панель внизу вкладки.
local MODES = { "Избранное", "Города", "Подземелья", "Рейды" }
local mode = 2
local modeButtons, scroll, content, rows = {}, nil, nil, {}
local questEdit, searchEdit
local searchText = ""

local ROW_H = 22

--------------------------------------------------------------------------

local function setMode(i)
  mode = i
  for j, b in pairs(modeButtons) do
    b:SetAccent(j == i)
  end
  page.refresh()
end

--- Строка списка: название, подпись справа, звёздочка избранного.
local function getRow(i)
  local r = rows[i]
  if r then return r end

  r = CreateFrame("Button", nil, content)
  r:SetHeight(ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_H + 2))
  r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
  T:Fill(r, T.color.bgLight)
  T:Hover(r)

  r.star = CreateFrame("Button", nil, r)
  r.star:SetWidth(18); r.star:SetHeight(18)
  r.star:SetPoint("LEFT", 3, 0)
  r.starText = T:Text(r.star, "*", 14, T.color.textDim)
  r.starText:SetPoint("CENTER", 0, -1)

  r.name = T:Text(r, "", 11)
  r.name:SetPoint("LEFT", 24, 0)

  r.note = T:Text(r, "", 9, T.color.textDim)
  r.note:SetPoint("RIGHT", -8, 0)

  rows[i] = r
  return r
end

--- Заголовок-разделитель внутри списка.
local function getHeader(i)
  local r = getRow(i)
  r.star:Hide()
  r.note:SetText("")
  r._isHeader = true
  return r
end

--------------------------------------------------------------------------

--- Собрать плоский список того, что показываем в текущем режиме.
local function buildList()
  local list = {}

  local function matches(entry)
    if searchText == "" then return true end
    local q = searchText:lower()
    return (entry.ru or ""):lower():find(q, 1, true) ~= nil
        or (entry.tele or ""):lower():find(q, 1, true) ~= nil
  end

  local function addGroup(groups)
    for _, g in ipairs(groups) do
      local matched = {}
      for _, e in ipairs(g.list) do
        if matches(e) then table.insert(matched, e) end
      end
      if #matched > 0 then
        table.insert(list, { header = g.era })
        for _, e in ipairs(matched) do table.insert(list, { entry = e }) end
      end
    end
  end

  if mode == 1 then
    if #ns.db.favorites == 0 then
      table.insert(list, { header = "Пусто — отметьте точки звёздочкой" })
    else
      for _, f in ipairs(ns.db.favorites) do
        if matches(f) then table.insert(list, { entry = f }) end
      end
    end

  elseif mode == 2 then
    local sides = {
      { key = "A", ru = "Альянс" },
      { key = "H", ru = "Орда" },
      { key = "N", ru = "Нейтральные" },
    }
    for _, s in ipairs(sides) do
      local matched = {}
      for _, c in ipairs(ns.TELE_CITIES) do
        if c.side == s.key and matches(c) then table.insert(matched, c) end
      end
      if #matched > 0 then
        table.insert(list, { header = s.ru })
        for _, c in ipairs(matched) do table.insert(list, { entry = c }) end
      end
    end

  elseif mode == 3 then
    addGroup(ns.TELE_DUNGEONS)

  elseif mode == 4 then
    addGroup(ns.TELE_RAIDS)
  end

  return list
end

--------------------------------------------------------------------------

function page.build(parent)
  local pad = 14

  -- Переключатель разделов.
  local x = 0
  for i, name in ipairs(MODES) do
    local b = W:Button(parent, {
      text = name, width = 84, height = 22,
      onClick = function() setMode(i) end,
    })
    b:SetPoint("TOPLEFT", pad + x, -pad)
    modeButtons[i] = b
    x = x + 86
  end

  -- Поиск.
  searchEdit = W:EditBox(parent, "поиск по названию", function() end)
  searchEdit:SetPoint("TOPLEFT", pad, -pad - 28)
  searchEdit:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  searchEdit._edit:SetScript("OnTextChanged", function(self)
    searchText = self:GetText() or ""
    page.refresh()
  end)

  -- Список.
  scroll, content = W:ScrollArea(parent)
  scroll:SetPoint("TOPLEFT", pad, -pad - 56)
  scroll:SetPoint("BOTTOMRIGHT", -pad, 98)
  content:SetWidth(430)

  ----------------------------------------------------------- квесты
  local qHead = T:Text(parent, "Квесты", 11, T.color.accent)
  qHead:SetPoint("BOTTOMLEFT", pad, 78)

  local qNote = T:Text(parent,
    "Координаты целей квеста недоступны. Можно прыгнуть\n" ..
    "к тому, кто выдаёт или принимает квест.", 9, T.color.textDim)
  qNote:SetPoint("BOTTOMLEFT", pad, 44)
  qNote:SetHeight(26)
  qNote:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  qNote:SetJustifyH("LEFT")

  questEdit = W:EditBox(parent, "ID квеста", function(text)
    local id = tonumber(text)
    if id then ns.GoQuest(id, "starter") end
  end)
  questEdit:SetPoint("BOTTOMLEFT", pad, 12)
  questEdit:SetWidth(80)

  local toStarter = W:Button(parent, {
    text = "К квестгиверу", width = 120, height = 24,
    tip = "Прыжок к тому, кто выдаёт квест",
    tipBody = "Команда: .go quest starter <id>",
    onClick = function()
      local id = tonumber(questEdit._edit:GetText())
      if id then ns.GoQuest(id, "starter")
      else ns.Print("Введите числовой ID квеста.") end
    end,
  })
  toStarter:SetPoint("BOTTOMLEFT", pad + 86, 12)

  local toEnder = W:Button(parent, {
    text = "К принимающему", width = 136, height = 24,
    tip = "Прыжок к тому, кто квест принимает",
    tipBody = "Команда: .go quest ender <id>",
    onClick = function()
      local id = tonumber(questEdit._edit:GetText())
      if id then ns.GoQuest(id, "ender")
      else ns.Print("Введите числовой ID квеста.") end
    end,
  })
  toEnder:SetPoint("BOTTOMLEFT", pad + 212, 12)

  local recall = W:Button(parent, {
    text = "Назад", width = 60, height = 24,
    tip = "Вернуться на прежнее место",
    tipBody = "Команда: .recall — возвращает туда, откуда вы телепортировались.",
    onClick = function() ns.Run("recall") end,
  })
  recall:SetPoint("BOTTOMRIGHT", -pad, 12)

  setMode(2)
end

--------------------------------------------------------------------------

function page.refresh()
  if not content then return end

  local list = buildList()

  for i, item in ipairs(list) do
    local r = getRow(i)
    r:Show()
    r._isHeader = item.header ~= nil

    if item.header then
      r.star:Hide()
      r.name:SetText("|cff808080" .. item.header .. "|r")
      r.name:SetPoint("LEFT", 6, 0)
      r.note:SetText("")
      r:SetScript("OnClick", nil)
      r:EnableMouse(false)
      r:SetAlpha(0.9)
    else
      local e = item.entry
      r.star:Show()
      r:EnableMouse(true)
      r:SetAlpha(1)
      r.name:SetPoint("LEFT", 24, 0)
      r.name:SetText(e.ru or e.tele)
      r.note:SetText(e.lvl or e.size or "")

      local fav = ns.IsFavorite(e.tele)
      r.starText:SetTextColor(T.unpackc(fav and T.color.accent or T.color.textDim))

      r.star:SetScript("OnClick", function()
        ns.ToggleFavorite(e)
      end)
      W.Tooltip(r.star, fav and "Убрать из избранного" or "В избранное")

      r:SetScript("OnClick", function() ns.Teleport(e) end)
      W.Tooltip(r, e.ru or e.tele, "Команда: .teleport " .. e.tele)
    end
  end

  for i = #list + 1, #rows do rows[i]:Hide() end
  content:SetHeight(math.max(1, #list * (ROW_H + 2)))
end

ns.RegisterPage(page)
