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
 local clip=Instance.new("CanvasGroup");clip.Name=name;clip.BackgroundColor3=Kit.color("panel");clip.BackgroundTransparency=.05;clip.BorderSizePixel=0
 clip.Position=UDim2.fromOffset(r.x,r.y);clip.Size=UDim2.fromOffset(r.w,r.h);clip.ClipsDescendants=true;clip.ZIndex=parent.ZIndex+1;clip.Parent=parent
 Kit.corner(clip,10);Kit.stroke(clip,nil,1,.75)
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
function View.new(owner,v)
 local self=setmetatable({owner=owner,view=v,buttons={},opened=os.clock()},View)
 local root=Instance.new("Frame");root.Name="InPlaceResults";root.Size=UDim2.fromScale(1,1);root.BackgroundColor3=Kit.color("panel");root.BackgroundTransparency=1;root.BorderSizePixel=0;root.ClipsDescendants=true;root.ZIndex=50;root.Parent=owner.host;self.root=root
 local l,r,m=v.left,v.right,v.center
 self.left=pane(root,"PayoutRegion",l);self.right=pane(root,"OutcomeRegion",r);self.middle=pane(root,"StarRegion",m)
 self.payout=scroll(self.left,"PayoutRows");self.goals=scroll(self.right,"Goals")
 local actionHeight=4*44+3*4
 self.scrollActions=r.h<actionHeight+68
 self.actions=self.scrollActions and scroll(self.right,"ResultActions")or Instance.new("Frame")
 if not self.scrollActions then
  self.actions.Name="ResultActions";self.actions.BackgroundTransparency=1;self.actions.BorderSizePixel=0;self.actions.ZIndex=self.right.ZIndex+2;self.actions.Parent=self.right
  self.actions.Position=UDim2.fromOffset(6,r.h-actionHeight-6);self.actions.Size=UDim2.fromOffset(r.w-12,actionHeight)
  self.goals.Size=UDim2.new(1,0,0,r.h-actionHeight-12)
 else
  self.goals.Size=UDim2.new(1,0,0,math.min(64,r.h*.35))
  self.actions.Position=UDim2.new(0,0,0,math.min(64,r.h*.35)+4);self.actions.Size=UDim2.new(1,0,1,-math.min(64,r.h*.35)-4)
 end
 self.payoutTitle=labelAt(self.payout,"Payout","Payout",14,"soft",8,8,l.w-16,20)
 self.rows={}
 for i=1,4 do self.rows[i]=labelAt(self.payout,"Row"..i,"",14,"text",8,34+(i-1)*34,l.w-16,32)end
 self.total=labelAt(self.payout,"Total","",16,"stars",8,174,l.w-16,38)
 self.today=labelAt(self.payout,"Today","",12,"soft",8,216,l.w-16,38)
 self.goalLabels={}
 self.goalTitle=labelAt(self.goals,"GoalTitle","Goals",12,"soft",8,4,r.w-16,16)
 for i=1,3 do self.goalLabels[i]=labelAt(self.goals,"Goal"..i,"",12,"text",8,24+(i-1)*34,r.w-16,32)end
 self.metrics=labelAt(self.goals,"Metrics","",12,"soft",8,128,r.w-16,32)
 local names={[1]="Replay",[3]="Difficulty",[5]="Hatch eggs",[2]="Back to garden"}
 for i,id in ipairs(ORDER)do
  local button=Kit.button(self.actions,"Action"..id,{text=names[id],size=Vector2.new(math.max(44,r.w-12),44),textSize=if r.w<150 then 13 else 15,selectable=false,variant=if id==1 then "primary"else nil})
  button.Position=UDim2.fromOffset(self.scrollActions and 6 or 0,(i-1)*48);button:SetAttribute("ResultAction",id)
  self.buttons[id]=button
  button.Activated:Connect(function()owner.focus=id;self:paintFocus();self:activate(id)end)
 end
 self.title=labelAt(self.middle,"Outcome","",if m.w<180 then 17 else 23,"text",8,16,m.w-16,48);self.title.TextXAlignment=Enum.TextXAlignment.Center
 self.subtitle=labelAt(self.middle,"RoundTitle","",12,"soft",8,64,m.w-16,34);self.subtitle.TextXAlignment=Enum.TextXAlignment.Center
 local starSize=math.max(36,math.min(m.w*.65,m.h*.30,128))
 self.star=C.star(self.middle,starSize,{mesh=owner.options.starMesh~=false,cleanMaterial=true});self.star.root.Position=UDim2.fromOffset(m.w/2,m.h*.49)
 self.face=owner.buildStarFace(self.star,starSize)
 self.count=labelAt(self.middle,"RewardCount","",if m.w<180 then 22 else 36,"stars",6,m.h*.72,m.w-12,44);self.count.TextXAlignment=Enum.TextXAlignment.Center
 self.saved=labelAt(self.middle,"Saved","",12,"soft",8,m.h-38,m.w-16,32);self.saved.TextXAlignment=Enum.TextXAlignment.Center
 self.wallet=Kit.wallet(self.middle,20);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(m.w-12,12)
 -- No name/hero overlaps the wallet's top band.
 self.title.Position=UDim2.fromOffset(8,46);self.title.Size=UDim2.fromOffset(m.w-16,36)
 self.subtitle.Position=UDim2.fromOffset(8,84);self.subtitle.Size=UDim2.fromOffset(m.w-16,28)
 self.star.root.Position=UDim2.fromOffset(m.w/2,m.h*.5+18)
 self.count.Position=UDim2.fromOffset(6,m.h-80);self.count.Size=UDim2.fromOffset(m.w-12,40)
 self.count.TextSize=if m.w<180 then 22 else 32
 self.saved.Position=UDim2.fromOffset(8,m.h-28);self.saved.Size=UDim2.fromOffset(m.w-16,20)
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
 local headline=self.owner.headline(data)
 self.title.Text=data.headline or headline
 self.subtitle.Text=data.title or "Round"
 self.wallet.set(data.balance or 0)
 local y=34
 for i,row in ipairs(self.rows)do
  local item=data.rows and data.rows[i]
  row.Visible=item~=nil
  if item then
   row.Text=item.name.."  "..(item.signed and "+"or "")..tostring(item.amount)
   local height=math.max(32,math.ceil(Kit.measure(row.Text,"BodyMedium",row.TextSize,self.view.left.w-16).Y*row.LineHeight)+4)
   row.Position=UDim2.fromOffset(8,y);row.Size=UDim2.fromOffset(self.view.left.w-16,height);y+=height+6
  end
 end
 if not data.pending and(data.earned or 0)==0 then
  self.rows[1].Visible=true;self.rows[1].Text=Copy.get("results.inPlace.noStars");y=72
 end
 self.total.Position=UDim2.fromOffset(8,y+4);self.total.Text=Copy.get("results.inPlace.total",{count=if data.pending then "…"else data.total or data.earned or 0})
 self.today.Position=UDim2.fromOffset(8,y+48);self.today.Text=Copy.get("results.today.line",{count=data.todayEarned or 0})
 local gy=24
 for i,label in ipairs(self.goalLabels)do
  local goal=data.goals and data.goals[i]
  label.Visible=goal~=nil
  if goal then
   label.Position=UDim2.fromOffset(8,gy);label.RichText=true
   label.Text=(goal.done and "✓ "or "○ ")..tostring(goal.short or goal.text or goal.title or goal.name or "")
   local height=math.max(32,math.ceil(Kit.measure(Balls.strip(label.Text),"BodyMedium",label.TextSize,self.view.right.w-16).Y*label.LineHeight)+4)
   label.Size=UDim2.fromOffset(self.view.right.w-16,height);Kit.localizeRich(label);gy+=height+6
  end
 end
 self.metrics.Position=UDim2.fromOffset(8,gy+4);self.metrics.Text=Copy.get("results.inPlace.metrics",{score=data.score or 0,best=data.best or 0,chain=data.chain or 0})
 Kit.setText(self.buttons[1],Copy.get(if data.pending then "results.saved.pending"else "results.inPlace.replay"))
 Kit.setText(self.buttons[3],data.nextDifficulty or data.difficulty or "Medium")
 Kit.setText(self.buttons[5],Copy.get("results.inPlace.hatch"))
 Kit.setText(self.buttons[2],Copy.get(if self.view.right.w<145 then "results.leave.narrow"else "results.leave.wide"))
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
function View:step()
 if not self.owner.visible then return end
 local t=os.clock()-self.opened
 local reduced=self:reduced()
 local fade=if reduced then 1 else math.clamp((t-.12)/.18,0,1)
 self.root.BackgroundTransparency=if reduced or t>=.12 then 0 else 1-.55*t/.12
 for _,pair in ipairs({{self.left,self.view.left,-1},{self.right,self.view.right,1},{self.middle,self.view.center,0}})do
  pair[1].GroupTransparency=1-fade
  pair[1].Position=UDim2.fromOffset(pair[2].x+(if reduced then 0 else pair[3]*8*(1-fade)),pair[2].y)
 end
 local yaw=if reduced then 0 else math.sin(t*.55)*20
 self.star.setSpin(yaw,0)
 if self.face then
  self.face.face.Visible=self.star.mode~="glass"
  self.face.face.Position=UDim2.new(.5,math.sin(math.rad(yaw))*self.face.size*.3,.5,0)
  self.face.face.Size=UDim2.fromScale(math.cos(math.rad(yaw)),1)
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
