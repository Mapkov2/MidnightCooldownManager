local CDM = _G["MidnightCooldownManager"]
local L = CDM:NewLocale("ptBR")
if not L then return end

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Enabled Blizzard Cooldown Manager."] = "Gerenciador de Cooldowns da Blizzard ativado."
--L["Config open queued until combat ends."] = "Config open queued until combat ends."
--L["Config open queued until login setup finishes."] = "Config open queued until login setup finishes."
L["Could not load options: %s"] = "Falha ao abrir as opções: %s"

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "Modo de Edição travado"
L["use /mcdm"] = "use /mcdm"
L["Edit Mode locked - use /mcdm"] = "Modo de Edição travado - use /mcdm"
L["Cooldown Viewer settings are managed by /mcdm."] = "As configs do Visualizador de Cooldowns são geridas pelo /mcdm."

-----------------------------------------------------------------------
-- Modules/BuffGroupOverlays.lua
-----------------------------------------------------------------------

--L["Ungrouped"] = "Ungrouped"

-----------------------------------------------------------------------
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- MidnightCooldownManager/Init.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "Você não pode abrir abrir as configs em combate!"
L["Invalid profile data"] = "Dados de perfil inválidos"
L["Copy this URL:"] = "Copie esta URL:"
L["Close"] = "Fechar"
L["Reset the current profile to default settings?"] = "Quer resetar o perfil atual para as configurações padrão?"
L["Reset"] = "Resetar"
L["Cancel"] = "Cancelar"
L["Copy"] = "Copiar"
L["Delete"] = "Excluir"

-----------------------------------------------------------------------
-- MidnightCooldownManager/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "Não dá pra %s em combate"
L["open CDM config"] = "abrir a config do CDM"
L["Display"] = "Visual"
L["Styling"] = "Estilo"
L["Buffs"] = "Buffs"
L["Features"] = "Funções"
L["Utility"] = "Utilitários"
L["Cooldown Manager"] = "Gerenciador de Cooldowns"
L["Settings"] = "Configurações"
--L["Edit Mode Settings"] = "Edit Mode Settings"
L["rebuild CDM config"] = "Reconstruir config do CDM"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "Essenciais"
L["Row 1 Width"] = "Largura da Linha 1"
L["Row 1 Height"] = "Altura da Linha 1"
L["Row 2 Width"] = "Largura da Linha 2"
L["Row 2 Height"] = "Altura da Linha 2"
L["Width"] = "Largura"
L["Height"] = "Altura"
L["Buff"] = "Buff"
L["Icon Sizes"] = "Tamanho dos Ícones"

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
L["Layout Settings"] = "Ajustes de Layout"
L["Icon Spacing"] = "Espaçamento dos Ícones"
L["Max Icons Per Row"] = "Máximo de Ícones por Linha"
L["Wrap Utility Bar"] = "Quebrar Linha da Barra de Utilitários"
L["Utility Max Icons Per Row"] = "Máximo de Ícones por Linha"
L["Unlock Utility Bar"] = "Destravar Barra de Utilitários"
L["Utility X Offset"] = "Ajuste X (Horizontal) dos Utilitários"
L["Display Vertical"] = "Exibir Verticalmente"
L["Layout"] = "Layout"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Positions.lua
-----------------------------------------------------------------------

