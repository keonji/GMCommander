-- wow_stub.lua — минимальная эмуляция клиентского API 3.3.5a.
--
-- Задача не в том, чтобы воспроизвести WoW, а в том, чтобы поймать
-- реальные ошибки загрузки: обращение к nil, опечатки в именах методов,
-- неверный порядок файлов, использование API, которого в 3.3.5a нет.
--
-- Поэтому стаб намеренно строгий: он НЕ определяет SetShown, IsInRaid и
-- прочие методы из более новых клиентов. Если аддон их вызовет напрямую,
-- минуя Compat.lua, тест упадёт — именно этого мы и хотим.

local M = {}

-- Реестр событий: frame -> { event = true }
local registered = {}
M.frames = {}

local function noop() end

local Texture = {}
Texture.__index = Texture
function Texture.new(parent)
  return setmetatable({ _parent = parent, _shown = true, _points = {} }, Texture)
end
function Texture:SetTexture() end
function Texture:SetVertexColor() end
function Texture:SetAllPoints() end
function Texture:SetPoint(...) table.insert(self._points, { ... }) end
function Texture:GetPoint() return self._points[1] and unpack(self._points[1]) end
function Texture:ClearAllPoints() self._points = {} end
function Texture:SetWidth(w) self._w = w end
function Texture:SetHeight(h) self._h = h end
function Texture:GetWidth() return self._w or 100 end
function Texture:GetHeight() return self._h or 20 end
function Texture:SetTexCoord() end
function Texture:SetAlpha() end
function Texture:Show() self._shown = true end
function Texture:Hide() self._shown = false end
function Texture:IsVisible() return self._shown end

local FontString = setmetatable({}, { __index = Texture })
FontString.__index = FontString
function FontString.new(parent)
  return setmetatable({ _parent = parent, _shown = true, _points = {}, _text = "" }, FontString)
end
function FontString:SetFont() end
function FontString:SetFontObject() end
function FontString:SetTextColor() end
function FontString:SetText(t) self._text = tostring(t or "") end
function FontString:GetText() return self._text end
function FontString:SetJustifyH() end
function FontString:SetJustifyV() end
function FontString:GetStringWidth() return #self._text * 6 end

local Frame = {}
Frame.__index = Frame

function Frame.new(ftype, name, parent)
  local f = setmetatable({
    _type = ftype, _name = name, _parent = parent,
    _shown = true, _points = {}, _scripts = {}, _children = {},
    _w = 100, _h = 20, _scale = 1, _alpha = 1,
  }, Frame)
  if name then _G[name] = f end
  table.insert(M.frames, f)
  return f
end

function Frame:CreateTexture() return Texture.new(self) end
function Frame:CreateFontString() return FontString.new(self) end

function Frame:SetPoint(...) table.insert(self._points, { ... }) end
function Frame:GetPoint()
  local p = self._points[1]
  if not p then return "CENTER", nil, "CENTER", 0, 0 end
  return p[1], p[2], p[3], p[4] or 0, p[5] or 0
end
function Frame:ClearAllPoints() self._points = {} end
function Frame:SetAllPoints() end
function Frame:SetWidth(w) self._w = w end
function Frame:SetHeight(h) self._h = h end
function Frame:GetWidth() return self._w end
function Frame:GetHeight() return self._h end
function Frame:SetScale(s) self._scale = s end
function Frame:GetScale() return self._scale end
function Frame:SetAlpha(a) self._alpha = a end
function Frame:GetAlpha() return self._alpha end
function Frame:Show() self._shown = true end
function Frame:Hide() self._shown = false end
function Frame:IsShown() return self._shown end
function Frame:IsVisible() return self._shown end
function Frame:EnableMouse() end
function Frame:EnableMouseWheel() end
function Frame:SetMovable() end
function Frame:SetClampedToScreen() end
function Frame:SetFrameStrata() end
function Frame:SetFrameLevel(v) self._level = v end
function Frame:GetFrameLevel() return self._level or 1 end
function Frame:SetToplevel() end
function Frame:StartMoving() end
function Frame:StopMovingOrSizing() end
function Frame:RegisterForDrag() end
function Frame:RegisterForClicks() end
function Frame:SetScrollChild(c) self._child = c end
function Frame:SetVerticalScroll(v) self._scroll = v end
function Frame:GetVerticalScroll() return self._scroll or 0 end
function Frame:SetOrientation() end
function Frame:SetMinMaxValues() end
function Frame:SetValueStep() end
function Frame:SetValue(v) self._value = v end
function Frame:GetValue() return self._value or 0 end
function Frame:SetThumbTexture() end
function Frame:SetAutoFocus() end
function Frame:HasFocus() return false end
function Frame:ClearFocus() end
function Frame:SetTextColor() end
function Frame:SetFontObject() end
function Frame:SetText(t) self._text = tostring(t or "") end
function Frame:GetText() return self._text or "" end

function Frame:SetScript(name, fn) self._scripts[name] = fn end
function Frame:GetScript(name) return self._scripts[name] end
function Frame:HookScript(name, fn) self._scripts[name] = fn end

function Frame:RegisterEvent(e)
  registered[self] = registered[self] or {}
  registered[self][e] = true
end
function Frame:UnregisterEvent(e)
  if registered[self] then registered[self][e] = nil end
end
function Frame:UnregisterAllEvents() registered[self] = nil end

--- Разослать событие всем подписчикам.
function M.Fire(event, ...)
  for frame, events in pairs(registered) do
    if events[event] then
      local fn = frame._scripts.OnEvent
      if fn then fn(frame, event, ...) end
    end
  end
end

--- Прогнать OnUpdate у всех фреймов (эмуляция кадра).
function M.Tick(elapsed)
  for _, f in ipairs(M.frames) do
    local fn = f._scripts.OnUpdate
    if fn then fn(f, elapsed or 0.05) end
  end
