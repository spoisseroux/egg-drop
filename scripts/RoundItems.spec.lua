-- Studio Server. Round items (BUILD-PLAN 2026-11-13 items 3, 5, 6, 7): star slots,
-- merge grants, the belt, and every `item` request rule, on the production
-- BoardSimulation and BoardItems modules with plain board doubles.
-- Usage: require(ServerScriptService.Server.ZZSpecs.RoundItems)(ServerScriptService.Server)
return function(server)
	local Simulation = require(server.BoardSimulation)
	local BoardItems = require(server.BoardItems)
	local Items = require(game.ReplicatedStorage.Shared.RoundItems)
	local Config = require(game.ReplicatedStorage.Shared.BoardConfig)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function keys(map) local list = {}; for key in pairs(map) do table.insert(list, key) end; table.sort(list); return list end
	local function egg(board, tier, x, y, extra)
		board.serial += 1
		local e = { id = board.serial, position = Vector2.new(x, y), velocity = Vector2.zero, tier = tier, radius = Config.Tiers[tier].radius }
		for key, value in pairs(extra or {}) do e[key] = value end
		table.insert(board.eggs, e)
		return e
	end
	local function fixture(heat)
		local sim = Simulation.new("Springy", 0, { seed = 40001, starter = {}, contactGate = true, powerUps = heat or "medium" })
		local board = { mode = "Board", sim = sim, round = { over = false, score = 0 }, field = { phase = "Playing", budget = 24 }, payoutPending = false }
		BoardItems.reset(board, true)
		return board
	end
	local ctx = { resetId = 9, ready = true, budget = 24 }
	local function ask(board, id, extra)
		local packet = { resetId = 9, seq = board.itemSeq, id = id }
		for key, value in pairs(extra or {}) do packet[key] = value end
		return BoardItems.request(board, packet, ctx)
	end

	test("star slots are deterministic per seed, inside earliest..20, and per-heat counts", function()
		for seed = 1, 300 do
			for heat, spec in pairs(Items.Heat) do
				local a, b = Items.plan(seed, heat, 24), Items.plan(seed, heat, 24)
				local slots = keys(a)
				assert(#slots == spec.count, heat .. " count " .. #slots)
				assert(table.concat(slots, ",") == table.concat(keys(b), ","), "same seed, same slots")
				for _, slot in ipairs(slots) do
					assert(slot >= spec.earliest and slot <= Items.Latest, "slot range " .. slot)
					assert(a[slot] == b[slot] and Items.valid(a[slot]), "same item")
				end
			end
		end
		local differs = false
		for seed = 2, 40 do
			if table.concat(keys(Items.plan(seed, "medium")), ",") ~= table.concat(keys(Items.plan(1, "medium")), ",") then differs = true; break end
		end
		assert(differs, "slots vary with the seed")
		assert(next(Items.plan(1, "nope")) == nil and next(Items.plan(0 / 0, "easy")) == nil, "bad input plans nothing")
	end)

	test("the ball queue is identical with and without power-ups (separate stream); Welcome has none", function()
		for seed = 40001, 40040 do
			local plain = Simulation.new("Springy", 0, { seed = seed, starter = {} })
			local starred = Simulation.new("Springy", 0, { seed = seed, starter = {}, powerUps = "easy" })
			assert(table.concat(plain.queue, ",") == table.concat(starred.queue, ","), "queue changed by items")
			assert(plain.stars == nil and starred.stars ~= nil)
		end
		local welcome = Simulation.new("Springy", 0, nil)
		assert(welcome.stars == nil and not Simulation.powerUpAt(welcome, 0))
	end)

	test("Next / Then flags follow the plan and a dropped star ball carries its item", function()
		local board = fixture("medium")
		local sim = board.sim
		local slot = keys(sim.stars)[1]
		local item = sim.stars[slot]
		sim.drops = slot - 2
		assert(not Simulation.powerUpAt(sim, 0) or sim.stars[slot - 1] ~= nil)
		assert(Simulation.powerUpAt(sim, 1), "Then is the star")
		sim.drops = slot - 1
		assert(Simulation.powerUpAt(sim, 0), "Next is the star")
		assert(Simulation.drop(sim, .5))
		local dropped = sim.eggs[#sim.eggs]
		assert(dropped.powerUp == item and sim.stars[slot] == nil, "drop moves the star onto the ball")
	end)

	test("merge keeps the star from either input and the result is a plain ball", function()
		for _, order in ipairs({ { "pop", nil }, { nil, "swap" }, { "bomb", "magnet" } }) do
			local sim = Simulation.new("Springy", 0, { starter = {} })
			egg(sim, 1, -.3, .72, { powerUp = order[1] })
			egg(sim, 1, .3, .72, { powerUp = order[2] })
			local merged = {}
			Simulation.step(sim, Config.FixedStep, merged)
			assert(#merged == 1, "merged")
			local m = merged[1]
			assert(m.powerUp == (order[1] or order[2]), "powerUp from either input")
			assert(#m.powerUps == (if order[1] and order[2] then 2 else 1), "both stars grant")
			for _, e in ipairs(sim.eggs) do assert(e.powerUp == nil, "result has no star") end
		end
	end)

	test("belt holds 3; a fourth item is lost ('full'); items off grants nothing", function()
		local board = fixture()
		for _, id in ipairs({ "swap", "pop", "bomb" }) do assert(BoardItems.grant(board, id) == "granted") end
		assert(BoardItems.grant(board, "magnet") == "full" and #board.belt == 3 and board.belt[3] == "bomb")
		assert(BoardItems.grant(board, "nope") == nil)
		local off = fixture(); off.itemsOn = false
		assert(BoardItems.grant(off, "pop") == nil and #off.belt == 0)
	end)

	test("reset clears belt, sequence and armed item; attributes publish the cleared state", function()
		local board = fixture()
		BoardItems.grant(board, "bomb"); BoardItems.grant(board, "pop")
		assert(ask(board, "bomb"))
		assert(board.sim.armed == "bomb" and board.itemSeq == 1)
		BoardItems.reset(board, true)
		assert(#board.belt == 0 and board.itemSeq == 0 and board.sim.armed == nil)
		local folder = Instance.new("Folder")
		BoardItems.publish(board, folder)
		assert(folder:GetAttribute("ItemBelt") == "" and folder:GetAttribute("ItemSeq") == 0 and folder:GetAttribute("ItemArmed") == "")
		assert(folder:GetAttribute("ItemsOn") == true and type(folder:GetAttribute("NextPowerUp")) == "boolean")
		BoardItems.grant(board, "swap"); BoardItems.grant(board, "pop")
		BoardItems.publish(board, folder)
		assert(folder:GetAttribute("ItemBelt") == "swap,pop")
		assert(table.concat(Items.decodeBelt("swap,pop,junk,bomb,magnet"), ",") == "swap,pop,bomb", "decode drops junk, keeps 3")
		folder:Destroy()
	end)

	test("enabled only in won-before fields that are not guided (off in Welcome, field 0, guided)", function()
		assert(BoardItems.enabled({ field = true, guided = false, totalWins = 1 }))
		assert(not BoardItems.enabled({ field = false, guided = false, totalWins = 4 }), "Welcome")
		assert(not BoardItems.enabled({ field = true, guided = true, totalWins = 0 }), "guided")
		assert(not BoardItems.enabled({ field = true, guided = false, totalWins = 0 }), "first field")
	end)

	test("requests: stale ResetId, wrong sequence, malformed, not on belt, armed, off are refused", function()
		local board = fixture()
		BoardItems.grant(board, "bomb"); BoardItems.grant(board, "pop")
		local function refused(reason, packet)
			local ok, why = BoardItems.request(board, packet, ctx)
			assert(not ok and why == reason, tostring(why) .. " ~= " .. reason)
		end
		refused("Malformed", "bomb")
		refused("Stale", { resetId = 8, seq = 0, id = "bomb" })
		refused("Stale", { resetId = "9", seq = 0, id = "bomb" })
		refused("Stale", { resetId = 9, seq = 1, id = "bomb" })
		refused("Stale", { resetId = 9, seq = .5, id = "bomb" })
		refused("Malformed", { resetId = 9, seq = 0, id = "laser" })
		refused("NotOnBelt", { resetId = 9, seq = 0, id = "swap" })
		assert(ask(board, "bomb"))
		refused("Stale", { resetId = 9, seq = 0, id = "pop" })
		refused("Armed", { resetId = 9, seq = 1, id = "pop" })
		assert(#board.belt == 1 and board.belt[1] == "pop", "refusals never debit")
		board.itemsOn = false
		refused("Off", { resetId = 9, seq = 1, id = "pop" })
	end)

	test("requests: only a live round (not over, no payout pending, field not complete, mode Board, ready)", function()
		for _, spoil in ipairs({
			function(b) b.round.over = true end, function(b) b.payoutPending = true end,
			function(b) b.field.phase = "Complete" end, function(b) b.field = nil end,
			function(b) b.mode = "Room" end, function(b) b.closing = true end,
		}) do
			local board = fixture(); BoardItems.grant(board, "swap"); spoil(board)
			assert(not ask(board, "swap") and #board.belt == 1)
		end
		local board = fixture(); BoardItems.grant(board, "swap")
		assert(not BoardItems.request(board, { resetId = 9, seq = 0, id = "swap" }, { resetId = 9, ready = false, budget = 24 }))
	end)

	test("requests are accepted while paused (the carousel freezes the round)", function()
		local board = fixture(); board.menuPaused = true
		BoardItems.grant(board, "swap")
		assert(ask(board, "swap") and board.itemSeq == 1 and #board.belt == 0)
	end)

	test("Swap trades Next and Then with their star marks; refused past the 24-drop budget", function()
		local board = fixture()
		local sim = board.sim
		sim.queue[1], sim.queue[2] = 1, 2
		sim.stars = { [2] = "pop" }
		BoardItems.grant(board, "swap"); BoardItems.grant(board, "swap")
		assert(ask(board, "swap"))
		assert(sim.queue[1] == 2 and sim.queue[2] == 1 and sim.stars[1] == "pop" and sim.stars[2] == nil, "marks swap with tiers")
		assert(Simulation.powerUpAt(sim, 0) and not Simulation.powerUpAt(sim, 1))
		sim.drops = 23
		local ok, why = ask(board, "swap")
		assert(not ok and why == "Budget" and #board.belt == 1, "the last drop has no Then")
		sim.drops = 22
		assert(ask(board, "swap"), "drops 23 and 24 are both inside the budget")
	end)

	test("Pop removes the highest resting ball outside merged: no score, no merge record; a popped star is lost", function()
		local board = fixture()
		local sim = board.sim
		local low = egg(sim, 3, -2, 1.43, { hasContact = true })
		local high = egg(sim, 1, 2, 6, { hasContact = true, powerUp = "bomb" })
		egg(sim, 2, 0, 9, {}) -- still falling: never the target
		BoardItems.grant(board, "pop")
		local ok, result = ask(board, "pop")
		assert(ok and result.eggId == high.id and result.lostStar == "bomb")
		for _, e in ipairs(sim.eggs) do assert(e ~= high) end
		assert(table.find(sim.eggs, low) and board.round.score == 0)
		local empty = fixture(); BoardItems.grant(empty, "pop")
		local refused, why = ask(empty, "pop")
		assert(not refused and why == "Empty" and #empty.belt == 1, "empty tray refuses and keeps the item")
	end)

	test("Bomb arms the next ball, bursts on first contact, never merges, removes at most 4 others", function()
		local board = fixture()
		local sim = board.sim
		BoardItems.grant(board, "bomb")
		assert(ask(board, "bomb") and sim.armed == "bomb")
		assert(Simulation.drop(sim, .5))
		local bomb = sim.eggs[#sim.eggs]
		assert(bomb.mark == "bomb" and sim.armed == nil, "armed item rides the next ball")
		-- Ring of tier-1 balls that do not touch each other, the bomb landing among them.
		table.clear(sim.eggs)
		-- Five candidates inside .72 + 2.2 of the bomb (two beside it, two above those, one
		-- over it); two more high up are out of reach. Nothing sits on the 2.2 banks: a ball
		-- there is pushed up the slope on the first step and merges with its neighbour.
		for _, x in ipairs({ -1.5, 1.5 }) do egg(sim, 1, x, .72, { hasContact = true }) end
		egg(sim, 1, -3, 4.5, { hasContact = true }); egg(sim, 1, 3, 4.5, { hasContact = true })
		egg(sim, 1, -1.5, 2.2, { hasContact = true }); egg(sim, 1, 1.5, 2.2, { hasContact = true })
		egg(sim, 1, 0, 3, { hasContact = true })
		bomb.tier, bomb.radius = 1, Config.Tiers[1].radius
		bomb.position, bomb.velocity = Vector2.new(0, .72), Vector2.zero
		table.insert(sim.eggs, bomb)
		local before = #sim.eggs
		local merged = {}
		Simulation.step(sim, Config.FixedStep, merged)
		local function describe()
			local parts = {}
			for _, m in ipairs(merged) do table.insert(parts, string.format("merge tier %d at (%.2f,%.2f) id %s", m.tier, m.position.X, m.position.Y, tostring(m.id))) end
			for _, b in ipairs(sim.bursts or {}) do table.insert(parts, "burst ids " .. table.concat(b.ids, ",")) end
			return table.concat(parts, "; ")
		end
		assert(#merged == 0, "a bomb never merges, removals never reach merged: " .. describe())
		assert(sim.bursts and #sim.bursts == 1 and #sim.bursts[1].ids <= 1 + Items.Bomb.max, "capped")
		assert(#sim.eggs == before - #sim.bursts[1].ids and not table.find(sim.eggs, bomb))
		assert(#sim.bursts[1].ids == 5, "bomb + 4 nearest: " .. describe())
	end)

	test("Magnet arms the next ball and pulls same-size balls in for 2 s after it lands", function()
		local board = fixture()
		BoardItems.grant(board, "magnet")
		assert(ask(board, "magnet") and board.sim.armed == "magnet")
		local sim = Simulation.new("Springy", 0, { starter = {} })
		local magnet = egg(sim, 2, 0, 1.04, { mark = "magnet", magnetLeft = Items.Magnet.seconds, hasContact = true })
		local pulled = egg(sim, 2, 2.5, 1.04, { hasContact = true })
		local other = egg(sim, 1, -2.2, .72, { hasContact = true })
		Simulation.step(sim, Config.FixedStep, {})
		assert(pulled.velocity.X < 0, "same size pulled toward the magnet")
		assert(math.abs(other.velocity.X) < 1e-3, "other sizes untouched")
		assert(magnet.magnetLeft < Items.Magnet.seconds)
	end)

	test("Bomb / Magnet refused when no ball is left to carry them (budget or settling)", function()
		local board = fixture(); BoardItems.grant(board, "bomb")
		board.sim.drops = 24
		assert(not ask(board, "bomb"))
		board.sim.drops = 10; board.field.phase = "Settling"
		local ok, why = ask(board, "bomb")
		assert(not ok and why == "Budget" and #board.belt == 1)
	end)

	return { passed = #cases, cases = cases, evidence = "production BoardSimulation + BoardItems with board doubles" }
end
