-- End-of-round results inside the deck LCD (UI-SPEC-2026-11-12 section 5.3,
-- redesigned by UI-SPEC-REDESIGN-CELEBRATIONS-2026-11-12 section 2).
-- RunReceipt stays the data owner and RecapFeedback the count-up clock; this
-- module is the view: a slanted headline, a Star centrepiece the payout counts
-- into, larger type, a come-back strip (next egg meter + the quest this round
-- moved) and a Hatch button when an egg is affordable.
-- Focus indices: 1 Replay, 2 Leave, 3 Change difficulty (phone), 4 Quest
-- shortcut (phone), 5 Hatch.
local RunService=game:GetService("RunService")
local Kit=require(script.Parent.DeckKit)
local C=require(script.Parent.CelebrationKit)
local Feedback=require(script.Parent.RecapFeedback)
local Results={}
Results.__index=Results

function Results.new(host,options)
 local self=setmetatable({host=host,options=options or {},focus=1,callbacks={},visible=false},Results)
 self.feedback=Feedback.new(function(sample)self:paintCount(sample)end,options.audio,options.reduce,function()return self.visible end)
 return self
end
function Results:on(name,callback)self.callbacks[name]=callback end

-- ── Pure rules (specs cover these) ───────────────────────────────────────────
-- 2.5 Headline: first match wins.
function Results.headline(data)
 if data.outcome=="clear"then
  if data.tidy then return "TIDY WIN!",false end
  if data.newBest then return "NEW BEST!",false end
  if data.level==3 or data.difficulty=="Hard"then return "SPICY WIN!",false end
  return "ROUND CLEAR!",false
 end
 if data.outcome=="overflow"then return "TOO TALL!",true end
 return "SO CLOSE!",true
end
-- 2.6 Next egg meter: one segment per Star up to 10 segments.
Results.MeterMax=10
function Results.meter(balance,cost)
 balance=math.max(0,math.floor(balance or 0));cost=math.max(1,math.floor(cost or 8))
 local segments=math.min(cost,Results.MeterMax)
 local held=math.min(balance,cost)
 local ready=balance>=cost
 local filled=if ready then segments else math.floor(held*segments/cost)
 return{segments=segments,filled=filled,ready=ready,held=held,cost=cost,
  label=if ready then "Ready to hatch!"else string.format("%d/%d",held,cost),short=if ready then "Ready!"else string.format("%d/%d",held,cost)}
end
-- 2.8 Focus order, left to right.
function Results.order(phone,hatch,quest)
 if phone then
  local order={2}
  if hatch then table.insert(order,5)elseif quest then table.insert(order,4)end
  table.insert(order,3);table.insert(order,1)
  return order
 end
 return if hatch then {1,5,2}else {1,2}
