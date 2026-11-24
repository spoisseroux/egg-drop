-- Full-screen reveal stage (UI-SPEC-REDESIGN-CELEBRATIONS-2026-11-12 section 1).
-- A dark stage with one painted spotlight, the pet in a ViewportFrame, light
-- streaks, sparkles, a slanted headline and an off-edge name plate.
--   RevealStage.show(parent,{pet,tag,accent,buttons,...}) -> stage
-- Any pet, any tag: the hatch hands off here after the egg splits, and the
-- journal or a shop preview can show a pet the same way.
--
-- options:
--   pet          PetCatalog entry (default Bear)
--   tag          "new" | "rare" | "owned" | "saved" (headline choice)
--   accent       Color3 (default: RevealStage.accentFor(pet.id, appearance))
--   appearance   saved appearance token for the 3D pet
--   description  one line under the plate (default pet.description)
--   next         desktop "NEXT · ..." line, or nil
--   buttons      {{id,text,glyph,primary}} left to right
--   onButton(id) a settled button press; onSkip() a press that only settled
--   audio, reduced() , owns(), instant (start settled), fresh (reduced first view)
--   voice        false when the caller already played the pet voice
--   scene        (QA v685 H1) the hatch's native egg scene (HatchDisplayScene) with
--                externalClock: the egg wobbles, cracks and opens on this stage as the
--                lead-in, then the stage's own entrance starts at Stage.LeadIn. The
--                cinematic drives it through stage:updateExternal(age, sample).
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Input=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Kit=require(script.Parent.DeckKit)
local C=require(script.Parent.CelebrationKit)
local Pets=require(ReplicatedStorage.Shared.PetCatalog)
local BaseColors=require(ReplicatedStorage.Shared.PetBaseColors)
local ItemStage=require(script.Parent.HatchItemStage)
local Rarity=require(script.Parent.HatchRarityCue)
local Copy=require(ReplicatedStorage.Shared.UICopy)
local Stage={};Stage.__index=Stage

-- ── Pure rules (specs cover these) ───────────────────────────────────────────
Stage.Gold=Color3.fromHex("#FFC14D");Stage.Ink=Color3.fromHex("#0E0F12")
Stage.Duration=1.14;Stage.InputAt=1.0;Stage.ReducedFade=.15
Stage.Spin={degPerPixel=.5,phoneDegPerPixel=.6,cap=1080,tau=.55,stop=4,settleDelay=2.5,home=-25,idle=12,springHz=1.6,damping=.8,
 stick=360,flick=45,window=.08,whooshAt=360,whooshGap=.25}
Stage.Headlines={new={"A NEW","LITTLE WONDER!"},rare={"RARE","DISCOVERY!"},owned={"ALREADY","OWNED!"},saved={"SAVED FOR","YOUR GARDEN!"}}
Stage.BurstCount,Stage.TwinkleCount,Stage.DustCount=18,11,12
-- QA R3 (2026-11-15): the name plate's slanted end is one triangle that shares the plate's
-- top and bottom edges, so the plate reads as one continuous shape. It was a rotated
-- rectangle whose corners stuck out above and below the plate, like a loose block.
-- Pure: a `h` px tall end slanted `Stage.PlateSlant` degrees, overlapping the plate by
-- `overlap` px. Returns the frame width, the gradient rotation (degrees), and the gradient
-- positions where the cut starts and ends (a one pixel ramp, so the edge is anti-aliased).
Stage.PlateSlant=16
function Stage.slantEnd(h,overlap)
 h=math.max(1,h);overlap=overlap or 2
 local w=math.max(1,math.floor(h*math.tan(math.rad(Stage.PlateSlant))+.5))
 local hyp=math.sqrt(w*w+h*h)
 -- The gradient runs square to the cut. Its length is the frame's extent along that line.
 local length=((w+overlap)*h+h*w)/hyp
 local cut=.5-(overlap*h/(2*hyp))/length
 local half=.5/length
 return w,math.deg(math.atan2(w,h)),math.clamp(cut-half,.001,.997),math.clamp(cut+half,.002,.998)
end
-- Lead-in (QA v685 H1): seconds of the native egg opening (wobble .12-.94, crack .65,
-- shell opens .95-1.18) before the entrance timeline starts. HatchDisplayPose.BearReady
-- is LeadIn + InputAt, so the receipt unlocks as the buttons open.
Stage.LeadIn=1.05;Stage.LeadOut=1.30
-- QA R5 (2026-11-15): the pet is lit flat and bright from the front with a soft glow behind
-- it, like in the garden (a hard top light under a dim ambient read as creepy), and it waves:
-- one arm up, three little wags, every few seconds while the screen is up.
Stage.Light={ambient=Color3.fromRGB(216,210,204),color=Color3.fromRGB(92,86,78),direction=Vector3.new(-.2,-.45,-1),glow=Color3.fromHex("#FFF3DA"),glowDiscs=14,glowAlpha=.34}
-- (The hand turns about its own anchor: past about 1.8 it tucks behind the body, so the wave
-- stays near 1.5 with the paw pad showing, the same right-hand fold the garden hello uses.)
Stage.Wave={period=3.4,raise=.18,wag=.72,lower=.22,rest=.24,up=1.5,swing=.2,wags=3,restL=.16}
-- Pure: the pet's reveal pose `t` seconds after its greeting beat (negative: not greeted
-- yet) at stage clock `clock`. Reduced Motion holds the resting pose.
function Stage.wavePose(t,clock,reduced)
 local W=Stage.Wave
 local pose={heroScale=1,stretch=0,eye=1,blink=1,headYaw=0,headRoll=0,handL=W.restL,handR=W.rest,ear=0,tail=0,waving=false}
 if reduced or t==nil or t<0 then return pose end
 local u=t%W.period;local lift,wag=0,0
 if u<W.raise then local x=u/W.raise;lift=x*x*(3-2*x)
 elseif u<W.raise+W.wag then lift=1;wag=math.sin((u-W.raise)/W.wag*math.pi*2*W.wags)
 elseif u<W.raise+W.wag+W.lower then local x=1-(u-W.raise-W.wag)/W.lower;lift=x*x*(3-2*x)end
 pose.waving=lift>0
 pose.handR=W.rest+(W.up-W.rest)*lift+W.swing*wag*lift
 pose.headRoll=-math.rad(6)*lift-math.rad(2)*wag*lift;pose.ear=math.rad(8)*lift;pose.eye=1-.06*lift
 -- A breath and a blink, so the pet is never a statue between waves.
 clock=clock or t
 pose.stretch=.012*math.sin(clock*2.1)
 local b=clock%3.7
 if b<.15 then pose.blink=if b<.055 then 1-.94*(b/.055)elseif b<.09 then .06 else .06+.94*((b-.09)/.06)end
 pose.tail=.10*math.sin(clock*9)*(.3+.7*lift)
 return pose
end
-- QA R4 (2026-11-15): with an egg lead-in the stage opens by CelebrationKit's shared rule
-- (the screen dims while the spotlight, the pool and the egg fade in), and stage:dismiss()
-- leaves by it (the content sinks into the dark, then the dark lifts off the garden).
-- Pure: the lead-in lanes at hatch age `t`. `glow` builds behind the egg, `flash` pops as
-- the shell opens, `egg` is the egg scene's opacity (it leaves as the silhouette rises).
function Stage.leadSample(t)
 t=math.max(0,t or 0)
 local glow=math.clamp(t/.95,0,1)
 return {t=t,glow=glow*glow,flash=if t<.95 then 0 else .45*(1-math.clamp((t-.95)/.30,0,1)),
  egg=1-math.clamp((t-1.12)/(Stage.LeadOut-1.12),0,1),done=t>=Stage.LeadIn}
end

local function ramp(t,start,duration)return math.clamp((t-start)/duration,0,1)end
local function backOut(x)local c1=1.70158;local c3=c1+1;return 1+c3*(x-1)^3+c1*(x-1)^2 end
local function quintOut(x)return 1-(1-x)^5 end
local function quadOut(x)return 1-(1-x)^2 end
Stage.ease={backOut=backOut,quintOut=quintOut,quadOut=quadOut}

-- Timeline 1.5, milliseconds after the egg splits, as progress lanes. `rare`: the Rare pet's
-- entrance (Stage.rareLanes); omitted, every lane is the Bear's.
function Stage.sample(t,rare)
 t=math.max(0,t or 0)
 local s={t=t}
 s.dark=ramp(t,0,.12)                           -- 0: stage fades to black
 s.spot=backOut(ramp(t,.12,.18))                -- 120: cone opens 25% -> 100%
 s.rise=backOut(ramp(t,.12,.30))                -- 120: silhouette scale .55 -> 1
 s.shown=ramp(t,.12,.08)                        -- silhouette appears
 s.spinIn=540*(1-quintOut(ramp(t,.12,.30)))     -- first damped spin, degrees left
 s.streak=quadOut(ramp(t,.30,.22))              -- 300: streaks sweep in
 s.streakGlow=if t<.30 then 1 else 1+2*(1-ramp(t,.52,.30)) -- 3x bright, settled by 820
 s.colour=ramp(t,.42,.12)                       -- 420: silhouette -> colour
 s.flash=if t<.42 then 0 else .6*(1-quadOut(ramp(t,.42,.28)))
 s.burst=quintOut(ramp(t,.42,.48));s.burstAlive=t>=.42 and t<.90
 s.headline=backOut(ramp(t,.48,.20))            -- 480: headline slams in
 s.greet=t>=.56                                 -- 560: greeting pose
 s.plate=quintOut(ramp(t,.60,.24))              -- 600: plate slides in
 s.letters=math.max(0,math.floor((t-.60)/.04)+1)-- letters pop 40 ms apart
 s.desc=quintOut(ramp(t,.84,.16))               -- 840: description wipe
 s.buttons=quadOut(ramp(t,Stage.InputAt,.14))   -- 1000: buttons + hint, input opens
 s.input=t>=Stage.InputAt
 s.settled=t>=Stage.Duration
 s.plateAt=.60
 if t<.12 then s.letters=0 end
 if rare then Stage.rareLanes(s,t)end
 return s
end
-- Reduced Motion: one 150 ms cross-fade to the settled frame.
function Stage.reducedSample(t,rare)
 local s=Stage.sample(Stage.Duration,rare)
 s.reduced=true;s.fade=ramp(t or 0,0,Stage.ReducedFade);s.flash=0;s.burstAlive=false;s.spinIn=0;s.streakGlow=1
 s.settled=(t or 0)>=Stage.ReducedFade
 if rare then
  -- The calm jackpot (Fable brief 3): no leap, hops or shake; "RARE!" fades in at full size
  -- and fades out again, over a static rainbow edge (Stage.jackpot).
  local R=Stage.Rare
  s.arc,s.squash,s.stampShake,s.stampScale=0,0,0,1
  s.stamp=ramp(t or 0,0,Stage.ReducedFade)*(1-ramp(t or 0,R.reducedStampOut,.15))
 end
 return s
end
Stage.Cues={{0,"reveal_hush"},{.12,"spot_on"},{.30,"streak_whoosh"},{.42,"reveal_shimmer"},{.48,"tag_slam"},{.60,"name_slam"},{.84,"desc_tick"}}

-- Round 3 (Spencer 2026-11-20: "the bunny should have an awesome hatch animation like the bear!
-- make it epic"; Fable brief 3, cut by the architect review). A Rare pet (the Bunny: earned pets
-- are Rare in HatchRarityCue) gets the jackpot on the pet's own clock. No wind-up or freeze:
-- LeadIn stays 1.05, the receipt still opens at LeadIn + InputAt (2.05) and HatchRarityCue's tier
-- timing is untouched, so no egg hatch changes. At the shell's opening (the tier burst, 0.98 on
-- the hatch clock) the shockwave, the rim and screen-edge rainbow, the well's punch and a shake;
-- then the leap (720 deg, an arc), the "RARE!" stamp, a three-hop landing with rising boops, two
-- cannons, and the "RARE / DISCOVERY!" headline once the stamp has gone. Times are entrance
-- seconds (hatch - LeadIn) except `burst`. Common and Uncommon pets (the Bear) keep every beat above.
Stage.Rare=table.freeze({burst=Rarity.BurstAt,leap=.12,leapFor=.34,spin=720,arc=.38,back=2.4,
 hops=table.freeze({table.freeze({.50,.62,.16}),table.freeze({.66,.76,.07})}),    -- {from, land, height x petH}
 lands=table.freeze({table.freeze({.46,.12}),table.freeze({.62,.06}),table.freeze({.76,.03})}), -- {at, squash}
 stamp=.25,stampFall=.12,stampShake=.18,stampLeave=.70,stampOut=.07,reducedStampOut=.9,
 headline=.77,greet=.80,plate=.82,desc=.96,cannon=.20,cannonGap=.12,burstCount=30,shafts=.25,calmEdge=.6,earFlick=22,
 cannonColors=table.freeze({"#FFC14D","#FFFFFF","#FF79D9","#B9EE5A"}),edgeRadius=table.freeze({phone=34,regular=24}),edgeBand=14})
-- The Rare pet's entrance sound: the three boops rise with the hops, then the slams. reveal_hush,
-- spot_on, streak_whoosh, reveal_shimmer and the popper's new_best are dropped (they fight the
-- rarity_rare sting that HatchRarityCue plays as the shell opens). {at, cue, pitch, gain}
Stage.RareCues=table.freeze({{.46,"bear_boop",1.25,.40},{.62,"bear_boop",1.40,.30},{.76,"bear_boop",1.55,.22},
 {.77,"tag_slam",1,.55},{.82,"name_slam",1,.55},{.96,"desc_tick",1,.45}})
