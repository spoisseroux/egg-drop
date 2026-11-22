-- Studio Server. The Frutiger Aero switch (AeroConfig on AliveConfig's publisher) on a fake ConfigService and clock:
-- off until the config has loaded once, then missing / malformed = on, false is off, failures keep the last value,
-- /aero overrides, and a build with the ceiling off writes and asks nothing.
-- Usage: require(ServerScriptService.Server.ZZSpecs.AeroConfig)(ServerScriptService.Server)
return function(server)
	local Aero=require(game:GetService("ReplicatedStorage").Shared.Aero)
	local Config=require(server.AeroConfig)
	local Others={require(server.AliveConfig),require(server.LevelsConfig),require(server.DashConfig)}
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function rig(service,ceiling)
		local r={at=0,attrs={},writes=0,waits={}}
		r.config=Config.new({service=service,now=function()return r.at end,ceiling=ceiling or function()return true end,warn=function()end,
			set=function(name,value)r.attrs[name]=value;r.writes+=1 end,
			spawn=function(fn)local co=coroutine.create(fn);r.co=co;local ok,problem=coroutine.resume(co);assert(ok,problem)end,
			wait=function(s)table.insert(r.waits,s);return coroutine.yield()end})
		function r.is(value)return r.attrs[Aero.Attribute]==value end
		return r
	end
	local function snapshot(values)
		local s={values=values,listeners={},asked={}}
		function s:GetValue(key)table.insert(s.asked,key);return s.values[key]end
		function s:Refresh()if s.fails then error("down")end end
		s.UpdateAvailable={Connect=function(_,fn)table.insert(s.listeners,fn)end}
		function s.update()for _,fn in ipairs(s.listeners)do fn()end end
		return s
	end
	local function serviceOf(s)return function()return{GetConfigAsync=function()return s end}end end

	test("off is written before anything yields; a service that never answers or fails leaves it off",function()
		local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end)
		r.config.start();assert(r.is(false)and r.writes==1)
		r=rig(function()error("down")end);r.config.start();assert(r.is(false)and r.waits[1]==5)
		coroutine.resume(r.co);coroutine.resume(r.co);coroutine.resume(r.co);assert(table.concat(r.waits," ")=="5 15 60 300"and r.is(false))
	end)
	test("aero_world: false is off, true is on, missing and malformed are the shipped default; no other key is read",function()
		for _,case in ipairs({{false,false},{true,true},{nil,true},{"false",true},{0,true}})do
			local s=snapshot({aero_world=case[1],levels_matter=false});local r=rig(serviceOf(s));r.config.start()
			assert(r.is(case[2]),tostring(case[1]))
			for _,key in ipairs(s.asked)do assert(key=="aero_world",key)end
		end
	end)
	test("an update flips it without a publish; a failed refresh keeps the last value",function()
		local s=snapshot({});local r=rig(serviceOf(s));r.config.start();assert(r.is(true))
		r.at=10;s.values={aero_world=false};s.update();assert(r.is(false))
		r.at=20;s.values={};s.fails=true;s.update();assert(r.is(false))
	end)
	test("/aero on, off and clear beat the config; lime and coral pick the crowns; nonsense and the other commands are ignored",function()
		local s=snapshot({aero_world=false});local r=rig(serviceOf(s));r.config.start()
		assert(r.config.command(" /AERO On ")and r.is(true));r.at=10;s.update();assert(r.is(true))
		assert(r.config.command("/aero off")and r.is(false)and r.config.command("/aero on")and r.config.command("/aero clear")and r.is(false))
		assert(r.attrs[Aero.TreesAttribute]==nil)
		assert(r.config.command("/aero coral")and r.attrs[Aero.TreesAttribute]=="coral"and r.is(false))
		assert(r.config.command("/aero lime")and r.attrs[Aero.TreesAttribute]=="lime")
		for _,odd in ipairs({"/aero","/aero maybe","/aero all on","aero on","/alive all on","/aero on now","/aeroon"})do assert(not r.config.command(odd),odd)end
		for _,odd in ipairs({5,{},true})do assert(not r.config.command(odd))end
		for _,other in ipairs(Others)do assert(other.parse("/aero on")==nil)end
		assert(not r.config.command(nil)and r.is(false))
	end)
	test("the ceiling is false: nothing is written, ConfigService is never asked and /aero does nothing",function()
		local asked=false
		local r=rig(function()asked=true;error("asked")end,function()return false end)
		r.config.start();assert(not r.config.command("/aero on")and not r.config.command("/aero coral")and r.writes==0 and not asked)
	end)
	test("the live place is under no ceiling",function()
		assert(not Aero.ceiling({flags={AeroWorld=true},place=96451847774961,studio=false}))
	end)
	return{passed=#cases,cases=cases}
end
