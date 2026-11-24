-- The Sleepy Nest in the garden, the client (ONBOARDING-V3-PLAN-2026-11-23 slice D; the look is
-- artifacts/onboarding-2026-11-23/NEST-LOOK.md, remodelled and moved to the plaza for beta 12 QA O2:
-- artifacts/qa-2026-11-23-beta12/GARDEN-LIFE-NEST-LOOK.md section 4). mount() answers nil with the Onboarding v3 build
-- ceiling off; with Onboard.on("nest") off it only watches the switch: no instances, no remotes bound, no per-frame work.
-- On: the nest (21 parts: a twig mound, rim rolls, a straw bed, twig and straw fringes, a wooden sign with the pet's
-- name) and the napping egg at Nest.Spot as local inert parts in one folder (anchored, nothing can touch, stand on or
-- query them; only the mound casts a shadow), the egg's growth look from Nest.look (small, glow, rocking, ready), a label with
-- the clock, a ProximityPrompt to Tuck in or Hatch, a HUD chip with the countdown, and clientUI.nestPlace for the Bear.
-- The server is the truth (NestHost):
--   NestEvent {kind="state", public}    the egg, its clock and its gift (public = nil: no nest, everything goes)
--   NestEvent {kind="claimed", receipt} the egg hatched and was saved: only now is the reward shown
--   NestEvent {kind="refused", reason, of}
--   NestClaim {kind="sync"|"tuck"|"claim"} (the server lands the egg by itself; the client never sends "land")
-- Remotes are bound through remotes.ChildAdded, never waited for; {kind="sync"} once both are there, again on each
-- switch-on and on respawn. Presentation only: nothing here pays, times or decides anything.
-- deps: remotes, audio ({play(name, speed, volume)}), reduced(), root() -> Vector3?, free() (Room mode, nothing
--   in the way), busy() (a menu or card is up), compact() (phone), chipHost() -> GuiObject? (the garden dock),
--   show() (lay the Show me trail to the nest), toast(text, stars) (the rail), petName(), ground(at) -> y?,
--   meshes() -> {TopShell, BottomShell, Core}? (fresh MeshPart copies, or nil while they load), focus() (the pet focus
--   camera is on: the label hides), chipHidden() (in the Pet Park: the chip hides), measure(text, size) -> px,
--   plus world, player ({CharacterAdded}), now() (server unix time) and step=false (no Heartbeat; specs call :step).
-- Beta 14 QA Q2 (WORLD-AND-NEST-LOOK 4): one pill with one message (Client.row's seven rows), shown by the player's
--   distance and never under the pet's need bubble: bubble() -> {shown, pet = Vector3?} (optional; init's bubble
--   wrapper asks holdsBubble() so a beat holds the bubble back). No second pill, no tuck-in rail toast.
-- Beta 14 QA D1: the nest sits beside the Eggs station; while its prompt can act and the player stands nearer to it,
--   the station's prompt steps aside (LoungeStations.Yield.Eggs). menuRow(summary) is the Hatch eggs screen's row.
-- The egg corner (Onboard.on("corner"), EGG-CORNER-BUILD-PLAN 8; EGG-CORNER-LOOK 3 and R2 3): the nest stands at
--   EggCorner.nestSpot() (the old station's spot once the island split lands), faces EggCorner.nestFacing(), and
--   re-opens when the switch flips; no Yield (the machine is far away); the napping pill is the clock plus a "?" disc
--   (44 px hit; the board lives in deps.gui() so it can be tapped), the prompt's third verb is Peek, and the disc, the
--   pill and Peek all call help() (deps.help(self): the "?" card). At (-31, -11) it also lays a straw scatter and a soft
--   contact shadow on the marble. Off: exactly the nest before.
-- The Sleepy Nest landmark (Onboard.on("landmark"), NestLandmark; NEST-LANDMARK-LOOK, NEST-LANDMARK-BUILD-PLAN): at the
--   corner's spot the 21 twig parts give way to the NestLandmark model (ReplicatedStorage.NestLandmark, cloned locally;
--   a greybox with the same names until it is there) and a code sign board on the bowl's front. The egg is 1.3x and
--   sits in the bed at 2.15, breathes every 4.5 s; the blanket folds, drapes (tucked, unrolling in .6 s) or slips
--   (ready); the moon and the awning sway, the awning lifts 6 degrees when ready; the moon lantern is the nest's light
--   (off by day, lit at dusk, gold and pulsing when ready). Prompt at (0, 1, -3.5), pill fixed at 5.2, Bear on the mat
--   at (-2.9, 0, -2.0), the Show me pin at 8.2. Off (or anywhere else): the twig nest as before.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Onboard=require(Shared:WaitForChild("Onboard"))
local Nest=require(Shared:WaitForChild("Nest"))
local UICopy=require(Shared:WaitForChild("UICopy"))
local Toys=require(Shared:WaitForChild("ToyCatalog"))
local Wear=require(Shared:WaitForChild("WearableCatalog"))
local Pets=require(Shared:WaitForChild("PetCatalog"))
local LifeArt=require(Shared:WaitForChild("LifeArt"))
local Models=require(Shared:WaitForChild("EggModels")).Egg
local Stations=require(script.Parent:WaitForChild("LoungeStations"))
local Corner=require(Shared:WaitForChild("EggCorner"))
local Land=require(Shared:WaitForChild("NestLandmark"))
local Client={};Client.__index=Client
Client.Folder="EggDropSleepyNest"
Client.Event="NestEvent"
Client.Claim="NestClaim"
Client.Spot=Nest.Spot                  -- the plaza's east rim (spot A); the walk map's ground, raycast when it can be
Client.Facing=Nest.Facing              -- the plaza's middle: root -Z points at it
Client.PromptAt=Vector3.new(0,1,-Nest.Front) -- root-local: the prompt, and where the Bear's prints end (outside the pets' box)
-- Beta 14 D1 (Fable R2): beside the Eggs station the station side carries nothing; the Bear curls on the outer (-X)
-- side in front, the sign stands behind it. PENDING Studio probe P1 (scripts/probe_nest_spot.luau).
Client.BearSpot=Vector3.new(-2.2,0,-1.4) -- the Bear curls here (was +2.2 at the plaza rim)
Client.SignAt=Vector3.new(-1.7,0,1.6)  -- the sign post and board, root-local X and Z (was -1.95, -1.03)
Client.EggBase=.64     -- .06 into the straw bed
Client.Scale=table.freeze({small=1.25,glow=1.6,rocking=2,ready=2})
Client.Halo=table.freeze({glow={.25,.5},rocking={.45,.7},ready={.85,.85}})
Client.HaloStill=table.freeze({glow=.3,rocking=.5,ready=.8})
Client.ZzzEvery=table.freeze({small=4,glow=3,rocking=3})
Client.Pending=8        -- a claim with no answer this long settles back
Client.BusyWait=2       -- a refused claim: the prompt returns after this long
Client.TuckSeconds=2.6
Client.TuckedLabel=4
Client.TuckedFirstLabel=6 -- the first tuck-in ever holds its line longer (GARDEN-LIFE-NEST-LOOK 5)
Client.NextLabel=5 -- beta 14 Q2: a new egg's beat holds 5 s (was 3)
Client.HatchSeconds=2
Client.StageTween=.6
Client.DropSeconds=.35
Client.Prompt=4.5       -- studs: only within reach of the nest's front (beta 14 D1: 6, beside the station now)
Client.PromptOffset=Vector2.new(0,72) -- under the nest, never on the egg
Client.Near=8           -- studs: the "Inside:" line
-- Beta 14 Q2: the one pill. At most 220 px, wrapping at 196, 14 px for the clock and "Hatch me!", 13 for sentences (12
-- if a sentence would need three lines), two lines at most; 28 px tall for one line, 46 for two. The board is 220 x 80
-- with the pill at its bottom, so it lifts 34 px over the need bubble without moving anything else.
Client.Pill=table.freeze({max=220,wrap=196,pad=12,min=120,one=28,two=46,text=14,sentence=13,small=12,lift=34,board=Vector2.new(220,80)})
-- The egg corner's "?" disc on the napping pill (EGG-CORNER-LOOK 3): drawn 24, hit 44, 6 px from the clock; two
-- first-time pulses to 1.15 (coach bit nestHelp).
Client.Help=table.freeze({drawn=24,hit=44,gap=6,pulse=1.15,pulseSeconds=.5,pulses=2})
-- Shown within `near` studs of the player's root (not the camera), fading in to `full`.
Client.Show=table.freeze({near=table.freeze({12,10}),ready=table.freeze({18,15}),beat=table.freeze({18,18})})
Client.BeatIn=.25;Client.BeatOut=.4
Client.BubbleNear=6     -- studs, the pet from the nest's root: the need bubble and the pill would overlap
Client.BubbleAfter=.3   -- the bubble comes back this long after a beat
Client.HaloDistance=80;Client.ZzzDistance=40
-- Beta (12) QA O1 (Fable, GARDEN-LIFE-NEST-LOOK.md section 5): the nest's words by role, so a wording change is a
-- UICopy edit only. `how` explains the egg until the first hatch; `tuckedFirst` is the first tuck-in ever.
Client.Copy=table.freeze({how="onb3.nest.how",howPlain="onb3.nest.howPlain",tucked="onb3.nest.tucked",
	tuckedFirst="onb3.nest.tuckedFirst",next="onb3.nest.next",title="onb3.nest.title",chipReady="onb3.nest.chipReady",
	ready="onb3.nest.ready"})
Client.GroundSlack=1    -- studs: a ground hit further than this from Spot.Y is not the lawn
Client.Assets=table.freeze({
	chip="rbxassetid://114080030018596",egg="rbxassetid://116613877519776",halo="rbxassetid://93444884817210",
	z="rbxassetid://127381504371398"})
-- The remodel's textures (LifeArt: the uploaded ids, or stand-ins until then).
Client.Art=table.freeze({twigs="nestTwigs",fringe="nestFringe",bed="strawBed",wisps="strawWisps",sign="nestSign"})
Client.Spark="rbxasset://textures/particles/sparkles_main.dds"
Client.Color=table.freeze({mound=Color3.fromHex("#3A2616"),rim1=Color3.fromHex("#6B4A2C"),rim2=Color3.fromHex("#5A3D24"),
	rim3=Color3.fromHex("#7D5A38"),straw=Color3.fromHex("#B8974F"),post=Color3.fromHex("#6B4A2B"),board=Color3.fromHex("#A47E50"),
	signInk=Color3.fromHex("#3B2A1A"),egg=Color3.fromHex("#C9B4FF"),halo=Color3.fromHex("#FFF3C4"),gold=Color3.fromHex("#FFE08A"),
	core=Color3.fromHex("#FFF3C4"),cream=Color3.fromHex("#FFF4DC"),ink=Color3.fromHex("#15143A"),stars=Color3.fromHex("#FFC14D"),
	well=Color3.fromHex("#20234A"),text=Color3.fromHex("#FFFFFF")})

local function finite(n)return type(n)=="number"and n==n and n~=math.huge and n~=-math.huge end
local function int(n,low)return finite(n)and n%1==0 and n>=(low or 0)end
local GiftKinds=table.freeze({hat=true,neck=true,toy=true,charm=true,stars=true})

