-- Drift balloons, the garden's air (GARDEN-PLAY-BRIEF-2 2026-11-26 section 6, Fable; Spencer: "maybe they could be
-- little hot air balloons, with sometimes a pet mascot in ... and at night they all light up with soft fire
-- flickering"). The module keeps its old name (DriftLanterns) so the switch, the probes and the spec runner are
-- unchanged: nine small hot-air balloons floating over the ground in three loose groups (over the hub, along the
-- bridge, round the fountain), and one soft seed-fluff emitter over the hub by day. Pure data and maths here
-- (DriftLanternsClient builds and moves them on this client only); not touchable, never released, nothing replicates.
-- Gate: the Alive `air` switch (AliveAir, the beta place or Studio, ConfigService `alive_air`); off, nothing is built.
-- One balloon (Fable, section 6): a matte envelope (Ball 3.0) with four accent gore rings, an accent skirt, four
-- ropes, a wood basket and rim, and a Neon burner flame under the skirt. 13 parts, SmoothPlastic and Wood, no Fabric.
-- Every few seconds the burner fires (the flame grows 1.6x, the balloon lifts .4). Night is the lamps' rule (daylight
-- under .3), ramping over GlowSpan: the flame comes up and flickers (two sines, 7.3 and 11.1 Hz, 15%), the envelope
-- warms, and the four balloons nearest the camera carry a PointLight at the burner (range 12, .5 to .8, flickering
-- with it), which also lights the envelope's underside warm.
-- Three of the nine carry a mascot, picked per session (pickMascots): a baby pet (PetFactory) at .45 world scale with a
-- random roster pet and palette, never a player's, as an imp (horn buds, a warm palette) or a cherub (folded wings, a
-- soft palette and a halo). Those three hang lower (MascotOver). The mascot looks about every 4 to 7 s, now and then
-- emotes (PetIdleBeats' poses), and turns, waves 1.2 s and hops for the local player within 35 studs (at most every 10 s).
-- Every number is a [PLACEHOLDER]; the spots are checked against GardenClearance (air: off the paths, water, blocked
-- ground, parks and Dash, drift included) and the tree crowns by scripts/DriftLanterns.spec.lua. Raycast them in Studio.
local Lanterns={}
Lanterns.Feature="air"
Lanterns.Cull=table.freeze({phone=90,desktop=150})
Lanterns.Rate=1/30          -- the loop's step while a balloon is near
Lanterns.LookRate=.5        -- day / night look and the lights' owners, this often
Lanterns.Sleep=.5
Lanterns.NightBelow=.3      -- daylight under this: lit (the lamps' rule, NestLandmark.NightBelow)
Lanterns.GlowSpan=.25       -- from just lit to full glow over this much daylight (full at .05)
Lanterns.FluffAbove=.7      -- the seed fluff drifts only in daylight over this
-- The envelope's centre through its bob and a burn's lift, over the ground under its drift. A mascot's balloon hangs
-- at MascotOver (Fable: 14) so the pet reads from the ground; the basket's bottom never lower than LowestOver (two
-- avatars and a jump clear).
Lanterns.MinOver,Lanterns.MaxOver=13,25
Lanterns.MascotOver=14
Lanterns.LowestOver=9.5

-- One balloon (Fable, section 6). Offsets are from the envelope's centre.
Lanterns.Look=table.freeze({
	envelope=3.0,envelopeColour="#F6EBD2",
	gore=.06,goreAcross=3.04,gores=4,                 -- thin upright rings, 45 degrees apart
	skirt=.5,skirtAcross=1.2,skirtY=-1.6,
	rope=.04,ropeLength=1.0,ropeAt=.4,ropeColour="#8A6A3C", -- four, at the basket's corners
	basket=Vector3.new(.9,.7,.9),basketColour="#8A6A3C",
	rim=Vector3.new(.95,.1,.95),rimColour="#6B4A2E",
	flame=.28,flameColour="#FFB347",flameY=-2.1,
	accents=table.freeze({"#E8785A","#7FB8A4","#F2C14E"}),
	-- Day (>= .3) and full night; glow 0..1 runs between them. The envelope warms toward `warm` by `warmth` (the lower
	-- half's warmth on the nearest four comes from the burner's light on its underside).
	day=table.freeze({flameClear=.55}),
	night=table.freeze({flameClear=0}),
	warm="#FFD98A",warmth=.35,
})
do
	local L=Lanterns.Look
	-- Derived heights under the centre: the skirt's bottom, the ropes' foot (the basket's top), the basket's bottom.
	Lanterns.SkirtBottom=L.skirtY-L.skirt/2
	Lanterns.BasketTop=Lanterns.SkirtBottom-L.ropeLength
	Lanterns.BasketBottom=Lanterns.BasketTop-L.basket.Y
end
Lanterns.PartsEach=1+4+1+4+1+1+1 -- the envelope, four gores, the skirt, four ropes, the basket, its rim, the flame
-- Motion (WorldMotion.pose "bob" and "sway" about the envelope's centre; the drift is ours): each its own phase.
Lanterns.Motion=table.freeze({bob=.6,bobPeriod=7,drift=1.5,driftPeriod=40,sway=2.5,swayPeriod=6.5})
-- The burner (Fable): every 6 to 10 s the flame grows 1.6x for .8 s and the balloon lifts .4 (up and settled in Rise).
Lanterns.Burn=table.freeze({gapMin=6,gapMax=10,length=.8,grow=1.6,ease=.15,lift=.4,rise=2.4})
-- The night flicker (Fable): two sines, 7.3 and 11.1 Hz, 15% on the flame's size and its light.
Lanterns.Flicker=table.freeze({a=7.3,b=11.1,depth=.15,mix=.6})
-- The lights: the four nearest the camera, at night, at their burners; brightness .5 just lit to .8 at full glow.
Lanterns.Lights=table.freeze({count=4,range=12,brightness=.5,full=.8})
-- Sounds (Fable): the burn is `asmr_exhale_a/b` pitched .7 within 30 studs of me, plus the new `burner_whoosh` takes
-- once they have ids; the mascot's wave is `snack_happy_squeak` at .3 within 25.
Lanterns.Sounds=table.freeze({
	burn=table.freeze({cues=table.freeze({"asmr_exhale_a","asmr_exhale_b","burner_whoosh_a","burner_whoosh_b"}),speed=.7,
		volume=.35,range=30,vary=.06}),
	squeak=table.freeze({cues=table.freeze({"snack_happy_squeak"}),speed=1,volume=.3,range=25,vary=.06}),
})
Lanterns.NewTakes=table.freeze({burner_whoosh_a=0,burner_whoosh_b=0}) -- [PLACEHOLDER] ids: Fable's new takes, not uploaded

-- The mascots (Fable, section 6).
Lanterns.Mascot=table.freeze({
	count=3,scale=.45,           -- PetFactory world scale (garden pets are .72)
	lookMin=4,lookMax=7,         -- a look about (or an emote) this often
	emoteChance=.3,              -- of those, this many are an emote instead of a look
	waveRange=35,waveGap=10,waveFor=1.2, -- the local player within 35: turn, wave 1.2 s, hop; at most every 10 s
	hop=.22,hopFor=.45,          -- the hop after the wave (studs, s)
	turnRate=3,                  -- radians a second toward the player (or back)
	near=60,slowEvery=4,         -- past 60 studs from the camera the pet is posed every 4th step
	paws=.08,                    -- the paws' top this far over the basket's rim
	halo=.5,haloThick=.04,haloOver=.25,haloBob=.05,haloPeriod=2.2,haloColour="#FFE9A8",
})
-- Emotes from PetIdleBeats (no sit: it would sink into the basket; no wave: the wave is the player's). Night: sleepier.
Lanterns.Emotes=table.freeze({
	day=table.freeze({stretch=3,wiggle=4,scratch=2,sneeze=1,yawn=1}),
	night=table.freeze({yawn=5,stretch=2,wiggle=1,scratch=1}),
})
Lanterns.Kinds=table.freeze({
	imp=table.freeze({features=table.freeze({horns=3,claws=0,wings=0}),halo=false,
		palettes=table.freeze({
			table.freeze({bodyMix="citrus:rose",bodyRank=1,secondary="rose"}),
			table.freeze({body="rose",bodyRank=1,secondary="citrus"}),
			table.freeze({body="citrus",bodyRank=2,secondary="rose"}),
		})}),
	cherub=table.freeze({features=table.freeze({horns=0,claws=0,wings=3}),halo=true,
		palettes=table.freeze({
			table.freeze({body="original",secondary="citrus"}),
			table.freeze({body="tide",bodyRank=1,secondaryWhite=true}),
			table.freeze({body="rose",bodyRank=1,secondaryWhite=true}),
		})}),
})
Lanterns.KindOrder=table.freeze({"imp","cherub"})

-- Tree crowns a balloon keeps clear of (Fable B35: 20 studs XZ of the hatch tree's crown, 9 of any other). The island's
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

-- Where (XZ, the envelope centre's height over World.groundY there, accent 1..3). Three each of the three accents.
-- The lanterns' nine spots (Fable B35 and the clearance spec's nudges; see git history), nudged for the balloons' wider
-- reach (envelope 3.04 across, not 1.84) by the same rules with half a stud to spare: hub_1 (-36, 3.5) -> (-36.5, 2),
-- hub_2 (-21, 3.5) -> (-21, 2.5) (the arrival path), hub_3 (-28.5, 20) -> (-27, 20.3) (the knoll stairs), bridge_3
-- (13, 31) -> (14, 31) (the stream). Round the bridge every spot is now on the stream or the Dash, so bridge_2 crosses
-- from (16, 14) to the east bank at (29.5, 18.5), on the way to the fountain.
Lanterns.Places=table.freeze({
	table.freeze({id="hub_1",group="hub",x=-36.5,z=2,over=16,accent=1}),
	table.freeze({id="hub_2",group="hub",x=-21,z=2.5,over=15,accent=2}),
	table.freeze({id="hub_3",group="hub",x=-27,z=20.3,over=18,accent=3}),
	table.freeze({id="bridge_1",group="bridge",x=-19,z=27.5,over=17.4,accent=2}),
	table.freeze({id="bridge_2",group="bridge",x=29.5,z=18.5,over=20.6,accent=3}),
	table.freeze({id="bridge_3",group="bridge",x=14,z=31,over=17.2,accent=1}),
	table.freeze({id="fountain_1",group="fountain",x=47,z=13,over=19.6,accent=3}),
	table.freeze({id="fountain_2",group="fountain",x=52,z=11,over=17.0,accent=1}),
	table.freeze({id="fountain_3",group="fountain",x=59,z=7,over=21.4,accent=2}),
})
Lanterns.Groups=table.freeze({"hub","bridge","fountain"})
-- The seed fluff: one box emitter over the hub lawn, 3 a second.
Lanterns.Fluff=table.freeze({x=-29,z=-4,over=10,size=Vector3.new(8,1,8),rate=3,colour="#F4EEDC",radius=4})

-- Every part but the mascots' rigs: nine balloons, the fluff's host and the sound anchor (a cherub's halo is one more).
function Lanterns.partCount()return #Lanterns.Places*Lanterns.PartsEach+1+1 end
-- How far a balloon reaches sideways from its spot (the drift circle, the envelope's gores, a little sway).
function Lanterns.reach()
	local M=Lanterns.Motion
	return M.drift+Lanterns.Look.goreAcross/2+math.sin(math.rad(M.sway))*math.abs(Lanterns.BasketBottom)
end
-- Its top and bottom from the envelope's centre (the envelope's top; the basket's bottom), both positive.
function Lanterns.extent()
	return Lanterns.Look.goreAcross/2,-Lanterns.BasketBottom
end
-- The rest height over the ground for place i: MascotOver when it carries a mascot.
function Lanterns.over(place,mascot)return if mascot then Lanterns.MascotOver else place.over end

local function mix(a,b,t)
	local p,q=Color3.fromHex(a),Color3.fromHex(b)
	return Color3.new(p.R+(q.R-p.R)*t,p.G+(q.G-p.G)*t,p.B+(q.B-p.B)*t)
end
-- Pure: the look for a glow (0 day .. 1 full night): the envelope's colour (Color3), the flame's transparency, the
-- lights' brightness.
function Lanterns.lookAt(glow)
	local L=Lanterns.Look
	glow=math.clamp(glow or 0,0,1)
	return{envelope=mix(L.envelopeColour,L.warm,L.warmth*glow),
		flameClear=L.day.flameClear+(L.night.flameClear-L.day.flameClear)*glow,
		light=Lanterns.Lights.brightness+(Lanterns.Lights.full-Lanterns.Lights.brightness)*glow}
end

local function hash(i,k)
	local x=math.sin(i*91.17+k*13.31)*24634.6345
	return x-math.floor(x)
end
-- Each balloon's phases (bob, drift, sway, flicker), fixed by its number.
function Lanterns.phases(i)return hash(i,1),hash(i,2),hash(i,3),hash(i,4)end
-- The drift offset (studs, XZ) of balloon i at t.
function Lanterns.drift(i,t)
	local M=Lanterns.Motion
	local _,phase=Lanterns.phases(i)
	local a=math.pi*2*(t/M.driftPeriod+phase)
	return Vector3.new(math.cos(a)*M.drift,0,math.sin(a)*M.drift)
end
-- Pure: the night glow for a daylight, 0 (day) .. 1 (full glow); nil daylight is day.
function Lanterns.glow(daylight)
	if type(daylight)~="number"or daylight>=Lanterns.NightBelow then return 0 end
	return math.clamp((Lanterns.NightBelow-daylight)/Lanterns.GlowSpan,0,1)
end
function Lanterns.lit(daylight)return type(daylight)=="number"and daylight<Lanterns.NightBelow end
function Lanterns.fluff(daylight)return type(daylight)=="number"and daylight>Lanterns.FluffAbove end
-- Pure: the indices of the `n` balloons nearest `point` (positions: a list of Vector3), nearest first.
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

local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
-- Pure: a burn `age` seconds old: the flame's growth (1 .. Burn.grow) and the balloon's lift (studs). Before or long
-- after a burn: 1 and 0.
function Lanterns.burn(age)
	local B=Lanterns.Burn
	if type(age)~="number"or age<0 then return 1,0 end
	local grow=1
	if age<B.length then
		local w=math.min(age/B.ease,(B.length-age)/B.ease,1)
		grow=1+(B.grow-1)*smooth(w)
	end
	local lift=if age<B.rise then B.lift*math.sin(math.pi*age/B.rise)else 0
	return grow,lift
end
-- Pure: the night flicker at t for a phase: 1 +/- Flicker.depth (two sines that never quite repeat).
function Lanterns.flicker(t,phase)
	local F=Lanterns.Flicker
	phase=phase or 0
	local a=math.sin(math.pi*2*(F.a*t+phase))
	local b=math.sin(math.pi*2*(F.b*t+phase*1.7+.31))
	return 1+F.depth*(F.mix*a+(1-F.mix)*b)
end
-- Pure: the next burn's gap, a look's gap (`random` has NextNumber).
function Lanterns.burnGap(random)return random:NextNumber(Lanterns.Burn.gapMin,Lanterns.Burn.gapMax)end
function Lanterns.lookGap(random)return random:NextNumber(Lanterns.Mascot.lookMin,Lanterns.Mascot.lookMax)end
-- Pure: what the mascot does at its next beat: "look" mostly, else a weighted emote (night: sleepier).
function Lanterns.pickBeat(random,daylight)
	if random:NextNumber()>=Lanterns.Mascot.emoteChance then return "look"end
	local weights=if Lanterns.lit(daylight)then Lanterns.Emotes.night else Lanterns.Emotes.day
	local names={}
	for name in pairs(weights)do table.insert(names,name)end
	table.sort(names)
	local total=0
	for _,name in ipairs(names)do total+=weights[name]end
	local roll=random:NextNumber()*total
	for _,name in ipairs(names)do
		roll-=weights[name]
		if roll<=0 then return name end
	end
	return names[#names]
end
-- Pure: should a mascot wave now? The local player within waveRange and the last wave WaveGap ago or more.
function Lanterns.shouldWave(distance,now,lastWave)
	local M=Lanterns.Mascot
	return type(distance)=="number"and distance<=M.waveRange and now-(lastWave or -math.huge)>=M.waveGap
end
-- Pure: the hop after a wave, `age` seconds after the wave began: studs up (0 outside the hop).
function Lanterns.hop(age)
	local M=Lanterns.Mascot
	local t=(age or -1)-M.waveFor
	if t<0 or t>=M.hopFor then return 0 end
	return M.hop*math.sin(math.pi*t/M.hopFor)
end
-- Pure: the session's mascots. One balloon in each group carries one (so they spread round the garden); the kinds
-- are one imp, one cherub and one either way, shuffled; each a random roster pet and a random palette of its kind.
-- roster: a list of pet ids (the pets players can hatch now). Returns {{place = index, petId, kind, appearance}}.
function Lanterns.pickMascots(random,roster)
	local out={}
	if type(roster)~="table"or #roster==0 then return out end
	local kinds={"imp","cherub",Lanterns.KindOrder[random:NextInteger(1,2)]}
	for i=#kinds,2,-1 do local j=random:NextInteger(1,i);kinds[i],kinds[j]=kinds[j],kinds[i]end
	for g,group in ipairs(Lanterns.Groups)do
		if #out>=Lanterns.Mascot.count then break end
		local spots={}
		for i,p in ipairs(Lanterns.Places)do if p.group==group then table.insert(spots,i)end end
		local kind=kinds[g]
		local K=Lanterns.Kinds[kind]
		local palette=K.palettes[random:NextInteger(1,#K.palettes)]
		local appearance={featureStages=table.clone(K.features),toyId="none",charmVisible=false,appearanceGeneration=0}
		for key,value in pairs(palette)do appearance[key]=value end
		table.insert(out,{place=spots[random:NextInteger(1,#spots)],petId=roster[random:NextInteger(1,#roster)],kind=kind,
			appearance=appearance})
	end
	return out
end
return table.freeze(Lanterns)
