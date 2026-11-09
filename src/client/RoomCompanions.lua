local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local PetFollow = require(script.Parent.PetFollow)
local PetPrestige = require(script.Parent.PetPrestige)

local Companions = {}
Companions.__index = Companions

function Companions.new(boards, createPet, reduceEffects, options)
	return setmetatable({ players=options and options.players or function()return Players:GetPlayers()end,localRoot=options and options.localRoot,boards = boards, createPet = createPet, reduceEffects = reduceEffects, garden=options and options.garden,active = {}, refreshIn = 0 }, Companions)
end

function Companions:clear()
	for _, entry in pairs(self.active) do
		entry.visual:destroy()
	end
	table.clear(self.active)
	self.refreshIn = 0
end

function Companions:update(dt,serverNow)
    serverNow=serverNow or workspace:GetServerTimeNow()
	self.refreshIn -= dt
	if self.refreshIn <= 0 then
		self.refreshIn = 0.12
		local ownRoot = if self.localRoot then self.localRoot()else Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
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
				local mode=board and board:GetAttribute("Mode")
				local actor=pet and self.garden and self.garden:renderActor(player.UserId,pet.id,player.Character)
				if root and humanoid and humanoid.Health>0 and pet and (mode=="Room"or mode=="Board") and (root.Position - ownRoot.Position).Magnitude <= 72 then
					local rank, legacy = PetPrestige.read(board, pet)
					table.insert(near, { player = player, root = root, pet = pet, masteryMask = board:GetAttribute("MasteryMask") or 0, rank = rank, legacy = legacy,
						actor=actor,board=board,distance = (root.Position - ownRoot.Position).Magnitude })
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
			local appearance=if self.garden then self.garden:appearance(item.board,item.pet.id)else nil
			if not entry then
				local dock=item.actor and item.actor.care and item.actor.care.state=="Docked"
				local position = if dock then require(ReplicatedStorage.Shared.GardenActivity).vector(item.actor.to)else item.root.Position + item.root.CFrame.RightVector * 2.2
				local start=if dock then position else Vector3.new(position.X,4.025,position.Z)
				local visual = self.createPet(workspace, start, item.pet, item.masteryMask, item.rank, item.legacy,appearance,{priority=1})
				visual.cosmeticSeed=item.player.UserId
                visual.origin = if dock then start else Vector3.new(position.X, PetFollow.ground(position, visual), position.Z)
				if dock then require(script.Parent.PetCarePose).set(visual,"Docked");visual.yaw=item.actor.yaw or 0;visual:update(0)end
				visual.model:SetAttribute("CompanionOwnerId", item.player.UserId)
				entry = { visual = visual, pet = item.pet, masteryMask = item.masteryMask, rank = item.rank, legacy = item.legacy }
				self.active[item.player] = entry
			end
			if entry.root~=item.root then entry.followState=nil;PetFollow.rest(entry.visual)end
			entry.root,entry.actor = item.root,item.actor
			entry.board=item.board
			local appearanceKey=appearance and game:GetService("HttpService"):JSONEncode(appearance)
            if appearance and entry.visual.applyAppearance and entry.appearanceKey~=appearanceKey then
				entry.visual:applyAppearance(appearance);entry.charmVisible=appearance.charmVisible;entry.appearanceKey=appearanceKey
			end
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
		local actor=self.garden and self.garden:renderActor(entry.visual.model:GetAttribute("CompanionOwnerId"),entry.pet.id,entry.root.Parent)
		if actor then entry.followState=PetFollow.activity(entry.visual,actor,serverNow,dt,entry.followState,self.reduceEffects())
		elseif entry.board:GetAttribute("Mode")=="Board"then PetFollow.rest(entry.visual)
		else entry.followState = PetFollow.step(entry.visual, entry.root, dt, entry.followState,self.reduceEffects())end
		entry.visual.cosmeticTime=serverNow
        entry.visual:update(dt)
		PetPrestige.update(entry.visual, dt, self.reduceEffects())
	end
end

return Companions
