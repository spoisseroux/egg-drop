-- Quest log inside the deck LCD (UI-SPEC-2026-11-12 section 5.4, mockups 04 to
-- 06). Presentation only: the snapshot (`nurseryState.quests`) is the data and
-- the server owns every claim and reroll. Focus is owned here: up / down move
-- between rows, L / R (Q / E) switch tabs, A claims or rerolls the focused row,
-- B goes back. Touch and mouse use the tabs and row buttons directly.
local Kit=require(script.Parent.DeckKit)
local Log={}
Log.__index=Log
Log.Tabs={"daily","weekly","history"}
local icons={play="trophy",craft="chain",skill="bars"}

local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
-- Pure: "New in 7 h 12 m" / "New in 3 d 7 h".
function Log.resetText(seconds)
 seconds=math.max(0,math.floor(seconds or 0))
 local d,h,m=seconds//86400,(seconds%86400)//3600,(seconds%3600)//60
 if d>0 then return string.format("New in %d d %d h",d,h)end
 return string.format("New in %d h %d m",h,m)
end
-- Pure: where focus lands when a tab opens (first Ready, else first Reroll, else 1).
function Log.initialFocus(rows,bonusReady)
 for i,row in ipairs(rows or {})do if row.ready then return i end end
 if bonusReady then return 4 end
 for i,row in ipairs(rows or {})do if row.canReroll then return i end end
 return 1
end
-- Pure: what A does on a row.
function Log.action(row,rerollLeft)
 if not row then return nil end
 if row.ready then return "claim"end
 if row.canReroll and (rerollLeft or 0)>0 then return "reroll"end
 return nil
end
local function claimedCount(rows)local n=0;for _,r in ipairs(rows or {})do if r.claimed then n+=1 end end;return n end