L["Current: %s (%d, %d)"] = "Atual: %s (%d, %d)"
L["X Position"] = "Posição X"
L["Y Position"] = "Posição Y"
L["Essential Container Position"] = "Posição do Painel Essencial"
L["Utility Y Offset"] = "Ajuste Y (Vertical)"
L["Main Buff Container Position"] = "Posição do Painel de Buffs Principal"
L["Buff Bar Container Position"] = "Posição do Painel de Barras de Buffs"
L["Positions"] = "Posições"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "Configurações de Borda"
L["Border Texture"] = "Textura da Borda"
L["Select Border..."] = "Escolher Borda..."
L["Border Color"] = "Cor da Borda"
L["Border Size"] = "Tamanho da Borda"
L["Border Offset X"] = "Ajuste X da Borda"
L["Border Offset Y"] = "Ajuste Y da Borda"
L["Zoom Icons"] = "Dar Zoom nos Ícones"
--L["Zoom Amount"] = "Zoom Amount"
--L["Remove Shadow Overlay"] = "Remove Shadow Overlay"
--L["Remove Default Icon Mask"] = "Remove Default Icon Mask"
L["Visual Elements"] = "Elementos Visuais"
L["* These options require /reload to take effect"] = "* Essas opções precisam de /reload para funcionar"
L["Hide Debuff Border (red outline on harmful effects)"] = "Esconder Borda de Debuff (contorno vermelho em efeitos negativos)"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "Esconder Brilho de Recarga (o flash que dá quando o CD volta)"
--L["Pandemic Display"] = "Pandemic Display"
L["Hide Blizzard's Pandemic Indicator (animated refresh window border)"] = "Esconder Indicador de Pandemia da Blizzard (borda animada para renovar o DOT)"
--L["Enable Pandemic Customization"] = "Enable Pandemic Customization"
--L["Custom Pandemic Border"] = "Custom Pandemic Border"
L["Color"] = "Cor"
--L["Pandemic Glow"] = "Pandemic Glow"
--L["Charge Cooldowns"] = "Charge Cooldowns"
--L["Show Edge"] = "Show Edge"
--L["Hide Swipe"] = "Hide Swipe"
L["Borders"] = "Bordas"
--L["Look"] = "Look"
--L["Borders & Look"] = "Borders & Look"
--L["Hide Buff Swipe"] = "Hide Buff Swipe"
--L["Don't desaturate on cooldown"] = "Don't desaturate on cooldown"
--L["Hide recharge timer"] = "Hide recharge timer"
--L["Color Buff Bars Borders"] = "Color Buff Bars Borders"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Text.lua
-----------------------------------------------------------------------

L["None"] = "Nenhum"
L["Outline"] = "Contorno"
L["Thick Outline"] = "Contorno Grosso"
L["Slug"] = "Slug"
L["Font"] = "Fonte"
L["Font Outline"] = "Contorno da Fonte"
L["Cooldown Timer"] = "Timer de Cooldown"
--L["Cooldown Countdown Format"] = "Cooldown Countdown Format"
--L["Show decimals below (seconds, 0 = off)"] = "Show decimals below (seconds, 0 = off)"
--L["Threshold Color"] = "Threshold Color"
--L["Color countdown below threshold"] = "Color countdown below threshold"
--L["Threshold (seconds)"] = "Threshold (seconds)"
--L["Row 1 Font Size"] = "Row 1 Font Size"
--L["Row 2 Font Size"] = "Row 2 Font Size"
--L["Row 1 - Stacks (Charges)"] = "Row 1 - Stacks (Charges)"
L["Font Size"] = "Tamanho da Fonte"
L["Position"] = "Posição"
L["X Offset"] = "Ajuste X"
L["Y Offset"] = "Ajuste Y"
--L["Row 2 - Stacks (Charges)"] = "Row 2 - Stacks (Charges)"
--L["Stacks (Charges)"] = "Stacks (Charges)"
--L["Name Text"] = "Name Text"
L["Anchor"] = "Âncora"
--L["Duration Text"] = "Duration Text"
--L["Stack Count Text"] = "Stack Count Text"
--L["Global"] = "Global"
--L["Buff Icons"] = "Buff Icons"
L["Buff Bars"] = "Barras de Buffs"
L["Text"] = "Texto"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Glow.lua
-----------------------------------------------------------------------

