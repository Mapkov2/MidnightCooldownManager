local CDM = _G["MidnightCooldownManager"]
local L = CDM:NewLocale("deDE")
if not L then return end

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Enabled Blizzard Cooldown Manager."] = "Blizzard-Abklingzeitenmanager aktiviert."
--L["Config open queued until combat ends."] = "Config open queued until combat ends."
--L["Config open queued until login setup finishes."] = "Config open queued until login setup finishes."
L["Could not load options: %s"] = "Optionen konnten nicht geladen werden: %s"

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "Bearbeitungsmodus gesperrt"
L["use /mcdm"] = "benutze /mcdm"
L["Edit Mode locked - use /mcdm"] = "Bearbeitungsmodus gesperrt – benutze /mcdm"
L["Cooldown Viewer settings are managed by /mcdm."] = "Abklingzeitenanzeige-Einstellungen werden durch /mcdm verwaltet."

-----------------------------------------------------------------------
-- Modules/BuffGroupOverlays.lua
-----------------------------------------------------------------------

--L["Ungrouped"] = "Ungrouped"

-----------------------------------------------------------------------
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- MidnightCooldownManager/Init.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "Konfiguration kann nicht im Kampf geöffnet werden"
L["Invalid profile data"] = "Ungültige Profildaten"
L["Copy this URL:"] = "Diese URL kopieren:"
L["Close"] = "Schließen"
L["Reset the current profile to default settings?"] = "Das aktuelle Profil auf Standardeinstellungen zurücksetzen?"
L["Reset"] = "Zurücksetzen"
L["Cancel"] = "Abbrechen"
L["Copy"] = "Kopieren"
L["Delete"] = "Löschen"

-----------------------------------------------------------------------
-- MidnightCooldownManager/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "Kann %s nicht im Kampf"
L["open CDM config"] = "CDM-Konfiguration öffnen"
L["Display"] = "Anzeige"
L["Styling"] = "Gestaltung"
L["Buffs"] = "Buffs"
L["Features"] = "Funktionen"
L["Utility"] = "Unterstützung"
L["Cooldown Manager"] = "Abklingzeitenmanager"
L["Settings"] = "Einstellungen"
--L["Edit Mode Settings"] = "Edit Mode Settings"
L["rebuild CDM config"] = "CDM-Konfiguration neu aufbauen"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "Essential"
L["Row 1 Width"] = "Reihe 1 Breite"
L["Row 1 Height"] = "Reihe 1 Höhe"
L["Row 2 Width"] = "Reihe 2 Breite"
L["Row 2 Height"] = "Reihe 2 Höhe"
L["Width"] = "Breite"
L["Height"] = "Höhe"
L["Buff"] = "Buff"
L["Icon Sizes"] = "Symbolgröße"

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
L["Layout Settings"] = "Layout-Einstellungen"
L["Icon Spacing"] = "Symbolabstand"
L["Max Icons Per Row"] = "Max. Symbole pro Reihe"
L["Wrap Utility Bar"] = "Unterstützungsleiste umbrechen"
L["Utility Max Icons Per Row"] = "Unterstützung Max. Symbole pro Reihe"
L["Unlock Utility Bar"] = "Unterstützungleiste entsperren"
L["Utility X Offset"] = "Unterstützung X-Versatz"
L["Display Vertical"] = "Vertikal anzeigen"
L["Layout"] = "Layout"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Positions.lua
-----------------------------------------------------------------------

