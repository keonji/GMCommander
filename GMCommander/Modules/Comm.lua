-- Comm.lua — отправка команд серверу.
--
-- GM-команды в 3.3.5a — это обычные сообщения чата, начинающиеся с
-- точки: сервер перехватывает их в ChatHandler до того, как текст
-- попадёт в канал. Никакого отдельного протокола нет.
--
-- Очередь с паузой нужна по той же причине, что и в BotCommander:
-- на чат распространяется антиспам сервера, а выдача набора предметов
-- или обучение четырнадцати профессиям — это десяток команд подряд.

local ADDON, ns = ...

local Comm = {}
ns.Comm = Comm

local queue, lastSend = {}, 0
local pump = CreateFrame("Frame")

--- Поставить GM-команду в очередь. Точку в начале добавлять не нужно.
function Comm:Send(cmd, quiet)
  if not cmd or cmd == "" then return end
  queue[#queue + 1] = { text = "." .. cmd, quiet = quiet }
end

--- Несколько команд разом, в заданном порядке.
function Comm:SendAll(list)
  for _, cmd in ipairs(list) do
    self:Send(cmd)
  end
end

function Comm:Pending()
  return #queue
end

function Comm:Clear()
  wipe(queue)
end

--- Каким каналом отправить команду.
--
-- Серверу тип канала безразличен: GM-команду он перехватывает по точке
-- в начале строки (ChatHandler.cpp:307) — причём ДО проверки на смерть
-- (ChatHandler.cpp:376). То есть команда мёртвого персонажа сработала
-- бы, если бы её удалось отправить.
--
-- Мешает клиент: канал SAY у мёртвого заблокирован на его стороне, и
-- сообщение до сервера просто не доходит. А вот WHISPER работает и в
-- виде духа — им и пользуемся, отправляя команду любому персонажу.
-- Получатель её не увидит: сервер забирает сообщение себе.
--
-- @return channel, target — target равен nil для SAY
function Comm:PickChannel()
  local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
  if not dead then
    return "SAY", nil
  end

  -- Пустая настройка означает «шептать себе»: получатель есть всегда,
  -- и на чужого персонажа рассчитывать не нужно.
  local to = ns.db and ns.db.deadWhisperTarget
  if not to or to == "" then
    to = UnitName("player")
  end

  return "WHISPER", to
end

pump:SetScript("OnUpdate", function()
  if #queue == 0 then return end
  local now = GetTime()
  local gap = (ns.db and ns.db.throttle) or 0.3
  if now - lastSend < gap then return end

  local item = table.remove(queue, 1)
  lastSend = now

  local channel, target = Comm:PickChannel()
  SendChatMessage(item.text, channel, nil, target)

  if ns.db and ns.db.echo and not item.quiet then
    ns.Print("|cff808080" .. item.text .. "|r")
  end

  if ns.OnQueueChanged then ns.OnQueueChanged() end
end)
