-- Deck net audit (artifacts/qa-2026-11-26-beta35/DECK-NET-AUDIT.md), offline: one Pocket Deck field round
-- through the real client path (ClientRoundDriver + ClientBoardMirror) against the real server lockstep
-- (ClientSimHost), over a simulated reliable ordered link (DeckNetSim: round trip, jitter, loss with
-- head-of-line resends), on one simulated 60 Hz clock. The player taps whenever the drawn board says it
-- can drop (seeded aims and gaps, a pause, item uses). Every scenario must draw exactly the frames the
-- no-latency run draws (the network never moves, holds or rewinds a drawn ball), lose no tap, play every
-- merge's juice on time, end the round on the same frame, and end with the server's hash and result. A
-- forced desync must ease back (never more than BoardLockstep.MaxCorrection a frame beyond the motion).
-- Also measured (the old waits): the server's hello ack after the start, and its round end after the
-- local one (what the results used to wait for).
return function(client, offline)
	local cases = {}
	local function test(name, run) local extra = run(); table.insert(cases, name .. (if extra then " (" .. extra .. ")" else "")) end
	local DT = 1 / 60
	local TEMPLATE, FIELD_SEED, HEAT, PRESET = "bank_pair", 4242, "medium", "Springy"

	local function deepCopy(value)
		if type(value) ~= "table" then return value end
		local out = {}
		for k, v in pairs(value) do out[k] = deepCopy(v) end
		return out
	end

	-- One round. net: nil or {rtt, jitter, loss} (ms, ms, %); options.perturb: {at = seconds, dx}.
	local function play(net, options)
		options = options or {}
		local tree = offline.fresh("new")
		local Shared = tree.shared
		local L = tree.require(Shared.BoardLockstep)
		local RoundSim = tree.require(Shared.BoardRoundSim)
		local Objectives = tree.require(Shared.FieldObjectives)
		local NetSim = tree.require(Shared.DeckNetSim)
		local Host = tree.require(tree.server.ClientSimHost)
		local Driver = tree.require(tree.client.ClientRoundDriver)
		local Mirror = tree.require(tree.client.ClientBoardMirror)
		local Items = tree.require(Shared.RoundItems)
		-- The control case puts back the old gate (no tap before the server's hello ack).
		if options.earlyTapSeconds ~= nil then Driver.EarlyTapSeconds = options.earlyTapSeconds end
		-- The simulated clock starts at os.clock(): ClientSimHost.begin stamps its round with os.clock().
		local base = os.clock()
		local now = base
		local function clock() return now end
		-- Half the round trip each way (a reliable ordered RemoteEvent in each direction).
		local up = NetSim.link(net, 0.5, 11)
		local down = NetSim.link(net, 0.5, 23)

		-- Server: the board, its folder and the remote.
		local player = { UserId = 1, Name = "p", Parent = {} }
		local serverFolder = offline.Instance.new("Folder")
		local clientFolder = offline.Instance.new("Folder")
		local REPLICATED = { "ResetId", "RunSequence", "ClientSimRound", "RoundOver", "FieldPhase", "FieldSuccess",
			"FieldReason", "FieldFinalStage", "RewardStatus", "Mode" }
		for _, name in ipairs(REPLICATED) do
			serverFolder:GetAttributeChangedSignal(name):Connect(function()
				down:push(now, { attr = name, value = serverFolder:GetAttribute(name) })
			end)
		end
		local serverRemote = { Name = "", OnServerEvent = offline.signal() }
		function serverRemote:FireClient(_, kind, packet) down:push(now, { kind = kind, packet = deepCopy(packet) }) end
		local remotes = { FindFirstChild = function() return serverRemote end }
		local board = { player = player, folder = serverFolder, runSequence = 7, runHeat = HEAT, belt = {}, mode = "Board",
			menuPaused = false, closing = false }
		Host.mount(remotes, function() return board end)
		Host.serverNow = clock -- one synced clock (workspace:GetServerTimeNow) for both sides
		local result, merges, overAt = nil, 0, nil
		local hooks = {
			merge = function() merges += 1 end,
			over = function(_, _, r)
				result = r
				overAt = now
				serverFolder:SetAttribute("FieldPhase", "Complete")
				serverFolder:SetAttribute("FieldSuccess", r.success)
				serverFolder:SetAttribute("FieldReason", r.reason)
				serverFolder:SetAttribute("FieldFinalStage", r.goalsMet)
				serverFolder:SetAttribute("RoundOver", true)
				serverFolder:SetAttribute("RewardStatus", "Saved")
			end,
		}

		-- Client: the driver, the mirror and a view registry standing in for the deck's renderer.
		local clientRemote = { OnClientEvent = offline.signal() }
		function clientRemote:FireServer(packet) up:push(now, deepCopy(packet)) end
		local heartbeat = offline.signal()
		clientFolder:SetAttribute("Mode", "Board")
		Driver.start({ remote = clientRemote, folder = clientFolder, clock = clock, serverNow = clock, heartbeat = heartbeat })
		local views, render = {}, nil
		local played = { merges = 0, late = 0, drops = 0, grants = 0, impacts = 0 }
		local mirror = Mirror.new({
			board = clientFolder, driver = Driver, clock = clock, bindRender = function(fn) render = fn end,
			add = function(part) views[part] = true end, remove = function(part) views[part] = nil end,
			hasView = function(part) return views[part] ~= nil end,
			hideServer = function() end, released = function() end,
			merge = function(_, _, late) played.merges += 1; if late then played.late += 1 end end,
			impacts = function(batch) played.impacts += #batch end,
			drop = function() played.drops += 1 end,
			grant = function() played.grants += 1 end,
			changed = function() end,
		})

		-- The round starts (the server's reset).
		local descriptor = Objectives.create(TEMPLATE, FIELD_SEED, HEAT)
		serverFolder:SetAttribute("RunSequence", 7)
		local view = assert(Host.begin(board, PRESET, 0, descriptor, true, function() error("no-hello fallback") end), "begin")
		serverFolder:SetAttribute("ResetId", view.serial)

		-- The player: seeded gaps and aims, taps only while the drawn board can drop.
		local random = Random.new(5150)
		local nextTap, taps, tapRefused = 0.05, 0, {}
		local pauseAt, resumeAt, itemAt = 9.0, 10.2, 6.0
		-- Frames and the player's clock count from the frame the start reached the client (its round's frame 0).
		local frames, startSeen, startFrame, helloAt, earlyTaps = {}, nil, nil, nil, 0
		local localOverAt, localOverFrame, settledAt, statesSeen = nil, nil, nil, 0
		local frame = 0
		local maxJump = 0
		local last = {}
		local perturbed = false
		local lastPreview, previewFlips = nil, 0
		local function deliver(item)
			if item.attr then clientFolder:SetAttribute(item.attr, item.value); return end
			if item.kind == "start" and not startSeen then startSeen, startFrame = now, frame end
			if item.kind == "state" then statesSeen += 1 end
			clientRemote.OnClientEvent:Fire(item.kind, item.packet)
			if item.kind == "ack" and not helloAt then helloAt = now end
		end
		while frame < 60 * 240 do
			frame += 1
			now = base + frame * DT
			for _, packet in ipairs(up:due(now) or {}) do Host.receive(board, packet, now) end
			Host.advance(board, now, DT, hooks)
			for _, item in ipairs(down:due(now) or {}) do deliver(item) end
			local state = Driver.round()
			-- Whole frames since the start (exact, the same in every run).
			local rel = if startFrame then (frame - startFrame) * DT else -1
			-- Input (start of the frame, before the render step).
			if state and not state.host.over then
				if options.perturb and not perturbed and rel >= options.perturb.at and #state.host.board.eggs > 0 then
					perturbed = true
					local eggs = state.host.board.eggs
					eggs[#eggs].x += options.perturb.dx
				end
				if rel >= pauseAt and pauseAt > 0 then pauseAt = -1; Driver.pause(true) end
				if rel >= resumeAt and resumeAt > 0 and pauseAt < 0 then resumeAt = -1; Driver.pause(false) end
				if rel >= itemAt and itemAt > 0 then
					local belt = state.host.belt
					if #belt > 0 then
						itemAt = -1
						local ok, why = Driver.item(belt[1])
						if not ok then tapRefused["item:" .. tostring(why)] = (tapRefused["item:" .. tostring(why)] or 0) + 1 end
					end
				end
				local ready = mirror:value("FieldReady")
				if ready == true and rel >= nextTap and not state.host.paused then
					taps += 1
					if not state.hello then earlyTaps += 1 end
					local ok, why = Driver.drop(random:NextNumber())
					if not ok and why ~= "Full" and why ~= "Spawn" then tapRefused[why] = (tapRefused[why] or 0) + 1 end
					nextTap = rel + random:NextNumber(0.12, 0.9)
				end
			end
			-- Render step: the drawn frame.
			render()
			local drawn = {}
			for part in pairs(views) do
				local id = part:GetAttribute("EggId")
				local p = part.Position
				drawn[id] = { p.X, p.Y }
				local before = last[id]
				if before then
					local jump = math.sqrt((p.X - before[1]) ^ 2 + (p.Y - before[2]) ^ 2)
					if jump > maxJump then maxJump = jump end
				end
			end
			last = drawn
			if startFrame then frames[frame - startFrame] = drawn end
			-- The next-ball previews: a change with no drop and no item use is a reveal landing late (a flip).
			-- (The server's values stand after its end: not a reveal.)
			if state and not mirror.settled then
				local shown = { mirror:value("NextTier"), mirror:value("PreviewTier1"), mirror:value("PreviewTier2"),
					state.host.board.drops, state.host.itemSeq }
				local prev = lastPreview
				if prev and prev[4] == shown[4] and prev[5] == shown[5] and (prev[1] ~= shown[1] or prev[2] ~= shown[2] or prev[3] ~= shown[3]) then
					previewFlips += 1
				end
				lastPreview = shown
			end
			if state and state.host.over and not localOverAt then localOverAt, localOverFrame = now, frame - startFrame end
			if mirror.settled and not settledAt then settledAt = now end
			-- Heartbeat: the client host steps.
			heartbeat:Fire(DT)
			if localOverAt and settledAt and now - math.max(localOverAt, settledAt) > 1.5 then break end
		end
		local cs = Driver.stats()
		local ss = Host.stats(board)
		return {
			net = net, frames = frames, lastFrame = frame, taps = taps, tapRefused = tapRefused, earlyTaps = earlyTaps,
			helloMs = if helloAt and startSeen then (helloAt - startSeen) * 1000 else nil,
			endGapMs = if settledAt and localOverAt then (settledAt - localOverAt) * 1000 else nil,
			localOverFrame = localOverFrame, result = result, clientResult = cs.result, clientFinal = cs.final, serverFinal = ss.final,
			cs = cs, ss = ss, played = played, mirrorStats = mirror:publicStats(), maxJump = maxJump, merges = merges,
			lost = up.lost + down.lost, upMax = up.maxDelay, downMax = down.maxDelay, statesSeen = statesSeen,
			itemsUsed = cs.result and cs.result.itemsUsed or 0, previewFlips = previewFlips, L = L, RoundSim = RoundSim, Items = Items,
		}
	end

	local function count(map)
		local n = 0
		for _, v in pairs(map or {}) do n += v end
		return n
	end
	local function fmt(map)
		local parts = {}
		for k, v in pairs(map or {}) do table.insert(parts, k .. "=" .. tostring(v)) end
		table.sort(parts)
		return "{" .. table.concat(parts, ",") .. "}"
	end

	-- The same frames: every drawn ball at the same spot, every frame, up to the end + 1 s.
	local function sameFrames(a, b, upTo)
		for f = 0, upTo do
			local fa, fb = a.frames[f], b.frames[f]
			if fa == nil or fb == nil then return false, "frame " .. f .. " missing" end
			for id, p in pairs(fa) do
				local q = fb[id]
				if not q then return false, string.format("frame %d: ball %s drawn in one run only", f, tostring(id)) end
				if math.abs(p[1] - q[1]) > 1e-9 or math.abs(p[2] - q[2]) > 1e-9 then
					return false, string.format("frame %d: ball %s at (%.4f, %.4f) vs (%.4f, %.4f)", f, tostring(id), p[1], p[2], q[1], q[2])
				end
			end
			for id in pairs(fb) do
				if not fa[id] then return false, string.format("frame %d: ball %s drawn in one run only", f, tostring(id)) end
			end
		end
		return true
	end

	local function healthy(run, label)
		assert(run.result, label .. ": the server's round ended")
		assert(run.localOverFrame, label .. ": the client's round ended")
		assert(run.clientFinal == run.serverFinal, label .. ": client and server end hashes differ")
		local a, b = run.result, run.clientResult
		for _, key in ipairs({ "success", "reward", "score", "peakChain", "clears", "drops", "merges", "maxTier", "itemsUsed", "goalsMet" }) do
			assert(a[key] == b[key], label .. ": result " .. key .. " server " .. tostring(a[key]) .. " / client " .. tostring(b[key]))
		end
		assert(count(run.tapRefused) == 0, label .. ": taps refused " .. fmt(run.tapRefused))
		local refused = run.cs.localRefused
		for _, reason in ipairs({ "Hello", "Unrevealed", "Backlog", "Joining", "Held", "HeldHello", "HeldUnrevealed", "HeldBacklog" }) do
			assert((refused[reason] or 0) == 0, label .. ": a tap lost for " .. reason)
		end
		assert(run.cs.heldExpired == 0, label .. ": a held tap expired")
		assert(run.taps >= 20 and run.result.drops >= 20, label .. ": a real round (" .. run.taps .. " taps, " .. run.result.drops .. " drops)")
		assert(count(run.ss.refused) == 0 and count(run.ss.rule) == 0, label .. ": server refusals " .. fmt(run.ss.refused) .. " rule " .. fmt(run.ss.rule))
		assert(run.played.late == 0, label .. ": merge juice skipped as late")
		assert(run.played.merges == run.result.merges, label .. ": merges played " .. run.played.merges .. " / " .. run.result.merges)
		assert(run.played.drops == run.result.drops, label .. ": drop cues " .. run.played.drops .. " / " .. run.result.drops)
		local released = run.mirrorStats.released
		assert(count(released) == 0, label .. ": the mirror let the round go " .. fmt(released))
		assert(run.ss.takeover == nil, label .. ": the server took the round over (" .. tostring(run.ss.takeover) .. ")")
	end

	local base = play(nil)
	local baseMax = base.maxJump
	test("no latency: a full round, client = server (hash and result), every tap played, every merge's juice on time", function()
		healthy(base, "lag 0")
		assert(base.itemsUsed >= 1, "an item was used")
		assert(base.cs.early == 0 or base.cs.early >= 0)
		return string.format("%d taps, %d merges, score %d, largest drawn step %.2f studs", base.taps, base.result.merges, base.result.score, baseMax)
	end)

	local SCENARIOS = {
		{ "150 ms", { rtt = 150, jitter = 0, loss = 0 }, true },
		{ "300 ms", { rtt = 300, jitter = 0, loss = 0 }, true },
		{ "600 ms", { rtt = 600, jitter = 0, loss = 0 }, true },
		{ "300 ms +/-100 jitter, 5% loss", { rtt = 300, jitter = 100, loss = 5 } },
		{ "600 ms +/-150 jitter, 5% loss", { rtt = 600, jitter = 150, loss = 5 } },
		{ "1000 ms +/-250 jitter, 5% loss", { rtt = 1000, jitter = 250, loss = 5 } },
	}
	for _, scenario in ipairs(SCENARIOS) do
		local label, net, steady = scenario[1], scenario[2], scenario[3]
		test(label .. ": the same drawn frames as lag 0 to the end, no tap lost, same end frame, server result equal", function()
			local run = play(net)
			healthy(run, label)
			assert(run.localOverFrame == base.localOverFrame, label .. ": the round ended on frame " .. tostring(run.localOverFrame)
				.. ", lag 0 on " .. tostring(base.localOverFrame))
			local ok, why = sameFrames(run, base, base.localOverFrame + 60)
			assert(ok, label .. ": drawn frames differ: " .. tostring(why))
			assert(run.maxJump <= baseMax + 1e-9, label .. ": a drawn step of " .. run.maxJump)
			-- Up to 600 ms the previews never wait for a reveal; past it (and with loss bursts) a third preview
			-- can show the placeholder for a moment (audit finding 7: the server's reveal window).
			if steady then assert(run.previewFlips == 0, label .. ": " .. run.previewFlips .. " preview flips") end
			return string.format("hello ack %.0f ms after the start (%d early taps played), server end %.0f ms after the local end, %d packets resent, %d held, %d preview flips",
				run.helloMs or -1, run.earlyTaps, run.endGapMs or -1, run.lost, run.cs.held, run.previewFlips)
		end)
	end

	test("2.6 s round trip: early taps stop before the no-hello fallback could take them; the round still ends equal", function()
		local run = play({ rtt = 2600, jitter = 0, loss = 0 })
		assert(run.result and run.localOverFrame, "both ends")
		assert(run.clientFinal == run.serverFinal, "end hashes equal")
		assert(run.ss.takeover == nil and count(run.mirrorStats.released) == 0, "no fallback or takeover")
		assert(run.cs.early <= 1, "at most the first frames' tap played before the ack (" .. run.cs.early .. ")")
		assert(run.cs.held >= 1, "later taps were held, not shown")
		return string.format("%d early, %d held (%d played, %d let go), %d drops", run.cs.early, run.cs.held, run.cs.heldPlayed,
			run.cs.heldExpired, run.result.drops)
	end)

	test("control: with the old hello gate (no tap before the ack) the harness sees the drawn frames move at 600 ms", function()
		local run = play({ rtt = 600, jitter = 0, loss = 0 }, { earlyTapSeconds = 0 })
		local ok, why = sameFrames(run, base, base.localOverFrame + 60)
		assert(not ok, "the old gate changed nothing drawn?")
		assert(run.cs.held >= 1, "the first taps waited")
		return string.format("%d tap(s) held %.0f ms for the ack; first difference: %s", run.cs.held, run.cs.heldMsMax, why)
	end)

	test("forced desync at 300 ms (+0.3 stud on the newest ball): rollback, eased back, never a jump, ends equal", function()
		local run = play({ rtt = 300, jitter = 0, loss = 0 }, { perturb = { at = 4.0, dx = 0.3 } })
		assert(run.cs.mismatches >= 1 and run.cs.rollbacks >= 1, "a mismatch and a rollback (" .. run.cs.mismatches .. ", " .. run.cs.rollbacks .. ")")
		assert(run.clientFinal == run.serverFinal, "end hashes equal after the rollback")
		assert(run.result.score == run.clientResult.score and run.result.drops == run.clientResult.drops, "result equal")
		assert(run.mirrorStats.popFar == 0 and run.mirrorStats.popRemoved == 0, "no ball redrawn elsewhere")
		local limit = baseMax + run.L.MaxCorrection + 0.3 + 1e-6
		assert(run.maxJump <= limit, string.format("largest drawn step %.3f > %.3f", run.maxJump, limit))
		assert(count(run.tapRefused) == 0, "taps refused " .. fmt(run.tapRefused))
		return string.format("%d rollback(s) %.0f ms after the mismatch, largest offset %.2f, largest drawn step %.2f studs (lag 0: %.2f)",
			run.cs.rollbacks, run.cs.recoverMs[1] or -1, run.mirrorStats.offsetMax, run.maxJump, baseMax)
	end)

	test("round end: the end art and results open from the client host's end; the server's end takes over with no second intro, and corrects a different outcome", function()
		local tree = offline.fresh("new")
		local End = tree.require(tree.client.RoundEndPresentation)
		local Objectives = tree.require(tree.shared.FieldObjectives)
		local FieldRun = tree.require(tree.server.FieldRun)
		local Http = tree.game:GetService("HttpService")
		local run = FieldRun.new({ descriptor = Objectives.create(TEMPLATE, FIELD_SEED, HEAT), sequence = 7, heat = HEAT })
		run.rootStage = 2
		local title = run.descriptor.title
		local objective = Http:JSONEncode(run:public(7))
		local function scenario(localSuccess, serverSuccess)
			local board = offline.Instance.new("Folder")
			board:SetAttribute("ResetId", 5); board:SetAttribute("RunSequence", 7); board:SetAttribute("Mode", "Board")
			board:SetAttribute("FieldStage", 2); board:SetAttribute("FieldObjective", objective)
			local localEnd = nil
			local presentation = End.new(board, {
				localEnd = function(serial) return if serial == 5 then localEnd else nil end,
				localBalls = function() return {} end, owns = function() return true end, reduced = function() return false end,
			})
			presentation:observe()
			assert(presentation.frozen == nil, "nothing while the round plays")
			localEnd = { success = localSuccess, reason = title .. (if localSuccess then " complete" else " incomplete"), stage = 2 }
			local early = presentation:observe()
			assert(early and early.provisional and early.success == localSuccess, "frozen from the client's end at once")
			assert(presentation.active and presentation.starts == 1, "the intro plays from the local end")
			board:SetAttribute("FieldPhase", "Complete"); board:SetAttribute("FieldSuccess", serverSuccess)
			board:SetAttribute("FieldReason", title .. (if serverSuccess then " complete" else " incomplete"))
			board:SetAttribute("FieldFinalStage", 2)
			board:SetAttribute("RoundOver", true)
			local final = presentation:observe()
			assert(final and not final.provisional and final.success == serverSuccess, "the server's values stand")
			assert(presentation.starts == 1, "no second intro")
			return presentation.corrected or 0
		end
		assert(scenario(true, true) == 0, "same outcome: nothing corrected")
		assert(scenario(false, true) == 1, "a different outcome is corrected")
	end)

	test("netsim parse / command: /netsim 300 50 5, /netsim off, clamps, junk ignored", function()
		local tree = offline.fresh("new")
		local NetSim = tree.require(tree.shared.DeckNetSim)
		assert(NetSim.command("/netsim 300 50 5") == "300,50,5")
		assert(NetSim.command("/NetSim 600") == "600,0,0")
		assert(NetSim.command("/netsim off") == false and NetSim.command("/netsim") == false)
		assert(NetSim.command("/netsim 99999 9999 90") == "3000,1000,50")
		assert(NetSim.command("hello") == nil and NetSim.command("/netsim fast") == nil)
		local c = NetSim.parse("300,50,5")
		assert(c.rtt == 300 and c.jitter == 50 and c.loss == 5)
		assert(NetSim.parse(nil) == nil and NetSim.parse("0,0,0") == nil and NetSim.parse("x") == nil)
		-- Ordered: a later push never leaves first, whatever the jitter.
		local link = NetSim.link({ rtt = 400, jitter = 300, loss = 20 }, 1, 3)
		for i = 1, 200 do link:push(i * 0.01, i) end
		local got = {}
		for t = 0, 10, 0.01 do for _, v in ipairs(link:due(t) or {}) do table.insert(got, v) end end
		assert(#got == 200, "all delivered")
		for i = 1, 200 do assert(got[i] == i, "in order") end
		assert(link.lost > 0 and link.maxDelay >= 0.1)
	end)

	return { passed = #cases, cases = cases }
end