L["Current: %s (%d, %d)"] = "Aktuell: %s (%d, %d)"
L["X Position"] = "X-Position"
L["Y Position"] = "Y-Position"
L["Essential Container Position"] = "Essential-Container-Position"
L["Utility Y Offset"] = "Unterstützung Y-Versatz"
L["Main Buff Container Position"] = "Haupt-Buff-Container-Position"
L["Buff Bar Container Position"] = "Buff-Leisten-Container-Position"
L["Positions"] = "Positionen"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "Rahmen-Einstellungen"
L["Border Texture"] = "Rahmen-Textur"
L["Select Border..."] = "Rahmen auswählen..."
L["Border Color"] = "Rahmenfarbe"
L["Border Size"] = "Rahmengröße"
L["Border Offset X"] = "Rahmen X-Versatz"
L["Border Offset Y"] = "Rahmen Y-Versatz"
L["Zoom Icons"] = "Symbole zoomen"
--L["Zoom Amount"] = "Zoom Amount"
--L["Remove Shadow Overlay"] = "Remove Shadow Overlay"
--L["Remove Default Icon Mask"] = "Remove Default Icon Mask"
L["Visual Elements"] = "Visuelle Elemente"
L["* These options require /reload to take effect"] = "* Diese Optionen erfordern /reload zur Aktivierung"
L["Hide Debuff Border (red outline on harmful effects)"] = "Debuff-Rahmen ausblenden (roter Umriss bei schädlichen Effekten)"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "Aufleuchten nach Abklingzeit ausblenden (Leuchtanimation bei Abklingzeitende)"
--L["Pandemic Display"] = "Pandemic Display"
L["Hide Blizzard's Pandemic Indicator (animated refresh window border)"] = "Blizzards Pandemie-Indikator ausblenden (animierter Erneuerungsfensterrahmen)"
--L["Enable Pandemic Customization"] = "Enable Pandemic Customization"
--L["Custom Pandemic Border"] = "Custom Pandemic Border"
L["Color"] = "Farbe"
--L["Pandemic Glow"] = "Pandemic Glow"
--L["Charge Cooldowns"] = "Charge Cooldowns"
--L["Show Edge"] = "Show Edge"
--L["Hide Swipe"] = "Hide Swipe"
L["Borders"] = "Rahmen"
--L["Look"] = "Look"
--L["Borders & Look"] = "Borders & Look"
--L["Hide Buff Swipe"] = "Hide Buff Swipe"
--L["Don't desaturate on cooldown"] = "Don't desaturate on cooldown"
--L["Hide recharge timer"] = "Hide recharge timer"
--L["Color Buff Bars Borders"] = "Color Buff Bars Borders"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Text.lua
-----------------------------------------------------------------------

L["None"] = "Keine"
L["Outline"] = "Kontur"
L["Thick Outline"] = "Dicke Kontur"
L["Slug"] = "Slug"
L["Font"] = "Schriftart"
L["Font Outline"] = "Schriftkontur"
L["Cooldown Timer"] = "Abklingzeit-Timer"
--L["Cooldown Countdown Format"] = "Cooldown Countdown Format"
--L["Show decimals below (seconds, 0 = off)"] = "Show decimals below (seconds, 0 = off)"
--L["Threshold Color"] = "Threshold Color"
--L["Color countdown below threshold"] = "Color countdown below threshold"
--L["Threshold (seconds)"] = "Threshold (seconds)"
--L["Row 1 Font Size"] = "Row 1 Font Size"
--L["Row 2 Font Size"] = "Row 2 Font Size"
--L["Row 1 - Stacks (Charges)"] = "Row 1 - Stacks (Charges)"
L["Font Size"] = "Schriftgröße"
L["Position"] = "Position"
L["X Offset"] = "X-Versatz"
L["Y Offset"] = "Y-Versatz"
--L["Row 2 - Stacks (Charges)"] = "Row 2 - Stacks (Charges)"
--L["Stacks (Charges)"] = "Stacks (Charges)"
--L["Name Text"] = "Name Text"
L["Anchor"] = "Ankerpunkt"
--L["Duration Text"] = "Duration Text"
--L["Stack Count Text"] = "Stack Count Text"
--L["Global"] = "Global"
--L["Buff Icons"] = "Buff Icons"
L["Buff Bars"] = "Buff-Leisten"
L["Text"] = "Text"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Glow.lua
-----------------------------------------------------------------------

