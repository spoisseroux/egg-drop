-- Garden Dash stats and simulation (V3 slice S5): the 4.4 table at every level, determinism, the input rules,
-- the luck budget and the cost. Pure shared modules; no instances.
-- Usage: require(ServerScriptService.Server.ZZSpecs.DashSim)()  (third argument: {heats=n}, default 300)
-- Offline with 10,000 heats: scripts/run_dash_specs.py
return function(_, shared, options)
	local Shared = shared or game:GetService("ReplicatedStorage").Shared
	local Course = require(Shared.DashCourse)
	local Stats = require(Shared.DashStats)
	local Sim = require(Shared.DashSim)
	local HEATS = options and options.heats or 300
	local cases = {}
	local function test(name, run) local note = run(); table.insert(cases, if note then name .. ": " .. note else name) end
	local P, C, T = Sim.Result.Perfect, Sim.Result.Clear, Sim.Result.Trip
	local UNIT = Stats.UnitsPerCs
	local function near(a, b) return math.abs(a - b) < 1e-9 end

	-- A scripted player: presses each jump for the wanted result, through push(), like a real client.
	-- script: {jumps={P,C,T,...}, stones=bool, dash="hold" (default) | "smart" | "none"}
	local function drive(race, seat, script)
		local r = race.runners[seat]
		local tick = race.tick + 1
		if script.stones and not r.forked and not r.wants and Course.Fork * UNIT - r.pos < r.step * 150 then Sim.push(race, seat, tick, "stones") end
		local goal, want = r.list[r.next], script.jumps[r.next] or P
		local gap = if goal then Sim.takeoff(r, goal) - r.pos else Course.Length * UNIT
		if goal and want ~= T and r.air == 0 and r.tumble == 0 and script.at ~= r.next then
			local early = if want == P then r.step else r.judge * 20 -- 10 ms early, or 0.20 s early
			if gap <= early then script.at = r.next; assert(Sim.push(race, seat, tick, "jump")) end
		end
		local plan = script.dash or "hold"
		if plan == "hold" then
			if tick == 1 then Sim.push(race, seat, tick, "dashDown") end
		elseif plan == "smart" then
			local down = r.dash
			if down and(r.bar <= 8 * Stats.DashTick or gap <= r.judge * 40) then Sim.push(race, seat, tick, "dashUp")
			elseif not down and r.bar >= 80 * Stats.DashTick and r.puff == 0 and r.tumble == 0 and gap > r.judge * 70 then Sim.push(race, seat, tick, "dashDown") end
		end
	end
	local function heat(plan, runners, scripts)
		local race = Sim.new({ plan = plan, runners = runners })
		repeat
			for seat, script in ipairs(scripts) do if not race.runners[seat].finishUs then drive(race, seat, script) end end
		until not Sim.step(race)
		return race
	end
	local function plain(mode, layout, count)
		local plan = { mode = mode, layout = layout or "even", count = count, lanes = {}, clovers = {}, cloverHurdle = 0, zoomies = {} }
		for i = 1, count do plan.lanes[i] = i end
		return plan
	end
	local function all(level) return { speed = level, energy = level, jump = level } end
	local function solo(level, script, layout)
		local race = heat(plain("stats", layout, 1), { all(level) }, { script })
		return race.runners[1].finishUs / 1e6, race.runners[1]
	end
	local function clean() return { jumps = { P, P, P, P, P, P, P, P, P } } end

	test("every level 1 to 99 is base x (1 + 0.25 x (level-1)/98), in whole numbers, and the 4.4 table holds", function()
		for level = 1, 99 do
			local f = 1 + .25 * (level - 1) / 98
			assert(near(Stats.speed(level), 6 * f) and near(Stats.energy(level), 3 * f), level)
			assert(near(Stats.jump(level), .12 * f) and near(Stats.clearWindow(level), .3 * f), level)
			for _, value in ipairs({ Stats.stride(level), Stats.bar(level), Stats.perfect(level), Stats.clear(level) }) do assert(value % 1 == 0, level) end
		end
		local function shown(v, places) return string.format("%." .. places .. "f", v) end
		for level, row in pairs({ [1] = { "6.00", "3.0", "0.120" }, [50] = { "6.75", "3.4", "0.135" }, [99] = { "7.50", "3.8", "0.150" } }) do
			assert(shown(Stats.speed(level), 2) == row[1] and shown(Stats.energy(level) + 1e-9, 1) == row[2] and shown(Stats.jump(level), 3) == row[3], level)
		end
		assert(near(Stats.energy(99), 3.75))
		for _, bad in ipairs({ 0 / 0, -5, 0, "x", {} }) do assert(Stats.level(bad) == 1) end
		assert(Stats.level(1e9) == 99 and Stats.level(50.9) == 50)
	end)
	test("the simulated pet runs at those speeds, dashes for that long and judges those windows at every level", function()
		for level = 1, 99 do
			local race = Sim.new({ plan = plain("stats", "even", 1), runners = { all(level) } })
			local r = race.runners[1]
			for _ = 1, 100 do Sim.step(race) end
			assert(near(r.pos / Stats.UnitsPerStud, Stats.speed(level)), level)
			Sim.push(race, 1, 101, "dashDown")
			local before, dashed = r.bar, 0
			-- no jump is due for a while at 16 studs; count the dash ticks on a runner with no hoops in front
			r.next = 99
			while Sim.step(race) do if r.bar < before then dashed += 1; before = r.bar else break end end
			assert(dashed == math.floor(Stats.energy(level) * 100 + 1e-9) and r.puffs == 1, level)
			-- windows, one unit inside and outside, early and late
			local step = r.stride * 100
			for _, pair in ipairs({ { Stats.perfect(level), P, C }, { Stats.clear(level), C, 0 } }) do
				for _, sign in ipairs({ 1, -1 }) do
					for inside = 0, 1 do
						local try = Sim.new({ plan = plain("stats", "even", 1), runners = { all(level) } })
						local q = try.runners[1]
						local gap = math.floor(step * pair[1] / 980000) + (if inside == 1 then 0 else 1)
						q.pos = Sim.takeoff(q, q.list[1]) - sign * gap
						Sim.push(try, 1, 1, "jump"); Sim.step(try)
						local want = if inside == 1 then pair[2] else pair[3]
						-- past the late Clear edge is past the hoop itself: a Trip
						assert((q.results[1] or 0) == want or (sign == -1 and q.results[1] == T and gap >= math.floor(step * Stats.clear(level) / 980000)), level)
					end
				end
			end
		end
	end)
	test("bands and pals' levels", function()
		local rows = { { 1, 1, 1, 1 }, { 27, 1, 1, 1 }, { 28, 1, 1, 2 }, { 72, 1, 1, 2 }, { 73, 1, 1, 3 }, { 99, 49, 1, 3 }, { 99, 50, 1, 4 }, { 99, 99, 26, 4 }, { 99, 99, 27, 5 }, { 99, 99, 99, 5 } }
		for i, row in ipairs(rows) do assert(Stats.band({ speed = row[1], energy = row[2], jump = row[3] }) == row[4], i) end
		for i = 1, 5 do
			local level = Stats.bandMiddle(i)
			assert(Stats.band({ speed = level, energy = level, jump = level }) == i, i)
		end
		assert(Stats.dashLevel(nil) == 3)
	end)
	test("1,000 seeded races: the same inputs give the same bits twice, and seeds differ", function()
		local modes, seen, different = { "fun", "stats", "trial" }, {}, 0
		local function fold(hash, v) return (hash * 31 + v) % 2147483647 end
		for n = 1, 1000 do
			local mode, count = modes[n % 3 + 1], if n % 3 == 2 then 1 else n % 8 + 1
			local function race()
				local runners = {}
				for seat = 1, count do runners[seat] = { speed = (n * 7 + seat * 13) % 99 + 1, energy = (n * 3 + seat) % 99 + 1, jump = (n + seat * 29) % 99 + 1, bot = seat > 1 } end
				local made = Sim.new({ seed = n * 7919, mode = mode, runners = runners })
				local script = { jumps = {}, stones = n % 2 == 0 }
				for j = 1, 9 do script.jumps[j] = (n * (j + 3) + j) % 3 + 1 end
				local hash = 7
				repeat
					if not made.runners[1].finishUs then drive(made, 1, script) end
					if made.tick % 50 == 0 then for _, r in ipairs(made.runners) do hash = fold(fold(hash, r.pos), r.bar) end end
				until not Sim.step(made)
				for _, r in ipairs(made.runners) do
					assert(r.finishUs and r.finishUs % 1 == 0 and r.pos % 1 == 0 and r.bar % 1 == 0 and r.pos < 2 ^ 40, n)
					hash = fold(hash, r.finishUs)
				end
				return hash, table.concat(Sim.placings(made), ",")
			end
			local a, ap = race(); local b, bp = race()
			assert(a == b and ap == bp, n)
			if mode ~= "trial" and not seen[a] then different += 1 end
			seen[a] = true
		end
		assert(different > 600, different) -- of 667; lone runners have no luck to differ by
	end)
	test("server and client agree: inputs recorded on one side, pushed late by 14 ticks on the other", function()
		for n = 1, 60 do
			local plan = Sim.plan(n, "stats", 1)
			local log = {}
			local race = Sim.new({ plan = plan, runners = { all(n) } })
			local script = { jumps = { P, C, T, P, C, P, P, P, P }, stones = n % 2 == 1 }
			repeat
				local before = race.runners[1].inputs
				drive(race, 1, script)
				local queue = race.runners[1].queue
				for k = #queue - (race.runners[1].inputs - before) + 1, #queue do table.insert(log, queue[k]) end
			until not Sim.step(race)
			local server = Sim.new({ plan = plan, runners = { all(n) } })
			local clock, at = 0, 1
			repeat
				clock += 1
				while log[at] and log[at].tick + Sim.LagTicks - 1 <= clock do assert(Sim.push(server, 1, log[at].tick, log[at].kind)); at += 1 end
			until clock > Sim.LagTicks and not Sim.step(server)
			assert(server.runners[1].finishUs == race.runners[1].finishUs, n)
		end
	end)
	test("input rules: late, early, out of order, unknown, flooded and unseated inputs change nothing", function()
		local race = Sim.new({ plan = plain("stats", "even", 2), runners = { all(1), { speed = 1, energy = 1, jump = 1, bot = true } } })
		for _ = 1, 20 do Sim.step(race) end
		for _, try in ipairs({ { 1, 20, "jump", "late" }, { 1, 122, "jump", "early" }, { 1, 30.5, "jump", "bad" }, { 1, 0 / 0, "jump", "bad" }, { 1, "30", "jump", "bad" },
			{ 1, 30, "win", "bad" }, { 3, 30, "jump", "closed" }, { 2, 30, "jump", "closed" } }) do
			local ok, why = Sim.push(race, try[1], try[2], try[3])
			assert(ok == false and why == try[4], try[4])
		end
		assert(Sim.push(race, 1, 60, "dashUp"))
		local ok, why = Sim.push(race, 1, 59, "dashDown"); assert(not ok and why == "order")
		local taken = 0
		for k = 1, 500 do if Sim.push(race, 1, 60 + k // 10, "dashUp") then taken += 1 end end
		assert(taken == 9, taken)
		assert(race.runners[1].inputs == 10 and #race.runners[1].queue == 10)
	end)
	test("mashing Jump never clears a hoop; a far press is a free hop; one press settles a hoop", function()
		local race = Sim.new({ plan = plain("stats", "even", 1), runners = { all(1) } })
		repeat if race.tick % 10 == 0 then Sim.push(race, 1, race.tick + 1, "jump") end until not Sim.step(race)
		assert(race.runners[1].trips == 6, race.runners[1].trips)
		local free = Sim.new({ plan = plain("stats", "even", 1), runners = { all(1) } })
		Sim.push(free, 1, 50, "jump")
		local script = clean()
		repeat drive(free, 1, script) until not Sim.step(free)
		assert(free.runners[1].perfects == 6)
	end)
	test("the stones: only inside the signpost; three Perfects beat the bridge; one miss is slower at every level", function()
		local gains, losses = { 1e9, 0 }, { 1e9, 0 }
		for level = 1, 99, 7 do
			local bridge, b = solo(level, clean())
			local ok, r = solo(level, { jumps = clean().jumps, stones = true })
			assert(r.stones and r.perfects == 9 and not b.stones and b.perfects == 6)
			gains = { math.min(gains[1], bridge - ok), math.max(gains[2], bridge - ok) }
			for miss = 4, 6 do
				local jumps = clean().jumps; jumps[miss] = T
				local wet, w = solo(level, { jumps = jumps, stones = true })
				assert(w.trips == 1 and wet > bridge, level)
				losses = { math.min(losses[1], wet - bridge), math.max(losses[2], wet - bridge) }
			end
		end
		assert(gains[1] > 1.5)
		local race = Sim.new({ plan = plain("stats", "even", 1), runners = { all(1) } })
		Sim.push(race, 1, 5, "stones"); for _ = 1, 10 do Sim.step(race) end
		assert(race.runners[1].wants == false)
		return string.format("clean saves %.2f to %.2f s, one miss costs %.2f to %.2f s", gains[1], gains[2], losses[1], losses[2])
	end)
	test("an unpressed or mistimed hoop trips at the hoop, at every pace", function()
		for level = 1, 99, 14 do
			for _, dash in ipairs({ "hold", "none" }) do
				local race = Sim.new({ plan = plain("stats", "pairs", 1), runners = { all(level) } })
				local script, at = { jumps = { T, T, T, T, T, T }, dash = dash }, 1
				repeat
					drive(race, 1, script)
					if race.tick == 100 then Sim.push(race, 1, 101, "jump") end
					local r = race.runners[1]
					local going = Sim.step(race)
					if r.trips >= at then
						assert(r.pos - r.list[at].at >= 0 and r.pos - r.list[at].at < r.step, level); at += 1
					end
				until not going
				assert(at == 7)
			end
		end
	end)
	test("dash is a choice: spending it well beats holding it, which beats leaving it; empty means puffed out", function()
		local least, most, held = 1e9, 0, 1e9
		for level = 1, 99, 7 do
			for _, layout in ipairs(Course.LayoutOrder) do
				for _, jumps in ipairs({ { P, P, P, P, P, P }, { C, P, C, P, C, P }, { C, T, C, T, C, C } }) do
					local smart, sr = solo(level, { jumps = jumps, dash = "smart" }, layout)
					local hold, hr = solo(level, { jumps = jumps }, layout)
					local none = solo(level, { jumps = jumps, dash = "none" }, layout)
					assert(sr.puffs == 0 and hr.puffs > 5 and smart < hold and hold < none, string.format("%d %s %.2f %.2f %.2f", level, layout, smart, hold, none))
					least, most, held = math.min(least, hold - smart), math.max(most, hold - smart), math.min(held, none - hold)
				end
			end
		end
		local race = Sim.new({ plan = plain("stats", "even", 1), runners = { all(1) } })
		local r = race.runners[1]; r.next = 99; r.bar = Stats.DashTick * 2; r.dash = true
		Sim.step(race); Sim.step(race); assert(r.puff == Sim.PuffTicks)
		local from = r.pos
		for _ = 1, 100 do Sim.step(race) end
		assert(near((r.pos - from) / Stats.UnitsPerStud, Stats.speed(1) * .9) and r.bar == Sim.RefillTick * 100 and r.puff == 0)
		-- sprinting into a hoop: the window is judged at the pace without the dash
		local base = r.stride * 100
		r.bar = r.cap; Sim.step(race); assert(r.step == r.stride * 130 and r.judge == base)
		return string.format("spent well saves %.2f to %.2f s over holding; holding saves at least %.2f s over none", least, most, held)
	end)
	test("a band's pets: lopsided is never over 8% from balanced; balanced pets keep their numbers; never less for more", function()
		local widest, name = 0, ""
		for index, band in ipairs(Stats.Bands) do
			local fast, slow = {}, {}
			-- every corner of the band: each stat at a limit or sharing what is left
			local seen = {}
			for _, total in ipairs({ band.from, band.to }) do
				for speed = 1, 99, 7 do for energy = 1, 99, 14 do
					local jump = total - speed - energy
					if jump >= 1 and jump <= 99 then table.insert(seen, { speed = speed, energy = energy, jump = jump }) end
				end end
				for _, s in ipairs({ 1, 99 }) do
					local rest = (total - s) // 2
					if rest >= 1 and rest <= 99 then table.insert(seen, { speed = s, energy = rest, jump = total - s - rest }) end
				end
				local even = total // 3
				local balanced = { speed = even, energy = even, jump = total - 2 * even }
				local same = Stats.effective(balanced)
				for _, id in ipairs(Stats.Order) do assert(same[id] == balanced[id], total) end
				table.insert(seen, balanced)
			end
			for _, levels in ipairs(seen) do
				assert(Stats.band(levels) == index)
				for _, dash in ipairs({ "smart", "none" }) do
					local race = heat(plain("stats", "even", 1), { levels }, { { jumps = { P, P, P, P, P, P }, dash = dash } })
					local t = race.runners[1].finishUs / 1e6
					fast[dash] = math.min(fast[dash] or 1e9, t); slow[dash] = math.max(slow[dash] or 0, t)
				end
			end
			for _, dash in ipairs({ "smart", "none" }) do
				local gap = slow[dash] / fast[dash] - 1
				if gap > widest then widest, name = gap, band.id end
			end
		end
		assert(widest <= .08, name .. " " .. widest)
		for other = 1, 99, 9 do
			local last
			for level = 1, 99 do
				for _, id in ipairs(Stats.Order) do
					local levels = { speed = other, energy = other, jump = other }
					levels[id] = level
					local up = table.clone(levels); up[id] = math.min(99, level + 1)
					local a, b2 = Stats.effective(levels), Stats.effective(up)
					for _, each in ipairs(Stats.Order) do assert(b2[each] >= a[each], level) end
				end
			end
		end
		return string.format("widest %.1f%% (%s)", widest * 100, name)
	end)
	local MODELS = {
		bronze = { jumps = { C, T, C, T, C, C }, dash = "hold" },
		silver = { jumps = { P, C, P, C, P, C }, dash = "hold" },
		gold = { jumps = { P, P, C, P, P, P }, dash = "smart" },
	}
	local function slowest(level, model)
		local worst, best = 0, 1e9
		for _, layout in ipairs(Course.LayoutOrder) do
			local t = solo(level, { jumps = model.jumps, dash = model.dash }, layout)
			worst, best = math.max(worst, t), math.min(best, t)
		end
		return worst, best
	end
	test("pars: re-derived from the model runs; doing nothing, only Dash or mashing Jump earns no medal anywhere", function()
		local idle, only = { jumps = { T, T, T, T, T, T }, dash = "none" }, { jumps = { T, T, T, T, T, T }, dash = "hold" }
		local rows, wrong = {}, false
		local function row(id, level, top, mode, band)
			local text = id
			for _, medal in ipairs({ "bronze", "silver", "gold" }) do
				local want = math.ceil((slowest(level, MODELS[medal]) + .3) * 2) * 500
				text ..= string.format(" %s=%d", medal, want)
				local pars = Stats.Pars[id]
				if not pars or pars[medal] ~= want then wrong = true end
			end
			for _, model in ipairs({ idle, only }) do
				local _, best = slowest(top, model)
				text ..= string.format(" (%.1f)", best) -- idle, then Dash held
				if not wrong then assert(Stats.medal(mode, band, best * 1e6) == nil, id) end
			end
			table.insert(rows, text)
		end
		row("trial", 50, 50, "trial", nil)
		for index, band in ipairs(Stats.Bands) do
			row(band.id, math.max(1, band.from // 3), math.min(99, Stats.bandMiddle(index) + Stats.BandReach), "stats", index)
		end
		assert(not wrong, table.concat(rows, "\n"))
		local mash = Sim.new({ plan = plain("trial", "even", 1), runners = { all(50) } })
		repeat if mash.tick % 10 == 0 then Sim.push(mash, 1, mash.tick + 1, "jump") end until not Sim.step(mash)
		assert(Stats.medal("trial", nil, mash.runners[1].finishUs) == nil)
		for id, pars in pairs(Stats.Pars) do assert(pars.gold + 1000 <= pars.silver and pars.silver + 1000 <= pars.bronze, id) end
		assert(Stats.medal("trial", nil, nil) == nil and Stats.medal("trial", nil, Stats.Pars.trial.gold * 1000) == "gold")
		return table.concat(rows, "; ")
	end)
	test("pace: clean runs, an idle run, and an all-99 pet about 20% sooner than an all-1 pet", function()
		local one, fifty, ninety = solo(1, clean()), solo(50, clean()), solo(99, clean())
		local idle = solo(50, { jumps = { T, T, T, T, T, T }, dash = "none" })
		local typical = solo(50, { jumps = { P, C, T, P, C, T } })
		assert(ninety / one > .76 and ninety / one < .82, ninety / one)
		assert(one > 30 and one < 36 and ninety > 24 and ninety < 29)
		return string.format("clean %.1f / %.1f / %.1f s at 1 / 50 / 99; two Trips %.1f s; idle %.1f s at 50", one, fifty, ninety, typical, idle)
	end)
	test("modes: Just for Fun ignores levels; Time Trial has no luck and the Even layout; plans keep their secrets", function()
		local race = Sim.new({ seed = 5, mode = "fun", runners = { all(1), all(99) } })
		assert(race.runners[1].stride == Stats.stride(50) and race.runners[1].cap == race.runners[2].cap and race.runners[1].perfect == race.runners[2].perfect)
		local layouts, hurdles = {}, {}
		for seed = 1, 400 do
			local trial = Sim.plan(seed, "trial", 1)
			assert(trial.layout == "even" and #trial.clovers == 0 and #trial.zoomies == 0 and trial.cloverHurdle == 0)
			for count = 2, 8 do
				local stats, fun = Sim.plan(seed, "stats", count), Sim.plan(seed, "fun", count)
				layouts[stats.layout] = (layouts[stats.layout] or 0) + 1; hurdles[stats.cloverHurdle] = (hurdles[stats.cloverHurdle] or 0) + 1
				assert(#stats.clovers == (if count < 4 then 1 else 2) and #fun.clovers == math.max(1, count // 2) and #stats.zoomies == 1 and #fun.zoomies == 2)
				for _, plan in ipairs({ stats, fun }) do
					for _, z in ipairs(plan.zoomies) do assert(z >= 400 and z <= 700) end
					local lanes = table.clone(plan.lanes); table.sort(lanes)
					for i, lane in ipairs(lanes) do assert(lane == i) end
					local open = Sim.publicPlan(plan)
					assert(open.seed == nil and #open.zoomies == 0 and #open.lanes == count)
				end
			end
		end
		for _, id in ipairs(Course.LayoutOrder) do assert(layouts[id] > 560 and layouts[id] < 840, id) end
		for i = 1, 6 do assert(hurdles[i] > 350 and hurdles[i] < 590, i) end
		for _, seed in ipairs({ 0, -3, 1e300, 0 / 0, math.huge }) do Sim.plan(seed, "fun", 8) end
	end)
	test("clover: only past a hoop that was not tripped, 1.0 s of bar at most; zoomies: a 6-stud gap, once a pet", function()
		for _, want in ipairs({ P, C, T }) do
			local plan = plain("stats", "even", 1); plan.clovers = { 1 }; plan.cloverHurdle = 2
			local race = heat(plan, { all(50) }, { { jumps = { P, want, P, P, P, P } } })
			assert((race.runners[1].cloverTick > 0) == (want ~= T))
		end
		for _, mode in ipairs({ "stats", "fun" }) do
			local plan = plain(mode, "even", 2); plan.zoomies = { 500, 600 }
			local race = heat(plan, { all(50), all(50) }, { clean(), { jumps = { T, T, T, T, T, T } } })
			local plan2 = plain(mode, "even", 2)
			local dry = heat(plan2, { all(50), all(50) }, { clean(), { jumps = { T, T, T, T, T, T } } })
			local gain = (dry.runners[2].finishUs - race.runners[2].finishUs) / 1e6
			assert(race.runners[2].zoomTick > 0 and race.runners[1].zoomTick == 0 and gain > .2 and gain <= (if mode == "fun" then .61 else .41), gain)
			local close = heat(plan, { all(50), all(50) }, { clean(), { jumps = { C, C, P, P, P, P } } })
			assert(close.runners[2].zoomTick == 0 and close.runners[1].zoomTick == 0)
		end
	end)
	test("luck budget: at every level and mode, zoomies plus clover is under one Trip, and zoomies under its own gap", function()
		for level = 1, 99 do
			for mode, ticks in pairs({ stats = Sim.ZoomTicks.stats, fun = Sim.ZoomTicks.fun }) do
				local stride = Stats.stride(if mode == "fun" then 50 else level)
				local zoom, clover, trip = stride * Sim.ZoomPct * ticks, stride * Sim.DashPct * 100, stride * 100 * Sim.TripTicks
				assert(zoom < Sim.ZoomGap, level)
				local puff = stride * Sim.PuffPct * Sim.PuffTicks -- one more puff dodged, at most
				assert(zoom + clover + puff < trip, level)
			end
		end
	end)
	test("a run one Trip cleaner always wins: best luck for the worse run, worst luck for the better one", function()
		-- Clearly better: the same stats, buttons and jumps, except one hoop the worse run tripped on.
		local raced, closest = 0, 1e9
		local bases = { { P, P, P, P, P, P }, { C, C, C, C, C, C }, { T, T, T, T, T, T }, { P, T, C, P, T, C }, { T, P, P, T, C, P }, { C, P, T, C, P, P } }
		for _, mode in ipairs({ "stats", "fun" }) do
			for _, level in ipairs(if mode == "fun" then { 50 } else { 1, 50, 99 }) do
				for _, layout in ipairs(Course.LayoutOrder) do
					for index, base in ipairs(bases) do
						for hoop = 1, 6 do
							for _, better in ipairs({ P, C }) do
								local good, bad = table.clone(base), table.clone(base)
								good[hoop], bad[hoop] = better, T
								for clover = 1, 6 do for _, dash in ipairs({ "hold", "smart", "none" }) do
									local plan = plain(mode, layout, 2)
									plan.clovers = { 2 }; plan.cloverHurdle = clover
									local moment = 400 + (clover * 97 + hoop * 53 + index * 31) % 301
									plan.zoomies = if mode == "fun" then { moment, math.min(700, moment + 90) } else { moment }
									local race = heat(plan, { all(level), all(level) }, { { jumps = good, dash = dash }, { jumps = bad, dash = dash } })
									local margin = (race.runners[2].finishUs - race.runners[1].finishUs) / 1e6
									assert(margin > 0, string.format("%s %d %s base %d hoop %d clover %d %s: %.3f", mode, level, layout, index, hoop, clover, dash, margin))
									closest = math.min(closest, margin); raced += 1
								end end
							end
						end
					end
				end
			end
		end
		return string.format("%d heats, closest %.2f s", raced, closest)
	end)
	test("four evenly banded runners: how often the best-played run wins", function()
		local played, won, nothing, zooms, tripWins, tripHeats = 0, 0, 0, 0, 0, 0
		for n = 1, HEATS do
			local runners = {}
			for seat = 1, 4 do local level = Stats.bandMiddle(n % 5 + 1); runners[seat] = { speed = level, energy = level, jump = level, bot = true } end
			local race = Sim.new({ seed = n * 104729 + 17, mode = "stats", runners = runners })
			local order = Sim.run(race)
			local best, tie
			for _, r in ipairs(race.runners) do
				if r.zoomTick > 0 then zooms += 1 end
				if not best or r.trips < best.trips or (r.trips == best.trips and r.perfects > best.perfects) then best, tie = r, false
				elseif r.trips == best.trips and r.perfects == best.perfects then tie = true end
			end
			if tie then nothing += 1 else played += 1; if order[1] == best.seat then won += 1 end end
			local fewest, sole = 1e9, false
			for _, r in ipairs(race.runners) do if r.trips < fewest then fewest, sole = r.trips, true elseif r.trips == fewest then sole = false end end
			if sole then tripHeats += 1; if race.runners[order[1]].trips == fewest then tripWins += 1 end end
		end
		local share = won / played
		if HEATS >= 2000 then assert(share >= .7 and share <= .8, share) end
		return string.format("%.1f%% of %d (%d ties); fewest Trips alone %.1f%%; zoomies in %.0f%% of heats", share * 100, played, nothing, tripWins / tripHeats * 100, zooms / HEATS * 100)
	end)
	test("a leaver becomes a pal on the spot; the heat ends 20 s after the winner; every pet is placed", function()
		local race = Sim.new({ seed = 3, mode = "fun", runners = { all(1), all(1), { bot = true } } })
		for _ = 1, 800 do Sim.step(race) end
		local spot = race.runners[2].pos
		Sim.toBot(race, 2, 800); assert(race.runners[2].bot and race.runners[2].pos == spot)
		local order = Sim.run(race)
		assert(#order == 3 and race.over and race.runners[2].finishUs and race.runners[1].trips == 6)
		local slow = Sim.new({ plan = plain("stats", "even", 2), runners = { all(99), all(1) } })
		slow.runners[2].stride = 100
		Sim.run(slow)
		assert(slow.tick == slow.winnerTick + Sim.TailTicks and not slow.runners[2].finishUs and Sim.placings(slow)[2] == 2)
	end)
	test("drawing: spot() and the course meet with no jump on either way", function()
		for _, stones in ipairs({ true, false }) do
			local race = Sim.new({ plan = plain("stats", "even", 1), runners = { all(99) } })
			local script = { jumps = clean().jumps, stones = stones }
			local px, pz
			repeat
				drive(race, 1, script)
				local x, _, z = Course.at(Sim.spot(race.runners[1]))
				if px then assert((x - px) ^ 2 + (z - pz) ^ 2 < .2 ^ 2, race.tick) end
				px, pz = x, z
			until not Sim.step(race)
			assert(race.runners[1].stones == stones)
		end
	end)
	test("cost: eight runners a tick", function()
		local start, ticks = os.clock(), 0
		for n = 1, 10 do
			local runners = {}
			for seat = 1, 8 do runners[seat] = { speed = 50, energy = 50, jump = 50, bot = true } end
			local race = Sim.new({ seed = n, mode = "fun", runners = runners })
			while Sim.step(race) do ticks += 1 end
		end
		local us = (os.clock() - start) / ticks * 1e6
		assert(us < 200, us)
		return string.format("%.1f us, %.2f ms for each second of race", us, us / 10)
	end)
	return { passed = #cases, cases = cases }
end