-- ── Pure ─────────────────────────────────────────────────────────────────────────────────────────────────────────
-- A state packet's `public` as a checked view, or nil (no nest, or junk).
function Client.parse(public)
	if type(public)~="table"or not finite(public.at)or not int(public.n)then return nil end
	local gift=type(public.gift)=="table"and public.gift or {}
	local kind=if GiftKinds[gift.kind]then gift.kind else "stars"
	local item=if kind~="stars"and type(gift.item)=="string"and #gift.item>0 and #gift.item<=64 then gift.item else nil
	if kind~="stars"and not item then kind="stars"end
	local readyAt=if finite(public.readyAt)then public.readyAt else public.at+Nest.Seconds
	return{at=public.at,readyAt=readyAt,n=public.n,egg=if int(public.egg,1)then public.egg else public.n+1,
		week=public.week==true or public.n>=Nest.WeekLength,tucked=public.tucked==true,
		pet=if type(public.pet)=="string"then public.pet else "",
		gift={kind=kind,item=item,stars=if int(gift.stars)then gift.stars else 0}}
end
-- Seconds left (0 = ready) and the look at server time `now`.
function Client.left(view,now)return math.max(0,view.readyAt-now)end
function Client.look(view,now)
	if Client.left(view,now)<=0 then return "ready"end
	return Nest.look({at=view.readyAt-Nest.Seconds},now)or "small"
end
-- The label clock ("Ready in 7 h.") and the chip clock ("7 h"), from Nest.countdown.
function Client.clock(left)
	local kind,value=Nest.countdown(left)
	if kind=="hours"then return UICopy.get("onb3.nest.hours",{hours=value}),kind end
	if kind=="minutes"then return UICopy.get("onb3.nest.minutes",{minutes=value}),kind end
	return UICopy.get("onb3.nest.ready"),"ready"
end
function Client.chipText(left)
	local kind,value=Nest.countdown(left)
	if kind=="hours"then return UICopy.get("onb3.nest.chipHours",{hours=value}),kind end
	if kind=="minutes"then return UICopy.get("onb3.nest.chipMinutes",{minutes=value}),kind end
	return UICopy.get(Client.Copy.chipReady),"ready"
end
-- The gift's name for the label and the reward ("Bow Tie", "Ball", "Nest Charm"); nil for Stars.
function Client.itemName(kind,item,pet)
	if type(item)~="string"then return nil end
	if kind=="charm"then return UICopy.get("onb3.charm.name")end
	if kind=="toy"then local toy=Toys.ById[item];return toy and toy.name or nil end
	if kind=="hat"or kind=="neck"then
		local ok,found=pcall(function()return Wear.forPet(pet,math.huge).byId[item]end)
		return if ok and found then found.name else nil
	end
	return nil
end
-- The pet's display name for a view, or nil.
function Client.petName(view)
	return if type(view)=="table"then Pets.petName(view.pet)else nil
end
-- "{pet}'s egg naps for {hours} hours. Come back to hatch a gift." ({hours} is Nest.Hours, never a typed 8).
function Client.how(view)
	local name=Client.petName(view)
	if name then return UICopy.get(Client.Copy.how,{pet=name,hours=Nest.Hours})end
	return UICopy.get(Client.Copy.howPlain,{hours=Nest.Hours})
end
-- The label's second line and its kind: the explainer until the first hatch (n == 0, shown at any distance the label
-- shows), then what is inside (within Client.Near only).
function Client.secondLine(view)
	if view.n==0 then return Client.how(view),"how"end
	return Client.inside(view),"inside"
end
-- "Inside: {item} and {stars} Stars." or "Inside: {stars} Stars."
function Client.inside(view)
	local name=Client.itemName(view.gift.kind,view.gift.item,view.pet)
	if name then return UICopy.get("onb3.nest.inside",{item=name,stars=view.gift.stars})end
	return UICopy.get("onb3.nest.insideStars",{stars=view.gift.stars})
end
-- Pure (beta 14 Q2): the pill's see-through for a distance, shown within `near` and fading in to `full`; nil = no root.
function Client.fade(distance,near,full)
	if type(distance)~="number"or distance~=distance or distance>near then return 1 end
	if near<=full then return 0 end
	return math.clamp((distance-full)/(near-full),0,1)
end
-- Pure (beta 14 Q2): the pill's one message, first true row wins (WORLD-AND-NEST-LOOK 4):
--   1 to 3  beats (ctx.beat = {row, text}): the first tuck-in ever, a later one, a new egg landed
--   4  ready: "Hatch me!", gold      5  untucked, no egg hatched yet: the explainer
--   6  within Near and n >= 1: what is inside      7  the clock
-- ctx = {beat, look, left, near (studs), tucked, bubble (the need bubble shows with the pet near), compact}.
-- Returns {row, text, size, gold, onTop, show = {near, full}, hidden, lift}.
function Client.row(view,ctx)
	local P=Client.Pill
	if ctx.beat then
		return{row=ctx.beat.row,text=ctx.beat.text,size=P.sentence,gold=false,onTop=true,show=Client.Show.beat,hidden=false,lift=false}
	end
	if ctx.look=="ready"then
		return{row=4,text=UICopy.get(Client.Copy.ready),size=if ctx.compact then P.sentence else P.text,gold=true,onTop=false,show=Client.Show.ready,
			hidden=false,lift=ctx.bubble==true}
	end
	local hidden=ctx.bubble==true
	-- The egg corner: the explainer and "Inside" live in the "?" card; the napping pill is the clock and the disc.
	if ctx.corner then
		return{row=7,text=(Client.clock(ctx.left or 0)),size=if ctx.compact then P.sentence else P.text,gold=false,onTop=false,show=Client.Show.near,
			hidden=hidden,lift=false,help=true}
	end
	if not ctx.tucked and view.n==0 then
		return{row=5,text=Client.how(view),size=P.sentence,gold=false,onTop=false,show=Client.Show.near,hidden=hidden,lift=false}
	end
	if view.n>=1 and type(ctx.near)=="number"and ctx.near<=Client.Near then
		return{row=6,text=Client.inside(view),size=P.sentence,gold=false,onTop=false,show=Client.Show.near,hidden=hidden,lift=false}
	end
	return{row=7,text=(Client.clock(ctx.left or 0)),size=if ctx.compact then P.sentence else P.text,gold=false,onTop=false,show=Client.Show.near,
		hidden=hidden,lift=false}
end
-- Pure (beta 14 Q2): the pill's size for text `textW` px wide at its size: lines (1 or 2), width, height, and whether
-- the text must drop to the small size first (a sentence that would need three lines).
function Client.pillSize(textW,smallW)
	local P=Client.Pill
	local function lines(w)return if w<=P.wrap then 1 else math.ceil(w*1.15/P.wrap)end
	local n,small=lines(textW),false
	if n>2 and smallW then n,small=math.min(2,lines(smallW)),true end
	n=math.min(n,2)
	if n==1 then return 1,math.clamp(math.ceil(textW)+P.pad*2,P.min,P.max),P.one,small end
	return 2,P.max,P.two,small
end
-- Pure (beta 14 D1): the Hatch eggs screen's quiet top row from summary() (nil: no row).
function Client.menuRow(summary)
	if type(summary)~="table"or type(summary.left)~="number"then return nil end
	local ready=summary.left<=0
	local clock=Client.clock(summary.left)
	local title=UICopy.get(Client.Copy.title)
	return{title=title,clock=clock,ready=ready,label=title..", "..clock}
end
-- The egg's pose for a look at clock t: scale multiplier, rock (degrees), hop (studs), squash Y, halo opacity.
-- Reduced Motion: no rock, hop or breath; the halo steady.
function Client.motion(look,t,reduced)
	local halo=Client.Halo[look]
	if reduced then return 1,0,0,1,Client.HaloStill[look]or 0 end
	if look=="glow"then
		local wave=.5-.5*math.cos(t/3.2*2*math.pi)
		return 1+.03*wave,0,0,1,halo[1]+(halo[2]-halo[1])*wave
	elseif look=="rocking"then
		local cycle=2/.9+1.2
		local p=t%cycle
		local rock=if p<2/.9 then 7*math.sin(p*.9*2*math.pi)else 0
		local wave=.5-.5*math.cos(t/3.2*2*math.pi)
		return 1,rock,0,1,halo[1]+(halo[2]-halo[1])*wave
	elseif look=="ready"then
		local p=t%1.6
		local hop=if p<.4 then .35*math.sin(p/.4*math.pi)else 0
		local rock=if p<.8 then 10*math.sin(p/.8*2*math.pi)else 0
		local squash=if p>=.4 and p<.48 then .92 else 1
		return 1,rock,hop,squash,halo[1]
	end
	return 1,0,0,1,0
end
-- Back Out over 0..1 (the stage change).
function Client.backOut(x)local c1=1.70158;local c3=c1+1;return 1+c3*(x-1)^3+c1*(x-1)^2 end
-- The root frame on ground `y`: -Z at the dais.
function Client.frame(y,spot,facing)
	spot,facing=spot or Client.Spot,facing or Client.Facing
	local at=Vector3.new(spot.X,y,spot.Z)
	return CFrame.lookAt(at,Vector3.new(facing.X,y,facing.Z))