L["Pixel Glow"] = "Brilho de Pixel"
L["Autocast Glow"] = "Brilho de Autocast"
L["Button Glow"] = "Brilho de Botão"
L["Proc Glow"] = "Brilho de Proc"
L["Glow Settings"] = "Ajustes de Brilho"
L["Glow Type"] = "Tipo de Brilho"
L["Use Custom Color"] = "Usar Cor Personalizada"
L["Glow Color"] = "Cor do Brilho"
L["Pixel Glow Settings"] = "Ajustes do Brilho de Pixel"
L["Lines"] = "Linhas"
L["Frequency"] = "Frequência"
L["Length (0=auto)"] = "Comprimento (0=auto)"
L["Thickness"] = "Espessura"
--L["Border"] = "Border"
L["Autocast Glow Settings"] = "Ajustes do Brilho de Autocast"
L["Particles"] = "Partículas"
L["Scale"] = "Escala"
L["Button Glow Settings"] = "Ajustes de Brilho do Botão"
L["Frequency (0=default)"] = "Frequência (0=padrão)"
L["Proc Glow Settings"] = "Ajustes do Brilho de Proc"
L["Duration (x10)"] = "Duração (x10)"
L["Glow"] = "Brilho"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "Transparência (Fade)"
L["Enable Fading"] = "Ativar Esmaecimento"
L["Fade Triggers"] = "Gatilhos do Fade"
L["Fade when no target"] = "Sumir quando estiver sem alvo"
L["Fade out of combat"] = "Sumir fora de combate"
L["Fade when mounted"] = "Sumir quando montado"
L["Faded Opacity"] = "Opacidade ao Sumir"
L["Apply Fading To"] = "Aplicar Fade em"
L["Racials"] = "Raciais"
L["Defensives"] = "Defensivos"
L["Trinkets"] = "Trinkets"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Assist.lua
-----------------------------------------------------------------------

--L["Press Overlay"] = "Press Overlay"
--L["Enable Press Overlay"] = "Enable Press Overlay"
--L["Color Tint"] = "Color Tint"
--L["Tint Color"] = "Tint Color"
--L["Highlight"] = "Highlight"
L["Rotation Assist"] = "Assistente de Rotação"
L["Enable Rotation Assist"] = "Ativar Assistente de Rotação"
L["Highlight Size"] = "Tamanho do brilho"
L["Keybindings"] = "Teclas de atalho"
L["Enable Keybind Text"] = "Ativar Texto das Teclas de Atalho"
L["Assist"] = "Assistente"

-----------------------------------------------------------------------
-- MidnightCooldownManager/GroupEditorShared.lua
-----------------------------------------------------------------------

--L["Text Overrides"] = "Text Overrides"
--L["Override Text Settings"] = "Override Text Settings"
--L["Cooldown Size"] = "Cooldown Size"
--L["Cooldown Color"] = "Cooldown Color"
--L["Charge Size"] = "Charge Size"
--L["Charge Color"] = "Charge Color"
L["Current Spec"] = "Especialização Atual"
--L["Grow Direction"] = "Grow Direction"
--L["Spacing"] = "Spacing"
L["Icon Width"] = "Largura do Ícone"
L["Icon Height"] = "Altura do Ícone"
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
L["Unknown"] = "Desconhecido"
L["Border:"] = "Borda:"
--L["Right-click icon to reset border color"] = "Right-click icon to reset border color"
L["Enable Glow"] = "Ativar Brilho"
L["Glow Color:"] = "Cor do Brilho:"
L["Spell ID:"] = "ID da Habilidade:"
L["Duration (sec):"] = "Duração (seg):"
--L["Save"] = "Save"
L["Invalid spell ID"] = "ID de Habilidade inválido"
L["Enter a valid duration"] = "Dê uma duração válida"
--L["Ungrouped Buffs"] = "Ungrouped Buffs"
--L["Add Spell to:"] = "Add Spell to:"
--L["Log %s to build spell list"] = "Log %s to build spell list"
--L["No untracked buff icons available for this spec"] = "No untracked buff icons available for this spec"
--L["All available icons are assigned to groups"] = "All available icons are assigned to groups"
--L["Add Custom Buff to:"] = "Add Custom Buff to:"
--L["Add Custom Buff"] = "Add Custom Buff"
--L["Quick Add"] = "Quick Add"
L["Add"] = "Adicionar"
--L["Custom Spell"] = "Custom Spell"
L["Add Spell"] = "Adicionar Habilidade"
L["Failed - invalid spell ID"] = "Falhou - ID da Habilidade inválido"
L["Added!"] = "Adicionado!"
--L["Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"] = "Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"
--L["Back"] = "Back"
--L["Add Group"] = "Add Group"
--L["Add Icon"] = "Add Icon"
--L["No ungrouped buffs"] = "No ungrouped buffs"
L["Rename"] = "Renomear"
--L["Duplicate"] = "Duplicate"
--L["Copy to"] = "Copy to"
--L["Delete group with %d spell(s)?"] = "Delete group with %d spell(s)?"
--L["Drag spells here"] = "Drag spells here"
L["Buff Groups"] = "Grupos de Buffs"

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

