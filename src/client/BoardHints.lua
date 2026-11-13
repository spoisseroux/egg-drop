-- Two small board notes over the Pocket Deck board (QA 2026-11-13 Q1 items 7, 11).
--  * Settling: after the last ball the server waits FieldRun.SettleSeconds (4 s)
--    before it ends the round. The board now says so: a "Settling…" chip with a
--    bar that fills over the wait and three soft ticks, so the wait never looks
--    stuck. Client presentation only; the server rule is unchanged.
--  * First-drop idle hint (approved): on a first-time round (the Welcome round with
--    no drop yet) a small bobbing "aim / drop" hint shows after ~6 s without a drop,
--    in the glyphs of the last input. The first drop hides it for the session.
-- Both sit in their own host over the board rect (like the item carousel), never
-- take input and are cut to static under Reduced Motion.
local Kit=require(script.Parent.DeckKit)
local Hints={}
Hints.__index=Hints
Hints.SettleSeconds=4 -- mirrors FieldRun.SettleSeconds (server)
Hints.IdleDelay=6
Hints.TickCue="desc_tick"
Hints.TickTimes={0,1,2,3}
Hints.SettleText="Settling…"

-- ── Pure rules (spec-checked) ───────────────────────────────────────────────
-- The hint line in the glyphs of the last input.
function Hints.idleText(input)
 if input=="Gamepad"then return "◀▶ aim  ·  A to drop"end
 if input=="Touch"then return "Drag to aim  ·  tap A to drop"end
 return "← → aim  ·  Space to drop"
end
-- A first-time round: the Welcome round before its first drop.
function Hints.firstRun(phase,drops)
 return phase=="Welcome"and(drops or 0)==0
end
-- Show the idle hint? state: firstRun, dropped (this session), live (the player can
-- aim and drop right now), idleFor (seconds live without a drop).
function Hints.idleWanted(state)
 return state.firstRun==true and state.dropped~=true and state.live==true and(state.idleFor or 0)>=Hints.IdleDelay
end
-- Settle bar fill 0..1 for the seconds since settling began.
function Hints.settleProgress(elapsed)
 return math.clamp((elapsed or 0)/Hints.SettleSeconds,0,1)
end
-- Tick indices crossed between two elapsed times (each tick plays once).
function Hints.ticksBetween(before,after)
 local out={}
 for index,at in ipairs(Hints.TickTimes)do
  if(before==nil or before<at)and after>=at then table.insert(out,index)end
 end
 return out
end

-- ── Instances ───────────────────────────────────────────────────────────────
function Hints.new(parent,options)
 options=options or {}
 local z=options.z or 37
 local self=setmetatable({audio=options.audio,dropped=false,idleSince=nil},Hints)
 local host=Kit.node("Frame",parent,{Name="BoardHints",BackgroundTransparency=1,ZIndex=z,Active=false,Size=UDim2.fromOffset(0,0)})
 self.host=host
 -- Settling chip: top centre of the board.
 local settle=Kit.frame(host,"Settling","well",UDim2.new(.5,0,0,10),UDim2.fromOffset(132,34),999)
 settle.AnchorPoint=Vector2.new(.5,0);settle.ZIndex=z+1;settle.BackgroundTransparency=.08;settle.Visible=false
 Kit.stroke(settle,"stars",1.5,.2)
 self.settleText=Kit.text(settle,"Strong",Hints.SettleText,"text",{Name="Label",Position=UDim2.fromOffset(14,3),Size=UDim2.new(1,-28,0,18),TextSize=14,TextXAlignment=Enum.TextXAlignment.Center})
 local track=Kit.frame(settle,"Track","raised",UDim2.new(0,14,1,-10),UDim2.new(1,-28,0,4),999)
 track.BackgroundTransparency=0
 local fill=Kit.frame(track,"Fill",nil,UDim2.new(),UDim2.fromScale(0,1),999)
 fill.BackgroundTransparency=0;fill.BackgroundColor3=Kit.Color.stars
 self.settle,self.settleFill,self.settleStroke=settle,fill,settle:FindFirstChild("KitStroke")
 -- Idle hint: a pill a little above the board's middle (clear of the fill line).
 local hint=Kit.frame(host,"IdleHint","well",UDim2.new(.5,0,.3,0),UDim2.fromOffset(240,40),999)
 hint.AnchorPoint=Vector2.new(.5,.5);hint.ZIndex=z+1;hint.BackgroundTransparency=.06;hint.Visible=false
 Kit.stroke(hint,"accent",2,0)
 self.hintText=Kit.text(hint,"Strong","","text",{Name="Line",Size=UDim2.fromScale(1,1),TextSize=15,TextXAlignment=Enum.TextXAlignment.Center})
 self.hintScale=Kit.node("UIScale",hint,{Scale=1})
 self.hint=hint
 return self
