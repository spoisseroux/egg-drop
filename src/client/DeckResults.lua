-- End-of-round results inside the deck LCD (UI-SPEC-2026-11-12 section 5.3).
-- RunReceipt stays the data owner and RecapFeedback the count-up clock; this
-- module is only the view and its two-target focus (Replay, Leave).
local Kit=require(script.Parent.DeckKit)
local Feedback=require(script.Parent.RecapFeedback)
local Results={}
Results.__index=Results

function Results.new(host,options)
 local self=setmetatable({host=host,options=options or {},focus=1,callbacks={},visible=false},Results)
 self.feedback=Feedback.new(function(sample)self:paintCount(sample)end,options.audio,options.reduce,function()return self.visible end)
 return self
end
function Results:on(name,callback)self.callbacks[name]=callback end

local function commas(n)
 local s=tostring(math.floor(n or 0));local out=s:reverse():gsub("(%d%d%d)","%1,"):reverse()
 return(out:gsub("^,",""))
end
local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end

-- Layout key: false (regular 848), true (small 417 LCD, portrait) or the compact
-- phone view table from DeckScreen:view().
function Results.viewKey(view)
 if type(view)=="table"then return string.format("phone:%dx%d:%d",view.W,view.H,view.hx)end
 return tostring(view==true)
end

