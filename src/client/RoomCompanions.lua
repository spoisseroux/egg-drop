local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local PetFollow = require(script.Parent.PetFollow)
local PetPrestige = require(script.Parent.PetPrestige)
local Layout = require(ReplicatedStorage.Shared.GardenLayout)
local Flags = require(ReplicatedStorage.Shared.FeatureFlags)

local Companions = {}
Companions.__index = Companions
-- Distance tiers (Pet Park K3, only with FeatureFlags.Park): the nearest ObserverCap (6) pets within
-- ObserverDistance (72) get full updates; up to MaxRendered get a lite update instead: position and
-- facing at LiteHz with the cached pose frozen (no charm or face animation, no prestige effects).
-- Flag off: exactly the old rule (6 nearest within 72, all full).
Companions.MaxRendered = 11
Companions.LiteHz = 10
Companions.LiteCadence = .001 -- PetPoseSampler re-samples the expressive pose once per ~1000 s

function Companions.new(boards, createPet, reduceEffects, options)
	return setmetatable({ tiers=if options and options.tiers~=nil then options.tiers==true else Flags.Park==true,
		players=options and options.players or function()return Players:GetPlayers()end,localRoot=options and options.localRoot,boards = boards, createPet = createPet, reduceEffects = reduceEffects, garden=options and options.garden,active = {}, refreshIn = 0 }, Companions)
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
				if root and humanoid and humanoid.Health>0 and pet and (mode=="Room"or mode=="Board") and (root.Position - ownRoot.Position).Magnitude <= Layout.ObserverDistance then
					local rank, legacy = PetPrestige.read(board, pet)
					table.insert(near, { player = player, root = root, pet = pet, masteryMask = board:GetAttribute("MasteryMask") or 0, rank = rank, legacy = legacy,
						actor=actor,board=board,distance = (root.Position - ownRoot.Position).Magnitude })
				end
			end
		end
		table.sort(near, function(a, b) return a.distance < b.distance end)
		local visible = {}
		local cap = if self.tiers then Companions.MaxRendered else Layout.ObserverCap
		for index = 1, math.min(cap, #near) do
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
			entry.full=index<=Layout.ObserverCap
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
		local step=dt
		if entry.full==false then
			entry.liteDt=(entry.liteDt or 0)+dt
			if entry.liteDt<1/Companions.LiteHz then continue end
			step=math.min(entry.liteDt,.25);entry.liteDt=0
			if not entry.liteCadence then entry.liteCadence=entry.visual.poseCadence;entry.visual.poseCadence=Companions.LiteCadence end
			if entry.visual.poseSlots then entry.visual.poseDirty=false end
		elseif entry.liteCadence then
			entry.visual.poseCadence=entry.liteCadence;entry.liteCadence=nil;entry.liteDt=nil;entry.visual.poseDirty=true
		end
		local actor=self.garden and self.garden:renderActor(entry.visual.model:GetAttribute("CompanionOwnerId"),entry.pet.id,entry.root.Parent)
		entry.visual.personalPlayEnabled=actor~=nil and actor.mode=="Room"and entry.board:GetAttribute("Mode")=="Room"
        entry.visual.personalActorIdentity=actor and(tostring(actor.characterId)..":"..tostring(actor.petGeneration))or nil
        entry.visual.personalIdleUntil=if actor and actor.behavior=="follow"then actor.endTime+3.5 else 0
		if actor and self.park then entry.followState=self.park:drive(entry.visual,actor,serverNow,step,entry.followState,self.reduceEffects())
		elseif actor then entry.followState=PetFollow.activity(entry.visual,actor,serverNow,step,entry.followState,self.reduceEffects())
		elseif entry.board:GetAttribute("Mode")=="Board"then PetFollow.rest(entry.visual)
		else entry.followState = PetFollow.step(entry.visual, entry.root, step, entry.followState,self.reduceEffects())end
		entry.visual.cosmeticTime=serverNow
        entry.visual:update(step)
		if entry.full~=false then PetPrestige.update(entry.visual, step, self.reduceEffects()) end
	end
end

return Companions
