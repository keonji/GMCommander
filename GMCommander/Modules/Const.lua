-- Const.lua — таблицы команд и точек телепортации.
--
-- Все команды сверены с исходниками AzerothCore (src/server/scripts/
-- Commands/cs_*.cpp, июль 2026). Имена точек телепортации взяты из
-- таблицы game_tele (data/sql/base/db_world/game_tele.sql) — сервер
-- принимает `.tele <name>` ровно по этим именам.

local ADDON, ns = ...

ns.VERSION = "1.0.2"

--------------------------------------------------------------------------
-- Быстрые действия
--------------------------------------------------------------------------

-- Действия над собой или целью.
--
-- needsTarget задаёт, что команда без выделения бессмысленна:
--   "any"      — любой юнит (игрок или NPC), как у `.die`
--   "creature" — только существо, как у `.respawn`
--   "player"   — только персонаж, как у `.summon`
-- Аддон в этом случае предупредит сам: сервер ответил бы лишь строкой
-- в чат, и нажатие выглядело бы как «ничего не произошло».
ns.ACTIONS = {
  {
    cmd = "revive", ru = "Воскресить", target = true,
    icon = "Interface\\Icons\\Spell_Holy_Resurrection",
    desc = "Поднять игрока — цель или себя, если цели нет. " ..
           "Для существ используйте «Оживить NPC».",
  },
  {
    -- .respawn работает только по существу и только если оно мертво
    -- (cs_misc.cpp:2728). Для игроков есть отдельная .revive.
    cmd = "respawn", ru = "Оживить NPC", needsTarget = "creature",
    icon = "Interface\\Icons\\Ability_Hunter_BeastSoothe",
    desc = "Возродить выделенное мёртвое существо.",
  },
  {
    -- .die требует выделения любого юнита; без цели сервер отвечает
    -- «выберите персонажа или существо» и ничего не делает
    -- (cs_misc.cpp:1211). Своего персонажа она НЕ убивает.
    cmd = "die", ru = "Убить", needsTarget = "any", risky = true,
    icon = "Interface\\Icons\\Spell_Shadow_DeathCoil",
    desc = "Мгновенно убить выделенную цель — игрока или существо.",
  },
  {
    -- .summon принимает имя игрока либо берёт выделенного
    -- (cs_misc.cpp:974). На NPC не действует.
    cmd = "summon", ru = "Призвать к себе", needsTarget = "player",
    icon = "Interface\\Icons\\Spell_Shadow_Teleport",
    desc = "Перенести выделенного игрока к вам.",
  },
  {
    cmd = "appear", ru = "Прыгнуть к цели", needsTarget = "player",
    icon = "Interface\\Icons\\Spell_Arcane_Blink",
    desc = "Переместиться к выделенному игроку.",
  },
  {
    cmd = "cheat god on", ru = "Бессмертие", toggle = "cheat god",
    icon = "Interface\\Icons\\Spell_Holy_DevineAegis",
    desc = "Урон по вам перестаёт проходить.",
  },
  {
    cmd = "gm fly on", ru = "Полёт", toggle = "gm fly",
    icon = "Interface\\Icons\\Spell_Magic_FeatherFall",
    desc = "Свободный полёт в любой локации.",
  },
  {
    cmd = "gm on", ru = "Режим ГМ", toggle = "gm",
    icon = "Interface\\Icons\\INV_Misc_Rune_06",
    desc = "Невидимость для игроков, неуязвимость, доступ ко всему.",
  },
  {
    cmd = "cheat casttime on", ru = "Мгновенный каст", toggle = "cheat casttime",
    icon = "Interface\\Icons\\Spell_Nature_TimeStop",
    desc = "Заклинания читаются без времени каста и отката.",
  },
  {
    cmd = "cheat cooldown on", ru = "Без откатов", toggle = "cheat cooldown",
    icon = "Interface\\Icons\\Spell_Nature_Sleep",
    desc = "Способности без времени восстановления.",
  },
  {
    cmd = "cheat power on", ru = "Без ресурса", toggle = "cheat power",
    icon = "Interface\\Icons\\Spell_Shadow_ManaBurn",
    desc = "Заклинания не тратят ману, ярость и энергию.",
  },
  {
    cmd = "unstuck self", ru = "Вытащить",
    icon = "Interface\\Icons\\Spell_Arcane_PortalStormWind",
    desc = "Переместить к ближайшему кладбищу, если застряли в текстурах.",
  },
  {
    cmd = "gear repair", ru = "Починить", target = true,
    icon = "Interface\\Icons\\Trade_BlackSmithing",
    desc = "Полностью починить всю экипировку.",
  },
  {
    cmd = "cheat waterwalk on", ru = "Хождение по воде", toggle = "cheat waterwalk",
    icon = "Interface\\Icons\\Spell_Frost_WindWalkOn",
    desc = "Ходить по поверхности воды.",
  },
  {
    cmd = "cheat taxi on", ru = "Все полёты", toggle = "cheat taxi",
    icon = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    desc = "Открыть все точки полётов на карте.",
  },
  {
    cmd = "maxskill", ru = "Макс. навыки",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    desc = "Поднять все изученные навыки до потолка вашего уровня.",
  },
  {
    cmd = "cheat explore 1", ru = "Открыть карту",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    desc = "Открыть всю карту мира.",
  },
}

