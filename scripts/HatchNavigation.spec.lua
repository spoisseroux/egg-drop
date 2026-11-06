-- Deterministic race fixtures for the production post-ack coordinator.
return function(client)
	local Navigation = require(client.HatchNavigation)
	local cases = {}
	local function test(name, body) body(); table.insert(cases, name) end
	local function fixture(overrides)
		local f = { time = 0, values = { Mode = "Room", CompanionId = "pip", RoundOver = false },
			requests = {}, presented = {}, failed = 0, blocked = false, ready = true }
		local dependencies = {
			get = function(name) return f.values[name] end,
			send = function(action, value)
				table.insert(f.requests, { action, value })
				if f.onSend then f.onSend(action, value) end
			end,
			blocked = function() return f.blocked end,
			ready = function() return f.ready end,
			present = function(pet) table.insert(f.presented, pet) end,
			failure = function() f.failed += 1 end,
			now = function() return f.time end,
			wait = function(dt) f.time += dt; if f.onWait then f.onWait() end end,
			spawn = function(run) run() end,
		}
		for key, value in pairs(overrides or {}) do dependencies[key] = value end
		f.navigation = Navigation.new(dependencies)
		return f
	end
	test("already equipped pet focuses without duplicate equip", function()
		local f = fixture(); f.navigation:meet("pip")
		assert(#f.requests == 0 and f.presented[1] == "pip" and not f.navigation.active)
	end)
	test("rare-only companion waits for server equip acknowledgment", function()
		local f = fixture(); f.values.CompanionId = "eclipse_orbit"
		f.onWait = function() if f.time >= .3 then f.values.CompanionId = "foxfire_wick" end end
		f.navigation:meet("foxfire_wick")
		assert(f.requests[1][1] == "companion" and f.presented[1] == "foxfire_wick" and f.time >= .3)
	end)
	test("mode and local handoff must both finish before equip", function()
		local f = fixture(); f.values.Mode, f.ready = "Board", false
		f.onWait = function()
			if f.time >= .2 then f.values.Mode = "Room" end
			if f.time >= .5 then f.ready = true end
		end
		f.navigation:meet("pip")
		assert(f.requests[1][1] == "mode" and f.presented[1] == "pip" and f.time >= .5)
	end)
	test("manual cancellation prevents late equip and focus", function()
		local f = fixture(); f.values.Mode = "Board"
		f.onWait = function() f.navigation:cancel(); f.values.Mode = "Room" end
		f.navigation:meet("wick")
		assert(#f.requests == 1 and #f.presented == 0 and not f.navigation.active)
	end)
	test("overlay interruption cancels pending focus", function()
		local f = fixture(); f.onWait = function() f.blocked = true; f.values.CompanionId = "wick" end
		f.navigation:meet("wick")
		assert(#f.presented == 0 and not f.navigation.active)
	end)
	test("unconfirmed equip never substitutes a local pet", function()
		local f = fixture(); f.navigation:meet("wick")
		assert(#f.presented == 0 and f.failed == 1 and f.values.CompanionId == "pip" and #f.requests <= 6)
	end)
	test("replay resets finished board once after handoff", function()
		local f = fixture(); f.values.Mode, f.values.RoundOver = "Room", true
		f.onWait = function() f.values.Mode = "Board" end
		f.navigation:play()
		assert(#f.requests == 2 and f.requests[1][1] == "mode" and f.requests[2][1] == "reset")
	end)
	test("replay preserves an unfinished board", function()
		local f = fixture(); f.values.Mode = "Board"; f.navigation:play(); assert(#f.requests == 0)
	end)
	test("cancelled replay cannot reset a later round", function()
		local f = fixture(); f.values.RoundOver = true
		f.onWait = function() f.navigation:cancel(); f.values.Mode = "Board" end
		f.navigation:play(); assert(#f.requests == 1 and #f.presented == 0)
	end)
	test("newer navigation wins over a stale mode wait", function()
		local f = fixture(); f.values.Mode = "Board"
		f.onWait = function()
			f.onWait = nil; f.values.Mode = "Room"; f.navigation:meet("pip")
		end
		f.navigation:meet("wick")
		assert(#f.presented == 1 and f.presented[1] == "pip")
	end)
	return { passed = #cases, cases = cases }
end
