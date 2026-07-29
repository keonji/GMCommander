-- QuestieBridge.lua — необязательная связка с базой Questie.
--
-- Зачем. Клиент 3.3.5a не знает ни названий квестов, которых нет в
-- журнале, ни их целей, ни того, какие предметы для них нужны — эти
-- данные живут в базе сервера. Обходной путь через `.lookup quest`
-- работает, но ответ приходит текстом в чат и требует ручного клика.
--
-- Если у игрока установлен Questie-335, рядом уже лежит полная база
-- WotLK (~13 МБ: квесты, предметы, NPC, объекты) с целями и
-- координатами. Читаем её напрямую — без дублирования данных у себя.
--
-- Связь строго опциональная: без Questie аддон работает как раньше,
-- просто без подсказок. Никаких зависимостей в .toc — только проверка
-- на наличие в рантайме.
--
-- Источник: https://github.com/divial28/Questie-335

local ADDON, ns = ...

local Q = { available = false }
ns.Questie = Q

--- Попытаться подключиться. Вызывается после входа в мир: Questie
--- грузится своим чередом, и на ADDON_LOADED его может ещё не быть.
function Q:Probe()
  self.available = false
  self.db = nil

  if not QuestieLoader or not QuestieLoader.ImportModule then
    return false
  end

  -- ImportModule у Questie создаёт заглушку, если модуля ещё нет,
  -- поэтому проверяем не сам факт возврата, а наличие функций.
  local okImport, db = pcall(function()
    return QuestieLoader:ImportModule("QuestieDB")
  end)

  if not okImport or type(db) ~= "table" then
    return false
  end

  if type(db.GetQuest) ~= "function" then
    return false
  end

  self.db = db
  self.available = true
  return true
end

--- Данные квеста или nil.
-- @return { name, objectivesText, requiredSourceItems, startedBy, finishedBy }
function Q:GetQuest(questId)
  if not self.available or not questId then return nil end
  local ok, quest = pcall(function() return self.db:GetQuest(questId) end)
  if not ok or type(quest) ~= "table" then return nil end
  return quest
end

--- Название квеста для показа в интерфейсе.
function Q:QuestName(questId)
  local q = self:GetQuest(questId)
  if not q then return nil end
  return q.name
end

--- Предметы, которые квест требует иметь на руках.
-- В базе Questie это поле requiredSourceItems — «нужны, но не
-- являются целью». Ровно то, что чаще всего приходится выдавать
-- вручную, когда квест сломался.
-- @return массив ID либо nil
function Q:RequiredItems(questId)
  local q = self:GetQuest(questId)
  if not q then return nil end

  local out = {}

  if type(q.requiredSourceItems) == "table" then
    for _, id in ipairs(q.requiredSourceItems) do
      if type(id) == "number" then table.insert(out, id) end
    end
  end

  -- Предмет, который выдаёт сам квестгивер при взятии задания.
  if type(q.sourceItemId) == "number" and q.sourceItemId > 0 then
    table.insert(out, q.sourceItemId)
  end

  -- Цели-предметы: objectives[3] — список { {itemId, text}, ... }.
  -- Нумерация полей задокументирована в шапке wotlkQuestDB.lua.
  if type(q.objectives) == "table" and type(q.objectives[3]) == "table" then
    for _, entry in ipairs(q.objectives[3]) do
      local id = type(entry) == "table" and entry[1] or entry
      if type(id) == "number" then table.insert(out, id) end
    end
  end

  -- Один и тот же предмет может быть и целью, и требуемым — не
  -- выдавать же его дважды.
  local seen, uniq = {}, {}
  for _, id in ipairs(out) do
    if not seen[id] then
      seen[id] = true
      table.insert(uniq, id)
    end
  end

  if #uniq == 0 then return nil end
  return uniq
end

--- Название предмета из базы Questie.
function Q:ItemName(itemId)
  if not self.available or not itemId then return nil end
  if type(self.db.GetItem) ~= "function" then return nil end
  local ok, item = pcall(function() return self.db:GetItem(itemId) end)
  if not ok or type(item) ~= "table" then return nil end
  return item.name
end

--- Короткая строка о состоянии связки — для интерфейса.
function Q:StatusText()
  if self.available then
    return "|cff5cd95cQuestie подключён|r — названия и предметы квестов доступны"
  end
  return "|cff808080Questie не найден|r — ищите квесты через «.lookup quest»"
end
