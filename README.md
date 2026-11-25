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
Entries saved by v0.2 keep working unchanged: the saved format is the same
(`version = 3`); the new optional `battletag` field is simply absent on them, so
no migration is needed. (Data from versions before v0.2 is still discarded.)

## Usage

| Command | Effect |
| --- | --- |
| `/blacklist add <First> <Last> [reason]` | Add a player. The date is recorded automatically. |
| `/blacklist remove <First> <Last>` | Remove a player. |
| `/blacklist list` | Show all entries with date added and reason. |
| `/blacklist window` | Open or close the blacklist window (see below). |
| `/blacklist battletag <First> <Last> <Name#1234>` | Set the BattleTag of an existing entry by hand (`none` clears it). |

`/bl` works as a short alias. Example:

```
/blacklist add Ada Smith ninja'd loot in dungeon
```

### Right-click menu

Right-click a player (unit frame, party/raid frame, chat name, friend list) and
choose **Add to blacklist**. The entry is added with no reason; edit it in the
window. The item is not shown for yourself or for players already listed.

### Window

`/blacklist window` shows one row per entry: name, BattleTag (`-` if unknown),
date added and reason. Click into a reason to edit it; it is saved when you press
Enter or click away (Escape discards the edit). **Remove** asks for a second
click ("Sure?") before deleting. Scroll with the mouse wheel or the up/down
arrow buttons; drag to move; the title-bar X or Escape closes it.

The window uses the game's stock templates (`BasicFrameTemplateWithInset`,
`UIPanelButtonTemplate`, `InputBoxTemplate`, `UIPanelScrollUp/DownButtonTemplate`,
`UIPanelCloseButton`). Each is created through `pcall`, so one missing in Forever
falls back to a plainer look instead of an error.

### Warnings

All warnings go to your chat frame and include the entry's reason.

- **Someone listed joins your group:** one warning per player, once per time they join.
- **You join a group that already has listed players:** a single warning that
  names every listed member found (a scan within 10 s of joining counts as "the
  group you joined", to cover members whose names load a moment late).
- **A listed player applies to your group** (group finder): warned once per
  application.

### Matching

Players match on first and last name (case-insensitive) **or** on BattleTag when
both sides have one. See the BattleTag section below for where a BattleTag can be
read at all.

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
   (entry gone). Close with Escape. With over 10 entries, check the arrow
   buttons and the mouse wheel; the window should look like a default panel.
4. **Applicant warning:** blacklist a friend, list your group in the group
   finder, and have that friend apply. Expect one warning. Declining and re-applying warns
   again. If nothing happens, run
   `/dump C_LFGList.GetApplicants()` and `/dump C_LFGList.GetApplicantMemberInfo(<id>, 1)`
   while an application is pending and note the name format.
5. **Joining a group with listed players:** list two members of a group, join it.
   Expect one message naming both. Leave and rejoin: warned again.
6. **Someone joins you:** list a player, invite them. Expect one warning.
7. **BattleTag:** `/dump C_BattleNet.GetAccountInfoByGUID(UnitGUID("party1"))` for a
   Battle.net friend and for a stranger. A friend should return a table with
   `battleTag`; if the stranger also does, matching by BattleTag works for more
   than friends. Add the friend through the menu and check the window shows the tag.

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

### BattleTag

Asked: can an addon read another player's BattleTag (Blizzard's ignore list uses
them), and does it identify an account or a character?

- **What it identifies.** A BattleTag (`Name#1234`) identifies a Battle.net
  **account**; characters are separate (`BNetGameAccountInfo`). Matching on it
  therefore catches a player's other characters, which name matching cannot.
  ([BNGetInfo](https://warcraft.wiki.gg/wiki/API:BNGetInfo),
  [BNetAccountInfo](https://warcraft.wiki.gg/wiki/Struct_BNetAccountInfo).)
  Confidence: **high** (documented structure; the wiki does not say it in so many words).
- **Group member.** The only route is
  `C_BattleNet.GetAccountInfoByGUID(UnitGUID(unit))`, whose `battleTag` field is
  documented only for **Battle.net friends** ([API page](https://warcraft.wiki.gg/wiki/API:C_BattleNet.GetAccountInfoByGUID)).
  Retail's own UI treats a non-nil result as "this is a friend". The function
  exists in the Forever client dump. **Unverified in Forever:** what it returns for
  non-friends, and whether Battle.net friends are enabled there (Forever's friends
  window and `C_BattleNet.GetAccountInfoByID` use by another Forever addon suggest
  yes). Expectation: BattleTag is readable for friends only.
- **Applicant.** Not readable: `GetApplicantMemberInfo` returns a name and a
  friend flag but no GUID or tag. Applicants are matched on name only.
- **Right-click target.** Blizzard resolves the same `GetAccountInfoByGUID` from
  the menu's unit/GUID; the addon does likewise when the context has a unit (or a
  `guid` field, an unconfirmed field name). Strangers are expected to return
  nothing.
- **Ignore list.** Nothing found says whether Forever's ignore list uses
  BattleTags. Not established.

What the addon does with that: it stores a `battletag` on an entry when one can be
read (menu add, or filled in later when a matching group member's tag is readable),
shows it in `/blacklist list` and the window, and matches a player on name **or**
BattleTag. Group members are matched by tag where readable; applicants by name
only. You can set a tag by hand with `/blacklist battletag`. In practice, expect
tags only for Battle.net friends until the `/dump` in the test checklist shows
otherwise. Overall confidence that tags are readable beyond friends: **low**.

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