L["Pixel Glow"] = "Pixel-Leuchten"
L["Autocast Glow"] = "Leuchten bei automatischem Wirken"
L["Button Glow"] = "Schaltflächen-Leuchten"
L["Proc Glow"] = "Proc-Leuchten"
L["Glow Settings"] = "Leucht-Einstellungen"
L["Glow Type"] = "Leuchttyp"
L["Use Custom Color"] = "Benutzerdefinierte Farbe verwenden"
L["Glow Color"] = "Leuchtfarbe"
L["Pixel Glow Settings"] = "Pixel-Leucht-Einstellungen"
L["Lines"] = "Linien"
L["Frequency"] = "Frequenz"
L["Length (0=auto)"] = "Länge (0=auto)"
L["Thickness"] = "Stärke"
--L["Border"] = "Border"
L["Autocast Glow Settings"] = "Automatischer-Zauber-Leucht-Einstellungen"
L["Particles"] = "Partikel"
L["Scale"] = "Skalierung"
L["Button Glow Settings"] = "Schaltflächen-Leucht-Einstellungen"
L["Frequency (0=default)"] = "Frequenz (0=Standard)"
L["Proc Glow Settings"] = "Proc-Leucht-Einstellungen"
L["Duration (x10)"] = "Dauer (x10)"
L["Glow"] = "Leuchten"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "Verblassen"
L["Enable Fading"] = "Verblassen aktivieren"
L["Fade Triggers"] = "Verblassen Auslöser"
L["Fade when no target"] = "Verblassen ohne Ziel"
L["Fade out of combat"] = "Verblassen außerhalb des Kampfes"
L["Fade when mounted"] = "Verblassen wenn aufgestiegen"
L["Faded Opacity"] = "Verblassen Stärke"
L["Apply Fading To"] = "Verblassen anwenden auf"
L["Racials"] = "Volksfertigkeiten"
L["Defensives"] = "Defensivfähigkeiten"
L["Trinkets"] = "Schmuckstücke"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Assist.lua
-----------------------------------------------------------------------

--L["Press Overlay"] = "Press Overlay"
--L["Enable Press Overlay"] = "Enable Press Overlay"
--L["Color Tint"] = "Color Tint"
--L["Tint Color"] = "Tint Color"
--L["Highlight"] = "Highlight"
L["Rotation Assist"] = "Rotationshelfer"
L["Enable Rotation Assist"] = "Rotationshelfer aktivieren"
L["Highlight Size"] = "Größe der Hervorhebung"
L["Keybindings"] = "Tastenbelegung"
L["Enable Keybind Text"] = "Beschriftung für Tastenbelegung aktivieren"
L["Assist"] = "Assist"

-----------------------------------------------------------------------
-- MidnightCooldownManager/GroupEditorShared.lua
-----------------------------------------------------------------------

