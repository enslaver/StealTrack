# StealTrack

StealTrack is a World of Warcraft Retail addon for Mages that watches common enemy unit tokens for Spellsteal targets and presents them as clickable secure buttons.

## What It Does

- Tracks `target`, `focus`, and `arena1` through `arena5`
- Detects the first stealable aura found on each tracked unit
- Checks whether Spellsteal is in range for that unit
- Shows a labeled icon for each tracked unit
- Lets you click the icon to cast Spellsteal on that specific unit
- Highlights configured priority buffs with a glow and pixel border
- Lets you edit the priority buff list in settings

## Features

- Secure click-to-cast Spellsteal buttons
- Range coloring for in-range and out-of-range targets
- Draggable tracker header
- Right-click header shortcut to open settings
- Slash commands for lock, reset, and settings
- Adjustable scale, icon size, spacing, and orientation
- Arena target support up to `arena5`
- Option to hide arena targets outside arena instances
- Arena icon count automatically matches the active opponent count

## Usage

- Left-click an icon to cast Spellsteal on that unit
- Mouse over the header for quick controls and slash command help
- Left-drag the header to move the tracker when it is unlocked
- Right-click the header to open settings

### Slash Commands

- `/st lock` toggles the tracker lock state
- `/st reset` resets the tracker position
- `/st settings` opens the settings panel
- `/stealtrack` is also available as the full slash command

## Settings

The settings panel lets you:

- Lock or unlock the tracker position
- Adjust tracker scale
- Change icon size
- Change spacing between icons
- Switch between horizontal and vertical layout
- Hide arena targets outside arena instances
- Edit the list of priority spell names to highlight
- Reset the tracker position

## Installation

1. Copy the `StealTrack` folder into your `World of Warcraft/_retail_/Interface/AddOns` directory.
2. Reload the UI or restart the game.
3. Enable the addon from the character selection AddOns menu if needed.

## Notes

- This addon is intended for WoW Retail.
- Some enemy auras can be hidden by Blizzard's secret aura restrictions. When that happens, the addon cannot read those aura details, so those buffs cannot be shown or highlighted.
- Spellsteal tracking only applies to Mages who know Spellsteal.