L["Invalid Base64 encoding"] = "Encoding de Base64 inválido"
L["Decompression failed"] = "Falha na descompressão"
L["Invalid profile version"] = "Versão do perfil inválida"
L["Missing profile metadata"] = "Metadados do perfil faltando"
--L["Profile is for a different addon"] = "Profile is for a different addon"
L["No import string provided"] = "Nenhuma string de importação fornecida"
L["Failed to import profile"] = "Erro ao importar perfil"
--L["Select at least one category to export."] = "Select at least one category to export."
L["Profile is for a different addon: %s"] = "O perfil é de outro addon: %s"
L["Imported %d settings as '%s'"] = "%d configurações importadas como '%s'"
L["Export Profile"] = "Exportar Perfil"
L["Select categories to include, then click Export."] = "Escolha as categorias e clique em Exportar."
L["Export"] = "Exportar"
L["Export String (Ctrl+C to copy):"] = "String de Exportação (Ctrl+C para copiar):"
L["Profile exported! Copy the string above."] = "Perfil exportado! Copie o código acima."
L["Export failed."] = "Falha ao exportar."
L["Import Profile"] = "Importar Perfil"
L["Paste an export string below and click Import."] = "Cole a string abaixo e clique em Importar."
L["Import"] = "Importar"
L["Clear"] = "Limpar"
L["Import/Export"] = "Importar/Exportar"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Profiles.lua
-----------------------------------------------------------------------

L["Already exists"] = "Já existe"
L["Enter a name"] = "Dê um nome"
--L["Failed to apply profile"] = "Failed to apply profile"
--L["Profile not found"] = "Profile not found"
--L["Cannot copy active profile"] = "Cannot copy active profile"
--L["Cannot delete active profile"] = "Cannot delete active profile"
L["Current Profile"] = "Perfil Atual"
L["New Profile"] = "Novo Perfil"
L["Create"] = "Criar"
L["Copy From"] = "Copiar de"
L["Copy all settings from another profile into the current one."] = "Copia as configurações de outro perfil para o atual."
L["Select Source..."] = "Escolher Origem..."
L["Manage"] = "Gerenciar"
L["Reset Profile"] = "Resetar Perfil"
L["Delete Profile..."] = "Excluir Perfil..."
L["Default Profile for New Characters"] = "Perfil Padrão para Novos Personagens"
L["Specialization Profiles"] = "Perfis por Especialização"
L["Auto-switch profile per specialization"] = "Trocar perfil automaticamente ao mudar de spec"
L["Spec %d"] = "Spec %d"
L["Profiles"] = "Perfis"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "Adicionar Habilidade ou Item Personalizado"
L["Spell"] = "Habilidade"
L["Item"] = "Item"
L["Enter a valid ID"] = "Insira um ID válido"
L["Loading item data, try again"] = "Carregando dados do item, tente de novo"
L["Unknown spell ID"] = "ID de Habilidade desconhecido"
L["Added: %s"] = "Adicionado: %s"
L["Already tracked"] = "Já está sendo rastreado"
L["Enable Racials"] = "Ativar Raciais"
--L["Show Items at 0 Stacks"] = "Show Items at 0 Stacks"
L["Tracked Spells"] = "Habilidades Rastreadas"
L["Manage Spells"] = "Gerenciar Habilidades"
L["Icon Size"] = "Tamanho do Ícone"
L["Party Frame Anchoring"] = "Fixar no Quadro do grupo"
L["Anchor to Party Frame"] = "Fixar no Quadro do grupo"
L["Side (relative to Party Frame)"] = "Lado (relativo ao Quadro de Grupo)"
L["Party Frame X Offset"] = "Ajuste X do Quadro de grupo"
L["Party Frame Y Offset"] = "Ajuste Y do Quadro de grupo"
L["Anchor Position (relative to Player Frame)"] = "Âncora (relativo ao Quadro do Personagem)"
L["Cooldown"] = "Cooldown"
L["Stacks"] = "Stacks"
L["Text Position"] = "Posição do Texto"
L["Text X Offset"] = "Ajuste X do Texto"
L["Text Y Offset"] = "Ajuste Y do Texto"

