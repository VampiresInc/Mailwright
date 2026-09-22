local _, ns = ...
local M = ns.M
M.categories = {"All", "Trade goods", "Consumables", "Equipment", "Gems", "Recipes", "Quest items"}
function M:ItemEligible(item, category)
    if not item or not item.link or item.locked or item.bound then return false end
    local d = self:ItemDetails(item.link)
    if not d then return false end
    -- Binds-on-pickup/quest items can be character-bound on legacy clients without an isBound field.
    if d.bind == 1 or d.bind == 4 then return false end
    if item.bound == nil and d.bind and d.bind ~= 0 then return false end
    if (d.quality or 0) < self.db.options.quality then return false end
    if self.db.options.bag >= 0 and item.bag ~= self.db.options.bag then return false end
    return category == "All" or category == "Trade goods" and d.class == 7
        or category == "Consumables" and d.class == 0 or category == "Equipment" and (d.class == 2 or d.class == 4)
        or category == "Gems" and d.class == 3 or category == "Recipes" and d.class == 9
        or category == "Quest items" and d.class == 12
end
function M:StartAttach(items, autoSend)
    if not self.mailOpen or self.conflict or self.queue or self.attachQueue then return false end
    if MailFrameTab_OnClick then MailFrameTab_OnClick(nil, 2) end
    if #items == 0 then self:Print("No eligible cached, unbound items match those filters."); return false end
    local empty = self:SendCount() == 0 and (not SendMailBodyEditBox or SendMailBodyEditBox:GetText() == "")
    self.attachQueue = {items = items, next = GetTime(), recipient = self:Recipient(), autoSend = autoSend and empty, added = 0}
    return true