end

--- Кликнуть по фрейму.
function M.Click(frame, button)
  local fn = frame._scripts.OnClick
  if fn then fn(frame, button or "LeftButton") end
end

------------------------------------------------------------------ глобалы

_G.CreateFrame = function(ftype, name, parent) return Frame.new(ftype, name, parent) end

_G.UIParent = Frame.new("Frame", "UIParent")
_G.GameTooltip = Frame.new("GameTooltip", "GameTooltip")
GameTooltip.SetOwner = noop
GameTooltip.AddLine = noop
_G.UISpecialFrames = {}

_G.DEFAULT_CHAT_FRAME = { messages = {} }
function DEFAULT_CHAT_FRAME:AddMessage(m) table.insert(self.messages, m) end

_G.GetTime = function() return M.now or 0 end
M.now = 0

-- Состояние «игрового мира», которым управляют тесты.
M.world = {
  player = { name = "Админ", level = 12, class = "WARRIOR" },
  group  = {},   -- список { name, level, class, dead, online }
  raid   = false,
}

-- Разрешение unit-id в запись мира.
--   partyN -> group[N]        (вас в party-юнитах нет)
--   raid1  -> вы, raidN -> group[N-1]   (рейд включает вас первым)
local function resolve(unit)
  if not unit then return nil end
  if unit == "player" then return M.world.player end
  if unit == "target" then return M.world.target end
  local i = tonumber(unit:match("%d+") or "")
  if not i then return nil end
  if unit:match("^raid") then
    if i == 1 then return M.world.player end
    return M.world.group[i - 1]
  end
  return M.world.group[i]
end
M.resolve = resolve

_G.UnitName = function(unit)
  local m = resolve(unit)
  return m and m.name
end

_G.UnitClass = function(unit)
  local m = resolve(unit)
  if not m then return nil, nil end
  return m.class, m.class
end

_G.UnitLevel = function(unit)
  local m = resolve(unit)
  return m and m.level or 0
end

_G.UnitExists = function(unit)
  return resolve(unit) ~= nil
end

-- Цель может быть и NPC: у записи мира тогда стоит isNPC = true.
-- Это принципиально для команд .die и .respawn, которые работают по
-- любому юниту, тогда как .summon — только по игроку.
_G.UnitIsPlayer = function(unit)
  local m = resolve(unit)
  if not m then return false end
  return not m.isNPC
end

_G.UnitIsUnit = function(a, b)
  local na, nb = UnitName(a), UnitName(b)
  return na ~= nil and na == nb
end
_G.UnitIsDeadOrGhost = function(unit)
  local m = resolve(unit)
  return m and m.dead or false
end
_G.UnitIsConnected = function(unit)
  local m = resolve(unit)
  if not m then return true end
  return m.online ~= false
end

-- В настоящем 3.3.5a: GetNumPartyMembers НЕ считает вас, а
-- GetNumRaidMembers — считает. Воспроизводим ровно так, иначе тесты
-- разойдутся с игрой на единицу.
_G.GetNumPartyMembers = function()
  return M.world.raid and 0 or #M.world.group
end
_G.GetNumRaidMembers = function()
  return M.world.raid and (#M.world.group + 1) or 0
end

-- Лидерство и конвертация в рейд.
M.world.leader = true
M.converted = false

_G.IsPartyLeader = function() return M.world.leader end

-- В рейде GetNumRaidMembers включает и вас, поэтому ростер рейда — это
-- вы плюс группа. Ранг 2 = лидер.
_G.GetRaidRosterInfo = function(i)
  if i == 1 then
    return M.world.player.name, M.world.leader and 2 or 0
  end
  local m = M.world.group[i - 1]
  if not m then return nil end
  return m.name, m.rank or 0
end

_G.ConvertToRaid = function()
  M.converted = true
  M.world.raid = true
end

_G.TargetUnit = function(unit)
  M.world.target = resolve(unit)
end

-- Всё, что уходит «на сервер», собираем сюда для проверок.
M.sent = {}
_G.SendChatMessage = function(text, channel, lang, to)
  table.insert(M.sent, { text = text, channel = channel, to = to })
end
_G.SendAddonMessage = function(prefix, text, channel, to)
  table.insert(M.sent, { addon = true, prefix = prefix, text = text, channel = channel, to = to })
end

_G.ReloadUI = function() M.reloaded = true end

-- Подстановка ссылок по Shift+клику. Клиент вызывает эту глобальную
-- функцию, обходя открытые фреймы; аддон её перехватывает.
_G.ChatEdit_InsertLink = function(link)
  M.lastLink = link
  return false
end

_G.RAID_CLASS_COLORS = {
  WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
  PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
  HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
  ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
  PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
  DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
  SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
  MAGE    = { r = 0.41, g = 0.80, b = 0.94 },
  WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
  DRUID   = { r = 1.00, g = 0.49, b = 0.04 },
}

_G.SLASH_BOTCOMMANDER1 = nil
_G.SlashCmdList = {}

_G.tinsert = table.insert
_G.tremove = table.remove
_G.unpack = unpack or table.unpack
_G.pairs, _G.ipairs = pairs, ipairs

-- wipe в 3.3.5a есть — воспроизводим.
_G.wipe = function(t)
  for k in pairs(t) do t[k] = nil end
  return t
end

-- А вот SetShown / IsInRaid / IsInGroup в 3.3.5a НЕТ. Намеренно не
-- определяем: их обязан обеспечить Compat.lua аддона. Если аддон
-- вызовет их напрямую в обход Compat — тест упадёт, и это правильно.
_G.IsInRaid = nil
_G.IsInGroup = nil

return M
