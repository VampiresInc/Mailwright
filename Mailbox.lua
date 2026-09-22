local _, ns = ...
local M = ns.M
function M:Eligible(h, mode)
    if h.gm or h.cod > 0 then return false end
    if mode == "return" then return h.reply and not h.returned end
    if mode == "money" then return h.money > 0 end
    if mode == "selected" or mode == "forward" then return h.money > 0 or h.count > 0 end
    if not self.db.options.auctions and GetInboxInvoiceInfo then
        local invoice = GetInboxInvoiceInfo(h.index)
        if invoice and invoice ~= "" then return false end
    end
    return (self.db.options.money and h.money > 0) or (self.db.options.items and h.count > 0)
end
function M:StartQueue(mode, indices, finished)
    if self.queue or self.attachQueue then self:Print("Finish or cancel the current operation first."); return false end
    if not self.mailOpen or self.conflict then return false end
    local tasks = {}
    local inbox, total = self:Inbox()
    for i = #inbox, 1, -1 do
        local h = inbox[i]
        local chosen = not indices or indices[h.index] == true or indices[h.index] == h.signature
        if chosen and self:Eligible(h, mode) then tasks[#tasks + 1] = h end
    end
    if #tasks == 0 then self:Print("No eligible mail. COD and GM mail are skipped."); return false end
    self.queue = {mode = mode, tasks = tasks, next = GetTime(), completed = 0, finished = finished,
        initialTotal = total, batches = 0}
    self.selection = {}
    self:RefreshUI()
    return true
end
function M:StopQueue(reason, quiet)
    local q = self.queue
    self.queue = nil
    if q and not quiet then self:Print(reason or "Stopped. Items already collected remain in your bags.") end
    if self.ui then self:RefreshUI() end
end
function M:FinishQueue()
    local q = self.queue
    self.queue = nil
    self:Print("Finished: " .. q.completed .. " messages processed.")
    self:RefreshUI()
    if q.finished then q.finished() end
end
function M:TickQueue()
    local q = self.queue
    if not q or GetTime() < q.next then return end
    if q.wait then
        local current = self:Header(q.wait.index)
        local removed = (GetInboxNumItems() or 0) < q.wait.visible
        local changed = removed or not current or current.signature ~= q.wait.signature
        if changed and not self:Pending() then
            if q.wait.kind == "money" then self.collected = (self.collected or 0) + q.wait.money end
            local task = q.tasks[1]
            if q.wait.kind == "return" or removed or not current or current.sender ~= task.sender or current.subject ~= task.subject then
                table.remove(q.tasks, 1); q.completed = q.completed + 1
            elseif q.wait.kind == "money" and current.money == task.money then
                self:StopQueue("Inbox changed unexpectedly; stopped safely."); return
            elseif q.wait.kind == "item" and current.count >= task.count then
                self:StopQueue("Inbox changed unexpectedly; stopped safely."); return
            else q.tasks[1] = current end
            q.wait = nil
            q.next = GetTime() + self.db.options.delay
            self:RefreshUI()
        elseif GetTime() - q.wait.started > 12 then self:StopQueue("Server did not confirm the mail operation. Check your inbox and try again.") end
        return
    end
    if self:Pending() then return end
    local task = q.tasks[1]
    if not task then
        local inbox, total = self:Inbox()
        if q.mode == "all" and q.completed > 0 and total > #inbox and q.batches < 20 and not q.refreshed then
            local allowed = not C_Mail or not C_Mail.CanCheckInbox or C_Mail.CanCheckInbox()
            if allowed and CheckInbox then q.refreshed = true; q.next = GetTime() + 2; CheckInbox(); return end
        end
        if q.refreshed then
            q.refreshed = nil; q.batches = q.batches + 1
            for i = #inbox, 1, -1 do if self:Eligible(inbox[i], "all") then q.tasks[#q.tasks + 1] = inbox[i] end end
            if #q.tasks > 0 then q.next = GetTime() + self.db.options.delay; return end
        end
        self:FinishQueue(); return
    end
    local h = self:Header(task.index)
    if not h or h.signature ~= task.signature then self:StopQueue("Inbox changed before the next operation. Select the mail again."); return end
    local kind
    if q.mode == "return" then kind = "return"
    elseif h.money > 0 and (q.mode ~= "all" or self.db.options.money) then kind = "money"
    elseif h.count > 0 and q.mode ~= "money" and (q.mode ~= "all" or self.db.options.items) then
        if #h.items == 0 then self:StopQueue("Attachment details are not ready. Try again in a moment."); return end
        if self:FreeSlots() <= self.db.options.reserve then self:StopQueue("Stopped at your free-bag-slot reserve. Make room or lower the reserve in Options."); return end
        kind = "item"
    else table.remove(q.tasks, 1); q.completed = q.completed + 1; return end
    q.wait = {index = h.index, signature = h.signature, kind = kind, money = h.money, started = GetTime(), visible = GetInboxNumItems()}
    if kind == "return" then ReturnInboxItem(h.index)
    elseif kind == "money" then TakeInboxMoney(h.index)
    else TakeInboxItem(h.index, h.items[1].slot) end
end
M:Listen("MAIL_INBOX_UPDATE", function(self)
    if not self.queue then self.selection = {} end
    if self.ui then self:RefreshUI() end
end)
M:Listen("MAIL_FAILED", function(self)
    if self.queue then self:StopQueue("The server rejected the mail operation. Check the game's error message.") end
    self.attachQueue, self.forwardPlan = nil, nil
end)
M:Listen("UI_ERROR_MESSAGE", function(self, id, message)
    local full = message == ERR_INV_FULL or message == ERR_ITEM_MAX_COUNT or message == ERR_MAIL_DATABASE_ERROR
    if full and self.queue then self:StopQueue(message) end
end)
