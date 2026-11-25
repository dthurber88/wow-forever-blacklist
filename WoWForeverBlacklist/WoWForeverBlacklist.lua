-- WoW Forever Blacklist
-- Slash command: /blacklist (alias /bl). See README.md for usage.
--
-- Player model (WoW: Forever): a player is a first name + last name. There are
-- no realms; a ruleset takes that role. Entries may omit the ruleset, in which
-- case they match that first/last name on any ruleset.

local ADDON = "WoWForeverBlacklist"
local PREFIX = "|cffff4040[Blacklist]|r "
local DB_VERSION = 2

local db            -- saved: db.entries[key] = { first, last, ruleset (or nil), reason, added }
local warned = {}   -- entry keys already warned about while still in the group

local function Print(msg)
    print(PREFIX .. msg)
end

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "ada" -> "Ada", "o'neil" -> "O'neil". Display only; comparisons are case-insensitive.
local function Capitalize(s)
    return (s:gsub("^%l", string.upper))
end

-- Rulesets compare case-insensitively with whitespace collapsed.
local function NormalizeRuleset(ruleset)
    if not ruleset then return nil end
    ruleset = Trim(ruleset):gsub("%s+", " ")
    if ruleset == "" then return nil end
    return ruleset
end

local function RulesetKey(ruleset)
    return ruleset and ruleset:lower() or ""
end

local function MakeKey(first, last, ruleset)
    return (first .. " " .. last):lower() .. "|" .. RulesetKey(ruleset)
end

local function FullName(first, last)
    return first .. " " .. last
end

local function Describe(e)
    return FullName(e.first, e.last) .. " [" .. (e.ruleset or "any ruleset") .. "]"
end

-- Ruleset of a group member. No API for this could be established, so it is
-- unknown (nil) and ruleset-specific entries still match on name alone.
local function UnitRuleset(unit)
    return nil
end

-- Parse "First Last [Ruleset] reason words". Returns first, last, ruleset, reason
-- or nil if first/last are missing.
local function ParseTarget(input)
    input = Trim(input)
    local head, ruleset, rest = input:match("^(.-)%[(.-)%](.*)$")
    if not head then
        head, ruleset, rest = input, nil, ""
    end
    local first, last, tail = head:match("^(%S+)%s+(%S+)%s*(.*)$")
    if not first then return nil end
    local reason = Trim(tail .. " " .. rest)
    if reason == "" then reason = nil end
    return Capitalize(first), Capitalize(last), NormalizeRuleset(ruleset), reason
end

