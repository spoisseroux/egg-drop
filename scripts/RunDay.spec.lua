-- require(ServerScriptService.Server.ZZSpecs.RunDay)(ServerScriptService.Server)
return function(server)
	local RunDay = require(server.RunDay)
	local passed = {}
	local function test(name, fn) fn(); table.insert(passed, name) end
	test("a board reset before 05:00 UTC but first dropped after counts toward the drop day", function()
		-- Reset on day 100 leaves no stamp; the first drop lands on day 101.
		local runDay = nil
		runDay = RunDay.onDrop(runDay, 1, "101")
		assert(runDay == "101")
		assert(RunDay.forSummary(runDay, "101") == "101")
	end)
	test("later drops and settlement across the rollover keep the first-drop day", function()
		local runDay = RunDay.onDrop(nil, 1, "100")
		for drops = 2, 24 do runDay = RunDay.onDrop(runDay, drops, "101") end
		assert(runDay == "100")
		assert(RunDay.forSummary(runDay, "102") == "100")
	end)
	test("a fresh board's next run re-stamps at its own first drop", function()
		local runDay = RunDay.onDrop(nil, 1, "100")
		runDay = nil -- reset clears the stamp
		assert(RunDay.onDrop(runDay, 1, "103") == "103")
	end)
	test("a missing stamp is repaired, and an unstamped settlement uses today", function()
		assert(RunDay.onDrop(nil, 5, "104") == "104")
		assert(RunDay.forSummary(nil, "105") == "105")
	end)
	return { passed = #passed, cases = passed }
end
