# Changelog

## 0.2.2 - 2026-05-18

Arena taint follow-up.

### Fixed

- Protected priority aura lookups from secret-key taint during hostile unit scans
- Hardened arena target handling against secret boolean and secret number aura values
- Kept arena1 through arena5 nameplate lookups safely gated away from forbidden API calls

## 0.2.1 - 2026-05-18

Arena target aura stability update.

### Fixed

- Prevented forbidden nameplate API calls for `arena1` through `arena5` by skipping direct nameplate lookups for arena unit tokens and wrapping calls safely
- Fixed taint-sensitive aura ordering by protecting numeric aura comparisons against secret/protected aura values
- Restored arena hostile helpful-aura evaluation so arena icon updates reflect current buff state correctly

### Changed

- Expanded stealable buff detection to handle multiple Retail aura flags (`isStealable`, `canStealOrPurge`, `canActivePlayerDispel`) and magic dispel type fallback

## 0.2.0 - 2026-05-18

Hostile target aura tracking refresh.

### Changed

- Reworked hostile target aura detection to use Blizzard nameplate aura state and short-lived fallback retention when hostile aura updates briefly clear
- Hardened hostile aura handling against Retail secret aura values in debug, priority matching, and cache paths
- Moved mutable button visuals onto a non-secure overlay so icon state updates are not blocked by secure button restrictions in combat
- Restored the main settings panel scrollbar
- Expanded target debug output for hostile aura troubleshooting

## 0.1.0 - 2026-05-17

Initial public release.

### Added

- Spellsteal tracking for `target`, `focus`, and `arena1` through `arena5`
- Secure clickable unit buttons for casting Spellsteal
- Range-aware icon and border state updates
- Draggable tracker header with right-click settings access
- Settings panel for scale, icon size, spacing, orientation, lock state, and arena visibility
- Arena-opponent-count-based icon visibility
- Configurable priority aura highlighting with glow and pixel border
- Editable priority spell list in settings
- Header tooltip help for movement, settings, and slash commands
- Slash commands for `lock`, `reset`, and `settings`
- Secret-aura-safe scanning for WoW Retail enemy units
