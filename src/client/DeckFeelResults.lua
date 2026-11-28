-- The results sequence (DECK-FEEL-BRIEF 8; Spencer beta 40 note 17: "the end game screen/audio needs to be better /
-- more exciting?"), on the in-place results (DeckResultsInPlace). Behind Alive "deckfeel": made only when the switch is
-- on as the results open; DeckResultsInPlace's own entry runs otherwise.
--   0     the headline banner slams in from 1.6, -4 degrees to 0 (.22 Back Out)   [win / tag_slam, so close / whoosh]
--   .15   goals stamp one by one, .09 apart (1.4 -> 1, a 3 degree wobble)          [goal_tick, +.06 a goal]
--   .30   payout rows flip in, .12 apart                                           [row_flip]
--   .60   the Star lands with a squash, its rays open (.3)                          [star_land]
--   .6-1.5 the count; the Star pulses 1.04 every 5; a mini Star flies from each payout row into it   [count_blip 1.0-1.5]
--   1.5   the total punches 1.25, a 12-piece star burst (6 so close), confetti for a win (to 2.7), the body bounces
--         3 px (win)                                                               [bank + stars_total]
--   1.7   new best only: a stamp over the Stars count                                             [new_best]
--   1.9   the buttons rise 8 px into place, Replay focused (never later)
-- Sounds are RecapFeedback's beats (DeckResults.showInPlace sets them). A skips to the final state at any time.
-- Reduced Motion: no slam, burst, confetti or bounce; everything shows at once.
local Kit=require(script.Parent.DeckKit)
local C=require(script.Parent.CelebrationKit)
local Feel=require(script.Parent.DeckFeel)
local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)

local Fx={};Fx.__index=Fx
local Gold,White=Color3.fromRGB(255,211,92),Color3.new(1,1,1)

local function node(class,parent,props)
 local o=Instance.new(class)
 for k,v in pairs(props or {})do o[k]=v end
 o.Parent=parent
 return o
end
local function scaleOf(object,name)
 return object:FindFirstChild(name)or node("UIScale",object,{Name=name,Scale=1})
end

-- view: the DeckResultsInPlace view (its headline, goalLabels, rows, amounts, star, count, metrics, actions, middle).
function Fx.new(view,kind)
 local self=setmetatable({view=view,kind=kind or "win",skipped=false,done=false},Fx)
 self.look=Feel.resultLook(self.kind,Kit.reduced())
 local R=Feel.Results
 local middle=view.middle
 local z=(view.star and view.star.root.ZIndex or middle.ZIndex)+6
 -- The burst and the confetti: pools made once.
 self.burst={}
 for j=1,R.burst do
  self.burst[j]=node("TextLabel",middle,{Name="FeelBurst"..j,BackgroundTransparency=1,Text="★",TextSize=12,TextColor3=if j%2==0 then White else Gold,
   AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(14,14),ZIndex=z,Visible=false,Font=Enum.Font.GothamBold})
 end
 self.confetti={}
 for j=1,R.confettiCount do
  local piece=node("Frame",view.root,{Name="FeelConfetti"..j,BorderSizePixel=0,BackgroundColor3=C.Confetti[(j-1)%#C.Confetti+1],
   Size=UDim2.fromOffset(4+j%3,6+(j*7)%5),ZIndex=view.root.ZIndex+20,Visible=false,Active=false})
  self.confetti[j]=piece
 end
 self.minis={}
 for j=1,R.miniStars do
  self.minis[j]=node("TextLabel",view.root,{Name="FeelMini"..j,BackgroundTransparency=1,Text="★",TextSize=14,TextColor3=Gold,
   AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(16,16),ZIndex=view.root.ZIndex+18,Visible=false,Font=Enum.Font.GothamBold})
 end
 -- The new best's stamp: between the Star and the Stars count in the middle pane (beta 41 Studio check: over the score line it hid
 -- the score, in the narrow goals pane it hid "Goals n/m"); the goals pane's top-right corner when there is no count.
 local bestHost=if view.count and view.count.Parent then view.count else view.metrics
 if bestHost then
  self.best=node("TextLabel",bestHost.Parent,{Name="FeelBest",BackgroundColor3=Gold,BackgroundTransparency=0,Text=Copy.get("deck.feel.best"),
   TextColor3=Color3.fromHex("#15143A"),TextSize=13,Font=Enum.Font.GothamBold,AnchorPoint=Vector2.new(if bestHost==view.count then .5 else 1,.5),Size=UDim2.fromOffset(84,22),
   ZIndex=bestHost.ZIndex+4,Visible=false,Rotation=-4})
  node("UICorner",self.best,{CornerRadius=UDim.new(0,6)})
 end
 if self.kind=="close"and view.star and view.star.rays then
  for _,ray in ipairs(view.star.rays:GetChildren())do if ray:IsA("Frame")then ray.BackgroundTransparency=.5 end end
 end
 self.actionsRest=view.actions and view.actions.Position
 return self
end

-- A skips the sequence to its final state (the first press; the next one acts). From 1.9 s every press acts.
function Fx:skip(t)
 if self.skipped or self.done or(t or 0)>=Feel.Results.buttonsAt then return false end
 self.skipped=true
 return true
end
function Fx:running()return not self.skipped and not self.done end