end
-- The 21 nest parts, root-local (GARDEN-LIFE-NEST-LOOK 4; degrees, root -Z the front). shape: "cylinder" (axis along
-- X), "block" or "plate" (a see-through decal plate). texture = {key, faces, u, v, offsetU}; decal = {key, faces}.
local Face=Enum.NormalId
local CURVED={Face.Top,Face.Bottom,Face.Front,Face.Back} -- a Cylinder's round side (its caps are Left and Right)
local BOTH={Face.Front,Face.Back}
local ROLL={Face.Top,Face.Bottom,Face.Front,Face.Back,Face.Left,Face.Right} -- a rim roll: its round side and both caps
Client.SignYaw=50 -- degrees about root Y (beta 14 D1, Fable R2: the Front looks forward-left; was -40)
Client.SignPostTop=1.08 -- the post's top (studs over the nest root), just into the board's bottom edge
function Client.parts()
	local list={}
	local rad=math.rad
	local up=CFrame.Angles(0,0,math.pi/2) -- a Cylinder's axis is X: turn it up (its Right cap then faces up)
	-- FABLE-REVIEW-R1 3: the mound and the rim rolls are Material Wood (the twig Texture stays on top), and each roll's
	-- end caps carry the twigs too: a plain-coloured cap poking past its neighbour read as a flat brown slat.
	table.insert(list,{name="NestMound",shape="cylinder",size=Vector3.new(.42,3.5,3.5),cf=CFrame.new(0,.21,0)*up,color="mound",
		texture={"twigs",CURVED,2.4,1.2,0},shadow=true,wood=true})
	for k=0,7 do
		local a=rad(22.5+45*k)
		local even=k%2==0
		local r,y=if even then 1.42 else 1.50,if even then .56 else .62
		table.insert(list,{name="NestRim"..(k+1),shape="cylinder",size=Vector3.new(1.30,.66,.66),
			cf=CFrame.new(math.sin(a)*r,y,math.cos(a)*r)*CFrame.Angles(0,a,0)*CFrame.Angles(0,0,rad(if even then 7 else -7)),
			color="rim"..(k%3+1),texture={"twigs",ROLL,2.4,1.2,.37*k},wood=true})
	end
	table.insert(list,{name="NestStraw",shape="cylinder",size=Vector3.new(.30,2.36,2.36),cf=CFrame.new(0,.55,0)*up,color="straw",
		decal={"bed",{Face.Right}}})
	for k=0,5 do
		local a=rad(15+60*k)
		table.insert(list,{name="NestFringe"..(k+1),shape="plate",size=Vector3.new(1.9,1.05,.04),
			cf=CFrame.new(math.sin(a)*1.62,.78,math.cos(a)*1.62)*CFrame.Angles(0,a,0)*CFrame.Angles(0,rad(if k%2==0 then 8 else -8),0)
				*CFrame.Angles(rad(22),0,0),decal={"fringe",BOTH}})
	end
	for k=0,2 do
		local a=rad(40+120*k)
		table.insert(list,{name="NestTuft"..(k+1),shape="plate",size=Vector3.new(1.3,.62,.04),
			cf=CFrame.new(math.sin(a)*1.05,.98,math.cos(a)*1.05)*CFrame.Angles(0,a,0)*CFrame.Angles(rad(15),0,0),decal={"wisps",BOTH}})
	end
	-- STUDIO-CHECK-R2: the board has words on both faces, so a post behind it hid the "e" of "egg" from the arrival path.
	-- The post stops under the board (its lowest edge is about 1.0 after the 6 degree tilt), which sits on its top.
	table.insert(list,{name="NestSignPost",shape="block",size=Vector3.new(.14,Client.SignPostTop,.14),cf=CFrame.new(Client.SignAt.X,Client.SignPostTop/2,Client.SignAt.Z),color="post",wood=true})
	-- The board is painted on both faces and yawed 40 toward the egg (Studio check beta 12: at 20, one face, people
	-- coming in from the arrival path's mouth saw its edge and back). The Front reads from the prompt point and the
	-- plaza's middle, the Back from the arrival path's mouth, each within about 35 degrees (NestClient.spec).
	table.insert(list,{name="NestSign",shape="block",size=Vector3.new(1.3,.8,.08),
		cf=CFrame.new(Client.SignAt.X,1.45,Client.SignAt.Z)*CFrame.Angles(0,rad(Client.SignYaw),0)*CFrame.Angles(rad(6),0,0),color="board",wood=true,
		decal={"sign",BOTH},sign=true})
	return list
end
-- The sign's words: "{pet}'s egg" for the pet stored at land, "Your egg" without a name.
function Client.signText(view)
	local name=Client.petName(view)
	if name then return UICopy.get("onb3.nest.sign",{pet=name})end
	return UICopy.get("onb3.nest.signPlain")
end

-- ── Instances ────────────────────────────────────────────────────────────────────────────────────────────────────
local function inert(p)
	p.Anchored=true
	p.CanCollide=false;p.CanQuery=false -- CanQuery only goes false once CanCollide is
	p.CanTouch=false;p.CastShadow=false
	p.Massless=true
	return p
end
local function make(class,parent,props)
	local object=Instance.new(class)
	for key,value in pairs(props or {})do object[key]=value end
	object.Parent=parent
	return object
end
local function corner(parent)make("UICorner",parent,{CornerRadius=UDim.new(1,0)})end
local function label(parent,name,size,color)
	return make("TextLabel",parent,{Name=name,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.FredokaOne,
		TextSize=size,TextColor3=color,TextWrapped=false})
end

function Client.mount(deps)
	if not Onboard.ceiling()then return nil end
	local self=setmetatable({d=deps,isOpen=false,connections={},clock=0,pinged={},beats={}},Client)
	self.world=deps.world or workspace
	self.now=deps.now or function()return workspace:GetServerTimeNow()end
	self.changed=Onboard.changed("nest"):Connect(function()self:sync()end)
	-- The egg corner moves the nest (and drops the station's Yield): a flip closes and re-opens it where it now stands.
	self.cornerChanged=Onboard.changed("corner"):Connect(function()self:relocate()end)
	self.landmarkChanged=Onboard.changed("landmark"):Connect(function()self:relocate()end)
	self:sync()
	return self
end
function Client:sync()
	local on=not self.dead and Onboard.on("nest")
	if on==self.isOpen then return end
	if on then
		local ok,problem=pcall(self.open,self)
		if not ok then warn("[Nest] not opened: "..tostring(problem));self.dead=true;pcall(self.close,self)end
	else self:close()end
end
-- The egg corner's switch and the nest's place, read when the nest opens (specs inject deps.corner / deps.split).
function Client:cornerOn()
	if self.d.corner~=nil then return self.d.corner()==true end
	return Corner.on()
end
function Client:placeNow()
	local on=self:cornerOn()
	local split=if self.d.split~=nil then self.d.split()==true else nil
	local spot=Corner.nestSpot(on,split)
	local landmarkOn=if self.d.landmark~=nil then self.d.landmark()==true else Land.on()
	return on,spot,if on then Corner.nestFacing()else Client.Facing,Land.applies(landmarkOn,on and spot==Corner.NestSpot)
end
-- A corner flip while open: close and open again at the new place (the view comes back with the next sync).
function Client:relocate()
	if not self.isOpen or self.dead then return end
	local on,spot,_,landmark=self:placeNow()
	if on==self.corner and spot==self.spot and landmark==self.landmark then return end
	-- Studio check R8: the corner off takes the "?" card with it (the nest only moves, so nothing else would close it).
	if self.corner and not on and self.d.helpClose then pcall(self.d.helpClose)end
	self:close()
	self:sync()
end
function Client:open()
	self.isOpen=true
	self.synced=false
	local d=self.d
	self.corner,self.spot,self.facing,self.landmark=self:placeNow()
	-- Root-local numbers for this nest (the landmark's, or the twig nest's).
	self.promptAt=if self.landmark then Land.PromptAt else Client.PromptAt
	self.bearSpot=if self.landmark then Land.BearSpot else Client.BearSpot
	self.eggBase=if self.landmark then Land.EggBase else Client.EggBase
	self.eggScales=if self.landmark then Land.EggScales else Client.Scale
	-- Beta 14 D1: the station's E / ButtonX steps aside where the nest's prompt can act and is nearer. Not in the egg
	-- corner: the station is the machine, far from the nest.
	self.yield=function(position,part)return self:claims(position,part)end
	if not self.corner then Stations.Yield.Eggs=self.yield end
	-- Per-frame work only while on (off: the switch is watched, nothing else).
	if d.step~=false and not self.heartbeat then
		-- R5: the connection has its own field (self.beat is the speech beat; sharing it crashed the first frame).
		self.heartbeat=RunService.Heartbeat:Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok then warn("[Nest] "..tostring(problem));self.dead=true;pcall(self.close,self)end
		end)
	end
	local function on(signal,fn)table.insert(self.connections,signal:Connect(fn))end
	local function receive(packet)
		local ok,problem=pcall(self.receive,self,packet)
		if not ok then warn("[Nest] "..tostring(problem))end
	end
	local function bind(remote)
		if not self.isOpen then return end
		if remote.Name==Client.Event and not self.eventRemote then
			self.eventRemote=remote;on(remote.OnClientEvent,receive)
		elseif remote.Name==Client.Claim and not self.claimRemote then
			self.claimRemote=remote
		else return end
		self:ask()
	end
	for _,name in ipairs({Client.Event,Client.Claim})do
		local remote=d.remotes:FindFirstChild(name)
		if remote then bind(remote)end
	end
	on(d.remotes.ChildAdded,bind)
	local player=d.player
	if player==nil then player=game:GetService("Players").LocalPlayer end
	if player and player.CharacterAdded then on(player.CharacterAdded,function()self.synced=false;self:ask()end)end
end
function Client:ask()
	if self.synced or not self.isOpen or not self.eventRemote or not self.claimRemote then return end
	self.synced=true
	self.claimRemote:FireServer({kind="sync"})
end
function Client:send(kind)
	if not self.claimRemote then return false end
	self.claimRemote:FireServer({kind=kind})
	return true
end
function Client:clear()
	-- The landmark is the server's shared copy: put it back as it was, and forget it (code review of 443346b).
	pcall(self.restLandmark,self)
	self.landmarkState=nil
	if self.folder then self.folder:Destroy();self.folder=nil end
	if self.hosted then self.hosted:Destroy();self.hosted=nil end
	self.signWords=nil
	if self.chip then self.chip.button:Destroy();self.chip=nil end
	self.view,self.drawn,self.egg,self.hatching,self.waiting,self.queued,self.tuck=nil,nil,nil,nil,nil,nil,nil
	self.beat,self.beatUntil=nil,nil
	table.clear(self.beats)
end
function Client:close()
	self.isOpen=false
	if self.yield and Stations.Yield.Eggs==self.yield then Stations.Yield.Eggs=nil end
	self.yield=nil
	if self.heartbeat then self.heartbeat:Disconnect();self.heartbeat=nil end
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	table.clear(self.connections)
	self:clear()
	self.eventRemote,self.claimRemote,self.synced=nil,nil,false
end
function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true;self.dead=true
	self.changed:Disconnect()
	if self.cornerChanged then self.cornerChanged:Disconnect()end
	if self.landmarkChanged then self.landmarkChanged:Disconnect()end
	self:close()
end
function Client:play(name,speed,volume)
	local audio=self.d.audio
	if audio then pcall(audio.play,audio,name,speed or 1,volume or .5)end
end
function Client:reduced()return self.d.reduced~=nil and self.d.reduced()==true end

-- Packets -------------------------------------------------------------------------------------------------------
function Client:receive(packet)
	if type(packet)~="table"or not self.isOpen then return end
	if packet.kind=="state"then
		local view=Client.parse(packet.public)
		if self.hatching then self.queued={view=view};return end -- the new egg lands when the hatch is over
		self:set(view)
	elseif packet.kind=="claimed"then
		self:claimed(type(packet.receipt)=="table"and packet.receipt or {})
	elseif packet.kind=="refused"then
		if packet.of=="claim"then
			self.waiting=nil
			self.promptAfter=self.clock+Client.BusyWait
		end
		-- A tuck refused as "Tucked" undoes nothing (it is tucked); any other refusal (Lost, Off, Busy...) gives Tuck in back.
		if packet.of=="tuck"and packet.reason~="Tucked"then self.tuck=nil end
	end
end
-- A new view: drawn on first sight (no tween), moved on, or everything goes (nil).
function Client:set(view,landing)
	if view==nil then self:clear();return end
	local before=self.view
	self.view=view
	if before and(before.at~=view.at or before.n~=view.n)then self.tuck,self.waiting=nil,nil end
	if not self.drawn then self:draw()end
	self:paintSign()
	if landing then
		self.drop={t=0}
		self:play("land",1,.5)
		self:say(UICopy.get(Client.Copy.next,{hours=Nest.Hours}),Client.NextLabel,3)
		self.shownScale=nil
	end
	self:paint(true)
end

-- Drawing -------------------------------------------------------------------------------------------------------
-- The sign's words, written only when they change (the pet stored at land).
function Client:paintSign()
	local list=self.signWords
	if not list or not self.view then return end
	local text=Client.signText(self.view)
	for _,words in ipairs(list)do if words.Text~=text then words.Text=text end end
end
function Client:groundY()
	local spot=self.spot or Client.Spot
	local y=spot.Y
	local ground=self.d.ground
	if ground then
		local ok,hit=pcall(ground,spot)
		-- Only the lawn: a hit far from the walk map's ground is a pet, a player or a prop standing there.
		if ok and finite(hit)and math.abs(hit-spot.Y)<=Client.GroundSlack then y=hit end
	end
	return y
end
function Client:draw()
	local folder=make("Folder",self.world,{Name=Client.Folder})
	self.folder=folder
	self.root=Client.frame(self:groundY(),self.spot,self.facing)
	-- The landmark: the server's root (NestRoot), so this nest and the idle landmark share one frame (code review of
	-- de31e8a); a re-seat is picked up in step().
	if self.landmark then
		local model=self:landmarkModelNow()
		local root=model and model:GetAttribute("NestRoot")
		if typeof(root)=="CFrame"then self.root=root end
	end
	for _,spec in ipairs(if self.landmark then Client.landmarkParts()else Client.parts())do self:drawPart(folder,spec)end
	if self.landmark then self:drawLandmark(folder)end
	if self.corner and self.spot==Corner.NestSpot then self:drawGround(folder)end
	self:drawEgg(folder)
