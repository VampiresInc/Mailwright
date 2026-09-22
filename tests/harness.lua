-- Minimal independent WoW API model for testing Mailwright.
frames, messages, calls, clock = {}, {}, {}, 0
local methods = {}
local function noop() end
for _, name in ipairs({"SetPoint", "ClearAllPoints", "SetFrameStrata", "SetClampedToScreen", "SetBackdrop", "SetBackdropColor",
    "EnableMouse", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetJustifyH", "SetTextColor",
    "SetHighlightTexture", "EnableMouseWheel", "SetMultiLine", "SetFontObject", "SetAutoFocus", "SetMaxLetters",
    "SetTextInsets", "SetScrollChild", "HighlightText", "Raise", "SetOwner", "AddLine",
    "SetNormalFontObject", "SetHighlightFontObject", "SetDisabledFontObject", "SetNormalTexture",
    "SetPushedTexture", "SetFrameLevel", "RegisterForClicks", "SetColorTexture"}) do methods[name] = noop end
function methods:GetFrameLevel() return 1 end
function methods:GetPoint() return "TOPLEFT",self.parent,"TOPLEFT",20,-70 end
function methods:GetStringWidth() return #(self.text or "") * 5 end
function methods:RegisterEvent(e) self.events[e] = true end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:HookScript(name, fn)
    local old = self.scripts[name]
    self.scripts[name] = function(...) if old then old(...) end; fn(...) end
