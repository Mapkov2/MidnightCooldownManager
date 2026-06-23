# Midnight Simple Cooldown

Midnight Simple Cooldown is a Retail World of Warcraft addon for cooldown icons, buff icons, buff bars, and class-resource/player bars with a Midnight-style options UI.

## Local Build

```powershell
pwsh ./tools/validate.ps1
pwsh ./tools/package-release.ps1 -Version "1.0 Beta 1"
```

The release ZIP is written to `dist/` and contains both addon folders:

- `MidnightCooldownManager`
- `MidnightCooldownManager_Options`

## In Game

- `/mcdm` opens the options menu.
- `/rl` reloads the UI.

# Midnight Cooldown Manager

Midnight Cooldown Manager is a clean, modern cooldown and buff tracking addon for World of Warcraft Retail. It builds on Blizzard's Cooldown Manager and gives you a much more polished, customizable, and readable frontend for your important abilities, buffs, trinkets, defensives, racials, class resources, and utility cooldowns.

Designed for players who want the important information close to their character without turning the UI into clutter.

## Features

- Track important cooldowns, buffs, buff bars, defensives, trinkets, racials, and externals
- Custom buff groups, cooldown groups, and bar groups per specialization
- Class resource display with customizable bars, colors, textures, spacing, and text
- Rotation Assist and Press Overlay options for clearer combat feedback
- Custom spell and item tracking
- Glow effects, borders, cooldown text, stack text, keybind text, and fading options
- Profile system with import/export support for sharing setups
- Spec-based profile switching
- Minimap button and addon compartment support
- Clean Midnight-style superellipse UI with pixel-sharp styling

## Configuration

Open the settings with:

`/mcdm`

Alternative commands:

`/midnightcdm`  
`/cdm`

## Notes

Some tracked buffs, bars, or cooldown icons must first be enabled in Blizzard's Cooldown Manager settings. If an ability is listed under "Not Displayed" in Blizzard settings, MCDM cannot add it until it is enabled there.

Midnight Cooldown Manager is built for Retail and focuses on a clean, fast, customizable combat UI.
