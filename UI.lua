local _, ns = ...
local M = ns.M
local function label(parent, text, x, y, width, font)
    local f = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT", x, y); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetText(M:L(text))
    return f
end
local function button(parent, text, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24); b:SetPoint("TOPLEFT", x, y); b:SetText(M:L(text)); b:SetScript("OnClick", callback)
    return b
end
local function panel(name, width, height)
    local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(width, height); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
    if f.SetBackdrop then
        f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
        f:SetBackdropColor(0.035, 0.055, 0.075, 0.98)
    end
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    button(f, "X", width - 34, -8, 24, function() f:Hide() end)
    if name and UISpecialFrames then table.insert(UISpecialFrames, name) end
    return f
end
local function checkbox(parent, text, x, y, checked, callback)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(26, 26); c:SetPoint("TOPLEFT", x, y); c:SetChecked(checked)
    label(c, text, 29, -7, 370)
    c:SetScript("OnClick", function(self) callback(not not self:GetChecked()) end)
    return c
end
function M:FocusedMail(action)
    if self.queue or self.attachQueue or self.forwardPlan then self:Print("Finish or cancel the current operation first."); return end
    local nativeIndex = InboxFrame and InboxFrame.openMailID
    local h = nativeIndex and nativeIndex > 0 and self:Header(nativeIndex) or self.focusMail and self:Header(self.focusMail.index)
    if not h or (not (nativeIndex and nativeIndex > 0) and h.signature ~= self.focusMail.signature) then self:Print("Click a message row first."); return end
    action(h)
end
function M:ToggleSelection(h, checked)
    if self.queue then return end
    local inbox = self:Inbox()
    if IsShiftKeyDown() and self.lastSelected then
        for i = math.min(self.lastSelected, h.index), math.max(self.lastSelected, h.index) do
            if inbox[i] then self.selection[i] = checked and inbox[i].signature or nil end
        end
    elseif IsControlKeyDown() then
        for _, mail in ipairs(inbox) do if mail.sender == h.sender then self.selection[mail.index] = checked and mail.signature or nil end end
    else self.selection[h.index] = checked and h.signature or nil end
    self.lastSelected = h.index
    self:RefreshUI()
end
function M:ShowUI()
    if not self.ui then self:BuildUI() end
    if self.ui then self.ui:Show(); self:RefreshUI() end
