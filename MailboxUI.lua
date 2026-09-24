local _, ns = ...
local M = ns.M

local function button(parent, text, width, action)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 20); b:SetText(text); b:SetScript("OnClick", action)
    return b
end
local function arrow(parent, action)
    local b = button(parent, "", 20, action)
    b:SetNormalTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Up")
    b:SetPushedTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Down")
    b:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight")
    b:SetFrameLevel(parent:GetFrameLevel() + 10)
    return b
end
local function tip(frame, text)
    frame:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(text, 1, 1, 1, true); GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function M:BuildUI()
    if not MailFrame or not InboxFrame then return end
    -- An invisible owner for controls, not a second mailbox window.
    local owner = CreateFrame("Frame", nil, MailFrame)
    owner:SetSize(1, 1); owner:SetPoint("TOPLEFT")
    self.ui = owner
    self.inboxChecks = {}
    self.toolbar = CreateFrame("Frame", nil, InboxFrame)
    self.toolbar:SetSize(300, 22); self.toolbar:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 50, -31)
    local all = CreateFrame("CheckButton", nil, self.toolbar, "UICheckButtonTemplate")
    all:SetSize(20, 20); all:SetPoint("LEFT", -27, 0)
    all:SetScript("OnClick", function(b)
        if M.queue then return end
        M.selection = {}
        if b:GetChecked() then for _, h in ipairs(M:Inbox()) do M.selection[h.index] = h.signature end end
        M:RefreshUI()
    end)
    tip(all, "Select all mail. Shift-checkbox selects a range; Ctrl-checkbox selects the same sender.")
    self.selectAll = all
    self.openAll = button(InboxFrame, "Open All", 120, function()
        if M.queue then M:StopQueue() else M:StartQueue("all") end
    end)
    if InboxPrevPageButton then self.openAll:SetPoint("LEFT", InboxPrevPageButton, "RIGHT", 28, 0)
    else self.openAll:SetPoint("BOTTOMLEFT", InboxFrame, "BOTTOMLEFT", 80, 8) end
    self.collectButton = button(self.toolbar, "Open", 120, function()
        if M.queue then M:StopQueue() else M:StartQueue("selected", M.selection) end
    end)
    self.collectButton:SetPoint("LEFT", 0, 0); tip(self.collectButton, "Collect selected messages; click again to stop.")
    self.returnButton = button(self.toolbar, "Return", 120, function() M:StartQueue("return", M.selection) end)
    self.returnButton:SetPoint("LEFT", 128, 0); tip(self.returnButton, "Return selected messages to their senders.")
    self.settingsButton = arrow(MailFrame, function() M:ShowOptionsMenu() end)
    local close = MailFrameCloseButton or MailFrame.CloseButton
    if close then self.settingsButton:SetPoint("RIGHT", close, "LEFT", 0, 0)
    else self.settingsButton:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 300, -5) end
    self.openAllOptions = arrow(InboxFrame, function() M:ShowOptionsMenu() end)
    self.openAllOptions:SetPoint("LEFT", self.openAll, "RIGHT", 2, 0)
    tip(self.settingsButton, "Mailwright options")
    if SendMailNameEditBox then
        self.recipientButton = arrow(SendMailFrame or MailFrame, function()
            if M.menu and M.menu:IsShown() and not M.menuGroup then M.menu:Hide() else M:ShowContactMenu() end
        end)
        self.recipientButton:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 0, 0)
        tip(self.recipientButton, "Contacts")
    end
    if SendMailFrame then
        self.attachButtons = {}
        local icons = {"INV_Misc_Bag_08", "INV_Fabric_Linen_01", "INV_Potion_54", "INV_Sword_04", "INV_Misc_Gem_Emerald_02", "INV_Scroll_03", "INV_Misc_Book_09"}
        for i, category in ipairs(self.categories) do
            local name = category
            local b = CreateFrame("Button", nil, SendMailFrame, "UIPanelButtonTemplate")
            b:SetSize(28, 28); b:SetFrameLevel(SendMailFrame:GetFrameLevel() + 10)
            b:SetNormalTexture("Interface/Icons/" .. icons[i])
            if i == 1 then
                if close then b:SetPoint("TOPLEFT", close, "TOPRIGHT", 5, 0)
                else b:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 350, 2) end
            else b:SetPoint("TOP", self.attachButtons[i - 1], "BOTTOM", 0, -3) end
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnClick", function(_, mouse)
                M.db.options.category = name
                if mouse == "RightButton" then M:ShowAttachMenu() else M:QuickAttach() end
            end)
            tip(b, "Attach " .. name .. ". Right-click for attachment options.")
            self.attachButtons[i] = b
        end
        self.attachButton = self.attachButtons[1]
    end
    if OpenMailFrame then
        self.copyButton = button(OpenMailFrame, "Copy", 56, function() M:FocusedMail(function(h) M:CopyMail(h.index) end) end)
        self.copyButton:SetPoint("TOPRIGHT", -88, -37)
        self.forwardButton = button(OpenMailFrame, "Forward", 72, function() M:FocusedMail(function(h) M:ForwardMail(h.index) end) end)
        self.forwardButton:SetPoint("LEFT", self.copyButton, "RIGHT", 4, 0)
    end
    -- Preserve normal native mailbox paging, including clients whose update globals disappeared.
    InboxFrame:EnableMouseWheel(true)
    InboxFrame:HookScript("OnMouseWheel", function(_, delta)
        if not M.mailOpen or M.queue then return end
        local pager = delta > 0 and InboxPrevPageButton or InboxNextPageButton
        if pager and pager.Click and (not pager.IsEnabled or pager:IsEnabled()) then pager:Click() end
        M:RefreshUI()
    end)
