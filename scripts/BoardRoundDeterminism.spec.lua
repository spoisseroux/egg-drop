-- Studio Server AND Client (B1 of the client-run board, artifacts/qa-2026-11-17-v887/B1-plan.md).
-- Replays seeded synthetic field rounds (three heats and templates, star slots on, item uses,
-- pause/resume, junk inputs) through the shared round host (BoardRoundSim) and returns every
-- per-60-tick hash plus a digest; run it on both datamodels and compare. Unit checks: tick
-- constants, refusals never error, spec validation, bounds for untrusted logs, snapshot/restore
-- resume, hash sensitivity, publicSpec. Optional `recordedJson`: a JSON array of
-- {spec, inputs, endTick} (e.g. live rounds from RoundRecorder) replayed the same way.
-- Copy to src/server/ZZSpecs/BoardRoundDeterminism.lua and src/client/ZZSpecs/BoardRoundDeterminism.lua.
-- Usage: require(<Server or PlayerScripts.Client>.ZZSpecs.BoardRoundDeterminism)([recordedJson])
return function(recordedJson)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Config = require(Shared.BoardConfig)
	local Sim = require(Shared.BoardSim)
	local RoundSim = require(Shared.BoardRoundSim)
	local Objectives = require(Shared.FieldObjectives)
	local HttpService = game:GetService("HttpService")
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end

	local Setups = {
		{ logSeed = 1101, template = "bank_pair", fieldSeed = 4242, heat = "medium", preset = "Springy" },
		{ logSeed = 2202, template = "lantern_chain", fieldSeed = 777, heat = "hard", preset = "Gentle" },
		{ logSeed = 3303, template = "creek_crossing", fieldSeed = 90001, heat = "easy", preset = "Springy" },
	}
	local function makeSpec(setup)
		local descriptor = Objectives.create(setup.template, setup.fieldSeed, setup.heat)
		local spec = RoundSim.fieldSpec(setup.preset, 0, descriptor, setup.heat, true)
		-- Star slots are data: put one on every third drop so the belt, grants and uses all run.
		local order = { "pop", "swap", "bomb", "magnet" }
		for slot = 1, #spec.queue do spec.stars[slot] = if slot % 3 == 0 then order[(slot // 3 - 1) % 4 + 1] else false end
		return spec
	end
	-- 40 drop attempts (gaps 25-150 ticks, so the 31-tick interval and the 72-tick gate refuse some),
	-- item attempts, a pause with an item inside it, and a few junk inputs.
	local function makeLog(setup)
		local random = Random.new(setup.logSeed)
		local inputs, tick, n = {}, 20, 0
		local function add(entry) n += 1; entry.n = n; entry.tick = tick; table.insert(inputs, entry) end
		for drop = 1, 40 do -- more than the 24-drop budget: refused ones are retried, the rest refused Budget
			add({ kind = "drop", aim = random:NextInteger(0, Sim.AimSteps) })
			if drop % 4 == 2 then add({ kind = "drop", aim = random:NextInteger(0, Sim.AimSteps) }) end -- same tick: Gate
			local roll = random:NextInteger(1, 6)
			tick += random:NextInteger(25, 150)
			add({ kind = if drop % 2 == 0 then "swap" else "pop" }) -- refused NotOnBelt until a star ball merges
			if roll == 1 then add({ kind = "pop" })
			elseif roll == 2 then add({ kind = "swap" })
			elseif roll == 3 then add({ kind = "arm", item = if random:NextInteger(0, 1) == 0 then "bomb" else "magnet" })
			elseif roll == 4 then add({ kind = "pause" }); add({ kind = "pop" }); add({ kind = "drop", aim = 200 }); add({ kind = "resume" })
			end
			if drop == 10 then add({ kind = "drop", aim = 401 }); add({ kind = "teleport" }); add({ kind = "arm", item = "pop" }) end
		end
		return inputs
	end

	local function run(spec, inputs, endTick)
		local out = assert(RoundSim.replay(spec, inputs, { endTick = endTick, hashEvery = 60 }))
		return out
	end

	test("tick constants: interval 31, chain 150 (1.25 s on float clocks), warm-up 169, settle 361, grace 289 (medium)", function()
		assert(RoundSim.DropIntervalTicks == 31 and RoundSim.ChainTicks == 150, "interval/chain")
		assert(RoundSim.WarmupTicks == 169 and RoundSim.SettleTicks == 361, "warm-up/settle")
		local host = RoundSim.new(makeSpec(Setups[1]))
		assert(host.graceTicks == 289 and RoundSim.accumulatedTicks(Config.Heat.hard.grace) == 241, "grace")
	end)

	test("refusals never error and give the reason", function()
		local host = assert(RoundSim.new(makeSpec(Setups[1])))
		local function expect(input, reason)
			local ok, why = RoundSim.apply(host, input)
			assert(ok == false and why == reason, "expected " .. reason .. ", got " .. tostring(ok) .. " " .. tostring(why))
		end
		expect(nil, "Malformed"); expect("drop", "Malformed")
		expect({ n = 1.5, tick = 0, kind = "drop", aim = 1 }, "Malformed")
		expect({ n = 1, tick = 0 / 0, kind = "drop", aim = 1 }, "Malformed")
		expect({ n = 1, tick = 0, kind = 5 }, "Malformed")
		expect({ n = 1, tick = 3, kind = "drop", aim = 1 }, "Early")
		expect({ n = 1, tick = 0, kind = "drop", aim = 401 }, "Aim")
		expect({ n = 2, tick = 0, kind = "drop", aim = 0.5 }, "Aim")
		expect({ n = 2, tick = 0, kind = "drop", aim = 200 }, "Duplicate")
		expect({ n = 3, tick = 0, kind = "pop" }, "NotOnBelt")
		expect({ n = 4, tick = 0, kind = "arm", item = "pop" }, "Malformed")
		expect({ n = 5, tick = 0, kind = "fly" }, "Malformed")
		assert(RoundSim.apply(host, { n = 6, tick = 0, kind = "drop", aim = 200 }), "a good drop")
		expect({ n = 7, tick = 0, kind = "drop", aim = 200 }, "Gate") -- the gate is checked before the interval, as today
		assert(RoundSim.apply(host, { n = 8, tick = 0, kind = "pause" }))
		expect({ n = 9, tick = 0, kind = "pause" }, "Same")
		assert(RoundSim.step(host) == nil and host.board.tick == 0, "paused host does not step")
		RoundSim.apply(host, { n = 10, tick = 0, kind = "resume" })
		RoundSim.step(host)
		expect({ n = 11, tick = 0, kind = "drop", aim = 100 }, "Late")
		expect({ n = 12, tick = 1, kind = "drop", aim = 100 }, "Gate")
		host.over = true
		expect({ n = 13, tick = 1, kind = "pause" }, "RoundOver")
		host.over = false
		-- Without the contact gate the interval decides: 31 ticks.
		local spec = makeSpec(Setups[1]); spec.contactGate = false
		local open = assert(RoundSim.new(spec))
		assert(RoundSim.apply(open, { n = 1, tick = 0, kind = "drop", aim = 0 }))
		for _ = 1, 30 do RoundSim.step(open) end
		local ok, why = RoundSim.apply(open, { n = 2, tick = 30, kind = "drop", aim = 400 })
		assert(not ok and why == "Interval", "interval at 30: " .. tostring(why))
		RoundSim.step(open)
		ok, why = RoundSim.apply(open, { n = 3, tick = 31, kind = "drop", aim = 400 })
		assert(why ~= "Interval", "interval open at 31")
	end)

	test("spec validation", function()
		local spec = makeSpec(Setups[1])
		local bad = table.clone(spec); bad.queue = { 1, 9 }
		assert(select(2, RoundSim.new(bad)) == "Queue")
		bad = table.clone(spec); bad.descriptor = nil
		assert(select(2, RoundSim.new(bad)) == "Field")
		bad = table.clone(spec); bad.stars = { "rocket" }
		assert(select(2, RoundSim.new(bad)) == "Stars")
		bad = table.clone(spec); bad.kick = math.huge
		assert(select(2, RoundSim.new(bad)) == "Physics")
		assert(RoundSim.replay(nil, {}) == nil)
		local public = RoundSim.publicSpec(spec)
		assert(public.queue == nil and public.stars == nil and public.descriptor and spec.queue, "publicSpec")
	end)

	test("bounds: input caps, per-tick cap, a log stuck paused still ends", function()
		local spec = makeSpec(Setups[1])
		local many = {}
		for index = 1, RoundSim.MaxInputs + 40 do table.insert(many, { n = index, tick = index * 40, kind = "pop" }) end
		local out = RoundSim.replay(spec, many, { maxTicks = 3000 })
		assert(out.refused == #many and out.reasons.TooMany == 40 and out.host.board.tick <= 3000, "input cap")
		local burst = {}
		for index = 1, 20 do table.insert(burst, { n = index, tick = 5, kind = "pop" }) end
		out = RoundSim.replay(spec, burst, { maxTicks = 100 })
		assert(out.reasons.TooMany == 4 and out.reasons.NotOnBelt == 16, "per-tick cap")
		-- A pause, then 20 refused taps at its tick: resume still lands (it skips the caps).
		local stuck = { { n = 1, tick = 5, kind = "pause" } }
		for index = 2, 21 do table.insert(stuck, { n = index, tick = 5, kind = "pop" }) end
		table.insert(stuck, { n = 22, tick = 5, kind = "resume" })
		out = RoundSim.replay(spec, stuck, { maxTicks = 100 })
		assert(not out.host.paused and out.host.board.tick == 100, "resume after a capped tick")
		out = RoundSim.replay(spec, { { n = 1, tick = 0, kind = "pause" }, { n = 2, tick = 2147483647, kind = "drop", aim = 1 } })
		assert(out.host.board.tick == 0 and out.reasons.Early == 1, "paused log")
		out = RoundSim.replay(spec, { { n = 1, tick = 2147483647, kind = "drop", aim = 1 } }, { maxTicks = 500 })
		assert(out.host.board.tick == 500 and out.reasons.Early == 1, "far future input")
	end)

	local logs = {}
	for index, setup in ipairs(Setups) do logs[index] = { spec = makeSpec(setup), inputs = makeLog(setup) } end

	test("snapshot/restore resumes to the uninterrupted final hash", function()
		local log = logs[2]
		local full = run(log.spec, log.inputs)
		local host = RoundSim.new(log.spec)
		local nextInput = 1
		local function advanceTo(target, h)
			while h.board.tick < target and not h.over do
				while log.inputs[nextInput] and log.inputs[nextInput].tick == h.board.tick do
					RoundSim.apply(h, log.inputs[nextInput]); nextInput += 1
				end
				if h.paused then
					-- inputs at a paused tick
					while log.inputs[nextInput] and h.paused do RoundSim.apply(h, log.inputs[nextInput]); nextInput += 1 end
				end
				RoundSim.step(h)
			end
		end
		advanceTo(1500, host)
		local snap = RoundSim.snapshot(host)
		local a = RoundSim.restore(snap)
		assert(RoundSim.hash(a) == RoundSim.hash(host), "restore hash")
		local resumeAt = nextInput
		advanceTo(RoundSim.MaxTicks, a)
		local b = RoundSim.restore(snap)
		nextInput = resumeAt
		advanceTo(RoundSim.MaxTicks, b)
		assert(RoundSim.hash(a) == full.final and RoundSim.hash(b) == full.final, "resumed final hash")
	end)

	test("hash sees the belt, the score and a ball's warm-up", function()
		local host = RoundSim.new(logs[1].spec)
		local base = RoundSim.hash(host)
		host.belt = { "pop" }; assert(RoundSim.hash(host) ~= base, "belt"); host.belt = {}
		host.score = 10; assert(RoundSim.hash(host) ~= base, "score"); host.score = 0
		assert(RoundSim.hash(host) == base, "restored")
		RoundSim.apply(host, { n = 1, tick = 0, kind = "drop", aim = 200 })
		local withBall = RoundSim.hash(host)
		host.board.eggs[1].bornTick = 1
		assert(RoundSim.hash(host) ~= withBall, "bornTick")
	end)

	local results, all = {}, {}
	for index, log in ipairs(logs) do
		local out = run(log.spec, log.inputs)
		for _, hash in ipairs(out.hashes) do table.insert(all, hash) end
		table.insert(all, out.final)
		results[index] = { belt = table.concat(out.host.belt, ","), grants = (function() local g = 0; for _, m in ipairs(out.merges) do g += if m.grants then #m.grants else 0 end; return g end)(), hashes = #out.hashes, final = out.final, accepted = out.accepted, refused = out.refused,
			reasons = HttpService:JSONEncode(out.reasons), result = out.result }
	end
	test("synthetic rounds end, use items and refuse the junk", function()
		local used, overs = 0, 0
		for _, item in ipairs(results) do
			used += item.result.itemsUsed
			if item.result.over then overs += 1 end
		end
		assert(overs == #results, "every synthetic round ends: " .. HttpService:JSONEncode(results))
		assert(used > 0, "items were used")
	end)

	local recorded = nil
	if recordedJson then
		recorded = {}
		for index, log in ipairs(HttpService:JSONDecode(recordedJson)) do
			local out = run(log.spec, log.inputs, log.endTick)
			for _, hash in ipairs(out.hashes) do table.insert(all, hash) end
			table.insert(all, out.final)
			recorded[index] = { hashes = #out.hashes, final = out.final, score = out.result.score }
		end
	end
	return {
		cases = cases, rounds = results, recorded = recorded, hashCount = #all,
		digest = Sim.hashBytes(table.concat(all)), hashes = table.concat(all, ","),
		side = if game:GetService("RunService"):IsServer() then "Server" else "Client",
	}
end
