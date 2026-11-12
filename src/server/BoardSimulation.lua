local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)

local Simulation = {}
local halfWidth = Config.Width / 2
local diagonal = 1 / math.sqrt(2)

local function addEgg(board, position, tier, velocity)
	board.serial += 1
	local egg = {
		id = board.serial,
		position = position,
		velocity = velocity or Vector2.zero,
		tier = tier,
		radius = Config.Tiers[tier].radius,
	}
	table.insert(board.eggs, egg)
	return egg
end

function Simulation.new(preset, serial, options)
	options = options or {}
	local board = { eggs = {}, preset = preset, serial = serial or 0, drops = 0 }
	board.contactGate = options.contactGate == true
	board.dropAge = 0
	if options.seed ~= nil then
		local random = Random.new(options.seed)
		board.queue = {}
		for _ = 1, 4 do
			local bag = table.clone(options.bag or { 1, 1, 1, 1, 2, 2 })
			for index = #bag, 2, -1 do
				local other = random:NextInteger(1, index)
				bag[index], bag[other] = bag[other], bag[index]
			end
			for _, tier in ipairs(bag) do table.insert(board.queue, tier) end
		end
		board.seed = options.seed
	end
	if options.kick ~= nil or options.bounce~=nil then
		board.physics = table.clone(Config.Presets[preset])
		if options.kick~=nil then board.physics.kick = options.kick end
		if options.bounce~=nil then board.physics.bounce=options.bounce end
	end
	for _, seed in ipairs(options.starter or Config.Starter) do
		addEgg(board, Vector2.new(seed.x, Config.Tiers[seed.tier].radius), seed.tier)
	end
	return board
end

function Simulation.nextTier(board, lookahead)
	local queue = board.queue or Config.Queue
	return queue[(board.drops + (lookahead or 0)) % #queue + 1]
end

function Simulation.canDrop(board)
	if not board.contactGate or not board.fallingId or board.dropAge >= 1.8 then return true end
	for _, egg in ipairs(board.eggs) do
		if egg.id == board.fallingId then return egg.hasContact == true end
	end
	-- A merge consumed the falling piece.
	return true
end

function Simulation.drop(board, aim)
	if not Config.validAim(aim) or #board.eggs >= Config.MaxEggs or not Simulation.canDrop(board) then
		return false
	end
	local tier = Simulation.nextTier(board)
	local position = Config.launchPosition()
	for _, egg in ipairs(board.eggs) do
		if (egg.position - position).Magnitude < egg.radius + Config.Tiers[tier].radius then
			return false
		end
	end
	local dropped = addEgg(board, position, tier, Config.launchVelocity(aim))
	board.fallingId, board.dropAge = dropped.id, 0
	board.drops += 1
	return true
end

local function recordImpact(impacts, egg, normal, speed)
	if impacts and speed >= 5 and (not impacts[egg.id] or speed > impacts[egg.id].speed) then
		impacts[egg.id] = { egg = egg, normal = normal, speed = speed }
	end
end

local function keepInside(egg, normal, distance, bounce, impacts, contact)
	local overlap = egg.radius - distance
	if overlap <= 0 then
		return
	end
	if contact then egg.hasContact = true end
	egg.position += normal * overlap
	local speed = egg.velocity:Dot(normal)
	if speed < 0 then
		recordImpact(impacts, egg, normal, -speed)
		egg.velocity -= normal * speed * (1 + (speed < -1.8 and bounce or 0))
	end
end

local function collideWithTray(egg, bounce, impacts)
	keepInside(egg, Vector2.xAxis, egg.position.X + halfWidth, bounce, impacts)
	keepInside(egg, -Vector2.xAxis, halfWidth - egg.position.X, bounce, impacts)
	keepInside(egg, Vector2.yAxis, egg.position.Y, bounce, impacts, true)
	keepInside(egg, -Vector2.yAxis, Config.Height - egg.position.Y, bounce, impacts)
	keepInside(egg, Vector2.new(diagonal, diagonal),
		(egg.position.X + halfWidth + egg.position.Y - Config.Bank) * diagonal, bounce, impacts, true)
	keepInside(egg, Vector2.new(-diagonal, diagonal),
		(halfWidth - egg.position.X + egg.position.Y - Config.Bank) * diagonal, bounce, impacts, true)
end

local function merge(board, firstIndex, secondIndex, preset)
	local first, second = board.eggs[firstIndex], board.eggs[secondIndex]
	local position = (first.position + second.position) / 2
	local velocity = (first.velocity + second.velocity) * 0.38 + Vector2.new(0, 2)
	table.remove(board.eggs, secondIndex)
	table.remove(board.eggs, firstIndex)
	local cleared = first.tier == #Config.Tiers
	local result
	if not cleared then
		result = addEgg(board, position, first.tier + 1, velocity)
		collideWithTray(result, 0)
		position = result.position
	end

	for _, egg in ipairs(board.eggs) do
		if egg ~= result then
			local delta = egg.position - position
			local distance = delta.Magnitude
			if distance > 0 and distance < preset.reach then
				egg.velocity += delta.Unit * preset.kick * (1 - distance / preset.reach)
			end
		end
	end
	return {
		position = position, tier = if result then result.tier else first.tier,
		from = first.position, other = second.position, id = if result then result.id else nil,
		cleared = cleared,
	}
end

local function resolvePairs(board, preset, merged, impacts)
	local eggs = board.eggs
	for firstIndex = 1, #eggs - 1 do
		local first = eggs[firstIndex]
		for secondIndex = firstIndex + 1, #eggs do
			local second = eggs[secondIndex]
			local delta = second.position - first.position
			local distance = delta.Magnitude
			local overlap = first.radius + second.radius - distance
			if overlap > 0 then
				first.hasContact, second.hasContact = true, true
				local normal = if distance > 0 then delta / distance else Vector2.xAxis
				local speed = (second.velocity - first.velocity):Dot(normal)
				if first.tier == second.tier then
					table.insert(merged, merge(board, firstIndex, secondIndex, preset))
					return true
				end
				first.position -= normal * (overlap / 2)
				second.position += normal * (overlap / 2)
				if speed < 0 then
					recordImpact(impacts, first, -normal, -speed)
					recordImpact(impacts, second, normal, -speed)
					local bounce = if speed < -1.8 then preset.bounce else 0
					local impulse = normal * (speed * (1 + bounce) / 2)
					first.velocity += impulse
					second.velocity -= impulse
				end
			end
		end
	end
	return false
end

function Simulation.step(board, dt, merged, impacts)
	local preset = board.physics or Config.Presets[board.preset]
	board.dropAge = (board.dropAge or 0) + dt
	for _, egg in ipairs(board.eggs) do
		egg.position,egg.velocity=Config.advanceFlight(egg.position,egg.velocity,dt)
		collideWithTray(egg, preset.bounce, impacts)
	end
	-- Each successful merge removes a pair before the next scan.
	for _ = 1, 3 do
		local didMerge = resolvePairs(board, preset, merged, impacts)
		for _, egg in ipairs(board.eggs) do
			collideWithTray(egg, preset.bounce, impacts)
		end
		if not didMerge then
			break
		end
	end
end

return Simulation
