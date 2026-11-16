-- Park counter (QA v735 W2): "Pets playing 3/9" from garden membership, "Park full · 9/9" with a
-- pointer to the other park when it has room, and a layout that stacks above the Menu + Deck
-- dock (never beside it) and stays on a 812 x 354 phone. Fake snapshots and a fake park client;
-- no remotes, no GardenState.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.ParkCounter)(PlayerScripts.Client, workspace)
return function(client,parent)
	local Counter=require(client.ParkCounter)
	local Control=require(client.ParkThrowControl)
	local Room=require(client.RoomView)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Park=require(Shared.ParkLayout)
	local Copy=require(Shared.UICopy)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	assert(Park.Enabled,"ParkLayout needs the v7 world")
	local arrival,grove=Park.ById.arrival,Park.ById.grove
	local root=Instance.new("Folder");root.Name="_ParkCounterSpec";root.Parent=parent or workspace
	-- n pets in `first`, m in `second`, plus two that are in no park and must not count.
	local function actors(first,n,second,m)
		local out={}
		for i=1,n do out[tostring(i)]={parkId=first.Id,mode="Room"}end
		for i=1,m or 0 do out[tostring(100+i)]={parkId=second.Id,mode="Room"}end
		out["900"]={mode="Room"};out["901"]={mode="Board"}
		return out
	end
	local ok,err=pcall(function()

	test("capacity is one pet per slot: 9 at both parks",function()
		assert(Counter.capacity(arrival)==9 and Counter.capacity(grove)==9,"capacity "..Counter.capacity(arrival).."/"..Counter.capacity(grove))
		assert(Counter.capacity(nil)==0)
	end)

	test("members counts only pets whose membership is this park",function()
		local snapshot=actors(arrival,3,grove,5)
		assert(Counter.members(snapshot,"arrival")==3 and Counter.members(snapshot,"grove")==5)
		assert(Counter.members(nil,"arrival")==0 and Counter.members({},"arrival")==0)
	end)

	test("live count reads Pets playing 3/9 on one line",function()
		local status=Counter.status(actors(arrival,3,grove,9),arrival,Park.Sites)
		assert(status.count==3 and status.capacity==9 and not status.full and status.lines==1 and status.other==nil)
		assert(status.text==Copy.get("park.count",{count=3,capacity=9}),status.text)
		assert(string.find(Copy.get("park.count",{count=3,capacity=9}),"3/9",1,true),"copy lost the count")
		assert(Counter.status({},grove,Park.Sites).text==Copy.get("park.count",{count=0,capacity=9}))
	end)

	test("a full park says Park full 9/9 and points to the other park when it has room",function()
		local status=Counter.status(actors(arrival,9,grove,4),arrival,Park.Sites)
		assert(status.full and status.count==9 and status.other==grove and status.lines==2)
		assert(status.text==Copy.get("park.full",{count=9,capacity=9}).."\n"..Copy.get("park.otherHasRoom"),status.text)
		assert(string.find(Copy.get("park.full",{count=9,capacity=9}),"9/9",1,true),"copy lost the count")
		local mirrored=Counter.status(actors(grove,9,arrival,0),grove,Park.Sites)
		assert(mirrored.full and mirrored.other==arrival)
	end)

	test("both parks full: no pointer; a crowd past capacity still reads 9/9",function()
		local status=Counter.status(actors(arrival,11,grove,9),arrival,Park.Sites)
		assert(status.full and status.other==nil and status.lines==1 and status.count==9)
		assert(status.text==Copy.get("park.full",{count=9,capacity=9}),status.text)
	end)

	test("layout: above the dock, on its right edge, never beside it",function()
		local dock=UDim2.new(1,-12,1,-102)
		local throw,count,height=Counter.layout(dock,false,1)
		assert(count.X==dock.X and throw.X==dock.X,"the counter moved off the dock's column")
		assert(count.Y.Offset==dock.Y.Offset-Room.DockHeight-Counter.Gap,"the counter is not directly above the dock")
		assert(height==Counter.LineHeight)
		local throw2,count2,height2=Counter.layout(dock,true,2)
		assert(throw2.Y.Offset==dock.Y.Offset-Room.DockHeight-Counter.Gap,"Throw is not directly above the dock")
		assert(count2.Y.Offset==throw2.Y.Offset-Counter.ThrowHeight-Counter.Gap,"the counter is not above Throw")
		assert(height2==Counter.LineHeight+Counter.LineExtra)
		assert(Counter.DockHeight==Room.DockHeight,"dock height drifted from RoomView")
	end)

	test("layout fits phones and desktop under the top bar, tallest stack",function()
		for _,screen in ipairs({{812,354,true},{844,390,true},{926,428,true},{1024,768,true},{1280,720,false}})do
			local dock=Room.dockPlacement(screen[1],screen[2],screen[3])
			local _,count,height=Counter.layout(dock,true,2)
			local top=screen[2]+count.Y.Offset-height
			assert(top>=64,string.format("%dx%d: the counter's top is at %d, under the top bar",screen[1],screen[2],top))
		end
	end)

	test("gui: counter shows in the park above the dock; Throw only when it can be pressed",function()
		local folder=Instance.new("Folder");folder.Parent=root
		local fetch={stage="idle",laneReady=true,availableOwners={}}
		local garden={playerId=7,snapshot={actors=actors(arrival,3,grove,0)}}
		local fakePark={folder=folder,sites={arrival={block=function()return {fetch=fetch}end},grove={block=function()return {fetch=fetch}end}}}
		local control=Control.new(fakePark,{gui=folder,garden=garden})
		local dock=UDim2.new(1,-12,1,-102)
		local context={active=true,ownerPosition=arrival.Center,dockPosition=dock}
		control:step(0,context)
		local gui=folder:FindFirstChild("EggDropParkThrow")
		assert(gui and gui.Enabled,"no park gui inside the park")
		local count,button=gui.ParkCount,gui.Throw
		assert(count.Visible and count.Text==Copy.get("park.count",{count=3,capacity=9}),count.Text)
		assert(not button.Visible and not control.enabled,"Throw shown while the pets are busy")
		assert(count.AnchorPoint==Vector2.one and count.Position.X==dock.X and count.Position.Y.Offset==dock.Y.Offset-Room.DockHeight-Counter.Gap,"counter not above the dock")
		-- Throw available: the button takes the row above the dock, the counter moves above it.
		fetch.availableOwners["7"]=true
		control:step(0,context)
		assert(button.Visible and control.enabled and button.Text==Copy.get("park.throw"))
		assert(button.Position.X==dock.X and button.Position.Y.Offset==dock.Y.Offset-Room.DockHeight-Counter.Gap,"Throw not above the dock")
		assert(count.Position.Y.Offset==button.Position.Y.Offset-Counter.ThrowHeight-Counter.Gap,"counter not above Throw")
		-- The park fills up: live text, two lines, pointer to the grove.
		garden.snapshot={actors=actors(arrival,9,grove,2)}
		control:step(0,context)
		assert(count.Text==Copy.get("park.full",{count=9,capacity=9}).."\n"..Copy.get("park.otherHasRoom"),count.Text)
		assert(count.Size.Y.Offset==Counter.LineHeight+Counter.LineExtra)
		-- The other park: its own count.
		context.ownerPosition=grove.Center
		control:step(0,context)
		assert(count.Text==Copy.get("park.count",{count=2,capacity=9}),count.Text)
		-- Outside any park, or with a menu open: hidden.
		context.ownerPosition=arrival.Center+Vector3.new(0,0,400)
		control:step(0,context)
		assert(not gui.Enabled,"park gui shown outside the park")
		context.ownerPosition=arrival.Center;context.active=false
		control:step(0,context)
		assert(not gui.Enabled,"park gui shown while inactive")
		control:destroy()
		assert(folder:FindFirstChild("EggDropParkThrow")==nil,"destroy left the gui")
	end)

	end)
	root:Destroy()
	if not ok then error(err,0)end
	return {suite="ParkCounter",passed=#cases,cases=cases}
end
