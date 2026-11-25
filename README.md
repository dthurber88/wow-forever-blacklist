# WoW Forever Blacklist

A small addon for **WoW: Forever** that keeps a personal blacklist of players you
do not want to group with. It saves the list between sessions and warns you in
chat when someone on it joins your party or raid.

## Install

1. Copy the `WoWForeverBlacklist` folder into your Forever AddOns directory:
   `World of Warcraft/_forever_/Interface/AddOns/`
2. Start the game (or `/reload`) and make sure the addon is enabled on the
   character select AddOns screen.

The list is stored account-wide in the `WoWForeverBlacklistDB` saved variable.

## Usage

| Command | Effect |
| --- | --- |
| `/blacklist add <Name[-Realm]> [reason]` | Add a player. Realm defaults to yours. The date is recorded automatically. |
| `/blacklist remove <Name[-Realm]>` | Remove a player. |
| `/blacklist list` | Show all entries with date added and reason. |

`/bl` works as a short alias. Example:

```
/blacklist add Badplayer-Area52 ninja'd loot in dungeon
```

When a blacklisted player joins your group, a warning with their reason is
printed to your chat frame. It is shown once per time they join.

## Interface version note

The TOC uses `## Interface: 16001`.

- Source: the Warcraft Wiki [TOC format](https://warcraft.wiki.gg/wiki/TOC_format)
  page lists **Forever = 16001** (Forever patch 1.60.1, 2026-11-04). Third-party
  addon guides and Questie's Forever TOC also use 16001.
- Confidence: **fairly high, but not verified in-game.** I found no Blizzard
  statement, and the wiki is community-maintained. Confirm in game with
  `/dump select(4, GetBuildInfo())`; if it differs, edit the `Interface` line.
- The addon uses only long-standing APIs (`GROUP_ROSTER_UPDATE`, `UnitFullName`,
  `SlashCmdList`, saved variables). It has not been run in the Forever client.

## Layout

- `WoWForeverBlacklist/WoWForeverBlacklist.toc`
- `WoWForeverBlacklist/WoWForeverBlacklist.lua`
