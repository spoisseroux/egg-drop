-- Results content in the existing device's exact three LCD regions. This module
-- owns no wallet write, camera, shell, viewport size or transaction clock.
local Run=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Copy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local C=require(script.Parent.CelebrationKit)
local Balls=require(Shared.BallThemes)
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
 Kit.paint(clip,"BackgroundColor3","panel") -- bound once parented, so it takes the plate's glass (QA v760)
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
 local root=Instance.new("Frame");root.Name="InPlaceResults";root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.BorderSizePixel=0;root.ClipsDescendants=true;root.ZIndex=50;root.Parent=owner.host;self.root=root;Kit.paint(root,"BackgroundColor3","panel")
 local l,r=v.left,v.right
 local m=if l.h==r.h and l.y==r.y then{x=v.center.x,y=l.y,w=v.center.w,h=l.h}else v.center
 self.regions={left=l,right=r,middle=m}
 self.left=pane(root,"PayoutRegion",l);self.right=pane(root,"OutcomeRegion",r);self.middle=pane(root,"StarRegion",m)
 self.payout=scroll(self.left,"PayoutRows");self.goals=scroll(self.right,"Goals")
 -- Actions: a 2 x 2 grid when two 44 px buttons fit side by side, else the stack.
 self.grid=r.w>=176 and r.h>=2*44+4+12+70
 local actionHeight=if self.grid then 2*44+4 else 4*44+3*4
 self.scrollActions=not self.grid and r.h<actionHeight+68
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
 self.payout.Size=UDim2.new(1,0,1,-34)
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
 -- QA v751 P5: the 28 px chip (Kit.WalletSpec[28]) carries the 3D WalletStar; the 20 px one
 -- had an 11 px Star, under WalletStar.MinSize, so it stayed a flat glyph.
 self.wallet=Kit.wallet(self.left,28);self.wallet.root.AnchorPoint=Vector2.new(0,1);self.wallet.root.Position=UDim2.fromOffset(pad,l.h-4)
 -- Goals.
 self.goalLabels={}
 self.goalTitle=labelAt(self.goals,"GoalTitle","Goals",12,"soft",pad,if self.tightGoals then 4 else 8,r.w-2*pad,16)
 for i=1,3 do self.goalLabels[i]=labelAt(self.goals,"Goal"..i,"",13,"text",pad,28+(i-1)*24,r.w-2*pad,22)end
 self.metrics=labelAt(self.goals,"Metrics","",12,"soft",pad,104,r.w-2*pad,32)
 local names={[1]="Replay",[3]="Difficulty",[5]="Hatch eggs",[2]="Back to garden"}
 local cell=math.floor((r.w-12-4)/2)
 for i,id in ipairs(ORDER)do
  local size=if self.grid then Vector2.new(cell,44)else Vector2.new(math.max(44,r.w-12),44)
  local button=Kit.button(self.actions,"Action"..id,{text=names[id],size=size,textSize=if self.grid or r.w<150 then 13 else 15,selectable=false,variant=if id==1 then "primary"else nil})
  button.Position=if self.grid then UDim2.fromOffset(((i-1)%2)*(cell+4),math.floor((i-1)/2)*48)else UDim2.fromOffset(self.scrollActions and 6 or 0,(i-1)*48)
  button:SetAttribute("ResultAction",id)
  self.buttons[id]=button
  button.Activated:Connect(function()owner.focus=id;self:paintFocus();self:activate(id)end)
 end
 -- Star column: headline, round name, Star, count, saved line.
 local narrow=m.w<180
 self.headlineSize=if narrow then 24 else 30
 self.headline=if narrow then headline(self.middle,self.headlineSize)else C.banner(self.middle,{size=self.headlineSize,rotation=-3})
 self.headline.root.Position=UDim2.fromOffset(math.floor(m.w/2),if narrow then 28 else 36)
 self.title=self.headline.label -- the headline's own label (specs and callers read .Text)
 self.subtitle=labelAt(self.middle,"RoundTitle","",12,"soft",8,if narrow then 50 else 64,m.w-16,18);self.subtitle.TextXAlignment=Enum.TextXAlignment.Center;self.subtitle.TextWrapped=false;self.subtitle.TextTruncate=Enum.TextTruncate.AtEnd
 local top=if narrow then 70 else 86
 local foot=if narrow then 64 else 76
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
 Kit.setText(self.buttons[5],Copy.get("results.inPlace.hatch"))
 Kit.setText(self.buttons[2],Copy.get(if self.grid or self.view.right.w<145 then "results.leave.narrow"else "results.leave.wide"))
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
