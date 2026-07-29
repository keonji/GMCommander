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

--- Есть ли вообще выделенная цель — игрок или NPC.
-- Важно различать: `.die` и `.respawn` работают по любому юниту, а
-- `.summon` и `.character levelup` — только по игроку.
function ns.HasTarget()
  return UnitExists("target") and true or false
end

--- Выделенная цель — игрок?
function ns.TargetIsPlayer()
  return UnitExists("target") and UnitIsPlayer("target") and true or false
end

--- Имя выделенного игрока. Для NPC возвращает nil: команды вроде
--- `.summon` принимают только имена персонажей.
function ns.TargetName()
  if ns.TargetIsPlayer() then
    return UnitName("target")
  end
  return nil
end

--- Имя любой цели, включая NPC — только для показа в интерфейсе.
function ns.TargetDisplayName()
  if UnitExists("target") then
    return UnitName("target"), ns.TargetIsPlayer()
  end
  return nil, false
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

  -- Команды с обязательным выделением. Сервер в этом случае отвечает
  -- лишь строкой в чат, поэтому предупреждаем сами — иначе нажатие
  -- выглядит как «ничего не произошло».
  --
  -- Тип цели важен: `.summon` не работает по NPC, `.respawn` — по
  -- игроку, а `.die` принимает и то, и другое.
  local need = action.needsTarget
  if need then
    local okTarget
    if need == "player" then
      okTarget = ns.TargetIsPlayer()
    elseif need == "creature" then
      okTarget = ns.HasTarget() and not ns.TargetIsPlayer()
    else
      okTarget = ns.HasTarget()
    end

    if not okTarget then
      local what = (need == "creature" and "существо")
                or (need == "player" and "игрока")
                or "цель"
      ns.Print("|cffffcc00" .. action.ru .. "|r: сначала выделите " .. what .. ".")
      return
    end
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
-- Скорость
--------------------------------------------------------------------------

--- `.modify speed N` меняет бег, полёт и плавание разом
--- (cs_modify.cpp:415). Допустимо от 0.1 до 50.
function ns.SetSpeed(value)
  if not value or value < ns.SPEED_MIN or value > ns.SPEED_MAX then
    ns.Print(string.format("Скорость должна быть от %s до %s.",
      ns.SPEED_MIN, ns.SPEED_MAX))
    return
  end
  ns.Run("modify speed " .. value)
  ns.Print(string.format("Скорость %s: x%s", ns.TargetLabel(), value))
end

--------------------------------------------------------------------------
-- Квесты
--------------------------------------------------------------------------

--- Действие над квестом: add / complete / reward / remove / status.
function ns.QuestAction(cmd, questId)
  if not questId then
    ns.Print("|cffffcc00Укажите ID квеста|r.")
    return
  end
  ns.Run("quest " .. cmd .. " " .. questId)
end

--- Достать ID квеста из ссылки |Hquest:ID:level|h[Название]|h.
--- Такие ссылки приходят от `.lookup quest` и есть в журнале заданий.
function ns.ParseQuestLink(text)
  if not text then return nil end
  local id = text:match("|Hquest:(%d+)")
  if id then return tonumber(id) end
  if text:match("^%s*%d+%s*$") then return tonumber(text) end
  return nil
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

--------------------------------------------------------------------------
-- Вставка ссылок по Shift+клику
--------------------------------------------------------------------------

-- Клиент 3.3.5a вставляет ссылку в поле ввода через глобальную
-- ChatEdit_InsertLink. Каждая вкладка со своим полем должна в ней
-- поучаствовать, но городить цепочку перехватов на каждое поле —
-- хрупко: порядок загрузки решает, чей обработчик сработает первым,
-- а снять регистрацию потом нельзя. Поэтому перехват один, а поля
-- регистрируются в списке.
local linkTargets = {}

--- Разрешить полю принимать Shift+клик, пока оно в фокусе.
function ns.EnableLinkInsert(editBox)
  table.insert(linkTargets, editBox)
end

do
  local original = ChatEdit_InsertLink
  ChatEdit_InsertLink = function(link)
    if link then
      for _, eb in ipairs(linkTargets) do
        if eb:HasFocus() then
          eb:SetText(link)
          if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
          return true
        end
      end
    end
    if original then return original(link) end
    return false
  end
end

--- Разобрать ввод заклинания: число либо ссылка |Hspell:ID|h,
--- которую даёт Shift+клик по кнопке в книге заклинаний.
function ns.ParseSpellInput(text)
  if not text then return nil end
  local id = text:match("|Hspell:(%d+)") or text:match("|Henchant:(%d+)")
  if id then return tonumber(id) end
  if text:match("^%s*%d+%s*$") then return tonumber(text) end
  return nil
end

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
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    ns.InitDB()
  elseif event == "PLAYER_LOGIN" then
    ns.BuildUI()
    ns.BuildBar()

    -- Questie грузится своим чередом; на PLAYER_LOGIN его модули уже
    -- на месте, но база может инициализироваться позже, поэтому
    -- пробуем ещё раз при входе в мир.
    ns.Questie:Probe()

    ns.Print("готов. |cffffcc00/gm|r — панель, |cffffcc00/gm help|r — команды.")
    if ns.Questie.available then
      ns.Print("база Questie подключена — названия квестов и их предметы доступны.")
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    if not ns.Questie.available then
      ns.Questie:Probe()
    end
  end
end)
