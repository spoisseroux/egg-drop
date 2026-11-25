-- The upper tier runtime switch (TierConfig on AliveConfig's publisher, UPPER-TIER-BUILD-PLAN.md) on a fake ConfigService and
-- scheduler: IslandBoundsConfig's rules (off before the first load, then missing = on; a failed refresh keeps the last
-- good value). Usage (Server): require(ServerScriptService.Server.ZZSpecs.TierConfig)(ServerScriptService.Server);
-- offline in scripts/run_dash_server_specs.py.
return function(server)
	local Tier=require(game:GetService("ReplicatedStorage").Shared.Tier)
	local Config=require(server.TierConfig)
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
		function r.is(value)return r.held==value and r.attr.Tier_on==value end
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
	test("off before the config loads; once loaded a missing key is on (the cliff path is the way up, 2026-11-25), true is on; only garden_tier is read",function()
		local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end)
		r.config.start();assert(r.is(false)and table.concat(r.log,",")=="hold false,set Tier_on false",table.concat(r.log,","))
		for _,case in ipairs({{nil,true},{false,false},{true,true},{"false",true}})do
			local s=snapshot({garden_tier=case[1],garden_hush=false})
			local q=rig(of(s));q.config.start();assert(q.is(case[2]),tostring(case[1]))
			for _,key in ipairs(s.asked)do assert(key=="garden_tier",key)end
		end
	end)
	test("/tier on, off and clear beat the config; go, home, nonsense and other commands are not its; a closed ceiling does nothing",function()
		local r=rig(of(snapshot({garden_tier=false})));r.config.start();assert(r.is(false))
		assert(r.config.command(" /TIER On ")and r.is(true)and r.config.command("/tier off")and r.is(false)and r.config.command("/tier clear")and r.is(false))
		for _,odd in ipairs({"/tier","/tier maybe","tier on","/tier on now","/tier go","/tier home","/bounds on",5,{}})do assert(not r.config.command(odd),tostring(odd))end
		assert(not r.config.command(nil))
		local asked=false
		local q=rig(function()asked=true;error("asked")end,function()return false end)
		q.config.start();assert(not q.config.command("/tier on"));q.advance(1000);assert(#q.log==0 and not asked)
		assert(Config.parse("/tier on").value==true and Config.parse("/tier clear").value==nil and Config.parse("/tier off").value==false)
		assert(Tier.Key=="garden_tier"and Tier.Attribute=="Tier_on")
	end)
	test("a failed refresh keeps the last good value; a good one later is taken",function()
		local s=snapshot({garden_tier=true})
		local r=rig(of(s));r.config.start();assert(r.is(true))
		s.values.garden_tier=false;s.fail=true;s.update();r.advance(30);assert(r.is(true))
		s.fail=false;r.advance(400);assert(r.is(false))
	end)
	return{passed=#cases,cases=cases}
end
