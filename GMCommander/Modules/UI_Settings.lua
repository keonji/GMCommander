-- UI_Settings.lua — вкладка «Настройки».
local ADDON, ns = ...
local T, W = ns.Theme, ns.W

local page = { title = "Настройки" }

function page.build(parent)
  local footer = parent
  local scroll, content = W:ScrollArea(parent)
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", 0, 44)
  content:SetWidth(460)
  scroll:SetScript("OnSizeChanged", function(self, width)
    content:SetWidth(width)
  end)
  parent = content
  local pad = 14
  local y = pad
  local function nextY(h) local v = y; y = y + h; return -v end

  local h1 = T:Text(parent, "Поведение", 11, T.color.accent)
  h1:SetPoint("TOPLEFT", pad, nextY(20))

  local checks = {
    { key = "applyToTarget", label = "Применять команды к выделенной цели",
      tip = "Если снять, команды всегда будут действовать на вас, даже когда кто-то выделен." },
    { key = "confirmRisky", label = "Спрашивать перед необратимым",
      tip = "Подтверждение для команд, которые удаляют данные или убивают персонажа." },
    { key = "echo", label = "Показывать отправленные команды в чате",
      tip = "Видно, что именно ушло на сервер. Помогает, когда команда не сработала." },
    { key = "bar", label = "Показывать полосу быстрых действий",
      tip = "Небольшая панель поверх интерфейса." },
    { key = "locked", label = "Закрепить окно",
      tip = "Запретить перетаскивание." },
  }

  for _, c in ipairs(checks) do
    local cb = W:Check(parent, c.label, ns.db[c.key], function(v)
      ns.db[c.key] = v
      if c.key == "bar" and ns.Bar then ns.Bar:SetShown(v) end
      if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    end, c.tip)
    cb:SetPoint("TOPLEFT", pad, nextY(22))
  end

  y = y + 10
  local h2 = T:Text(parent, "Внешний вид", 11, T.color.accent)
  h2:SetPoint("TOPLEFT", pad, nextY(22))

  local sc = W:Slider(parent, "Масштаб окна", 0.7, 1.4, 0.05, ns.db.scale, function(v)
    ns.db.scale = v
    ns.UI.frame:SetScale(v)
  end, "%.2f")
  sc:SetPoint("TOPLEFT", pad, nextY(44))
  sc:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)

  local al = W:Slider(parent, "Непрозрачность", 0.4, 1.0, 0.05, ns.db.alpha, function(v)
    ns.db.alpha = v
    ns.UI.frame:SetAlpha(v)
  end, "%.0f%%")
  al:SetPoint("TOPLEFT", pad, nextY(44))
  al:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)

  local th = W:Slider(parent, "Пауза между командами, сек", 0.1, 1.0, 0.05,
    ns.db.throttle, function(v) ns.db.throttle = v end, "%.2f")
  th:SetPoint("TOPLEFT", pad, nextY(48))
  th:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  W.Tooltip(th._slider, "Пауза между командами",
    "GM-команды идут обычным чатом, а на чат действует антиспам сервера.\n" ..
    "Слишком малая пауза — часть команд из набора потеряется.")

  ------------------------------------------------- команды после смерти
  y = y + 8
  local hDead = T:Text(parent, "Команды в виде духа", 11, T.color.accent)
  hDead:SetPoint("TOPLEFT", pad, nextY(20))

  local deadNote = T:Text(parent,
    "Мёртвому клиент запрещает писать в /say, поэтому команды уходят\n" ..
    "шёпотом — серверу канал безразличен. Пусто = шептать себе.",
    9, T.color.textDim)
  deadNote:SetPoint("TOPLEFT", pad, nextY(30))
  deadNote:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  deadNote:SetJustifyH("LEFT")

  local deadEdit = W:EditBox(parent, "имя для шёпота (пусто = себе)", function(text)
    ns.db.deadWhisperTarget = text
    ns.Print(text ~= "" and ("Команды в виде духа пойдут шёпотом: " .. text)
                        or "Команды в виде духа пойдут шёпотом вам самому.")
  end)
  deadEdit:SetPoint("TOPLEFT", pad, nextY(30))
  deadEdit:SetWidth(220)
  deadEdit._edit:SetText(ns.db.deadWhisperTarget or "")

  ------------------------------------------------------------- права
  -- Текст короткий намеренно: с блоком «команды в виде духа» вкладка
  -- перестала помещаться в 460x520, а подробности всё равно есть в
  -- README и в подсказке ниже.
  y = y + 6
  local rights = T:Text(parent,
    "Права на команды решает сервер. Не работают молча — выдайте:\n" ..
    "|cffffcc00account set gmlevel ИМЯ 3 -1|r и перезайдите.",
    9, T.color.textDim)
  rights:SetPoint("TOPLEFT", pad, nextY(34))
  rights:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  rights:SetJustifyH("LEFT")

  ------------------------------------------------------------- сброс
  content:SetHeight(y + 8)

  local reset = W:Button(footer, {
    text = "Сбросить настройки", width = 150, height = 22,
    onClick = function()
      W:Confirm("Сброс",
        "Вернуть настройки к умолчаниям?\nИзбранное и история тоже очистятся.\nОкно перезагрузится.",
        function()
          GMCommanderDB = nil
          ReloadUI()
        end)
    end,
  })
  reset:SetPoint("BOTTOMLEFT", pad, 12)

  local ver = T:Text(footer, "GMCommander " .. ns.VERSION, 9, T.color.textDim)
  ver:SetPoint("BOTTOMRIGHT", -pad, 18)
end

function page.refresh() end

ns.RegisterPage(page)
