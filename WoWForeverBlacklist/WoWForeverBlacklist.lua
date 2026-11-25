-- WoW Forever Blacklist
-- Slash command: /blacklist (alias /bl). See README.md for usage and for what is
-- and is not known about the Forever API each feature relies on.
--
-- Player model (WoW: Forever): a player is a first name + last name. There are
-- no realms, and no way to read another player's ruleset.

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

-- Finds the entry for a player by first+last name. Returns entry, key.
local function FindEntry(first, last)
    local key = MakeKey(first, last)
    if db.entries[key] then return db.entries[key], key end
    return nil
end

-- Adds a player. Returns true if added, false if already listed.
local function AddEntry(first, last, reason)
    local key = MakeKey(first, last)
    local entry = { first = first, last = last, reason = reason,
        added = date("%Y-%m-%d") }
    if FindEntry(first, last) then
        Print(FullName(entry) .. " is already on the blacklist.")
        return false
    end
    db.entries[key] = entry
    Print("Added " .. FullName(entry) .. ".")
    return true
end

local RefreshWindow -- defined with the window code below

local function Add(input)
    local first, last, reason = ParseTarget(input)
    if not first then return false end
    AddEntry(first, last, reason)
    RefreshWindow()
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
        RefreshWindow()
    else
        Print(first .. " " .. last .. " is not on the blacklist.")
    end
    return true
end

