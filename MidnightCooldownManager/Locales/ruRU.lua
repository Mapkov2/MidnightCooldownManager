local CDM = _G["MidnightCooldownManager"]
local L = CDM:NewLocale("ruRU")
if not L then return end

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

--L["Enabled Blizzard Cooldown Manager."] = "Enabled Blizzard Cooldown Manager."
--L["Config open queued until combat ends."] = "Config open queued until combat ends."
--L["Config open queued until login setup finishes."] = "Config open queued until login setup finishes."
L["Could not load options: %s"] = "Не удалось загрузить настройки: %s"

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "Режим редактирования заблокирован"
L["use /mcdm"] = "используйте /mcdm"
L["Edit Mode locked - use /mcdm"] = "Режим редактирования заблокирован — используйте /mcdm"
L["Cooldown Viewer settings are managed by /mcdm."] = "Настройки трекера восстановления способностей управляются через /mcdm."

-----------------------------------------------------------------------
-- Modules/BuffGroupOverlays.lua
-----------------------------------------------------------------------

--L["Ungrouped"] = "Ungrouped"

-----------------------------------------------------------------------
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- MidnightCooldownManager/Init.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "Невозможно открыть настройки в бою"
L["Invalid profile data"] = "Некорректные данные профиля"
L["Copy this URL:"] = "Скопируйте этот URL:"
L["Close"] = "Закрыть"
L["Reset the current profile to default settings?"] = "Сбросить текущий профиль до настроек по умолчанию?"
L["Reset"] = "Сбросить"
L["Cancel"] = "Отмена"
L["Copy"] = "Копировать"
L["Delete"] = "Удалить"

-----------------------------------------------------------------------
-- MidnightCooldownManager/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "Невозможно %s в бою"
L["open CDM config"] = "открыть настройки CDM"
L["Display"] = "Отображение"
L["Styling"] = "Внешний вид"
L["Buffs"] = "Баффы"
L["Features"] = "Функции"
L["Utility"] = "Утилиты"
L["Cooldown Manager"] = "Трекер восстановления способностей"
L["Settings"] = "Настройки"
--L["Edit Mode Settings"] = "Edit Mode Settings"
L["rebuild CDM config"] = "перестроить настройки CDM"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "Основные способности"
L["Row 1 Width"] = "Ширина ряда 1"
L["Row 1 Height"] = "Высота ряда 1"
L["Row 2 Width"] = "Ширина ряда 2"
L["Row 2 Height"] = "Высота ряда 2"
L["Width"] = "Ширина"
L["Height"] = "Высота"
L["Buff"] = "Бафф"
L["Icon Sizes"] = "Размеры иконок"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Layout.lua
-----------------------------------------------------------------------

--L["Cooldowns"] = "Cooldowns"
--L["General"] = "General"
--L["Externals"] = "Externals"
--L["Cooldown Swipe"] = "Cooldown Swipe"
--L["Hide GCD Swipe"] = "Hide GCD Swipe"
--L["Swipe Color"] = "Swipe Color"
--L["Swipe Opacity"] = "Swipe Opacity"
L["Layout Settings"] = "Настройки макета"
L["Icon Spacing"] = "Расстояние между иконками"
L["Max Icons Per Row"] = "Макс. иконок в ряду"
L["Wrap Utility Bar"] = "Перенос панели вспомогательных способностей"
L["Utility Max Icons Per Row"] = "Макс. иконок вспомогательных способностей в ряду"
L["Unlock Utility Bar"] = "Разблокировать панель вспомогательных способностей"
L["Utility X Offset"] = "Смещение вспомогательных способностей по X"
L["Display Vertical"] = "Вертикальное отображение"
L["Layout"] = "Макет"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Positions.lua
-----------------------------------------------------------------------

