-- Quest log inside the deck LCD (UI-SPEC-2026-11-12 section 5.4, mockups 04 to
-- 06). Presentation only: the snapshot (`nurseryState.quests`) is the data and
-- the server owns every claim and reroll. Focus is owned here: up / down move
-- between rows, L / R (Q / E) switch tabs, A claims or rerolls the focused row,
-- B goes back. Touch and mouse use the tabs and row buttons directly.
local Kit=require(script.Parent.DeckKit)
-- Quest titles name a ball size with a colour circle, never a numeral (batch R1).
local BallThemes=require(game:GetService("ReplicatedStorage").Shared.BallThemes)
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Peek=require(script.Parent.PetPeek)
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
 self:build(nil)
 overlay.onLayout=function(view)
  local key=if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"
  if key==self.key then return end
  self:build(view)
  if self.visible then self.tabs.select(table.find(Log.Tabs,self.tab)or 1);self:paint()end
 end
 return self
end

-- Pure (UI-SPEC-COMPACT 8): row height, gap and row tops for a root H.
function Log.compactRows(H)
 local g=if H<340 then 6 else 8
 local rh=math.clamp(math.floor((H-134-2*g)/3),56,76)
 return rh,g,{64,64+rh+g,64+2*(rh+g)}
end
-- Compact type floor: the reward button's 22 px glyph letter goes to 12.
local function glyph12(button)
 local g=Kit.buttonState(button).glyph
 local t=g and g:FindFirstChildWhichIsA("TextLabel")
 if t then t.TextSize=12 end
end
-- Pure: tab track width in the header.
function Log.compactTabsWidth(W,hx)return math.min(312,W-hx-174)end

function Log:clear()
 if self.footer then Peek.hide(self.footer)end
 if self.ring then self.ring.hide();self.ring.root:Destroy()end
 for _,child in ipairs(self.overlay.content:GetChildren())do if not(child:IsA("UIScale")or child:IsA("UIPadding"))then child:Destroy()end end
 self.rows={};self.title=nil;self.squiggle=nil;self.view=nil
end

