-- The Pocket Deck feel pass in the well (DECK-FEEL-BRIEF 1 step 5, 2, 4 and 5). One per board (init.client). Every
-- entry point answers as if it were not there while Alive "deckfeel" is off (DeckFeel.switch).
--   arrival  the first presented frame after the deck opens: a new round's held ball drops in (10 px, one squash);
--            a resumed round's balls come in by row, bottom up (DeckFresh).
--   wedge    the d-pad's wedge shows for as long as aim moves that way: held keys, or a touch drag (on above 3 px a
--            frame, off after 120 ms still). Edge-triggered, so a menu's own d-pad presses are left alone.
--   life     calm 15 Hz steps, every Instance built here once: the well pattern drifts down a cell per 16 s (a merge
--            jumps it), the held ball breathes 1 px and blinks every 4-6 s, the aim dots march, the FILL LINE dashes
--            march left (twice as fast, easing to coral, near the line), its tag fades to 40% and LEFT / RIGHT fade out
--            after the first drop; a drop's lane lightens 4% (.25 s) and its landing puffs 3 pixels of dust (.18 s); a
--            merge flashes the well border in the tier's light (.2 s); a chain of 3+ glows the top edge gold (1.2 s).
--            Reduced Motion and Motion: Low: every loop off; the border flash and the lane tint stay.
local Feel=require(script.Parent.DeckFeel)
local Fresh=require(script.Parent.DeckFresh)

local Board={};Board.__index=Board

local function node(class,parent,props)
 local o=Instance.new(class)
 for k,v in pairs(props or {})do o[k]=v end
 o.Parent=parent
 return o
end

