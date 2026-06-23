# Midnight Simple Cooldown

Midnight Simple Cooldown is a Retail World of Warcraft addon for cooldown icons, buff icons, buff bars, and class-resource/player bars with a Midnight-style options UI.

## Local Build

```powershell
pwsh ./tools/validate.ps1
pwsh ./tools/package-release.ps1 -Version "1.0 Beta"
```

The release ZIP is written to `dist/` and contains both addon folders:

- `MidnightCooldownManager`
- `MidnightCooldownManager_Options`

## In Game

- `/mcdm` opens the options menu.
- `/rl` reloads the UI.

