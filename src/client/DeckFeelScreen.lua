-- The Pocket Deck feel pass on the deck's own UI (DECK-FEEL-BRIEF 2, 3, 1 step 4, 6 and 7). One per DeckScreen
-- (Screen.feel). Every entry point answers as if it were not there while Alive "deckfeel" is off (DeckFeel.switch).
--   2 holds    Screen:hold(id, down) for every input (touch on the drawn keys, release-to-drop, Space / ButtonA, the
--              d-pad's wedge for as long as aim moves); A presses to .94 and springs back; a 90 ms minimum; an 18 ms
--              tick on touch. Reduced Motion: the sprite swaps stay, no scale or spring.
--   3 lean     DeckPressLean's state and its pressed-half shade (two gradient frames built once). The offset itself is
--              written by DeckMergeJolt / Screen:setShake (one writer).
--   1 stagger  the HUD panels come up 6 px, 30 ms apart, left column, well, right column, as the LCD fades in.
--   6 stepper  the Difficulty card: "◀ Easy ▶", the level's tint, a 4 px lip, a tap hit, one arrival pop; it settles
--              into the plain card at the first drop.
--   7 polish   card radius 18 (12 compact), a 1 px top highlight and inner stroke, tag pills 14 / 12 in (24 tall, 10 pad,
--              a 2 px lip; BALLS LEFT and the level get pills too), content 12 under the pill where the card has room,
--              the well's radius 12 and 3 px top shadow; the score's punch, the balls-left tick, the chain dots' pop,
--              the next balls' bob. Motion on change only; Reduced Motion: none of the motion.
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Kit=require(script.Parent.DeckKit)
local Feel=require(script.Parent.DeckFeel)
local Lean=require(script.Parent.DeckPressLean)
-- DECK-AERO-BRIEF (Alive deckglass, with deckfeel): the glass dresses what the polish built (DeckGlassUI, required only
-- while the switch is on).
local Glass=require(game:GetService("ReplicatedStorage").Shared.DeckGlass)

local View={};View.__index=View
local PressTick=nil

local function node(class,parent,props)
 local o=Instance.new(class)
 for k,v in pairs(props or {})do o[k]=v end
 o.Parent=parent
 return o
end

function View.new(screen)
 local self=setmetatable({screen=screen,holds={},lean=Lean.new(),springs={},runners={},shade={left=0,right=0},
  last={},goalsDone={}},View)
 local function half(name,x,from,to)
  local f=node("Frame",screen.root,{Name=name,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,
   Position=UDim2.fromScale(x,0),Size=UDim2.fromScale(.5,1),ZIndex=7,Active=false,Visible=false})
  node("UIGradient",f,{Transparency=NumberSequence.new(from,to)})
  return f
 end
 -- The pressed edge is opaque in the gradient (black at the frame's own transparency), the centre clear.
 self.shadeLeft=half("FeelShadeLeft",0,0,1)
 self.shadeRight=half("FeelShadeRight",.5,1,0)
 return self
end
function View:on()return Feel.switch()end
function View:reduced()return Kit.reduced()end
function View:motionLow()return Kit.reducedEffects==true end
function View:compact()
 local g=self.screen.geometry
 return g~=nil and(g.phone==true or g.compact==true)
end

-- ── 2. Holds ────────────────────────────────────────────────────────────────────────────────────────────────────
function View:hold(id,down,now)
 now=now or os.clock()
 local h=self.holds[id]or {};self.holds[id]=h
 if down then
  h.down,h.downAt,h.pending=true,now,nil
  self:show(id,true,now)
 elseif h.down then
  h.down=false
  local at=Feel.releaseAt(h.downAt,now)
  if at<=now then self:show(id,false,now)
  else
   h.pending=at
   task.delay(at-now,function()if h.pending==at and not h.down then h.pending=nil;self:show(id,false,os.clock())end end)
  end
 end
end
-- Beta 41 review: every hold still down goes up (the deck closing mid-touch, a Mode change): no A left pressed with its
-- lean. Returns the ids it let go.
function View:releaseAll(now)
 local out={}
 for id,h in pairs(self.holds)do if h.down then table.insert(out,id)end end
 table.sort(out)
 for _,id in ipairs(out)do self:hold(id,false,now)end
 return out
end
-- Down and up at once: shows for the 90 ms minimum.
function View:tap(id)self:hold(id,true);self:hold(id,false)end
-- Keyboard and gamepad presses in menus: hold + release after .10.
function View:flash(id)
 self:hold(id,true)
 task.delay(Feel.Hold.flash,function()self:hold(id,false)end)
end
function View:isDown(id)local h=self.holds[id];return h~=nil and(h.down or h.pending~=nil)end
function View:show(id,down,now)
 local s=self.screen
 if id=="A"or id=="B"then s:pressButton(id,down);self:scale(id,down,now)
 else s:pressDpad(id,down)end
 if down then self.lean:press(id,now,self:compact())else self.lean:release(id,now)end
end
-- An 18 ms light tick for A on touch (the existing Haptics; its own switch and caps).
function View:touchTick()
 if not self:on()then return end
 local ok,Haptics=pcall(require,script.Parent.Haptics)
 if not ok then return end
 PressTick=PressTick or Haptics.pattern("Small",1,{{Feel.Hold.haptic.strength,Feel.Hold.haptic.strength,Feel.Hold.haptic.ms}})
 pcall(Haptics.play,"deck_press_a",PressTick)
end
-- A's (and B's) press scale: .94 in 60 ms, up on the spring.
function View:scale(id,down,now)
 local b=self.screen.buttons[id];if not b then return end
 local scale=b.holder:FindFirstChild("FeelPress")or node("UIScale",b.holder,{Name="FeelPress",Scale=1})
 if self:reduced()then scale.Scale=1;self.springs[id]=nil;return end
 self.springs[id]={down=down,at=now,scale=scale}
 self:run("buttons",function(t)return self:stepButtons(t)end)
end
function View:stepButtons(now)
 local busy=false
 for id,s in pairs(self.springs)do
  if not s.scale.Parent then self.springs[id]=nil
  else
   local v
   if s.down then v=Feel.pressScale(now-s.at,nil);busy=true
   elseif now-s.at>1.5 then v=1;self.springs[id]=nil
   else v=Feel.pressScale(nil,now-s.at);busy=true end
   s.scale.Scale=v
  end
 end
 return busy
end

-- One RenderStepped connection per running effect, gone when it reports done.
function View:run(name,step)
 if self.runners[name]then self.runners[name].step=step;return end
 local runner={step=step}
 runner.connection=RunService.RenderStepped:Connect(function()
  local ok,busy=pcall(runner.step,os.clock())
  if not ok or not busy then runner.connection:Disconnect();if self.runners[name]==runner then self.runners[name]=nil end end
 end)
 self.runners[name]=runner
end

-- ── 3. Lean ─────────────────────────────────────────────────────────────────────────────────────────────────────
-- Advances the lean; returns the body offset (Vector2, whole px) or nil while off. Paints the pressed-half shade.
function View:stepLean(now)
 if not self:on()then self:paintShade(nil,0);return nil,nil end
 local allows=Lean.allows(self:reduced(),self:motionLow())
 local x,y,shade=self.lean:step(now)
 self:paintShade(self.lean.side,if allows.shade then shade else 0)
 if not allows.offset then return Vector2.zero,Vector2.zero end
 local lean=Vector2.new(math.round(x),math.round(y))
 -- The LCD's 1 px counter-move: not on a phone (its HUD is not inside the LCD frame).
 local g=self.screen.geometry
 if g and g.phone then return lean,Vector2.zero end
 local px,py=Lean.parallax(lean.X,lean.Y)
 return lean,Vector2.new(px,py)
end
-- DECK-FEEL-BRIEF 6: the Difficulty card's one pop on arrival (only while it is the control).
function View:popStepper()
 if not self:on()or self:reduced()then return end
 local h=self.screen.hud
 local card=h and h.diffName and h.diffName.Parent
 if not card or not card:FindFirstChild("FeelHit")or not card.FeelHit.Visible then return end
 local scale=card:FindFirstChild("FeelPop")or node("UIScale",card,{Name="FeelPop"})
 local from=os.clock()
 self:run("stepperPop",function(now)local t=now-from;scale.Scale=Feel.stepperPop(t);return t<Feel.Stepper.pop[2]end)
end
function View:paintShade(side,strength)
 for name,frame in pairs({left=self.shadeLeft,right=self.shadeRight})do
  local a=if name==side then strength else 0
  if math.abs(a-(self.shade[name]or 0))>.02 or(a==0)~=((self.shade[name]or 0)==0)then
   self.shade[name]=a
   frame.Visible=a>.01
   frame.BackgroundTransparency=1-Lean.Shade*a
  end
 end
end
function View:kick(x,y)
 if not self:on()or self:reduced()or self:motionLow()then return end
 self.lean:kick(x,y,os.clock())
end

-- ── 1. The panels' stagger ──────────────────────────────────────────────────────────────────────────────────────
function View:stagger()
 if not self:on()or self:reduced()then return end
 local s=self.screen
 local host=s.hudRoot;if not host then return end
 local items={}
 local function add(frame,id)
  if frame and frame:IsA("GuiObject")and frame.Visible then
   table.insert(items,{id=id or frame,frame=frame,x=frame.Position.X.Offset,y=frame.Position.Y.Offset,w=frame.Size.X.Offset})
  end
 end
 -- (deckglass: a card's shadow follows its card, so it is not a panel of its own)
 for _,child in ipairs(host:GetChildren())do if child:IsA("Frame")and child.Size.X.Offset>0 and not child:GetAttribute("GlassShadow")then add(child)end end
 add(s.well,"well")
 local g=s.geometry
 local left,right=0,0
 if s.well and s.well.Size.X.Offset>0 then left=s.well.Position.X.Offset;right=left+s.well.Size.X.Offset
 elseif g and g.boardLocal then left=g.boardLocal.x;right=left+g.boardLocal.w end
 local byId={};for _,item in ipairs(items)do byId[item.id]=item end
 for _,row in ipairs(Feel.panelOrder(items,left,right))do
  local item=byId[row.id]
  local frame=item.frame
  local rest=frame.Position
  frame.Position=rest+UDim2.fromOffset(0,Feel.Open.panelRise)
  TweenService:Create(frame,TweenInfo.new(Feel.Open.panelTween,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,row.delay),{Position=rest}):Play()
 end
end

-- ── 7. Polish ───────────────────────────────────────────────────────────────────────────────────────────────────
local Decor={FeelHighlight=true,FeelInner=true,FeelLip=true,FeelHit=true}
local function isEyebrow(child)
 return child:IsA("TextLabel")and child:GetAttribute("KitRole")=="Label"and string.match(child.Text,"^%u")~=nil and child.Text==string.upper(child.Text)
end
-- Restyles a freshly built HUD (Screen:buildHud / buildCompactHud).
function View:built(g)
 self.cards=nil;self.nextBase=nil;self.last={};self.goalsDone={};self.pills=nil
 self.glass=false
 if not self:on()then return end
 self.glass=Glass.switch()
 local s=self.screen
 local host=s.hudRoot;if not host then return end
 local compact=g.phone==true or g.compact==true
 local radius=Feel.cardRadius(compact)
 local P=Feel.Polish
 self.cards={}
 for _,card in ipairs(host:GetChildren())do
  if card:IsA("Frame")and card.Size.X.Offset>0 then
   self.cards[card.Name]=card
   local corner=card:FindFirstChildOfClass("UICorner")
   if corner and card.Name~="QuestHandle"then corner.CornerRadius=UDim.new(0,radius)end
   -- deckglass: the glass's rim and gloss take the highlight's and inner stroke's place (DeckGlassUI.card).
   if not self.glass then
    node("Frame",card,{Name="FeelHighlight",BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=P.highlight,BorderSizePixel=0,
     Position=UDim2.fromOffset(math.floor(radius*.7),1),Size=UDim2.new(1,-2*math.floor(radius*.7),0,1),ZIndex=card.ZIndex,Active=false})
    local inner=node("Frame",card,{Name="FeelInner",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(1,1),
     Size=UDim2.new(1,-2,1,-2),ZIndex=card.ZIndex,Active=false})
    node("UICorner",inner,{CornerRadius=UDim.new(0,math.max(0,radius-1))})
    node("UIStroke",inner,{Color=Color3.new(0,0,0),Transparency=P.stroke,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
   end
   self:pill(card,compact)
  end
 end
 -- The level's name gets the same pill (painted in its tint by paint()).
 local h=s.hud
 if h.diffName then
  local bars=h.diffBars and h.diffBars[#h.diffBars]
  local pad=if compact then P.pillCompact.pad else P.pill.pad
  if bars then
   local x=bars.Position.X.Offset+bars.Size.X.Offset+6+pad
   h.diffName.Position=UDim2.fromOffset(x,h.diffName.Position.Y.Offset)
  end
  h.diffName:SetAttribute("FeelPill",if compact then "compact"else "regular")
  local tab=Kit.hudLabel(h.diffName,Color3.fromRGB(255,211,92));tab:SetAttribute("FixedTab",true)
 end
 -- The well: radius 12 and a 3 px shadow along its top.
 if s.well then
  local corner=s.well:FindFirstChildOfClass("UICorner")or node("UICorner",s.well)
  corner.CornerRadius=UDim.new(0,P.wellRadius)
  if not s.well:FindFirstChild("FeelShadow")then
   local shadow=node("Frame",s.well,{Name="FeelShadow",BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0,BorderSizePixel=0,
    Position=UDim2.fromOffset(P.wellRadius,0),Size=UDim2.new(1,-2*P.wellRadius,0,P.wellShadow),ZIndex=s.well.ZIndex,Active=false})
   node("UIGradient",shadow,{Rotation=90,Transparency=NumberSequence.new(.7,1)})
  end
 end
 -- The next balls' rest positions (their 1 px bob).
 self.nextBase={}
 for index,slot in ipairs(h.next or {})do self.nextBase[index]=slot.ball.Position end
 -- DECK-AERO-BRIEF 2-5 (deckglass): glass cards, gel pills, tracks, the well's frame, the counters, the bubbles.
 if self.glass then self.pills=require(script.Parent.DeckGlassUI).dressHud(s,g,self.cards)end
end
-- deckglass: the pill on `card` (by name) takes a state flag; one sweep across a card.
function View:glassState(name,key,on)
 local tab=self.glass and self.pills and self.pills[name]
 if tab then require(script.Parent.DeckGlassUI).setState(tab,key,on)end
end
function View:glassSweep(name)
 local card=self.glass and self.cards and self.cards[name]
 if card then require(script.Parent.DeckGlassUI).sweep(card)end
end
-- The chain is live (Screen:paintChain): its pill turns `warn`. Gold as text only at 18 px and up (rule 3).
function View:chainLit(on)self:glassState("Chain","GlassLive",on)end
function View:goldText(size)return not self.glass or Glass.goldText(size)end
-- A card's eyebrow becomes a pill 14 / 12 in (24 tall, 10 pad, 2 px lip); its content moves to 12 under the pill
-- where the card has room (never past its foot).
function View:pill(card,compact)
 local eyebrow
 for _,child in ipairs(card:GetChildren())do
  if isEyebrow(child)and(not eyebrow or child.Position.Y.Offset<eyebrow.Position.Y.Offset)then eyebrow=child end
 end
 if not eyebrow then return end
 local cardH=card.Size.Y.Offset
 local lh=if eyebrow.Size.Y.Scale==0 then eyebrow.Size.Y.Offset else eyebrow.AbsoluteSize.Y
 local oneRow=lh>=cardH-4
 local word=string.match(eyebrow.Text,"^%u+")
 if not Kit.hudTabOf(eyebrow)then
  -- BALLS LEFT (and any caps label without a tab colour) gets the Eggs orange.
  if word=="BALLS"then Kit.hudLabel(eyebrow,Kit.HudTabColors.EGGS)else return end
 end
 -- Content: every other child placed in offsets below the eyebrow's row (a counter on the same row stays).
 local top,bottom=math.huge,0
 local moving={}
 for _,child in ipairs(card:GetChildren())do
  if child:IsA("GuiObject")and child~=eyebrow and not Decor[child.Name]and child~=Kit.hudTabOf(eyebrow)and child.Position.Y.Scale==0
   and child.Visible and child.Position.Y.Offset>eyebrow.Position.Y.Offset+6 then
   top=math.min(top,child.Position.Y.Offset);bottom=math.max(bottom,child.Position.Y.Offset+child.Size.Y.Offset)
   table.insert(moving,child)
  end
 end
 local textW=Kit.measure(eyebrow.Text,"Label",eyebrow.TextSize).X
 local rect=Feel.pillRect(textW,compact,if oneRow then cardH else nil,if #moving>0 then top else nil)
 eyebrow:SetAttribute("FeelPillH",rect.h)
 eyebrow:SetAttribute("FeelPill",if compact then "compact"else "regular")
 local y=if oneRow then eyebrow.Position.Y.Offset else rect.y+math.floor((rect.h-lh)/2)
 eyebrow.Position=UDim2.new(eyebrow.Position.X.Scale,rect.labelX,eyebrow.Position.Y.Scale,y)
 if oneRow or #moving==0 then return end
 local shift=Feel.contentShift(rect.y+rect.h,top,bottom,cardH,compact)
 if shift<=0 then return end
 for _,child in ipairs(moving)do child.Position+=UDim2.fromOffset(0,shift)end
end

-- Motion on change only: the score's punch, the chain dots' pop.
function View:score(score,chain)
 if not self:on()then return end
 local h=self.screen.hud;if not h or not h.score then return end
 local last=self.last
 if not self:reduced()and type(score)=="number"and type(last.score)=="number"and score>last.score then
  local scale=h.score:FindFirstChild("FeelPunch")or node("UIScale",h.score,{Name="FeelPunch"})
  local from=os.clock()
  self:run("punch",function(now)local t=now-from;scale.Scale=Feel.punchAt(t);return t<Feel.Polish.punch[2]end)
 end
 if not self:reduced()and h.chainBar and h.chainBar.cells and type(chain)=="number"and type(last.chain)=="number"and chain>last.chain then
  local cells={}
  for index=last.chain+1,math.min(chain,#h.chainBar.cells)do
   local cell=h.chainBar.cells[index]
   table.insert(cells,cell:FindFirstChild("FeelPop")or node("UIScale",cell,{Name="FeelPop"}))
  end
  local from=os.clock()
  if #cells>0 then self:run("dots",function(now)
   local t=now-from;local busy=false
   for i,scale in ipairs(cells)do scale.Scale=Feel.dotPop(t,i);busy=busy or t<(i-1)*Feel.Polish.chainPop[2]+.16 end
   return busy
  end)end
 end
 -- deckglass 5: the gloss sweeps the card whose value went up.
 if type(score)=="number"and type(last.score)=="number"and score>last.score then self:glassSweep("Score")end
 if type(chain)=="number"and type(last.chain)=="number"and chain>last.chain then self:glassSweep("Chain")end
 last.score,last.chain=score,chain
end

-- ── 6. The stepper, the balls-left tick, the goal fill (every HUD paint) ────────────────────────────────────────
-- data.stepper = {live, key, pop (true once, at its arrival)}; data.difficulty is the level's name.
function View:paint(data)
 if not self:on()then return end
 local s=self.screen
 local h=s.hud;if not h or not h.diffName then return end
 local stepper=data.stepper
 local live=stepper~=nil and stepper.live==true
 local name=data.difficulty or "Medium"
 if live then h.diffName.Text="◀ "..name.." ▶"end
 local r,g,b=Feel.levelTint(stepper and stepper.key or name)
 if r then
  local tint=Color3.fromRGB(r,g,b)
  -- deckglass: the level's name is a plate-coloured pill (one pill colour per plate); the bars keep the level's tint.
  if not self.glass then Kit.hudLabel(h.diffName,tint)end
  for _,bar in ipairs(h.diffBars or {})do if bar.BackgroundTransparency<.5 then bar.BackgroundColor3=tint end end
 end
 local card=h.diffName.Parent
 if card then self:stepperCard(card,live,stepper)end
 -- The balls-left number ticks down with a 2 px drop.
 local eggs=data.eggsLeft
 if h.eggs and not self:reduced()and type(eggs)=="number"and type(self.last.eggs)=="number"and eggs<self.last.eggs then
  local pad=h.eggs:FindFirstChild("FeelTick")or node("UIPadding",h.eggs,{Name="FeelTick"})
  local from=os.clock()
  self:run("tick",function(now)local t=now-from;pad.PaddingTop=UDim.new(0,math.round(2*Feel.tickAt(t)));return t<Feel.Polish.ballsEase end)
 end
 -- deckglass: a ball spent sweeps the card; three or fewer left turns its pill `bad`; every goal done turns Goals' `good`.
 if type(eggs)=="number"and type(self.last.eggs)=="number"and eggs<self.last.eggs then self:glassSweep("EggsLeft")end
 if type(eggs)=="number"then self:glassState("EggsLeft","GlassLow",Glass.ballsLow(eggs))end
 if data.goals then self:glassState("Goals","GlassDone",Glass.allDone(data.goals))end
 self.last.eggs=eggs
 -- A goal that completes: its check fills in (.3 s) with goal_tick.
 for index,goal in ipairs(data.goals or {})do
  local slot=h.goals and h.goals[index]
  local was=self.goalsDone[index]
  if goal.done and was==false then self:glassSweep("Goals")end
  if goal.done and was==false and slot and slot.check and not self:reduced()then
   local scale=slot.check.root:FindFirstChild("FeelFill")or node("UIScale",slot.check.root,{Name="FeelFill"})
   local from=os.clock()
   self:run("fill"..index,function(now)local t=now-from;scale.Scale=Feel.cubicOut(t/Feel.Polish.goalFill);return t<Feel.Polish.goalFill end)
   local audio=s.options.audio
   local ok,UI=pcall(require,script.Parent.AeroUI)
   if audio and audio.play and not(ok and UI.allows("chips"))then audio:play("goal_tick",1,.3)end
  end
  self.goalsDone[index]=goal.done==true
 end
end
-- The card is a pressable while the round is untouched: a 4 px lip under it and a tap hit over it; one pop on arrival;
-- at the first drop the lip sinks (.12 s) and it is the plain card again.
function View:stepperCard(card,live,stepper)
 local s=self.screen
 local lip=card.Parent:FindFirstChild("FeelLip"..card.Name)
 if not lip then
  lip=node("Frame",card.Parent,{Name="FeelLip"..card.Name,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.55,BorderSizePixel=0,
   ZIndex=math.max(1,card.ZIndex-1),Visible=false,Active=false})
  local corner=card:FindFirstChildOfClass("UICorner")
  node("UICorner",lip,{CornerRadius=corner and corner.CornerRadius or UDim.new(0,12)})
  local hit=node("TextButton",card,{Name="FeelHit",Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=card.ZIndex+20,
   AutoButtonColor=false,Selectable=false,Visible=false})
  hit:SetAttribute("AccessibleLabel","Difficulty")
  hit.Activated:Connect(function()local cb=s.callbacks.stepper;if cb then cb(1)end end)
 end
 local hit=card:FindFirstChild("FeelHit")
 local rest=card.Position+UDim2.fromOffset(0,Feel.Stepper.lip)
 if live then
  lip.Position,lip.Size=rest,card.Size
  lip.Visible=true
  if hit then hit.Visible=true end
  if stepper and stepper.pop and not self:reduced()then
   local scale=card:FindFirstChild("FeelPop")or node("UIScale",card,{Name="FeelPop"})
   local from=os.clock()
   self:run("stepperPop",function(now)local t=now-from;scale.Scale=Feel.stepperPop(t);return t<Feel.Stepper.pop[2]end)
  end
 elseif lip.Visible then
  if hit then hit.Visible=false end
  if self:reduced()then lip.Visible=false
  else
   local sink=TweenService:Create(lip,TweenInfo.new(Feel.Stepper.settle,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=card.Position})
   sink.Completed:Once(function()if not live then lip.Visible=false end end)
   sink:Play()
  end
 end
end

-- Beta 42 note 10 (C10): a next ball moved after the HUD was built (the calm Welcome deck re-centres NEXT's ball in its
-- cut card, restoreCalm puts it back) bobs about its new rest; returns the old rest (the ball's true place, never a
-- bobbed one) so the caller can save that. The next stepNext writes the ball at once.
function View:rebase(index,position)
 local base=self.nextBase;if not base then return nil end
 local was=base[index]
 base[index]=position
 if self.bob then self.bob[index]=nil end
 return was
end
-- The next balls' 1 px bob, half a beat apart (Screen:stepNext, every frame; written on whole-pixel changes).
function View:stepNext(now)
 if not self:on()or self:reduced()or not self.nextBase then return end
 local h=self.screen.hud;if not h or not h.next then return end
 self.bob=self.bob or {}
 for index,slot in ipairs(h.next)do
  local base=self.nextBase[index]
  if base then
   local dy=math.round(Feel.bobAt(now,index))
   if self.bob[index]~=dy then self.bob[index]=dy;slot.ball.Position=base+UDim2.fromOffset(0,dy)end
  end
 end
end

function View:destroy()
 for _,runner in pairs(self.runners)do runner.connection:Disconnect()end
 table.clear(self.runners)
end
return View