local function smooth(a,b,t)local u=math.clamp((t-a)/(b-a),0,1);return u*u*(3-2*u)end
-- Pure: the Rare pet's entrance lanes over `s` (Stage.sample's), at entrance time `t`. arc is the
-- pet's height off the floor (x petH), squash the landing squash (x wider, y shorter).
function Stage.rareLanes(s,t)
 local R,E=Stage.Rare,ItemStage.ease
 local u=ramp(t,R.leap,R.leapFor)
 s.rare=true
 s.rise=E.back(u,R.back);s.spinIn=R.spin*(1-quintOut(u))
 local arc=if t>=R.leap and t<R.leap+R.leapFor then R.arc*math.sin(math.pi*u)else 0
 for _,hop in ipairs(R.hops)do
  if t>=hop[1]and t<hop[2]then arc+=hop[3]*math.sin(math.pi*(t-hop[1])/(hop[2]-hop[1]))end
 end
 s.arc=arc
 local squash=0
 for _,land in ipairs(R.lands)do if t>=land[1]then squash+=land[2]*E.spring(t-land[1],.26,1,6)end end
 s.squash=squash
 s.stamp,s.stampScale,s.stampShake=0,1,0
 if t>=R.stamp then
  local leave=ramp(t,R.stampLeave,R.stampOut)
  s.stamp=1-leave;s.stampScale=(2.6-1.6*E.expoIn(ramp(t,R.stamp,R.stampFall)))*(1-.1*leave)
  local landed=R.stamp+R.stampFall
  if t>=landed and t<landed+R.stampShake then s.stampShake=4*(1-ramp(t,landed,R.stampShake))end
 end
 s.headline=backOut(ramp(t,R.headline,.20))
 s.greet=t>=R.greet
 s.plate=quintOut(ramp(t,R.plate,.24));s.plateAt=R.plate
 s.letters=if t<R.plate then 0 else math.floor((t-R.plate)/.04)+1
 s.desc=quintOut(ramp(t,R.desc,.16))
 return s
end
-- Pure: the jackpot lanes on the hatch clock `h` (they start inside the egg lead-in, as the shell
-- opens). Reduced Motion: the static calm frame (rainbow 0.6, shafts 0.15, nothing moves).
function Stage.jackpot(h,reduced)
 local R,E=Stage.Rare,ItemStage.ease;local B=R.burst
 if reduced then return{shafts=R.shafts*.6,rainbow=R.calmEdge,shock=nil,punch=0,shake=0,bloom=0,bloomR=0}end
 h=math.max(0,h or 0)
 local j={shafts=R.shafts*smooth(.12,B,h),rainbow=ramp(h,B,.25),shock=nil,punch=0,shake=0,bloom=0,bloomR=0}
 if h>=B then
  j.punch=E.back(ramp(h,B,.22),2.4)*(1-smooth(B+.22,B+.62,h))
  if h<B+.2 then j.shake=3*(1-ramp(h,B,.2))end
  if h<B+.5 then local v=ramp(h,B,.5);j.shock={radius=40+560*E.expoOut(v),width=10-8*v,alpha=1-v*v}end
  j.bloomR=E.expoOut(ramp(h,B,.16));j.bloom=Rarity.Stage.Rare.bloom*ramp(h,B,.05)*(1-ramp(h,B,.40))^2
 end
 return j
end
-- Pure: the ear flick on each landing (radians), 0 before the first.
function Stage.earFlick(t)
 local R=Stage.Rare;local flick=0
 for index,land in ipairs(R.lands)do
  if t>=land[1]then flick+=math.rad(R.earFlick)*ItemStage.ease.spring(t-land[1],.26,1,6)*(if index==1 then 1 else .5)end
 end
 return flick
end

-- Confetti popper (QA v2 R1.1): two poppers in the bottom corners fire with the colour
-- burst (t = 0.42), the pieces arc up and inward, tumble and fall out of the frame. The
-- colours are CelebrationKit.Confetti. A first view only: never on a reopen, a skip past
-- the burst still pops, Reduced Motion has none. The sound is a placeholder cue.
Stage.PopAt=.42;Stage.ConfettiCount=28;Stage.ConfettiLife=1.9;Stage.PopCue="new_best"
-- Pure: piece `i` (1..ConfettiCount) at `t` seconds after the pop on a W x H stage.
-- Returns x, y (px, piece centre), rotation (deg), width share (0..1, the tumble) and
-- transparency; nil when the piece is not on screen. Deterministic (no random state).
function Stage.confetti(i,t,W,H)
 if t<0 or t>Stage.ConfettiLife then return nil end
 local h1,h2,h3=Stage.hash(i,11),Stage.hash(i,12),Stage.hash(i,13)
 local side=if i%2==1 then 1 else -1 -- odd pieces fire from the left corner, rightward
 local angle=math.rad(58+20*h1)
 local speed=H*(1.25+.35*h2)
 local gravity=H*1.9
 local x0=if side>0 then W*.04 else W*.96
 local drag=1.1
 local travel=(1-math.exp(-drag*t))/drag
 local x=x0+side*math.cos(angle)*speed*travel+math.sin(t*(5+3*h3)+i)*H*.012
 local y=H*1.02-math.sin(angle)*speed*t+.5*gravity*t*t
 local spin=(if h3<.5 then -1 else 1)*(360+360*h2)
 local fade=if t>Stage.ConfettiLife-.4 then (t-(Stage.ConfettiLife-.4))/.4 else 0
 if y>H+20 and t>.3 then return nil end
 return x,y,spin*t,math.abs(math.cos(t*(6+4*h1)+i)),fade
end

-- Accent (1.4): the secondary colour lifted to read on black, Stars gold for an
-- undyed (near-grey) secondary.
function Stage.accent(color)
 if typeof(color)~="Color3"then return Stage.Gold end
 local h,s,v=color:ToHSV()
 if s<.12 then return Stage.Gold end
 return Color3.fromHSV(h,math.max(s,.55),math.max(v,.9))
end
function Stage.accentFor(petId,appearance)
 local ok,palette=pcall(function()return require(ReplicatedStorage.Shared.PetPalette).resolve(petId,appearance)end)
 local secondary=if ok and palette and palette.secondary then palette.secondary else BaseColors.secondary
 return Stage.accent(secondary)
end
local function luminance(c)
 local function lin(x)return if x<=.03928 then x/12.92 else((x+.055)/1.055)^2.4 end
 return .2126*lin(c.R)+.7152*lin(c.G)+.0722*lin(c.B)
end
function Stage.contrast(a,b)
 local la,lb=luminance(a),luminance(b)
 return(math.max(la,lb)+.05)/(math.min(la,lb)+.05)
end
function Stage.ink(accent)return if Stage.contrast(Stage.Ink,accent)>=4.5 then Stage.Ink else Color3.new(1,1,1)end

-- Headline (1.4 table) and the tag strip.
function Stage.tagKind(result,kind)
 if kind and kind~="companion"then return "saved"end
 if type(result)~="table"then return "new"end
 if result.duplicate then return "owned"elseif result.rare then return "rare"end
 return "new"
end
function Stage.headline(kind)return Stage.Headlines[kind]or Stage.Headlines.new end
function Stage.tagStrip(pet,kind)
 local rare=kind=="rare"or(pet and pet.trial~=nil)
 return string.format("No. %02d · %s",(pet and pet.index)or 0,if rare then "RARE FRIEND"else "NEW FRIEND")
end

-- Spin (1.6). Exponential damping with a 0.55 s time constant; stops under 4°/s.
function Stage.decay(omega,dt)
 local w=omega*math.exp(-math.max(0,dt)/Stage.Spin.tau)
 if math.abs(w)<Stage.Spin.stop then return 0 end
 return w
end
-- Release speed: yaw change over the last 80 ms of samples {t,yaw}, capped.
function Stage.releaseSpeed(samples,now)
 local last=samples[#samples];if not last then return 0 end
 now=now or last.t
 local first=last
 for index=#samples,1,-1 do
  local sample=samples[index]
  if now-sample.t>Stage.Spin.window then break end
  first=sample
 end
 local dt=last.t-first.t
 if dt<=1e-4 then return 0 end
 return math.clamp((last.yaw-first.yaw)/dt,-Stage.Spin.cap,Stage.Spin.cap)
end
-- Total angle a release coasts through: omega * tau (the integral of the decay).
function Stage.coast(omega)return omega*Stage.Spin.tau end
-- Flick (L1/R1, Q/E): the speed that coasts exactly 45°.
function Stage.flickSpeed(direction)return direction*Stage.Spin.flick/Stage.Spin.tau end
function Stage.wrap(angle)return((angle+180)%360)-180 end
-- One spring step toward the nearest copy of `home` (1.6 Hz, damping 0.8).
function Stage.springStep(yaw,velocity,dt,home)
 home=home or Stage.Spin.home
 local target=yaw-Stage.wrap(yaw-home)
 local w0=2*math.pi*Stage.Spin.springHz
 local acceleration=-w0*w0*(yaw-target)-2*Stage.Spin.damping*w0*velocity
 velocity+=acceleration*dt
 return yaw+velocity*dt,velocity,target
end

-- Layout (1.2). Desktop numbers are authored at 1920x1080 and phone numbers at
-- 812x354, then scaled; left items keep their left offset, right items their
-- right offset, so wider screens open up the middle.
-- Beta 14 Q3: on a phone the button row keeps RowClear px clear of the stage card (shot 2: Back sat 8 px inside it at
-- 844 x 390). Back (the short label) gives way first, down to PlayMin; then the card narrows (never under 1.3 pet boxes).
Stage.RowClear=12
Stage.PlayMin=110
-- Held to the beta place and Studio (DeckLook.on); live keeps today's layout exactly.
function Stage.rowClearOn()
 local ok,on=pcall(function()return require(ReplicatedStorage.Shared.DeckLook).on()end)
 return ok and on==true
end
-- clear (specs): true / false forces the Q3 row rule on or off; nil asks Stage.rowClearOn().
function Stage.geometry(W,H,clear)
 local L={W=W,H=H,phone=Kit.compactRule(W,H)or W<760}
 if clear==nil then clear=Stage.rowClearOn()end
 if L.phone then
  local s=math.min(W/812,H/354);L.s=s
  local top=60
  L.petX=math.floor(W*268/812);L.feet=H-math.floor(48*s);L.petH=188*s;L.petBox=230*s
  L.coneTop,L.coneBottom=34*s,240*s
  L.poolRX,L.poolRY,L.ring=120*s,24*s,math.max(2,4*s)
  L.headX,L.headY=math.max(24,math.floor(22*s)),math.max(top+4,math.floor(64*s))
  L.tagSize,L.lineSize=12,math.max(18,27*s);L.dropTag=W<700
  L.plateX=W-math.floor(368*s);L.plateY=math.max(top+40,math.floor(104*s));L.plateH=math.max(44,math.floor(60*s))
  L.nameSize=math.max(26,46*s);L.plateTag=12
  L.descX=W-math.floor(342*s);L.descY=L.plateY+L.plateH+math.floor(34*s);L.descSize=math.max(12,14*s);L.descW=math.floor(300*s);L.descLines=1
  L.btnH=48;L.btnY=H-L.btnH-math.floor(14*s);L.meetW=math.max(120,math.floor(176*s));L.playW=math.max(110,math.floor(150*s))
  L.margin=24;L.gap=10;L.btnText=16
  L.hintX,L.hintY,L.hintSize=L.petX,H-math.floor(16*s),12
  local wellRight=L.petX+math.floor(math.min(L.petBox*1.7,L.petX*2-32))/2
  local rowLeft=W-L.margin-L.meetW-L.gap-L.playW
  local need=math.ceil(wellRight+Stage.RowClear-rowLeft)
  if clear and need>0 then
   local give=math.min(need,math.max(0,L.playW-Stage.PlayMin))
   L.playW-=give;rowLeft+=give;need-=give
   if need>0 then L.wellW=math.max(math.floor(L.petBox*1.3),math.floor((rowLeft-Stage.RowClear-L.petX)*2))end
  end
 else
  local s=math.min(W/1920,H/1080);L.s=s
  L.petX=math.floor(W*800/1920);L.feet=H-math.floor(238*s);L.petH=590*s;L.petBox=700*s
  L.coneTop,L.coneBottom=92*s,700*s
  L.poolRX,L.poolRY,L.ring=350*s,70*s,math.max(2,4*s)
  L.headX,L.headY=math.floor(88*s),math.floor(76*s);L.tagSize,L.lineSize=math.max(12,26*s),math.max(24,80*s)
  L.plateX=W-math.floor(910*s);L.plateY=L.feet-math.floor(202*s);L.plateH=math.max(56,math.floor(168*s))
  L.nameSize=math.max(28,128*s);L.plateTag=math.max(12,22*s)
  L.descX=W-math.floor(812*s);L.descY=L.feet+math.floor(36*s);L.descSize=math.max(14,26*s);L.descW=math.floor(700*s);L.descLines=2
  L.btnH=math.max(44,math.floor(72*s));L.btnY=H-math.floor(112*s);L.meetW=math.max(160,math.floor(300*s));L.playW=math.max(130,math.floor(240*s))
  L.margin=math.floor(88*s);L.gap=math.max(10,math.floor(16*s));L.btnText=math.max(16,math.floor(22*s))
  L.hintX,L.hintY,L.hintSize=L.petX,H-math.floor(118*s),math.max(12,16*s)
  L.nextX,L.nextY,L.nextSize=math.floor(88*s),H-math.floor(76*s),math.max(12,16*s)
 end
 return L
end

-- Deterministic scatter for sparkles and dust (no random state in a sample).
local function hash(i,salt)local x=math.sin(i*12.9898+salt*78.233)*43758.5453;return x-math.floor(x)end
Stage.hash=hash

-- ── View ────────────────────────────────────────────────────────────────────
local function layerFrame(root,name,n)
 local f=Kit.frame(root,name,nil,UDim2.new(),UDim2.fromScale(1,1));f.ZIndex=root.ZIndex+n*10;return f
end
local function fill(parent,name,color,transparency)
 local f=Kit.frame(parent,name,nil,UDim2.new(),UDim2.fromOffset(1,1));f.BackgroundTransparency=transparency or 0;f.BackgroundColor3=color;return f
end

function Stage.show(parent,options)
 options=options or {}
 local pet=options.pet or Pets.byId.pip
 local self=setmetatable({options=options,parent=parent,pet=pet,age=0,yaw=Stage.Spin.home,omega=0,velocity=0,homed=true,
  lastTouch=-math.huge,connections={},focus=0,buttons={},sampleAge=0,clock=0,lastWhoosh=-math.huge,cued={}},Stage)
 self.kind=options.tag or "new"
 self.accent=options.accent or Stage.accentFor(pet.id,options.appearance)
 self.ink=Stage.ink(self.accent)
 -- The tier's well (and, Round 3, a Rare pet's jackpot) is chosen before anything is built.
 self.tier=Rarity.tier("companion",{petId=pet.id})
 self.jackpot=self.tier=="Rare"
 local root=Kit.frame(parent,"RevealStage",nil,UDim2.new(),UDim2.fromScale(1,1))
 -- v2 (V2-HATCH-REDESIGN 2.4): pets hatch on the same Pop-Out Stage as items: the deck's
 -- shell and the tier's vibrant well (Sunny Peach for the Bear). No dark stage, no spotlight
 -- and no full-screen flash (section 4).
 root.BackgroundTransparency=0;root.ClipsDescendants=true;root.Active=true
 Kit.paint(root,"BackgroundColor3","shell")
 root:SetAttribute("AccessibleLabel",(pet.name or "Pet").." revealed")
 self.root=root
 self:build()
 self.reducedStart=self:reduced()
 self.openedAt=os.clock()
 if options.scene then self:buildLead(options.scene)end
 -- A first view under Reduced Motion still gets its 150 ms cross-fade and cue;
 -- reopening or skipping lands on the settled frame without a sound.
 self.instant=options.instant==true and not(options.fresh==true and self.reducedStart)
 if self.instant then self.age=if self.reducedStart then Stage.ReducedFade else Stage.Duration end
 -- No egg lead-in on a reopen, a skip or under Reduced Motion.
 if self.lead and(self.instant or self.reducedStart)then self:endLead()end
 self:layout()
 table.insert(self.connections,root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:layout()end))
 self:bindInput()
 if not self.instant then
  if self.reducedStart then
   -- Round 3: a Rare pet's calm frame keeps only the voice (its sting is the host's).
   if not self.jackpot then self:cue("reveal_shimmer",if self.kind=="rare"then 2^(3/12)else 1,.6*.72)end
   if options.voice~=false then self:cue(pet.cue or "pet",1,.4)end
  elseif not self.lead and not self.jackpot then self:cue("reveal_hush",1,.5)end
 end
 self:paint()
 self.connection=RunService.RenderStepped:Connect(function(dt)self:step(dt)end)
 return self