function Log.new(overlay,callbacks)
 local self=setmetatable({overlay=overlay,callbacks=callbacks or {},tab="daily",focusIndex=1,visible=false,rows={},pendingRows={}},Log)
 local root=overlay.content
 txt(root,"Label","QUEST LOG","dim",24,16,200,16)
 self.title=txt(root,"Title","Today","text",24,34,300,34)
 self.wallet=Kit.wallet(root,40);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(824,24)
 local more=Kit.button(root,"PocketMenu",{variant="ghost",text="Menu",size=Vector2.new(96,40),selectable=false})
 more.Position=UDim2.fromOffset(600,24);Kit.buttonState(more).label.TextSize=16
 more.Activated:Connect(function()if self.callbacks.menu then self.callbacks.menu()end end)
 self.tabs=Kit.tabs(root,{"Daily 0/3","Weekly 0/3","History"},520);self.tabs.root.Position=UDim2.fromOffset(24,84)
 self.tabs.changed=function(index)self:setTab(Log.Tabs[index])end
 local clock=Kit.icon(root,"clock",18,"dim");clock.Position=UDim2.fromOffset(640,97);self.clock=clock
 self.reset=txt(root,"Small","","dim",662,84,162,44,{TextXAlignment=Enum.TextXAlignment.Right})
 for index=1,3 do
  local y=144+(index-1)*102
  local row=Kit.node("TextButton",root,{Name="Quest"..index,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
   Position=UDim2.fromOffset(24,y),Size=UDim2.fromOffset(800,92),ZIndex=root.ZIndex+1})
  Kit.corner(row,14);local stroke=Kit.stroke(row)
  local well=Kit.frame(row,"IconWell","well",UDim2.fromOffset(16,18),UDim2.fromOffset(56,56),14)
  local icon=Kit.icon(well,"trophy",28,"text");icon.AnchorPoint,icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
  local title=txt(row,"Strong","","text",88,12,540,26,{TextSize=19})
  local sub=txt(row,"Small","","soft",88,38,540,20)
  local bar=Kit.progress(row,8);bar.root.Position=UDim2.fromOffset(88,68);bar.root.Size=UDim2.fromOffset(466,8)
  local count=txt(row,"Counter","","soft",564,62,80,20,{TextSize=14})
  local reward=txt(row,"Counter","","stars",640,14,142,24,{TextXAlignment=Enum.TextXAlignment.Right})
  local claim=Kit.button(row,"Claim",{variant="reward",text="Claim",glyph="A",size=Vector2.new(120,38),selectable=false})
  claim.Position=UDim2.fromOffset(662,44)
  local reroll=Kit.button(row,"Reroll",{text="Reroll",size=Vector2.new(120,38),selectable=false});reroll.Position=UDim2.fromOffset(662,44)
  Kit.buttonState(reroll).label.TextSize=16
  local chip=Kit.chip(row,"CLAIMED",nil,26);chip.root.AnchorPoint=Vector2.new(1,0);chip.root.Position=UDim2.fromOffset(782,50)
  local slot={row=row,stroke=stroke,well=well,icon=icon,title=title,sub=sub,bar=bar,count=count,reward=reward,claim=claim,reroll=reroll,chip=chip}
  self.rows[index]=slot
  claim.Activated:Connect(function()self.focusIndex=index;self:paintFocus();self:act()end)
  reroll.Activated:Connect(function()self.focusIndex=index;self:paintFocus();self:act()end)
  row.Activated:Connect(function()self.focusIndex=index;self:paintFocus()end)
 end
 -- Footer strip.
 local footer=Kit.frame(root,"Footer","well",UDim2.fromOffset(24,452),UDim2.fromOffset(800,64),12);Kit.stroke(footer)
 self.footerIcon=Kit.icon(footer,"reroll",24,"accent");self.footerIcon.Position=UDim2.fromOffset(16,20)
 self.footerTitle=txt(footer,"Strong","","text",52,8,520,24,{TextSize=15})
 self.footerSub=txt(footer,"Small","","soft",52,32,520,22)
 self.footerLabel=txt(footer,"Label","TODAY","dim",600,10,184,16,{TextXAlignment=Enum.TextXAlignment.Right})
 self.footerValue=txt(footer,"Counter","","stars",560,28,224,26,{TextXAlignment=Enum.TextXAlignment.Right})
 self.bonusBar=Kit.progress(footer,12,3);self.bonusBar.layout(110,4);self.bonusBar.root.Position=UDim2.fromOffset(470,26)
 self.bonusClaim=Kit.button(footer,"BonusClaim",{variant="reward",text="Claim",glyph="A",size=Vector2.new(120,38),selectable=false})
 self.bonusClaim.Position=UDim2.fromOffset(596,13)
 self.bonusClaim.Activated:Connect(function()self.focusIndex=4;self:paintFocus();self:act()end)
 self.footer=footer
 -- History.
 local list=Kit.node("ScrollingFrame",root,{Name="History",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(24,142),
  Size=UDim2.fromOffset(800,350),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=6,Visible=false,ZIndex=root.ZIndex+1,Selectable=false})
 Kit.node("UIListLayout",list,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)})
 self.history=list
 self.historyFooter=txt(root,"Small","","dim",24,500,800,22,{TextXAlignment=Enum.TextXAlignment.Right})
 -- Hints.
 local hints=Kit.frame(root,"Hints",nil,UDim2.fromOffset(24,548),UDim2.fromOffset(800,24))
 local x=0
 for _,pair in ipairs({{"L","",true},{"R","Tabs"},{"+","Move"},{"A","Claim"},{"B","Back"}})do
  local g=Kit.glyph(hints,pair[1],false,22);g.Position=UDim2.fromOffset(x,1)
  local w=g.Size.X.Offset
  if pair[3]then x+=w+4 else
   txt(hints,"Small",pair[2],"soft",x+w+6,0,80,24)
   x+=w+6+game:GetService("TextService"):GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
  end
 end
 self.ring=Kit.focusRing(overlay.layer)
 return self
end

