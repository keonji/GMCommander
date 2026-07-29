-- UI_Player.lua — вкладка «Игрок»: состояние, деньги, уровни.
local ADDON, ns = ...
local T, W = ns.Theme, ns.W

local page = { title = "Игрок" }
local actionButtons, levelEdit, moneyEdit, infoLine = {}, nil, nil, nil

function page.build(parent)
  local pad = 14

  ---------------------------------------------------------- состояние
  local h1 = T:Text(parent, "Состояние и режимы", 11, T.color.accent)
  h1:SetPoint("TOPLEFT", pad, -pad)

  local perRow, bw, bh, gap = 3, 140, 26
  for i, a in ipairs(ns.ACTIONS) do
    local b = W:Button(parent, {
      text = a.ru, width = bw, height = bh, icon = a.icon,
      fontSize = 10,
      tip = a.ru, tipBody = a.desc .. "\n\nКоманда: ." .. (a.toggle or a.cmd),
      onClick = function() ns.DoAction(a) end,
    })
    local row = math.floor((i - 1) / perRow)
    local col = (i - 1) % perRow
    b:SetPoint("TOPLEFT", pad + col * (bw + 5), -pad - 18 - row * (bh + 4))
    actionButtons[i] = { button = b, action = a }
  end

  local rows = math.ceil(#ns.ACTIONS / perRow)
  local afterActions = pad + 18 + rows * (bh + 4) + 12

  ------------------------------------------------------------- деньги
  local h2 = T:Text(parent, "Золото", 11, T.color.accent)
  h2:SetPoint("TOPLEFT", pad, -afterActions)

  local x = 0
  for _, m in ipairs(ns.MONEY_STEPS) do
    local b = W:Button(parent, {
      text = m.ru, width = 68, height = 24,
      tip = "Выдать " .. m.ru,
      tipBody = "Команда: .modify money " .. m.copper,
      onClick = function() ns.GiveMoney(m.copper) end,
    })
    b:SetPoint("TOPLEFT", pad + x, -afterActions - 18)
    x = x + 72
  end

  moneyEdit = W:EditBox(parent, "своё, золотом", function(text)
    local g = tonumber(text)
    if not g then ns.Print("Введите число."); return end
    ns.GiveMoney(math.floor(g * 10000))
  end)
  moneyEdit:SetPoint("TOPLEFT", pad + x, -afterActions - 18)
  moneyEdit:SetWidth(110)

  ------------------------------------------------------------ уровни
  local afterMoney = afterActions + 52
  local h3 = T:Text(parent, "Уровень", 11, T.color.accent)
  h3:SetPoint("TOPLEFT", pad, -afterMoney)

  x = 0
  for _, d in ipairs(ns.LEVEL_STEPS) do
    local label = (d > 0 and "+" or "") .. d
    local b = W:Button(parent, {
      text = label, width = 52, height = 24,
      tip = "Изменить уровень на " .. label,
      tipBody = "Команда: .character levelup " .. d ..
                "\n\nСервер принимает прирост, а не итоговый уровень.",
      onClick = function() ns.AddLevels(d) end,
    })
    b:SetPoint("TOPLEFT", pad + x, -afterMoney - 18)
    x = x + 56
  end

  local b80 = W:Button(parent, {
    text = "До " .. ns.MAX_LEVEL, width = 68, height = 24, accent = true,
    tip = "Поднять до максимального уровня",
    onClick = function() ns.SetLevel(ns.MAX_LEVEL) end,
  })
  b80:SetPoint("TOPLEFT", pad + x, -afterMoney - 18)
  x = x + 72

  levelEdit = W:EditBox(parent, "точный уровень", function(text)
    local lvl = tonumber(text)
    if not lvl or lvl < 1 or lvl > ns.MAX_LEVEL then
      ns.Print("Уровень должен быть от 1 до " .. ns.MAX_LEVEL .. ".")
      return
    end
    ns.SetLevel(lvl)
  end)
  levelEdit:SetPoint("TOPLEFT", pad + x, -afterMoney - 18)
  levelEdit:SetWidth(110)

  -- Об опыте: команды нет, и это стоит объяснить прямо в интерфейсе,
  -- иначе её будут искать.
  local xpNote = T:Text(parent,
    "Опыт напрямую выдать нельзя: такой команды в AzerothCore нет — " ..
    "только уровни целиком.", 9, T.color.textDim)
  xpNote:SetPoint("TOPLEFT", pad, -afterMoney - 46)
  xpNote:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  xpNote:SetJustifyH("LEFT")

  --------------------------------------------------------- своя команда
  local free = T:Text(parent, "Произвольная команда", 11, T.color.accent)
  free:SetPoint("BOTTOMLEFT", pad, 44)

  local eb = W:EditBox(parent, "без точки: modify speed 3", function(text)
    ns.Run(text)
  end)
  eb:SetPoint("BOTTOMLEFT", pad, 18)
  eb:SetPoint("BOTTOMRIGHT", -pad, 18)

  infoLine = T:Text(parent, "", 9, T.color.textDim)
  infoLine:SetPoint("BOTTOMLEFT", pad, 4)
end

function page.refresh()
  -- Подсвечиваем включённые режимы.
  for _, rec in ipairs(actionButtons) do
    if rec.action.toggle then
      rec.button:SetAccent(ns.db.toggles[rec.action.toggle] == true)
    end
  end

  if infoLine then
    local unit = (ns.TargetName() and ns.db.applyToTarget) and "target" or "player"
    infoLine:SetText(string.format("Текущий уровень: %d", UnitLevel(unit) or 0))
  end
end

ns.RegisterPage(page)
