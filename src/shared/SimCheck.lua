-- Board sim determinism check (B0 of the client-run board, B0-plan.md). Three seeded input
-- logs replayed through BoardSim; the server and a client must get the same hash list.
-- Shared by scripts/BoardSimDeterminism.spec.lua (Studio, both datamodels) and the owner-only
-- phone check (FeatureFlags.SimCheck: src/client/SimCheckClient.lua, src/server/SimCheckHost.lua),
-- so every side runs the identical logs and code.
local RunService = game:GetService("RunService")
local Shared = script.Parent
local Config = require(Shared.BoardConfig)
local Sim = require(Shared.BoardSim)

local Check = {}
Check.Version = 1 -- bump when the logs, the sim rules or the hash change
Check.HashEvery = 60
Check.SettleTicks = 600
Check.Drops = 24
Check.MaxHashesPerLog = 128

-- Three round setups: a medium field (Springy), a hard field (Gentle, stars), and a starter
-- board with field-style dynamics overrides.
Check.Setups = table.freeze({
	table.freeze({ logSeed = 40001, boardSeed = 912345, preset = "Springy", heat = "medium", starter = false }),
	table.freeze({ logSeed = 51234, boardSeed = 300007, preset = "Gentle", heat = "hard", starter = false }),
	table.freeze({ logSeed = 77777, boardSeed = 64, preset = "Springy", heat = "easy", starter = true, kick = 9, bounce = 0.64 * 0.8 }),
})

-- One input log: 24 drops on the aim grid with 50-160 tick gaps (the 72-tick contact gate refuses some), plus a swap, a bomb, a
-- pop and a magnet at seeded drop numbers. Integers only (aim = index / AimSteps).
function Check.makeLog(setup)
	local random = Random.new(setup.logSeed)
	local inputs, tick = {}, 30
	local swapAt, bombAt = random:NextInteger(3, 7), random:NextInteger(8, 12)
	local popAt, magnetAt = random:NextInteger(13, 17), random:NextInteger(18, 22)
	for drop = 1, Check.Drops do
		if drop == swapAt then table.insert(inputs, { tick = tick - 4, kind = "swap" }) end
		if drop == bombAt then table.insert(inputs, { tick = tick - 3, kind = "arm", item = "bomb" }) end
		if drop == magnetAt then table.insert(inputs, { tick = tick - 3, kind = "arm", item = "magnet" }) end
		local index = random:NextInteger(0, Sim.AimSteps)
		table.insert(inputs, { tick = tick, kind = "drop", aim = index / Sim.AimSteps })
		if drop == popAt then table.insert(inputs, { tick = tick + 20, kind = "pop" }) end
		tick += random:NextInteger(50, 160)
	end
	local options = {
		starter = if setup.starter then nil else {}, contactGate = true,
		bag = Config.Heat[setup.heat].bag, powerUps = setup.heat,
		kick = setup.kick, bounce = setup.bounce, hashEvery = Check.HashEvery,
	}
	return { seed = setup.boardSeed, preset = setup.preset, inputs = inputs, ticks = tick + Check.SettleTicks, options = options }
end

function Check.logs()
	local logs = {}
	for _, setup in ipairs(Check.Setups) do table.insert(logs, Check.makeLog(setup)) end
	return logs
end

-- Replays every log. yield (optional) is called every yieldEvery ticks so the work spreads
-- over frames. Returns { hashes = { {...}, {...}, {...} }, results = {...}, seconds }.
function Check.run(yield, yieldEvery)
	local started = os.clock()
	local busy = 0
	local hashes, results = {}, {}
	for _, log in ipairs(Check.logs()) do
		local options = table.clone(log.options)
		if yield then
			local chunk = os.clock()
			options.yieldEvery = yieldEvery or 60
			options.yield = function()
				busy += os.clock() - chunk
				yield()
				chunk = os.clock()
			end
		end
		local result = Sim.replay(log.seed, log.preset, log.inputs, log.ticks, options)
		table.insert(hashes, result.hashes)
		table.insert(results, { ticks = log.ticks, accepted = result.accepted, refused = result.refused,
			balls = #result.board.eggs, drops = result.board.drops, final = result.final })
	end
	return { hashes = hashes, results = results, seconds = if yield then busy else os.clock() - started }
end

-- One digest over all lists (for a short log line).
function Check.digest(hashes)
	local parts = {}
	for _, list in ipairs(hashes) do table.insert(parts, table.concat(list, ",")) end
	return Sim.hashBytes(table.concat(parts, ";"))
end

-- A client's report: exactly one list per log, each of at most MaxHashesPerLog 16-hex strings.
function Check.validReport(report)
	if type(report) ~= "table" or report.version ~= Check.Version or type(report.hashes) ~= "table" then return false end
	if #report.hashes ~= #Check.Setups then return false end
	for _, list in ipairs(report.hashes) do
		if type(list) ~= "table" or #list < 1 or #list > Check.MaxHashesPerLog then return false end
		for _, hash in ipairs(list) do
			if type(hash) ~= "string" or #hash ~= 16 or not hash:match("^%x+$") then return false end
		end
	end
	return true
end

-- First difference: nil when every list matches, else { log = n, index = i }.
function Check.compare(expected, actual)
	for log, list in ipairs(expected) do
		local other = actual[log] or {}
		for index = 1, math.max(#list, #other) do
			if list[index] ~= other[index] then return { log = log, index = index } end
		end
	end
	return nil
end

-- The experience creator (user, or rank 255 in the owning group); anyone in Studio. Yields
-- for a group creator (GetRankInGroup).
-- Spencer's test accounts besides the creator (keehar01): his phone plays as solidSkunk.
Check.Testers = table.freeze({ [2288285049] = true })
function Check.isOwner(player)
	if RunService:IsStudio() then return true end
	if Check.Testers[player.UserId] then return true end
	if game.CreatorType == Enum.CreatorType.User then return player.UserId == game.CreatorId end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and rank == 255
	end
	return false
end

return table.freeze(Check)