end

function M:NativeIndex(slot, native)
    local page = InboxFrame and InboxFrame.pageNum or 1
    return native and native.index or ((page - 1) * (INBOXITEMS_TO_DISPLAY or 7) + slot)
end

function M:InstallInboxRow(slot, row, native)
    -- Reserve a checkbox gutter inside the existing mailbox, once per row.
    local point, relative, relativePoint, x, y = row:GetPoint(1)
    if point and slot == 1 then
        row:ClearAllPoints(); row:SetPoint(point, relative, relativePoint, (x or 0) + 18, y or 0)
    end
    row:SetWidth(math.max(1, row:GetWidth() - 18))
    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(20, 20); check:SetPoint("RIGHT", row, "LEFT", 2, 0)
    check:SetScript("OnClick", function(b)
        local h = M:Header(M:NativeIndex(slot, native))
        if h then M.focusMail = h; M:ToggleSelection(h, not not b:GetChecked()) end
    end)
    tip(check, "Select mail. Shift: range. Ctrl: same sender.")
    self.inboxChecks[slot] = {check = check, row = row, native = native}
    if native then
        local original = native:GetScript("OnClick")
        native:SetScript("OnClick", function(b, ...)
            if M.mailOpen and not M.conflict then
                if M.queue then return end
                local h = M:Header(M:NativeIndex(slot, b))
                if h then
                    M.focusMail = h
                    if M.db.options.express and (IsShiftKeyDown() or IsControlKeyDown()) then
                        M:StartQueue(IsControlKeyDown() and "return" or "selected", {[h.index] = h.signature})
                        return
                    end
                end
            end
            if original then return original(b, ...) end
        end)
        native:HookScript("OnEnter", function(b)
            local h = M:Header(M:NativeIndex(slot, b))
            if not h or not GameTooltip then return end
            for _, item in ipairs(h.items) do GameTooltip:AddLine(item.name .. " x" .. item.count, 1, 1, 1) end
            GameTooltip:Show()
        end)
    end
    local expiry = _G["MailItem" .. slot .. "ExpireTime"]
    if expiry then
        tip(expiry, "Click to return this message, or confirm deletion of an empty message.")
        expiry:SetScript("OnClick", function()
            if M.queue then return end
            local h = M:Header(M:NativeIndex(slot, native))
            if not h then return end
            if InboxItemCanDelete and InboxItemCanDelete(h.index) then M:ConfirmDelete(h)
            else M:StartQueue("return", {[h.index] = h.signature}) end
        end)
    end
end