end
-- Kept for callers of the earlier compact order (Leave, Quest, Difficulty, Replay).
function Results.phoneOrder(questTarget)return Results.order(true,false,questTarget)end
-- 2.5 Warm line under the hollow Star; the pet's own name fills in.
Results.WarmLines={"%s still thinks you're great.","%s saw that last merge. %s was impressed.","One more round? %s is watching."}
function Results.warmLine(name,seed)
 local line=Results.WarmLines[((seed or 0)%#Results.WarmLines)+1]
 return(line:gsub("%%s",name or "Bear"))
end

local function commas(n)
 local s=tostring(math.floor(n or 0));local out=s:reverse():gsub("(%d%d%d)","%1,"):reverse()
 return(out:gsub("^,",""))
end
local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
local CENTER={TextXAlignment=Enum.TextXAlignment.Center}
local function centered(props)
 local out={TextXAlignment=Enum.TextXAlignment.Center}
 for k,v in pairs(props or {})do out[k]=v end
 return out
end
local function backOut(x)local c1=1.70158;local c3=c1+1;return 1+c3*(x-1)^3+c1*(x-1)^2 end
local function quintOut(x)return 1-(1-x)^5 end
local function bounceOut(x)
 local n,d=7.5625,2.75
 if x<1/d then return n*x*x elseif x<2/d then x-=1.5/d;return n*x*x+.75 elseif x<2.5/d then x-=2.25/d;return n*x*x+.9375 end
 x-=2.625/d;return n*x*x+.984375
end
local function hash(i,salt)local x=math.sin(i*12.9898+salt*78.233)*43758.5453;return x-math.floor(x)end

-- Layout key: false (regular 848), true (small 417 LCD, portrait) or the compact
-- phone view table from DeckScreen:view().
function Results.viewKey(view)
 if type(view)=="table"then return string.format("phone:%dx%d:%d",view.W,view.H,view.hx)end
 return tostring(view==true)
end

-- Shared centrepiece pieces: Star, count, mini Stars, confetti, sparkles.
function Results:buildCentre(parent,cx,starY,starSize,countY,countSize,unitY,unitSize)
 self.centre={cx=cx,starY=starY,starSize=starSize,countY=countY};self.countSize=countSize
 -- The 3D StarToken loads into the Star's viewport; options.starMesh=false keeps the 2D star.
 self.star=C.star(parent,starSize,{mesh=self.options.starMesh~=false});self.star.root.Position=UDim2.fromOffset(cx,starY)
 -- Lowest sibling, so the rays and glow sit under the payout and goals cards.
 self.star.root.ZIndex=1
 local count=Kit.frame(parent,"Count",nil,UDim2.fromOffset(cx,countY),UDim2.fromOffset(countSize*5,countSize*1.2));count.AnchorPoint=Vector2.new(.5,.5)
 count.ZIndex=self.star.root.ZIndex+20
 self.countScale=Kit.node("UIScale",count,{Scale=1});self.countHolder=count
 local drop=math.max(2,math.floor(countSize*.07))
 self.countShadow=C.display(count,"+0",countSize,C.GoldDeep,{Name="CountShadow",TextXAlignment=Enum.TextXAlignment.Center,Position=UDim2.fromOffset(drop,drop),Size=UDim2.fromScale(1,1)})
 self.totalText=C.display(count,"+0",countSize,Kit.Color.stars,{Name="Count",TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromScale(1,1)})
 self.totalText.ZIndex=self.countShadow.ZIndex+1
 self.unit=C.display(parent,"S T A R S",unitSize,Kit.Color.stars,{Name="Unit",TextXAlignment=Enum.TextXAlignment.Center,AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromOffset(cx,unitY),Size=UDim2.fromOffset(unitSize*14,unitSize+8)})
 self.minis={}
 for index=1,6 do
  local mini=Kit.node("TextLabel",parent,{Name="MiniStar",BackgroundTransparency=1,Text="★",TextColor3=C.Gold,TextSize=math.max(14,math.floor(starSize*.16)),
   AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(30,30),ZIndex=count.ZIndex+2,Visible=false})
  self.minis[index]=mini
 end
 self.confetti={}
 for index=1,34 do
  local piece=Kit.frame(parent,"Confetti",nil,UDim2.new(),UDim2.fromOffset(math.max(3,math.floor(starSize*.025)),math.max(8,math.floor(starSize*.08))),2)
  piece.AnchorPoint=Vector2.new(.5,.5);piece.BackgroundTransparency=0;piece.BackgroundColor3=C.Confetti[(index-1)%#C.Confetti+1];piece.Visible=false
  piece.ZIndex=count.ZIndex+1;self.confetti[index]=piece
 end
 self.twinkles={}
 for index=1,3 do
  local spark=C.sparkle(parent,math.max(10,math.floor(starSize*.14)),C.White);spark.ZIndex=count.ZIndex+1;spark.Visible=false;self.twinkles[index]=spark
 end
end

-- Next egg meter cells (shared by the desktop strip and the phone payout card).
function Results:buildMeter(parent,x,y,width,height)
 self.meterCells={};self.meterRect={x=x,y=y,w=width,h=height,parent=parent}
 for index=1,Results.MeterMax do
  local cell=Kit.frame(parent,"MeterCell"..index,"well",UDim2.new(),UDim2.fromOffset(10,height),3);Kit.stroke(cell)
  self.meterCells[index]=cell
 end
end
function Results:paintMeter(balance)
 local data=self.data;if not data or not self.meterCells then return end
 local m=Results.meter(balance,data.eggCost or 8)
 local r=self.meterRect;local gap=if r.w>300 then 6 else 4
 local w=(r.w-gap*(m.segments-1))/m.segments
 for index,cell in ipairs(self.meterCells)do
  local on=index<=m.filled
  cell.Visible=index<=m.segments
  cell.Position=UDim2.fromOffset(r.x+(index-1)*(w+gap),r.y);cell.Size=UDim2.fromOffset(w,r.h)
  cell.BackgroundColor3=if on then Kit.Color.stars else Kit.color("well")
  cell.KitStroke.Enabled=not on
 end
 if self.meterStatus then
  self.meterStatus.Text=if self.phone then m.short else m.label
  self.meterStatus.TextColor3=if m.ready then Kit.Color.stars else Kit.Color.soft
 end
 if self.stripStroke then
  self.stripStroke.Color=if m.ready then Kit.Color.stars else Kit.Color.white
  self.stripStroke.Transparency=if m.ready then 0 else .86;self.stripStroke.Thickness=if m.ready then 2 else 1
 end
 self.meterReady=m.ready
 return m
end

-- ── Phone (2.3): sheet 732x288 under the Roblox controls ────────────────────
function Results:buildPhone(v)
 local W,H,cw,ch=v.W,v.H,v.cw,v.ch
 local root=Kit.frame(self.host,"Screen",nil,UDim2.new(),UDim2.fromScale(1,1));self.root=root
 local sheet=Kit.sheet(root,W,H)
 local body=Kit.frame(root,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 self.body=body
 local right={TextXAlignment=Enum.TextXAlignment.Right}
 self.wallet=Kit.wallet(body,32);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(W-66,8)
 -- Headline row.
 self.headline=C.banner(body,{size=22,rotation=-3});self.headline.root.Position=UDim2.fromOffset(W/2,20)
 self.eyebrow=self.headline.label
 self.subline=txt(body,"BodyMedium","","soft",W/2-170,33,340,16,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
 -- Centre column (behind the cards' edges).
 local mx=20+cw+10
 self:buildCentre(body,W/2,64+38,66,64+101,40,64+137,12)
 self.missText=txt(body,"Strong","No Stars this time","text",mx,64+92,cw,22,centered({TextSize=16,Visible=false}))
 self.warmText=txt(body,"Small","","soft",mx-6,64+116,cw+12,34,centered({TextSize=12,TextWrapped=true,Visible=false}))
 -- Payout card: rows, total, then the next egg meter.
 local payout=Kit.card(body,"Payout","PAYOUT",{pad=12,labelY=10});self.payout=payout
 payout.Position,payout.Size=UDim2.fromOffset(20,64),UDim2.fromOffset(cw,ch)
 payout.Eyebrow.TextSize=12
 self.rowPitch,self.rowTop=24,32
 self.rows={}
 for index=1,2 do
  local y=self.rowTop+(index-1)*self.rowPitch
  local name=txt(payout,"BodyMedium","","text",12,y,cw-80,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  local amount=txt(payout,"Counter","","stars",cw-82,y,70,20,{TextSize=16,TextXAlignment=Enum.TextXAlignment.Right})
  local hair=Kit.frame(payout,"Hairline",nil,UDim2.fromOffset(12,y+22),UDim2.fromOffset(cw-24,1))
  hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.92
  self.rows[index]={name=name,amount=amount,hair=hair}
 end
 self.totalLabel=txt(payout,"Strong","Total","text",12,0,100,20,{TextSize=14})
 self.totalAmount=txt(payout,"Counter","","stars",cw-112,0,100,20,{TextSize=16,TextXAlignment=Enum.TextXAlignment.Right})
 self.saved=txt(payout,"Small","Saved to your wallet","soft",12,ch-28,cw-24,20,{TextSize=12,Visible=false})
 self.eggIcon=Kit.icon(payout,"egg",20,"stars");self.eggIcon.Position=UDim2.fromOffset(10,ch-34)
 txt(payout,"Label","NEXT EGG","dim",36,ch-38,100,14,{TextSize=12})
 self.meterStatus=txt(payout,"Strong","","soft",cw-12-100,ch-38,100,14,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
 self:buildMeter(payout,36,ch-20,cw-48,10)
 -- Goals card: goals, NEW BEST, then Score / Best / Chain.
 local goals,eyebrow=Kit.card(body,"Goals","GOALS",{pad=12,labelY=10})
 goals.Position,goals.Size=UDim2.fromOffset(W-20-cw,64),UDim2.fromOffset(cw,ch);self.goalsEyebrow=eyebrow;eyebrow.TextSize=12
 self.goalsCard=goals
 self.goalsCount=txt(goals,"Counter","","dim",cw-72,8,60,20,{TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
 self.goals={}
 self.goalPitch=if ch<150 then 24 else 26
 for index=1,3 do
  local y=34+(index-1)*self.goalPitch
  local check=Kit.check(goals,20);check.root.Position=UDim2.fromOffset(12,y)
  local text=txt(goals,"BodyMedium","","text",40,y,cw-52,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  self.goals[index]={check=check,text=text,scale=Kit.node("UIScale",check.root,{Scale=1})}
 end
 self.goalHint=txt(goals,"Small","","dim",40,0,cw-52,16,{TextSize=12,Visible=false})
 self.newBest=Kit.chip(goals,"NEW BEST","gold",22);self.newBest.label.TextSize=12;self.newBest.set("NEW BEST","gold")
 self.newBestScale=Kit.node("UIScale",self.newBest.root,{Scale=1})
 local hair=Kit.frame(goals,"MetricsHairline",nil,UDim2.fromOffset(12,ch-50),UDim2.fromOffset(cw-24,1));hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.92
 self.metrics={};self.metricNames=if cw>=200 then {"SCORE","BEST","CHAIN"}else {"SCORE","CHAIN"}
 local n=#self.metricNames
 for index,name in ipairs(self.metricNames)do
  local x=12+(index-1)*math.floor((cw-24)/n)
  txt(goals,"Label",name,"dim",x,ch-44,80,14,{TextSize=12})
  self.metrics[index]=txt(goals,"Counter","0","text",x,ch-28,90,20,{TextSize=16})
 end
 -- Action row.
 local ay=v.actionY
 local narrow=W<600
 self.leave=Kit.button(body,"Leave",{text=if narrow then "Leave"else "Leave to garden",glyph="B",size=Vector2.new(if narrow then 100 else 160,48),textSize=15,selectable=false})
 self.leave.Position=UDim2.fromOffset(20,ay)
 self.replay=Kit.button(body,"Replay",{variant="primary",text="Replay",glyph="A",size=Vector2.new(cw,48),textSize=16,selectable=false})
 self.replay.Position=UDim2.fromOffset(W-20-cw,ay)
 local replayIcon=Kit.icon(Kit.buttonState(self.replay).content,"replay",18,"ink");replayIcon.LayoutOrder=1
 self.replayPulse=Kit.node("UIScale",Kit.buttonState(self.replay).content,{Scale=1})
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
 -- Shortcut cell between Leave and Difficulty: the quest this round moved, a
 -- claim, or (when an egg is affordable) the gold Hatch button in its place.
 local qx=20+(if narrow then 100 else 160)+10;local qw=(W-20-cw-58-10)-qx
 local quest=Kit.node("TextButton",body,{Name="QuestShortcut",Text="",AutoButtonColor=false,BackgroundTransparency=0,Position=UDim2.fromOffset(qx,ay),Size=UDim2.fromOffset(qw,48),ZIndex=body.ZIndex+1,Selectable=false})
 Kit.corner(quest,12);self.questStroke=Kit.stroke(quest)
 self.questButton=quest
 self.questIcon=Kit.icon(quest,"quests",18,"text");self.questIcon.Position=UDim2.fromOffset(14,15)
 self.questText=txt(quest,"Strong","","text",40,0,qw-50,48,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
 self.questChip=Kit.chip(quest,"CLAIM","gold",24);self.questChip.label.TextSize=12;self.questChip.set("CLAIM","gold")
 self.questChip.root.AnchorPoint=Vector2.new(1,.5);self.questChip.root.Position=UDim2.new(1,-10,.5,0)
 self.hatch=C.rewardButton(body,"Hatch","Hatch egg",Vector2.new(qw,48),16)
 self.hatch.Position=UDim2.fromOffset(qx,ay);self.hatch.Visible=false
 quest.Activated:Connect(function()if self.questTarget then self.focus=4;self:paintFocus();self:activate(4)end end)
 self.hatch.Activated:Connect(function()self.focus=5;self:paintFocus();self:activate(5)end)
 self.replay.Activated:Connect(function()self.focus=1;self:paintFocus();self:activate(1)end)
 self.leave.Activated:Connect(function()self.focus=2;self:paintFocus();self:activate(2)end)
 self.difficulty.Activated:Connect(function()self.focus=3;self:paintFocus();self:activate(3)end)
 self.ring=Kit.focusRing(self.host)
 local _=right;local _h=H
end

-- ── Desktop (2.2): the 848x608 LCD ──────────────────────────────────────────
function Results:buildDesktop()
 local W=848
 local root=Kit.frame(self.host,"Screen",nil,UDim2.new(),UDim2.fromScale(1,1));self.root=root
 self.body=root
 -- Centrepiece first so the cards draw over the rays.
 local centre=Kit.frame(root,"Centre",nil,UDim2.new(),UDim2.fromScale(1,1))
 self:buildCentre(centre,424,212,164,332,84,386,17)
 centre.ZIndex=1
 self.missText=txt(root,"Title","No Stars this time","text",280,296,288,44,centered({TextSize=34,Visible=false}))
 self.warmText=txt(root,"BodyMedium","","soft",268,364,312,24,centered({TextSize=17,Visible=false}))
 self.headline=C.banner(root,{size=44,rotation=-3});self.headline.root.Position=UDim2.fromOffset(424,48)
 self.eyebrow=self.headline.label
 self.subline=txt(root,"BodyMedium","","soft",224,84,400,20,centered({TextSize=16,TextTruncate=Enum.TextTruncate.AtEnd}))
 self.wallet=Kit.wallet(root,40);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(824,16)
 -- Payout card.
 local cw,chh=248,276
 local payout=Kit.card(root,"Payout","PAYOUT",{pad=18,labelY=16});self.payout=payout
 payout.Position,payout.Size=UDim2.fromOffset(24,124),UDim2.fromOffset(cw,chh)
 self.rowPitch,self.rowTop=40,46
 self.rows={}
 for index=1,3 do
  local y=self.rowTop+(index-1)*self.rowPitch
  local name=txt(payout,"BodyMedium","","text",18,y,cw-110,26,{TextSize=18,TextTruncate=Enum.TextTruncate.AtEnd})
  local amount=txt(payout,"Counter","","stars",cw-18-90,y,90,26,{TextSize=20,TextXAlignment=Enum.TextXAlignment.Right})
  local hair=Kit.frame(payout,"Hairline",nil,UDim2.fromOffset(18,y+32),UDim2.fromOffset(cw-36,1))
  hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.92
  self.rows[index]={name=name,amount=amount,hair=hair}
 end
 self.totalLabel=txt(payout,"Strong","Total","text",18,0,120,28,{TextSize=18})
 self.totalAmount=txt(payout,"Counter","","stars",cw-18-110,0,110,28,{TextSize=22,TextXAlignment=Enum.TextXAlignment.Right})
 self.nudge=txt(payout,"BodyMedium","","soft",18,chh-62,cw-36,22,{TextSize=16})
 self.saved=txt(payout,"Small","Saved to your wallet","dim",18,chh-36,cw-36,20)
 -- Goals card.
 local goals,eyebrow=Kit.card(root,"Goals","GOALS",{pad=18,labelY=16})
 goals.Position,goals.Size=UDim2.fromOffset(576,124),UDim2.fromOffset(cw,chh);self.goalsEyebrow=eyebrow
 self.goalsCard=goals
 self.goalsCount=txt(goals,"Counter","","dim",cw-18-80,14,80,20,{TextSize=15,TextXAlignment=Enum.TextXAlignment.Right})
 self.goals={}
 self.goalPitch=36
 for index=1,3 do
  local y=48+(index-1)*self.goalPitch
  local check=Kit.check(goals,22);check.root.Position=UDim2.fromOffset(18,y+1)
  local text=txt(goals,"BodyMedium","","text",48,y,cw-62,24,{TextSize=17,TextTruncate=Enum.TextTruncate.AtEnd})
  self.goals[index]={check=check,text=text,scale=Kit.node("UIScale",check.root,{Scale=1})}
 end
 self.goalHint=txt(goals,"Small","","dim",48,0,cw-62,20,{Visible=false})
 self.newBest=Kit.chip(goals,"NEW BEST","gold",26);self.newBest.root.Position=UDim2.fromOffset(18,166)
 self.newBestScale=Kit.node("UIScale",self.newBest.root,{Scale=1})
 local hair=Kit.frame(goals,"Hairline",nil,UDim2.fromOffset(18,204),UDim2.fromOffset(cw-36,1));hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.92
 self.metrics={}
 for index,name in ipairs({"SCORE","BEST","CHAIN"})do
  txt(goals,"Label",name,"dim",18+(index-1)*72,214,70,16,{TextSize=12})
  self.metrics[index]=txt(goals,"Counter","0","text",18+(index-1)*72,234,72,26,{TextSize=19})
 end
 -- Come-back strip: next egg meter (left), the quest this round moved (right).
 local strip=Kit.frame(root,"ComeBackStrip","well",UDim2.fromOffset(24,412),UDim2.fromOffset(800,56),14);self.stripStroke=Kit.stroke(strip)
 self.strip=strip
 self.eggIcon=Kit.icon(strip,"egg",30,"stars");self.eggIcon.Position=UDim2.fromOffset(14,13)
 txt(strip,"Label","NEXT EGG","soft",56,8,140,16,{TextSize=13})
 self.meterStatus=txt(strip,"Strong","","soft",236,8,140,16,{TextSize=14,TextXAlignment=Enum.TextXAlignment.Right})
 self:buildMeter(strip,56,30,320,14)
 local divider=Kit.frame(strip,"Divider",nil,UDim2.fromOffset(396,10),UDim2.fromOffset(1,36));divider.BackgroundColor3,divider.BackgroundTransparency=Color3.new(1,1,1),.88
 self.stripQuestIcon=Kit.icon(strip,"quests",22,"text");self.stripQuestIcon.Position=UDim2.fromOffset(414,17)
 self.questScope=txt(strip,"Label","DAILY QUEST","soft",448,6,180,16,{TextSize=13})
 self.questTitle=txt(strip,"Strong","","text",448,24,210,26,{TextSize=16,TextTruncate=Enum.TextTruncate.AtEnd})
 self.questMoved=txt(strip,"Strong","","accent",620,6,164,16,{TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
 self.questBar=Kit.progress(strip,10);self.questBar.root.Position=UDim2.fromOffset(664,32);self.questBar.root.Size=UDim2.fromOffset(76,10)
 self.questCountText=txt(strip,"Counter","","text",740,24,44,26,{TextSize=17,TextXAlignment=Enum.TextXAlignment.Right})
 -- Buttons: Replay (A), Hatch egg (gold, when affordable), Leave (B).
 self.replay=Kit.button(root,"Replay",{variant="primary",text="Replay",glyph="A",size=Vector2.new(392,64),textSize=22,selectable=false})
 local replayIcon=Kit.icon(Kit.buttonState(self.replay).content,"replay",24,"ink");replayIcon.LayoutOrder=1
 Kit.buttonState(self.replay).label.LayoutOrder=2
 self.replayPulse=Kit.node("UIScale",Kit.buttonState(self.replay).content,{Scale=1})
 self.hatch=C.rewardButton(root,"Hatch","Hatch egg",Vector2.new(216,64),22)
 self.leave=Kit.button(root,"Leave",{text="Leave to garden",glyph="B",size=Vector2.new(392,64),textSize=22,selectable=false})
 self.replay.Position=UDim2.fromOffset(24,484)
 self.replay.Activated:Connect(function()self.focus=1;self:paintFocus();self:activate(1)end)
 self.leave.Activated:Connect(function()self.focus=2;self:paintFocus();self:activate(2)end)
 self.hatch.Activated:Connect(function()self.focus=5;self:paintFocus();self:activate(5)end)
 -- Hints: Choose / Confirm / Leave, or "A Skip the count" while counting.
 local hints=Kit.frame(root,"Hints",nil,UDim2.fromOffset(24,568),UDim2.fromOffset(800,24));self.hints=hints
 local x=0
 for _,pair in ipairs({{"◀▶","Choose"},{"A","Confirm"},{"B","Leave"}})do
  local g=Kit.glyph(hints,pair[1],false,22);g.Position=UDim2.fromOffset(x,1)
  local w=g.Size.X.Offset
  local t=txt(hints,"Small",pair[2],"soft",x+w+6,0,70,24)
  x+=w+6+game:GetService("TextService"):GetTextSize(t.Text,14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
 end
 self.hintRight=txt(hints,"Small","","soft",x,0,800-x,24,{TextXAlignment=Enum.TextXAlignment.Right})
 local skip=Kit.frame(root,"SkipHint",nil,UDim2.fromOffset(24,568),UDim2.fromOffset(300,24));self.skipHint=skip;skip.Visible=false
 local g=Kit.glyph(skip,"A",false,22);g.Position=UDim2.fromOffset(0,1)
 txt(skip,"Small","Skip the count","soft",g.Size.X.Offset+6,0,200,24)
 self.ring=Kit.focusRing(self.host)
end

-- ── Small LCD (417x299 portrait): the compact layout, unchanged in shape ────
function Results:buildCompact()
 local W=417
 local root=Kit.frame(self.host,"Screen",nil,UDim2.new(),UDim2.fromScale(1,1));self.root=root
 self.body=root
 local pad=12
 self.headline=C.banner(root,{size=18,rotation=-3});self.headline.root.Position=UDim2.fromOffset(W/2,18)
 self.eyebrow=self.headline.label
 self.subline=txt(root,"Small","",
  "soft",0,32,W,16,{TextXAlignment=Enum.TextXAlignment.Center,TextSize=12})
 local total=Kit.frame(root,"StarsTotal",nil,UDim2.fromOffset(0,52),UDim2.fromOffset(W,34))
 Kit.node("UIListLayout",total,{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
 self.starIcon=Kit.icon(total,"star",30);self.starIcon.LayoutOrder=1
 self.starScale=Kit.node("UIScale",self.starIcon,{Scale=1})
 self.totalText=Kit.text(total,"Display","+0 Stars","stars",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,34),LayoutOrder=2,TextSize=30})
 local cardW,cardH,cardY=190,120,112
 local payout=Kit.card(root,"Payout","PAYOUT",{pad=10,labelY=8})
 payout.Position,payout.Size=UDim2.fromOffset(pad,cardY),UDim2.fromOffset(cardW,cardH);self.payout=payout
 self.rows={}
 do
  local y=40
  local name=txt(payout,"Body","","text",10,y-12,cardW-120,24)
  local amount=txt(payout,"Counter","","stars",cardW-110,y-12,100,24,{TextXAlignment=Enum.TextXAlignment.Right})
  local hair=Kit.frame(payout,"Hairline",nil,UDim2.fromOffset(10,y+16),UDim2.fromOffset(cardW-20,1))
  hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.92
  self.rows[1]={name=name,amount=amount,hair=hair}
 end
 self.totalLabel=txt(payout,"Strong","Total","text",10,62,120,24)
 self.totalAmount=txt(payout,"Counter","","stars",cardW-130,62,120,24,{TextXAlignment=Enum.TextXAlignment.Right})
 self.saved=txt(payout,"Small","Saved to your wallet","dim",10,90,cardW-150,20);self.saved.Visible=false
 self.wallet=Kit.wallet(payout,32);self.wallet.root.AnchorPoint=Vector2.new(1,.5);self.wallet.root.Position=UDim2.new(1,-10,0,100)
 local goals,eyebrow=Kit.card(root,"Goals","GOALS",{pad=10,labelY=8})
 goals.Position,goals.Size=UDim2.fromOffset(W-pad-cardW,cardY),UDim2.fromOffset(cardW,cardH);self.goalsEyebrow=eyebrow
 self.goalsCount=txt(goals,"Counter","","dim",cardW-90,6,80,20,{TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
 self.goals={}
 for index=1,3 do
  local y=42+(index-1)*26
  local check=Kit.check(goals,20);check.root.Position=UDim2.fromOffset(10,y-11)
  local text=txt(goals,"Body","","text",36,y-12,cardW-44,24,{TextTruncate=Enum.TextTruncate.AtEnd,TextSize=14})
  self.goals[index]={check=check,text=text,scale=Kit.node("UIScale",check.root,{Scale=1})}
 end
 self.metrics={}
 self.replay=Kit.button(root,"Replay",{variant="primary",text="Replay",glyph="A",size=Vector2.new(cardW,48),textSize=16,selectable=false})
 self.leave=Kit.button(root,"Leave",{text="Leave to garden",glyph="B",size=Vector2.new(cardW,48),textSize=16,selectable=false})
 self.replay.Position=UDim2.fromOffset(pad,239);self.leave.Position=UDim2.fromOffset(W-pad-cardW,239)
 self.replay.Activated:Connect(function()self.focus=1;self:paintFocus();self:activate(1)end)
 self.leave.Activated:Connect(function()self.focus=2;self:paintFocus();self:activate(2)end)
 self.ring=Kit.focusRing(self.host)
end

function Results:build(compact)
 self:stopIdle()
 if self.root then self.root:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 self.key=Results.viewKey(compact)
 self.phone=type(compact)=="table"
 self.difficulty,self.questButton,self.questTarget,self.hatch,self.star,self.meterCells=nil,nil,nil,nil,nil,nil
 self.nudge,self.strip,self.stripStroke,self.meterStatus,self.hints,self.skipHint,self.hintRight=nil,nil,nil,nil,nil,nil,nil
 self.missText,self.warmText,self.unit,self.minis,self.confetti,self.twinkles,self.newBest=nil,nil,nil,nil,nil,nil,nil
 self.goalHint,self.replayPulse,self.starIcon,self.countHolder=nil,nil,nil,nil
 if self.phone then self.compact=false;return self:buildPhone(compact)end
 self.compact=compact==true
 if self.compact then return self:buildCompact()end
 return self:buildDesktop()
end

function Results:target(index)
 return({self.replay,self.leave,self.difficulty,self.questButton,self.hatch})[index]
end
function Results:hatchShown()return self.hatch~=nil and self.hatch.Visible end
function Results:paintFocus()
 if not self.visible then self.ring.hide();return end
 local target=self:target(self.focus)or self.replay
 self.ring.attach(target,12)
 local glyphs=not(self.phone and Kit.lastInputTouch())
 Kit.setGlyphVisible(self.replay,glyphs);Kit.setGlyphVisible(self.leave,glyphs)
end

-- Desktop buttons: Replay 392 + Leave 392, or Replay 392 + Hatch 216 + Leave 160.
function Results:placeButtons(hatch)
 if self.phone or self.compact then return end
 self.hatch.Visible=hatch
 self.replay.Position=UDim2.fromOffset(24,484)
 if hatch then
  self.hatch.Position=UDim2.fromOffset(432,484)
  self.leave.Position,self.leave.Size=UDim2.fromOffset(664,484),UDim2.fromOffset(160,64)
  Kit.setText(self.leave,"Leave")
 else
  self.leave.Position,self.leave.Size=UDim2.fromOffset(432,484),UDim2.fromOffset(392,64)
  Kit.setText(self.leave,"Leave to garden")
 end
 Kit.buttonState(self.leave).label.Size=UDim2.fromOffset(0,64)
end

-- Payout rows and the Total row under them.
function Results:paintRows(data)
 local loss=data.loss and not data.pending
 local shown=0
 for index,row in ipairs(self.rows)do
  local item=data.rows and data.rows[index]
  if loss then item=nil end
  row.name.Text=item and item.name or "";row.name.TextColor3=Kit.Color.text
  row.amount.Text=if item then(if index==1 and not item.signed then tostring(item.amount)elseif item.amount<0 then "−"..tostring(-item.amount)else "+"..tostring(item.amount))else ""
  row.hair.Visible=item~=nil
  if item then shown=index end
 end
 if loss then
  local first=self.rows[1];first.name.Text="No Stars this round";first.name.TextColor3=Kit.Color.soft;first.hair.Visible=true
 end
 if self.compact then
  if not loss then
   local first=self.rows[1];first.name.Text="Total";first.amount.Text="★ "..tostring(data.total or 0)
   self.totalLabel.Text=data.multiplierLine or "Medium ×1";self.totalAmount.Text=""
  else self.totalLabel.Text="Total";self.totalAmount.Text="★ 0"end
  return
 end
 local y=self.rowTop+math.max(1,shown)*self.rowPitch+(if self.phone then 0 else 2)
 self.totalLabel.Position=UDim2.new(0,self.totalLabel.Position.X.Offset,0,y)
 self.totalAmount.Position=UDim2.new(0,self.totalAmount.Position.X.Offset,0,y)
 self.totalLabel.Visible,self.totalAmount.Visible=not loss,not loss
 self.totalLabel.Text="Total";self.totalAmount.Text=if data.pending then "…"else "★ "..tostring(data.total or 0)
end

-- Goals with their check stamps; an unmet goal can carry a "one more" hint.
function Results:paintGoals(data)
 local done,hintAt=0,nil
 local count=data.goals and #data.goals or 0
 for index,slot in ipairs(self.goals)do
  local goal=data.goals and data.goals[index]
  slot.check.root.Visible,slot.text.Visible=goal~=nil,goal~=nil
  if goal then
   if goal.done then done+=1 end
   local short=self.compact or(self.phone and self.payout.Size.X.Offset<200)
   slot.check.set(goal.done);slot.text.Text=if short then goal.short or goal.text else goal.text
   slot.text.TextColor3=if goal.done then Kit.Color.text else Kit.Color.soft
   if not goal.done and goal.hint and not hintAt then hintAt=index end
  end
 end
 self.goalsCount.Text=if count>0 then string.format("%d/%d",done,count)else ""
 if self.goalHint then
  local show=hintAt~=nil and not(self.phone and count>=3)
  self.goalHint.Visible=show
  if show then
   self.goalHint.Text=data.goals[hintAt].hint
   local y=self.goals[hintAt].text.Position.Y.Offset+(if self.phone then 20 else 26)
   self.goalHint.Position=UDim2.fromOffset(self.goalHint.Position.X.Offset,y)
   -- Later goals step down to make room.
   for index=hintAt+1,3 do
    local slot=self.goals[index];local base=(if self.phone then 34 else 48)+(index-1)*self.goalPitch+(if self.phone then 16 else 22)
    slot.text.Position=UDim2.fromOffset(slot.text.Position.X.Offset,base);slot.check.root.Position=UDim2.fromOffset(slot.check.root.Position.X.Offset,base+(if self.phone then 0 else 1))
   end
  else
   for index=1,3 do
    local slot=self.goals[index];local base=(if self.phone then 34 else 48)+(index-1)*self.goalPitch
    slot.text.Position=UDim2.fromOffset(slot.text.Position.X.Offset,base);slot.check.root.Position=UDim2.fromOffset(slot.check.root.Position.X.Offset,base+(if self.phone then 0 else 1))
   end
  end
 end
 if self.newBest and self.phone then
  -- Phone: under the goals; with three goals, beside the GOALS label.
  if count>=3 then self.newBest.root.Position=UDim2.fromOffset(76,8)
  else self.newBest.root.Position=UDim2.fromOffset(12,34+math.max(1,count)*self.goalPitch+(if self.goalHint and self.goalHint.Visible then 16 else 0))end
 end
end

-- Come-back strip (desktop) or the quest text (phone shortcut).
function Results:paintQuest(data)
 local quest=data.quest
 if self.phone or self.compact or not self.questTitle then return end
 if quest then
  self.questScope.Text=if quest.scope=="weekly"then "WEEKLY QUEST"else "DAILY QUEST"
  self.questTitle.Text=quest.title or "Quest"
  self.questMoved.Text=if quest.done then "Claim in the log"elseif(quest.moved or 0)>0 then "+"..quest.moved.." this round"else ""
  self.questBar.root.Visible=true;self.questBar.set(quest.count or 0,math.max(1,quest.target or 1),quest.done)
  self.questCountText.Text=string.format("%d/%d",quest.count or 0,quest.target or 0)
 else
  self.questScope.Text="QUESTS";self.questTitle.Text=data.strip or "Win a round to earn Stars"
  self.questMoved.Text="";self.questBar.root.Visible=false;self.questCountText.Text=data.questCount or ""
 end
end

-- Count-up paint. A nil sample means final values.
function Results:paintCount(sample)
 local data=self.data;if not data or not self.totalText then return end
 if self.compact then return self:paintCountCompact(sample)end
 local earned=data.earned or 0
 local shown=if sample and sample.counted then sample.counted else earned
 self.counting=sample~=nil
 local age=sample and sample.age
 local loss=data.loss and not data.pending
 -- Headline slam: scale 1.6 -> 1, tilt 8° -> -3° (up to the right).
 local e=if sample then backOut(sample.entrance)else 1
 self.headline.scale.Scale=1.6-.6*e;self.headline.root.Rotation=8+(-3-8)*e
 -- Goal stamps (90 ms apart) and payout rows (120 ms apart).
 for index,slot in ipairs(self.goals)do
  local p=if sample then Feedback.stagger(age,index,Feedback.GoalAt,Feedback.GoalGap,.12)else 1
  slot.scale.Scale=1.4-.4*p
 end
 for index,row in ipairs(self.rows)do
  local p=if sample then Feedback.stagger(age,index,Feedback.RowAt,Feedback.RowGap,.14)else 1
  row.name.TextTransparency=1-p;row.amount.TextTransparency=1-p
 end
 -- Count, unit, wallet and meter.
 self.totalText.Visible,self.countShadow.Visible,self.unit.Visible=not loss,not loss,not loss
 self.missText.Visible,self.warmText.Visible=loss,loss
 if loss then
  self.star.setMode("glass")
 else
  self.star.setMode("gold")
  local value=if data.pending then "Saving…"else "+"..tostring(shown)
  local size=math.floor(if data.pending then self.countSize*.5 else self.countSize)
  self.totalText.Text,self.countShadow.Text=value,value
  self.totalText.TextSize,self.countShadow.TextSize=size,size
 end
 local balance=data.balance or 0
 local shownBalance=if loss or data.pending then balance else balance-earned+shown
 self.wallet.set(shownBalance)
 self:paintMeter(shownBalance)
 if sample then
  local drop=sample.drop
  local starY=self.centre.starY-(1-bounceOut(drop))*self.centre.starSize*1.1
  self.star.root.Visible=age>=Feedback.DropAt
  self.star.root.Position=UDim2.fromOffset(self.centre.cx,starY)
  local f=sample.finale
  self.star.scale.Scale=1+.12*(sample.starPop or 0)+.08*math.sin(math.pi*f)
  -- 3D: spins at 360°/s from the landing, then the finale turns it two more
  -- times and stops facing front. 2D fallback: wobble, then a 720° planar spin.
  if f>0 then
   local from=(sample.finaleAt-Feedback.DropAt)*360;local to=math.ceil(from/360)*360+720
   self.star.setSpin(from+(to-from)*quintOut(f),-720*(1-quintOut(f)))
  else
   self.star.setSpin(math.max(0,age-Feedback.DropAt)*360,6*math.sin(age*14)*(1-drop*.5))
  end
  self.star.setRays((age*40)%360,math.sin(math.pi*f))
  self.countScale.Scale=1+.25*(sample.starPop or 0)
  self.totalText.TextColor3=if f>0 and f<1 then Color3.new(1,1,1):Lerp(Kit.Color.stars,f)else Kit.Color.stars
  self:paintMinis(sample)
  if f>0 and not self.finaleClock then self.finaleClock=os.clock()end
  if self.newBest then
   local b=sample.best
   self.newBest.root.Visible=data.newBest==true and not loss and b>0
   self.newBestScale.Scale=1.4-.4*backOut(b)
  end
  if self.hints then self.hints.Visible=false;self.skipHint.Visible=true end
 else
  self.star.root.Visible=true
  self.star.root.Position=UDim2.fromOffset(self.centre.cx,self.centre.starY)
  self.star.scale.Scale=1;self.star.setSpin(0,0);self.spinStart=os.clock();self.countScale.Scale=1
  self.totalText.TextColor3=Kit.Color.stars
  for _,mini in ipairs(self.minis)do mini.Visible=false end
  if self.newBest then self.newBest.root.Visible=data.newBest==true and not loss;self.newBestScale.Scale=1 end
  if self.hints then self.hints.Visible=true;self.skipHint.Visible=false end
  if self.wasCounting and not loss and not Kit.reduced()and not self.finaleClock then self.finaleClock=os.clock()end
 end
 self.wasCounting=self.counting
end
-- Mini Stars arc from the paying row into the big Star (180 ms each).
function Results:paintMinis(sample)
 -- From the first payout amount (authored coordinates of the card) to the Star.
 local card=self.payout
 local from=Vector2.new(card.Position.X.Offset+card.Size.X.Offset-24,card.Position.Y.Offset+self.rowTop+12)
 local to=Vector2.new(self.centre.cx,self.centre.starY)
 for _,mini in ipairs(self.minis)do mini.Visible=false end
 local spacing=sample.spacing or Feedback.CountStep
 for k=math.max(1,(sample.counted or 0)-5),(sample.total or 0)do
  local launch=Feedback.CountStart+(k-1)*spacing-Feedback.FlightSpan
  local q=(sample.age-launch)/Feedback.FlightSpan
  if q>=0 and q<1 then
   local mini=self.minis[(k-1)%#self.minis+1]
   local p=from:Lerp(to,quintOut(q))
   mini.Visible=true;mini.Position=UDim2.fromOffset(p.X,p.Y-math.sin(q*math.pi)*self.centre.starSize*.35)
   mini.Rotation=q*180
  end
 end
end
function Results:paintCountCompact(sample)
 local data=self.data
 local earned=data.earned or 0
 local shown=if sample and sample.counted then sample.counted else earned
 self.counting=sample~=nil
 if data.loss then self.totalText.Text="0 Stars";self.totalText.TextColor3=Kit.Color.soft;return end
 self.totalText.TextColor3=Kit.Color.stars
 self.totalText.Text=if data.pending then "Saving…"else string.format("+%d %s",shown,if shown==1 then "Star"else "Stars")
 self.wallet.set(data.balance or 0)
 if not sample and self.wasCounting and not Kit.reduced()then
  self.starScale.Scale=1.12;Kit.tween(self.starScale,.18,{Scale=1})
 end
 self.wasCounting=self.counting
end

-- Idle (2.7): Star turns and bobs, rays turn, a few sparkles, confetti falls
-- within 1.2 s, Replay pulses every 3 s. Off under Reduced Motion.
function Results:stopIdle()
 if self.idle then self.idle:Disconnect();self.idle=nil end
end
function Results:startIdle()
 self:stopIdle()
 if self.compact or not self.star then return end
 self.idleStart=os.clock()
 self.idle=RunService.RenderStepped:Connect(function()self:stepIdle()end)
end
function Results:stepIdle()
 if not self.visible or not self.star then self:stopIdle();return end
 local reduced=Kit.reduced()or(type(self.options.reduce)=="function"and self.options.reduce()==true)
 local now=os.clock();local t=now-(self.idleStart or now)
 local loss=self.data and self.data.loss and not self.data.pending
 local counting=self.feedback.active
 -- Confetti from the finale.
 local c=if self.finaleClock and not reduced then now-self.finaleClock else math.huge
 for index,piece in ipairs(self.confetti)do
  local on=c<1.2
  piece.Visible=on
  if on then
   local a=math.pi*(1.05+.9*hash(index,1))
   local speed=self.centre.starSize*(1.6+1.8*hash(index,2))
   local vx,vy=math.cos(a)*speed,math.sin(a)*speed-self.centre.starSize*.6
   local g=self.centre.starSize*3.2
   piece.Position=UDim2.fromOffset(self.centre.cx+vx*c,self.centre.starY+vy*c+.5*g*c*c)
   piece.Rotation=hash(index,3)*360+c*(if index%2==0 then 540 else -420)
   piece.BackgroundTransparency=math.clamp((c-.7)/.5,0,1)
  end
 end
 if c>=1.2 and self.finaleClock then self.finaleClock=nil end
 if counting then return end
 if reduced then
  -- Reduced Motion: the Star is still and faces front.
  self.star.setSpin(0,0);self.star.setRays(0,0)
  for _,spark in ipairs(self.twinkles)do spark.Visible=false end
  self.replayPulse.Scale=1
  return
 end
 -- Star: gold turns (gently, 2D) and bobs 4 px over 2 s; glass floats.
 local bob=math.sin(t*math.pi)*4*(self.centre.starSize/164)
 local float=if loss then -24*(self.centre.starSize/164)*(1-quintOut(math.clamp(t/.4,0,1)))else 0
 self.star.root.Position=UDim2.fromOffset(self.centre.cx,self.centre.starY+bob+float)
 -- Gentle idle turn: 40°/s about +Y (3D token) or a small planar sway (2D).
 if loss then self.star.setSpin(0,0)
 else self.star.setSpin(((now-(self.spinStart or now))*40)%360,5*math.sin(t*math.rad(40)*2))end
 if not loss then self.star.setRays((t*6)%360,0)end
 for index,spark in ipairs(self.twinkles)do
  local on=not loss or index<=3
  spark.Visible=on
  if on then
   local a=hash(index,4)*math.pi*2;local r=self.centre.starSize*(.62+.2*hash(index,5))
   spark.Position=UDim2.fromOffset(self.centre.cx+math.cos(a)*r,self.centre.starY+math.sin(a)*r*.8)
   C.fadeSparkle(spark,1-(.5+.5*math.sin(t*(2+index*.7)+index)))
  end
 end
 -- Replay idle pulse every 3 s once the count is done.
 local p=t%3
 self.replayPulse.Scale=if p>=2.7 then 1+.04*math.sin((p-2.7)/.3*math.pi)else 1
end

-- data: outcome("clear"|"overflow"|"missed"), title, difficulty, pending, earned,
-- rows{{name,amount,signed}}, total, balance, goals{{text,short,done,hint}}, score,
-- best, chain, newBest, tidy, level, headline, nudge, strip, stripRight,
-- eggName, eggCost, canHatch, quest{scope,title,count,target,moved,done},
-- petName, result (RecapFeedback observe record), loss, questDone, questCount
function Results:show(data,compact)
 local opening=not self.visible
 if not self.root or self.key~=Results.viewKey(compact)then self:build(compact)end
 self.data=data;self.visible=true;self.host.Parent.Visible=true
 local loss=data.loss and not data.pending
 -- Headline and subline.
 local headline,missed=Results.headline(data)
 headline=data.headline or headline
 local accent=Kit.color("accent");local grey=Color3.fromHex("#8C949D")
 self.headline.set(headline,if missed then grey else accent,if missed then grey else accent)
 self.subline.Text=(data.title or "Round").."  ·  "..(data.difficulty or "Medium")
 self:paintRows(data)
 if self.saved then self.saved.Text=if data.pending then "Saving…"else "Saved to your wallet";self.saved.Visible=not self.phone and not self.compact and not loss end
 if self.nudge then self.nudge.Text=data.nudge or "";self.nudge.Position=UDim2.fromOffset(18,if loss then 92 else 214)end
 if self.saved and not self.phone and not self.compact then self.saved.Position=UDim2.fromOffset(18,240)end
 self:paintGoals(data)
 if self.warmText then
  self.warmText.Text=Results.warmLine(data.petName or "Bear",data.result and data.result.sequence or 0)
 end
 if self.phone then self:paintPhone(data)
 elseif not self.compact then
  self.metrics[1].Text=commas(data.score);self.metrics[2].Text=commas(data.best);self.metrics[3].Text="×"..tostring(data.chain or 0)
  self:paintQuest(data)
  self.hintRight.Text="Replay keeps "..(data.difficulty or "Medium")..". Up on Replay changes difficulty."
  self:placeButtons(data.canHatch==true)
 end
 -- Pending save: Replay and Hatch disabled, Replay reads Saving…, focus to Leave.
 Kit.setEnabled(self.replay,not data.pending);Kit.setText(self.replay,if data.pending then "Saving…"elseif loss then "Try again"else "Replay")
 Kit.setEnabled(self.leave,data.canLeave~=false)
 if self.difficulty then Kit.setEnabled(self.difficulty,not data.pending)end
 if self.hatch then Kit.setEnabled(self.hatch,not data.pending)end
 if data.pending then self.focus=2 elseif opening then self.focus=1 end
 if self.focus==5 and not self:hatchShown()then self.focus=1 end
 if opening and not Kit.reduced()then
  self.root.Position=UDim2.fromOffset(0,12);Kit.tween(self.root,Kit.Motion.screen,{Position=UDim2.new()})
 end
 self:paintFocus()
 -- Cues: entrance beats for this result, then the clock.
 if not self.compact then
  local beats={}
  for index=1,(data.goals and #data.goals or 0)do table.insert(beats,{at=Feedback.GoalAt+(index-1)*Feedback.GoalGap,cue="goal_tick",pitch=1+(index-1)*.06,volume=.3})end
  for index=1,math.min(#self.rows,data.rows and #data.rows or 0)do table.insert(beats,{at=Feedback.RowAt+(index-1)*Feedback.RowGap,cue="row_flip",volume=.25})end
  if data.newBest then table.insert(beats,{at=.2,cue="new_best",finale=true,volume=.4})end
  if data.canHatch then table.insert(beats,{at=.3,cue="egg_ready",finale=true,volume=.4})end
  self.feedback:setBeats(beats)
 else self.feedback:setBeats({})end
 if data.result then self.feedback:observe(data.result,true)end
 local audio=self.options.audio
 if opening and audio and audio.play then
  if loss then audio:play("lose",1,.4);audio:play("meter_fill",1,.25)
  elseif self.feedback.active then audio:play("win",1,.5)
  elseif not data.pending and Kit.reduced()then audio:play("stars_total",1,.4)end
 end
 if not self.feedback.active then self:paintCount(nil)end
 -- Missed round entrance (2.7): the glass Star floats in (idle clock); no count.
 if opening and loss and self.star and not Kit.reduced()then
  self.star.scale.Scale=.85;Kit.tween(self.star.scale,.4,{Scale=1},Enum.EasingStyle.Back)
 end
 if opening then self:startIdle()end
end

-- Phone extras: metrics, NEW BEST, difficulty bars and the shortcut cell
-- (Hatch when affordable, else a claim, else the quest this round moved).
function Results:paintPhone(data)
 local values={SCORE=commas(data.score),BEST=commas(data.best),CHAIN="×"..tostring(data.chain or 0)}
 for index,name in ipairs(self.metricNames)do self.metrics[index].Text=values[name]end
 local level=data.level or 2
 local tone=if level==1 then Kit.Color.good elseif level==3 then Kit.Color.danger else Kit.Color.stars
 for index,bar in ipairs(self.diffBars)do bar.BackgroundColor3=tone;bar.BackgroundTransparency=if index<=level then 0 else .75 end
 local q=self.questButton;local w=q.Size.X.Offset
 local hatch=data.canHatch==true
 self.hatch.Visible=hatch;q.Visible=not hatch
 if hatch then
  Kit.setText(self.hatch,if w>=200 then "Hatch "..(data.eggName or "egg")else "Hatch")
 end
 self.questChip.root.Visible=false;self.questIcon.Visible=true
 if hatch then
  self.questTarget=nil
 elseif data.questDone then
  self.questTarget="claim"
  Kit.paint(q,"BackgroundColor3",function()return Kit.color("well"):Lerp(Kit.Color.stars,.06)end);q.BackgroundTransparency=0
  self.questStroke.Thickness,self.questStroke.Transparency=1.5,0;Kit.paint(self.questStroke,"Color","stars")
  self.questIcon.ImageRectOffset=require(script.Parent.DeckAssets).Icon.check;Kit.paint(self.questIcon,"ImageColor3","stars")
  if w<200 then self.questText.Text="Claim 1 quest";self.questText.Size=UDim2.fromOffset(w-50,48)
  else self.questText.Text=data.questDone;self.questChip.root.Visible=true;self.questText.Size=UDim2.fromOffset(w-50-80,48)end
  Kit.paint(self.questText,"TextColor3","text");Kit.setFontRole(self.questText,"Strong")
 else
  self.questTarget="log"
  Kit.paint(q,"BackgroundColor3","raised");q.BackgroundTransparency=1
  self.questStroke.Thickness,self.questStroke.Transparency=1,.86;self.questStroke.Color=Color3.new(1,1,1)
  self.questIcon.ImageRectOffset=require(script.Parent.DeckAssets).Icon.quests;Kit.paint(self.questIcon,"ImageColor3","text")
  local quest=data.quest
  self.questText.Text=if quest then string.format("%s %d/%d",quest.title or "Quest",quest.count or 0,quest.target or 0)else "Quests "..(data.questCount or "")
  self.questText.Size=UDim2.fromOffset(w-50,48)
  Kit.paint(self.questText,"TextColor3","text");Kit.setFontRole(self.questText,"Strong")
 end
 if self.questTarget then self.questText.Position=UDim2.fromOffset(40,0)end
 q.Active=self.questTarget~=nil;q:SetAttribute("AccessibleLabel",if self.questTarget then self.questText.Text else nil)
 if self.focus==4 and not self.questTarget then self.focus=if hatch then 5 else 1 end
end

function Results:hide()
 if not self.visible then return end
 self.visible=false;self.feedback:cancel();if self.ring then self.ring.hide()end
 self:stopIdle();self.finaleClock=nil
 if self.confetti then for _,piece in ipairs(self.confetti)do piece.Visible=false end end
 self.host.Parent.Visible=false
end

-- Left/right through the order; disabled targets are skipped while saving.
function Results:move(direction)
 if not self.visible then return false end
 local target
 local pending=self.data and self.data.pending
 local order
 if self.phone then order=Results.order(true,self:hatchShown(),self.questTarget~=nil)
 elseif self.compact then order={1,2}
 else order=Results.order(false,self:hatchShown(),false)end
 local at=table.find(order,self.focus)or 1
 local function blocked(index)return pending and(index==1 or index==3 or index==5)end
 local step=at
 repeat
  local nextAt=math.clamp(step+direction,1,#order)
  if nextAt==step then break end
  step=nextAt
 until not blocked(order[step])
 target=if blocked(order[step])then self.focus else order[step]
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
 if index==5 and not button.Visible then return end
 local state=Kit.buttonState(button);if not state or not state.enabled then return end
 Kit.pulse(button)
 local cb=self.callbacks[({"replay","leave","picker",nil,"hatch"})[index]]
 if cb then cb()end
end
function Results:back()
 if not self.visible then return false end
 self.focus=2;self:paintFocus();self:activate(2);return true
end
return Results
