-- The Garden Dash runtime switches (DashConfig on AliveConfig's publisher) on a fake ConfigService and scheduler.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DashConfig)(ServerScriptService.Server)
return function(server)
	local Config=require(server.DashConfig)
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
		function r.is(race,prizes)return r.held.race==race and r.held.prizes==prizes and r.attr.Dash_race==race and r.attr.Dash_prizes==prizes end
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
		assert(r.is(false,false)and table.concat(r.log,",")=="hold race false,set Dash_race false,hold prizes false,set Dash_prizes false")
	end)
	test("missing and malformed keys are on once loaded; each key turns its own part off; no other key is read",function()
		for _,case in ipairs({{nil,nil,true,true},{false,nil,false,true},{nil,false,true,false},{false,false,false,false},{"x",0,true,true},{true,true,true,true}})do
			local s=snapshot({garden_dash=case[1],garden_dash_prizes=case[2],levels_matter=false})
			local r=rig(of(s));r.config.start();assert(r.is(case[3],case[4]))
			for _,key in ipairs(s.asked)do assert(key=="garden_dash"or key=="garden_dash_prizes",key)end
		end
	end)
	test("never loaded is off; a late load applies; an update flips it; a failed refresh keeps the last value",function()
		local calls,s=0,snapshot({})
		local r=rig(function()return{GetConfigAsync=function()calls+=1;if calls<3 then error("down")end;return s end}end)
		r.config.start();r.advance(5);assert(r.is(false,false)and calls==2);r.advance(20);assert(r.is(true,true))
		r.advance(100);s.values={garden_dash=false};s.update();assert(r.is(false,true))
		r.advance(200);s.values={};s.fail=true;s.update();assert(r.is(false,true));s.fail=false;r.advance(1000);assert(r.is(true,true))
	end)
	test("an attribute that cannot be written still turns the server off",function()
		local r=rig(of(snapshot({garden_dash=false})),nil,function()error("locked")end)
		r.config.start();assert(r.held.race==false)
	end)
	test("the ceiling is false: nothing is written, ConfigService is never asked, chat does nothing",function()
		local asked=false
		local r=rig(function()asked=true;error("asked")end,function()return false end)
		r.config.start();assert(not r.config.command("/dash on"));r.advance(1000);assert(#r.log==0 and not asked)
	end)
	test("/dash and /dash prizes beat the config; nonsense is ignored",function()
		local r=rig(of(snapshot({garden_dash=false})));r.config.start()
		assert(r.config.command(" /DASH On ")and r.is(true,true)and r.config.command("/dash prizes off")and r.is(true,false))
		assert(r.config.command("/dash clear")and r.is(false,false)and r.config.command("/dash prizes clear")and r.is(false,true))
		for _,odd in ipairs({"/dash","/dash maybe","/dash prizes","/dash prizes maybe","dash on","/levels on","/dash on now"})do assert(not r.config.command(odd),odd)end
		for _,odd in ipairs({5,{},true})do assert(not r.config.command(odd))end
		assert(not r.config.command(nil))
	end)
	return{passed=#cases,cases=cases}
end
