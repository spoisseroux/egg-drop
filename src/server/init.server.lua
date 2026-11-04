local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Simulation = require(script.BoardSimulation)

local function child(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = child("RemoteEvent", "BoardRequest", remotes)
local feedback = child("RemoteEvent", "BoardMerge", remotes)
local trays = child("Folder", "EggDropBoards", ReplicatedStorage)
local boards = {}

local function publishState(board)
	board.folder:SetAttribute("Preset", board.sim.preset)
	board.folder:SetAttribute("Drops", board.sim.drops)
	board.folder:SetAttribute("NextTier", Simulation.nextTier(board.sim))
	board.folder:SetAttribute("Merges", board.merges)
	board.folder:SetAttribute("Chain", board.chain)
end

local function syncVisuals(board)
	local live = {}
	for _, egg in ipairs(board.sim.eggs) do
		live[egg.id] = true
		local part = board.parts[egg.id]
		if not part then
			part = Instance.new("Part")
			part.Name = "Egg_" .. egg.id
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.one * egg.radius * 2
			part.Color = Config.Tiers[egg.tier].color
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part:SetAttribute("Tier", egg.tier)
			board.parts[egg.id] = part
		end
		local position = Vector3.new(egg.position.X, egg.position.Y, 0)
		if part.Position ~= position then
			part.Position = position
		end
		if not part.Parent then
			part.Parent = board.folder
		end
	end
	for id, part in pairs(board.parts) do
		if not live[id] then
			part:Destroy()
			board.parts[id] = nil
		end
	end
end

local function reset(board, preset)
	board.folder:ClearAllChildren()
	table.clear(board.parts)
	board.sim = Simulation.new(preset)
	board.merges = 0
	board.chain = 0
	board.lastMerge = -math.huge
	publishState(board)
	syncVisuals(board)
end

local function addPlayer(player)
	if boards[player] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = tostring(player.UserId)
	local board = {
		folder = folder,
		parts = {},
		lastDrop = -math.huge,
		lastReset = -math.huge,
	}
	boards[player] = board
	reset(board, Config.DefaultPreset)
	folder.Parent = trays
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local board = boards[player]
	if board then
		board.folder:Destroy()
		boards[player] = nil
	end
end)
for _, player in ipairs(Players:GetPlayers()) do
	addPlayer(player)
end

request.OnServerEvent:Connect(function(player, action, value)
	local board = boards[player]
	if not board then
		return
	end
	local now = os.clock()
	if action == "drop" then
		if typeof(value) ~= "number" or not (value >= 0 and value <= 1)
			or now - board.lastDrop < Config.DropInterval then
			return
		end
		board.lastDrop = now
		if Simulation.drop(board.sim, value) then
			publishState(board)
		end
	elseif action == "reset" or action == "preset" then
		if now - board.lastReset < Config.ResetInterval then
			return
		end
		local preset = board.sim.preset
		if action == "preset" then
			if typeof(value) ~= "string" or not Config.Presets[value] then
				return
			end
			preset = value
		end
		board.lastReset = now
		reset(board, preset)
	end
end)

local accumulator = 0
local merged = {}
RunService.Heartbeat:Connect(function(dt)
	accumulator = math.min(accumulator + dt, Config.FixedStep * 8)
	while accumulator >= Config.FixedStep do
		accumulator -= Config.FixedStep
		for player, board in pairs(boards) do
			table.clear(merged)
			Simulation.step(board.sim, Config.FixedStep, merged)
			for _, egg in ipairs(merged) do
				local now = os.clock()
				board.chain = if now - board.lastMerge <= 1.25 then board.chain + 1 else 1
				board.lastMerge = now
				board.merges += 1
				feedback:FireClient(player, egg.position, egg.tier, board.chain)
			end
			if #merged > 0 then
				publishState(board)
			end
		end
	end
	for _, board in pairs(boards) do
		syncVisuals(board)
	end
end)