-- Entries matching a first/last name; if ruleset is given, an entry matches when
-- it is for that ruleset or for any ruleset. If ruleset is nil (unknown), every
-- entry for that name matches.
local function FindEntries(first, last, ruleset)
    local out = {}
    local name = (first .. " " .. last):lower()
    for key, e in pairs(db.entries) do
        if (e.first .. " " .. e.last):lower() == name then
            if not ruleset or not e.ruleset or e.ruleset:lower() == ruleset:lower() then
                out[#out + 1] = key
            end
        end
    end
    return out
end

local function Add(input)
    local first, last, ruleset, reason = ParseTarget(input)
    if not first then return false end
    local key = MakeKey(first, last, ruleset)
    local entry = { first = first, last = last, ruleset = ruleset, reason = reason, added = date("%Y-%m-%d") }
    if db.entries[key] then
        Print(Describe(entry) .. " is already on the blacklist.")
        return true
    end
    db.entries[key] = entry
    Print("Added " .. Describe(entry) .. ".")
    return true
end

local function Remove(input)
    local first, last, ruleset = ParseTarget(input)
    if not first then return false end
    local exact = db.entries[MakeKey(first, last, ruleset)]
    if exact then
        db.entries[MakeKey(first, last, ruleset)] = nil
        Print("Removed " .. Describe(exact) .. ".")
        return true
    end
    -- No exact match: with no ruleset given, remove the entry if it is unambiguous.
    local keys = ruleset and {} or FindEntries(first, last, nil)
    if #keys == 1 then
        local e = db.entries[keys[1]]
        db.entries[keys[1]] = nil
        Print("Removed " .. Describe(e) .. ".")
    elseif #keys > 1 then
        Print(FullName(first, last) .. " has several entries; specify one: /blacklist remove " ..
            FullName(first, last) .. " [Ruleset]")
    else
        Print(FullName(first, last) .. (ruleset and (" [" .. ruleset .. "]") or "") .. " is not on the blacklist.")
    end
    return true
end

local function EntryLine(e)
    return string.format("%s (added %s)%s", Describe(e), e.added or "?",
        e.reason and (": " .. e.reason) or "")
end

local function List()
    local entries = {}
    for _, entry in pairs(db.entries) do
        entries[#entries + 1] = entry
    end
    if #entries == 0 then
        Print("The blacklist is empty.")
        return
    end
    table.sort(entries, function(a, b)
        return (a.first .. " " .. a.last .. "|" .. (a.ruleset or "")):lower()
             < (b.first .. " " .. b.last .. "|" .. (b.ruleset or "")):lower()
    end)
    Print(#entries .. " blacklisted player(s):")
    for _, e in ipairs(entries) do
        print("  " .. EntryLine(e))
    end
end

-- Returns first, last for a unit. On Forever UnitName returns first name and
-- surname. Tolerates a single combined "First Last" string, and a missing last
-- name (returns nil, which never matches an entry).
local function UnitFirstLast(unit)
    local first, last = UnitName(unit)
    if not first then return nil end
    if not last or last == "" then
        local a, b = first:match("^(%S+)[%s%-]+(%S+)$")
        if not a then return nil end
        first, last = a, b
    end
    return first, last
end

local function CheckGroup()
    if not IsInGroup() then
        wipe(warned)
        return
    end
    local prefix = IsInRaid() and "raid" or "party"
    local present = {}
    for i = 1, GetNumGroupMembers() do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local first, last = UnitFirstLast(unit)
            if first then
                for _, key in ipairs(FindEntries(first, last, UnitRuleset(unit))) do
                    local entry = db.entries[key]
                    -- Warn key includes the member's name so each joiner warns once.
                    local wkey = key .. "#" .. (first .. " " .. last):lower()
                    present[wkey] = true
                    if not warned[wkey] then
                        warned[wkey] = true
                        Print("WARNING: blacklisted player " .. FullName(first, last) .. " joined your group. " ..
                            "Entry: " .. EntryLine(entry))
                    end
                end
            end
        end
    end
    -- Forget players who left, so they are warned about again if they rejoin.
    for key in pairs(warned) do
        if not present[key] then warned[key] = nil end
    end
end

local function PrintHelp()
    Print("Usage:")
    print("  /blacklist add <First> <Last> [Ruleset] [reason]")
    print("  /blacklist remove <First> <Last> [Ruleset]")
    print("  /blacklist list")
    print("  Ruleset is optional; in square brackets. Omit it to match any ruleset.")
end

SLASH_WOWFOREVERBLACKLIST1 = "/blacklist"
SLASH_WOWFOREVERBLACKLIST2 = "/bl"
SlashCmdList["WOWFOREVERBLACKLIST"] = function(msg)
    if not db then return end
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "add" then
        if not Add(rest) then PrintHelp() end
    elseif cmd == "remove" or cmd == "del" then
        if not Remove(rest) then PrintHelp() end
    elseif cmd == "list" then
        List()
    else
        PrintHelp()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        WoWForeverBlacklistDB = WoWForeverBlacklistDB or {}
        -- v1 saved data (single name + realm) is dropped; there are no users yet.
        if WoWForeverBlacklistDB.version ~= DB_VERSION then
            WoWForeverBlacklistDB = { version = DB_VERSION, entries = {} }
        end
        db = WoWForeverBlacklistDB
    elseif event == "GROUP_ROSTER_UPDATE" and db then
        CheckGroup()
    end
end)
