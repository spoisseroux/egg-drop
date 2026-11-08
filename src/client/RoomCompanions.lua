local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local PetFollow = require(script.Parent.PetFollow)
local PetPrestige = require(script.Parent.PetPrestige)

local Companions = {}
Companions.__index = Companions

function Companions.new(boards, createPet, reduceEffects, options)
	return setmetatable({ players=options and options.players or function()return Players:GetPlayers()end,boards = boards, createPet = createPet, reduceEffects = reduceEffects, active = {}, refreshIn = 0 }, Companions)
end

function Companions:clear()
	for _, entry in pairs(self.active) do
		entry.visual:destroy()
	end
	table.clear(self.active)
	self.refreshIn = 0
end

function Companions:update(dt)
	self.refreshIn -= dt
	if self.refreshIn <= 0 then
		self.refreshIn = 0.12
		local ownRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local near = {}
		if ownRoot then
			for _, player in ipairs(self.players()) do
				if player == Players.LocalPlayer then
					continue
				end
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				local board = self.boards:FindFirstChild(tostring(player.UserId))
				local pet = board and Pets.byId[board:GetAttribute("CompanionId")]
				if root and humanoid and humanoid.Health>0 and pet and board:GetAttribute("Mode") == "Room" and (root.Position - ownRoot.Position).Magnitude <= 72 then
					local rank, legacy = PetPrestige.read(board, pet)
					table.insert(near, { player = player, root = root, pet = pet, masteryMask = board:GetAttribute("MasteryMask") or 0, rank = rank, legacy = legacy,
						distance = (root.Position - ownRoot.Position).Magnitude })
				end
			end
		end
		table.sort(near, function(a, b) return a.distance < b.distance end)
		local visible = {}
		for index = 1, math.min(6, #near) do
			local item = near[index]
			local entry = self.active[item.player]
			if entry and (entry.pet ~= item.pet or entry.masteryMask ~= item.masteryMask or entry.rank ~= item.rank or entry.legacy ~= item.legacy) then
				entry.visual:destroy()
				entry = nil
			end
			if not entry then
				local position = item.root.Position + item.root.CFrame.RightVector * 2.2
				local visual = self.createPet(workspace, Vector3.new(position.X, 4.025, position.Z), item.pet, item.masteryMask, item.rank, item.legacy)
				visual.origin = Vector3.new(position.X, PetFollow.ground(position, visual), position.Z)
				visual.model:SetAttribute("CompanionOwnerId", item.player.UserId)
				entry = { visual = visual, pet = item.pet, masteryMask = item.masteryMask, rank = item.rank, legacy = item.legacy }
				self.active[item.player] = entry
			end
			if entry.root~=item.root then entry.followState=nil;PetFollow.rest(entry.visual)end
			entry.root = item.root
			visible[item.player] = true
		end
		for player, entry in pairs(self.active) do
			if not visible[player] then
				entry.visual:destroy()
				self.active[player] = nil
			end
		end
	end
	for _, entry in pairs(self.active) do
		if not entry.root.Parent then continue end
		entry.followState = PetFollow.step(entry.visual, entry.root, dt, entry.followState,self.reduceEffects())
		entry.visual:update(dt)
		PetPrestige.update(entry.visual, dt, self.reduceEffects())
	end
end

return Companions
