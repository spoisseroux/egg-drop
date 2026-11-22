-- The Things to do runtime switches (ThingsConfig on AliveConfig's publisher) on a fake ConfigService and scheduler, the
-- build ceiling, and the coach ids the server refuses while a part is off.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ThingsConfig)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Things=require(Shared.Things)
	local Coach=require(Shared.CoachMarks)
	local Config=require(server.ThingsConfig)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function rig(service,ceiling,set)
		local r={log={},held={},attr={},parked={},at=0}
		r.config=Config.new({service=service,now=function()return r.at end,ceiling=ceiling or function()return true end,
			hold=function(feature,value)r.held[feature]=value;table.insert(r.log,"hold "..feature.." "..tostring(value))end,
			set=set or function(name,value)r.attr[name]=value;table.insert(r.log,"set "..name.." "..tostring(value))end,
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
		function r.is(page,tips)return r.held.page==page and r.held.tips==tips and r.attr.Things_page==page and r.attr.Things_tips==tips end
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
	test("the ceiling: the flag, and the beta place or Studio",function()
		local on,off={ThingsToDo=true},{}
		assert(Things.ceiling({flags=on,place=Things.PlaceId,studio=false})and Things.ceiling({flags=on,place=1,studio=true}))
		assert(not Things.ceiling({flags=on,place=96451847774961,studio=false}),"never on the live place")
		assert(not Things.ceiling({flags=off,place=Things.PlaceId,studio=true})and not Things.ceiling({flags={ThingsToDo="yes"},place=Things.PlaceId,studio=true}))
		assert(not Things.resolve(true,true,false)and Things.resolve(nil,nil,true)and Things.resolve("x",nil,true)and not Things.resolve(false,nil,true))
		assert(not Things.resolve(true,false,true)and Things.resolve(false,true,true))
	end)
	test("off is written before anything yields, the server's value first",function()
		local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end)
		r.config.start()
		assert(r.is(false,false)and table.concat(r.log,",")=="hold page false,set Things_page false,hold tips false,set Things_tips false")
	end)
	test("once loaded a missing or malformed key is on, each key turns its own part off, no other key is read",function()
		for _,case in ipairs({{nil,nil,true,true},{false,nil,false,true},{nil,false,true,false},{"x",0,true,true},{true,true,true,true},{false,false,false,false}})do
			local s=snapshot({things_to_do=case[1],things_tips=case[2],garden_dash=false})
			local r=rig(of(s));r.config.start();assert(r.is(case[3],case[4]))
			for _,key in ipairs(s.asked)do assert(key=="things_to_do"or key=="things_tips",key)end
		end
	end)
	test("never loaded is off; a late load applies; an update flips it; a failed refresh keeps the last value",function()
		local calls,s=0,snapshot({})
		local r=rig(function()return{GetConfigAsync=function()calls+=1;if calls<3 then error("down")end;return s end}end)
		r.config.start();r.advance(5);assert(r.is(false,false)and calls==2);r.advance(20);assert(r.is(true,true))
		r.advance(100);s.values={things_to_do=false};s.update();assert(r.is(false,true))
		r.advance(200);s.values={};s.fail=true;s.update();assert(r.is(false,true));s.fail=false;r.advance(1000);assert(r.is(true,true))
	end)
	test("an attribute that cannot be written still turns the server off",function()
		local r=rig(of(snapshot({things_to_do=false})),nil,function()error("locked")end)
		r.config.start();assert(r.held.page==false)
	end)
	test("the ceiling is false: nothing is written, ConfigService is never asked, chat does nothing",function()
		local asked=false
		local r=rig(function()asked=true;error("asked")end,function()return false end)
		r.config.start();assert(not r.config.command("/todo on"));r.advance(1000);assert(#r.log==0 and not asked)
	end)
	test("/todo and /todo tips beat the config; nonsense is ignored",function()
		local r=rig(of(snapshot({things_to_do=false})));r.config.start()
		assert(r.config.command(" /TODO On ")and r.is(true,true)and r.config.command("/todo tips off")and r.is(true,false))
		assert(r.config.command("/todo clear")and r.is(false,false)and r.config.command("/todo tips clear")and r.is(false,true))
		for _,odd in ipairs({"/todo","/todo maybe","/todo tips","/todo tips maybe","todo on","/dash on","/todo on now"})do assert(not r.config.command(odd),odd)end
		for _,odd in ipairs({5,{},true})do assert(not r.config.command(odd))end
		assert(not r.config.command(nil))
	end)
	test("the new coach ids belong to a part; tips need the page; nothing older is gated",function()
		local ok,problem=pcall(function()
			assert(Coach.Gated.parkInvite=="tips"and Coach.Gated.dashIntro=="tips"and Coach.Gated.dashSeen=="page")
			for _,id in ipairs({"fillLine","gardenIntro","hatch","style","companions","quests","book","park","item","questDone","petArrived"})do assert(Coach.Gated[id]==nil,id)end
			Things.inject({flags={ThingsToDo=true},studio=true});assert(Things.allows("tips")and Things.allows("page"))
			Things.inject({flags={ThingsToDo=true},studio=true,tips=false});assert(not Things.allows("tips")and Things.allows("page"))
			Things.inject({flags={ThingsToDo=true},studio=true,page=false});assert(not Things.allows("tips")and not Things.allows("page"))
			Things.inject({flags={},studio=true});assert(not Things.allows("tips")and not Things.allows("page"))
		end)
		Things.inject(nil);assert(ok,problem)
	end)
	return{passed=#cases,cases=cases}
end
