-- First-session funnel fix (FIRST-SESSION-FUNNEL-PLAN-2026-11-23, revision): through a fake AnalyticsService,
-- step N logs only after step N-1, each step once; an early step goes once as the custom event
-- FunnelOutOfOrder_<StepKey>; FirstPet / FirstHatch / FiveMinutes log once; a throwing service or scheduler
-- never reaches the caller; only brand-new rank-0 saves get a funnel; FeatureFlags.FirstSessionFunnel=false logs nothing.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.FirstSession)(ServerScriptService.Server)
-- Offline: DASH_SPECS="FirstSession" python scripts/run_dash_server_specs.py <luau.exe>
return function(server)
	local FS=require(server.FirstSession)
	local Players=game:GetService("Players")
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local NEW={rank=0,newSave=true}
	local ON={FirstSessionFunnel=true}
	-- A stand-in AnalyticsService that records every call (or throws), run without the engine scheduler.
	local function fakeService(throws)
		local calls={}
		local service={calls=calls}
		function service:LogOnboardingFunnelStepEvent(player,step,name)
			if throws then error("analytics down")end
			table.insert(calls,{"step",step,name})
		end
		function service:LogCustomEvent(player,name,value)
			if throws then error("analytics down")end
			table.insert(calls,{"event",name,value})
		end
		return service
	end
	local function session(profile,more)
		local service=more and more.analytics or fakeService()
		local timers={}
		local options={force=true,analytics=service,players=Players,flags=ON,
			defer=function(fn,...)fn(...)end,
			delay=function(seconds,fn)table.insert(timers,{seconds,fn})end}
		for key,value in pairs(more or {})do options[key]=value end
		local player={Name="spec",Parent=Players}
		return FS.new(player,profile or NEW,options),service.calls,timers,player
	end
	local function steps(calls)
		local out={}
		for _,call in ipairs(calls)do if call[1]=="step"then table.insert(out,call[2])end end
		return out
	end
	local function events(calls,name)
		local n=0
		for _,call in ipairs(calls)do if call[1]=="event"and call[2]==name then n+=1 end end
		return n
	end

	test("the nine steps keep their numbers and names",function()
		assert(#FS.StepNames==9 and FS.Steps.BoardReady==1 and FS.Steps.SecondRound==9)
		assert(FS.StepNames[5]=="Garden walkthrough done"and FS.StepNames[8]=="First Stars spend")
		for key,step in pairs(FS.Steps)do assert(FS.StepKeys[step]==key)end
	end)

	test("order is enforced: step N logs only after step N-1",function()
		local s,calls=session()
		assert(not s:advance(2),"no drop before board ready")
		assert(s:advance(1)and s:advance(2)and s:advance(3)and s:advance(4))
		assert(not s:advance(6),"machine before the walkthrough")
		assert(s:advance(5)and s:advance(6))
		assert(not s:advance(8),"spend before a quest")
		assert(s:advance(7)and s:advance(8),"the next spend, now in order, logs")
		local logged=steps(calls)
		assert(#logged==8,#logged)
		for i,step in ipairs(logged)do assert(step==i)end
		assert(calls[1][2]=="FunnelOutOfOrder_FirstDrop"and calls[2][1]=="step"and calls[2][3]=="Board ready")
	end)

	test("each step logs once",function()
		local s,calls=session()
		assert(s:advance(1)and not s:advance(1))
		assert(s:advance(2)and not s:advance(2)and not s:advance(1))
		assert(not s:advance(0)and not s:advance(10),"unknown steps are ignored")
		assert(#steps(calls)==2)
	end)

	test("an out-of-order step goes once as FunnelOutOfOrder_<StepKey>, never as a step",function()
		local s,calls=session()
		s:advance(1);s:advance(8);s:advance(8);s:advance(9)
		assert(#steps(calls)==1)
		assert(events(calls,"FunnelOutOfOrder_FirstSpend")==1 and events(calls,"FunnelOutOfOrder_SecondRound")==1)
		for _,call in ipairs(calls)do assert(call[1]~="step"or call[2]==1)end
	end)

	test("step 9 is a round after the Bear, in order after step 8",function()
		local s,calls=session()
		s:roundStarted();assert(#calls==0,"the Welcome round is not the second round")
		for step=1,4 do s:advance(step)end
		s:roundStarted()
		assert(events(calls,"FunnelOutOfOrder_SecondRound")==1 and #steps(calls)==4)
		for step=5,8 do s:advance(step)end
		s:roundStarted();s:roundStarted()
		local logged=steps(calls);assert(#logged==9 and logged[9]==9)
	end)

	test("FirstPet, FirstHatch and FiveMinutes log once each",function()
		local s,calls,timers=session()
		assert(#timers==1 and timers[1][1]==300,"one five-minute timer")
		s:record("FirstPet");s:record("FirstPet");s:record("FirstHatch");s:record("FirstHatch")
		timers[1][2]();timers[1][2]()
		assert(events(calls,"FirstPet")==1 and events(calls,"FirstHatch")==1 and events(calls,"FiveMinutes")==1)
		assert(calls[1][3]==1,"custom event value")
	end)

	test("a player who left logs nothing",function()
		local s,calls,_,player=session()
		player.Parent=nil
		s:advance(1);s:record("FirstPet")
		assert(#calls==0)
	end)

	test("throws are contained: service, defer, delay and sink",function()
		local s=session(nil,{analytics=fakeService(true)})
		assert(s:advance(1)and s:advance(2),"a failing service still advances")
		s:record("FirstHatch")
		local d=session(nil,{defer=function()error("scheduler down")end})
		assert(d:advance(1))
		local t=session(nil,{delay=function()error("scheduler down")end})
		assert(t and t:advance(1),"a failed timer still gives a funnel")
		local k=session(nil,{log=function()error("sink down")end})
		assert(k:advance(1));k:record("FirstPet")
	end)

	test("only brand-new rank-0 saves get a funnel",function()
		assert(session({rank=0,newSave=true})~=nil)
		assert(session({rank=0})==nil,"returning rank-0 player: no funnel")
		assert(session({rank=0,newSave=false})==nil,"returning rank-0 player: no funnel")
		assert(session({rank=1,newSave=true})==nil)
		assert(session({rank=0,newSave=true,loadFailed=true})==nil)
		assert(session("not a profile")==nil)
		assert(FS.new({},NEW,{flags=ON})==nil,"Studio and unpublished places need force")
	end)

	test("gate off: no funnel, no events",function()
		local s,calls,timers=session(nil,{flags={FirstSessionFunnel=false}})
		assert(s==nil and #calls==0 and #timers==0)
		assert(session(nil,{flags={}})==nil)
	end)

	return {passed=#cases,cases=cases}
end
