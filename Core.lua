local addon, ns = ...
local M = CreateFrame("Frame")
ns.M = M
_G.Mailwright = M
M.addon, M.version = addon, "0.2.0-alpha.7"
M.listeners, M.selection = {}, {}
M.defaults = {reserve = 1, delay = 0.35, blockTrades = true, express = true,
    autoSend = false, moneySubject = true, summary = true, auctions = true,
    items = true, money = true, quality = 0, bag = -1, category = "All"}
function M:Print(s)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffMailwright:|r " .. tostring(s)) end
end
function M:Listen(event, callback)
    self.listeners[event] = self.listeners[event] or {}
    table.insert(self.listeners[event], callback)
    pcall(self.RegisterEvent, self, event)
end
function M:Emit(event, ...)
    for _, callback in ipairs(self.listeners[event] or {}) do callback(self, ...) end
end
M:SetScript("OnEvent", function(self, event, ...) self:Emit(event, ...) end)
function M:Initialize()
    if self.db then return end
    self.loadedData = type(MailwrightDB) == "table"
    if not self.loadedData then MailwrightDB = {} end
    local db = MailwrightDB
    for _, key in ipairs({"contacts", "alts", "recent", "options", "recipients"}) do
        if type(db[key]) ~= "table" then db[key] = {} end
    end
    for k, v in pairs(self.defaults) do if type(db.options[k]) ~= type(v) then db.options[k] = v end end
    db.options.reserve = math.max(0, math.min(100, tonumber(db.options.reserve) or 1))
    db.options.delay = math.max(0.2, math.min(3, tonumber(db.options.delay) or 0.35))
    db.options.quality = math.max(0, math.min(5, math.floor(db.options.quality)))
    db.options.bag = math.max(-1, math.min(NUM_BAG_SLOTS or 4, math.floor(db.options.bag)))
    local categoryFound
    for _, category in ipairs(self.categories) do if db.options.category == category then categoryFound = true end end
    if not categoryFound then db.options.category = "All" end
    db.sessions = (tonumber(db.sessions) or 0) + 1
    db.schema = 1
    self.db = db
    self.forever = ns.forever or (type(GetBuildInfo) == "function" and select(4, GetBuildInfo()) == 16001) or false
    self:RecordPlayer()
end
M:Listen("ADDON_LOADED", function(self, name) if name == addon then self:Initialize() end end)
M:Listen("PLAYER_LOGIN", function(self) if self.db then self:RecordPlayer() end end)
M:Listen("PLAYER_ENTERING_WORLD", function(self) if self.db then self:RecordPlayer() end end)
function M:SetMailOpen(open)
    if not self.db or self.mailOpen == open then return end
    self.mailOpen = open
    if open then
        self:RecordPlayer()
        self.collected = 0
        if _G.Postal then
            self.conflict = true
            self:Print("Disable Postal in the AddOns list and reload before testing Mailwright.")
            return
        end
        self.conflict = false
        self:RequestFriends()
        if self.db.options.blockTrades and GetCVar and SetCVar then
            local old = GetCVar("BlockTrades")
            if old == "0" then self.oldTrade = old; SetCVar("BlockTrades", "1") end
        end
        self:ShowUI()
        self:InstallSendHooks()
    else
        self:StopQueue("Mailbox closed.", true)
        self.attachQueue, self.forwardPlan = nil, nil
        if self.ui then self.ui:Hide() end
        if self.menu then self.menu:Hide() end
        if self.oldTrade and GetCVar("BlockTrades") == "1" then SetCVar("BlockTrades", self.oldTrade) end
        self.oldTrade = nil
        if self.db.options.summary and (self.collected or 0) > 0 then self:Print("Collected " .. self:Money(self.collected) .. " this visit.") end
    end
end
M:Listen("MAIL_SHOW", function(self) self:SetMailOpen(true) end)
M:Listen("MAIL_CLOSED", function(self) self:SetMailOpen(false) end)
M:Listen("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(self, kind)
    if Enum and Enum.PlayerInteractionType and kind == Enum.PlayerInteractionType.MailInfo then self:SetMailOpen(true) end
end)
M:Listen("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(self, kind)
    if Enum and Enum.PlayerInteractionType and kind == Enum.PlayerInteractionType.MailInfo then self:SetMailOpen(false) end
end)
M:Listen("PLAYER_LOGOUT", function(self)
    if self.oldTrade and GetCVar("BlockTrades") == "1" then SetCVar("BlockTrades", self.oldTrade) end
end)
function M:Status()
    if not self.db then return "Database has not initialized." end
    local c, a = 0, 0
    for _ in pairs(self.db.contacts) do c = c + 1 end
    for _ in pairs(self.db.alts) do a = a + 1 end
    return self.version .. "; " .. c .. " contacts; " .. a .. " alts. Saved data: " ..
        (self.loadedData and "loaded" or "not loaded / new database") .. "; session count: " .. self.db.sessions
end
SLASH_MAILWRIGHT1, SLASH_MAILWRIGHT2 = "/mailwright", "/mw"
SlashCmdList.MAILWRIGHT = function(msg)
    if msg == "export" and M.db then M:TextWindow("Export contacts", M:ExportContacts(), false)
    elseif msg == "import" and M.db then M:TextWindow("Import contacts", "", true)
    elseif M.mailOpen and msg ~= "status" and not M.conflict then M:ShowUI(); M:ShowOptionsMenu()
    else M:Print(M:Status()) end
end
SLASH_MAILWRIGHTSTATUS1 = "/mwstatus"
SlashCmdList.MAILWRIGHTSTATUS = function() M:Print(M:Status()) end
local elapsed = 0
M:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 or not self.db then return end
    elapsed = 0
    local shown = MailFrame and MailFrame:IsShown() or false
    if shown ~= (not not self.mailOpen) then self:SetMailOpen(shown) end
    if self.mailOpen and not self.conflict then
        if not self.ui then self:ShowUI()
        elseif InboxFrame and self.uiPage ~= InboxFrame.pageNum then self:RefreshUI() end
        self:TickQueue(); self:TickAttachments(); self:UpdateMoneySubject()
    end
end)
