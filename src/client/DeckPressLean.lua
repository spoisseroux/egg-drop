-- The body press (DECK-FEEL-BRIEF 3, Spencer beta 40 note 11: "animate the pocket deck to kinda warp on the side the
-- button is being pressed"). Behind Alive "deckfeel" (DeckFeel.switch). No GUI Rotation (it breaks ClipsDescendants
-- and blurs the pixel art): the tilt is faked by a small offset of the whole handheld, a soft shade on the pressed half
-- and the LCD counter-moving 1 px (the screen sits deeper than the keys).
--
-- One position writer: DeckMergeJolt composes this offset (Jolt:setLean), so Jolt:appliedOffset includes it and touch
-- aim never shifts. A merge jolt wins while it runs; a drop's 2 px kick adds to the lean under the 3 px cap.
-- Reduced Motion: none of it. Motion: Low: the shade only.
local Lean={};Lean.__index=Lean

-- Body offset (x, y px) per control.
Lean.Offsets=table.freeze({A=table.freeze({2,3}),B=table.freeze({2,2}),Left=table.freeze({-2,2}),Right=table.freeze({1,2}),
 Up=table.freeze({0,1}),Down=table.freeze({0,2})})
-- The pressed half: right for A and B, left for the d-pad.
Lean.Side=table.freeze({A="right",B="right",Left="left",Right="left",Up="left",Down="left"})
Lean.Cap=3            -- px, total, never stacks
Lean.Down=.07         -- Quad Out into the press
Lean.Frequency,Lean.Damping=5,.45 -- back on a spring (one small overshoot under 1 px)
Lean.Compact=.6       -- phones scale the offsets
Lean.Shade=.08        -- black at 8% at the pressed edge to 0% at the body centre
Lean.Parallax=1       -- the LCD counter-moves 1 px

local function cap(x,y)
 local m=math.sqrt(x*x+y*y)
 if m>Lean.Cap then x,y=x*Lean.Cap/m,y*Lean.Cap/m end
 return x,y
end
Lean.cap=cap

-- Pure: the target offset for a control (scaled on a phone, capped).
function Lean.target(id,compact)
 local o=Lean.Offsets[id]
 if not o then return 0,0 end
 local k=if compact then Lean.Compact else 1
 return cap(o[1]*k,o[2]*k)
end
-- Pure: an underdamped spring released from x0 (velocity 0), t seconds on.
function Lean.springAt(x0,t)
 local w=2*math.pi*Lean.Frequency
 local z=Lean.Damping
 local wd=w*math.sqrt(1-z*z)
 return math.exp(-z*w*t)*(x0*math.cos(wd*t)+(z*w*x0/wd)*math.sin(wd*t))
end
-- Pure: what runs for the motion settings.
function Lean.allows(reduced,motionLow)
 if reduced then return{offset=false,shade=false}end
 if motionLow then return{offset=false,shade=true}end
 return{offset=true,shade=true}
end
-- Pure: the LCD's counter-move for a body offset (1 px the other way on each axis that moved a whole pixel).
function Lean.parallax(x,y)
 local px=if math.abs(x)>=1 then -math.sign(x)*Lean.Parallax else 0
 local py=if math.abs(y)>=1 then -math.sign(y)*Lean.Parallax else 0
 return px,py
end
-- Pure: the one presentation offset for this frame. A running merge jolt wins outright; otherwise the lean plus a
-- drop's kick, capped at 3 px.
function Lean.compose(mergeOffset,lean,drop)
 if mergeOffset then return mergeOffset.X,mergeOffset.Y end
 local x,y=(lean and lean.X or 0)+(drop and drop.X or 0),(lean and lean.Y or 0)+(drop and drop.Y or 0)
 if lean and(lean.X~=0 or lean.Y~=0)then x,y=cap(x,y)end
 return x,y
end

-- State: one control leans at a time (the last pressed); releasing it springs back from where it was.
function Lean.new()
 return setmetatable({x=0,y=0,id=nil,from={0,0},downAt=nil,upAt=nil,upFrom={0,0},shade=0,side=nil,compact=false},Lean)
end
function Lean:press(id,now,compact)
 if not Lean.Offsets[id]then return false end
 self.id,self.downAt,self.upAt=id,now,nil
 self.from={self.x,self.y};self.side=Lean.Side[id];self.compact=compact==true
 return true
end
function Lean:release(id,now)
 if self.id~=id then return false end
 self.id,self.upAt,self.upFrom,self.upShade=nil,now,{self.x,self.y},self.shade
 return true
end
-- A one-off kick (the results' win bounce): leans by (x, y) and springs straight back.
function Lean:kick(x,y,now)
 x,y=cap(x,y)
 self.id,self.downAt=nil,nil
 self.upAt,self.upFrom,self.upShade=now,{x,y},0;self.x,self.y=x,y;self.side=nil
end
-- Advances to `now`: returns x, y (px, float) and the shade's strength 0..1.
function Lean:step(now)
 if self.id and self.downAt then
  local tx,ty=Lean.target(self.id,self.compact)
  local u=math.clamp((now-self.downAt)/Lean.Down,0,1);u=1-(1-u)*(1-u)
  self.x=self.from[1]+(tx-self.from[1])*u;self.y=self.from[2]+(ty-self.from[2])*u
  self.shade=u
 elseif self.upAt then
  local t=now-self.upAt
  self.x=Lean.springAt(self.upFrom[1],t);self.y=Lean.springAt(self.upFrom[2],t)
  self.shade=(self.upShade or 0)*math.max(0,1-t/.15) -- the shade fades with the release
  if t>1.2 then self.x,self.y,self.upAt,self.shade=0,0,nil,0 end
 else
  self.x,self.y,self.shade=0,0,0
 end
 return self.x,self.y,self.shade
end
function Lean:reset()self.x,self.y,self.id,self.downAt,self.upAt,self.shade=0,0,nil,nil,nil,0 end
return Lean