-- Compact phone results (UI-SPEC-COMPACT 7): three columns over an action row,
-- Leave under the left thumb, Replay under the right, Change difficulty beside it.
function Results:buildPhone(v)
 local W,H,cw,ch=v.W,v.H,v.cw,v.ch
 local root=Kit.frame(self.host,"Screen",nil,UDim2.new(),UDim2.fromScale(1,1));self.root=root
 local sheet=Kit.sheet(root,W,H)
 local body=Kit.frame(root,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 local right={TextXAlignment=Enum.TextXAlignment.Right}
 local hx=v.hx
 self.wallet=Kit.wallet(body,32);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(W-66,14)
 self.eyebrow=txt(body,"Label","ROUND CLEAR","accent",hx,15,300,14,{TextSize=12})
 self.subline=txt(body,"Body","","soft",hx,31,math.max(80,W-66-150-hx),20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
 -- Payout card.
 local p=if ch<200 then 26 else 28
 local payout=Kit.card(body,"Payout","PAYOUT",{pad=12,labelY=10});self.payout=payout
 payout.Position,payout.Size=UDim2.fromOffset(20,64),UDim2.fromOffset(cw,ch)
 payout.Eyebrow.TextSize=12
 self.rows={}
 for index=1,3 do
  local y=46+(index-1)*p
  local name=txt(payout,"Body","","text",12,y-10,cw-90,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  local amount=txt(payout,"Counter","","stars",cw-82,y-10,70,20,{TextSize=15,TextXAlignment=Enum.TextXAlignment.Right})
  local hair=Kit.frame(payout,"Hairline",nil,UDim2.fromOffset(12,y+p/2),UDim2.fromOffset(cw-24,1))
  hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.92
  self.rows[index]={name=name,amount=amount,hair=hair}
 end
 local ty=46+3*p+4
 self.totalLabel=txt(payout,"Strong","Total","text",12,ty-10,100,20,{TextSize=14})
 self.totalAmount=txt(payout,"Counter","","stars",cw-112,ty-10,100,20,{TextSize=15,TextXAlignment=Enum.TextXAlignment.Right})
 self.saved=txt(payout,"Small","Saved to your wallet","soft",12,ch-28,cw-24,20,{TextSize=12,Visible=ch>=186})
 -- Stars total in the middle column.
 local mx=20+cw+10;local mid=64+(ch-62)/2
 local total=Kit.frame(body,"StarsTotal",nil,UDim2.fromOffset(mx,mid-13-20),UDim2.fromOffset(cw,40))
 Kit.node("UIListLayout",total,{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
 self.star=Kit.icon(total,"star",34);self.star.LayoutOrder=1
 self.starScale=Kit.node("UIScale",self.star,{Scale=1})
 self.totalText=Kit.text(total,"Display","+0 Stars","stars",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,40),LayoutOrder=2,TextSize=30})
 self.newBest=Kit.chip(body,"NEW BEST","gold",22);self.newBest.label.TextSize=12;self.newBest.set("NEW BEST","gold")
 self.newBest.root.AnchorPoint=Vector2.new(.5,0);self.newBest.root.Position=UDim2.fromOffset(mx+cw/2,mid+14)
 local hair=Kit.frame(body,"MetricsHairline",nil,UDim2.fromOffset(mx,64+ch-60),UDim2.fromOffset(cw,1));hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.92
 self.metrics={};self.metricNames=if cw>=200 then {"SCORE","BEST","CHAIN"}else {"SCORE","CHAIN"}
 local n=#self.metricNames
 for index,name in ipairs(self.metricNames)do
  local x=mx+8+(index-1)*math.floor((cw-16)/n)
  txt(body,"Label",name,"dim",x,64+ch-50,80,14,{TextSize=12})
  self.metrics[index]=txt(body,"Counter","0","text",x,64+ch-32,90,20,{TextSize=15})
 end
 -- Goals card.
 local goals,eyebrow=Kit.card(body,"Goals","GOALS",{pad=12,labelY=10})
 goals.Position,goals.Size=UDim2.fromOffset(W-20-cw,64),UDim2.fromOffset(cw,ch);self.goalsEyebrow=eyebrow;eyebrow.TextSize=12
 self.goalsCount=txt(goals,"Counter","","dim",cw-72,8,60,20,{TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
 self.goals={}
 local gp=if ch<200 then 28 else 32
 for index=1,3 do
  local y=48+(index-1)*gp
  local check=Kit.check(goals,20);check.root.Position=UDim2.fromOffset(12,y-10)
  local text=txt(goals,"Body","","text",40,y-10,cw-52,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  self.goals[index]={check=check,text=text}
 end
 -- Action row.
 local ay=v.actionY
 local narrow=W<600
 self.leave=Kit.button(body,"Leave",{text=if narrow then "Leave"else "Leave to garden",glyph="B",size=Vector2.new(if narrow then 100 else 160,48),textSize=15,selectable=false})
 self.leave.Position=UDim2.fromOffset(20,ay)
 self.replay=Kit.button(body,"Replay",{variant="primary",text="Replay",glyph="A",size=Vector2.new(cw,48),textSize=16,selectable=false})
 self.replay.Position=UDim2.fromOffset(W-20-cw,ay)
 local replayIcon=Kit.icon(Kit.buttonState(self.replay).content,"replay",18,"ink");replayIcon.LayoutOrder=1
 self.difficulty=Kit.button(body,"Difficulty",{text="",size=Vector2.new(48,48),selectable=false})
 self.difficulty.Position=UDim2.fromOffset(W-20-cw-58,ay)
 self.difficulty:SetAttribute("AccessibleLabel","Change difficulty")
 Kit.buttonState(self.difficulty).label.Visible=false
 local bars=Kit.frame(self.difficulty,"Bars",nil,UDim2.fromOffset(10,13),UDim2.fromOffset(24,22));bars.ZIndex=self.difficulty.ZIndex+5
 self.diffBars={}
 for index,bh in ipairs({10,16,22})do
  local bar=Kit.frame(bars,"Bar"..index,"stars",UDim2.fromOffset((index-1)*8,22-bh),UDim2.fromOffset(6,bh),2);bar.ZIndex=bars.ZIndex+1;self.diffBars[index]=bar
 end
 local chev=Kit.chevron(self.difficulty,10,"down","soft");chev.Position=UDim2.fromOffset(34,22);chev.ZIndex=bars.ZIndex
 for _,node in ipairs(chev:GetChildren())do node.ZIndex=bars.ZIndex+1 end
 -- Quest shortcut between Leave and Difficulty.
 local qx=20+(if narrow then 100 else 160)+10;local qw=(W-20-cw-58-10)-qx
 local quest=Kit.node("TextButton",body,{Name="QuestShortcut",Text="",AutoButtonColor=false,BackgroundTransparency=0,Position=UDim2.fromOffset(qx,ay),Size=UDim2.fromOffset(qw,48),ZIndex=body.ZIndex+1,Selectable=false})
 Kit.corner(quest,12);self.questStroke=Kit.stroke(quest)
 self.questButton=quest
 self.questIcon=Kit.icon(quest,"quests",18,"text");self.questIcon.Position=UDim2.fromOffset(14,15)
 self.questText=txt(quest,"Strong","","text",40,0,qw-50,48,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
 self.questChip=Kit.chip(quest,"CLAIM","gold",24);self.questChip.label.TextSize=12;self.questChip.set("CLAIM","gold")
 self.questChip.root.AnchorPoint=Vector2.new(1,.5);self.questChip.root.Position=UDim2.new(1,-10,.5,0)
 quest.Activated:Connect(function()if self.questTarget then self.focus=4;self:paintFocus();self:activate(4)end end)
 self.replay.Activated:Connect(function()self.focus=1;self:paintFocus();self:activate(1)end)
 self.leave.Activated:Connect(function()self.focus=2;self:paintFocus();self:activate(2)end)
 self.difficulty.Activated:Connect(function()self.focus=3;self:paintFocus();self:activate(3)end)
 self.ring=Kit.focusRing(self.host)
end

function Results:build(compact)
 if self.root then self.root:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 self.key=Results.viewKey(compact)
 self.phone=type(compact)=="table"
 self.difficulty,self.questButton,self.questTarget=nil,nil,nil
 if self.phone then self.compact=false;return self:buildPhone(compact)end
 self.compact=compact
 local W=if compact then 417 else 848
 local root=Kit.frame(self.host,"Screen",nil,UDim2.new(),UDim2.fromScale(1,1));self.root=root
 local c=compact
 local pad=if c then 12 else 24
 local center={TextXAlignment=Enum.TextXAlignment.Center}
 self.eyebrow=txt(root,"Label","ROUND CLEAR","accent",0,if c then 8 else 14,W,16,center)
 self.subline=txt(root,"Small","","soft",0,if c then 22 else 36,W,20,{TextXAlignment=Enum.TextXAlignment.Center,TextSize=if c then 12 else 16})
 -- Stars total: star + Display number, counted up from 0.
 local total=Kit.frame(root,"StarsTotal",nil,UDim2.fromOffset(0,if c then 40 else 82),UDim2.fromOffset(W,if c then 34 else 46))
 local list=Kit.node("UIListLayout",total,{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
 local _=list
 self.star=Kit.icon(total,"star",if c then 30 else 42);self.star.LayoutOrder=1
 self.starScale=Kit.node("UIScale",self.star,{Scale=1})
 self.totalText=Kit.text(total,"Display","+0 Stars","stars",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,if c then 34 else 46),LayoutOrder=2})
 if c then self.totalText.TextSize=30 end
 -- Payout card.
 local cardW,cardH=if c then 190 else 392,if c then 120 else 250
 local cardY=if c then 112 else 150
 local payout=Kit.card(root,"Payout","PAYOUT",{pad=if c then 10 else 20,labelY=if c then 8 else 18})
 payout.Position,payout.Size=UDim2.fromOffset(pad,cardY),UDim2.fromOffset(cardW,cardH);self.payout=payout
 self.rows={}
 local rows=if c then 1 else 3
 for index=1,rows do
  local y=if c then 40 else 58+(index-1)*40
  local name=txt(payout,"Body","","text",if c then 10 else 20,y-12,cardW-120,24)
  local amount=txt(payout,"Counter","","stars",cardW-100-(if c then 10 else 20),y-12,100,24,{TextXAlignment=Enum.TextXAlignment.Right})
  local hair=Kit.frame(payout,"Hairline",nil,UDim2.fromOffset(if c then 10 else 20,y+16),UDim2.fromOffset(cardW-(if c then 20 else 40),1))
  hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.92
  self.rows[index]={name=name,amount=amount,hair=hair}
 end
 local ty=if c then 74 else 184
 self.totalLabel=txt(payout,"Strong","Total","text",if c then 10 else 20,ty-12,120,24)
 self.totalAmount=txt(payout,"Counter","","stars",cardW-120-(if c then 10 else 20),ty-12,120,24,{TextXAlignment=Enum.TextXAlignment.Right})
 self.saved=txt(payout,"Small","Saved to your wallet","dim",if c then 10 else 20,(if c then 100 else 222)-10,cardW-150,20)
 self.wallet=Kit.wallet(payout,32);self.wallet.root.AnchorPoint=Vector2.new(1,.5);self.wallet.root.Position=UDim2.new(1,if c then -10 else -20,0,if c then 100 else 222)
 if c then self.saved.Visible=false end
 -- Goals card.
 local goals,eyebrow=Kit.card(root,"Goals","GOALS",{pad=if c then 10 else 20,labelY=if c then 8 else 18})
 goals.Position,goals.Size=UDim2.fromOffset(W-pad-cardW,cardY),UDim2.fromOffset(cardW,cardH);self.goalsEyebrow=eyebrow
 self.goalsCount=txt(goals,"Counter","","dim",cardW-80-(if c then 10 else 20),if c then 6 else 16,80,20,{TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
 self.goals={}
 for index=1,3 do
  local y=if c then 42+(index-1)*26 else 56+(index-1)*34
  local check=Kit.check(goals,if c then 20 else 22);check.root.Position=UDim2.fromOffset(if c then 10 else 20,y-11)
  local text=txt(goals,"Body","","text",if c then 36 else 52,y-12,cardW-(if c then 44 else 72),24,{TextTruncate=Enum.TextTruncate.AtEnd})
  if c then text.TextSize=14 end
  self.goals[index]={check=check,text=text}
 end
 self.metrics={}
 if not c then
  local hair=Kit.frame(goals,"Hairline",nil,UDim2.fromOffset(20,156),UDim2.fromOffset(cardW-40,1));hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.92
  for index,name in ipairs({"SCORE","BEST","CHAIN"})do
   txt(goals,"Label",name,"dim",20+(index-1)*104,170,100,16,{TextSize=12})
   self.metrics[index]=txt(goals,"Counter","0","text",20+(index-1)*104,190,100,24)
  end
  self.newBest=Kit.chip(goals,"NEW BEST","gold",26);self.newBest.root.AnchorPoint=Vector2.new(1,0);self.newBest.root.Position=UDim2.new(1,-20,0,186)
  -- Quest strip.
  local strip=Kit.frame(root,"QuestStrip","well",UDim2.fromOffset(24,412),UDim2.fromOffset(800,44),12);Kit.stroke(strip)
  local icon=Kit.icon(strip,"quests",20,"text");icon.Position=UDim2.fromOffset(14,12)
  txt(strip,"Strong","Quests","text",42,0,70,44,{TextSize=14})
  self.stripText=txt(strip,"Small","","soft",116,0,440,44)
  self.stripRight=txt(strip,"Small","","dim",560,0,226,44,{TextXAlignment=Enum.TextXAlignment.Right})
 end
 -- Buttons: Replay (primary, A) and Leave to garden (secondary, B).
 local by=if c then 239 else 472
 local bh=if c then 48 else 64
 self.replay=Kit.button(root,"Replay",{variant="primary",text="Replay",glyph="A",size=Vector2.new(cardW,bh),textSize=if c then 16 else 22,selectable=false})
 self.leave=Kit.button(root,"Leave",{text="Leave to garden",glyph="B",size=Vector2.new(cardW,bh),textSize=if c then 16 else 22,selectable=false})
 self.replay.Position=UDim2.fromOffset(pad,by);self.leave.Position=UDim2.fromOffset(W-pad-cardW,by)
 self.replay.Activated:Connect(function()self.focus=1;self:paintFocus();self:activate(1)end)
 self.leave.Activated:Connect(function()self.focus=2;self:paintFocus();self:activate(2)end)
 self.replay.MouseEnter:Connect(function()end)
 if not c then
  local hints=Kit.frame(root,"Hints",nil,UDim2.fromOffset(24,560),UDim2.fromOffset(800,24))
  local x=0
  for _,pair in ipairs({{"◀▶","Choose"},{"A","Confirm"},{"B","Leave"}})do
   local g=Kit.glyph(hints,pair[1],false,22);g.Position=UDim2.fromOffset(x,1)
   local w=g.Size.X.Offset
   local t=txt(hints,"Small",pair[2],"soft",x+w+6,0,70,24)
   x+=w+6+game:GetService("TextService"):GetTextSize(t.Text,14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
  end
  self.hintRight=txt(hints,"Small","","soft",x,0,800-x,24,{TextXAlignment=Enum.TextXAlignment.Right})
 end
 self.ring=Kit.focusRing(self.host)
end

-- Focus indices: 1 Replay, 2 Leave; compact adds 3 Change difficulty, 4 Quest shortcut.
function Results:target(index)
 return({self.replay,self.leave,self.difficulty,self.questButton})[index]
end
function Results:paintFocus()
 if not self.visible then self.ring.hide();return end
 local target=self:target(self.focus)or self.replay
 self.ring.attach(target,12)
 local glyphs=not(self.phone and Kit.lastInputTouch())
 Kit.setGlyphVisible(self.replay,glyphs);Kit.setGlyphVisible(self.leave,glyphs)
end
-- Pure: compact focus order left to right (Leave, Quest, Difficulty, Replay).
function Results.phoneOrder(questTarget)
 return if questTarget then {2,4,3,1}else {2,3,1}
end

-- Count-up paint. A nil sample means final values.
function Results:paintCount(sample)
 local data=self.data;if not data or not self.totalText then return end
 local earned=data.earned or 0
 local shown=if sample and sample.counted then sample.counted else earned
 self.counting=sample~=nil
 if data.loss then self.totalText.Text="0 Stars";self.totalText.TextColor3=Kit.Color.soft;return end
 self.totalText.TextColor3=Kit.Color.stars
 self.totalText.Text=if data.pending then "Saving…"else string.format("+%d %s",shown,if shown==1 then "Star"else "Stars")
 if not sample and self.wasCounting and not Kit.reduced()then
  self.starScale.Scale=1.12;Kit.tween(self.starScale,.18,{Scale=1})
 end
 self.wasCounting=self.counting
end

-- data: outcome("clear"|"overflow"|"missed"), title, difficulty, pending, earned,
-- rows{{name,amount}}, total, balance, goals{{text,short,done}}, score, best, chain,
-- newBest, strip, stripRight, result (RecapFeedback observe record), loss
function Results:show(data,compact)
 local opening=not self.visible
 if not self.root or self.key~=Results.viewKey(compact)then self:build(compact)end
 self.data=data;self.visible=true;self.host.Parent.Visible=true
 local c=self.compact
 local clear=data.outcome=="clear"
 self.eyebrow.Text=if clear then "ROUND CLEAR"elseif data.outcome=="overflow"then "OVERFLOW"else "GOALS MISSED"
 Kit.paint(self.eyebrow,"TextColor3",if clear then "accent"else "dangerText")
 self.subline.Text=(data.title or "Round").."  ·  "..(data.difficulty or "Medium")
 -- Payout
 if data.loss and not data.pending then
  for index,row in ipairs(self.rows)do row.name.Text=if index==1 then "No Stars this round"else "";row.name.TextColor3=Kit.Color.soft;row.amount.Text="";row.hair.Visible=index==1 end
 else
  for index,row in ipairs(self.rows)do
   local item=data.rows and data.rows[index]
   row.name.Text=item and item.name or "";row.name.TextColor3=Kit.Color.text
   row.amount.Text=if item then(if index==1 then tostring(item.amount)elseif item.amount<0 then "−"..tostring(-item.amount)else "+"..tostring(item.amount))else ""
   row.hair.Visible=item~=nil
  end
 end
 if c and not data.loss then
  local first=self.rows[1];first.name.Text="Total";first.amount.Text="★ "..tostring(data.total or 0)
  self.totalLabel.Text=data.multiplierLine or "Medium ×1";self.totalAmount.Text=""
 else
  self.totalLabel.Text="Total";self.totalAmount.Text=if data.pending then "…"else "★ "..tostring(data.total or 0)
 end
 self.saved.Text=if data.pending then "Saving…"else "Saved to your wallet"
 self.wallet.set(data.balance or 0)
 -- Goals
 local done=0
 for index,slot in ipairs(self.goals)do
  local goal=data.goals and data.goals[index]
  slot.check.root.Visible,slot.text.Visible=goal~=nil,goal~=nil
  if goal then
   if goal.done then done+=1 end
   local short=c or(self.phone and self.payout.Size.X.Offset<200)
   slot.check.set(goal.done);slot.text.Text=if short then goal.short or goal.text else goal.text
   slot.text.TextColor3=if goal.done then Kit.Color.text else Kit.Color.soft
  end
 end
 self.goalsCount.Text=if data.goals and #data.goals>0 then string.format("%d/%d",done,#data.goals)else ""
 if self.phone then self:paintPhone(data)
 elseif #self.metrics>0 then
  self.metrics[1].Text=tostring(data.score or 0);self.metrics[2].Text=tostring(data.best or 0);self.metrics[3].Text="×"..tostring(data.chain or 0)
  self.newBest.root.Visible=data.newBest==true
  self.stripText.Text=data.strip or "";self.stripRight.Text=data.stripRight or ""
  self.hintRight.Text="Replay keeps "..(data.difficulty or "Medium").."."
 end
 -- Pending save: Replay disabled and labelled Saving…, focus to Leave.
 Kit.setEnabled(self.replay,not data.pending);Kit.setText(self.replay,if data.pending then "Saving…"else "Replay")
 Kit.setEnabled(self.leave,data.canLeave~=false)
 if self.difficulty then Kit.setEnabled(self.difficulty,not data.pending)end
 if data.pending then self.focus=2 elseif opening then self.focus=1 end
 if opening and not Kit.reduced()then
  self.root.Position=UDim2.fromOffset(0,12);Kit.tween(self.root,Kit.Motion.screen,{Position=UDim2.new()})
 end
 self:paintFocus()
 if data.result then self.feedback:observe(data.result,true)end
 if not self.feedback.active then self:paintCount(nil)end
end

-- Compact extras: metrics, NEW BEST, difficulty bars and the quest shortcut.
-- data.questDone (title of a quest finished this round), data.questCount ("1/3"),
-- data.canHatch, data.level (1..3).
function Results:paintPhone(data)
 local values={SCORE=commas(data.score),BEST=commas(data.best),CHAIN="×"..tostring(data.chain or 0)}
 for index,name in ipairs(self.metricNames)do self.metrics[index].Text=values[name]end
 self.newBest.root.Visible=data.newBest==true and not data.loss
 local level=data.level or 2
 local tone=if level==1 then Kit.Color.good elseif level==3 then Kit.Color.danger else Kit.Color.stars
 for index,bar in ipairs(self.diffBars)do bar.BackgroundColor3=tone;bar.BackgroundTransparency=if index<=level then 0 else .75 end
 local q=self.questButton;local w=q.Size.X.Offset
 self.questChip.root.Visible=false;self.questIcon.Visible=true
 if data.questDone then
  self.questTarget="claim"
  Kit.paint(q,"BackgroundColor3",function()return Kit.color("well"):Lerp(Kit.Color.stars,.06)end);q.BackgroundTransparency=0
  self.questStroke.Thickness,self.questStroke.Transparency=1.5,0;Kit.paint(self.questStroke,"Color","stars")
  self.questIcon.ImageRectOffset=require(script.Parent.DeckAssets).Icon.check;Kit.paint(self.questIcon,"ImageColor3","stars")
  if w<200 then self.questText.Text="Claim 1 quest";self.questText.Size=UDim2.fromOffset(w-50,48)
  else self.questText.Text=data.questDone;self.questChip.root.Visible=true;self.questText.Size=UDim2.fromOffset(w-50-80,48)end
  Kit.paint(self.questText,"TextColor3","text");Kit.setFontRole(self.questText,"Strong")
 elseif data.canHatch then
  self.questTarget=nil
  q.BackgroundTransparency=1;self.questStroke.Transparency=1;self.questIcon.Visible=false
  self.questText.Position=UDim2.fromOffset(12,0);self.questText.Size=UDim2.fromOffset(w-24,48)
  self.questText.Text="You can hatch an egg";Kit.paint(self.questText,"TextColor3","soft");Kit.setFontRole(self.questText,"Body")
 else
  self.questTarget="log"
  Kit.paint(q,"BackgroundColor3","raised");q.BackgroundTransparency=1
  self.questStroke.Thickness,self.questStroke.Transparency=1,.86;self.questStroke.Color=Color3.new(1,1,1)
  self.questIcon.ImageRectOffset=require(script.Parent.DeckAssets).Icon.quests;Kit.paint(self.questIcon,"ImageColor3","text")
  self.questText.Text="Quests "..(data.questCount or "");self.questText.Size=UDim2.fromOffset(w-50,48)
  Kit.paint(self.questText,"TextColor3","text");Kit.setFontRole(self.questText,"Strong")
 end
 if self.questTarget then self.questText.Position=UDim2.fromOffset(40,0)end
 q.Active=self.questTarget~=nil;q:SetAttribute("AccessibleLabel",if self.questTarget then self.questText.Text else nil)
 if self.focus==4 and not self.questTarget then self.focus=1 end
end

function Results:hide()
 if not self.visible then return end
 self.visible=false;self.feedback:cancel();if self.ring then self.ring.hide()end
 self.host.Parent.Visible=false
end

function Results:move(direction)
 if not self.visible then return false end
 local target
 if self.phone then
  local order=Results.phoneOrder(self.questTarget~=nil)
  local at=table.find(order,self.focus)or #order
  local pending=self.data and self.data.pending
  repeat at=math.clamp(at+direction,1,#order);target=order[at]
  until not(pending and(target==1 or target==3))or at==1 or at==#order
  if pending and(target==1 or target==3)then target=self.focus end
 else
  target=math.clamp(self.focus+direction,1,2)
  if target==1 and self.data and self.data.pending then target=2 end
 end
 if target~=self.focus then self.focus=target;self:paintFocus()
  if self.options.audio then self.options.audio:play("aim",1.1,.35)end
 end
 return true
end
-- First press finishes the count-up; the second acts.
function Results:confirm()
 if not self.visible then return false end
 if self.feedback.active then self.feedback:cancel();self:paintCount(nil);return true end
 self:activate(self.focus);return true
end
function Results:activate(index)
 if index==4 then
  if self.questTarget and self.callbacks.quests then self.callbacks.quests(self.questTarget)end
  return
 end
 local button=self:target(index);if not button then return end
 local state=Kit.buttonState(button);if not state or not state.enabled then return end
 Kit.pulse(button)
 local cb=self.callbacks[({"replay","leave","picker"})[index]]
 if cb then cb()end
end
function Results:back()
 if not self.visible then return false end
 self.focus=2;self:paintFocus();self:activate(2);return true
end
return Results
