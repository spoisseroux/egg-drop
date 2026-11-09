local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Themes = require(ReplicatedStorage.Shared.DeckThemes)
local Stickers = require(ReplicatedStorage.Shared.DeckStickers)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Settings = require(ReplicatedStorage.Shared.DeckSettings)
local Simulation = require(script.BoardSimulation)
local Round = require(script.BoardRound)
local Lounge = require(script.Lounge)
local Progress = require(script.PlayerProgress)
local FirstSession = require(script.FirstSession)
local FieldRun = require(script.FieldRun)
local FieldObjectives = require(ReplicatedStorage.Shared.FieldObjectives)
local PetContactController = require(script.PetContact)
local Daily = require(ReplicatedStorage.Shared.DailyContracts)
local Nursery = require(script.HatchProgress)
local HueState = require(script.HueState)
local NurseryCatalog = require(ReplicatedStorage.Shared.EggCatalog)
local FamilyMastery = require(ReplicatedStorage.Shared.FamilyMastery)
local CloseProgress = require(script.CloseProgress)
local SessionProfile = require(script.SessionProfile)
local RunReturn = require(script.RunReturn)
local AppearanceIntent = require(script.AppearanceIntent)
local AppearanceCatalog = require(ReplicatedStorage.Shared.AppearanceCatalog)
local Backgrounds = require(ReplicatedStorage.Shared.DeckBackgrounds)
local GardenState = require(script.GardenState)
local GardenLayout = require(ReplicatedStorage.Shared.GardenLayout)
local GardenActivity = require(ReplicatedStorage.Shared.GardenActivity)
local PetAppearance = require(script.PetAppearance)

