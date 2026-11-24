-- Onboarding v3 switches (ONBOARDING-V3-PLAN-2026-11-23): the build ceiling (flag, beta or Studio, Things to do on),
-- resolve, the three parts, the session capture of the follow switch, OnboardConfig on a fake ConfigService and
-- scheduler (the Things AND, the republish on a Things flip, /onboard), and the coach ids gated per owner module.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.Onboard)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Onboard=require(Shared.Onboard)
	local Things=require(Shared.Things)
	local Coach=require(Shared.CoachMarks)
	local Config=require(server.OnboardConfig)
	local cases={}
	local function test(name,run)
		local ok,problem=pcall(run)
		Onboard.inject(nil);Things.inject(nil)
		assert(ok,name..": "..tostring(problem))
		table.insert(cases,name)
	end
	local on={OnboardingV3=true}

	test("the ceiling: the flag, and the beta place or Studio; never the live place",function()
		assert(Onboard.PlaceId==107705084891479)
		assert(Onboard.ceiling({flags=on,place=Onboard.PlaceId,studio=false})and Onboard.ceiling({flags=on,place=1,studio=true}))
		assert(not Onboard.ceiling({flags=on,place=96451847774961,studio=false}),"never on the live place")
		assert(not Onboard.ceiling({flags={},place=Onboard.PlaceId,studio=true}),"missing flag = off")
		assert(not Onboard.ceiling({flags={OnboardingV3="yes"},place=Onboard.PlaceId,studio=true}),"only true opens it")
		assert(not Onboard.ceiling({flags={ThingsToDo=true},place=Onboard.PlaceId,studio=true}),"Things' flag is not this flag")
	end)
	test("open also needs Things to do on: Things off is every part off",function()
		assert(Onboard.open({flags=on,studio=true})and not Onboard.open({flags=on,studio=true,things=false}))
		assert(not Onboard.open({flags={},studio=true}))
		Onboard.inject({flags=on,studio=true,things=false})
		for _,feature in ipairs(Onboard.Features)do assert(not Onboard.on(feature),feature)end
		Onboard.inject({flags={},studio=true})
		for _,feature in ipairs(Onboard.Features)do assert(not Onboard.on(feature),feature)end
	end)
	test("resolve: off without the ceiling; an override beats the config; anything not boolean is on",function()
		assert(not Onboard.resolve(true,true,false))
		assert(Onboard.resolve(nil,nil,true)and Onboard.resolve("x",nil,true)and Onboard.resolve(0,{},true))
		assert(not Onboard.resolve(false,nil,true)and Onboard.resolve(true,nil,true))
		assert(not Onboard.resolve(true,false,true)and Onboard.resolve(false,true,true))
	end)
	test("three parts with their keys and attributes; each switches alone; unknown parts are off",function()
		assert(table.concat(Onboard.Features,",")=="follow,needs,nest,corner,landmark")
		for _,feature in ipairs(Onboard.Features)do
			assert(Onboard.key(feature)=="onboard_"..feature and Onboard.attribute(feature)=="Onboard_"..feature,feature)
		end
		Onboard.inject({flags=on,studio=true})
		assert(Onboard.on("follow")and Onboard.on("needs")and Onboard.on("nest"))
		assert(not Onboard.on("tour")and not Onboard.on(nil)and not Onboard.on(5)and not Onboard.allows("page"))
		Onboard.inject({flags=on,studio=true,needs=false})
		assert(Onboard.on("follow")and not Onboard.on("needs")and Onboard.on("nest"))
		assert(Onboard.allows("follow")and not Onboard.allows("needs"))
		assert(not Onboard.setSwitch("tour",true),"no such switch")
	end)
	test("the real path: the held value, the attribute and Things all have to say on",function()
		local saved={}
		for _,name in ipairs({"Things_page","Onboard_follow","Onboard_nest"})do saved[name]=workspace:GetAttribute(name)end
		local ok,problem=pcall(function()
			Things.setSwitch("page",true);workspace:SetAttribute("Things_page",true)
			Onboard.setSwitch("follow",true);workspace:SetAttribute("Onboard_follow",true)
			assert(Onboard.open()and Onboard.on("follow"),"all three on")
			Onboard.setSwitch("follow",false);assert(not Onboard.on("follow"),"the server's held value off")
			Onboard.setSwitch("follow",true);workspace:SetAttribute("Onboard_follow",false);assert(not Onboard.on("follow"),"the attribute off")
			workspace:SetAttribute("Onboard_follow",true);Things.setSwitch("page",false);assert(not Onboard.on("follow"),"Things off")
			Things.setSwitch("page",true);assert(not Onboard.on("nest"),"a part never set is off")
		end)
		Things.setSwitch("page",false);Onboard.setSwitch("follow",false)
		for name,value in pairs(saved)do workspace:SetAttribute(name,value)end
		assert(ok,problem)
	end)
	test("sessionFollow: read once at the first call; a mid-session flip never changes it; per player on the server",function()
		local saved={page=workspace:GetAttribute("Things_page"),follow=workspace:GetAttribute("Onboard_follow")}
		local ok,problem=pcall(function()
			Onboard.inject(nil)
			Onboard.forget();Onboard.forget(1);Onboard.forget(2)
			Things.setSwitch("page",true);workspace:SetAttribute("Things_page",true)
			Onboard.setSwitch("follow",true);workspace:SetAttribute("Onboard_follow",true)
			assert(Onboard.sessionFollow()==true and Onboard.sessionFollow(1)==true)
			workspace:SetAttribute("Onboard_follow",false)
			assert(not Onboard.on("follow"),"the switch is off now")
			assert(Onboard.sessionFollow()==true and Onboard.sessionFollow(1)==true,"the captured answer holds: the new tour keeps going")
			assert(Onboard.sessionFollow(2)==false,"a player who joins after the flip gets the old tour")
			workspace:SetAttribute("Onboard_follow",true)
			assert(Onboard.sessionFollow(2)==false,"and keeps it for the session")
			Onboard.forget(2);assert(Onboard.sessionFollow(2)==true,"forget on leave: the next session reads again")
			-- inject clears the captures (spec seam), then answers from env.
			Onboard.inject({flags=on,studio=true,follow=false});assert(Onboard.sessionFollow()==false)
			Onboard.inject({flags=on,studio=true});assert(Onboard.sessionFollow()==true)
		end)
		Onboard.inject(nil);Onboard.forget();Onboard.forget(1);Onboard.forget(2)
		Things.setSwitch("page",false);Onboard.setSwitch("follow",false)
		workspace:SetAttribute("Things_page",saved.page);workspace:SetAttribute("Onboard_follow",saved.follow)
		assert(ok,problem)
	end)

	-- OnboardConfig on AliveConfig's publisher (the ThingsConfig rig).
	local function rig(service,opts)
		opts=opts or {}
		local r={log={},held={},attr={},parked={},at=0,things=opts.things~=false,watchers={}}
		r.config=Config.new({service=service,now=function()return r.at end,ceiling=opts.ceiling or function()return true end,
			hold=function(feature,value)r.held[feature]=value;table.insert(r.log,"hold "..feature.." "..tostring(value))end,
			set=opts.set or function(name,value)r.attr[name]=value;table.insert(r.log,"set "..name.." "..tostring(value))end,
			things=function()return r.things end,watch=function(fn)table.insert(r.watchers,fn)end,
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
		function r.flip(value)r.things=value;for _,fn in ipairs(r.watchers)do fn()end end
		function r.is(follow,needs,nest)
			return r.held.follow==follow and r.held.needs==needs and r.held.nest==nest
				and r.attr.Onboard_follow==follow and r.attr.Onboard_needs==needs and r.attr.Onboard_nest==nest
		end
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
		assert(r.is(false,false,false))
		assert(table.concat(r.log,",")=="hold follow false,set Onboard_follow false,hold needs false,set Onboard_needs false,hold nest false,set Onboard_nest false,hold corner false,set Onboard_corner false,hold landmark false,set Onboard_landmark false")
	end)
	test("config: once loaded a missing or malformed key is on, each key its own part, no other key is read",function()
		for _,case in ipairs({{nil,nil,nil,true,true,true},{false,nil,"x",false,true,true},{true,false,0,true,false,true},{false,false,false,false,false,false}})do
			local s=snapshot({onboard_follow=case[1],onboard_needs=case[2],onboard_nest=case[3],things_to_do=false})
			local r=rig(of(s));r.config.start();assert(r.is(case[4],case[5],case[6]))
			for _,key in ipairs(s.asked)do assert(key=="onboard_follow"or key=="onboard_needs"or key=="onboard_nest"or key=="onboard_corner"or key=="onboard_landmark",key)end
		end
	end)
	test("config: Things off publishes every part off; a Things flip republishes at once",function()
		local r=rig(of(snapshot({})),{things=false});r.config.start()
		assert(r.is(false,false,false)and #r.watchers==1,"watching Things")
		r.flip(true);assert(r.is(true,true,true))
		r.flip(false);assert(r.is(false,false,false))
		assert(r.config.command("/onboard all on")and r.is(false,false,false),"an override never beats Things off")
	end)
	test("config: never loaded is off; a late load applies; an update flips it; a failed refresh keeps the last value",function()
		local calls,s=0,snapshot({})
		local r=rig(function()return{GetConfigAsync=function()calls+=1;if calls<3 then error("down")end;return s end}end)
		r.config.start();r.advance(5);assert(r.is(false,false,false)and calls==2);r.advance(20);assert(r.is(true,true,true))
		r.advance(100);s.values={onboard_nest=false};s.update();assert(r.is(true,true,false))
		r.advance(200);s.values={};s.fail=true;s.update();assert(r.is(true,true,false));s.fail=false;r.advance(1000);assert(r.is(true,true,true))
	end)
	test("config: an attribute that cannot be written still turns the server off",function()
		local r=rig(of(snapshot({onboard_needs=false})),{set=function()error("locked")end})
		r.config.start();assert(r.held.follow==true and r.held.needs==false and r.held.nest==true)
	end)
	test("config: the ceiling is false: nothing is written, ConfigService is never asked, no watch, chat does nothing",function()
		local asked=false
		local r=rig(function()asked=true;error("asked")end,{ceiling=function()return false end})
		r.config.start();assert(not r.config.command("/onboard all on"));r.advance(1000)
		assert(#r.log==0 and not asked and #r.watchers==0)
	end)
	test("config: /onboard <part|all> <on|off|clear> beats the config; nonsense is ignored",function()
		local r=rig(of(snapshot({onboard_follow=false})));r.config.start();assert(r.is(false,true,true))
		assert(r.config.command(" /ONBOARD Follow On ")and r.is(true,true,true))
		assert(r.config.command("/onboard nest off")and r.is(true,true,false))
		-- The egg corner is a part too: /onboard corner off (EGG-CORNER-BUILD-PLAN 3).
		assert(r.config.command("/onboard corner off")and r.held.corner==false and r.attr.Onboard_corner==false)
		assert(r.config.command("/onboard corner on")and r.held.corner==true and r.attr.Onboard_corner==true)
		assert(r.config.command("/onboard all off")and r.is(false,false,false))
		assert(r.config.command("/onboard all clear")and r.is(false,true,true),"clear: back to the config")
		for _,odd in ipairs({"/onboard","/onboard on","/onboard follow","/onboard tour on","/onboard follow maybe","onboard follow on","/todo on","/onboard follow on now"})do
			assert(not r.config.command(odd),odd)
		end
		for _,odd in ipairs({5,{},true})do assert(not r.config.command(odd))end
		assert(not r.config.command(nil))
		local parsed=Config.parse("/onboard all on");assert(#parsed.features==5 and parsed.value==true)
		assert(Config.parse("/onboard needs clear").value==nil and Config.parse("/onboard needs clear").features[1]=="needs")
	end)

	test("coach ids: each gated id asks its own owner module; ungated ids are always allowed",function()
		for id,part in pairs(Coach.Gated)do
			local owner=Coach.GateOwner[part]
			assert(owner=="Things"or owner=="Onboard",id)
			if owner=="Onboard"then assert(table.find(Onboard.Features,part),id)else assert(table.find(Things.Features,part),id)end
		end
		for _,id in ipairs({"tipHatch","tipStyle","tipCompanions","tipPark"})do assert(Coach.Gated[id]=="follow",id)end
		for _,id in ipairs({"needHi","needToy","needDeck","needPark"})do assert(Coach.Gated[id]=="needs",id)end
		for _,id in ipairs({"tipNest","needNest","nestIntro","weekDone"})do assert(Coach.Gated[id]=="nest",id)end
		for _,id in ipairs({"fillLine","gardenIntro","hatch","style","companions","quests","book","park","item","questDone","petArrived"})do
			assert(Coach.Gated[id]==nil and Coach.allows(id),id)
		end
		Things.inject({flags={ThingsToDo=true},studio=true})
		Onboard.inject({flags=on,studio=true,needs=false})
		assert(Coach.allows("parkInvite")and Coach.allows("dashSeen"),"Things ids follow Things")
		assert(Coach.allows("tipHatch")and Coach.allows("needNest")and not Coach.allows("needHi"),"Onboard ids follow their own part")
		Things.inject({flags={ThingsToDo=true},studio=true,tips=false})
		assert(not Coach.allows("parkInvite")and Coach.allows("dashSeen")and Coach.allows("tipHatch"),"Things tips off leaves onboarding alone")
		Onboard.inject({flags={},studio=true})
		assert(not Coach.allows("tipHatch")and not Coach.allows("weekDone")and Coach.allows("dashSeen"),"onboarding off leaves Things alone")
		assert(Coach.allows("nope")and not Coach.validId("nope"),"an unknown id is not gated here: validId refuses it first")
	end)
	return{passed=#cases,cases=cases}
end
