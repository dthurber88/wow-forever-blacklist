-- WoW Forever Blacklist
-- Slash command: /blacklist (alias /bl). See README.md for usage.

local ADDON = "WoWForeverBlacklist"
local PREFIX = "|cffff4040[Blacklist]|r "

local db            -- saved list: db[key] = { name, realm, reason, added }
local warned = {}   -- keys already warned about while still in the group

local function Print(msg)
    print(PREFIX .. msg)
end

-- Realm names are compared without spaces/hyphens, case-insensitively.
local function NormalizeRealm(realm)
    if not realm or realm == "" then
        realm = GetNormalizedRealmName() or GetRealmName() or ""
    end
    return (realm:gsub("[%s%-']", ""))
end

local function MakeKey(name, realm)
    return (name .. "-" .. NormalizeRealm(realm)):lower()
end

-- Accepts "Name" or "Name-Realm". Returns name, realm (realm may be nil).
local function SplitName(input)
    local name, realm = input:match("^([^%-]+)%-(.+)$")
    return name or input, realm
end

local function Capitalize(s)
    return (s:gsub("^%l", string.upper))
end

local function Add(input, reason)
    local name, realm = SplitName(input)
    name = Capitalize(name)
    realm = NormalizeRealm(realm)
    local key = MakeKey(name, realm)
    if db[key] then
        Print(name .. "-" .. realm .. " is already on the blacklist.")
        return
    end
    db[key] = {
        name = name,
        realm = realm,
        reason = (reason and reason ~= "") and reason or nil,
        added = date("%Y-%m-%d"),
    }
    Print("Added " .. name .. "-" .. realm .. ".")
end

local function Remove(input)
    local name, realm = SplitName(input)
    local key = MakeKey(name, realm)
    local entry = db[key]
    if not entry then
        Print(input .. " is not on the blacklist.")
        return
    end
    db[key] = nil
    Print("Removed " .. entry.name .. "-" .. entry.realm .. ".")
end

local function List()
    local entries = {}
    for _, entry in pairs(db) do
        entries[#entries + 1] = entry
    end
    if #entries == 0 then
        Print("The blacklist is empty.")
        return
    end
    table.sort(entries, function(a, b)
        return (a.name .. a.realm):lower() < (b.name .. b.realm):lower()
    end)
    Print(#entries .. " blacklisted player(s):")
    for _, e in ipairs(entries) do
        print(string.format("  %s-%s (added %s)%s", e.name, e.realm, e.added or "?",
            e.reason and (": " .. e.reason) or ""))
    end
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
            local name, realm = UnitFullName(unit)
            if name then
                local key = MakeKey(name, realm)
                local entry = db[key]
                if entry then present[key] = true end
                if entry and not warned[key] then
                    warned[key] = true
                    Print(string.format("WARNING: blacklisted player %s-%s joined your group (added %s)%s",
                        entry.name, entry.realm, entry.added or "?",
                        entry.reason and (": " .. entry.reason) or ""))
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
    print("  /blacklist add <Name[-Realm]> [reason]")
    print("  /blacklist remove <Name[-Realm]>")
    print("  /blacklist list")
end

SLASH_WOWFOREVERBLACKLIST1 = "/blacklist"
SLASH_WOWFOREVERBLACKLIST2 = "/bl"
SlashCmdList["WOWFOREVERBLACKLIST"] = function(msg)
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "add" then
        local target, reason = rest:match("^(%S+)%s*(.*)$")
        if target then Add(target, reason) else PrintHelp() end
    elseif cmd == "remove" or cmd == "del" then
        if rest ~= "" then Remove(rest) else PrintHelp() end
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
        db = WoWForeverBlacklistDB
    elseif event == "GROUP_ROSTER_UPDATE" and db then
        CheckGroup()
    end
end)