end

-- Lead-in: borrow the hatch's one native scene into a seat on this stage. The seat is
-- placed so the egg's contact point sits on the floor pool, under the spotlight.
function Stage:buildLead(scene)
 local seat=Kit.frame(self.petLayer,"EggLeadIn",nil,UDim2.new(),UDim2.fromOffset(10,10))
 seat.ZIndex=self.petLayer.ZIndex+3;seat.ClipsDescendants=false
 self.lead={scene=scene,seat=seat,age=0,done=false,sample=Stage.leadSample(0)}
 self.lead.token=scene:borrow(seat)
 if scene.setBare then scene:setBare(true,true)end
 table.insert(self.connections,seat:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:placeLead()end))
end
function Stage:placeLead()
 local lead=self.lead;local L=self.L;if not lead or not L or lead.placing or self.destroyed then return end
 lead.placing=true
 -- The scene frames the whole hatch (the pet's hop and wave too), so the egg is small in
 -- it; a seat larger than the pet box brings the egg up to about 60% of the pet's height.
 local w,h=math.floor(L.petBox*2.4),math.floor(L.petBox*1.85)
 lead.seat.Size=UDim2.fromOffset(w,h)
 if lead.scene.layout then lead.scene:layout()end
 local ground=if lead.scene.groundPoint then lead.scene:groundPoint()else Vector2.new(.5,.8)
 lead.seat.Position=UDim2.fromOffset(math.floor(L.petX-ground.X*w),math.floor(L.feet-ground.Y*h))
 lead.placing=false
end
function Stage:endLead()
 local lead=self.lead;if not lead or lead.done then return end
 lead.done=true;self.staticDone=false
end
-- The hatch clock. `sample` is HatchDisplayPose's; a jump (the hatch was skipped or lost
-- its owner) lands on the settled frame.
function Stage:updateExternal(age,sample)
 local lead=self.lead;if self.destroyed or not lead then return end
 local jumped=age-lead.age>.3 or(sample and sample.reduced==true)
 lead.age=age;lead.sample=Stage.leadSample(age)
 self.root:SetAttribute("InputLocked",sample~=nil and sample.inputLocked==true)
 self.root:SetAttribute("ReceiptReady",sample~=nil and sample.receiptReady==true)
 if not lead.done then
  if jumped then self:settle(true,true)
  elseif lead.sample.done then self:endLead();if not self.jackpot then self:cue("reveal_hush",1,.5)end end
 elseif jumped and not self:isSettled()then self:settle(true,true)end
end
function Stage:reduced()
 local r=self.options.reduced
 if type(r)=="function"then return r()==true end
 if r~=nil then return r==true end
 return Kit.reduced()
end
function Stage:owned()
 if self.destroyed or self.leaving or not self.root.Parent then return false end
 local node=self.root
 while node do
  if node:IsA("GuiObject")and not node.Visible then return false end
  if node:IsA("ScreenGui")and not node.Enabled then return false end
  node=node.Parent
 end
 return not self.options.owns or self.options.owns()==true
end
function Stage:cue(name,pitch,volume)
 local audio=self.options.audio
 if not audio or type(audio.play)~="function"or audio.deviceActive==false then return end
 audio:play(name,pitch or 1,volume or .5,self)
end

