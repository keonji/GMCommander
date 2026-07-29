-- Проверка символов, недопустимых в русском клиенте 3.3.5a.
--
-- Клиент читает Lua как UTF-8, но выводит текст шрифтом с кодировкой
-- CP1251. Символы, которых в CP1251 нет, рисуются как случайные буквы:
-- знак умножения × (U+00D7) превращается в «Ч», стрелка → тоже.
-- Тире, кавычки-лапки и middot в CP1251 есть — они работают.
--
-- Список именно запрещённых, а не «всех не-ASCII»: кириллица в
-- интерфейсе нужна, и запрещать её нельзя.
local BANNED = {
  ["\195\151"] = "× (U+00D7) -> в клиенте «Ч», используйте латинскую x",
  ["\226\134\146"] = "→ (U+2192) нет в CP1251, используйте ->",
  ["\226\134\144"] = "← (U+2190) нет в CP1251, используйте <-",
  ["\226\156\147"] = "✓ (U+2713) нет в CP1251",
  ["\226\128\162"] = "• (U+2022) нет в CP1251, используйте -",
  ["\194\183"]     = nil,  -- · есть в CP1251, разрешено
}

local root = arg[1] or "."
local found = 0

local function scan(path)
  local fh = io.open(path, "r")
  if not fh then return end
  local lineNo = 0
  for line in fh:lines() do
    lineNo = lineNo + 1
    for bytes, why in pairs(BANNED) do
      if why and line:find(bytes, 1, true) then
        print(string.format("  %s:%d  %s", path, lineNo, why))
        found = found + 1
      end
    end
  end
  fh:close()
end

local pipe = io.popen('find "' .. root .. '" -name "*.lua" -o -name "*.toc"')
for path in pipe:lines() do scan(path) end
pipe:close()

if found == 0 then
  print("  \27[32mok\27[0m   недопустимых символов нет")
  os.exit(0)
else
  print(string.format("  \27[31mFAIL\27[0m найдено %d вхождений", found))
  os.exit(1)
end
