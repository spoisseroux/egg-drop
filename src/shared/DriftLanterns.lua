-- Drift lanterns, the garden's air (GARDEN-PLAY-BRIEF 2026-11-26 section 4, Fable): nine paper lanterns floating
-- 14 to 24 studs over the ground in three loose groups (over the hub, along the bridge, round the fountain), and one
-- soft seed-fluff emitter over the hub by day. Something to look up at. Pure data and maths here (DriftLanternsClient
-- builds and moves them on this client only); not touchable, never released, nothing replicates.
-- Gate: the Alive `air` switch (AliveAir, the beta place or Studio, ConfigService `alive_air`); off, nothing is built.
-- The look (FABLE-REVIEW-B35 Fix 1: the first build read as dark woven hampers, this place's Fabric renders a knit): a
-- see-through paper globe round a Neon core, three accent ribs, two bark caps and a tassel; no Fabric anywhere. Day:
-- a warm heart, not a lamp. Night is the lamps' rule (daylight under .3), ramping over GlowSpan: the core and paper warm
-- and the four lanterns nearest the camera carry a light on their core (range 12, .5 to .8). Every number is a
-- [PLACEHOLDER]; the spots are checked against GardenClearance (air: off the paths, water, blocked ground, parks and
-- Dash, drift included) and the tree crowns by scripts/DriftLanterns.spec.lua. Raycast them in Studio.
local Lanterns={}
Lanterns.Feature="air"
Lanterns.Cull=table.freeze({phone=90,desktop=150})
Lanterns.Rate=1/30          -- the loop's step while a lantern is near
Lanterns.LookRate=.5        -- day / night look and the lights' owners, this often
Lanterns.Sleep=.5
Lanterns.NightBelow=.3      -- daylight under this: lit (the lamps' rule, NestLandmark.NightBelow)
Lanterns.GlowSpan=.25       -- from just lit to full glow over this much daylight (full at .05)
Lanterns.FluffAbove=.7      -- the seed fluff drifts only in daylight over this
Lanterns.MinOver,Lanterns.MaxOver=14,24 -- the centre through its bob, over the ground under its drift
Lanterns.LowestOver=12      -- the tassel's tip never lower than this over the ground

-- One lantern (Fable B35): globe Ball 1.8, core Ball 1.1, ribs .05 tall (1.84 across at y 0, 1.54 at y +/-.5), caps
-- .18 tall and .7 across at y +/-.86, a .12 x .8 x .12 tassel under the lower cap.
Lanterns.Look=table.freeze({
	globe=1.8,core=1.1,rib=.05,ribs=table.freeze({table.freeze({0,1.84}),table.freeze({.5,1.54}),table.freeze({-.5,1.54})}),
	cap=.18,capAcross=.7,capY=.86,tassel=.8,tasselWidth=.12,bark="#6B4A2E",
	-- Day (>= .3) and full night; glow 0..1 runs between them.
	day=table.freeze({core="#F2C98A",coreClear=.6,paper="#F6EBD2",paperClear=.25}),
	night=table.freeze({core="#FFD98A",coreClear=0,paper="#FFE6B0",paperClear=.4}),
	accents=table.freeze({"#E8785A","#7FB8A4","#F2C14E"})})
Lanterns.PartsEach=1+1+3+2+1 -- the globe, the core, three ribs, two caps, the tassel
-- Motion (WorldMotion.pose "bob" and "sway"; the drift is ours): each its own phase.
Lanterns.Motion=table.freeze({bob=.6,bobPeriod=7,drift=1.5,driftPeriod=40,sway=4,swayPeriod=5.5})
-- The lights: the four nearest the camera, at night, on their cores; brightness .5 just lit to .8 at full glow.
Lanterns.Lights=table.freeze({count=4,range=12,brightness=.5,full=.8})

-- Tree crowns a lantern keeps clear of (Fable B35: 20 studs XZ of the hatch tree's crown, 9 of any other). The island's
-- standing trees' crown middles (scripts/build_life_spots.py crown() over vegetation-placements.json less the declutter).
Lanterns.HatchCrown=table.freeze({x=-36.1,z=-18,keep=20})
Lanterns.CrownKeep=9
Lanterns.Crowns=table.freeze({
	{-99.44,-15.38},{-61.73,-24.38},{-70.41,-43.85},{-8.32,-47.79},{-76.22,15.68},{-66.38,27.92},{-33.63,37.73},
	{-27.89,56.38},{18.36,44.13},{52.38,56.02},{66.41,25.84},{73.99,12.38},{37.67,7.78},{72.43,-22.2},{37.61,-61.94},
	{75.77,-40.31},{-11.78,34.29},{100.09,44.36},{-76.8,-22.54},{35.88,-15.67},
})
-- Pure: nil when (x, z) keeps clear of every crown, else what it is too near.
function Lanterns.crownClash(x,z)
	local H=Lanterns.HatchCrown
	if Vector2.new(x-H.x,z-H.z).Magnitude<H.keep then return "the hatch tree's crown"end
	for _,c in ipairs(Lanterns.Crowns)do
		if Vector2.new(x-c[1],z-c[2]).Magnitude<Lanterns.CrownKeep then return string.format("the crown at (%g, %g)",c[1],c[2])end
	end
	return nil
end

-- Where (XZ, the centre's height over World.groundY there, accent 1..3). Three each of the three accents.
--   hub      over (-30, 4): the plaza's north side and the toy lawn, 20+ studs off the hatch tree's crown (Fable B35)
--   bridge   along (2.5, 21): the Dash runs on the deck and the stream either side, so they hang off its banks
--   fountain round (52, 3): the north side only (the Dash runs just south of the spring)
-- Fable B35 moves: hub_1 (-35, -1) -> (-38, 8) over 16; hub_2 (-25, -2) -> (-22, 5) over 15; hub_3 (-30, -7) ->
-- (-29, 12) over 18; fountain_1 (45, 9) -> (47, 13); bridge_1 (-15, 27.5) -> (-19, 27.5); bridge_2 (-9, 31) -> (-4, 31).
-- Nudged by the clearance spec (same rule: 20 off the hatch crown, 9 off any other): Fable's hub spots sat on the Dash
-- round the plaza (hub_1, hub_3) or the arrival path's end (hub_2), so hub_1 -> (-36, 3.5), hub_2 -> (-21, 3.5), hub_3
-- -> (-28.5, 20) over the toy lawn (off the knoll stairs' box too). Near (-4, 31) every spot is in the stream or inside 9 of the crown at
-- (-11.8, 34.3), so bridge_2 crosses to the bridge's south-east bank at (16, 14).
Lanterns.Places=table.freeze({
	table.freeze({id="hub_1",group="hub",x=-36,z=3.5,over=16,accent=1}),
	table.freeze({id="hub_2",group="hub",x=-21,z=3.5,over=15,accent=2}),
	table.freeze({id="hub_3",group="hub",x=-28.5,z=20,over=18,accent=3}),
	table.freeze({id="bridge_1",group="bridge",x=-19,z=27.5,over=17.4,accent=2}),
	table.freeze({id="bridge_2",group="bridge",x=16,z=14,over=20.6,accent=3}),
	table.freeze({id="bridge_3",group="bridge",x=13,z=31,over=17.2,accent=1}),
	table.freeze({id="fountain_1",group="fountain",x=47,z=13,over=19.6,accent=3}),
	table.freeze({id="fountain_2",group="fountain",x=52,z=11,over=17.0,accent=1}),
	table.freeze({id="fountain_3",group="fountain",x=59,z=7,over=21.4,accent=2}),
})
-- The seed fluff: one box emitter over the hub lawn, 3 a second.
Lanterns.Fluff=table.freeze({x=-29,z=-4,over=10,size=Vector3.new(8,1,8),rate=3,colour="#F4EEDC",radius=4})

function Lanterns.partCount()return #Lanterns.Places*Lanterns.PartsEach+1 end -- and the fluff's host
-- How far a lantern reaches sideways from its spot (the drift circle and its widest rib).
function Lanterns.reach()return Lanterns.Motion.drift+Lanterns.Look.ribs[1][2]/2 end
-- Its top and bottom over its centre (the upper cap's top; the tassel's tip).
function Lanterns.extent()
	local L=Lanterns.Look
	return L.capY+L.cap/2,L.capY+L.cap/2+L.tassel
end
-- Pure: the look for a glow (0 day .. 1 full night): core and paper colours (Color3) and transparencies, the lights'
-- brightness.
function Lanterns.lookAt(glow)
	local L=Lanterns.Look
	glow=math.clamp(glow or 0,0,1)
	local function mix(a,b)
		local p,q=Color3.fromHex(a),Color3.fromHex(b)
		return Color3.new(p.R+(q.R-p.R)*glow,p.G+(q.G-p.G)*glow,p.B+(q.B-p.B)*glow)
	end
	local d,n=L.day,L.night
	return{core=mix(d.core,n.core),coreClear=d.coreClear+(n.coreClear-d.coreClear)*glow,
		paper=mix(d.paper,n.paper),paperClear=d.paperClear+(n.paperClear-d.paperClear)*glow,
		light=Lanterns.Lights.brightness+(Lanterns.Lights.full-Lanterns.Lights.brightness)*glow}
end

local function hash(i,k)
	local x=math.sin(i*91.17+k*13.31)*24634.6345
	return x-math.floor(x)
end
-- Each lantern's phases (bob, drift, sway), fixed by its number.
function Lanterns.phases(i)return hash(i,1),hash(i,2),hash(i,3)end
-- The drift offset (studs, XZ) of lantern i at t.
function Lanterns.drift(i,t)
	local M=Lanterns.Motion
	local _,phase=Lanterns.phases(i)
	local a=math.pi*2*(t/M.driftPeriod+phase)
	return Vector3.new(math.cos(a)*M.drift,0,math.sin(a)*M.drift)
end
-- Pure: the night glow for a daylight, 0 (day, matte paper) .. 1 (full glow); nil daylight is day.
function Lanterns.glow(daylight)
	if type(daylight)~="number"or daylight>=Lanterns.NightBelow then return 0 end
	return math.clamp((Lanterns.NightBelow-daylight)/Lanterns.GlowSpan,0,1)
end
function Lanterns.lit(daylight)return type(daylight)=="number"and daylight<Lanterns.NightBelow end
function Lanterns.fluff(daylight)return type(daylight)=="number"and daylight>Lanterns.FluffAbove end
-- Pure: the indices of the `n` lanterns nearest `point` (positions: a list of Vector3), nearest first.
function Lanterns.nearest(positions,point,n)
	local order={}
	for i=1,#positions do order[i]=i end
	table.sort(order,function(a,b)
		local da,db=(positions[a]-point).Magnitude,(positions[b]-point).Magnitude
		if da==db then return a<b end
		return da<db
	end)
	local out={}
	for k=1,math.min(n,#order)do out[k]=order[k]end
	return out
end
return table.freeze(Lanterns)