-- All entries as an array, sorted by name.
local function SortedEntries()
    local entries = {}
    for _, entry in pairs(db.entries) do
        entries[#entries + 1] = entry
    end
    table.sort(entries, function(a, b)
        return MakeKey(a.first, a.last) < MakeKey(b.first, b.last)
    end)
    return entries
end

local function List()
    local entries = SortedEntries()
    if #entries == 0 then
        Print("The blacklist is empty.")
        return
    end
    Print(#entries .. " blacklisted player(s):")
    for _, e in ipairs(entries) do
        print("  " .. EntryLine(e))
    end
end

-- Splits a name into first, last. Accepts two values (UnitName on Forever:
-- first name, surname) or one combined "First Last" / "First-Last" string.
-- Returns nil if it cannot be split into exactly two parts (such a name never
-- matches an entry).
local function SplitName(first, last)
    if type(first) ~= "string" or first == "" then return nil end
    if type(last) == "string" and last ~= "" then return first, last end
    local a, b = first:match("^(%S+)[%s%-]+(%S+)$")
    return a, b
end

local function UnitFirstLast(unit)
    return SplitName(UnitName(unit))
end

-- Group warnings -------------------------------------------------------------

local JOIN_WINDOW = 10      -- seconds after joining in which a scan counts as "the group I joined"
local inGroup = false
local joinedAt = 0

local function CheckGroup()
    if not IsInGroup() then
        wipe(warned)
        inGroup = false
        return
    end
    if not inGroup then
        inGroup = true
        joinedAt = GetTime()
    end
    local prefix = IsInRaid() and "raid" or "party"
    local present, new = {}, {}
    for i = 1, GetNumGroupMembers() do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local first, last = UnitFirstLast(unit)
            local entry, key = FindEntry(first, last)
            if entry and not present[key] then
                present[key] = true
                if not warned[key] then
                    warned[key] = true
                    new[#new + 1] = entry
                end
            end
        end
    end
    -- Forget players who left, so they are warned about again if they rejoin.
    for key in pairs(warned) do
        if not present[key] then warned[key] = nil end
    end
    if #new == 0 then return end
    -- One message naming every listed member found in this scan.
    if GetTime() - joinedAt < JOIN_WINDOW then
        Print("WARNING: you joined a group with " .. #new .. " blacklisted player(s):")
    else
        Print("WARNING: " .. #new .. " blacklisted player(s) joined your group:")
    end
    for _, e in ipairs(new) do
        print("  " .. EntryLine(e))
    end
end

-- Group applicants -----------------------------------------------------------
-- C_LFGList.GetApplicants / GetApplicantInfo / GetApplicantMemberInfo exist in
-- the Forever client but their signatures are undocumented there, so every call
-- is wrapped in pcall and the retail shapes are checked rather than assumed.

local warnedApplicants = {} -- "<applicantID>|<key>" already warned about

local function ApplicantMemberCount(id)
    local ok, a, _, _, d = pcall(C_LFGList.GetApplicantInfo, id)
    if ok then
        if type(a) == "table" and type(a.numMembers) == "number" then return a.numMembers end
        if type(d) == "number" then return d end -- older multi-return form
    end
    return 1
end

local function CheckApplicants()
    if not (C_LFGList and C_LFGList.GetApplicants and C_LFGList.GetApplicantMemberInfo) then
        return
    end
    local ok, ids = pcall(C_LFGList.GetApplicants)
    if not ok or type(ids) ~= "table" then return end
    local seen = {}
    for _, id in ipairs(ids) do
        for i = 1, ApplicantMemberCount(id) do
            local okm, name = pcall(C_LFGList.GetApplicantMemberInfo, id, i)
            local first, last = SplitName(okm and name or nil)
            local entry, key = nil, nil
            if first then entry, key = FindEntry(first, last) end
            if entry then
                local wkey = id .. "|" .. key
                seen[wkey] = true
                if not warnedApplicants[wkey] then
                    warnedApplicants[wkey] = true
                    Print("WARNING: blacklisted player " .. FullName(entry) ..
                        " has applied to your group. Entry: " .. EntryLine(entry))
                end
            end
        end
    end
    -- Forget applicants no longer listed (applicant IDs are not reused).
    for wkey in pairs(warnedApplicants) do
        if not seen[wkey] then warnedApplicants[wkey] = nil end
    end
end

-- Right-click menu -----------------------------------------------------------
-- Uses Menu.ModifyMenu (present on Forever per ForeverPlusPlus's in-game /dump).
-- Which MENU_UNIT_* tags Forever fires is NOT established, so a retail-style
-- list is registered; tags that never fire are harmless.

local MENU_TAGS = {
    "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID",
    "MENU_UNIT_FRIEND", "MENU_UNIT_FRIEND_OFFLINE", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS",
    "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_OTHERPLAYER", "MENU_UNIT_GUILD",
    "MENU_UNIT_GUILD_OFFLINE", "MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
    "MENU_UNIT_COMMUNITIES_MEMBER",
}

-- First, last of the player a menu was opened on, or nil if
-- unknown/self/not a player. Prefers the unit token; falls back to a name that
-- splits by itself.
local function MenuPlayer(ctx)
    if type(ctx) ~= "table" then return nil end
    local first, last
    if ctx.unit and UnitExists(ctx.unit) then
        if UnitIsUnit(ctx.unit, "player") or not UnitIsPlayer(ctx.unit) then return nil end
        first, last = UnitFirstLast(ctx.unit)
    elseif type(ctx.name) == "string" then
        first, last = SplitName(ctx.name)
        local mf, ml = UnitFirstLast("player")
        if first and mf and MakeKey(first, last) == MakeKey(mf, ml) then return nil end
    end
    if not first then return nil end
    return Capitalize(first), Capitalize(last)
end

local function OnUnitMenu(_, root, ctx)
    if not db or type(root) ~= "table" or not root.CreateButton then return end
    local first, last = MenuPlayer(ctx)
    if not first or FindEntry(first, last) then return end
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton("Add to blacklist", function()
        AddEntry(first, last, nil)
        RefreshWindow()
    end)
end

local function SetupMenu()
    if not (Menu and Menu.ModifyMenu) then
        Print("Right-click menu is unavailable in this client; use /blacklist add instead.")
        return
    end
    for _, tag in ipairs(MENU_TAGS) do
        pcall(Menu.ModifyMenu, tag, function(...)
            -- A menu callback must never break the game's own menu.
            pcall(OnUnitMenu, ...)
        end)
    end
end

-- Window ---------------------------------------------------------------------
-- Plain frame built from textures and font strings only (no Blizzard frame
-- templates besides an optional button skin), since Forever's template set
-- is not documented.

local ROWS, ROW_H = 10, 24
local window, offset = nil, 0
local rows = {}

local function MakeButton(parent, label, w, h, onClick)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then
        b = CreateFrame("Button", nil, parent)
        local t = b:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(0.25, 0.25, 0.25, 0.9)
        b:SetFontString(b:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        b:GetFontString():SetPoint("CENTER")
    end
    b:SetSize(w, h)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function CommitReason(box)
    if not box.edited then return end
    box.edited = false
    local e = box.entry
    if not e then return end
    local text = Trim(box:GetText())
    e.reason = text ~= "" and text or nil
end

local function MakeRow(parent, i)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(616, ROW_H)
    row:SetPoint("TOPLEFT", 12, -48 - (i - 1) * ROW_H)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 0, 0)
    row.name:SetWidth(130)
    row.name:SetJustifyH("LEFT")

    row.date = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.date:SetPoint("LEFT", 134, 0)
    row.date:SetWidth(72)
    row.date:SetJustifyH("LEFT")

    local box = CreateFrame("EditBox", nil, row)
    box:SetPoint("LEFT", 210, 0)
    box:SetSize(210, ROW_H - 4)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetTextInsets(4, 4, 0, 0)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.08)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self.edited = true end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self)
        self.edited = false
        self:SetText(self.entry and self.entry.reason or "")
        self:SetCursorPosition(0)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", CommitReason)
    row.reason = box

    row.remove = MakeButton(row, "Remove", 64, ROW_H - 2, function(self)
        local e = row.entry
        if not e then return end
        if not self.confirm then
            self.confirm = true
            self:SetText("Sure?")
            return
        end
        db.entries[MakeKey(e.first, e.last)] = nil
        Print("Removed " .. FullName(e) .. ".")
        RefreshWindow()
    end)
    row.remove:SetPoint("LEFT", 426, 0)
    return row
end

RefreshWindow = function()
    if not window or not window:IsShown() then return end
    for _, row in ipairs(rows) do
        if row.reason:HasFocus() then row.reason:ClearFocus() end -- saves a pending edit
    end
    local entries = SortedEntries()
    local n = #entries
    offset = math.max(0, math.min(offset, n - ROWS))
    for i, row in ipairs(rows) do
        local e = entries[offset + i]
        row.entry, row.reason.entry = e, e
        row.remove.confirm = false
        row.remove:SetText("Remove")
        if e then
            row.name:SetText(FullName(e))
            row.date:SetText(e.added or "?")
            row.reason.edited = false
            row.reason:SetText(e.reason or "")
            row.reason:SetCursorPosition(0)
            row:Show()
        else
            row:Hide()
        end
    end
    window.empty:SetShown(n == 0)
    if n == 0 then
        window.count:SetText("")
    else
        window.count:SetText(string.format("%d-%d of %d", offset + 1, math.min(offset + ROWS, n), n))
    end
end

local function Scroll(delta)
    offset = math.max(0, offset + delta)
    RefreshWindow()
end

local function CreateWindow()
    local f = CreateFrame("Frame", "WoWForeverBlacklistFrame", UIParent)
    f:SetSize(640, 340)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetScript("OnMouseWheel", function(_, delta) Scroll(-delta) end)
    f:SetScript("OnShow", RefreshWindow)
    f:SetScript("OnHide", function() -- save a pending edit when closed
        for _, row in ipairs(rows) do
            if row.reason:HasFocus() then row.reason:ClearFocus() end
        end
    end)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.88)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("Blacklist")

    for _, h in ipairs({ { "Name", 12 }, { "Added", 146 }, { "Reason", 222 } }) do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", h[2], -34)
        fs:SetText(h[1])
    end

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.empty:SetPoint("TOP", 0, -100)
    f.empty:SetText("The blacklist is empty.")

    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.count:SetPoint("BOTTOM", 0, 18)

    MakeButton(f, "<", 28, 22, function() Scroll(-ROWS) end):SetPoint("BOTTOMLEFT", 12, 12)
    MakeButton(f, ">", 28, 22, function() Scroll(ROWS) end):SetPoint("BOTTOMLEFT", 44, 12)
    MakeButton(f, "Close", 70, 22, function() f:Hide() end):SetPoint("BOTTOMRIGHT", -12, 12)

    window = f
    for i = 1, ROWS do rows[i] = MakeRow(f, i) end
    if UISpecialFrames then table.insert(UISpecialFrames, "WoWForeverBlacklistFrame") end
end

local function ToggleWindow()
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end

local function PrintHelp()
    Print("Usage:")
    print("  /blacklist add <First> <Last> [reason]")
    print("  /blacklist remove <First> <Last>")
    print("  /blacklist list")
    print("  /blacklist window")
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
    elseif cmd == "window" then
        ToggleWindow()
    else
        PrintHelp()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
-- Registering an event the client does not know throws, so guard these two.
pcall(frame.RegisterEvent, frame, "LFG_LIST_APPLICANT_LIST_UPDATED")
pcall(frame.RegisterEvent, frame, "LFG_LIST_APPLICANT_UPDATED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        WoWForeverBlacklistDB = WoWForeverBlacklistDB or {}
        -- Older saved data (single name + realm, or with rulesets) is dropped;
        -- there are no users yet.
        if WoWForeverBlacklistDB.version ~= DB_VERSION then
            WoWForeverBlacklistDB = { version = DB_VERSION, entries = {} }
        end
        db = WoWForeverBlacklistDB
        SetupMenu()
    elseif event == "GROUP_ROSTER_UPDATE" and db then
        CheckGroup()
    elseif db and (event == "LFG_LIST_APPLICANT_LIST_UPDATED" or event == "LFG_LIST_APPLICANT_UPDATED") then
        CheckApplicants()
    end
end)
