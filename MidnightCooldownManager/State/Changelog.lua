local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]
if not CDM then return end

local data = {
    currentVersion = "1.0 Beta 1",
    previousVersion = "1.0 Beta",
    rangeLabel = "1.0 Beta -> 1.0 Beta 1",
    entries = {
        {
            version = "1.0 Beta 1",
            date = "2026-06-24",
            sections = {
                {
                    title = "Release Context",
                    bullets = {
                        "Prepared the first public beta package for MidnightCooldownManager.",
                        "Marked the build clearly as beta and prepared release metadata for GitHub, Wago, and CurseForge.",
                        "Kept the release focused on cooldown groups, buff icon groups, buff bars, class resources, player power, and optional second HP bar.",
                    },
                },
                {
                    title = "12.1 Backend",
                    bullets = {
                        "Built around Blizzard's current Cooldown Manager data path for 12.0.7 and 12.1.",
                        "Cached cooldown records, category lookups, group matching, viewer catalog state, and frame iteration to avoid redundant runtime work.",
                        "Added PTR smoke diagnostics for interface versions, viewer frame state, active records, compatibility APIs, and group counts.",
                    },
                },
                {
                    title = "Frontend",
                    bullets = {
                        "Rebuilt the options UI in Midnight superellipse style with MSUF-like switches, sliders, dropdowns, panels, and staged menu scaling.",
                        "Added dashboard overview, setup checks, move mode, minimap/addon-compartment access, runtime tooltip toggles, and support/changelog sections.",
                        "Reduced clipping across resource previews, group editors, tracker dialogs, profile/import pages, and scrollable panels.",
                    },
                },
                {
                    title = "Tracking Features",
                    bullets = {
                        "Added custom cooldown groups, buff icon groups, buff bars, per-spell overrides, dummy previews, and blacklists.",
                        "Added class resources, player power bar, optional second HP bar, texture controls, color tabs, outlines, load conditions, and preview zoom/pan/drag controls.",
                        "Added support for empowered combo points, Frost Mage Icicles, and Ayije CDM-inspired defaults.",
                    },
                },
                {
                    title = "Profiles And Migration",
                    bullets = {
                        "Added MCDM profile import/export and Ayije profile import coverage for cooldowns, buffs, bars, class resources, player power, and second HP settings.",
                        "Kept import behavior explicit and reversible through the normal profile workflow.",
                        "Kept MCDM standalone and independently maintained while preserving familiar Ayije-style setup quality.",
                    },
                },
            },
        },
        {
            version = "1.0 Beta",
            date = "2026-06-23",
            sections = {
                {
                    title = "Release Context",
                    bullets = {
                        "Renamed the public product to MidnightCooldownManager while keeping the internal addon folders and SavedVariables stable.",
                        "Prepared the first 1.0 Beta package for 12.1 testing.",
                        "Focused the addon on cooldown groups, buff icon groups, buff bars, class resources, player power, and optional second HP bar.",
                    },
                },
                {
                    title = "12.1 Backend",
                    bullets = {
                        "Moved cooldown viewer reads onto the current cooldownID/cooldownInfo oriented path with cached records and compatibility guards.",
                        "Added smoke diagnostics for PTR validation, active viewer counting, record layer generation, and API availability.",
                        "Reduced redundant viewer scans by centralizing cooldown records, category lookups, group matching, and frame iteration.",
                    },
                },
                {
                    title = "Frontend",
                    bullets = {
                        "Rebuilt the options UI in a Midnight superellipse style with dashboard, MSUF-like switches, sliders, dropdowns, previews, and grouped sections.",
                        "Added a dashboard with setup state, runtime overview, quick actions, maintenance shortcuts, and this changelog viewer.",
                        "Fixed overlay and scrollbar clipping in cooldown, buff, racial, defensive, trinket, and import/profile surfaces.",
                    },
                },
                {
                    title = "Class Resources",
                    bullets = {
                        "Added class resource runtime, player power bar, and optional second HP bar with preview controls.",
                        "Added texture, color, outline, load condition, text, smooth fill, and layout controls for the resource stack.",
                        "Added support for empowered combo points and Frost Mage Icicles.",
                    },
                },
                {
                    title = "Profile And Import",
                    bullets = {
                        "Added Ayije profile import coverage for cooldown groups, buff groups, bars, class resources, player power, and second HP settings.",
                        "Kept import behavior explicit and reversible through the normal profile workflow.",
                        "Kept exported MCDM profiles on the existing !MCDM wire prefix for compatibility with earlier test builds.",
                    },
                },
            },
        },
    },
}

CDM.Changelog = data
_G.MCDM_Changelog = data
