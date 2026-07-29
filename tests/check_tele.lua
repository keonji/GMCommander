-- check_tele.lua — сверка имён телепортов с базой сервера.
--
--   lua tests/check_tele.lua /путь/к/AzerothCore/data/sql/base/db_world/game_tele.sql
--
-- Аддон шлёт `.teleport <name>`, где name должен точно совпадать со
-- значением поля `name` таблицы game_tele. Опечатка не вызовет ошибки
-- в Lua — она просто молча не сработает в игре. Поэтому сверяем
-- заранее, отдельным скриптом: путь к дампу есть не на всякой машине,
-- и обычный прогон тестов от него зависеть не должен.

local dump = arg[1] or
  "../AzerothCore/data/sql/base/db_world/game_tele.sql"

local fh = io.open(dump, "r")
if not fh then
  print("Не найден дамп game_tele.sql: " .. dump)
  print("Укажите путь аргументом. Проверка пропущена.")
  os.exit(0)
end

-- Имена в дампе — последнее строковое поле каждого кортежа.
local known = {}
for line in fh:lines() do
  for name in line:gmatch("'([^']+)'%)") do
    known[name:lower()] = name
  end
end
fh:close()

print(string.format("В game_tele найдено имён: %d", (function()
  local n = 0
  for _ in pairs(known) do n = n + 1 end
  return n
end)()))

-- Загружаем только Const.lua: остальному нужен клиентский API.
local ns = {}
loadfile("GMCommander/Modules/Const.lua")("GMCommander", ns)

local bad, total = 0, 0

local function check(list, where)
  for _, e in ipairs(list) do
    total = total + 1
    if not known[e.tele:lower()] then
      bad = bad + 1
      print(string.format("  \27[31mНЕТ В БАЗЕ\27[0m %-24s (%s, %s)",
        e.tele, e.ru, where))
    end
  end
end

check(ns.TELE_CITIES, "города")
for _, g in ipairs(ns.TELE_DUNGEONS) do check(g.list, "подземелья/" .. g.era) end
for _, g in ipairs(ns.TELE_RAIDS) do check(g.list, "рейды/" .. g.era) end

if bad == 0 then
  print(string.format("\27[32mВсе %d точек найдены в базе.\27[0m", total))
else
  print(string.format("\27[31m%d из %d точек отсутствуют.\27[0m", bad, total))
end

os.exit(bad == 0 and 0 or 1)
