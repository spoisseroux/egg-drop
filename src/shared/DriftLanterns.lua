-- Drift lanterns, the garden's air (GARDEN-PLAY-BRIEF 2026-11-26 section 4, Fable): nine paper lanterns floating
-- 14 to 24 studs over the ground in three loose groups (over the hub, along the bridge, round the fountain), and one
-- soft seed-fluff emitter over the hub by day. Something to look up at. Pure data and maths here (DriftLanternsClient
-- builds and moves them on this client only); not touchable, never released, nothing replicates.
-- Gate: the Alive `air` switch (AliveAir, the beta place or Studio, ConfigService `alive_air`); off, nothing is built.
-- Day: unlit matte paper. Night is the lamps' rule (daylight under .3): the paper warms to #FFD98A and glows, and the
-- four lanterns nearest the camera carry a light (range 12, .5). Every number is a [PLACEHOLDER]; the spots are checked
-- against GardenClearance (air: off the paths, water, blocked ground, parks and Dash, drift included) by
-- scripts/DriftLanterns.spec.lua. Raycast them in Studio.
local Lanterns={}
Lanterns.Feature="air"
Lanterns.Cull=table.freeze({phone=90,desktop=150})
Lanterns.Rate=1/30          -- the loop's step while a lantern is near
Lanterns.LookRate=.5        -- day / night look and the lights' owners, this often
Lanterns.Sleep=.5
Lanterns.NightBelow=.3      -- daylight under this: lit (the lamps' rule, NestLandmark.NightBelow)
Lanterns.GlowSpan=.15       -- from just lit to full glow over this much daylight
Lanterns.FluffAbove=.7      -- the seed fluff drifts only in daylight over this
Lanterns.MinOver,Lanterns.MaxOver=14,24

-- One lantern: eight-sided (four crossed boards make the octagon), 1.6 across the flats, 2.2 tall with its cap.
Lanterns.Look=table.freeze({across=1.6,body=1.7,paper="#F6EBD2",warm="#FFD98A",dusk="#A88A5C",bark="#6B4A2E",
	hoop=.1,capAcross=.95,cap=.22,tassel=.8,tasselWidth=.12,
	accents=table.freeze({"#E8785A","#7FB8A4","#F2C14E"})})
function Lanterns.side()return Lanterns.Look.across*math.tan(math.pi/8)end
Lanterns.PartsEach=4+2+1+1  -- four boards, two hoops, the cap, the tassel
-- Motion (WorldMotion.pose "bob" and "sway"; the drift is ours): each its own phase.
Lanterns.Motion=table.freeze({bob=.6,bobPeriod=7,drift=1.5,driftPeriod=40,sway=4,swayPeriod=5.5})
-- The lights: the four nearest the camera, at night.
Lanterns.Lights=table.freeze({count=4,range=12,brightness=.5})

-- Where (XZ, the centre's height over World.groundY there, accent 1..3). Three each of the three accents.
--   hub      over (-30, 4): off the arrival path's end and the Dash round the plaza's edge
--   bridge   along (2.5, 21): the Dash runs on the deck and the stream either side, so they hang off its north banks
--   fountain round (52, 3): the north side only (the Dash runs just south of the spring)
Lanterns.Places=table.freeze({
	table.freeze({id="hub_1",group="hub",x=-35,z=-1,over=18.5,accent=1}),
	table.freeze({id="hub_2",group="hub",x=-25,z=-2,over=16.9,accent=2}),
	table.freeze({id="hub_3",group="hub",x=-30,z=-7,over=21.0,accent=3}),
	table.freeze({id="bridge_1",group="bridge",x=-15,z=27.5,over=17.4,accent=2}),
	table.freeze({id="bridge_2",group="bridge",x=-9,z=31,over=20.6,accent=3}),
	table.freeze({id="bridge_3",group="bridge",x=13,z=31,over=17.2,accent=1}),
	table.freeze({id="fountain_1",group="fountain",x=45,z=9,over=19.6,accent=3}),
	table.freeze({id="fountain_2",group="fountain",x=52,z=11,over=17.0,accent=1}),
	table.freeze({id="fountain_3",group="fountain",x=59,z=7,over=21.4,accent=2}),
})
-- The seed fluff: one box emitter over the hub lawn, 3 a second.
Lanterns.Fluff=table.freeze({x=-29,z=-4,over=10,size=Vector3.new(8,1,8),rate=3,colour="#F4EEDC",radius=4})

function Lanterns.partCount()return #Lanterns.Places*Lanterns.PartsEach+1 end -- and the fluff's host
-- How far a lantern reaches sideways from its spot (the drift circle and its own half width).
function Lanterns.reach()return Lanterns.Motion.drift+Lanterns.Look.across/2 end
-- Its top and bottom over its centre (the cap; the tassel's end).
function Lanterns.extent()
	local L=Lanterns.Look
	return L.body/2+L.hoop/2+L.cap,L.body/2+L.hoop/2+L.tassel
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
