-- Compat.lua — то, чего нет в клиенте 3.3.5a.
--
-- Загружается первым. Каждая заплатка ставится только если метода
-- действительно нет: тогда аддон переживёт и запуск на более новом клиенте.

local ADDON, ns = ...

-- SetShown / IsShown появились в Cataclysm (4.0). В 3.3.5a есть только
-- Show/Hide и IsVisible. Добавляем к каждому типу объекта, который мы
-- реально используем: Frame, Button, Texture, FontString, EditBox, Slider.
local function patchShown(obj)
  local mt = getmetatable(obj)
  if not mt or not mt.__index then return end
  local index = mt.__index
  if type(index) ~= "table" then return end
  if index.SetShown then return end

  index.SetShown = function(self, show)
    if show then self:Show() else self:Hide() end
  end
end

do
  local probe = CreateFrame("Frame")
  patchShown(probe)
  patchShown(CreateFrame("Button", nil, probe))
  patchShown(CreateFrame("EditBox", nil, probe))
  patchShown(CreateFrame("Slider", nil, probe))
  patchShown(CreateFrame("ScrollFrame", nil, probe))
  patchShown(probe:CreateTexture())
  patchShown(probe:CreateFontString())
  probe:Hide()
end

-- IsInRaid / IsInGroup — тоже из 4.0. В 3.3.5a считаем по членам.
if not IsInRaid then
  function IsInRaid()
    return (GetNumRaidMembers() or 0) > 0
  end
end

if not IsInGroup then
  function IsInGroup()
    return (GetNumRaidMembers() or 0) > 0 or (GetNumPartyMembers() or 0) > 0
  end
end

-- wipe есть в 3.3.5a, но подстрахуемся.
if not wipe then
  function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
  end
end
