-- The petting screen's rules (ONBOARDING-V3-BRIEF section 4, switch `pet2`: Alive "pet2", FeatureFlags.AlivePet2, the
-- beta place and Studio, ConfigService `alive_pet2`, owner chat /alive pet2 on|off|clear). Pure and shared: the Happy
-- heart's fill, drain, stages and burst, the purr pitch, the brush gain, the lean toward the hand, the mitten's offset,
-- size, tilt and squash, the screen sizes, and (P2) the spots, their reactions and the favourite spot picked from the
-- pet's id. Presentation only: callbacks.pet() and the server still decide the Star; nothing here is saved or sent.
-- Client: PetCuddleUI (the plates, the mitten, the hearts and sounds). Spec: scripts/PetCuddle.spec.lua (offline:
-- scripts/run_dash_server_specs.py).
local C={}
C.Feature="pet2"

-- The Happy heart. It fills in `seconds` of rubbing (twice as fast on the favourite spot), drains `drain` a second
-- while nobody rubs, and at full plays the happy burst and drops to `burstTo`. No fail state, no timer.
C.Fill=table.freeze({seconds=6,favourite=2,drain=.05,burstTo=.2})
-- The first visit (the guide's "Pet me!" open when the screen opened; ONBOARDING-FUN-PASS section 1): the heart fills
-- twice as fast (3 s), and the happy burst closes the screen by itself `close` s later (the pet's wave and the camera's
-- ease out follow, then the Bear runs out of it on the lead). Every later visit is as above.
C.First=table.freeze({seconds=3,close=.8})
-- Stage thresholds: 1 small hearts, 2 bigger hearts + blush + purr up, 3 the burst.
C.Stages=table.freeze({.33,.66,1})
-- Hearts rise from the hand while rubbing: from stage 1 one small heart every .5 s, from stage 2 a bigger one every .4 s.
C.Hearts=table.freeze({small=table.freeze({every=.5,size=22}),big=table.freeze({every=.4,size=32}),burst=8,sparkles=10,
 rise=table.freeze({70,100}),life=.9,colour="#FF6FA8",sparkle="#FFE58A"})
-- The purr loop's pitch follows the heart: .9 empty, 1.15 from 66% up.
C.Purr=table.freeze({low=.9,high=1.15})
-- The fur brush loop's gain follows the hand's speed (px a second): 0 still, .25 at `full`.
C.Brush=table.freeze({gain=.25,full=900})
-- The body leans up to 12 degrees toward the hand on contact, eased in .2 s; `forward` is how much of the lean goes
-- toward the camera (the hand is always in front of the pet).
C.Lean=table.freeze({max=math.rad(12),ease=.2,forward=.35})
-- The eyes and head follow the hovering hand: head up to 20 / 12 degrees (yaw / pitch), eyes up to .035 studs a side.
C.Look=table.freeze({yaw=math.rad(20),pitch=math.rad(12),eye=.035,ease=.12})
-- The mitten: 48 px on a computer (it is the cursor), 56 px on touch drawn 28 px above the finger, tilting up to 12
-- degrees with the rub (full tilt at `tiltSpeed` px a second across), squashing to .92 on contact. A gamepad's left
-- stick moves it at `stick` px a second; X rubs.
C.Hand=table.freeze({pc=48,phone=56,lift=28,tilt=12,tiltSpeed=600,squash=.92,stick=520,ease=.08,outline=2.5,
 ink="#1B2A4A",fill="#FFFFFF"})
-- A rub is contact with the hand moving at least this fast (px a second); a held contact (E, X) always rubs.
C.RubSpeed=40
-- The favourite spot's sparkles show after 4 s of rubbing elsewhere.
C.FavouriteHint=4
-- The exit: the pet waves and the camera eases out over .3 s. The camera sits 15% closer than the old shot.
C.Exit=table.freeze({ease=.3})
C.CameraCloser=.15

-- Pure: a fresh visit (the heart starts empty every time the screen opens). first: the guide's first pet (C.First).
function C.new(first)
 return{fill=0,stage=0,bursts=0,rubbed=0,elsewhere=0,lovedShown=false,first=first==true,
  seconds=if first==true then C.First.seconds else C.Fill.seconds}
end
-- Pure: does a first visit close itself now? burstAt: when its first burst played (nil: none yet).
function C.closeDue(state,burstAt,now)
 return type(state)=="table"and state.first==true and type(burstAt)=="number"and type(now)=="number"and now-burstAt>=C.First.close
end
-- Pure: the stage for a fill: 0 under 33%, 1 from 33%, 2 from 66%, 3 at full.
function C.stageOf(fill)
 fill=tonumber(fill)or 0
 if fill>=C.Stages[3]then return 3 end
 if fill>=C.Stages[2]then return 2 end
 if fill>=C.Stages[1]then return 1 end
 return 0
end
-- Pure: one step of the heart. rubbing: a rub this frame; favourite: on the favourite spot. Returns the events:
-- {stage = the new stage when it went up, burst = true when it filled}. Mutates `state`.
function C.step(state,dt,rubbing,favourite)
 dt=math.clamp(tonumber(dt)or 0,0,.25)
 local events={}
 local before=state.stage or C.stageOf(state.fill)
 if rubbing then
  state.rubbed+=dt
  if favourite then state.elsewhere=0 else state.elsewhere+=dt end
  state.fill=math.min(1,state.fill+dt/(state.seconds or C.Fill.seconds)*(if favourite then C.Fill.favourite else 1))
 else
  state.fill=math.max(0,state.fill-C.Fill.drain*dt)
 end
 local now=C.stageOf(state.fill)
 if now==3 then
  events.burst=true;state.bursts+=1
  state.fill=C.Fill.burstTo;now=C.stageOf(state.fill)
 elseif now>before then events.stage=now end
 state.stage=now
 return events
end
-- Pure: how often hearts rise at a stage (seconds between, nil = none) and their size in px.
function C.heartEvery(stage)
 if stage>=2 then return C.Hearts.big.every,C.Hearts.big.size end
 if stage>=1 then return C.Hearts.small.every,C.Hearts.small.size end
 return nil,nil
end
-- Pure: the purr pitch for a fill.
function C.purrPitch(fill)
 local p=C.Purr
 return p.low+(p.high-p.low)*math.clamp((tonumber(fill)or 0)/C.Stages[2],0,1)
end
-- Pure: the fur brush gain for the hand's speed (px a second).
function C.brushGain(speed)
 return C.Brush.gain*math.clamp((tonumber(speed)or 0)/C.Brush.full,0,1)
end
-- Pure: is this frame a rub?
function C.rubbing(contact,speed,held)
 return contact==true and(held==true or(tonumber(speed)or 0)>=C.RubSpeed)
end
-- Pure: an eased approach: `seconds` is about 95% of the way (three time constants).
function C.ease(current,target,dt,seconds)
 local k=1-math.exp(-math.max(0,dt)*3/math.max(seconds,1e-3))
 return current+(target-current)*k
end
-- Pure: the lean toward the hand. side: where the hand is across the pet (-1 its left, 1 its right, in the pet's own X);
-- weight: the eased contact (0..1). Returns pitch and roll (radians, CFrame.Angles order) that tip the body's top toward
-- the hand and a little toward the camera; the whole tilt is weight * 12 degrees at most.
function C.lean(side,weight)
 side=math.clamp(tonumber(side)or 0,-1,1)
 weight=math.clamp(tonumber(weight)or 0,0,1)
 local dx,dz=side,C.Lean.forward
 local length=math.sqrt(dx*dx+dz*dz)
 local angle=C.Lean.max*weight
 -- The top of the body moves along (dx, 0, dz): the axis is up x d = (dz, 0, -dx).
 return dz/length*angle,-dx/length*angle
end
-- Pure: the head turn and the eye shift toward a point in the pet's own frame (+Z forward, +Y up), from its head.
-- Returns head yaw, head pitch (radians) and eye x, eye y (studs at scale 1), all times `weight`.
function C.look(rel,weight)
 weight=math.clamp(tonumber(weight)or 0,0,1)
 if typeof(rel)~="Vector3"then return 0,0,0,0 end
 local flat=math.sqrt(rel.X*rel.X+rel.Z*rel.Z)
 if flat<1e-3 and math.abs(rel.Y)<1e-3 then return 0,0,0,0 end
 local yaw=math.atan2(rel.X,math.max(rel.Z,.05))
 local up=math.atan2(rel.Y,math.max(flat,.05))
 local L=C.Look
 local ny,np=math.clamp(yaw/L.yaw,-1,1),math.clamp(up/L.pitch,-1,1)
 -- Positive pitch looks down (CFrame.Angles about X), so looking up is negative.
 return ny*L.yaw*weight,-np*L.pitch*weight,ny*L.eye*weight,np*L.eye*weight
end
-- Pure: the mitten's size (px) and its offset from the pointer: a finger never hides it.
function C.hand(kind)
 if kind=="touch"then return C.Hand.phone,Vector2.new(0,-C.Hand.lift)end
 return C.Hand.pc,Vector2.zero
end
-- Pure: the mitten's tilt (degrees) for its speed across (px a second), and its scale for contact.
function C.handTilt(vx)
 return math.clamp((tonumber(vx)or 0)/C.Hand.tiltSpeed,-1,1)*C.Hand.tilt
end
function C.handScale(contact)return if contact then C.Hand.squash else 1 end
-- Pure: the screen sizes. Phone (the short side under 500 px, e.g. 812 x 354): heart 56, pill text 14; computer: heart
-- 72, pill text 16. Back is always 48.
function C.layout(width,height)
 local phone=math.min(tonumber(width)or 0,tonumber(height)or 0)<500
 return{phone=phone,heart=if phone then 56 else 72,text=if phone then 14 else 16,back=48,pill=if phone then 36 else 42,edge=12}
end

-- ── P2: spots and the favourite ─────────────────────────────────────────────────────────────────────────────────
C.Spots=table.freeze({"head","cheeks","chin","belly","back","ears","tail"})
-- Pure: the favourite spot from the pet's id (no save): a small string hash over the spots.
function C.favourite(petId)
 local text=tostring(petId or "")
 local h=7
 for i=1,#text do h=(h*31+string.byte(text,i))%16777216 end
 return C.Spots[h%#C.Spots+1]
end
-- Pure: the spot under the hand. u, v: the hand in the pet's on-screen box (0..1, v down). A front-facing pet: the
-- head is the top half, the body the bottom; back and tail are the body's far sides and bottom.
function C.spotAt(u,v)
 u,v=tonumber(u)or .5,tonumber(v)or .5
 local across=math.abs(u-.5)
 if v<.16 then return "ears"end
 if v<.32 then return if across>.3 then "ears"else "head"end
 if v<.44 then return if across>.12 then "cheeks"else "head"end
 if v<.56 then return if across>.14 then "cheeks"else "chin"end
 if v>.86 then return "tail"end
 if across>.26 then return "back"end
 return "belly"
end
-- Pure: where to draw a spot's sparkles in the box (u, v), the left one for paired spots.
C.SpotCentre=table.freeze({head=Vector2.new(.5,.22),cheeks=Vector2.new(.3,.44),chin=Vector2.new(.5,.5),belly=Vector2.new(.5,.7),
 back=Vector2.new(.18,.68),ears=Vector2.new(.22,.08),tail=Vector2.new(.7,.92)})
-- Pure: the pet's answer to a spot, `age` seconds into rubbing it. side: the hand across the pet (-1..1).
-- {headPitch, headRoll, eye (multiplier), stretch, ear, sway, hop}. Ticklish never means upset. Reduced Motion keeps
-- the eyes and the lean, drops the nod, wiggle, stretch and twitch.
function C.spotPose(spot,age,side,reduced)
 age=math.max(0,tonumber(age)or 0);side=math.clamp(tonumber(side)or 0,-1,1)
 local p={headPitch=0,headRoll=0,eye=1,stretch=0,ear=0,sway=0,hop=0}
 local still=reduced==true
 if spot=="head"then
  p.eye=.15;if not still then p.headPitch=math.sin(age*2.2)*.06 end
 elseif spot=="cheeks"then
  p.eye=.5;p.headRoll=side*(if still then .08 else .18);if not still then p.stretch=-.05 end
 elseif spot=="chin"then
  p.eye=.45;p.headPitch=-.18
 elseif spot=="belly"then
  p.eye=.35;if not still then p.sway=math.sin(age*18)*.08*math.min(1,age/.15)end
 elseif spot=="back"then
  p.eye=.4;p.headPitch=-.06;if not still then p.stretch=.08*math.sin(math.min(age/1.2,1)*math.pi*.5)end
 elseif spot=="ears"or spot=="tail"then
  -- A twitch and a blink, then a pleased squint.
  local blink=age>.1 and age<.22
  p.eye=if blink then 0 else .6
  if not still and age<.3 then p.ear=math.sin(age/.3*math.pi*3)*.25 end
 end
 return p
end
-- Pure: the burst's wiggle-jump, `age` seconds in (.6 s): {hop (studs at scale 1), sway (radians)}; still under Reduced Motion.
C.BurstSeconds=.6
function C.burstPose(age,reduced)
 age=tonumber(age)or 0
 if reduced==true or age<0 or age>=C.BurstSeconds then return 0,0 end
 local t=age/C.BurstSeconds
 return math.sin(t*math.pi)*.35,math.sin(age*25)*.1*(1-t)
end
return table.freeze(C)
