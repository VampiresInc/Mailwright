local _, ns = ...
local M = ns.M
local function label(parent, text, x, y, width, font)
    local f = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT", x, y); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetText(text)
    return f
end
local function button(parent, text, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24); b:SetPoint("TOPLEFT", x, y); b:SetText(text); b:SetScript("OnClick", callback)
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
    if self.queue or self.attachQueue then self:Print("Finish or cancel the current operation first."); return end
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
        edit:SetScript("OnTextChanged", function() f.prepared = nil; if f.apply then f.apply:SetText("Check import") end end)
        f.edit = edit
        f.apply = button(f, "Check import", 18, -417, 150, function()
            if not f.prepared then
                local rows, errors = M:ParseContacts(edit:GetText())
                if not rows then f.help:SetText(errors); return end
                f.help:SetText(#rows .. " valid records; " .. errors .. " invalid lines. Existing contacts are kept. Click Import to merge.")
                f.prepared = edit:GetText(); f.apply:SetText("Import contacts")
            else
                local ok, message = M:ImportContacts(f.prepared); M:Print(message); f.help:SetText(message)
                f.prepared = nil; f.apply:SetText("Check import")
            end
        end)
        button(f, "Select all", 184, -417, 120, function() edit:SetFocus(); edit:HighlightText() end)
        button(f, "Close", 422, -417, 120, function() f:Hide() end)
        self.textWindow = f
    end
    local f = self.textWindow
    f.title:SetText(title); f.help:SetText(importing and "Paste a Mailwright backup or one full recipient name per line. Check the import before merging."
        or "Click Select all, then Ctrl+C to copy. Keep contact backups in a text file outside the game.")
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
    self.deleteWindow.text:SetText("Permanently delete this empty message?\n\n" .. h.sender .. ": " .. h.subject)
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
