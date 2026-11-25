# WoW Forever Blacklist

A small addon for **WoW: Forever** that keeps a personal blacklist of players you
do not want to group with. It saves the list between sessions and warns you in
chat when someone on it joins your party or raid.

In Forever a player is identified by a **first name and a last name**; there are
no realms. Entries here are `First Last`, compared case-insensitively.

## Install

1. Copy the `WoWForeverBlacklist` folder into your Forever AddOns directory:
   `World of Warcraft/_forever_/Interface/AddOns/`
2. Start the game (or `/reload`) and make sure the addon is enabled on the
   character select AddOns screen.

The list is stored account-wide in the `WoWForeverBlacklistDB` saved variable.
Data saved by earlier versions is discarded on first load.

## Usage

| Command | Effect |
| --- | --- |
| `/blacklist add <First> <Last> [reason]` | Add a player. The date is recorded automatically. |
| `/blacklist remove <First> <Last>` | Remove a player. |
| `/blacklist list` | Show all entries with date added and reason. |

`/bl` works as a short alias. Example:

```
/blacklist add Ada Smith ninja'd loot in dungeon
```

When a blacklisted player joins your group, a warning with their reason is
printed to your chat frame. It is shown once per time they join.

## What was found about the Forever API, and how sure I am

No official Blizzard API documentation was available. Everything below comes
from community sources, mostly addon authors reporting in-game results, and
**none of it has been verified by running this addon in the Forever client.**

- **First and last name**: `UnitName(unit)` (and `UnitFullName`,
  `UnitNameUnmodified`) return the *first name* and the *last name (surname)* as
  the first and second values; the second slot is where other clients return the
  realm. `GetUnitName` returns them joined as one `"First Last"` string.
  Sources: [ForeverPlusPlus API notes](https://github.com/xIGBClutchIx/ForeverPlusPlus/blob/main/docs/forever-api.md)
  (in-game, build 70009), [AllTheThings #2630](https://github.com/ATTWoWAddon/AllTheThings/issues/2630),
  [polestar #1019](https://github.com/fitzforge/polestar/pull/1019) (quotes Forever's
  own `NameUtil.lua`: `local name, surname = UnitName(unit)`).
  Confidence: **fairly high.**
- **Group members**: party/raid units appear to follow the same two-value
  form (`"Ana", "Smith"`), but I only found this in addon code and issue reports,
  not a direct test. Names sent between players (addon messages) arrive as
  `"First Last"` with a space, not `First-Last`. Confidence: **medium.** The addon
  accepts either two return values or a single combined `"First Last"` string,
  and skips a unit it cannot split into two names.
- **Rulesets**: not used. `GetRealmName()` returns an empty string in the live
  game and there is no way to read another player's ruleset, so players are
  identified by first and last name only.

## Interface version note

The TOC uses `## Interface: 16001` (re-checked 2026-11-25).

- The Warcraft Wiki [TOC format](https://warcraft.wiki.gg/wiki/TOC_format) page
  lists **Forever = 16001**; ForeverPlusPlus reports `GetBuildInfo()` returning
  `1.60.1, <build>, <date>, 16001` in game, and Forever addons such as Questie
  ship 16001. Confidence: **fairly high, not verified by me in game.** Confirm
  with `/dump select(4, GetBuildInfo())`; if it differs, edit the `Interface` line.

## Layout

- `WoWForeverBlacklist/WoWForeverBlacklist.toc`
- `WoWForeverBlacklist/WoWForeverBlacklist.lua`
