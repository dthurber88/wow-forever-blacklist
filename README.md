# WoW Forever Blacklist

A small addon for **WoW: Forever** that keeps a personal blacklist of players you
do not want to group with. It saves the list between sessions and warns you in
chat when someone on it joins your party or raid.

In Forever a player is identified by a **first name and a last name**, and there
are no realms: a **ruleset** (each backed by a megaserver) takes the realm's
place. Entries here are therefore `First Last` plus an optional ruleset.

## Install

1. Copy the `WoWForeverBlacklist` folder into your Forever AddOns directory:
   `World of Warcraft/_forever_/Interface/AddOns/`
2. Start the game (or `/reload`) and make sure the addon is enabled on the
   character select AddOns screen.

The list is stored account-wide in the `WoWForeverBlacklistDB` saved variable.
Data saved by v0.1 (single name + realm) is discarded on first load.

## Usage

| Command | Effect |
| --- | --- |
| `/blacklist add <First> <Last> [Ruleset] [reason]` | Add a player. The date is recorded automatically. |
| `/blacklist remove <First> <Last> [Ruleset]` | Remove a player. |
| `/blacklist list` | Show all entries with ruleset, date added and reason. |

`/bl` works as a short alias. The ruleset goes in square brackets because
ruleset names contain spaces. Examples:

```
/blacklist add Ada Smith ninja'd loot in dungeon
/blacklist add Ada Smith [Classic Beta PvE] ninja'd loot in dungeon
/blacklist remove Ada Smith [Classic Beta PvE]
```

When a blacklisted player joins your group, a warning with their ruleset and
reason is printed to your chat frame. It is shown once per time they join.

### Matching when the ruleset is unknown or omitted

- **Entry without a ruleset** (`any ruleset`): matches that first and last name
  on every ruleset. This is the default when you leave the brackets out.
- **Entry with a ruleset**: matches that name when the player's ruleset is that
  ruleset *or when the player's ruleset is unknown*. The addon currently has no
  way to read a group member's ruleset (see below), so in practice every entry
  matches on name alone. It errs on the side of warning you.
- Names and rulesets are compared case-insensitively.
- `remove` without a ruleset removes the entry if exactly one entry has that
  name; if there are several (different rulesets) it asks you to specify one.

## What was found about the Forever API, and how sure I am

No official Blizzard API documentation was available. Everything below comes
from community sources, mostly addon authors reporting in-game results, and
**none of it has been verified by running this addon in the Forever client.**

- **First and last name** — `UnitName(unit)` (and `UnitFullName`,
  `UnitNameUnmodified`) return the *first name* and the *last name (surname)* as
  the first and second values; the second slot is where other clients return the
  realm. `GetUnitName` returns them joined as one `"First Last"` string.
  Sources: [ForeverPlusPlus API notes](https://github.com/xIGBClutchIx/ForeverPlusPlus/blob/main/docs/forever-api.md)
  (in-game, build 70009), [AllTheThings #2630](https://github.com/ATTWoWAddon/AllTheThings/issues/2630),
  [polestar #1019](https://github.com/fitzforge/polestar/pull/1019) (quotes Forever's
  own `NameUtil.lua`: `local name, surname = UnitName(unit)`).
  Confidence: **fairly high.**
- **Group members** — party/raid units appear to follow the same two-value
  form (`"Ana", "Smith"`), but I only found this in addon code and issue reports,
  not a direct test. Names sent between players (addon messages) arrive as
  `"First Last"` with a space, not `First-Last`. Confidence: **medium.** The addon
  accepts either two return values or a single combined `"First Last"` string,
  and skips a unit it cannot split into two names.
- **Ruleset** — I could not establish a reliable way to read it. `GetRealmName()`
  reportedly returns a ruleset/server string on Forever (e.g.
  `"... Realm 1 PvE"`), but a Wowhead/LazyGrip report says Blizzard intends to
  make `GetRealmName`/`GetRealmID` return empty/zero, and I could not confirm that
  or whether it is live. I found **no API for another player's ruleset**, and a
  ruleset spans several realm IDs, so GUIDs don't help. Confidence that a
  member's ruleset is readable: **low / not established.** The ruleset on an entry
  is therefore whatever you type, and it is not compared against group members.
  If a member-ruleset API is found, `UnitRuleset()` in the Lua file is the only
  place to change.
- **Invite/whisper formatting** — not used by this addon (no automation).

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
