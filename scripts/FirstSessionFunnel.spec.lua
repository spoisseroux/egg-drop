-- Slice A (artifacts/slice-a-2026-11-14/PLAN.md): the 9-step onboarding funnel logs each step
-- once, when it happens (early steps are not held), step 9 is the first round started after
-- the Bear, returning players get no funnel, and the analytics helpers build Roblox's custom
-- field shape. Usage (Server): require(ServerScriptService.Server.ZZSpecs.FirstSessionFunnel)(ServerScriptService.Server)
return function(server)
	local FS=require(server.FirstSession)
	local Economy=require(server.EconomyAnalytics)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function session(profile)
		local log={}
		local s=FS.new({Name="spec"},profile or {rank=0},{force=true,log=function(_,kind,a,b)table.insert(log,{kind,a,b})end})
		return s,log
	end

	test("nine named steps, numbered 1..9",function()
		assert(#FS.StepNames==9)
		local seen={};for _,n in pairs(FS.Steps)do assert(not seen[n]and n>=1 and n<=9);seen[n]=true end
		assert(FS.StepNames[4]=="Bear met"and FS.StepNames[9]=="Second round started")
	end)

	test("steps log once each, in the order they happen (no holding)",function()
		local s,log=session()
		assert(s:advance(1)and s:advance(2)and s:advance(3))
		assert(not s:advance(2),"a repeat is dropped")
		assert(s:advance(8),"a spend before step 4 still logs")
		assert(s:advance(4))
		assert(#log==5 and log[4][2]==8 and log[5][2]==4 and log[5][3]=="Bear met")
		assert(not s:advance(0)and not s:advance(10),"unknown steps are ignored")
	end)

	test("step 9 is the first round started after the Bear",function()
		local s,log=session()
		s:roundStarted();assert(#log==0,"the Welcome round is not the second round")
		s:advance(4);s:roundStarted();s:roundStarted()
		assert(#log==2 and log[2][2]==9,"step 9 once")
	end)

	test("returning or failed saves get no funnel; Studio needs force",function()
		assert(FS.new({}, {rank=1},{force=true})==nil)
		assert(FS.new({}, {rank=0,loadFailed=true},{force=true})==nil)
		assert(FS.new({}, {rank=0})==nil,"Studio is a no-op")
	end)

	test("milestones log once",function()
		local s,log=session();s:record("FirstSessionLoungeVisit");s:record("FirstSessionLoungeVisit")
		assert(#log==1 and log[1][1]=="event")
	end)

	test("custom fields use the AnalyticsCustomFieldKeys names, capped at three and 50 chars",function()
		local f=Economy.customFields({"beanie",string.rep("x",80),"c","dropped"})
		local k1=Enum.AnalyticsCustomFieldKeys.CustomField01.Name
		local k3=Enum.AnalyticsCustomFieldKeys.CustomField03.Name
		assert(f[k1]=="beanie"and #f[Enum.AnalyticsCustomFieldKeys.CustomField02.Name]==50 and f[k3]=="c")
		local n=0;for _ in pairs(f)do n+=1 end;assert(n==3)
		assert(Economy.customFields(nil)==nil and Economy.customFields({})==nil)
	end)

	test("the sink hook fires even in Studio, and a failing hook never breaks a sink",function()
		local saved=Economy.onSink;local hits=0;Economy.onSink=function()hits+=1 end
		Economy.sink({},5,10,"Shop","x");Economy.sink({},0,10,"Shop","x")
		Economy.onSink=function()error("boom")end;Economy.sink({},5,10,"Shop","x")
		Economy.onSink=saved
		assert(hits==1)
	end)

	return cases
end