end
function M:QuickAttach()
    local category = self.db.options.category
    local recipient = self.db.recipients[category]
    if recipient and not self:SetRecipient(recipient) then return end
    local items = {}
    for _, item in ipairs(self:BagItems()) do if self:ItemEligible(item, category) then items[#items + 1] = item end end
    self:StartAttach(items, false)
end
function M:TickAttachments()
    local q = self.attachQueue
    if not q or GetTime() < q.next then return end
    if q.wait then
        if self:SendCount() > q.wait.count then
            q.added = q.added + 1; q.wait = nil; table.remove(q.items, 1); q.next = GetTime() + self.db.options.delay
        elseif GetTime() - q.wait.started > 6 then self.attachQueue = nil; self:Print("Attachment was not accepted. Check the draft before trying again.") end
        return
    end
    if #q.items == 0 or self:SendCount() >= (ATTACHMENTS_MAX_SEND or 12) then
        self.attachQueue = nil
        if q.autoSend and #q.items == 0 and q.added > 0 and self:Recipient() == q.recipient and self:SendCount() == q.added then self:SendDraft()
        else self:Print("Attached " .. q.added .. " item stacks. Review the draft before sending.") end
        return
    end
    local item = q.items[1]
    local current = self:BagItem(item.bag, item.slot)
    if not current or current.link ~= item.link or current.count ~= item.count or current.locked or current.bound then
        self.attachQueue = nil; self:Print("Inventory changed. Review the draft before attaching again."); return
    end
    q.wait = {count = self:SendCount(), started = GetTime()}
    self:UseBagItem(item.bag, item.slot)
end
function M:SendDraft()
    local recipient = self:Recipient()
    local ok, why = self:CanRecipient(recipient)
    if not ok then self:Print(why); return end
    if SendMailFrame and SendMailFrame.sendMode == "cod" then self:Print("Automatic sending is disabled for COD drafts."); return end
    if GetSendMailMoney and GetSendMailMoney() > 0 then self:Print("Send drafts containing money with the game's Send button."); return end
    self:UpdateMoneySubject()
    local subject = SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() or ""
    if subject == "" then self:Print("Enter a subject before sending."); return end
    SendMail(recipient, subject, SendMailBodyEditBox and SendMailBodyEditBox:GetText() or "")
end
function M:UpdateMoneySubject()
    if not self.db.options.moneySubject or not SendMailSubjectEditBox then return end
    local value = GetSendMailMoney and GetSendMailMoney() or 0
    if value <= 0 or SendMailFrame and SendMailFrame.sendMode == "cod" then return end
    local text = SendMailSubjectEditBox:GetText()
    if text == "" or text == self.moneySubject then
        self.moneySubject = self:Money(value)
        SendMailSubjectEditBox:SetText(self.moneySubject)
    end
end
function M:ExpressBag(bag, slot)
    if not self.mailOpen or self.conflict or not self.db.options.express or not IsAltKeyDown() then return end
    local item = self:BagItem(bag, slot)
    if not self:ItemEligible(item, "All") then self:Print("That item cannot be attached automatically with your current filters."); return end
    local items = {item}
    if IsControlKeyDown() then
        items = {}
        for _, i in ipairs(self:BagItems()) do if i.link == item.link and self:ItemEligible(i, "All") then items[#items + 1] = i end end
    end
    self:StartAttach(items, self.db.options.autoSend)
end
function M:InstallSendHooks()
    if not self.sendHook and type(SendMail) == "function" then
        self.sendHook = true
        hooksecurefunc("SendMail", function(name) if M.db then M.pendingRecipient = name end end)
    end
    if not self.bagHook and type(HandleModifiedItemClick) == "function" then
        self.bagHook = true
        hooksecurefunc("HandleModifiedItemClick", function(link, location)
            if location and location.IsBagAndSlot and location:IsBagAndSlot() then M:ExpressBag(location:GetBagAndSlot()) end
        end)
    elseif not self.bagHook and type(ContainerFrameItemButton_OnModifiedClick) == "function" then
        self.bagHook = true
        hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(button)
            if button and button.GetParent then M:ExpressBag(button:GetParent():GetID(), button:GetID()) end
        end)
    end
    if SendMailNameEditBox and not self.nameHook then
        self.nameHook = true
        SendMailNameEditBox:HookScript("OnTextChanged", function(box, user)
            if user and M.mailOpen and not M.conflict then M:ShowSuggestions(box:GetText()) end
        end)
    end
end
M:Listen("MAIL_SEND_SUCCESS", function(self)
    if self.pendingRecipient then self:RememberRecipient(self.pendingRecipient); self.pendingRecipient = nil end
end)
M:Listen("MAIL_FAILED", function(self) self.pendingRecipient = nil end)
function M:CopyMail(index)
    local h = self:Header(index)
    if not h then return end
    local body = GetInboxText(index) or ""
    local lines = {"From: " .. h.sender, "Subject: " .. h.subject, "Money: " .. self:Money(h.money), "", body}
    for _, item in ipairs(h.items) do lines[#lines + 1] = item.name .. " x" .. item.count end
    if GetInboxInvoiceInfo then
        local kind, name, player, bid, buyout, deposit, fee = GetInboxInvoiceInfo(index)
        if kind and kind ~= "" then
            lines[#lines + 1] = "Invoice: " .. kind .. " / " .. tostring(name or "") .. " / " .. tostring(player or "")
            lines[#lines + 1] = "Bid: " .. self:Money(bid) .. "; buyout: " .. self:Money(buyout) .. "; deposit: " .. self:Money(deposit) .. "; fee: " .. self:Money(fee)
        end
    end
    self:TextWindow("Copy message", table.concat(lines, "\n"), false)
end
function M:ForwardMail(index)
    if self.queue or self.attachQueue then self:Print("Finish the current operation first."); return end
    local h = self:Header(index)
    if not h then return end
    if h.cod > 0 or h.money > 0 or h.gm then self:Print("Collect money yourself first. COD and GM mail cannot be forwarded."); return end
    if self:SendCount() > 0 or (SendMailBodyEditBox and SendMailBodyEditBox:GetText() ~= "")
        or (SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() ~= "") or (GetSendMailMoney and GetSendMailMoney() > 0) then
        self:Print("Clear your existing draft before forwarding."); return
    end
    if h.count > (ATTACHMENTS_MAX_SEND or 12) then self:Print("Too many attachments to forward in one draft."); return end
    local wanted, bags = {}, self:BagItems()
    for _, item in ipairs(h.items) do
        local d = self:ItemDetails(item.link)
        if not d or d.stack ~= 1 or wanted[item.link] or item.count ~= 1 then
            self:Print("Automatic forwarding requires cached, distinct, non-stackable items. Collect other attachments and attach them manually."); return
        end
        for _, owned in ipairs(bags) do if owned.link == item.link then self:Print("An identical item is already in your bags. Forward that attachment manually."); return end end
        wanted[item.link] = true
    end
    if h.count ~= #h.items then self:Print("Wait for attachment details to load."); return end
    local body = GetInboxText(index) or ""
    local function draft()
        if not M.mailOpen then return end
        if MailFrameTab_OnClick then MailFrameTab_OnClick(nil, 2) end
        SendMailSubjectEditBox:SetText("Fwd: " .. h.subject)
        SendMailBodyEditBox:SetText("From: " .. h.sender .. "\n\n" .. body)
        local items, counts = {}, {}
        for _, item in ipairs(M:BagItems()) do
            if wanted[item.link] then items[#items + 1] = item; counts[item.link] = (counts[item.link] or 0) + 1 end
        end
        for link in pairs(wanted) do
            if counts[link] ~= 1 then M:Print("Forward draft created; attach the collected items manually because inventory identification was ambiguous."); return end
        end
        if #items > 0 then M:StartAttach(items, false) end
        M:Print("Forward draft ready. Choose a recipient and review before sending.")
    end
    if h.count == 0 then draft() else self:StartQueue("forward", {[index] = h.signature}, draft) end
end
