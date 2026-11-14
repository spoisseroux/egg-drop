-- W2 station attract: the distance + used-this-session state machine, ping limits
-- and one instance driven by a fake station context. No prompts are fired.
return function(client, parent)
	local Attract = require(client.StationAttract)
	local Data = Attract.Data
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end

	test("far = glow only; 40 studs = beckon; 14 studs = invite; learned = marker within 18; hidden overrides all", function()
		assert(Attract.state(60, false, true) == "learned")
		assert(Attract.state(40.01, false, true) == "learned")
		assert(Attract.state(40, false, true) == "beckon" and Attract.state(14.01, false, true) == "beckon")
		assert(Attract.state(14, false, true) == "invite" and Attract.state(0, false, true) == "invite")
		-- QA v2 R5.2: a used / coach-learned station keeps its marker on approach (never fully silent).
		assert(Attract.state(5, true, true) == "marker" and Attract.state(Data.MarkerRange, true, true) == "marker")
		assert(Attract.state(Data.MarkerRange + .01, true, true) == "learned" and Attract.state(30, true, true) == "learned",
			"a used station still beckons")
		assert(Attract.state(5, false, false) == "hidden" and Attract.state(nil, false, true) == "hidden")
		assert(Attract.state(5, true, false) == "hidden", "a learned marker over a menu")
		for _, mode in ipairs({ "beckon", "invite", "marker" }) do assert(Attract.showsMarker(mode), mode) end
		assert(not Attract.showsMarker("learned") and not Attract.showsMarker("hidden"))
		assert(Attract.showsLabel("invite", 10) and Attract.showsLabel("marker", Data.LabelRange))
		assert(not Attract.showsLabel("marker", Data.LabelRange + .01) and not Attract.showsLabel("beckon", 20) and not Attract.showsLabel("hidden", 2))
	end)

	test("QA v2 R5.1: the pointer is tucked under the disc (one connected pin) and every station has label copy", function()
		local g = Attract.pointerGeometry()
		assert(g.cornerRadius <= .5 and g.cornerRadius >= .45, "pointer corners off the disc edge: " .. g.cornerRadius)
		assert(g.tipY > 1 / Data.MarkerAspect and g.tipY <= 1, "pointer tip not below the icon inside the marker")
		-- The diamond's top corner hides behind the disc (above the disc's lower edge).
		local topY = g.position.Y.Scale - Data.PointerHalf / Data.MarkerAspect
		assert(topY < 1 / Data.MarkerAspect, "pointer does not reach under the disc (gap)")
		local UICopy = require(game:GetService("ReplicatedStorage").Shared.UICopy)
		for _, id in ipairs(Data.Order) do
			local name, line = Attract.labelText(id, true)
			assert(name ~= "" and line ~= "" and UICopy.has("r5.station." .. id .. ".name") and UICopy.has("r5.station." .. id .. ".line"), id)
			local short, none = Attract.labelText(id, false)
			assert(short == name and none == nil, id)
		end
	end)

	test("ping: none in the first 10 s, one per station per 45 s, one of any kind per 20 s", function()
		assert(not Attract.canPing(9.9, 0, nil, nil) and Attract.canPing(10, 0, nil, nil))
		assert(not Attract.canPing(30, 0, 15, nil) and Attract.canPing(35, 0, 15, nil))
		assert(not Attract.canPing(100, 0, 60, 60) and Attract.canPing(105, 0, 60, 60))
	end)

	test("the marker hops twice in 1 s then rests 1 s; glow breath is +-8 % learned and +-20 % active", function()
		assert(Attract.hop(.25) > .99 and Attract.hop(.75) > .99 and Attract.hop(.5) < .01 and Attract.hop(1.5) == 0)
		local lo, hi, alo, ahi = 2, 0, 2, 0
		for i = 0, 320 do
			local t = i / 100
			lo, hi = math.min(lo, Attract.breath("learned", t)), math.max(hi, Attract.breath("learned", t))
			alo, ahi = math.min(alo, Attract.breath("beckon", t)), math.max(ahi, Attract.breath("beckon", t))
		end
		assert(math.abs(hi - 1.08) < .002 and math.abs(lo - .92) < .002 and math.abs(ahi - 1.2) < .002 and math.abs(alo - .8) < .002)
	end)

	test("a live instance walks learned -> beckon -> invite, pings once, and remembers use for the session", function()
		local folder = Instance.new("Folder"); folder.Parent = parent or workspace
		local clock, plays = 0, {}
		local voice = {}
		function voice:play(cue, pitch, volume) table.insert(plays, { cue, pitch, volume }); return true end
		local position = Vector3.new(-46, 4, 60)
		local state = { uiReady = true, mode = "Room", viewMode = "Room", alive = true, position = position }
		local a = Attract.new({ auto = false, world = folder, now = function() return clock end, voice = voice,
			read = function() state.position = position; return state end,
			positions = { Customize = Vector3.new(-46, 4.2, -9) } })
		local ok, err = pcall(function()
			local e = a.stations.Customize
			clock = 20; a:step(1 / 30)
			assert(e.state == "learned" and not e.billboard.Enabled and not e.shaft.Enabled, "far station shows its icon")
			position = Vector3.new(-46, 4, 20); a:step(1 / 30)
			assert(e.state == "beckon" and e.billboard.Enabled and e.shaft.Enabled and e.surface.Enabled and not e.label.Enabled)
			assert(e.pointer.Parent == e.billboard and e.icon.Parent == e.billboard and not e.billboard:FindFirstChild("Chevron"),
				"icon and pointer are not one marker")
			position = Vector3.new(-46, 4, 0); a:step(1 / 30)
			assert(e.state == "invite" and #plays == 1 and plays[1][1] == "machine_attract" and plays[1][2] == 1)
			assert(e.label.Enabled and e.labelLine.Visible and e.labelName.Text ~= "", "first visit: no name + line label")
			clock += Data.IntroSeconds; for _ = 1, math.ceil(Data.IntroSeconds * 30) + 2 do a:step(1 / 30) end
			assert(e.label.Enabled and not e.labelLine.Visible, "the intro line never shortens to the name")
			for _ = 1, 10 do a:step(1 / 30) end
			assert(#plays == 1, "pinged every frame")
			state.mode = "Board"; a:step(1 / 30)
			assert(e.state == "hidden" and not e.billboard.Enabled, "attract shown in Board mode")
			state.mode = "Room"; state.overlay = true; a:step(1 / 30); assert(e.state == "hidden", "attract over a menu")
			state.overlay = nil; a:step(1 / 30)
			assert(a:markUsed("Customize") and not a:markUsed("Nope"))
			a:step(1 / 30); assert(e.state == "hidden", "not hidden for 2 s after use")
			clock += 2.1; a:step(1 / 30)
			-- QA v2 R5.2: used and close = the quiet marker + name, no shaft/ring/sparkles.
			assert(e.state == "marker" and e.billboard.Enabled and e.label.Enabled and not e.labelLine.Visible, "a used station lost its marker")
			assert(not e.shaft.Enabled and not e.surface.Enabled and not e.sparkles.Enabled, "a used station still beckons")
			position = Vector3.new(-46, 4, 20); a:step(1 / 30)
			assert(e.state == "learned" and not e.billboard.Enabled and not e.label.Enabled, "a used station beckons from afar")
			position = Vector3.new(-46, 4, 0); a:step(1 / 30)
			local count = #folder:GetDescendants()
			for _ = 1, 60 do a:step(1 / 30) end
			assert(#folder:GetDescendants() == count, "attract allocated per frame")
		end)
		a:destroy(); folder:Destroy(); assert(ok, err)
	end)

	test("QA Q4: the Pet Park attract hovers over the east gateway and is learned on the first walk in", function()
		local Park = require(game:GetService("ReplicatedStorage").Shared.ParkLayout)
		local anchor = Attract.parkAnchor()
		local Flags = require(game:GetService("ReplicatedStorage").Shared.FeatureFlags)
		if Flags.Park ~= true or not Park.Enabled then assert(anchor == nil, "park attract with the park off"); return end
		assert(anchor == Park.Gateways[1].position, "park attract not on the east gateway")
		assert(Data.Stations.Park and Data.Stations.Park.hue and table.find(Data.Order, "Park"))
		local folder = Instance.new("Folder"); folder.Parent = parent or workspace
		local position = anchor + Vector3.new(20, 0, 0)
		local state = { uiReady = true, mode = "Room", viewMode = "Room", alive = true, position = position }
		local a = Attract.new({ auto = false, world = folder, now = function() return 30 end,
			read = function() state.position = position; return state end, positions = { Park = anchor } })
		local ok, err = pcall(function()
			local e = a.stations.Park
			a:step(1 / 30); assert(e.state == "beckon" and e.billboard.Enabled, "park does not beckon at 20 studs")
			assert(e.billboard:FindFirstChild("Icon"), "no icon (vector stand-in until the upload)")
			position = Park.Center; a:step(1 / 30)
			assert(a.used.Park == true, "walking into the park did not learn it")
			position = anchor + Vector3.new(6, 0, 0); a:step(1 / 30)
			assert(e.state == "marker" and e.billboard.Enabled and not e.shaft.Enabled, "a learned park lost its marker or still beckons")
			position = anchor + Vector3.new(30, 0, 0); a:step(1 / 30)
			assert(e.state == "learned" and not e.billboard.Enabled, "a learned park still beckons from afar")
		end)
		a:destroy(); folder:Destroy(); assert(ok, err)
	end)

	test("QA v2 R5.2: a coach-learned Eggs station (saved hatch bit) keeps its marker and name, never the loud beckon", function()
		local folder = Instance.new("Folder"); folder.Parent = parent or workspace
		local position = Vector3.new(-31, 4, -3)
		local state = { uiReady = true, mode = "Room", viewMode = "Room", alive = true, position = position }
		local a = Attract.new({ auto = false, world = folder, now = function() return 30 end,
			read = function() state.position = position; return state end, positions = { Eggs = Vector3.new(-31, 4.1, -11) } })
		local ok, err = pcall(function()
			assert(a:learn("Eggs"))
			local e = a.stations.Eggs
			a:step(1 / 30)
			assert(e.state == "marker" and e.billboard.Enabled and e.label.Enabled and not e.labelLine.Visible)
			assert(not e.shaft.Enabled and not e.surface.Enabled)
		end)
		a:destroy(); folder:Destroy(); assert(ok, err)
	end)

	test("the egg nest icon id slot and three hues exist for the coordinator", function()
		for _, id in ipairs(Data.Order) do assert(Data.Stations[id] and Data.Stations[id].hue) end
		assert(Data.Stations.Eggs.iconHeight < Data.Stations.Customize.iconHeight)
	end)

	return { passed = #cases, cases = cases }
end
