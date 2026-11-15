-- QA v685 R6: the reward-free visitor hello (src/server/PetHello.lua + PetHelloRules).
-- Pure: a fake garden and clock; no remotes, no saves.
-- Run (Server): require(game.ServerScriptService.Server.ZZSpecs.PetHello)(game.ServerScriptService.Server)
return function(server)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Rules = require(Shared.PetHelloRules)
	local Hello = require(server.PetHello)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end

	local function world()
		local w = { now = 100, published = {}, off = {}, blocked = false }
		w.viewers = { [1] = Vector3.new(3, 4, 0), [3] = Vector3.new(-3, 4, 0) }
		w.garden = {
			actors = { [2] = { ownerId = 2, petId = "bear", characterId = 7, petGeneration = 4, generation = 9, mode = "Room", behavior = "follow", endTime = 90 } },
			inputs = { [2] = { alive = true, owned = true, petId = "bear", characterId = 7, petGeneration = 4 } },
			position = function() return Vector3.new(0, 4, 0) end,
		}
		w.hello = Hello.new({ now = function() return w.now end, garden = w.garden,
			viewer = function(id) return w.viewers[id] end,
			allowed = function(id) return not w.off[id] end,
			clear = function() return not w.blocked end,
			publish = function(id, hello) table.insert(w.published, { id = id, hello = hello or false }) end })
		return w
	end
	local function packet(seq, overrides)
		local p = { seq = seq, ownerId = 2, petId = "bear", characterId = 7, petGeneration = 4 }
		for key, value in pairs(overrides or {}) do p[key] = value end
		return p
	end

	test("an idle pet in reach accepts one hello and publishes only the small wave record", function()
		local w = world()
		local r = w.hello:request(1, packet(1))
		assert(r.status == "Accepted" and r.seq == 1 and r.duration == Rules.Duration and r.at == 100)
		assert(#w.published == 1 and w.published[1].id == 2)
		local record = w.published[1].hello
		local keys = 0
		for _ in pairs(record) do keys += 1 end
		assert(keys == 5 and record.from == 1 and record.at == 100 and record.petId == "bear" and record.petGeneration == 4 and type(record.id) == "number")
	end)

	test("malformed, own-pet and stale requests are refused without a wave", function()
		local w = world()
		for _, bad in ipairs({ false, {}, packet(0), packet(1.5), packet(1, { ownerId = "2" }), packet(1, { petId = string.rep("x", 33) }), packet(1, { characterId = -1 }) }) do
			w.now += 1
			local r = w.hello:request(1, bad)
			assert(r.status == "Rejected" and r.reason == "Malformed", "expected Malformed")
		end
		w.now += 1
		assert(w.hello:request(2, packet(1)).reason == "Own")
		for _, stale in ipairs({ { petId = "pip" }, { characterId = 8 }, { petGeneration = 5 }, { ownerId = 44 } }) do
			w.now += 1
			assert(w.hello:request(1, packet(2, stale)).reason == "Stale")
		end
		w.now += 1; w.garden.inputs[2].alive = false
		assert(w.hello:request(1, packet(3)).reason == "Stale")
		assert(#w.published == 0)
	end)

	test("consent off, distance, a busy pet and a wall each refuse", function()
		local w = world()
		w.off[2] = true
		assert(w.hello:request(1, packet(1)).reason == "Off")
		w.off[2] = nil; w.now += 1
		w.viewers[1] = Vector3.new(Rules.HelloRange + .1, 4, 0)
		assert(w.hello:request(1, packet(2)).reason == "Far")
		w.viewers[1] = Vector3.new(3, 4 + Rules.HeightReach + .1, 0); w.now += 1
		assert(w.hello:request(1, packet(3)).reason == "Far")
		w.viewers[1] = nil; w.now += 1
		assert(w.hello:request(1, packet(4)).reason == "Unavailable")
		w.viewers[1] = Vector3.new(3, 4, 0)
		local actor = w.garden.actors[2]
		for _, busy in ipairs({ { mode = "Focus" }, { mode = "Carried" }, { mode = "Board" }, { care = { state = "Docked" } }, { pairId = 3 }, { toyActionId = 5 },
			{ park = { state = "swing" } }, { behavior = "investigate" }, { behavior = "play" }, { action = "greet" }, { endTime = 1e9 } }) do
			local saved = {}
			for key, value in pairs(busy) do saved[key] = actor[key]; actor[key] = value end
			w.now += 1
			assert(w.hello:request(1, packet(5)).reason == "Busy", "expected Busy")
			for key in pairs(busy) do actor[key] = saved[key] end
		end
		w.blocked = true; w.now += 1
		assert(w.hello:request(1, packet(6)).reason == "Blocked")
		assert(#w.published == 0)
		-- A park pet standing idle, and a resting pet, may wave.
		w.blocked = false; actor.park = { state = "idle" }; actor.behavior, actor.action = "rest", "nookRest"; w.now += 1
		assert(w.hello:request(1, packet(7)).status == "Accepted")
	end)

	test("rate limits: 5 s per viewer, 10 s per target, 30 s per pair; spam is dropped", function()
		local w = world()
		assert(w.hello:request(1, packet(1)).status == "Accepted")
		-- Closer than MinGap: no reply at all.
		w.now += Rules.MinGap * .5
		assert(w.hello:request(1, packet(2)) == nil)
		w.now = 100 + 1
		local r = w.hello:request(1, packet(3))
		assert(r.reason == "Cooldown" and r.retryIn > 28 and r.retryIn <= Rules.PairCooldown)
		-- Another viewer still waits out the target's 10 s.
		w.now = 100 + Rules.TargetCooldown - 1
		assert(w.hello:request(3, packet(1)).reason == "Cooldown")
		w.now = 100 + Rules.TargetCooldown
		assert(w.hello:request(3, packet(2)).status == "Accepted")
		-- The first viewer's pair cooldown outlasts the viewer and target ones.
		w.now = 100 + Rules.PairCooldown - .5
		assert(w.hello:request(1, packet(4)).reason == "Cooldown")
		w.now = 100 + Rules.PairCooldown
		assert(w.hello:request(1, packet(5)).status == "Accepted")
		assert(#w.published == 3)
	end)

	test("the owner wins: focus, a pet swap or greetings off withdraws a running wave", function()
		for _, change in ipairs({ function(w) w.garden.actors[2].mode = "Focus" end, function(w) w.garden.actors[2].petGeneration = 5 end,
			function(w) w.garden.actors[2] = nil end, function(w) w.off[2] = true end, function(w) w.garden.actors[2].care = {} end }) do
			local w = world()
			assert(w.hello:request(1, packet(1)).status == "Accepted")
			w.now += .3; w.hello:step()
			assert(#w.published == 1, "an untouched wave keeps its record")
			change(w); w.hello:step()
			assert(#w.published == 2 and w.published[2].hello == false, "the wave is withdrawn")
			w.hello:step()
			assert(#w.published == 2)
		end
		-- A finished wave is left alone (clients time it out).
		local w = world()
		w.hello:request(1, packet(1)); w.now += Rules.Duration + .1; w.hello:step()
		w.garden.actors[2].mode = "Focus"; w.hello:step()
		assert(#w.published == 1)
		-- cancel() and remove() withdraw too, and remove() forgets the leaver's cooldowns.
		w = world()
		w.hello:request(1, packet(1)); w.hello:cancel(2)
		assert(#w.published == 2 and w.published[2].hello == false)
		w.hello:remove(1); w.now += 11
		assert(w.hello:request(1, packet(2)).status == "Accepted", "a rejoined viewer starts clean")
	end)

	test("Rules.free and validPacket are the shared truth", function()
		assert(Rules.free({ mode = "Room", behavior = "follow", endTime = 5 }, 6))
		assert(not Rules.free({ mode = "Room", behavior = "follow", endTime = 5 }, 4))
		assert(Rules.free({ mode = "Room", behavior = "rest", action = "wanderPause" }, 0))
		assert(not Rules.free({ mode = "Room", behavior = "rest", action = "focus" }, 0))
		assert(not Rules.free({ mode = "Room", behavior = "follow", peerId = 3 }, 0) and not Rules.free(nil, 0))
		assert(Rules.validPacket({ seq = 1, ownerId = 5, petId = "bear", characterId = 0, petGeneration = 0 }))
		assert(not Rules.validPacket({ seq = 1, ownerId = 5, petId = "", characterId = 0, petGeneration = 0 }))
		assert(Rules.Duration == 1.3 and Rules.InspectRange == 12 and Rules.HelloRange == 7)
	end)

	return cases
end