end
-- One code part of the nest from its spec (the twig parts, or the landmark's sign board with the words).
function Client:drawPart(folder,spec)
	do
		local p=inert(make("Part",nil,{Name=spec.name}))
		p.Material=if spec.wood then Enum.Material.Wood else Enum.Material.SmoothPlastic
		p.Size=spec.size
		p.CFrame=self.root*spec.cf
		if spec.shadow then p.CastShadow=true end -- the mound alone: the nest sits on the marble
		if spec.shape=="plate"then p.Transparency=1 else p.Color=Client.Color[spec.color]end
		if spec.shape=="cylinder"then p.Shape=Enum.PartType.Cylinder end
		local texture=spec.texture
		if texture then
			local id=LifeArt.id(Client.Art[texture[1]])
			for _,face in ipairs(texture[2])do
				make("Texture",p,{Name="Twigs",Texture=id,Face=face,StudsPerTileU=texture[3],StudsPerTileV=texture[4],OffsetStudsU=texture[5]})
			end
		end
		local decal=spec.decal
		local id=decal and LifeArt.id(Client.Art[decal[1]])
		if id then
			for _,face in ipairs(decal[2])do make("Decal",p,{Name="Art",Texture=id,Face=face})end
		end
		if spec.sign then
			-- The pet's name on the board's right 62% of each face; the burnt crescent is in the texture at the left.
			self.signWords={}
			for _,face in ipairs(BOTH)do
				local gui=make("SurfaceGui",p,{Name=if face==Face.Front then "Words"else "WordsBack",Face=face,
					SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud,PixelsPerStud=50,LightInfluence=1,AlwaysOnTop=false,ClipsDescendants=true})
				local words=make("TextLabel",gui,{Name="Name",BackgroundTransparency=1,Position=UDim2.fromScale(.34,.14),
					Size=UDim2.fromScale(.63,.72),Font=Enum.Font.FredokaOne,TextColor3=Client.Color.signInk,TextScaled=true,
					TextWrapped=true,Text=""})
				make("UITextSizeConstraint",words,{MaxTextSize=22})
				table.insert(self.signWords,words)
			end
		end
		p.Parent=folder
	end
end
function Client:drawEgg(folder)
	-- The egg: an invisible anchor at its base carries the halo, the label, the light and the emitters; the shells
	-- (or a lilac ball until the meshes load) are posed from it every frame.
	local anchor=inert(make("Part",nil,{Name="SleepyEgg",Transparency=1,Size=Vector3.new(.2,.2,.2)}))
	anchor.CFrame=self.root*CFrame.new(0,self.eggBase or Client.EggBase,0)
	anchor.Parent=folder
	local egg={anchor=anchor,shells={}}
	-- A Ball part is always round: a block with a sphere mesh stretches to the egg's 1 x 1.3.
	egg.ball=inert(make("Part",nil,{Name="SleepyEggBody",Color=Client.Color.egg,Material=Enum.Material.SmoothPlastic,
		Size=Vector3.new(1,1.3,1)}))
	make("SpecialMesh",egg.ball,{Name="Shape",MeshType=Enum.MeshType.Sphere})
	egg.ball.Parent=folder
	egg.halo=make("BillboardGui",anchor,{Name="Halo",LightInfluence=0,AlwaysOnTop=false,MaxDistance=Client.HaloDistance,Enabled=false})
	egg.haloImage=make("ImageLabel",egg.halo,{Name="Glow",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=Client.Assets.halo,
		ImageColor3=Client.Color.halo,ImageTransparency=1})
	egg.light=make("PointLight",anchor,{Name="Glow",Range=6,Brightness=.4,Color=Client.Color.halo,Enabled=false,Shadows=false})
	egg.zzz=make("ParticleEmitter",anchor,{Name="Zzz",Texture=Client.Assets.z,Rate=0,Lifetime=NumberRange.new(2.2),Speed=NumberRange.new(.6),
		Rotation=NumberRange.new(-12,12),LightInfluence=0,Acceleration=Vector3.new(if self.landmark then -.25 else .25,0,0),EmissionDirection=Enum.NormalId.Top,
		Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,.6)}),
		Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.09,0),NumberSequenceKeypoint.new(.73,0),NumberSequenceKeypoint.new(1,1)})})
	egg.sparks=make("ParticleEmitter",anchor,{Name="Sparks",Texture=Client.Spark,Rate=0,Lifetime=NumberRange.new(.6,1),Speed=NumberRange.new(.6,1.4),
		SpreadAngle=Vector2.new(180,180),LightEmission=1,LightInfluence=0,Color=ColorSequence.new(Client.Color.gold),
		Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(1,0)})})
	egg.stillZ=make("BillboardGui",anchor,{Name="StillZ",LightInfluence=0,AlwaysOnTop=false,MaxDistance=Client.ZzzDistance,Enabled=false,Size=UDim2.fromOffset(20,20)})
	make("ImageLabel",egg.stillZ,{Name="Z",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=Client.Assets.z})
	-- The label (beta 14 Q2): one cream pill (gold when ready) with one message, Client.row. The board is a fixed
	-- 220 x 80 with the pill at its bottom (SizeOffset lifts the board so its bottom sits where the old pill's top
	-- line did), so a one-line pill never jumps when the text changes. MaxDistance is a backstop; paintPill shows it.
	local P=Client.Pill
	-- The egg corner: a billboard under a workspace part never gets clicks, so the board lives in deps.gui() (PlayerGui)
	-- with the egg's anchor as its Adornee; it goes with the folder (clear()).
	local host=if self.corner and self.d.gui then self.d.gui()else nil
	local board=make("BillboardGui",host or anchor,{Name="Label",LightInfluence=0,AlwaysOnTop=false,MaxDistance=60,Size=UDim2.fromOffset(P.board.X,P.board.Y),
		SizeOffset=Vector2.new(0,.5),Enabled=false,Adornee=anchor,Active=host~=nil,ResetOnSpawn=false})
	if host then self.hosted=board end
	local pill=make("Frame",board,{Name="Pill",AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,1),Size=UDim2.fromOffset(160,P.one),
		BackgroundColor3=Client.Color.cream,BorderSizePixel=0})
	corner(pill)
	egg.pillStroke=make("UIStroke",pill,{Color=Client.Color.ink,Thickness=2})
	egg.clock=label(pill,"Clock",P.text,Client.Color.ink)
	make("UIPadding",pill,{PaddingLeft=UDim.new(0,P.pad),PaddingRight=UDim.new(0,P.pad)})
	egg.board,egg.pill=board,pill
	if self.corner then self:buildHelp(egg)end
	-- The prompt, at the front of the nest (where the Bear's prints end).
	local spot=inert(make("Part",nil,{Name="SleepyNestPrompt",Transparency=1,Size=Vector3.new(.2,.2,.2)}))
	spot.CFrame=self.root*CFrame.new(self.promptAt or Client.PromptAt)
	spot.Parent=folder
	egg.prompt=make("ProximityPrompt",spot,{Name="NestPrompt",ObjectText=UICopy.get(Client.Copy.title),ActionText=UICopy.get("onb3.nest.tuck"),
		HoldDuration=0,MaxActivationDistance=Client.Prompt,RequiresLineOfSight=false,Enabled=false,UIOffset=Client.PromptOffset})
	local triggered=egg.prompt.Triggered
	if typeof(triggered)=="RBXScriptSignal"then
		table.insert(self.connections,triggered:Connect(function()
			local ok,problem=pcall(self.act,self)
			if not ok then warn("[Nest] "..tostring(problem))end
		end))
	end
	self.egg=egg
	self.drawn=true
	self:meshes()
end
-- ── The Sleepy Nest landmark ─────────────────────────────────────────────────────────────────────────────────────
-- Its sign board, a code part with the words, on the bowl's front (LOOK 1): the only code part besides the egg.
function Client.landmarkParts()
	local S=Land.Sign
	return{{name="NestSign",shape="block",size=S.size,cf=CFrame.new(S.centre)*CFrame.Angles(math.rad(S.tiltBack),0,0),color="board",wood=true,
		decal={"sign",BOTH},sign=true}}
end
Client.LandmarkNames=table.freeze({"Body","Awning","Moon","BlanketDraped","BlanketSlipped","BlanketFolded","Collider"})
Client.LandmarkMoving=table.freeze({"Awning","Moon","BlanketDraped","BlanketSlipped","BlanketFolded"})
-- The daylight the moon follows, from HollowClock's real shape: daylight() when it is there, else lastDaylight, else
-- the second value of sample(now). 1 (day) when none answers.
function Client.daylightFrom(Clock,now)
	if type(Clock)~="table"then return 1 end
	if type(Clock.daylight)=="function"then
		local ok,value=pcall(Clock.daylight)
		if ok and type(value)=="number"then return value end
	end
	if type(Clock.lastDaylight)=="number"then return Clock.lastDaylight end
	if type(Clock.sample)=="function"then
		local ok,_,value=pcall(Clock.sample,now or workspace:GetServerTimeNow())
		if ok and type(value)=="number"then return value end
	end
	return 1
end
function Client:daylight()
	if self.d.daylight then return self.d.daylight()end
	local ok,Clock=pcall(function()return require(script.Parent:WaitForChild("HollowClock"))end)
	return Client.daylightFrom(if ok then Clock else nil)
end
-- The shared model (the server's one copy, code review of 443346b): this client animates it locally.
function Client:landmarkModelNow()
	if self.d.landmarkModel then return self.d.landmarkModel()end
	local room=workspace:FindFirstChild("EggDropLounge")
	return room and room:FindFirstChild(Land.Template)
end
-- The moon lantern's light and halo (this client's): it replaces EggNestLight while the landmark stands.
function Client:drawLandmark(folder)
	local data=Land.data()
	local function v(list)return Vector3.new(list[1],list[2],list[3])end
	local lamp=inert(make("Part",nil,{Name="MoonLamp",Transparency=1,Size=Vector3.new(.2,.2,.2)}))
	lamp.CFrame=self.root*CFrame.new(v(data.moonLight))
	lamp.Parent=folder
	local L={data=data,lamp=lamp,fade=0,brightness=0}
	L.light=make("PointLight",lamp,{Name="MoonLight",Color=Land.Moon.night.color,Range=Land.Moon.night.range,Brightness=0,Enabled=false,Shadows=false})
	L.halo=make("BillboardGui",lamp,{Name="MoonHalo",LightInfluence=0,AlwaysOnTop=false,MaxDistance=Client.HaloDistance,Enabled=false,
		Size=UDim2.fromScale(1.6,1.6)})
	L.haloImage=make("ImageLabel",L.halo,{Name="Glow",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=Client.Assets.halo,
		ImageColor3=Land.Moon.night.color,ImageTransparency=1})
	self.landmarkState=L
	self:bindLandmark()
	return L
end
-- Finds the shared model (it may stream in, or be swapped from the greybox to the template): its parts, their rest
-- poses (the server's WorldRestCFrame / RestTransparency) and the pivots, in world space, from its own root.
function Client:bindLandmark()
	local L=self.landmarkState
	if not L then return nil end
	local model=self:landmarkModelNow()
	if model==L.model and(model==nil or model.Parent~=nil)then return L end
	L.model,L.parts,L.rest=model,{},{}
	if not model then return L end
	for _,name in ipairs(Client.LandmarkNames)do
		local part=model:FindFirstChild(name)
		if part then
			L.parts[name]=part
			L.rest[name]={cf=part:GetAttribute("WorldRestCFrame")or part.CFrame,size=part.Size,transparency=part:GetAttribute("RestTransparency")or part.Transparency,
				color=part:GetAttribute("RestColor")or part.Color}
		end
	end
	local root=model:GetAttribute("NestRoot")
	if typeof(root)~="CFrame"then root=self.root end
	local data=L.data
	local function v(list)return Vector3.new(list[1],list[2],list[3])end
	L.root=root
	L.moonPivot=root*v(data.pivots.Moon.at)
	L.moonAxis=root:VectorToWorldSpace(v(data.pivots.Moon.axis or {0,0,1}))
	L.awningPivot=root*v(data.pivots.Awning.at)
	L.awningAxis=root:VectorToWorldSpace(v(data.pivots.Awning.axis or {1,0,0}))
	L.drapePivot=root*v(data.pivots.BlanketDraped.at)
	L.skinState={}
	return L
end
-- Puts the shared model back as the server left it (this client's nest closed: no egg, the switch off, a re-open).
function Client:restLandmark()
	local L=self.landmarkState
	if not L or not L.parts then return end
	for _,name in ipairs(Client.LandmarkMoving)do
		local part,rest=L.parts[name],L.rest[name]
		if part and rest and part.Parent then
			part.CFrame,part.Size,part.Transparency=rest.cf,rest.size,rest.transparency
			if name=="Moon"then
				part.Color=rest.color
				local skin=part:FindFirstChildOfClass("SurfaceAppearance")
				if skin then
					pcall(function()skin.EmissiveStrength=0 end)
					pcall(function()skin.Color=Color3.new(1,1,1)end)
				end
			end
		end
	end
end
-- The blanket for this frame: which of the three shows, the tuck's unroll and the breath's ripple; the moon and the
-- awning sway; the moon lantern's light by the hour and the egg's state (a 3 s linear fade in and out; ready snaps).
function Client:poseLandmark(dt,look,tucked,reduced)
	local L=self:bindLandmark()
	if not L then return end
	local ready=look=="ready"
	local P=L.parts or {}
	if L.model then
		local hasEgg=self.view~=nil and not(self.hatching and self.hatching.t>=Land.Drop)
		local state=Land.blanket(hasEgg,tucked,ready)
		if self.hatching and self.hatching.t<Land.Drop then state="dropping"end
		local function show(name,visible,alpha)
			local part=P[name]
			if not part then return end
			-- The template hides the draped and slipped blankets (Transparency 1); shown, every blanket is opaque.
			local want=if visible then(alpha or 0)else 1
			if part.Transparency~=want then part.Transparency=want end
		end
		local dropAlpha=if state=="dropping"then math.clamp(self.hatching.t/Land.Drop,0,1)else nil
		show("BlanketFolded",state=="folded")
		show("BlanketDraped",state=="draped"or(state=="dropping"and not ready),dropAlpha)
		show("BlanketSlipped",state=="slipped"or(state=="dropping"and ready),dropAlpha)
		-- The draped blanket: unrolls from its lower edge on Tuck in, then follows the breath .15 s late.
		local draped=P.BlanketDraped
		if draped and state=="draped"then
			local unroll=if self.tuck and not reduced then Land.unroll(self.tuck.t)else 1
			local B=Land.Breath
			local _,_,rise=Land.breath(self.clock-B.blanketLag,reduced)
			local ripple=if B.rise>0 then rise/B.rise*B.blanketScale else 0
			local rest=L.rest.BlanketDraped
			local local3=L.root:VectorToObjectSpace(rest.cf.Position-L.drapePivot)
			local scaled=Vector3.new(local3.X*(1+ripple),local3.Y*unroll*(1+ripple),local3.Z*(1+ripple))
			draped.Size=Vector3.new(rest.size.X*(1+ripple),rest.size.Y*unroll*(1+ripple),rest.size.Z*(1+ripple))
			draped.CFrame=(rest.cf-rest.cf.Position)+L.drapePivot+L.root:VectorToWorldSpace(scaled)
		end
		-- Sway.
		local moonAngle,awningAngle=Land.sway(self.clock,ready,reduced)
		local function about(part,pivot,axis,angle)
			if not part then return end
			part.CFrame=CFrame.new(pivot)*CFrame.fromAxisAngle(axis,math.rad(angle))*CFrame.new(-pivot)*L.rest[part.Name].cf
		end
		about(P.Moon,L.moonPivot,L.moonAxis,moonAngle)
		about(P.Awning,L.awningPivot,L.awningAxis,awningAngle)
	end
	-- The moon lantern: lit at dusk and night (a 3 s linear fade with the lamps), gold and pulsing when ready.
	local M=Land.moon(ready,self:daylight())
	if ready then L.fade=1
	elseif M.lit then L.fade=math.min(1,L.fade+dt/3)
	else L.fade=math.max(0,L.fade-dt/3)end
	local lit=if M.lit then M else(if L.fade>0 then Land.Moon.night else M) -- fading out keeps the night look
	local pulse=if ready then Land.pulse(self.clock,reduced)else 1
	L.brightness=lit.brightness*L.fade*pulse
	L.light.Enabled=L.brightness>.01
	L.light.Brightness=L.brightness
	L.light.Range=lit.range
	if lit.color then L.light.Color=lit.color end
	local haloAlpha=lit.haloAlpha*L.fade*pulse
	L.halo.Enabled=lit.halo>0 and haloAlpha>.01
	if lit.halo>0 then
		L.halo.Size=UDim2.fromScale(lit.halo,lit.halo)
		L.haloImage.ImageColor3=lit.color
		L.haloImage.ImageTransparency=1-haloAlpha
	end
	local moon=P.Moon
	if moon and L.rest.Moon then
		local want=if L.fade>0 and lit.color then L.rest.Moon.color:Lerp(lit.color,L.fade)else L.rest.Moon.color
		if moon.Color~=want then moon.Color=want end
		-- The template's moon wears a SurfaceAppearance (Part.Color is ignored under it): its tint and its emissive mask
		-- (game scripts may write Strength and Tint, not the mask). One pcall per property: an engine without one keeps
		-- the others.
		local skin=moon:FindFirstChildOfClass("SurfaceAppearance")
		if skin then
			local strength=L.fade*pulse*(if ready then 1 else .6)
			local tint=if L.fade>0 and lit.color then Color3.new(1,1,1):Lerp(lit.color,L.fade)else Color3.new(1,1,1)
			local seen=L.skinState
			if seen.strength==nil or math.abs(seen.strength-strength)>.01 or seen.tint~=tint then
				seen.strength,seen.tint=strength,tint
				pcall(function()skin.Color=tint end)
				pcall(function()skin.EmissiveStrength=strength end)
				pcall(function()skin.EmissiveTint=lit.color or tint end)
			end
		end
	end
end
-- The landmark's pill and peek: a fixed world offset from the egg's anchor, `height` over the root and PillForward in
-- front of it (Fable R10 2). StudsOffsetWorldSpace is in the adornee's object space (Studio R11: a world vector put the
-- pill 1 behind the root, under the awning leaf); the anchor stands on the root's frame, so this is nest-local.
function Client:landmarkOffset(height)
	return Vector3.new(0,height-(self.eggBase or Land.EggBase),-Land.PillForward)
end
-- Does the shared landmark's root (NestRoot) differ from the one this nest was drawn on?
function Client:landmarkMoved()
	local model=self:landmarkModelNow()
	local root=model and model:GetAttribute("NestRoot")
	return typeof(root)=="CFrame"and self.root~=nil and(root.Position-self.root.Position).Magnitude>.005
end
-- Is this player's nest animating the shared landmark now? (The empty landmark's idle life steps aside then.)
function Client:animatesLandmark()
	return self.isOpen==true and self.landmarkState~=nil
end
-- ── The empty landmark (Studio check R10) ───────────────────────────────────────────────────────────────────────────
-- With no nest of this player's open (no egg, or the nest switched off) the shared landmark keeps its idle life here:
-- the moon by the hour, the moon and awning swaying, the folded quilt, and the sign board on the bowl's rope loops
-- (blank but for its painted moon: Fable R10 4). Only the pill, the prompt and the Zzz go. init steps it every frame with `active` = the landmark stands and this player's nest does not
-- animate it. Its root is the server's (NestRoot). deps as mount: world, reduced, daylight, landmarkModel.
Client.IdleFolder="EggDropSleepyNestIdle"
function Client.idleMount(deps)
	local self=setmetatable({d=deps or {},clock=0,landmark=true,idle=true,isOpen=true,beats={},connections={}},Client)
	self.world=self.d.world or workspace
	return self
end
function Client:idleClose()
	pcall(self.restLandmark,self)
	self.landmarkState=nil
	if self.folder then self.folder:Destroy();self.folder=nil end
	self.signWords,self.root=nil,nil
end
function Client:idleStep(dt,active)
	local model=active and self:landmarkModelNow()
	local root=model and model:GetAttribute("NestRoot")
	if typeof(root)~="CFrame"then
		if self.folder then self:idleClose()end
		return false
	end
	if not self.folder or self.root~=root then
		self:idleClose()
		self.root,self.promptAt,self.bearSpot,self.eggBase=root,Land.PromptAt,Land.BearSpot,Land.EggBase
		local folder=make("Folder",self.world,{Name=Client.IdleFolder})
		self.folder=folder
		for _,spec in ipairs(Client.landmarkParts())do self:drawPart(folder,spec)end
		-- Fable R10 4: no egg, no name: the board stays, blank but for its painted moon.
		for _,words in ipairs(self.signWords or {})do words.Text=""end
		self:drawLandmark(folder)
	end
	self.clock+=dt or 0
	self:poseLandmark(dt or 0,"small",false,self:reduced())
	return true
end
-- The Show me pin over the landmark: Land.PinAt straight over the bowl's centre (nil: the trail's own pin).
function Client:pinAt()
	if not self.landmark or not self.isOpen or not self.root then return nil end
	return(self.root*CFrame.new(0,Land.PinAt,0)).Position
