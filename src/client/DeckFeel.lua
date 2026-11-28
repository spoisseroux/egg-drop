-- The Pocket Deck feel pass (DECK-FEEL-BRIEF, Fable 2026-11-27, beta 40 notes 9-17). Pure rules only: the numbers and
-- shapes of the open transition (1), the buttons that mirror every input (2), the playfield life (4), the difficulty
-- card stepper (6), the panel polish (7) and the results sequence (8). The body press lives in DeckPressLean (3); the
-- stale-balls gate and the resumed round's rows in DeckFresh (5). Presentation only: nothing here reads or writes the
-- sim, the score, a payout or any server state.
--
-- Behind Alive "deckfeel" (AliveDeckFeel, beta and Studio, ConfigService `alive_deckfeel`, owner chat
-- /alive deckfeel on|off|clear). Off is the deck exactly as before (the stale-balls fix in DeckFresh is always on).
-- Reduced Motion (Kit.reduced, Roblox's setting) and the game's Motion: Low (board ReducedEffects) are each section's
-- own lines below.
local Shared=game:GetService("ReplicatedStorage").Shared
local Alive=require(Shared.Alive)

local Feel={}
Feel.Feature="deckfeel"

-- The switch. Specs set an override (true / false / nil = the real switch).
local override=nil
function Feel.setSwitch(value)override=value end
function Feel.switch()
 if override~=nil then return override==true end
 local ok,on=pcall(Alive.on,Feel.Feature)
 return ok and on==true
end

local function smooth(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end
local function quadOut(u)u=math.clamp(u,0,1);return 1-(1-u)*(1-u)end
local function cubicOut(u)u=math.clamp(u,0,1);return 1-(1-u)^3 end
Feel.quadOut,Feel.cubicOut,Feel.smooth=quadOut,cubicOut,smooth

-- ── 1. Open transition ──────────────────────────────────────────────────────────────────────────────────────────
-- Every open: 1.25 s to playable (was about 2.6). Seconds from the open's start.
Feel.Open=table.freeze({
 shade=.20,        -- 0-.20 the shade in (Quad Out)
 rise=.38,         -- .20-.58 the handheld arrives (Back Out, a 4 px overshoot)
 from=.42,         -- from 0.42 body heights below
 scaleFrom=.92,    -- UIScale on the device root, .92 -> 1
 overshoot=4,      -- px past rest
 uncover=.30,      -- the shade lifts while the handheld rises
 scan=.12,         -- .58-.70 the scanline opens the LCD from its centre (Quad Out)
 scanHeight=2,scanColor=table.freeze({118,246,176}),
 cue="deck_boot",cueVolume=.4,
 markFrame=21,mark=.20, -- .70-.90 the wordmark frame held
 lit=.15,          -- .90-1.05 the LCD content fades in
 panelRise=6,panelGap=.03,panelTween=.14, -- the panels stagger up 6 px, 30 ms apart (Quad Out .14 each)
 live=1.05,        -- input is live
 ballFrom=10,ballFall=.08,squash=table.freeze({1.12,.88}),squashFor=.12, -- 1.05-1.25 the held ball drops in
 total=1.25,
 skipFrom=.15,     -- the first open's full boot: any press from .15 s skips to the wordmark
})
-- The phase timeline of an ordinary (not first) open: {name, start, length}.
Feel.OpenPhases=table.freeze({
 table.freeze({"shade",0,.20}),table.freeze({"rise",.20,.38}),table.freeze({"scan",.58,.12}),
 table.freeze({"mark",.70,.20}),table.freeze({"lit",.90,.15}),table.freeze({"ball",1.05,.20}),
})
function Feel.openPhase(t)
 for _,phase in ipairs(Feel.OpenPhases)do if t<phase[2]+phase[3]then return phase[1],math.clamp((t-phase[2])/phase[3],0,1)end end
 return nil,1
end
-- The full 1.67 s boot sheet only on the session's first open (`boots` = opens already played this session).
function Feel.fullBoot(boots)return(boots or 0)<=0 end
-- The handheld `t` seconds into its rise from `distance` px below: its y offset (px, + is down) and its scale.
-- A cubic approach that settles through a 4 px overshoot (never more), at rest at the end.
function Feel.riseAt(t,distance)
 local O=Feel.Open
 local u=math.clamp(t/O.rise,0,1)
 local approach=math.clamp(u/.75,0,1)
 local y=distance*(1-approach)^3-O.overshoot*math.sin(math.pi*math.clamp((u-.55)/.45,0,1))
 if u>=1 then y=0 end
 return y,O.scaleFrom+(1-O.scaleFrom)*cubicOut(u)
end
-- The scanline's open fraction of the LCD's height (0 = the 2 px line, 1 = full height).
function Feel.scanAt(t)return quadOut(t/Feel.Open.scan)end
-- The panels' order and delays: left column top to bottom, then the well, then the right column. `items` are
-- {x, y, w, id}; `left` and `right` are the well's edges. Returns {id, delay} in order.
function Feel.panelOrder(items,left,right)
 local columns={{},{},{}}
 for _,item in ipairs(items)do
  local mid=item.x+(item.w or 0)/2
  local column=if mid<left then 1 elseif mid>right then 3 else 2
  table.insert(columns[column],item)
 end
 local out={}
 for _,column in ipairs(columns)do
  table.sort(column,function(a,b)return a.y<b.y end)
  for _,item in ipairs(column)do table.insert(out,{id=item.id,delay=#out*Feel.Open.panelGap})end
 end
 return out
end
-- A panel `t` seconds after its own delay: its y offset (px, + is down) and its transparency share (1 = hidden).
function Feel.panelAt(t)
 local e=quadOut(t/Feel.Open.panelTween)
 return Feel.Open.panelRise*(1-e),1-e
end
-- The held ball `t` seconds after input goes live: dy (px, - is up), x and y scale. Falls 10 px (.08 s), then one
-- squash (1.12 x .88) that eases back over .12 s; at rest after.
function Feel.ballDrop(t)
 local O=Feel.Open
 if t<0 then return -O.ballFrom,1,1 end
 if t<O.ballFall then local u=t/O.ballFall;return -O.ballFrom*(1-u*u),1,1 end
 local u=(t-O.ballFall)/O.squashFor
 if u>=1 then return 0,1,1 end
 local k=math.sin(math.pi*.5*(1-u))
 return 0,1+(O.squash[1]-1)*k,1+(O.squash[2]-1)*k
end
-- First open after loading (one handoff): the loading sky cross-fades to the shade colour while its pals and title
-- fade; the garden is never shown in between.
Feel.Handoff=table.freeze({sky=.30,pals=.20,wait=12,hold=1.5})
-- Reduced Motion: a .2 s shade cross-fade, the deck at rest and the still logo for .4 s (today's stillBoot).
Feel.ReducedOpen=table.freeze({shade=.2,still=.4})
-- The transition's phase lengths under the switch (DeckTransition.Timing's keys).
Feel.Timing=table.freeze({Cover=.20,Rise=.38,Uncover=.30,Lit=.15,Shutter=.16,Sink=.30,Lift=.32,Drop=.42})

-- ── 2. Buttons mirror every input ───────────────────────────────────────────────────────────────────────────────
Feel.Hold=table.freeze({
 down=.06,minHold=.09,flash=.10, -- A goes down in 60 ms; it shows for 90 ms at least; flash = hold + release after .10
 letterDrop=.07,pressScale=.94,  -- the letter drops 7% of the diameter, the button presses to .94
 frequency=4.5,damping=.32,      -- up on a spring (Kit.Press)
 dragOn=3,dragOff=.12,           -- touch drag: on above 3 px a frame, off after 120 ms still
 stick=.25,                      -- the stick past .25
 haptic=table.freeze({strength=.2,ms=18}), -- A on touch: an 18 ms light tick (none for the d-pad)
})
-- Beta 41 review: the drawn keys' touch holds, by the touch that pressed them. A touch that ends anywhere (off the key:
-- UserInputService.InputEnded) lets its key go, and the deck closing lets every one go. Pure bookkeeping.
local Touches={};Touches.__index=Touches
function Feel.touches()return setmetatable({held={}},Touches)end
function Touches:down(input,id)if input~=nil and id~=nil then self.held[input]=id end end
-- The key this touch held (and now lets go), or nil.
function Touches:up(input)
 local id=self.held[input]
 self.held[input]=nil
 return id
end
-- Every key still held (each once), and none held after.
function Touches:clear()
 local out,seen={},{}
 for _,id in pairs(self.held)do if not seen[id]then seen[id]=true;table.insert(out,id)end end
 table.clear(self.held)
 table.sort(out)
 return out
end
function Touches:holding(id)for _,v in pairs(self.held)do if v==id then return true end end;return false end
-- When a press that went down at `downAt` may show as released (never before the minimum hold).
function Feel.releaseAt(downAt,now)return math.max(now,(downAt or now)+Feel.Hold.minHold)end
-- Touch drag direction. `state` keeps {dir, movedAt} between frames; `dx` is this frame's pointer move (px).
function Feel.dragStep(state,dx,now)
 if math.abs(dx or 0)>Feel.Hold.dragOn then state.dir=if dx<0 then -1 else 1;state.movedAt=now
 elseif state.dir~=nil and now-(state.movedAt or now)>Feel.Hold.dragOff then state.dir=nil end
 return state.dir
end
function Feel.stickDirection(x)
 if type(x)~="number"or math.abs(x)<=Feel.Hold.stick then return 0 end
 return if x<0 then -1 else 1
end
-- Which d-pad wedge shows: held keys (their summed direction), else the touch drag, else the stick. nil = none.
function Feel.aimWedge(heldSum,dragDir,stickX)
 local d=if(heldSum or 0)~=0 then math.sign(heldSum)elseif dragDir and dragDir~=0 then dragDir else Feel.stickDirection(stickX)
 return if d<0 then "Left"elseif d>0 then "Right"else nil
end
-- A damped spring released from `x0` (velocity 0), `t` seconds on (analytic; underdamped).
function Feel.springAt(x0,t,frequency,damping)
 local w=2*math.pi*frequency
 local z=math.clamp(damping,0,.999)
 local wd=w*math.sqrt(1-z*z)
 return math.exp(-z*w*t)*(x0*math.cos(wd*t)+(z*w*x0/wd)*math.sin(wd*t))
end
-- A's press scale: down to .94 in 60 ms (Quad Out), up on the spring from the release; 1 at rest.
function Feel.pressScale(downFor,upFor)
 local H=Feel.Hold
 if upFor==nil then return 1-(1-H.pressScale)*quadOut((downFor or 0)/H.down)end
 return 1-Feel.springAt(1-H.pressScale,upFor,H.frequency,H.damping)
end

-- ── 4. Playfield life ───────────────────────────────────────────────────────────────────────────────────────────
Feel.Life=table.freeze({
 step=1/15,maxTweens=4,
 cellSeconds=16,mergeJump=1/8,    -- the well pattern drifts down one cell per 16 s; a merge jumps it 1/8 cell
 breathPx=1,breathPeriod=2.4,     -- the held ball breathes 1 px
 blinkMin=4,blinkMax=6,blinkFrames=2, -- and blinks every 4 to 6 s for two frames
 aimPeriod=.6,                    -- the aim dots march down one spacing per .6 s
 dashSpeed=8,nearSpeed=2,lineLabel=.4, -- FILL LINE dashes march left 8 px/s (2x near the line); the label to 40%
 dust=table.freeze({px=2,count=3,life=.18}), -- a 2 px puff of 3 pixels where the ball lands
 lane=table.freeze({tint=.04,life=.25}),     -- the lane the ball fell through lightens 4% for .25 s
 border=.2,                                  -- the well border flashes the merged tier's light (.2 s out)
 glow=table.freeze({from=3,alpha=.30,decay=1.2,color=table.freeze({255,211,92})}), -- chain x3+: the top edge glows gold
 near=table.freeze({color=table.freeze({255,120,96}),from=.35,maxHz=2}),
})
-- Every loop off under Reduced Motion and Motion: Low; the border flash and the lane tint stay.
function Feel.lifeAllows(feature,reduced)
 if feature=="border"or feature=="lane"then return true end
 return not reduced
end
-- The pattern's downward drift (px) at `t` seconds for a `cell` px pattern: quantised to the 15 Hz step, wrapped to
-- the pattern's period (`period` px, two rows).
function Feel.patternOffset(t,cell,period,jumps)
 local L=Feel.Life
 local stepped=math.floor(t/L.step)*L.step
 local px=stepped*cell/L.cellSeconds+(jumps or 0)*cell*L.mergeJump
 return math.floor(px%math.max(1,period))
end
function Feel.breath(t)
 local L=Feel.Life
 return L.breathPx*math.sin(2*math.pi*t/L.breathPeriod)
end
-- Blinks: a deterministic 4-6 s schedule (a hash of the blink's index), each two LCD frames long.
local function interval(n)
 local h=math.sin(n*12.9898+4.1414)*43758.5453
 local f=h-math.floor(h)
 return Feel.Life.blinkMin+(Feel.Life.blinkMax-Feel.Life.blinkMin)*f
end
function Feel.blinkAt(t,frame)
 frame=frame or 1/30
 local at,n=0,1
 while at<=t do
  at+=interval(n)
  if t>=at and t<at+Feel.Life.blinkFrames*frame then return true end
  n+=1
  if n>10000 then break end
 end
 return false
end
-- The aim dots' march, 0..1 of one spacing.
function Feel.aimPhase(t)return(t/Feel.Life.aimPeriod)%1 end
-- The FILL LINE dashes' offset (px, <= 0) for a dash `period` px wide: left at 8 px/s, twice that near the line.
function Feel.dashOffset(t,period,near)
 local speed=Feel.Life.dashSpeed*(if near then Feel.Life.nearSpeed else 1)
 period=math.max(1,period)
 return -((t*speed)%period)
end
-- How near the pile is (0..1 from OverflowPressure): the line's colour eases from white to coral. No flashing.
function Feel.nearAmount(pressure)
 local from=Feel.Life.near.from
 return math.clamp(((pressure or 0)-from)/(1-from),0,1)
end
function Feel.lineColor(near)
 local c=Feel.Life.near.color
 local k=smooth(near or 0)
 return 1+(c[1]/255-1)*k,1+(c[2]/255-1)*k,1+(c[3]/255-1)*k
end
-- One-shot shapes (age in seconds): 0..1 strength, 0 when over.
function Feel.laneAt(age)return if age<0 or age>=Feel.Life.lane.life then 0 else Feel.Life.lane.tint*(1-age/Feel.Life.lane.life)end
function Feel.borderAt(age)return if age<0 or age>=Feel.Life.border then 0 else 1-quadOut(age/Feel.Life.border)end
function Feel.glowAt(age,chain)
 local G=Feel.Life.glow
 if(chain or 0)<G.from or age<0 or age>=G.decay then return 0 end
 return G.alpha*(1-age/G.decay)
end
-- Dust: pixel `j` of 3, `age` seconds on: x, y (px from the landing point), alpha (0 = gone).
function Feel.dustAt(j,age)
 local D=Feel.Life.dust
 if age<0 or age>=D.life then return 0,0,0 end
 local u=age/D.life
 local dir=({-1,0,1})[((j-1)%3)+1]
 return dir*D.px*2*quadOut(u),-D.px*quadOut(u)*(if dir==0 then 1.5 else 1),1-u
end

-- ── 6. Difficulty on reopen ─────────────────────────────────────────────────────────────────────────────────────
Feel.Stepper=table.freeze({
 lip=4,popAt=.15,pop=table.freeze({1.08,.28}),settle=.12,roll=.2,
 tints=table.freeze({easy=table.freeze({95,227,154}),medium=table.freeze({255,211,92}),hard=table.freeze({255,120,96})}),
})
-- The card is the control while the round is untouched: no drop yet, the heat not frozen, not over.
function Feel.stepperLive(drops,frozen,over,guided)
 return(drops or 0)==0 and frozen~=true and over~=true and guided~=true
end
-- Tap cycles Easy -> Medium -> Hard -> Easy (wrap); Up / Down step and stop at the ends.
function Feel.stepLevel(order,key,delta,wrap)
 local at=table.find(order,key)or 1
 local n=#order
 local nextAt=at+delta
 if wrap then nextAt=((nextAt-1)%n)+1 else nextAt=math.clamp(nextAt,1,n)end
 return order[nextAt]
end
-- The one arrival pop (1 -> 1.08 -> 1 over .28 s) at `t` seconds after it starts; 1 outside.
function Feel.stepperPop(t)
 local P=Feel.Stepper.pop
 if t<0 or t>=P[2]then return 1 end
 return 1+(P[1]-1)*math.sin(math.pi*t/P[2])
end
function Feel.levelTint(key)
 local c=Feel.Stepper.tints[string.lower(tostring(key or ""))]
 if not c then return nil end
 return c[1],c[2],c[3]
end
-- The full-LCD picker stays for the first ever round and "Up on Replay"; otherwise the card is the control.
function Feel.pickerWanted(firstEver,askedForPicker)return firstEver==true or askedForPicker==true end

-- ── 7. Panel polish ─────────────────────────────────────────────────────────────────────────────────────────────
Feel.Polish=table.freeze({
 radius=18,radiusCompact=12,gap=12,gapCompact=8,
 pill=table.freeze({x=14,y=12,h=24,pad=10,radius=8,lip=2}),
 pillCompact=table.freeze({x=10,y=8,h=20,pad=8,radius=6,lip=2}),
 contentGap=12,side=14,
 highlight=.86,stroke=.82, -- 1 px top highlight white 14%, 1 px inner stroke black 18%
 wellRadius=12,wellShadow=3,
 punch=table.freeze({1.14,.16}),ballsEase=.25,ballsDrop=2,chainPop=table.freeze({1.3,.04}),goalFill=.3,nextBob=1,
})
-- The tag pill for an eyebrow `textW` px wide: its rect and the label's new position inside it. A one-row card
-- (`rowH`, the label centred in the card) keeps its vertical centre and takes the side inset only.
-- `contentTop` (a fixed card whose first line starts there): the pill keeps 2 px clear of it, shrinking to 16 px tall
-- and then moving up (to 4 px in at least) on a card too tight for the full pill.
Feel.PillMin=16
function Feel.pillRect(textW,compact,rowH,contentTop)
 local P=if compact then Feel.Polish.pillCompact else Feel.Polish.pill
 local w=math.ceil(textW)+2*P.pad
 local h=P.h
 local y=if rowH then math.floor((rowH-P.h)/2)else P.y
 if not rowH and contentTop then
  local room=contentTop-2
  if y+h>room then h=math.max(Feel.PillMin,room-y)end
  if y+h>room then y=math.max(4,room-h)end
 end
 return{x=P.x,y=y,w=w,h=h,labelX=P.x+P.pad,labelY=y,radius=P.radius,lip=P.lip}
end
-- How far a card's content moves down so it starts `contentGap` under the pill, never past the card's foot.
function Feel.contentShift(pillBottom,contentTop,contentBottom,cardH,compact)
 local gap=if compact then 8 else Feel.Polish.contentGap
 local want=pillBottom+gap-contentTop
 local room=cardH-6-contentBottom
 return math.max(0,math.floor(math.min(want,room)))
end
function Feel.cardRadius(compact)return if compact then Feel.Polish.radiusCompact else Feel.Polish.radius end
-- Motion on change only. The score's punch (1 -> 1.14 -> 1 over .16 s), the balls-left number's 2 px tick down, the
-- chain dots' pop in turn (1.3, 40 ms apart), the next balls' 1 px bob (half a beat apart).
function Feel.punchAt(t)
 local P=Feel.Polish.punch
 if t<0 or t>=P[2]then return 1 end
 return 1+(P[1]-1)*math.sin(math.pi*t/P[2])
end
function Feel.tickAt(t)
 local d=Feel.Polish.ballsEase
 if t<0 or t>=d then return 0 end
 return Feel.Polish.ballsDrop*(1-quadOut(t/d))
end
function Feel.dotPop(t,index)
 local P=Feel.Polish.chainPop
 local local_=t-(index-1)*P[2]
 if local_<0 or local_>=.16 then return 1 end
 return 1+(P[1]-1)*math.sin(math.pi*local_/.16)
end
function Feel.bobAt(t,index)
 return Feel.Polish.nextBob*math.sin(2*math.pi*(t/Feel.Life.breathPeriod)+(index-1)*math.pi)
end

-- ── 8. Results ──────────────────────────────────────────────────────────────────────────────────────────────────
Feel.Results=table.freeze({
 headline=table.freeze({from=1.6,rotation=-4,seconds=.22}),
 goalAt=.15,goalGap=.09,stamp=table.freeze({from=1.4,wobble=3,seconds=.14}),
 rowAt=.30,rowGap=.12,rowFlip=.14,
 starAt=.60,rays=.3,squash=table.freeze({1.14,.86,.16}),
 countFrom=.6,countTo=1.5,pulseEvery=5,pulse=1.04,blip=table.freeze({1,1.5}),
 totalAt=1.5,punch=1.25,burst=12,burstClose=6,burstLife=.6,
 bestAt=1.7,buttonsAt=1.9,rise=8,riseFor=.16,
 confetti=table.freeze({1.5,2.7}),confettiCount=16,bounce=3,dim=.4,
 miniStars=5,miniFlight=.22,
})
-- "win" (a cleared round), "close" (missed, at least one goal reached) or "loss".
function Feel.resultKind(outcome,goalsDone)
 if outcome=="clear"then return "win"end
 if(goalsDone or 0)>0 then return "close"end
 return "loss"
end
-- The cues the moment the screen opens, by kind: {cue, pitch, volume}.
function Feel.openingCues(kind)
 if kind=="win"then return{{"win",1,.5},{"tag_slam",1,.5}}end
 if kind=="close"then return{{"streak_whoosh",1,.35}}end
 -- The old `lose` sting read sad: a hush and the meter's fill instead.
 return{{"reveal_hush",1,.35},{"meter_fill",1,.25}}
end
-- The timed beats RecapFeedback plays (RecapFeedback.setBeats' rows): goals .15 on, .09 apart, pitch +.06 each;
-- payout rows .30 on, .12 apart; the new best at 1.7. The Star's land (.6), the count's blips and the 1.5 finale
-- (bank + stars_total) are the clock's own (Feel.recapSpec).
function Feel.resultBeats(goals,rows,newBest)
 local R=Feel.Results
 local beats={}
 for index=1,(goals or 0)do table.insert(beats,{at=R.goalAt+(index-1)*R.goalGap,cue="goal_tick",pitch=1+(index-1)*.06,volume=.3})end
 for index=1,(rows or 0)do table.insert(beats,{at=R.rowAt+(index-1)*R.rowGap,cue="row_flip",pitch=1,volume=.3})end
 if newBest then table.insert(beats,{at=R.bestAt,cue="new_best",pitch=1,volume=.4})end
 return beats
end
-- RecapFeedback's clock under the switch: the Star lands at .6, the count runs .6 to 1.5 with its pitch rising 1.0
-- to 1.5, the finale (bank + stars_total) at 1.5, no early bank chips.
function Feel.recapSpec()
 local R=Feel.Results
 return{dropAt=R.starAt,countStart=R.countFrom,countSpan=R.countTo-R.countFrom,finaleAt=R.totalAt,blipFrom=R.blip[1],blipTo=R.blip[2],banks=false}
end
function Feel.blipPitch(counted,total)
 local R=Feel.Results
 if(total or 0)<=1 then return R.blip[1]end
 return R.blip[1]+(R.blip[2]-R.blip[1])*math.clamp((counted-1)/(total-1),0,1)
end
-- The Star pulses 1.04 on every fifth Star counted (for 90 ms).
function Feel.starPulse(counted,sinceTick)
 if(counted or 0)<=0 or counted%Feel.Results.pulseEvery~=0 or(sinceTick or 0)>=.09 then return 1 end
 return Feel.Results.pulse
end
-- The headline `t` seconds in: scale (1.6 -> 1, Back Out) and rotation (-4 -> 0).
local function backOut(x)local c=1.70158;return 1+(c+1)*(x-1)^3+c*(x-1)^2 end
Feel.backOut=backOut
function Feel.headlineAt(t)
 local H=Feel.Results.headline
 local u=math.clamp(t/H.seconds,0,1)
 local e=backOut(u)
 return H.from+(1-H.from)*e,H.rotation*(1-cubicOut(u))
end
-- A goal's stamp `t` seconds after its beat: scale (1.4 -> 1), rotation (a 3 degree wobble), shown.
function Feel.stampAt(t)
 local S=Feel.Results.stamp
 if t<0 then return S.from,0,false end
 local u=math.clamp(t/S.seconds,0,1)
 return S.from+(1-S.from)*cubicOut(u),S.wobble*math.sin(u*math.pi*2)*(1-u),true
end
-- A payout row `t` seconds after its beat: its flip (0 = edge on, 1 = flat) and shown.
function Feel.rowAt(t)
 if t<0 then return 0,false end
 return quadOut(t/Feel.Results.rowFlip),true
end
-- The Star's landing `t` seconds after .6: x and y scale (a squash 1.14 x .86 easing back).
function Feel.starLand(t)
 local S=Feel.Results.squash
 if t<0 or t>=S[3]then return 1,1 end
 local k=math.sin(math.pi*(1-t/S[3])*.5)
 return 1+(S[1]-1)*k,1+(S[2]-1)*k
end
-- The total's punch at 1.5 (1 -> 1.25 -> 1 over .2 s).
function Feel.totalPunch(t)
 if t<0 or t>=.2 then return 1 end
 return 1+(Feel.Results.punch-1)*math.sin(math.pi*t/.2)
end
-- The buttons' rise at 1.9 (8 px up into place, .16 s).
function Feel.buttonsAt(t)
 local R=Feel.Results
 return R.rise*(1-quadOut((t-R.buttonsAt)/R.riseFor))
end
-- The star burst at 1.5: piece `j` of `n`, `t` seconds on: x, y (px for a `reach`), alpha.
function Feel.burstAt(j,n,t,reach)
 local R=Feel.Results
 if t<0 or t>=R.burstLife then return 0,0,0 end
 local u=t/R.burstLife
 local a=(j-1)*2*math.pi/n
 local r=reach*cubicOut(u)
 return math.cos(a)*r,math.sin(a)*r,1-u
end
-- What each kind shows (rays alpha share, confetti, burst count). Reduced Motion: none of it.
function Feel.resultLook(kind,reduced)
 local R=Feel.Results
 if reduced then return{rays=0,confetti=false,burst=0,bounce=false,slam=false}end
 if kind=="win"then return{rays=1,confetti=true,burst=R.burst,bounce=true,slam=true}end
 if kind=="close"then return{rays=.5,confetti=false,burst=R.burstClose,bounce=false,slam=true}end
 return{rays=0,confetti=false,burst=0,bounce=false,slam=true}
end

return Feel
