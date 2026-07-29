-- Slash.lua — команды чата.
local ADDON, ns = ...

SLASH_GMCOMMANDER1 = "/gm"
SLASH_GMCOMMANDER2 = "/gmc"
SLASH_GMCOMMANDER3 = "/gmcommander"

local function help()
  ns.Print("команды:")
  local lines = {
    { "/gm",             "открыть или закрыть панель" },
    { "/gm tp Даларан",  "телепорт по названию (русскому или из базы)" },
    { "/gm item 6948 5", "выдать предмет" },
    { "/gm gold 500",    "выдать золото" },
    { "/gm lvl 80",      "поднять до уровня" },
    { "/gm quest 1234",  "прыжок к выдающему квест" },
    { "/gm bar",         "показать или скрыть полосу" },
    { "/gm <команда>",   "любая GM-команда без точки" },
  }
  for _, l in ipairs(lines) do
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffcc00%-18s|r %s", l[1], l[2]))
  end
end

--- Найти точку телепортации по русскому или английскому названию.
local function findTele(query)
  local q = query:lower()

  local function scan(list)
    -- Сначала точное совпадение, потом вхождение — иначе «Даларан»
    -- рискует найти «DalaranCrater».
    for _, e in ipairs(list) do
      if (e.ru or ""):lower() == q or (e.tele or ""):lower() == q then
        return e
      end
    end
    for _, e in ipairs(list) do
      if (e.ru or ""):lower():find(q, 1, true)
         or (e.tele or ""):lower():find(q, 1, true) then
        return e
      end
    end
  end

  local found = scan(ns.TELE_CITIES)
  if found then return found end

  for _, groups in ipairs({ ns.TELE_DUNGEONS, ns.TELE_RAIDS }) do
    for _, g in ipairs(groups) do
      found = scan(g.list)
      if found then return found end
    end
  end

  return nil
end

SlashCmdList["GMCOMMANDER"] = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local lower = msg:lower()

  if msg == "" then
    ns.ToggleUI()
    return
  end

  if lower == "help" or lower == "?" or lower == "помощь" then
    help()
    return
  end

  if lower == "bar" then
    ns.db.bar = not ns.db.bar
    ns.Bar:SetShown(ns.db.bar)
    ns.Print("полоса " .. (ns.db.bar and "показана" or "скрыта") .. ".")
    return
  end

  -- Телепорт по названию.
  local teleArg = msg:match("^[Tt][Pp]%s+(.+)$") or msg:match("^тп%s+(.+)$")
  if teleArg then
    local found = findTele(teleArg)
    if found then
      ns.Teleport(found)
    else
      -- Не нашли в своих списках — отдадим серверу как есть: в
      -- game_tele почти две тысячи точек, наш перечень покрывает
      -- только популярные.
      ns.Run("teleport " .. teleArg)
      ns.Print("Пробую как имя из базы: " .. teleArg)
    end
    return
  end

  -- Предмет.
  local itemId, itemCount = msg:match("^[Ii][Tt][Ee][Mm]%s+(%d+)%s*(%d*)$")
  if itemId then
    ns.GiveItem(tonumber(itemId), tonumber(itemCount) or 1)
    ns.Print("Выдано: предмет " .. itemId .. ".")
    return
  end

  -- Золото.
  local gold = msg:match("^[Gg][Oo][Ll][Dd]%s+(%d+)$") or msg:match("^золото%s+(%d+)$")
  if gold then
    ns.GiveMoney(tonumber(gold) * 10000)
    return
  end

  -- Уровень.
  local lvl = msg:match("^[Ll][Vv][Ll]%s+(%d+)$") or msg:match("^уровень%s+(%d+)$")
  if lvl then
    ns.SetLevel(tonumber(lvl))
    return
  end

  -- Квест.
  local quest = msg:match("^[Qq][Uu][Ee][Ss][Tt]%s+(%d+)$") or msg:match("^квест%s+(%d+)$")
  if quest then
    ns.GoQuest(tonumber(quest), "starter")
    return
  end

  -- Всё остальное — как есть на сервер.
  ns.Run(msg)
end
