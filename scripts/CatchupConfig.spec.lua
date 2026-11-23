-- The pet catch-up runtime switch (CatchupConfig on AliveConfig's publisher, beta (12) QA G1) on a fake ConfigService
-- and scheduler. Usage (Server): require(ServerScriptService.Server.ZZSpecs.CatchupConfig)(ServerScriptService.Server);
-- offline in scripts/run_dash_server_specs.py.
return function(server)
	local Catchup=require(game:GetService("ReplicatedStorage").Shared.PetCatchup)
	local Config=require(server.CatchupConfig)
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
		function r.is(value)return r.held==value and r.attr.Catchup_on==value end
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
	test("off before the config loads; once loaded a missing key is on, false is off; only pet_catchup is read",function()
		local r=rig(function()return{GetConfigAsync=function()return coroutine.yield()end}end)
		r.config.start();assert(r.is(false)and table.concat(r.log,",")=="hold false,set Catchup_on false",table.concat(r.log,","))
		for _,case in ipairs({{nil,true},{false,false},{true,true},{"false",true}})do
			local s=snapshot({pet_catchup=case[1],garden_finds=false})
			local q=rig(of(s));q.config.start();assert(q.is(case[2]),tostring(case[1]))
			for _,key in ipairs(s.asked)do assert(key=="pet_catchup",key)end
		end
	end)
	test("/catchup on, off and clear beat the config; nonsense and other commands are ignored; a closed ceiling does nothing",function()
		local r=rig(of(snapshot({pet_catchup=false})));r.config.start();assert(r.is(false))
		assert(r.config.command(" /CATCHUP On ")and r.is(true)and r.config.command("/catchup off")and r.is(false)and r.config.command("/catchup clear")and r.is(false))
		for _,odd in ipairs({"/catchup","/catchup maybe","catchup on","/catchup on now","/finds on",5,{}})do assert(not r.config.command(odd),tostring(odd))end
		assert(not r.config.command(nil))
		local asked=false
		local q=rig(function()asked=true;error("asked")end,function()return false end)
		q.config.start();assert(not q.config.command("/catchup on"));q.advance(1000);assert(#q.log==0 and not asked)
		assert(Config.parse("/catchup on").value==true and Config.parse("/catchup clear").value==nil and Config.parse("/catchup off").value==false)
		assert(Catchup.Key=="pet_catchup"and Catchup.Attribute=="Catchup_on")
	end)
	return{passed=#cases,cases=cases}
end
