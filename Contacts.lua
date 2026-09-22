local _, ns = ...
local M = ns.M
function M:ValidName(raw)
    local name = self:Trim(raw)
    if name == "" then return nil, "Type a recipient name in the To field first, then choose Add contact." end
    if #name > 100 or name:find("[%c%d|:;<>%[%]%%]") then return nil, "That recipient name contains unsupported characters." end
    if self.forever and not name:match("^%S+%s+%S+") then return nil, "Forever recipients need both first and last names." end
    if not self.forever and name:find(" ", 1, true) then return nil, "Use Character or Character-Realm on this client." end
    return name
end
function M:ContactKey(name) return self:Client() .. "\031" .. string.lower(name) end
function M:RecordPlayer()
    if not self.db or not UnitName then return end
    local name = UnitName("player")
    name = self:ValidName(name)
    if not name then return end
    local realm = self:Realm()
    local _, class = UnitClass("player")
    local record = {name = name, realm = realm, ruleset = self:Ruleset(realm), client = self:Client(),
        faction = UnitFactionGroup("player"), class = class, level = UnitLevel("player"), guid = UnitGUID("player")}
    local key = self:Client() .. "\031" .. tostring(record.guid or (name .. "-" .. realm))
    self.db.alts[key], self.player = record, record
end
function M:AltRecipient(r)
    if self.forever or not r.realm or r.realm == self:Realm() or r.name:find("-", 1, true) then return r.name end
    return r.name .. "-" .. r.realm:gsub("%s", "")
end
function M:Compatible(r)
    if r.client and r.client ~= "" and r.client ~= self:Client() then return false, "Different WoW client" end
    if self.forever and r.ruleset and r.ruleset ~= "" and r.ruleset ~= self:Ruleset() then
        return false, "Mail unavailable: " .. r.ruleset .. " ruleset"
    end
    if not self.forever and WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
        if r.realm and r.realm ~= "" and r.realm ~= self:Realm() then return false, "Different realm" end
        if self.player and r.faction and r.faction ~= self.player.faction then return false, "Different faction" end
    end
    return true
end
function M:CanRecipient(raw)
    local name, why = self:ValidName(raw)
    if not name then return false, why end
    local contact = self.db.contacts[self:ContactKey(name)]
    if contact then local ok, reason = self:Compatible(contact); if not ok then return false, reason end end
    local found, permitted, reason = false, false, nil
    for _, r in pairs(self.db.alts) do
        if string.lower(self:AltRecipient(r)) == string.lower(name) and r.client == self:Client() then
            found = true
            local ok, whyAlt = self:Compatible(r)
            permitted, reason = permitted or ok, whyAlt
        end
    end
    if found and not permitted then return false, reason end
    return true
end
function M:AddContact(raw)
    local name, why = self:ValidName(raw)
    if not name then self:Print(why); return false end
    local record = {name = name, client = self:Client()}
    -- Unknown manually entered contacts stay unknown; never guess their ruleset.
    local matches = 0
    for _, alt in pairs(self.db.alts) do
        if alt.client == self:Client() and string.lower(self:AltRecipient(alt)) == string.lower(name) then
            matches = matches + 1; record.ruleset, record.realm = alt.ruleset, alt.realm
        end
    end
    if matches > 1 then record.ruleset, record.realm = nil, nil end
    self.db.contacts[self:ContactKey(name)] = record
    self:Print("Saved contact: " .. name)
    return true
end
function M:RemoveContact(raw)
    local name = self:Trim(raw)
    local key = self:ContactKey(name)
    if not self.db.contacts[key] then self:Print("Put a saved contact's name in To first."); return end
    self.db.contacts[key] = nil
    self:Print("Removed contact: " .. name)
end
function M:RememberRecipient(raw)
    local name = self:ValidName(raw)
    if not name then return end
    local key = self:ContactKey(name)
    local recent = self.db.recent
    for i = #recent, 1, -1 do if recent[i].key == key then table.remove(recent, i) end end
    table.insert(recent, 1, {name = name, key = key, client = self:Client()})
    while #recent > 20 do table.remove(recent) end
