-- Results content in the existing device's exact three LCD regions. This module
-- owns no wallet write, camera, shell, viewport size or transaction clock.
-- Beta 12 QA U7 (DASH-DECK-UI-LOOK), only while DeckLook.on() (the beta and Studio): the See you tomorrow strip (v2)
-- across the whole LCD under the panes, which give up 54 pt for it; the payout restyled (rows at 22, stat gains as
-- coloured rows with a level pill); in the stack layout the four actions compacted to 128 pt (Replay, Difficulty,
-- Hatch | Leave) with their own gamepad moves (DeckResultsLayout). Off: every path below is the one before.
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Copy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local C=require(script.Parent.CelebrationKit)
local Balls=require(Shared.BallThemes)
local Look=require(Shared.DeckLook)
local Layout=require(script.Parent.DeckResultsLayout)
local StatCatalog=require(Shared.StatCatalog)
local View={};View.__index=View
local ORDER={1,3,5,2} -- Replay, difficulty, Hatch eggs, Back to garden.
local function text(parent,name,value,size,color)
 local t=Kit.text(parent,"BodyMedium",value,color or "text",{Name=name,TextSize=size or 14,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
 t.Size=UDim2.new(1,-16,0,24);return t
end
local function pane(parent,name,r)
 local clip=Instance.new("CanvasGroup");clip.Name=name;clip.BackgroundTransparency=.05;clip.BorderSizePixel=0
 clip.Position=UDim2.fromOffset(r.x,r.y);clip.Size=UDim2.fromOffset(r.w,r.h);clip.ClipsDescendants=true;clip.ZIndex=parent.ZIndex+1;clip.Parent=parent
 Kit.corner(clip,10);Kit.stroke(clip,nil,1,.75)
 Kit.paint(clip,"BackgroundColor3","raised") -- Toy Shell: a tray on the LCD glass; bound once parented, so it takes the plate's glass (QA v760)
 return clip
end
local function scroll(parent,name)
 local s=Instance.new("ScrollingFrame");s.Name=name;s.BackgroundTransparency=1;s.BorderSizePixel=0;s.Size=UDim2.fromScale(1,1)
 s.ScrollBarThickness=3;s.ScrollingDirection=Enum.ScrollingDirection.Y;s.CanvasSize=UDim2.new();s.AutomaticCanvasSize=Enum.AutomaticSize.Y;s.ZIndex=parent.ZIndex+1;s.Parent=parent
 return s
end
local function labelAt(parent,name,value,size,color,x,y,w,h)
 local t=text(parent,name,value,size,color);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
-- QA v735 D6 (results polish). Layout:
--   Payout (left): an eyebrow, one row per award with its amount in a right-hand column,
--     a rule, the total, today's line, and the wallet chip pinned at the foot (it counts
--     up with the payout; it used to sit on top of the headline's band).
--   Star (middle): the slanted display headline (CelebrationKit.banner, the old WIN font),
--     the round's name, the 3D Star turning all the way round, the count, the saved line.
--   Goals (right): every goal on its own short row with the round's numbers under them,
--     above a 2 x 2 action grid (a 4-high stack left room for one goal). Narrow columns
--     keep the scrolling stack.
-- The three panes share one top and one height when the device gives them the same
-- column height (the middle one used to be the taller board rect).
View.Entry={dim=.22,middle={.04,.30},left={.12,.30},right={.18,.30},headline={.20,.32},star={.14,.44},rise=12,slide=14}
-- The display headline without CelebrationKit.banner's speed lines: in a phone's narrow
-- Star column the lines took half the width and the words shrank to 11 px. Same display
-- face, same gold drop shadow, same 3 degree slant; `set` sizes the box to the words.
local function headline(parent,size)
 local root=Kit.frame(parent,"Headline",nil,UDim2.new(),UDim2.fromOffset(10,10));root.AnchorPoint=Vector2.new(.5,.5);root.Rotation=-3
 local scale=Kit.node("UIScale",root,{Scale=1})
 local shadow=C.display(root,"",size,C.Gold,{Name="Shadow",TextXAlignment=Enum.TextXAlignment.Center})
 local main=C.display(root,"",size,C.White,{Name="Line",TextXAlignment=Enum.TextXAlignment.Center});main.ZIndex=shadow.ZIndex+1
 local api={root=root,scale=scale,label=main,shadow=shadow}
 function api.set(value,_,shadowColor)
  main.Text,shadow.Text=value,value
  local w=C.measure(value,size).X+8;local h=size+8
  local drop=math.max(2,math.floor(size*.08))
  root.Size=UDim2.fromOffset(w+drop,h+drop)
  main.Position,main.Size=UDim2.new(),UDim2.fromOffset(w,h)
  shadow.Position,shadow.Size=UDim2.fromOffset(drop,drop),UDim2.fromOffset(w,h)
  shadow.TextColor3=shadowColor or C.Gold
 end
 return api
end
function View.new(owner,v)
 local self=setmetatable({owner=owner,view=v,buttons={},opened=os.clock()},View)
 local root=Instance.new("Frame");root.Name="InPlaceResults";root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.BorderSizePixel=0;root.ClipsDescendants=true;root.ZIndex=50;root.Parent=owner.host;self.root=root;Kit.paint(root,"BackgroundColor3","well")
 local l,r=v.left,v.right
 local m=if l.h==r.h and l.y==r.y then{x=v.center.x,y=l.y,w=v.center.w,h=l.h}else v.center
 -- U7 (v3): with the strip on, the panes give up its row and the strip runs under all three.
 self.v3=Look.on()
 self.stripOn=self.v3 and owner.tomorrowModel~=nil and owner:tomorrowModel()~=nil
 if self.v3 then
  local panes=Layout.panes(l,m,r,self.stripOn)
  l,m,r=panes.left,panes.middle,panes.right
  self.stripBox=panes.strip
 end
 self.regions={left=l,right=r,middle=m}
 self.left=pane(root,"PayoutRegion",l);self.right=pane(root,"OutcomeRegion",r);self.middle=pane(root,"StarRegion",m)
 self.payout=scroll(self.left,"PayoutRows");self.goals=scroll(self.right,"Goals")
 -- Actions: a 2 x 2 grid when two 44 px buttons fit side by side, else the stack.
 self.grid=r.w>=176 and r.h>=2*44+4+12+70
 local actionHeight=if self.grid then 2*44+4 else 4*44+3*4
 self.scrollActions=not self.grid and r.h<actionHeight+68
 -- U7 (v3): the stack compacted to 128 pt (164 when Hatch and Leave cannot share a row).
 if self.v3 and not self.grid then
  self.compact=Layout.actions(r.w,{Copy.get("results.inPlace.hatchShort"),Copy.get("results.leave.narrow")},function(value,size)return Kit.measure(value,"Button",size).X end)
  actionHeight=self.compact.total
  self.scrollActions=false
 end
 self.actions=self.scrollActions and scroll(self.right,"ResultActions")or Instance.new("Frame")
 if not self.scrollActions then
  self.actions.Name="ResultActions";self.actions.BackgroundTransparency=1;self.actions.BorderSizePixel=0;self.actions.ZIndex=self.right.ZIndex+2;self.actions.Parent=self.right
  self.actions.Position=UDim2.fromOffset(6,r.h-actionHeight-6);self.actions.Size=UDim2.fromOffset(r.w-12,actionHeight)
  self.goals.Size=UDim2.new(1,0,0,r.h-actionHeight-12)
  -- QA v751 P1 follow-up: the fitted phone shell left this pane 14 px shorter (263 px on a
  -- 750x402 phone), which cut the second goal off above the four-button stack. A pane with
  -- room for under two full rows closes the title and row spacing so both goals show.
  self.tightGoals=r.h-actionHeight-12<78
 else
  self.goals.Size=UDim2.new(1,0,0,math.min(64,r.h*.35))
  self.actions.Position=UDim2.new(0,0,0,math.min(64,r.h*.35)+4);self.actions.Size=UDim2.new(1,0,1,-math.min(64,r.h*.35)-4)
 end
 -- Payout: rows scroll above the pinned wallet chip.
 local pad=10
 self.amountWidth=44
 -- v3 (FABLE-REVIEW-R1 8): the rows stop 42 above the pane's bottom and the chip sits 8 above it, so nothing
 -- draws under the chip (Studio check beta 12: the chip covered the Energy row).
 self.payout.Size=UDim2.new(1,0,1,if self.v3 then -Layout.payoutFoot()else -34)
 self.payoutTitle=labelAt(self.payout,"Payout","Payout",12,"soft",pad,8,l.w-2*pad,16)
 self.rows={};self.amounts={}
 for i=1,4 do
  self.rows[i]=labelAt(self.payout,"Row"..i,"",13,"text",pad,30+(i-1)*26,l.w-2*pad-self.amountWidth-4,22)
  local amount=labelAt(self.payout,"Amount"..i,"",13,"text",l.w-pad-self.amountWidth,30+(i-1)*26,self.amountWidth,22)
  amount.TextXAlignment=Enum.TextXAlignment.Right;amount.TextWrapped=false;self.amounts[i]=amount
 end
 self.rule=Kit.frame(self.payout,"Rule","text",UDim2.fromOffset(pad,134),UDim2.fromOffset(l.w-2*pad,1));self.rule.BackgroundTransparency=.8
 self.total=labelAt(self.payout,"Total","",16,"stars",pad,140,l.w-2*pad,24)
 self.today=labelAt(self.payout,"Today","",12,"soft",pad,166,l.w-2*pad,18)
 -- v2 S3: the round's stat gains under today's line, one stat a line in its colour.
 self.statsTitle=labelAt(self.payout,"StatsTitle",Copy.get("stats.results.label"),12,"soft",pad,190,l.w-2*pad,16)
 self.statsGains=labelAt(self.payout,"StatsGains","",12,"text",pad,208,l.w-2*pad,18);self.statsGains.RichText=true
 -- QA v751 P5: the 28 px chip (Kit.WalletSpec[28]) carries the 3D WalletStar; the 20 px one
 -- had an 11 px Star, under WalletStar.MinSize, so it stayed a flat glyph.
 self.wallet=Kit.wallet(self.left,28);self.wallet.root.AnchorPoint=Vector2.new(0,1)
 self.wallet.root.Position=UDim2.fromOffset(pad,l.h-(if self.v3 then Layout.WalletBottom else 4))
 -- Goals.
 self.goalLabels={}
 self.goalTitle=labelAt(self.goals,"GoalTitle","Goals",12,"soft",pad,if self.tightGoals then 4 else 8,r.w-2*pad,16)
 for i=1,3 do self.goalLabels[i]=labelAt(self.goals,"Goal"..i,"",13,"text",pad,28+(i-1)*24,r.w-2*pad,22)end
 self.metrics=labelAt(self.goals,"Metrics","",12,"soft",pad,104,r.w-2*pad,32)
 local names={[1]="Replay",[3]="Difficulty",[5]="Hatch eggs",[2]="Back to garden"}
 local cell=math.floor((r.w-12-4)/2)
 for i,id in ipairs(ORDER)do
  local size=if self.grid then Vector2.new(cell,44)else Vector2.new(math.max(44,r.w-12),44)
  local button
  local row=self.compact and self.compact.rows[id]
  if row then
   -- U7 (v3): Replay primary at 15; the cream keys with a 3 pt lip, radius 10, at 13 (or 11 to fit a half).
   button=Kit.button(self.actions,"Action"..id,{text=names[id],size=Vector2.new(row.w,row.h),textSize=if id==1 then 15 else self.compact.textSize,selectable=false,
    variant=if id==1 then "primary"else nil,lip=if id==1 then nil else 3,radius=if id==1 then nil else 10,compact=true})
   button.Position=UDim2.fromOffset(row.x,row.y)
   if id==3 then
    -- Difficulty steps: a soft chevron 12 pt in from each side.
    for side,glyph in pairs({[-1]="‹",[1]="›"})do
     local mark=Kit.text(button,"Strong",glyph,"soft",{Name="Step",AnchorPoint=Vector2.new(if side<0 then 0 else 1,.5),
      Position=UDim2.new(if side<0 then 0 else 1,side*-12,.5,0),Size=UDim2.fromOffset(12,row.h),TextSize=18,TextXAlignment=Enum.TextXAlignment.Center})
     mark.TextColor3=Color3.fromHex("#4A4972");mark.ZIndex=button.ZIndex+6;Kit.fixedText(mark)
    end
   end
  else
   button=Kit.button(self.actions,"Action"..id,{text=names[id],size=size,textSize=if self.grid or r.w<150 then 13 else 15,selectable=false,variant=if id==1 then "primary"else nil})
   button.Position=if self.grid then UDim2.fromOffset(((i-1)%2)*(cell+4),math.floor((i-1)/2)*48)else UDim2.fromOffset(self.scrollActions and 6 or 0,(i-1)*48)
  end
  button:SetAttribute("ResultAction",id)
  self.buttons[id]=button
  button.Activated:Connect(function()owner.focus=id;self:paintFocus();self:activate(id)end)
 end
 -- Star column: headline, round name, Star, count, saved line.
 local narrow=m.w<180
 self.headlineSize=if narrow then 24 else 30
 self.headline=if narrow then headline(self.middle,self.headlineSize)else C.banner(self.middle,{size=self.headlineSize,rotation=-3})
 -- U7 (v3) with the strip on: the headline, name and Star's band move up so the Star stays about 80 pt.
 local tight=self.stripOn and narrow
 self.headline.root.Position=UDim2.fromOffset(math.floor(m.w/2),if tight then 26 elseif narrow then 28 else 36)
 self.title=self.headline.label -- the headline's own label (specs and callers read .Text)
 self.subtitle=labelAt(self.middle,"RoundTitle","",12,"soft",8,if tight then 46 elseif narrow then 50 else 64,m.w-16,18);self.subtitle.TextXAlignment=Enum.TextXAlignment.Center;self.subtitle.TextWrapped=false;self.subtitle.TextTruncate=Enum.TextTruncate.AtEnd
 local top=if tight then 58 elseif narrow then 70 else 86
 local foot=if tight then 52 elseif narrow then 64 else 76
 local starSize=math.max(36,math.min(m.w*.62,(m.h-top-foot)*.78,128))
 self.star=C.star(self.middle,starSize,{mesh=owner.options.starMesh~=false,cleanMaterial=true})
 self.star.root.Position=UDim2.fromOffset(math.floor(m.w/2),math.floor(top+(m.h-top-foot)/2))
 self.face=owner.buildStarFace(self.star,starSize)
 self.count=labelAt(self.middle,"RewardCount","",if narrow then 24 else 32,"stars",6,m.h-foot+4,m.w-12,34);self.count.TextXAlignment=Enum.TextXAlignment.Center;self.count.TextWrapped=false
 self.saved=labelAt(self.middle,"Saved","",12,"soft",8,m.h-26,m.w-16,18);self.saved.TextXAlignment=Enum.TextXAlignment.Center
 root.Destroying:Connect(function()self:hide()end)
 self.ring=Kit.focusRing(owner.host)
 return self
end
function View:reduced()
 local value=self.owner.options.reduce
 return(type(value)=="function"and value()==true)or value==true or Kit.reduced()
end
-- U7 (v3): the payout pane restyled. Rows at 22, the total in Stars, today's line only without the strip, the stat
-- gains as rows (a dot and the name in the stat's colour, the gain, a "Lv n" pill on a level-up); the strip under all
-- three panes.
function View:paintPayoutV3(data,pad,lw)
 self.payoutTitle.Text=string.upper(self.payoutTitle.Text);self.payoutTitle.TextSize=11;self.payoutTitle.Position=UDim2.fromOffset(pad,8)
 local nameWidth=lw-2*pad-self.amountWidth-4
 -- Beta 14 B6: the blocks fitted to the scroll window (Layout.payoutPlan): tighter rows and gaps, then stats two to a
 -- line, so nothing is cut at the window's foot (shot 5: the second stat sat under the edge).
 local shown=0;for i=1,#self.rows do if data.rows and data.rows[i]then shown+=1 end end
 local noStars=not data.pending and(data.earned or 0)==0
 local plan=Layout.payoutPlan(lw,self.regions.left.h,shown,#(data.stats or {}),{noStars=noStars,today=not self.stripOn})
 self.payoutPlan=plan
 local y=28
 for i,row in ipairs(self.rows)do
  local item=data.rows and data.rows[i]
  local amount=self.amounts[i]
  row.Visible=item~=nil;amount.Visible=item~=nil
  if item then
   row.Text=item.name
   amount.Text=(if item.signed then "+"else "")..tostring(item.amount)
   local height=math.max(plan.row,math.ceil(Kit.measure(row.Text,"BodyMedium",row.TextSize,nameWidth).Y*row.LineHeight)+2)
   row.Position=UDim2.fromOffset(pad,y);row.Size=UDim2.fromOffset(nameWidth,height)
   amount.Position=UDim2.fromOffset(lw-pad-self.amountWidth,y);amount.Size=UDim2.fromOffset(self.amountWidth,plan.row)
   y+=height
  end
 end
 if not data.pending and(data.earned or 0)==0 then
  self.rows[1].Visible=true;self.rows[1].Text=Copy.get("results.inPlace.noStars");self.rows[1].Size=UDim2.fromOffset(lw-2*pad,40)
  self.amounts[1].Visible=false;y=28+44
 end
 self.rule.Position=UDim2.fromOffset(pad,y+2);self.rule.Size=UDim2.fromOffset(lw-2*pad,1)
 self.total.Position=UDim2.fromOffset(pad,y+8);self.total.TextSize=15
 self.total.Text=Copy.get("results.inPlace.total",{count=if data.pending then "…"else data.total or data.earned or 0})
 y+=plan.total
 self.today.Visible=not self.stripOn
 if self.today.Visible then
  self.today.Position=UDim2.fromOffset(pad,y);self.today.Text=Copy.get("results.today.line",{count=data.todayEarned or 0});y+=18
 end
 self.statsTitle.Visible=false;self.statsGains.Visible=false
 local parts=data.stats or {}
 self.statRows=self.statRows or {}
 y+=plan.gap
 local paired=plan.perLine==2
 local half=plan.half
 local top=y
 for i=1,math.max(#parts,#self.statRows)do
  local part=parts[i]
  local row=self.statRows[i]
  if part and not row then
   local frame=Kit.frame(self.payout,"StatGain"..i,nil,UDim2.new(),UDim2.fromOffset(lw-2*pad,18))
   local dot=Kit.frame(frame,"Dot",nil,UDim2.fromOffset(0,4),UDim2.fromOffset(10,10),999);dot.BackgroundTransparency=0
   local name=Kit.text(frame,"BodyMedium","","text",{Name="Name",Position=UDim2.fromOffset(16,0),Size=UDim2.fromOffset(lw-2*pad-16,18),TextSize=12,
    TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
   local gain=Kit.text(frame,"Strong","","text",{Name="Gain",Position=UDim2.fromOffset(16,0),Size=UDim2.fromOffset(40,18),TextSize=12,TextWrapped=false});Kit.fixedText(gain)
   local pill=Kit.frame(frame,"LevelUp",nil,UDim2.new(0,0,.5,0),UDim2.fromOffset(34,14),999);pill.AnchorPoint=Vector2.new(0,.5);pill.BackgroundTransparency=0
   local lv=Kit.text(pill,"Title","","text",{Size=UDim2.fromScale(1,1),TextSize=10,TextXAlignment=Enum.TextXAlignment.Center});Kit.fixedText(lv)
   lv.TextColor3=Color3.fromHex("#15143A")
   row={frame=frame,dot=dot,name=name,gain=gain,pill=pill,lv=lv}
   self.statRows[i]=row
  end
  if row then
   row.frame.Visible=part~=nil
   if part then
    local stat=StatCatalog.ById[part.id]
    local color=stat and stat.color or Color3.new(1,1,1)
    row.frame.Position=UDim2.fromOffset(pad,y)
    row.frame.Size=UDim2.fromOffset(lw-2*pad,18)
    row.dot.BackgroundColor3=color
    row.name.Text=Copy.get("stats.name."..part.id);row.name.TextColor3=color
    row.gain.Text="+"..tostring(part.gain or 0);row.gain.TextColor3=Color3.new(1,1,1)
    local up=part.up==true and type(part.level)=="number"
    local nameW=math.ceil(Kit.measure(row.name.Text,"BodyMedium",12).X)
    local gainW=math.ceil(Kit.measure(row.gain.Text,"Strong",12).X)+1
    if paired then
     -- Beta 14 B6: two to a line; the name gives way (its colour is the dot's), a level-up's disc takes the dot's place.
     local col=(i-1)%2
     row.frame.Position=UDim2.fromOffset(pad+col*(half+Layout.Payout.pairGap),top+((i-1)//2)*Layout.Payout.stat)
     row.frame.Size=UDim2.fromOffset(half,18)
     local g=Layout.pairedStat(half,gainW,up)
     row.dot.Visible=not up;row.dot.Position=UDim2.fromOffset(g.mark.x,4)
     row.name.Visible=false
     row.gain.Position=UDim2.fromOffset(g.gain.x,0);row.gain.Size=UDim2.fromOffset(g.gain.w,18)
     row.pill.Visible=up
     if up then
      row.pill.BackgroundColor3=color
      row.pill.Position=UDim2.new(0,g.mark.x,.5,0);row.pill.Size=UDim2.fromOffset(g.mark.w,14)
      row.lv.Text=tostring(part.level)
     end
     if col==1 or i==#parts then y=top+(((i-1)//2)+1)*Layout.Payout.stat end
    else
    -- Studio check beta 12: placed by Layout.statRow, so the level never covers the gain (a disc on a narrow pane).
    local g=Layout.statRow(lw,pad,nameW,gainW,up)
    row.dot.Visible=true;row.dot.Position=UDim2.fromOffset(g.dot.x,4)
    row.name.Position=UDim2.fromOffset(g.name.x,0);row.name.Size=UDim2.fromOffset(g.name.w,18);row.name.Visible=g.name.w>0
    row.gain.Position=UDim2.fromOffset(g.gain.x,0);row.gain.Size=UDim2.fromOffset(g.gain.w,18)
    row.pill.Visible=up
    if up then
     row.pill.BackgroundColor3=color
     row.pill.Position=UDim2.new(0,g.pill.x,.5,0);row.pill.Size=UDim2.fromOffset(g.pill.w,14)
     row.lv.Text=if g.disc then tostring(part.level)else Copy.get("bond.short",{count=part.level})
    end
    y+=18
    end
   end
  end
 end
 -- Beta 14 B6: still over the window (a very short pane): it scrolls, with a 12 pt fade at the window's foot as the cue.
 if not self.payoutFade then
  local fade=Instance.new("Frame");fade.Name="PayoutFade";fade.BorderSizePixel=0;fade.Active=false;fade.ZIndex=self.payout.ZIndex+2
  local gradient=Instance.new("UIGradient");gradient.Rotation=90;gradient.Transparency=NumberSequence.new(1,0);gradient.Parent=fade
  fade.Parent=self.left;self.payoutFade=fade
 end
 self.payoutFade.Visible=plan.overflow==true
 self.payoutFade.BackgroundColor3=self.left.BackgroundColor3
 self.payoutFade.Position=UDim2.fromOffset(0,math.max(0,self.regions.left.h-Layout.payoutFoot()-12));self.payoutFade.Size=UDim2.new(1,0,0,12)
 -- The strip under the three panes (the panes made room for it when the results opened).
 local tomorrow=self.owner:tomorrowModel()
 if tomorrow and self.stripBox then
  local fresh=self.tomorrow==nil
  if fresh then self.tomorrow=require(script.Parent.TomorrowStrip).new(self.root,{phone=true,z=self.root.ZIndex+3,source=function()return self.owner:tomorrowModel()end,reduced=function()return self:reduced()end})end
  local box=self.stripBox
  self.tomorrow.root.Position=UDim2.fromOffset(box.x,box.y)
  self.tomorrow:set(tomorrow,box.w)
  if fresh then self.tomorrow:enter(self.owner.TomorrowDelay or 1,self:reduced())end
 elseif self.tomorrow then self.tomorrow:destroy();self.tomorrow=nil end
end
function View:paint(data)
 self.data=data
 local headline,missed=self.owner.headline(data)
 -- The display headline: gold for a win, grey for a missed round; scaled to its column.
 local accent=if missed then Kit.color("soft")else C.Gold
 self.headline.set(data.headline or headline,accent,accent)
 self.headlineFit=math.min(1,(self.regions.middle.w-8)/math.max(1,self.headline.root.Size.X.Offset))
 self.subtitle.Text=data.title or "Round"
 self.wallet.set(data.balance or 0)
 local pad=10;local lw=self.view.left.w
 if self.v3 then self:paintPayoutV3(data,pad,lw)else
 local nameWidth=lw-2*pad-self.amountWidth-4
 local y=30
 for i,row in ipairs(self.rows)do
  local item=data.rows and data.rows[i]
  local amount=self.amounts[i]
  row.Visible=item~=nil;amount.Visible=item~=nil
  if item then
   row.Text=item.name
   amount.Text=(if item.signed then "+"else "")..tostring(item.amount)
   local height=math.max(22,math.ceil(Kit.measure(row.Text,"BodyMedium",row.TextSize,nameWidth).Y*row.LineHeight)+4)
   row.Position=UDim2.fromOffset(pad,y);row.Size=UDim2.fromOffset(nameWidth,height)
   amount.Position=UDim2.fromOffset(lw-pad-self.amountWidth,y);amount.Size=UDim2.fromOffset(self.amountWidth,22)
   y+=height+6
  end
 end
 if not data.pending and(data.earned or 0)==0 then
  self.rows[1].Visible=true;self.rows[1].Text=Copy.get("results.inPlace.noStars");self.rows[1].Size=UDim2.fromOffset(lw-2*pad,40)
  self.amounts[1].Visible=false;y=30+46
 end
 self.rule.Position=UDim2.fromOffset(pad,y);self.rule.Size=UDim2.fromOffset(lw-2*pad,1)
 self.total.Position=UDim2.fromOffset(pad,y+8);self.total.Text=Copy.get("results.inPlace.total",{count=if data.pending then "…"else data.total or data.earned or 0})
 self.today.Position=UDim2.fromOffset(pad,y+36);self.today.Text=Copy.get("results.today.line",{count=data.todayEarned or 0})
 local parts=data.stats or {}
 self.statsTitle.Visible=#parts>0;self.statsGains.Visible=#parts>0
 if #parts>0 then
  local Toasts=require(script.Parent.StatToasts)
  local lines={}
  for _,part in ipairs(parts)do table.insert(lines,Toasts.resultsRich({part}))end
  self.statsTitle.Position=UDim2.fromOffset(pad,y+60)
  self.statsGains.Text=table.concat(lines,"\n");Kit.localizeRich(self.statsGains)
  self.statsGains.Position=UDim2.fromOffset(pad,y+78);self.statsGains.Size=UDim2.fromOffset(lw-2*pad,#parts*17+4)
 end

 -- Onboarding v3 slice E: the See you tomorrow strip at the foot of the payout rows (they scroll, so it never sits
 -- over the near-miss item or the buttons); a narrow pane, so the short values.
 local tomorrow=self.owner:tomorrowModel()
 if tomorrow then
  local fresh=self.tomorrow==nil
  if fresh then self.tomorrow=require(script.Parent.TomorrowStrip).new(self.payout,{phone=true,short=true,source=function()return self.owner:tomorrowModel()end,reduced=function()return self:reduced()end})end
  -- Placed and drawn first: enter() tweens back to where the strip is now, and fades the chips it has.
  local sy=if #parts>0 then y+78+#parts*17+12 else y+64
  self.tomorrow.root.Position=UDim2.fromOffset(pad,sy+8)
  self.tomorrow:set(tomorrow,lw-2*pad)
  if fresh then self.tomorrow:enter(self.owner.TomorrowDelay or 1,self:reduced())end
 elseif self.tomorrow then self.tomorrow:destroy();self.tomorrow=nil end
 end -- the payout before v3
 local rw=self.view.right.w
 local tight=self.tightGoals==true
 local gy=if tight then 21 else 28;local done,count=0,0
 for i,label in ipairs(self.goalLabels)do
  local goal=data.goals and data.goals[i]
  label.Visible=goal~=nil
  if goal then
   count+=1;if goal.done then done+=1 end
   label.Position=UDim2.fromOffset(pad,gy);label.RichText=true
   label.Text=(goal.done and "✓ "or "○ ")..tostring(goal.short or goal.text or goal.title or goal.name or "")
   -- A goal still open reads softer than one that is done.
   label.TextTransparency=if goal.done then 0 else .25
   local height=math.max(if tight then 20 else 22,math.ceil(Kit.measure(Balls.strip(label.Text),"BodyMedium",label.TextSize,rw-2*pad).Y*label.LineHeight)+(if tight then 2 else 4))
   label.Size=UDim2.fromOffset(rw-2*pad,height);Kit.localizeRich(label);gy+=height+(if tight then 2 else 6)
  end
 end
 self.goalTitle.Text=if count>0 then string.format("Goals  %d/%d",done,count)else "Goals"
 self.metrics.Position=UDim2.fromOffset(pad,gy+2);self.metrics.Text=Copy.get("results.inPlace.metrics",{score=data.score or 0,best=data.best or 0,chain=data.chain or 0})
 Kit.setText(self.buttons[1],Copy.get(if data.pending then "results.saved.pending"else "results.inPlace.replay"))
 Kit.setText(self.buttons[3],data.nextDifficulty or data.difficulty or "Medium")
 Kit.setText(self.buttons[5],Copy.get(if self.compact and self.compact.paired then "results.inPlace.hatchShort"else "results.inPlace.hatch"))
 Kit.setText(self.buttons[2],Copy.get(if self.grid or self.view.right.w<145 or(self.compact and self.compact.paired)then "results.leave.narrow"else "results.leave.wide"))
 for id,button in pairs(self.buttons)do Kit.setEnabled(button,if id==2 then data.canLeave~=false else not data.pending)end
 self.saved.Text=Copy.get(if data.pending then "results.saved.pending"else "results.saved.done")
 self.star.setMode(if self.owner.zeroPayout(data)then "glass"else "gold")
 self:paintFocus();self:paintCount(if self.owner.feedback.active then {counted=self.owner.feedback.counted} else nil)
end
function View:paintCount(sample)
 if not self.data then return end
 local data=self.data
 local n=if sample and sample.counted then sample.counted else data.earned or 0
 self.count.Text=if data.pending then "…"elseif n>0 then "+"..tostring(n).." ★"else "0 ★"
 self.wallet.set(if sample and not data.pending then(data.balance or 0)-(data.earned or 0)+n else data.balance or 0)
end
function View:paintFocus()
 local button=self.buttons[self.owner.focus]or self.buttons[1]
 self.ring.attach(button,10)
 if self.scrollActions then
  local y=button.Position.Y.Offset
  local h=self.actions.AbsoluteSize.Y
  if h>0 then self.actions.CanvasPosition=Vector2.new(0,math.clamp(y-4,0,math.max(0,4*48-h)))end
 end
end
function View:move(dx,dy)
 if not self.owner.visible then return false end
 if dx~=0 and self.owner.focus==3 then
  local callback=self.owner.callbacks.heatShift
  if callback and not self.data.pending then callback(dx);return true end
 end
 -- U7 (v3): the compact stack's own moves (Difficulty down to Hatch, Hatch and Leave side by side, up to Difficulty).
 if self.compact then
  local target=Layout.move(self.owner.focus,dx,dy,self.compact.paired)
  if target then
   local state=Kit.buttonState(self.buttons[target])
   if target~=self.owner.focus and state and state.enabled then
    self.owner.focus=target;self:paintFocus()
    if self.owner.options.audio then self.owner.options.audio:play("aim",1,.3)end
   end
   return true
  end
 end
 local at=table.find(ORDER,self.owner.focus)or 1
 local delta=if dy~=0 then math.sign(dy)else math.sign(dx)
 if delta==0 then return false end
 if math.clamp(at+delta,1,#ORDER)==at then return true end
 for nextAt=math.clamp(at+delta,1,#ORDER),if delta>0 then #ORDER else 1,delta do
  local id=ORDER[nextAt];local state=Kit.buttonState(self.buttons[id])
  if state and state.enabled then self.owner.focus=id;self:paintFocus();if self.owner.options.audio then self.owner.options.audio:play("aim",1,.3)end;return true end
 end
 return true
end
function View:activate(id)
 local button=self.buttons[id];local state=button and Kit.buttonState(button)
 if not state or not state.enabled or not self.owner.visible then return false end
 if os.clock()-self.opened<.3 and not self:reduced()then return false end
 local callback=self.owner.callbacks[({[1]="replay",[3]="picker",[5]="hatch",[2]="leave"})[id]]
 if callback then Kit.pulse(button);callback();return true end
 return false
end
-- Eased 0..1 progress of an entry beat ({start, length}) at `t` seconds.
local function beat(t,spec)
 local x=math.clamp((t-spec[1])/spec[2],0,1)
 return 1-(1-x)^4
end
local function backOut(x)
 local c=1.70158
 return 1+(c+1)*(x-1)^3+c*(x-1)^2
end
function View:step()
 if not self.owner.visible then return end
 local t=os.clock()-self.opened
 local reduced=self:reduced()
 local E=View.Entry
 -- Entry (QA v735 D6): the screen dims in, the Star column rises, the two side panes
 -- slide in from their edges, the headline lands and the Star pops, each eased, a few
 -- frames apart. (It was a 0.12 s dim that jumped to opaque, then one 0.18 s fade.)
 if not self.settled or t<1 then
  local dim=if reduced then 1 else math.clamp(t/E.dim,0,1)
  self.root.BackgroundTransparency=1-dim*dim*(3-2*dim)
  local R=self.regions
  for _,item in ipairs({{self.middle,R.middle,E.middle,0,E.rise},{self.left,R.left,E.left,-E.slide,0},{self.right,R.right,E.right,E.slide,0}})do
   local e=if reduced then 1 else beat(t,item[3])
   item[1].GroupTransparency=1-e
   item[1].Position=UDim2.fromOffset(item[2].x+item[4]*(1-e),item[2].y+item[5]*(1-e))
  end
  local h=if reduced then 1 else math.clamp((t-E.headline[1])/E.headline[2],0,1)
  self.headline.scale.Scale=(self.headlineFit or 1)*(if h>=1 then 1 else 1.5-.5*backOut(h))
  self.headline.root.Rotation=6+(-3-6)*(1-(1-h)^3)
  local p=if reduced then 1 else math.clamp((t-E.star[1])/E.star[2],0,1)
  self.star.scale.Scale=if p>=1 then 1 else .55+.45*backOut(p)
  self.settled=reduced or t>=1
 end
 -- The Star turns all the way round (45 degrees a second, from the moment the results
 -- open); its face rides the front and hides while the back is showing.
 local yaw=if reduced or self.star.mode=="glass"then 0 else self.owner.spinYaw(t)
 self.star.setSpin(yaw,0)
 if self.face then
  local turn=self.owner.faceTurn(yaw)
  local show=turn~=nil and self.star.mode~="glass"
  if self.face.face.Visible~=show then self.face.face.Visible=show end
  if show then
   local r=math.rad(turn)
   self.face.face.Position=UDim2.new(.5,math.sin(r)*self.face.size*.3,.5,0)
   self.face.face.Size=UDim2.fromScale(math.cos(r),1)
  end
 end
end
function View:start()
 if not self.connection then self.connection=Run.RenderStepped:Connect(function()self:step()end)end
 self:step()
end
function View:hide()
 if self.connection then self.connection:Disconnect();self.connection=nil end
 self.ring.hide()
end
function View:destroy()
 self:hide();self.root:Destroy();self.ring.root:Destroy()
end
return View
