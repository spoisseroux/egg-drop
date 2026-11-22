-- Full-screen item reveal: the v2 "Pop-Out Stage" (V2-HATCH-REDESIGN-2026-11-19 and its
-- Revision 1). Toy, Customization (jar, finish, charm), Material, Feature and Stat eggs.
--
-- The screen is the toy's shell (the deck's colour, ink outline, the diagonal checker). The
-- egg sits in one big stage well, tinted by the tier (Sunny Peach, Lime Soda, Berry Blast:
-- HatchRarityCue.Stage), never by the deck. Rarity is light: the rim, the rays, the stones
-- and the sparkles. At the burst the confetti leaves the well and lands on the shell. A Rare
-- is a jackpot (R1.1): wind-up orbit, light shafts, a freeze, the well punching open, a
-- shockwave line, a travelling rainbow edge, two confetti cannons and a "RARE!" stamp.
-- There is no full-screen flash at all: one bloom, inside the well, per hatch (section 4).
-- The way in is the toy lid closing and an iris opening (R1.4); the way out is the iris
-- closing on the item and the lid opening onto wherever the player came from.
--
--   HatchItemStage.show(parent,{scene,kind,tier,...}) -> stage
-- It borrows the hatch's one native scene (HatchDisplayScene) and follows the hatch's one
-- clock through stage:updateExternal(age, sample); it owns no reward, receipt or asset.
-- While its lid is closing (or the scene is still loading) it holds that clock (holdsClock).
--
-- options:
--   scene       HatchDisplayScene, or any table with borrow/release/layout (required)
--   kind        "toy"|"hue"|"material"|"feature"|"stat"; tier "Common"|"Uncommon"|"Rare"|"Neutral"
--   name()      the item's name, read once the receipt is ready (never before)
--   detail()    the host's supporting line; description() one fun line (default Stage.describe)
--   effect()    an effect line under the name (a Stat Snack's boost), optional
--   sticker()   the kind word on the sticker (default from hatch.reveal.kind.*)
--   quietText   (medals) no sticker, a larger effect line, and the words centred on the well
--   actions()   {{source=GuiButton, primary=bool, act=function}}: the host's receipt buttons,
--               mirrored (text / enabled / visible) and called only once the receipt is ready
--   odds()      {rows={{id,name,value,info?}}, restricted?, empty?} for the "In this egg" tray,
--               on the state after this hatch (the egg card's own rows); wonId the cell to light
--   pity()      {line, sub}: the pity line and the stock line beside Hatch another
--   again()     {text, enabled, reason, pending, act}: Hatch another (nil hides the key)
--   stoneColors() the confetti stones' colours after the burst (a stat's colour)
--   ready()     false while the scene is still loading (the lid stays shut, the egg bobs)
--   lid         false: no lid (Hatch another, a reopen); skippable() may the hatch be skipped
--   onSkip(), onClose(), owns(), reduced(), instant, consumeSkipInput(), cover, zIndex
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Input=game:GetService("UserInputService")
local Kit=require(script.Parent.DeckKit)
local C=require(script.Parent.CelebrationKit)
local Rarity=require(script.Parent.HatchRarityCue)
local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Look=require(game:GetService("ReplicatedStorage").Shared.LookEggCatalog)
local Stage={};Stage.__index=Stage

-- Art: two atlases built by scripts/build_hatch_v2_art.py (white, tinted in game).
Stage.Art=table.freeze({burst="rbxassetid://80540254791233",bits="rbxassetid://103382562170036",
 sunburst={"burst",0,0,512,512},shafts={"burst",512,0,512,512},dots={"burst",0,512,512,512},stripes={"burst",512,512,512,512},
 diamonds={"bits",0,0,512,512},glow={"bits",512,0,256,256},sparkle={"bits",768,0,128,128},pebble={"bits",768,128,64,64},
 statEgg={"bits",512,256,256,320},egg={"bits",768,256,256,320}})

function Stage.resultKind(kind,result)
 if kind=="hue"and type(result)=="table"then
  local k=Look.kind(result.itemId)
  if k=="finish"or k=="charm"then return k end
 end
 return kind
end

-- ── Pure rules (specs cover these) ───────────────────────────────────────────
Stage.BurstAt=Rarity.BurstAt;Stage.SettleAfter=.50;Stage.AgainLock=.40;Stage.ReducedFade=.15
Stage.SpinSpeed=math.rad(42);Stage.SpinEase=.8
Stage.Shadow=Color3.fromHex("#5A3424");Stage.ShadowAlpha=.5
Stage.Ink=Color3.fromHex("#15143A");Stage.Lemon=Color3.fromHex("#FFE14D");Stage.Cream=Color3.fromHex("#FFF4DC")
Stage.Rainbow=table.freeze({"#FF5A7A","#FFB13B","#FFE14D","#5CE27A","#4FC3FF","#8E7CFF","#FF5A7A"})
Stage.Pool=table.freeze({burst=30,cannon=52,orbit=12}) -- 94 moving pieces at most, all made at open
Stage.Cannon=table.freeze({count=26,speedMin=620,speedMax=1180,angleMin=40,angleMax=80,gravity=520,life=2.4})
function Stage.spinAt(t)
 if t<=0 then return 0 end
 local e=Stage.SpinEase
 return Stage.SpinSpeed*(if t<e then t*t/(2*e)else t-e*.5)
end
local function ramp(t,start,duration)return math.clamp((t-start)/duration,0,1)end
local function smooth(a,b,t)local u=math.clamp((t-a)/(b-a),0,1);return u*u*(3-2*u)end
local function pulse(t,a,b)return if t>a and t<b then math.sin(math.pi*(t-a)/(b-a))else 0 end
-- Motion spec curves (R1.3). Back s: 1 + u*u*((s+1)*u + s), u = x - 1.
local function back(x,s)if x<=0 then return 0 end;if x>=1 then return 1 end;local u=x-1;return 1+u*u*((s+1)*u+s)end
local function expoOut(x)return if x>=1 then 1 elseif x<=0 then 0 else 1-2^(-10*x)end
local function expoIn(x)return if x<=0 then 0 elseif x>=1 then 1 else 2^(10*x-10)end
local function quadIn(x)return x*x end
local function spring(t,length,n,d)
 if t<0 then return 1 end
 local x=t/length;if x>=1 then return 0 end
 return math.exp(-d*x)*math.cos(2*math.pi*n*x)*(1-x)
end
Stage.ease=table.freeze({back=back,expoOut=expoOut,expoIn=expoIn,spring=spring})
local function hash(i,salt)local x=math.sin(i*12.9898+salt*78.233)*43758.5453;return x-math.floor(x)end
Stage.hash=hash

-- Pure: every lane at hatch clock `t`. One clock (R1.3): poses are a function of time only.
function Stage.sample(t,reduced,tier)
 tier=if Rarity.Look[tier or ""]then tier else "Neutral"
 local T=Rarity.timing(tier,"item",reduced==true);local J=Rarity.Jackpot
 t=math.max(0,t or 0)
 local R=T.ready
 local s={t=t,reduced=reduced==true,tier=tier,jackpot=T.jackpot,burstAt=T.burst,readyAt=R,fade=1,
  named=t>=R,input=t>=R,settled=t>=R+(if reduced then 0 else Stage.SettleAfter)}
 s.againLive=t>=R+(if reduced then 0 else Stage.SettleAfter)+Stage.AgainLock
 if reduced then
  -- 4 / R1.1: no camera, bloom, shake, flying confetti; still stones round the well; the
  -- stamp fades in at full size; text and keys fade, nothing slides or bounces.
  s.fade=ramp(t,0,Stage.ReducedFade);s.burstAge=math.huge;s.slide=1;s.cam=1;s.tip=0;s.bloom=0;s.bloomR=0;s.shake=0;s.punch=0
  s.shock=nil;s.rainbow=if T.jackpot then .6 else 0;s.shafts=if T.jackpot then .25*.6 else 0
  s.orbit=0;s.stillStones=true
  s.stamp=if T.jackpot and t>=J.reducedStamp then ramp(t,J.reducedStamp,.15)*(1-ramp(t,R,.15))else 0;s.stampScale=1;s.stampTravel=0
  s.sticker=ramp(t,R-.15,.15);s.name=s.sticker;s.lines=s.sticker;s.tray=1;s.trayAlpha=s.sticker;s.buttons=1;s.buttonsAlpha=s.sticker
  s.pity=if s.named then 1 else 0;s.pre=1-s.sticker
  return s
 end
 local B=T.burst;local look=Rarity.Stage[tier]
 s.burstAge=t-B
 -- Camera (2.3): a 4% push in over the shakes, a tip per rock, a pull back at the burst.
 local push=.04*smooth(0,.95,math.min(t,B))*(1-quadIn(ramp(t,B,.3)))
 local pull=look.pull*pulse(t,B,B+.6)*(if T.jackpot then 1+.2*math.sin(math.pi*ramp(t,B,.6))else 1)
 s.cam=1+push-pull
 s.tip=look.tip*(-pulse(t,.12,.31)+pulse(t,.34,.62)+pulse(t,.69,.94))
 -- The well slides to its seat; the card rises from the right.
 s.slide=expoOut(ramp(t,if T.jackpot then J.seat else B+.28,.34))
 -- One bloom inside the well: radius 0 to 150 px (Expo Out, 0.16 s), opacity peak to 0 ((1-x)^2, 0.40 s).
 s.bloomR=if t>=B then expoOut(ramp(t,B,.16))else 0
 s.bloom=if t>=B then look.bloom*ramp(t,B,.05)*(1-ramp(t,B,.40))^2 else 0
 s.shake=0;s.punch=0;s.shock=nil;s.rainbow=0;s.shafts=0;s.orbit=0;s.stamp=0;s.stampScale=1;s.stampTravel=0
 if T.jackpot then
  s.shafts=.25*smooth(J.windup,J.freeze,t)
  s.orbit=if t>=J.windup and t<B then ramp(t,J.windup,.15)else 0
  s.orbitRadius=132-40*smooth(J.windup,J.freeze,t)
  s.shake=if t>=B and t<B+.2 then 3*(1-ramp(t,B,.2))else 0
  -- The well punches open (Back 2.4, 0.22 s), then settles.
  s.punch=back(ramp(t,B,.22),2.4)*(1-smooth(B+.22,B+.62,t))
  if t>=B and t<B+.5 then local u=ramp(t,B,.5);s.shock={radius=40+560*expoOut(u),width=10-8*u,alpha=1-u*u}end
  s.rainbow=ramp(t,B,.25)
  if t>=J.stamp then
   local fall=ramp(t,J.stamp,.12)
   s.stamp=1;s.stampScale=2.6-1.6*expoIn(fall)
   if t>=J.stamp+.12 and t<J.stamp+.30 then s.shake=4*(1-ramp(t,J.stamp+.12,.18))end
   s.stampTravel=expoOut(ramp(t,J.seat,.34))
   s.stamp=1-ramp(t,J.seatEnd-.04,.06)
  end
 end
 s.sticker=back(ramp(t,R,.18),2.0);s.name=back(ramp(t,R,.20),2.2)
 s.lines=ramp(t,R+.10,.18)
 s.tray=expoOut(ramp(t,R+.05,.30));s.trayAlpha=ramp(t,R+.05,.12)
 s.buttons=expoOut(ramp(t,R,.30));s.buttonsAlpha=ramp(t,R,.10)
 s.pity=ramp(t,R+.05,.40)
 s.pre=1-ramp(t,B-.05,.15)
 return s
end
-- Pure speeds (integrated by the stage, so a change of speed never jumps).
-- The checker in px/s: 8 at rest; Uncommon 16 for 0.5 s after its burst; Rare 8 to 48 through
-- the wind-up, one tenth in the freeze, easing back to 8 by 3.0 s.
function Stage.checkerSpeed(t,tier,reduced)
 if reduced then return 0 end
 local T=Rarity.timing(tier,"item",false);local J=Rarity.Jackpot
 if T.jackpot then
  if t<J.windup then return 8 end
  if t<J.freeze then return 8+40*smooth(J.windup,J.freeze,t)end
  if t<T.burst then return 4.8 end
  return 48-40*smooth(T.burst+.3,3.0,t)
 end
 if tier=="Uncommon"and t>=T.burst and t<T.burst+.5 then return 16 end
 return 8
end
-- Ray turn (deg/s): the tier's spin; Rare also fans its shafts 12 to 40 deg/s in the wind-up.
function Stage.raySpeed(t,tier,reduced)
 if reduced then return 0 end
 local look=Rarity.Stage[tier]or Rarity.Stage.Neutral;local J=Rarity.Jackpot
 if tier=="Rare"and t>=J.freeze and t<J.burst then return look.spin*.1 end
 return look.spin
end
function Stage.shaftSpeed(t)
 local J=Rarity.Jackpot
 if t<J.windup then return 12 end
 if t<J.freeze then return 12+28*smooth(J.windup,J.freeze,t)end
 if t<J.burst then return 4 end
 return 12
end
-- Orbit turns per second in the wind-up (0.75 to 2.5), one tenth in the freeze.
function Stage.orbitSpeed(t)
 local J=Rarity.Jackpot
 if t<J.windup then return 0 end
 if t<J.freeze then return .75+1.75*smooth(J.windup,J.freeze,t)end
 return .25
end
-- Pure: burst confetti piece `i` of `n` at `age` s after the burst, in stage px around the
-- well centre. `escape`: the share that leaves the well; `half`: the well's half size.
-- Returns x, y, rotation, alpha or nil when gone.
function Stage.confetti(i,n,age,escape,half,scale)
 if age<0 then return nil end
 local out=hash(i,51)<escape
 local life=if out then 1.7 else 1.05
 if age>life then return nil end
 local angle=(i/n)*math.pi*2+hash(i,52)*.8
 local speed=(if out then 520+520*hash(i,53)else 180+160*hash(i,53))*scale
 local drag=if out then 1.6 else 3.2
 local travel=(1-math.exp(-drag*age))/drag
 local x=math.cos(angle)*speed*travel
 local y=math.sin(angle)*speed*travel*.85+.5*(if out then 900 else 260)*scale*age*age*.5
 if not out then
  -- Common stays inside the well: the pieces settle on its floor.
  local lim=half*.84
  x=math.clamp(x,-lim,lim);y=math.clamp(y,-lim,lim)
 end
 local fade=if age>life-.3 then 1-(age-(life-.3))/.3 else 1
 return x,y,(if hash(i,54)<.5 then -1 else 1)*(160+420*hash(i,55))*age,fade
end
-- Pure: cannon piece `i` (side -1 left, 1 right) `age` s after it fired, from the bottom
-- corner of a W x H stage. 620 to 1,180 px/s, 40 to 80 degrees, gravity 520 px/s2.
function Stage.cannon(i,side,age,W,H,scale)
 local K=Stage.Cannon
 if age<0 or age>K.life then return nil end
 local a=math.rad(K.angleMin+(K.angleMax-K.angleMin)*hash(i,61+side))
 local v=(K.speedMin+(K.speedMax-K.speedMin)*hash(i,63+side))*scale
 local x0=if side<0 then 0 else W
 local x=x0-side*math.cos(a)*v*age
 local y=H-math.sin(a)*v*age+.5*K.gravity*scale*age*age
 if y>H+40 then return nil end
 local fade=if age>K.life-.4 then 1-(age-(K.life-.4))/.4 else 1
 return x,y,(hash(i,65+side)-.5)*900*age,fade
end
-- The toy lid (R1.4), on the stage's own real-time clock from the moment it opened.
Stage.Lid=table.freeze({close=.22,clack=.10,iris=.30,irisFrom=40,irisTo=480,eggFrom=108,eggTo=150})
function Stage.lidSample(u,ready,heldFor)
 local L=Stage.Lid
 local s={u=u}
 s.close=quadIn(ramp(u,0,L.close))                             -- halves 0 open .. 1 shut
 s.clack=if u>=L.close then 6*spring(u-L.close,L.clack,1,6)else 0 -- px overshoot
 s.egg=L.eggFrom+(L.eggTo-L.eggFrom)*s.close
 s.eggSquash=if u>=L.close then 1-.12*spring(u-L.close,.30,1.5,5)else 1
 local start=L.close+(heldFor or 0)
 s.waiting=u>=L.close and not ready
 s.bob=if s.waiting then 2*math.sin((u-L.close)*math.pi*2/1.2)else 0
 s.iris=if ready and u>=start then expoOut(ramp(u,start,L.iris))else 0
 s.irisR=L.irisFrom+(L.irisTo-L.irisFrom)*s.iris
 s.done=ready and u>=start+L.iris
 return s
end
-- The iris out (R1.4): closes 480 to 44 px on the item (Expo In, 0.24 s), holds 0.06 s, pops
-- shut, then the lid opens (Expo Out, 0.26 s). Reduced Motion: 150 ms to the flat deck
-- colour, 150 ms to the destination.
Stage.LeaveTime=.56;Stage.ReducedLeave=.30
function Stage.leaveSample(u,reduced)
 if reduced then
  local a=ramp(u,0,.15)
  return {u=u,cover=a,open=ramp(u,.15,.15),reduced=true,done=u>=Stage.ReducedLeave,iris=0,shut=u>=.15}
 end
 local close=expoIn(ramp(u,0,.24))
 return {u=u,irisR=480-436*close,iris=close,shut=u>=.30,open=expoOut(ramp(u,.30,.26)),done=u>=Stage.LeaveTime}
end
-- Sticker words: "RARE · CHARM", "COMMON · FINISH JAR", and "NEW TOY" for an untiered item.
function Stage.bannerText(tier,kind)
 local kindWord=Copy.get("hatch.reveal.kind."..(if Copy.has("hatch.reveal.kind."..tostring(kind))then kind else "item"))
 if tier=="Common"or tier=="Uncommon"or tier=="Rare"then return Copy.get("hatch.reveal.banner",{tier=Copy.get("hatch.reveal.tier."..tier),kind=kindWord})end
 return Copy.get("hatch.reveal.fresh",{kind=kindWord})
end
local idField={toy="toyId",material="finishId",hue="itemId",feature="featureId"}
function Stage.describe(kind,result)
 local lookKind=Stage.resultKind(kind,result)
 if lookKind=="finish"then return Copy.get("hatch.reveal.describe.finishJar."..result.itemId)end
 if lookKind=="charm"then return Copy.get("hatch.reveal.describe.charm."..Look.shape(result.itemId))end
 local id=type(result)=="table"and idField[kind]and result[idField[kind]]
 local key=if type(id)=="string"then "hatch.reveal.describe."..kind.."."..id else nil
 if key and Copy.has(key)then return Copy.get(key)end
 return Copy.get("hatch.reveal.describe.other."..(if idField[kind]then kind else "item"))
end
function Stage.inkOn(color)return if Kit.contrast(color,Stage.Ink)>=4.5 then Stage.Ink else Color3.new(1,1,1)end

-- QA v775 note 11: the corner close keeps a thumb-safe inset from the safe area and top bar.
Stage.CloseSize=44
Stage.CloseInset=table.freeze({phone=table.freeze({x=24,y=16}),regular=table.freeze({x=32,y=28})})
function Stage.closeRect(W,H,phone,safe,bar)
 safe=safe or {}
 local size=Stage.CloseSize
 local inset=if phone then Stage.CloseInset.phone else Stage.CloseInset.regular
 local x=W-math.max(0,safe.r or 0)-inset.x-size
 local y=math.max(0,safe.t or 0)+inset.y
 if bar and bar.height and bar.maxX and bar.height>y and bar.maxX<x+size then y=bar.height+8 end
 x=math.clamp(x,0,math.max(0,W-size));y=math.clamp(y,0,math.max(0,H-size))
 return math.floor(x),math.floor(y),size
end
-- Pure: how much of the top to keep clear: the top bar (with the notification row in it) plus
-- 6 px, or the safe-area top when that is larger.
-- Round 3 (Spencer: rounded corners on the inside, like an iPhone's screen): the Rare screen
-- edge is a ring whose inner edge is rounded and whose outer corners stay square. The frame
-- reaches `offset` px past every screen edge (the root clips it) with a corner of `corner` and an
-- inner stroke of `thickness`, so the band's inner edge sits Stage.EdgeThickness in from the
-- screen with an inner radius of `radius`, and the rounded outer cut stays off screen
-- (corner <= offset * sqrt2 / (sqrt2 - 1)). Pure.
Stage.EdgeThickness=14
Stage.EdgeRadius={phone=34,regular=24} -- Fable brief 8: parallel to an iPhone's glass on phones
function Stage.edgeRing(radius,band)
 band=band or Stage.EdgeThickness
 local offset=math.max(24,math.ceil((radius+band)/2.4142)+2)
 return{offset=offset,corner=radius+band+offset,thickness=band+offset}
end
function Stage.topClear(safe,bar)
 local t=math.max(0,(safe and safe.t)or 0)
 if bar and bar.height and bar.height>0 then t=math.max(t,bar.height+6)end
 return t
end
function Stage.safeArea(root)
 local safe={l=0,t=0,r=0,b=0}
 local holder=root:FindFirstAncestorOfClass("PlayerGui")
 local probe=holder and holder:FindFirstChild("EggDropInsetProbe")
 if not(probe and probe:IsA("GuiBase2d"))or root:GetAttribute("CoversScreen")~=true then return safe,nil end
 local rp,rs,pp,ps=root.AbsolutePosition,root.AbsoluteSize,probe.AbsolutePosition,probe.AbsoluteSize
 if ps.X<=0 or ps.Y<=0 then return safe,nil end
 safe.l=math.max(0,pp.X-rp.X);safe.t=math.max(0,pp.Y-rp.Y)
 safe.r=math.max(0,rp.X+rs.X-pp.X-ps.X);safe.b=math.max(0,rp.Y+rs.Y-pp.Y-ps.Y)
 local inset=GuiService.TopbarInset
 local bar=if inset.Height>0 and inset.Width>0 then {maxX=inset.Max.X,height=inset.Height}else nil
 return safe,bar
end

-- Layout (section 5). Landscape is drawn on the 844 x 390 phone design and scaled to fit
-- (PC: centred in a band, at most 1.35x); portrait stacks the well on top.
-- Rects are {x, y, w, h} in stage px. All whole pixels.
local function rect(x,y,w,h)return {x=math.floor(x+.5),y=math.floor(y+.5),w=math.floor(w+.5),h=math.floor(h+.5)}end
-- `top` (optional): rows kept clear at the top for Roblox's top bar and the notification row
-- (Spencer 2026-11-20: the hatch content sat under them). The layout uses the area below and
-- every rect moves down by `top`; the stage backdrop still fills the whole screen.
function Stage.geometry(W,H,top)
 top=math.max(0,math.floor(top or 0))
 if top>0 and H-top>=200 then
  local L=Stage.geometry(W,H-top)
  for _,r in pairs(L)do if type(r)=="table"and r.y and r.h then r.y+=top end end
  L.H=H;L.top=top
  return L
 end
 local L={W=W,H=H,landscape=W>=H*1.15,phone=Kit.compactRule(W,H)or W<760,top=0}
 if L.landscape then
  local s=math.min(W/844,H/390,1.35);L.s=s
  local ox=math.floor((W-844*s)*.5);local oy=math.floor((H-390*s)*.5)
  local function r(x,y,w,h)return rect(ox+x*s,oy+y*s,w*s,h*s)end
  L.wellCentre=r(232,20,380,346);L.wellSeat=r(24,20,380,292)
  L.again=r(24,322,182,48);L.pityTray=r(214,322,190,48)
  L.sticker=r(420,40,300,26);L.name=r(420,72,380,40);L.line1=r(420,114,380,20);L.line2=r(420,134,380,18)
  L.tray=r(420,156,400,156)
  L.secondary=r(420,322,196,48);L.primary=r(626,322,194,48)
  L.textX=L.name.x;L.textW=L.name.w
 else
  local s=math.min(W/390,H/844,1.35);L.s=s
  local ox=math.floor((W-390*s)*.5);local oy=math.floor((H-844*s)*.5)
  local function r(x,y,w,h)return rect(ox+x*s,oy+y*s,w*s,h*s)end
  L.wellCentre=r(16,120,358,340);L.wellSeat=r(16,60,358,300)
  L.sticker=r(16,374,300,26);L.name=r(16,404,358,40);L.line1=r(16,446,358,20);L.line2=r(16,466,358,18)
  L.tray=r(16,492,358,170)
  L.again=r(16,676,172,48);L.pityTray=r(196,676,178,48)
  L.secondary=r(16,760,174,48);L.primary=r(200,760,174,48)
  L.textX=L.name.x;L.textW=L.name.w
 end
 -- Keys keep a 44 px target on the smallest phones (568 x 320); they grow upward.
 for _,key in ipairs({"again","pityTray","secondary","primary"})do
  local r=L[key];if r.h<44 then r.y-=44-r.h;r.h=44 end
 end
 L.tray.h=math.max(40,math.min(L.tray.h,L.primary.y-6-L.tray.y))
 L.wellSeat.h=math.max(80,math.min(L.wellSeat.h,L.again.y-8-L.wellSeat.y))
 L.margin=24
 L.text={sticker=math.max(12,math.floor(12*L.s+.5)),name=math.max(18,math.floor(34*L.s+.5)),line=math.max(12,math.floor(14*L.s+.5)),
  small=math.max(12,math.floor(12*L.s+.5)),cell=math.max(12,math.floor(13*L.s+.5)),button=math.max(14,math.floor(16*L.s+.5)),stamp=math.max(40,math.floor(64*L.s+.5))}
 L.radius=math.max(12,math.floor(16*L.s))
 return L
end
-- Pure: the well's rect at slide `x` (0 centre .. 1 seat) with a punch of `p` (0..1, overshoots).
function Stage.wellRect(L,x,p)
 local a,b=L.wellCentre,L.wellSeat
 local function lerp(u,v)return u+(v-u)*x end
 local w,h=lerp(a.w,b.w),lerp(a.h,b.h)
 local cx,cy=lerp(a.x+a.w/2,b.x+b.w/2),lerp(a.y+a.h/2,b.y+b.h/2)
 w+=48*L.s*(p or 0);h+=12*L.s*(p or 0)
 return cx,cy,w,h
end
-- Pure: the odds tray's cells, `columns` across, from the egg card's rows. Info rows (pity,
-- rounding) become note lines; a long table keeps its first `max` cells and says how many more.
function Stage.trayCells(odds,wonId,max)
 local cells,notes={},{}
 if type(odds)~="table"then return cells,notes end
 if odds.empty then table.insert(notes,odds.empty)end
 for _,row in ipairs(odds.rows or {})do
  if row.info or row.value==""then table.insert(notes,row.label or row.name)
  else table.insert(cells,{id=row.id,name=row.name,value=row.value,won=wonId~=nil and row.id==wonId})end
 end
 max=max or 9
 if #cells>max then
  local more=#cells-(max-1)
  while #cells>max-1 do table.remove(cells)end
  table.insert(cells,{id="more",name=Copy.get("hatch.result.more",{count=more}),value="",won=false})
 end
 return cells,notes
end
-- "First hatch of each egg type plays in full" (2.2): session memory (the saved bits are
-- the next step; a rejoin plays the first one in full again).
Stage.seenTypes={}
function Stage.firstOfType(kind)return Stage.seenTypes[kind]~=true end

-- ── View ────────────────────────────────────────────────────────────────────
local node=Kit.node
local function frame(parent,name,z,props)
 local f=node("Frame",parent,{Name=name,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z,Active=false,Selectable=false})
 for k,v in pairs(props or {})do f[k]=v end
 return f
end
local function image(parent,name,piece,z,props)
 local a=Stage.Art[piece]
 local i=node("ImageLabel",parent,{Name=name,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z,Image=Stage.Art[a[1]],
  ImageRectOffset=Vector2.new(a[2],a[3]),ImageRectSize=Vector2.new(a[4],a[5]),AnchorPoint=Vector2.new(.5,.5),Active=false,Selectable=false})
 for k,v in pairs(props or {})do i[k]=v end
 return i
end
local function label(parent,name,z,size,color,props)
 local t=node("TextLabel",parent,{Name=name,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z,Text="",TextSize=size,TextColor3=color,
  FontFace=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.Bold),TextXAlignment=Enum.TextXAlignment.Left,
  TextYAlignment=Enum.TextYAlignment.Center,Active=false,Selectable=false})
 for k,v in pairs(props or {})do t[k]=v end
 return t
end
local function place(o,r)o.Position=UDim2.fromOffset(r.x,r.y);o.Size=UDim2.fromOffset(math.max(1,r.w),math.max(1,r.h))end
local function rainbowSequence()
 local keys={}
 for i,hex in ipairs(Stage.Rainbow)do table.insert(keys,ColorSequenceKeypoint.new((i-1)/(#Stage.Rainbow-1),Color3.fromHex(hex)))end
 return ColorSequence.new(keys)
end

-- The shell and the stage well as one piece (the pet reveal draws the same backdrop).
-- Returns {shell, checkerTile, shafts, well, clip, core, raysImage, pattern, floorLight,
-- floorShadow, bloom, seat, waitEgg, rim, rimStroke, rimRainbow, ...}.
function Stage.backdrop(root,z,tier,kind)
 tier=if Rarity.Look[tier or ""]then tier else "Neutral"
 local look,st=Rarity.Look[tier],Rarity.Stage[tier]
 local b={}
 b.shell=frame(root,"Shell",z+1,{Size=UDim2.fromScale(1,1),BackgroundTransparency=0})
 Kit.paint(b.shell,"BackgroundColor3","shell")
 local holder=frame(b.shell,"CheckerHolder",z+1,{Size=UDim2.fromScale(1,1),ClipsDescendants=true})
 local K=Kit.Checker
 b.checkerTile=node("ImageLabel",holder,{Name="Checker",BackgroundTransparency=1,Image=K.image,ImageTransparency=K.transparency,
  ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(K.tile,K.tile),Size=UDim2.new(1,K.tile,1,K.tile),Position=UDim2.fromOffset(-K.tile,-K.tile),ZIndex=z+1})
 local fade=frame(holder,"Fade",z+1,{Size=UDim2.fromScale(1,1),BackgroundTransparency=0})
 Kit.paint(fade,"BackgroundColor3","shell")
 node("UIGradient",fade,{Rotation=90,Transparency=NumberSequence.new(1,K.fadeTo)})
 -- Rare: twelve deck-colour light shafts fan out behind the well (one image).
 b.shafts=image(root,"LightShafts","shafts",z+2,{ImageTransparency=1})
 Kit.paint(b.shafts,"ImageColor3",function()return Kit.color("shell"):Lerp(Color3.new(1,1,1),.62)end)
 -- The stage well: edge colour, a core glow, light rays, the edge pattern, a vignette in
 -- the tier's deep colour, the floor light and a soft warm contact shadow, the bloom; ink outline, tier rim.
 b.well=frame(root,"StageWell",z+3,{BackgroundTransparency=0,BackgroundColor3=st.edge,AnchorPoint=Vector2.new(.5,.5)})
 b.wellCorner=node("UICorner",b.well,{CornerRadius=UDim.new(0,16)})
 b.wellStroke=node("UIStroke",b.well,{Color=Stage.Ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 b.clip=frame(b.well,"Clip",z+3,{ClipsDescendants=true})
 b.core=image(b.clip,"Core","glow",z+3,{ImageColor3=st.core,Position=UDim2.fromScale(.5,.46)})
 b.raysImage=image(b.clip,"Rays","sunburst",z+3,{ImageColor3=st.ray,ImageTransparency=.42,Position=UDim2.fromScale(.5,.5)})
 b.pattern=image(b.clip,"EdgePattern",st.pattern,z+3,{ImageColor3=Color3.new(1,1,1),ImageTransparency=.8,Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1)})
 for index,rotation in ipairs({0,90})do
  local v=frame(b.clip,"Vignette"..index,z+3,{Size=UDim2.fromScale(1,1),BackgroundTransparency=0,BackgroundColor3=st.deep})
  node("UIGradient",v,{Rotation=rotation,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.7),NumberSequenceKeypoint.new(.22,1),
   NumberSequenceKeypoint.new(.78,1),NumberSequenceKeypoint.new(1,.7)})})
 end
 b.floorLight=image(b.clip,"FloorLight","glow",z+3,{ImageColor3=st.floor,ImageTransparency=.25})
 -- Spencer 2026-11-20: the white floor ring read as a leftover; a soft warm drop shadow on the
 -- stage floor instead (the glow sprite, tinted a warm cocoa, never an outline).
 b.floorShadow=image(b.clip,"FloorShadow","glow",z+3,{ImageColor3=Stage.Shadow,ImageTransparency=Stage.ShadowAlpha})
 b.bloom=image(b.clip,"Bloom","glow",z+4,{ImageColor3=Color3.new(1,1,1),ImageTransparency=1})
 -- The scene seat (the 3D egg and result), and the 2D egg that waits while it loads.
 b.seat=frame(root,"NativeSceneSeat",z+4,{AnchorPoint=Vector2.new(.5,.5)})
 b.waitEgg=image(root,"WaitingEgg",if kind=="stat"then "statEgg"else "egg",z+4,{Visible=false})
 -- The rim keeps the tier colour; Rare's rainbow rides on it after the burst.
 b.rim=frame(root,"TierRim",z+5,{AnchorPoint=Vector2.new(.5,.5)})
 b.rimCorner=node("UICorner",b.rim,{CornerRadius=UDim.new(0,13)})
 b.rimStroke=node("UIStroke",b.rim,{Color=look.color,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 b.rimRainbow=node("UIGradient",b.rimStroke,{Color=rainbowSequence(),Enabled=false})
 return b
end
function Stage.show(parent,options)
 assert(options and options.scene,"HatchItemStage needs the hatch's native scene")
 local tier=if Rarity.Look[options.tier or ""]then options.tier else "Neutral"
 local self=setmetatable({options=options,scene=options.scene,tier=tier,look=Rarity.Look[tier],stageLook=Rarity.Stage[tier],
  kind=Stage.resultKind(options.kind or "item",options.result),age=0,lastAge=0,clock=0,openClock=0,connections={},buttons={},watched={},
  pieces={},cannons={},orbit={},checker=0,rays=0,shaftTurn=0,orbitTurn=0},Stage)
 local root=Kit.frame(parent,"ItemRevealStage",nil,UDim2.new(),UDim2.fromScale(1,1))
 root.ZIndex=options.zIndex or 80;root.BackgroundTransparency=1;root.Active=true;root.ClipsDescendants=true
 root:SetAttribute("RevealTier",tier);root:SetAttribute("RevealKind",self.kind);root:SetAttribute("PopOutStage",true)
 self.root=root
 if options.cover~=false then Kit.coverScreen(root)end
 -- Round 3: a host whose own ScreenGui already spans the whole screen (the Stat and Names Egg
 -- reveals: ScreenInsets None, IgnoreGuiInset) says fullScreen, so the safe area and the top
 -- bar (with the notification row) are kept clear like a covering stage's.
 if options.cover==false and options.fullScreen==true then root:SetAttribute("CoversScreen",true)end
 -- Hatch another hands over from the stage that is still up: no lid, the shell stays.
 local handover=Stage.handover;Stage.handover=nil
 self.instant=options.instant==true
 self.useLid=options.lid~=false and not self.instant and handover==nil
 self.handedFrom=handover
 self:build()
 self.reducedStart=self:reduced()
 if self.reducedStart then self.useLid=false end
 if self.instant then self.age=Rarity.timing(tier,"item",self.reducedStart).duration end
 self.skippable=not Stage.firstOfType(self.kind)or(options.skippable~=nil and options.skippable()==true)
 -- A reopen (instant) does not use up the type's one full play.
 if not self.instant then Stage.seenTypes[self.kind]=true end
 self.borrowToken=self.scene:borrow(self.seat)
 if self.scene.setBare then self.scene:setBare(true,false)end
 self:layout()
 table.insert(self.connections,root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:layout()end))
 table.insert(self.connections,GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()self:paintFocus()end))
 table.insert(self.connections,Input.InputBegan:Connect(function(input,processed)self:onKey(input,processed)end))
 self:refresh();self:paint()
 if handover then pcall(function()handover:destroy()end)end
 self.connection=RunService.RenderStepped:Connect(function(dt)self:step(dt)end)
 return self
end
function Stage:reduced()
 local r=self.options.reduced
 if type(r)=="function"then return r()==true end
 if r~=nil then return r==true end
 return Kit.reduced()
end
function Stage:owned()
 if self.destroyed or self.leaving or not self.root.Parent then return false end
 local n=self.root
 while n do
  if n:IsA("GuiObject")and not n.Visible then return false end
  if n:IsA("ScreenGui")and not n.Enabled then return false end
  n=n.Parent
 end
 return not self.options.owns or self.options.owns()==true
end
function Stage:sceneReady()
 if self.options.ready then return self.options.ready()~=false end
 return self.scene.ready~=false
end
-- The cinematic asks before it advances its clock (HatchCinematic.clockHold).
function Stage:holdsClock()
 if self.destroyed or self.leaving or self.instant then return false end
 if self.useLid then return not(self.lid and self.lid.done)end
 return false
end

function Stage:build()
 local root=self.root;local z=root.ZIndex;local look=self.look;local st=self.stageLook
 -- 1 shell + checker, 2 shafts, 3 well, 4 seat, 5 rim, 6 orbit, 7 confetti, 8 shockwave and
 -- rainbow, 9 text, tray, keys, 10 stamp, 11 skip, 12 controls, 14 lid and iris.
 local b=Stage.backdrop(root,z,self.tier,self.kind)
 for key,value in pairs(b)do self[key]=value end
 -- Orbit (Rare wind-up): eight blank stones and four sparkles in the tier colour.
 for index=1,Stage.Pool.orbit do
  local sparkle=index>8
  local o=image(root,"Orbit"..index,if sparkle then "sparkle"else "pebble",z+6,{Visible=false,ImageColor3=if sparkle then Color3.new(1,1,1)else look.color})
  self.orbit[index]=o
 end
 -- Confetti: stat-colour pebbles and four-point sparkles (never Stars gold, never a five-point star).
 for index=1,Stage.Pool.burst do
  local o=image(root,"Confetti"..index,"pebble",z+7,{Visible=false});self.pieces[index]=o
 end
 for index=1,Stage.Pool.cannon do
  local o=image(root,"Cannon"..index,if index%3==0 then "sparkle"else "pebble",z+7,{Visible=false});self.cannons[index]=o
 end
 -- Round 3 (Fable brief 1.3): the Stat Egg's stone roulette, six sparkles round the belt.
 self.roulette={}
 if self.options.roulette then
  for index=1,6 do self.roulette[index]=image(root,"Roulette"..index,"sparkle",z+6,{Visible=false})end
 end
 -- Shockwave: a 10 px line thinning to 2 px (not a filled flash), and the rainbow edge.
 self.shock=frame(root,"Shockwave",z+8,{AnchorPoint=Vector2.new(.5,.5),Visible=false})
 node("UICorner",self.shock,{CornerRadius=UDim.new(.5,0)})
 self.shockStroke=node("UIStroke",self.shock,{Color=Color3.new(1,1,1),Thickness=10})
 self.rainbow=frame(root,"RainbowEdge",z+8,{Size=UDim2.fromScale(1,1),Visible=false})
 self.rainbowStroke=Kit.inner(node("UIStroke",self.rainbow,{Thickness=Stage.EdgeThickness,Color=Color3.new(1,1,1),ApplyStrokeMode=Enum.ApplyStrokeMode.Border}))
 self.rainbowCorner=node("UICorner",self.rainbow,{CornerRadius=UDim.new(0,0)})
 self.rainbowGradient=node("UIGradient",self.rainbowStroke,{Color=rainbowSequence()})
 -- Text column: sticker, name, effect line, fun line; the "In this egg" tray.
 local tz=z+9
 self.sticker=frame(root,"Sticker",tz,{BackgroundTransparency=0,BackgroundColor3=look.color,AnchorPoint=Vector2.new(0,.5),Visible=false})
 node("UICorner",self.sticker,{CornerRadius=UDim.new(.5,0)})
 node("UIStroke",self.sticker,{Color=Stage.Ink,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 self.stickerScale=node("UIScale",self.sticker,{Scale=1})
 self.stickerText=label(self.sticker,"StickerText",tz+1,12,Stage.inkOn(look.color),{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,Text=Stage.bannerText(self.tier,self.kind)})
 self.stickerSheen=frame(self.sticker,"Sheen",tz+1,{BackgroundTransparency=.4,BackgroundColor3=Color3.new(1,1,1),Size=UDim2.new(0,10,1,0),Visible=false})
 self.nameGroup=frame(root,"NameGroup",tz,{Visible=false})
 self.nameScale=node("UIScale",self.nameGroup,{Scale=1})
 self.name=label(self.nameGroup,"ItemName",tz+1,30,Color3.new(1,1,1),{FontFace=Kit.DisplayFace,Size=UDim2.fromScale(1,1),TextScaled=false})
 self.nameStroke=node("UIStroke",self.name,{Color=Stage.Ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 self.lines=frame(root,"Lines",tz,{Visible=false})
 self.effect=label(self.lines,"Effect",tz+1,14,Color3.new(1,1,1),{TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd})
 self.describe=label(self.lines,"Description",tz+1,13,Color3.fromHex("#F2EEFF"),{TextWrapped=true,FontFace=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.Medium)})
 self.detail=self.describe -- (older callers read stage.detail)
 self.hostLine=label(self.lines,"Detail",tz+1,12,Color3.fromHex("#DCE5FF"),{TextWrapped=true})
 -- Odds tray: a sunk tray, "IN THIS EGG", a lemon key ("Yellow = you got"), cells and notes.
 self.tray=frame(root,"OddsTray",tz,{BackgroundTransparency=0,Visible=false})
 Kit.paint(self.tray,"BackgroundColor3","tray")
 node("UICorner",self.tray,{CornerRadius=UDim.new(0,12)})
 node("UIStroke",self.tray,{Color=Stage.Ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 self.trayTitle=label(self.tray,"Title",tz+1,12,Color3.new(1,1,1),{Text=Copy.get("hatch.result.inThisEgg")})
 self.trayKey=frame(self.tray,"Key",tz+1,{BackgroundTransparency=0,BackgroundColor3=Stage.Lemon})
 node("UICorner",self.trayKey,{CornerRadius=UDim.new(.5,0)})
 node("UIStroke",self.trayKey,{Color=Stage.Ink,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 self.trayKeyText=label(self.trayKey,"Text",tz+2,11,Stage.Ink,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,Text=Copy.get("hatch.result.youGot")})
 self.cells={}
 for index=1,12 do
  local c=frame(self.tray,"Cell"..index,tz+1,{BackgroundTransparency=0,BackgroundColor3=Stage.Cream,Visible=false})
  node("UICorner",c,{CornerRadius=UDim.new(0,8)})
  node("UIStroke",c,{Color=Stage.Ink,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  local n=label(c,"Name",tz+2,13,Stage.Ink,{TextTruncate=Enum.TextTruncate.AtEnd})
  local v=label(c,"Value",tz+2,13,Stage.Ink,{TextXAlignment=Enum.TextXAlignment.Right,FontFace=Font.new("rbxasset://fonts/families/RobotoMono.json",Enum.FontWeight.Bold)})
  self.cells[index]={frame=c,name=n,value=v}
 end
 self.notes={}
 for index=1,3 do self.notes[index]=label(self.tray,"Note"..index,tz+1,12,Color3.fromHex("#DCE5FF"),{TextWrapped=true,Visible=false})end
 -- Hatch another and the pity tray (2.5).
 self.pityTray=frame(root,"PityTray",tz,{BackgroundTransparency=0,Visible=false})
 Kit.paint(self.pityTray,"BackgroundColor3","tray")
 node("UICorner",self.pityTray,{CornerRadius=UDim.new(0,12)})
 node("UIStroke",self.pityTray,{Color=Stage.Ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 self.pityLine=label(self.pityTray,"Pity",tz+1,13,Color3.new(1,1,1),{TextTruncate=Enum.TextTruncate.AtEnd})
 self.pitySub=label(self.pityTray,"Stock",tz+1,12,Color3.fromHex("#DCE5FF"),{TextTruncate=Enum.TextTruncate.AtEnd})
 -- Stamp: "RARE!" (one translated string), laid out at its final size; Rare only.
 self.stamp=label(root,"RareStamp",z+10,64,Color3.new(1,1,1),{FontFace=Kit.DisplayFace,TextXAlignment=Enum.TextXAlignment.Center,AnchorPoint=Vector2.new(.5,.5),
  Text=Copy.get("hatch.result.stamp.rare"),Rotation=-6,Visible=false})
 node("UIStroke",self.stamp,{Color=Stage.Ink,Thickness=5,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 self.stampScale=node("UIScale",self.stamp,{Scale=1})
 -- "Tap to skip" (from the second hatch of an egg type) and the skip pad.
 self.skipChip=frame(root,"SkipChip",z+11,{BackgroundTransparency=.2,BackgroundColor3=Stage.Ink,AnchorPoint=Vector2.new(.5,1),Visible=false})
 node("UICorner",self.skipChip,{CornerRadius=UDim.new(.5,0)})
 self.skipText=label(self.skipChip,"Text",z+12,12,Color3.new(1,1,1),{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,Text=Copy.get("hatch.result.tapToSkip")})
 self.pre=self.skipChip -- (older callers read stage.pre)
 self.skip=node("TextButton",root,{Name="SkipReveal",Text="",AutoButtonColor=false,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=z+11,Selectable=false})
 self.skip:SetAttribute("AccessibleLabel",Copy.get("r1.hatchHints.hatch"))
 table.insert(self.connections,self.skip.Activated:Connect(function()
  if self:owned()and not self:inputOpen()and self.skippable and self.options.onSkip then self.options.onSkip()end
 end))
 -- Controls: the host's two receipt buttons, Hatch another, the cream round close.
 local ui=frame(root,"Controls",z+12,{Size=UDim2.fromScale(1,1)});self.ui=ui
 for index,variant in ipairs({"secondary","primary"})do
  local button=Kit.button(ui,if variant=="primary"then "StagePrimary"else "StageSecondary",{variant=variant,text="",selectable=false})
  button.Visible=false
  local entry={node=button,primary=variant=="primary"}
  table.insert(self.connections,button.Activated:Connect(function()self:activate(entry)end))
  self.buttons[index]=entry
 end
 self.againButton=Kit.button(ui,"HatchAnother",{variant="secondary",text=Copy.get("hatch.result.again"),selectable=false})
 self.againButton.Visible=false
 table.insert(self.connections,self.againButton.Activated:Connect(function()self:hatchAnother()end))
 self.close=node("TextButton",ui,{Name="StageClose",Text="",AutoButtonColor=false,BackgroundTransparency=1,Size=UDim2.fromOffset(44,44),ZIndex=ui.ZIndex+1,Selectable=false,Visible=false})
 local key=frame(self.close,"Key",ui.ZIndex+1,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(30,30),BackgroundTransparency=0,BackgroundColor3=Stage.Cream})
 node("UICorner",key,{CornerRadius=UDim.new(.5,0)})
 node("UIStroke",key,{Color=Stage.Ink,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 label(key,"X",ui.ZIndex+2,20,Stage.Ink,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,Text="×",AutoLocalize=false})
 self.closeKey=key
 self.close:SetAttribute("AccessibleLabel",Copy.get("hatch.reveal.close"))
 table.insert(self.connections,self.close.Activated:Connect(function()
  if self:owned()and self:inputOpen()and self.options.onClose then self.options.onClose()end
 end))
 self.ring=Kit.focusRing(ui)
 -- The toy lid (two shell halves, lip and ink seam) and the iris (a round window in a
 -- shell-coloured cover: one ring whose stroke covers the rest of the screen).
 local lz=z+14
 self.lidTop=frame(root,"LidTop",lz,{BackgroundTransparency=0,Visible=false})
 self.lidBottom=frame(root,"LidBottom",lz,{BackgroundTransparency=0,Visible=false})
 for _,half in ipairs({self.lidTop,self.lidBottom})do
  Kit.paint(half,"BackgroundColor3","shell")
  local lip=frame(half,"Lip",lz,{BackgroundTransparency=0,Size=UDim2.new(1,0,0,6)})
  Kit.paint(lip,"BackgroundColor3","shellLip")
  local seam=frame(half,"Seam",lz,{BackgroundTransparency=0,BackgroundColor3=Stage.Ink,Size=UDim2.new(1,0,0,3)})
  if half==self.lidTop then lip.Position=UDim2.new(0,0,1,-9);seam.Position=UDim2.new(0,0,1,-3)else lip.Position=UDim2.fromOffset(0,3);seam.Position=UDim2.new()end
 end
 self.iris=frame(root,"Iris",lz,{AnchorPoint=Vector2.new(.5,.5),Visible=false})
 node("UICorner",self.iris,{CornerRadius=UDim.new(.5,0)})
 self.irisCover=node("UIStroke",self.iris,{Thickness=2000,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,LineJoinMode=Enum.LineJoinMode.Round})
 Kit.paint(self.irisCover,"Color","shell")
 self.irisRing=frame(self.iris,"Ring",lz,{Size=UDim2.fromScale(1,1)})
 node("UICorner",self.irisRing,{CornerRadius=UDim.new(.5,0)})
 node("UIStroke",self.irisRing,{Color=Stage.Ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 self.lidEgg=image(root,"LidEgg",if self.kind=="stat"then "statEgg"else "egg",lz+1,{Visible=false})
 self.flat=frame(root,"FlatCover",lz+2,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false})
 Kit.paint(self.flat,"BackgroundColor3","shell")
 self.cover=self.flat -- (older callers read stage.cover)
end

function Stage:inputOpen()return self.lastSample~=nil and self.lastSample.input==true end
function Stage:isSettled()return self.lastSample~=nil and self.lastSample.settled==true end
function Stage:activate(entry)
 if not self:owned()or(self.options.consumeSkipInput and self.options.consumeSkipInput())then return false end
 if not self:inputOpen()then if self.skippable and self.options.onSkip then self.options.onSkip()end;return false end
 local action=entry.action
 if not action or not entry.enabled or type(action.act)~="function"then return false end
 action.act();return true
end
-- Hatch another (2.5): never the default focus, locked for 0.4 s after the card settles,
-- one press makes one request (the key waits on the host's pending state).
-- The host's state for the key, read at most 8 times a second (it clones a snapshot).
function Stage:againState(fresh)
 if not self.options.again then return nil end
 local now=os.clock()
 if not fresh and self.againCache and now-self.againCache.at<.125 then return self.againCache.state end
 local ok,state=pcall(self.options.again)
 state=if ok and type(state)=="table"then state else nil
 self.againCache={at=now,state=state}
 return state
end
function Stage:hatchAnother()
 if not self:owned()or self.againPressed or(self.options.consumeSkipInput and self.options.consumeSkipInput())then return false end
 local s=self.lastSample
 if not(s and s.againLive)then return false end
 local state=self:againState(true)
 if not state or state.enabled~=true or state.pending or type(state.act)~="function"then return false end
 self.againPressed=true;self.againPressedAt=os.clock()
 Kit.setEnabled(self.againButton,false)
 local ok=state.act()==true
 if not ok then self.againPressed=false end
 self.againCache=nil
 self:paintAgain(true)
 return ok
end
function Stage:onKey(input,processed)
 if processed or not self:owned()then return end
 local k=input.KeyCode
 -- H / gamepad Y (X already switches the colour channel on the Customize screen underneath).
 if k==Enum.KeyCode.H or k==Enum.KeyCode.ButtonY then
  if self:isSettled()then self:hatchAnother()end
 end
end
function Stage:refresh()
 if self.destroyed then return end
 local actions=if self.options.actions then self.options.actions()or {}else {}
 for _,entry in ipairs(self.buttons)do entry.action=nil end
 for _,action in ipairs(actions)do
  local entry=if action.primary then self.buttons[2]else self.buttons[1]
  if not entry.action then entry.action=action end
  local source=action.source
  if typeof(source)=="Instance"and not self.watched[source]then
   self.watched[source]=true
   for _,property in ipairs({"Text","Visible","Interactable"})do
    table.insert(self.connections,source:GetPropertyChangedSignal(property):Connect(function()if not self.refreshing then self:refresh()end end))
   end
  end
 end
 self.refreshing=true
 for _,entry in ipairs(self.buttons)do
  local action=entry.action;local source=action and action.source
  entry.shown=action~=nil and(source==nil or source.Visible)
  entry.enabled=entry.shown and(source==nil or source.Interactable)
  if action then Kit.setText(entry.node,if source then source.Text else action.text or "")end
  entry.live=nil
 end
 self.refreshing=false
 self:pullText()
 self.staticDone=false
 self:paintFocus()
end
-- The name and every line, only once the receipt is ready (disclosure rule).
function Stage:pullText()
 if not self:inputOpen()then return end
 local o=self.options
 local name=if o.name then o.name()else nil
 if type(name)=="string"and name~=""and self.nameValue~=name then
  self.nameValue=name;self.name.Text=string.upper(name)
  self.root:SetAttribute("AccessibleLabel",name);self:layoutText()
 end
 local effect=if o.effect then o.effect()else nil
 effect=if type(effect)=="string"then effect else ""
 local describe=if o.description then o.description()else Stage.describe(self.kind,o.result)
 local detail=if o.detail then o.detail()else nil
 if self.effect.Text~=effect then self.effect.Text=effect;self:layoutText()end
 if type(describe)=="string"and self.describe.Text~=describe then self.describe.Text=describe end
 if type(detail)=="string"and self.hostLine.Text~=detail then self.hostLine.Text=detail end
 if o.sticker then local word=o.sticker();if type(word)=="string"and word~=""then self.stickerText.Text=word end end
 self:pullTray()
end
function Stage:pullTray()
 local o=self.options
 local odds=if o.odds then o.odds()else nil
 local cells,notes=Stage.trayCells(odds,o.wonId,if self.L and self.L.s<.8 then 6 else 9)
 self.trayData={cells=cells,notes=notes,shown=odds~=nil}
 local pity=if o.pity then o.pity()else nil
 self.pityData=if type(pity)=="table"then pity else nil
 self:layoutTray()
end
function Stage:paintFocus()
 if self.destroyed or not self.ring then return end
 local selected=GuiService.SelectedObject
 for _,entry in ipairs(self.buttons)do
  if entry.action and entry.action.source==selected and selected~=nil and entry.node.Visible and not Kit.lastInputTouch()then self.ring.attach(entry.node,12);return end
 end
 self.ring.hide()
end

function Stage:layout()
 if self.destroyed then return end
 local size=self.root.AbsoluteSize;local W,H=math.max(1,size.X),math.max(1,size.Y)
 local safe,bar=Stage.safeArea(self.root)
 local L=Stage.geometry(W,H,Stage.topClear(safe,bar));self.L=L;self.staticDone=false
 do
  local ring=Stage.edgeRing(if L.phone then Stage.EdgeRadius.phone else Stage.EdgeRadius.regular)
  self.rainbow.Position=UDim2.fromOffset(-ring.offset,-ring.offset);self.rainbow.Size=UDim2.new(1,ring.offset*2,1,ring.offset*2)
  self.rainbowCorner.CornerRadius=UDim.new(0,ring.corner);self.rainbowStroke.Thickness=ring.thickness
 end
 local tx=L.text
 self.stickerText.TextSize=tx.sticker
 self.name.TextSize=tx.name;self.nameStroke.Thickness=math.max(2,math.floor(3*L.s+.5))
 tx.effect=if self.options.quietText then math.max(14,math.floor(16.3*L.s+.5))else tx.line
 self.effect.TextSize=tx.effect;self.describe.TextSize=tx.small+1;self.hostLine.TextSize=tx.small
 self.trayTitle.TextSize=tx.small;self.trayKeyText.TextSize=math.max(11,tx.small-1)
 self.pityLine.TextSize=tx.small+1;self.pitySub.TextSize=tx.small
 self.stamp.TextSize=tx.stamp;self.skipText.TextSize=tx.small
 self.rimCorner.CornerRadius=UDim.new(0,math.max(8,L.radius-3));self.wellCorner.CornerRadius=UDim.new(0,L.radius)
 local inset=Kit.patternInset(L.radius)
 self.clip.Position=UDim2.fromOffset(inset,inset);self.clip.Size=UDim2.new(1,-inset*2,1,-inset*2)
 for index,entry in ipairs(self.buttons)do
  local r=if index==2 then L.primary else L.secondary
  entry.node.Size=UDim2.fromOffset(r.w,r.h);entry.x,entry.y=r.x,r.y
  local state=Kit.buttonState(entry.node);if state then state.label.TextSize=tx.button;state.label.Size=UDim2.fromOffset(0,r.h)end
 end
 self.againButton.Size=UDim2.fromOffset(L.again.w,L.again.h)
 do local state=Kit.buttonState(self.againButton);if state then state.label.TextSize=tx.button;state.label.Size=UDim2.fromOffset(0,L.again.h)end end
 place(self.pityTray,L.pityTray)
 local pad=math.floor(12*L.s)
 self.pityLine.Position=UDim2.fromOffset(pad,math.floor(L.pityTray.h*.12));self.pityLine.Size=UDim2.fromOffset(L.pityTray.w-pad*2,math.floor(L.pityTray.h*.42))
 self.pitySub.Position=UDim2.fromOffset(pad,math.floor(L.pityTray.h*.52));self.pitySub.Size=UDim2.fromOffset(L.pityTray.w-pad*2,math.floor(L.pityTray.h*.38))
 local closeX,closeY=Stage.closeRect(W,H,L.phone,safe,bar)
 self.close.Position=UDim2.fromOffset(closeX,closeY)
 self.skipChip.Size=UDim2.fromOffset(math.floor(110*L.s),math.floor(24*L.s));self.skipChip.Position=UDim2.fromOffset(math.floor(W/2),H-math.floor(10*L.s))
 place(self.lines,{x=L.line1.x,y=L.line1.y,w=L.line1.w,h=L.tray.y-L.line1.y-2})
 self.effect.Position=UDim2.new();self.effect.Size=UDim2.fromOffset(L.line1.w,L.line1.h)
 self:layoutText();self:layoutTray()
 if self.scene and not self.scene.destroyed then self.scene:layout()end
 self:paint()
end
-- quietText: the name, the effect (two lines when it is long) and the fun line as one block, centred
-- on the well's seat. Landscape only; nothing else uses the tray's room there.
function Stage:quietLayout()
 local L=self.L
 if not L or not self.options.quietText or not L.landscape then return end
 local size=L.text.effect or L.text.line
 local wide=Kit.measure(self.effect.Text,"Body",size).X*(if Kit.translating then 1.35 else 1.05)>L.line1.w
 local effectH=math.ceil(size*1.25)*(if wide then 2 else 1)
 local gap=math.floor(6*L.s)
 local total=L.name.h+gap+effectH+2+L.line2.h
 local y=math.floor(L.wellSeat.y+(L.wellSeat.h-total)/2+.5)
 L.name.y=y;L.line1.y=y+L.name.h+gap;L.line1.h=effectH;L.line2.y=L.line1.y+effectH+2
 place(self.lines,{x=L.line1.x,y=L.line1.y,w=L.line1.w,h=effectH+2+L.line2.h*2+2})
 self.effect.Size=UDim2.fromOffset(L.line1.w,effectH)
end
-- The name shrinks to its column (never below 18 px) instead of clipping.
function Stage:layoutText()
 local L=self.L;if not L then return end
 self:quietLayout()
 local text=self.name.Text
 local wanted=Kit.measure(text,"Title",L.text.name).X
 local size=if wanted>L.textW-8 then math.max(18,math.floor(L.text.name*(L.textW-8)/math.max(1,wanted)))else L.text.name
 self.name.TextSize=size
 local w=math.min(L.textW,math.ceil(Kit.measure(text,"Title",size).X*1.08)+12)
 self.nameW,self.nameH=w,L.name.h
 place(self.nameGroup,{x=L.name.x,y=L.name.y,w=w,h=L.name.h})
 local sw=math.ceil(Kit.measure(self.stickerText.Text,"Label",L.text.sticker).X)+math.floor(24*L.s)
 self.stickerW=math.min(L.textW,sw)
 self.sticker.Size=UDim2.fromOffset(self.stickerW,L.sticker.h)
 -- With no effect line the fun line moves up into its place.
 local hasEffect=self.effect.Text~=""
 local y=if hasEffect then L.line1.h+2 else 0
 self.describe.Position=UDim2.fromOffset(0,y);self.describe.Size=UDim2.fromOffset(L.line1.w,L.line2.h+(if hasEffect then 0 else 4))
 self.hostLine.Position=UDim2.fromOffset(0,y+L.line2.h+2);self.hostLine.Size=UDim2.fromOffset(L.line1.w,L.line2.h)
 self.hostLine.Visible=not hasEffect
end
function Stage:layoutTray()
 local L=self.L;if not L then return end
 local data=self.trayData or {cells={},notes={}}
 place(self.tray,L.tray)
 local s=L.s;local pad=math.floor(14*s);local w=L.tray.w-pad*2
 self.trayTitle.Position=UDim2.fromOffset(pad,math.floor(8*s));self.trayTitle.Size=UDim2.fromOffset(math.floor(w*.5),math.floor(20*s))
 local kw=math.min(math.floor(w*.42),math.ceil(Kit.measure(self.trayKeyText.Text,"Label",self.trayKeyText.TextSize).X)+math.floor(18*s))
 self.trayKey.Position=UDim2.fromOffset(L.tray.w-pad-kw,math.floor(8*s));self.trayKey.Size=UDim2.fromOffset(kw,math.floor(20*s))
 local n=#data.cells
 local columns=if n<=3 then math.max(1,n)elseif n==4 then 2 else 3
 local gap=math.floor(6*s);local ch=math.max(L.text.cell+8,math.floor(26*s))
 local cw=math.floor((w-gap*(columns-1))/columns)
 local top=math.floor(34*s)
 for index,cell in ipairs(self.cells)do
  local c=data.cells[index]
  cell.frame.Visible=c~=nil
  if c then
   local col=(index-1)%columns;local row=math.floor((index-1)/columns)
   cell.frame.Position=UDim2.fromOffset(pad+col*(cw+gap),top+row*(ch+gap));cell.frame.Size=UDim2.fromOffset(cw,ch)
   cell.frame.BackgroundColor3=if c.won then Stage.Lemon else Stage.Cream
   cell.frame:SetAttribute("Won",c.won==true);cell.frame:SetAttribute("RowId",c.id)
   local inner=math.floor(8*s)
   cell.name.Text=c.name;cell.value.Text=c.value
   cell.name.TextSize=L.text.cell;cell.value.TextSize=L.text.cell
   local vw=if c.value~=""then math.ceil(Kit.measure(c.value,"Counter",L.text.cell).X)+2 else 0
   cell.value.Position=UDim2.fromOffset(cw-inner-vw,0);cell.value.Size=UDim2.fromOffset(vw,ch)
   cell.name.Position=UDim2.fromOffset(inner,0);cell.name.Size=UDim2.fromOffset(math.max(1,cw-inner*2-vw-4),ch)
  end
 end
 local rows=math.ceil(n/columns)
 local y=top+rows*(ch+gap)+math.floor(2*s)
 for index,note in ipairs(self.notes)do
  local text=data.notes[index]
  note.Visible=text~=nil and y+L.text.small<L.tray.h-4
  if text then
   note.Text=text;note.TextSize=L.text.small
   local h=math.ceil(Kit.measure(text,"Small",L.text.small,w).Y)+2
   note.Position=UDim2.fromOffset(pad,y);note.Size=UDim2.fromOffset(w,h);y+=h+math.floor(2*s)
  end
 end
 self.trayKey.Visible=false
 for _,c in ipairs(data.cells)do if c.won then self.trayKey.Visible=true end end
end

function Stage:currentSample()
 local reduced=self.reducedStart or self:reduced()
 return Stage.sample(self.age,reduced,self.tier)
end
-- Integrate the moving patterns over the hatch clock (R1.3: speeds never jump).
function Stage:integrate(dt,reduced)
 local from,to=self.lastAge,self.age
 self.lastAge=to
 local dh=math.clamp(to-from,0,.25)
 local mid=from+dh*.5
 if reduced then return end
 local still=self.staticDone
 local checker=if self.age<=0 or still then 8 else Stage.checkerSpeed(mid,self.tier,false)
 -- After the hatch the patterns keep drifting on the frame clock.
 local step=if dh>0 then dh else dt
 self.checker=(self.checker+checker*step)%Kit.Checker.tile
 self.rays=(self.rays+Stage.raySpeed(mid,self.tier,false)*step)%360
 if self.tier=="Rare"then
  self.shaftTurn=(self.shaftTurn+Stage.shaftSpeed(mid)*step)%360
  self.orbitTurn=(self.orbitTurn+Stage.orbitSpeed(mid)*dh)%1
 end
end
function Stage:paint(dt)
 local L=self.L;if not L or self.destroyed then return end
 local s=self:currentSample();local was=self.lastSample;self.lastSample=s
 if s.input and not(was and was.input)then self:refresh();self:pullText()
 elseif s.input and not self.staticDone then self:pullText()end
 local reduced=s.reduced
 local still=reduced or self.instant
 self:integrate(dt or 0,reduced)
 self.root:SetAttribute("InputLocked",not s.input);self.root:SetAttribute("ReceiptReady",s.input)
 self.root:SetAttribute("HatchAge",self.age)
 if self.staticDone and s.settled then self:paintIdle(s);return end
 local W,H=L.W,L.H;local scale=L.s
 -- Lid in / iris (real time from the open), or the Reduced Motion fade.
 self:paintLid(s)
 -- Shell and checker.
 self.checkerTile.Position=UDim2.fromOffset(math.floor(-Kit.Checker.tile+self.checker),math.floor(-Kit.Checker.tile+self.checker))
 -- The well: slide, punch, camera; a shake for Rare.
 local slide=if still then 1 else s.slide
 local shakeX=if still then 0 else math.sin(self.clock*61)*s.shake*scale
 local shakeY=if still then 0 else math.cos(self.clock*53)*s.shake*scale*.6
 local cx,cy,ww,wh=Stage.wellRect(L,slide,if still then 0 else s.punch)
 cx+=shakeX;cy+=shakeY
 -- The new egg drops into the well from above when the shell is already up (Hatch another).
 local drop=0
 if self.handedFrom and not still then drop=(1-expoOut(ramp(self.openClock,0,.20)))*-wh*.6 end
 if slide>=1 and not s.jackpot or s.settled then cx,cy,ww,wh=math.round(cx),math.round(cy),math.round(ww),math.round(wh)end
 self.cx,self.cy,self.ww,self.wh=cx,cy,ww,wh
 self.well.Position=UDim2.fromOffset(cx,cy);self.well.Size=UDim2.fromOffset(ww,wh)
 self.rim.Position=UDim2.fromOffset(cx,cy);self.rim.Size=UDim2.fromOffset(ww-6,wh-6)
 local side=math.min(ww,wh)
 local seat=side*.98*(if still then 1 else s.cam)
 self.seat.Position=UDim2.fromOffset(cx,cy+drop);self.seat.Size=UDim2.fromOffset(seat,seat)
 self.seat.Rotation=if still then 0 else s.tip
 -- Inside the well: core, rays (turning), pattern, floor light, bloom.
 local diag=math.sqrt(ww*ww+wh*wh)*1.05
 self.core.Size=UDim2.fromOffset(ww*1.5,wh*1.5)
 self.raysImage.Size=UDim2.fromOffset(diag,diag);self.raysImage.Rotation=self.rays
 self.raysImage.ImageTransparency=if s.jackpot and s.t<s.burstAt and not still then .65 else .42
 local fw=side*.66
 self.floorLight.Position=UDim2.new(.5,0,.78,0);self.floorLight.Size=UDim2.fromOffset(fw,fw*.28)
 self.floorShadow.Position=UDim2.new(.5,0,.79,0);self.floorShadow.Size=UDim2.fromOffset(fw*.6,fw*.13)
 local br=150*scale*s.bloomR*2
 self.bloom.Position=UDim2.fromScale(.5,.5);self.bloom.Size=UDim2.fromOffset(math.max(1,br),math.max(1,br));self.bloom.ImageTransparency=1-s.bloom
 -- Rare: light shafts behind the well, the rainbow on the rim and the screen edge.
 local shafts=s.shafts or 0
 self.shafts.Visible=shafts>0
 if shafts>0 then
  local sd=math.max(W,H)*1.6
  self.shafts.Position=UDim2.fromOffset(cx,cy);self.shafts.Size=UDim2.fromOffset(sd,sd);self.shafts.Rotation=self.shaftTurn;self.shafts.ImageTransparency=1-shafts
 end
 local rainbow=s.rainbow or 0
 self.rainbow.Visible=rainbow>0;self.rimRainbow.Enabled=rainbow>0
 if rainbow>0 then
  self.rainbowStroke.Transparency=1-rainbow
  local turn=if reduced then 0 else(self.clock*216)%360
  self.rainbowGradient.Rotation=turn;self.rimRainbow.Rotation=turn
  self.rimStroke.Color=Color3.new(1,1,1);self.rimStroke.Thickness=math.max(3,math.floor(5*scale))
 else self.rimStroke.Color=self.look.color;self.rimStroke.Thickness=3 end
 -- Shockwave.
 local shock=s.shock
 -- Round 3 (Fable brief 1.3): a host with an accent (the won stat's colour) shows it only from
 -- the burst: the bloom and the shockwave take it, and an Uncommon gets one ring of it.
 local accent=self:accent()
 if accent then
  local burst=s.burstAge~=nil and s.burstAge>=0
  self.bloom.ImageColor3=if burst then accent else Color3.new(1,1,1)
  self.shockStroke.Color=accent
  if not shock and self.tier=="Uncommon"and burst and s.burstAge<.35 and not still then
   local u=s.burstAge/.35
   shock={radius=40+240*expoOut(u),width=6-4*u,alpha=.8*(1-u)}
  end
 end
 self:paintRoulette(s,still)
 self.shock.Visible=shock~=nil and not still
 if shock and not still then
  local d=shock.radius*2*scale
  self.shock.Position=UDim2.fromOffset(cx,cy);self.shock.Size=UDim2.fromOffset(d,d)
  self.shockStroke.Thickness=math.max(1,math.floor(shock.width*scale+.5));self.shockStroke.Transparency=1-shock.alpha
 end
 self:paintOrbit(s,still)
 self:paintConfetti(s,still)
 self:paintStamp(s,still)
 self:paintText(s,still)
 self:paintSpin(s)
 local skipVisible=not s.input and self.skippable and not still and self.openClock>=.15
 self.skipChip.Visible=skipVisible and(not self.useLid or(self.lid and self.lid.done))
 self.skip.Visible=not s.input;self.skip.Active=not s.input
 local opened=not self.useLid or(self.lid and self.lid.done)
 -- Rest only once every piece of confetti has landed (still falling as the keys go live).
 local flying=false
 for _,o in ipairs(self.cannons)do if o.Visible then flying=true;break end end
 if not flying then for _,o in ipairs(self.pieces)do if o.Visible then flying=true;break end end end
 if s.settled and opened and(not flying or still)then self.staticDone=true;self:paintFocus()end
end
function Stage:paintLid(s)
 local L=self.L;local W,H=L.W,L.H
 local reduced=s.reduced
 if reduced and not self.instant then
  -- 150 ms fade up from the flat deck colour.
  local a=s.fade
  self.flat.Visible=a<1;self.flat.BackgroundTransparency=a
 elseif not self.leaving then self.flat.Visible=false end
 local waiting=not self:sceneReady()
 if not self.useLid then
  self.lidTop.Visible=false;self.lidBottom.Visible=false;self.iris.Visible=false
  self.lidEgg.Visible=false
  -- No lid (Hatch another): the 2D egg holds the well until the scene has loaded.
  self.waitEgg.Visible=waiting and not self.instant
  if waiting then
   local e=math.min(self.ww or 200,self.wh or 200)*.42
   self.waitEgg.Position=UDim2.fromOffset(self.cx or W/2,(self.cy or H/2)+2*math.sin(self.openClock*math.pi*2/1.2))
   self.waitEgg.Size=UDim2.fromOffset(e*.8,e)
  end
  return
 end
 if self.lid and self.lid.done then
  self.lidTop.Visible=false;self.lidBottom.Visible=false;self.iris.Visible=false;self.lidEgg.Visible=false;self.waitEgg.Visible=false
  self:showContent(true)
  return
 end
 self.lidHeld=self.lidHeld or 0
 local u=self.openClock
 local ready=not waiting
 local lid=Stage.lidSample(u,ready,self.lidHeld)
 if not ready and u>=Stage.Lid.close then self.lidHeld=u-Stage.Lid.close end
 self.lid=lid
 if lid.done then
  self.lidTop.Visible=false;self.lidBottom.Visible=false;self.iris.Visible=false;self.lidEgg.Visible=false;self.waitEgg.Visible=false
  self:showContent(true)
  return
 end
 local half=math.ceil(H/2)
 -- While the halves close, the screen underneath (the egg shop) shows between them; the
 -- stage is drawn beneath the lid once it is shut, and the iris opens onto it.
 self:showContent(u>=Stage.Lid.close)
 if lid.iris<=0 then
  -- Halves close from top and bottom; they meet at the middle with a little clack.
  local clack=lid.clack
  self.lidTop.Visible=true;self.lidBottom.Visible=true;self.iris.Visible=false
  self.lidTop.Position=UDim2.fromOffset(0,math.floor(-half+half*lid.close-clack));self.lidTop.Size=UDim2.fromOffset(W,half+3)
  self.lidBottom.Position=UDim2.fromOffset(0,math.floor(H-half*lid.close+clack));self.lidBottom.Size=UDim2.fromOffset(W,half+3)
 else
  self.lidTop.Visible=false;self.lidBottom.Visible=false;self.iris.Visible=true
  local r=lid.irisR*L.s
  self.iris.Position=UDim2.fromOffset(self.cx or W/2,self.cy or H/2);self.iris.Size=UDim2.fromOffset(r*2,r*2)
  self.irisCover.Thickness=math.max(W,H)*1.5
 end
 -- The egg rides the lid to the middle, lands with a squash, bobs while the server answers,
 -- and fades into the stage's own egg as the iris opens.
 local e=lid.egg*L.s
 self.lidEgg.Visible=lid.iris<1
 -- It rides to where the stage's own egg stands (a little under the well's middle).
 local eggY=(self.cy or H/2)+math.min(self.ww or 300,self.wh or 300)*.08*lid.close
 self.lidEgg.Position=UDim2.fromOffset(self.cx or W/2,eggY-lid.bob*L.s)
 self.lidEgg.Size=UDim2.fromOffset(e*.8/lid.eggSquash,e*lid.eggSquash)
 self.lidEgg.ImageTransparency=lid.iris
end
-- Everything but the lid, the iris and the flat cover (toggled only when it changes).
function Stage:showContent(on)
 if self.contentShown==on then return end
 self.contentShown=on
 local keep={[self.lidTop]=true,[self.lidBottom]=true,[self.iris]=true,[self.lidEgg]=true,[self.flat]=true}
 for _,child in ipairs(self.root:GetChildren())do
  if child:IsA("GuiObject")and not keep[child]then
   if on then
    if child:GetAttribute("LidHidden")then child.Visible=true;child:SetAttribute("LidHidden",nil)end
   elseif child.Visible then child.Visible=false;child:SetAttribute("LidHidden",true)end
  end
 end
end
function Stage:paintOrbit(s,still)
 local on=s.orbit>0 and not still
 local L=self.L
 for index,o in ipairs(self.orbit)do
  local show=on or(still and s.stillStones and index<=(if s.jackpot then 12 else 6))
  o.Visible=show
  if show then
   local n=if still then(if s.jackpot then 12 else 6)else #self.orbit
   local a=(index-1)/n*math.pi*2+(if still then 0 else self.orbitTurn*math.pi*2)
   local r=(if still then math.min(self.ww,self.wh)*.42 else(s.orbitRadius or 120)*L.s)
   local size=math.floor((if index>8 then 20 else 19)*L.s+.5)
   o.Position=UDim2.fromOffset(self.cx+math.cos(a)*r,self.cy+math.sin(a)*r*.82)
   o.Size=UDim2.fromOffset(size,size);o.ImageTransparency=if still then 0 else 1-s.orbit
   o.Rotation=if index>8 then 0 else math.deg(a)*.25
   local colors=self.options.orbitColors and self.options.orbitColors()
   if index<=8 and type(colors)=="table"and #colors>0 then o.ImageColor3=colors[(index-1)%#colors+1]end
  end
 end
end
function Stage:accent()
 local fn=self.options.accent
 local value=if fn then fn()else nil
 return if typeof(value)=="Color3"then value else nil
end
-- Round 3 (Fable brief 1.3): while the egg rocks, six stat-coloured sparkles pop on an ellipse
-- round its belt, two per rock (0.21, 0.48, 0.81). They say "one of six" and never the answer.
Stage.RouletteAt=table.freeze({.21,.48,.81})
function Stage.rouletteScale(t,index)
 local at=Stage.RouletteAt[math.ceil(index/2)]
 if not at then return 0 end
 local u=(t-at)/.22
 if u<=0 or u>=1 then return 0 end
 return 1.2*math.sin(math.pi*u)
end
function Stage:paintRoulette(s,still)
 local list=self.roulette;if #list==0 then return end
 local colors=self.options.roulette()
 local L=self.L
 -- The egg in the well is about 21% of its short side wide, its belt 20% of its height below
 -- the centre (measured on the 844x390 and desktop captures, round 3).
 local eggW=math.min(self.ww,self.wh)*.21
 for index,o in ipairs(list)do
  local k=if still or s.reduced then 0 else Stage.rouletteScale(s.t,index)
  o.Visible=k>0
  if k>0 then
   local a=(index-1)/6*math.pi*2+math.pi/2
   local size=math.floor(14*L.s*k+.5)
   o.ImageColor3=(type(colors)=="table"and colors[index])or Color3.new(1,1,1)
   o.Position=UDim2.fromOffset(self.cx+math.cos(a)*eggW*.62,self.cy+self.wh*.20+math.sin(a)*eggW*.14)
   o.Size=UDim2.fromOffset(size,size)
  end
 end
end
function Stage:stoneColor(index)
 local fn=self.options.stoneColors
 local colors=if fn then fn()else nil
 if type(colors)=="table"and #colors>0 then return colors[(index-1)%#colors+1]end
 return if index%2==0 then self.look.color else self.look.second
end
function Stage:paintConfetti(s,still)
 local L=self.L;local st=self.stageLook
 local age=if still then math.huge else s.burstAge
 local stones,sparkles=st.stones,st.sparkles
 local n=stones+sparkles
 for index,o in ipairs(self.pieces)do
  local x,y,rot,fade
  if index<=n and age>=0 then x,y,rot,fade=Stage.confetti(index,n,age,st.escape,math.min(self.ww,self.wh)*.5,L.s)end
  o.Visible=x~=nil
  if x then
   local sparkle=index>stones
   if not o:GetAttribute("Painted")then
    local a=Stage.Art[if sparkle then "sparkle"else "pebble"]
    o.ImageRectOffset=Vector2.new(a[2],a[3]);o.ImageRectSize=Vector2.new(a[4],a[5])
    o.ImageColor3=if sparkle then Color3.new(1,1,1)else self:stoneColor(index)
    o:SetAttribute("Painted",true)
   end
   local size=math.floor((if sparkle then 16+8*hash(index,56)else 15+6*hash(index,57))*L.s+.5)
   o.Position=UDim2.fromOffset(self.cx+x,self.cy+y);o.Size=UDim2.fromOffset(size,size);o.Rotation=if sparkle then 0 else rot;o.ImageTransparency=1-fade
  end
 end
 -- Rare: the two cannons.
 local J=Rarity.Jackpot
 local per=Stage.Cannon.count
 for index,o in ipairs(self.cannons)do
  local x,y,rot,fade
  if s.jackpot and not still then
   local sideIndex=if index<=per then -1 else 1
   local fired=if sideIndex<0 then J.cannonL else J.cannonR
   x,y,rot,fade=Stage.cannon(index,sideIndex,s.t-fired,L.W,L.H,L.s)
  end
  o.Visible=x~=nil
  if x then
   if not o:GetAttribute("Painted")then
    local accent=self:accent()
    o.ImageColor3=if index%3==0 then Color3.new(1,1,1)elseif accent then(if index%2==0 then accent else Color3.fromHex("#FFC14D"))else Color3.fromHex(Stage.Rainbow[(index%6)+1])
    o:SetAttribute("Painted",true)
   end
   local size=math.floor((12+8*hash(index,58))*L.s+.5)
   o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(size,size);o.Rotation=rot;o.ImageTransparency=1-fade
  end
 end
end
function Stage:paintStamp(s,still)
 local L=self.L
 local on=s.jackpot and s.stamp>0 and(not self.instant)
 self.stamp.Visible=on
 if not on then return end
 local w=math.ceil(Kit.measure(self.stamp.Text,"Title",L.text.stamp).X*1.2)+20
 self.stamp.Size=UDim2.fromOffset(w,math.floor(L.text.stamp*1.3))
 local from=Vector2.new(self.cx,self.cy-math.min(self.ww,self.wh)*.30)
 local to=Vector2.new(L.sticker.x+(self.stickerW or 100)/2,L.sticker.y)
 local u=s.stampTravel or 0
 local p=from:Lerp(to,u)
 self.stamp.Position=UDim2.fromOffset(math.round(p.X),math.round(p.Y))
 local sc=(s.stampScale or 1)*(1-.75*u)
 if s.reduced then sc=1 end
 -- Squash keeps volume: the stamp's own UIScale carries the size; a squash is drawn as a
 -- shorter text box (laid out at its final size, never left scaled).
 self.stampScale.Scale=if math.abs(sc-1)<1e-3 then 1 else sc
 self.stamp.TextTransparency=1-s.stamp
end
function Stage:paintText(s,still)
 local L=self.L
 -- Sticker and name pop (Back 2.0 / 2.2) when the receipt is ready.
 local named=s.named
 self.sticker.Visible=named and s.sticker>0 and not self.options.quietText
 self.sticker.Position=UDim2.fromOffset(L.sticker.x,L.sticker.y+math.floor(L.sticker.h/2))
 self.stickerScale.Scale=if s.reduced or s.sticker>=1 then 1 else math.max(.01,s.sticker)
 self.sticker.BackgroundTransparency=if s.reduced then 1-s.sticker else 0
 self.stickerText.TextTransparency=if s.reduced then 1-s.sticker else 0
 self.nameGroup.Visible=named and self.nameValue~=nil
 self.nameScale.Scale=if s.reduced or s.t>=s.readyAt+.2 then 1 else math.max(.01,s.name)
 self.name.TextTransparency=if s.reduced then 1-s.name else 0
 self.nameStroke.Transparency=self.name.TextTransparency
 -- One sheen sweep across a Rare sticker as the card settles.
 local sheen=if self.tier=="Rare"and not s.reduced then ramp(s.t,s.readyAt+.05,.40)else 0
 self.stickerSheen.Visible=sheen>0 and sheen<1
 if self.stickerSheen.Visible then self.stickerSheen.Position=UDim2.fromOffset(math.floor((self.stickerW or 100)*sheen)-5,0)end
 self.lines.Visible=named and s.lines>0
 local la=1-s.lines
 self.effect.TextTransparency=la;self.describe.TextTransparency=la;self.hostLine.TextTransparency=la
 self.effect.Visible=self.effect.Text~="";self.describe.Visible=self.describe.Text~=""
 self.hostLine.Visible=self.hostLine.Text~=""and self.effect.Text==""
 -- Tray and keys rise 70 px (Expo Out, 0.30 s).
 local rise=math.floor((1-s.tray)*70*L.s)
 local data=self.trayData
 self.tray.Visible=named and data~=nil and data.shown
 self.tray.Position=UDim2.fromOffset(L.tray.x,L.tray.y+rise)
 local brise=math.floor((1-s.buttons)*70*L.s)
 for _,entry in ipairs(self.buttons)do
  entry.node.Visible=s.input and entry.shown==true
  entry.node.Position=UDim2.fromOffset(entry.x or 0,(entry.y or 0)+brise)
  local live=entry.enabled==true and s.input
  if entry.live~=live then entry.live=live;Kit.setEnabled(entry.node,live)end
 end
 self.pityTray.Visible=s.input and self.pityData~=nil
 self.pityTray.Position=UDim2.fromOffset(L.pityTray.x,L.pityTray.y+brise)
 if self.pityData then
  self.pityLine.Text=self.pityData.line or "";self.pitySub.Text=self.pityData.sub or ""
  -- One line sits in the middle of the tray; two share it.
  local one=self.pitySub.Text==""
  local h=self.L.pityTray.h
  self.pityLine.Position=UDim2.fromOffset(self.pityLine.Position.X.Offset,if one then math.floor(h*.29)else math.floor(h*.12))
  self.pityLine.TextTransparency=1-(if s.reduced then 1 else math.max(.3,s.pity))
 end
 self.againButton.Position=UDim2.fromOffset(L.again.x,L.again.y+brise)
 self:paintAgain(false)
 self.close.Visible=s.input and self.options.onClose~=nil
end
function Stage:paintAgain(force)
 local s=self.lastSample;if not s then return end
 local state=if s.input then self:againState()else nil
 -- Round 3 (Spencer): once shown, the key stays up (disabled) while the card leaves: the host
 -- stops offering it as soon as the result is stored, before the stage's own exit.
 if state==nil and self.againShown and s.input then
  if self.againLive~=false then self.againLive=false;Kit.setEnabled(self.againButton,false)end
  self.againButton:SetAttribute("AgainLive",false)
  return
 end
 local show=state~=nil
 self.againButton.Visible=show
 if not show then return end
 self.againShown=true
 -- A press the host refused (it is no longer pending a second later) frees the key again.
 if self.againPressed and not state.pending and os.clock()-(self.againPressedAt or 0)>1 then self.againPressed=false end
 local text=state.text or Copy.get("hatch.result.again")
 if state.pending then text=Copy.get("hatch.result.hatching")end
 if not state.enabled and state.reason and state.reason~=""then text=state.reason end
 if self.againText~=text or force then self.againText=text;Kit.setText(self.againButton,text)end
 local live=state.enabled==true and not state.pending and s.againLive and not self.againPressed
 if self.againLive~=live or force then self.againLive=live;Kit.setEnabled(self.againButton,live)end
 self.againButton:SetAttribute("AgainLive",live)
end
-- A 3D result turns slowly once its name is out (never under Reduced Motion).
function Stage:paintSpin(s)
 local scene=self.scene
 if not scene or scene.destroyed or type(scene.setSpin)~="function"then return end
 if s.reduced or self:reduced()or not s.named then
  if self.spinning then self.spinning=false;self.spinFrom=nil;scene:setSpin(0)end
  return
 end
 self.spinFrom=self.spinFrom or self.clock
 self.spinning=scene:setSpin(Stage.spinAt(self.clock-self.spinFrom))
end
function Stage:paintIdle(s)
 self:paintSpin(s)
 self:paintAgain(false)
 if s.reduced then return end
 self.checkerTile.Position=UDim2.fromOffset(math.floor(-Kit.Checker.tile+self.checker),math.floor(-Kit.Checker.tile+self.checker))
 self.raysImage.Rotation=self.rays
 if self.rainbow.Visible then
  local turn=(self.clock*216)%360
  self.rainbowGradient.Rotation=turn;self.rimRainbow.Rotation=turn
 end
 if self.shafts.Visible then self.shafts.Rotation=self.shaftTurn end
end

function Stage:updateExternal(age,sample)
 if self.destroyed then return end
 self.age=math.max(0,age or 0);self.poseSample=sample
end
-- Leave (R1.4). The stage moves to its own top-level gui (its host may hide or change page in
-- the same frame), stops taking input, closes its iris on the item, then opens the lid onto
-- whatever is underneath. `after` runs once it is gone. options.handover (Hatch another):
-- stay up, unchanged, until the next stage takes over (or 8 s pass). False (and nothing done)
-- when the stage was not on screen in the last moment: the caller destroys it as before.
Stage.HandoverTimeout=8
function Stage:dismiss(after,options)
 if self.destroyed or self.leaving then return false end
 if not self.seenAt or os.clock()-self.seenAt>.1 then return false end
 local gui=C.detach(self.root);if not gui then return false end
 self.leaving={at=os.clock(),gui=gui,after=after,cx=self.cx,cy=self.cy}
 if self.connection then self.connection:Disconnect();self.connection=nil end
 for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
 if self.ring then self.ring.hide()end
 self.skip.Visible=false;self.skipChip.Visible=false
 self.root:SetAttribute("Leaving",true)
 if options and options.handover then
  -- Kept up for Hatch another: a full-screen sink with no keys (no tap reaches the screen
  -- underneath), until the next stage takes over. It leaves by the iris if the host stops
  -- waiting (a refused store or buy) for half a second, or after HandoverTimeout.
  self.leaving.handover=true
  -- Round 3 (Spencer): the keys stay on screen, disabled, until the next stage takes over
  -- (the root sinks every tap; the key bindings are already gone).
  self.root.Active=true
  for _,entry in ipairs(self.buttons)do if entry.node then Kit.setEnabled(entry.node,false)end end
  Kit.setEnabled(self.againButton,false);self.againLive=false
  if self.close then self.close.Interactable=false end
  Stage.handover=self
  local idleSince
  local pending=options.pending
  self.connection=RunService.RenderStepped:Connect(function()
   local waiting=pending==nil or pending()==true
   if waiting then idleSince=nil else idleSince=idleSince or os.clock()end
   if os.clock()-self.leaving.at>Stage.HandoverTimeout or(idleSince and os.clock()-idleSince>.5)then
    if Stage.handover==self then Stage.handover=nil end
    self.leaving.handover=false;self.leaving.at=os.clock()
    self.root.Active=false;self.root.Interactable=false
    self.connection:Disconnect();self.connection=RunService.RenderStepped:Connect(function()self:paintLeave()end)
   end
  end)
  return true
 end
 self.root.Active=false;self.root.Interactable=false
 self.connection=RunService.RenderStepped:Connect(function()self:paintLeave()end)
 self:paintLeave()
 return true
end
function Stage:paintLeave(elapsed)
 local leave=self.leaving;if not leave or self.destroyed or leave.handover then return end
 local reduced=self:reduced()
 local s=Stage.leaveSample(elapsed or os.clock()-leave.at,reduced)
 if s.done then self:destroy();return end
 local L=self.L;local W,H=L.W,L.H
 if reduced then
  self.flat.Visible=true
  if not s.shut then self.flat.BackgroundTransparency=1-s.cover;return end
  if not leave.cleared then
   leave.cleared=true
   for _,child in ipairs(self.root:GetChildren())do if child:IsA("GuiObject")and child~=self.flat then child.Visible=false end end
  end
  self.flat.BackgroundTransparency=s.open
  return
 end
 if not s.shut then
  self.iris.Visible=true;self.irisCover.Thickness=math.max(W,H)*1.5
  local r=math.max(1,s.irisR*L.s)
  self.iris.Position=UDim2.fromOffset(leave.cx or W/2,leave.cy or H/2);self.iris.Size=UDim2.fromOffset(r*2,r*2)
  return
 end
 if not leave.cleared then
  leave.cleared=true
  for _,child in ipairs(self.root:GetChildren())do
   if child:IsA("GuiObject")and child~=self.lidTop and child~=self.lidBottom then child.Visible=false end
  end
  self.lidTop.Visible=true;self.lidBottom.Visible=true
 end
 -- The lid opens (Expo Out) onto the destination.
 local half=math.ceil(H/2)
 self.lidTop.Position=UDim2.fromOffset(0,math.floor(-half*s.open));self.lidTop.Size=UDim2.fromOffset(W,half+3)
 self.lidBottom.Position=UDim2.fromOffset(0,math.floor(half+half*s.open));self.lidBottom.Size=UDim2.fromOffset(W,half+3)
end
function Stage:step(dt)
 if self.destroyed or self.leaving then return end
 if C.onScreen(self.root)then self.seenAt=os.clock()end
 if self:owned()then
  local d=math.clamp(dt,0,.1)
  self.clock+=d;self.openClock+=d
 end
 self:paint(dt)
end
function Stage:getStats()
 local s=self.lastSample or Stage.sample(self.age,false,self.tier)
 local live=0
 for _,o in ipairs(self.pieces)do if o.Visible then live+=1 end end
 for _,o in ipairs(self.cannons)do if o.Visible then live+=1 end end
 for _,o in ipairs(self.orbit)do if o.Visible then live+=1 end end
 return {age=self.age,tier=self.tier,kind=self.kind,settled=s.settled,input=s.input,named=self.nameValue,instant=self.instant,
  pieces=#self.pieces+#self.cannons+#self.orbit,live=live,jackpot=s.jackpot,lid=self.useLid,skippable=self.skippable,
  sharedScene=true,externalClock=true,phone=self.L and self.L.phone,landscape=self.L and self.L.landscape}
end
function Stage:destroy()
 if self.destroyed then return end
 self.destroyed=true
 if Stage.handover==self then Stage.handover=nil end
 if self.connection then self.connection:Disconnect();self.connection=nil end
 for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
 if self.ring then self.ring.hide()end
 local scene=self.scene;self.scene=nil
 if scene and not scene.destroyed then scene:release(self.borrowToken)end
 self.root:Destroy()
 local leave=self.leaving
 if leave and leave.gui then leave.gui:Destroy()end
 -- The leave's `after` (the reveal keeps its cinematic until then) runs however it ended:
 -- the iris and lid, or a Hatch another handover.
 local after=leave and leave.after
 if leave then leave.after=nil end
 if after then after()end
end
return Stage