function Log:rowsFor(tab)
 local q=self.quests;if not q then return {}end
 return if tab=="weekly"then q.weekly or {}else q.daily or {}
end
function Log:paintRow(slot,row,scope)
 slot.row.Visible=row~=nil
 if not row then return end
 local q=self.quests
 slot.title.Text=row.title
 slot.sub.Text=if row.claimed then "Claimed" elseif row.ready then (row.sub or "") .. " · ready to claim" elseif scope=="daily"and row.progress==0 then (row.sub or "").."  ·  Not started"else row.sub or ""
 slot.bar.set(row.progress,row.target,true,true)
 slot.count.Text=string.format("%d/%d",row.progress,row.target)
 slot.reward.Text="★ +"..row.reward
 slot.icon.ImageRectOffset=require(script.Parent.DeckAssets).Icon[if row.claimed then "check"else icons[row.pool]or "quests"]
 Kit.paint(slot.icon,"ImageColor3",if row.claimed then "accent"else "text")
 local pending=self.pendingRows[scope..":"..row.slot]
 slot.claim.Visible=row.ready
 Kit.setText(slot.claim,if pending then "…"else "Claim");Kit.setEnabled(slot.claim,not pending)
 slot.reroll.Visible=scope=="daily"and not row.ready and row.canReroll and (q.rerollLeft or 0)>0
 Kit.setEnabled(slot.reroll,not pending)
 slot.chip.root.Visible=row.claimed
 local alpha=if row.claimed then .4 else 0
 for _,t in ipairs({slot.title,slot.sub,slot.count,slot.reward})do t.TextTransparency=alpha end
 Kit.paint(slot.row,"BackgroundColor3",function()return if row.ready then Kit.color("raised"):Lerp(Kit.Color.stars,.07)else Kit.color("raised")end)
 slot.stroke.Thickness=if row.ready then 2 else 1;slot.stroke.Transparency=if row.ready then 0 else .86
 Kit.paint(slot.stroke,"Color",function()return if row.ready then Kit.Color.stars else Color3.new(1,1,1)end)
end
function Log:paintHistory()
 for _,child in ipairs(self.history:GetChildren())do if child:IsA("GuiObject")then child:Destroy()end end
 local q=self.quests;if not q then return end
 local today=tonumber(q.day)or 0
 local lastDay,order,weekStars=nil,0,0
 local week=tonumber(q.week)or 0
 for _,entry in ipairs(q.history or {})do
  local d=tonumber(entry.d)or today
  if (d+3)//7==week then weekStars+=entry.s end
  if d~=lastDay then
   lastDay=d;order+=1
   local ago=today-d
   local header=Kit.text(self.history,"Label",if ago<=0 then "TODAY"elseif ago==1 then "YESTERDAY"else ago.." DAYS AGO","dim",{TextSize=12,Size=UDim2.fromOffset(784,30),LayoutOrder=order})
   header.TextYAlignment=Enum.TextYAlignment.Bottom
  end
  order+=1
  local row=Kit.listRow(self.history,if entry.a then "AUTO"else(if entry.weekly then "WEEK"else "DAY"),(if entry.weekly then "Weekly: "else "")..entry.title,entry.s)
  row.LayoutOrder=order;row.Selectable=false
 end
 if #(q.history or {})==0 then
  Kit.text(self.history,"Body","Claimed quests show up here.","soft",{Size=UDim2.fromOffset(784,42),LayoutOrder=1})
 end
 self.historyFooter.Text=weekStars.." Stars from quests this week"