L["Current: %s (%d, %d)"] = "Текущее: %s (%d, %d)"
L["X Position"] = "Позиция по X"
L["Y Position"] = "Позиция по Y"
L["Essential Container Position"] = "Позиция контейнера основных способностей"
L["Utility Y Offset"] = "Смещение вспомогательных способностей по Y"
L["Main Buff Container Position"] = "Позиция контейнера основных баффов"
L["Buff Bar Container Position"] = "Позиция контейнера полос баффов"
L["Positions"] = "Позиции"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "Настройки границы"
L["Border Texture"] = "Текстура границы"
L["Select Border..."] = "Выбрать границу..."
L["Border Color"] = "Цвет границы"
L["Border Size"] = "Размер границы"
L["Border Offset X"] = "Смещение границы по X"
L["Border Offset Y"] = "Смещение границы по Y"
L["Zoom Icons"] = "Увеличить иконки"
--L["Zoom Amount"] = "Zoom Amount"
--L["Remove Shadow Overlay"] = "Remove Shadow Overlay"
--L["Remove Default Icon Mask"] = "Remove Default Icon Mask"
L["Visual Elements"] = "Визуальные элементы"
L["* These options require /reload to take effect"] = "* Для применения этих настроек требуется /reload"
L["Hide Debuff Border (red outline on harmful effects)"] = "Скрыть границу дебаффа (красный контур на негативных эффектах)"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "Скрыть вспышку восстановления (вспышка при завершении восстановления)"
--L["Pandemic Display"] = "Pandemic Display"
L["Hide Blizzard's Pandemic Indicator (animated refresh window border)"] = "Скрыть индикатор пандемии Blizzard (анимированная граница окна обновления)"
--L["Enable Pandemic Customization"] = "Enable Pandemic Customization"
--L["Custom Pandemic Border"] = "Custom Pandemic Border"
L["Color"] = "Цвет"
--L["Pandemic Glow"] = "Pandemic Glow"
--L["Charge Cooldowns"] = "Charge Cooldowns"
--L["Show Edge"] = "Show Edge"
--L["Hide Swipe"] = "Hide Swipe"
L["Borders"] = "Границы"
--L["Look"] = "Look"
--L["Borders & Look"] = "Borders & Look"
--L["Hide Buff Swipe"] = "Hide Buff Swipe"
--L["Don't desaturate on cooldown"] = "Don't desaturate on cooldown"
--L["Hide recharge timer"] = "Hide recharge timer"
--L["Color Buff Bars Borders"] = "Color Buff Bars Borders"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Text.lua
-----------------------------------------------------------------------

L["None"] = "Нет"
L["Outline"] = "Outline"
L["Thick Outline"] = "Thick Outline"
L["Slug"] = "Slug"
L["Font"] = "Шрифт"
L["Font Outline"] = "Контур шрифта"
L["Cooldown Timer"] = "Таймер восстановления"
--L["Cooldown Countdown Format"] = "Cooldown Countdown Format"
--L["Show decimals below (seconds, 0 = off)"] = "Show decimals below (seconds, 0 = off)"
--L["Threshold Color"] = "Threshold Color"
--L["Color countdown below threshold"] = "Color countdown below threshold"
--L["Threshold (seconds)"] = "Threshold (seconds)"
--L["Row 1 Font Size"] = "Row 1 Font Size"
--L["Row 2 Font Size"] = "Row 2 Font Size"
--L["Row 1 - Stacks (Charges)"] = "Row 1 - Stacks (Charges)"
L["Font Size"] = "Размер шрифта"
L["Position"] = "Позиция"
L["X Offset"] = "Смещение по X"
L["Y Offset"] = "Смещение по Y"
--L["Row 2 - Stacks (Charges)"] = "Row 2 - Stacks (Charges)"
--L["Stacks (Charges)"] = "Stacks (Charges)"
--L["Name Text"] = "Name Text"
L["Anchor"] = "Якорь"
--L["Duration Text"] = "Duration Text"
--L["Stack Count Text"] = "Stack Count Text"
--L["Global"] = "Global"
--L["Buff Icons"] = "Buff Icons"
L["Buff Bars"] = "Полосы баффов"
L["Text"] = "Текст"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Glow.lua
-----------------------------------------------------------------------

L["Pixel Glow"] = "Pixel Glow"
L["Autocast Glow"] = "Autocast Glow"
L["Button Glow"] = "Button Glow"
L["Proc Glow"] = "Proc Glow"
L["Glow Settings"] = "Настройки свечения"
L["Glow Type"] = "Тип свечения"
L["Use Custom Color"] = "Использовать свой цвет"
L["Glow Color"] = "Цвет свечения"
L["Pixel Glow Settings"] = "Настройки Pixel Glow"
L["Lines"] = "Линии"
L["Frequency"] = "Частота"
L["Length (0=auto)"] = "Длина (0=авто)"
L["Thickness"] = "Толщина"
--L["Border"] = "Border"
L["Autocast Glow Settings"] = "Настройки Autocast Glow"
L["Particles"] = "Частицы"
L["Scale"] = "Масштаб"
L["Button Glow Settings"] = "Настройки Button Glow"
L["Frequency (0=default)"] = "Частота (0=по умолчанию)"
L["Proc Glow Settings"] = "Настройки Proc Glow"
L["Duration (x10)"] = "Длительность (x10)"
L["Glow"] = "Свечение"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "Затухание"
L["Enable Fading"] = "Включить затухание"
L["Fade Triggers"] = "Условия затухания"
L["Fade when no target"] = "Затухание, если нет цели"
L["Fade out of combat"] = "Затухание, если не в бою"
L["Fade when mounted"] = "Затухание на маунте"
L["Faded Opacity"] = "Прозрачность при затухании"
L["Apply Fading To"] = "Применить затухание к"
L["Racials"] = "Расовые способности"
L["Defensives"] = "Защитные способности"
L["Trinkets"] = "Аксессуары"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Assist.lua
-----------------------------------------------------------------------

