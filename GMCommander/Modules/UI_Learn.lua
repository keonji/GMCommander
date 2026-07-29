-- UI_Learn.lua — вкладка «Обучение»: профессии, заклинания, таланты.
local ADDON, ns = ...
local T, W = ns.Theme, ns.W

local page = { title = "Обучение" }
local spellEdit

function page.build(parent)
  local pad = 14

  --------------------------------------------------------- профессии
  local h1 = T:Text(parent, "Профессии", 11, T.color.accent)
  h1:SetPoint("TOPLEFT", pad, -pad)

  local note = T:Text(parent,
    "Изучается сразу со всеми рангами, до грандмастера.", 9, T.color.textDim)
  note:SetPoint("TOPLEFT", pad, -pad - 16)

  local perRow, bw, bh = 3, 140, 24
  for i, p in ipairs(ns.PROFESSIONS) do
    local b = W:Button(parent, {
      text = p.ru, width = bw, height = bh, icon = p.icon, fontSize = 10,
      tip = p.ru,
      tipBody = "Команда: .learn " .. p.spell .. " all\n\n" ..
                "Суффикс all проходит всю цепочку рангов.",
      onClick = function() ns.LearnProfession(p) end,
    })
    local row = math.floor((i - 1) / perRow)
    local col = (i - 1) % perRow
    b:SetPoint("TOPLEFT", pad + col * (bw + 5), -pad - 34 - row * (bh + 4))
  end

  local profRows = math.ceil(#ns.PROFESSIONS / perRow)
  local afterProf = pad + 34 + profRows * (bh + 4) + 12

  ------------------------------------------------------------ массово
  local h2 = T:Text(parent, "Массовое обучение", 11, T.color.accent)
  h2:SetPoint("TOPLEFT", pad, -afterProf)

  perRow, bw = 2, 210
  for i, l in ipairs(ns.LEARN_BULK) do
    local b = W:Button(parent, {
      text = l.ru, width = bw, height = 26, fontSize = 10,
      tip = l.ru, tipBody = l.desc .. "\n\nКоманда: ." .. l.cmd,
      onClick = function() ns.Run(l.cmd) end,
    })
    local row = math.floor((i - 1) / perRow)
    local col = (i - 1) % perRow
    b:SetPoint("TOPLEFT", pad + col * (bw + 6), -afterProf - 18 - row * 30)
  end

  local bulkRows = math.ceil(#ns.LEARN_BULK / perRow)
  local afterBulk = afterProf + 18 + bulkRows * 30 + 12

  ------------------------------------------------- отдельное заклинание
  local h3 = T:Text(parent, "Отдельное заклинание", 11, T.color.accent)
  h3:SetPoint("TOPLEFT", pad, -afterBulk)

  -- Ширины подобраны под окно 460: доступно 460 - 2*14 = 432 пикселя.
  -- Строка ниже занимает 130 + 4 + 88 + 4 + 140 = 366, с запасом.
  local function readSpellId()
    return ns.ParseSpellInput(spellEdit._edit:GetText())
  end

  spellEdit = W:EditBox(parent, "ID заклинания", function(text)
    local id = ns.ParseSpellInput(text)
    if id then
      ns.Run("learn " .. id .. " all")
      ns.Print("Изучено заклинание " .. id .. " (все ранги).")
    else
      ns.Print("Введите числовой ID заклинания.")
    end
  end)
  spellEdit:SetPoint("TOPLEFT", pad, -afterBulk - 18)
  spellEdit:SetWidth(130)

  local learnBtn = W:Button(parent, {
    text = "Выучить", width = 88, height = 24, accent = true,
    tip = "Выучить заклинание со всеми рангами",
    tipBody = "Команда: .learn <id> all",
    onClick = function()
      local id = readSpellId()
      if id then
        ns.Run("learn " .. id .. " all")
        ns.Print("Изучено заклинание " .. id .. " (все ранги).")
      else
        ns.Print("Введите числовой ID заклинания.")
      end
    end,
  })
  learnBtn:SetPoint("TOPLEFT", pad + 134, -afterBulk - 18)

  local unlearnBtn = W:Button(parent, {
    text = "Забыть", width = 88, height = 24,
    tip = "Убрать заклинание",
    tipBody = "Команда: .unlearn <id>",
    onClick = function()
      local id = readSpellId()
      if id then
        ns.Run("unlearn " .. id)
        ns.Print("Забыто заклинание " .. id .. ".")
      else
        ns.Print("Введите числовой ID заклинания.")
      end
    end,
  })
  unlearnBtn:SetPoint("TOPLEFT", pad + 226, -afterBulk - 18)

  -- Поиск отдельной строкой: в один ряд с полем и двумя кнопками он
  -- не помещался и вылезал за край окна.
  local searchEdit = W:EditBox(parent, "часть названия заклинания", function(text)
    if text ~= "" then ns.Run("lookup spell " .. text) end
  end)
  searchEdit:SetPoint("TOPLEFT", pad, -afterBulk - 46)
  searchEdit:SetWidth(300)

  local lookupBtn = W:Button(parent, {
    text = "Искать", width = 88, height = 24,
    tip = "Поиск заклинания в базе сервера",
    tipBody = "Команда: .lookup spell <текст>\n\n" ..
              "Ответ придёт в чат списком с ID.",
    onClick = function()
      local t = searchEdit._edit:GetText()
      if t ~= "" then ns.Run("lookup spell " .. t)
      else ns.Print("Введите часть названия заклинания.") end
    end,
  })
  lookupBtn:SetPoint("TOPLEFT", pad + 306, -afterBulk - 46)

  ------------------------------------------------------------- навыки
  -- Три кнопки в один ряд давали 512 пикселей при доступных 432 и
  -- вылезали за окно. Разложены в два ряда.
  local skills = T:Text(parent, "Навыки и сбросы", 11, T.color.accent)
  skills:SetPoint("BOTTOMLEFT", pad, 74)

  local maxAll = W:Button(parent, {
    text = "Все навыки на максимум", width = 210, height = 24,
    tip = "Поднять изученные навыки до потолка уровня",
    tipBody = "Команда: .maxskill",
    onClick = function() ns.Run("maxskill") end,
  })
  maxAll:SetPoint("BOTTOMLEFT", pad, 44)

  local talents = W:Button(parent, {
    text = "Сбросить таланты", width = 210, height = 24,
    tip = "Обнулить распределение талантов",
    tipBody = "Команда: .reset talents",
    onClick = function() ns.Run("reset talents") end,
  })
  talents:SetPoint("BOTTOMLEFT", pad + 216, 44)

  local spellsReset = W:Button(parent, {
    text = "Сбросить заклинания", width = 210, height = 24,
    tip = "Вернуть книгу заклинаний к стартовой",
    tipBody = "Команда: .reset spells",
    onClick = function() ns.Run("reset spells") end,
  })
  spellsReset:SetPoint("BOTTOMLEFT", pad, 16)

  local statsReset = W:Button(parent, {
    text = "Сбросить характеристики", width = 210, height = 24,
    tip = "Пересчитать базовые характеристики",
    tipBody = "Команда: .reset stats",
    onClick = function() ns.Run("reset stats") end,
  })
  statsReset:SetPoint("BOTTOMLEFT", pad + 216, 16)
end

function page.refresh() end

ns.RegisterPage(page)
