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
		test("overlap ownership is nearest with a stable tie independent of enumeration",function()
			prompt.Parent=part;prompt:SetAttribute("PocketClubStation","Journal")
			local other=Instance.new("ProximityPrompt");other.MaxActivationDistance=7
			other:SetAttribute("PocketClubStation","Eggs");other.Parent=part
			assert(Priority.nearest(part.Position,{prompt,other})==other)
			assert(Priority.nearest(part.Position,{other,prompt})==other)
			other:Destroy()
		end)
	end)
	prompt:Destroy();part:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