--L["Press Overlay"] = "Press Overlay"
--L["Enable Press Overlay"] = "Enable Press Overlay"
--L["Color Tint"] = "Color Tint"
--L["Tint Color"] = "Tint Color"
--L["Highlight"] = "Highlight"
--L["Rotation Assist"] = "Rotation Assist"
--L["Enable Rotation Assist"] = "Enable Rotation Assist"
--L["Highlight Size"] = "Highlight Size"
--L["Keybindings"] = "Keybindings"
--L["Enable Keybind Text"] = "Enable Keybind Text"
L["Assist"] = "Помощник"

-----------------------------------------------------------------------
-- MidnightCooldownManager/GroupEditorShared.lua
-----------------------------------------------------------------------

--L["Text Overrides"] = "Text Overrides"
--L["Override Text Settings"] = "Override Text Settings"
--L["Cooldown Size"] = "Cooldown Size"
--L["Cooldown Color"] = "Cooldown Color"
--L["Charge Size"] = "Charge Size"
--L["Charge Color"] = "Charge Color"
L["Current Spec"] = "Текущая специализация"
--L["Grow Direction"] = "Grow Direction"
--L["Spacing"] = "Spacing"
L["Icon Width"] = "Ширина иконки"
L["Icon Height"] = "Высота иконки"
--L["Anchor To"] = "Anchor To"
--L["Anchor Point"] = "Anchor Point"
--L["Essential Viewer Point"] = "Essential Viewer Point"

-----------------------------------------------------------------------
-- MidnightCooldownManager/BuffGroups.lua
-----------------------------------------------------------------------

--L["Select a group or spell to edit settings"] = "Select a group or spell to edit settings"
--L["Static Display"] = "Static Display"
--L["Screen"] = "Screen"
--L["Player Frame"] = "Player Frame"
--L["Essential Viewer"] = "Essential Viewer"
--L["Buff Viewer"] = "Buff Viewer"
--L["Player Frame Point"] = "Player Frame Point"
--L["Buff Viewer Point"] = "Buff Viewer Point"
--L["Per-Spell Overrides"] = "Per-Spell Overrides"
--L["Hide Cooldown Timer"] = "Hide Cooldown Timer"
--L["Hide Icon"] = "Hide Icon"
--L["Show Placeholder"] = "Show Placeholder"
--L["Play Sound"] = "Play Sound"
--L["On Show"] = "On Show"
--L["On Hide"] = "On Hide"
--L["Text to Speech"] = "Text to Speech"
--L["Voice Settings"] = "Voice Settings"
--L["(empty = spell name)"] = "(empty = spell name)"
L["Unknown"] = "Неизвестно"
L["Border:"] = "Граница:"
--L["Right-click icon to reset border color"] = "Right-click icon to reset border color"
L["Enable Glow"] = "Включить свечение"
L["Glow Color:"] = "Цвет свечения:"
L["Spell ID:"] = "ID заклинания:"
L["Duration (sec):"] = "Длительность (сек):"
--L["Save"] = "Save"
L["Invalid spell ID"] = "Некорректный ID заклинания"
L["Enter a valid duration"] = "Введите корректную длительность"
--L["Ungrouped Buffs"] = "Ungrouped Buffs"
--L["Add Spell to:"] = "Add Spell to:"
--L["Log %s to build spell list"] = "Log %s to build spell list"
--L["No untracked buff icons available for this spec"] = "No untracked buff icons available for this spec"
--L["All available icons are assigned to groups"] = "All available icons are assigned to groups"
--L["Add Custom Buff to:"] = "Add Custom Buff to:"
--L["Add Custom Buff"] = "Add Custom Buff"
--L["Quick Add"] = "Quick Add"
L["Add"] = "Добавить"
--L["Custom Spell"] = "Custom Spell"
L["Add Spell"] = "Добавить заклинание"
L["Failed - invalid spell ID"] = "Ошибка — некорректный ID заклинания"
L["Added!"] = "Добавлено!"
--L["Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"] = "Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"
--L["Back"] = "Back"
--L["Add Group"] = "Add Group"
--L["Add Icon"] = "Add Icon"
--L["No ungrouped buffs"] = "No ungrouped buffs"
L["Rename"] = "Переименовать"
--L["Duplicate"] = "Duplicate"
--L["Copy to"] = "Copy to"
--L["Delete group with %d spell(s)?"] = "Delete group with %d spell(s)?"
--L["Drag spells here"] = "Drag spells here"
L["Buff Groups"] = "Группы баффов"

