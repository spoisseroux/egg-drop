-- The garden hour (GARDEN-HOUR-BUILD-PLAN-2026-11-23, slice A): the pure clock and look (GardenHour), the value tables
-- (WorldNight, WorldDawn) and the switch (GardenHourConfig) on a fake ConfigService and scheduler.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.GardenHour)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Hour=require(Shared.GardenHour)
	local Aero=require(Shared.Aero)
	local Day=require(Shared.WorldAero)
	local Dusk=require(Shared.WorldDusk)
	local Night=require(Shared.WorldNight)
	local Dawn=require(Shared.WorldDawn)
	local Config=require(server.GardenHourConfig)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-9)end
	local function same(a,b)return a.R==b.R and a.G==b.G and a.B==b.B end
	local function hex(text)return Color3.fromHex(text)end
	local Step=.25
	-- A sample every Step seconds over one hour (and one past the wrap), from an hour that is not at 0.
	local Base=3600*400000
	local function each(fn)
		for i=0,(3600/Step)do fn(i*Step,Hour.look(Base+i*Step),Hour.phase(Base+i*Step))end
	end
	local Windows={{0,90,"night","dawn"},{360,450,"dawn","day"},{2400,2490,"day","golden"},{2880,3000,"golden","night"}}

	test("phase boundaries: dawn 0-360, day 360-2400, golden 2400-2880, night 2880-3600; any time folds into the hour",function()
		for _,case in ipairs({{0,"dawn"},{359.9,"dawn"},{360,"day"},{2399.9,"day"},{2400,"golden"},{2879.9,"golden"},
			{2880,"night"},{3599.9,"night"},{3600,"dawn"},{-1,"night"},{Base+2400,"golden"},{-3600*5+361,"day"}})do
			local got=Hour.phase(case[1])
			assert(got.phase==case[2],case[1].." "..got.phase)
			assert(got.f>=0 and got.f<1 and near(got.f,got.s/3600),"f")
		end
		assert(near(Hour.phase(1800).f,.5))
	end)
	test("blend windows: the first 90 s of dawn, day and golden and the first 120 s of night; holds everywhere else",function()
		for _,w in ipairs(Windows)do
			assert(Hour.Blending(w[1])and Hour.Blending(w[2]-.01),"in "..w[1])
			assert(not Hour.Blending(w[2])and not Hour.Blending(w[1]-.01+(if w[1]==0 then 3600 else 0)),"out "..w[1])
			local p=Hour.phase(w[1]+(w[2]-w[1])/2)
			assert(p.from==w[3]and p.phase==w[4]and near(p.blend,.5)and near(p.k,.5),"middle "..w[1])
			assert(Hour.phase(w[1]).blend==0 and Hour.phase(w[1]).k==0)
		end
		for _,s in ipairs({100,359,1000,2399,2600,3100,3599})do
			local p=Hour.phase(s)
			assert(not Hour.Blending(s)and p.from==nil and p.blend==nil and p.k==1,"hold "..s)
		end
	end)
	test("daylight is one continuous number in the look's ranges: exact in holds, monotonic within each blend",function()
		local expect={dawn=.5,day=.9,golden=.55,night=.12}
		assert(Hour.Holds.day.Daylight==Day.Daylight and Hour.Holds.golden.Daylight==Dusk.Daylight)
		assert(Hour.Holds.night.Daylight==Night.Daylight and Hour.Holds.dawn.Daylight==Dawn.Daylight)
		local last,lastBlend
		each(function(s,look,p)
			assert(p.daylight>=.12 and p.daylight<=.9,"range "..s)
			assert(look.Daylight==p.daylight,"look daylight "..s)
			if not p.blend then assert(p.daylight==expect[p.phase],"hold "..s)
			else
				local a,b=expect[p.from],expect[p.phase]
				assert(p.daylight>=math.min(a,b)and p.daylight<=math.max(a,b),"between "..s)
				if lastBlend and lastBlend.phase==p.phase and lastBlend.blend then
					assert((b-a)*(p.daylight-lastBlend.daylight)>=0,"monotonic "..s)
				end
			end
			if last then assert(math.abs(p.daylight-last)<.01,"jump at "..s)end
			last,lastBlend=p.daylight,p
		end)
	end)
	test("holds return the phase's own frozen tables (never a lerp); day is WorldAero, golden WorldDusk but diffuse .25",function()
		local function check(look,values,name)
			for _,section in ipairs({"Lighting","Atmosphere","Grade","Bloom","SunRays","Sky"})do
				for key,value in pairs(values[section])do
					if not(name=="golden"and key=="EnvironmentDiffuseScale")then
						assert(look[section][key]==value,name.." "..section.."."..key)
					end
				end
			end
			assert(look.Hour==values.Hour and look.Daylight==values.Daylight and look.CloudColor==values.CloudColor,name)
			assert(look.Cover==0 and look.From==nil and look.Blend==nil and table.isfrozen(look),name)
		end
		for _,case in ipairs({{200,"dawn",Dawn},{1000,"day",Day},{2700,"golden",Dusk},{3300,"night",Night}})do
			local look=Hour.look(Base+case[1])
			assert(look==Hour.look(Base+case[1]+30)and look==Hour.Holds[case[2]]and look.Phase==case[2],"same table "..case[2])
			check(look,case[3],case[2])
		end
		assert(Hour.Holds.day.Lighting==Day.Lighting and Hour.Holds.day.Clouds==Day.Clouds)
		assert(Hour.Holds.day.GlowWarm==Day.Surfaces.glow_warm.Color and Hour.Holds.day.PeakColor==nil)
		assert(Hour.Holds.golden.Lighting.EnvironmentDiffuseScale==.25 and Dusk.Lighting.EnvironmentDiffuseScale==.35)
		assert(Hour.Holds.golden.FaceSet=="dusk"and Hour.Holds.night.FaceSet=="night"and Hour.Holds.dawn.FaceSet=="day")
		assert(same(Hour.Holds.golden.Clouds.Color,hex("#FFD9E4"))and same(Hour.Holds.golden.GlowWarm,hex("#FFC96A")))
		assert(same(Night.PeakColor,hex("#56629A"))and Dawn.PeakColor==nil and Hour.Holds.golden.PeakColor==nil)
		assert(Night.Sky.StarCount==1200 and Night.Sky.MoonAngularSize==9 and Dawn.Sky.SunAngularSize==14)
	end)
	test("blends: k = 0 is the phase before, the blend lerps every number and colour, stepped values change once",function()
		for _,w in ipairs(Windows)do
			local a,b=Hour.Holds[w[3]],Hour.Holds[w[4]]
			local first=Hour.look(w[1])
			for _,key in ipairs({"Brightness","ExposureCompensation","ShadowSoftness","EnvironmentSpecularScale"})do
				assert(near(first.Lighting[key],a.Lighting[key],1e-6),w[4].." first "..key)
			end
			assert(same(first.Lighting.Ambient,a.Lighting.Ambient)and same(first.GlowWarm,a.GlowWarm),w[4].." first colours")
			local last=Hour.look(w[2]-1e-6)
			assert(near(last.Bloom.Intensity,b.Bloom.Intensity,1e-6)and near(last.Grade.Saturation,b.Grade.Saturation,1e-6),w[4].." last")
			assert(near(last.Lighting.Ambient.B,b.Lighting.Ambient.B,1e-6)and near(last.Clouds.Color.R,b.Clouds.Color.R,1e-6))
			local mid=Hour.look(w[1]+(w[2]-w[1])/2)
			assert(near(mid.Grade.Contrast,(a.Grade.Contrast+b.Grade.Contrast)/2,1e-9),w[4].." middle")
			assert(near(mid.CloudColor.G,(a.CloudColor.G+b.CloudColor.G)/2,1e-9),w[4].." middle cloud")
			local steps,faces=0,first.FaceSet
			for s=w[1],w[2]-Step,Step do
				local look=Hour.look(s)
				assert(look.Sky==a.Sky or look.Sky==b.Sky,"sky is one side")
				if look.FaceSet~=faces then steps+=1;faces=look.FaceSet end
				local side=if look.Sky==b.Sky then b else a
				assert(look.PeakColor==side.PeakColor and look.FaceSet==side.FaceSet,"stepped together "..s)
			end
			assert(steps==(if a.FaceSet==b.FaceSet then 0 else 1),w[4].." face steps "..steps)
		end
	end)
	test("ClockTime only moves forward and lands on 18.0 and 6.0 at the sky swap, under the haze peak",function()
		local last
		each(function(s,look,p)
			assert(look.Lighting.ClockTime==look.Hour,"Hour "..s)
			if last then
				local step=(look.Hour-last+24)%24
				assert(step>=0 and step<.2,"forward at "..s.." by "..step)
			end
			last=look.Hour
		end)
		for _,case in ipairs({{2880,3000,18,"golden","night"},{0,90,6,"night","dawn"}})do
			local cross,swap
			local prev=Hour.look(case[1])
			for s=case[1]+Step,case[2]-Step,Step do
				local look=Hour.look(s)
				local before,after=(prev.Hour-case[3]+12)%24-12,(look.Hour-case[3]+12)%24-12
				if before<0 and after>=0 and not cross then cross=s end
				if look.FaceSet~=prev.FaceSet then assert(not swap,"one swap");swap=s end
				prev=look
			end
			assert(cross and swap and cross==swap,case[5].." crossing "..tostring(cross).." swap "..tostring(swap))
			local k=Hour.stepAt(case[5],case[4])
			local at=Hour.look(case[1]+(case[2]-case[1])*0)
			assert(at.Cover==0)
			-- Exactly at the step: ClockTime is the handoff, the haze cover is at its peak, daylight is the threshold.
			local lo,hi=case[1],case[2]
			for _=1,60 do
				local m=(lo+hi)/2
				if Hour.phase(m).k<k then lo=m else hi=m end
			end
			local look=Hour.look(hi)
			assert(near(look.Hour,case[3],1e-4),case[5].." handoff "..look.Hour)
			assert(look.Cover>.9999 and near(look.Daylight,Hour.SkyThreshold,1e-6),case[5].." cover")
			assert(look.FaceSet==Hour.Holds[case[5]].FaceSet or case[5]=="dawn"and look.FaceSet=="day")
		end
		assert(near(Hour.stepAt("night","golden"),.2/.43)and near(Hour.stepAt("dawn","night"),.23/.38)and Hour.stepAt("day","dawn")==.5)
	end)
	test("the haze cover and key-light pinch stay inside the white Bear rule at every quarter second",function()
		local floorAmbient,floorOutdoor=hex("#566090"),hex("#6E86C8")
		local function luma(c)return .2126*c.R+.7152*c.G+.0722*c.B end
		local pinched=false
		each(function(s,look,p)
			local L=look.Lighting
			assert(L.Brightness>=1.1-1e-9,"Brightness "..s)
			-- The floors are on brightness (golden's warm OutdoorAmbient is under #6E86C8 in blue alone).
			assert(luma(L.Ambient)>=luma(floorAmbient)-1e-9,"Ambient "..s)
			assert(luma(L.OutdoorAmbient)>=luma(floorOutdoor)-1e-9,"Outdoor "..s)
			assert(L.ExposureCompensation>=0 and L.ExposureCompensation<=.15,"Exposure "..s)
			-- Golden's .25 is Fable's [check] cell (look section 2), above the section 3 ceiling of .2.
			assert(L.EnvironmentDiffuseScale<=.25+1e-9,"Diffuse "..s)
			assert(look.Bloom.Intensity<=.18+1e-9,"Bloom "..s)
			assert(look.Atmosphere.Density<=Hour.Cover.MaxDensity+1e-9,"Density "..s)
			if look.Cover==0 then assert(look.Atmosphere.Density<=.3+1e-9,"Density without cover "..s)end
			if p.phase=="day"or p.phase=="golden"then assert(look.Cover==0,"cover only in the night blends "..s)end
			if p.blend and look.Cover>0 then
				local a,b=Hour.Holds[p.from].Lighting.Brightness,Hour.Holds[p.phase].Lighting.Brightness
				if L.Brightness<math.min(a,b)-1e-9 then pinched=true end
			end
		end)
		assert(pinched,"the pinch dims the key light somewhere in a night blend")
		for _,s in ipairs({2880+60,45})do
			local look,p=Hour.look(s),Hour.phase(s)
			local a,b=Hour.Holds[p.from].Atmosphere,Hour.Holds[p.phase].Atmosphere
			local plain=a.Haze+(b.Haze-a.Haze)*p.k
			assert(look.Cover>.9 and near(look.Atmosphere.Haze,plain+Hour.Cover.Haze*look.Cover,1e-9),"haze added "..s)
			assert(look.Atmosphere.Density>a.Density+(b.Density-a.Density)*p.k,"density added "..s)
		end
	end)
	test("Reduced Motion: ClockTime takes only the two ends of each blend and steps once, at the sky step",function()
		for _,w in ipairs(Windows)do
			local a,b=Hour.Holds[w[3]].Hour,Hour.Holds[w[4]].Hour
			local seen,steps,last={},0,nil
			for s=w[1],w[2]-Step,Step do
				local look=Hour.look(s,true)
				assert(look.Hour==a or look.Hour==b,"ends only "..s)
				if last and look.Hour~=last then
					steps+=1
					local at=Hour.stepAt(w[4],w[3])
					assert(Hour.phase(s).k>=at and Hour.phase(s-Step).k<at,"steps at the sky step "..s)
				end
				last=look.Hour;seen[look.Hour]=true
				assert(look.Lighting.Brightness==Hour.look(s).Lighting.Brightness or look.Cover>0,"brightness still blends "..s)
			end
			assert(steps==1 and seen[a]and seen[b],w[4].." steps "..steps)
		end
		assert(Hour.look(1000,true)==Hour.Holds.day)
	end)
	test("isNight is the phase (s >= 2880), not daylight",function()
		for _,case in ipairs({{2879.9,false},{2880,true},{2900,true},{3599.9,true},{0,false},{45,false},{1000,false},
			{Base+2880,true},{-100,true}})do
			assert(Hour.isNight(case[1])==case[2],tostring(case[1]))
		end
	end)
	test("ceiling and switch: flag and beta or Studio; missing or malformed is off; needs the Aero look on",function()
		local Flags={GardenHour=true}
		assert(Hour.ceiling({flags=Flags,studio=false,place=Hour.PlaceId})and Hour.ceiling({flags=Flags,studio=true,place=1}))
		assert(not Hour.ceiling({flags=Flags,studio=false,place=96451847774961}))
		assert(not Hour.ceiling({flags={GardenHour=false},studio=true})and not Hour.ceiling({flags={},studio=true}))
		assert(Hour.resolve(nil,nil,true)==false and Hour.resolve("true",nil,true)==false and Hour.resolve(1,nil,true)==false)
		assert(Hour.resolve(true,nil,true)==true and Hour.resolve(false,true,true)==true and Hour.resolve(true,false,true)==false)
		assert(Hour.resolve(true,true,false)==false)
		local saved={}
		for _,name in ipairs({Hour.Attribute,Aero.Attribute})do saved[name]=workspace:GetAttribute(name)end
		local ok,problem=pcall(function()
			if not Hour.ceiling()then return end -- a build with the flag off: on() must be off, checked below
			workspace:SetAttribute(Aero.Attribute,true);Hour.setSwitch(true)
			workspace:SetAttribute(Hour.Attribute,nil);assert(not Hour.on(),"missing attribute")
			workspace:SetAttribute(Hour.Attribute,"true");assert(not Hour.on(),"malformed attribute")
			workspace:SetAttribute(Hour.Attribute,true);assert(Hour.on()==Aero.on(),"on with Aero")
			if Aero.on()then
				workspace:SetAttribute(Aero.Attribute,false);assert(not Hour.on(),"Aero off")
				workspace:SetAttribute(Aero.Attribute,true);Hour.setSwitch(false);assert(not Hour.on(),"server switch off")
			end
		end)
		Hour.setSwitch(false)
		for name,value in pairs(saved)do workspace:SetAttribute(name,value)end
		assert(ok,problem)
		if not Hour.ceiling()then assert(not Hour.on())end
	end)
	test("offset: Hour_offset (Studio and beta only) moves the clock; anything not a finite number is 0",function()
		local saved=workspace:GetAttribute(Hour.OffsetAttribute)
		local ok,problem=pcall(function()
			for _,case in ipairs({{1000,1000},{-30.5,-30.5},{"5",0},{0/0,0},{math.huge,0},{nil,0}})do
				workspace:SetAttribute(Hour.OffsetAttribute,case[1])
				assert(Hour.offset({studio=true})==case[2],tostring(case[1]))
				assert(Hour.offset({studio=false,place=96451847774961})==0,"live ignores it")
			end
			workspace:SetAttribute(Hour.OffsetAttribute,1000)
			if Hour.testing()then assert(near(Hour.time()-workspace:GetServerTimeNow(),1000,.5),"time")end
		end)
		workspace:SetAttribute(Hour.OffsetAttribute,saved)
		assert(ok,problem)
	end)

	-- GardenHourConfig ------------------------------------------------------------------------------------------------
	local function rig(service,ceiling,set,testing)
		local r={log={},attr={},parked={},at=0,clock=123456.75}
		r.config=Config.new({service=service,now=function()return r.at end,ceiling=ceiling or function()return true end,
			hold=function(value)r.held=value;table.insert(r.log,"hold "..tostring(value))end,
			set=set or function(name,value)r.attr[name]=value;table.insert(r.log,"set "..name.." "..tostring(value))end,
			testing=testing or function()return true end,clock=function()return r.clock end,
			offset=function(value)r.offset=value;table.insert(r.log,"offset "..tostring(value))end,
			wait=function(seconds)table.insert(r.parked,{due=r.at+seconds,co=coroutine.running()});coroutine.yield()end,
			spawn=function(fn)local good,e=coroutine.resume(coroutine.create(fn));assert(good,e)end,warn=function()end})
		function r.advance(to)
			while true do
				local best
				for i,p in ipairs(r.parked)do if p.due<=to and(not best or p.due<r.parked[best].due)then best=i end end
				if not best then break end
				local p=table.remove(r.parked,best);r.at=math.max(r.at,p.due)
				local good,e=coroutine.resume(p.co);assert(good,e)
			end
			r.at=to
		end
		function r.is(value)return r.held==value and r.attr.Hour_on==value end
		return r
	end
	local function snapshot(values)
		local s={values=values,listeners={},asked={}}
		function s:GetValue(key)table.insert(s.asked,key);return s.values[key]end
		function s:Refresh()if s.fail then error("down")end end
		s.UpdateAvailable={Connect=function(_,fn)table.insert(s.listeners,fn)end}
		function s.update()for _,fn in ipairs(s.listeners)do fn()end end
		return s
	end
	local function of(s)return function()return{GetConfigAsync=function()return s end}end end
	test("config: off is written before anything yields, the server's value first",function()
		local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end)
		r.config.start()
		assert(r.is(false)and table.concat(r.log,",")=="hold false,set Hour_on false",table.concat(r.log,","))
	end)
	test("config: once loaded only true is on (missing or malformed is off); no other key is read",function()
		for _,case in ipairs({{nil,false},{false,false},{true,true},{"true",false},{1,false}})do
			local s=snapshot({garden_hour=case[1],garden_finds=true,aero_world=true})
			local r=rig(of(s));r.config.start();assert(r.is(case[2]),tostring(case[1]))
			for _,key in ipairs(s.asked)do assert(key=="garden_hour",key)end
		end
	end)
	test("config: a late load applies, an update flips it, a failed refresh keeps the last value",function()
		local calls,s=0,snapshot({garden_hour=true})
		local r=rig(function()return{GetConfigAsync=function()calls+=1;if calls<3 then error("down")end;return s end}end)
		r.config.start();r.advance(5);assert(r.is(false)and calls==2);r.advance(20);assert(r.is(true))
		r.advance(100);s.values={garden_hour=false};s.update();r.advance(110);assert(r.is(false))
		r.advance(200);s.values={garden_hour=true};s.fail=true;s.update();r.advance(210);assert(r.is(false))
		s.fail=false;r.advance(1000);assert(r.is(true))
	end)
	test("config: the ceiling is false: nothing is written, ConfigService is never asked, chat does nothing",function()
		local asked=false
		local r=rig(function()asked=true;error("asked")end,function()return false end)
		r.config.start();assert(not r.config.command("/hour on")and not r.config.command("/hour at 10"))
		r.advance(1000);assert(#r.log==0 and not asked)
	end)
	test("config: /hour on|off|clear beats the config; nonsense is ignored",function()
		local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end);r.config.start()
		assert(r.config.command(" /HOUR On ")and r.is(true)and r.config.command("/hour clear")and r.is(false),"not loaded yet")
		r=rig(of(snapshot({garden_hour=true})));r.config.start();assert(r.is(true))
		assert(r.config.command("/hour off")and r.is(false)and r.config.command("/hour on")and r.is(true)and r.config.command("/hour clear")and r.is(true))
		for _,odd in ipairs({"/hour","/hour maybe","hour on","/hours on","/hour on now","/finds on","/aero on","/hour at",
			"/hour at 3600","/hour at -1","/hour at 12.5","/hour at 1e3","/hour at 10 now"})do assert(not r.config.command(odd),odd)end
		for _,odd in ipairs({5,{},true})do assert(not r.config.command(odd))end
		assert(not r.config.command(nil)and r.offset==nil)
	end)
	test("config: /hour at N sets Hour_offset so the hour reads N now (Studio and beta only)",function()
		local r=rig(of(snapshot({})))
		r.config.start()
		for _,at in ipairs({0,360,2400,2880,3599,1800})do
			assert(r.config.command("/hour at "..at),at)
			assert(r.offset>=0 and r.offset<3600,"range")
			assert(near((r.clock+r.offset)%3600,at,1e-6),"lands "..at)
			assert(Hour.phase(r.clock+r.offset).s==(r.clock+r.offset)%3600)
		end
		assert(Config.parse("/hour at 0007").at==7 and Config.parse("/Hour AT 2880").at==2880)
		local live=rig(of(snapshot({})),nil,nil,function()return false end)
		live.config.start();assert(not live.config.command("/hour at 10")and live.offset==nil)
		assert(Config.offsetFor(100,3600*7+50)==50 and Config.offsetFor(0,3599)==1)
	end)
	return{passed=#cases,cases=cases}
end