function Stage:build()
 local root=self.root;local accent=self.accent
 -- 1 glow, 2 streaks, 3 cone, 4 pool + shadow, 5 pet, 6 sparkles, 7 flash,
 -- 8 headline, 9 plate, 10 description, 11 spin pad, 12 buttons and hints.
 local glowLayer=layerFrame(root,"GlowLayer",1)
 -- A soft ellipse (round frame, radial-looking falloff from two crossed gradients). The
 -- 9-slice focus glow showed its slice rectangle at this size (Studio 2026-11-13).
 self.glow=Kit.node("Frame",glowLayer,{Name="AccentGlow",BackgroundColor3=accent,BackgroundTransparency=1,BorderSizePixel=0,
  AnchorPoint=Vector2.new(.5,.5),ZIndex=glowLayer.ZIndex+1})
 Kit.node("UICorner",self.glow,{CornerRadius=UDim.new(.5,0)})
 Kit.node("UIGradient",self.glow,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})})
 -- Streaks: three accent bands and two hairlines at -16°, behind the pet.
 local streakLayer=layerFrame(root,"Streaks",2)
 self.streaks=Kit.frame(streakLayer,"Sweep",nil,UDim2.new(),UDim2.fromOffset(10,10));self.streaks.AnchorPoint=Vector2.new(.5,.5);self.streaks.Rotation=-16
 self.streakParts={}
 for index,spec in ipairs({{.22,140,.80},{.46,48,.78},{-.30,96,.86},{.36,3,.35},{-.12,3,.45}})do
  local band=fill(self.streaks,"Streak"..index,if spec[2]<=3 then Color3.new(1,1,1)else accent,spec[3])
  band.AnchorPoint=Vector2.new(.5,.5)
  C.gradient(band,0,{{0,1},{.25,0},{.75,0},{1,1}})
  self.streakParts[index]={node=band,y=spec[1],h=spec[2],base=spec[3]}
 end
 -- Spotlight cone: each half is one clip rect holding one frame rotated to the
 -- cone's edge, with a screen-vertical falloff gradient. A wider, fainter cone
 -- behind gives the soft edge. No stacked strips, so no banding.
 local coneLayer=layerFrame(root,"Cone",3)
 -- The halves live in one group centred on the pet (top edge anchored), so the
 -- idle ±3% breathing is a single UIScale write rather than geometry writes.
 local coneGroup=Kit.frame(coneLayer,"ConeGroup",nil,UDim2.new(),UDim2.fromOffset(1,1));coneGroup.AnchorPoint=Vector2.new(.5,0)
 self.coneGroup=coneGroup;self.coneScale=Kit.node("UIScale",coneGroup,{Scale=1})
 self.cone={}
 for layerIndex,spec in ipairs({{"Halo",1.3,.86},{"Beam",1,.62}})do
  for side=-1,1,2 do
   local clip=Kit.frame(coneGroup,spec[1]..(if side<0 then "Left"else "Right"),nil,UDim2.new(),UDim2.fromOffset(1,1))
   clip.ClipsDescendants=true;clip.ZIndex=coneGroup.ZIndex+layerIndex
   local light=fill(clip,"Light",Color3.fromHex("#FFE9C4"),spec[3]);light.AnchorPoint=Vector2.new(.5,.5)
   local gradient=C.gradient(light,90,{{0,.1},{.55,.35},{1,.05}})
   table.insert(self.cone,{clip=clip,light=light,gradient=gradient,side=side,spread=spec[2],base=spec[3]})
  end
 end
 -- Floor pool (three nested soft pills), accent ring (tangent segments),
 -- contact shadow (one soft pill).
 local poolLayer=layerFrame(root,"Pool",4)
 self.pool,self.shadow,self.ringSegs={},{},{}
 for index,share in ipairs({1,.72,.44})do
  local pill=fill(poolLayer,"Pool"..index,Color3.fromHex("#FFE2A8"),.8);pill.AnchorPoint=Vector2.new(.5,.5);Kit.corner(pill,999)
  C.gradient(pill,0,{{0,1},{.18,.2},{.5,0},{.82,.2},{1,1}});self.pool[index]={node=pill,share=share}
 end
 do
  local pill=fill(poolLayer,"Shadow",Color3.new(0,0,0),.45);pill.AnchorPoint=Vector2.new(.5,.5);pill.ZIndex+=1;Kit.corner(pill,999)
  C.gradient(pill,0,{{0,1},{.25,.1},{.5,0},{.75,.1},{1,1}});self.shadow[1]={node=pill,share=1}
 end
 for index=1,72 do
  local seg=fill(poolLayer,"Ring"..index,accent,0);seg.AnchorPoint=Vector2.new(.5,.5);seg.ZIndex+=2;self.ringSegs[index]=seg
 end
 -- Pet, with a soft warm glow right behind it (nested discs, so no edge shows).
 local petLayer=layerFrame(root,"Pet",5)
 self.petLayer=petLayer
 self.petGlow={}
 for index=1,Stage.Light.glowDiscs do
  local disc=fill(petLayer,"PetGlow"..index,Stage.Light.glow,1);disc.AnchorPoint=Vector2.new(.5,.5);disc.ZIndex=petLayer.ZIndex;Kit.corner(disc,999)
  self.petGlow[index]=disc
 end
 self:createPet()
 -- Sparkles: burst, idle twinkles and dust in the beam.
 local sparkLayer=layerFrame(root,"Sparkles",6)
 self.burst,self.twinkles,self.dust={},{},{}
 for index=1,if self.jackpot then Stage.Rare.burstCount else Stage.BurstCount do
  local spark=C.sparkle(sparkLayer,math.floor(16+10*hash(index,1)),if index%3==0 then accent else Color3.new(1,1,1));spark.Visible=false;self.burst[index]=spark
 end
 for index=1,Stage.TwinkleCount do
  local spark=C.sparkle(sparkLayer,math.floor(12+10*hash(index,2)),Color3.new(1,1,1));spark.Visible=false;self.twinkles[index]=spark
 end
 for index=1,Stage.DustCount do
  local mote=fill(sparkLayer,"Dust"..index,Color3.fromHex("#FFF2D6"),.4);Kit.corner(mote,999);mote.AnchorPoint=Vector2.new(.5,.5);mote.Visible=false;self.dust[index]=mote
 end
 -- Confetti popper pieces (one pool, painted only while the pop is alive).
 self.confettiPieces={}
 local confettiLayer=Kit.frame(root,"Confetti",nil,UDim2.new(),UDim2.fromScale(1,1));confettiLayer.ZIndex=sparkLayer.ZIndex+5
 for index=1,Stage.ConfettiCount do
  local piece=fill(confettiLayer,"Piece"..index,C.Confetti[(index-1)%#C.Confetti+1],0)
  piece.AnchorPoint=Vector2.new(.5,.5);piece.Visible=false;piece.ZIndex=confettiLayer.ZIndex+1
  if index%4==0 then Kit.corner(piece,999)end
  self.confettiPieces[index]=piece
 end
 if self.jackpot then self:buildJackpot(confettiLayer)end
 local flashLayer=layerFrame(root,"Flash",7)
 self.flash=fill(flashLayer,"White",Color3.new(1,1,1),1);self.flash.Size=UDim2.fromScale(1,1)
 -- Headline.
 local headLayer=layerFrame(root,"HeadlineLayer",8)
 self.headline=C.headline(headLayer,{tagSize=26,lineSize=80,rotation=-4})
 -- Name plate group (rotated 4° up to the right).
 local plateLayer=layerFrame(root,"PlateLayer",9)
 local plate=Kit.frame(plateLayer,"NamePlate",nil,UDim2.new(),UDim2.fromOffset(10,10));plate.Rotation=-4;self.plate=plate
 self.plateSmear=fill(plate,"Smear",accent,.72)
 self.plateBody=fill(plate,"Plate",accent,0);self.plateBody.ZIndex+=1
 -- The slanted end: a frame left of the plate whose gradient cuts it along its diagonal
 -- (opaque below the cut), so its top and bottom edges are the plate's own.
 self.plateCut=fill(plate,"SlantedEnd",accent,0);self.plateCut.ZIndex+=1
 self.plateCutGradient=Kit.node("UIGradient",self.plateCut,{Name="Cut"})
 self.dots={}
 local dotColor=accent:Lerp(Color3.new(1,1,1),.45)
 for row=1,5 do for col=1,12 do
  local dot=fill(plate,"Dot",dotColor,0);Kit.corner(dot,999);dot.AnchorPoint=Vector2.new(.5,.5);dot.ZIndex+=2
  table.insert(self.dots,{node=dot,row=row,col=col})
 end end
 self.plateTagBox=fill(plate,"TagStrip",C.Ink,.05);self.plateTagBox.ZIndex+=3
 self.plateTag=C.display(self.plateTagBox,Stage.tagStrip(self.pet,self.kind),22,accent,{Name="TagText",TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromScale(1,1)})
 self.name=C.display(plate,string.upper(self.options.name or self.pet.name or "FRIEND"),128,self.ink,{Name="PetName"});self.name.ZIndex=self.plateBody.ZIndex+4
 self.nameScale=Kit.node("UIScale",self.name,{Scale=1})
 self.glint=fill(plate,"Glint",Color3.new(1,1,1),.55);self.glint.Rotation=20;self.glint.ZIndex=self.name.ZIndex+1;self.glint.Visible=false
 C.gradient(self.glint,0,{{0,1},{.5,0},{1,1}})
 -- Description strip (not rotated, so its wipe can clip).
 local descLayer=layerFrame(root,"DescriptionLayer",10)
 self.descClip=Kit.frame(descLayer,"DescriptionClip",nil,UDim2.new(),UDim2.fromOffset(1,1));self.descClip.ClipsDescendants=true
 self.descBox=fill(self.descClip,"Strip",C.Ink,.12)
 self.descBar=fill(self.descBox,"AccentBar",accent,0)
 self.desc=Kit.text(self.descBox,"BodyMedium",self.options.description or self.pet.description or "","text",{Name="Description",TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd})
 -- Input pad under the buttons.
 local pad=Kit.node("TextButton",root,{Name="SpinPad",Text="",AutoButtonColor=false,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),
  ZIndex=root.ZIndex+115,Selectable=false})
 pad:SetAttribute("AccessibleLabel","Drag to spin");self.pad=pad
 -- Buttons, spin hint, next step.
 local ui=layerFrame(root,"Controls",12);self.ui=ui
 self.hint=Kit.frame(ui,"SpinHint","well",UDim2.new(),UDim2.fromOffset(10,10),999);self.hint.AnchorPoint=Vector2.new(.5,.5);self.hint.BackgroundTransparency=.1;Kit.stroke(self.hint)
 self.hintIcon=Kit.icon(self.hint,"replay",16,"text");self.hintIcon.AnchorPoint=Vector2.new(0,.5)
 self.hintText=Kit.text(self.hint,"Strong","Drag to spin","text",{Name="HintText"})
 if self.options.next then
  self.nextPill=Kit.frame(ui,"NextStep","well",UDim2.new(),UDim2.fromOffset(10,10),999);self.nextPill.AnchorPoint=Vector2.new(0,.5);self.nextPill.BackgroundTransparency=.1;Kit.stroke(self.nextPill)
  self.nextLabel=Kit.text(self.nextPill,"Label","NEXT","dim",{Name="NextLabel"})
  self.nextText=Kit.text(self.nextPill,"Body",self.options.next,"soft",{Name="NextText"})
 end
 self.selectionNone=Instance.new("Frame");self.selectionNone.BackgroundTransparency=1;self.selectionNone.Size=UDim2.fromScale(1,1)
 for index,spec in ipairs(self.options.buttons or {})do
  local button=Kit.button(ui,"Stage"..(spec.id or tostring(index)),{variant=if spec.primary then "primary"else "secondary",text=spec.text or spec.id,glyph=spec.glyph})
  button.SelectionImageObject=self.selectionNone;button.Visible=false
  local entry={id=spec.id,node=button,primary=spec.primary==true,enabled=true,width=0}
  button.Activated:Connect(function()self.focus=index;self:paintFocus();self:activate(index,true)end)
  self.buttons[index]=entry
  if spec.primary then self.focus=index end
 end
 if self.focus==0 then self.focus=#self.buttons end
 for index,entry in ipairs(self.buttons)do
  local left,right=self.buttons[index-1],self.buttons[index+1]
  if left then entry.node.NextSelectionLeft=left.node end
  if right then entry.node.NextSelectionRight=right.node end
 end
 self.ring=Kit.focusRing(ui)
 self.cover=fill(root,"FadeCover",C.Stage,1);self.cover.Size=UDim2.fromScale(1,1);self.cover.ZIndex=root.ZIndex+200;self.cover.Active=false
 Kit.paint(self.cover,"BackgroundColor3","shell")
 -- The shell's checker and the tier's well, under every layer (layers start at +10).
 local b=ItemStage.backdrop(root,root.ZIndex,self.tier,"companion")
 b.shell.BackgroundTransparency=1
 -- Round 3: a Rare pet keeps the light shafts behind its well (Fable brief 3).
 for _,extra in ipairs({b.seat,b.waitEgg})do extra:Destroy()end
 if self.jackpot then b.shafts.Visible=false else b.shafts:Destroy();b.shafts=nil end
 self.backdrop=b;self.checkerOffset=0;self.rayTurn=0;self.shaftTurn=0;self.shaftLevel=0
 self.coneGroup.Visible=false
end
-- Round 3 (Fable brief 3, 8): the Rare pet's jackpot nodes, the same ones HatchItemStage draws:
-- the shockwave line, the rainbow screen edge (rounded inner corners), the "RARE!" stamp and the
-- two cannons' 52 pieces. Built only for a Rare pet, so a Bear stage is unchanged.
function Stage:buildJackpot(confettiLayer)
 local root=self.root
 self.shock=Kit.node("Frame",root,{Name="Shockwave",BackgroundTransparency=1,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),ZIndex=root.ZIndex+65,Visible=false})
 Kit.node("UICorner",self.shock,{CornerRadius=UDim.new(.5,0)})
 self.shockStroke=Kit.node("UIStroke",self.shock,{Color=Color3.new(1,1,1),Thickness=10})
 local keys={}
 for i,hex in ipairs(ItemStage.Rainbow)do table.insert(keys,ColorSequenceKeypoint.new((i-1)/(#ItemStage.Rainbow-1),Color3.fromHex(hex)))end
 self.edge=Kit.node("Frame",root,{Name="RainbowEdge",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=root.ZIndex+75,Visible=false,Active=false})
 self.edgeStroke=Kit.inner(Kit.node("UIStroke",self.edge,{Thickness=Stage.Rare.edgeBand,Color=Color3.new(1,1,1),ApplyStrokeMode=Enum.ApplyStrokeMode.Border}))
 self.edgeCorner=Kit.node("UICorner",self.edge,{CornerRadius=UDim.new(0,0)})
 self.edgeGradient=Kit.node("UIGradient",self.edgeStroke,{Color=ColorSequence.new(keys)})
 self.stamp=Kit.node("TextLabel",root,{Name="RareStamp",BackgroundTransparency=1,BorderSizePixel=0,ZIndex=root.ZIndex+76,Visible=false,
  Text=Copy.get("hatch.result.stamp.rare"),FontFace=Kit.DisplayFace,TextSize=64,TextColor3=Color3.new(1,1,1),
  TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,AnchorPoint=Vector2.new(.5,.5),Rotation=-6})
 self.stampStroke=Kit.node("UIStroke",self.stamp,{Color=ItemStage.Ink,Thickness=5,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 self.stampScale=Kit.node("UIScale",self.stamp,{Scale=1})
 self.cannonPieces={}
 local art=ItemStage.Art
 for index=1,ItemStage.Cannon.count*2 do
  local a=art[if index%3==0 then "sparkle"else "pebble"]
  local R=Stage.Rare.cannonColors
  self.cannonPieces[index]=Kit.node("ImageLabel",confettiLayer,{Name="Cannon"..index,BackgroundTransparency=1,BorderSizePixel=0,
   Image=art[a[1]],ImageRectOffset=Vector2.new(a[2],a[3]),ImageRectSize=Vector2.new(a[4],a[5]),AnchorPoint=Vector2.new(.5,.5),
   ImageColor3=Color3.fromHex(R[(index-1)%#R+1]),ZIndex=confettiLayer.ZIndex+2,Visible=false})
 end
end

-- The 3D pet: hidden until its meshes load (at most 2.5 s), then faded in, so
-- unloaded MeshParts never show as stretched boxes (QA 2026-11-12).
function Stage:createPet()
 local holder=Kit.frame(self.petLayer,"PetHolder",nil,UDim2.new(),UDim2.fromOffset(10,10));holder.AnchorPoint=Vector2.new(.5,1)
 self.petHolder=holder
 local viewport=Kit.node("ViewportFrame",holder,{Name="PetHero3D",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=holder.ZIndex+1,
  Ambient=Stage.Light.ambient,LightColor=Stage.Light.color,LightDirection=Stage.Light.direction,ImageTransparency=1})
 self.viewport=viewport;self.loaded=false
 local ok=pcall(function()
  local world=Instance.new("WorldModel");world.Name="PetStage";world.Parent=viewport;self.world=world
  local Factory=require(script.Parent.PetFactory)
  local visual=Factory.new(world,Vector3.zero,self.pet,nil,self.options.appearance);self.visual=visual
  visual.onRigChanged=function()if not self.destroyed and self.visual==visual then self:measurePet();self:placeCamera()end end
  visual:update(0)
  local camera=Instance.new("Camera");camera.Name="RevealCamera";camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera;self.camera=camera
  self:measurePet()
 end)
 if not ok then
  if self.visual then pcall(function()self.visual:destroy()end);self.visual=nil end
  if self.world then self.world:Destroy();self.world=nil end
  self.renderMode="Portrait"
  pcall(function()
   local Portrait=require(script.Parent.PetPortrait)
   self.portrait=Portrait.create(holder,self.pet,1,UDim2.fromScale(.5,.5),holder.ZIndex+2,false,self.options.appearance)
  end)
  self.loaded=true
 else
  self.renderMode="3D"
  local function ready()if self.destroyed or self.loaded then return end;self.loaded=true;self.loadedAt=self.clock end
  task.delay(2.5,ready)
  task.defer(function()
   if self.destroyed then return end
   pcall(function()game:GetService("ContentProvider"):PreloadAsync(viewport:GetDescendants())end)
   ready()
  end)
 end
 holder:SetAttribute("RenderMode",self.renderMode)
end
function Stage:measurePet()
 if not self.world then return end
 local minV,maxV=Vector3.one*math.huge,-Vector3.one*math.huge
 for _,part in ipairs(self.world:GetDescendants())do
  if part:IsA("BasePart")and part.Transparency<.99 then
   local cf,half=part.CFrame,part.Size*.5
   for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
    local p=cf:PointToWorldSpace(half*Vector3.new(x,y,z));minV=minV:Min(p);maxV=maxV:Max(p)
   end end end
  end
 end
 if minV.X==math.huge then minV,maxV=Vector3.new(-1,0,-1),Vector3.new(1,2,1)end
 self.petCenter=(minV+maxV)*.5;self.petSize=maxV-minV
end
-- Orbit camera: yaw turns the camera (and the light with it) around the pet,
-- which reads as the pet spinning under a fixed light. Pitch 8° down.
function Stage:placeCamera()
 local camera=self.camera;if not camera or not self.petCenter then return end
 local size=self.petSize;local L=self.L
 local fraction=if L then math.clamp(L.petH/math.max(1,L.petBox),.3,.95)else .84
 local reach=math.max(size.Y,math.max(size.X,size.Z)*.95)
 local distance=reach/(fraction*2*math.tan(math.rad(15)))+math.max(size.X,size.Z)*.5
 local shown=self.shownYaw or self.yaw
 -- Only write when the view actually moved (idle frames with a still pet).
 local key=string.format("%.2f|%.4f|%.4f",shown,distance,fraction)
 if self.cameraKey==key then return end
 self.cameraKey=key
 local yaw,pitch=math.rad(shown),math.rad(8)
 local offset=Vector3.new(math.sin(yaw)*math.cos(pitch),math.sin(pitch),math.cos(yaw)*math.cos(pitch))*distance
 camera.CFrame=CFrame.lookAt(self.petCenter+offset,self.petCenter)
 self.viewport.LightDirection=CFrame.Angles(0,yaw,0):VectorToWorldSpace(Stage.Light.direction)
end

-- The well behind the pet: from the top of the stage to just under its feet.
function Stage.wellRect(L)
 local top=math.max(16,math.floor(L.feet-L.petH*1.55))
 local bottom=math.min(L.H-8,math.floor(L.feet+math.max(30,L.petH*.2)))
 local w=L.wellW or math.floor(math.min(L.petBox*1.7,L.petX*2-32))
 return math.floor(L.petX-w/2),top,w,bottom-top
end
function Stage:paintBackdrop()
 local b=self.backdrop;if not b or not self.L then return end
 local alpha=self.root.BackgroundTransparency
 b.well.Visible=alpha<.5;b.rim.Visible=alpha<.5
 b.checkerTile.Position=UDim2.fromOffset(math.floor(-Kit.Checker.tile+self.checkerOffset),math.floor(-Kit.Checker.tile+self.checkerOffset))
 b.raysImage.Rotation=self.rayTurn
 -- Round 3: a Rare pet's shafts and rainbow edge keep turning while the card is up.
 if b.shafts then b.shafts.Visible=alpha<.5 and self.shaftLevel>0;b.shafts.Rotation=self.shaftTurn end
 if self.edge and self.edge.Visible and not self:reduced()then
  local turn=(self.clock*216)%360;self.edgeGradient.Rotation=turn;b.rimRainbow.Rotation=turn
 end
end
function Stage:layout()
 local size=self.root.AbsoluteSize
 local W,H=math.max(1,size.X),math.max(1,size.Y)
 local L=Stage.geometry(W,H);self.L=L
 do
  local b=self.backdrop
  local x,y,w,h=Stage.wellRect(L)
  b.well.Position=UDim2.fromOffset(x+w/2,y+h/2);b.well.Size=UDim2.fromOffset(w,h)
  b.rim.Position=b.well.Position;b.rim.Size=UDim2.fromOffset(w-6,h-6)
  local radius=math.max(12,math.floor(16*math.max(.6,L.s)))
  b.wellCorner.CornerRadius=UDim.new(0,radius);b.rimCorner.CornerRadius=UDim.new(0,radius-3)
  local inset=Kit.patternInset(radius)
  b.clip.Position=UDim2.fromOffset(inset,inset);b.clip.Size=UDim2.new(1,-inset*2,1,-inset*2)
  local diag=math.sqrt(w*w+h*h)*1.05
  b.core.Size=UDim2.fromOffset(w*1.5,h*1.5);b.raysImage.Size=UDim2.fromOffset(diag,diag)
  local fw=math.min(w,h)*.66
  local floorY=(L.feet-y)/math.max(1,h)
  b.floorLight.Position=UDim2.new(.5,0,floorY,0);b.floorLight.Size=UDim2.fromOffset(fw,fw*.28)
  b.floorShadow.Position=UDim2.new(.5,0,floorY+.01,0);b.floorShadow.Size=UDim2.fromOffset(fw*.6,fw*.13)
  self.wellBase={cx=x+w/2,cy=y+h/2,w=w,h=h,top=y}
  if self.jackpot then
   -- Round 3: the bloom opens on the egg; the rainbow edge has rounded inner corners
   -- (HatchItemStage.edgeRing; 34 px on the phone, 24 elsewhere, a 14 px band).
   b.bloom.Position=UDim2.new(.5,0,math.clamp((L.feet-L.petH*.35-y)/math.max(1,h),0,1),0)
   local R=Stage.Rare
   local ring=ItemStage.edgeRing(if L.phone then R.edgeRadius.phone else R.edgeRadius.regular,R.edgeBand)
   self.edge.Position=UDim2.fromOffset(-ring.offset,-ring.offset);self.edge.Size=UDim2.new(1,ring.offset*2,1,ring.offset*2)
   self.edgeCorner.CornerRadius=UDim.new(0,ring.corner);self.edgeStroke.Thickness=ring.thickness
   local text=math.max(40,math.floor((if L.phone then 64 else 110)*L.s+.5))
   self.stamp.TextSize=text
   self.stamp.Size=UDim2.fromOffset(math.ceil(Kit.measure(self.stamp.Text,"Title",text).X*1.2)+20,math.floor(text*1.3))
   self.stampY=math.max(y+text*.9,L.feet-L.petH*1.12)
  end
 end
 self.staticDone,self.coneKey,self.cameraKey=false,nil,nil
 -- Cone group: centred on the pet, top edge at y 0, wide enough for the halo.
 self.coneHalfW=math.ceil(L.coneBottom*1.3*.5+4)
 self.coneGroup.Position=UDim2.fromOffset(L.petX,0);self.coneGroup.Size=UDim2.fromOffset(self.coneHalfW*2,math.max(1,L.feet))
 self.headline.set(if L.dropTag then nil else Stage.headline(self.kind)[1],Stage.headline(self.kind)[2],self.accent,not L.dropTag)
 self.headline.tagText.TextSize=math.floor(L.tagSize);self.headline.label.TextSize=math.floor(L.lineSize);self.headline.shadow.TextSize=math.floor(L.lineSize)
 -- C.headline sizes come from its options; rebuild the measures at this size.
 self:fitHeadline(L)
 -- Glow behind the pet.
 self.glow.Position=UDim2.fromOffset(L.petX,L.feet-L.petH*.5);self.glow.Size=UDim2.fromOffset(L.petBox*1.5,L.petBox*1.3)
 for index,disc in ipairs(self.petGlow)do
  local share=1-(index-1)/#self.petGlow*.84
  disc.Position=UDim2.fromOffset(L.petX,L.feet-L.petH*.52);disc.Size=UDim2.fromOffset(L.petBox*1.18*share,L.petBox*1.12*share)
 end
 self.petGlowKey=nil
 -- Streak geometry (positions; the sweep moves the group).
 self.streaks.Size=UDim2.fromOffset(W*3,H*2)
 for _,part in ipairs(self.streakParts)do
  -- Band widths follow the stage height (1080 authored), so a phone keeps a
  -- near-black stage; hairlines stay 2-3 px.
  local hs=H/1080
  part.node.Size=UDim2.fromOffset(W*3,if part.h<=3 then math.max(2,math.floor(3*hs+.5))else math.max(4,part.h*hs))
  part.node.Position=UDim2.new(.5,0,.5,part.y*H)
 end
 -- Pool ellipse, shadow and ring.
 local cx,cy=L.petX,L.feet
 local function pills(list,rx,ry)
  for _,entry in ipairs(list)do
   entry.node.Position=UDim2.fromOffset(cx,cy);entry.node.Size=UDim2.fromOffset(math.max(2,2*rx*entry.share),math.max(2,2*ry*entry.share))
  end
 end
 pills(self.pool,L.poolRX*.98,L.poolRY*.96);pills(self.shadow,L.poolRX*.42,L.poolRY*.36)
 local n=#self.ringSegs
 for index,seg in ipairs(self.ringSegs)do
  local a=(index-1)/n*math.pi*2;local b=index/n*math.pi*2
  local p=Vector2.new(cx+L.poolRX*math.cos(a),cy+L.poolRY*math.sin(a));local q=Vector2.new(cx+L.poolRX*math.cos(b),cy+L.poolRY*math.sin(b))
  local mid=(p+q)*.5;local d=q-p
  seg.Position=UDim2.fromOffset(mid.X,mid.Y);seg.Size=UDim2.fromOffset(d.Magnitude+1.5,L.ring);seg.Rotation=math.deg(math.atan2(d.Y,d.X))
 end
 -- Plate.
 local plateW=W-L.plateX+math.floor(L.plateH*.6)
 self.plateW=plateW
 self.plate.Size=UDim2.fromOffset(plateW+L.plateH,L.plateH)
 self.plateBody.Size=UDim2.fromOffset(plateW+L.plateH,L.plateH)
 self.plateSmear.Size=self.plateBody.Size;self.plateSmear.Position=UDim2.fromOffset(L.plateH*.5,0)
 do
  local overlap=2
  local w,rotation,from,to=Stage.slantEnd(L.plateH,overlap)
  self.plateCut.Position=UDim2.fromOffset(-w,0);self.plateCut.Size=UDim2.fromOffset(w+overlap,L.plateH)
  self.plateCutGradient.Rotation=rotation
  self.plateCutGradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(from,1),NumberSequenceKeypoint.new(to,0),NumberSequenceKeypoint.new(1,0)})
 end
 local dot=math.max(3,L.plateH*.075)
 for _,entry in ipairs(self.dots)do
  local x=plateW*.62+(entry.col-1)*(plateW*.38/12)+(if entry.row%2==0 then dot*.6 else 0)
  local y=L.plateH*(.16+(entry.row-1)*.17)
  entry.node.Position=UDim2.fromOffset(x,y)
  local share=(entry.col-1)/11
  entry.node.Size=UDim2.fromOffset(dot*(.5+.5*share),dot*(.5+.5*share));entry.node.BackgroundTransparency=.55-.4*share
 end
 local tagText=self.plateTag.Text
 self.plateTag.TextSize=math.floor(L.plateTag)
 local tw=C.measure(tagText,L.plateTag).X+math.floor(L.plateTag*1.4)
 local th=math.floor(L.plateTag*1.6)
 self.plateTagBox.Size=UDim2.fromOffset(tw,th);self.plateTagBox.Position=UDim2.fromOffset(math.floor(L.plateH*.42),-th)
 local available=W-L.plateX-L.plateH*.5-(if L.phone then 24 else 60)
 local wanted=C.measure(self.name.Text,L.nameSize).X
 local nameSize=if wanted>available then math.max(20,math.floor(L.nameSize*available/wanted))else math.floor(L.nameSize)
 self.name.TextSize=nameSize
 self.name.Position=UDim2.fromOffset(math.floor(L.plateH*.36),0);self.name.Size=UDim2.fromOffset(math.max(1,available),L.plateH)
 self.glint.Size=UDim2.fromOffset(math.max(6,L.plateH*.16),L.plateH*1.1)
 -- Twinkles sit still (only their fade animates); dust motes have one size.
 do
  local cx,cy=L.petX,L.feet-L.petH*.55
  for index,spark in ipairs(self.twinkles)do
   local a=hash(index,5)*math.pi*2;local r=L.petBox*(.35+.35*hash(index,6))
   spark.Position=UDim2.fromOffset(cx+math.cos(a)*r*1.15,cy+math.sin(a)*r*.75)
  end
  local d=math.max(2,math.floor(3*math.max(L.s,.6)))
  for _,mote in ipairs(self.dust)do mote.Size=UDim2.fromOffset(d,d)end
  self.moteState=nil
 end
 -- Description.
 local descText=self.desc.Text
 self.desc.TextSize=math.floor(L.descSize)
 local textW=math.min(L.descW,C.measure(descText,L.descSize).X*.86+8)
 local boxH=math.floor(L.descSize*(if L.descLines>1 and textW>=L.descW then 2.7 else 1.9))
 self.descFullW=math.floor(textW+L.descSize*1.6)
 self.descClip.Position=UDim2.fromOffset(L.descX,L.descY);self.descClip.Size=UDim2.fromOffset(self.descFullW,boxH)
 self.descBox.Size=UDim2.fromOffset(self.descFullW,boxH)
 self.descBar.Size=UDim2.fromOffset(math.max(3,math.floor(4*math.max(L.s,.75))),boxH)
 self.desc.Position=UDim2.fromOffset(math.floor(L.descSize*.9),0);self.desc.Size=UDim2.fromOffset(math.floor(textW),boxH)
 self.desc.TextWrapped=L.descLines>1
 -- Buttons right-aligned at the bottom; Meet on the right.
 local x=W-L.margin
 for index=#self.buttons,1,-1 do
  local entry=self.buttons[index]
  local w=if entry.primary then L.meetW else L.playW
  entry.width=w;entry.node.Size=UDim2.fromOffset(w,L.btnH)
  local state=Kit.buttonState(entry.node);if state then state.label.TextSize=L.btnText;state.label.Size=UDim2.fromOffset(0,L.btnH)end
  x-=w;entry.x=x;x-=L.gap
 end
 -- Hint and next step.
 local hintW=C.measure("Drag to spin",L.hintSize).X*.85+L.hintSize*2.6
 self.hint.Size=UDim2.fromOffset(hintW,math.floor(L.hintSize*2));self.hintText.TextSize=math.floor(L.hintSize)
 self.hintIcon.Size=UDim2.fromOffset(L.hintSize+2,L.hintSize+2);self.hintIcon.Position=UDim2.new(0,math.floor(L.hintSize*.6),.5,0)
 self.hintText.Position=UDim2.fromOffset(math.floor(L.hintSize*2),0);self.hintText.Size=UDim2.new(1,-math.floor(L.hintSize*2),1,0)
 if self.nextPill then
  self.nextPill.Visible=not L.phone and L.nextX~=nil
  if L.nextX then
   local size=math.floor(L.nextSize)
   local textW2=C.measure(self.nextText.Text,size).X*.85
   self.nextPill.Position=UDim2.fromOffset(L.nextX-16,L.nextY);self.nextPill.Size=UDim2.fromOffset(textW2+size*5.5,size*2.4)
   self.nextLabel.TextSize=math.max(12,size-3);self.nextLabel.Position=UDim2.fromOffset(size,0);self.nextLabel.Size=UDim2.fromOffset(size*3,size*2.4)
   self.nextText.TextSize=size;self.nextText.Position=UDim2.fromOffset(size*4,0);self.nextText.Size=UDim2.fromOffset(textW2+size,size*2.4)
  end
 end
 self:placeCamera()
 self:placeLead()
 self:paint()
end
function Stage:fitHeadline(L)
 local h=self.headline
 local kind=Stage.headline(self.kind)
 -- Re-run the headline measure at the layout's sizes.
 local tagSize,lineSize=math.floor(L.tagSize),math.floor(L.lineSize)
 h.tagText.TextSize,h.label.TextSize,h.shadow.TextSize=tagSize,lineSize,lineSize
 local tw=C.measure(kind[1],tagSize);local lw=C.measure(kind[2],lineSize)
 local tagH=if L.dropTag then 0 else math.floor(tagSize*1.45)
 h.tag.Visible=tagH>0;h.tag.Size=UDim2.fromOffset(tw.X+math.floor(tagSize*1.1),tagH);h.tag.Position=UDim2.fromOffset(math.floor(lineSize*.08),0)
 local lineH=math.floor(lineSize*1.1);local y=if tagH>0 then tagH-math.floor(lineSize*.08)else 0
 h.label.Position,h.label.Size=UDim2.fromOffset(0,y),UDim2.fromOffset(lw.X+8,lineH)
 local drop=math.max(2,math.floor(lineSize*.06))
 h.shadow.Position,h.shadow.Size=UDim2.fromOffset(drop,y+drop),h.label.Size
 local ul=math.max(3,math.floor(lineSize*.08))
 h.underline.Position=UDim2.fromOffset(0,y+lineH-math.floor(lineSize*.02));h.underline.Size=UDim2.fromOffset(math.floor((lw.X+8)*.86),ul)
 h.root.Size=UDim2.fromOffset(lw.X+8+drop,y+lineH+ul+4)
end

-- Paint one sample (timeline) plus the idle layer once settled.
function Stage:currentSample()
 if self.reducedStart then return Stage.reducedSample(self.age,self.jackpot)end
 return Stage.sample(self.age,self.jackpot)
end
-- One half of the cone: clip rect from the centre line out to the floor width,
-- holding one frame whose inner-facing edge lies on the cone's slanted edge.
function Stage:placeConeHalf(half,width)
 local L=self.L
 local top=L.coneTop*width*half.spread;local bottom=L.coneBottom*width*half.spread
 -- Group-local: the group is centred on the pet, `coneHalfW` either side.
 local feet=math.max(1,L.feet);local cx=self.coneHalfW or L.petX;local side=half.side
 local phi=math.atan((bottom-top)*.5/feet)
 local span=bottom*.5+2
 -- The left half reaches 1 px past the centre line so the halves overlap
 -- instead of leaving an anti-aliased seam.
 half.clip.Position=UDim2.fromOffset(if side<0 then cx-span else cx,0);half.clip.Size=UDim2.fromOffset(span+(if side<0 then 1 else 0),feet)
 -- Frame size: wide enough to cover the half, tall enough for the slant.
 local w,h=bottom*1.2+40,feet/math.cos(phi)+bottom
 -- Midpoint of the slanted edge, in clip coordinates.
 local mid=Vector2.new(side*(top+bottom)*.25+(if side<0 then span else 0),feet*.5)
 -- Clockwise rotation phi for the left half (top leans right), mirrored for the right.
 local rotation=-side*phi
 local inward=Vector2.new(-side*math.cos(phi)*w*.5,math.sin(phi)*w*.5)
 local centre=mid+inward
 half.light.Rotation=math.deg(rotation)
 half.light.Position=UDim2.fromOffset(centre.X,centre.Y);half.light.Size=UDim2.fromOffset(w,h)
 -- Screen-vertical falloff whatever the frame's rotation. The gradient spans
 -- the frame's projected height, so map the beam's top and the feet into it:
 -- bright at the top, a little dimmer mid-way, faded out over the bottom 15%.
 half.gradient.Rotation=90-math.deg(rotation)
 local projected=w*math.sin(phi)+h*math.cos(phi)
 local yTop=centre.Y-projected*.5
 local function at(y)return math.clamp((y-yTop)/projected,.002,.998)end
 local a,f=at(0),at(feet)
 local key=math.floor(a*1000)*10000+math.floor(f*1000)
 if half.key~=key then
  half.key=key
  local span2=f-a
  local points={{0,.1},{a,.1},{a+span2*.55,.3},{a+span2*.85,.2},{f,1},{1,1}}
  local seq={};local last=-1
  for _,p in ipairs(points)do
   local t=math.clamp(p[1],0,1)
   if t<=last then t=math.min(1,last+1e-4)end
   if t>last then table.insert(seq,NumberSequenceKeypoint.new(t,p[2]));last=t end
  end
  if seq[#seq].Time<1 then table.insert(seq,NumberSequenceKeypoint.new(1,1))end
  half.gradient.Transparency=NumberSequence.new(seq)
 end
end
-- Settled idle (phone cost): one UIScale for the breathing beam, the camera
-- only when the yaw moves, and twinkles / dust / glint only when a quantised
-- value changes. Everything else stays as the last full paint left it.
function Stage:paintIdle()
 self:paintBackdrop()
 local clock=self.clock
 local idle=not self.reducedStart and not self:reduced()
 local breathe=if idle then 1+.03*math.sin(clock*math.pi*2/4)else 1
 breathe=math.floor(breathe*400+.5)/400
 if self.coneScale.Scale~=breathe then self.coneScale.Scale=breathe end
 self.shownYaw=self.yaw;self:placeCamera()
 self:paintSparkles(true,idle,clock)
 self:paintGlint(idle,clock)
end
function Stage:paintSparkles(on,idle,clock)
 local L=self.L
 self.twinkleLevels=self.twinkleLevels or {}
 for index,spark in ipairs(self.twinkles)do
  if spark.Visible~=on then spark.Visible=on end
  if on then
   local tw=if idle then .5+.5*math.sin(clock*(2.2+hash(index,7))+index*1.7)else .7
   local level=math.floor((1-tw)*20+.5)/20
   if self.twinkleLevels[index]~=level then self.twinkleLevels[index]=level;C.fadeSparkle(spark,level)end
  end
 end
 self.moteState=self.moteState or {}
 for index,mote in ipairs(self.dust)do
  if mote.Visible~=idle then mote.Visible=idle end
  if idle then
   local speed=18+20*hash(index,8);local span=L.feet*.9
   local y=L.feet-((clock*speed+hash(index,9)*span)%span)
   local half=(L.coneTop+(L.coneBottom-L.coneTop)*(y/L.feet))*.4
   local x=math.floor(L.petX+(hash(index,10)*2-1)*half+math.sin(clock+index)*6+.5);y=math.floor(y+.5)
   local alpha=math.floor((.35+.4*math.abs(math.sin(clock*.7+index)))*20+.5)/20
   local state=self.moteState[index]
   if not state then state={};self.moteState[index]=state end
   if state.x~=x or state.y~=y then state.x,state.y=x,y;mote.Position=UDim2.fromOffset(x,y)end
   if state.alpha~=alpha then state.alpha=alpha;mote.BackgroundTransparency=alpha end
  end
 end
end
function Stage:paintGlint(idle,clock)
 local L=self.L
 local g=clock%5;local on=idle and g<.6
 if self.glint.Visible~=on then self.glint.Visible=on end
 if on then self.glint.Position=UDim2.fromOffset(L.plateH*.2+(self.plateW or 0)*.7*(g/.6),-L.plateH*.05)end
end
function Stage:paint()
 local L=self.L;if not L or self.destroyed then return end
 -- Settled and unchanged since the last full paint: the cheap idle path.
 if self.staticDone and not self.exiting and not self.boopAt and self:isSettled()then self:paintIdle();return end
 local s=self:currentSample();self.lastSample=s
 local reduced=s.reduced==true
 -- Egg lead-in: the egg sits in a narrow spotlight on the black stage while it wobbles.
 local lead=self.lead;local leading=lead~=nil and not lead.done
 local ls=lead and lead.sample
 if lead then
  local show=not reduced and not self.instant and ls.egg>0 and not(lead.done and self:isSettled())
  if lead.seat.Visible~=show then lead.seat.Visible=show end
 end
 local idle=s.settled and not reduced and not self:reduced()
 local clock=self.clock
 local exit=self.exiting and math.clamp((clock-self.exiting.at)/.18,0,1)or 0
 local meetExit=self.exiting and self.exiting.kind=="meet"
 -- Opening with an egg lead-in (QA R4): the dim, the spotlight, the pool and the egg all
 -- fade in together on real time (the hatch clock may still be waiting for its window).
 local opening=if lead and not reduced and not self.instant then C.openSample(self.openElapsed or os.clock()-self.openedAt)else nil
 -- `open` is the egg, spotlight and pool; the dark backdrop leads it (QA v735 H1).
 local open=if opening then opening.content else 1
 local openDim=if opening then opening.dim else 1
 if lead and lead.scene and type(lead.scene.setVeil)=="function"and not lead.scene.destroyed then lead.scene:setVeil(1-open)end
 -- The stage fades to black over the egg scene (120 ms; 150 ms when reduced).
 self.root.BackgroundTransparency=if lead then 1-openDim else 1-(if reduced then s.fade else s.dark)
 self:paintBackdrop()
 -- "Play again" fades the stage out under the cover.
 local cover=if self.exiting and not meetExit then 1-exit else 1
 self.cover.BackgroundTransparency=cover;self.cover.Visible=cover<1
 -- Cone (25% -> 100% width) narrows on Meet; geometry is rewritten only when
 -- that width changes. Idle breathing is the group's UIScale (paintIdle).
 local width=(.25+.75*s.spot)*(1-.7*(if meetExit then exit else 0))
 -- With an egg lead-in the spotlight and pool are already up, and stay up through the hand-off.
 local coneOn=s.t>=.12 or reduced or lead~=nil
 local coneKey=if coneOn then math.floor(width*2000+.5)else -1
 local fade=if meetExit then .3*exit else 0
 if self.coneKey~=coneKey or self.coneFade~=fade or self.coneOpen~=open then
  self.coneKey,self.coneFade,self.coneOpen=coneKey,fade,open
  for _,half in ipairs(self.cone)do
   half.clip.Visible=coneOn
   if coneOn then self:placeConeHalf(half,width)end
   half.light.BackgroundTransparency=1-(1-math.min(1,half.base+fade))*open
  end
 end
 local poolOn=s.t>=.12 or reduced or lead~=nil
 local poolKey=(if poolOn then 1 else 0)+(if s.colour<1 then 2 else 0)+math.floor(open*100+.5)*4
 if self.poolKey~=poolKey then
  self.poolKey=poolKey
  for _,entry in ipairs(self.pool)do entry.node.Visible=poolOn;entry.node.BackgroundTransparency=1-.2*open end
  for _,entry in ipairs(self.shadow)do entry.node.Visible=poolOn;entry.node.BackgroundTransparency=1-.55*open end
  for _,seg in ipairs(self.ringSegs)do seg.Visible=poolOn;seg.BackgroundTransparency=1-(if s.colour<1 then .5 else .95)*open end
 end
 self.glow.BackgroundTransparency=if s.colour>0 then .82-.08*s.colour elseif leading then 1-.2*ls.glow*(.8+.2*math.sin(clock*9))else 1
 -- Streaks sweep in from the left, three times brighter at first.
 self.streaks.Position=UDim2.fromOffset(L.petX-(1-s.streak)*L.W*1.4,L.feet-L.petH*.45)
 self.streaks.Visible=false
 for _,part in ipairs(self.streakParts)do
  part.node.BackgroundTransparency=1-math.min(1,(1-part.base)*s.streakGlow*(if L.phone and part.h>3 then .7 else 1))
 end
 -- Pet: rise, silhouette -> colour, spin in, boop squash.
 local box=L.petBox*(.55+.45*s.rise)
 local squash=0
 if self.boopAt then local b=clock-self.boopAt;if b<.28 then squash=.07*math.sin(b/.28*math.pi)*(1-b/.28)else self.boopAt=nil end end
 -- Round 3: a Rare pet's leap arc, hops and landing squashes (none on a Bear).
 squash+=if reduced then 0 else(s.squash or 0)
 local lift=if reduced then 0 else(s.arc or 0)*L.petH
 self.petHolder.Position=UDim2.fromOffset(L.petX,L.feet+(L.petBox-L.petH)*.5*(box/L.petBox)-lift)
 self.petHolder.Size=UDim2.fromOffset(box*(1+squash),box*(1-squash))
 -- Hidden until loaded, then a 220 ms fade (the load fade-in from the card).
 local loadMask=1
 if self.loaded then
  loadMask=if self.loadedAt and not reduced then 1-math.clamp((clock-self.loadedAt)/.22,0,1)else 0
 end
 self.viewport.ImageTransparency=math.max(loadMask,1-s.shown)
 local shade=if reduced then 1 else s.colour
 self.viewport.ImageColor3=Color3.new(0,0,0):Lerp(Color3.new(1,1,1),shade)
 if self.portrait then self.portrait.Visible=s.shown>0 end
 -- The soft glow comes up as the silhouette takes its colour.
 local glowKey=math.floor(shade*open*50+.5)
 if self.petGlowKey~=glowKey then
  self.petGlowKey=glowKey
  local each=1-(1-Stage.Light.glowAlpha*glowKey/50)^(1/#self.petGlow)
  for _,disc in ipairs(self.petGlow)do disc.BackgroundTransparency=1-each;disc.Visible=glowKey>0 end
 end
 self.shownYaw=self.yaw+(if reduced then 0 else s.spinIn)
 self:placeCamera()
 -- Flash.
 -- v2 photosensitivity (section 4): no full-screen flash, for everyone.
 self.flash.BackgroundTransparency=1
 self:paintConfetti()
 if self.jackpot then self:paintJackpot(s,reduced)end
 -- Burst sparkles (Round 3: 30 for a Rare pet, 18 for the Bear).
 local cx,cy=L.petX,L.feet-L.petH*.55
 local count=#self.burst
 for index,spark in ipairs(self.burst)do
  spark.Visible=s.burstAlive and not reduced
  if spark.Visible then
   local a=index/count*math.pi*2+hash(index,3)*.4
   local r=s.burst*L.petBox*(.45+.4*hash(index,4))
   spark.Position=UDim2.fromOffset(cx+math.cos(a)*r,cy+math.sin(a)*r*.8)
   C.fadeSparkle(spark,math.clamp((s.burst-.55)/.45,0,1))
  end
 end
 -- Twinkles (idle; still under Reduced Motion) and dust: see paintIdle.
 self:paintSparkles(s.colour>=1 or reduced,idle,clock)
 -- Headline slams in from the left (Back Out gives the overshoot).
 local headOut=if meetExit then exit else 0
 self.headline.root.Visible=s.headline>0 or reduced
 self.headline.root.Position=UDim2.fromOffset(L.headX-(1-s.headline)*(L.W*.55)-headOut*L.W*.6,L.headY)
 -- Plate slides in from the right with a smear; letters pop.
 local plateIn=s.plate
 self.plate.Visible=plateIn>0 or reduced
 self.plate.Position=UDim2.fromOffset(L.plateX+(1-plateIn)*L.W*.7+headOut*L.W*.7,L.plateY)
 self.plateSmear.Visible=plateIn>0 and plateIn<.98 and not reduced
 local letters=#self.name.Text
 self.name.MaxVisibleGraphemes=if reduced or s.settled then -1 else math.min(letters,s.letters)
 local pop=if reduced or s.settled or s.t<s.plateAt then 0 else math.max(0,1-((s.t-s.plateAt)%.04)/.04)
 self.nameScale.Scale=1+.06*pop
 self:paintGlint(idle,clock)
 -- Description wipe.
 self.descClip.Visible=s.desc>0 or reduced
 self.descClip.Size=UDim2.fromOffset(math.max(1,(self.descFullW or 1)*(if reduced then 1 else s.desc)),self.descBox.Size.Y.Offset)
 if meetExit then self.descClip.Visible=exit<1 end
 -- Buttons and hint.
 local rise=(1-s.buttons)*12
 for _,entry in ipairs(self.buttons)do
  entry.node.Visible=s.buttons>0 or reduced
  entry.node.Position=UDim2.fromOffset(entry.x or 0,L.btnY+rise)
 end
 self.hint.Visible=(s.buttons>0 or reduced)and not self.spun
 self.hint.Position=UDim2.fromOffset(L.hintX,L.hintY+rise)
 if self.nextPill then self.nextPill.Visible=(s.buttons>0 or reduced)and not L.phone end
 if s.input and not self.inputOpened then
  self.inputOpened=true;self:paintFocus()
  -- Gamepad: focus lands on Meet once the buttons exist (they are hidden before).
  if self:owned()and string.match(Input:GetLastInputType().Name,"^Gamepad")and(GuiService.SelectedObject==nil or not GuiService.SelectedObject:IsDescendantOf(self.root))then
   local primary=self:primaryButton();if primary then GuiService.SelectedObject=primary end
  end
 end
 -- The first settled frame is the last full paint; idle frames take paintIdle.
 -- (Not before the pet has loaded and finished its fade-in.)
 local petDone=self.loaded and(not self.loadedAt or self.clock-self.loadedAt>=.25)
 -- (Round 3: a calm Rare frame also waits for its stamp to fade.)
 local calmStamp=self.jackpot and reduced and self.age<Stage.Rare.reducedStampOut+.15
 if s.settled and not self.exiting and not self.boopAt and self.inputOpened and petDone and not self:confettiAlive()and(not opening or opening.done)and not calmStamp then self.staticDone=true end
end
-- Round 3: the Rare pet's jackpot lanes (Stage.jackpot on the hatch clock, the stamp on the
-- entrance clock). The lead-in's hatch age drives the burst, so it lands as the shell opens.
function Stage:paintJackpot(s,reduced)
 local L,b=self.L,self.backdrop;local lead=self.lead
 local h=if lead and not lead.done then lead.age else Stage.LeadIn+s.t
 local j=Stage.jackpot(h,reduced)
 local shake=((j.shake or 0)+(s.stampShake or 0))*math.max(L.s,.6)
 local dx,dy=0,0
 if shake>0 then dx,dy=math.sin(self.clock*61)*shake,math.cos(self.clock*53)*shake*.6 end
 local base=self.wellBase
 if base then
  local w,hh=base.w+48*L.s*j.punch,base.h+12*L.s*j.punch
  b.well.Position=UDim2.fromOffset(base.cx+dx,base.cy+dy);b.well.Size=UDim2.fromOffset(w,hh)
  b.rim.Position=b.well.Position;b.rim.Size=UDim2.fromOffset(w-6,hh-6)
  self.petLayer.Position=UDim2.fromOffset(math.round(dx),math.round(dy))
  self.shaftLevel=j.shafts
  if b.shafts then
   local side=math.max(L.W,L.H)*1.6
   b.shafts.Position=UDim2.fromOffset(base.cx,base.cy);b.shafts.Size=UDim2.fromOffset(side,side);b.shafts.ImageTransparency=1-j.shafts
   b.shafts.Visible=b.well.Visible and j.shafts>0
  end
 end
 -- The rainbow on the rim and round the screen.
 local rainbow=j.rainbow
 self.edge.Visible=rainbow>0 and b.well.Visible;b.rimRainbow.Enabled=rainbow>0
 if rainbow>0 then
  self.edgeStroke.Transparency=1-rainbow
  local turn=if reduced then 0 else(self.clock*216)%360
  self.edgeGradient.Rotation=turn;b.rimRainbow.Rotation=turn
  b.rimStroke.Color=Color3.new(1,1,1);b.rimStroke.Thickness=math.max(3,math.floor(5*L.s))
 else b.rimStroke.Color=Rarity.Look[self.tier].color;b.rimStroke.Thickness=3 end
 -- The shockwave line from the egg, and the one bloom inside the well.
 local shock=j.shock
 self.shock.Visible=shock~=nil
 if shock then
  local d=shock.radius*2*L.s
  self.shock.Position=UDim2.fromOffset(L.petX+dx,L.feet-L.petH*.45+dy);self.shock.Size=UDim2.fromOffset(d,d)
  self.shockStroke.Thickness=math.max(1,math.floor(shock.width*L.s+.5));self.shockStroke.Transparency=1-shock.alpha
 end
 local bloom=150*L.s*j.bloomR*2
 b.bloom.Size=UDim2.fromOffset(math.max(1,bloom),math.max(1,bloom));b.bloom.ImageTransparency=1-j.bloom
 -- "RARE!" drops onto the well over the pet's head, then leaves before the headline.
 local stamp=s.stamp or 0
 self.stamp.Visible=stamp>0 and not self.instant
 if self.stamp.Visible then
  self.stamp.Position=UDim2.fromOffset(math.round(L.petX+dx),math.round((self.stampY or L.feet-L.petH)+dy))
  local scale=if reduced then 1 else s.stampScale or 1
  self.stampScale.Scale=if math.abs(scale-1)<1e-3 then 1 else scale
  self.stamp.TextTransparency=1-stamp;self.stampStroke.Transparency=1-stamp
 end
end
-- QA R4: leave instead of vanishing (see HatchItemStage:dismiss). The stage moves to its own
-- top-level gui, stops taking input, its content sinks into the dark and the dark lifts off
-- the garden or menu underneath. False when it was not on screen: the caller destroys it.
function Stage:dismiss(after)
 if self.destroyed or self.leaving then return false end
 if not self.seenAt or os.clock()-self.seenAt>.1 then return false end
 local gui=C.detach(self.root);if not gui then return false end
 -- "Play again" may already have faded the cover in: the leave never brightens it again.
 self.leaving={at=os.clock(),gui=gui,after=after,pet=self.petHolder.Size,cover=if self.cover.Visible then self.cover.BackgroundTransparency else 1}
 if self.connection then self.connection:Disconnect();self.connection=nil end
 for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
 if self:ownsSelection()then GuiService.SelectedObject=nil end
 if self.ring then self.ring.hide()end
 -- The borrowed egg scene goes back now: its cinematic is being cancelled with this call.
 if self.lead then
  local lead=self.lead;self.lead=nil
  if lead.seat then lead.seat.Visible=false end
  if lead.scene and not lead.scene.destroyed then lead.scene:release(lead.token)end
 end
 self.root.Active=false;self.root.Interactable=false;self.pad.Visible=false
 self.root:SetAttribute("Leaving",true)
 self.cover.Visible=true;self.cover.BackgroundTransparency=self.leaving.cover
 self.connection=RunService.RenderStepped:Connect(function()self:paintLeave()end)
 self:paintLeave()
 return true
end
function Stage:paintLeave(elapsed)
 local leave=self.leaving;if not leave or self.destroyed then return end
 local s=C.leaveSample(elapsed or os.clock()-leave.at)
 if s.done then
  local after=leave.after;self:destroy()
  if after then after()end
  return
 end
 if s.lift<=0 then
  self.cover.BackgroundTransparency=math.min(leave.cover,1-s.content)
  if not self:reduced()then self.petHolder.Size=UDim2.fromOffset(leave.pet.X.Offset*s.scale,leave.pet.Y.Offset*s.scale)end
  return
 end
 if not leave.cleared then
  leave.cleared=true
  for _,child in ipairs(self.root:GetChildren())do if child:IsA("GuiObject")and child~=self.cover then child.Visible=false end end
  self.root.BackgroundTransparency=1
 end
 self.cover.BackgroundTransparency=s.lift
end
-- Confetti popper (QA v2 R1.1).
-- Round 3: a Rare pet fires the two cannons instead (left, then right 0.12 s later), silently.
function Stage:pop()
 if self.popAt or self.destroyed or self.instant or self.reducedStart or self:reduced()then return false end
 self.popAt=self.clock
 if not self.jackpot then self:cue(Stage.PopCue,1.18,.45)end
 return true
end
function Stage:confettiAlive()
 local life=if self.jackpot then ItemStage.Cannon.life+Stage.Rare.cannonGap else Stage.ConfettiLife
 return self.popAt~=nil and self.clock-self.popAt<=life
end
function Stage:paintCannons()
 local pieces,L=self.cannonPieces,self.L
 if not self:confettiAlive()or self:reduced()then
  if self.confettiShown then self.confettiShown=false;for _,piece in ipairs(pieces)do piece.Visible=false end end
  return
 end
 self.confettiShown=true
 local t=self.clock-self.popAt;local per=ItemStage.Cannon.count
 for index,piece in ipairs(pieces)do
  local side=if index<=per then -1 else 1
  local x,y,rotation,fade=ItemStage.cannon(index,side,t-(if side<0 then 0 else Stage.Rare.cannonGap),L.W,L.H,L.s)
  piece.Visible=x~=nil
  if x then
   local size=math.floor((12+8*hash(index,58))*L.s+.5)
   piece.Position=UDim2.fromOffset(math.floor(x+.5),math.floor(y+.5));piece.Size=UDim2.fromOffset(size,size)
   piece.Rotation=rotation;piece.ImageTransparency=1-fade
  end
 end
end
function Stage:paintConfetti()
 if self.jackpot then self:paintCannons();return end
 local pieces=self.confettiPieces;if not pieces then return end
 local L=self.L
 local alive=self:confettiAlive()and not self:reduced()
 if not alive then
  if self.confettiShown then self.confettiShown=false;for _,piece in ipairs(pieces)do piece.Visible=false end end
  return
 end
 self.confettiShown=true
 local t=self.clock-self.popAt
 local long=math.max(6,math.floor(14*math.max(L.s,.5)+.5));local short=math.max(3,math.floor(long*.45+.5))
 for index,piece in ipairs(pieces)do
  local x,y,rotation,share,fade=Stage.confetti(index,t,L.W,L.H)
  piece.Visible=x~=nil
  if x then
   piece.Position=UDim2.fromOffset(math.floor(x+.5),math.floor(y+.5))
   piece.Size=UDim2.fromOffset(math.max(1,math.floor(long*(.25+.75*share)+.5)),short)
   piece.Rotation=rotation;piece.BackgroundTransparency=fade
  end
 end
end

-- Clock: entrance timeline, then idle (spin physics, self-turn, twinkles).
function Stage:step(dt)
 if self.destroyed or self.leaving then return end
 if C.onScreen(self.root)then self.seenAt=os.clock()end
 if not self:owned()then
  -- The hatch has not started yet (its window is unfocused, so the hatch clock is waiting):
  -- hold on the egg. The lead-in and the entrance play together when the owner returns.
  if self.lead and not self.lead.done and self.lead.age<=0 then
   self.clock+=math.clamp(dt,0,.1);self:paint();return
  end
  if not self:isSettled()then self:settle(true)end
  -- An unfocused window still fades the loaded pet in on the settled frame (no motion).
  self.clock+=math.clamp(dt,0,.1);if not self.staticDone then self:paint()end
  return
 end
 dt=math.clamp(dt,0,.1);self.clock+=dt
 if not self:reduced()then
  self.checkerOffset=(self.checkerOffset+8*dt)%Kit.Checker.tile
  self.rayTurn=(self.rayTurn+(Rarity.Stage[self.tier]or Rarity.Stage.Common).spin*dt)%360
  if self.jackpot then self.shaftTurn=(self.shaftTurn+12*dt)%360 end
 end
 -- The entrance waits at 0 while the egg lead-in plays (the hatch clock ends it).
 if self.lead and not self.lead.done then self:paint();return end
 local before=self.age;self.age+=dt
 if not self.reducedStart and not self.instant then
  for _,beat in ipairs(if self.jackpot then Stage.RareCues else Stage.Cues)do
   if before<beat[1]and self.age>=beat[1]then
    local pitch=beat[3]or(if beat[2]=="reveal_shimmer"and self.kind=="rare"then 2^(3/12)else 1)
    self:cue(beat[2],pitch,beat[4]or .55)
    if beat[2]=="name_slam"and self.kind=="rare"then task.delay(.09,function()if not self.destroyed then self:cue("name_slam",1.06,.45)end end)end
   end
  end
  local popAt=if self.jackpot then Stage.Rare.cannon else Stage.PopAt
  local greetAt=if self.jackpot then Stage.Rare.greet else .56
  if before<popAt and self.age>=popAt then self:pop()end
  if before<greetAt and self.age>=greetAt then
   self.waveAt=self.clock
   if self.visual then pcall(function()self.visual:greet()end)end
   if self.options.voice~=false or self.lead then self:cue(self.pet.cue or "pet",1,.4)end
  end
 end
 if self:isSettled()then self:stepIdle(dt)end
 self.sampleAge+=dt
 if self.visual and self.sampleAge>=1/30 then
  local elapsed=self.sampleAge;self.sampleAge=0
  -- The wave (QA R5): the visual's reveal pose, sampled on the stage clock.
  if not self.waveAt and self:isSettled()then self.waveAt=self.clock end
  pcall(function()
   local reduced=self:reduced()
   self.visual.reducedEffects=reduced
   local pose=Stage.wavePose(if self.waveAt then self.clock-self.waveAt else -1,self.clock,reduced)
   -- Round 3: a Rare pet's ears flick on each landing.
   if self.jackpot and not reduced and not self.reducedStart then pose.ear+=Stage.earFlick(self.age)end
   self.visual:setRevealPose(pose)
   self.visual:update(elapsed)
  end)
 end
 self:paint()
end
function Stage:isSettled()
 if self.reducedStart then return self.age>=Stage.ReducedFade end
 return self.age>=Stage.Duration
end
function Stage:stepIdle(dt)
 local now=self.clock;local reduced=self:reduced()
 if self.drag then return end
 if math.abs(self.stick or 0)>0 then
  self.yaw+=self.stick*Stage.Spin.stick*dt;self.lastTouch=now;self.homed=false;return
 end
 if self.omega~=0 then
  if reduced then self.omega=0 else
   self.yaw+=self.omega*dt;self.omega=Stage.decay(self.omega,dt)
  end
  if self.omega==0 then self.lastTouch=now end
  return
 end
 if now-self.lastTouch<Stage.Spin.settleDelay then return end
 if not self.homed then
  local target
  self.yaw,self.velocity,target=Stage.springStep(self.yaw,self.velocity,dt)
  if math.abs(self.yaw-target)<.5 and math.abs(self.velocity)<2 then self.yaw,self.velocity,self.homed=target,0,true end
  return
 end
 if not reduced then self.yaw+=Stage.Spin.idle*dt end
end

-- A press before the input opens jumps to the settled frame; it never acts.
function Stage:settle(quiet,pop)
 if self.destroyed then return end
 local was=self:isSettled()
 -- Round 3: a host may hold a press-to-skip (options.canSkip; the Bunny's once-ever hatch plays
 -- in full, as the first Bear's does). Clock jumps and a lost owner (quiet) always settle.
 if not quiet and not was and type(self.options.canSkip)=="function"and self.options.canSkip()~=true then return end
 if self.lead then self:endLead()end
 self.age=math.max(self.age,if self.reducedStart then Stage.ReducedFade else Stage.Duration)
 if not was and self.visual then pcall(function()self.visual:greet()end)end
 if not was then self.waveAt=self.clock end
 -- A skip past the colour burst still gets its popper (only an owned, first view).
 if not was and(not quiet or pop)then self:pop()end
 self:paint()
 if not quiet and self.options.onSkip then self.options.onSkip()end
end

function Stage:bindInput()
 local pad=self.pad
 local function touchOrMouse(input)return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch end
 table.insert(self.connections,pad.InputBegan:Connect(function(input)
  if not touchOrMouse(input)or not self:owned()then return end
  if not self:isSettled()then self:settle();return end
  self.drag={input=input,x=input.Position.X,start=input.Position,moved=0,samples={{t=self.clock,yaw=self.yaw}}}
  self.omega,self.velocity,self.homed=0,0,false;self.lastTouch=self.clock
 end))
 table.insert(self.connections,Input.InputChanged:Connect(function(input)
  if input.KeyCode==Enum.KeyCode.Thumbstick2 then
   local x=input.Position.X;self.stick=if math.abs(x)>.15 then x else 0;return
  end
  local drag=self.drag;if not drag then return end
  local follows=(drag.input.UserInputType==Enum.UserInputType.Touch and input==drag.input)
   or(drag.input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)
  if not follows then return end
  local dx=input.Position.X-drag.x;drag.x=input.Position.X;drag.moved+=math.abs(dx)
  local rate=if self.L and self.L.phone then Stage.Spin.phoneDegPerPixel else Stage.Spin.degPerPixel
  self.yaw+=dx*rate;self.lastTouch=self.clock
  table.insert(drag.samples,{t=self.clock,yaw=self.yaw});if #drag.samples>24 then table.remove(drag.samples,1)end
 end))
 table.insert(self.connections,Input.InputEnded:Connect(function(input)
  local drag=self.drag;if not drag then return end
  if input~=drag.input and not(drag.input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)then return end
  self.drag=nil;self.lastTouch=self.clock
  if drag.moved<6 then
   if self:overPet(drag.start)then self:boop()end
   return
  end
  table.insert(drag.samples,{t=self.clock,yaw=self.yaw})
  self.omega=if self:reduced()then 0 else Stage.releaseSpeed(drag.samples,self.clock)
  self:spunOnce();self:whoosh(self.omega)
 end))
 table.insert(self.connections,Input.InputBegan:Connect(function(input,processed)
  if not self:owned()then return end
  local key=input.KeyCode
  if key==Enum.KeyCode.ButtonL1 or key==Enum.KeyCode.ButtonR1 or(not processed and(key==Enum.KeyCode.Q or key==Enum.KeyCode.E))then
   if not self:isSettled()then self:settle();return end
   local direction=if key==Enum.KeyCode.ButtonL1 or key==Enum.KeyCode.Q then -1 else 1
   self.omega=if self:reduced()then 0 else Stage.flickSpeed(direction);self.homed=false;self.lastTouch=self.clock
   if self:reduced()then self.yaw+=direction*Stage.Spin.flick end
   self:spunOnce();return
  end
  if key==Enum.KeyCode.Space then
   if not self:isSettled()then self:settle()end
   return
  end
  if key==Enum.KeyCode.Return or key==Enum.KeyCode.KeypadEnter or key==Enum.KeyCode.ButtonA then
   -- The press that skipped the egg lead-in never also presses Meet.
   if self.options.consumeSkipInput and self.options.consumeSkipInput()then return end
   if not self:isSettled()then self:settle();return end
   -- A selected stage button already receives the native gamepad press.
   if key==Enum.KeyCode.ButtonA and self:ownsSelection()then return end
   if processed and key~=Enum.KeyCode.ButtonA then return end
   self:confirm();return
  end
  if processed then return end
  if key==Enum.KeyCode.Left or key==Enum.KeyCode.DPadLeft then self:move(-1)
  elseif key==Enum.KeyCode.Right or key==Enum.KeyCode.DPadRight then self:move(1)end
 end))
 table.insert(self.connections,GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
  local selected=GuiService.SelectedObject
  for index,entry in ipairs(self.buttons)do if entry.node==selected then self.focus=index;self:paintFocus()end end
 end))
end
function Stage:overPet(position)
 local holder=self.petHolder;if not position then return false end
 local p,s=holder.AbsolutePosition,holder.AbsoluteSize
 return position.X>=p.X and position.X<=p.X+s.X and position.Y>=p.Y and position.Y<=p.Y+s.Y
end
function Stage:boop()
 self.boopAt=self.clock;self:cue("bear_boop",1,.5)
end
function Stage:spunOnce()self.spun=true;self.hint.Visible=false end
function Stage:whoosh(omega)
 if math.abs(omega)<Stage.Spin.whooshAt or self.clock-self.lastWhoosh<Stage.Spin.whooshGap then return end
 self.lastWhoosh=self.clock
 self:cue("spin_whoosh",1+(math.abs(omega)-Stage.Spin.whooshAt)/1440,.4)
end

-- Focus: Meet starts focused; D-pad or arrows move; A / Enter acts.
function Stage:ownsSelection()
 local selected=GuiService.SelectedObject
 for _,entry in ipairs(self.buttons)do if entry.node==selected then return true end end
 return false
end
function Stage:primaryButton()
 for _,entry in ipairs(self.buttons)do if entry.primary then return entry.node end end
 return self.buttons[#self.buttons]and self.buttons[#self.buttons].node
end
function Stage:paintFocus()
 local entry=self.buttons[self.focus]
 if not entry or not self.inputOpened or Kit.lastInputTouch()then self.ring.hide();return end
 self.ring.attach(entry.node,12)
end
function Stage:move(direction)
 if not self:isSettled()or #self.buttons==0 then return false end
 local target=math.clamp(self.focus+direction,1,#self.buttons)
 if target~=self.focus then self.focus=target;self:paintFocus();self:cue("aim",1.1,.35)end
 if self:ownsSelection()then GuiService.SelectedObject=self.buttons[self.focus].node end
 return true
end
function Stage:activate(index,fromPointer)
 local entry=self.buttons[index];if not entry or self.leaving then return false end
 -- The press that skipped the egg lead-in never also presses a button.
 if self.options.consumeSkipInput and self.options.consumeSkipInput()then return false end
 if not self:isSettled()then self:settle();return false end
 if not entry.enabled then return false end
 if not fromPointer then Kit.pulse(entry.node)end
 if self.options.onButton then self.options.onButton(entry.id)end
 return true
end
function Stage:confirm()
 if not self:isSettled()then self:settle();return true end
 return self:activate(self.focus)
end
-- B / Esc: the secondary button ("Play again").
function Stage:back()
 if not self:isSettled()then self:settle();return true end
 for index,entry in ipairs(self.buttons)do
  if not entry.primary then self.focus=index;self:paintFocus();return self:activate(index)end
 end
 return false
end
-- {id={text=,enabled=}} from the host's footer state.
function Stage:setButtons(states)
 for _,entry in ipairs(self.buttons)do
  local state=states[entry.id]
  if state then
   if state.text then Kit.setText(entry.node,state.text)end
   if state.enabled~=nil then entry.enabled=state.enabled==true;Kit.setEnabled(entry.node,entry.enabled)end
  end
 end
end
-- Exit beats (1.5): Meet sends the plate and headline away and narrows the
-- beam; Play again fades. `restore` returns to the settled frame (a retry).
function Stage:exit(kind)
 if self.destroyed or self.exiting then return end
 self.exiting={kind=kind,at=self.clock};self.staticDone=false
 self:cue("reveal_out",1,.4)
 if kind=="meet"and self.visual then pcall(function()self.visual:greet()end)end
end
function Stage:restore()
 if self.exiting then self.exiting=nil;self.staticDone=false;self:paint()end
end

-- Read-only QA view of the stage.
function Stage:getStats()
 return{age=self.age,settled=self:isSettled(),yaw=self.yaw,omega=self.omega,renderMode=self.renderMode,loaded=self.loaded,
  kind=self.kind,accent=self.accent,focus=self.focus,phone=self.L and self.L.phone,popped=self.popAt~=nil,confetti=self:confettiAlive(),
  tier=self.tier,jackpot=self.jackpot,
  sharedScene=self.lead~=nil,externalClock=self.lead~=nil,leadDone=self.lead~=nil and self.lead.done,leadAge=self.lead and self.lead.age}
end

function Stage:destroy()
 if self.destroyed then return end
 self.destroyed=true
 if self.connection then self.connection:Disconnect();self.connection=nil end
 for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
 if self.audio and self.audio.stopOwner then self.audio:stopOwner(self)end
 local audio=self.options.audio;if audio and type(audio.stopOwner)=="function"then audio:stopOwner(self)end
 if self:ownsSelection()then GuiService.SelectedObject=nil end
 if self.visual then pcall(function()self.visual:destroy()end);self.visual=nil end
 if self.lead then local lead=self.lead;self.lead=nil;if lead.scene and not lead.scene.destroyed then lead.scene:release(lead.token)end end
 if self.ring then self.ring.hide()end
 self.root:Destroy()
 if self.leaving and self.leaving.gui then self.leaving.gui:Destroy()end
 if self.selectionNone then self.selectionNone:Destroy()end
end

return Stage