-----------------------------------------------------------------------
-- MidnightCooldownManager/CooldownGroups.lua
-----------------------------------------------------------------------

--L["Max Per Row"] = "Max Per Row"
--L["Utility Viewer"] = "Utility Viewer"
--L["Utility Viewer Point"] = "Utility Viewer Point"
--L["Show Aura Overlay"] = "Show Aura Overlay"
--L["Desaturate when inactive"] = "Desaturate when inactive"
--L["Aura Glow"] = "Aura Glow"
--L["Aura Border Color"] = "Aura Border Color"
--L["Border Color:"] = "Border Color:"
--L["Glow When Ready"] = "Glow When Ready"
--L["No untracked cooldown icons available for this spec"] = "No untracked cooldown icons available for this spec"
--L["All spells are in groups"] = "All spells are in groups"

-----------------------------------------------------------------------
-- MidnightCooldownManager/ImportExport.lua
-----------------------------------------------------------------------

L["Invalid Base64 encoding"] = "Некорректная кодировка Base64"
L["Decompression failed"] = "Ошибка распаковки"
L["Invalid profile version"] = "Некорректная версия профиля"
L["Missing profile metadata"] = "Отсутствуют метаданные профиля"
--L["Profile is for a different addon"] = "Profile is for a different addon"
L["No import string provided"] = "Строка импорта не указана"
L["Failed to import profile"] = "Не удалось импортировать профиль"
--L["Select at least one category to export."] = "Select at least one category to export."
L["Profile is for a different addon: %s"] = "Профиль предназначен для другого аддона: %s"
L["Imported %d settings as '%s'"] = "Импортировано %d настроек как '%s'"
L["Export Profile"] = "Экспорт профиля"
L["Select categories to include, then click Export."] = "Выберите категории для включения, затем нажмите «Экспорт»."
L["Export"] = "Экспорт"
L["Export String (Ctrl+C to copy):"] = "Строка экспорта (Ctrl+C для копирования):"
L["Profile exported! Copy the string above."] = "Профиль экспортирован! Скопируйте строку выше."
L["Export failed."] = "Экспорт не удался."
L["Import Profile"] = "Импорт профиля"
L["Paste an export string below and click Import."] = "Вставьте строку экспорта ниже и нажмите «Импорт»."
L["Import"] = "Импорт"
L["Clear"] = "Очистить"
L["Import/Export"] = "Импорт/Экспорт"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Profiles.lua
-----------------------------------------------------------------------

L["Already exists"] = "Уже существует"
L["Enter a name"] = "Введите название"
--L["Failed to apply profile"] = "Failed to apply profile"
--L["Profile not found"] = "Profile not found"
--L["Cannot copy active profile"] = "Cannot copy active profile"
--L["Cannot delete active profile"] = "Cannot delete active profile"
L["Current Profile"] = "Текущий профиль"
L["New Profile"] = "Новый профиль"
L["Create"] = "Создать"
L["Copy From"] = "Копировать из"
L["Copy all settings from another profile into the current one."] = "Скопировать все настройки из другого профиля в текущий."
L["Select Source..."] = "Выбрать источник..."
L["Manage"] = "Управление"
L["Reset Profile"] = "Сбросить профиль"
L["Delete Profile..."] = "Удалить профиль..."
L["Default Profile for New Characters"] = "Профиль по умолчанию для новых персонажей"
L["Specialization Profiles"] = "Профили специализаций"
L["Auto-switch profile per specialization"] = "Автоматически переключать профиль по специализации"
L["Spec %d"] = "Специализация %d"
L["Profiles"] = "Профили"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "Добавить свое заклинание или предмет"
L["Spell"] = "Заклинание"
L["Item"] = "Предмет"
L["Enter a valid ID"] = "Введите корректный ID"
L["Loading item data, try again"] = "Загрузка данных предмета, попробуйте снова"
L["Unknown spell ID"] = "Неизвестный ID заклинания"
L["Added: %s"] = "Добавлено: %s"
L["Already tracked"] = "Уже отслеживается"
L["Enable Racials"] = "Включить расовые способности"
--L["Show Items at 0 Stacks"] = "Show Items at 0 Stacks"
L["Tracked Spells"] = "Отслеживаемые заклинания"
L["Manage Spells"] = "Управление заклинаниями"
L["Icon Size"] = "Размер иконки"
L["Party Frame Anchoring"] = "Привязка к фрейму группы"
L["Anchor to Party Frame"] = "Привязать к фрейму группы"
L["Side (relative to Party Frame)"] = "Сторона (относительно фрейма группы)"
L["Party Frame X Offset"] = "Смещение фрейма группы по X"
L["Party Frame Y Offset"] = "Смещение фрейма группы по Y"
L["Anchor Position (relative to Player Frame)"] = "Позиция привязки (относительно фрейма игрока)"
L["Cooldown"] = "Восстановление"
L["Stacks"] = "Стаки"
L["Text Position"] = "Позиция текста"
L["Text X Offset"] = "Смещение текста по X"
L["Text Y Offset"] = "Смещение текста по Y"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Defensives.lua
-----------------------------------------------------------------------

