# WoW Forever Blacklist

A small addon for **WoW: Forever** that keeps a personal blacklist of players you
do not want to group with. It saves the list between sessions and warns you in
chat when someone on it joins your party or raid, applies to your group, or is
already in a group you join.

In Forever a player is identified by a **first name and a last name**; there are
no realms. Entries here are `First Last`, compared case-insensitively.

## Install

1. Copy the `WoWForeverBlacklist` folder into your Forever AddOns directory:
   `World of Warcraft/_forever_/Interface/AddOns/`
2. Start the game (or `/reload`) and make sure the addon is enabled on the
   character select AddOns screen.

The list is stored account-wide in the `WoWForeverBlacklistDB` saved variable.
Entries saved by earlier versions keep working unchanged (`version = 3`); a
leftover `battletag` field on an old entry is ignored. (Data from versions before
v0.2 is still discarded.)

## Usage

| Command | Effect |
| --- | --- |
| `/blacklist add <First> <Last> [reason]` | Add a player. The date is recorded automatically. |
| `/blacklist remove <First> <Last>` | Remove a player. |
| `/blacklist list` | Show all entries with date added and reason. |
| `/blacklist window` | Open or close the blacklist window (see below). |

`/bl` works as a short alias. Example:

```
/blacklist add Ada Smith ninja'd loot in dungeon
```

### Right-click menu

Right-click a player (unit frame, party/raid frame, chat name, friend list) and
choose **Add to blacklist**. The entry is added with no reason; edit it in the
window. The item is not shown for yourself or for players already listed.

### Window

`/blacklist window` shows one row per entry: name, date added and
reason. Click into a reason to edit it; it is saved when you press
Enter or click away (Escape discards the edit). **Remove** asks for a second
click ("Sure?") before deleting. Scroll with the mouse wheel or the `<` `>`
buttons; drag to move; Escape closes it.

### Warnings

All warnings go to your chat frame and include the entry's reason.