end
function methods:GetScript(name) return self.scripts[name] end
function methods:SetSize(w,h) self.width,self.height = w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width or 100 end
function methods:GetHeight() return self.height or 100 end
function methods:SetText(s) self.text=tostring(s); if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
function methods:GetText() return self.text or "" end
function methods:Show() self.shown=true end
function methods:Hide() local was=self.shown; self.shown=false; if was~=false and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(b) self.shown=b end
function methods:IsShown() return self.shown~=false end
function methods:SetChecked(b) self.checked=b end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(b) self.enabled=b end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetFocus() self.focus=true end
function methods:ClearFocus() self.focus=false end
function methods:SetVerticalScroll(n) self.scroll=n end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:GetParent() return self.parent end
function methods:GetID() return self.id end
function methods:CreateFontString() return CreateFrame("FontString",nil,self) end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function CreateFrame(kind,name,parent,template)
    local f=setmetatable({kind=kind,name=name,parent=parent,template=template,scripts={},events={}}, {__index=methods})
    frames[#frames+1]=f; if name then _G[name]=f end; return f
end
UIParent=CreateFrame("Frame")
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) messages[#messages+1]=s end}
SlashCmdList,UISpecialFrames={},{}
BackdropTemplateMixin={}
WOW_PROJECT_ID,WOW_PROJECT_MAINLINE=1,1
Enum={PlayerInteractionType={MailInfo=17}}
ATTACHMENTS_MAX_RECEIVE,ATTACHMENTS_MAX_SEND,NUM_BAG_SLOTS=16,12,4
ERR_INV_FULL,ERR_ITEM_MAX_COUNT,ERR_MAIL_DATABASE_ERROR="Inventory full","Maximum count","Mail error"
playerName,realm,playerGuid="Example Surname","Classic Beta PvE 2","Player-test-1"
function GetBuildInfo() return "1.60.1","69913","date",16001 end
function GetRealmName() return realm end
function UnitName() return playerName end
function UnitClass() return "Hunter","HUNTER" end
function UnitFactionGroup() return "Alliance" end
function UnitLevel() return 12 end
function UnitGUID() return playerGuid end
function GetTime() return clock end
function IsAltKeyDown() return alt or false end
function IsShiftKeyDown() return shift or false end
function IsControlKeyDown() return ctrl or false end
trade="0"
function GetCVar() return trade end
function SetCVar(_,v) trade=v end
function hooksecurefunc(name,fn)
    assert(type(_G[name])=="function", "Missing hook: "..name)
    local old=_G[name]; _G[name]=function(...) old(...); fn(...) end
end
function HandleModifiedItemClick() end
inbox,total={},nil
function GetInboxNumItems() return #inbox,total or #inbox end
function GetInboxHeaderInfo(i)
    local h=inbox[i]; if not h then return end
    return 1,1,h.sender or "Sender Surname",h.subject or "Subject",h.money or 0,h.cod or 0,h.days or 30,
        #(h.items or {}),false,h.returned,false,h.reply~=false,h.gm
end
function GetInboxItem(i,s)
    local item=inbox[i] and (inbox[i].items or {})[s]
    if item then return item.name or "Item",item.id or 123,1,item.count or 1,1 end
end
function GetInboxItemLink(i,s) local item=inbox[i] and (inbox[i].items or {})[s]; return item and (item.link or "item:123") end
function GetInboxText(i) return inbox[i] and inbox[i].body or "Message body" end
function GetInboxInvoiceInfo(i) return inbox[i] and inbox[i].invoice end
function InboxItemCanDelete(i) return inbox[i] and inbox[i].reply==false end
function TakeInboxMoney(i) calls[#calls+1]={"money",i} end
function TakeInboxItem(i,s) calls[#calls+1]={"item",i,s} end
function ReturnInboxItem(i) calls[#calls+1]={"return",i} end
function DeleteInboxItem(i) calls[#calls+1]={"delete",i} end
function CheckInbox() calls[#calls+1]={"refresh"} end
pending=false
C_Mail={IsCommandPending=function() return pending end,CanCheckInbox=function() return true,0 end}
bags,free={},8
C_Container={
    GetContainerNumSlots=function(bag) return bag==0 and 16 or 0 end,
    GetContainerNumFreeSlots=function(bag) return bag==0 and free or 0,0 end,
    GetContainerItemInfo=function(bag,slot) return bags[bag..":"..slot] end,
    UseContainerItem=function(bag,slot) calls[#calls+1]={"attach",bag,slot} end
}
itemDetails={}
function GetItemInfo(link)
    local i=itemDetails[link]; if not i then return end
    return "Item",link,i.quality or 1,1,1,"Type","Subtype",i.stack or 1,"",1,1,i.class or 7,1,i.bind or 0
end
sendItems,sendMoney={},0
function GetSendMailItem(i) return sendItems[i] end
function GetSendMailMoney() return sendMoney end
function SendMail(to,subject,body) calls[#calls+1]={"send",to,subject,body} end
function MailFrameTab_OnClick(_,i) SendMailFrame.sendMode="send" end
MailFrame=CreateFrame("Frame"); MailFrame:Hide()
InboxFrame=CreateFrame("Frame",nil,MailFrame); InboxFrame.pageNum=1
OpenMailFrame=CreateFrame("Frame",nil,MailFrame)
for i=1,7 do
 local row=CreateFrame("Frame","MailItem"..i,InboxFrame)
 row.Button=CreateFrame("CheckButton","MailItem"..i.."Button",row)
 row.Button.index=i
 row.Button:SetScript("OnClick",function(self) calls[#calls+1]={"native",self.index}; InboxFrame.openMailID=self.index end)
 CreateFrame("Button","MailItem"..i.."ExpireTime",row)
end
SendMailFrame=CreateFrame("Frame"); SendMailFrame.sendMode="send"
SendMailNameEditBox=CreateFrame("EditBox")
SendMailSubjectEditBox=CreateFrame("EditBox")
SendMailBodyEditBox=CreateFrame("EditBox")
GameTooltip=CreateFrame("Frame")
function GetNumGuildMembers() return 0 end
function tick(seconds)
    clock=clock+(seconds or 1)
    Mailwright:TickQueue(); Mailwright:TickAttachments()
end
function resetMail()
    Mailwright.queue,Mailwright.attachQueue=nil,nil
    Mailwright.mailOpen,Mailwright.conflict=true,false
    Mailwright.selection={}; Mailwright.db.options.reserve=1
    Mailwright.db.options.items,Mailwright.db.options.money,Mailwright.db.options.auctions=true,true,true
    calls,inbox,bags,sendItems={}, {}, {}, {}
    pending,total,free,sendMoney=false,nil,8,0
end