end
-- The egg corner's nest on plain marble (R2 3): a soft contact shadow (concentric see-through discs on one plate) and
-- the straw and leaf scatter (EggCorner.scatter), root-local, inert, no shadow.
Client.ScatterColor=table.freeze({straw=Color3.fromHex("#C9A560"),leaf=Color3.fromHex("#5E8A3A")})
function Client:drawGround(folder)
	local S=Corner.Shadow
	local radius=if self.landmark then Land.Shadow else S.radius
	local plate=inert(make("Part",nil,{Name="NestShadow",Transparency=1,Size=Vector3.new(radius*2,.02,radius*2)}))
	plate.CFrame=self.root*CFrame.new(0,.012,0)
	local surface=make("SurfaceGui",plate,{Name="Shadow",Face=Enum.NormalId.Top,LightInfluence=1,
		SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud,PixelsPerStud=20})
	for k=1,S.rings do
		local scale=k/S.rings
		local ring=make("Frame",surface,{Name="Ring"..k,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(scale,scale),
			BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=S.transparency,BorderSizePixel=0})
		corner(ring)
	end
	plate.Parent=folder
	local at=self.promptAt or Client.PromptAt
	local prompt=Vector3.new(at.X,0,at.Z)
	local ring=if self.landmark then Land.Scatter else {}
	for index,bit in ipairs(Corner.scatter(self.root,self.bearSpot or Client.BearSpot,prompt,ring.inner,ring.outer))do
		local p=inert(make("Part",nil,{Name=(if bit.leaf then "ScatterLeaf"else "ScatterStraw")..index,Material=Enum.Material.SmoothPlastic,
			Color=if bit.leaf then Client.ScatterColor.leaf else Client.ScatterColor.straw,
			Size=if bit.leaf then Vector3.new(.22,.02,bit.length)else Vector3.new(.06,.02,bit.length)}))
		p.CFrame=self.root*CFrame.new(bit.at.X,.02,bit.at.Z)*CFrame.Angles(0,math.rad(bit.yaw),0)
		p.Parent=folder
	end