-----------------------------------------------------------------------
-- MidnightCooldownManager/Defensives.lua
-----------------------------------------------------------------------

L["Add Custom Spell"] = "Adicionar Habilidade Personalizada"
L["Spell ID"] = "ID da Habilidade"
L["Enter a valid spell ID"] = "Insira um ID de Habilidade válido"
L["Not available for spec"] = "Indisponível para esta especialização"
L["Enable Defensives"] = "Ativar Defensivos"

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
L["Independent"] = "Independente"
L["Append to Defensives"] = "Anexar aos Defensivos"
L["Append to Spells"] = "Anexar às Habilidades"
L["Row 1"] = "Linha 1"
L["Row 2"] = "Linha 2"
L["Start"] = "Início"
L["End"] = "Fim"
L["Enable Trinkets"] = "Ativar Trinkets"
--L["Manage Blacklist"] = "Manage Blacklist"
L["Layout Mode"] = "Modo de Layout"
L["Display Mode"] = "Modo de Exibição"
L["Row"] = "Linha"
L["Position in Row"] = "Posição na Linha"
L["Show Passive Trinkets"] = "Mostrar Trinkets Passivos"


-----------------------------------------------------------------------
-- MidnightCooldownManager/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "Dimensões"
L["Bar Width (0 = Auto)"] = "Largura da Barra (0 = Auto)"
L["Bar Height"] = "Altura da Barra"
L["Appearance"] = "Aparência"
L["Background Color"] = "Cor do Fundo"
L["Growth Direction:"] = "Direção de Crescimento:"
L["Down"] = "Para Baixo"
L["Up"] = "Para Cima"
L["Icon Position:"] = "Posição do Ícone:"
L["Hidden"] = "Oculto"
L["Icon-Bar Gap"] = "Espaço Ícone-Barra"
L["Dual Bar Mode (2 bars per row)"] = "Modo Barra Dupla (2 por linha)"
L["Show Buff Name"] = "Mostrar Nome do Buff"
--L["Max Name Length (0 = Full)"] = "Max Name Length (0 = Full)"
L["Show Duration Text"] = "Mostrar Duração"
L["Show Stack Count"] = "Mostrar Stacks"
L["Notes"] = "Notas"
L["Border settings: see Borders tab"] = "Ajustes de borda: veja na aba Bordas"
L["Text styling (font size, color, offsets): see Text tab"] = "Estilo de texto (fonte, cor, posição): veja na aba Texto"
L["Position lock and X/Y controls: see Positions tab"] = "Trava de posição e ajustes X/Y: veja na aba Posições"
L["Bars"] = "Barras"


-----------------------------------------------------------------------
-- MidnightCooldownManager/Externals.lua
-----------------------------------------------------------------------

--L["Enable Externals"] = "Enable Externals"
--L["Disable Blink"] = "Disable Blink"

