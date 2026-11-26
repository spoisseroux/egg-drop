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
	pad=8,glow=hex("#FFE58A"),glowIdle=.2,glowFinal=.6,seam=hex("#FFFBE6"),
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
-- How much of the crack seam is lit: a third more each combo.
function V2.seam(combos)return math.clamp(math.floor(tonumber(combos)or 0),0,3)/3 end
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
-- Combo 3's finale `age` s in: glow (alpha), lift (card heights), fade (0 shown .. 1 gone).
function V2.finale(age,reduced)
	local D=V2.Deck
	local u=math.clamp((age or 0)/D.finale,0,1)
	local glow=D.glowIdle+(D.glowFinal-D.glowIdle)*u
	return glow,if reduced then 0 else D.lift*smooth(u),u
end
-- The sound and buzz of combo n (HatchAsmr layer names; no pop: the pop belongs to step 3).
V2.ComboLayers=table.freeze({"crack1","crack2","creakLong"})

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

-- ── Step 3: crack it ─────────────────────────────────────────────────────────────────────────────────────────────────
V2.Crack=table.freeze({
	dist=5,up=1.6,fov=40,tween=.6,vignette=hex("#0B1220"),vignetteAlpha=.35,pill=hex("#FFD86B"),
	stops={.05,.4,.75},                                   -- the ritual's clock: a stop per tap, a beat between
	handAfter=3,auto=7,                                    -- no countdown shown; the hand at 3 s, the tap itself at 7 s
	creak=.25,swell=1.08,pop={up=3,fade=.5,flash=.12,hold=.6},
	zone=.6,                                               -- any tap in the middle 60% of the screen counts
})
-- What each tap does: the rock, the crack line count, the flakes, the sounds (HatchAsmr layers) and the buzz.
V2.Taps=table.freeze({
	{rock=10,flakes=4,layers={"crack1","flake"},haptic="crack1"},
	{rock=14,flakes=6,layers={"crack2","creak"},haptic="crack2",leak=true},
	{rock=0,flakes=3,layers={"creakLong"},haptic="creak_long",pop=true},
})
V2.ReducedFlakes=3
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