--------------------------------------------------------------------------
-- Деньги
--------------------------------------------------------------------------

-- Сервер принимает медь: 1 золото = 10000 меди.
ns.MONEY_STEPS = {
  { ru = "10з",    copper = 10 * 10000 },
  { ru = "100з",   copper = 100 * 10000 },
  { ru = "1000з",  copper = 1000 * 10000 },
  { ru = "5000з",  copper = 5000 * 10000 },
}

--------------------------------------------------------------------------
-- Скорость
--------------------------------------------------------------------------

-- `.modify speed N` меняет разом бег, полёт и плавание
-- (cs_modify.cpp:44 — пустой подключ ведёт на HandleModifyASpeedCommand).
-- Сервер принимает от 0.1 до 50.
ns.SPEED_STEPS = { 1, 3, 5, 10 }
ns.SPEED_MIN, ns.SPEED_MAX = 0.1, 50

--------------------------------------------------------------------------
-- Уровни
--------------------------------------------------------------------------

-- `.character levelup N` принимает ПРИРОСТ, а не итоговый уровень
-- (cs_character.cpp:775: newlevel = oldlevel + level). Отрицательное
-- значение понижает.
ns.LEVEL_STEPS = { 1, 5, 10, -1 }
ns.MAX_LEVEL = 80

--------------------------------------------------------------------------
-- Профессии
--------------------------------------------------------------------------

