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
local RunDay = require(script.RunDay)
local RewardRetry = require(script.RewardRetry)
local HueState = require(script.HueState)
local MaterialState=require(script.MaterialState)
local ToyState=require(script.ToyState)
local FeatureState=require(script.FeatureState)
local MaterialCatalog=require(ReplicatedStorage.Shared.MaterialCatalog)
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
local GardenWalkability=require(ReplicatedStorage.Shared.GardenWalkability)
local GardenPathPlanner=require(ReplicatedStorage.Shared.GardenPathPlanner)
local PetAppearance = require(script.PetAppearance)
local StoreService = require(script.StoreService)
local Economy = require(script.EconomyAnalytics)
local HeatPayout = require(ReplicatedStorage.Shared.HeatPayout)
local HeatRequest = require(script.HeatRequest)

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
local materialResult=child("RemoteEvent","MaterialResult",remotes)
local toyResult=child("RemoteEvent","ToyResult",remotes)
local featureResult=child("RemoteEvent","FeatureResult",remotes)
local appearanceResult = child("RemoteEvent", "AppearanceResult", remotes)
local faceplateResult = child("RemoteEvent", "FaceplateResult", remotes)
local wearableResult = child("RemoteEvent", "WearableResult", remotes)
local questResult = child("RemoteEvent", "QuestResult", remotes)
local petContactRemote = child("RemoteEvent", "PetContact", remotes)
local gardenIntentRemote = child("RemoteEvent", "GardenIntent", remotes)
local gardenToyResult = child("RemoteEvent", "GardenToyResult", remotes)
local petAppearanceResult = child("RemoteEvent", "PetAppearanceResult", remotes)
remotes:SetAttribute("PetCharmVersion",require(ReplicatedStorage.Shared.PetCharmCatalog).Version)
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
		conflict=board.payoutPending or state.lastHatch~=nil or board.profile.saving or board.profile.loadFailed or board.profile.saveFailed or(board.careHeld==true),
		lastPetAward=state.lastPetAward,capReached=tonumber(today)<tonumber(state.petDay)
			or(today==state.petDay and state.petCount>=5)}
end
local gardenScene
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
    local grounded=Vector3.new(position.X,hit.Position.Y+.025,position.Z)
    local scene=gardenScene and gardenScene()
    return if scene then GardenWalkability.resolveAnchor(grounded,scene.wet)or grounded else grounded
end

-- Cache authored station/water geometry once per live lounge, never scan rigs.
local wanderScene
gardenScene=function()
 local room=workspace:FindFirstChild("EggDropLounge")
 if not room then return nil end
 if not wanderScene or wanderScene.room~=room then
  wanderScene={room=room,wet={},stations={},solids={}}
  for _,node in ipairs(room:GetDescendants())do
   -- Merged island meshes span the world; their bounds would block every rest path.
   if node:IsA("BasePart")and node.CanCollide and node.Name~="Floor"and node:GetAttribute("WorldMesh")~=true then table.insert(wanderScene.solids,node)end
   if node:IsA("BasePart")and(node:GetAttribute("GardenWetRegion")==true or node:GetAttribute("GardenBlockedRegion")==true or node.Name=="Creek"or node.Name=="MeadowCreek"or node.Name=="OutlookPond"or node.Name=="LanternPool")then table.insert(wanderScene.wet,node)
   elseif node:IsA("ProximityPrompt")and node:GetAttribute("PocketClubStation")and node.Parent:IsA("BasePart")then table.insert(wanderScene.stations,node.Parent)end
  end
 end
 return wanderScene