end
local function escape(s)
    return (tostring(s or ""):gsub("%%", "%%25"):gsub("\t", "%%09"):gsub("\r", "%%0D"):gsub("\n", "%%0A"))
end
local function unescape(s) return (s:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)) end
function M:ExportContacts()
    local rows = {"MAILWRIGHT-CONTACTS\t1"}
    local sorted = {}
    for _, r in pairs(self.db.contacts) do sorted[#sorted + 1] = r end
    table.sort(sorted, function(a,b) return (a.client or "") .. a.name < (b.client or "") .. b.name end)
    for _, r in ipairs(sorted) do
        rows[#rows + 1] = table.concat({escape(r.name), escape(r.client), escape(r.ruleset), escape(r.realm)}, "\t")
    end
    return table.concat(rows, "\n")
end
function M:ParseContacts(text)
    if #text > 200000 then return nil, "Import is too large (maximum 200 KB)." end
    local records, errors, formatted, first = {}, 0, false, true
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        if line ~= "" then
            if first and line == "MAILWRIGHT-CONTACTS\t1" then formatted = true
            elseif first and line:find("^MAILWRIGHT%-CONTACTS") then return nil, "Unsupported backup version."
            else
                local name, client, ruleset, realm
                if formatted then
                    local a,b,c,d = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
                    if a then name,client,ruleset,realm = unescape(a),unescape(b),unescape(c),unescape(d) end
                else name,client = self:Trim(line),self:Client() end
                -- Validate according to the backup's client, preserving backups across installations.
                local wasForever = self.forever
                self.forever = client == "Forever"
                local valid = name and self:ValidName(name)
                self.forever = wasForever
                if valid and client and #client <= 40 and #(realm or "") <= 100 and #(ruleset or "") <= 100
                    and not (client .. (realm or "") .. (ruleset or "")):find("[%c|]") then
                    records[#records + 1] = {name = valid, client = client, ruleset = ruleset ~= "" and ruleset or nil,
                        realm = realm ~= "" and realm or nil}
                else errors = errors + 1 end
            end
            first = false
        end
    end
    return records, errors
end
function M:ImportContacts(text)
    local records, invalid = self:ParseContacts(text)
    if not records then return false, invalid end
    local added, duplicates = 0, 0
    for _, r in ipairs(records) do
        local key = r.client .. "\031" .. string.lower(r.name)
        if self.db.contacts[key] then duplicates = duplicates + 1
        else self.db.contacts[key] = r; added = added + 1 end
    end
    return true, string.format("Imported %d; kept %d existing; skipped %d invalid lines.", added, duplicates, invalid)
end
function M:Recipients(group)
    local list, seen = {}, {}
    local function add(r, alt)
        if r.client and r.client ~= M:Client() then return end
        local name = alt and M:AltRecipient(r) or r.name
        if not name then return end
        local ok, why = M:Compatible(r)
        local key = name .. "\031" .. (r.ruleset or "")
        if not seen[key] then
            seen[key] = true
            list[#list + 1] = {name = name, ruleset = r.ruleset, ok = ok, why = why,
                class = r.class, className = r.className, level = r.level, rank = r.rank,
                realm = r.realm, faction = r.faction}
        end
    end
    if group == "Contacts" then for _, r in pairs(self.db.contacts) do add(r) end
    elseif group == "Recent" then for _, r in ipairs(self.db.recent) do add(r) end
    elseif group == "Alts" or group == "All alts" then
        for _, r in pairs(self.db.alts) do
            if not self.player or r.guid ~= self.player.guid then
                if group == "All alts" or self:Compatible(r) then add(r, true) end
            end
        end
    elseif group == "Friends" then
        local count = C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or GetNumFriends and GetNumFriends() or 0
        for i = 1, count do
            local name
            if C_FriendList and C_FriendList.GetFriendInfoByIndex then local r = C_FriendList.GetFriendInfoByIndex(i); name = r and r.name
            elseif GetFriendInfo then name = GetFriendInfo(i) end
            if name then add({name = name}) end
        end
        -- Battle.net friends are separate from the character-only friend list.
        -- Only exposed WoW character identities can be used as mail addresses.
        if C_BattleNet and C_BattleNet.GetFriendGameAccountInfo and BNGetNumFriends then
            for friend = 1, BNGetNumFriends() or 0 do
                local count = C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendNumGameAccounts(friend) or 0
                for account = 1, count do
                    local r = C_BattleNet.GetFriendGameAccountInfo(friend, account)
                    if r and r.clientProgram == (BNET_CLIENT_WOW or "WoW") and r.isOnline
                        and r.isInCurrentRegion ~= false and r.wowProjectID == WOW_PROJECT_ID
                        and r.characterName and r.characterName ~= "" and r.realmName and r.realmName ~= "" then
                        local name = self:ValidName(r.characterName)
                        if name then
                            local record = {name = name, realm = r.realmName, faction = r.factionName, class = r.classFilename, className = r.className, level = r.characterLevel}
                            if self.forever then record.ruleset = self:Ruleset(r.realmName) end
                            -- Forever uses the mainline project ID too; full-name validation
                            -- and the ruleset record prevent mixing its recipients with Retail.
                            add(record, true)
                        end
                    end
                end
            end
        end
    elseif group == "Guild" then
        for i = 1, GetNumGuildMembers and GetNumGuildMembers() or 0 do
            local name, rank, rankIndex, level, className, zone, note, officerNote, online, status, class = GetGuildRosterInfo(i)
            if name then add({name = name, rank = rank, level = level, class = class, className = className}) end
        end
    end
    table.sort(list, function(a,b)
        if group == "All alts" and (a.ruleset or "") ~= (b.ruleset or "") then return (a.ruleset or "") < (b.ruleset or "") end
        return string.lower(a.name) < string.lower(b.name)
    end)
    return list
end

function M:RequestFriends()
    if self.lastFriendRequest and GetTime() - self.lastFriendRequest < 10 then return end
    self.lastFriendRequest = GetTime()
    local request = C_FriendList and C_FriendList.ShowFriends or ShowFriends
    if request then pcall(request) end
end
local function friendsChanged(self)
    if not self.db or not self.mailOpen or not self.menu or not self.menu:IsShown() then return end
    if self.menuGroup == nil or self.menuGroup == "Friends" then self:ShowContactMenu(self.menuGroup) end
end
M:Listen("FRIENDLIST_UPDATE", friendsChanged)
M:Listen("BN_FRIEND_INFO_CHANGED", friendsChanged)
M:Listen("BN_FRIEND_ACCOUNT_ONLINE", friendsChanged)
M:Listen("BN_FRIEND_ACCOUNT_OFFLINE", friendsChanged)

function M:RecipientLabel(r, group)
    local text = r.name
    if group == "All alts" then
        if r.realm and not self.forever and not text:find("-", 1, true) then text = text .. "-" .. r.realm end
        if r.faction then text = text .. "-" .. r.faction end
    end
    if r.rank and r.rank ~= "" then text = text .. " |cffffd100(" .. r.rank .. ")|r" end
    local className = r.className or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[r.class or ""]) or r.class
    local details = {}
    if r.level and r.level > 0 then details[#details + 1] = tostring(r.level) end
    if className and className ~= "" then details[#details + 1] = className end
    if #details > 0 then
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[r.class or ""]
        local hex = color and string.format("%02x%02x%02x", math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5)) or "aaaaaa"
        text = text .. " |cff" .. hex .. "(" .. table.concat(details, " ") .. ")|r"
    end
    if not r.ok then text = text .. " [unavailable]" end
    return text
end
