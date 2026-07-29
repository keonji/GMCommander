-- UI_Items.lua — вкладка «Предметы»: выдача по ID, ссылке и наборами.
local ADDON, ns = ...
local T, W = ns.Theme, ns.W

local page = { title = "Предметы" }
local idEdit, countEdit, histRows, lookupEdit = nil, nil, {}, nil

--------------------------------------------------------------------------

local function giveFromInput()
  local raw = idEdit._edit:GetText()
  local id = ns.ParseItemLink(raw)
  if not id then
    ns.Print("|cffffcc00Не разобрал предмет|r — введите ID числом или " ..
             "перетащите предмет в поле (Shift+клик).")
    return
  end
  local count = tonumber(countEdit._edit:GetText()) or 1
  ns.GiveItem(id, count)
  ns.Print(string.format("Выдано: предмет %d ×%d.", id, count))
  page.refresh()
end

--------------------------------------------------------------------------

function page.build(parent)
  local pad = 14

  ------------------------------------------------------------ выдача
  local h1 = T:Text(parent, "Выдать предмет", 11, T.color.accent)
  h1:SetPoint("TOPLEFT", pad, -pad)

  idEdit = W:EditBox(parent, "ID или Shift+клик по предмету", giveFromInput)
  idEdit:SetPoint("TOPLEFT", pad, -pad - 18)
  idEdit:SetWidth(250)

  -- Shift+клик по предмету вставляет ссылку в активное поле ввода, но
  -- только если игра знает про это поле. Клиент опрашивает открытые
  -- фреймы через глобальную ChatEdit_InsertLink; перехватываем её и
  -- отдаём ссылку своему полю, когда оно в фокусе.
  do
    local original = ChatEdit_InsertLink
    ChatEdit_InsertLink = function(link)
      if idEdit._edit:HasFocus() and link then
        idEdit._edit:SetText(link)
        return true
      end
      if original then return original(link) end
      return false
    end
  end

  W.Tooltip(idEdit, "Предмет",
    "Введите числовой ID либо кликните с зажатым Shift по предмету " ..
    "в сумке или по ссылке в чате — сначала поставьте курсор в это поле.")

  countEdit = W:EditBox(parent, "шт", giveFromInput)
  countEdit:SetPoint("TOPLEFT", pad + 256, -pad - 18)
  countEdit:SetWidth(50)

  local giveBtn = W:Button(parent, {
    text = "Выдать", width = 92, height = 24, accent = true,
    tip = "Положить предмет в сумку",
    tipBody = "Команда: .additem <id> <количество>",
    onClick = giveFromInput,
  })
  giveBtn:SetPoint("TOPLEFT", pad + 312, -pad - 18)

  ------------------------------------------------------------- поиск
  local h2 = T:Text(parent, "Найти предмет по названию", 11, T.color.accent)
  h2:SetPoint("TOPLEFT", pad, -pad - 52)

  lookupEdit = W:EditBox(parent, "часть названия, например: Frostweave", function(text)
    if text == "" then return end
    ns.Run("lookup item " .. text)
  end)
  lookupEdit:SetPoint("TOPLEFT", pad, -pad - 70)
  lookupEdit:SetWidth(330)

  local lookupBtn = W:Button(parent, {
    text = "Искать", width = 92, height = 24,
    tip = "Поиск по базе сервера",
    tipBody = "Команда: .lookup item <текст>\n\n" ..
              "Сервер ответит в чат списком ссылок. Shift+клик по любой " ..
              "из них подставит ID в поле выдачи.",
    onClick = function()
      local t = lookupEdit._edit:GetText()
      if t ~= "" then ns.Run("lookup item " .. t) end
    end,
  })
  lookupBtn:SetPoint("TOPLEFT", pad + 336, -pad - 70)

  local lookupNote = T:Text(parent,
    "Результаты придут в чат кликабельными ссылками — Shift+клик по нужной " ..
    "подставит её ID в поле выше.", 9, T.color.textDim)
  lookupNote:SetPoint("TOPLEFT", pad, -pad - 96)
  lookupNote:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  lookupNote:SetJustifyH("LEFT")

  ------------------------------------------------------------ наборы
  local h3 = T:Text(parent, "Готовые наборы", 11, T.color.accent)
  h3:SetPoint("TOPLEFT", pad, -pad - 124)

  local perRow, bw, bh = 2, 205, 28
  for i, kit in ipairs(ns.ITEM_KITS) do
    local b = W:Button(parent, {
      text = kit.ru, width = bw, height = bh,
      tip = kit.ru, tipBody = kit.desc,
      onClick = function()
        ns.GiveKit(kit)
        page.refresh()
      end,
    })
    local row = math.floor((i - 1) / perRow)
    local col = (i - 1) % perRow
    b:SetPoint("TOPLEFT", pad + col * (bw + 6), -pad - 142 - row * (bh + 4))
  end

  local kitRows = math.ceil(#ns.ITEM_KITS / perRow)

  ----------------------------------------------------------- история
  local h4 = T:Text(parent, "Выдавали недавно", 11, T.color.accent)
  h4:SetPoint("TOPLEFT", pad, -pad - 150 - kitRows * (bh + 4))
  page._histY = pad + 168 + kitRows * (bh + 4)

  page._histHint = T:Text(parent, "", 9, T.color.textDim)
  page._histHint:SetPoint("TOPLEFT", pad, -page._histY)

  page._parent = parent
end

--------------------------------------------------------------------------

function page.refresh()
  if not page._parent then return end

  for _, r in ipairs(histRows) do r:Hide() end

  local hist = ns.db.history
  page._histHint:SetShown(#hist == 0)
  if #hist == 0 then
    page._histHint:SetText("здесь появятся последние выданные предметы")
    return
  end

  local perRow, bw = 4, 100
  for i, h in ipairs(hist) do
    local b = histRows[i]
    if not b then
      b = W:Button(page._parent, { text = "", width = bw, height = 22 })
      histRows[i] = b
    end
    b:Show()
    b:SetLabel(h.id .. (h.count > 1 and (" ×" .. h.count) or ""))
    b:SetScript("OnClick", function() ns.GiveItem(h.id, h.count) end)
    W.Tooltip(b, "Выдать снова", "Предмет " .. h.id .. ", количество " .. h.count)

    local row = math.floor((i - 1) / perRow)
    local col = (i - 1) % perRow
    b:SetPoint("TOPLEFT", 14 + col * (bw + 4), -page._histY - row * 25)
  end
end

ns.RegisterPage(page)
