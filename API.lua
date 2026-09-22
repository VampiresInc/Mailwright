local _, ns = ...
local M = ns.M
function M:Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")) end
function M:Money(n)
    n = math.floor(tonumber(n) or 0)
    return string.format("%dg %ds %dc", math.floor(n / 10000), math.floor(n / 100) % 100, n % 100)
end
function M:Realm() return GetRealmName and GetRealmName() or "Unknown realm" end
function M:Ruleset(realm)
    if not self.forever then return "Standard" end
    local r = string.lower(realm or self:Realm())
    if r:find("hardcore", 1, true) then return "Hardcore" end
    if r:find("rp", 1, true) then return realm or self:Realm() end
    if r:find("pvp", 1, true) then return "PvP" end
    if r:find("pve", 1, true) or r:find("normal", 1, true) then return "Normal" end
    return realm or self:Realm()
end
function M:Client()
    if self.forever then return "Forever" end
    return "WoW-" .. tostring(WOW_PROJECT_ID or "unknown")
end
function M:Header(index)
    if not GetInboxHeaderInfo then return end
    local icon, paper, sender, subject, money, cod, days, count, read, returned, text, reply, gm = GetInboxHeaderInfo(index)
    if not sender and not subject then return end
    local h = {index = index, sender = sender or "", subject = subject or "", money = money or 0,
        cod = cod or 0, days = days or 0, count = count or 0, read = read, returned = returned,
        text = text, reply = reply, gm = gm, items = {}}
    local parts = {h.sender, h.subject, tostring(h.money), tostring(h.cod), tostring(h.count)}
    for slot = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
        local name, id, texture, quantity = GetInboxItem(index, slot)
        if name or id then
            local link = GetInboxItemLink and GetInboxItemLink(index, slot)
            table.insert(h.items, {slot = slot, name = name or "Item", id = id, link = link, count = quantity or 1})
            table.insert(parts, tostring(slot) .. ":" .. tostring(link or id or name) .. ":" .. tostring(quantity))
        end
    end
    h.signature = table.concat(parts, "\031")
    return h
end
function M:Inbox()
    local list = {}
    local visible, total = GetInboxNumItems()
    for i = 1, visible or 0 do local h = self:Header(i); if h then list[#list + 1] = h end end
    return list, total or visible or 0
end
function M:Pending() return C_Mail and C_Mail.IsCommandPending and C_Mail.IsCommandPending() or false end
function M:BagSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
    return GetContainerNumSlots(bag)
end
function M:BagItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local i = C_Container.GetContainerItemInfo(bag, slot)
        if i then return {bag = bag, slot = slot, link = i.hyperlink, id = i.itemID, count = i.stackCount,
            locked = i.isLocked, bound = i.isBound, quality = i.quality} end
    elseif GetContainerItemInfo then
        local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
        if texture then return {bag = bag, slot = slot, link = link, count = count, locked = locked, quality = quality} end
    end
end
function M:BagItems()
    local items = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, self:BagSlots(bag) do local i = self:BagItem(bag, slot); if i then items[#items + 1] = i end end
    end
    return items
end
function M:FreeSlots()
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local n, family
        if C_Container and C_Container.GetContainerNumFreeSlots then n, family = C_Container.GetContainerNumFreeSlots(bag)
        elseif GetContainerNumFreeSlots then n, family = GetContainerNumFreeSlots(bag) end
        if not family or family == 0 then free = free + (n or 0) end
    end
    return free
end
function M:UseBagItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then C_Container.UseContainerItem(bag, slot)
    else UseContainerItem(bag, slot) end
end
function M:ItemDetails(link)
    if not link then return end
    local getter = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getter then return end
    local name, _, quality, level, req, kind, subkind, stack, equip, texture, price, class, subclass, bind = getter(link)
    if name then return {name = name, quality = quality, stack = stack, class = class, subclass = subclass, bind = bind} end
end
function M:SendCount()
    local count = 0
    for slot = 1, ATTACHMENTS_MAX_SEND or 12 do if GetSendMailItem(slot) then count = count + 1 end end
    return count
end
function M:Recipient() return SendMailNameEditBox and self:Trim(SendMailNameEditBox:GetText()) or "" end
function M:SetRecipient(name)
    local ok, why = self:CanRecipient(name)
    if not ok then self:Print(why); return false end
    if MailFrameTab_OnClick then MailFrameTab_OnClick(nil, 2) end
    if SendMailNameEditBox then SendMailNameEditBox:SetText(name); SendMailNameEditBox:ClearFocus() end
    return true
end
