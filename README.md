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

## GitHub Release Pipeline

The release workflow builds the same two-folder ZIP and attaches it to a GitHub release. Wago and CurseForge uploads run only when the repository secrets/variables are configured.

Required for Wago:

- `WAGO_API_TOKEN`
- `WAGO_PROJECT_ID` as a repository variable or secret, or `## X-Wago-ID` in the TOC

Required for CurseForge:

- `CF_API_KEY`
- `CF_PROJECT_ID` as a repository variable or secret, or `## X-Curse-Project-ID` in the TOC
- `CF_GAME_VERSION_IDS` as comma-separated numeric CurseForge game-version ids