-- deps: overlay (the well's overlay frame), deck (DeckScreen), danger() (BoardDanger or nil), zones (LEFT / RIGHT
-- {tag}), pattern() (DeckBackdrop board or nil), reduced() (Reduced Motion or Motion: Low).
function Board.new(deps)
 local self=setmetatable({deps=deps,drag=nil,wedge=nil,jumps=0,stepAt=-math.huge,shot={},restored=true},Board)
 local overlay=deps.overlay
 self.lane=node("Frame",overlay,{Name="FeelLane",BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,
  AnchorPoint=Vector2.new(.5,0),Size=UDim2.new(0,10,1,0),ZIndex=2,Active=false,Visible=false})
 local border=node("Frame",overlay,{Name="FeelBorder",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=5,Active=false,Visible=false})
 self.borderStroke=node("UIStroke",border,{Thickness=2,Transparency=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 self.border=border
 local G=Feel.Life.glow
 self.glow=node("Frame",overlay,{Name="FeelGlow",BackgroundColor3=Color3.fromRGB(G.color[1],G.color[2],G.color[3]),BackgroundTransparency=1,
  BorderSizePixel=0,Size=UDim2.new(1,0,0,14),ZIndex=5,Active=false,Visible=false})
 node("UIGradient",self.glow,{Rotation=90,Transparency=NumberSequence.new(0,1)})
 self.dust={}
 for j=1,Feel.Life.dust.count do
  self.dust[j]=node("Frame",overlay,{Name="FeelDust"..j,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,
   Size=UDim2.fromOffset(Feel.Life.dust.px,Feel.Life.dust.px),AnchorPoint=Vector2.new(.5,.5),ZIndex=5,Active=false,Visible=false})
 end
 return self
end
function Board:on()return Feel.switch()end
function Board:reduced()local f=self.deps.reduced;return f~=nil and f()==true end

-- ── Arrival (1 step 5, 5) ───────────────────────────────────────────────────────────────────────────────────────
function Board:arrive()self.arrival=true;self.reveal=nil;self.firstDropAt=nil end
-- A new round (ResetId): LEFT / RIGHT and the FILL LINE tag come back until its first drop.
function Board:newRound()self.firstDropAt=nil end
-- The first presented frame after an arrival. Returns the arrival's kind ("fresh" / "resume") or nil.
function Board:presented(now,drops)
 if not self.arrival then return nil end
 self.arrival=nil
 if not self:on()then return nil end
 self.reveal={at=now,kind=Fresh.arrival(drops)};self.arrivedAt=now
 if(drops or 0)>0 then self.firstDropAt=now-10 end
 return self.reveal.kind
end
-- The held ball this frame: dy (screen px, - is up), x scale, y scale, the breath (px of radius), blink.
function Board:held(now)
 if not self:on()then return 0,1,1,0,false end
 local dy,sx,sy=0,1,1
 local reduced=self:reduced()
 local reveal=self.reveal
 if reveal and reveal.kind=="fresh"and not reduced then
  local t=now-reveal.at
  if t<Feel.Open.ballFall+Feel.Open.squashFor then dy,sx,sy=Feel.ballDrop(t)else self.reveal=nil end
 end
 if reduced then return dy,sx,sy,0,false end
 local since=now-(self.arrivedAt or 0)
 return dy,sx,sy,Feel.breath(since),Feel.blinkAt(since)
end
-- May a ball `y` board units up (rows `rowHeight`) draw yet? (A resumed round's rows, bottom up.)
function Board:ballShown(now,y,rowHeight)
 local reveal=self.reveal
 if not reveal or reveal.kind~="resume"or not self:on()then return true end
 local t=now-reveal.at
 if t>Fresh.RowMax+.05 then self.reveal=nil;return true end
 return Fresh.rowShown(y,rowHeight,t)
end
-- The difficulty card's one pop, a beat after input goes live.
function Board:stepperPop(now)
 local at=self.arrivedAt
 if not at or self.popped==at or now-at<Feel.Stepper.popAt then return false end
 self.popped=at
 return true
end

-- ── Wedge (2) ───────────────────────────────────────────────────────────────────────────────────────────────────
function Board:dragBegin(x)self.drag={x=x,dir=nil,movedAt=0}end
function Board:dragMove(x,now)
 local d=self.drag;if not d then return end
 Feel.dragStep(d,x-(d.x or x),now);d.x=x
end
function Board:dragEnd()self.drag=nil end
-- `heldSum` is the held aim keys' summed direction; `live` is an aimable round with nothing over it.
function Board:stepWedge(heldSum,live,now)
 local feel=self.deps.deck and self.deps.deck.feel
 local want=nil
 if self:on()and live then
  local dir=nil
  if self.drag then dir=Feel.dragStep(self.drag,0,now)end
  want=Feel.aimWedge(heldSum,dir,nil)
 end
 if want==self.wedge or not feel then return end
 if self.wedge then feel:hold(self.wedge,false,now)end
 if want then feel:hold(want,true,now)end
 self.wedge=want
end

-- ── Life (4) ────────────────────────────────────────────────────────────────────────────────────────────────────
-- A drop leaves the dispenser at `x` (overlay px), its lane `width` px wide.
function Board:drop(x,width,now)
 if not self:on()then return end
 self.firstDropAt=self.firstDropAt or now
 self.shot.lane={at=now,x=x,width=width}
end
-- The first contact at `point` (overlay px).
function Board:land(point,now)
 if not self:on()or self:reduced()or typeof(point)~="Vector2"then return end
 self.shot.dust={at=now,point=point}
end
-- A merge of `tier` (its light colour) on a chain.
function Board:merge(color,chain,now)
 if not self:on()then return end
 self.shot.border={at=now,color=color}
 if(chain or 0)>=Feel.Life.glow.from then self.shot.glow={at=now,chain=chain}end
 if not self:reduced()then self.jumps+=1 end
end
-- What the LEFT / RIGHT tags show after the first drop: `base` faded out over .3 s.
function Board:zoneTag(base,now)
 if not self:on()or not self.firstDropAt then return base end
 local k=math.clamp((now-self.firstDropAt)/.3,0,1)
 return base+(1-base)*k
end
-- One calm 15 Hz step. state: {presented, pressure, drops}.
function Board:step(now,state)
 if not self:on()then self:restore();return end
 if now-self.stepAt<Feel.Life.step then return end
 self.stepAt=now;self.restored=false
 local reduced=self:reduced()
 local presented=state.presented==true
 -- The pattern's drift (a cell per 16 s; merges jump it).
 local pattern=self.deps.pattern and self.deps.pattern()
 if pattern and pattern.setDrift then
  if reduced or not presented then pattern:setDrift(nil)
  else pattern:setDrift(Feel.patternOffset(now,pattern:cellPx(),pattern:periodPx(),self.jumps))end
 end
 -- The FILL LINE: dashes march left, ease to coral near the line; the tag to 40% after the first drop.
 local danger=self.deps.danger and self.deps.danger()
 if danger and danger.feel then
  local near=Feel.nearAmount(state.pressure)
  local r,g,b=Feel.lineColor(near)
  local period=0
  local dashes=danger.dashes
  if dashes and dashes.AbsoluteSize.X>0 then period=dashes.AbsoluteSize.X/math.max(1,#dashes:GetChildren())end
  danger:feel(if reduced or period<=0 then 0 else math.round(Feel.dashOffset(now,period,near>0)),Color3.new(r,g,b),self.firstDropAt~=nil)
 end
 -- LEFT / RIGHT fade out after the first drop.
 for _,zone in ipairs(self.deps.zones or {})do
  if zone.tag and self.firstDropAt then
   local want=self:zoneTag(zone.tag:GetAttribute("FeelBase")or .45,now)
   if zone.tag.TextTransparency<want then zone.tag.TextTransparency=want end
  end
 end
 -- One-shots.
 local lane=self.shot.lane
 local a=if lane then Feel.laneAt(now-lane.at)else 0
 if a>0 then
  self.lane.Position=UDim2.new(0,lane.x,0,0);self.lane.Size=UDim2.new(0,math.max(4,lane.width),1,0)
  self.lane.BackgroundTransparency=1-a;self.lane.Visible=true
 elseif self.lane.Visible then self.lane.Visible=false;self.shot.lane=nil end
 local border=self.shot.border
 local b=if border then Feel.borderAt(now-border.at)else 0
 if b>0 then
  self.borderStroke.Color=border.color;self.borderStroke.Transparency=1-.85*b;self.border.Visible=true
 elseif self.border.Visible then self.border.Visible=false;self.shot.border=nil end
 local glow=self.shot.glow
 local gl=if glow and not reduced then Feel.glowAt(now-glow.at,glow.chain)else 0
 if gl>0 then self.glow.BackgroundTransparency=1-gl;self.glow.Visible=true
 elseif self.glow.Visible then self.glow.Visible=false;self.shot.glow=nil end
 local dust=self.shot.dust
 for j,pixel in ipairs(self.dust)do
  local x,y,alpha=0,0,0
  if dust and not reduced then x,y,alpha=Feel.dustAt(j,now-dust.at)end
  if alpha>0 then
   pixel.Position=UDim2.fromOffset(math.round(dust.point.X+x),math.round(dust.point.Y+y));pixel.BackgroundTransparency=1-alpha*.8;pixel.Visible=true
  elseif pixel.Visible then pixel.Visible=false end
 end
 if dust and now-dust.at>=Feel.Life.dust.life then self.shot.dust=nil end
end
-- Everything back to the deck as it was (the switch turned off mid-session, or the deck closed).
function Board:restore()
 if self.restored then return end
 self.restored=true
 local pattern=self.deps.pattern and self.deps.pattern()
 if pattern and pattern.setDrift then pattern:setDrift(nil)end
 local danger=self.deps.danger and self.deps.danger()
 if danger and danger.feel then danger:feel(nil,nil,false)end
 for _,frame in ipairs({self.lane,self.border,self.glow})do frame.Visible=false end
 for _,pixel in ipairs(self.dust)do pixel.Visible=false end
 table.clear(self.shot)
 local feel=self.deps.deck and self.deps.deck.feel
 if self.wedge and feel then feel:hold(self.wedge,false)end
 self.wedge=nil
end
return Board
