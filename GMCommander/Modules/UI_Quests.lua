-- UI_Quests.lua — вкладка «Квесты»: выдать, завершить, наградить.
--
-- Все команды из cs_quest.cpp действуют на выделенного игрока, а без
-- выделения — на вас. NPC они не касаются.

local ADDON, ns = ...
local T, W = ns.Theme, ns.W

local page = { title = "Квесты" }
local questEdit, searchEdit, logRows, targetLine = nil, nil, {}, nil

--------------------------------------------------------------------------

local function currentQuestId()
  return ns.ParseQuestLink(questEdit._edit:GetText())
end

local function runAction(cmd)
  local id = currentQuestId()
  if not id then
    ns.Print("|cffffcc00Укажите квест|r — введите ID, вставьте ссылку " ..
             "или выберите из журнала ниже.")
    return
  end
  ns.QuestAction(cmd, id)
  ns.Print(string.format("Квест %d: %s.", id, cmd))
end

--------------------------------------------------------------------------

function page.build(parent)
  local pad = 14

  ------------------------------------------------------------ квест
  local h1 = T:Text(parent, "Квест", 11, T.color.accent)
  h1:SetPoint("TOPLEFT", pad, -pad)

  questEdit = W:EditBox(parent, "ID квеста или ссылка", function()
    runAction("add")
  end)
  questEdit:SetPoint("TOPLEFT", pad, -pad - 18)
  questEdit:SetWidth(200)

  -- Ссылку на квест можно вставить Shift+кликом из журнала заданий
  -- или из ответа `.lookup quest`.
  ns.EnableLinkInsert(questEdit._edit)

  W.Tooltip(questEdit, "Квест",
    "Введите числовой ID, либо поставьте курсор сюда и кликните " ..
    "с Shift по квесту в журнале заданий или по ссылке в чате.")

  local fromLog = W:Button(parent, {
    text = "Из журнала", width = 100, height = 24,
    tip = "Взять отслеживаемый квест",
    tipBody = "Подставит ID выбранного в журнале заданий квеста.",
    onClick = function()
      -- GetQuestLogSelection даёт индекс выделенной строки журнала,
      -- а GetQuestLink по нему — ссылку с ID.
      local sel = GetQuestLogSelection and GetQuestLogSelection() or 0
      if sel and sel > 0 and GetQuestLink then
        local link = GetQuestLink(sel)
        if link then
          questEdit._edit:SetText(link)
          page.refresh()
          return
        end
      end
      ns.Print("Откройте журнал заданий и выделите квест.")
    end,
  })
  fromLog:SetPoint("TOPLEFT", pad + 206, -pad - 18)

  page._questLabel = T:Text(parent, "", 9, T.color.textDim)
  page._questLabel:SetPoint("TOPLEFT", pad, -pad - 46)
  page._questLabel:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  page._questLabel:SetJustifyH("LEFT")

  ---------------------------------------------------------- действия
  local h2 = T:Text(parent, "Действие", 11, T.color.accent)
  h2:SetPoint("TOPLEFT", pad, -pad - 66)

  local perRow, bw, bh = 3, 140, 28
  for i, a in ipairs(ns.QUEST_ACTIONS) do
    local b = W:Button(parent, {
      text = a.ru, width = bw, height = bh, icon = a.icon, fontSize = 10,
      tip = a.ru,
      tipBody = a.desc .. "\n\nКоманда: .quest " .. a.cmd .. " <id>",
      onClick = function() runAction(a.cmd) end,
    })
    local row = math.floor((i - 1) / perRow)
    local col = (i - 1) % perRow
    b:SetPoint("TOPLEFT", pad + col * (bw + 5), -pad - 84 - row * (bh + 4))
  end

  local actRows = math.ceil(#ns.QUEST_ACTIONS / perRow)
  local afterActions = pad + 84 + actRows * (bh + 4) + 10

  -- Полный цикл одной кнопкой: чаще всего нужно именно это.
  local doAll = W:Button(parent, {
    text = "Выдать, завершить и наградить", width = 260, height = 26, accent = true,
    tip = "Пройти квест целиком",
    tipBody = "Три команды подряд: .quest add, .quest complete, .quest reward.\n\n" ..
              "Квест окажется в журнале уже завершённым и с наградой.",
    onClick = function()
      local id = currentQuestId()
      if not id then
        ns.Print("|cffffcc00Укажите квест|r.")
        return
      end
      ns.QuestAction("add", id)
      ns.QuestAction("complete", id)
      ns.QuestAction("reward", id)
      ns.Print("Квест " .. id .. " выдан, завершён и награда получена.")
    end,
  })
  doAll:SetPoint("TOPLEFT", pad, -afterActions)

  ------------------------------------------------------- предметы квеста
  local h3 = T:Text(parent, "Предметы для квеста", 11, T.color.accent)
  h3:SetPoint("TOPLEFT", pad, -afterActions - 38)

  page._itemNote = T:Text(parent, "", 9, T.color.textDim)
  page._itemNote:SetPoint("TOPLEFT", pad, -afterActions - 54)
  page._itemNote:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  page._itemNote:SetJustifyH("LEFT")

  -- Кнопка активна только когда база Questie доступна и знает, какие
  -- предметы нужны выбранному квесту.
  page._giveQuestItems = W:Button(parent, {
    text = "Выдать предметы квеста", width = 200, height = 24, accent = true,
    tip = "Все предметы, нужные выбранному квесту",
    tipBody = "Берёт список из базы Questie: и цели-предметы, и то, " ..
              "что квест требует иметь на руках.",
    onClick = function()
      local id = currentQuestId()
      if not id then
        ns.Print("|cffffcc00Укажите квест|r.")
        return
      end
      local items = ns.Questie:RequiredItems(id)
      if not items then
        ns.Print("Для квеста " .. id .. " предметы не найдены в базе Questie.")
        return
      end
      for _, itemId in ipairs(items) do
        ns.GiveItem(itemId, 1)
      end
      ns.Print(string.format("Выдано предметов квеста %d: %d.", id, #items))
    end,
  })
  page._giveQuestItems:SetPoint("TOPLEFT", pad, -afterActions - 100)
  page._itemsRowY = afterActions - 100

  local itemEdit = W:EditBox(parent, "ID предмета или ссылка", function(text)
    local id = ns.ParseItemLink(text)
    if id then
      ns.GiveItem(id, 1)
      ns.Print("Выдан предмет " .. id .. ".")
    end
  end)
  itemEdit:SetPoint("TOPLEFT", pad, -afterActions - 132)
  itemEdit:SetWidth(160)
  page._itemEdit = itemEdit

  ns.EnableLinkInsert(itemEdit._edit)

  local itemCount = W:EditBox(parent, "шт", function() end)
  itemCount:SetPoint("TOPLEFT", pad + 166, -afterActions - 132)
  itemCount:SetWidth(44)

  local giveItem = W:Button(parent, {
    text = "Выдать предмет", width = 130, height = 24,
    tip = "Положить предмет в сумку",
    tipBody = "Команда: .additem <id> <количество>",
    onClick = function()
      local id = ns.ParseItemLink(itemEdit._edit:GetText())
      if not id then
        ns.Print("|cffffcc00Укажите предмет|r — ID или ссылку.")
        return
      end
      local n = tonumber(itemCount._edit:GetText()) or 1
      ns.GiveItem(id, n)
      ns.Print(string.format("Выдано: предмет %d ×%d.", id, n))
    end,
  })
  giveItem:SetPoint("TOPLEFT", pad + 216, -afterActions - 132)

  local findItem = W:Button(parent, {
    text = "Найти", width = 68, height = 24,
    tip = "Поиск предмета по названию",
    tipBody = "Команда: .lookup item <текст>",
    onClick = function()
      local t = itemEdit._edit:GetText()
      if t ~= "" and not tonumber(t) then
        ns.Run("lookup item " .. t)
      else
        ns.Print("Введите часть названия предмета.")
      end
    end,
  })
  findItem:SetPoint("TOPLEFT", pad + 350, -afterActions - 132)

  ------------------------------------------------------------- поиск
  local h4 = T:Text(parent, "Найти квест по названию", 11, T.color.accent)
  h4:SetPoint("BOTTOMLEFT", pad, 76)

  searchEdit = W:EditBox(parent, "часть названия квеста", function(text)
    if text ~= "" then ns.Run("lookup quest " .. text) end
  end)
  searchEdit:SetPoint("BOTTOMLEFT", pad, 46)
  searchEdit:SetWidth(300)

  local searchBtn = W:Button(parent, {
    text = "Искать", width = 88, height = 24,
    tip = "Поиск квеста в базе сервера",
    tipBody = "Команда: .lookup quest <текст>\n\n" ..
              "Сервер ответит списком: ID, уровень, название и — если " ..
              "выделен игрок — состояние квеста у него. Ссылки кликабельны.",
    onClick = function()
      local t = searchEdit._edit:GetText()
      if t ~= "" then ns.Run("lookup quest " .. t)
      else ns.Print("Введите часть названия квеста.") end
    end,
  })
  searchBtn:SetPoint("BOTTOMLEFT", pad + 306, 46)

  targetLine = T:Text(parent, "", 9, T.color.textDim)
  targetLine:SetPoint("BOTTOMLEFT", pad, 16)
  targetLine:SetPoint("RIGHT", parent, "RIGHT", -pad, 0)
  targetLine:SetJustifyH("LEFT")
end

--------------------------------------------------------------------------

function page.refresh()
  if not page._questLabel then return end

  local id = currentQuestId()
  if id then
    -- Если рядом установлен Questie, показываем ещё и название: иначе
    -- по одному числу не понять, тот ли квест выбран.
    local name = ns.Questie:QuestName(id)
    if name then
      page._questLabel:SetText(string.format(
        "Выбран квест |cffffcc00%d|r — %s", id, name))
    else
      page._questLabel:SetText("Выбран квест |cffffcc00" .. id .. "|r")
    end
  else
    page._questLabel:SetText("Квест не выбран")
  end

  -- Блок предметов: что можно выдать и откуда мы это знаем.
  if page._itemNote then
    if not ns.Questie.available then
      page._itemNote:SetText(
        "Какие предметы нужны квесту, клиент не знает — эти данные есть " ..
        "только в базе сервера.\nУстановите |cffffcc00Questie|r, и список " ..
        "подтянется сам. Пока ищите вручную кнопкой «Найти».")
      page._giveQuestItems:SetEnabledLook(false)
    elseif not id then
      page._itemNote:SetText(ns.Questie:StatusText())
      page._giveQuestItems:SetEnabledLook(false)
    else
      local items = ns.Questie:RequiredItems(id)
      if items then
        local parts = {}
        for _, itemId in ipairs(items) do
          local nm = ns.Questie:ItemName(itemId)
          table.insert(parts, nm and (nm .. " (" .. itemId .. ")") or tostring(itemId))
        end
        page._itemNote:SetText("Нужны: " .. table.concat(parts, ", "))
        page._giveQuestItems:SetEnabledLook(true)
      else
        page._itemNote:SetText("Для этого квеста предметы не требуются.")
        page._giveQuestItems:SetEnabledLook(false)
      end
    end
  end

  if targetLine then
    local name, isPlayer = ns.TargetDisplayName()
    if name and isPlayer then
      targetLine:SetText("Команды применятся к игроку |cffffcc00" .. name .. "|r")
    elseif name then
      targetLine:SetText("Выделено существо — команды квестов применятся к вам")
    else
      targetLine:SetText("Команды применятся к вам")
    end
  end
end

ns.RegisterPage(page)
