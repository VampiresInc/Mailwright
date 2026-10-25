"""Lua 5.1 regression tests using mocked WoW APIs; never modifies the game installation."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools'))
from lupa.lua51 import LuaRuntime

def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    compile_fn = lua.eval('function(code,name) local fn,err=loadstring(code,name); assert(fn,err); return fn end')
    lua.execute((ROOT / 'tests/harness.lua').read_text(encoding='utf-8'))
    ns = lua.table()
    for filename in ['Core.lua','Locales.lua','API.lua','Contacts.lua','Mailbox.lua','Sending.lua','UI.lua','MailboxUI.lua']:
        compile_fn((ROOT / filename).read_text(encoding='utf-8'), '@'+filename)('Mailwright', ns)
    return lua, compile_fn

lua, compile_fn = runtime()
for path in ROOT.rglob('*.lua'):
    compile_fn(path.read_text(encoding='utf-8-sig'), '@'+str(path))
print('PASS Lua 5.1 syntax')
for path in ROOT.glob('*.toc'):
    lines = path.read_text(encoding='utf-8-sig').splitlines()
    entries = [s.strip() for s in lines if s.strip() and not s.startswith('#')]
    assert all((ROOT / s).is_file() for s in entries)
    assert entries.index('Core.lua') < entries.index('Contacts.lua') < entries.index('UI.lua')
    assert ('FlavorForever.lua' in entries) == ('Camelot' in path.name)
    assert '## SavedVariables: MailwrightDB' in lines
print('PASS manifests and load order')

def check(name, code):
    lua.execute(code)
    print('PASS', name)

check('database initializes at own ADDON_LOADED and preserves loaded records', r'''
assert(MailwrightDB==nil and Mailwright.db==nil)
Mailwright:Emit('ADDON_LOADED','OtherAddon'); assert(MailwrightDB==nil)
MailwrightDB={contacts={saved={name='Saved Person',client='Forever'}},sessions=4,options={reserve=2}}
local original=MailwrightDB
Mailwright:Emit('ADDON_LOADED','Mailwright')
assert(Mailwright.db==original and Mailwright.loadedData and Mailwright.db.sessions==5)
assert(Mailwright.db.contacts.saved.name=='Saved Person' and Mailwright.db.options.reserve==2)
Mailwright:Emit('ADDON_LOADED','Mailwright'); assert(Mailwright.db.sessions==5)
''')
check('Forever names, distinct surnames, blanks and rulesets', r'''
local m=Mailwright
assert(not m:AddContact('')); assert(messages[#messages]:find('To field'))
assert(not m:AddContact('Single'))
assert(m:AddContact('Example One') and m:AddContact('Example Two'))
assert(m.db.contacts[m:ContactKey('Example One')] and m.db.contacts[m:ContactKey('Example Two')])
assert(m:Ruleset('Classic Beta PvP 2')=='PvP' and m:Ruleset('Classic Beta PvE 2')=='Normal')
assert(m:Ruleset('Mystery Realm')=='Mystery Realm')
realm,playerName,playerGuid='Classic Beta PvP 2','Other Person','Player-test-2'; m:RecordPlayer()
realm,playerName,playerGuid='Classic Beta PvE 2','Example Surname','Player-test-1'; m:RecordPlayer()
assert(not m:CanRecipient('Other Person')); assert(m:CanRecipient('Unknown Person'))
local all=m:Recipients('All alts'); assert(#all==1 and not all[1].ok)
assert(#m:Recipients('Alts')==0)
''')
check('backup round-trip, metadata, duplicates, validation and format version', r'''
local m=Mailwright
m:AddContact('Other Person')
local export=m:ExportContacts(); m.db.contacts={}
local ok,text=m:ImportContacts(export); assert(ok)
assert(m.db.contacts[m:ContactKey('Other Person')].ruleset=='PvP')
assert(not m:CanRecipient('Other Person'))
local ok,summary=m:ImportContacts(export); assert(ok and summary:find('Imported 0'))
local ok,summary=m:ImportContacts('New Person\nSingle\nBad|Name'); assert(ok and summary:find('skipped 2'))
assert(not m:ImportContacts('MAILWRIGHT-CONTACTS\t99'))
assert(not m:ImportContacts(string.rep('a',200001)))
''')
check('UI without removed globals, modern event payload, and trade restoration', r'''
local m=Mailwright
assert(InboxFrame_Update==nil and OpenMail_Update==nil)
m.mailOpen=false; m:Emit('PLAYER_INTERACTION_MANAGER_FRAME_SHOW',99); assert(not m.mailOpen)
m:Emit('PLAYER_INTERACTION_MANAGER_FRAME_SHOW',17); assert(m.mailOpen and m.ui:IsShown() and trade=='1')
m:ShowContactMenu(); assert(m.menu:IsShown())
m:TextWindow('Export',m:ExportContacts(),false); assert(m.textWindow.edit:GetText():find('MAILWRIGHT'))
m:TextWindow('Import','New Friend',true); m.textWindow.apply.scripts.OnClick(); assert(m.textWindow.prepared)
m.textWindow.apply.scripts.OnClick(); assert(m.db.contacts[m:ContactKey('New Friend')])
m:Emit('PLAYER_INTERACTION_MANAGER_FRAME_HIDE',17); assert(not m.mailOpen and trade=='0')
trade='1'; m:Emit('MAIL_SHOW'); m:Emit('MAIL_CLOSED'); assert(trade=='1'); trade='0'
''')
check('queue waits for ACK, collects money then attachment, preserves letter', r'''
resetMail(); inbox={{money=12345,items={{link='item:1'}}}}
assert(Mailwright:StartQueue('all')); tick(); assert(#calls==1 and calls[1][1]=='money')
tick(); assert(#calls==1)
inbox[1].money=0; tick(); tick(); assert(#calls==2 and calls[2][1]=='item')
inbox[1].items={}; tick(); tick(); tick(); assert(not Mailwright.queue)
assert(#calls==2 and #inbox==1 and Mailwright.collected==12345)
''')
check('COD/GM excluded, reserve stops, unrelated errors do not cancel', r'''
resetMail(); inbox={{cod=10,items={{}}},{gm=true,money=100},{items={{}}}}; free=1
assert(Mailwright:StartQueue('all')); tick(); assert(not Mailwright.queue and #calls==0)
free=8; assert(Mailwright:StartQueue('all')); Mailwright:Emit('UI_ERROR_MESSAGE',42,'Other error'); assert(Mailwright.queue)
Mailwright:Emit('UI_ERROR_MESSAGE',1,ERR_INV_FULL); assert(not Mailwright.queue)
''')
check('descending selection and external inbox changes', r'''
resetMail(); inbox={{money=1},{money=2},{money=3}}
local sig=Mailwright:Header(2).signature
assert(Mailwright:StartQueue('selected',{[2]=sig})); tick(); assert(calls[1][2]==2)
inbox[2].money=0; tick(); tick(); tick(); assert(not Mailwright.queue and #calls==1)
resetMail(); inbox={{money=1},{money=2}}; assert(Mailwright:StartQueue('selected',{[2]=true}))
inbox[2].subject='New message'; tick(); assert(not Mailwright.queue and #calls==0)
''')
check('Open All follows live inbox changes without another click', r'''
resetMail(); inbox={{subject='First',items={{link='item:1'}}},{subject='Second',items={{link='item:2'}}}}
assert(Mailwright:StartQueue('all'))
-- Cached attachment information resolves after the initial queue snapshot.
inbox[2].items[1].link='item:2:resolved'
tick(); assert(#calls==1 and calls[1][2]==2)
-- The looted message disappears; the remaining row and its item cache change.
table.remove(inbox,2); tick()
inbox[1].items[1].link='item:1:resolved'
table.insert(inbox,1,{subject='New COD',cod=100,items={{}}})
tick(); assert(#calls==2 and calls[2][2]==2)
table.remove(inbox,2); tick(); tick()
assert(not Mailwright.queue and #calls==2 and inbox[1].cod==100)
-- A full/reserved bag stops the continuing run before another attachment.
resetMail(); inbox={{items={{}}},{items={{}}}}; free=8
assert(Mailwright:StartQueue('all')); tick(); table.remove(inbox,2); tick()
free=Mailwright.db.options.reserve; tick()
assert(not Mailwright.queue and #calls==1)
''')
check('return identical messages, timeout, and cancellation', r'''
resetMail(); inbox={{money=1},{money=1}}; assert(Mailwright:StartQueue('return',{[1]=true}))
tick(); assert(calls[1][1]=='return'); table.remove(inbox,1); tick(); tick(); assert(not Mailwright.queue and #calls==1)
resetMail(); inbox={{money=1}}; assert(Mailwright:StartQueue('all')); tick(); tick(13); assert(not Mailwright.queue and #calls==1)
resetMail(); inbox={{money=1}}; assert(Mailwright:StartQueue('all')); Mailwright:StopQueue(); tick(); assert(#calls==0)
''')
check('auction filter and next server page', r'''
resetMail(); inbox={{money=1,invoice='seller'},{money=2}}; Mailwright.db.options.auctions=false
assert(Mailwright:StartQueue('all')); assert(#Mailwright.queue.tasks==1 and Mailwright.queue.tasks[1].index==2)
resetMail(); inbox={{money=1}}; total=2; assert(Mailwright:StartQueue('all')); tick()
inbox={}; total=1; tick(); tick(); assert(calls[#calls][1]=='refresh')
inbox={{money=2}}; tick(3); tick(); assert(calls[#calls][1]=='money')
inbox={}; total=0; tick(); tick(); assert(not Mailwright.queue)
''')
check('attachment ACK, inventory mutation, opt-in auto-send, successful recent', r'''
resetMail(); itemDetails['item:1']={class=7,stack=20}
bags['0:1']={hyperlink='item:1',itemID=1,stackCount=3,isBound=false,quality=1}
local m=Mailwright; m.db.options.bag=-1; m.db.options.quality=0
SendMailNameEditBox:SetText('New Friend'); SendMailSubjectEditBox:SetText('Supplies')
assert(m:StartAttach({m:BagItem(0,1)},false)); tick(); tick(); assert(#calls==1 and calls[1][1]=='attach')
sendItems[1]='Item'; tick(); tick(); assert(not m.attachQueue and #calls==1)
sendItems={}; assert(m:StartAttach({m:BagItem(0,1)},true)); tick(); sendItems[1]='Item'; tick(); tick()
assert(calls[#calls][1]=='send')
m:Emit('MAIL_SEND_SUCCESS'); assert(m.db.recent[1].name=='New Friend')
sendItems={}; assert(m:StartAttach({m:BagItem(0,1)},false)); bags['0:1'].hyperlink='item:2'; tick(); assert(not m.attachQueue)
''')
check('auto-send excludes COD/money and enforces ruleset', r'''
resetMail(); local m=Mailwright
SendMailNameEditBox:SetText('New Friend'); SendMailSubjectEditBox:SetText('Supplies')
sendMoney=100; m:SendDraft(); assert(#calls==0); sendMoney=0
SendMailFrame.sendMode='cod'; m:SendDraft(); assert(#calls==0); SendMailFrame.sendMode='send'
SendMailNameEditBox:SetText('Other Person'); m:SendDraft(); assert(#calls==0)
''')
check('copy, confirmed empty deletion, text forward and stacked-item rejection', r'''
resetMail(); inbox={{subject='Letter',body='Hello',items={}}}; local m=Mailwright
m:CopyMail(1); assert(m.textWindow.edit:GetText():find('Hello'))
m:ConfirmDelete(m:Header(1)); assert(#calls==0); m.deleteWindow.target.signature='changed'
for _, f in ipairs(frames) do if f.parent==m.deleteWindow and f.text=='Delete' then f.scripts.OnClick() end end
assert(#calls==0)
m:ConfirmDelete(m:Header(1))
for _, f in ipairs(frames) do if f.parent==m.deleteWindow and f.text=='Delete' then f.scripts.OnClick() end end
assert(calls[1][1]=='delete')
SendMailSubjectEditBox:SetText(''); SendMailBodyEditBox:SetText(''); m:ForwardMail(1)
assert(SendMailSubjectEditBox:GetText()=='Fwd: Letter' and SendMailBodyEditBox:GetText():find('Hello'))
SendMailSubjectEditBox:SetText(''); SendMailBodyEditBox:SetText(''); inbox[1].items={{link='item:1'}}
itemDetails['item:1']={stack=20}; m:ForwardMail(1); assert(not m.queue)
''')
check('Retail names and legacy bag API fallback', r'''
local m=Mailwright; m.forever=false
assert(m:ValidName('Character-Realm')); assert(not m:ValidName('First Last'))
C_Container=nil
function GetContainerNumSlots() return 1 end
function GetContainerItemInfo() return 1,2,false,1,false,false,'item:1' end
function GetContainerNumFreeSlots() return 2,0 end
function UseContainerItem(b,s) calls[#calls+1]={'legacy',b,s} end
assert(m:BagItem(0,1).count==2 and m:FreeSlots()==10)
m:UseBagItem(0,1); assert(calls[#calls][1]=='legacy')
''')

check('forward unique attachment into a draft without sending', r'''
local m=Mailwright; m.forever=true
resetMail()
C_Container={
 GetContainerNumSlots=function(b) return b==0 and 16 or 0 end,
 GetContainerNumFreeSlots=function(b) return b==0 and free or 0,0 end,
 GetContainerItemInfo=function(b,s) return bags[b..":"..s] end,
 UseContainerItem=function(b,s) calls[#calls+1]={'attach',b,s} end
}
SendMailSubjectEditBox:SetText(''); SendMailBodyEditBox:SetText('')
inbox={{subject='Gift',body='For you',items={{link='item:77'}}}}
itemDetails['item:77']={stack=1,class=2,bind=0}
m:ForwardMail(1); assert(m.queue and #calls==0)
tick(); assert(calls[1][1]=='item')
inbox[1].items={}; bags['0:3']={hyperlink='item:77',itemID=77,stackCount=1,isBound=false}
tick(); tick(); tick()
assert(m.attachQueue and calls[#calls][1]=='attach')
sendItems[1]='Gift item'; tick(); tick()
assert(not m.queue and not m.attachQueue and #calls==2)
assert(SendMailSubjectEditBox:GetText()=='Fwd: Gift')
''')
check('Retail auction forwarding survives delayed removal of emptied mail', r'''
local m=Mailwright; m.forever=false
resetMail()
SendMailSubjectEditBox:SetText(''); SendMailBodyEditBox:SetText('')
inbox={{sender='Auction House',subject='Auction won: Design',body='Recipe purchase',invoice='buyer',items={{link='item:77'}}}}
itemDetails['item:77']={stack=1,class=9,bind=0}
m:ForwardMail(1); tick()
assert(calls[1][1]=='item')
inbox[1].items={}
bags['0:3']={hyperlink='item:77',itemID=77,stackCount=1,isBound=false}
tick() -- The item disappears before the auction letter is removed.
inbox={{sender='Other',subject='Unrelated mail',items={{link='item:88'}}}}
tick(); tick()
assert(SendMailSubjectEditBox:GetText()=='Fwd: Auction won: Design')
assert(m.attachQueue and calls[#calls][1]=='attach')
sendItems[1]='Design: Polished Ammolite'; tick(); tick()
assert(not m.queue and not m.attachQueue and #calls==2)
assert(#inbox[1].items==1) -- Never collect the replacement row.
''')
check('forward waits for unlocked bag data and tolerates changed link context', r'''
local m=Mailwright
resetMail(); SendMailSubjectEditBox:SetText(''); SendMailBodyEditBox:SetText('')
inbox={{subject='Delayed recipe',items={{link='item:77'}}}}
m:ForwardMail(1); tick(); inbox[1].items={}; tick(); tick()
assert(m.forwardPlan and not m.attachQueue and #calls==1)
assert(not m:StartQueue('all'))
bags['0:3']={hyperlink='item:77:0:0:0:0:0:0:0:90',itemID=77,stackCount=1,isLocked=true,isBound=false}
tick(); assert(m.forwardPlan and #calls==1)
bags['0:3'].isLocked=false; tick()
assert(not m.forwardPlan and m.attachQueue and calls[2][1]=='attach')
sendItems[1]='Recipe'; tick(); tick(); assert(#calls==2)
-- Multiple new matches must never be selected arbitrarily.
resetMail(); SendMailSubjectEditBox:SetText(''); SendMailBodyEditBox:SetText('')
inbox={{subject='Duplicate',items={{link='item:77'}}}}
m:ForwardMail(1); tick(); inbox[1].items={}; tick(); tick()
bags['0:3']={hyperlink='item:77',itemID=77,stackCount=1,isBound=false}
bags['0:4']={hyperlink='item:77:90',itemID=77,stackCount=1,isBound=false}
tick(); assert(not m.forwardPlan and not m.attachQueue and #calls==1)
-- Missing bag data has a bounded wait and leaves the draft intact.
resetMail(); SendMailSubjectEditBox:SetText(''); SendMailBodyEditBox:SetText('')
inbox={{subject='Timeout',items={{link='item:77'}}}}
m:ForwardMail(1); tick(); inbox[1].items={}; tick(); tick()
assert(m.forwardPlan); clock=clock+7; tick()
assert(not m.forwardPlan and #calls==1 and SendMailSubjectEditBox:GetText()=='Fwd: Timeout')
''')
check('forward attaches only the new copy when an identical item is already owned', r'''
local m=Mailwright
resetMail(); SendMailSubjectEditBox:SetText(''); SendMailBodyEditBox:SetText('')
bags['0:2']={hyperlink='item:77',itemID=77,stackCount=1,isBound=false}
inbox={{subject='Another recipe',items={{link='item:77'}}}}
m:ForwardMail(1); assert(m.queue); tick(); inbox[1].items={}; tick(); tick()
assert(m.forwardPlan and #calls==1)
bags['0:5']={hyperlink='item:77:90',itemID=77,stackCount=1,isBound=false}
tick(); assert(calls[2][1]=='attach' and calls[2][2]==0 and calls[2][3]==5)
assert(bags['0:2'].hyperlink=='item:77')
sendItems[1]='Recipe'; tick(); tick(); assert(#calls==2)
-- Moving the old copy must not make it look newly collected.
resetMail(); SendMailSubjectEditBox:SetText(''); SendMailBodyEditBox:SetText('')
bags['0:2']={hyperlink='item:77',itemID=77,stackCount=1,isBound=false}
inbox={{subject='Moved recipe',items={{link='item:77'}}}}
m:ForwardMail(1); tick(); inbox[1].items={}; tick(); tick()
bags['0:5']=bags['0:2']; bags['0:2']=nil
tick(); assert(not m.forwardPlan and not m.attachQueue and #calls==1)
''')
check('forward supports nested mail editor and preserves existing drafts', r'''
local m=Mailwright
resetMail()
local legacy=SendMailBodyEditBox
SendMailBodyEditBox=nil
local editor=CreateFrame('EditBox')
MailEditBox={ScrollBox={EditBox=editor}}
SendMailSubjectEditBox:SetText(''); editor:SetText('Unsent letter')
inbox={{sender='Sender',subject='Letter',body='Original text'}}
m:ForwardMail(1)
assert(editor:GetText()=='Unsent letter' and SendMailSubjectEditBox:GetText()=='' and not m.queue)
editor:SetText(''); m:ForwardMail(1)
assert(editor:GetText()=='From: Sender\n\nOriginal text')
assert(SendMailSubjectEditBox:GetText()=='Fwd: Letter')
MailEditBox=nil; SendMailBodyEditBox=legacy
''')
check('reopening installs hooks once; failed sending does not populate recent', r'''
local m=Mailwright
resetMail(); m:InstallSendHooks()
local originalSend,originalClick=SendMail,HandleModifiedItemClick
m:InstallSendHooks(); assert(SendMail==originalSend and HandleModifiedItemClick==originalClick)
local count=#m.db.recent
SendMail('Failure Person','Test',''); m:Emit('MAIL_FAILED'); m:Emit('MAIL_SEND_SUCCESS')
assert(#m.db.recent==count)
''')
check('category filters and money subjects preserve user content', r'''
local m=Mailwright
itemDetails['item:7']={class=7,quality=2,bind=0}
local item={link='item:7',bag=0,slot=1,count=1,bound=false}
m.db.options.bag=-1; m.db.options.quality=0
assert(m:ItemEligible(item,'Trade goods')); assert(not m:ItemEligible(item,'Equipment'))
item.bound=true; assert(not m:ItemEligible(item,'All')); item.bound=false
m.db.options.quality=3; assert(not m:ItemEligible(item,'All')); m.db.options.quality=0
m.db.options.bag=2; assert(not m:ItemEligible(item,'All')); m.db.options.bag=-1
SendMailFrame.sendMode='send'; SendMailSubjectEditBox:SetText(''); sendMoney=12345
m:UpdateMoneySubject(); assert(SendMailSubjectEditBox:GetText()=='1g 23s 45c')
SendMailSubjectEditBox:SetText('My subject'); sendMoney=777; m:UpdateMoneySubject()
assert(SendMailSubjectEditBox:GetText()=='My subject')
''')

check('native UI: no companion window, correct page targets, original clicks and no duplicate hooks', r'''
local m=Mailwright
resetMail()
assert(MailwrightWindow==nil and m.ui.parent==MailFrame)
assert(m.toolbar.parent==InboxFrame and m.recipientButton.parent==SendMailFrame)
for i=1,14 do inbox[i]={subject='Message '..i,money=i} end
InboxFrame.pageNum=2
for i=1,7 do _G['MailItem'..i..'Button'].index=7+i end
m:RefreshUI()
local check=m.inboxChecks[1].check
check:SetChecked(true); check.scripts.OnClick(check)
assert(m.selection[8] and not m.selection[1])
local native=MailItem1Button
native.scripts.OnClick(native)
assert(calls[#calls][1]=='native' and calls[#calls][2]==8)
shift=true; native.scripts.OnClick(native); shift=false
assert(m.queue and #m.queue.tasks==1 and m.queue.tasks[1].index==8)
m:StopQueue(nil,true)
local original=native:GetScript('OnClick'); m:ShowUI(); m:RefreshUI()
assert(native:GetScript('OnClick')==original)
m:ShowContactMenu()
assert(m.menu.width<260)
local export,import
for i,row in ipairs(m.menu.rows) do
 if row.caption:GetText()=='Export contacts' then export=i end
 if row.caption:GetText()=='Import contacts' then import=i end
end
assert(export and import==export+1)
m:ShowOptionsMenu(); assert(m.menuGroup=='Options')
m:ShowAttachMenu(); assert(m.menuGroup=='Attach')
InboxFrame.openMailID=8
m:FocusedMail(function(h) assert(h.index==8) end)
InboxFrame.openMailID=nil
InboxFrame.pageNum=1
for i=1,7 do _G['MailItem'..i..'Button'].index=i end
''')

check('character and Battle.net friends, realm qualification and unsupported accounts', r'''
local m=Mailwright
local wasForever=m.forever; m.forever=false
local requests=0
C_FriendList={
 GetNumFriends=function() return 2 end,
 GetFriendInfoByIndex=function(i) return {name=i==1 and 'Ordinary' or 'Offlinefriend'} end,
 ShowFriends=function() requests=requests+1 end
}
local games={
 {clientProgram='WoW',isOnline=true,isInCurrentRegion=true,wowProjectID=1,characterName='Remote',realmName='Other Realm'},
 {clientProgram='WoW',isOnline=true,isInCurrentRegion=true,wowProjectID=1,characterName='Ordinary',realmName=realm},
 {clientProgram='WoW',isOnline=true,isInCurrentRegion=true,wowProjectID=2,characterName='ClassicOnly',realmName=realm},
 {clientProgram='D3',isOnline=true,wowProjectID=1,characterName='OtherGame',realmName=realm},
 {clientProgram='WoW',isOnline=false,wowProjectID=1,characterName='OfflineBnet',realmName=realm},
 {clientProgram='WoW',isOnline=true,isInCurrentRegion=false,wowProjectID=1,characterName='OtherRegion',realmName=realm},
 {clientProgram='WoW',isOnline=true,wowProjectID=1,realmName=realm}
}
BNGetNumFriends=function() return 1 end
C_BattleNet={GetFriendNumGameAccounts=function() return #games end,GetFriendGameAccountInfo=function(_,i) return games[i] end}
local friends=m:Recipients('Friends')
assert(#friends==3)
local names={}; for _,r in ipairs(friends) do names[r.name]=true end
assert(names.Ordinary and names.Offlinefriend and names['Remote-OtherRealm'])
m.lastFriendRequest=nil; m:RequestFriends(); m:RequestFriends(); assert(requests==1)
m:ShowContactMenu('Friends'); assert(m.menu:IsShown())
Mailwright:Emit('FRIENDLIST_UPDATE'); assert(m.menuGroup=='Friends')
C_FriendList=nil; C_BattleNet=nil; BNGetNumFriends=nil
GetNumFriends=function() return 1 end; GetFriendInfo=function() return 'Legacyfriend' end
assert(m:Recipients('Friends')[1].name=='Legacyfriend')
GetNumFriends=nil; GetFriendInfo=nil; m.forever=wasForever
''')
check('bottom options dropdown retains its clicked anchor and stays open', r'''
local m=Mailwright
m.openAllOptions:GetScript('OnClick')(m.openAllOptions)
assert(m.menu.anchor==m.openAllOptions and m.menu:IsShown())
MouseIsOver=function(frame) return frame==m.openAllOptions end
m:MenuMouseWatch(1); assert(m.menu:IsShown())
for _,row in ipairs(m.menu.rows) do
 if row.caption:GetText():find('Collect attachments',1,true) then row.action(); break end
end
assert(m.menu.anchor==m.openAllOptions)
m:MenuMouseWatch(1); assert(m.menu:IsShown())
m.settingsButton:GetScript('OnClick')(m.settingsButton)
assert(m.menu.anchor==m.settingsButton)
MouseIsOver=nil
''')
check('hover parts, class and rank labels, recipient identity, and dismissing the menu tree', r'''
local m=Mailwright
RAID_CLASS_COLORS={MAGE={r=0.25,g=0.75,b=1}}
LOCALIZED_CLASS_NAMES_MALE={MAGE='Mage'}
GetNumGuildMembers=function() return 55 end
GetGuildRosterInfo=function(i) return 'Guildmember'..string.char(64+math.floor((i-1)/26)+1)..string.char(65+(i-1)%26)..'-Realm', 'Officer',1,80,'Mage',nil,nil,nil,true,nil,'MAGE' end
local r=m:Recipients('Guild')[1]
assert(r.level==80 and r.class=='MAGE' and r.rank=='Officer')
local text=m:RecipientLabel(r,'Guild')
assert(text:find('80 Mage',1,true) and text:find('Officer',1,true) and text:find('|cff40bfff',1,true))
local function rowNamed(frame,text)
 for _,row in ipairs(frame.rows) do if row:IsShown() and row.caption:GetText()==text then return row end end
end
m:ShowContactMenu()
local root=m.menu
local guild=rowNamed(root,'Guild >'); assert(guild and guild.hover)
guild.scripts.OnEnter(guild)
local parts=m.menuPanels[2]; assert(root:IsShown() and parts:IsShown())
assert(rowNamed(parts,'Part 1 >') and rowNamed(parts,'Part 3 >'))
assert(not rowNamed(parts,'Next >') and not parts.scripts.OnMouseWheel)
local part=rowNamed(parts,'Part 1 >'); part.scripts.OnEnter(part)
local names=m.menuPanels[3]; assert(names:IsShown() and parts:IsShown() and root:IsShown())
local expected=m:Recipients('Guild')[1].name
local original=m.SetRecipient
m.SetRecipient=function(_,name) assert(name==expected); return true end
names.rows[1].scripts.OnClick(names.rows[1]); m.SetRecipient=original
assert(not root:IsShown() and not parts:IsShown() and not names:IsShown())
m:ShowContactMenu(); guild=rowNamed(root,'Guild >'); guild.scripts.OnEnter(guild)
MouseIsOver=function(frame) return frame==m.menuPanels[2] end
m:MenuMouseWatch(1); assert(root:IsShown())
MouseIsOver=function() return false end
m:MenuMouseWatch(0.2); assert(root:IsShown())
m:MenuMouseWatch(0.3); assert(not root:IsShown() and not m.menuPanels[2]:IsShown())
MouseIsOver=nil; GetNumGuildMembers=function() return 0 end; GetGuildRosterInfo=nil
''')

fresh, _ = runtime()
fresh.execute('Mailwright:Emit("ADDON_LOADED","Mailwright"); assert(not Mailwright.loadedData and Mailwright.db.sessions==1); Mailwright:AddContact("Persist Person")')
backup = fresh.globals().Mailwright.ExportContacts(fresh.globals().Mailwright)
reloaded, _ = runtime()
reloaded.execute(r'''
MailwrightDB={sessions=1,contacts={ ["Forever\031persist person"]={name="Persist Person",client="Forever"} }}
Mailwright:Emit("ADDON_LOADED","Mailwright")
assert(Mailwright.loadedData and Mailwright.db.sessions==2)
assert(Mailwright.db.contacts[Mailwright:ContactKey("Persist Person")])
''')
assert 'Persist Person' in backup
print('PASS simulated saved-variable reload in a fresh VM')
for client, interface, project in [('Retail',120105,1),('Classic',50504,19),('Era',11508,2)]:
    test, _ = runtime()
    test.execute(f'function GetBuildInfo() return "{client}","build","date",{interface} end; WOW_PROJECT_ID={project}; playerName="Tester"; Mailwright:Emit("ADDON_LOADED","Mailwright"); assert(not Mailwright.forever); Mailwright:Emit("MAIL_SHOW"); assert(Mailwright.ui:IsShown()); assert(Mailwright:AddContact("Recipient")); Mailwright:Emit("MAIL_CLOSED")')
    print(f'PASS {client} initialization and UI smoke test')
split, _ = runtime()
split.execute(r'''
function UnitName() return playerName, surname end
playerName, surname = 'Selle', nil
Mailwright:Emit('ADDON_LOADED','Mailwright')
assert(next(Mailwright.db.alts)==nil)
surname = 'Quickgale'
Mailwright:Emit('PLAYER_ENTERING_WORLD')
assert(Mailwright.player.name=='Selle Quickgale')
playerName, surname, playerGuid = 'Other', 'Person', 'Player-test-2'
Mailwright:Emit('PLAYER_LOGIN')
assert(Mailwright.player.name=='Other Person')
local alts=Mailwright:Recipients('Alts')
assert(#alts==1 and alts[1].name=='Selle Quickgale')
assert(#Mailwright:Recipients('All alts')==1)
playerName='Other Person'
Mailwright:RecordPlayer()
assert(Mailwright.player.name=='Other Person')
''')
print('PASS fresh Forever split surnames, delayed identity and alt menus')
for interface in [120105, 11509, 50504, 20506]:
    ordinary, _ = runtime()
    ordinary.execute(f'GetBuildInfo=function() return "client","build","date",{interface} end')
    ordinary.execute('UnitName=function() return "Tester", "OtherRealm" end; Mailwright:Emit("ADDON_LOADED","Mailwright"); assert(Mailwright.player.name=="Tester")')
print('PASS non-Forever realm return is not treated as a surname')
for modern in [True, False]:
    settings, _ = runtime()
    if modern:
        settings.execute('Settings={RegisterCanvasLayoutCategory=function(f) registered=f; return {GetID=function() return 42 end} end, RegisterAddOnCategory=function(c) assert(c:GetID()==42) end, OpenToCategory=function(id) opened=id end}')
    else:
        settings.execute('InterfaceOptions_AddCategory=function(f) registered=f end; InterfaceOptionsFrame_OpenToCategory=function(f) opened=f end')
    settings.execute(r'''
MailwrightDB={options={showAttachTabs=false}}
Mailwright:Emit('ADDON_LOADED','Mailwright')
local m=Mailwright
assert(registered==m.settingsPanel)
m:Emit('MAIL_SHOW')
for _,b in ipairs(m.attachButtons) do assert(not b:IsShown()) end
m:SetOption('showAttachTabs',true)
for _,b in ipairs(m.attachButtons) do assert(b:IsShown()) end
assert(m.settingsPanel.controls.showAttachTabs:GetChecked())
local c=m.settingsPanel.controls.showAttachTabs
c:SetChecked(false); c.scripts.OnClick(c)
m:Emit('MAIL_CLOSED'); m:Emit('MAIL_SHOW')
for _,b in ipairs(m.attachButtons) do assert(not b:IsShown()) end
m:Emit('MAIL_CLOSED')
SetCVar('BlockTrades','0'); m:SetOption('blockTrades',true)
assert(GetCVar('BlockTrades')=='0')
m:OpenSettings()
assert(opened==(Settings and 42 or m.settingsPanel))
''')
print('PASS modern and legacy settings, saved tab visibility and trade scope')
for locale in ['enUS','enGB','deDE','frFR','esES','esMX','itIT','ptBR','ruRU','koKR','zhCN','zhTW','unknown']:
    language, _ = runtime()
    language.execute('GetLocale=function() return '+repr(locale)+' end')
    language.execute(r'''
Mailwright:Emit('ADDON_LOADED','Mailwright')
local m=Mailwright
assert(m.db.options.language=='auto')
assert(type(m:L('Open All'))=='string')
assert(m:L('Untranslated fallback')=='Untranslated fallback')
local client=m:Client(); local key=m:ContactKey('Example Surname')
m:ShowContactMenu()
m.db.options.language='enUS'
assert(m:L('Open All')=='Open All')
m.db.options.language='deDE'
assert(m:L('Open All')=='Alles öffnen')
assert(m:Client()==client and m:ContactKey('Example Surname')==key)
m.db.options.language='auto'
m:ChooseLanguage(m.settingsPanel)
local chosen
for _,row in ipairs(m.menu.rows) do
 if row:IsShown() and row.caption:GetText()=='Deutsch' then chosen=row end
end
assert(chosen); chosen.action(chosen)
assert(m.db.options.language=='deDE')
-- User-supplied names must not be translated even if they match a UI label.
m.forever=false; assert(m:AddContact('Open'))
m:ShowContactMenu()
local found=false
for _,row in ipairs(m.menu.rows) do
 if row:IsShown() and row.caption:GetText()=='Open' then found=true end
end
assert(found)
''')
print('PASS locale matching, overrides, fallback, selection and unchanged contact identities')
check('language preference survives reload and menu anchors do not reference their own children', r'''
local m=Mailwright
m.db.options.language='frFR'
local saved=m.db; m.db=nil; MailwrightDB=saved; m:Initialize()
assert(m:Locale()=='frFR')
m:ShowOptionsMenu()
local row=m.menu.rows[1]; row.action(row)
assert(m.menuPanels[2]:IsShown() and m.menuPanels[2].anchor==row)
m.menu:Hide(); assert(not m.menuPanels[2]:IsShown())
m.db.options.language='invalid'; m.db=nil; MailwrightDB=saved; m:Initialize()
assert(m.db.options.language=='auto')
m.db.options.language='enUS'
''')
# Every supported language must cover the entire catalog and retain format arguments.
import re
locale_runtime, _ = runtime()
catalogs = locale_runtime.globals().Mailwright.translations
reference = set(catalogs['deDE'].keys())
for locale in ['deDE','frFR','esES','esMX','itIT','ptBR','ruRU','koKR','zhCN','zhTW']:
    catalog = catalogs[locale]
    assert set(catalog.keys()) == reference, (locale, reference - set(catalog.keys()))
    for key in reference:
        value = catalog[key]
        assert value and '\ufffd' not in value, (locale, key)
        tokens = re.findall(r'%(?!%)[-+ #0]*[0-9.]*[a-zA-Z]', key)
        assert tokens == re.findall(r'%(?!%)[-+ #0]*[0-9.]*[a-zA-Z]', value), (locale, key)
        args = [7 if token[-1] in 'diuoxXfgeE' else 'Test' for token in tokens]
        locale_runtime.eval('string.format')(value, *args)
    # Exercise every localized view, including validation and existing-draft protection.
    l, _ = runtime()
    l.execute('GetLocale=function() return '+repr(locale)+' end')
    l.execute(r'''
local m=Mailwright; m:Emit('ADDON_LOADED','Mailwright'); m:Emit('MAIL_SHOW')
assert(m:Locale()==GetLocale())
assert(m.settingsPanel.languageButton:GetText():find(m:L('Language'),1,true))
local stable=m:ExportContacts()
m:ShowOptionsMenu(); m:ShowAttachMenu(); m:ShowContactMenu()
m:TextWindow('Import contacts','',true)
local _,why=m:ValidName(''); assert(why==m:L('Type a recipient name in the To field first, then choose Add contact.'))
assert(m:Status():find(m.version,1,true))
m.db.options.language='enUS'; assert(m:ExportContacts()==stable)
assert(m:Locale()=='enUS')
''')
# Audit static text entry points; dynamic templates use F before interpolation.
ignore={'','X','C','F','Mailwright','-- '}
for filename in ['Core.lua','API.lua','Mailbox.lua','Sending.lua','Contacts.lua','UI.lua','MailboxUI.lua']:
    source=(ROOT/filename).read_text(encoding='utf-8')
    patterns=[r':(?:Print|StopQueue|L|F|TextWindow)\("([^"\n]*)"',
              r'(?:label|button|tip)\([^,]+, "([^"\n]*)"',
              r'text = "([^"\n]*)"']
    for pattern in patterns:
        for key in re.findall(pattern,source):
            key=key.removesuffix(' >')
            if key in ignore or key=='< Contacts': continue
            assert key in reference, (filename, 'untranslated static text', key)
print(f'PASS complete coverage and formatting: {len(reference)} strings in 10 non-English locales; localized UI smoke tests')
print('All Mailwright checks passed. In-game client testing is still required.')