end
-- The egg corner's "?" disc on the pill (44 px hit, 24 drawn) and a tap target over the pill's words; both call help().
function Client:buildHelp(egg)
	local H=Client.Help
	local pill=egg.pill
	local function tapped()
		local ok,problem=pcall(self.help,self)
		if not ok then warn("[Nest] "..tostring(problem))end
	end
	local tap=make("TextButton",pill,{Name="HelpTap",Text="",BackgroundTransparency=1,AutoButtonColor=false,Selectable=false,
		Size=UDim2.new(1,-(H.drawn+H.gap),1,0),ZIndex=3})
	local hit=make("TextButton",pill,{Name="HelpDisc",Text="",BackgroundTransparency=1,AutoButtonColor=false,Selectable=false,
		AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,(H.hit-H.drawn)/2+4,.5,0),Size=UDim2.fromOffset(H.hit,H.hit),ZIndex=4,Visible=false})
	hit:SetAttribute("AccessibleLabel",UICopy.get("onb3.nest.helpAsk"))
	local disc=make("Frame",hit,{Name="Disc",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(H.drawn,H.drawn),
		BackgroundColor3=Client.Color.cream,BorderSizePixel=0,ZIndex=4})
	corner(disc)
	egg.helpStroke=make("UIStroke",disc,{Color=Client.Color.ink,Thickness=2})
	local mark=label(disc,"Mark",15,Client.Color.ink)
	mark.Text="?";mark.ZIndex=5;mark.AutoLocalize=false
	egg.helpScale=make("UIScale",disc,{Scale=1})
	egg.help,egg.helpDisc,egg.helpMark,egg.helpTap=hit,disc,mark,tap
	for _,button in ipairs({tap,hit})do
		local activated=button.Activated
		if typeof(activated)=="RBXScriptSignal"then table.insert(self.connections,activated:Connect(tapped))end
	end
end
-- The "?" card (the disc, the pill, or Peek): deps.help(self). False when there is nothing to explain.
function Client:help()
	if not self.isOpen or not self.view or not self.d.help then return false end
	local ok,shown=pcall(self.d.help,self)
	return ok and shown~=false
end
-- The card's words for the view (EGG-CORNER-LOOK 3; UICopy onb3.nest.help). Pure: {title, live, lines = {{key, text}}}.
-- `live` is the clock line ("Hatches in 8 h", and "Egg 2 of 7" in the welcome week); a ready egg says "Hatch me!".
Client.HelpOrder=table.freeze({"what","time","gift","inside","free","next","wait"})
Client.HelpDropFirst="next"
function Client.helpCard(view,now)
	local left=Client.left(view,now)
	local live=(Client.clock(left))
	if left>0 and view.egg<=Nest.WeekLength then live=live.." · "..UICopy.get("onb3.nest.count",{count=view.egg})end
	local lines={}
	for _,key in ipairs(Client.HelpOrder)do
		local text=if key=="inside"then Client.inside(view)
			elseif key=="time"then UICopy.get("onb3.nest.help.time",{hours=Nest.Hours})
			else UICopy.get("onb3.nest.help."..key)
		table.insert(lines,{key=key,text=text})
	end
	return{title=UICopy.get("onb3.nest.help.title"),live=live,ready=left<=0,lines=lines,button=UICopy.get("onb3.nest.help.button"),
		icon=Client.Assets.chip}
end
-- The card's model now (nil without a view): init's card asks it once a second while it is open.
function Client:helpNow()
	if not self.isOpen or not self.view then return nil end
	return Client.helpCard(self.view,self.now())
end
-- The real shells (the existing egg mesh with the Sleepy ColorMap) take the ball's place once they load.
function Client:meshes()
	local egg=self.egg
	if not egg or egg.mesh or not self.d.meshes then return end
	local ok,parts=pcall(self.d.meshes)
	if not ok or type(parts)~="table"or not parts.TopShell or not parts.BottomShell then return end
	for _,key in ipairs({"BottomShell","TopShell","Core"})do
		local part=parts[key]
		if part then
			inert(part)
			part.Name="SleepyEgg"..key
			if key=="Core"then part.Material=Enum.Material.Neon;part.Color=Client.Color.core;part.Transparency=1;part.TextureID=""
			else part.Material=Enum.Material.SmoothPlastic;part.TextureID=Client.Assets.egg end
			part.Parent=self.folder
			egg.shells[key]=part
		end
	end
	egg.mesh=true
	if egg.ball then egg.ball:Destroy();egg.ball=nil end
end
-- The prompt, the label and the chip; `fresh` writes everything.
function Client:paint(fresh)
	local view,egg=self.view,self.egg
	if not view or not egg then return end
	local now=self.now()
	local left=Client.left(view,now)
	local look=Client.look(view,now)
	self.lookNow=look
	if fresh or self.paintedLook~=look then
		if self.paintedLook and self.paintedLook~=look and not fresh then self.stage={from=self.shownScale or(self.eggScales or Client.Scale)[look],t=0}end
		self.paintedLook=look
	end
	-- Tuck in while it grows (once per egg), Hatch when it is ready; nothing while a hatch is asked for or playing.
	local action=nil
	if look=="ready"then action="hatch"elseif not view.tucked and not self.tuck then action="tuck"
	elseif self.corner and self.d.help and(view.tucked or(self.tuck~=nil and self.tuck.t>=Client.TuckSeconds))then
		action="peek" -- the egg corner: Peek opens the "?" card
	end
	local free=(self.d.free==nil or self.d.free()==true)and(self.d.busy==nil or self.d.busy()~=true)
	local enabled=action~=nil and free and not self.waiting and not self.hatching and self.clock>=(self.promptAfter or -math.huge)
	self.action=action
	local actionText=UICopy.get(if action=="hatch"then "onb3.nest.hatch"elseif action=="peek"then "onb3.nest.peek"else "onb3.nest.tuck")
	if egg.prompt.ActionText~=actionText then egg.prompt.ActionText=actionText end
	if egg.prompt.Enabled~=enabled then egg.prompt.Enabled=enabled end
	self:paintChip(left,look)
end

-- The HUD chip: the nest icon and the clock; gold when ready. A tap lays the Show me trail. It sits above the garden
-- dock, right-aligned with it and never wider: the dock's own row (left of it) is the save notice and feedback line
-- (PetFocusUI), so the two never meet. In the Pet Park the lane above the dock is the Throw button's: the chip hides.
Client.ChipGap=8
Client.ChipIconGap=6
function Client.chipWidth(iconSize,textW)return math.ceil(10+iconSize+Client.ChipIconGap+textW+12)end
-- Pure: the chip's rect for a dock rect {x, y, w, h} (screen px), `w` wide and `hit` tall.
function Client.chipRect(dock,w,hit)
	w=math.min(w,dock.w)
	return{x=dock.x+dock.w-w,y=dock.y-Client.ChipGap-hit,w=w,h=hit}
end
function Client:measure(text,size)
	if self.d.measure then
		local ok,w=pcall(self.d.measure,text,size)
		if ok and finite(w)then return w end
	end
	return #text*size*.6
end
function Client:paintChip(left,look)
	local host=self.d.chipHost and self.d.chipHost()
	if not host then
		if self.chip then self.chip.button:Destroy();self.chip=nil end
		return
	end
	local compact=self.d.compact and self.d.compact()==true
	local chip=self.chip
	if not chip or chip.host~=host or chip.compact~=compact then
		if chip then chip.button:Destroy()end
		chip=self:buildChip(host,compact)
		self.chip=chip
	end
	local text,kind=Client.chipText(left)
	local ready=kind=="ready"
	if chip.label.Text~=text then chip.label.Text=text end
	-- The moon icon alone did not name the thing: the chip's accessible label is the explainer (O1).
	local named=Client.how(self.view)
	if chip.button:GetAttribute("AccessibleLabel")~=named then chip.button:SetAttribute("AccessibleLabel",named)end
	if chip.ready~=ready then
		chip.ready=ready
		chip.pill.BackgroundColor3=if ready then Client.Color.stars else Client.Color.well
		chip.label.TextColor3=if ready then Client.Color.ink else Client.Color.text
		chip.stroke.Color=if ready then Client.Color.gold else Client.Color.ink
	end
	-- Measured only when the words change (once a minute at most).
	if chip.measured~=text then
		chip.measured=text
		local dockW=host.AbsoluteSize and host.AbsoluteSize.X
		local size=chip.textSize
		local w=Client.chipWidth(chip.iconSize,self:measure(text,size))
		if typeof(dockW)=="number"and dockW>0 and w>dockW then size=12;w=math.min(dockW,Client.chipWidth(chip.iconSize,self:measure(text,size)))end
		chip.label.TextSize=size
		chip.width=w
		chip.button.Size=UDim2.fromOffset(w,chip.hit)
		local iconW=chip.iconSize+Client.ChipIconGap
		chip.label.Position=UDim2.fromOffset(10+iconW,0);chip.label.Size=UDim2.new(1,-(10+iconW),1,0)
	end
	chip.button.Visible=not(self.d.chipHidden and self.d.chipHidden()==true)
	local bob=if ready and not self:reduced()then math.floor(2*math.sin(self.clock*1.2*2*math.pi)+.5)else 0
	chip.icon.Position=UDim2.new(0,10,.5,-bob)
