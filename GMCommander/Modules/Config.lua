-- Config.lua — SavedVariables и дефолты.
local ADDON, ns = ...

ns.DEFAULTS = {
  point   = "CENTER",
  x       = 0,
  y       = 0,
  scale   = 1.0,
  alpha   = 0.95,
  locked  = false,
  lastTab = 1,

  bar       = true,
  barPoint  = "CENTER",
  barX      = 0,
  barY      = -200,

  -- Кому шептать команды, когда персонаж мёртв: канал /say клиент в
  -- этом состоянии блокирует, а /whisper работает.
  --
  -- Пусто = шёпот самому себе. Это надёжнее любого чужого имени: вы
  -- всегда онлайн, а сервер всё равно перехватывает команду по точке
  -- до всякой проверки получателя (ChatHandler.cpp:307) — то есть
  -- сообщение никому не приходит и в чате не появляется.
  deadWhisperTarget = "",

  confirmRisky = true,   -- спрашивать перед необратимым
  echo         = true,   -- показывать отправленные команды
  throttle     = 0.30,   -- пауза между командами, сек
  applyToTarget = true,  -- команды идут выделенной цели, если она есть

  favorites = {},        -- избранные телепорты: { tele = "...", ru = "..." }
  history   = {},        -- последние выданные предметы
  toggles   = {},        -- состояние переключателей: "cheat god" -> true

}

local function fill(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      fill(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function ns.InitDB()
  GMCommanderDB = GMCommanderDB or {}
  fill(GMCommanderDB, ns.DEFAULTS)
  ns.db = GMCommanderDB
end
