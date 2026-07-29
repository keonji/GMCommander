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

  spellEdit = W:EditBox(parent, "ID заклинания", function(text)
    local id = tonumber(text)
    if id then
      ns.Run("learn " .. id .. " all")
      ns.Print("Изучено заклинание " .. id .. " (все ранги).")
    else
      ns.Print("Введите числовой ID.")
    end
  end)
  spellEdit:SetPoint("TOPLEFT", pad, -afterBulk - 18)
  spellEdit:SetWidth(140)

  local unlearnBtn = W:Button(parent, {
    text = "Забыть", width = 90, height = 24,
    tip = "Убрать заклинание",
    tipBody = "Команда: .unlearn <id>",
    onClick = function()
      local id = tonumber(spellEdit._edit:GetText())
      if id then
        ns.Run("unlearn " .. id)
        ns.Print("Забыто заклинание " .. id .. ".")
      else
        ns.Print("Введите числовой ID.")
      end
    end,
  })
  unlearnBtn:SetPoint("TOPLEFT", pad + 146, -afterBulk - 18)

  local lookupBtn = W:Button(parent, {
    text = "Найти по названию", width = 150, height = 24,
    tip = "Поиск заклинания в базе",
    tipBody = "Команда: .lookup spell <текст>\nОтвет придёт в чат.",
    onClick = function()
      local t = spellEdit._edit:GetText()
      if t ~= "" and not tonumber(t) then
        ns.Run("lookup spell " .. t)
      else
        ns.Print("Введите часть названия заклинания, не ID.")
      end
    end,
  })
  lookupBtn:SetPoint("TOPLEFT", pad + 242, -afterBulk - 18)

  ------------------------------------------------------------- навыки
  local skills = T:Text(parent, "Навыки", 11, T.color.accent)
  skills:SetPoint("BOTTOMLEFT", pad, 46)

  local maxAll = W:Button(parent, {
    text = "Все навыки на максимум", width = 190, height = 24,
    tip = "Поднять изученные навыки до потолка уровня",
    tipBody = "Команда: .maxskill",
    onClick = function() ns.Run("maxskill") end,
  })
  maxAll:SetPoint("BOTTOMLEFT", pad, 16)

  local talents = W:Button(parent, {
    text = "Сбросить таланты", width = 150, height = 24,
    tip = "Обнулить распределение талантов",
    tipBody = "Команда: .reset talents",
    onClick = function() ns.Run("reset talents") end,
  })
  talents:SetPoint("BOTTOMLEFT", pad + 196, 16)

  local spellsReset = W:Button(parent, {
    text = "Сбросить заклинания", width = 160, height = 24,
    tip = "Вернуть книгу заклинаний к стартовой",
    tipBody = "Команда: .reset spells",
    onClick = function() ns.Run("reset spells") end,
  })
  spellsReset:SetPoint("BOTTOMLEFT", pad + 352, 16)
end

function page.refresh() end

ns.RegisterPage(page)
