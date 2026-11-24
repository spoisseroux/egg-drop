-- The Sleepy Nest as a landmark (artifacts/qa-2026-11-24-beta16/NEST-LANDMARK-LOOK.md; NEST-LANDMARK-BUILD-PLAN.md in
-- the same folder; the island session's template on branch claude/nest-landmark). Shared and pure: the switch, the
-- numbers NestClient and the server use, and the look of each state (blanket, moon, awning, breath).
--   Onboard.on("landmark")  its own onboarding v3 part (`/onboard landmark off`): off draws the twig nest as before.
--   It only applies where the nest stands at the egg corner's spot (corner on and the station split out): elsewhere the
--   nest is the twig nest whatever this says.
-- The template (Model NestLandmark: Body, Awning, Moon, BlanketDraped, BlanketSlipped, BlanketFolded, Collider,
-- LandmarkVersion) is mounted at ServerStorage.NestLandmark; the server copies it to ReplicatedStorage (beta only) and
-- each client clones it for its own nest. Without it (or with a stale LandmarkVersion) the client builds a greybox
-- with the same names. Nest-local studs: origin on the ground at the bowl's centre, front -Z, +X the plaza's west.
local Shared=script.Parent
local Onboard=require(Shared.Onboard)
local Land={}
Land.Template="NestLandmark"
Land.Version=1
Land.Block=5.6          -- the pets' box (was Nest.Block 4.2)
Land.Front=3.5          -- the prompt, the Show me trail's end and a catch-up landing (was Nest.Front 2.6)
Land.PromptAt=Vector3.new(0,1.0,-3.5)
Land.BearSpot=Vector3.new(-2.9,0,-2.0) -- on the baked straw mat
Land.PillAt=5.2         -- the pill's bottom edge over the root, fixed (it no longer rides the egg's scale)
Land.PeekAt=5.6         -- the gift peek tile's bottom
Land.ZzzAt=Vector3.new(.4,4.6,0)
Land.PinAt=8.2          -- the "Hatch!" pin (Show me) over the root: the top + 1.6
Land.EggScale=1.3       -- every look of today's egg, times this
Land.EggBase=2.15       -- the egg's base over the root (the straw bed's dent)
Land.Sign=table.freeze({centre=Vector3.new(0,1.15,-2.45),size=Vector3.new(1.7,.85,.1),tiltBack=10})
Land.Shadow=3.3         -- the contact shadow's radius (was 3.0)
Land.Scatter=table.freeze({inner=3.0,outer=4.0}) -- the straw scatter ring (was 2.7 to 3.6)
-- Motion (LOOK 4): the egg breathes every 4.5 s (+2.5% tall, -1% wide, rises .04; ease in and out, .6 s rest at the
-- bottom); the blanket follows .15 s late (scale to 1.02, its spill rolls 2 degrees); the moon sways 3 degrees at
-- .25 Hz, the awning 2 degrees at .3 Hz; ready lifts the awning 6 degrees. Reduced Motion: none of it.
Land.Breath=table.freeze({period=4.5,rest=.6,tall=.025,wide=-.01,rise=.04,blanketLag=.15,blanketScale=.02,spill=2})
Land.Sway=table.freeze({moon=table.freeze({angle=3,hz=.25}),awning=table.freeze({angle=2,hz=.3,phase=.37}),readyLift=6})
Land.Unroll=.6          -- Tuck in: the draped blanket unrolls from its lower edge (scale Y .2 to 1)
Land.Drop=.3            -- Hatch: the blanket drops to the bed before the hatch beat
-- The moon (LOOK 4): it replaces EggNestLight. Day: matte paper, no light. Dusk and night: lifted cream, a halo 1.6 at
-- 40%, a light #FFE9A6 range 9 at .6 (fading with the lamps). Ready, any hour: gold #FFE08A, halo 2.0 at 60%, the light
-- range 10 at .8, pulsing .5 Hz between 80% and 100%.
Land.Moon=table.freeze({
	day=table.freeze({lit=false,color=nil,halo=0,haloAlpha=0,range=9,brightness=0}),
	night=table.freeze({lit=true,color=Color3.fromHex("#FFE9A6"),halo=1.6,haloAlpha=.4,range=9,brightness=.6}),
	ready=table.freeze({lit=true,color=Color3.fromHex("#FFE08A"),halo=2.0,haloAlpha=.6,range=10,brightness=.8,pulseHz=.5,pulseLow=.8}),
})
Land.NightBelow=.3      -- daylight under this: dusk and night (the lamps' rule)

-- The template's numbers (branch claude/nest-landmark, nest-landmark-manifest.json, version 1): NestLandmarkData when
-- it is mounted, else this copy.
Land.DataCopy=table.freeze({
	version=1,front={0,0,-1},
	pivots={Awning={at={1.15,5.95,1.12},axis={-.2588,0,-.9659}},Moon={at={2.0,5.1,-.5},axis={0,0,1}},
		BlanketDraped={at={0,2.22,-2.47},up={0,1,0}},BlanketSlipped={at={0,2.217,-2.47},up={0,1,0}},
		BlanketFolded={at={-1.5,2.9,-1.1},long={-.5914,0,.8064}}},
	moonLight={2.0,4.25,-.5},moonTop={2.0244,4.7494,-.5},
	egg={base=2.15,size={1.6,2.1,1.6},centre={0,3.2,0}},dent={centre={0,2.1,0},size={1.56,.1,1.32}},bed={top=2.2,radius=1.3},
	rim=2.75,sign={centre={0,1.15,-2.45},size={1.7,.85,.1},tiltBack=10},mat={centre={-2.9,0,-2.0},radius=1.1},
	bearSpot={-2.9,0,-2.0},collider={centre={0,1.375,0},radius=2.4,height=2.75},
	parts={Body={center={-.7515,3.2971,-.3005},size={6.4971,6.5941,5.5991}},Awning={center={.324,5.5278,1.3341},size={2.1248,1.0379,2.3318}},
		Moon={center={2.084,4.4363,-.5},size={.8296,1.3701,.18}},BlanketDraped={center={0,2.6429,-.9426},size={2.3329,.9042,3.0549}},
		BlanketSlipped={center={-.4737,2.2666,-.865},size={3.8325,1.2767,3.2109}},BlanketFolded={center={-1.4806,2.9,-1.0806},size={1.1912,.35,1.2557}}},
})
function Land.data()
	local module=Shared:FindFirstChild("NestLandmarkData")
	if module then
		local ok,data=pcall(require,module)
		if ok and type(data)=="table"and type(data.pivots)=="table"and data.version==Land.Version then return data end
	end
	return Land.DataCopy
end

-- ── Switch ───────────────────────────────────────────────────────────────────────────────────────────────────────
function Land.on()return Onboard.on("landmark")end
-- The landmark stands only at the corner's spot (corner on and split) with its own switch on.
function Land.applies(landmark,cornerSpot)return landmark==true and cornerSpot==true end

-- ── States (pure) ────────────────────────────────────────────────────────────────────────────────────────────────
-- The blanket for a nest state: "folded" (no egg, not tucked, or the beat after a hatch), "draped" (tucked, napping) or
-- "slipped" (ready). view nil = empty.
function Land.blanket(hasEgg,tucked,ready)
	if not hasEgg then return "folded"end
	if ready then return "slipped"end
	return if tucked then "draped"else "folded"
end
-- The moon for (ready, daylight 0..1): Land.Moon.day / night / ready.
function Land.moon(ready,daylight)
	if ready then return Land.Moon.ready end
	if type(daylight)=="number"and daylight<Land.NightBelow then return Land.Moon.night end
	return Land.Moon.day
end
-- The ready moon's brightness factor at clock t: .5 Hz between 80% and 100%.
function Land.pulse(t,reduced)
	local m=Land.Moon.ready
	if reduced then return 1 end
	return m.pulseLow+(1-m.pulseLow)*(.5+.5*math.cos(t*m.pulseHz*2*math.pi))
end
-- One breath at clock t: (tall factor, wide factor, rise). Ease in and out over period - rest, then a rest at the bottom.
function Land.breath(t,reduced)
	local B=Land.Breath
	if reduced then return 1,1,0 end
	local p=t%B.period
	local active=B.period-B.rest
	if p>=active then return 1,1,0 end
	local s=.5-.5*math.cos(p/active*2*math.pi) -- 0 -> 1 -> 0
	return 1+B.tall*s,1+B.wide*s,B.rise*s
end
-- Sway angles (degrees) at clock t: moon, awning (plus the ready lift).
function Land.sway(t,ready,reduced)
	local S=Land.Sway
	local lift=if ready then S.readyLift else 0
	if reduced then return 0,lift end
	return S.moon.angle*math.sin(t*S.moon.hz*2*math.pi),S.awning.angle*math.sin((t*S.awning.hz+S.awning.phase)*2*math.pi)+lift
end
-- The draped blanket's unroll (0..1 of Unroll seconds): scale Y from .2 to 1 off its lower edge (ease out).
function Land.unroll(t)
	local x=math.clamp(t/Land.Unroll,0,1)
	return .2+.8*(1-(1-x)^2)
end
return table.freeze(Land)
