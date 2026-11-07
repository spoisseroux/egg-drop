-- Run in the real game client; isolated geometry never moves a player or changes profile state.
return function(client)
	local Stations=require(client.LoungeStations)
	local cases={}
	local function test(name,body)body();table.insert(cases,name)end
	local function context()
		return{uiReady=true,mode="Room",viewMode="Room",alive=true,position=Vector3.zero,
			snapshot={status="Ready",inventoryMask=16},rank=0,trials=0}
	end
	test("rare-only inventory is browsable while an explicit empty mask overrides legacy rank",function()
		assert(Stations.canBrowse({status="Ready",inventoryMask=16},0,0))
		assert(not Stations.canBrowse({status="Ready",inventoryMask=0},4,255))
		assert(not Stations.canBrowse({status="Ready"},1,0))
		assert(not Stations.canBrowse({status="Ready"},0,255))
	end)
	test("missing mask rejects legacy prefix and trials until the loaded mask arrives",function()
		for _,snapshot in ipairs({{}, {status="Loading",inventoryMask=1},{status="Retrying",inventoryMask=1},
			{status="Ready",inventoryMask="1"},{status="Ready",inventoryMask=0}})do
			assert(not Stations.canBrowse(snapshot,0,0))
		end
		assert(not Stations.canBrowse(nil,4,255))
	end)
	test("committed pending ID recovery is separate from Ready-only browsing",function()
		local state={status="Retrying",inventoryMask=0,lastHatch={id="station-recovery",petId="pip"}}
		assert(not Stations.canBrowse(state,0,0) and Stations.canVisitEggs(state,0,0))
		state.lastHatch.id="";assert(not Stations.canVisitEggs(state,0,0))
		state.lastHatch.id="id";state.lastHatch.petId="unknown";assert(not Stations.canVisitEggs(state,0,0))
	end)
	test("all presentation owners reject free roam without changing focus controls",function()
		assert(Stations.canRoam(context()))
		for _,field in ipairs({"busy","switchQueued","focusing","overlay","menuOpen","coreMenu","textCapture"})do
			local state=context();state[field]=true;assert(not Stations.canRoam(state),field)
		end
		for field,value in pairs({uiReady=false,alive=false,mode="Board",viewMode="Board"})do
			local state=context();state[field]=value;assert(not Stations.canRoam(state),field)
		end
	end)
	test("UI lifetime rejects detached destroyed disabled and missing presentation nodes",function()
		local playerGui=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
		local main=Instance.new("ScreenGui");main.Parent=playerGui
		local overlays=Instance.new("ScreenGui");overlays.Parent=playerGui
		local node=Instance.new("Frame");node.Parent=overlays
		local owner={}
		assert(Stations.uiLive(owner,playerGui,main,overlays,node))
		owner.destroyed=true;assert(not Stations.uiLive(owner,playerGui,main,overlays,node));owner.destroyed=false
		node.Parent=nil;assert(not Stations.uiLive(owner,playerGui,main,overlays,node));node.Parent=overlays
		main.Enabled=false;assert(not Stations.uiLive(owner,playerGui,main,overlays,node));main.Enabled=true
		assert(not Stations.uiLive(owner,playerGui,main,overlays,node,nil))
		node:Destroy();assert(not Stations.uiLive(owner,playerGui,main,overlays,node))
		main:Destroy();overlays:Destroy()
	end)
	local lounge=Instance.new("Model");lounge.Name="_StationFixture";lounge.Parent=workspace
	local currentLounge=lounge
	local state=context();local player=game:GetService("Players").LocalPlayer
	local visits={Eggs=0,Journal=0,Customize=0}
	local triggered=Instance.new("BindableEvent");local changed=Instance.new("BindableEvent")
	local cache=Stations.new({player=player,read=function()return state end,lounge=function()return currentLounge end,
		triggered=triggered.Event,routes={Eggs=function()visits.Eggs+=1 end,
		Journal=function()visits.Journal+=1 end,Customize=function()visits.Customize+=1 end}})
	cache:watch(changed.Event)
	local function prompt(id,position,radius,tagAfter)
		local part=Instance.new("Part");part.Anchored=true;part.CanCollide=false;part.CanQuery=false
		part.Position=position;part.Parent=lounge
		local p=Instance.new("ProximityPrompt");p.MaxActivationDistance=radius
		if not tagAfter then p:SetAttribute("PocketClubStation",id)end
		p.Parent=part
		if tagAfter then p:SetAttribute("PocketClubStation",id)end
		return p,part
	end
	local ok,problem=pcall(function()
		test("new and late-tagged streamed prompts inherit the current overlay owner",function()
			state.overlay=true
			local p=prompt("Eggs",Vector3.zero,5,true);task.wait()
			assert(cache.records[p] and not p.Enabled and not cache:dispatch(p,player))
			state.overlay=false;changed:Fire();task.wait();assert(p.Enabled)
			p.Parent:Destroy();task.wait();assert(not cache.records[p])
		end)
		local eggs,eggPart=prompt("Eggs",Vector3.new(0,5.5,-3.5),5)
		local journal=prompt("Journal",Vector3.new(11,5.41,-6.3),7)
		test("overlapping nest and journal radii expose only the nearest shared-key station",function()
			state.position=Vector3.new(4.4,5.5,-4.62);cache:refresh()
			assert(eggs.Enabled and not journal.Enabled and cache:inReach())
			assert(not cache:dispatch(journal,player) and cache:dispatch(eggs,player))
			assert(visits.Eggs==1 and visits.Journal==0)
			state.position=Vector3.new(6,5.5,-5);cache:refresh()
			assert(not eggs.Enabled and journal.Enabled and cache:dispatch(journal,player))
		end)
		test("dispatch rechecks local player enabled state distance and current ownership",function()
			state.position=eggPart.Position;cache:refresh()
			assert(not cache:dispatch(eggs,nil))
			eggs.Enabled=false;assert(not cache:dispatch(eggs,player));cache:refresh()
			state.position=Vector3.new(100,100,100);assert(not cache:dispatch(eggs,player))
			state.position=eggPart.Position;state.coreMenu=true;assert(not cache:dispatch(eggs,player))
			state.coreMenu=false;state.textCapture=true;assert(not cache:dispatch(eggs,player))
			state.textCapture=false;state.alive=false;assert(not cache:dispatch(eggs,player));state.alive=true
			assert(visits.Eggs==1)
		end)
		test("detached reinserted and invalid-parent prompts share the single cache",function()
			eggPart.Parent=nil;task.wait();assert(not cache.records[eggs] and not cache:dispatch(eggs,player))
			eggPart.Parent=lounge;task.wait();cache:refresh();assert(cache.records[eggs] and eggs.Enabled)
			local attachment=Instance.new("Attachment");attachment.Parent=eggPart;eggs.Parent=attachment
			task.wait();assert(not eggs.Enabled and not cache:dispatch(eggs,player))
			eggs.Parent=eggPart;task.wait();cache:refresh();assert(eggs.Enabled)
			currentLounge=nil;assert(not cache:dispatch(eggs,player));currentLounge=lounge
		end)
		test("destroy disconnects trigger stream and owner listeners and disables owned prompts",function()
			cache:refresh();local before=visits.Eggs;cache:destroy()
			assert(not eggs.Enabled and next(cache.records)==nil and #cache.connections==0)
			triggered:Fire(eggs,player);changed:Fire();local late=prompt("Eggs",Vector3.zero,5);task.wait()
			assert(not cache.records[late] and visits.Eggs==before and not cache:inReach())
		end)
	end)
	cache:destroy();lounge:Destroy();triggered:Destroy();changed:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