-- Compact (phone) quest log: full-screen sheet, sticky header (tabs, reset
-- timer, wallet, back arrow), single-column rows that scroll, pinned footer.
function Log:buildCompact(v)
 local root=self.overlay.content
 local W,H=v.W,v.H
 self.view=v
 local sheet=Kit.sheet(root,W,H)
 local body=Kit.frame(root,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 self.wallet=Kit.wallet(body,32);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(W-66,14)
 local tw=Log.compactTabsWidth(W,v.hx)
 self.tabs=Kit.tabs(body,{"Daily 0/3","Weekly 0/3","History"},tw,36,14);self.tabs.root.Position=UDim2.fromOffset(v.hx,12)
 self.tabs.changed=function(index)self:setTab(Log.Tabs[index])end
 self.tabsRight=v.hx+tw
 local clock=Kit.icon(body,"clock",15,"soft");self.clock=clock
 self.reset=txt(body,"Small","","soft",0,20,160,20,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
 -- Rows in a scrolling frame between the pinned header and footer.
 local rh,g=Log.compactRows(H)
 local footerY=H-62
 local list=Kit.node("ScrollingFrame",body,{Name="Rows",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,64),
  Size=UDim2.fromOffset(W-40,footerY-8-64),CanvasSize=UDim2.fromOffset(0,3*rh+2*g),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,
  ScrollingDirection=Enum.ScrollingDirection.Y,ElasticBehavior=Enum.ElasticBehavior.WhenScrollable})
 self.rowList=list
 local w=W-40
 local small=rh<64
 for index=1,3 do
  local y=(index-1)*(rh+g)
  local row=Kit.node("TextButton",list,{Name="Quest"..index,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
   Position=UDim2.fromOffset(0,y),Size=UDim2.fromOffset(w,rh),ZIndex=list.ZIndex+1})
  Kit.corner(row,14);local stroke=Kit.stroke(row)
  local well=Kit.frame(row,"IconWell","well",UDim2.fromOffset(12,(rh-44)/2),UDim2.fromOffset(44,44),12)
  local icon=Kit.icon(well,"trophy",22,"text");icon.AnchorPoint,icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
  local ty=if small then 16 else 19
  local title=txt(row,"Strong","","text",68,ty-11,w-68-220,22,{TextSize=16,TextTruncate=Enum.TextTruncate.AtEnd})
  local sub=txt(row,"Small","","soft",68,ty+20-9,w-68-220,18,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
  local barY=if small then rh-11 else rh-14
  local bar=Kit.progress(row,6);bar.root.Position=UDim2.fromOffset(68,barY);bar.root.Size=UDim2.fromOffset(math.max(40,w-318),6)
  local count=txt(row,"Counter","","soft",68+math.max(40,w-318)+10,barY-7,50,20,{TextSize=13})
  local reward=txt(row,"Counter","","stars",w-128-80,0,80,rh,{TextSize=15,TextXAlignment=Enum.TextXAlignment.Right})
  local claim=Kit.button(row,"Claim",{variant="reward",text="Claim",glyph="A",size=Vector2.new(104,44),textSize=16,selectable=false})
  claim.Position=UDim2.fromOffset(w-116,(rh-44)/2);glyph12(claim)
  local reroll=Kit.button(row,"Reroll",{text="Reroll",size=Vector2.new(104,44),textSize=15,selectable=false});reroll.Position=claim.Position
  local chip=Kit.chip(row,"CLAIMED",nil,24);chip.label.TextSize=12;chip.set("CLAIMED")
  chip.root.AnchorPoint=Vector2.new(.5,.5);chip.root.Position=UDim2.fromOffset(w-116+52,rh/2)
  local slot={row=row,stroke=stroke,well=well,icon=icon,title=title,sub=sub,bar=bar,count=count,reward=reward,claim=claim,reroll=reroll,chip=chip}
  self.rows[index]=slot
  claim.Activated:Connect(function()self.focusIndex=index;self:paintFocus();self:act()end)
  reroll.Activated:Connect(function()self.focusIndex=index;self:paintFocus();self:act()end)
  row.Activated:Connect(function()self.focusIndex=index;self:paintFocus()end)
 end
 -- Pinned footer.
 local fw=W-40
 local footer=Kit.frame(body,"Footer","well",UDim2.fromOffset(20,footerY),UDim2.fromOffset(fw,44),12);Kit.stroke(footer)
 self.footerIcon=Kit.icon(footer,"reroll",18,"accent");self.footerIcon.Position=UDim2.fromOffset(13,13)
 self.footerTitle=txt(footer,"Strong","","text",40,0,220,44,{TextSize=14,AutomaticSize=Enum.AutomaticSize.X})
 self.footerSub=txt(footer,"Small","","soft",0,0,280,44,{TextSize=12,Visible=W>=800})
 local menu=Kit.button(footer,"PocketMenu",{variant="ghost",text="Menu ›",size=Vector2.new(84,44),textSize=15,selectable=false})
 menu.Position=UDim2.fromOffset(fw-84,0)
 menu.Activated:Connect(function()if self.callbacks.menu then self.callbacks.menu()end end)
 local divider=Kit.frame(footer,"Divider",nil,UDim2.fromOffset(fw-86,10),UDim2.fromOffset(1,24));divider.BackgroundTransparency=.88;divider.BackgroundColor3=Color3.new(1,1,1)
 self.footerValue=txt(footer,"Counter","","stars",fw-96-90,0,90,44,{TextSize=15,TextXAlignment=Enum.TextXAlignment.Right})
 self.footerLabel=txt(footer,"Label","TODAY","dim",fw-96-90-8-80,0,80,44,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
 self.bonusBar=Kit.progress(footer,8,3);self.bonusBar.layout(84,4);self.bonusBar.root.Position=UDim2.fromOffset(fw-96-90-8-84,18)
 self.bonusClaim=Kit.button(footer,"BonusClaim",{variant="reward",text="Claim",glyph="A",size=Vector2.new(104,44),textSize=16,selectable=false})
 self.bonusClaim.Position=UDim2.fromOffset(fw-96-104,0);glyph12(self.bonusClaim)
 self.bonusClaim.Activated:Connect(function()self.focusIndex=4;self:paintFocus();self:act()end)
 self.footer=footer
 -- History.
 local history=Kit.node("ScrollingFrame",body,{Name="History",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,64),
  Size=UDim2.fromOffset(W-40,H-110),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,Visible=false,ZIndex=body.ZIndex+1,Selectable=false})
 Kit.node("UIListLayout",history,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,0)})
 self.history=history
 self.historyFooter=txt(body,"Small","","soft",20,H-40,W-40,20,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
 self.ring=Kit.focusRing(self.overlay.layer)
end

function Log:build(view)
 self:clear()
 self.key=if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"
 self.phone=view~=nil
 if view then return self:buildCompact(view)end
 local root=self.overlay.content
 local eyebrow=txt(root,"Label","QUEST LOG","dim",24,16,200,16)
 self.title=txt(root,"Title","Today","text",24,34,300,34)
 -- T5 Quests tint (sky): dot + eyebrow, squiggle under the title, halftone fade.
 Kit.tintEyebrow(eyebrow,"quests")
 self.squiggle=Kit.squiggle(root,self.title,"quests")
 Kit.halftone(root,"quests",false)
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
  local g=Kit.glyph(hints,pair[1],false,22,true);g.Position=UDim2.fromOffset(x,1)
  local w=g.Size.X.Offset
  if pair[3]then x+=w+4 else
   txt(hints,"Small",pair[2],"soft",x+w+6,0,80,24)
   x+=w+6+game:GetService("TextService"):GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
  end
 end
 self.ring=Kit.focusRing(self.overlay.layer)
end

function Log:rowsFor(tab)
 local q=self.quests;if not q then return {}end
 return if tab=="weekly"then q.weekly or {}else q.daily or {}
end
function Log:paintRow(slot,row,scope)
 slot.row.Visible=row~=nil
 if not row then return end
 local q=self.quests
 slot.title.RichText=true;slot.title.Text=BallThemes.questText(row.title,slot.title.TextSize);Kit.localizeRich(slot.title)
 slot.row:SetAttribute("AccessibleLabel",BallThemes.questText(row.title,nil,true))
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
 if self.view then return self:paintCompactHistory(q)end
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
  local row=Kit.listRow(self.history,if entry.a then "AUTO"else(if entry.weekly then "WEEK"else "DAY"),(if entry.weekly then "Weekly: "else "")..BallThemes.questText(entry.title,nil,true),entry.s)
  row.LayoutOrder=order;row.Selectable=false
 end
 if #(q.history or {})==0 then
  Kit.text(self.history,"Body","Claimed quests show up here.","soft",{Size=UDim2.fromOffset(784,42),LayoutOrder=1})
 end
 self.historyFooter.Text=weekStars.." Stars from quests this week"
end
-- Compact history (UI-SPEC-COMPACT 8): 44-high rows, 28-high group headers.
function Log:paintCompactHistory(q)
 local w=self.view.W-44
 local today=tonumber(q.day)or 0
 local lastDay,order,weekStars=nil,0,0
 local week=tonumber(q.week)or 0
 local right={TextXAlignment=Enum.TextXAlignment.Right}
 for _,entry in ipairs(q.history or {})do
  local d=tonumber(entry.d)or today
  if (d+3)//7==week then weekStars+=entry.s end
  if d~=lastDay then
   lastDay=d;order+=1
   local ago=today-d
   local header=Kit.text(self.history,"Label",if ago<=0 then "TODAY"elseif ago==1 then "YESTERDAY"else ago.." DAYS AGO","dim",{TextSize=12,Size=UDim2.fromOffset(w,28),LayoutOrder=order})
   header.TextYAlignment=Enum.TextYAlignment.Bottom
  end
  order+=1
  local row=Kit.frame(self.history,"ListRow",nil,UDim2.new(),UDim2.fromOffset(w,44));row.LayoutOrder=order
  local hair=Kit.frame(row,"Hairline",nil,UDim2.new(0,0,1,-1),UDim2.new(1,0,0,1));hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.95
  txt(row,"Counter",if entry.a then "AUTO"else(if entry.weekly then "WEEK"else "DAY"),"dim",12,0,56,44,{TextSize=12})
  txt(row,"Body",(if entry.weekly then "Weekly: "else "")..BallThemes.questText(entry.title,nil,true),"text",72,0,w-72-120,44,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  txt(row,"Counter","★ +"..entry.s,"stars",w-120,0,80,44,{TextSize=14,TextXAlignment=right.TextXAlignment})
  local mark=Kit.icon(row,"check",18,"accent");mark.Position=UDim2.fromOffset(w-30,13)
 end
 if #(q.history or {})==0 then
  Kit.text(self.history,"Body","Claimed quests show up here.","soft",{TextSize=14,Size=UDim2.fromOffset(w,44),LayoutOrder=1})
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
 if self.title then self.title.Text=if tab=="daily"then "Today"elseif tab=="weekly"then "This week"else "History"end
 if self.squiggle then self.squiggle.update()end
 self.reset.Text=if tab=="daily"then Log.resetText(q.resetIn)elseif tab=="weekly"then Log.resetText(q.weekResetIn)else(if #(q.history or {})==1 then "Last claim"else "Last "..#(q.history or {}).." claims")
 local resetWidth=game:GetService("TextService"):GetTextSize(self.reset.Text,self.reset.TextSize,Enum.Font.BuilderSans,Vector2.new(400,40)).X
 if self.view then
  -- Compact: right edge 12 px left of the wallet, only with 130+ px of gap after the tabs.
  self.wallet.set(self.walletValue or 0)
  local walletLeft=self.view.W-66-self.wallet.root.Size.X.Offset
  local rightEdge=walletLeft-12
  local show=walletLeft-self.tabsRight>=130
  self.reset.Visible,self.clock.Visible=show,show
  self.reset.Position=UDim2.fromOffset(rightEdge-160,20)
  self.clock.Position=UDim2.fromOffset(rightEdge-resetWidth-21,23)
 else
  self.clock.Position=UDim2.fromOffset(824-resetWidth-24,97)
 end
 local list=tab~="history"
 for index,slot in ipairs(self.rows)do
  if list then self:paintRow(slot,self:rowsFor(tab)[index],tab)else slot.row.Visible=false end
 end
 self.footer.Visible=list;self.history.Visible=not list;self.historyFooter.Visible=not list
 self.bonusBar.root.Visible=tab=="weekly";self.bonusClaim.Visible=false
 local allDone=tab=="daily"and #daily>0 and claimedCount(daily)==#daily
 if not self.view then self.footerSub.Visible=not allDone end
 if tab=="daily"then
  self.footerIcon.ImageRectOffset=require(script.Parent.DeckAssets).Icon.reroll;Kit.paint(self.footerIcon,"ImageColor3","accent")
  local left=q.rerollLeft or 0
  self.footerTitle.Text=if left>0 then "1 free reroll left today"else "No reroll left today"
  Kit.paint(self.footerTitle,"TextColor3",if left>0 then "text"elseif self.view then "soft"else "dim")
  -- T12: every daily quest claimed: one line in voice, with the pet when there is one.
  if allDone then
   local name=Peek.petName()
   self.footerTitle.Text=if name then UICopy.get("quests.allDone",{pet=name})else UICopy.get("quests.allDoneSolo")
   Kit.paint(self.footerTitle,"TextColor3","text")
  end
  self.footerSub.Text=if self.view then "Swaps one quest you have not started."else "Swaps one quest you have not started for another of the same kind."
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
  if self.view then
   -- Compact weekly: gold segments, ★ +5 or a Claim in that slot; no BONUS label.
   for i,cell in ipairs(self.bonusBar.cells)do if i<=done then Kit.paint(cell,"BackgroundColor3","stars")end end
   self.footerLabel.Visible=false
   local fw=self.view.W-40
   self.bonusBar.root.Position=UDim2.fromOffset(if self.bonusClaim.Visible then fw-96-104-8-84 else fw-96-90-8-84,18)
  else
   self.bonusBar.root.Position=UDim2.fromOffset(if self.bonusClaim.Visible then 470 else 560,26)
  end
  Kit.setEnabled(self.bonusClaim,not self.pendingRows["weekly:0"])
 else self:paintHistory()end
 if self.view then
  self.footerLabel.Visible=tab=="daily"
  local tw=game:GetService("TextService"):GetTextSize(self.footerTitle.Text,14,Enum.Font.BuilderSansBold,Vector2.new(600,40)).X
  self.footerSub.Position=UDim2.fromOffset(40+tw+10,0)
  self.footerSub.Visible=self.view.W>=800 and tab=="daily"and not allDone
 end
 self.wallet.set(self.walletValue or 0)
 self:syncPeek(allDone)
 self:paintFocus()
end
-- T4 / T12: with every daily quest claimed the pet peeks up inside the footer strip
-- (desktop only), clear of the footer text.
Log.PeekSlot=table.freeze({x=440,y=0,w=200,h=64})
function Log:syncPeek(on)
 local footer=self.footer;if not footer then return false end
 if not on or not self.visible or self.view then Peek.hide(footer);return false end
 local TextService=game:GetService("TextService")
 local function width(label,font)return TextService:GetTextSize(label.Text,label.TextSize,font,Vector2.new(2000,200)).X*1.1 end
 local avoid={{x=52,y=8,w=width(self.footerTitle,Enum.Font.BuilderSansBold),h=24}}
 if self.footerSub.Visible then table.insert(avoid,{x=52,y=32,w=width(self.footerSub,Enum.Font.BuilderSans),h=22})end
 local lw=width(self.footerLabel,Enum.Font.BuilderSansBold);table.insert(avoid,{x=784-lw,y=10,w=lw,h=16})
 local vw=width(self.footerValue,Enum.Font.RobotoMono);table.insert(avoid,{x=784-vw,y=28,w=vw,h=26})
 return Peek.show(footer,{rect=Log.PeekSlot,avoid=avoid,align="center",key="quests"})
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
 if self.footer then Peek.hide(self.footer)end
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
