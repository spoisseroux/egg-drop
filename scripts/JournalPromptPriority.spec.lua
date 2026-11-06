return function(client)
	local Priority = require(client.JournalPromptPriority)
	local part = Instance.new("Part")
	part.Position = Vector3.new(11,5.4,-6.3)
	local prompt = Instance.new("ProximityPrompt")
	prompt.MaxActivationDistance, prompt.Parent = 7, part
	local cases = {}
	local function test(name, run) run();table.insert(cases,name)end
	local ok,problem=pcall(function()
		test("reachable enabled journal suppresses ambiguous pet shortcut",function()
			assert(Priority.stationInReach(Vector3.new(7.2,7,-7),{prompt}))
		end)
		test("moving away releases the pet shortcut",function()
			assert(not Priority.stationInReach(Vector3.new(-11,7,4),{prompt}))
		end)
		test("hidden or transition-disabled stations do not claim input",function()
			prompt.Enabled=false;assert(not Priority.stationInReach(part.Position,{prompt}));prompt.Enabled=true
		end)
		test("removed station and empty list release input",function()
			prompt.Parent=nil;assert(not Priority.stationInReach(part.Position,{prompt}));assert(not Priority.stationInReach(part.Position,{}))
		end)
		test("room cache follows added, removed and reparented station prompts",function()
			local Room=require(client.RoomView)
			local lounge=workspace:WaitForChild("EggDropLounge")
			local root=game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
			local cache={}
			Room.stationInReach(cache)
			local candidate=Instance.new("Part")
			candidate.Name,candidate.Anchored,candidate.CanCollide,candidate.CanQuery="_JournalPromptFixture",true,false,false
			candidate.Position,candidate.Parent=root.Position,lounge
			local added=Instance.new("ProximityPrompt")
			added:SetAttribute("PocketClubStation","Journal")
			added.Parent=candidate;task.wait(.05)
			assert(table.find(cache.stationPrompts,added) and Room.stationInReach(cache))
			candidate.Parent=nil;task.wait(.05);assert(not table.find(cache.stationPrompts,added))
			candidate.Parent=lounge;task.wait(.05);assert(table.find(cache.stationPrompts,added))
			candidate:Destroy();task.wait(.05);assert(not table.find(cache.stationPrompts,added))
			cache.stationAdded:Disconnect();cache.stationRemoved:Disconnect()
		end)
	end)
	prompt:Destroy();part:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