end
function Client:buildChip(host,compact)
	local pillH=if compact then 26 else 30
	local hit=if compact then 44 else 36
	local iconSize=if compact then 18 else 22
	local textSize=if compact then 13 else 14
	local button=make("TextButton",host,{Name="NestChip",Text="",AutoButtonColor=false,BackgroundTransparency=1,
		AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,0,0,-Client.ChipGap),Size=UDim2.fromOffset(92,hit),Selectable=false,ZIndex=10})
	button:SetAttribute("AccessibleLabel",if self.view then Client.how(self.view)else UICopy.get(Client.Copy.title))
	local pill=make("Frame",button,{Name="Pill",AnchorPoint=Vector2.new(0,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.new(1,0,0,pillH),
		BackgroundColor3=Client.Color.well,BorderSizePixel=0,ZIndex=10})
	corner(pill)
	local stroke=make("UIStroke",pill,{Color=Client.Color.ink,Thickness=2})
	local icon=make("ImageLabel",pill,{Name="NestIcon",BackgroundTransparency=1,Image=Client.Assets.chip,AnchorPoint=Vector2.new(0,.5),
		Position=UDim2.new(0,10,.5,0),Size=UDim2.fromOffset(iconSize,iconSize),ZIndex=11})
	local text=label(pill,"Clock",textSize,Client.Color.text)
	text.ZIndex=11;text.TextXAlignment=Enum.TextXAlignment.Left;text.AutoLocalize=true
	local chip={host=host,compact=compact,button=button,pill=pill,stroke=stroke,icon=icon,label=text,hit=hit,iconSize=iconSize,textSize=textSize}
	local activated=button.Activated
	if typeof(activated)=="RBXScriptSignal"then
		activated:Connect(function()if self.d.show then pcall(self.d.show)end end)
	end
	return chip
end

-- Actions ---------------------------------------------------------------------------------------------------------
-- The prompt (or a spec): Tuck in or Hatch.
function Client:act()
	if not self.isOpen or not self.view or self.waiting or self.hatching then return false end
	if self.action=="tuck"then
		if not self:send("tuck")then return false end
		self.tuck={t=0,first=self.view.n==0}
		self:play("pet_coo_1",.85,.35)
		if self.egg then pcall(function()self.egg.zzz:Emit(3)end)end
		self:peek()
		return true
	elseif self.action=="hatch"then
		if not self:send("claim")then return false end
		self.waiting={t=0}
		return true
	elseif self.action=="peek"then
		return self:help()
	end
	return false
end
-- The gift peek over the egg on Tuck in: what is inside, and its Stars.
function Client:peek()
	local egg,view=self.egg,self.view
	if not egg or not view then return end
	local board=make("BillboardGui",egg.anchor,{Name="GiftPeek",LightInfluence=0,AlwaysOnTop=not self.landmark,MaxDistance=60,Size=UDim2.fromOffset(120,96)})
	local tile=make("Frame",board,{Name="Tile",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.fromOffset(96,72),
		BackgroundColor3=Client.Color.cream,BorderSizePixel=0})
	make("UICorner",tile,{CornerRadius=UDim.new(0,12)})
	make("UIStroke",tile,{Color=Client.Color.ink,Thickness=2})
	local name=Client.itemName(view.gift.kind,view.gift.item,view.pet)
	local item=label(tile,"Item",14,Client.Color.ink)
	item.Text=name or "★";item.TextWrapped=true
	item.Size=UDim2.new(1,0,1,-18)
	-- "Egg n of 7" lives here in the welcome week (not on the world label).
	local count=label(tile,"Count",12,Client.Color.ink)
	count.Position=UDim2.new(0,0,1,-20);count.Size=UDim2.new(1,0,0,16)
	count.Text=if view.egg<=Nest.WeekLength then UICopy.get("onb3.nest.count",{count=view.egg})else ""
	local chip=make("Frame",board,{Name="Stars",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,70),Size=UDim2.fromOffset(56,22),
		BackgroundColor3=Client.Color.stars,BorderSizePixel=0})
	corner(chip)
	local stars=label(chip,"Count",14,Client.Color.ink);stars.Text="+"..view.gift.stars;stars.AutoLocalize=false
	if self.landmark then
		board.StudsOffsetWorldSpace=self:landmarkOffset(Land.PeekAt)
	else
		board.StudsOffset=Vector3.new(0,(self.shownScale or 1.25)*1.3+1.6,0)
	end
	table.insert(self.beats,{kind="peek",board=board,t=0,parts={tile,chip},labels={item,count,stars}})
end
-- A beat (beta 14 Q2, rows 1 to 3): the pill says `text` for `seconds`, over the other rows, and holds the need bubble
-- back until BubbleAfter after it ends.
function Client:say(text,seconds,row)
	self.beat={row=row or 2,text=text,at=self.clock,untilT=self.clock+seconds}
	self.beatUntil=self.beat.untilT
end
-- Is a beat up (or just over)? init's need bubble wrapper hides the bubble while this is true.
function Client:holdsBubble()
	return self.isOpen==true and self.beatUntil~=nil and self.clock<self.beatUntil+Client.BubbleAfter
end
-- Does the nest's prompt claim E / ButtonX at `position` over the station's (`part`)? LoungeStations.Yield.Eggs.
function Client:claims(position,part)
	local egg=self.egg
	if not self.isOpen or not egg or not egg.prompt.Enabled or not self.root then return false end
	local at=(self.root*CFrame.new(self.promptAt or Client.PromptAt)).Position
	local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
	local mine=flat(position,at)
	if mine>Client.Prompt then return false end
	return part==nil or mine<flat(position,part.Position)
end
-- The hatch, only once the save has it: the reward shows only now.
function Client:claimed(receipt)
	if not self.view or not self.egg then return end
	self.waiting=nil
	self.hatching={t=0,receipt=receipt,rewarded=false,popped=false}
	self:play("hatch_rise",1,.6)
end
function Client:reward(receipt)
	local stars=if int(receipt.stars)then receipt.stars else 0
	local kind=receipt.kind
	local name=if kind~="stars"then Client.itemName(kind,receipt.item,receipt.pet)else nil
	if name and self.d.toast then pcall(self.d.toast,UICopy.get("onb3.nest.got",{item=name}),stars)end
	if stars>0 then self:float(stars)end
	self:play("snack_boost_sparkle",1,.7)
	self.rewarded=(self.rewarded or 0)+1
