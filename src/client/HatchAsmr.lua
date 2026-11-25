-- The ASMR hatch (ASMR-AND-SCALE-LOOK.md section 1; Spencer: "asmr-y egg hatching ... this needs to be a cathartic
-- experience"). Build, release, stillness: small dry cracks get closer together, one full pop lands in the ear and the
-- hand on the burst, then a beat of quiet and (sometimes) a soft exhale.
--
-- This is the sound and vibration layer on today's hatch clock (HatchRarityCue.timing), not the tap-to-crack ritual:
-- the egg still hatches on its own. Each hatch gets extra events for HatchRarityCue.new (`extra`): the players
-- (HatchCinematic, StatEggReveal, NameEggReveal, PetArrivalHatch) play them with the tier line and call
-- HatchAsmr.fire(event) beside each play, so a crack's buzz starts in the same frame as its sound.
--
-- Beta and Studio only: Alive "asmr" (flag AliveAsmr, ConfigService `alive_asmr`, missing = on; owner chat
-- /alive asmr <on|off|clear>). Off, layer() answers nil and the hatch is exactly today's.
--
-- The 100th hatch (section 1 "The 100th hatch"): every layer has 2 to 5 recorded variants (scripts/synth_asmr.py, each
-- its own seed), never the same twice running; playback speed 0.94 to 1.06 times the egg type's shell pitch; gain
-- +-1.5 dB; the cracks drift +-12 ms; random layer picks (a crumb after crack 1, a soft creak under crack 2, 2 to 4
-- flakes after the pop); the exhale only on the first hatch of a streak and every third after it.
-- Pure parts (schedule, pick, jitter, the streak) take their random numbers from the caller: specs in
-- scripts/HatchAsmr.spec.lua.
local Asmr={}

-- One-shots: cue prefix, variants, base gain (files peak at -3 dBFS; this sets the level, under the tier sting at
-- 0.55 to 1), the haptic pattern that fires with it (Haptics.Patterns), and how far its start may drift (s).
local function layer(cue,variants,gain,haptic,drift)
	return table.freeze({cue=cue,variants=table.freeze(variants),gain=gain,haptic=haptic,drift=drift or 0})
end
Asmr.Layers=table.freeze({
	settle=layer("asmr_egg_set",{"a","b","c"},.16,"settle",.008),
	crack1=layer("asmr_crack1",{"a","b","c"},.24,"crack1",.012),
	crack2=layer("asmr_crack2",{"a","b","c"},.32,"crack2",.012),
	creak=layer("asmr_creak",{"a","b","c"},.20,"creak"),
	creakLong=layer("asmr_creak_long",{"a","b"},.22,"creak_long"),
	pop=layer("asmr_pop",{"a","b","c"},.42,"pop"),
	flake=layer("asmr_flake",{"a","b","c","d","e"},.07,nil),
	exhale=layer("asmr_exhale",{"a","b"},.08,nil),
})
-- Every cue name (BoardAudio registers these).
function Asmr.cues()
	local out={}
	for _,name in ipairs({"settle","crack1","crack2","creak","creakLong","pop","flake","exhale"})do
		local l=Asmr.Layers[name]
		for _,v in ipairs(l.variants)do table.insert(out,l.cue.."_"..v)end
	end
	return out
end

-- The beats on the hatch clock (s). The egg settles, cracks twice (the second on today's crack glint at 0.65), creaks
-- for the 0.18 s before the burst and pops on it. A Rare item's long creak rides its wind-up and ends on the freeze.
Asmr.Beats=table.freeze({settle=.04,crack1=.36,crack2=.65,creak=.18,creakLong=.35,freezeLead=.12,
	crumbAfter={.04,.07},crumbChance=.35,underCreakChance=.5,underCreakGain=.4,
	flakes={2,4},flakeFrom=.10,flakeTo=.55,flakeGap=.03,exhaleAfter=.25})
-- Under Reduced Motion the sounds and the buzz stay (they are not motion), on a shorter line.
Asmr.Reduced=table.freeze({crack1=.02,crack2=.12,room=.25})
Asmr.Speed=table.freeze({.94,1.06})
Asmr.GainDb=1.5
-- Each egg type's shell (section 1: thick and low to thin and bright).
Asmr.ShellPitch=table.freeze({companion=1.00,stat=.92,toy=.90,material=1.04,feature=1.00,hue=1.10,name=1.06})
-- Streaks: a hatch within this long of the last one continues the streak.
Asmr.StreakGap=20
Asmr.ExhaleEvery=3

-- Pure: a variant of `layerName` from u in [0, 1), never `last` (when there are two or more).
function Asmr.pick(layerName,u,last)
	local l=Asmr.Layers[layerName]
	local n=#l.variants
	if n==1 then return l.variants[1]end
	local options={}
	for _,v in ipairs(l.variants)do if v~=last then table.insert(options,v)end end
	return options[math.clamp(math.floor(u*#options)+1,1,#options)]
end
-- Pure: speed and gain for a layer from two numbers in [0, 1).
function Asmr.jitter(layerName,kind,u1,u2)
	local l=Asmr.Layers[layerName]
	local speed=(Asmr.Speed[1]+(Asmr.Speed[2]-Asmr.Speed[1])*u1)*(Asmr.ShellPitch[kind]or 1)
	local db=(u2*2-1)*Asmr.GainDb
	return speed,l.gain*10^(db/20)
end
-- Pure: the streak after a hatch at `now`; plays the exhale on the first of a streak and every third after it.
function Asmr.streak(state,now)
	local count=if state.lastAt and now-state.lastAt<=Asmr.StreakGap then(state.streak or 0)+1 else 1
	state.lastAt,state.streak=now,count
	return count,(count-1)%Asmr.ExhaleEvery==0
end

-- Pure: the extra events for one hatch. timing: HatchRarityCue.timing (burst, jackpot, reduced). random(): a number
-- in [0, 1). state: {last = {layer = variant}, lastAt, streak} carried hatch to hatch. now: seconds (streaks).
-- Each event: {at, cue, speed, gain, pre = true, haptic, layer}. Sorted by `at`; none before 0.
function Asmr.schedule(timing,kind,random,state,now)
	state.last=state.last or {}
	local B=Asmr.Beats
	local out={}
	local function add(name,at,gainScale,haptic)
		local l=Asmr.Layers[name]
		local variant=Asmr.pick(name,random(),state.last[name])
		state.last[name]=variant
		local speed,gain=Asmr.jitter(name,kind,random(),random())
		if l.drift>0 then at+=(random()*2-1)*l.drift end
		local event={at=math.max(0,at),cue=l.cue.."_"..variant,speed=speed,gain=gain*(gainScale or 1),pre=true,layer=name}
		if haptic~=false then event.haptic=haptic or l.haptic end
		table.insert(out,event)
		return event
	end
	local burst=timing.burst or 0
	local popHaptic=if timing.jackpot then "jackpot"else "pop"
	local _,exhale=Asmr.streak(state,now or 0)
	if timing.reduced then
		if burst>=Asmr.Reduced.room then
			add("crack1",Asmr.Reduced.crack1)
			add("crack2",Asmr.Reduced.crack2)
		end
		add("pop",burst,1,popHaptic)
	else
		add("settle",B.settle)
		add("crack1",B.crack1)
		if random()<B.crumbChance then add("flake",B.crack1+B.crumbAfter[1]+random()*(B.crumbAfter[2]-B.crumbAfter[1]))end
		add("crack2",B.crack2)
		-- A soft creak under the second crack (section 1: "under the bulge in touch 2, at -8 dB more"); no buzz of its own.
		if random()<B.underCreakChance then add("creak",B.crack2+.03,B.underCreakGain,false)end
		if timing.jackpot then
			-- The long creak ends on the freeze (the jackpot's wind-up), the pop on the burst.
			add("creakLong",burst-B.freezeLead-B.creakLong)
		else
			add("creak",burst-B.creak)
		end
		add("pop",burst,1,popHaptic)
	end
	-- Flakes after the pop: 2 to 4, at least 30 ms apart, sound only.
	local count=B.flakes[1]+math.floor(random()*(B.flakes[2]-B.flakes[1]+1))
	local at=burst+B.flakeFrom
	for _=1,count do
		at+=B.flakeGap+random()*((B.flakeTo-B.flakeFrom)/count)
		if at>burst+B.flakeTo+B.flakeGap then break end
		add("flake",at)
	end
	-- Stillness, then (sometimes) the exhale.
	if exhale then add("exhale",burst+B.exhaleAfter)end
	table.sort(out,function(a,b)return a.at<b.at end)
	return out
end

-- ---------------------------------------------------------------- the game side

-- The switch (Alive "asmr"). Specs never reach it.
function Asmr.on()
	local ok,on=pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Alive).on("asmr")
	end)
	return ok and on==true
end
local state={}
local rng
-- The extra events for this hatch, or nil with the switch off (HatchRarityCue.new's `extra`).
function Asmr.layer(kind,result,reduced)
	if not Asmr.on()then return nil end
	local ok,events=pcall(function()
		local Rarity=require(script.Parent.HatchRarityCue)
		local tier=Rarity.tier(kind,result)
		local timing=Rarity.timing(tier,kind,reduced==true)
		rng=rng or Random.new()
		return Asmr.schedule(timing,kind,function()return rng:NextNumber()end,state,os.clock())
	end)
	return if ok then events else nil
end
-- The buzz that goes with an event (beside its sound; the sound may be missing or muted, the buzz still plays).
function Asmr.fire(event)
	if type(event)~="table"or not event.haptic then return false end
	local ok,played=pcall(function()return require(script.Parent.Haptics).play(event.haptic)end)
	return ok and played==true
end
return Asmr
