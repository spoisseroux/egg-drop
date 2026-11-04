local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)

local Simulation = {}
local halfWidth = Config.Width / 2
local diagonal = 1 / math.sqrt(2)
local maxSpeed = 38

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

function Simulation.new(preset, serial)
	local board = { eggs = {}, preset = preset, serial = serial or 0, drops = 0 }
	for _, seed in ipairs(Config.Starter) do
		addEgg(board, Vector2.new(seed.x, Config.Tiers[seed.tier].radius), seed.tier)
	end
	return board
end

function Simulation.nextTier(board)
	return Config.Queue[board.drops % #Config.Queue + 1]
end

function Simulation.drop(board, aim)
	if #board.eggs >= Config.MaxEggs then
		return false
	end
	local tier = Simulation.nextTier(board)
	local position = Vector2.new(Config.aimX(aim, tier), Config.SpawnY)
	for _, egg in ipairs(board.eggs) do
		if (egg.position - position).Magnitude < egg.radius + Config.Tiers[tier].radius then
			return false
		end
	end
	addEgg(board, position, tier)
	board.drops += 1
	return true
end

local function recordImpact(impacts, egg, normal, speed)
	if impacts and speed >= 5 and (not impacts[egg.id] or speed > impacts[egg.id].speed) then
		impacts[egg.id] = { egg = egg, normal = normal, speed = speed }
	end
end

local function keepInside(egg, normal, distance, bounce, impacts)
	local overlap = egg.radius - distance
	if overlap <= 0 then
		return
	end
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
	keepInside(egg, Vector2.yAxis, egg.position.Y, bounce, impacts)
	keepInside(egg, -Vector2.yAxis, Config.Height - egg.position.Y, bounce, impacts)
	keepInside(egg, Vector2.new(diagonal, diagonal),
		(egg.position.X + halfWidth + egg.position.Y - Config.Bank) * diagonal, bounce, impacts)
	keepInside(egg, Vector2.new(-diagonal, diagonal),
		(halfWidth - egg.position.X + egg.position.Y - Config.Bank) * diagonal, bounce, impacts)
end

local function merge(board, firstIndex, secondIndex, preset)
	local first, second = board.eggs[firstIndex], board.eggs[secondIndex]
	local position = (first.position + second.position) / 2
	local velocity = (first.velocity + second.velocity) * 0.38 + Vector2.new(0, 2)
	table.remove(board.eggs, secondIndex)
	table.remove(board.eggs, firstIndex)
	local result = addEgg(board, position, first.tier + 1, velocity)
	collideWithTray(result, 0)

	for _, egg in ipairs(board.eggs) do
		if egg ~= result then
			local delta = egg.position - result.position
			local distance = delta.Magnitude
			if distance > 0 and distance < preset.reach then
				egg.velocity += delta.Unit * preset.kick * (1 - distance / preset.reach)
			end
		end
	end
	return result
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
				local normal = if distance > 0 then delta / distance else Vector2.xAxis
				local speed = (second.velocity - first.velocity):Dot(normal)
				if first.tier == second.tier and first.tier < #Config.Tiers then
					local egg = merge(board, firstIndex, secondIndex, preset)
					table.insert(merged, { egg = egg, from = first.position, other = second.position })
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
	local preset = Config.Presets[board.preset]
	for _, egg in ipairs(board.eggs) do
		local velocity = egg.velocity + Vector2.new(0, -Config.Gravity * dt)
		if velocity.Magnitude > maxSpeed then
			velocity = velocity.Unit * maxSpeed
		end
		egg.velocity = velocity * (1 - dt * 0.85)
		egg.position += egg.velocity * dt
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
