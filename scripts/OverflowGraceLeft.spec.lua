-- Studio Server. BoardRound.graceLeft, published as the OverflowGraceLeft board
-- attribute beside OverflowPressure: seconds of grace left while the stack is over
-- the fill line, 0 when it is not. Pure fixtures; round rules and timing unchanged.
-- Usage: require(ServerScriptService.Server.ZZSpecs.OverflowGraceLeft)(ServerScriptService.Server)
return function(server)
	local Round = require(server.BoardRound)
	local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function near(a, b) return math.abs(a - b) < 1e-6 end
	-- One settled egg whose top sits `top` above the floor.
	local function egg(top) return { position = Vector3.new(0, top - 1, 0), radius = 1, roundAge = 5, enteredTray = true } end
	local below, above = { egg(Config.OverflowY - 0.5) }, { egg(Config.OverflowY + 0.5) }
	test("zero before any overflow and while the stack is only near the line", function()
		local r = Round.new()
		assert(r.graceLeft == 0)
		r:step(below, 0.1, 99)
		assert(r.graceLeft == 0 and r.danger > 0, "near the line has pressure but no grace countdown")
	end)
	test("counts down by the elapsed overflow time and matches the default grace", function()
		local r = Round.new()
		r:step(above, 0.1, 99)
		assert(near(r.graceLeft, Config.OverflowGrace - 0.1), "graceLeft=" .. r.graceLeft)
		r:step(above, 0.5, 99)
		assert(near(r.graceLeft, Config.OverflowGrace - 0.6) and not r.over)
	end)
	test("resets to zero the moment the stack drops back under the line", function()
		local r = Round.new()
		r:step(above, 0.4, 99); assert(r.graceLeft > 0)
		r:step(below, 0.1, 99)
		assert(r.graceLeft == 0 and r.overflowTime == 0 and not r.over)
	end)
	test("zero when the grace runs out and the round ends (rules unchanged)", function()
		local r = Round.new()
		r:step(above, Config.OverflowGrace + 0.01, 99)
		assert(r.over and r.graceLeft == 0)
	end)
	test("unarmed rounds and trial grace follow the existing options", function()
		local r = Round.new({ armAfterDrops = 10, grace = 3 })
		r:step(above, 0.2, 2)
		assert(r.graceLeft == 0 and r.overflowTime == 0, "not armed before the drop threshold")
		r:step(above, 0.5, 10)
		assert(near(r.graceLeft, 2.5) and r.grace == 3)
	end)
	test("the server publishes it beside OverflowPressure", function()
		local source = server:FindFirstChild("init") or server
		assert(Config.OverflowGrace == 1.1, "default grace changed")
		-- Source scan is only possible in Studio with the script loaded; skip quietly otherwise.
		local ok, text = pcall(function() return source.Source end)
		if ok and type(text) == "string" and #text > 0 then
			local _, count = string.gsub(text, 'SetAttribute%("OverflowGraceLeft", if board%.round%.over then 0 else board%.round%.graceLeft or 0%)', "")
			-- Zero once the round is over (code review: the warning stuck after a field-ended round).
			assert(count == 2, "OverflowGraceLeft publish sites=" .. count)
		end
	end)
	return { passed = #cases, cases = cases }
end
