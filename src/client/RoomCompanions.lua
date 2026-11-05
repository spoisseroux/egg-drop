local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.PetCatalog)

local Companions = {}
Companions.__index = Companions

function Companions.new(boards, createPet, reduceEffects)
	return setmetatable({ boards = boards, createPet = createPet, reduceEffects = reduceEffects, active = {}, refreshIn = 0 }, Companions)
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
			for _, player in ipairs(Players:GetPlayers()) do
				if player == Players.LocalPlayer then
					continue
				end
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local board = self.boards:FindFirstChild(tostring(player.UserId))
				local pet = board and Pets.byId[board:GetAttribute("CompanionId")]
				if root and pet and (root.Position - ownRoot.Position).Magnitude <= 48 then
					table.insert(near, { player = player, root = root, pet = pet, masteryMask = board:GetAttribute("MasteryMask") or 0,
						distance = (root.Position - ownRoot.Position).Magnitude })
				end
			end
		end
		table.sort(near, function(a, b) return a.distance < b.distance end)
		local visible = {}
		for index = 1, math.min(6, #near) do
			local item = near[index]
			local entry = self.active[item.player]
			if entry and (entry.pet ~= item.pet or entry.masteryMask ~= item.masteryMask) then
				entry.visual:destroy()
				entry = nil
			end
			if not entry then
				local position = item.root.Position + item.root.CFrame.RightVector * 2.2
				local visual = self.createPet(workspace, Vector3.new(position.X, 4.02, position.Z), item.pet, item.masteryMask)
				visual.model:SetAttribute("CompanionOwnerId", item.player.UserId)
				entry = { visual = visual, pet = item.pet, masteryMask = item.masteryMask }
				self.active[item.player] = entry
			end
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
		local position = entry.root.Position + entry.root.CFrame.RightVector * 2.2
		entry.visual.origin = entry.visual.origin:Lerp(Vector3.new(position.X, 4.02, position.Z), 1 - math.exp(-7 * dt))
		entry.visual:update(dt)
		if entry.visual.masterySparkles then entry.visual.masterySparkles.Enabled = not self.reduceEffects() end
	end
end

return Companions
