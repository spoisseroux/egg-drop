-- W2 station attract: the distance + used-this-session state machine, ping limits
-- and one instance driven by a fake station context. No prompts are fired.
return function(client, parent)
	local Attract = require(client.StationAttract)
	local Data = Attract.Data
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end

	test("far or learned = glow only; 40 studs = beckon; 14 studs = invite; hidden overrides all", function()
		assert(Attract.state(60, false, true) == "learned")
		assert(Attract.state(40.01, false, true) == "learned")
		assert(Attract.state(40, false, true) == "beckon" and Attract.state(14.01, false, true) == "beckon")
		assert(Attract.state(14, false, true) == "invite" and Attract.state(0, false, true) == "invite")
		assert(Attract.state(5, true, true) == "learned" and Attract.state(30, true, true) == "learned", "a used station still beckons")
		assert(Attract.state(5, false, false) == "hidden" and Attract.state(nil, false, true) == "hidden")
	end)

	test("ping: none in the first 10 s, one per station per 45 s, one of any kind per 20 s", function()
		assert(not Attract.canPing(9.9, 0, nil, nil) and Attract.canPing(10, 0, nil, nil))
		assert(not Attract.canPing(30, 0, 15, nil) and Attract.canPing(35, 0, 15, nil))
		assert(not Attract.canPing(100, 0, 60, 60) and Attract.canPing(105, 0, 60, 60))
	end)

	test("chevron hops twice in 1 s then rests 1 s; glow breath is +-8 % learned and +-20 % active", function()
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
			assert(e.state == "beckon" and e.billboard.Enabled and e.shaft.Enabled and e.surface.Enabled and not e.chevron.Visible)
			position = Vector3.new(-46, 4, 0); a:step(1 / 30)
			assert(e.state == "invite" and e.chevron.Visible and #plays == 1 and plays[1][1] == "machine_attract" and plays[1][2] == 1)
			for _ = 1, 10 do a:step(1 / 30) end
			assert(#plays == 1, "pinged every frame")
			state.mode = "Board"; a:step(1 / 30)
			assert(e.state == "hidden" and not e.billboard.Enabled, "attract shown in Board mode")
			state.mode = "Room"; state.overlay = true; a:step(1 / 30); assert(e.state == "hidden", "attract over a menu")
			state.overlay = nil; a:step(1 / 30)
			assert(a:markUsed("Customize") and not a:markUsed("Nope"))
			a:step(1 / 30); assert(e.state == "hidden", "not hidden for 2 s after use")
			clock += 2.1; a:step(1 / 30)
			assert(e.state == "learned" and not e.billboard.Enabled and not e.chevron.Visible, "a used station still beckons")
			local count = #folder:GetDescendants()
			for _ = 1, 60 do a:step(1 / 30) end
			assert(#folder:GetDescendants() == count, "attract allocated per frame")
		end)
		a:destroy(); folder:Destroy(); assert(ok, err)
	end)

	test("the egg nest icon id slot and three hues exist for the coordinator", function()
		for _, id in ipairs(Data.Order) do assert(Data.Stations[id] and Data.Stations[id].hue) end
		assert(Data.Stations.Eggs.iconHeight < Data.Stations.Customize.iconHeight)
	end)

	return { passed = #cases, cases = cases }
end
