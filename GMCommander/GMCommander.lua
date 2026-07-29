-- GMCommander.lua — точка входа и высокоуровневые действия.
local ADDON, ns = ...

ns.name = ADDON
local PREFIX = "|cffffcc00GM|r|cffffffffCommander|r: "

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

--------------------------------------------------------------------------
-- Цель команды
--------------------------------------------------------------------------

--- Имя выделенного игрока, если он выделен и это игрок.
function ns.TargetName()
  if UnitExists("target") and UnitIsPlayer("target") then
    return UnitName("target")
  end
  return nil
end

--- Кого затронет команда — для подписи в интерфейсе.
function ns.TargetLabel()
  local t = ns.TargetName()
  if t and ns.db.applyToTarget then return t end
  return UnitName("player")
end

--------------------------------------------------------------------------
-- Отправка с защитой
--------------------------------------------------------------------------

local function guard(cmd, run)
  if not (ns.db and ns.db.confirmRisky) then run(); return end
  for pattern, why in pairs(ns.RISKY) do
    if cmd:find(pattern, 1, true) then
      ns.W:Confirm("Подтверждение", "«." .. cmd .. "»\n\n" .. why, run)
      return
    end
  end
  run()
end

--- Выполнить GM-команду.
function ns.Run(cmd)
  guard(cmd, function() ns.Comm:Send(cmd) end)
end

--------------------------------------------------------------------------
-- Действия
--------------------------------------------------------------------------

--- Выполнить запись из ns.ACTIONS с учётом переключателей и цели.
function ns.DoAction(action)
  -- Переключатели: помним состояние и шлём противоположное.
  if action.toggle then
    local on = not ns.db.toggles[action.toggle]
    ns.db.toggles[action.toggle] = on
    ns.Run(action.toggle .. (on and " on" or " off"))
    ns.Print(action.ru .. ": " .. (on and "|cff5cd95cвключено|r" or "|cffff5555выключено|r"))
    -- Один и тот же режим есть и в окне, и на полосе — обновляем оба,
    -- иначе подсветка в них разойдётся.
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    if ns.Bar and ns.Bar.Refresh then ns.Bar:Refresh() end
    return
  end

  -- Команды, работающие по выделению: сервер сам применит их к цели,
  -- если она есть. Отдельного аргумента не нужно — предупреждаем
  -- только про `die`, где отсутствие цели означает смерть игрока.
  if action.cmd == "die" and not ns.TargetName() then
    ns.W:Confirm("Убить себя?",
      "Цель не выделена — команда убьёт вашего персонажа.",
      function() ns.Comm:Send("die") end)
    return
  end

  ns.Run(action.cmd)
end

--------------------------------------------------------------------------
-- Деньги, уровни
--------------------------------------------------------------------------

function ns.GiveMoney(copper)
  ns.Run("modify money " .. copper)
  ns.Print(string.format("Выдано %d золота игроку %s.",
    math.floor(copper / 10000), ns.TargetLabel()))
end

--- Изменить уровень. `.character levelup` принимает ПРИРОСТ, а не
--- итоговый уровень (cs_character.cpp:775).
function ns.AddLevels(delta)
  ns.Run("character levelup " .. delta)
  ns.Print(string.format("%s: уровень %+d.", ns.TargetLabel(), delta))
end

--- Довести до конкретного уровня: считаем прирост сами.
function ns.SetLevel(target)
  local unit = (ns.TargetName() and ns.db.applyToTarget) and "target" or "player"
  local now = UnitLevel(unit) or 1
  local delta = target - now
  if delta == 0 then
    ns.Print("Уровень уже " .. target .. ".")
    return
  end
  ns.AddLevels(delta)
end

--------------------------------------------------------------------------
-- Предметы
--------------------------------------------------------------------------

--- Выдать предмет. Количество необязательно.
function ns.GiveItem(itemId, count)
  count = count or 1
  ns.Run("additem " .. itemId .. " " .. count)

  -- Пополняем историю, чтобы часто выдаваемое было под рукой.
  local hist = ns.db.history
  for i, h in ipairs(hist) do
    if h.id == itemId then table.remove(hist, i) break end
  end
  table.insert(hist, 1, { id = itemId, count = count })
  while #hist > 12 do table.remove(hist) end
end

function ns.GiveKit(kit)
  for _, it in ipairs(kit.items) do
    ns.GiveItem(it.id, it.count)
  end
  ns.Print("Выдан набор «" .. kit.ru .. "».")
end

--- Достать ID предмета из ссылки вида |Hitem:6948:0:...|h[Камень]|h
function ns.ParseItemLink(text)
  if not text then return nil end
  local id = text:match("|Hitem:(%d+)")
  if id then return tonumber(id) end
  -- Может быть введён и просто числом.
  if text:match("^%s*%d+%s*$") then return tonumber(text) end
  return nil
end

--------------------------------------------------------------------------
-- Обучение
--------------------------------------------------------------------------

--- Выучить профессию со всеми рангами.
-- `all` в конце заставляет ядро пройти всю цепочку рангов
-- (cs_learn.cpp:70), поэтому достаточно ID ранга «ученик».
function ns.LearnProfession(prof)
  ns.Run("learn " .. prof.spell .. " all")
  ns.Print("Изучено: " .. prof.ru .. " (все ранги).")
end

--------------------------------------------------------------------------
-- Телепортация
--------------------------------------------------------------------------

function ns.Teleport(entry)
  ns.Run("teleport " .. entry.tele)
  ns.Print("Телепорт: " .. (entry.ru or entry.tele))
end

--- К цели квеста аддон переместить не может — координат целей у
--- клиента нет. Зато сервер умеет прыгать к тому, кто квест выдаёт
--- и кто его принимает (cs_go.cpp:520, HandleGoQuestCommand).
function ns.GoQuest(questId, which)
  ns.Run("go quest " .. which .. " " .. questId)
  ns.Print(string.format("Прыжок к %s квеста %d.",
    which == "starter" and "выдающему" or "принимающему", questId))
end

--- Избранные точки.
function ns.IsFavorite(tele)
  for _, f in ipairs(ns.db.favorites) do
    if f.tele == tele then return true end
  end
  return false
end

function ns.ToggleFavorite(entry)
  for i, f in ipairs(ns.db.favorites) do
    if f.tele == entry.tele then
      table.remove(ns.db.favorites, i)
      if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
      return false
    end
  end
  table.insert(ns.db.favorites, { tele = entry.tele, ru = entry.ru })
  if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
  return true
end

--------------------------------------------------------------------------
-- Служебное
--------------------------------------------------------------------------

function ns.OnQueueChanged()
  if ns.UI and ns.UI.RefreshQueue then ns.UI:RefreshQueue() end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    ns.InitDB()
  elseif event == "PLAYER_LOGIN" then
    ns.BuildUI()
    ns.BuildBar()
    ns.Print("готов. |cffffcc00/gm|r — панель, |cffffcc00/gm help|r — команды.")
  end
end)
