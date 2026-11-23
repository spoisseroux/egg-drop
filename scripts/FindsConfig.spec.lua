-- The Garden finds runtime switch (FindsConfig on AliveConfig's publisher) on a fake ConfigService and scheduler.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.FindsConfig)(ServerScriptService.Server)
return function(server)
	local Finds=require(game:GetService("ReplicatedStorage").Shared.Finds)
	local Config=require(server.FindsConfig)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function rig(service,ceiling,set)
		local r={log={},attr={},parked={},at=0}
		r.config=Config.new({service=service,now=function()return r.at end,ceiling=ceiling or function()return true end,
			hold=function(value)r.held=value;table.insert(r.log,"hold "..tostring(value))end,
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
		function r.is(value)return r.held==value and r.attr.Finds_on==value end
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
	test("off is written before anything yields, the server's value first",function()
		local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end)
		r.config.start()
		assert(r.is(false)and table.concat(r.log,",")=="hold false,set Finds_on false",table.concat(r.log,","))
	end)
	test("once loaded a missing or malformed key is on, false is off; no other key is read",function()
		for _,case in ipairs({{nil,true},{false,false},{true,true},{"false",true},{0,true}})do
			local s=snapshot({garden_finds=case[1],garden_dash=false,things_to_do=false})
			local r=rig(of(s));r.config.start();assert(r.is(case[2]),tostring(case[1]))
			for _,key in ipairs(s.asked)do assert(key=="garden_finds",key)end
		end
	end)
	test("never loaded is off; a late load applies; an update flips it; a failed refresh keeps the last value",function()
		local calls,s=0,snapshot({})
		local r=rig(function()return{GetConfigAsync=function()calls+=1;if calls<3 then error("down")end;return s end}end)
		r.config.start();r.advance(5);assert(r.is(false)and calls==2);r.advance(20);assert(r.is(true))
		r.advance(100);s.values={garden_finds=false};s.update();r.advance(110);assert(r.is(false))
		r.advance(200);s.values={};s.fail=true;s.update();r.advance(210);assert(r.is(false));s.fail=false;r.advance(1000);assert(r.is(true))
	end)
	test("an attribute that cannot be written still turns the server off",function()
		local r=rig(of(snapshot({garden_finds=false})),nil,function()error("locked")end)
		r.config.start();assert(r.held==false)
	end)
	test("the ceiling is false: nothing is written, ConfigService is never asked, chat does nothing",function()
		local asked=false
		local r=rig(function()asked=true;error("asked")end,function()return false end)
		r.config.start();assert(not r.config.command("/finds on"));r.advance(1000);assert(#r.log==0 and not asked)
	end)
	test("/finds beats the config before and after it loads; clear goes back to it; nonsense is ignored",function()
		local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end);r.config.start()
		assert(r.config.command(" /FINDS On ")and r.is(true)and r.config.command("/finds clear")and r.is(false),"not loaded yet")
		r=rig(of(snapshot({garden_finds=false})));r.config.start();assert(r.is(false))
		assert(r.config.command("/finds on")and r.is(true)and r.config.command("/finds off")and r.is(false)and r.config.command("/finds clear")and r.is(false))
		for _,odd in ipairs({"/finds","/finds maybe","finds on","/find on","/finds on now","/dash on","/todo on"})do assert(not r.config.command(odd),odd)end
		for _,odd in ipairs({5,{},true})do assert(not r.config.command(odd))end
		assert(not r.config.command(nil))
	end)
	test("resolve is off with the ceiling off; the ceiling is the flag and the beta place or Studio, never live",function()
		assert(Finds.resolve(nil,nil,false)==false and Finds.resolve(true,true,false)==false)
		assert(Finds.resolve(nil,nil,true)==true and Finds.resolve(false,nil,true)==false and Finds.resolve(false,true,true)==true)
		local Flags={GardenFinds=true}
		assert(Finds.ceiling({flags=Flags,studio=false,place=Finds.PlaceId})and not Finds.ceiling({flags=Flags,studio=false,place=96451847774961}))
		assert(not Finds.ceiling({flags={GardenFinds=false},studio=true})and Finds.ceiling({flags=Flags,studio=true,place=1}))
	end)
	return{passed=#cases,cases=cases}
end
