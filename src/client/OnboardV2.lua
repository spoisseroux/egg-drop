-- Onboarding v2 (Fable, artifacts/qa-2026-11-26-beta35/ONBOARDING-V2.md; Spencer's notes 20 to 25: "the new onboarding
-- doesnt help? idek know what to do?"): the numbers and pure rules of the five steps, spec-checked offline
-- (scripts/OnboardV2.spec.lua). The views read these; nothing here touches the game.
--   1 the Welcome deck: one instruction, a 3D spinning egg, three shell pips           (switch egg3d, WelcomeEgg3D)
--   2 the stork brings the egg into the garden                                          (switch stork, FirstHatchStory)
--   3 three taps crack it there                                                         (switch stork, FirstHatchStory)
--   4 the Bear's card, inside the safe area                                             (switch safecard, RevealLayout)
--   5 what now: one worded bubble at a time and the end card                            (switch guide, BearNeeds)
-- Every instruction is 16 characters or fewer and never a key name. The server stays the truth: the Bear is granted and
-- saved by the Welcome round before any of this plays; steps 2 to 4 are presentation and the receipt's own ack.
local V2={}
local function hex(h)return Color3.fromHex(h)end

-- ── Switches ─────────────────────────────────────────────────────────────────────────────────────────────────────────
-- Onboard.on(name); "stork" also needs opener and crack (Onboard.storyOn). Specs inject V2.read.
V2.read=nil
function V2.on(name)
	if V2.read then return V2.read(name)==true end
	local ok,on=pcall(function()
		local Onboard=require(game:GetService("ReplicatedStorage").Shared.Onboard)
		if name=="stork"then return Onboard.storyOn()end
		return Onboard.on(name)
	end)
	return ok and on==true
end

-- ── Step 1: the Welcome deck ─────────────────────────────────────────────────────────────────────────────────────────
V2.Deck=table.freeze({
	textMin=18,textMax=34,ink=hex("#FFFFFF"),
	pip=22,pipGap=10,pipEmpty=hex("#2B4C7E"),pipRing=hex("#9FC4FF"),pipFilled=hex("#FFD86B"),
	-- Beta (36), Spencer: "we dont need that giant shiny circle" and no cracking on the deck (the egg cracks in the
	-- world, step 3); Fable (AERO-JUICE-BRIEF 4): no disc at all and no Neon core showing. The egg itself is lit a
	-- little brighter each combo (the viewport's light), with a short flare on the hop; the finale brightens it more.
	-- Fable B37 1b: the grey flash: a cream base colour under the texture, the texture preloaded (at most 0.6 s) with
	-- the egg hidden, then a 150 ms fade in.
	base=hex("#FBF6D2"),preloadCap=.6,fadeIn=.15,
	pad=8,light=hex("#FFF3D6"),lightIdle=0,lightStep=.12,lightFlare=.12,lightFinal=.6,
	yawRate=25,bobDeg=3,bobHz=.5,                          -- idle: degrees a second, tilt bob
	hop=.10,wobbleDeg=14,wobbleTime=.4,turnTime=.6,        -- each combo: a hop (card heights), a damped wobble, one turn
	pipPop=.2,pipScale=1.3,                                -- a pip fills with a 1.0 -> 1.3 -> 1.0 pop
	finale=.5,lift=.2,                                     -- combo 3: the glow rises, the egg lifts 20% and fades
	reducedYaw=-28,                                        -- Reduced Motion: a still three-quarter pose
	tuckAfter=.4,                                          -- step 2: the deck tucks this long after combo 3
})
-- The card's one line for this moment (UICopy keys).
function V2.deckLine(drops,combos)
	combos=math.clamp(math.floor(tonumber(combos)or 0),0,3)
	if combos>=3 then return "onb2.deck.hatching"end
	if combos==2 then return "onb2.deck.one"end
	if combos==1 then return "onb2.deck.two"end
	if(tonumber(drops)or 0)>=1 then return "onb2.deck.match"end
	return "onb2.deck.drop"
end
-- The board pill before the first drop: computer words only (the phone has the hand, the pad its own picture line).
function V2.dropHint(input)
	if input=="Touch"or input=="Gamepad"then return nil end
	return "onb2.deck.click"
end
-- Pip i (1..3) with `combos` filled: "filled" or "empty".
function V2.pip(i,combos)return if i<=math.clamp(math.floor(tonumber(combos)or 0),0,3)then "filled"else "empty"end
-- The pop of a pip that just filled, `age` s after (1 at rest).
function V2.pipScale(age)
	local D=V2.Deck
	if type(age)~="number"or age<0 or age>=D.pipPop then return 1 end
	return 1+(D.pipScale-1)*math.sin(age/D.pipPop*math.pi)
end
-- How much brighter the egg is lit after `combos` combos (0 = as Hatch eggs lights it): a little more each one.
function V2.glow(combos)return V2.Deck.lightIdle+V2.Deck.lightStep*math.clamp(math.floor(tonumber(combos)or 0),0,3)end
-- Pure: a light colour lifted toward the warm white by `amount` (0..1).
function V2.lift(color,amount)return color:Lerp(V2.Deck.light,math.clamp(amount or 0,0,1))end
local function smooth(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end
-- The egg's pose at clock t, `beat` s after the last combo (nil: none yet). Returns yaw and tilt (degrees) and hop (card
-- heights). Reduced Motion: the still three-quarter pose, no hop.
function V2.eggPose(t,beat,reduced)
	local D=V2.Deck
	if reduced then return D.reducedYaw,0,0 end
	local yaw=(t*D.yawRate)%360
	local tilt=D.bobDeg*math.sin(t*D.bobHz*math.pi*2)
	local hop=0
	if type(beat)=="number"and beat>=0 then
		if beat<D.wobbleTime then
			local u=beat/D.wobbleTime
			hop=D.hop*math.sin(u*math.pi)
			tilt+=D.wobbleDeg*(1-u)*math.sin(u*math.pi*4)
		end
		if beat<D.turnTime then yaw+=360*smooth(beat/D.turnTime)end
	end
	return yaw,tilt,hop
end
-- Combo 3's finale `age` s in: light (0..1), lift (card heights), fade (0 shown .. 1 gone).
function V2.finale(age,reduced)
	local D=V2.Deck
	local u=math.clamp((age or 0)/D.finale,0,1)
	local from=V2.glow(3)
	local glow=from+(D.lightFinal-from)*u
	return glow,if reduced then 0 else D.lift*smooth(u),u
end
-- Each combo's sound on the deck: a rising fill chime (the "charge" cue up a step each time) and a soft buzz. Never a
-- crack: beta (36), the egg only cracks in the world.
V2.ComboChime=table.freeze({cue="charge",pitches={1.12,1.26,1.5},gain=.45,haptic="settle"})

-- ── Step 1 to 2: one hatch, never two (review B36) ──────────────────────────────────────────────────────────────────
-- The deck's own hatch modal waits up to Hold s for the Bear's receipt (the stork plays it). A receipt that comes later
-- finds the modal already let back: the stork then declines it for the session (the old path plays it), so the Bear
-- never hatches twice. gate: a table the story keeps ({since, declined}).
V2.Hold=4
-- Pure: does the deck modal wait (true) at `now`? bear: the deck is hatching the first Bear; running: the story runs.
function V2.deckHold(gate,bear,running,now)
	if not bear then gate.since=nil;return false end
	if running then return true end
	if gate.declined then return false end
	gate.since=gate.since or now
	if now-gate.since<V2.Hold then return true end
	gate.declined=true -- the modal shows from here: no stork for this session
	return false
end
-- Pure: may the story still take the Bear's receipt?
function V2.mayClaim(gate)return gate.declined~=true end
-- The card's safety: with no stage (it failed to show) Meet happens at once; a card left up this long meets too.
V2.CardTimeout=90

-- ── Step 2: the stork ────────────────────────────────────────────────────────────────────────────────────────────────
V2.Stork=table.freeze({
	glide=3.0,hover=3.8,release=4.3,total=6.0,             -- seconds: glide in, lower the bundle, let go, fly off
	out=40,up=18,land=6,hoverUp=4.2,                       -- studs: the start (out, up, to the player's right), the drop
	flapDeg=35,flapFast=3,flapSlow=1.5,                    -- wings
	open=1.2,rockDeg=6,clacks=2,                           -- the blanket's radius, the egg's settle rock
	skipAt=1,skipH=44,fov=55,reducedFade=.3,
	body=hex("#F6F3EA"),tips=hex("#2E3440"),beak=hex("#F28C28"),cap=hex("#5B8DEF"),band=hex("#FFD86B"),
	blanket=hex("#8FD3FF"),dots=hex("#FFFFFF"),
})
-- The phase at t: "glide", "hover", "release", "leave" or "gone".
function V2.storkPhase(t)
	local S=V2.Stork
	if t<S.glide then return "glide"end
	if t<S.hover then return "hover"end
	if t<S.release then return "release"end
	if t<S.total then return "leave"end
	return "gone"
end
-- The wing angle (degrees) at t: 3 Hz slowing to 1.5 Hz over the glide, 1.5 Hz after (the phase is the integral, so
-- the beat never jumps).
function V2.flap(t)
	local S=V2.Stork
	local phase
	if t<=S.glide then
		local slope=(S.flapSlow-S.flapFast)/S.glide
		phase=S.flapFast*t+.5*slope*t*t
	else
		phase=S.flapFast*S.glide+.5*(S.flapSlow-S.flapFast)*S.glide+S.flapSlow*(t-S.glide)
	end
	return S.flapDeg*math.sin(phase*math.pi*2)
end
-- Pure: the point on a curve at u (0..1) from a to b, bowed out by `bow` (a Vector3 offset at the middle).
function V2.curve(a,b,bow,u)
	u=math.clamp(u,0,1)
	local c=(a+b)/2+bow
	local v=1-u
	return a*(v*v)+c*(2*v*u)+b*(u*u)
end
-- Pure: how far the bundle hangs under the beak (0 tucked .. 1 on the ground) at t.
function V2.lower(t)
	local S=V2.Stork
	if t<S.glide then return 0 end
	return smooth((t-S.glide)/(S.hover-S.glide))
end
-- Pure: the egg's settle rock (degrees) `age` s after it is let go.
function V2.rock(age)
	local S=V2.Stork
	if type(age)~="number"or age<0 then return 0 end
	local span=S.release-S.hover
	if age>=span then return 0 end
	local u=age/span
	return S.rockDeg*(1-u)*math.sin(u*math.pi*3)
end
-- The two beak clacks and the nod in the leave phase (seconds after the release): {clacks}, nodAt, flyAt.
V2.Leave=table.freeze({clacks={.15,.42},nod=.7,fly=1.0})

-- Beta (36), Spencer: "the stork flies thru the arch mesh". The flight is chosen against the world before it starts:
-- candidate approaches (a heading round the landing and a height) are sampled along the same curve the stork flies,
-- its body (2.2 studs over its feet) swept as a sphere of Route.radius (the wings); the first clear one is flown, and
-- the stork leaves back along it. None clear: it comes straight down from high over the landing.
--   headings: degrees from the player's right (0) toward beyond the landing (90); negative ones come from behind.
V2.Route=table.freeze({radius=3,body=2.2,samples=24,coarse=6,budget=160,castsPerSweep=4,framesCasts=24,out=40,bowUp=5,bowBack=6,
	headings={11,169,45,135,90,-20,-160},heights={18,28,38},drop=40,
	-- the landing: 6 studs ahead first, then round the player, with open sky over it (the bundle comes down there)
	landing={{0,6},{30,6},{-30,6},{60,6},{-60,6},{0,8},{90,6},{-90,6},{0,10},{45,9},{-45,9},{135,6},{-135,6},{180,6}},
	sky=9,skyRadius=1.3,
	-- the stork's beak tip from its feet (StorkModel.BeakTip): the bundle hangs here, so it hovers with its body back
	beak=Vector3.new(0,3.4,-2.95),hoverUp=4.4})
-- Fable B37 section 3: the open blanket 78% of its old diameter, half as thick, with no grey tufts (the dots are a pale
-- blue), and on the arrival dais it lands 0.6 studs further in, so nothing hangs past the chamfer.
V2.Blanket=table.freeze({radius=1.2*.78,thick=.1*.5,dots=hex("#DCEBFA"),inward=.6,daisReach=8})
-- Pure: the landing moved Blanket.inward studs toward the dais centre when it is on (near) the dais.
function V2.onDais(land,dais)
	if typeof(dais)~="Vector3"then return land end
	local d=Vector3.new(dais.X-land.X,0,dais.Z-land.Z)
	local m=d.Magnitude
	if m>V2.Blanket.daisReach or m<1e-3 then return land end
	return land+d/m*math.min(V2.Blanket.inward,m)
end
-- Pure: the stork's feet (root) while it hovers over `land` facing the player (its beak tip over the landing).
function V2.hover(land,toPlayer)
	local R=V2.Route
	return land+Vector3.new(0,R.hoverUp-R.beak.Y,0)+toPlayer*R.beak.Z
end
-- Pure: a heading's direction (degrees) from the player's right toward beyond the landing.
function V2.heading(right,away,degrees)
	local a=math.rad(degrees)
	return right*math.cos(a)+away*math.sin(a)
end
-- Pure: the body's path for a start, a hover root and a bow: Route.samples + 1 points.
function V2.routePath(start,hover,bow,samples)
	local out={}
	local lift=Vector3.new(0,V2.Route.body,0)
	local n=samples or V2.Route.samples
	for i=0,n do out[i+1]=V2.curve(start,hover,bow,i/n)+lift end
	return out
end
-- Pure: the flight. land: the landing point; toPlayer: flat unit vector from it to the player; hover: the stork's root
-- when it hovers over the landing; clear(a, b, radius): true when a sphere swept from a to b hits nothing. Returns
-- {start, bow, heading, height} (heading nil = straight down) and how many candidates were tried.
function V2.storkRoute(land,toPlayer,hover,clear)
	local R=V2.Route
	local up=Vector3.new(0,1,0)
	local away=-toPlayer
	local right=away:Cross(up)
	right=right/math.max(1e-6,right.Magnitude)
	local bow=up*R.bowUp-toPlayer*R.bowBack
	-- Code review: a cast budget. Each candidate is swept coarse first (Route.coarse legs), then fine only if that is
	-- clear; the first clear one is flown; past Route.budget sweeps it stops and comes straight down.
	local tried,calls=0,0
	local function sweep(path)
		for i=1,#path-1 do
			if calls>=R.budget then return false end
			calls+=1
			if not clear(path[i],path[i+1],R.radius)then return false end
		end
		return true
	end
	for _,height in ipairs(R.heights)do
		for _,degrees in ipairs(R.headings)do
			if calls>=R.budget then break end
			tried+=1
			local start=land+V2.heading(right,away,degrees)*R.out+up*height
			if sweep(V2.routePath(start,hover,bow,R.coarse))and sweep(V2.routePath(start,hover,bow))then
				return{start=start,bow=bow,heading=degrees,height=height},tried,calls
			end
		end
	end
	return{start=hover+up*R.drop,bow=Vector3.new(0,0,0),heading=nil,height=R.drop},tried,calls
end
-- Pure: the landing. ground(x, z) -> the ground point under it or nil; clear as storkRoute. look: the player's flat
-- look; at: the player's feet. The first spot with ground and open sky (Route.sky studs) over it, else the first guess.
function V2.landing(at,look,ground,clear)
	local R=V2.Route
	local up=Vector3.new(0,1,0)
	local first
	for _,spot in ipairs(R.landing)do
		local dir=CFrame.Angles(0,math.rad(spot[1]),0):VectorToWorldSpace(look)
		local guess=at+dir*spot[2]
		local point=ground(guess.X,guess.Z,at.Y)
		if point then
			first=first or point
			-- open sky over it, and room for the hovering stork (its body and wings) over it
			local toPlayer=Vector3.new(at.X-point.X,0,at.Z-point.Z)
			toPlayer=if toPlayer.Magnitude>1e-3 then toPlayer/toPlayer.Magnitude else -look
			local body=V2.hover(point,toPlayer)+up*R.body
			if clear(point+up*.6,point+up*R.sky,R.skyRadius)and clear(body,body+up*6,R.radius)then return point end
		end
	end
	-- no ground under any spot: nil, so the story can take the spawn pad
	return first
end

-- ── Step 3: crack it ─────────────────────────────────────────────────────────────────────────────────────────────────
-- Fable's cathartic crack (AERO-JUICE-BRIEF section 4), on Spencer's 3D cracks: the cracks grow on the shell itself
-- (EggCrackPaths: where; EggCrack3D: how it looks), never on the screen. Per tap: a 40 ms anticipation dip, the
-- sound and buzz, the crack stage growing over 90 ms, the rock (or the flex), crumbs, the camera 3% closer.
V2.Crack=table.freeze({
	dist=5,up=1.6,fov=40,tween=.6,vignette=hex("#0B1220"),vignetteAlpha=.35,pill=hex("#FFD86B"),
	stops={.05,.5,.95},                                   -- the ritual's clock: a stop per tap, a beat between
	handAfter=3,auto=7,                                    -- no countdown shown; the hand at 3 s, the tap itself at 7 s
	zone=.6,                                               -- any tap in the middle 60% of the screen counts
	anticipate=.04,grow=.09,closer=.03,leakAlpha=.25,
	flex={time=.25,to=1.08,hzFrom=5,hzTo=9},
	pop={silence=.08,duck=.5,keepBottom=.6,up=3,fade=.5,flash=.12,flashAlpha=.35,kick=.15,fovPeak=44,fovRest=42,settle=.4,hold=.6,
		pieces={12,16},voiced=5,cueDelay=.12,lateFlakes={2,4},sting="rarity_common",scatter="shell_scatter"},
	-- the pop's beat: the creak and flex, then the silence, then the burst (s after tap 3's sound)
	creak=.25,
})
-- What each tap does. layers: HatchAsmr layers (existing ids); takes: the new synthesised takes (Story.Takes, empty
-- slots until uploaded); under: a layer under it at a gain; rock (deg) and its cycles, or flex; crumbs and their kind.
V2.Taps=table.freeze({
	{dip=.03,widen=.02,layers={"crack1"},takes={"tap_knuckle"},haptic="crack1",rock=10,cycles=2,crumbs=4,stage=1,closer=true},
	{dip=.04,widen=.02,layers={"crack2"},takes={"tap_knuckle"},under={layer="creak",gain=.4},haptic="crack2",rock=14,cycles=3,
		crumbs=6,stage=2,leak=true,closer=true,duck={time=.6,gain=.7}},
	{dip=.05,widen=.02,hold=true,layers={"creakLong"},takes={"asmr_crack3"},haptic="creak_long",flex=true,crumbs=3,skitter=true,
		stage=3,pop=true},
})
V2.ReducedFlakes=3
-- Pure: the anticipation dip before a tap's sound: squash Y (1 = rest) and widen XZ at t (s since the tap), for tap i.
function V2.dip(i,t)
	local tap=V2.Taps[i];if not tap or type(t)~="number"or t<0 then return 1,1 end
	local A=V2.Crack.anticipate
	if t<A then local u=smooth(t/A);return 1-tap.dip*u,1+tap.widen*u end
	if tap.hold then return 1-tap.dip,1+tap.widen end -- tap 3 holds its dip into the flex
	local u=smooth((t-A)/.08)
	return 1-tap.dip*(1-u),1+tap.widen*(1-u)
end
-- Pure: the rock (deg) t s after a tap's sound: damped, `cycles` swings over 0.4 s.
function V2.tapRock(i,t)
	local tap=V2.Taps[i];if not tap or not tap.rock or type(t)~="number"or t<0 or t>=.4 then return 0 end
	local u=t/.4
	return tap.rock*(1-u)*(1-u)*math.sin(u*math.pi*2*tap.cycles)
end
-- Pure: tap 3's shell flex: the scale t s after its sound (1.00 to 1.08 while the wobble climbs 5 Hz to 9 Hz).
function V2.flex(t)
	local F=V2.Crack.flex
	if type(t)~="number"or t<0 then return 1 end
	local u=math.clamp(t/F.time,0,1)
	local cycles=(F.hzFrom*u+.5*(F.hzTo-F.hzFrom)*u*u)*F.time -- the integral of a 5 -> 9 Hz sweep
	return 1+(F.to-1)*u+.012*u*math.sin(cycles*math.pi*2)
end
-- Pure: the pop's camera, t s after the burst: kick back (studs) and the FOV (40 -> 44 -> 42 over 0.4 s).
function V2.popCamera(t)
	local P=V2.Crack.pop
	if type(t)~="number"or t<0 then return 0,V2.Crack.fov end
	local u=math.clamp((t-.06)/(P.settle-.06),0,1)
	local up=math.clamp(t/.06,0,1)
	local fov=if t<.06 then V2.Crack.fov+(P.fovPeak-V2.Crack.fov)*smooth(up)else P.fovPeak+(P.fovRest-P.fovPeak)*smooth(u)
	return P.kick*smooth(up)*(1-.6*smooth(u)),fov
end
-- TODO(upload): the asset id of assets/eggs/textures/egg-companion-color-noseam.png (scripts/build_egg_textures.py
-- noseam): the first Bear's egg without its zig-zag until it opens. PLACEHOLDER 0 = not uploaded yet: the old map
-- (Models.Types.companion.colorMap, with the zig-zag) is used.
V2.NoSeamId=130682441511149 -- egg-companion-color-noseam.png (uploaded 2026-11-26)
-- The closed egg's map, or nil for the old one.
function V2.closedMap()return if type(V2.NoSeamId)=="number"and V2.NoSeamId>0 then "rbxassetid://"..V2.NoSeamId else nil end
-- Pure: does a press at `at` (px) count, on a screen of `size` (px)? The middle 60% each way.
function V2.inZone(at,size)
	if typeof(at)~="Vector2"or typeof(size)~="Vector2"then return false end
	local m=(1-V2.Crack.zone)/2
	return at.X>=size.X*m and at.X<=size.X*(1-m)and at.Y>=size.Y*m and at.Y<=size.Y*(1-m)
end
-- The longest an untouched egg takes to open (s): three waits, the beats and the creak.
function V2.longest()
	local C=V2.Crack
	return C.auto*#C.stops+C.stops[#C.stops]+C.creak
end
-- The pill's wording by the last input (UICopy keys for CrackFx:configure).
V2.CrackCopy=table.freeze({Touch="onb2.crack.tap",Gamepad="onb2.crack.pad",other="onb2.crack.click"})

-- ── Step 5: what now ─────────────────────────────────────────────────────────────────────────────────────────────────
V2.Guide=table.freeze({
	order={"needHi","needNest","needDeck"},
	ignore=20,                                            -- a prompt ignored this long shrinks and the next shows
	shrink=1.2,                                           -- the shrink to its icon before the next
	far=12,                                               -- a dotted trail leads to anything further than this (studs)
	fill=hex("#FFFFFF"),ink=hex("#1B2A4A"),arrow=hex("#FFD86B"),arrowPx=6,arrowHz=1,
	endCard=2.5,
})
V2.GuideCopy=table.freeze({needHi="onb2.guide.pet",needNest="onb2.guide.nest",needDeck="onb2.guide.deck"})
V2.GuideIcon=table.freeze({needHi="hand",needNest="moon",needDeck="deck"})
-- The bubble's button picture: the pad's X only (G and L2 still work, never printed; a phone taps, a computer clicks).
function V2.guideKey(input)return if input=="Gamepad"then "X"else nil end
-- Is a guide prompt that has shown since `shownAt` ignored at `now`?
function V2.ignored(shownAt,now)return type(shownAt)=="number"and type(now)=="number"and now-shownAt>=V2.Guide.ignore end
-- The bubble's arrow lift (px) at t; still under Reduced Motion.
function V2.arrowLift(t,reduced)
	if reduced then return 0 end
	return V2.Guide.arrowPx*(.5-.5*math.cos((t or 0)*V2.Guide.arrowHz*math.pi*2))
end
return V2
