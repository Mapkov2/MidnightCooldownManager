local AddonName = "MidnightCooldownManager"
local CDM = _G[AddonName]
if not CDM then return end

local data = {
    currentVersion = "1.0.1 Beta",
    previousVersion = "1.0 Beta",
    rangeLabel = "1.0 Beta -> 1.0.1 Beta",
    entries = {
        {
            version = "1.0.1 Beta",
            date = "2026-06-23",
            sections = {
                {
                    title = "Release Context",
                    bullets = {
                        "Made the in-menu version label more readable and marked beta builds explicitly.",
                        "Kept the release in beta while continuing 12.1 PTR and retail validation.",
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
