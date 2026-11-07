-- Production browse coordinator, with deterministic time/identity changes and no remotes.
return function(client)
	local Stations=require(client.LoungeStations)
	local cases={}
	local function test(name,body)body();table.insert(cases,name)end
	local function fixture()
		local f={time=0,generation=0,character={},camera={},requests={},opened={},cancelled=0}
		f.state={uiReady=true,mode="Room",viewMode="Room",alive=true,
			snapshot={status="Ready",inventoryMask=16},rank=0,trials=0}
		f.d={cancel=function()f.generation+=1;f.cancelled+=1 end,read=function()return f.state end,
			generation=function()return f.generation end,identity=function()return f.character,f.camera end,
			canEnterFromBoard=function()return not f.blocked end,
			sendMode=function(mode)table.insert(f.requests,{"mode",mode})end,
			open=function()table.insert(f.opened,f.state.snapshot.lastHatch or "shop")end,
			now=function()return f.time end,wait=function(dt)f.time+=dt;if f.onWait then f.onWait()end end,
			spawn=function(run)run()end}
		return f
	end
	test("settled rare-only Room opens immediately without same-mode request",function()
		local f=fixture();assert(Stations.visitEggs(f.d));assert(#f.requests==0 and #f.opened==1 and f.time==0)
	end)
	test("Menu and tree recovery reopen the same committed ID without purchase or acknowledgment",function()
		local f=fixture();local result={id="station-pending-id",petId="pip"}
		f.state.snapshot={status="Retrying",inventoryMask=0,lastHatch=result}
		assert(Stations.visitEggs(f.d));assert(Stations.visitEggs(f.d))
		assert(#f.requests==0 and #f.opened==2 and f.opened[1]==result and f.opened[2]==result)
	end)
	test("unloaded or explicitly empty inventory cannot start a browse route",function()
		for _,snapshot in ipairs({{status="Loading",inventoryMask=16},{status="Ready",inventoryMask=0}})do
			local f=fixture();f.state.snapshot=snapshot;assert(not Stations.visitEggs(f.d))
			assert(#f.requests==0 and #f.opened==0)
		end
	end)
	test("board origin waits for both server mode and settled local presentation",function()
		local f=fixture();f.state.mode="Board";f.state.viewMode="Board"
		f.onWait=function()
			if f.time>=.1 then f.state.mode="Room"end
			if f.time>=.4 then f.state.viewMode="Room";f.state.busy=true end
			if f.time>=.6 then f.state.busy=false end
		end
		assert(Stations.visitEggs(f.d));assert(#f.requests==1 and f.requests[1][2]=="Room" and #f.opened==1 and f.time>=.6)
	end)
	test("a newer navigation generation cancels the old board waiter",function()
		local f=fixture();f.state.mode="Board"
		f.onWait=function()f.generation+=1;f.state.mode="Room"end
		Stations.visitEggs(f.d);assert(#f.opened==0 and #f.requests==1)
	end)
	test("character and camera replacement cancel delayed presentation",function()
		for _,field in ipairs({"character","camera"})do
			local f=fixture();f.state.mode="Board"
			f.onWait=function()f[field]={};f.state.mode="Room"end
			Stations.visitEggs(f.d);assert(#f.opened==0,field)
		end
	end)
	test("native menu text capture and death interrupt waiting before late open",function()
		for _,field in ipairs({"coreMenu","textCapture","alive"})do
			local f=fixture();f.state.mode="Board"
			f.onWait=function()f.state[field]=field~="alive";f.state.mode="Room"end
			Stations.visitEggs(f.d);assert(#f.opened==0,field)
		end
	end)
	test("UI teardown stops the Board waiter immediately even with unchanged character and camera",function()
		local f=fixture();f.state.mode="Board"
		local originalCharacter,originalCamera=f.character,f.camera
		f.onWait=function()f.state.uiReady=false end
		Stations.visitEggs(f.d)
		assert(#f.requests==1 and #f.opened==0 and f.time<.2)
		assert(f.character==originalCharacter and f.camera==originalCamera)
		f.state.mode="Room";f.state.uiReady=true
		assert(#f.opened==0,"restored UI must not revive a cancelled waiter")
	end)
	test("empty inventory or another sheet at arrival cannot reopen the shop",function()
		for _,block in ipairs({"inventory","overlay","switchQueued"})do
			local f=fixture();f.state.mode="Board"
			f.onWait=function()
				f.state.mode="Room"
				if block=="inventory" then f.state.snapshot.inventoryMask=0 else f.state[block]=true end
			end
			Stations.visitEggs(f.d);assert(#f.opened==0,block)
		end
	end)
	test("blocked board route has no mode request and timeout never opens stale state",function()
		local f=fixture();f.state.mode="Board";f.blocked=true
		assert(not Stations.visitEggs(f.d) and #f.requests==0)
		f.blocked=false;Stations.visitEggs(f.d);assert(#f.opened==0 and #f.requests==1 and f.time>=4)
	end)
	return{passed=#cases,cases=cases}
end