end
local function validWander(input,target,from)
 local room=workspace:FindFirstChild("EggDropLounge");local floor=room and room:FindFirstChild("Floor")
 if not floor or typeof(target)~="Vector3"or typeof(from)~="Vector3"then return nil end
 gardenScene()
 local at=floor.CFrame:PointToObjectSpace(target)
 if math.abs(at.X)>floor.Size.X*.5-1 or math.abs(at.Z)>floor.Size.Z*.5-1 then return nil end
 for _,station in ipairs(wanderScene.stations)do if station.Parent and Vector2.new(target.X-station.Position.X,target.Z-station.Position.Z).Magnitude<3 then return nil end end
 local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
 local hit=workspace:Raycast(target+Vector3.new(0,3,0),Vector3.new(0,-6,0),params)
 if not hit or hit.Material==Enum.Material.Water or math.abs(hit.Position.Y+.025-input.anchor.Y)>.7 then return nil end
 local grounded=Vector3.new(target.X,hit.Position.Y+.025,target.Z)
 local span,id=GardenWalkability.spanAt(grounded)
 if span and hit.Instance:GetAttribute("GardenWalkableSpan")~=id then return nil end
 local lift=Vector3.new(0,.7,0)
 if not GardenWalkability.segmentAllowed(from,grounded,wanderScene.wet)then
  -- A nearby owner's registered nook may be reached through the existing safe
  -- bridge exit even when its straight chord crosses unsupported creek.
  if id~="RestNook"or Vector2.new(input.position.X-target.X,input.position.Z-target.Z).Magnitude>4 or(from-grounded).Magnitude>8 then return nil end
  local path=GardenPathPlanner.plan(from,grounded,Vector3.zero,GardenLayout.StrollSpeed,0,0,nil,Vector3.zero,wanderScene.wet)
  local last=path[#path]
  if not last or last.safetyStop or(GardenActivity.vector(last.to)-grounded).Magnitude>=.1 or not GardenWalkability.pathAllowed(path,wanderScene.wet)then return nil end
  for _,leg in ipairs(path)do
   local a,b=GardenActivity.vector(leg.from),GardenActivity.vector(leg.to)
   if workspace:Raycast(a+lift,b-a,params)then return nil end
  end
 elseif workspace:Raycast(from+lift,grounded-from,params)then return nil end
 return grounded
end
local garden = GardenState.new({sharedToyEnabled=false,now=function()return workspace:GetServerTimeNow()end,
	publish=function(snapshot)
		gardenShared:SetAttribute("Snapshot",HttpService:JSONEncode(snapshot))
		for player,board in pairs(boards)do local actor=snapshot.actors[tostring(player.UserId)];board.careHeld=actor~=nil and actor.care~=nil;board.folder:SetAttribute("CareMode",if actor and actor.care then actor.mode else nil)end
	end,
    planPath=function(from,to,velocity,speed,minimum,yaw,via,terminal)
        local scene=gardenScene()
        return GardenPathPlanner.plan(from,to,velocity,speed,minimum,yaw,via,terminal,if scene then scene.wet else {})
    end,
    resolveTarget=function(target,from)
        local scene=gardenScene();if not scene then return target,false end
        local resolved=GardenWalkability.resolveAnchor(target,scene.wet)
        if not resolved then return from,true end
        local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={scene.room}
        local hit=workspace:Raycast(resolved+Vector3.new(0,8,0),Vector3.new(0,-80,0),params)
        local span,id=GardenWalkability.spanAt(resolved)
        if not hit or(span and hit.Instance:GetAttribute("GardenWalkableSpan")~=id)then return from,true end
        local grounded=Vector3.new(resolved.X,hit.Position.Y+.025,resolved.Z)
        if not GardenWalkability.segmentAllowed(grounded,grounded,scene.wet)then return from,true end
        return grounded,(grounded-target).Magnitude>.001
    end,
    validToyPath=function(path)
        local scene=gardenScene();return scene~=nil and GardenWalkability.pathAllowed(path,scene.wet)
    end,
    validRestPath=function(path)
        local scene=gardenScene();return scene~=nil and GardenPathPlanner.restPathClear(path,scene.solids)
    end,
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
-- Pets stay on the ground level: an owner on a terrace, ramp, pillar, ledge or
-- bench leaves the pet at the last ground anchor (bridges and other authored
-- spans still count as ground). Kept out of petAnchor so care reach is unchanged.
local function groundAnchor(board,anchor)
	if anchor and(GardenWalkability.spanAt(anchor)~=nil or GardenLayout.onGround(anchor))then
		board.groundAnchor=anchor
		return anchor
	end
	-- Above the ground with no remembered spot yet: start on the open lawn, never
	-- under the owner inside a terrace or ledge footprint.
	if anchor and not board.groundAnchor then return GardenLayout.Lawn end
	return board.groundAnchor
end
local function gardenInput(board)
	local character=board.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local petId=board.profile.companionId
	local position=root and root.Position or Vector3.zero
	local preferences=PetAppearance.public(board.profile,board.nursery.state.hues,board.nursery.state.petHues,board.nursery.state.petMaterials,board.nursery.state.petToys,board.nursery.state.petFeatures,board.profile.companionId,board.nursery.state.petWearables)
	return {petId=petId,owned=petId~=nil and NurseryCatalog.isOwned(inventory(board),petId),root=root,character=character,
		carryPosition=root and(root.Position+root.CFrame.LookVector*1.2+Vector3.new(0,.3,0))or nil,
		alive=not board.closing and root~=nil and humanoid~=nil and humanoid.Health>0 and character:IsDescendantOf(workspace),
		characterId=board.characterGeneration or 0,petGeneration=board.companionGeneration or 0,position=position,mode=board.mode,
		anchor=if root then groundAnchor(board,petAnchor({root=root,position=position}))or Vector3.new(position.X,GardenLayout.groundAt(position.X,position.Z),position.Z)else Vector3.zero,
		yaw=if root then math.atan2(root.CFrame.LookVector.X,root.CFrame.LookVector.Z)else 0,
		charmVisible=preferences[petId]~=nil and preferences[petId].charmVisible==true}
end
local function gardenInputs()
	local inputs={}
	for player,board in pairs(boards)do inputs[player.UserId]=gardenInput(board)end
	return inputs
end
local function publishPetAppearance(board)
	board.folder:SetAttribute("PetAppearance",HttpService:JSONEncode(PetAppearance.public(board.profile,board.nursery.state.hues,board.nursery.state.petHues,board.nursery.state.petMaterials,board.nursery.state.petToys,board.nursery.state.petFeatures,board.profile.companionId,board.nursery.state.petWearables)))
	board.folder:SetAttribute("PetAppearanceRevision",board.petPreferences.revision+board.nursery.state.revision)
end

local function publishAppearance(board)
	board.folder:SetAttribute("DeckThemeId",board.profile.theme)
	board.folder:SetAttribute("DeckStickerId",board.profile.sticker)
	board.folder:SetAttribute("DeckBackgroundId",board.profile.background)
	board.folder:SetAttribute("AppearanceFallbacks",HttpService:JSONEncode(board.profile.appearanceFallbacks or {}))
	board.folder:SetAttribute("AppearanceRevision",board.appearance.revision)
	Lounge.setAppearance(board.player.Character,board.profile.theme)
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
local gardenCareHost=require(script.GardenCareHost).new({garden=garden,boards=boards,progress=Progress,remotes=remotes,
 canProgress=canProgress,inventory=inventory,gardenInput=gardenInput,publishCompanion=publishCompanion,
 place=function(input)
  local scene=gardenScene();if not scene then return nil end
  return require(script.GardenCarePlacement).find(input,scene.room,scene.wet,scene.solids)
 end,
 validDock=function()
  local scene=gardenScene();local careLayout=require(ReplicatedStorage.Shared.GardenCareLayout)
  local art=scene and scene.room:FindFirstChild("CareMachine");local support=art and art:FindFirstChild("PlinthSupport")
  if not support or not support.CanCollide then return false end
  local at=support.CFrame:PointToObjectSpace(careLayout.Dock)
  if math.abs(at.X)>support.Size.X*.5 or math.abs(at.Z)>support.Size.Z*.5 or math.abs(at.Y-support.Size.Y*.5)>.08 then return false end
  for _,dx in ipairs({-.95,0,.95})do for _,dz in ipairs({-.95,0,.95})do local p=careLayout.Dock+Vector3.new(dx,0,dz);if not GardenWalkability.segmentAllowed(p,p,scene.wet)then return false end end end
  local overlap=OverlapParams.new();overlap.RespectCanCollide=true;overlap.FilterType=Enum.RaycastFilterType.Include;overlap.FilterDescendantsInstances={scene.room}
  for _,hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(careLayout.Dock+Vector3.new(0,1.53,0)),careLayout.Footprint,overlap))do
   if hit:GetAttribute("WorldMesh")~=true then return false end
  end
  return true
 end})

local function sendHueResult(board,quote,status,reason,receipt)
	if not quote then return end
	hueResult:FireClient(board.player,{id=quote.id,action=quote.action,petId=quote.petId,status=status,reason=reason,
		revision=board.nursery.state.revision,receipt=receipt})
	local pending=board.nursery.pending
	local awaiting=pending and pending.kind=="hue"and pending.candidate.quote.id==quote.id
	if status~="Retrying"and not awaiting and board.hueWaiting and board.hueWaiting.id==quote.id then board.hueWaiting=nil end
end

local function sendMaterialResult(board,quote,status,reason,receipt)
 if not quote then return end
 materialResult:FireClient(board.player,{id=quote.id,action=quote.action,petId=quote.petId,status=status,reason=reason,revision=board.nursery.state.revision,receipt=receipt})
 local pending=board.nursery.pending;local awaiting=pending and pending.kind=="material"and pending.candidate.quote.id==quote.id
 if status~="Retrying"and not awaiting and board.materialWaiting and board.materialWaiting.id==quote.id then board.materialWaiting=nil end
end

local itemRemotes={toy=toyResult,feature=featureResult}
local function sendItemResult(board,kind,quote,status,reason,receipt)
 if not quote then return end
 itemRemotes[kind]:FireClient(board.player,{id=quote.id,action=quote.action,petId=quote.petId,status=status,reason=reason,revision=board.nursery.state.revision,receipt=receipt})
 local pending=board.nursery.pending;local awaiting=pending and pending.kind==kind and pending.candidate.quote.id==quote.id
 local waiting=kind.."Waiting"
 if status~="Retrying"and not awaiting and board[waiting]and board[waiting].id==quote.id then board[waiting]=nil end
end

-- Guided first session (plan section 1): until the first saved win, the first
-- three rounds of a session run Easy with no picker.
local function guidedHeat(board)
	return HeatRequest.guided(board.nursery.state.totalWins, board.settledRounds)
end
-- The picker's numbers come from here: each heat's win and tidy-win totals for
-- this player's passes. Presentation only; payout reads the run's stored heat.
local function publishHeat(board)
	local boost = StoreService.boost(board)
	local pays = {}
	for _, key in ipairs(Config.HeatOrder) do
		local low, high = HeatPayout.range(key, boost)
		pays[key] = { low, high }
	end
	board.folder:SetAttribute("Heat", board.runHeat or Config.DefaultHeat)
	board.folder:SetAttribute("NextHeat", board.nextHeat or Config.DefaultHeat)
	board.folder:SetAttribute("HeatGuided", board.heatGuided == true)
	board.folder:SetAttribute("HeatPays", HttpService:JSONEncode(pays))
	board.folder:SetAttribute("WinPays", HeatPayout.rangeText(board.runHeat or Config.DefaultHeat, boost))
end

local function publishNursery(board)
	-- Quest rewards are shown with the player's 2x pass applied.
	board.nursery.passMultiplier = StoreService.boost(board).multiplier
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
	if board.runHeat then publishHeat(board) end
	publishPetAppearance(board)
	if board.hueWaiting and state.lastHueResult and state.lastHueResult.id==board.hueWaiting.id then
		sendHueResult(board,board.hueWaiting,"Saved",nil,state.lastHueResult)
	end
	if board.materialWaiting and state.lastMaterialResult and state.lastMaterialResult.id==board.materialWaiting.id then sendMaterialResult(board,board.materialWaiting,"Saved",nil,state.lastMaterialResult)end
	for _,kind in ipairs({"toy","feature"})do
  local title=kind:sub(1,1):upper()..kind:sub(2);local waiting=board[kind.."Waiting"];local receipt=state["last"..title.."Result"]
  if waiting and receipt and receipt.id==waiting.id then sendItemResult(board,kind,waiting,"Saved",nil,receipt)end
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
	board.folder:SetAttribute("OverflowPressure", if board.round.over then 0 else board.round.danger or 0)
	board.folder:SetAttribute("OverflowGraceLeft", if board.round.over then 0 else board.round.graceLeft or 0)
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
	local contentIds={}
 -- Simulation.serial allocates ball IDs on drops/merges. ResetId alone is
 -- the stable presentation generation of this run.
 local runSerial=board.folder:GetAttribute("ResetId")
	for _, egg in ipairs(board.sim.eggs) do
		live[egg.id] = true
		table.insert(contentIds,egg.id)
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
		if part:GetAttribute("BoardSerial")~=runSerial then part:SetAttribute("BoardSerial",runSerial)end
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
	table.sort(contentIds)
	local signature=tostring(runSerial)..":"..table.concat(contentIds,",")
 if board.contentSignature~=signature then
  board.contentSignature=signature
  board.folder:SetAttribute("BoardContent",HttpService:JSONEncode({serial=runSerial,ids=contentIds}))
 end
end

-- `sameField` rebuilds the current fresh field (no drops yet) with the newly
-- chosen heat, keeping its template and seed instead of advancing the rotation.
local function reset(board, preset, sameField)
	board.folder:ClearAllChildren()
	table.clear(board.parts)
	local field = hasPip(board) and board.nursery.status == "Ready"
	board.heatGuided = field and guidedHeat(board)
	-- A run's heat is frozen here, before its first drop.
	board.runHeat = HeatRequest.runHeat(board.heatGuided, board.nextHeat)
	local descriptor
	if field then
		if sameField and board.field then
			-- "template" (Pocket Menu restart): same field, fresh seed, so the egg queue is new.
			local seed=if sameField=="template" then Random.new():NextInteger(1,2147483646) else board.field.descriptor.seed
			descriptor=FieldObjectives.create(board.field.descriptor.id,seed,board.runHeat)
		else
			local count=board.fieldCount or 0
			descriptor=FieldObjectives.create(FieldObjectives.next(count),Random.new():NextInteger(1,2147483646),board.runHeat)
			board.fieldCount=count+1
		end
	end
	local selected = NurseryCatalog.family(board.profile.companionId) or "pip"
	board.runFamily = if FamilyMastery.ownsFamily(inventory(board), selected) then selected else "pip"
	board.selectedFamily = board.runFamily
	-- Stamped at the first drop (RunDay), not here: an idle fresh board can
	-- sit across the 05:00 UTC rollover before the player starts it.
	board.runDay = nil
	board.runSequence = board.nursery.nextRunSeq
	board.folder:SetAttribute("RunSequence", board.runSequence)
	board.nursery.nextRunSeq += 1
	board.field=if field then FieldRun.new({descriptor=descriptor,sequence=board.runSequence,heat=board.runHeat})else nil
	board.sim = Simulation.new(preset, board.sim and board.sim.serial,
		if field then FieldObjectives.simulationOptions(descriptor,preset,board.runHeat) else nil)
	board.round = Round.new(if field then FieldRun.roundOptions(board.runHeat) else nil)
	board.maxTier = 0
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
	publishHeat(board)
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
	board.passes = {}
	board.nextHeat = if Config.validHeat(profile.lastHeat) then profile.lastHeat else Config.DefaultHeat
	StoreService.join(board)
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
		return allowed("theme",theme,Themes.Default),Stickers.Default,allowed("background",background,Backgrounds.Default) -- stickers retired
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
			local walletBefore=board.nursery.state.nectar
			local petOk,petReason=Nursery.awardPet(board.nursery,candidate)
			if petOk and petReason~="AlreadySaved"then Economy.source(player,board.nursery.state.nectar-walletBefore,board.nursery.state.nectar,"Gameplay","PetCare")end
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
		board.characterGeneration=(board.characterGeneration or 0)+1;board.groundAnchor=nil
		character:SetAttribute("GardenCharacterId",board.characterGeneration)
		board.folder:SetAttribute("GardenCharacterId",board.characterGeneration)
		Lounge.spawn(character, slot, player, function()
			return board.mode, profile.theme
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
StoreService.start({
	board = function(player) return boards[player] end,
	nursery = Nursery,
	publish = function(board)
		if boards[board.player] == board and not board.closing then publishNursery(board); publishState(board) end
	end,
})
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
	if type(kind)=="string"and string.sub(kind,1,4)=="care"then gardenCareHost:request(board,packet);return end
	if kind=="toyStart"or kind=="toyJoin"or kind=="toyCancel"then
        gardenToyResult:FireClient(player,{kind=kind,seq=packet.seq,status="Rejected",reason="ActivityRetired",actionId=packet.actionId});return
    end
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
		if packet and packet.status=="Applied"then Progress.requestFlush(board.profile)end
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
		or action == "family" or action == "drop" or action == "reset" or action == "preset" or action == "restart")
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
	-- Difficulty (plan section 1). Validated and stored here; applied at reset.
	-- Refused once the run has its first drop, and while a payout is pending.
	if action == "heat" then
		if now - (board.lastHeatRequest or -math.huge) < .2 then return end
		board.lastHeatRequest = now
		local decision = HeatRequest.decide({ mode = board.mode, ready = canProgress(board), payoutPending = board.payoutPending,
			over = board.round.over, drops = board.sim.drops, field = board.field ~= nil, guided = board.heatGuided,
			runHeat = board.runHeat, cooling = now - board.lastReset < Config.ResetInterval }, value)
		if decision == "Store" or decision == "Rebuild" then
			board.nextHeat = value
			Progress.setHeat(board.profile, value)
			if decision == "Rebuild" then
				board.lastReset = now
				reset(board, board.sim.preset, true)
			end
		end
		publishHeat(board)
		return
	end
	-- Retired progression request: no active family selection remains.
	if action == "family" then return end
	if action == "companion" then
		local pet = if typeof(value) == "string" then Pets.byId[value] else nil
		if board.mode == "Room" and pet and NurseryCatalog.isOwned(inventory(board), pet.id)
			and value ~= board.profile.companionId and now - board.lastCompanionChange >= 0.35 then
			board.lastCompanionChange = now
			gardenCareHost:switch(board,pet.id)
		end
		return
	end
	if action == "mode" then
		if now - board.lastModeChange < Config.ModeSwitchInterval or value == board.mode
			or (value ~= "Board" and (value ~= "Room" or not hasPip(board))) then
			return
		end
        if value=="Board"and board.round.over and hasPip(board)and RunReturn.classify(board,canProgress(board),true)=="Preserve"then return end
		board.lastModeChange = now
		if value=="Board"then
			local actor=garden.actors[player.UserId]
			if actor and actor.care then
				local input=gardenInput(board);local point=gardenCareHost.d.place(input)
				if not point then return end
				gardenCareHost.care:follow(actor,input,point)
			end
		end
		if value == "Board" then
            local refreshed=RunReturn.enter(board,canProgress(board),hasPip(board),reset)
            -- A completed field can leave Room only after exact saved payout
            -- permits its fresh replacement. Active fields resume unchanged.
            if board.round.over and hasPip(board)and not refreshed then return end
        end
		board.mode = value
		board.menuPaused = false
		Lounge.setMode(player.Character, player.UserId, value, board.profile.theme)
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
			board.runDay = RunDay.onDrop(board.runDay, board.sim.drops, Daily.dayOf(board.nursery.adapter.now()))
			publishState(board)
			if board.firstSession then
				board.firstSession:advance(2)
			end
		end
	elseif action == "restart" then
		-- Pocket Menu restart: same field template, new seed; its own 3 s cooldown.
		if now - board.lastReset < Config.ResetInterval or now - (board.lastRestart or -math.huge) < 3 then return end
		if RunReturn.restart(board, canProgress(board), hasPip(board), value, function(target, preset) reset(target, preset, "template") end) then
			board.lastReset, board.lastRestart = now, now
			board.menuPaused = false
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
	BalanceLimit = "Your Stars wallet is full, so this round's Stars could not be added.",
}