-- Per frame from DeckResultsInPlace:step (t seconds since the results opened).
function Fx:step(t,data)
 local view=self.view
 local R=Feel.Results
 local still=self.skipped or Kit.reduced()
 if still then t=10 end
 local look=self.look
 -- 0: the headline slams.
 if view.headline then
  local s,r=1,0
  if look.slam and not still then s,r=Feel.headlineAt(t)end
  view.headline.scale.Scale=(view.headlineFit or 1)*s
  view.headline.root.Rotation=r
 end
 -- .15: goals stamp.
 for index,label in ipairs(view.goalLabels or {})do
  local scale=scaleOf(label,"FeelStamp")
  local st,rot,shown=Feel.stampAt(t-(R.goalAt+(index-1)*R.goalGap))
  scale.Scale=if shown then st else 0
  label.Rotation=if shown then rot else 0
 end
 -- .30: payout rows flip in.
 for index,label in ipairs(view.rows or {})do
  local flip,shown=Feel.rowAt(t-(R.rowAt+(index-1)*R.rowGap))
  local k=if shown then .6+.4*flip else 0
  scaleOf(label,"FeelFlip").Scale=k
  local amount=view.amounts and view.amounts[index]
  if amount then scaleOf(amount,"FeelFlip").Scale=k end
 end
 -- .60: the Star lands (squash), its rays open; it pulses on every fifth Star counted; the total punches at 1.5.
 local star=view.star
 if star then
  local landT=t-R.starAt
  local base=star.baseSize or star.root.Size;star.baseSize=base
  if landT<0 then star.scale.Scale=0
  else
   local sx,sy=Feel.starLand(landT)
   local counted=view.owner.feedback.counted or 0
   local tickAt=view.feelTickAt or 0
   if counted~=view.feelCounted then view.feelCounted=counted;view.feelTickAt=t;tickAt=t end
   star.scale.Scale=Feel.starPulse(counted,t-tickAt)
   star.root.Size=UDim2.fromOffset(base.X.Offset*sx,base.Y.Offset*sy)
  end
  if star.rays and star.mode~="glass"then
   local open=if look.rays>0 then Feel.cubicOut(landT/R.rays)else 0
   star.rays.Visible=open>0
   if open>0 then local d=(star.size or 60)*2.5*open;star.rays.Size=UDim2.fromOffset(d,d)end
  end
 end
 if view.count then scaleOf(view.count,"FeelPunch").Scale=Feel.totalPunch(t-R.totalAt)end
 -- 1.5: the burst around the Star.
 local burstN=look.burst
 for j,piece in ipairs(self.burst)do
  local x,y,a=0,0,0
  if j<=burstN and star then x,y,a=Feel.burstAt(j,burstN,t-R.totalAt,(star.size or 60)*.9)end
  piece.Visible=a>0
  if a>0 then piece.Position=star.root.Position+UDim2.fromOffset(x,y);piece.TextTransparency=1-a end
 end
 -- Mini Stars fly from each payout row into the Star during the count.
 local rows=math.min(#self.minis,data and data.rows and #data.rows or 0)
 for j,mini in ipairs(self.minis)do
  local shown=false
  if j<=rows and star and not still then
   local start=R.countFrom+(j-1)*(R.countTo-R.countFrom)/math.max(1,rows)
   local u=(t-start)/R.miniFlight
   if u>=0 and u<1 then
    local row=view.rows[j]
    local from=row.AbsolutePosition+row.AbsoluteSize*Vector2.new(.85,.5)-view.root.AbsolutePosition
    local to=star.root.AbsolutePosition+star.root.AbsoluteSize/2-view.root.AbsolutePosition
    local e=Feel.cubicOut(u)
    local p=from:Lerp(to,e)-Vector2.new(0,math.sin(math.pi*u)*18)
    mini.Position=UDim2.fromOffset(p.X,p.Y);mini.TextTransparency=u*.6;shown=true
   end
  end
  mini.Visible=shown
 end
 -- 1.5-2.7: confetti for a win.
 local h=view.root.AbsoluteSize
 for j,piece in ipairs(self.confetti)do
  local u=(t-R.confetti[1]-(j%5)*.04)/(R.confetti[2]-R.confetti[1])
  local on=look.confetti and not still and u>=0 and u<1
  piece.Visible=on
  if on then
   local x=((j*37)%100)/100*h.X
   piece.Position=UDim2.fromOffset(x+math.sin(u*6+j)*10,-10+u*(h.Y+20))
   piece.Rotation=u*360*(if j%2==0 then 1 else -1)
   piece.BackgroundTransparency=math.max(0,(u-.7)/.3)
  end
 end
 -- 1.5: the body's 3 px bounce (a win).
 if look.bounce and not still and not self.bounced and t>=R.totalAt then
  self.bounced=true
  local bounce=view.owner.feelBounce
  if bounce then pcall(bounce)end
 end
 -- 1.7: the new best's stamp.
 if self.best then
  local newBest=data and data.newBest==true
  local st,rot,shown=Feel.stampAt(t-R.bestAt)
  self.best.Visible=newBest and shown
  if newBest and shown then
   local c=view.count
   if c and self.best.Parent==c.Parent then
    -- centred in the gap between the Star and the count (the pane is too narrow beside the count)
    self.best.Position=UDim2.fromOffset(c.Position.X.Offset+c.Size.X.Offset/2,c.Position.Y.Offset-10)
   else
    self.best.Position=UDim2.new(1,-10,0,18)
   end
   scaleOf(self.best,"FeelStamp").Scale=st;self.best.Rotation=-4+rot
  end
 end
 -- 1.9: the buttons rise 8 px into place.
 if view.actions and self.actionsRest then
  local dy=if still then 0 else Feel.buttonsAt(t)
  view.actions.Position=self.actionsRest+UDim2.fromOffset(0,math.round(dy))
 end
 if t>=3 then self.done=true end
end

function Fx:destroy()
 for _,list in ipairs({self.burst,self.confetti,self.minis})do for _,item in ipairs(list)do item:Destroy()end end
 if self.best then self.best:Destroy()end
end
return Fx
