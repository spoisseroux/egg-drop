-- require(ServerScriptService.Server.ZZSpecs.HeatRequest)(ServerScriptService.Server)
return function(server)
	local Heat = require(server.HeatRequest)
	local passed = {}
	local function test(name, fn) fn(); table.insert(passed, name) end
	local function state(over)
		local s = { mode = "Board", ready = true, payoutPending = false, over = false, drops = 0, field = true, guided = false, runHeat = "medium" }
		for k, v in pairs(over or {}) do s[k] = v end
		return s
	end
	test("a fresh field with no drops rebuilds at the new heat", function()
		assert(Heat.decide(state(), "hard") == "Rebuild")
		assert(Heat.decide(state(), "medium") == "Store")
	end)
	test("locked at the first drop", function()
		for drops = 1, 24 do assert(Heat.decide(state({ drops = drops }), "hard") == "Locked") end
	end)
	test("ignored while a payout is pending, even after the round ends", function()
		assert(Heat.decide(state({ payoutPending = true }), "hard") == "PayoutPending")
		assert(Heat.decide(state({ payoutPending = true, over = true, drops = 24 }), "hard") == "PayoutPending")
	end)
	test("after the round ends the choice is stored for the next reset", function()
		assert(Heat.decide(state({ over = true, drops = 24 }), "hard") == "Store")
		assert(Heat.decide(state({ over = true, drops = 7 }), "easy") == "Store")
	end)
	test("unknown heats, garden mode and loading saves are refused", function()
		for _, bad in ipairs({ "insane", "", 3, nil, {} }) do assert(Heat.decide(state(), bad) == "Invalid") end
		assert(Heat.decide(state({ mode = "Room" }), "hard") == "Unavailable")
		assert(Heat.decide(state({ ready = false }), "hard") == "Unavailable")
	end)
	test("a guided first session forces Easy", function()
		assert(Heat.guided(0, 0) and Heat.guided(0, 2) and not Heat.guided(0, 3) and not Heat.guided(1, 0))
		assert(Heat.runHeat(true, "hard") == "easy" and Heat.runHeat(false, "hard") == "hard")
		assert(Heat.runHeat(false, "nope") == "medium" and Heat.runHeat(false, nil) == "medium")
		assert(Heat.decide(state({ guided = true, runHeat = "easy" }), "hard") == "Guided")
		-- After a guided round ends the player may pick; the next reset decides.
		assert(Heat.decide(state({ guided = true, over = true, drops = 24 }), "hard") == "Store")
	end)
	return { passed = #passed, cases = passed }
end
