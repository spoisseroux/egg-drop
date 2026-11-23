-- Garden hour slice E (GARDEN-HOUR-BUILD-PLAN-2026-11-23, architect review): pets stay awake through the hour's night.
-- PetFace.moodDaylight() feeds the three mood rules (PetExpression.garden, PetIdleBeats night weights, PetCooScheduler
-- NightWait); while GardenHour.on() it never drops below .3, so none of them reads night. Off: today's numbers, so the
-- rules behave exactly as before. Glow reads the light (Face.daylight), but Fable R1 caps the two-tone night glow ramp
-- (PetMaterials.nightGlow) at .6 while the hour is on (HollowClock.hourOn); off, the ramp as it was.
-- Usage (Client): require(<ZZSpecs copy>)(StarterPlayer.StarterPlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Hour=require(Shared.GardenHour)
	local Aero=require(Shared.Aero)
	local Face=require(client.PetFace)
	local Clock=require(client.HollowClock)
	local Expression=require(client.PetExpression)
	local Beats=require(client.PetIdleBeats)
	local Coos=require(client.PetCooScheduler)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	-- The coo wait band a daylight picks (the scheduler's own default wait, sampled).
	local function cooBand(daylight)
		local s=Coos.new({group={Volume=1}},{})
		local low,high=math.huge,-math.huge
		for _=1,40 do local w=s.wait(daylight);low=math.min(low,w);high=math.max(high,w)end
		return if low>=Coos.NightWait[1]then "night"elseif high<=Coos.DayWait[2]then "day"else "mixed"
	end
	local function sleepy(daylight)return Expression.garden("neutral",true,10,daylight,false)end
	-- Runs fn with the hour switched on (true) or off (false), restoring every attribute after.
	local function withHour(on,fn)
		local names={Hour.Attribute,Aero.Attribute,Hour.OffsetAttribute}
		local saved={}
		for _,name in ipairs(names)do saved[name]=workspace:GetAttribute(name)end
		local savedLast=Clock.lastDaylight
		local ok,problem=pcall(function()
			workspace:SetAttribute(Aero.Attribute,on)
			workspace:SetAttribute(Hour.Attribute,on)
			Hour.setSwitch(on) -- server realm only (offline mocks, or a server-side copy); a client ignores it
			fn()
		end)
		Hour.setSwitch(false)
		Clock.lastDaylight=savedLast
		for _,name in ipairs(names)do workspace:SetAttribute(name,saved[name])end
		assert(ok,problem)
	end

	test("the awake floor sits on all three night tests (each reads night below .3)",function()
		assert(Face.AwakeFloor==.3)
		assert(Face.AwakeFloor>=Expression.Night and Face.AwakeFloor>=Beats.Night and Face.AwakeFloor>=Coos.Night)
	end)
	test("Face.mood: on lifts anything under .3 to .3; day values, off and non-numbers pass through",function()
		for _,d in ipairs({0,.12,.29})do
			assert(Face.mood(d,true)==.3,"on "..d)
			assert(Face.mood(d,false)==d and Face.mood(d,nil)==d,"off "..d)
		end
		for _,d in ipairs({.3,.55,.9,1})do assert(Face.mood(d,true)==d and Face.mood(d,false)==d,"day "..d)end
		assert(Face.mood(nil,true)==nil and Face.mood("x",true)=="x")
	end)
	test("hour on, at the hour's night (daylight .12): awake face, day idle weights, day coo wait",function()
		if not Hour.ceiling()then table.insert(cases,"SKIPPED on case: GardenHour ceiling is off in this build");return end
		withHour(true,function()
			if not Hour.on()then return end -- a client copy: the server switch is not readable here
			workspace:SetAttribute(Hour.OffsetAttribute,3100-workspace:GetServerTimeNow()%Hour.Period) -- deep in the hour's night hold
			assert(Hour.isNight(Hour.time())and Hour.phase(Hour.time()).daylight==.12)
			Clock.lastDaylight=.12
			assert(Face.daylight()==.12,"glow still reads the light")
			local mood=Face.moodDaylight()
			assert(mood==.3,"mood "..tostring(mood))
			assert(sleepy(mood)=="content","rest face "..sleepy(mood))
			assert(Beats.weights(mood)==Beats.DayWeights)
			assert(Face.moodDaylight(.12)==.3 and cooBand(Face.moodDaylight(.12))=="day")
			-- Daylight above the floor passes through (dawn, golden, day).
			Clock.lastDaylight=.55;assert(Face.moodDaylight()==.55)
		end)
	end)
	test("hour off: today's behaviour (sleepy at night, night weights, night coo wait)",function()
		withHour(false,function()
			assert(not Hour.on())
			Clock.lastDaylight=.12
			local mood=Face.moodDaylight()
			assert(mood==.12 and mood==Face.daylight())
			assert(sleepy(mood)=="sleepy")
			assert(Beats.weights(mood)==Beats.NightWeights)
			assert(cooBand(Face.moodDaylight(.12))=="night")
			Clock.lastDaylight=.9;assert(Face.moodDaylight()==.9 and sleepy(.9)=="content"and Beats.weights(.9)==Beats.DayWeights)
			Clock.lastDaylight=nil;assert(Face.moodDaylight()==1)
		end)
	end)
	test("the switch alone is not enough: Aero off or a missing Hour_on keeps today's night",function()
		withHour(true,function()
			Clock.lastDaylight=.12
			workspace:SetAttribute(Aero.Attribute,false);assert(Face.moodDaylight()==.12,"Aero off")
			workspace:SetAttribute(Aero.Attribute,true);workspace:SetAttribute(Hour.Attribute,nil)
			assert(Face.moodDaylight()==.12,"missing Hour_on")
		end)
	end)
	test("night glow: the ramp stops at .6 while the hour is on (HollowClock.hourOn); off, the ramp as it was",function()
		local Materials=require(client.PetMaterials)
		assert(Materials.HourGlowCap==.6)
		local function before(d)local t=math.clamp((.75-d)/.75,0,1);return t*t*(3-2*t)end
		for _,d in ipairs({0,.12,.3,.5,.55,.75,.9,1})do
			assert(Materials.nightGlow(d)==before(d)and Materials.nightGlow(d,false)==before(d),"off "..d)
			assert(Materials.nightGlow(d,true)==math.min(before(d),.6),"on "..d)
		end
		assert(math.abs(Materials.nightGlow(.12)-.93)<.005 and Materials.nightGlow(.12,true)==.6,"the hour's night")
		assert(Materials.nightGlow(.55,true)==before(.55)and Materials.nightGlow(.5,true)==before(.5),"golden and dawn under the cap")
		local real=Clock.hourOn
		local ok,problem=pcall(function()
			Clock.hourOn=function()return true end;assert(Materials.hourOn()==true,"on")
			Clock.hourOn=function()return false end;assert(Materials.hourOn()==false,"off")
		end)
		Clock.hourOn=real
		assert(ok,problem)
	end)
	return{passed=#cases,cases=cases}
end