- **Someone listed joins your group:** one warning per player, once per time they join.
- **You join a group that already has listed players:** a single warning that
  names every listed member found (a scan within 10 s of joining counts as "the
  group you joined", to cover members whose names load a moment late).
- **A listed player applies to your group** (group finder): warned once per
  application.

### Matching

Players match on first and last name only (case-insensitive).

BattleTags are not exposed to addons for players who are not your Battle.net
friends in this game version (tested live: `C_BattleNet.GetAccountInfoByGUID`
returned nothing for a target and a groupmate who were not friends), so the addon
does not use them.

## Not run in game

This code could not be run or loaded in a WoW client where it was written. It
passes a Lua 5.1 syntax check only. Everything below about the Forever API is
research, not observation. The addon wraps the uncertain calls in `pcall`, and
a feature that cannot work simply stays silent rather than erroring.

## In-game test checklist

Run `/reload` first and watch for Lua errors (`/console scriptErrors 1`).

1. **Existing data:** `/blacklist list` still shows entries saved by v0.2.
2. **Right-click menu:** right-click another player's unit frame, a party member,
   and a name in chat. Does **Add to blacklist** appear? Click it, then
   `/blacklist list`. Repeat on the same player: the item should be gone. If it
   never appears, you should have seen "Right-click menu is unavailable" at
   login (`Menu.ModifyMenu` missing), otherwise the unit-menu tags differ; report
   which menus you opened.
3. **Window:** `/blacklist window`. Edit a reason, press Enter, `/blacklist list`
   (reason changed). Click away instead of Enter (also saved). Press Remove twice
   (entry gone). Close with Escape. With over 10 entries, check `<` `>` and the
   mouse wheel.
4. **Applicant warning:** blacklist a friend, list your group in the group
   finder, and have that friend apply. Expect one warning. Declining and re-applying warns
   again. If nothing happens, run
   `/dump C_LFGList.GetApplicants()` and `/dump C_LFGList.GetApplicantMemberInfo(<id>, 1)`
   while an application is pending and note the name format.
5. **Joining a group with listed players:** list two members of a group, join it.
   Expect one message naming both. Leave and rejoin: warned again.
6. **Someone joins you:** list a player, invite them. Expect one warning.

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

### Right-click menu, applicants, group join (added in v0.3)

- **Right-click menu.** Retail's menus (10.0+) are built with
  `Menu.ModifyMenu(tag, callback(owner, rootDescription, contextData))`;
  `contextData` carries the unit token and `which`
  ([Patch 11.0.0 API changes](https://warcraft.wiki.gg/wiki/Patch_11.0.0/API_changes)).
  ForeverPlusPlus's in-game `/dump` (2026-09-25) shows `Menu.ModifyMenu` is a
  function on Forever, and the client function dump in
  [forever-addon-kit](https://github.com/Thunderz96/forever-addon-kit) has
  `UnitPopup_OpenMenu` and `UIDropDownMenu_*` but no `UnitPopup_ShowMenu`,
  consistent with the new menu system. Confidence that `Menu.ModifyMenu` exists:
  **high** (in-game). **Not established:** which `MENU_UNIT_*` tags Forever uses
  and what `contextData` holds (no source lists them). The addon registers a
  retail-style list of tags (player, party, raid, friend, target, focus, guild,
  chat roster, ...); unknown tags are harmless but also add nothing, and a
  `contextData` with neither a usable `unit` nor a `name` that splits into two
  words gets no menu item. ForeverPlusPlus reports menus opened *from addon code*
  taint the controller focus manager; this addon only adds an item to Blizzard's
  own menu and does not open menus. Confidence the item appears on the common
  menus: **medium**.
- **Group applicants.** Forever has `C_LFGList.GetApplicants`, `GetApplicantInfo`,
  `GetApplicantMemberInfo` and the events `LFG_LIST_APPLICANT_LIST_UPDATED` /
  `LFG_LIST_APPLICANT_UPDATED` (client dump + a generated API reference from
  build 70862: [justadakaje/wow-addons](https://github.com/justadakaje/wow-addons/blob/master/reference/api/C_LFGList.md)).
  `GetApplicants` and `GetApplicantMemberInfo` are listed there as *undocumented*,
  i.e. present but with no confirmed signature. Retail's
  [`GetApplicantMemberInfo(applicantID, memberIndex)`](https://warcraft.wiki.gg/wiki/API:C_LFGList.GetApplicantMemberInfo)
  returns the name first, as "Character name and realm". Whether Forever returns
  `First Last`, `First-Last` or `First` is **unknown**; the addon accepts the
  first two and ignores a lone first name. It calls everything through `pcall`,
  accepts both the table and the older multi-return form of `GetApplicantInfo`,
  and registers the two events in `pcall` (an unknown event throws). Confidence:
  functions and events exist **high**; the name format and signatures **low to
  medium**.
- **Group roster on joining.** Unchanged from v0.2 (`GROUP_ROSTER_UPDATE`, then
  `party1..4` / `raid1..n` with `UnitName`), which was tested in game. The new
  join warning only adds a "was I already in a group" flag. `GROUP_JOINED` was not
  found in any Forever source and is not used. Not established: whether member
  names are always loaded on the first update; the addon re-scans on every
  roster update and names anyone found late, using the same "joined" wording
  for 10 s.

## Interface version note

The TOC uses `## Interface: 16001` (re-checked 2026-11-25).

- The Warcraft Wiki [TOC format](https://warcraft.wiki.gg/wiki/TOC_format) page
  lists **Forever = 16001**; ForeverPlusPlus reports `GetBuildInfo()` returning
  `1.60.1, <build>, <date>, 16001` in game, and Forever addons such as Questie
  ship 16001. Confidence: **fairly high, not verified by me in game.** Confirm
  with `/dump select(4, GetBuildInfo())`; if it differs, edit the `Interface` line.

## Layout

- `WoWForeverBlacklist/WoWForeverBlacklist.toc`
- `WoWForeverBlacklist/WoWForeverBlacklist.lua` (one file: data, matching, warnings, menu, window)
