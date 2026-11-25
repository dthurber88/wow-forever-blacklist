-- WoW Forever Blacklist
-- Slash command: /blacklist (alias /bl). See README.md for usage.
--
-- Player model (WoW: Forever): a player is a first name + last name. There are
-- no realms, and no way to read another player's ruleset, so names alone are used.

local ADDON = "WoWForeverBlacklist"
local PREFIX = "|cffff4040[Blacklist]|r "
local DB_VERSION = 3

local db            -- saved: db.entries[key] = { first, last, reason, added }
local warned = {}   -- keys already warned about while still in the group

local function Print(msg)
    print(PREFIX .. msg)
end

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "ada" -> "Ada". Display only; comparisons are case-insensitive.
local function Capitalize(s)
    return (s:gsub("^%l", string.upper))
end

local function MakeKey(first, last)
    return (first .. " " .. last):lower()
end

local function FullName(e)
    return e.first .. " " .. e.last
end

-- Parse "First Last reason words". Returns first, last, reason, or nil if the
-- first or last name is missing.
local function ParseTarget(input)
    local first, last, tail = Trim(input):match("^(%S+)%s+(%S+)%s*(.*)$")
    if not first then return nil end
    return Capitalize(first), Capitalize(last), tail ~= "" and tail or nil
end

local function EntryLine(e)
    return string.format("%s (added %s)%s", FullName(e), e.added or "?",
        e.reason and (": " .. e.reason) or "")
end

local function Add(input)
    local first, last, reason = ParseTarget(input)
    if not first then return false end
    local key = MakeKey(first, last)
    local entry = { first = first, last = last, reason = reason, added = date("%Y-%m-%d") }
    if db.entries[key] then
        Print(FullName(entry) .. " is already on the blacklist.")
    else
        db.entries[key] = entry
        Print("Added " .. FullName(entry) .. ".")
    end
    return true
end

local function Remove(input)
    local first, last = ParseTarget(input)
    if not first then return false end
    local key = MakeKey(first, last)
    local entry = db.entries[key]
    if entry then
        db.entries[key] = nil
        Print("Removed " .. FullName(entry) .. ".")
    else
        Print(first .. " " .. last .. " is not on the blacklist.")
    end
    return true
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
        return MakeKey(a.first, a.last) < MakeKey(b.first, b.last)
    end)
    Print(#entries .. " blacklisted player(s):")
    for _, e in ipairs(entries) do
        print("  " .. EntryLine(e))
    end
end

-- Returns first, last for a unit. On Forever UnitName returns first name and
-- surname. Tolerates a single combined "First Last" string; returns nil if the
-- name cannot be split into two parts (such a unit never matches an entry).
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
            local key = first and MakeKey(first, last)
            local entry = key and db.entries[key]
            if entry then
                present[key] = true
                if not warned[key] then
                    warned[key] = true
                    Print("WARNING: blacklisted player " .. FullName(entry) ..
                        " joined your group. Entry: " .. EntryLine(entry))
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
    print("  /blacklist add <First> <Last> [reason]")
    print("  /blacklist remove <First> <Last>")
    print("  /blacklist list")
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
        -- Older saved data (single name + realm, or with rulesets) is dropped;
        -- there are no users yet.
        if WoWForeverBlacklistDB.version ~= DB_VERSION then
            WoWForeverBlacklistDB = { version = DB_VERSION, entries = {} }
        end
        db = WoWForeverBlacklistDB
    elseif event == "GROUP_ROSTER_UPDATE" and db then
        CheckGroup()
    end
end)
