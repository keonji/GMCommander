-- UI_Settings.lua — вкладка «Настройки».
local ADDON, ns = ...
local T, W = ns.Theme, ns.W

local page = { title = "Настройки" }

function page.build(parent)
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

  ------------------------------------------------------------- права
  y = y + 10
  local h3 = T:Text(parent, "О правах", 11, T.color.accent)
  h3:SetPoint("TOPLEFT", pad, nextY(20))

  local rights = T:Text(parent,
    "Аддон только отправляет команды — доступ решает сервер по уровню\n" ..
    "вашего аккаунта. Если команда не срабатывает молча, скорее всего\n" ..
    "не хватает прав: выдайте их в консоли сервера командой\n" ..
    "|cffffcc00account set gmlevel ИМЯ 3 -1|r и перезайдите в игру.",
    9, T.color.textDim)
  rights:SetPoint("TOPLEFT", pad, nextY(64))
  rights:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  rights:SetJustifyH("LEFT")

  ------------------------------------------------------------- сброс
  local reset = W:Button(parent, {
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

  local ver = T:Text(parent, "GMCommander " .. ns.VERSION, 9, T.color.textDim)
  ver:SetPoint("BOTTOMRIGHT", -pad, 18)
end

function page.refresh() end

ns.RegisterPage(page)
