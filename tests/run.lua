-- run.lua — прогон аддона на эмуляции клиента.
--   lua tests/run.lua

package.path = "./tests/?.lua;" .. package.path
local wow = require("wow_stub")

local ROOT = "GMCommander/"
local passed, failed = 0, 0

local function ok(cond, label)
  if cond then
    passed = passed + 1
    print("  \27[32mok\27[0m   " .. label)
  else
    failed = failed + 1
    print("  \27[31mFAIL\27[0m " .. label)
  end
end

local function eq(a, b, label)
  ok(a == b, label .. (a == b and "" or ("  (получено: " .. tostring(a) ..
     ", ожидалось: " .. tostring(b) .. ")")))
end

--- Прогнать очередь до конца и вернуть отправленное.
local function flush()
  wow.sent = {}
  for _ = 1, 80 do
    wow.now = wow.now + 1
    wow.Tick()
  end
  return wow.sent
end

--- Последняя отправленная команда.
local function lastCmd()
  local s = flush()
  return s[#s] and s[#s].text
end

------------------------------------------------------------------ загрузка

local function readTOC(path)
  local files, fh = {}, assert(io.open(path, "r"))
  for raw in fh:lines() do
    local line = raw:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and not line:match("^#") then
      table.insert(files, (line:gsub("\\", "/")))
    end
  end
  fh:close()
  return files
end

local ADDON_NAME = "GMCommander"
local ns = {}

print("\n\27[1mЗагрузка файлов из .toc\27[0m")
for _, rel in ipairs(readTOC(ROOT .. "GMCommander.toc")) do
  local chunk, err = loadfile(ROOT .. rel)
  if not chunk then
    print("  \27[31mFAIL\27[0m " .. rel .. ": " .. tostring(err))
    failed = failed + 1
  else
    local success, rerr = pcall(chunk, ADDON_NAME, ns)
    if success then
      passed = passed + 1
      print("  \27[32mok\27[0m   " .. rel)
    else
      failed = failed + 1
      print("  \27[31mFAIL\27[0m " .. rel .. ": " .. tostring(rerr))
    end
  end
end

------------------------------------------------------------------ события

print("\n\27[1mСобытия загрузки\27[0m")
local s1, e1 = pcall(wow.Fire, "ADDON_LOADED", ADDON_NAME)
ok(s1, "ADDON_LOADED отработал" .. (s1 and "" or ": " .. tostring(e1)))
ok(ns.db ~= nil, "SavedVariables инициализированы")

s1, e1 = pcall(wow.Fire, "PLAYER_LOGIN")
ok(s1, "PLAYER_LOGIN отработал" .. (s1 and "" or ": " .. tostring(e1)))
ok(ns.UI and ns.UI.frame ~= nil, "окно построено")
ok(ns.Bar and ns.Bar.frame ~= nil, "полоса построена")
eq(#ns.UI.pages, 6, "зарегистрировано 6 вкладок")

print("\n\27[1mКнопка закрытия\27[0m")
-- Ищем кнопку по её обработчику: у неё OnClick скрывает главное окно.
-- Раньше кнопка не работала, потому что не имела текстуры (нечему было
-- принимать мышь) и лежала под шапкой, которая перехватывала клики.
do
  local closeBtn = ns.UI.closeButton
  ok(closeBtn ~= nil, "кнопка закрытия доступна как UI.closeButton")
  if closeBtn then
    ns.UI.frame:Show()
    ok(ns.UI.frame:IsShown(), "окно открыто перед проверкой")
    wow.Click(closeBtn)
    ok(not ns.UI.frame:IsShown(), "клик по кнопке закрывает окно")
    ns.UI.frame:Show()
  end
end

print("\n\27[1mПереключение вкладок\27[0m")
ns.UI.frame:Show()
for i, page in ipairs(ns.UI.pages) do
  local s, e = pcall(function() ns.UI:Select(i) end)
  ok(s, "вкладка «" .. page.title .. "» открывается" .. (s and "" or ": " .. tostring(e)))
end

------------------------------------------------------- формат команд

print("\n\27[1mФормат отправки\27[0m")
ns.Comm:Clear()
ns.Run("revive")
eq(ns.Comm:Pending(), 1, "команда встала в очередь")
local sent = flush()
eq(sent[1] and sent[1].text, ".revive", "точка добавлена автоматически")
eq(sent[1] and sent[1].channel, "SAY", "уходит каналом SAY")

-- Троттлинг: две команды не уходят одним кадром.
ns.Comm:Clear()
wow.sent = {}
ns.Run("a"); ns.Run("b")
wow.now = wow.now + 10
wow.Tick()
eq(#wow.sent, 1, "за один кадр уходит только одна команда")
wow.now = wow.now + 10
wow.Tick()
eq(#wow.sent, 2, "вторая уходит после паузы")

-- Защита клиента. В 3.3.5a SendChatMessage для строки, начинающейся с
-- точки, — защищённая функция: вне «hardware event» клиент отвечает
-- «AddOn пытается выполнить защищённое действие». Очередь работает из
-- OnUpdate, где такого контекста нет, поэтому команды обязаны уходить
-- штатной строкой ввода чата (ChatEdit_SendText), как их отправляет
-- сам клиент. Стаб роняет прямой вызов, так что эти проверки поймают
-- возврат к нему.
wow.blocked = 0
ns.Comm:Clear()
ns.Run("revive")
local sProt = flush()
ok(sProt[1] and sProt[1].viaChatBox, "команда уходит через строку ввода чата")
eq(wow.blocked, 0, "прямой защищённый вызов не используется")

-- Шёпот в виде духа идёт тем же путём и с тем же получателем.
wow.world.player.dead = true
ns.Comm:Clear()
ns.Run("revive")
local sProtD = flush()
ok(sProtD[1] and sProtD[1].viaChatBox, "и в виде духа тоже через строку ввода")
eq(sProtD[1] and sProtD[1].to, wow.world.player.name,
   "получатель шёпота передан строке ввода")
eq(wow.blocked, 0, "защищённый вызов не понадобился и мёртвому")
wow.world.player.dead = false

--------------------------------------------- команды в виде духа

print("\n\27[1mКоманды после смерти\27[0m")

-- Живому команда идёт в SAY.
wow.world.player.dead = false
ns.Comm:Clear()
ns.Run("revive")
local s0 = flush()
eq(s0[1] and s0[1].channel, "SAY", "живой отправляет в SAY")
eq(s0[1] and s0[1].to, nil, "получателя нет")

-- Мёртвому клиент запрещает SAY, поэтому уходит шёпот. Серверу канал
-- безразличен: команду он перехватывает по точке до проверки на смерть
-- (ChatHandler.cpp:307 против 376).
wow.world.player.dead = true
ns.Comm:Clear()
ns.Run("revive")
local s1d = flush()
eq(s1d[1] and s1d[1].channel, "WHISPER", "мёртвый отправляет шёпотом")
eq(s1d[1] and s1d[1].to, wow.world.player.name,
   "по умолчанию шёпот самому себе — получатель есть всегда")
eq(s1d[1] and s1d[1].text, ".revive", "текст команды не изменился")

-- Заданное имя используется вместо своего. Команда взята безобидная:
-- у «die» сработал бы диалог подтверждения, и в очередь ничего бы не
-- встало.
ns.db.deadWhisperTarget = "Перекуп"
ns.Comm:Clear()
ns.Run("gear repair")
local s2d = flush()
eq(s2d[1] and s2d[1].to, "Перекуп", "шёпот уходит указанному персонажу")

-- Пустая настройка снова означает «себе».
ns.db.deadWhisperTarget = ""
ns.Comm:Clear()
ns.Run("gear repair")
local s3d = flush()
eq(s3d[1] and s3d[1].to, wow.world.player.name, "пустое имя = шёпот себе")

wow.world.player.dead = false

------------------------------------------------------------- деньги

print("\n\27[1mДеньги и уровни\27[0m")
ns.Comm:Clear()
ns.GiveMoney(100 * 10000)
eq(lastCmd(), ".modify money 1000000", "100 золота = 1000000 меди")

ns.Comm:Clear()
ns.AddLevels(5)
eq(lastCmd(), ".character levelup 5", "прирост уровня уходит как есть")

-- SetLevel считает разницу: сервер принимает прирост, не итог.
wow.world.player.level = 12
wow.world.target = nil
ns.Comm:Clear()
ns.SetLevel(80)
eq(lastCmd(), ".character levelup 68", "до 80 с 12 — прирост 68")

ns.Comm:Clear()
ns.SetLevel(12)
eq(ns.Comm:Pending(), 0, "если уровень уже нужный, команда не шлётся")

-- Понижение уровня — отрицательный прирост.
ns.Comm:Clear()
ns.SetLevel(5)
eq(lastCmd(), ".character levelup -7", "понижение уходит отрицательным")

------------------------------------------------------------ цель

print("\n\27[1mВыбор цели\27[0m")
wow.world.target = nil
eq(ns.TargetName(), nil, "без выделения цели нет")
eq(ns.TargetLabel(), wow.world.player.name, "команды идут игроку")

wow.world.target = { name = "Пётр", level = 40, class = "MAGE" }
eq(ns.TargetName(), "Пётр", "цель распознана")
eq(ns.TargetLabel(), "Пётр", "команды пойдут цели")

ns.db.applyToTarget = false
eq(ns.TargetLabel(), wow.world.player.name, "при снятой галочке — игроку")
ns.db.applyToTarget = true

-- SetLevel учитывает уровень цели, а не свой.
ns.Comm:Clear()
ns.SetLevel(45)
eq(lastCmd(), ".character levelup 5", "прирост считается от уровня цели (40 -> 45)")
wow.world.target = nil

-------------------------------------------------- цели: игрок и NPC

print("\n\27[1mЦель: игрок или существо\27[0m")
wow.world.target = nil
ok(not ns.HasTarget(), "без выделения цели нет")
ok(not ns.TargetIsPlayer(), "и игрока тоже нет")

wow.world.target = { name = "Кабан", level = 5, class = "WARRIOR", isNPC = true }
ok(ns.HasTarget(), "NPC считается выделенной целью")
ok(not ns.TargetIsPlayer(), "но игроком не считается")
eq(ns.TargetName(), nil, "TargetName для NPC пуст: .summon его не примет")
local dispName, dispIsPlayer = ns.TargetDisplayName()
eq(dispName, "Кабан", "для показа имя NPC доступно")
eq(dispIsPlayer, false, "и помечено как не-игрок")

wow.world.target = { name = "Пётр", level = 40, class = "MAGE" }
ok(ns.TargetIsPlayer(), "игрок распознан")
eq(ns.TargetName(), "Пётр", "имя игрока доступно")

-------------------------------------------- обязательное выделение

print("\n\27[1mКоманды, требующие цели\27[0m")

local function findAction(cmd)
  for _, a in ipairs(ns.ACTIONS) do
    if a.cmd == cmd then return a end
  end
end

-- .die требует выделения ЛЮБОГО юнита и своего персонажа не убивает
-- (cs_misc.cpp:1211). Раньше аддон предлагал «убить себя» — это было
-- неверно.
local die = findAction("die")
ok(die ~= nil, "действие «Убить» есть")
eq(die.needsTarget, "any", "«Убить» помечено как требующее любой цели")

wow.world.target = nil
ns.Comm:Clear()
ns.DoAction(die)
eq(ns.Comm:Pending(), 0, "без цели команда не отправляется")
ok(not (ns._confirm and ns._confirm:IsShown()),
   "и диалог «убить себя» больше не показывается")

-- С выделенным NPC команда обязана уходить без вопросов.
ns.db.confirmRisky = false
wow.world.target = { name = "Кабан", level = 5, class = "WARRIOR", isNPC = true }
ns.Comm:Clear()
ns.DoAction(die)
eq(lastCmd(), ".die", "с выделенным NPC команда уходит")

-- .respawn — только по существу.
local respawn = findAction("respawn")
ok(respawn ~= nil, "действие «Оживить NPC» есть")
eq(respawn.needsTarget, "creature", "помечено как требующее существо")
ns.Comm:Clear()
ns.DoAction(respawn)
eq(lastCmd(), ".respawn", "с выделенным NPC оживление уходит")

wow.world.target = nil
ns.Comm:Clear()
ns.DoAction(respawn)
eq(ns.Comm:Pending(), 0, "без цели оживление не отправляется")

-- .summon — только по игроку.
local summon = findAction("summon")
ok(summon ~= nil, "действие «Призвать к себе» есть")
eq(summon.needsTarget, "player", "помечено как требующее игрока")

wow.world.target = { name = "Кабан", level = 5, class = "WARRIOR", isNPC = true }
ns.Comm:Clear()
ns.DoAction(summon)
eq(ns.Comm:Pending(), 0, "NPC призвать нельзя — команда не уходит")

wow.world.target = { name = "Пётр", level = 40, class = "MAGE" }
ns.Comm:Clear()
ns.DoAction(summon)
eq(lastCmd(), ".summon", "игрока призываем")

wow.world.target = nil
ns.db.confirmRisky = true

--------------------------------------------------------- скорость

print("\n\27[1mСкорость\27[0m")
ns.Comm:Clear()
ns.SetSpeed(5)
eq(lastCmd(), ".modify speed 5", "скорость уходит одной командой")

ns.Comm:Clear()
ns.SetSpeed(0.05)
eq(ns.Comm:Pending(), 0, "значение ниже минимума отвергнуто")

ns.Comm:Clear()
ns.SetSpeed(100)
eq(ns.Comm:Pending(), 0, "значение выше максимума отвергнуто")

ns.Comm:Clear()
ns.SetSpeed(ns.SPEED_MAX)
eq(lastCmd(), ".modify speed 50", "граничное значение принимается")

ok(#ns.SPEED_STEPS >= 4, "быстрые кнопки скорости заданы")

-- Кнопка скорости на полосе быстрых действий. Отдельной кнопки под
-- каждое значение нет — одна кнопка открывает список.
local speedBtn
for _, b in ipairs(ns.Bar.buttons or {}) do
  if b._action and b._action.speed then speedBtn = b end
end
ok(speedBtn ~= nil, "на полосе есть кнопка скорости")

wow.Click(speedBtn)
local menu = ns._dropdown
ok(menu and menu:IsVisible(), "нажатие открывает список")
eq(#ns.SPEED_STEPS, 4, "в списке четыре множителя")

-- Второе нажатие по той же кнопке закрывает список.
wow.Click(speedBtn)
ok(not menu:IsVisible(), "повторное нажатие закрывает список")

-- Выбор из списка отправляет команду и запоминает значение.
wow.Click(speedBtn)
ns.Comm:Clear()
local row10
for _, r in ipairs(menu._rows) do
  if r:IsVisible() and r._label:GetText() == "x10" then row10 = r end
end
ok(row10 ~= nil, "в списке есть x10")
wow.Click(row10)
eq(lastCmd(), ".modify speed 10", "выбор из списка отправляет команду")
eq(ns.db.speed, 10, "выбранная скорость запомнена")
ok(not menu:IsVisible(), "после выбора список закрывается")
eq(speedBtn._speedLabel:GetText(), "x10", "множитель подписан на кнопке")

-- Возврат к обычной скорости подпись убирает: x1 — состояние по умолчанию.
ns.SetSpeed(1)
eq(speedBtn._speedLabel:GetText(), "", "при x1 подпись пустая")

---------------------------------------------------------- квесты

print("\n\27[1mКвесты\27[0m")
ns.Comm:Clear()
ns.QuestAction("add", 1234)
eq(lastCmd(), ".quest add 1234", "выдача квеста")

ns.Comm:Clear()
ns.QuestAction("complete", 1234)
eq(lastCmd(), ".quest complete 1234", "завершение квеста")

ns.Comm:Clear()
ns.QuestAction("reward", 1234)
eq(lastCmd(), ".quest reward 1234", "награда за квест")

ns.Comm:Clear()
ns.QuestAction("add", nil)
eq(ns.Comm:Pending(), 0, "без ID команда не уходит")

-- Разбор ссылок квеста: такие приходят от .lookup quest и из журнала.
eq(ns.ParseQuestLink("|cffffff00|Hquest:1234:15|h[Волчьи шкуры]|h|r"), 1234,
   "ID вынут из ссылки квеста")
eq(ns.ParseQuestLink(" 987 "), 987, "число принято как ID")
eq(ns.ParseQuestLink("Волчьи шкуры"), nil, "текст без ID отвергнут")
eq(ns.ParseQuestLink(nil), nil, "nil не роняет разбор")

-- Разбор заклинаний.
eq(ns.ParseSpellInput("|cff71d5ff|Hspell:2018|h[Кузнечное дело]|h|r"), 2018,
   "ID вынут из ссылки заклинания")
eq(ns.ParseSpellInput("133"), 133, "число принято как ID заклинания")
eq(ns.ParseSpellInput("огненный шар"), nil, "название без ID отвергнуто")

-------------------------------------------------- связка с Questie

print("\n\27[1mСвязка с Questie\27[0m")

-- Без Questie аддон обязан работать: связка строго опциональная.
ok(not ns.Questie.available, "без Questie связка выключена")
eq(ns.Questie:QuestName(1234), nil, "название квеста недоступно")
eq(ns.Questie:RequiredItems(1234), nil, "предметы квеста недоступны")
ok(ns.Questie:StatusText():find("не найден") ~= nil,
   "статус сообщает об отсутствии базы")

-- Подсовываем поддельный Questie и проверяем, что мост его подхватит.
local fakeQuest = {
  name = "Волчьи шкуры",
  sourceItemId = 111,
  requiredSourceItems = { 222 },
  objectives = { nil, nil, { { 333, "Шкура" }, { 222, "Дубликат" } } },
}
_G.QuestieLoader = {
  ImportModule = function(_, name)
    if name ~= "QuestieDB" then return {} end
    return {
      GetQuest = function(_, id) return id == 1234 and fakeQuest or nil end,
      GetItem = function(_, id)
        return ({ [111] = { name = "Записка" }, [222] = { name = "Нож" },
                  [333] = { name = "Шкура" } })[id]
      end,
    }
  end,
}

ok(ns.Questie:Probe(), "мост подключается к найденной базе")
ok(ns.Questie.available, "связка помечена доступной")
eq(ns.Questie:QuestName(1234), "Волчьи шкуры", "название квеста читается")
eq(ns.Questie:QuestName(9999), nil, "неизвестный квест даёт nil")

local reqItems = ns.Questie:RequiredItems(1234)
ok(reqItems ~= nil, "список предметов получен")
eq(#reqItems, 3, "собраны sourceItemId, requiredSourceItems и цели-предметы")
-- Предмет 222 есть и в requiredSourceItems, и в целях — не должен
-- выдаваться дважды.
local count222 = 0
for _, id in ipairs(reqItems or {}) do
  if id == 222 then count222 = count222 + 1 end
end
eq(count222, 1, "дубликат предмета убран")

eq(ns.Questie:ItemName(333), "Шкура", "название предмета читается")
ok(ns.Questie:StatusText():find("подключён") ~= nil, "статус сообщает об успехе")

-- Битая база не должна ронять аддон.
_G.QuestieLoader = {
  ImportModule = function() error("сломано") end,
}
ok(not ns.Questie:Probe(), "ошибка при импорте обработана")
ok(not ns.Questie.available, "связка выключена после сбоя")

_G.QuestieLoader = nil
ns.Questie:Probe()

-------------------------------------------- вставка ссылок Shift+кликом

print("\n\27[1mВставка ссылок\27[0m")
ok(type(ns.EnableLinkInsert) == "function", "механизм регистрации полей есть")
-- Перехват должен быть один на весь аддон, а не цепочка на каждое поле.
local probe = CreateFrame("EditBox")
local focused = false
probe.HasFocus = function() return focused end
probe.SetText = function(self, t) self._t = t end
ns.EnableLinkInsert(probe)

focused = false
ChatEdit_InsertLink("|Hitem:6948|h[Камень]|h")
eq(probe._t, nil, "поле без фокуса ссылку не принимает")

focused = true
ChatEdit_InsertLink("|Hitem:6948|h[Камень]|h")
eq(probe._t, "|Hitem:6948|h[Камень]|h", "поле в фокусе принимает ссылку")

--------------------------------------------------- опасные команды

print("\n\27[1mЗащита от необратимого\27[0m")
ns.db.confirmRisky = true
ns.Comm:Clear()
ns.Run("character erase Вася")
eq(ns.Comm:Pending(), 0, "удаление персонажа требует подтверждения")
ok(ns._confirm and ns._confirm:IsShown(), "показан диалог")
wow.Click(ns._confirm._yes)
eq(ns.Comm:Pending(), 1, "после подтверждения команда уходит")

-- Поведение «Убить» проверяется выше, в разделе про обязательное
-- выделение: команда требует цели и своего персонажа не убивает.

------------------------------------------------------- переключатели

print("\n\27[1mПереключатели режимов\27[0m")
ns.db.toggles = {}
local flyAction
for _, a in ipairs(ns.ACTIONS) do
  if a.toggle == "gm fly" then flyAction = a end
end
ok(flyAction ~= nil, "действие «Полёт» найдено")

ns.Comm:Clear()
ns.DoAction(flyAction)
eq(lastCmd(), ".gm fly on", "первое нажатие включает")
eq(ns.db.toggles["gm fly"], true, "состояние запомнено")

ns.Comm:Clear()
ns.DoAction(flyAction)
eq(lastCmd(), ".gm fly off", "второе нажатие выключает")
eq(ns.db.toggles["gm fly"], false, "состояние обновлено")

--------------------------------------------------------- предметы

print("\n\27[1mПредметы\27[0m")
ns.db.history = {}
ns.Comm:Clear()
ns.GiveItem(6948, 3)
eq(lastCmd(), ".additem 6948 3", "команда выдачи собрана верно")
eq(#ns.db.history, 1, "предмет попал в историю")
eq(ns.db.history[1].id, 6948, "id сохранён")

-- Повторная выдача не плодит дубликаты, а поднимает наверх.
ns.GiveItem(1234, 1)
ns.GiveItem(6948, 5)
eq(#ns.db.history, 2, "дубликат не добавлен")
eq(ns.db.history[1].id, 6948, "повторный поднялся наверх")
eq(ns.db.history[1].count, 5, "количество обновилось")

-- История ограничена.
for i = 1, 30 do ns.GiveItem(10000 + i, 1) end
ok(#ns.db.history <= 12, "история не растёт бесконечно (" .. #ns.db.history .. ")")

-- Разбор ссылок.
eq(ns.ParseItemLink("|cffffffff|Hitem:6948:0:0:0:0:0:0:0:80|h[Камень]|h|r"), 6948,
   "ID вынут из ссылки предмета")
eq(ns.ParseItemLink("  4321  "), 4321, "число принято как ID")
eq(ns.ParseItemLink("Frostweave Bag"), nil, "текст без ID отвергнут")
eq(ns.ParseItemLink(nil), nil, "nil не роняет разбор")

-- Наборы.
ns.Comm:Clear()
local kit = ns.ITEM_KITS[2]   -- еда и вода, два предмета
ns.GiveKit(kit)
eq(ns.Comm:Pending(), #kit.items, "набор ставит по команде на предмет")

--------------------------------------------------------- обучение

print("\n\27[1mОбучение\27[0m")
ns.Comm:Clear()
ns.LearnProfession(ns.PROFESSIONS[1])
eq(lastCmd(), ".learn 2018 all", "профессия учится со всеми рангами")

-- Все ID профессий — числа, и они различны.
local seen, dupes = {}, 0
for _, p in ipairs(ns.PROFESSIONS) do
  ok(type(p.spell) == "number" and p.spell > 0,
     "у профессии «" .. p.ru .. "» задан ID")
  if seen[p.spell] then dupes = dupes + 1 end
  seen[p.spell] = true
end
eq(dupes, 0, "ID профессий не повторяются")

-------------------------------------------------------- телепорты

print("\n\27[1mТелепорты\27[0m")
ns.Comm:Clear()
ns.Teleport({ tele = "Dalaran", ru = "Даларан" })
eq(lastCmd(), ".teleport Dalaran", "телепорт по имени из базы")

ns.Comm:Clear()
ns.GoQuest(1234, "starter")
eq(lastCmd(), ".go quest starter 1234", "прыжок к выдающему квест")

ns.Comm:Clear()
ns.GoQuest(1234, "ender")
eq(lastCmd(), ".go quest ender 1234", "прыжок к принимающему")

-- Избранное.
ns.db.favorites = {}
local dal = { tele = "Dalaran", ru = "Даларан" }
ok(not ns.IsFavorite("Dalaran"), "изначально не в избранном")
ns.ToggleFavorite(dal)
ok(ns.IsFavorite("Dalaran"), "добавлено в избранное")
eq(#ns.db.favorites, 1, "запись одна")
ns.ToggleFavorite(dal)
ok(not ns.IsFavorite("Dalaran"), "убрано из избранного")
eq(#ns.db.favorites, 0, "список пуст")

-- Все точки заданы непустыми строками.
local badTele = 0
local function checkList(list)
  for _, e in ipairs(list) do
    if type(e.tele) ~= "string" or e.tele == "" then badTele = badTele + 1 end
    if type(e.ru) ~= "string" or e.ru == "" then badTele = badTele + 1 end
  end
end
checkList(ns.TELE_CITIES)
for _, g in ipairs(ns.TELE_DUNGEONS) do checkList(g.list) end
for _, g in ipairs(ns.TELE_RAIDS) do checkList(g.list) end
eq(badTele, 0, "у всех точек есть имя в базе и русская подпись")

------------------------------------------------------ слэш-команды

print("\n\27[1mСлэш-команды\27[0m")
local slash = SlashCmdList["GMCOMMANDER"]
ok(type(slash) == "function", "обработчик /gm зарегистрирован")

ns.Comm:Clear()
slash("tp Даларан")
eq(lastCmd(), ".teleport Dalaran", "«/gm tp Даларан» нашёл русское имя")

ns.Comm:Clear()
slash("tp Оргриммар")
eq(lastCmd(), ".teleport Orgrimmar", "русские имена ищутся по всем спискам")

ns.Comm:Clear()
slash("tp Ульдуар")
eq(lastCmd(), ".teleport UlduarRaid", "рейды тоже находятся")

-- Неизвестное имя уходит серверу как есть: в game_tele ~2000 точек,
-- наш список покрывает не все.
ns.Comm:Clear()
slash("tp SomeUnknownPlace")
eq(lastCmd(), ".teleport SomeUnknownPlace", "неизвестное имя отдаётся серверу")

ns.Comm:Clear()
slash("item 6948 2")
eq(lastCmd(), ".additem 6948 2", "«/gm item» выдаёт предмет")

ns.Comm:Clear()
slash("gold 500")
eq(lastCmd(), ".modify money 5000000", "«/gm gold 500» переводит в медь")

wow.world.player.level = 10
ns.Comm:Clear()
slash("lvl 60")
eq(lastCmd(), ".character levelup 50", "«/gm lvl 60» считает прирост")

ns.Comm:Clear()
slash("quest 42")
eq(lastCmd(), ".go quest starter 42", "«/gm quest» прыгает к квестгиверу")

ns.Comm:Clear()
slash("modify speed 3")
eq(lastCmd(), ".modify speed 3", "произвольная команда уходит как есть")

ns.Comm:Clear()
slash("speed 5")
eq(lastCmd(), ".modify speed 5", "«/gm speed 5» меняет скорость")

ns.Comm:Clear()
slash("q add 1234")
eq(lastCmd(), ".quest add 1234", "«/gm q add» выдаёт квест")

ns.Comm:Clear()
slash("q done 1234")
eq(lastCmd(), ".quest complete 1234", "«done» распознан как complete")

ns.Comm:Clear()
slash("q выдать 777")
eq(lastCmd(), ".quest add 777", "русский синоним действия работает")

ns.Comm:Clear()
slash("q нечто 777")
eq(ns.Comm:Pending(), 0, "неизвестное действие квеста не отправляется")

for _, cmd in ipairs({ "help", "bar", "" }) do
  local s, e = pcall(slash, cmd)
  ok(s, "«/gm " .. cmd .. "» не падает" .. (s and "" or ": " .. tostring(e)))
end
ns.db.bar = true

--------------------------------------------------- отрисовка

print("\n\27[1mОтрисовка\27[0m")
for i, p in ipairs(ns.UI.pages) do
  ns.UI:Select(i)
  local s, e = pcall(function() ns.UI:Refresh() end)
  ok(s, "«" .. p.title .. "» переживает Refresh" .. (s and "" or ": " .. tostring(e)))
end

-- Смена цели не должна ронять отрисовку.
wow.world.target = { name = "Цель", level = 70, class = "PRIEST" }
local s2, e2 = pcall(wow.Fire, "PLAYER_TARGET_CHANGED")
ok(s2, "смена цели обрабатывается" .. (s2 and "" or ": " .. tostring(e2)))
wow.world.target = nil
s2, e2 = pcall(wow.Fire, "PLAYER_TARGET_CHANGED")
ok(s2, "снятие цели обрабатывается")

-- Вёрстка: ничто не должно вылезать за края окна. Стаб запоминает
-- SetPoint и размеры, поэтому правый край считается точно — именно
-- так кнопки заклинаний однажды уехали за границу.
do
  local WIDTH, HEIGHT = 460, 520
  local overflow = {}
  for _, f in ipairs(wow.frames) do
    for _, p in ipairs(f._points or {}) do
      local anchor, x = p[1], tonumber(p[4])
      -- Интересуют только элементы, спозиционированные от левого края
      -- с явным отступом: у них правый край = x + ширина.
      if x and (anchor == "TOPLEFT" or anchor == "BOTTOMLEFT") and x > 0 then
        local right = x + (f:GetWidth() or 0)
        if right > WIDTH - 8 then
          table.insert(overflow, string.format("x=%d w=%d -> %d",
            x, f:GetWidth() or 0, right))
        end
      end
    end
  end
  eq(#overflow, 0, "ни один элемент не выходит за правый край окна" ..
     (#overflow > 0 and ("  [" .. table.concat(overflow, "; ") .. "]") or ""))
end

-- Пустое избранное и заполненная история — частые крайние случаи.
ns.db.favorites = {}
ns.UI:Select(2)
s2, e2 = pcall(function() ns.UI:Refresh() end)
ok(s2, "пустое избранное не ломает список" .. (s2 and "" or ": " .. tostring(e2)))

--------------------------------------------------------------------- итог

print(string.format("\n\27[1mИтого:\27[0m %d пройдено, %s\n",
  passed, failed == 0 and "\27[32m0 провалено\27[0m"
                      or ("\27[31m" .. failed .. " провалено\27[0m")))

os.exit(failed == 0 and 0 or 1)