local function child(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = child("RemoteEvent", "BoardRequest", remotes)
local feedback = child("RemoteEvent", "BoardMerge", remotes)
local impactsRemote = child("RemoteEvent", "BoardImpact", remotes)
local nurseryRequest = child("RemoteEvent", "HatchRequest", remotes)
local nurseryFeedback = child("RemoteEvent", "HatchFeedback", remotes)
local nurserySnapshot = child("RemoteEvent", "NurserySnapshot", remotes)
local hueResult = child("RemoteEvent", "HueResult", remotes)
local appearanceResult = child("RemoteEvent", "AppearanceResult", remotes)
local petContactRemote = child("RemoteEvent", "PetContact", remotes)
local gardenIntentRemote = child("RemoteEvent", "GardenIntent", remotes)
local petAppearanceResult = child("RemoteEvent", "PetAppearanceResult", remotes)
local gardenShared = child("Folder", "GardenState", ReplicatedStorage)
local trays = child("Folder", "EggDropBoards", ReplicatedStorage)
local boards = {}
local loading = {}
local closing = {}
local nextSlot = 0
Lounge.create()

local function inventory(board)
	return board.nursery.state.inventoryMask
end

local function hasPip(board)
	return NurseryCatalog.isOwned(inventory(board), "pip")
end

local function canProgress(board)
	return board.profileReady and SessionProfile.ready(board.nursery, board.nurseryBusy)
end

local function petState(board)
	local character=board.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local handle,state=board.nursery,board.nursery.state
	local petId=board.profile.companionId
	local today=Daily.dayOf(handle.adapter.now())
	return {mode=board.mode,closing=board.closing,petId=petId,owned=NurseryCatalog.isOwned(state.inventoryMask,petId),
		character=character,root=root,position=root and root.Position,epoch=handle.epoch,status=handle.status,
		alive=humanoid~=nil and humanoid.Health>0 and root~=nil and character:IsDescendantOf(workspace),
		ready=canProgress(board)and not handle.busy and not handle.pending,
		busy=handle.busy or board.nurseryBusy,pendingId=handle.pending and handle.pending.id,
		conflict=board.payoutPending or state.lastHatch~=nil or board.profile.saving or board.profile.loadFailed or board.profile.saveFailed,
		lastPetAward=state.lastPetAward,capReached=tonumber(today)<tonumber(state.petDay)
			or(today==state.petDay and state.petCount>=5)}
end
local function petAnchor(state)
	local room=workspace:FindFirstChild("EggDropLounge")
	local floor=room and room:FindFirstChild("Floor")
	if not floor or not state.root then return nil end
	local position=state.position-state.root.CFrame.LookVector*3+state.root.CFrame.RightVector*2.6
	local at=floor.CFrame:PointToObjectSpace(position)
	if math.abs(at.X)>floor.Size.X*.5-1 or math.abs(at.Z)>floor.Size.Z*.5-1 then return nil end
	local params=RaycastParams.new();params.RespectCanCollide=true
	params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
	local hit=workspace:Raycast(position+Vector3.new(0,8,0),Vector3.new(0,-80,0),params)
	if not hit or hit.Position.Y>state.position.Y+1 or hit.Position.Y<state.position.Y-6 then return nil end
	return Vector3.new(position.X,hit.Position.Y+.025,position.Z)
end

-- Cache authored station/water geometry once per live lounge, never scan rigs.
local wanderScene
local function validWander(input,target,from)
 local room=workspace:FindFirstChild("EggDropLounge");local floor=room and room:FindFirstChild("Floor")
 if not floor or typeof(target)~="Vector3"or typeof(from)~="Vector3"then return nil end
 if not wanderScene or wanderScene.room~=room then
  wanderScene={room=room,wet={},stations={}}
  for _,node in ipairs(room:GetDescendants())do
   if node:IsA("BasePart")and(node.Name=="Creek"or node.Name=="MeadowCreek"or node.Name=="OutlookPond"or node.Name=="LanternPool")then table.insert(wanderScene.wet,node)
   elseif node:IsA("ProximityPrompt")and node:GetAttribute("PocketClubStation")and node.Parent:IsA("BasePart")then table.insert(wanderScene.stations,node.Parent)end
  end
 end
 local at=floor.CFrame:PointToObjectSpace(target)
 if math.abs(at.X)>floor.Size.X*.5-1 or math.abs(at.Z)>floor.Size.Z*.5-1 then return nil end
 for _,station in ipairs(wanderScene.stations)do if station.Parent and Vector2.new(target.X-station.Position.X,target.Z-station.Position.Z).Magnitude<3 then return nil end end
 for _,wet in ipairs(wanderScene.wet)do if wet.Parent then
  for i=0,4 do local point=wet.CFrame:PointToObjectSpace(from:Lerp(target,i/4))
   if math.abs(point.X)<wet.Size.X*.5+.5 and math.abs(point.Z)<wet.Size.Z*.5+.5 then return nil end
  end
 end end
 local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
 local hit=workspace:Raycast(target+Vector3.new(0,3,0),Vector3.new(0,-6,0),params)
 if not hit or hit.Material==Enum.Material.Water or math.abs(hit.Position.Y+.025-input.anchor.Y)>.7 then return nil end
 local grounded=Vector3.new(target.X,hit.Position.Y+.025,target.Z)
 local lift=Vector3.new(0,.7,0)
 if workspace:Raycast(from+lift,grounded-from,params)then return nil end
 return grounded
end
local garden = GardenState.new({now=function()return workspace:GetServerTimeNow()end,
	publish=function(snapshot)gardenShared:SetAttribute("Snapshot",HttpService:JSONEncode(snapshot))end,
    validWander=validWander,
	validFocus=function(input,target)
		local room=workspace:FindFirstChild("EggDropLounge");local floor=room and room:FindFirstChild("Floor")
		if not floor then return false end
		local at=floor.CFrame:PointToObjectSpace(target)
		if math.abs(at.X)>floor.Size.X*.5-1 or math.abs(at.Z)>floor.Size.Z*.5-1 then return false end
		local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
		local hit=workspace:Raycast(target+Vector3.new(0,3,0),Vector3.new(0,-6,0),params)
		return hit~=nil and math.abs(hit.Position.Y+.025-target.Y)<.3
	end})
local function gardenInput(board)
	local character=board.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local petId=board.profile.companionId
	local position=root and root.Position or Vector3.zero
	local preferences=PetAppearance.public(board.profile,board.nursery.state.hues,board.nursery.state.petHues)
	return {petId=petId,owned=petId~=nil and NurseryCatalog.isOwned(inventory(board),petId),
		alive=not board.closing and root~=nil and humanoid~=nil and humanoid.Health>0 and character:IsDescendantOf(workspace),
		characterId=board.characterGeneration or 0,petGeneration=board.companionGeneration or 0,position=position,mode=board.mode,
		anchor=if root then petAnchor({root=root,position=position})or Vector3.new(position.X,GardenLayout.FloorY,position.Z)else Vector3.zero,
		yaw=if root then math.atan2(root.CFrame.LookVector.X,root.CFrame.LookVector.Z)else 0,
		charmVisible=not preferences[petId] or preferences[petId].charmVisible~=false}
end
local function gardenInputs()
	local inputs={}
	for player,board in pairs(boards)do inputs[player.UserId]=gardenInput(board)end
	return inputs
end
local function publishPetAppearance(board)
	board.folder:SetAttribute("PetAppearance",HttpService:JSONEncode(PetAppearance.public(board.profile,board.nursery.state.hues,board.nursery.state.petHues)))
	board.folder:SetAttribute("PetAppearanceRevision",board.petPreferences.revision)
end

local function publishAppearance(board)
	board.folder:SetAttribute("DeckThemeId",board.profile.theme)
	board.folder:SetAttribute("DeckStickerId",board.profile.sticker)
	board.folder:SetAttribute("DeckBackgroundId",board.profile.background)
	board.folder:SetAttribute("AppearanceFallbacks",HttpService:JSONEncode(board.profile.appearanceFallbacks or {}))
	board.folder:SetAttribute("AppearanceRevision",board.appearance.revision)
	Lounge.setAppearance(board.player.Character,board.profile.theme,board.profile.sticker)
end

local function validateAppearance(board,slot,id)
	local description=AppearanceCatalog.describeRequirement(slot,id,AppearanceCatalog.facts(board.profile,board.nursery.state))
	return if description.rule=="invalid"then "Invalid"elseif description.unlocked then nil else "Locked"
end

local function publishCompanion(board)
	local id=board.profile.companionId
	if board.publishedCompanionId~=id then
		board.publishedCompanionId=id
		board.companionGeneration=(board.companionGeneration or 0)+1
	end
	board.folder:SetAttribute("CompanionGeneration",board.companionGeneration or 0)
	board.folder:SetAttribute("CompanionId",id)
end

local function sendHueResult(board,quote,status,reason,receipt)
	if not quote then return end
	hueResult:FireClient(board.player,{id=quote.id,action=quote.action,petId=quote.petId,status=status,reason=reason,
		revision=board.nursery.state.revision,receipt=receipt})
	local pending=board.nursery.pending
	local awaiting=pending and pending.kind=="hue"and pending.candidate.quote.id==quote.id
	if status~="Retrying"and not awaiting and board.hueWaiting and board.hueWaiting.id==quote.id then board.hueWaiting=nil end
end

local function publishNursery(board)
	local state = Nursery.public(board.nursery)
	if canProgress(board) and NurseryCatalog.isOwned(state.inventoryMask, "pip") then
		if not NurseryCatalog.isOwned(state.inventoryMask, board.profile.companionId) then
			Progress.equipCompanion(board.profile, Pets.byId.pip)
			publishCompanion(board)
		end
		if board.firstSession then board.firstSession:advance(4) end
	end
	if board.nurseryBusy then state.status = "Busy" end
	-- Inventory, wallet and operation tokens are owner-private. Replicated board
	-- attributes carry only appearance/roster; never publish the full profile there.
	board.folder:SetAttribute("HatchState", nil)
	nurserySnapshot:FireClient(board.player,state)
	publishPetAppearance(board)
	if board.hueWaiting and state.lastHueResult and state.lastHueResult.id==board.hueWaiting.id then
		sendHueResult(board,board.hueWaiting,"Saved",nil,state.lastHueResult)
	end
	board.folder:SetAttribute("InventoryMask", state.inventoryMask)
	board.folder:SetAttribute("HatchActive", true)
	local masteryMask = state.masteryLegacyMask or 0
	board.folder:SetAttribute("MasteryRanks", HttpService:JSONEncode(state.masteryRanks or {}))

	board.folder:SetAttribute("MasteryMask", masteryMask)
end

local function publishState(board)
	board.folder:SetAttribute("Preset", board.sim.preset)
	board.folder:SetAttribute("Drops", board.sim.drops)
	board.folder:SetAttribute("NextTier", Simulation.nextTier(board.sim))
	board.folder:SetAttribute("PreviewTier1", Simulation.nextTier(board.sim, 1))
	board.folder:SetAttribute("PreviewTier2", Simulation.nextTier(board.sim, 2))
	board.folder:SetAttribute("Merges", board.merges)
	board.folder:SetAttribute("Chain", board.chain)
	board.folder:SetAttribute("PeakChain", board.peakChain)
	board.folder:SetAttribute("MaxClears", board.round.maxClears)
	board.folder:SetAttribute("TrialMask", board.profile.trials)
	board.folder:SetAttribute("Score", board.round.score)
	board.folder:SetAttribute("BestScore", board.profile.bestScore)
	board.folder:SetAttribute("NewBest", board.round.score > board.startBest)
	board.folder:SetAttribute("HatchCharge", board.profile.charge)
	-- Compatibility for the welcome guide only. Sparse inventory uses its own mask.
	local prefix = 0
	for i, pet in ipairs(Pets) do
		if not NurseryCatalog.isOwned(inventory(board), pet.id) then break end
		prefix = i
	end
	board.folder:SetAttribute("OwnedPets", prefix)
	board.folder:SetAttribute("InventoryMask", inventory(board))
	publishCompanion(board)
	board.folder:SetAttribute("RoundOver", board.round.over)
	board.folder:SetAttribute("RunFamily", board.runFamily or "pip")
	board.folder:SetAttribute("SelectedFamily", board.selectedFamily or "pip")
	board.folder:SetAttribute("DangerY", board.round.overflowY or Config.OverflowY)
	board.folder:SetAttribute("OverflowPressure", board.round.danger or 0)
	board.folder:SetAttribute("FieldPhase", board.field and board.field.phase or "Welcome")
	board.folder:SetAttribute("FieldStage", board.field and board.field.rootStage or 0)
	board.folder:SetAttribute("FieldBudget", board.field and board.field.budget or nil)
	board.folder:SetAttribute("FieldZoneBound", FieldRun.ZoneBound)
	local objectiveKey=if board.field then board.runSequence..":"..board.field.rootStage..":"..board.field.goalProgress else ""
	if board.objectiveKey~=objectiveKey then
		board.objectiveKey=objectiveKey
		board.folder:SetAttribute("FieldObjective",if board.field then HttpService:JSONEncode(board.field:public(board.runSequence))else "")
	end
	board.folder:SetAttribute("FieldReady", canProgress(board)
		and (not board.field or (board.field:canDrop(board.sim.drops) and Simulation.canDrop(board.sim))))
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
			part:SetAttribute("EggId", egg.id)
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
	local field = hasPip(board) and board.nursery.status == "Ready"
	local descriptor
	if field then
		local count=board.fieldCount or 0
		descriptor=FieldObjectives.create(FieldObjectives.next(count),Random.new():NextInteger(1,2147483646))
		board.fieldCount=count+1
	end
	local selected = NurseryCatalog.family(board.profile.companionId) or "pip"
	board.runFamily = if FamilyMastery.ownsFamily(inventory(board), selected) then selected else "pip"
	board.selectedFamily = board.runFamily
	board.runDay = Nursery.public(board.nursery).dailyDay
	board.runSequence = board.nursery.nextRunSeq
	board.folder:SetAttribute("RunSequence", board.runSequence)
	board.nursery.nextRunSeq += 1
	board.field=if field then FieldRun.new({descriptor=descriptor,sequence=board.runSequence})else nil
	board.sim = Simulation.new(preset, board.sim and board.sim.serial,
		if field then FieldObjectives.simulationOptions(descriptor,preset) else nil)
	board.round = Round.new(if field then FieldRun.roundOptions() else nil)
	board.startBest = board.profile.bestScore
	board.folder:SetAttribute("ResetId", board.sim.serial)
	board.merges = 0
	board.chain = 0
	board.peakChain = 0
	board.lastMerge = -math.huge
	board.lastDrop = -math.huge
	board.playTime = 0
	board.payoutPending = false
	board.earnedPayout = nil
	board.folder:SetAttribute("FieldSuccess", false)
	board.folder:SetAttribute("FieldReason", "")
	board.folder:SetAttribute("FieldFinalStage", 0)
	board.folder:SetAttribute("NectarAward", 0)
	board.folder:SetAttribute("DailyAward", 0)
	board.folder:SetAttribute("MasteryAward", 0)
	board.folder:SetAttribute("RewardStatus", "")
	publishState(board)
	syncVisuals(board)
end

local function addPlayer(player)
	if boards[player] or loading[player] then
		return
	end
	loading[player] = true
	local profile = Progress.load(player.UserId)
	local nursery = Nursery.load(player.UserId, profile)
	loading[player] = nil
	if player.Parent ~= Players then
		Nursery.release(nursery)
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = tostring(player.UserId)
	nextSlot += 1
	local slot = nextSlot
	local board = {
		player = player,
		appearance = AppearanceIntent.new(),
		petPreferences = PetAppearance.new(),
		folder = folder,
		parts = {},
		impacts = {},
		lastDrop = -math.huge,
		lastReset = -math.huge,
		lastModeChange = -math.huge,
		lastAppearanceChange = -math.huge,
		lastCompanionChange = -math.huge,
		mode = "Board",
		profile = profile,
		nursery = nursery,
		firstSession = nil,
	}
	board.profileReady = SessionProfile.hydrate(profile, nursery)
	if board.profileReady then board.firstSession = FirstSession.new(player, profile) end
	board.mode = if NurseryCatalog.isOwned(nursery.state.inventoryMask, "pip") then "Room" else "Board"
	boards[player] = board
	reset(board, Config.DefaultPreset)
	publishNursery(board)
	publishPetAppearance(board)
	folder:SetAttribute("Mode", board.mode)
	folder:SetAttribute("DeckThemeId", profile.theme)
	folder:SetAttribute("DeckStickerId", profile.sticker)
	folder:SetAttribute("DeckBackgroundId",profile.background)
	folder:SetAttribute("AppearanceFallbacks",HttpService:JSONEncode(profile.appearanceFallbacks or {}))
	folder:SetAttribute("AppearanceRevision",board.appearance.revision)
	folder:SetAttribute("SoundLevel", profile.sound)
	folder:SetAttribute("ReducedEffects", profile.reduced)
	folder:SetAttribute("SaveStatus", if profile.loadFailed then "Temporary" else nil)
	profile.onSaveFailed = function(failed)
		if boards[player] == board and folder.Parent then
			folder:SetAttribute("SaveStatus", if failed then "Retrying" else nil)
		end
	end
	profile.onAppearanceSaved=function(candidate)
		if boards[player]~=board or board.closing then return end
		board.folder:SetAttribute("AppearanceFallbacks",HttpService:JSONEncode(profile.appearanceFallbacks or {}))
		for _,result in ipairs(AppearanceIntent.saved(board.appearance,profile,candidate))do
			appearanceResult:FireClient(player,result)
		end
	end
	profile.resolveAppearance=function(theme,sticker,background)
		local facts=AppearanceCatalog.facts(profile,board.nursery.state)
		profile.appearanceFallbacks={}
		local function allowed(slot,id,default)
			if AppearanceCatalog.canEquip(slot,id,facts)then return id end
			profile.appearanceFallbacks[slot]="Locked";return default
		end
		return allowed("theme",theme,Themes.Default),allowed("sticker",sticker,Stickers.Default),allowed("background",background,Backgrounds.Default)
	end
	profile.onAppearanceSuperseded=function(candidate)
		if boards[player]~=board or board.closing then return end
		local results=AppearanceIntent.superseded(board.appearance,profile,candidate)
		publishAppearance(board)
		for _,result in ipairs(results)do appearanceResult:FireClient(player,result) end
	end
	profile.onPetAppearanceSaved=function(candidate)
		if boards[player]~=board or board.closing then return end
		publishPetAppearance(board)
		for _,packet in ipairs(PetAppearance.saved(board.petPreferences,profile,candidate))do petAppearanceResult:FireClient(player,packet)end
	end
	profile.onPetAppearanceSuperseded=function(candidate)
		if boards[player]~=board or board.closing then return end
		for _,packet in ipairs(PetAppearance.superseded(board.petPreferences,profile,candidate))do petAppearanceResult:FireClient(player,packet)end
		publishPetAppearance(board)
	end
	local affectionRandom=Random.new()
	board.petContact=PetContactController.new({now=os.clock,guid=function()return HttpService:GenerateGUID(false)end,
		random=function()return affectionRandom:NextNumber()end,read=function()return petState(board)end,
		anchor=function(state)
			local actor=garden.actors[player.UserId]
			if actor and actor.mode=="Focus"then
				return garden:focusAnchor(player.UserId,state.petId,board.characterGeneration or 0,board.companionGeneration or 0,state.position)
			end
			return petAnchor(state)
		end,
		candidate=function(lease)return Nursery.petCandidate(board.nursery,lease.id,lease.petId)end,
		award=function(candidate)
			if boards[player]~=board or board.closing then return end
			board.nurseryBusy=true;publishNursery(board)
			Nursery.awardPet(board.nursery,candidate)
			board.nurseryBusy=false
			if boards[player]==board and not board.closing then publishNursery(board);publishState(board)end
		end,
		emit=function(packet)
			if boards[player]==board and not board.closing and player.Parent==Players then petContactRemote:FireClient(player,packet)end
		end})
	folder.Parent = trays
	if board.firstSession then
		board.firstSession:advance(1)
	end
	local function spawn(character)
		board.characterGeneration=(board.characterGeneration or 0)+1
		character:SetAttribute("GardenCharacterId",board.characterGeneration)
		board.folder:SetAttribute("GardenCharacterId",board.characterGeneration)
		Lounge.spawn(character, slot, player, function()
			return board.mode, profile.theme, profile.sticker
		end)
	end
	board.characterConnection = player.CharacterAdded:Connect(spawn)
	if player.Character then
		task.spawn(spawn, player.Character)
	end
end

local function closeBoard(board)
	if board.closing then return end
	closing[board] = true
	board.closing = true
	garden:remove(board.player.UserId)
	if board.petContact then board.petContact:destroy()end
	task.spawn(function()
		local ok, reason = CloseProgress.drain(Nursery, board.nursery, board.earnedPayout, {
			profileFlush = function() return Progress.flushOnce(board.profile) end,
		})
		if not ok then warn("Egg Drop close save did not finish:", reason) end
		closing[board] = nil
	end)
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local board = boards[player]
	if board then
		board.profile.onSaveFailed = nil
		board.profile.onAppearanceSaved = nil
		board.profile.onAppearanceSuperseded = nil
		board.profile.resolveAppearance = nil
		board.profile.onPetAppearanceSaved = nil
		board.profile.onPetAppearanceSuperseded = nil
		board.characterConnection:Disconnect()
		board.folder:Destroy()
		if board.petContact then board.petContact:destroy()end
		boards[player] = nil
		closeBoard(board)
	end
end)