end
-- "+N" with the Star floats up from the nest (the find's "+N Smarts" billboard, gold).
function Client:float(stars)
	local egg=self.egg
	if not egg then return end
	local board=make("BillboardGui",egg.anchor,{Name="StarsGain",LightInfluence=0,AlwaysOnTop=true,MaxDistance=80,Size=UDim2.fromOffset(180,40),
		StudsOffset=Vector3.new(0,2.6,0)})
	local text=label(board,"Text",28,Client.Color.stars)
	text.TextScaled=true;text.TextStrokeColor3=Color3.fromHex("#5A3A12");text.TextStrokeTransparency=.35;text.Text="+"..stars.." ★";text.AutoLocalize=false
	table.insert(self.beats,{kind="float",board=board,label=text,t=0})
end

-- ── Per frame ──────────────────────────────────────────────────────────────────────────────────────────────────────
function Client:step(dt)
	if self.isOpen and not Onboard.on("nest")then self:close()end -- off: gone within the frame, whatever the signal does
	if not self.isOpen then return end
	self.clock+=dt
	if self.beat and self.clock>=self.beat.untilT then self.beat=nil end
	self:stepBeats(dt)
	if not self.view or not self.egg then return end
	-- The landmark arrived or was re-seated since this nest was drawn: draw it again on the server's root.
	if self.landmark and not self.hatching and self:landmarkMoved()then
		local view=self.view
		self:clear()
		self:set(view)
		if not self.egg then return end
	end
	if not self.egg.mesh then self:meshes()end
	if self.waiting then
		self.waiting.t+=dt
		if self.waiting.t>=Client.Pending then self.waiting=nil;self.synced=false;self:ask()end
	end
	self:paint(false)
	self:pose(dt)
	self:ping()
end
function Client:stepBeats(dt)
	local reduced=self:reduced()
	for index=#self.beats,1,-1 do
		local beat=self.beats[index]
		beat.t+=dt
		local done=false
		if beat.kind=="peek"then
			local fade=if beat.t<.2 then 1-beat.t/.2 elseif beat.t<2.2 then 0 else math.min(1,(beat.t-2.2)/.3)
			for _,part in ipairs(beat.parts)do part.BackgroundTransparency=fade end
			for _,text in ipairs(beat.labels)do text.TextTransparency=fade end
			done=beat.t>=2.5
		elseif beat.kind=="float"then
			if not reduced then beat.board.StudsOffset=Vector3.new(0,2.6+math.min(1,beat.t/1.4)*1.6,0)end
			local fade=math.clamp((beat.t-.77)/.63,0,1)
			beat.label.TextTransparency=fade;beat.label.TextStrokeTransparency=.35+.65*fade
			done=beat.t>=1.4
		end
		if done then beat.board:Destroy();table.remove(self.beats,index)end
	end
end
-- The egg's scale, rock, hop and glow for this frame, plus the tuck, hatch and drop moments.
function Client:pose(dt)
	local egg,view=self.egg,self.view
	local look=self.lookNow or "small"
	local reduced=self:reduced()
	local target=(self.eggScales or Client.Scale)[look]
	local scale=target
	if self.stage and not reduced then
		self.stage.t+=dt
		local p=math.min(1,self.stage.t/Client.StageTween)
		scale=self.stage.from+(target-self.stage.from)*Client.backOut(p)
		if p>=1 then self.stage=nil end
	else self.stage=nil end
	self.shownScale=scale
	local breath,rock,hop,squash,halo=Client.motion(look,self.clock,reduced)
	local lean,sink,haloBoost=0,0,0
	local tucked=view.tucked or self.tuck~=nil
	if tucked and not reduced then lean=6 end
	-- Tuck in: a 0.12 sink and back, the halo to 0.9 and back over 0.6 s.
	if self.tuck then
		self.tuck.t+=dt
		local t=self.tuck.t
		if t<.25 and not reduced then sink=-.12*math.sin(t/.25*math.pi)end
		if t<.6 then haloBoost=math.max(0,.9-halo)*(1-t/.6)end
		if t>=Client.TuckSeconds and not self.tuck.said then
			self.tuck.said=true
			-- Beta 14 Q2: the pill says it once; no rail toast (the pill is in front of the player, the chip keeps it).
			if self.tuck.first then self:say(UICopy.get(Client.Copy.tuckedFirst,{hours=Nest.Hours}),Client.TuckedFirstLabel,1)
			else self:say(UICopy.get(Client.Copy.tucked),Client.TuckedLabel,2)end
		end
	end
	-- Waiting for the save: a fast rock on a loop.
	if self.waiting and not reduced then rock=14*math.sin(self.clock*6*2*math.pi);hop=0 end
	local top,bottomFade,core=0,0,nil
	if self.hatching then
		local h=self.hatching
		h.t+=dt
		local t=h.t
		if t<.5 and not reduced then rock=14*math.sin(t*6*2*math.pi);hop=0 end
		haloBoost=math.max(haloBoost,math.min(1,t/.5)*.3)
		if t>=.5 and not h.popped then
			h.popped=true
			pcall(function()egg.sparks:Emit(if reduced then 6 else 18)end)
			self:play("hatch",1,.7)
		end
		if t>=.5 then
			local p=math.min(1,(t-.5)/.4)
			top=if reduced then 0 else 1.2*math.sin(p*math.pi*.5)
			core=math.min(1,(t-.5)/.35)
		end
		if t>=.6 and not h.rewarded then h.rewarded=true;self:reward(h.receipt)end
		if t>=1.6 then bottomFade=math.min(1,(t-1.6)/.4)end
		if t>=Client.HatchSeconds then
			self.hatching=nil
			local queued=self.queued;self.queued=nil
			for _,part in pairs(egg.shells)do if part.Name~="SleepyEggCore"then part.Transparency=0 end end
			if queued then self:set(queued.view,queued.view~=nil)end
			return
		end
	end
	-- The new egg drops 1.5 studs onto the straw with one bounce.
	local drop=0
	if self.drop then
		self.drop.t+=dt
		local p=math.min(1,self.drop.t/Client.DropSeconds)
		drop=if reduced then 0 else 1.5*(1-p)*(1-p)-(if p>.7 then .08*math.sin((p-.7)/.3*math.pi)else 0)
		if p>=1 then self.drop=nil end
	end
	local s=scale*breath
	local rise=0
	if self.landmark and look~="ready"and not self.hatching then
		-- The landmark's sleeping breath (LOOK 4): taller and a touch narrower, rising a little.
		local tall,wide
		tall,wide,rise=Land.breath(self.clock,reduced)
		s*=wide
		squash*=tall/wide
	end
	local frame=self.root*CFrame.new(0,(self.eggBase or Client.EggBase)+sink+drop+rise,0)
	if lean~=0 then
		local bear=self.bearSpot or Client.BearSpot
		local d=Vector3.new(bear.X,0,bear.Z).Unit
		frame=frame*CFrame.fromAxisAngle(Vector3.new(d.Z,0,-d.X),math.rad(lean))
	end
	frame=frame*CFrame.Angles(0,0,math.rad(rock))*CFrame.new(0,hop,0)*CFrame.Angles(0,math.pi,0) -- the face looks at the dais
	self:place(frame,s,squash,top,bottomFade,core)
	-- Glow, light, sparks, Zzz.
	local alpha=math.min(1,(halo or 0)+haloBoost)
	egg.halo.Enabled=alpha>0
	egg.halo.Size=UDim2.fromScale(2.6*s,2.6*s)
	egg.halo.StudsOffset=Vector3.new(0,.65*s,0)
	egg.haloImage.ImageTransparency=1-alpha
	egg.haloImage.ImageColor3=if look=="ready"then Client.Color.gold else Client.Color.halo
	egg.light.Enabled=look~="small"
	egg.sparks.Rate=if look=="ready"and not reduced then 6 else 0
	-- The landmark's pill is fixed at Land.PillAt over the root (it never rides the egg's scale).
	if self.landmark then
		local offset=self:landmarkOffset(Land.PillAt)
		if egg.board.StudsOffsetWorldSpace~=offset then egg.board.StudsOffsetWorldSpace=offset end
	else
		egg.board.StudsOffset=Vector3.new(0,1.3*s+.6,0)
	end
	if self.landmark then self:poseLandmark(dt,look,tucked,reduced)end
	egg.stillZ.Enabled=reduced and look~="ready"
	egg.stillZ.StudsOffset=Vector3.new(.3,1.3*s+.3,0)
	local every=Client.ZzzEvery[look]
	if every and not reduced then
		if tucked then every/=2 end
		self.zzzAt=self.zzzAt or self.clock
		if self.clock>=self.zzzAt then
			self.zzzAt=self.clock+every
			pcall(function()egg.zzz:Emit(1)end)
		end
	end
	self:paintPill()
end
-- The pill (beta 14 Q2), every frame: which row, how far the player is, the need bubble, the peek and the focus camera.
-- Writes only what changed.
function Client:paintPill()
	local egg,view=self.egg,self.view
	if not egg or not view then return end
	local d=self.d
	local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
	local centre=self.root.Position
	local root=d.root and d.root()
	local distance=if typeof(root)=="Vector3"then flat(root,centre)else nil
	local bubble=false
	if d.bubble then
		local ok,b=pcall(d.bubble)
		bubble=ok and type(b)=="table"and b.shown==true and typeof(b.pet)=="Vector3"and flat(b.pet,centre)<=Client.BubbleNear
	end
	local beat=self.beat
	local row=Client.row(view,{beat=beat,look=self.lookNow,left=Client.left(view,self.now()),near=distance,tucked=view.tucked or self.tuck~=nil,
		bubble=bubble,compact=d.compact~=nil and d.compact()==true,corner=self.corner==true})
	local alpha=Client.fade(distance,row.show[1],row.show[2])
	if beat then
		local t,length=self.clock-beat.at,beat.untilT-beat.at
		alpha=math.max(alpha,math.clamp(1-t/Client.BeatIn,0,1),math.clamp((t-(length-Client.BeatOut))/Client.BeatOut,0,1))
	end
	if row.hidden then alpha=1 end
	-- The gift peek is up, or the pet focus (greeting) camera: no pill (it would read as the Bear's speech).
	for _,item in ipairs(self.beats)do if item.kind=="peek"then alpha=1 end end
	if d.focus~=nil and d.focus()==true then alpha=1 end
	if self:reduced()and alpha<1 then alpha=0 end
	local key=row.row..":"..row.text..":"..row.size..":"..tostring(row.lift)..":"..tostring(row.help)
	if egg.rowKey~=key then
		egg.rowKey=key
		local P=Client.Pill
		egg.clock.Text=row.text
		local size=row.size
		local w=self:measure(row.text,size)
		local lines,width,height,small=Client.pillSize(w,if size>P.small then self:measure(row.text,P.small)else nil)
		if small then size=P.small end
		egg.clock.TextSize=size
		egg.clock.TextWrapped=lines>1
		if row.help and egg.help then width+=Client.Help.drawn+Client.Help.gap end
		egg.pill.Size=UDim2.fromOffset(width,height)
		if egg.help then
			egg.help.Visible=row.help==true
			egg.helpTap.Visible=row.help==true
			-- The words keep left of the disc.
			egg.clock.Size=if row.help then UDim2.new(1,-(Client.Help.drawn+Client.Help.gap),1,0)else UDim2.fromScale(1,1)
		end
		egg.pill.Position=UDim2.new(.5,0,1,if row.lift then -P.lift else 0)
		egg.pill.BackgroundColor3=if row.gold then Client.Color.stars else Client.Color.cream
		egg.board.AlwaysOnTop=row.onTop and not self.landmark -- Fable R10 2: never over the landmark
		egg.row=row
	end
	if egg.alpha~=alpha then
		egg.alpha=alpha
		egg.board.Enabled=alpha<1
		egg.pill.BackgroundTransparency=alpha;egg.pillStroke.Transparency=alpha;egg.clock.TextTransparency=alpha
		if egg.helpDisc then egg.helpDisc.BackgroundTransparency=alpha;egg.helpStroke.Transparency=alpha;egg.helpMark.TextTransparency=alpha end
	end
	self:paintPulse(egg,row,alpha)
end
-- The "?" disc's two first-time pulses (once ever: deps.helpPulse() says it is due, deps.helpPulsed() saves the bit),
-- the first time the disc shows after a tuck-in. Reduced Motion: none (the bit is still saved).
function Client:paintPulse(egg,row,alpha)
	if not egg.helpScale then return end
	local H=Client.Help
	local pulse=self.pulse
	if not pulse and row.help and alpha<.5 and self.view and(self.view.tucked or self.view.n>=1)and not self.pulseAsked then
		self.pulseAsked=true
		local d=self.d
		if d.helpPulse and d.helpPulse()==true then
			if d.helpPulsed then pcall(d.helpPulsed)end
			if not self:reduced()then self.pulse={at=self.clock};pulse=self.pulse end
		end
	end
	if not pulse then return end
	local t=self.clock-pulse.at
	local length=H.pulseSeconds*H.pulses
	if t>=length then self.pulse=nil;egg.helpScale.Scale=1;return end
	local p=(t%H.pulseSeconds)/H.pulseSeconds
	egg.helpScale.Scale=1+(H.pulse-1)*math.sin(p*math.pi)
end
function Client:place(frame,s,squash,top,bottomFade,core)
	local egg=self.egg
	if egg.mesh then
		for key,part in pairs(egg.shells)do
			local spec=Models[key]
			if spec then
				part.Size=Vector3.new(spec.size.X*s,spec.size.Y*s*squash,spec.size.Z*s)
				local lift=if key=="TopShell"then top else 0
				part.CFrame=frame*CFrame.new(spec.center.X*s,spec.center.Y*s*squash+lift,spec.center.Z*s)
				if key=="TopShell"and top>0 then part.Transparency=math.clamp((top-.6)/.6,0,1)end
				if key=="BottomShell"and bottomFade>0 then part.Transparency=bottomFade end
				if key=="Core"then
					part.Transparency=if core then .2+.8*core else 1
					if core then part.Size=part.Size*(1+1.4*core)end
				end
			end
		end
	elseif egg.ball then
		egg.ball.Size=Vector3.new(s,1.3*s*squash,s)
		egg.ball.CFrame=frame*CFrame.new(0,.65*s*squash+top*.2,0)
		egg.ball.Transparency=if top>0 then math.clamp(top/1.2,0,1)else 0
	end
end
-- The one soft ping when a ready egg comes within Nest.ReadyPing, once per egg.
function Client:ping()
	if self.lookNow~="ready"then return end
	local root=self.d.root and self.d.root()
	local key=tostring(self.view.at)..":"..tostring(self.view.n)
	if root and not self.pinged[key]and(root-self.root.Position).Magnitude<=Nest.ReadyPing then
		self.pinged[key]=true
		self:play("machine_attract",1,.35)
	end
end

-- What the rest of the client asks ---------------------------------------------------------------------------------
-- Where the Bear's prints end (the front of the nest), or nil while there is no nest drawn.
function Client:place3D()
	if not self.isOpen or not self.drawn or not self.view then return nil end
	return(self.root*CFrame.new(self.promptAt or Client.PromptAt)).Position
end
-- {left, look, ready, kind, item, stars} for the strip, or nil.
function Client:summary()
	if not self.isOpen or not self.view then return nil end
	local now=self.now()
	local left=Client.left(self.view,now)
	return{left=left,look=Client.look(self.view,now),ready=left<=0,view=self.view}
end
return Client