end

-- `position`/`size`: the board's rect in the parent (the board viewport's UDim2s).
function Hints:place(position,size)
 self.host.Position=position;self.host.Size=size
 local W=size.X.Offset
 if W<=0 then W=self.host.AbsoluteSize.X end
 self.W=W
 self:sizeHint()
end
function Hints:sizeHint()
 local text=self.hintText.Text
 local size=if(self.W or 300)<220 then 13 else 15
 self.hintText.TextSize=size
 local w=math.ceil(Kit.measure(text,"Strong",size).X)+32
 self.hint.Size=UDim2.fromOffset(math.min(w,math.max(120,(self.W or 300)-12)),if size<15 then 34 else 40)
 self.hintText.TextWrapped=w>(self.W or 300)-12
end

-- The first drop of the session hides the idle hint for good.
function Hints:noteDrop()
 self.dropped=true
 self.hint.Visible=false
end

-- Per frame. state: presented (the board is on screen), settling, live, firstRun,
-- input ("Keyboard"|"Gamepad"|"Touch"), reduced.
function Hints:step(now,state)
 local presented=state.presented==true
 -- Settling.
 local settling=presented and state.settling==true
 if settling then
  if not self.settleAt then self.settleAt=now;self.settleLast=nil end
  local elapsed=now-self.settleAt
  self.settle.Visible=true
  self.settleFill.Size=UDim2.fromScale(Hints.settleProgress(elapsed),1)
  if state.reduced then self.settleStroke.Transparency=.2
  else self.settleStroke.Transparency=.2+.5*(.5+.5*math.sin(elapsed*math.pi*2))end
  local dots=if state.reduced then 3 else math.floor(elapsed*3)%3+1
  local text="Settling"..string.rep(".",dots)
  if self.settleText.Text~=text then self.settleText.Text=text end
  for index in ipairs(Hints.ticksBetween(self.settleLast,elapsed))do
   if self.audio and self.audio.play then self.audio:play(Hints.TickCue,.9+.08*(index-1),.2)end
  end
  self.settleLast=elapsed
 else
  self.settleAt,self.settleLast=nil,nil
  if self.settle.Visible then self.settle.Visible=false end
 end
 -- Idle hint.
 local live=presented and state.live==true and not settling
 if live then self.idleSince=self.idleSince or now else self.idleSince=nil end
 local want=Hints.idleWanted({firstRun=state.firstRun,dropped=self.dropped,live=live,idleFor=if self.idleSince then now-self.idleSince else 0})
 if want then
  local text=Hints.idleText(state.input)
  if self.hintText.Text~=text then self.hintText.Text=text;self:sizeHint()end
  if not self.hint.Visible then
   self.hint.Visible=true;self.shownAt=now
  end
  local t=now-(self.shownAt or now)
  if state.reduced then
   self.hint.Position=UDim2.new(.5,0,.3,0);self.hintScale.Scale=1
  else
   -- Pops in (220 ms), then bobs 4 px and sways 6 px like an aim nudge.
   local pop=math.clamp(t/.22,0,1)
   self.hintScale.Scale=.8+.2*(1-(1-pop)^3)
   self.hint.Position=UDim2.new(.5,math.floor(math.sin(t*2.4)*6+.5),.3,math.floor(math.sin(t*4.8)*2-2+.5))
  end
 elseif self.hint.Visible then
  self.hint.Visible=false
 end
end

function Hints:destroy()self.host:Destroy()end

return Hints