end
function Log:paint()
 local q=self.quests or {daily={},weekly={},history={}}
 local daily,weekly=q.daily or {},q.weekly or {}
 self.tabs.labels[1].Text=string.format("Daily %d/%d",claimedCount(daily),#daily)
 self.tabs.labels[2].Text=string.format("Weekly %d/%d",claimedCount(weekly),#weekly)
 local dailyDot,weeklyDot=false,q.bonusReady==true
 for _,r in ipairs(daily)do if r.ready then dailyDot=true end end
 for _,r in ipairs(weekly)do if r.ready then weeklyDot=true end end
 self.tabs.setDot(1,dailyDot);self.tabs.setDot(2,weeklyDot)
 local tab=self.tab
 self.title.Text=if tab=="daily"then "Today"elseif tab=="weekly"then "This week"else "History"
 self.reset.Text=if tab=="daily"then Log.resetText(q.resetIn)elseif tab=="weekly"then Log.resetText(q.weekResetIn)else(if #(q.history or {})==1 then "Last claim"else "Last "..#(q.history or {}).." claims")
local resetWidth=game:GetService("TextService"):GetTextSize(self.reset.Text,self.reset.TextSize,Enum.Font.BuilderSans,Vector2.new(400,40)).X
 self.clock.Position=UDim2.fromOffset(824-resetWidth-24,97)
 local list=tab~="history"
 for index,slot in ipairs(self.rows)do
  if list then self:paintRow(slot,self:rowsFor(tab)[index],tab)else slot.row.Visible=false end
 end
 self.footer.Visible=list;self.history.Visible=not list;self.historyFooter.Visible=not list
 self.bonusBar.root.Visible=tab=="weekly";self.bonusClaim.Visible=false
 if tab=="daily"then
  self.footerIcon.ImageRectOffset=require(script.Parent.DeckAssets).Icon.reroll;Kit.paint(self.footerIcon,"ImageColor3","accent")
  local left=q.rerollLeft or 0
  self.footerTitle.Text=if left>0 then "1 free reroll left today"else "No reroll left today"
  Kit.paint(self.footerTitle,"TextColor3",if left>0 then "text"else "dim")
  self.footerSub.Text="Swaps one quest you have not started for another of the same kind."
  local earned,total=0,0;for _,r in ipairs(daily)do total+=r.reward;if r.claimed then earned+=r.reward end end
  self.footerLabel.Text="TODAY";self.footerValue.Text=string.format("★ %d/%d",earned,total);self.footerValue.Visible=true
 elseif tab=="weekly"then
  self.footerIcon.ImageRectOffset=require(script.Parent.DeckAssets).Icon.trophy;Kit.paint(self.footerIcon,"ImageColor3","stars")
  local bonus=q.bonus or {reward=5}
  self.footerTitle.Text=if bonus.claimed then "Weekly bonus claimed"else "Clear all three this week"
  Kit.paint(self.footerTitle,"TextColor3","text")
  self.footerSub.Text="Bonus on top of the weekly quests above."
  local done=claimedCount(weekly);self.bonusBar.set(done)
  self.footerLabel.Text="BONUS";self.footerValue.Text="★ +"..(bonus.reward or 5)
  self.bonusClaim.Visible=q.bonusReady==true;self.footerValue.Visible=not self.bonusClaim.Visible
  self.bonusBar.root.Position=UDim2.fromOffset(if self.bonusClaim.Visible then 470 else 560,26)
  Kit.setEnabled(self.bonusClaim,not self.pendingRows["weekly:0"])
 else self:paintHistory()end
 self.wallet.set(self.walletValue or 0)
 self:paintFocus()
end
function Log:focusables()
 if self.tab=="history"then return {}end
 local list={}
 for index,slot in ipairs(self.rows)do if slot.row.Visible then list[index]=slot.row end end
 if self.tab=="weekly"and self.bonusClaim.Visible then list[4]=self.bonusClaim end
 return list
end
function Log:paintFocus()
 if not self.visible or self.tab=="history"then self.ring.hide();return end
 local targets=self:focusables()
 local target=targets[self.focusIndex]
 if not target then self.focusIndex=1;target=targets[1]end
 if not target then self.ring.hide();return end
 local slot=self.rows[self.focusIndex]
 local inner=slot and((slot.claim.Visible and slot.claim)or(slot.reroll.Visible and slot.reroll))
 self.ring.attach(inner or target,12)
 self.overlay.layer:SetAttribute("FocusIndex",self.focusIndex)
end

function Log:setTab(tab)
 if not table.find(Log.Tabs,tab)then return end
 self.tab=tab;self.tabs.select(table.find(Log.Tabs,tab))
 self.overlay.layer:SetAttribute("Tab",tab)
 self.focusIndex=Log.initialFocus(self:rowsFor(tab),tab=="weekly"and self.quests and self.quests.bonusReady)
 self:paint()
 if self.callbacks.tab then self.callbacks.tab(tab)end
end
function Log:cycleTab(direction)
 local index=math.clamp(table.find(Log.Tabs,self.tab)+direction,1,#Log.Tabs)
 if Log.Tabs[index]~=self.tab then self:setTab(Log.Tabs[index]);return true end
 return false
end
function Log:move(direction)
 if not self.visible or self.tab=="history"then
  if self.visible and self.tab=="history"then self.history.CanvasPosition+=Vector2.new(0,direction*44)end
  return self.visible
 end
 local targets=self:focusables();local index=self.focusIndex
 repeat index+=direction until index<1 or index>4 or targets[index]
 if targets[index]then self.focusIndex=index;self:paintFocus()end
 return true
end

-- quests: the snapshot's `quests`; wallet: Stars.
function Log:update(quests,wallet)
 self.quests=quests;self.walletValue=wallet
 if self.visible then self:paint()end
end
function Log:show(quests,wallet,tab)
 local opening=not self.visible
 self.quests=quests;self.walletValue=wallet;self.visible=true;self.overlay.layer.Visible=true
 if opening then
  self.pendingRows={}
  self:setTab(tab or "daily")
  if not Kit.reduced()then self.overlay.content.Position=UDim2.fromOffset(0,12);Kit.tween(self.overlay.content,Kit.Motion.screen,{Position=UDim2.new()})end
 else self:paint()end
end
function Log:hide()
 if not self.visible then return end
 self.visible=false;self.overlay.layer.Visible=false;self.ring.hide()
end
-- A on the focused row: claim if ready, reroll if allowed.
function Log:act()
 if not self.visible or not self.quests then return false end
 local q=self.quests
 if self.tab=="weekly"and self.focusIndex==4 then
  if not q.bonusReady or self.pendingRows["weekly:0"]then return false end
  self.pendingRows["weekly:0"]=true;Kit.pulse(self.bonusClaim)
  if self.callbacks.claim then self.callbacks.claim("weekly",0,q.week)end
  self:paint();return true
 end
 local scope=self.tab;local row=self:rowsFor(scope)[self.focusIndex]
 local action=Log.action(row,q.rerollLeft)
 if not action or self.pendingRows[scope..":"..row.slot]then return false end
 self.pendingRows[scope..":"..row.slot]=true
 if action=="claim"then
  Kit.pulse(self.rows[self.focusIndex].claim)
  if self.callbacks.claim then self.callbacks.claim(scope,row.slot,if scope=="daily"then q.day else q.week)end
 else
  Kit.pulse(self.rows[self.focusIndex].reroll)
  if self.callbacks.reroll then self.callbacks.reroll(row.slot,q.day)end
 end
 self:paint();return true
end
-- Server reply (QuestResult). Clears the pending mark; on a saved claim, focus
-- moves on to the next Ready row.
function Log:result(message)
 if type(message)~="table"then return false end
 local key=(message.scope or "daily")..":"..tostring(message.slot)
 self.pendingRows[key]=nil
 if self.visible then
  if message.status=="Saved"and message.action=="questClaim"then
   local rows=self:rowsFor(self.tab)
   for i,r in ipairs(rows)do if r.ready and not(message.scope==self.tab and r.slot==message.slot)then self.focusIndex=i;break end end
  end
  self:paint()
 end
 return true
end
return Log
