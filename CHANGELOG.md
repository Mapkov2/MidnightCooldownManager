# Changelog

## 1.0 Beta 1 - 2026-06-24

- First public beta package for MidnightCooldownManager.
- Built around Blizzard's current Cooldown Manager data path for 12.0.7 and 12.1, with cached cooldown records, compatibility guards, and smoke diagnostics.
- Added custom cooldown groups, buff icon groups, buff bars, per-spell overrides, dummy previews, import/export, profile management, and spec-aware setup.
- Added class resources, player power bar, optional second HP bar, textures, color tabs, outlines, load conditions, preview zoom/pan/drag controls, and Ayije profile import coverage for resource settings.
- Added the Midnight superellipse options UI with dashboard, staged menu scaling, minimap/addon-compartment access, move mode, runtime tooltip toggles, MSUF-style controls, and clipping fixes across the main editor surfaces.
- Includes Ayije CDM-inspired defaults and migration helpers while keeping MCDM standalone and independently maintained.

## 1.0 Beta - 2026-06-23

- Split Midnight Simple Cooldown into its own standalone local repository.
- Added a GitHub Actions build/release pipeline for the two-addon-folder package.
- Added local validation and packaging scripts for repeatable release ZIPs.
- Included the current 12.1-compatible MCDM addon state with cooldown groups, buff icons, buff bars, class resources, player power, and second HP bar support.
