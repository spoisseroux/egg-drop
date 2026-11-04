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

function Simulation.new(preset)
	local board = { eggs = {}, preset = preset, serial = 0, drops = 0 }
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

local function keepInside(egg, normal, distance, bounce)
	local overlap = egg.radius - distance
	if overlap <= 0 then
		return
	end
	egg.position += normal * overlap
	local speed = egg.velocity:Dot(normal)
	if speed < 0 then
		egg.velocity -= normal * speed * (1 + (speed < -1.8 and bounce or 0))
	end
end

local function collideWithTray(egg, bounce)
	keepInside(egg, Vector2.xAxis, egg.position.X + halfWidth, bounce)
	keepInside(egg, -Vector2.xAxis, halfWidth - egg.position.X, bounce)
	keepInside(egg, Vector2.yAxis, egg.position.Y, bounce)
	keepInside(egg, -Vector2.yAxis, Config.Height - egg.position.Y, bounce)
	keepInside(egg, Vector2.new(diagonal, diagonal),
		(egg.position.X + halfWidth + egg.position.Y - Config.Bank) * diagonal, bounce)
	keepInside(egg, Vector2.new(-diagonal, diagonal),
		(halfWidth - egg.position.X + egg.position.Y - Config.Bank) * diagonal, bounce)
end

local function merge(board, firstIndex, secondIndex, kick)
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
			if distance > 0 and distance < 4 then
				egg.velocity += delta.Unit * kick * (1 - distance / 4)
			end
		end
	end
	return result
end

local function resolvePairs(board, preset, merged)
	local eggs = board.eggs
	for firstIndex = 1, #eggs - 1 do
		local first = eggs[firstIndex]
		for secondIndex = firstIndex + 1, #eggs do
			local second = eggs[secondIndex]
			local delta = second.position - first.position
			local distance = delta.Magnitude
			local overlap = first.radius + second.radius - distance
			if overlap > 0 then
				if first.tier == second.tier and first.tier < #Config.Tiers then
					table.insert(merged, merge(board, firstIndex, secondIndex, preset.kick))
					return true
				end
				local normal = if distance > 0 then delta / distance else Vector2.xAxis
				first.position -= normal * (overlap / 2)
				second.position += normal * (overlap / 2)
				local speed = (second.velocity - first.velocity):Dot(normal)
				if speed < 0 then
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

function Simulation.step(board, dt, merged)
	local preset = Config.Presets[board.preset]
	for _, egg in ipairs(board.eggs) do
		local velocity = egg.velocity + Vector2.new(0, -Config.Gravity * dt)
		if velocity.Magnitude > maxSpeed then
			velocity = velocity.Unit * maxSpeed
		end
		egg.velocity = velocity * (1 - dt * 0.85)
		egg.position += egg.velocity * dt
		collideWithTray(egg, preset.bounce)
	end
	-- Each successful merge removes a pair before the next scan.
	for _ = 1, 3 do
		local didMerge = resolvePairs(board, preset, merged)
		for _, egg in ipairs(board.eggs) do
			collideWithTray(egg, preset.bounce)
		end
		if not didMerge then
			break
		end
	end
end

return Simulation