petContactRemote.OnServerEvent:Connect(function(player,action,payload)
	local board=boards[player]
	if not board or board.closing or not board.petContact then return end
	if action=="begin"then board.petContact:begin(payload)
	elseif action=="pulse"then board.petContact:pulse(payload)
	elseif action=="end"then board.petContact:finish(payload)end
end)

gardenIntentRemote.OnServerEvent:Connect(function(player,packet)
	local board=boards[player]
	if not board or board.closing or type(packet)~="table" then return end
	local now=os.clock()
	local kind=packet.kind
	if kind~="focus"and kind~="focusPulse"and kind~="focusEnd"then return end
	board.gardenIntentAt=board.gardenIntentAt or {}
	if now-(board.gardenIntentAt[kind]or -math.huge)<.1 then return end
	board.gardenIntentAt[kind]=now
	if type(packet.seq)~="number"or packet.seq~=packet.seq or packet.seq%1~=0 or packet.seq<1 or packet.seq>2147483647
		or type(packet.petId)~="string"or packet.petId~=board.profile.companionId or board.mode~="Room"
		or packet.characterId~=(board.characterGeneration or 0)or packet.petGeneration~=(board.companionGeneration or 0)then return end
	if kind=="focus"then
		local actor=garden.actors[player.UserId]
		if actor and packet.seq<=(actor.lastFocusSeq or 0)then return end
		-- A deliberate focus may precede first2Hz actor creation; refresh only it.
		garden:syncOne(player.UserId,gardenInput(board))
	else garden.inputs[player.UserId]=gardenInput(board)end
	if garden:focus(player.UserId,packet)then garden:publish()end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(addPlayer, player)
end

request.OnServerEvent:Connect(function(player, action, value, sticker)
	local board = boards[player]
	if not board then return end
	local now = os.clock()
	if action=="petAppearance" then
		local usable=if board.closing then "Closing"else canProgress(board)
		local packet,changed=PetAppearance.request(board.petPreferences,board.profile,value,now,usable,
			function(petId)return NurseryCatalog.isOwned(inventory(board),petId)end,Progress.setPetAppearance)
		if changed then publishPetAppearance(board)end
		if packet then petAppearanceResult:FireClient(player,packet)end
		return
	end
	if action=="appearanceSlot" then
		local usable=if board.closing then "Closing" else canProgress(board)
		local result,changed=AppearanceIntent.request(board.appearance,board.profile,value,now,usable,
			function(slot,id)return validateAppearance(board,slot,id)end,Progress.equip)
		if changed then publishAppearance(board) end
		if result then appearanceResult:FireClient(player,result) end
		return
	end
	if board.closing then
		if action=="appearance" then appearanceResult:FireClient(player,{slot="pair",seq=0,id="",status="Rejected",
			reason="Closing",revision=board.appearance.revision,themeId=board.profile.theme,stickerId=board.profile.sticker,backgroundId=board.profile.background}) end
		return
	end
	if (action == "sound" or action == "motion" or action == "companion"
		or action == "family" or action == "drop" or action == "reset" or action == "preset")
		and not canProgress(board) then return end
	if action == "appearance" then
		-- Compatibility for the previous full-pair client; new clients send slots.
		local reason=if not canProgress(board) then "Unavailable" elseif typeof(value)~="string" or typeof(sticker)~="string" then "Malformed"
			else validateAppearance(board,"theme",value) or validateAppearance(board,"sticker",sticker)
		if not reason and now-board.appearance.lastAt<.25 then reason="Throttled" end
		if not reason then
			board.appearance.lastAt=now
			if value~=board.profile.theme or sticker~=board.profile.sticker then
				Progress.equip(board.profile,value,sticker,board.profile.background);board.appearance.revision+=1;publishAppearance(board)
			end
		end
		appearanceResult:FireClient(player,{slot="pair",seq=0,id="",revision=board.appearance.revision,
			themeId=board.profile.theme,stickerId=board.profile.sticker,backgroundId=board.profile.background,status=if reason then "Rejected" else "Applied",reason=reason})
		return
	end
	if action == "sound" or action == "motion" then
		if value ~= nil then
			return
		end
		if action == "sound" then
			local nextSound = Settings.NextSound[board.profile.sound]
			Progress.setSetting(board.profile, "sound", nextSound)
			board.folder:SetAttribute("SoundLevel", nextSound)
		else
			local reduced = not board.profile.reduced
			Progress.setSetting(board.profile, "reduced", reduced)
			board.folder:SetAttribute("ReducedEffects", reduced)
		end
		return
	end
	if action == "pause" then
		if typeof(value) == "boolean" then board.menuPaused = value end
		return
	end
	-- Retired progression request: no active family selection remains.
	if action == "family" then return end
	if action == "companion" then
		local pet = if typeof(value) == "string" then Pets.byId[value] else nil
		if board.mode == "Room" and pet and NurseryCatalog.isOwned(inventory(board), pet.id)
			and value ~= board.profile.companionId and now - board.lastCompanionChange >= 0.35 then
			board.lastCompanionChange = now
			Progress.equipCompanion(board.profile, pet)
			publishCompanion(board)
			garden:sync(gardenInputs());garden:publish()
		end
		return
	end
	if action == "mode" then
		if now - board.lastModeChange < Config.ModeSwitchInterval or value == board.mode
			or (value ~= "Board" and (value ~= "Room" or not hasPip(board))) then
			return
		end
		board.lastModeChange = now
		if value == "Board" then RunReturn.enter(board, canProgress(board), hasPip(board), reset) end
		board.mode = value
		board.menuPaused = false
		Lounge.setMode(player.Character, player.UserId, value, board.profile.theme, board.profile.sticker)
		board.folder:SetAttribute("Mode", value)
		garden:sync(gardenInputs());garden:publish()
		if value == "Room" and board.firstSession then
			board.firstSession:record("FirstSessionLoungeVisit")
		end
		return
	end
	if board.mode ~= "Board" then
		return
	end
	if action == "drop" then
		if board.menuPaused or board.round.over or (hasPip(board) and board.nursery.status ~= "Ready")
			or (board.field and (not board.field:canDrop(board.sim.drops) or not Simulation.canDrop(board.sim)))
			or typeof(value) ~= "number" or not (value >= 0 and value <= 1)
			or now - board.lastDrop < Config.DropInterval then
			return
		end
		board.lastDrop = now
		if Simulation.drop(board.sim, value) then
			publishState(board)
			if board.firstSession then
				board.firstSession:advance(2)
			end
		end
	elseif action == "reset" or action == "preset" then
		if board.payoutPending then return end
		if now - board.lastReset < Config.ResetInterval then
			return
		end
		if action == "reset" then
			if not RunReturn.retry(board, canProgress(board), hasPip(board), value, reset) then return end
			board.lastReset = now
			if board.firstSession then board.firstSession:record("FirstSessionRoundRetry") end
			return
		end
		if not RunService:IsStudio() then
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

local messages = {
	NeedNectar = "Earn more Stars in a field run.", NeedStars="Earn more Stars in a field run.", RevisionChanged = "Your progress updated. Refresh your preview.",
	Busy = "Finishing your last hatch action…", Pending = "Retry the previous action while it saves.",
	Retrying = "Saving is delayed. Your result will stay the same when retried.",
	SessionLost = "This hatch session moved to another server. Rejoin to continue.",
	Locked = "Your previous session is closing. Please wait a moment.",
	Temporary = "Loading your save. Please wait before spending Stars.",
}

nurseryRequest.OnServerEvent:Connect(function(player, action, value, revision)
	local board = boards[player]
	if not board or board.closing or typeof(action) ~= "string" then return end
	if action=="snapshot"then
		if os.clock()-(board.lastNurserySnapshot or -math.huge)<.3 then return end
		board.lastNurserySnapshot=os.clock()
		local state=Nursery.public(board.nursery);if board.nurseryBusy then state.status="Busy"end
		nurserySnapshot:FireClient(player,state);return
	end
	if not board.profileReady then return end
	local isHue=HueState.isAction(action)
	if action ~= "hatch" and action ~= "ack" and action ~= "daily" and not isHue then return end
	local quote=if isHue and type(value)=="table"and type(value.id)=="string"and #value.id<=100 then{id=value.id,action=action,petId=value.petId}else nil
	local pending=board.nursery.pending
	local canonical=if isHue then HueState.quote(action,value,revision)else nil
	local receipt,same
	if canonical then receipt,same=HueState.find(board.nursery.state,canonical)end
	if receipt and same then
		-- Exact bounded saved proof is read-only; a queued duplicate cannot be
		-- turned into a false failure by the request rate limit after commit.
		publishNursery(board);sendHueResult(board,quote,"Saved","AlreadySaved",HueState.publicReceipt(receipt));return
	end
	local samePending=isHue and pending and pending.kind=="hue"and HueState.same(pending.candidate.quote,canonical)
	if samePending and(board.nurseryBusy or board.nursery.busy or board.payoutPending or os.clock()-(board.lastHatchRequest or -math.huge)<.3)then
		sendHueResult(board,quote,"Retrying","Busy");return
	end
	if os.clock() - (board.lastHatchRequest or -math.huge) < .3 then
		if isHue then sendHueResult(board,quote,"Rejected","Throttled");return end
		nurseryFeedback:FireClient(player, "error", "One moment…")
		return
	end
	board.lastHatchRequest = os.clock()
	if board.nurseryBusy or board.payoutPending then
		if isHue then sendHueResult(board,quote,"Rejected","Busy");return end
		nurseryFeedback:FireClient(player, "error", "Finishing your last save…")
		return
	end
	board.nurseryBusy = true
	publishNursery(board)
	local ok, reason, receipt
	if isHue then ok,reason,receipt=Nursery.hueCommand(board.nursery,action,value,revision)
	else ok,reason=Nursery.command(board.nursery,action,value,revision)end
	if isHue and reason=="Retrying"then board.hueWaiting=quote end
	board.nurseryBusy = false
	if boards[player] ~= board then return end
	publishNursery(board)
	publishState(board)
	if isHue then
		sendHueResult(board,quote,if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason,receipt)
		return
	end
	if not ok then nurseryFeedback:FireClient(player, "error", messages[reason] or reason) end
end)

local function settleReward(player, board)
	if board.payoutRunning then return end
	local amount = board.field.outcome.reward
	board.folder:SetAttribute("FieldSuccess", board.field.outcome.success)
	board.folder:SetAttribute("FieldReason", board.field.outcome.reason)
	board.folder:SetAttribute("FieldFinalStage", board.field.outcome.rootStage)
	local summary = { family = board.runFamily, day = board.runDay, success = board.field.outcome.success,
		clean = board.field.outcome.success and amount == 8, score = board.round.score, chain = board.peakChain,
		clears = board.round.maxClears, drops = board.sim.drops }
	board.earnedPayout = { sequence = board.runSequence, amount = amount, summary = summary, saved = false }
	board.payoutPending, board.payoutRunning = true, true
	board.folder:SetAttribute("RewardStatus", "Saving")
	task.spawn(function()
		while boards[player] == board and not board.closing and board.payoutPending do
			if not board.closing and not board.nurseryBusy and not board.nursery.busy then
				local ok, reason = Nursery.award(board.nursery, board.runSequence, amount, summary)
				if boards[player] ~= board then break end
				publishNursery(board)
				if ok then
					board.payoutPending = false
					board.earnedPayout.saved = true
					local saved = Nursery.public(board.nursery).lastRunReward
					board.folder:SetAttribute("NectarAward", saved and saved.sequence == board.runSequence and saved.total or amount)
					board.folder:SetAttribute("MasteryAward", saved and saved.sequence == board.runSequence and saved.masteryPoints or 0)
					board.folder:SetAttribute("DailyAward", saved and saved.sequence == board.runSequence and saved.daily or 0)
					board.folder:SetAttribute("RewardStatus", "Saved")
					break
				end
				board.folder:SetAttribute("RewardStatus", messages[reason] or reason)
			end
			task.wait(2)
		end
		board.payoutRunning = false
	end)
end

local function grantWelcome(player, board)
	if board.starterRunning or hasPip(board) then return end
	board.starterRunning = true
	task.spawn(function()
		while boards[player] == board and not board.closing and not hasPip(board) do
			if not board.closing and not board.nurseryBusy and not board.nursery.busy then
				local ok = Nursery.grantStarter(board.nursery)
				if boards[player] ~= board then break end
				publishNursery(board)
				publishState(board)
				if ok then
					board.profile.companionId = "pip"
					publishCompanion(board)
					if board.firstSession then board.firstSession:advance(4) end
					break
				end
			end
			task.wait(2)
		end
		board.starterRunning = false
	end)
end

local accumulator = 0
local merged = {}
RunService.Heartbeat:Connect(function(dt)
	garden:step(dt,gardenInputs)
	accumulator = math.min(accumulator + dt, Config.FixedStep * 8)
	while accumulator >= Config.FixedStep do
		accumulator -= Config.FixedStep
		for player, board in pairs(boards) do
			if board.closing or board.mode ~= "Board" or board.round.over or board.menuPaused
				or not canProgress(board) then
				continue
			end
			board.playTime += Config.FixedStep
			local wasReady = Simulation.canDrop(board.sim)
			table.clear(merged)
			Simulation.step(board.sim, Config.FixedStep, merged, board.impacts)
			board.round:step(board.sim.eggs, Config.FixedStep, board.sim.drops)
			for _, merge in ipairs(merged) do
				board.chain = if board.playTime - board.lastMerge <= 1.25 then board.chain + 1 else 1
				board.peakChain = math.max(board.peakChain, board.chain)
				board.lastMerge = board.playTime
				board.merges += 1
				if merge.cleared then
					board.round.maxClears += 1
				end
				board.round.score += 10 * (merge.tier + math.min(board.chain - 1, 9)) + (if merge.cleared then 100 else 0)
				Progress.recordScore(board.profile, board.round.score)
				Progress.recordTrials(board.profile, board.chain, board.round.score, board.round.maxClears)
				if board.field then board.field:observe(merge,{sequence=board.runSequence,ordinal=board.merges,chain=board.chain,playTime=board.playTime}) end
				if not hasPip(board) and board.profile.rank < 1 then
					Progress.chargeHatch(board.profile, merge.tier)
				end
				if board.firstSession then
					board.firstSession:advance(3)
				end
				feedback:FireClient(player, merge.position, merge.tier, board.chain, merge.from, merge.other, merge.id, merge.cleared, board.folder:GetAttribute("ResetId"))
			end
			if board.profile.rank >= 1 and not hasPip(board) then grantWelcome(player, board) end
			if board.field then
				local oldPhase, oldStage = board.field.phase, board.field.rootStage
				local expired=board.field:expireChain(board.playTime,board.lastMerge)
				local result = board.field:step(board.sim.eggs, Config.FixedStep, board.sim.drops, board.round.over)
				if result then
					board.round.over = true
					settleReward(player, board)
				end
				if expired or oldPhase ~= board.field.phase or oldStage ~= board.field.rootStage then publishState(board) end
			end
			if #merged > 0 or board.round.over then
				publishState(board)
			elseif wasReady ~= Simulation.canDrop(board.sim) then
				publishState(board)
			end
		end
	end
	local now = os.clock()
	for player, board in pairs(boards) do
		if board.petContact then board.petContact:update()end
		syncVisuals(board)
		if now - (board.lastPressurePublish or 0) >= .1 then
			board.lastPressurePublish = now
			board.folder:SetAttribute("DangerY", board.round.overflowY or Config.OverflowY)
			board.folder:SetAttribute("OverflowPressure", board.round.danger or 0)
		end
		local batch = {}
		for id, impact in pairs(board.impacts) do
			if board.parts[id] and now - (impact.egg.lastImpact or -math.huge) >= 0.12 then
				impact.egg.lastImpact = now
				table.insert(batch, { id, impact.normal, impact.speed })
			end
		end
		if #batch > 0 then
			impactsRemote:FireClient(player, batch, board.folder:GetAttribute("ResetId"))
		end
		table.clear(board.impacts)
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		for player, board in pairs(boards) do
			if not board.closing and board.nursery.status == "Retrying" and board.nursery.pending
				and not board.nurseryBusy and not board.nursery.busy then
				task.spawn(function()
					local pending=board.nursery.pending
					local ok,reason=Nursery.retry(board.nursery)
					if boards[player] == board then publishNursery(board); publishState(board);if board.petContact then board.petContact:reconcile()end end
					if boards[player]==board and pending and pending.kind=="hue"and not ok and reason~="Retrying"then sendHueResult(board,pending.candidate.quote,"Rejected",reason)end
				end)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(Nursery.RenewSeconds)
		for player, board in pairs(boards) do
			if not board.closing and not board.nurseryBusy and not board.nursery.busy then
				task.spawn(function()
					if board.nursery.status == "Locked" or board.nursery.status == "Unavailable" or board.nursery.status == "Temporary" then
						board.nurseryBusy = true
						local candidateProfile = board.profile
						if candidateProfile.loadFailed then candidateProfile = Progress.load(player.UserId) end
						local replacement = Nursery.load(player.UserId, candidateProfile)
						if boards[player] ~= board or board.closing then Nursery.release(replacement); return end
						board.nursery = replacement
						board.nurseryBusy = false
						board.profileReady = SessionProfile.hydrate(board.profile, replacement)
						if board.profileReady then
							publishPetAppearance(board)
							board.folder:SetAttribute("SaveStatus", nil)
							board.firstSession = FirstSession.new(player, board.profile)
							board.selectedFamily = NurseryCatalog.family(board.profile.companionId) or "pip"
							board.mode = if hasPip(board) then "Room" else "Board"
							reset(board, board.sim.preset)
							board.folder:SetAttribute("Mode", board.mode)
							if board.folder:GetAttribute("DeckThemeId")~=board.profile.theme
								or board.folder:GetAttribute("DeckStickerId")~=board.profile.sticker
								or board.folder:GetAttribute("DeckBackgroundId")~=board.profile.background then board.appearance.revision+=1 end
							board.folder:SetAttribute("DeckThemeId", board.profile.theme)
							board.folder:SetAttribute("DeckStickerId", board.profile.sticker)
							board.folder:SetAttribute("DeckBackgroundId",board.profile.background)
							board.folder:SetAttribute("AppearanceFallbacks",HttpService:JSONEncode(board.profile.appearanceFallbacks or {}))
							board.folder:SetAttribute("AppearanceRevision",board.appearance.revision)
							board.folder:SetAttribute("SoundLevel", board.profile.sound)
							board.folder:SetAttribute("ReducedEffects", board.profile.reduced)
							Lounge.setMode(player.Character, player.UserId, board.mode, board.profile.theme, board.profile.sticker)
							Lounge.setAppearance(player.Character, board.profile.theme, board.profile.sticker)
							if board.firstSession then board.firstSession:advance(1) end
						elseif replacement.status == "Ready" then
							-- Never enable play over a dirty/unhydrated provisional profile.
							Nursery.release(replacement)
							replacement.status = "Unavailable"
						end
					else
						Nursery.renew(board.nursery)
					end
					if boards[player] == board then publishNursery(board); publishState(board);if board.petContact then board.petContact:reconcile()end end
				end)
			end
		end
	end
end)

game:BindToClose(function()
	for _, board in pairs(boards) do closeBoard(board) end
	local deadline = os.clock() + 25
	while next(closing) and os.clock() < deadline do task.wait(.1) end
end)