function M:RefreshUI()
    if not self.ui then return end
    self.uiPage = InboxFrame.pageNum
    local inbox = self:Inbox()
    local count = 0
    for index, signature in pairs(self.selection) do
        if inbox[index] and inbox[index].signature == signature then count = count + 1 else self.selection[index] = nil end
    end
    self.selectAll:SetChecked(#inbox > 0 and count == #inbox)
    self.selectAll:SetShown(#inbox > 0)
    self.collectButton:SetText(self.queue and "Stop" or "Open")
    self.returnButton:SetEnabled(not self.queue)
    self.openAll:SetText(self.queue and "Stop" or "Open All")
    for slot = 1, INBOXITEMS_TO_DISPLAY or 7 do
        local row = _G["MailItem" .. slot]
        local native = row and (row.Button or _G["MailItem" .. slot .. "Button"])
        if row and not self.inboxChecks[slot] then self:InstallInboxRow(slot, row, native) end
        local entry = self.inboxChecks[slot]
        if entry then
            local index = self:NativeIndex(slot, native)
            entry.check:SetShown(inbox[index] ~= nil and row:IsShown())
            entry.check:SetChecked(self.selection[index] ~= nil)
        end
    end
    -- Some clients include a native Open All button. Use its existing position.
    if not self.nativeOpenAll then
        local candidate = _G.OpenAllMail or _G.OpenAllMailButton or InboxFrame.OpenAllMail
        if not candidate and InboxFrame.GetChildren then
            for _, child in ipairs({InboxFrame:GetChildren()}) do
                if child.GetText and (child:GetText() == (OPEN_ALL_MAIL or "Open All") or child:GetText() == "Open All") then
                    candidate = child; break
                end
            end
        end
        if candidate and candidate ~= self.openAll and candidate.GetScript then
            self.nativeOpenAll = candidate
            candidate:SetScript("OnClick", function() if M.queue then M:StopQueue() else M:StartQueue("all") end end)
            candidate:ClearAllPoints()
            candidate:SetSize(120, 22)
            if InboxPrevPageButton then candidate:SetPoint("LEFT", InboxPrevPageButton, "RIGHT", 28, 0)
            else candidate:SetPoint("BOTTOMLEFT", InboxFrame, "BOTTOMLEFT", 80, 8) end
            self.openAllOptions:ClearAllPoints(); self.openAllOptions:SetPoint("LEFT", candidate, "RIGHT", 2, 0)
            self.openAll:Hide()
        end
    end
    if self.nativeOpenAll then self.nativeOpenAll:SetText(self.queue and "Stop" or "Open All") end
end

function M:HideSubmenus(depth)
    for level, frame in pairs(self.menuPanels or {}) do if level > depth then frame:Hide() end end
end
function M:MenuMouseWatch(delta)
    if not MouseIsOver then return end
    for _, frame in pairs(self.menuPanels or {}) do
        if frame:IsShown() and (MouseIsOver(frame) or (frame.anchor and MouseIsOver(frame.anchor))) then
            self.menuAwayFor = 0; return
        end
    end
    self.menuAwayFor = (self.menuAwayFor or 0) + delta
    if self.menuAwayFor > 0.45 and self.menu then self.menu:Hide() end
end
function M:SmallMenu(title, entries, anchor, offset, depth)
    depth = depth or 1
    self.menuPanels = self.menuPanels or {}
    self:HideSubmenus(depth)
    local body, footer = {}, {}
    for _, entry in ipairs(entries) do
        if entry.footer then footer[#footer + 1] = entry
        elseif entry.text ~= "Close" then body[#body + 1] = entry end
    end
    while #body > 0 and body[#body].separator do table.remove(body) end
    if not self.menuPanels[depth] then
        local f = CreateFrame("Frame", depth == 1 and "MailwrightContactsMenu" or nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
        if f.SetBackdrop then
            f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
            f:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
        end
        f.rows = {}
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.title:SetPoint("TOPLEFT", 12, -11)
        if depth == 1 then
            if UISpecialFrames then table.insert(UISpecialFrames, "MailwrightContactsMenu") end
            self.menu = f
            f:SetScript("OnHide", function() M:HideSubmenus(1) end)
            f:SetScript("OnUpdate", function(_, delta) M:MenuMouseWatch(delta) end)
        end
        self.menuPanels[depth] = f
    end
    local f = self.menuPanels[depth]
    f.anchor = anchor or self.recipientButton or MailFrame
    f.title:SetText(title)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", f.anchor, depth > 1 and "TOPRIGHT" or "BOTTOMLEFT", depth > 1 and -2 or 0, depth > 1 and 12 or -2)
    local visible = {}
    for _, entry in ipairs(body) do visible[#visible + 1] = entry end
    visible[#visible + 1] = {text = "", separator = true, disabled = true}
    for _, entry in ipairs(footer) do visible[#visible + 1] = entry end
    visible[#visible + 1] = {text = "Close", action = function() M.menu:Hide() end}
    local width = 150
    for _, entry in ipairs(visible) do
        f.title:SetText(entry.text)
        width = math.max(width, (f.title:GetStringWidth() or 0) + 28)
    end
    f.title:SetText(title)
    width = math.min(560, width)
    local cursor = 28
    for i = 1, math.max(#f.rows, #visible) do
        if not f.rows[i] then
            local b = CreateFrame("Button", nil, f)
            b.caption = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.caption:SetPoint("LEFT", 0, 0); b.caption:SetJustifyH("LEFT")
            b.divider = b:CreateTexture(nil, "ARTWORK")
            b.divider:SetPoint("LEFT", 0, 0); b.divider:SetPoint("RIGHT", 0, 0)
            b.divider:SetHeight(1); b.divider:SetColorTexture(0.65, 0.58, 0.4, 0.45)
            b:SetNormalFontObject("GameFontHighlightSmall"); b:SetHighlightFontObject("GameFontNormalSmall")
            b:SetDisabledFontObject("GameFontDisableSmall")
            b:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
            b:SetScript("OnClick", function(self) if self.action then self.action(self) end end)
            b:SetScript("OnEnter", function(self)
                M.menuAwayFor = 0
                if self.hover then self.hover(self) else M:HideSubmenus(depth) end
            end)
            f.rows[i] = b
        end
        local b, entry = f.rows[i], visible[i]
        b:SetShown(entry ~= nil)
        if entry then
            local height = entry.separator and 10 or 18
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 12, -cursor)
            b:SetSize(width - 24, height); b.caption:SetWidth(width - 24)
            b.divider:SetShown(not not entry.separator)
            b.caption:SetShown(not entry.separator)
            cursor = cursor + height
            b:SetText(""); b.caption:SetText(entry.text)
            b.caption:SetTextColor(entry.disabled and 0.5 or 1, entry.disabled and 0.5 or 1, entry.disabled and 0.5 or 1)
            b.action = entry.action; b.hover = entry.hover; b:SetEnabled(not entry.disabled)
        end
    end
    f:SetSize(width, cursor + 8)
    self.menuAwayFor = 0
    f:Show(); f:Raise()
end

function M:ShowContactMenu(group, suggestions, anchor, depth)
    depth = depth or 1
    self.menuGroup = group
    if not group or group == "Friends" then self:RequestFriends() end
    local entries = {}
    if not group then
        local contacts = self:Recipients("Contacts")
        for i = 1, math.min(#contacts, 4) do
            local r = contacts[i]
            entries[#entries + 1] = {text = r.name, disabled = not r.ok,
                action = function() if M:SetRecipient(r.name) then M.menu:Hide() end end}
        end
        if #contacts > 4 then
            local open = function(b) M:ShowContactMenu("Contacts", nil, b, depth + 1) end
            entries[#entries + 1] = {text = "More contacts >", action = open, hover = open}
        end
        if #contacts > 0 then entries[#entries + 1] = {text = "", separator = true, disabled = true} end
        entries[#entries + 1] = {text = "Add contact", action = function() if M:AddContact(M:Recipient()) then M:ShowContactMenu() end end}
        entries[#entries + 1] = {text = "Remove contact", action = function() M:RemoveContact(M:Recipient()); M.menu:Hide() end}
        entries[#entries + 1] = {text = "", separator = true, disabled = true}
        for _, value in ipairs({"Recent", "Alts", "All alts", "Friends", "Guild"}) do
            local name = value
            local labels = {Recent = "Recently Mailed", Alts = self.forever and "Alts (current ruleset)" or "Alts", ["All alts"] = self.forever and "All Alts (by ruleset)" or "All Alts"}
            local open = function(b) M:ShowContactMenu(name, nil, b, depth + 1) end
            entries[#entries + 1] = {text = (labels[name] or name) .. " >", disabled = name ~= "Friends" and #M:Recipients(name) == 0,
                action = open, hover = open}
        end
        entries[#entries + 1] = {text = "", separator = true, disabled = true}
        entries[#entries + 1] = {text = "Export contacts", action = function() M.menu:Hide(); M:TextWindow("Export contacts", M:ExportContacts(), false) end}
        entries[#entries + 1] = {text = "Import contacts", action = function() M.menu:Hide(); M:TextWindow("Import contacts", "", true) end}
    else
        local previous
        local records = suggestions or self:Recipients(group)
        if #records > 25 then
            for first = 1, #records, 25 do
                local chunk = {}
                for i = first, math.min(first + 24, #records) do chunk[#chunk + 1] = records[i] end
                local open = function(b) M:ShowContactMenu(group, chunk, b, depth + 1) end
                entries[#entries + 1] = {text = "Part " .. math.floor((first - 1) / 25 + 1) .. " >", action = open, hover = open}
            end
            records = {}
        end
        for _, r in ipairs(records) do
            if self.forever and group == "All alts" and previous ~= (r.ruleset or "Unknown") then
                previous = r.ruleset or "Unknown"; entries[#entries + 1] = {text = "-- " .. previous .. " --", disabled = true}
            end
            local name = r.name
            entries[#entries + 1] = {text = M:RecipientLabel(r, group), disabled = not r.ok,
                action = function() if M:SetRecipient(name) then M.menu:Hide() end end}
        end
        if #entries == 0 then entries[#entries + 1] = {text = group == "Friends" and "No mail-ready characters available" or "No entries yet", disabled = true} end
        entries[#entries + 1] = {text = "< Contacts", footer = true, action = function() M:ShowContactMenu() end}
    end
    entries[#entries + 1] = {text = "", separator = true, disabled = true}
    entries[#entries + 1] = {text = "Close", action = function() M.menu:Hide() end}
    self:SmallMenu(group or "Contacts", entries, anchor or self.recipientButton, nil, depth)
end

function M:ShowOptionsMenu()
    self.menuGroup = "Options"
    local entries = {}
    for _, pair in ipairs({{"items", "Collect attachments"}, {"money", "Collect money"}, {"auctions", "Include auction mail"},
        {"express", "Express shortcuts"}, {"autoSend", "Express automatic send"}, {"moneySubject", "Money subject"},
        {"summary", "Money summary"}, {"blockTrades", "Block trades"}}) do
        local key, text = pair[1], pair[2]
        entries[#entries + 1] = {text = (self.db.options[key] and "[x] " or "[ ] ") .. text, action = function()
            M.db.options[key] = not M.db.options[key]
            if key == "blockTrades" then
                if M.db.options[key] and GetCVar("BlockTrades") == "0" then M.oldTrade = "0"; SetCVar("BlockTrades", "1")
                elseif not M.db.options[key] and M.oldTrade then
                    if GetCVar("BlockTrades") == "1" then SetCVar("BlockTrades", M.oldTrade) end
                    M.oldTrade = nil
                end
            end
            M:ShowOptionsMenu()
        end}
    end
    entries[#entries + 1] = {text = "Free bag slots: " .. self.db.options.reserve .. " (+1; Shift -1)", action = function()
        M.db.options.reserve = math.max(0, math.min(100, M.db.options.reserve + (IsShiftKeyDown() and -1 or 1))); M:ShowOptionsMenu()
    end}
    entries[#entries + 1] = {text = "Delay: " .. self.db.options.delay .. " sec (cycle)", action = function()
        local n = M.db.options.delay + 0.25; M.db.options.delay = n > 2 and 0.25 or n; M:ShowOptionsMenu()
    end}
    entries[#entries + 1] = {text = "Collect money only", action = function() M.menu:Hide(); M:StartQueue("money") end}
    entries[#entries + 1] = {text = "Quick attach >", action = function() M:ShowAttachMenu() end}
    entries[#entries + 1] = {text = "Saved-data status", action = function() M:Print(M:Status()); M.menu:Hide() end}
    self:SmallMenu("Mailwright", entries, self.settingsButton)
end

function M:ShowAttachMenu()
    self.menuGroup = "Attach"
    local entries = {}
    for _, category in ipairs(self.categories) do
        local name = category
        entries[#entries + 1] = {text = "Attach " .. name, action = function()
            M.db.options.category = name; M.menu:Hide(); M:QuickAttach()
        end}
    end
    entries[#entries + 1] = {text = "Minimum quality: " .. self.db.options.quality .. " (cycle)", action = function()
        M.db.options.quality = (M.db.options.quality + 1) % 6; M:ShowAttachMenu()
    end}
    entries[#entries + 1] = {text = "Bag: " .. (self.db.options.bag == -1 and "All" or self.db.options.bag) .. " (cycle)", action = function()
        M.db.options.bag = M.db.options.bag + 1
        if M.db.options.bag > (NUM_BAG_SLOTS or 4) then M.db.options.bag = -1 end
        M:ShowAttachMenu()
    end}
    entries[#entries + 1] = {text = "Save To for " .. self.db.options.category, action = function()
        local name, why = M:ValidName(M:Recipient())
        if name then M.db.recipients[M.db.options.category] = name; M:Print("Category recipient saved.")
        else M:Print(why) end
        M.menu:Hide()
    end}
    entries[#entries + 1] = {text = "Clear category recipient", action = function() M.db.recipients[M.db.options.category] = nil; M.menu:Hide() end}
    entries[#entries + 1] = {text = "Stop attaching", action = function() M.attachQueue = nil; M.menu:Hide() end}
    self:SmallMenu("Quick attach", entries, self.attachButton or self.settingsButton)
end
