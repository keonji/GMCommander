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

--------------------------------------------------------------------------
-- Почему нельзя звать SendChatMessage напрямую
--------------------------------------------------------------------------
--
-- В 3.3.5a SendChatMessage — защищённая функция для сообщений, которые
-- начинаются с точки или слэша: клиент считает их командами и требует
-- «hardware event», то есть тот самый кадр, в котором игрок нажал
-- кнопку или клавишу. Наша очередь работает из OnUpdate, где такого
-- контекста уже нет, и клиент отвечает ошибкой «AddOn пытается
-- выполнить защищённое действие».
--
-- Штатный путь, которым сам клиент отправляет GM-команды, — строка
-- ввода чата: ChatEdit_SendText разбирает текст и вызывает защищённую
-- часть уже из доверенного кода. Своей строке достаточно быть скрытой
-- и наследовать шаблон ChatFrameEditBoxTemplate — видимый чат при этом
-- не трогается: команда не появится ни в одном окне, потому что сервер
-- перехватит её по точке.

local sender

local function ensureSender()
  if sender then return sender end

  -- Шаблон даёт ChatEdit_SendText всё, на что он рассчитывает:
  -- chatType, tellTarget, языковые поля. Без шаблона он падает.
  local ok, box = pcall(CreateFrame, "EditBox", "GMCommanderSender",
                        UIParent, "ChatFrameEditBoxTemplate")
  if not ok or not box then return nil end

  box:Hide()
  box:SetAutoFocus(false)
  sender = box
  return sender
end

--- Отправить строку так, чтобы клиент не счёл это защищённым действием.
--
-- Возвращает false, если штатный путь недоступен (нестандартный клиент,
-- заменённый чат) — тогда остаётся прямой вызов.
local function sendViaChatBox(text, channel, target)
  local box = ensureSender()
  if not box or not ChatEdit_SendText then return false end

  box:SetAttribute("chatType", channel)
  box:SetAttribute("tellTarget", target)
  -- Те же поля, но обычными ключами: часть сборок 3.3.5a читает их
  -- напрямую, а не через атрибуты.
  box.chatType = channel
  box.tellTarget = target
  box.language = nil

  -- В режиме шёпота клиент ждёт имя получателя в самом тексте:
  -- ChatEdit_SendText берёт tellTarget, но собственный парсер строки
  -- срабатывает раньше, если строка начинается с точки. Точку он
  -- пропускает как есть — это и нужно.
  box:SetText(text)

  local ok = pcall(ChatEdit_SendText, box, 0)
  box:SetText("")
  return ok
end

--- Единственное место, где команда действительно уходит на сервер.
function Comm:Dispatch(text)
  local channel, target = self:PickChannel()

  if sendViaChatBox(text, channel, target) then return true end

  -- Запасной путь для клиентов без стандартного чата. Он же сработает,
  -- если команду отправляют прямо из обработчика нажатия.
  local ok = pcall(SendChatMessage, text, channel, nil, target)
  if not ok then
    ns.Print("|cffff5555Клиент заблокировал команду|r " .. text ..
             " — отправьте её вручную через чат.")
  end
  return ok
end

pump:SetScript("OnUpdate", function()
  if #queue == 0 then return end
  local now = GetTime()
  local gap = (ns.db and ns.db.throttle) or 0.3
  if now - lastSend < gap then return end

  local item = table.remove(queue, 1)
  lastSend = now

  Comm:Dispatch(item.text)

  if ns.db and ns.db.echo and not item.quiet then
    ns.Print("|cff808080" .. item.text .. "|r")
  end

  if ns.OnQueueChanged then ns.OnQueueChanged() end
end)
