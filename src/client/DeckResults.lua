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

local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end

function Results:build(compact)
 if self.root then self.root:Destroy()end
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

function Results:paintFocus()
 if not self.visible then self.ring.hide();return end
 local target=if self.focus==1 then self.replay else self.leave
 self.ring.attach(target,12)
 Kit.setGlyphVisible(self.replay,true);Kit.setGlyphVisible(self.leave,true)
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
 if not self.root or self.compact~=compact then self:build(compact)end
 self.data=data;self.visible=true;self.host.Parent.Visible=true
 local c=self.compact
 local clear=data.outcome=="clear"
 self.eyebrow.Text=if clear then "ROUND CLEAR"elseif data.outcome=="overflow"then "OVERFLOW"else "GOALS MISSED"
 Kit.paint(self.eyebrow,"TextColor3",if clear then "accent"else "danger")
 self.subline.Text=(data.title or "Round").."  ·  "..(data.difficulty or "Medium")
 -- Payout
 if data.loss and not data.pending then
  for index,row in ipairs(self.rows)do row.name.Text=if index==1 then "No Stars this round"else "";row.name.TextColor3=Kit.Color.soft;row.amount.Text="";row.hair.Visible=index==1 end
 else
  for index,row in ipairs(self.rows)do
   local item=data.rows and data.rows[index]
   row.name.Text=item and item.name or "";row.name.TextColor3=Kit.Color.text
   row.amount.Text=if item then(if index==1 then tostring(item.amount)else "+"..tostring(item.amount))else ""
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
   slot.check.set(goal.done);slot.text.Text=if c then goal.short or goal.text else goal.text
   slot.text.TextColor3=if goal.done then Kit.Color.text else Kit.Color.soft
  end
 end
 self.goalsCount.Text=if data.goals and #data.goals>0 then string.format("%d/%d",done,#data.goals)else ""
 if #self.metrics>0 then
  self.metrics[1].Text=tostring(data.score or 0);self.metrics[2].Text=tostring(data.best or 0);self.metrics[3].Text="×"..tostring(data.chain or 0)
  self.newBest.root.Visible=data.newBest==true
  self.stripText.Text=data.strip or "";self.stripRight.Text=data.stripRight or ""
  self.hintRight.Text="Replay keeps "..(data.difficulty or "Medium").."."
 end
 -- Pending save: Replay disabled and labelled Saving…, focus to Leave.
 Kit.setEnabled(self.replay,not data.pending);Kit.setText(self.replay,if data.pending then "Saving…"else "Replay")
 Kit.setEnabled(self.leave,data.canLeave~=false)
 if data.pending then self.focus=2 elseif opening then self.focus=1 end
 if opening and not Kit.reduced()then
  self.root.Position=UDim2.fromOffset(0,12);Kit.tween(self.root,Kit.Motion.screen,{Position=UDim2.new()})
 end
 self:paintFocus()
 if data.result then self.feedback:observe(data.result,true)end
 if not self.feedback.active then self:paintCount(nil)end
end

function Results:hide()
 if not self.visible then return end
 self.visible=false;self.feedback:cancel();if self.ring then self.ring.hide()end
 self.host.Parent.Visible=false
end

function Results:move(direction)
 if not self.visible then return false end
 local target=math.clamp(self.focus+direction,1,2)
 if target==1 and self.data and self.data.pending then target=2 end
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
 local button=if index==1 then self.replay else self.leave
 local state=Kit.buttonState(button);if not state or not state.enabled then return end
 Kit.pulse(button)
 local cb=self.callbacks[if index==1 then "replay"else "leave"]
 if cb then cb()end
end
function Results:back()
 if not self.visible then return false end
 self.focus=2;self:paintFocus();self:activate(2);return true
end
return Results