end
function M:TextWindow(title, text, importing)
    if not self.textWindow then
        local f = panel("MailwrightTextWindow", 570, 460)
        f.title = label(f, "", 16, -14, 500, "GameFontNormalLarge")
        f.help = label(f, "", 16, -46, 525)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -92); scroll:SetSize(504, 300)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(495); edit:SetHeight(300); edit:SetAutoFocus(false)
        edit:SetMaxLetters(200000); edit:SetTextInsets(4, 4, 4, 4); scroll:SetScrollChild(edit)
        edit:SetScript("OnEscapePressed", function() edit:ClearFocus(); f:Hide() end)
        edit:SetScript("OnCursorChanged", function(_, x, y, w, h)
            local current = scroll:GetVerticalScroll()
            if -y < current then scroll:SetVerticalScroll(-y)
            elseif -y + h > current + 300 then scroll:SetVerticalScroll(-y + h - 300) end
        end)
        edit:SetScript("OnTextChanged", function() f.prepared = nil; if f.apply then f.apply:SetText(M:L("Check import")) end end)
        f.edit = edit
        f.apply = button(f, "Check import", 18, -417, 150, function()
            if not f.prepared then
                local rows, errors = M:ParseContacts(edit:GetText())
                if not rows then f.help:SetText(errors); return end
                f.help:SetText(M:F("%d valid records; %d invalid lines. Existing contacts are kept. Click Import to merge.", #rows, errors))
                f.prepared = edit:GetText(); f.apply:SetText(M:L("Import contacts"))
            else
                local ok, message = M:ImportContacts(f.prepared); M:Print(message); f.help:SetText(message)
                f.prepared = nil; f.apply:SetText(M:L("Check import"))
            end
        end)
        button(f, "Select all", 184, -417, 120, function() edit:SetFocus(); edit:HighlightText() end)
        button(f, "Close", 422, -417, 120, function() f:Hide() end)
        self.textWindow = f
    end
    local f = self.textWindow
    f.title:SetText(self:L(title)); f.help:SetText(self:L(importing and "Paste a Mailwright backup or one full recipient name per line. Check the import before merging."
        or "Click Select all, then Ctrl+C to copy. Keep contact backups in a text file outside the game."))
    f.edit:SetText(text); f.apply:SetShown(importing); f:Show(); f:Raise(); f.edit:SetFocus()
end
function M:ConfirmDelete(h)
    if h.money > 0 or h.count > 0 or h.cod > 0 or h.gm then self:Print("Collect or return valuable contents first. Mailwright only deletes empty messages."); return end
    if not self.deleteWindow then
        local f = panel("MailwrightDeleteWindow", 410, 160)
        f.text = label(f, "", 18, -36, 370)
        button(f, "Delete", 55, -113, 130, function()
            local target = f.target; local current = target and M:Header(target.index)
            if M.mailOpen and not M.queue and current and current.signature == target.signature and current.count == 0 and current.money == 0 then
                DeleteInboxItem(target.index)
            else M:Print("Message changed. Select it again.") end
            f:Hide()
        end)
        button(f, "Cancel", 220, -113, 130, function() f:Hide() end)
        self.deleteWindow = f
    end
    self.deleteWindow.target = h
    self.deleteWindow.text:SetText(self:L("Permanently delete this empty message?") .. "\n\n" .. h.sender .. ": " .. h.subject)
    self.deleteWindow:Show()
end
function M:ShowSuggestions(raw)
    local prefix = string.lower(self:Trim(raw))
    if #prefix < 2 then if self.menu and self.menuGroup == "Suggestions" then self.menu:Hide() end; return end
    local list, seen = {}, {}
    for _, group in ipairs({"Contacts", "Alts", "Recent", "Friends", "Guild"}) do
        for _, r in ipairs(self:Recipients(group)) do
            local ok = self:CanRecipient(r.name)
            if r.ok and ok and not seen[r.name] and string.lower(r.name):sub(1, #prefix) == prefix then
                seen[r.name] = true; list[#list + 1] = r
            end
        end
    end
    if #list > 0 then self:ShowContactMenu("Suggestions", list)
    elseif self.menu and self.menuGroup == "Suggestions" then self.menu:Hide() end
end

-- Shared setters keep the mailbox menu and AddOns settings in sync.
function M:RefreshAttachmentTabs()
    if not self.db then return end
    for _, b in ipairs(self.attachButtons or {}) do b:SetShown(self.db.options.showAttachTabs) end
end
function M:SetOption(key, value)
    self.db.options[key] = value
    if key == "blockTrades" and self.mailOpen and not self.conflict then
        if value and GetCVar("BlockTrades") == "0" then self.oldTrade = "0"; SetCVar("BlockTrades", "1")
        elseif not value and self.oldTrade then
            if GetCVar("BlockTrades") == "1" then SetCVar("BlockTrades", self.oldTrade) end
            self.oldTrade = nil
        end
    end
    self:RefreshAttachmentTabs()
    if self.settingsPanel then self.settingsPanel.refresh() end
end
function M:RegisterSettings()
    if self.settingsPanel then return end
    local f = CreateFrame("Frame", nil, UIParent)
    f.name = "Mailwright"; f:Hide()
    self.settingsPanel = f
    label(f, "Mailwright", 16, -16, 500, "GameFontNormalLarge")
    label(f, "Changes are saved immediately. Mail actions require an open mailbox.", 16, -46, 540)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -72); scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, 610); scroll:SetScrollChild(content)
    local controls = {}
    local language = button(content, "", 16, -4, 350, function(b) M:ChooseLanguage(b) end)
    button(content, "Reload UI", 380, -4, 150, function() if ReloadUI then ReloadUI() end end)
    label(content, "Reload UI to apply language changes.", 16, -36, 510)
    local y = -70
    for _, pair in ipairs({{"showAttachTabs", "Show attachment tabs beside Send Mail"},
        {"items", "Collect attachments"}, {"money", "Collect money"}, {"auctions", "Include auction mail"},
        {"express", "Express shortcuts"}, {"autoSend", "Express automatic send (sends mail immediately)"},
        {"moneySubject", "Money subject"}, {"summary", "Money summary"}, {"blockTrades", "Block trades while the mailbox is open"}}) do
        local key = pair[1]
        controls[key] = checkbox(content, pair[2], 16, y, self.db.options[key], function(value) M:SetOption(key, value) end)
        y = y - 42
    end
    local reserve = button(content, "", 16, y - 8, 260, function()
        M:SetOption("reserve", math.max(0, math.min(100, M.db.options.reserve + (IsShiftKeyDown() and -1 or 1))))
    end)
    label(content, "Click +1; Shift-click -1", 290, y - 14, 240)
    local delay = button(content, "", 16, y - 42, 260, function()
        local n = M.db.options.delay + 0.25
        M:SetOption("delay", n > 2 and 0.25 or n)
    end)
    label(content, "Click to cycle collection delay", 290, y - 48, 240)
    f.refresh = function()
        language:SetText(M:L("Language") .. ": " .. M:LanguageName())
        for key, control in pairs(controls) do control:SetChecked(M.db.options[key]) end
        reserve:SetText(M:L("Free bag slots: ") .. M.db.options.reserve)
        delay:SetText(M:F("Delay: %s sec", M.db.options.delay))
    end
    f.languageButton = language
    f:SetScript("OnHide", function() if M.menu and M.menu.anchor == language then M.menu:Hide() end end)
    f.controls = controls
    f:SetScript("OnShow", f.refresh); f.refresh()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        self.settingsCategory = Settings.RegisterCanvasLayoutCategory(f, f.name)
        Settings.RegisterAddOnCategory(self.settingsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(f)
    end
end
function M:OpenSettings()
    self:RegisterSettings()
    if self.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
    else
        self:Print("AddOns settings are unavailable on this client; use /mw at a mailbox.")
    end
end