nurseryRequest.OnServerEvent:Connect(function(player, action, value, revision)
	local board = boards[player]
	if not board or board.closing or typeof(action) ~= "string" then return end
	if action=="snapshot"then
		if os.clock()-(board.lastNurserySnapshot or -math.huge)<.3 then return end
		board.lastNurserySnapshot=os.clock()
		board.nursery.passMultiplier=StoreService.boost(board).multiplier
		local state=Nursery.public(board.nursery);if board.nurseryBusy then state.status="Busy"end
		nurserySnapshot:FireClient(player,state);return
	end
	if not board.profileReady then return end
	-- Faceplate Star purchase (UI-SPEC 5.5): fixed price, server-validated,
	-- idempotent by the client's operation id. Success equips the plate.
	if action=="faceplateBuy"then
		local opId=if type(value)=="table"and type(value.id)=="string"and #value.id<=80 then value.id else nil
		local plateId=if type(value)=="table"and type(value.plateId)=="string"and #value.plateId<=64 then value.plateId else nil
		local function reply(status,reason)faceplateResult:FireClient(player,{id=opId,plateId=plateId,status=status,reason=reason,revision=board.nursery.state.revision})end
		if not opId or not plateId then reply("Rejected","InvalidFaceplate");return end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then reply("Rejected","Throttled");return end
		board.lastHatchRequest=os.clock()
		if board.nurseryBusy or board.payoutPending then reply("Rejected","Busy");return end
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		local ok,reason=Nursery.buyFaceplate(board.nursery,opId,plateId,if type(value.price)=="number"then value.price else nil)
		if ok and reason~="AlreadyOwned"then Economy.command(player,"Faceplate_"..plateId,walletBefore,board.nursery.state.nectar,board.nursery.state)end
		board.nurseryBusy=false;if boards[player]~=board then return end
		if ok then
			-- Wear it at once; the appearance save path confirms it as usual.
			Progress.equip(board.profile,plateId,board.profile.sticker,board.profile.background);board.appearance.revision+=1;publishAppearance(board)
		end
		publishNursery(board);publishState(board)
		reply(if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason);return
	end
	-- Pet wearables (hatching v10): fixed Star price, server-validated, idempotent by
	-- the client's operation id; equip/unequip one slot. Public appearance replicates.
	if action=="wearableBuy"or action=="wearableEquip"then
		local v=if type(value)=="table"then value else {}
		local opId=if type(v.id)=="string"and #v.id<=80 then v.id else nil
		local petId=if type(v.petId)=="string"and #v.petId<=32 then v.petId else nil
		local itemId=if type(v.itemId)=="string"and #v.itemId<=32 then v.itemId elseif v.itemId==false then false else nil
		local slot=if type(v.slot)=="string"and #v.slot<=32 then v.slot else nil
		local function reply(status,reason)wearableResult:FireClient(player,{id=opId,action=action,petId=petId,itemId=itemId,slot=slot,status=status,reason=reason,revision=board.nursery.state.revision})end
		if not opId or not petId or(action=="wearableBuy"and type(itemId)~="string")or(action=="wearableEquip"and(not slot or itemId==nil))then reply("Rejected","InvalidWearable");return end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then reply("Rejected","Throttled");return end
		board.lastHatchRequest=os.clock()
		if board.nurseryBusy or board.payoutPending then reply("Rejected","Busy");return end
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		local ok,reason
		if action=="wearableBuy"then
			ok,reason=Nursery.buyWearable(board.nursery,opId,petId,itemId,if type(v.price)=="number"then v.price else nil,v.equip==true)
			if ok and reason~="AlreadyOwned"then Economy.command(player,"Wearable_"..itemId,walletBefore,board.nursery.state.nectar,board.nursery.state)end
		else
			ok,reason=Nursery.equipWearable(board.nursery,opId,petId,slot,itemId)
		end
		board.nurseryBusy=false;if boards[player]~=board then return end
		publishNursery(board);publishState(board);publishPetAppearance(board)
		reply(if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason);return
	end

	-- Quests (plan sections 5 and 7). Claims are idempotent; the reroll is one a
	-- day. Same busy and rate rules as the other hatch actions.
	if action=="questClaim"or action=="questReroll"then
		local v=if type(value)=="table"then value else {}
		local scope=if action=="questReroll"then "daily"elseif v.scope=="weekly"then "weekly"elseif v.scope=="daily"then "daily"else nil
		local slot=if type(v.slot)=="number"and v.slot%1==0 then v.slot else nil
		local period=if type(v.period)=="string"and #v.period<=12 then v.period else nil
		local function reply(status,reason)questResult:FireClient(player,{action=action,scope=scope,slot=slot,period=period,status=status,reason=reason,
			stars=if status=="Saved"and action=="questClaim"and board.nursery.state.lastQuestClaim then board.nursery.state.lastQuestClaim.stars else nil})end
		if not scope or not slot or not period then reply("Rejected","InvalidQuest");return end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then reply("Rejected","Throttled");return end
		board.lastHatchRequest=os.clock()
		if board.nurseryBusy or board.payoutPending then reply("Rejected","Busy");return end
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		local boost=StoreService.boost(board)
		local ok,reason
		if action=="questClaim"then ok,reason=Nursery.questClaim(board.nursery,scope,slot,period,boost)
		else ok,reason=Nursery.questReroll(board.nursery,slot,period,boost)end
		if ok and board.nursery.state.nectar>walletBefore then Economy.source(player,board.nursery.state.nectar-walletBefore,board.nursery.state.nectar,"Gameplay","Quest")end
		board.nurseryBusy=false;if boards[player]~=board then return end
		publishNursery(board);publishState(board)
		reply(if ok then(if reason=="AlreadyClaimed"then "AlreadyClaimed"else "Saved")elseif reason=="Retrying"then "Retrying"else "Rejected",reason);return
	end

	 local itemKind=if ToyState.isAction(action)then "toy"elseif FeatureState.isAction(action)then "feature"else nil
 if itemKind then
  local api=if itemKind=="toy"then ToyState else FeatureState
  local quote=if type(value)=="table"and type(value.id)=="string"and #value.id<=100 then{id=value.id,action=action,petId=value.petId}else nil
  local canonical=api.quote(action,value,revision);local receipt,same=api.find(board.nursery.state,canonical)
  if receipt and same then publishNursery(board);sendItemResult(board,itemKind,quote,"Saved","AlreadySaved",api.publicReceipt(receipt));return end
  local pending=board.nursery.pending;local samePending=pending and pending.kind==itemKind and api.same(pending.candidate.quote,canonical)
  if samePending and(board.nurseryBusy or board.nursery.busy or board.payoutPending or os.clock()-(board.lastHatchRequest or -math.huge)<.3)then sendItemResult(board,itemKind,quote,"Retrying","Busy");return end
  if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then sendItemResult(board,itemKind,quote,"Rejected","Throttled");return end
  board.lastHatchRequest=os.clock()
  if board.nurseryBusy or board.payoutPending then sendItemResult(board,itemKind,quote,"Rejected","Busy");return end
  board.nurseryBusy=true;publishNursery(board)
  local walletBefore=board.nursery.state.nectar
  local ok,reason,saved=Nursery[itemKind.."Command"](board.nursery,action,value,revision)
  if ok then Economy.command(player,action,walletBefore,board.nursery.state.nectar,board.nursery.state)end
  if reason=="Retrying"then board[itemKind.."Waiting"]=quote end
  board.nurseryBusy=false;if boards[player]~=board then return end
  publishNursery(board);publishState(board)
  sendItemResult(board,itemKind,quote,if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason,saved);return
 end
	if MaterialState.isAction(action)then
		local quote=if type(value)=="table"and type(value.id)=="string"and #value.id<=100 then {id=value.id,action=action,petId=value.petId}else nil
		local canonical=MaterialState.quote(action,value,revision)
		local receipt,same=MaterialState.find(board.nursery.state,canonical)
		if receipt and same then publishNursery(board);sendMaterialResult(board,quote,"Saved","AlreadySaved",MaterialState.publicReceipt(receipt));return end
		local pending=board.nursery.pending
		local samePending=pending and pending.kind=="material"and MaterialState.same(pending.candidate.quote,canonical)
		if samePending and(board.nurseryBusy or board.nursery.busy or board.payoutPending or os.clock()-(board.lastHatchRequest or -math.huge)<.3)then sendMaterialResult(board,quote,"Retrying","Busy");return end
		if action=="materialBuy"and not samePending and not MaterialCatalog.available(ReplicatedStorage:FindFirstChild("PetMaterials"))then sendMaterialResult(board,quote,"Rejected","MaterialsUnavailable");return end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then sendMaterialResult(board,quote,"Rejected","Throttled");return end
		board.lastHatchRequest=os.clock()
		if board.nurseryBusy or board.payoutPending then sendMaterialResult(board,quote,"Rejected","Busy");return end
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		local ok,reason,saved=Nursery.materialCommand(board.nursery,action,value,revision)
		if ok then Economy.command(player,action,walletBefore,board.nursery.state.nectar,board.nursery.state)end
		if reason=="Retrying"then board.materialWaiting=quote end
		board.nurseryBusy=false;if boards[player]~=board then return end
		publishNursery(board);publishState(board)
		sendMaterialResult(board,quote,if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason,saved);return
	end
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
	local walletBefore = board.nursery.state.nectar
	if isHue then ok,reason,receipt=Nursery.hueCommand(board.nursery,action,value,revision)
	else ok,reason=Nursery.command(board.nursery,action,value,revision)end
	if ok and reason ~= "AlreadySaved" then Economy.command(player, action, walletBefore, board.nursery.state.nectar, board.nursery.state) end
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
	local summary = { family = board.runFamily, day = RunDay.forSummary(board.runDay, Daily.dayOf(board.nursery.adapter.now())), success = board.field.outcome.success,
		clean = board.field.outcome.success and amount == 8, score = board.round.score, chain = board.peakChain,
		clears = board.round.maxClears, drops = board.sim.drops, heat = board.runHeat,
		maxTier = math.clamp(board.maxTier or 0, 0, #Config.Tiers), goalsMet = board.field.outcome.rootStage,
		templateId = board.field.descriptor.id }
	board.settledRounds = (board.settledRounds or 0) + 1
	local boost = StoreService.boost(board)
	board.earnedPayout = { sequence = board.runSequence, amount = amount, summary = summary, saved = false, boost = boost }
	board.payoutPending, board.payoutRunning = true, true
	board.folder:SetAttribute("RewardStatus", "Saving")
	task.spawn(function()
		local failures = 0
		while boards[player] == board and not board.closing and board.payoutPending do
			local wait = 2
			if not board.closing and not board.nurseryBusy and not board.nursery.busy then
				local ok, reason = Nursery.award(board.nursery, board.runSequence, amount, summary, boost)
				if boards[player] ~= board then break end
				publishNursery(board)
				local outcome = RewardRetry.classify(ok, reason)
				if outcome == "Permanent" then
					-- A retry can never save this (e.g. BalanceLimit): end cleanly so
					-- the board can replay/leave, and tell the player once.
					warn("Egg Drop round payout refused:", reason)
					board.payoutPending = false
					board.earnedPayout.refused = reason
					board.folder:SetAttribute("RewardStatus", "Refused")
					nurseryFeedback:FireClient(player, "error", messages[reason] or "This round's Stars could not be saved.")
					publishState(board)
					break
				end
				if outcome == "Saved" then
					board.payoutPending = false
					board.earnedPayout.saved = true
					local saved = Nursery.public(board.nursery).lastRunReward
					board.folder:SetAttribute("NectarAward", saved and saved.sequence == board.runSequence and saved.total or amount)
					board.folder:SetAttribute("MasteryAward", saved and saved.sequence == board.runSequence and saved.masteryPoints or 0)
					board.folder:SetAttribute("DailyAward", saved and saved.sequence == board.runSequence and saved.daily or 0)
					board.folder:SetAttribute("RewardStatus", "Saved")
					if saved and saved.sequence == board.runSequence then
						Economy.source(player, saved.total, Nursery.public(board.nursery).nectar, "Gameplay", "RoundReward:" .. (summary.heat or "medium"))
					end
					Economy.event(player, if summary.success then "RoundWon" else "RoundLost")
					break
				end
				-- Transient (DataStore error, busy, pending): retry with backoff.
				failures += 1
				wait = RewardRetry.delay(failures)
				board.folder:SetAttribute("RewardStatus", messages[reason] or reason)
			end
			task.wait(wait)
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
				board.maxTier = math.max(board.maxTier or 0, merge.tier)
				board.lastMerge = board.playTime
				board.merges += 1
				if merge.cleared then
					board.round.maxClears += 1
				end
				board.round.score += Config.mergeScore(merge.tier, board.chain, merge.cleared)
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
			board.folder:SetAttribute("OverflowPressure", if board.round.over then 0 else board.round.danger or 0)
			board.folder:SetAttribute("OverflowGraceLeft", if board.round.over then 0 else board.round.graceLeft or 0)
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
					if boards[player]==board and pending and pending.kind=="material"and not ok and reason~="Retrying"then sendMaterialResult(board,pending.candidate.quote,"Rejected",reason)end
					if boards[player]==board and pending and(pending.kind=="toy"or pending.kind=="feature")and not ok and reason~="Retrying"then sendItemResult(board,pending.kind,pending.candidate.quote,"Rejected",reason)end
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
							Lounge.setMode(player.Character, player.UserId, board.mode, board.profile.theme)
							Lounge.setAppearance(player.Character, board.profile.theme)
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

-- Studio-only check hook (never in a live server): finish the current field's
-- goals and budget so the real settle, award and quest paths run. "plain"
-- disables the tidy line for this run, "tidy" clears the stack. Returns the run heat.
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "EggDropRoundTestHook"
	hook.OnInvoke = function(player, action)
		local board = boards[player]
		if not board or not board.field or board.round.over then return nil, "NoField" end
		if action == "plain" or action == "tidy" then
			board.field.rootStage = board.field.goalCount
			board.sim.drops = FieldRun.Budget
			if action == "plain" then board.field.bonusHeight = -1 else table.clear(board.sim.eggs) end
			publishState(board)
			return board.runHeat
		end
		return nil, "UnknownAction"
	end
	hook.Parent = game:GetService("ServerStorage")
end

game:BindToClose(function()
	for _, board in pairs(boards) do closeBoard(board) end
	local deadline = os.clock() + 25
	while next(closing) and os.clock() < deadline do task.wait(.1) end
end)