-- Профессии. spell — ID заклинания ПЕРВОГО ранга («ученик»).
--
-- Почему первого, а не высшего: `.learn <id> all` учит всю цепочку
-- рангов сразу (cs_learn.cpp:70, параметр allRanks), а ID первого
-- ранга — исходные значения из Классики, они не менялись между
-- дополнениями. ID грандмастерских рангов пришлось бы брать из
-- клиентского DBC, которого в репозитории сервера нет, то есть
-- проверить их локально невозможно.
--
-- Обучение идёт как `.learn <spell> all` — см. ns.LearnProfession.
ns.PROFESSIONS = {
  { ru = "Кузнечное дело",   spell = 2018,  icon = "Interface\\Icons\\Trade_BlackSmithing" },
  { ru = "Кожевничество",    spell = 2108,  icon = "Interface\\Icons\\Trade_LeatherWorking" },
  { ru = "Портняжное дело",  spell = 3908,  icon = "Interface\\Icons\\Trade_Tailoring" },
  { ru = "Инженерия",        spell = 4036,  icon = "Interface\\Icons\\Trade_Engineering" },
  { ru = "Алхимия",          spell = 2259,  icon = "Interface\\Icons\\Trade_Alchemy" },
  { ru = "Наложение чар",    spell = 7411,  icon = "Interface\\Icons\\Trade_Engraving" },
  { ru = "Ювелирное дело",   spell = 25229, icon = "Interface\\Icons\\INV_Misc_Gem_01" },
  { ru = "Начертание",       spell = 45357, icon = "Interface\\Icons\\INV_Inscription_Tradeskill01" },
  { ru = "Горное дело",      spell = 2575,  icon = "Interface\\Icons\\Trade_Mining" },
  { ru = "Травничество",     spell = 2366,  icon = "Interface\\Icons\\Trade_Herbalism" },
  { ru = "Снятие шкур",      spell = 8613,  icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
  { ru = "Кулинария",        spell = 2550,  icon = "Interface\\Icons\\INV_Misc_Food_15" },
  { ru = "Первая помощь",    spell = 3273,  icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
  { ru = "Рыбная ловля",     spell = 7620,  icon = "Interface\\Icons\\Trade_Fishing" },
}

-- Массовое обучение — команды ядра (cs_learn.cpp).
ns.LEARN_BULK = {
  { cmd = "learn all my class",   ru = "Все заклинания класса",
    desc = "Все доступные вашему классу заклинания по уровню." },
  { cmd = "learn all my talents", ru = "Все таланты",
    desc = "Разложить все очки талантов." },
  { cmd = "learn all my trainer", ru = "Всё у тренера",
    desc = "Всё, чему научил бы классовый тренер." },
  { cmd = "learn all lang",       ru = "Все языки",
    desc = "Понимать речь обеих фракций." },
  { cmd = "learn all recipes",    ru = "Все рецепты",
    desc = "Все рецепты изученных профессий." },
  { cmd = "learn all crafts",     ru = "Все профессии",
    desc = "Выучить сразу все профессии на максимум." },
  { cmd = "learn all default",    ru = "Стартовый набор",
    desc = "Расовые и стартовые умения." },
}

--------------------------------------------------------------------------
-- Телепортация
--------------------------------------------------------------------------

-- Имена совпадают с полем `name` в game_tele. Регистр не важен.

ns.TELE_CITIES = {
  { tele = "Stormwind",      ru = "Штормград",        side = "A" },
  { tele = "Ironforge",      ru = "Стальгорн",        side = "A" },
  { tele = "Darnassus",      ru = "Дарнас",           side = "A" },
  { tele = "TheExodar",      ru = "Экзодар",          side = "A" },
  { tele = "Orgrimmar",      ru = "Оргриммар",        side = "H" },
  { tele = "Undercity",      ru = "Подгород",         side = "H" },
  { tele = "ThunderBluff",   ru = "Громовой Утёс",    side = "H" },
  { tele = "SilvermoonCity", ru = "Луносвет",         side = "H" },
  { tele = "Shattrath",      ru = "Шаттрат",          side = "N" },
  { tele = "Dalaran",        ru = "Даларан",          side = "N" },
  { tele = "BootyBay",       ru = "Пиратская Бухта",  side = "N" },
  { tele = "Gadgetzan",      ru = "Прибамбасск",      side = "N" },
}

-- Подземелья по дополнениям. Порядок — примерно по уровню.
ns.TELE_DUNGEONS = {
  {
    era = "Классика",
    list = {
      { tele = "TheDeadmines",     ru = "Мертвые копи",        lvl = "17-26" },
      { tele = "WailingCaverns",   ru = "Пещеры Стенаний",     lvl = "17-24" },
      { tele = "ShadowFangKeep",   ru = "Крепость Темного Клыка", lvl = "22-30" },
      { tele = "TheStockade",      ru = "Тюрьма",              lvl = "24-32" },
      { tele = "Gnomeregan",       ru = "Гномреган",           lvl = "29-38" },
      { tele = "RazorfenKraul",    ru = "Лабиринты Иглошкурых", lvl = "29-38" },
      { tele = "ScarletMonastery", ru = "Монастырь Алого ордена", lvl = "34-45" },
      { tele = "RazorfenDowns",    ru = "Курганы Иглошкурых",  lvl = "37-46" },
      { tele = "Uldaman",          ru = "Ульдаман",            lvl = "41-51" },
      { tele = "ZulFarrak",        ru = "Зул'Фаррак",          lvl = "44-54" },
      { tele = "Maraudon",         ru = "Мародон",             lvl = "46-55" },
      { tele = "TheSunkenTemple",  ru = "Затонувший храм",     lvl = "50-60" },
      { tele = "BlackrockDepths",  ru = "Глубины Черной горы", lvl = "52-60" },
      { tele = "BlackrockSpire",   ru = "Пик Черной горы",     lvl = "55-60" },
      { tele = "DireMaulWest",     ru = "Забытый город (З)",   lvl = "55-60" },
      { tele = "Stratholme",       ru = "Стратхольм",          lvl = "58-60" },
      { tele = "Scholomance",      ru = "Некроситет",          lvl = "58-60" },
    },
  },
  {
    era = "Запределье",
    list = {
      { tele = "HellfireRamparts",   ru = "Бастионы Адского Пламени", lvl = "59-62" },
      { tele = "TheBloodFurnace",    ru = "Кузня Крови",         lvl = "60-63" },
      { tele = "TheSlavePens",       ru = "Узилище",             lvl = "60-63" },
      { tele = "ManaTombs",          ru = "Гробницы Маны",       lvl = "62-65" },
      { tele = "AuchenaiCrypts",     ru = "Аукенайские гробницы", lvl = "63-66" },
      { tele = "SethekkHalls",       ru = "Сетеккские залы",     lvl = "65-68" },
      { tele = "ShadowLabyrinth",    ru = "Лабиринт Теней",      lvl = "67-70" },
      { tele = "TheMechanar",        ru = "Механар",             lvl = "68-70" },
      { tele = "TheBotanica",        ru = "Ботаника",            lvl = "68-70" },
      { tele = "TheArcatraz",        ru = "Аркатрац",            lvl = "68-70" },
      { tele = "MagistersTerrace",   ru = "Терраса Магистров",   lvl = "68-70" },
    },
  },
  {
    era = "Нордскол",
    list = {
      { tele = "UtgardeKeep",     ru = "Крепость Утгард",      lvl = "69-72" },
      { tele = "TheNexus",        ru = "Нексус",               lvl = "71-73" },
      { tele = "AzjolNerub",      ru = "Азжол-Неруб",          lvl = "72-74" },
      { tele = "DrakTharonKeep",  ru = "Крепость Драк'Тарон",  lvl = "74-76" },
      { tele = "TheVioletHold",   ru = "Аметистовая крепость", lvl = "75-77" },
      { tele = "Gundrak",         ru = "Гундрак",              lvl = "76-78" },
      { tele = "UtgardePinnacle", ru = "Вершина Утгард",       lvl = "79-80" },
    },
  },
}

ns.TELE_RAIDS = {
  {
    era = "Классика",
    list = {
      { tele = "MoltenCore",         ru = "Огненные Недра",     size = "40" },
      { tele = "OnyxiasLair",        ru = "Логово Ониксии",     size = "40" },
      { tele = "BlackwingLair",      ru = "Логово Крыла Тьмы",  size = "40" },
      { tele = "ZulGurub",           ru = "Зул'Гуруб",          size = "20" },
      { tele = "TheRuinsOfAhnQiraj", ru = "Руины Ан'Киража",    size = "20" },
      { tele = "TheTempleOfAhnQiraj", ru = "Храм Ан'Киража",    size = "40" },
      { tele = "Naxxramas",          ru = "Наксрамас",          size = "10/25" },
    },
  },
  {
    era = "Запределье",
    list = {
      { tele = "Karazhan",            ru = "Каражан",            size = "10" },
      { tele = "GruulsLair",          ru = "Логово Груула",      size = "25" },
      { tele = "MagtheridonsLair",    ru = "Логово Магтеридона", size = "25" },
      { tele = "SerpentshrineCavern", ru = "Змеиное святилище",  size = "25" },
      { tele = "TempestKeep",         ru = "Крепость Бурь",      size = "25" },
      { tele = "HyjalSummit",         ru = "Вершина Хиджала",    size = "25" },
      { tele = "BlackTemple",         ru = "Черный храм",        size = "25" },
      { tele = "SunwellPlateau",      ru = "Плато Солнечного Колодца", size = "25" },
      { tele = "ZulAman",             ru = "Зул'Аман",           size = "10" },
    },
  },
  {
    era = "Нордскол",
    list = {
      { tele = "VaultOfArchavon",   ru = "Крепость Архавон",     size = "10/25" },
      { tele = "TheObsidianSanctum", ru = "Обсидиановое святилище", size = "10/25" },
      { tele = "TheEyeOfEternity",  ru = "Око Вечности",         size = "10/25" },
      { tele = "UlduarRaid",        ru = "Ульдуар",              size = "10/25" },
      { tele = "TrialOfTheCrusader", ru = "Испытание крестоносца", size = "10/25" },
      { tele = "IcecrownCitadelRaid", ru = "Цитадель Ледяной Короны", size = "10/25" },
      { tele = "TheRubySanctum",    ru = "Рубиновое святилище",  size = "10/25" },
    },
  },
}

--------------------------------------------------------------------------
-- Готовые наборы предметов
--------------------------------------------------------------------------

-- ID проверены по item_template 3.3.5a.
ns.ITEM_KITS = {
  {
    ru = "Сумки 22 ячейки",
    desc = "Четыре вместительные сумки.",
    items = { { id = 41599, count = 4 } },   -- Frostweave Bag
  },
  {
    ru = "Еда и вода",
    desc = "Восстановление здоровья и маны, по 20 штук.",
    items = { { id = 43518, count = 20 }, { id = 43523, count = 20 } },
  },
  {
    ru = "Зелья",
    desc = "Лечение и мана, по 20 штук.",
    items = { { id = 33447, count = 20 }, { id = 33448, count = 20 } },
  },
  {
    ru = "Реагенты",
    desc = "Расходники для заклинаний воскрешения и порталов.",
    items = { { id = 17033, count = 40 }, { id = 17031, count = 40 } },
  },
  {
    -- Маунты во фракциях разные: волк ордынский, грифон альянсовый.
    -- Противоположной фракции предмет упадёт в сумку, но не сработает.
    ru = "Наземный маунт",
    desc = "Быстрый волк (Орда) — 100% скорости.",
    items = { { id = 18796, count = 1 } },   -- Horn of the Swift Brown Wolf
  },
  {
    ru = "Летающий маунт",
    desc = "Быстрый грифон (Альянс) — 280% скорости.",
    items = { { id = 25473, count = 1 } },   -- Swift Blue Gryphon
  },
  {
    ru = "Камень возвращения",
    desc = "На случай, если потеряли.",
    items = { { id = 6948, count = 1 } },
  },
  {
    ru = "Ключи-отмычки",
    desc = "Скелетный ключ для замков.",
    items = { { id = 43853, count = 5 } },
  },
}

--------------------------------------------------------------------------
-- Квесты
--------------------------------------------------------------------------

-- Все четыре команды из cs_quest.cpp работают по выделенному игроку
-- (или по вам, если цели нет) и принимают ID квеста.
ns.QUEST_ACTIONS = {
  { cmd = "add",      ru = "Выдать",     icon = "Interface\\Icons\\INV_Misc_Note_01",
    desc = "Добавить квест в журнал, как если бы вы взяли его у NPC." },
  { cmd = "complete", ru = "Завершить",  icon = "Interface\\Icons\\Achievement_Quests_Completed_01",
    desc = "Отметить все цели выполненными. Награду ещё нужно получить." },
  { cmd = "reward",   ru = "Наградить",  icon = "Interface\\Icons\\INV_Misc_Coin_02",
    desc = "Выдать награду и закрыть квест, минуя NPC." },
  { cmd = "remove",   ru = "Убрать",     icon = "Interface\\Icons\\Spell_ChargeNegative",
    desc = "Удалить квест из журнала." },
  { cmd = "status",   ru = "Состояние",  icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    desc = "Показать в чате, на какой стадии квест." },
}

--------------------------------------------------------------------------
-- Опасные команды
--------------------------------------------------------------------------

-- Показываются с подтверждением или не показываются вовсе.
ns.RISKY = {
  ["die"]              = "Без выделенной цели команда убьёт ВАС.",
  ["character erase"]  = "Безвозвратно удаляет персонажа.",
  ["account delete"]   = "Безвозвратно удаляет аккаунт со всеми персонажами.",
  ["server shutdown"]  = "Останавливает сервер.",
  ["server exit"]      = "Останавливает сервер немедленно.",
  ["reload all"]       = "Перезагружает всю базу — сервер подвиснет на минуту.",
}