--L["Text Overrides"] = "Text Overrides"
--L["Override Text Settings"] = "Override Text Settings"
--L["Cooldown Size"] = "Cooldown Size"
--L["Cooldown Color"] = "Cooldown Color"
--L["Charge Size"] = "Charge Size"
--L["Charge Color"] = "Charge Color"
L["Current Spec"] = "Aktuelle Spezialisierung"
--L["Grow Direction"] = "Grow Direction"
--L["Spacing"] = "Spacing"
L["Icon Width"] = "Symbolbreite"
L["Icon Height"] = "Symbolhöhe"
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
L["Unknown"] = "Unbekannt"
L["Border:"] = "Rahmen:"
--L["Right-click icon to reset border color"] = "Right-click icon to reset border color"
L["Enable Glow"] = "Leuchten aktivieren"
L["Glow Color:"] = "Leuchtfarbe:"
L["Spell ID:"] = "Zauber-ID:"
L["Duration (sec):"] = "Dauer (Sek.):"
--L["Save"] = "Save"
L["Invalid spell ID"] = "Ungültige Zauber-ID"
L["Enter a valid duration"] = "Gültige Dauer eingeben"
--L["Ungrouped Buffs"] = "Ungrouped Buffs"
--L["Add Spell to:"] = "Add Spell to:"
--L["Log %s to build spell list"] = "Log %s to build spell list"
--L["No untracked buff icons available for this spec"] = "No untracked buff icons available for this spec"
--L["All available icons are assigned to groups"] = "All available icons are assigned to groups"
L["Missing buffs must be enabled in Blizzard Cooldown Settings under Tracked Buffs for this spec. If a buff is under Not Displayed, MCDM cannot add it."] = "Fehlende Buffs muessen in den Blizzard-Abklingzeiten-Einstellungen fuer diese Spezialisierung unter Tracked Buffs aktiviert sein. Wenn ein Buff unter Not Displayed liegt, kann MCDM ihn nicht hinzufuegen."
L["Open Settings"] = "Einstellungen öffnen"
L["Blizzard load required"] = "Blizzard-Ladung erforderlich"
L["No loaded buff icons are available. Open Blizzard Settings and move missing buffs from Not Displayed to Tracked Buffs."] = "Keine geladenen Buff-Icons verfuegbar. Oeffne die Blizzard-Einstellungen und verschiebe fehlende Buffs von Not Displayed nach Tracked Buffs."
L["All loaded buff icons are assigned to groups. Missing buffs must be enabled in Blizzard Settings first."] = "Alle geladenen Buff-Icons sind Gruppen zugewiesen. Fehlende Buffs muessen zuerst in den Blizzard-Einstellungen aktiviert werden."
L["Missing bars must be enabled in Blizzard Cooldown Settings under Tracked Bars for this spec. If a bar is under Not Displayed, MCDM cannot add it."] = "Fehlende Bars muessen in den Blizzard-Abklingzeiten-Einstellungen fuer diese Spezialisierung unter Tracked Bars aktiviert sein. Wenn eine Bar unter Not Displayed liegt, kann MCDM sie nicht hinzufuegen."
L["No loaded bar entries are available. Open Blizzard Settings and move missing entries from Not Displayed to Tracked Bars."] = "Keine geladenen Bar-Eintraege verfuegbar. Oeffne die Blizzard-Einstellungen und verschiebe fehlende Eintraege von Not Displayed nach Tracked Bars."
L["All loaded bar entries are assigned to groups. Missing bars must be enabled in Blizzard Settings first."] = "Alle geladenen Bar-Eintraege sind Gruppen zugewiesen. Fehlende Bars muessen zuerst in den Blizzard-Einstellungen aktiviert werden."
--L["Add Custom Buff to:"] = "Add Custom Buff to:"
--L["Add Custom Buff"] = "Add Custom Buff"
--L["Quick Add"] = "Quick Add"
L["Add"] = "Hinzufügen"
--L["Custom Spell"] = "Custom Spell"
L["Add Spell"] = "Zauber hinzufügen"
L["Failed - invalid spell ID"] = "Fehlgeschlagen – ungültige Zauber-ID"
L["Added!"] = "Hinzugefügt!"
L["Only buffs loaded by Blizzard Cooldown Manager for this spec can be added."] = "Nur Buffs, die der Blizzard-Abklingzeitenmanager für diese Spezialisierung geladen hat, können hinzugefügt werden."
L["Quick Add uses built-in MCDM templates. Custom Spell IDs must be loaded by Blizzard Cooldown Manager for this spec."] = "Quick Add nutzt eingebaute MCDM-Vorlagen. Eigene Zauber-IDs müssen vom Blizzard-Abklingzeitenmanager für diese Spezialisierung geladen sein."
L["Log %s to build the CDM buff list first."] = "Logge %s ein, damit die CDM-Buffliste zuerst aufgebaut wird."
L["this spec"] = "diese Spezialisierung"
L["If a spell is missing here, Blizzard CDM has not loaded it for this spec."] = "Wenn ein Zauber hier fehlt, hat Blizzard CDM ihn für diese Spezialisierung nicht geladen."
L["If a manual spell is blocked, Blizzard CDM has not loaded it for this spec."] = "Wenn ein manueller Zauber blockiert wird, hat Blizzard CDM ihn für diese Spezialisierung nicht geladen."
L["Open Blizzard Settings and move the buff from Not Displayed to Tracked Buffs first."] = "Oeffne zuerst die Blizzard-Einstellungen und verschiebe den Buff von Not Displayed nach Tracked Buffs."
L["Already added"] = "Bereits hinzugefügt"
L["Not loaded in CDM for this spec"] = "Nicht in CDM für diese Spec geladen"
L["Loaded in CDM"] = "In CDM geladen"
L["This spell is not loaded in CDM for this spec."] = "Dieser Zauber ist für diese Spezialisierung nicht in CDM geladen."
--L["Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"] = "Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"
--L["Back"] = "Back"
--L["Add Group"] = "Add Group"
--L["Add Icon"] = "Add Icon"
--L["No ungrouped buffs"] = "No ungrouped buffs"
L["Rename"] = "Umbenennen"
--L["Duplicate"] = "Duplicate"
--L["Copy to"] = "Copy to"
--L["Delete group with %d spell(s)?"] = "Delete group with %d spell(s)?"
--L["Drag spells here"] = "Drag spells here"
L["Buff Groups"] = "Buff-Gruppen"

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
L["Missing cooldown icons must be enabled in Blizzard Cooldown Settings for this spec. If an icon is under Not Displayed, MCDM cannot add it."] = "Fehlende Cooldown-Icons muessen in den Blizzard-Abklingzeiten-Einstellungen fuer diese Spezialisierung aktiviert sein. Wenn ein Icon unter Not Displayed liegt, kann MCDM es nicht hinzufuegen."
L["No loaded cooldown icons are available. Open Blizzard Settings and move missing icons out of Not Displayed."] = "Keine geladenen Cooldown-Icons verfuegbar. Oeffne die Blizzard-Einstellungen und verschiebe fehlende Icons aus Not Displayed heraus."
L["All loaded cooldown icons are assigned to groups. Missing icons must be enabled in Blizzard Settings first."] = "Alle geladenen Cooldown-Icons sind Gruppen zugewiesen. Fehlende Icons muessen zuerst in den Blizzard-Einstellungen aktiviert werden."
--L["All spells are in groups"] = "All spells are in groups"

