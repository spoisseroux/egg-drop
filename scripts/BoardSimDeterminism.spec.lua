-- Studio Server AND Client (B0 of the client-run board, artifacts/qa-2026-11-17-v887/B0-plan.md).
-- Replays SimCheck's three seeded input logs (24 drops, varied aims and gaps, swap/bomb/pop/
-- magnet) through the shared BoardSim and returns every per-60-tick hash, plus unit checks:
-- snapshot/restore round trip and resume, hash sensitivity to one ulp, aim grid, launch table
-- against BoardConfig.launchVelocity. Run it on both datamodels and compare `digest` and `hashes`.
-- Copy to src/server/ZZSpecs/BoardSimDeterminism.lua and src/client/ZZSpecs/BoardSimDeterminism.lua.
-- Usage: require(<Server or PlayerScripts.Client>.ZZSpecs.BoardSimDeterminism)()
return function()
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Sim = require(Shared.BoardSim)
	local Check = require(Shared.SimCheck)
	local Config = require(Shared.BoardConfig)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end

	test("aim grid: index = floor(aim*400+.5), grid aims round-trip, invalid aims refused", function()
		for index = 0, Sim.AimSteps do assert(Sim.aimIndex(index / Sim.AimSteps) == index, "round trip " .. index) end
		assert(Sim.aimIndex(0.5) == 200 and Sim.aimIndex(0.00124) == 0 and Sim.aimIndex(0.00126) == 1)
		assert(Sim.aimIndex(-0.01) == nil and Sim.aimIndex(1.01) == nil and Sim.aimIndex(0 / 0) == nil and Sim.aimIndex("0.5") == nil)
	end)

	test("launch table matches BoardConfig.launchVelocity (float32) within 1e-5", function()
		for index = 0, Sim.AimSteps, 8 do
			local vx, vy = Sim.launchVelocity(index)
			local v = Config.launchVelocity(index / Sim.AimSteps)
			assert(math.abs(vx - v.X) < 1e-5 and math.abs(vy - v.Y) < 1e-5, "aim " .. index)
		end
	end)

	local logs = Check.logs()
	test("snapshot/restore: same hash, and resuming from a snapshot gives the uninterrupted hashes", function()
		local log = logs[1]
		local full = Sim.replay(log.seed, log.preset, log.inputs, log.ticks, log.options)
		-- Replay to tick 900 by hand, snapshot, restore twice, continue.
		local options = table.clone(log.options); options.seed = log.seed
		local board = Sim.new(log.preset, 0, options)
		local nextInput = 1
		local function advanceTo(target, b)
			while b.tick < target do
				while log.inputs[nextInput] and log.inputs[nextInput].tick == b.tick do Sim.apply(b, log.inputs[nextInput]); nextInput += 1 end
				Sim.step(b, {}, nil); b.bursts = nil
			end
		end
		advanceTo(900, board)
		local snap = Sim.snapshot(board)
		local a, b = Sim.restore(snap), Sim.restore(snap)
		assert(Sim.hash(a) == Sim.hash(board) and Sim.hash(b) == Sim.hash(board), "restore hash")
		assert(a ~= b and a.eggs ~= b.eggs and a.eggs[1] ~= board.eggs[1], "deep copies")
		local resumeAt = nextInput
		advanceTo(log.ticks, a)
		assert(Sim.hash(a) == full.final, "resumed final hash equals the uninterrupted replay")
		nextInput = resumeAt
		advanceTo(log.ticks, b)
		assert(Sim.hash(b) == full.final, "second restore equals too")
		assert(Sim.hash(Sim.restore(snap)) == Sim.hash(Sim.restore(snap)), "snapshot unchanged by the replays")
	end)

	test("hash sees one ulp, a flag, the queue and the armed item", function()
		local board = Sim.new("Springy", 0, { seed = 7, starter = {}, contactGate = true, powerUps = "medium" })
		assert(Sim.drop(board, 0.5))
		for _ = 1, 30 do Sim.step(board) end
		local base = Sim.hash(board)
		local egg = board.eggs[1]
		local y = egg.y -- x is exactly 0 for a straight drop; y is not
		assert(y ~= 0)
		egg.y = y + math.abs(y) * 2 ^ -52; assert(egg.y ~= y and Sim.hash(board) ~= base, "one ulp"); egg.y = y
		assert(Sim.hash(board) == base)
		egg.hasContact = not egg.hasContact; assert(Sim.hash(board) ~= base, "contact"); egg.hasContact = not egg.hasContact
		local tier = board.queue[5] -- (a swap of two equal tiers is a true no-op)
		board.queue[5] = tier % 2 + 1; assert(Sim.hash(board) ~= base, "queue"); board.queue[5] = tier
		assert(Sim.hash(board) == base)
		assert(Sim.arm(board, "bomb") and Sim.hash(board) ~= base and not Sim.arm(board, "magnet"), "armed")
	end)

	test("rules: bomb bursts on contact, magnet counts 240 ticks, pop takes the top resting ball", function()
		local board = Sim.new("Springy", 0, { seed = 11, starter = {}, contactGate = true })
		assert(Sim.drop(board, 0.5))
		for _ = 1, 240 do Sim.step(board) end
		assert(Sim.arm(board, "bomb") and Sim.drop(board, 0.5) and board.eggs[#board.eggs].mark == "bomb")
		local bursts = 0
		for _ = 1, 240 do Sim.step(board); if board.bursts then bursts += #board.bursts; board.bursts = nil end end
		assert(bursts == 1 and #board.eggs == 0, "bomb took the resting ball with it")
		assert(Sim.drop(board, 0.3))
		for _ = 1, 200 do Sim.step(board) end
		assert(Sim.arm(board, "magnet") and Sim.drop(board, 0.7))
		local magnet = board.eggs[#board.eggs]
		assert(magnet.magnetTicks == Sim.MagnetTicks and Sim.MagnetTicks == 240 and Sim.GateTicks == 72)
		for _ = 1, 600 do Sim.step(board) end
		if magnet.hasContact then assert(magnet.magnetTicks == 0 or table.find(board.eggs, magnet) == nil, "magnet ran out") end
		local top = Sim.popTarget(board)
		if top then assert(Sim.pop(board) == top and table.find(board.eggs, top) == nil) end
	end)

	local started = os.clock()
	local run = Check.run()
	local seconds = os.clock() - started
	local total = 0
	for _, list in ipairs(run.hashes) do total += #list end
	-- Determinism on this machine: a second run must agree exactly.
	test("two runs in one datamodel agree", function()
		local again = Check.run()
		assert(Check.compare(run.hashes, again.hashes) == nil)
	end)
	return {
		side = if game:GetService("RunService"):IsServer() then "server" else "client",
		cases = cases, digest = Check.digest(run.hashes), total = total, seconds = seconds,
		results = run.results, hashes = run.hashes,
	}
end
