local _, ns = ...
local M = ns.M
local LIMIT = 50
local function safe(value)
    if issecretvalue and issecretvalue(value) then return "<restricted>" end
    if type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" then return "unknown" end
    return tostring(value)
end
local function query(fn, ...)
    if type(fn) ~= "function" then return "unavailable" end
    local ok, value = pcall(fn, ...)
    return ok and safe(value) or "unavailable"
end
local function stamp()
    return query(date, "%Y-%m-%d %H:%M:%S")
end
local function clean(value)
    local s = safe(value):sub(1, 6000)
    -- Never export local-variable dumps, hyperlinks or quoted payloads.
    s = s:match("^(.-)\nLocals:") or s
    s = s:gsub("|H.-|h.-|h", "<link>"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub('"[^"\n]*"', '"<redacted>"'):gsub("'[^'\n]*'", "'<redacted>'")
    return s:sub(1, 2000)
end
function M:IssueEnvironment()
    local version, build, _, interface
    if GetBuildInfo then
        local ok
        ok, version, build, _, interface = pcall(GetBuildInfo)
        if not ok then version, build, interface = nil, nil, nil end
    end
    return "Mailwright " .. safe(self.version) .. " | game " .. safe(version) .. " | build " .. safe(build)
        .. " | interface " .. safe(interface) .. " | client " .. query(self.Client, self)
        .. " | locale " .. query(GetLocale)
end
function M:RecordIssue(kind, source, detail)
    if not self.db then return end
    local entries = self.db.issues
    if type(entries) ~= "table" then entries = {}; self.db.issues = entries end
    kind, source, detail = clean(kind), clean(source), clean(detail)
    local env = self:IssueEnvironment()
    local combat = query(InCombatLockdown)
    for i = #entries, 1, -1 do
        local e = entries[i]
        if e.kind == kind and e.source == source and e.detail == detail and e.environment == env and e.combat == combat then
            e.count = math.min((tonumber(e.count) or 1) + 1, 999999)
            e.last = stamp()
            table.remove(entries, i); entries[#entries + 1] = e
            return
        end
    end
    entries[#entries + 1] = {kind=kind, source=source, detail=detail, environment=env,
        combat=combat, first=stamp(), last=stamp(), count=1}
    while #entries > LIMIT do table.remove(entries, 1) end
end
function M:LogIssue(kind, source, detail)
    -- Diagnostics must never interrupt mail operations or recurse into errors.
    if self.loggingIssue then return end
    self.loggingIssue = true
    pcall(self.RecordIssue, self, kind, source, detail)
    self.loggingIssue = nil
end
function M:IssueMailContext()
    return self.mailOpen or (self.lastMailTransition and GetTime and GetTime() - self.lastMailTransition < 3)
end
function M:CaptureIssueError(message, stack)
    local raw, trace = safe(message), safe(stack)
    -- Ignore the logger's own stack frames when deciding whether this is ours.
    local relevant = raw:find("Mailwright", 1, true)
    for line in trace:gmatch("[^\n]+") do
        if line:find("Mailwright", 1, true) and not line:find("Issues.lua", 1, true) then relevant = true end
    end
    local context = self:IssueMailContext() and (raw .. trace):lower():match("controller")
        or self:IssueMailContext() and (raw .. trace):lower():match("gamepad")
        or self:IssueMailContext() and (raw .. trace):find("FrameControls", 1, true)
    if not relevant and not context then return end
    local lines = {clean(raw)}
    for line in trace:gmatch("[^\n]+") do
        -- Retain file/line locations only, not locals or function arguments.
        local location = line:match("([%w_/%-%.]+%.lua:%d+)")
        if location and not location:find("Issues.lua", 1, true) then lines[#lines + 1] = location end
        if #lines >= 12 then break end
    end
    self:LogIssue("error", relevant and "Mailwright-related Lua error" or "Controller error near mailbox (cause unknown)", table.concat(lines, "\n"))
end
function M:InstallIssueCapture()
    if self.issueErrorHandler or type(geterrorhandler) ~= "function" or type(seterrorhandler) ~= "function" then return end
    local previous = geterrorhandler()
    if type(previous) ~= "function" then return end
    self.issueErrorHandler = function(message)
        if not M.capturingIssue then
            M.capturingIssue = true
            pcall(function() M:CaptureIssueError(message, query(debugstack, 2, 12, 0)) end)
            M.capturingIssue = nil
        end
        return previous(message)
    end
    seterrorhandler(self.issueErrorHandler)
end
local function blocked(self, addon, fn)
    addon = safe(addon)
    if addon == "Mailwright" then
        self:LogIssue("blocked", "Game attributed action to Mailwright", fn)
    elseif addon == "UNKNOWN" and self:IssueMailContext() then
        self:LogIssue("blocked", "Unattributed action near mailbox (cause unknown)", fn)
    end
end
M:Listen("ADDON_ACTION_BLOCKED", blocked)
M:Listen("ADDON_ACTION_FORBIDDEN", blocked)
local warnings = {
    ["Attachment was not accepted. Check the draft before trying again."] = true,
    ["Inventory changed. Review the draft before attaching again."] = true,
    ["Forward draft created; attach the collected items manually because inventory identification was ambiguous."] = true,
    ["Forward draft created, but the collected items are not ready in your bags. Attach them manually."] = true,
    ["Existing inventory moved during forwarding. Attach the collected items manually."] = true,
    ["Inbox changed unexpectedly; stopped safely."] = true,
    ["Server did not confirm the mail operation. Check your inbox and try again."] = true,
    ["Inbox changed before the next operation. Select the mail again."] = true,
    ["Attachment details are not ready. Try again in a moment."] = true,
    ["The server rejected the mail operation. Check the game's error message."] = true,
}
function M:RecordOperationalIssue(message)
    if issecretvalue and issecretvalue(message) then return end
    if type(message) == "string" and warnings[message] then self:LogIssue("warning", "Mail operation", message) end
end
function M:IssueReport(checks)
    local out = {"== " .. self:IssueEnvironment(), "Generated: " .. stamp(),
        "GamePadEnable: " .. query(GetCVar, "GamePadEnable") .. " | Controller UI: " .. query(InputUtil and InputUtil.IsGamepadUIEnabled),
        "Controller settings may be unavailable on this client; gamepad enabled does not prove Controller UI is active.",
        "Mailbox open: " .. tostring(not not self.mailOpen) .. " | combat: " .. query(InCombatLockdown),
        "Errors observed near mailbox use are not proof of the cause. No contact list or mail content is collected.", ""}
    if checks then
        local function check(ok, name) out[#out+1] = (ok and "[PASS] " or "[FAIL] ") .. name end
        check(type(self.db) == "table", "saved data initialized")
        check(type(self.version) == "string" and self.version ~= "", "addon version set")
        check(type(SlashCmdList.MAILWRIGHT) == "function", "/mw command registered")
        check(type(GetInboxNumItems) == "function" and type(GetInboxHeaderInfo) == "function", "inbox read APIs present")
        check(type(GetSendMailItem) == "function" and type(SendMail) == "function", "send APIs present (permission not tested)")
        local old = self.db and self.db.issues
        local ok = false
        if self.db then
            self.db.issues = {}
            local worked = pcall(self.RecordIssue, self, "test", "self-check", "temporary entry")
            ok = worked and #self.db.issues == 1 and self.db.issues[1].detail == "temporary entry"
            self.db.issues = old
        end
        check(ok, "issue log write/read (temporary; history unchanged)")
        local active = self.issueErrorHandler and geterrorhandler and geterrorhandler() == self.issueErrorHandler
        out[#out+1] = active and "[PASS] Lua error capture installed" or "[INFO] Lua error capture unavailable or another handler is active; capture may be incomplete"
        out[#out+1] = self.mailOpen and (self.ui and "[PASS] mailbox controls created" or "[FAIL] mailbox controls not created") or "[INFO] mailbox closed; layout not tested"
        out[#out+1] = "Checks do not send, collect or delete mail, and do not prove in-game compatibility."
        out[#out+1] = ""
    end
    local entries = self.db and self.db.issues or {}
    out[#out+1] = "== Saved issues: " .. #entries .. " (newest first; limit " .. LIMIT .. ")"
    if #entries == 0 then out[#out+1] = "No issues recorded. This does not prove there were no errors." end
    for i = #entries, 1, -1 do
        local e = entries[i]
        out[#out+1] = safe(e.last) .. " x" .. safe(e.count) .. " [" .. safe(e.kind) .. "] " .. safe(e.source)
        out[#out+1] = "First: " .. safe(e.first) .. " | combat: " .. safe(e.combat)
        out[#out+1] = safe(e.environment)
        out[#out+1] = safe(e.detail)
        out[#out+1] = ""
    end
    return table.concat(out, "\n")
end