-----------------------------------------------------------------------
-- MidnightCooldownManager/ImportExport.lua
-----------------------------------------------------------------------

L["Invalid Base64 encoding"] = "Ungültige Base64-Kodierung"
L["Decompression failed"] = "Dekomprimierung fehlgeschlagen"
L["Invalid profile version"] = "Ungültige Profilversion"
L["Missing profile metadata"] = "Fehlende Profil-Metadaten"
--L["Profile is for a different addon"] = "Profile is for a different addon"
L["No import string provided"] = "Keine Import-Zeichenkette angegeben"
L["Failed to import profile"] = "Profil konnte nicht importiert werden"
--L["Select at least one category to export."] = "Select at least one category to export."
L["Profile is for a different addon: %s"] = "Profil gehört zu einem anderen Addon: %s"
L["Imported %d settings as '%s'"] = "%d Einstellungen als '%s' importiert"
L["Export Profile"] = "Profil exportieren"
L["Select categories to include, then click Export."] = "Kategorien auswählen und dann auf Exportieren klicken."
L["Export"] = "Exportieren"
L["Export String (Ctrl+C to copy):"] = "Export-Zeichenkette (Ctrl+C zum Kopieren):"
L["Profile exported! Copy the string above."] = "Profil exportiert! Die obige Zeichenkette kopieren."
L["Export failed."] = "Export fehlgeschlagen."
L["Import Profile"] = "Profil importieren"
L["Paste an export string below and click Import."] = "Eine Export-Zeichenkette unten einfügen und auf Importieren klicken."
L["Import"] = "Importieren"
L["Clear"] = "Leeren"
L["Import/Export"] = "Import/Export"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Profiles.lua
-----------------------------------------------------------------------

L["Already exists"] = "Bereits vorhanden"
L["Enter a name"] = "Namen eingeben"
--L["Failed to apply profile"] = "Failed to apply profile"
--L["Profile not found"] = "Profile not found"
--L["Cannot copy active profile"] = "Cannot copy active profile"
--L["Cannot delete active profile"] = "Cannot delete active profile"
L["Current Profile"] = "Aktuelles Profil"
L["New Profile"] = "Neues Profil"
L["Create"] = "Erstellen"
L["Copy From"] = "Kopieren von"
L["Copy all settings from another profile into the current one."] = "Alle Einstellungen aus einem anderen Profil in das aktuelle kopieren."
L["Select Source..."] = "Quelle auswählen..."
L["Manage"] = "Verwalten"
L["Reset Profile"] = "Profil zurücksetzen"
L["Delete Profile..."] = "Profil löschen..."
L["Default Profile for New Characters"] = "Standardprofil für neue Charaktere"
L["Specialization Profiles"] = "Spezialisierungsprofile"
L["Auto-switch profile per specialization"] = "Profil automatisch je Spezialisierung wechseln"
L["Spec %d"] = "Spezialisierung %d"
L["Profiles"] = "Profile"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "Benutzerdefinierten Zauber oder Gegenstand hinzufügen"
L["Spell"] = "Zauber"
L["Item"] = "Gegenstand"
L["Enter a valid ID"] = "Gültige ID eingeben"
L["Loading item data, try again"] = "Gegenstandsdaten werden geladen, erneut versuchen"
L["Unknown spell ID"] = "Unbekannte Zauber-ID"
L["Added: %s"] = "Hinzugefügt: %s"
L["Already tracked"] = "Wird bereits verfolgt"
L["Enable Racials"] = "Volksfertigkeiten aktivieren"
--L["Show Items at 0 Stacks"] = "Show Items at 0 Stacks"
L["Tracked Spells"] = "Verfolgte Zauber"
L["Manage Spells"] = "Zauber verwalten"
L["Icon Size"] = "Symbolgröße"
L["Party Frame Anchoring"] = "Gruppenrahmen-Verankerung"
L["Anchor to Party Frame"] = "Am Gruppenrahmen verankern"
L["Side (relative to Party Frame)"] = "Seite (relativ zum Gruppenrahmen)"
L["Party Frame X Offset"] = "Gruppenrahmen X-Versatz"
L["Party Frame Y Offset"] = "Gruppenrahmen Y-Versatz"
L["Anchor Position (relative to Player Frame)"] = "Ankerposition (relativ zum Spielerportrait)"
L["Cooldown"] = "Abklingzeit"
L["Stacks"] = "Stapel"
L["Text Position"] = "Textposition"
L["Text X Offset"] = "Text X-Versatz"
L["Text Y Offset"] = "Text Y-Versatz"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Defensives.lua
-----------------------------------------------------------------------