L["Add Custom Spell"] = "Добавить свое заклинание"
L["Spell ID"] = "ID заклинания"
L["Enter a valid spell ID"] = "Введите корректный ID заклинания"
L["Not available for spec"] = "Недоступно для данной специализации"
L["Enable Defensives"] = "Включить защитные способности"

-----------------------------------------------------------------------
-- MidnightCooldownManager/EditModeOverlay.lua
-----------------------------------------------------------------------

--L["Compliant"] = "Compliant"
--L["Mismatched"] = "Mismatched"
--L["N/A"] = "N/A"
--L["Active layout is a preset. Switch to or create a custom layout to save changes."] = "Active layout is a preset. Switch to or create a custom layout to save changes."
--L["Apply"] = "Apply"
--L["All settings are correct"] = "All settings are correct"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Trinkets.lua
-----------------------------------------------------------------------

--L["Trinket Blacklist"] = "Trinket Blacklist"
--L["Add Item"] = "Add Item"
--L["Item ID"] = "Item ID"
--L["(loading...)"] = "(loading...)"
--L["Enter a valid item ID"] = "Enter a valid item ID"
--L["Unknown item ID"] = "Unknown item ID"
--L["Already blacklisted"] = "Already blacklisted"
L["Independent"] = "Отдельно"
L["Append to Defensives"] = "Добавить к защитным способностям"
L["Append to Spells"] = "Добавить к заклинаниям"
L["Row 1"] = "Ряд 1"
L["Row 2"] = "Ряд 2"
L["Start"] = "Начало"
L["End"] = "Конец"
L["Enable Trinkets"] = "Включить аксессуары"
--L["Manage Blacklist"] = "Manage Blacklist"
L["Layout Mode"] = "Режим размещения"
L["Display Mode"] = "Режим отображения"
L["Row"] = "Ряд"
L["Position in Row"] = "Позиция в ряду"
L["Show Passive Trinkets"] = "Показывать пассивные аксессуары"


-----------------------------------------------------------------------
-- MidnightCooldownManager/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "Размеры"
L["Bar Width (0 = Auto)"] = "Ширина полосы (0 = авто)"
L["Bar Height"] = "Высота полосы"
L["Appearance"] = "Внешний вид"
L["Background Color"] = "Цвет фона"
L["Growth Direction:"] = "Направление роста:"
L["Down"] = "Вниз"
L["Up"] = "Вверх"
L["Icon Position:"] = "Позиция иконки:"
L["Hidden"] = "Скрыто"
L["Icon-Bar Gap"] = "Расстояние между иконкой и полосой"
L["Dual Bar Mode (2 bars per row)"] = "Режим «двойной полосы» (2 полосы в ряду)"
L["Show Buff Name"] = "Показывать название баффа"
--L["Max Name Length (0 = Full)"] = "Max Name Length (0 = Full)"
L["Show Duration Text"] = "Показывать текст длительности"
L["Show Stack Count"] = "Показывать количество стаков"
L["Notes"] = "Примечания"
L["Border settings: see Borders tab"] = "Настройки границы: см. вкладку «Границы»"
L["Text styling (font size, color, offsets): see Text tab"] = "Оформление текста (размер шрифта, цвет, смещения): см. вкладку «Текст»"
L["Position lock and X/Y controls: see Positions tab"] = "Блокировка позиции и перемещение по X/Y: см. вкладку «Позиции»"
L["Bars"] = "Полосы"


-----------------------------------------------------------------------
-- MidnightCooldownManager/Externals.lua
-----------------------------------------------------------------------

--L["Enable Externals"] = "Enable Externals"
--L["Disable Blink"] = "Disable Blink"