L["Add Custom Spell"] = "Benutzerdefinierten Zauber hinzufügen"
L["Spell ID"] = "Zauber-ID"
L["Enter a valid spell ID"] = "Gültige Zauber-ID eingeben"
L["Not available for spec"] = "Nicht für diese Spezialisierung verfügbar"
L["Enable Defensives"] = "Defensivfähigkeiten aktivieren"

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
L["Independent"] = "Unabhängig"
L["Append to Defensives"] = "An Defensivfähigkeiten anhängen"
L["Append to Spells"] = "An Zauber anhängen"
L["Row 1"] = "Reihe 1"
L["Row 2"] = "Reihe 2"
L["Start"] = "Anfang"
L["End"] = "Ende"
L["Enable Trinkets"] = "Schmuckstücke aktivieren"
--L["Manage Blacklist"] = "Manage Blacklist"
L["Layout Mode"] = "Layout-Modus"
L["Display Mode"] = "Anzeigemodus"
L["Row"] = "Reihe"
L["Position in Row"] = "Position in der Reihe"
L["Show Passive Trinkets"] = "Passive Schmuckstücke anzeigen"


-----------------------------------------------------------------------
-- MidnightCooldownManager/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "Abmessungen"
L["Bar Width (0 = Auto)"] = "Leistenbreite (0 = Auto)"
L["Bar Height"] = "Leistenhöhe"
L["Appearance"] = "Erscheinungsbild"
L["Background Color"] = "Hintergrundfarbe"
L["Growth Direction:"] = "Wachstumsrichtung:"
L["Down"] = "Unten"
L["Up"] = "Oben"
L["Icon Position:"] = "Symbolposition:"
L["Hidden"] = "Ausgeblendet"
L["Icon-Bar Gap"] = "Symbol-Leisten-Abstand"
L["Dual Bar Mode (2 bars per row)"] = "Doppelleisten-Modus (2 Leisten pro Reihe)"
L["Show Buff Name"] = "Buff-Namen anzeigen"
--L["Max Name Length (0 = Full)"] = "Max Name Length (0 = Full)"
L["Show Duration Text"] = "Dauertext anzeigen"
L["Show Stack Count"] = "Stapelanzahl anzeigen"
L["Notes"] = "Hinweise"
L["Border settings: see Borders tab"] = "Rahmen-Einstellungen: siehe Reiter Rahmen"
L["Text styling (font size, color, offsets): see Text tab"] = "Textgestaltung (Schriftgröße, Farbe, Versätze): siehe Reiter Text"
L["Position lock and X/Y controls: see Positions tab"] = "Positionssperre und X/Y-Steuerung: siehe Reiter Positionen"
L["Bars"] = "Leisten"


-----------------------------------------------------------------------
-- MidnightCooldownManager/Externals.lua
-----------------------------------------------------------------------

--L["Enable Externals"] = "Enable Externals"
--L["Disable Blink"] = "Disable Blink"

