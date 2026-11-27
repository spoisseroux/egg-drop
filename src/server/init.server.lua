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
local CoachMarks = require(ReplicatedStorage.Shared.CoachMarks)
local FieldRun = require(script.FieldRun)
local FieldObjectives = require(ReplicatedStorage.Shared.FieldObjectives)
local PetContactController = require(script.PetContact)
local Daily = require(ReplicatedStorage.Shared.DailyContracts)
local Nursery = require(script.HatchProgress)
local RunDay = require(script.RunDay)
local RewardRetry = require(script.RewardRetry)
local HueState = require(script.HueState)
local MaterialState=require(script.MaterialState)
-- Paint pots (PAINT-SHINE-DRESS-PLAN): the potBuy replay rules; every new buy is refused (pots come from the Paint Egg).
local PaintPotState=require(script.PaintPotState)
local PaintPotHost=require(script.PaintPotHost)
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
local PetCatchup=require(ReplicatedStorage.Shared.PetCatchup)
local Hush=require(ReplicatedStorage.Shared.Hush)
local Tier=require(ReplicatedStorage.Shared.Tier)
local PetFloors=require(ReplicatedStorage.Shared.PetFloors)
local TierPets=require(ReplicatedStorage.Shared.TierPets)
local DenLayout=require(ReplicatedStorage.Shared.DenLayout)
local GardenPathPlanner=require(ReplicatedStorage.Shared.GardenPathPlanner)
local PetAppearance = require(script.PetAppearance)
local StoreService = require(script.StoreService)
local Economy = require(script.EconomyAnalytics)
local HeatPayout = require(ReplicatedStorage.Shared.HeatPayout)
local HeatRequest = require(script.HeatRequest)
local BoardItems = require(script.BoardItems)
-- B1 parity (Studio only, off unless ServerStorage.RoundRecorder): records field rounds as tick-stamped logs.
local roundRecorder = if RunService:IsStudio() then require(script.RoundRecorder) else nil
-- B2 client-run board (FeatureFlags.DeckClientSim, Studio override ServerStorage.DeckClientSim): lockstep field rounds.
local ClientSim = require(script.ClientSimHost)
-- Deck net audit (artifacts/qa-2026-11-26-beta35/DECK-NET-AUDIT.md): Studio /netsim, artificial deck latency.
local DeckNetSim = require(ReplicatedStorage.Shared.DeckNetSim)
local PaidRandomPolicy = require(script.PaidRandomPolicy)
local BookCatalog = require(ReplicatedStorage.Shared.BookCatalog)
local FeatureFlags = require(ReplicatedStorage.Shared.FeatureFlags)
local EarnedPets = require(ReplicatedStorage.Shared.EarnedPets)
local ParkDirector = require(script.ParkDirector)
local ParkMount = require(script.ParkMount)

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
-- Deck network rework (deck-network-plan.md): sim ticks, the owner snapshot stream and
-- the 8 Hz shared Part positions, each behind its FeatureFlags.DeckNet* flag.
local BoardNet = require(script.BoardNet)
BoardNet.setup(remotes)
local nurseryRequest = child("RemoteEvent", "HatchRequest", remotes)
local nurseryFeedback = child("RemoteEvent", "HatchFeedback", remotes)
local nurserySnapshot = child("RemoteEvent", "NurserySnapshot", remotes)
local hueResult = child("RemoteEvent", "HueResult", remotes)
local materialResult=child("RemoteEvent","MaterialResult",remotes)
local toyResult=child("RemoteEvent","ToyResult",remotes)
local featureResult=child("RemoteEvent","FeatureResult",remotes)
-- Paint pots (PAINT-SHINE-DRESS-PLAN): the owner's potBuy replies.
local potResult=child("RemoteEvent","PotResult",remotes)
-- The welcome gift on "You're all set!" (ONBOARDING-V3-BRIEF section 3): the owner's one reply {status, reason, stars}.
local welcomeGiftResult=child("RemoteEvent","WelcomeGiftResult",remotes)
-- The gift chain (GiftEggs, Onboard "gifts"): the owner's replies to giftEgg / giftSeen {kind, action, status, reason, gift}.
local giftResult=child("RemoteEvent","GiftResult",remotes)
local appearanceResult = child("RemoteEvent", "AppearanceResult", remotes)
local faceplateResult = child("RemoteEvent", "FaceplateResult", remotes)
local wearableResult = child("RemoteEvent", "WearableResult", remotes)
local questResult = child("RemoteEvent", "QuestResult", remotes)
local petContactRemote = child("RemoteEvent", "PetContact", remotes)
local gardenIntentRemote = child("RemoteEvent", "GardenIntent", remotes)
local gardenToyResult = child("RemoteEvent", "GardenToyResult", remotes)
local parkResult = child("RemoteEvent", "ParkResult", remotes)
local welcomeResult = child("RemoteEvent", "WelcomeResult", remotes)
local petAppearanceResult = child("RemoteEvent", "PetAppearanceResult", remotes)
-- v2 Stat Eggs: the owner's buy/feed replies, and the public "ate a snack" beat other players see.
local snackResult = child("RemoteEvent", "SnackResult", remotes)
local snackBeat = child("RemoteEvent", "SnackBeat", remotes)
-- v2 pet names: the owner's Names Egg and rename replies.
local nameResult = child("RemoteEvent", "NameResult", remotes)
local NameCatalog = require(ReplicatedStorage.Shared.NameCatalog)
local NameState = require(script.NameState)
local StatEggCatalog = require(ReplicatedStorage.Shared.StatEggCatalog)
local StatEggState = require(script.StatEggState)
-- v1 track B: bug reports / suggestions (remote BugReport, owner tool ServerStorage.EggDropReportsTool).
do local ok,problem=pcall(function()require(script.BugReportStore).mount(remotes)end);if not ok then warn("[EggDropReport] not mounted: "..tostring(problem))end end
-- Client-run board B0: owner-only sim determinism check (FeatureFlags.SimCheck, remote SimCheck).
do local ok,problem=pcall(function()require(script.SimCheckHost).mount(remotes)end);if not ok then warn("[SimCheck] not mounted: "..tostring(problem))end end
-- Alive off switch (ALIVE-BUILD-PLAN-2026-11-22): workspace attributes first, ConfigService later; never blocks boot.
task.spawn(function()local ok,problem=pcall(function()require(script.AliveConfig).start()end);if not ok then warn("[Alive] config not started: "..tostring(problem))end end)
-- Levels matter off switch (LevelsConfig): the same way, one key. Not started = off for everyone.
task.spawn(function()local ok,problem=pcall(function()require(script.LevelsConfig).start()end);if not ok then warn("[Levels] config not started: "..tostring(problem))end end)
-- Garden Dash off switches (DashConfig): the same way, two keys. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.DashConfig).start()end);if not ok then warn("[Dash] config not started: "..tostring(problem))end end)
-- Frutiger Aero off switch (AeroConfig): the same way, one key. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.AeroConfig).start()end);if not ok then warn("[Aero] config not started: "..tostring(problem))end end)
-- Things to do off switches (ThingsConfig): the same way, two keys. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.ThingsConfig).start()end);if not ok then warn("[Things] config not started: "..tostring(problem))end end)
-- Onboarding v3 off switches (OnboardConfig): the same way, three keys, each also off while Things to do is off.
task.spawn(function()local ok,problem=pcall(function()require(script.OnboardConfig).start()end);if not ok then warn("[Onboard] config not started: "..tostring(problem))end end)
-- Beta 14 W4 world feel switches (WorldFeelConfig): the same way, two keys. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.WorldFeelConfig).start()end);if not ok then warn("[Feel] config not started: "..tostring(problem))end end)
-- Player scale (PlayerScaleConfig): ConfigService player_scale (a number) and the owner's /scale. Ceiling off: nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.PlayerScaleConfig).start()end);if not ok then warn("[PlayerScale] config not started: "..tostring(problem))end end)
-- Garden finds off switch (FindsConfig): the same way, one key. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.FindsConfig).start()end);if not ok then warn("[Finds] config not started: "..tostring(problem))end end)
-- "This week" wardrobe pick off switch (ThisWeekConfig): the same way, one key. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.ThisWeekConfig).start()end);if not ok then warn("[ThisWeek] config not started: "..tostring(problem))end end)
-- Garden hour off switch (GardenHourConfig): the same way, one key, but missing = off. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.GardenHourConfig).start()end);if not ok then warn("[Hour] config not started: "..tostring(problem))end end)
-- Island edges off switch (IslandBoundsConfig): the same way, one key. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.IslandBoundsConfig).start()end);if not ok then warn("[Bounds] config not started: "..tostring(problem))end end)
-- Pet catch-up off switch (CatchupConfig, beta (12) QA G1): the same way, one key. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.CatchupConfig).start()end);if not ok then warn("[Catchup] config not started: "..tostring(problem))end end)
-- The Hush off switch (HushConfig): the same way, one key. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.HushConfig).start()end);if not ok then warn("[Hush] config not started: "..tostring(problem))end end)
-- The upper tier off switch (TierConfig): the same way, one key. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.TierConfig).start()end);if not ok then warn("[Tier] config not started: "..tostring(problem))end end)
-- Pets go up off switch (TierPetsConfig, WORLD-FINISH-LOOK slice A): the same way, one key. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.TierPetsConfig).start()end);if not ok then warn("[TierPets] config not started: "..tostring(problem))end end)
-- The Play Den off switch (DenConfig): the same way, one key. With its build ceiling off nothing starts.
task.spawn(function()local ok,problem=pcall(function()require(script.DenConfig).start()end);if not ok then warn("[Den] config not started: "..tostring(problem))end end)
remotes:SetAttribute("PetCharmVersion",require(ReplicatedStorage.Shared.PetCharmCatalog).Version)
local gardenShared = child("Folder", "GardenState", ReplicatedStorage)
local trays = child("Folder", "EggDropBoards", ReplicatedStorage)
local boards = {}
-- The side effects of a saved Stat Egg or feed (also for one the background retry settled).
local function snackEffects(player,board,action,receipt,walletBefore)
	if type(receipt)~="table"then return end
	if action=="statEggBuy"then
		Economy.command(player,"StatEgg",walletBefore,board.nursery.state.nectar,board.nursery.state)
		Economy.event(player,"EggOpened_stat",1,{receipt.stat,receipt.size,receipt.source or(if receipt.free then "free"else "paid")})
	else
		board.lastFeedAt=os.clock()
		Economy.event(player,"SnackFed",1,{receipt.stat,receipt.size})
		-- Everyone (the owner included) gets the public beat; other clients play the bites on this pet.
		snackBeat:FireAllClients(player.UserId,{petId=receipt.petId,stat=receipt.stat,size=receipt.size,id=receipt.snackId})
	end
end
-- Code review: a snack op that ended "Retrying" on the client and was settled later by the
-- background retry (or found committed by the lease renew) still answers its op id, so the
-- client shows the result instead of inviting a second press.
local function settleSnack(player,board,pending,ok,reason)
	local signature=type(pending)=="table"and pending.signature or ""
	-- v2 pet names (code review): a Names Egg the background retry settled still answers its op id,
	-- so the client shows the reveal instead of a silent debit.
	if string.sub(signature,1,8)=="nameEgg:"then
		if boards[player]~=board then return end
		local c=pending.candidate
		local saved=NameState.receipt(board.nursery.state,c.op)
		local revision=board.nursery.state.revision
		if saved and saved.digest==c.digest then
			Economy.command(player,"NameEgg",board.nursery.state.nectar+(tonumber(saved.cost)or 0),board.nursery.state.nectar,board.nursery.state)
			nameResult:FireClient(player,{id=c.op,action="nameEggBuy",status="Saved",reason="Saved",receipt=NameState.publicReceipt(saved),revision=revision})
		elseif not ok and reason~="Retrying"and board.nursery.pending~=pending then
			nameResult:FireClient(player,{id=c.op,action="nameEggBuy",status="Rejected",reason=reason,revision=revision})
		end
		return
	end
	local action=if string.sub(signature,1,8)=="statEgg:"then "statEggBuy"elseif string.sub(signature,1,6)=="snack:"then "snackFeed"else nil
	if not action or boards[player]~=board then return end
	local c=pending.candidate
	local saved=StatEggState.receipt(board.nursery.state,c.op)
	local revision=board.nursery.state.revision
	if saved and saved.digest==c.digest then
		snackEffects(player,board,action,StatEggState.publicReceipt(saved),board.nursery.state.nectar+(tonumber(saved.cost)or 0))
		snackResult:FireClient(player,{id=c.op,action=action,status="Saved",reason="Saved",receipt=StatEggState.publicReceipt(saved),revision=revision})
	elseif not ok and reason~="Retrying"and board.nursery.pending~=pending then
		snackResult:FireClient(player,{id=c.op,action=action,status="Rejected",reason=reason,revision=revision})
	end
end
ClientSim.mount(remotes,function(player)return boards[player]end)
local loading = {}
local closing = {}
local nextSlot = 0
Lounge.create()
-- Pet Park equipment (K3): built only with FeatureFlags.Park on; nothing is created otherwise.
-- Beside the lounge, not inside it: the garden's Include-lounge + RespectCanCollide rays never see the player colliders.
if FeatureFlags.Park == true then ParkMount.build(workspace) end

local function inventory(board)
	return board.nursery.state.inventoryMask
end

-- Slice E: "has a pet" is any owned pet that is active in this build (the Bear today, the
-- Bear or Blip once SecondPet is on), never a literal id.
local function hasPet(board)
	return SessionProfile.hasActivePet(inventory(board))
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
		conflict=board.payoutPending or state.lastHatch~=nil or board.profile.saving or board.profile.loadFailed or board.profile.saveFailed or(board.careHeld==true)or(board.dashHeld==true),
		lastPetAward=state.lastPetAward,capReached=tonumber(today)<tonumber(state.petDay)
			or(today==state.petDay and state.petCount>=Nursery.PetDailyCap)}
end
local gardenScene
-- The Hush (HushHost, mounted below): its own `open` flag is what the pet floor checks read. nil on live.
local hushHost
-- The upper tier (TierHost, mounted below): its own `open` flag is what Tier.covers reads. nil on live.
local tierHost
-- The Play Den (DenHost, mounted below): its layout while it is open is what the pet floor, catch-up, the island bounds
-- and Garden Dash read (denHost:live()). nil on live.
local denHost
local function denLive()return if denHost~=nil then denHost:live()else nil end
-- Pets go up (WORLD-FINISH-LOOK slice A, TierPets): the tier open, the pets' switch and the catch-up switch (a pet that
-- falls behind on the flight needs its hop). false on live (no tier host) and with any of them off: then every hook
-- below takes today's line exactly.
local function petsUp()return tierHost~=nil and tierHost.open==true and TierPets.on()and PetCatchup.on()end
local sceneWatch -- the one DescendantAdded listener of the current garden scene (beta and Studio only)
-- Pets go round the garden's solid props (GARDEN-PLAY-BRIEF-2 section 4, GardenKeepOut; the Alive `keepout` switch, beta
-- and Studio only): the built props' keep-out circles join the scene's wet list. A flip of it, or of a prop's own
-- switch, drops the cached scene so the next plan reads the list again. Live: the ceiling is closed, nothing is added.
local GardenKeepOut=require(ReplicatedStorage.Shared.GardenKeepOut)
local function keepOutRegions()
	local ok,regions=pcall(function()
		local Alive=require(ReplicatedStorage.Shared.Alive)
		if not Alive.on(GardenKeepOut.Feature)then return {}end
		return GardenKeepOut.regions(function(feature)return Alive.on(feature)end)
	end)
	if not ok then warn("[KeepOut] not read: "..tostring(regions));return {}end
	return regions
end
local function petAnchor(state)
	local room=workspace:FindFirstChild("EggDropLounge")
	local floor=room and room:FindFirstChild("Floor")
	if not floor or not state.root then return nil end
	local position=state.position-state.root.CFrame.LookVector*3+state.root.CFrame.RightVector*2.6
	local up=petsUp()
	-- Pets go up: an owner on the terrace or the path is followed on that floor (the offset point snapped into the
	-- path's lane or the terrace less 3, never off the tread).
	if up then position=TierPets.anchor(state.position,position)or position end
	if not PetFloors.ok(floor,position,hushHost~=nil and hushHost.open,tierHost~=nil and tierHost.open,denLive(),up)then return nil end
	local params=RaycastParams.new();params.RespectCanCollide=true
	params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
	-- The Play Den's ceiling is lower than 8 over a root in it (DenLayout.groundRayTop; elsewhere exactly +8); on the
	-- cliff path at most 6 over the tread (rock overhangs).
	local top=DenLayout.groundRayTop(denLive(),position,8)
	if up then top=TierPets.rayTop(position,top)end
	local hit=workspace:Raycast(Vector3.new(position.X,top,position.Z),Vector3.new(0,-80,0),params)
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
  -- Beta (12) QA G1 (code review 3): on the beta and in Studio only (the catch-up or onboarding v3 ceiling), a blocked
  -- or wet footprint added after this cache was built (the plaza nest's GardenBlockedRegion box) joins the wet list,
  -- so pet paths, wanders and catch-up landings reject it. The attribute must be set before the part is parented.
  -- One listener: a rebuilt scene disconnects the old one.
  if sceneWatch then sceneWatch:Disconnect();sceneWatch=nil end
  local watch=false
  pcall(function()watch=PetCatchup.ceiling()or require(ReplicatedStorage.Shared.Onboard).ceiling()end)
  if watch then
   local scene=wanderScene
   sceneWatch=room.DescendantAdded:Connect(function(node)
    if not node:IsA("BasePart")then return end
    if node:GetAttribute("GardenWetRegion")~=true and node:GetAttribute("GardenBlockedRegion")~=true then return end
    if wanderScene==scene and not table.find(scene.wet,node)then table.insert(scene.wet,node)end
   end)
  end
  for _,node in ipairs(room:GetDescendants())do
   -- Merged island meshes span the world; their bounds would block every rest path.
   -- Park colliders (players only) never block pet rest paths; pets are visuals.
   if node:IsA("BasePart")and node.CanCollide and node.Name~="Floor"and node:GetAttribute("WorldMesh")~=true and not ParkMount.isParkPart(node)then table.insert(wanderScene.solids,node)end
   if node:IsA("BasePart")and(node:GetAttribute("GardenWetRegion")==true or node:GetAttribute("GardenBlockedRegion")==true or node.Name=="Creek"or node.Name=="MeadowCreek"or node.Name=="OutlookPond"or node.Name=="LanternPool")then table.insert(wanderScene.wet,node)
   elseif node:IsA("ProximityPrompt")and node:GetAttribute("PocketClubStation")and node.Parent:IsA("BasePart")then table.insert(wanderScene.stations,node.Parent)end
  end
  for _,region in ipairs(keepOutRegions())do table.insert(wanderScene.wet,region)end
 end
 return wanderScene
end
-- GardenKeepOut: a flip of `keepout` or of a prop's own switch reads the scene again (the keep-outs come and go).
do
 local ok,problem=pcall(function()
  local Alive=require(ReplicatedStorage.Shared.Alive)
  if not Alive.ceiling(GardenKeepOut.Feature)then return end
  for _,feature in ipairs({GardenKeepOut.Feature,"crunch","wobble"})do
   Alive.changed(feature):Connect(function()wanderScene=nil end)
  end
 end)
 if not ok then warn("[KeepOut] not watched: "..tostring(problem))end
end
-- Pets go up: a ground point under `point` on the terrace or the path (the ray starts at most 6 over the tread), within
-- `slack` of its height; nil when there is none.
local function tierGround(point,slack)
 local room=workspace:FindFirstChild("EggDropLounge")
 if not room or typeof(point)~="Vector3"then return nil end
 local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
 local top=TierPets.rayTop(point,point.Y+8)
 local hit=workspace:Raycast(Vector3.new(point.X,top,point.Z),Vector3.new(0,-(top-point.Y)-6,0),params)
 if not hit or hit.Material==Enum.Material.Water or math.abs(hit.Position.Y+TierPets.Sole-point.Y)>(slack or .8)then return nil end
 return Vector3.new(point.X,hit.Position.Y+TierPets.Sole,point.Z)
end
local function validWander(input,target,from)
 local room=workspace:FindFirstChild("EggDropLounge");local floor=room and room:FindFirstChild("Floor")
 if not floor or typeof(target)~="Vector3"or typeof(from)~="Vector3"then return nil end
 gardenScene()
 -- Pets go up: the terrace less 3 is wander floor; the path only at its turn's rest spot (transit only).
 if petsUp()then
  local ok=TierPets.targetOk(target)
  if ok==false then return nil end
  if ok==true then
   local grounded=tierGround(target,.7)
   if not grounded or(math.abs(grounded.Y-input.anchor.Y)>.7 and not TierPets.restAt(target))then return nil end
   local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
   if workspace:Raycast(from+Vector3.new(0,.7,0),grounded-from,params)then return nil end
   return grounded
  end
 end
 if not PetFloors.ok(floor,target,hushHost~=nil and hushHost.open,tierHost~=nil and tierHost.open,denLive())then return nil end
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
local function resolveGardenTarget(target,from,base)
        local scene=gardenScene();if not scene then return target,false end
        -- Pets go up: a target on the terrace or the path (by the anchor's floor: `base`, before the owner's look-ahead)
        -- snaps into that floor (the lane, the terrace less 3) and is checked by a ray; it never meets the lawn's wet
        -- list (the path's own footprints lie under it in plan).
        local zone=if petsUp()then TierPets.zone(if typeof(base)=="Vector3"then base else target)else "lawn"
        if zone~="lawn"then
            local snapped=TierPets.snap(target,zone)
            local grounded=snapped and tierGround(snapped,.8)
            if not grounded then return from,true end
            return grounded,true
        end
        local resolved=GardenWalkability.resolveAnchor(target,scene.wet)
        if not resolved then return from,true end
        local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={scene.room}
        local hit=workspace:Raycast(Vector3.new(resolved.X,DenLayout.groundRayTop(denLive(),resolved,8),resolved.Z),Vector3.new(0,-80,0),params)
        local span,id=GardenWalkability.spanAt(resolved)
        if not hit or(span and hit.Instance:GetAttribute("GardenWalkableSpan")~=id)then return from,true end
        local grounded=Vector3.new(resolved.X,hit.Position.Y+.025,resolved.Z)
        if not GardenWalkability.segmentAllowed(grounded,grounded,scene.wet)then return from,true end
        return grounded,(grounded-target).Magnitude>.001
end
-- Beta (12) QA G1: where a catching-up pet lands. Rings round the owner's ground anchor (PetCatchup.candidates, behind
-- the owner first); each must resolve to walkable ground where it stands (no `from` fallback: nil is a refusal), stay
-- within Rise of the anchor's height, and pass PetCatchup.clear (safe ground, island walls, the course and pad while a
-- race is live). nil when none does: the pet stays and GardenState retries later.
local function catchupLanding(input,racing,pet)
	local anchor=input and input.anchor
	if typeof(anchor)~="Vector3"then return nil end
	-- With no garden scene nothing can be checked: refuse (resolveGardenTarget would hand the spot back unchecked).
	if not gardenScene()then return nil end
	-- Pets go up: the owner on the path -> 4 studs behind them on the centre line, never on the flight; on the terrace ->
	-- the rings round the anchor on the terrace less 3. The island walls and the lawn's safe cells do not apply there.
	if petsUp()then
		local zone=TierPets.zone(anchor)
		if zone=="path"then
			local spot=TierPets.landing(anchor,pet)
			return spot and tierGround(spot,.8)
		elseif zone=="terrace"then
			for _,candidate in ipairs(PetCatchup.candidates(anchor,nil))do
				if TierPets.terraceSafe(candidate.X,candidate.Z)then
					local spot=tierGround(candidate,PetCatchup.Rise)
					if spot then return spot end
				end
			end
			return nil
		end
	end
	-- More safe ground while it is open: the Hush's, the Play Den's (its floor clear of the furniture).
	local hushSafe=if hushHost~=nil and hushHost.open then Hush.safeCell else nil
	local den=denLive()
	local extraSafe=hushSafe
	if den then extraSafe=function(x,z)return(hushSafe~=nil and hushSafe(x,z))or DenLayout.safeCell(den,x,z)end end
	local facing=nil
	local root=input.root
	if root and root.Parent then local look=root.CFrame.LookVector;facing=Vector3.new(look.X,0,look.Z)end
	for _,candidate in ipairs(PetCatchup.candidates(anchor,facing))do
		local spot=resolveGardenTarget(candidate,nil)
		if typeof(spot)=="Vector3"and PetCatchup.flat(spot,candidate)<=.5 and math.abs(spot.Y-anchor.Y)<=PetCatchup.Rise
			and PetCatchup.clear(spot.X,spot.Z,racing,anchor,extraSafe)then return spot end
	end
	return nil
end
local garden = GardenState.new({sharedToyEnabled=false,now=function()return workspace:GetServerTimeNow()end,
	publish=function(snapshot)
		gardenShared:SetAttribute("Snapshot",HttpService:JSONEncode(snapshot))
		for player,board in pairs(boards)do local actor=snapshot.actors[tostring(player.UserId)];board.careHeld=actor~=nil and actor.care~=nil;board.folder:SetAttribute("CareMode",if actor and actor.care then actor.mode else nil)end
	end,
    planPath=function(from,to,velocity,speed,minimum,yaw,via,terminal)
        local scene=gardenScene()
        local wet=if scene then scene.wet else {}
        -- Pets go up: between floors along the cliff path (TierPets.plan); on the terrace alone no lawn wet list (the
        -- path's footprints and the lawn's water lie under it in plan).
        if petsUp()then
            local path,seconds=TierPets.plan(from,to,velocity,speed,minimum,yaw,function(a,b,v,s,m,y,i,t)return GardenPathPlanner.plan(a,b,v,s,m,y,i,t,wet)end)
            if path then return path,seconds end
            if TierPets.zone(from)=="terrace"and TierPets.zone(to)=="terrace"then
                return GardenPathPlanner.plan(from,to,velocity,speed,minimum,yaw,via,terminal,{})
            end
        end
        return GardenPathPlanner.plan(from,to,velocity,speed,minimum,yaw,via,terminal,wet)
    end,
    resolveTarget=resolveGardenTarget,
    -- Beta (12) QA G1: pets catch up (PetCatchup; off unless its switch is on).
    catchup=function()return PetCatchup.on()end,
    landing=catchupLanding,
    -- Pets go up (TierPets): the catch-up gap along the route between floors; no settle sit on the path; no greeting
    -- across floors or on the path. All three answer today's default when the gate is closed (live).
    routeGap=function(pet,anchor)if not petsUp()then return nil end;return TierPets.routeDistance(pet,anchor)end,
    canSettle=function(position)return not petsUp()or TierPets.zone(position)~="path"end,
    canMeet=function(a,b)if not petsUp()then return true end;local za,zb=TierPets.zone(a),TierPets.zone(b);return za==zb and za~="path"end,
    warn=warn,
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
		-- Pets go up: focus on the terrace less 3, never on the path (transit only).
		if petsUp()and TierPets.up(target)then
			return TierPets.zone(target)=="terrace"and TierPets.terraceSafe(target.X,target.Z)and tierGround(target,.3)~=nil
		end
		if not PetFloors.ok(floor,target,hushHost~=nil and hushHost.open,tierHost~=nil and tierHost.open,denLive())then return false end
		local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
		local hit=workspace:Raycast(target+Vector3.new(0,3,0),Vector3.new(0,-6,0),params)
		return hit~=nil and math.abs(hit.Position.Y+.025-target.Y)<.3
	end})
-- Pets go up (TierPets): the rest spots on the terrace and at the path's turn while the gate is open; nil otherwise.
GardenState.tierRests=function()if petsUp()then return TierPets.rests()end;return nil end
-- The Top Lawn (ParkLayout, WORLD-FINISH-LOOK slice B): membership up there only while pets can go up. No effect on a
-- site without a floor (the arrival, the Hollow, the old grove: live).
require(ReplicatedStorage.Shared.ParkLayout).setTerraceGate(petsUp)
-- Pets stay on the ground level: an owner on a terrace, ramp, pillar, ledge or
-- bench leaves the pet at the last ground anchor (bridges and other authored
-- spans still count as ground). Kept out of petAnchor so care reach is unchanged.
local function groundAnchor(board,anchor,position)
	-- Pets go up: an anchor on the terrace or the path is followed, kept apart from the ground anchor (architect B2: the
	-- gate closing never leaves an up-there point as a lawn pet's target); a missing one while the owner is still up
	-- there is the last up-there anchor.
	if petsUp()then
		if anchor and TierPets.up(anchor)then board.upAnchor=anchor;return anchor end
		if not anchor and board.upAnchor and TierPets.up(position)then return board.upAnchor end
	end
	board.upAnchor=nil
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
	-- Charm ownership (Customization Egg): public() masks a saved charm the save does not own.
	local preferences=PetAppearance.public(board.profile,board.nursery.state.hues,board.nursery.state.petHues,board.nursery.state.petMaterials,board.nursery.state.petToys,board.nursery.state.petFeatures,board.profile.companionId,board.nursery.state.petWearables,board.nursery.state)
	return {petId=petId,owned=petId~=nil and NurseryCatalog.isOwned(inventory(board),petId),root=root,character=character,
		-- player scale: the carry anchor's offsets shrink with the avatar (PlayerScale)
		carryPosition=root and(root.Position+(root.CFrame.LookVector*1.2+Vector3.new(0,.3,0))*require(ReplicatedStorage.Shared.PlayerScale).of(character))or nil,
		alive=not board.closing and root~=nil and humanoid~=nil and humanoid.Health>0 and character:IsDescendantOf(workspace),
		characterId=board.characterGeneration or 0,petGeneration=board.companionGeneration or 0,position=position,mode=board.mode,
		anchor=if root then groundAnchor(board,petAnchor({root=root,position=position}),position)or Vector3.new(position.X,GardenLayout.groundAt(position.X,position.Z),position.Z)else Vector3.zero,
		yaw=if root then math.atan2(root.CFrame.LookVector.X,root.CFrame.LookVector.Z)else 0,
		charmVisible=preferences[petId]~=nil and preferences[petId].charmVisible==true}
end
local function gardenInputs()
	local inputs={}
	for player,board in pairs(boards)do inputs[player.UserId]=gardenInput(board)end
	return inputs
end
-- QA v685 R6: inspect and greet another player's pet (PetHello.lua). Reward-free; the
-- board carries only a small public summary (bond level, greetings off) and the wave.
local petHello={}
do
	local Rules=require(ReplicatedStorage.Shared.PetHelloRules)
	local Bond=require(ReplicatedStorage.Shared.BondCatalog)
	local remote=child("RemoteEvent","PetHello",remotes)
	local function boardOf(userId)
		local player=Players:GetPlayerByUserId(userId)
		return player and boards[player]or nil
	end
	petHello.state=require(script.PetHello).new({now=function()return workspace:GetServerTimeNow()end,garden=garden,
		viewer=function(userId)
			local board=boardOf(userId);local character=board and not board.closing and board.player.Character
			local root=character and character:FindFirstChild("HumanoidRootPart");local humanoid=character and character:FindFirstChildOfClass("Humanoid")
			return if root and humanoid and humanoid.Health>0 and character:IsDescendantOf(workspace)then root.Position else nil
		end,
		allowed=function(ownerId)local board=boardOf(ownerId);return board~=nil and not board.closing and board.profile.greetOff~=true end,
		clear=function(from,to)
			local scene=gardenScene();if not scene then return true end
			local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={scene.room}
			local target=to+Vector3.new(0,1,0)
			return workspace:Raycast(from,target-from,params)==nil
		end,
		publish=function(ownerId,hello)
			local board=boardOf(ownerId)
			if board and board.folder.Parent then board.folder:SetAttribute(Rules.Attribute,if hello then HttpService:JSONEncode(hello)else nil)end
		end})
	local StatCatalog=require(ReplicatedStorage.Shared.StatCatalog)
	local StatState=require(script.StatState)
	-- The public summary on the owner's board: greetings off, the selected pet's bond level and
	-- (v2 S4) every owned pet's stat levels. publishNursery reaches here after every saved
	-- transaction (award, pet, park, quest, daily, book), so the levels follow the save.
	function petHello.social(board)
		board.folder:SetAttribute(Rules.OffAttribute,board.profile.greetOff==true)
		local petId=board.profile.companionId
		local state=board.nursery and board.nursery.state
		local bond=state and state.bond
		board.folder:SetAttribute(Rules.BondAttribute,if petId then Bond.level(Bond.xpOf(bond,petId))else nil)
		board.folder:SetAttribute(StatCatalog.PublicAttribute,if state then HttpService:JSONEncode(StatState.publicLevels(state))else nil)
		-- Levels matter S3: the deck juice every client draws (nil while the part is off).
		local juice=state and require(script.DeckJuiceState).public(board.profile.deckJuice,state)or nil
		board.folder:SetAttribute(require(ReplicatedStorage.Shared.DeckJuiceCatalog).Attribute,if juice then HttpService:JSONEncode(juice)else nil)
		-- v2 names: piece ids per owned pet (never text); viewers build the text from NameCatalog.
		board.folder:SetAttribute(NameCatalog.Attribute,if state then HttpService:JSONEncode(NameState.publicNames(state))else nil)
	end
	remote.OnServerEvent:Connect(function(player,packet)
		local board=boards[player]
		if not board or board.closing then return end
		local result=petHello.state:request(player.UserId,packet)
		if result then remote:FireClient(player,result)end
	end)
end
local function publishPetAppearance(board)
	board.folder:SetAttribute("PetAppearance",HttpService:JSONEncode(PetAppearance.public(board.profile,board.nursery.state.hues,board.nursery.state.petHues,board.nursery.state.petMaterials,board.nursery.state.petToys,board.nursery.state.petFeatures,board.profile.companionId,board.nursery.state.petWearables,board.nursery.state)))
	board.folder:SetAttribute("PetAppearanceRevision",board.petPreferences.revision+board.nursery.state.revision)
	petHello.social(board)
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
	petHello.social(board)
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

-- Paint pots: one reply per request; a Retrying buy waits (board.potWaiting) for its proof in publishNursery.
local function sendPotResult(board,quote,status,reason,receipt)
 if not quote then return end
 potResult:FireClient(board.player,{id=quote.id,action=quote.action,status=status,reason=reason,revision=board.nursery.state.revision,receipt=receipt})
 local pending=board.nursery.pending;local awaiting=pending and pending.kind=="pot"and pending.candidate.quote.id==quote.id
 if status~="Retrying"and not awaiting and board.potWaiting and board.potWaiting.id==quote.id then board.potWaiting=nil end
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
	-- Slice E: a companion that is not owned, or an earned pet whose rig is not in this build,
	-- falls back to the first owned active pet (never an unrenderable companion).
	if canProgress(board) and not SessionProfile.usable(state.inventoryMask, board.profile.companionId) then
		local fallback = SessionProfile.firstOwnedActive(state.inventoryMask)
		if fallback then
			Progress.equipCompanion(board.profile, Pets.byId[fallback])
			publishCompanion(board)
		end
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
	-- Paint pots (architect review item 3): a Retrying buy that settled later reaches PaintPotIntent.
	if board.potWaiting and state.lastPotResult and state.lastPotResult.id==board.potWaiting.id then sendPotResult(board,board.potWaiting,"Saved",nil,state.lastPotResult)end
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

-- The First Hatch (artifacts/onboarding-2026-11-26/PLAN.md; Spencer: "three combos and the egg hatches"): with
-- Onboard.on("opener") the Welcome egg hatches on its third combo (a drop that merges at least once), counted here in
-- server memory; pip.charge and the saved charge are never touched until the grant. Read once per Welcome round, and
-- again until the first drop (the switch is off until OnboardConfig has loaded).
local function welcomeOpener(board)
	local welcome=board.welcome
	if not welcome or welcome.combo or(welcome.drops or 0)>0 then return end
	local on=false
	pcall(function()on=require(ReplicatedStorage.Shared.Onboard).on("opener")end)
	if not on then board.folder:SetAttribute("WelcomeComboTarget",nil);return end
	welcome.combo,welcome.combos,welcome.comboDrop=3,0,nil
	-- the opener's staircase (WelcomeSeed.Opener); a switch that resolves after the board was built re-seeds it
	-- before the first drop (code review: never mid-round)
	if board.sim and not board.sim.welcomeOpener and(board.sim.drops or 0)==0 then
		board.sim=require(script.WelcomeSeed).create(Simulation,board.sim.preset,board.sim.serial,board.sim.drops,true)
	end
	board.folder:SetAttribute("WelcomeComboTarget",3);board.folder:SetAttribute("WelcomeCombos",0)
end
local function publishWelcome(board)
	local welcome=board.welcome
	local snapshot=welcome and welcome:snapshot()
	board.folder:SetAttribute("WelcomeSkipReady",snapshot~=nil and snapshot.skipReady==true and not hasPet(board))
	board.folder:SetAttribute("WelcomeGrantPending",snapshot~=nil and snapshot.grantPending==true and not hasPet(board))
	board.folder:SetAttribute("WelcomeDemoUsed",snapshot~=nil and snapshot.demoUsed==true)
	board.folder:SetAttribute("WelcomeInputEpoch",snapshot and snapshot.inputEpoch or 0)
	board.folder:SetAttribute("WelcomeActiveSeconds",snapshot and math.floor(snapshot.activeSeconds*10)/10 or 0)
	board.folder:SetAttribute("WelcomeReplay",board.welcomeReplay or 0)
end
local function publishState(board)
	publishWelcome(board)
	board.folder:SetAttribute("Preset", board.sim.preset)
	board.folder:SetAttribute("Drops", board.sim.drops)
	board.folder:SetAttribute("NextTier", Simulation.nextTier(board.sim))
	board.folder:SetAttribute("PreviewTier1", Simulation.nextTier(board.sim, 1))
	board.folder:SetAttribute("PreviewTier2", Simulation.nextTier(board.sim, 2))
	BoardItems.publish(board, board.folder)
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
	-- S0: the tick the round ended on, so presentation can finish the last merge first.
	if BoardNet.ticks() then board.folder:SetAttribute("RoundOverTick", if board.round.over then BoardNet.tick(board) else nil) end
	board.folder:SetAttribute("RunFamily", board.runFamily or "pip")
	board.folder:SetAttribute("SelectedFamily", board.selectedFamily or "pip")
	board.folder:SetAttribute("DangerY", board.round.overflowY or Config.OverflowY)
	board.folder:SetAttribute("OverflowPressure", if board.round.over then 0 else board.round.danger or 0)
	board.folder:SetAttribute("OverflowGraceLeft", if board.round.over then 0 else (board.round.graceLeft or 0) / Config.Pace)
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
	-- Deck network S3: no tables, sort or string per Heartbeat. `live` is a reused
	-- scratch set and the content list is rebuilt only when a ball joins or leaves.
	local live = board.syncLive or {}
	board.syncLive = live
	table.clear(live)
	local membershipChanged = false
 -- Simulation.serial allocates ball IDs on drops/merges. ResetId alone is
 -- the stable presentation generation of this run.
 local runSerial=board.folder:GetAttribute("ResetId")
	for _, egg in ipairs(board.sim.eggs) do
		live[egg.id] = true
		local part = board.parts[egg.id]
		local created = part == nil
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
			if egg.dropToken then part:SetAttribute("DropToken", egg.dropToken) end
			board.parts[egg.id] = part
			membershipChanged = true
		end
		if part:GetAttribute("BoardSerial")~=runSerial then part:SetAttribute("BoardSerial",runSerial)end
		-- Round items (R1 renders): PowerUp = a star ball; ItemMark = an armed Bomb, or a Magnet still pulling.
		local powerUp=egg.powerUp~=nil
		if part:GetAttribute("PowerUp")~=powerUp then part:SetAttribute("PowerUp",powerUp)end
		local mark=if egg.mark=="magnet"and egg.hasContact and(egg.magnetLeft or 0)<=0 then nil else egg.mark
		if part:GetAttribute("ItemMark")~=mark then part:SetAttribute("ItemMark",mark)end
		local position = Vector3.new(egg.position.X, egg.position.Y, 0)
		-- S2: with the owner on the snapshot stream, the shared Parts move at 8 Hz.
		if part.Position ~= position and BoardNet.writePosition(board, created) then
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
			membershipChanged = true
		end
	end
	if not membershipChanged and board.contentSerial == runSerial then return end
	board.contentSerial = runSerial
	local contentIds = {}
	for id in pairs(live) do table.insert(contentIds, id) end
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
	board.pendingDrop = nil -- a queued drop never carries into a new run (deck network S4)
	board.folder:ClearAllChildren()
	table.clear(board.parts)
	local field = hasPet(board) and board.nursery.status == "Ready"
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
	-- Round items: power-up balls only in real fields (BUILD-PLAN item 7).
	local itemsOn=BoardItems.enabled({field=field==true,guided=board.heatGuided,totalWins=board.nursery.state.totalWins})
	local simOptions=nil
	if field then
		simOptions={}
		for key,value in pairs(FieldObjectives.simulationOptions(descriptor,preset,board.runHeat))do simOptions[key]=value end
		if itemsOn then simOptions.powerUps=board.runHeat end
	end
	if board.welcome then board.welcome:destroy();board.welcome=nil end
	if not field and not hasPet(board)then
		ClientSim.begin(board) -- code review: a Welcome reset never keeps a lockstep round
		board.sim=require(script.WelcomeSeed).create(Simulation,preset,board.sim and board.sim.serial)
		board.welcome=require(script.WelcomeState).new(board.runSequence)
		board.welcomeReplay=0;board.welcomeWindowActive=false
		welcomeOpener(board)
	else
		-- B3: today's board for this round, put in place when the client never answers the lockstep start.
		local function todaysBoard(serial)
			board.sim=Simulation.new(preset,serial,simOptions)
			if roundRecorder then roundRecorder.begin(board) end
		end
		board.sim=ClientSim.begin(board,preset,board.sim and board.sim.serial,field and descriptor or nil,itemsOn,todaysBoard)or Simulation.new(preset,board.sim and board.sim.serial,simOptions)
	end
	-- Belt, sequence and armed item never outlive their round (BUILD-PLAN item 3).
	BoardItems.reset(board, itemsOn)
	board.itemKinds = 0
	-- The Welcome round (no field yet) is safe: the fill line never ends it (onboarding v1).
	board.round = Round.new(if field then FieldRun.roundOptions(board.runHeat) elseif not hasPet(board) then { safe = true } else nil)
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
	board.folder:SetAttribute("ItemEvent", "")
	if roundRecorder and not board.lockstep then roundRecorder.begin(board) end
	publishHeat(board)
	publishState(board)
	syncVisuals(board)
end

local grantWelcome

-- Earned pets (slice E; SYSTEMS-SCOPE 1.3): one loop grants every pet EarnedPets.owed() names
-- (Blip on the 7th stamp). Started after a daily claim, and on join / save reload as a repair
-- for saves that passed the rule with the flag off or lost the write. Same shape as
-- grantWelcome: busy-aware, one write at a time, retried every 2 s, stops on close. The
-- ownership bit is the receipt, so a replay on any server converges; an ambiguous write is
-- left to the background Nursery.retry loop. With SecondPet off, owed() is empty: no loop.
local function grantEarned(player, board)
	if board.earnedRunning or #EarnedPets.owed(board.nursery.state) == 0 then return end
	board.earnedRunning = true
	task.spawn(function()
		local tries, attempted = 0, {}
		local function logGranted()
			for petId, logged in pairs(attempted) do
				if not logged and NurseryCatalog.isOwned(inventory(board), petId) then
					attempted[petId] = true
					Economy.event(player, "PetEarned", 1, { petId })
				end
			end
		end
		while boards[player] == board and not board.closing and tries < 60 do
			logGranted()
			local owed = EarnedPets.owed(board.nursery.state)
			if #owed == 0 then break end
			-- A grant bumps the save revision: wait for a short quiet window after the last
			-- command so the tap that follows a stamp never meets "RevisionChanged".
			local quiet = os.clock() - (board.lastNurseryCommand or -math.huge) >= 3
			if quiet and canProgress(board) and not board.nurseryBusy and not board.nursery.busy
				and not board.nursery.pending and not board.payoutPending then
				tries += 1
				if attempted[owed[1]] == nil then attempted[owed[1]] = false end
				board.nurseryBusy = true
				local ok, reason = Nursery.grantEarnedPet(board.nursery, owed[1])
				board.nurseryBusy = false
				if boards[player] ~= board then break end
				publishNursery(board)
				publishState(board)
				-- Disabled / NotEarned / UnknownPet can never succeed in this session.
				if not ok and reason ~= "Retrying" and reason ~= "Busy" and reason ~= "Pending" and reason ~= "RevisionChanged" then break end
			end
			task.wait(2)
		end
		if boards[player] == board then logGranted() end
		board.earnedRunning = false
	end)
end

local function addPlayer(player)
	if boards[player] or loading[player] then
		return
	end
	loading[player] = true
	-- Beta (12) QA T1 (code review 4): only the owner's fresh-save pointer is ever read; everyone else is player_<id>
	-- with no extra read. isOwner is asked only where the gate is open (never on live).
	do
		local ProgressKey = require(script.ProgressKey)
		local owner = false
		if ProgressKey.enabled() then
			local ok, result = pcall(require(ReplicatedStorage.Shared.SimCheck).isOwner, player)
			owner = ok and result == true
		end
		ProgressKey.markOwner(player.UserId, owner)
	end
	local profile = Progress.load(player.UserId)
	local nursery = Nursery.load(player.UserId, profile)
	-- v2 S2: the pet that earns stat XP for quests, stamps and book milestones.
	nursery.statPetOf = function() return profile.companionId end
	-- Fail closed until PolicyService answers: restricted players get fixed-order eggs.
	nursery.restricted = PaidRandomPolicy.cached(player)
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
	board.mode = if hasPet(board) then "Room" else "Board"
	boards[player] = board
	board.passes = {}
	board.nextHeat = if Config.validHeat(profile.lastHeat) then profile.lastHeat else Config.DefaultHeat
	StoreService.join(board)
	PaidRandomPolicy.resolveAsync(player, function(restricted)
		if boards[player] ~= board or board.closing then return end
		board.nursery.restricted = restricted
		publishNursery(board)
	end)
	reset(board, Config.DefaultPreset)
	publishNursery(board)
	publishPetAppearance(board)
	-- Slice E repair-on-join: a pet already earned but not granted yet.
	if board.profileReady then grantEarned(player, board) end
	-- Private beta and Studio: the owner can set the test save's Stars with "/stars N" in chat
	-- (Stars store access testing, Spencer 2026-11-21). Live: never connected.
	if (game.PlaceId == Nursery.BetaPlaceId or RunService:IsStudio()) and require(ReplicatedStorage.Shared.SimCheck).isOwner(player) then
		-- "/alive <feature|all> <on|off|clear>": its own connection, never behind the board and busy checks below.
		player.Chatted:Connect(function(message) pcall(function() require(script.AliveConfig).command(message) end) end)
		-- "/levels <on|off|clear>": the Levels matter switch, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.LevelsConfig).command(message) end) end)
		-- "/dash <on|off|clear>" and "/dash prizes <on|off|clear>": the Garden Dash switches, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.DashConfig).command(message) end) end)
		-- "/aero <on|off|clear>" and "/aero <lime|coral>": the Frutiger Aero look, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.AeroConfig).command(message) end) end)
		-- "/todo <on|off|clear>" and "/todo tips <on|off|clear>": the Things to do switches, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.ThingsConfig).command(message) end) end)
		-- "/onboard <follow|needs|nest|all> <on|off|clear>": the onboarding v3 switches, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.OnboardConfig).command(message) end) end)
		-- "/feel <feel|walk|all> <on|off|clear>": the beta 14 world feel switches, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.WorldFeelConfig).command(message) end) end)
		-- "/bounds <on|off|clear>": the island edges switch (wall top-ups, safe-spot return), this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.IslandBoundsConfig).command(message) end) end)
		-- "/finds <on|off|clear>": the Garden finds switch, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.FindsConfig).command(message) end) end)
		-- "/thisweek <on|off|clear>": the This week wardrobe pick switch, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.ThisWeekConfig).command(message) end) end)
		-- "/finds now": one find at once near you, past the timer (beta (12) QA G2), this server only.
		player.Chatted:Connect(function(message)
			if not garden.findsHost or not garden.findsHost.parseNow(message) then return end
			pcall(garden.findsHost.now, garden.findsHost, board)
		end)
		-- "/hour <on|off|clear>" and "/hour at <0-3599>": the garden hour switch and its test clock, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.GardenHourConfig).command(message) end) end)
		-- "/catchup <on|off|clear>": pets hop to their owner when far or stuck (beta (12) QA G1), this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.CatchupConfig).command(message) end) end)
		-- "/hush <on|off|clear>": the Hush switch; "/hush go" and "/hush home": the owner's own passage. This server only.
		player.Chatted:Connect(function(message) pcall(function() if not require(script.HushConfig).command(message) and garden.hushHost then garden.hushHost:command(board, message) end end) end)
		-- "/tier <on|off|clear>": the upper tier switch, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.TierConfig).command(message) end) end)
		-- "/tierpets <on|off|clear>": pets follow their owners up the cliff path (WORLD-FINISH-LOOK slice A), this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.TierPetsConfig).command(message) end) end)
		-- "/scale <0.6-1.2|clear>": the player's drawn scale (the world reads bigger), this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.PlayerScaleConfig).command(message) end) end)
		-- "/den <on|off|clear>": the Play Den switch, this server only.
		player.Chatted:Connect(function(message) pcall(function() require(script.DenConfig).command(message) end) end)
		-- "/netsim <rtt ms> [jitter ms] [loss %]" and "/netsim off" (Studio only): artificial Pocket Deck latency
		-- (DeckNetSim; deck net audit 2026-11-26). Sets the board folder's DeckNetSim attribute.
		if RunService:IsStudio() then
			player.Chatted:Connect(function(message)
				local value = DeckNetSim.command(message)
				if value == nil then return end
				board.folder:SetAttribute(DeckNetSim.Attribute, if value then value else nil)
				print("[DeckNetSim] " .. (if value then "on: rtt,jitter,loss = " .. value else "off"))
			end)
		end
		-- "/freshsave" and "/freshsave restore": the owner's next join is a brand-new save, or the old one again
		-- (beta (12) QA T1). One pointer write and a kick; FreshSave refuses unless ProgressKey's gate is open.
		player.Chatted:Connect(function(message) pcall(function() require(script.FreshSave).command(player, message) end) end)
		player.Chatted:Connect(function(message)
			local amount = type(message) == "string" and tonumber(string.match(message, "^%s*/stars%s+(%d+)%s*$"))
			if not amount or boards[player] ~= board or board.closing then return end
			if not canProgress(board) or board.nurseryBusy or board.nursery.busy or board.nursery.pending then return end
			board.nurseryBusy = true
			local ok = Nursery.betaSetStars(board.nursery, amount)
			board.nurseryBusy = false
			if boards[player] ~= board then return end
			if ok then publishNursery(board); publishState(board) end
		end)
	end
	-- Private beta: the owner's test save gets a one-time 1,000 Star top-up (the Bunny is 400).
	-- Not on a fresh test save (beta (12) QA T1): a first-session test starts with no Stars, so only the base key gets it.
	-- Checked again on every try: a refused first load (unreadable pointer) reloads later onto whatever key resolves.
	if game.PlaceId == Nursery.BetaPlaceId and require(ReplicatedStorage.Shared.SimCheck).isOwner(player) then
		local baseKey = require(script.ProgressKey).base(player.UserId)
		task.spawn(function()
			for _ = 1, 30 do
				if boards[player] ~= board or board.closing then return end
				if canProgress(board) and board.nursery.key ~= baseKey then return end
				if canProgress(board) and not board.nurseryBusy and not board.nursery.busy and not board.nursery.pending
					and board.nursery.key == baseKey then
					board.nurseryBusy = true
					local ok, why = Nursery.betaGrantStars(board.nursery, "beta:stars:2026-11-20", 1000)
					board.nurseryBusy = false
					if boards[player] ~= board then return end
					publishNursery(board); publishState(board)
					if ok or (why ~= "Busy" and why ~= "Pending" and why ~= "Retrying" and why ~= "RevisionChanged") then return end
				end
				task.wait(2)
			end
		end)
	end
	folder:SetAttribute("Mode", board.mode)
	folder:SetAttribute("DeckThemeId", profile.theme)
	folder:SetAttribute("DeckStickerId", profile.sticker)
	folder:SetAttribute("DeckBackgroundId",profile.background)
	folder:SetAttribute("AppearanceFallbacks",HttpService:JSONEncode(profile.appearanceFallbacks or {}))
	folder:SetAttribute("AppearanceRevision",board.appearance.revision)
	folder:SetAttribute("SoundLevel", profile.sound)
	folder:SetAttribute("ReducedEffects", profile.reduced)
	folder:SetAttribute("MenuColours", if profile.menuClassic then "classic" else "deck")
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
			if petOk and petReason~="AlreadySaved"then
				-- G2: the first hello's extra Stars are their own source (Onboarding / FirstHello), never petting income.
				local receipt=board.nursery.state.lastPetAward
				local hello=if type(receipt)=="table"and receipt.id==candidate.id and type(receipt.hello)=="number"and receipt.hello>0 then receipt.hello else 0
				local after=board.nursery.state.nectar
				Economy.source(player,after-walletBefore-hello,after-hello,"Gameplay","PetCare")
				if hello>0 then Economy.source(player,hello,after,"Onboarding","FirstHello")end
			end
			if petOk and petReason~="AlreadySaved"and board.firstSession then board.firstSession:record("FirstPet")end
			if petOk and petReason~="AlreadySaved"and board.nursery.state.petCount==(Nursery.PetDailyCap or 10)then Economy.event(player,"PettingCapReached")end
			board.nurseryBusy=false
			if boards[player]==board and not board.closing then publishNursery(board);publishState(board)end
		end,
		emit=function(packet)
			if boards[player]==board and not board.closing and player.Parent==Players then petContactRemote:FireClient(player,packet)end
		end})
	folder.Parent = trays
	if board.firstSession then
		board.firstSession:hit("BoardReady")
	end
	local function spawn(character)
		board.characterGeneration=(board.characterGeneration or 0)+1;board.groundAnchor=nil
		character:SetAttribute("GardenCharacterId",board.characterGeneration)
		board.folder:SetAttribute("GardenCharacterId",board.characterGeneration)
		-- Player scale (beta): the avatar is drawn at PlayerScale once its appearance has loaded, in place (never holds
		-- the spawn; architect review). Ceiling off: returns at once, nothing touched.
		pcall(function() require(script.PlayerScaleConfig).prepare(player, character) end)
		Lounge.spawn(character, slot, player, function()
			return board.mode, profile.theme
		end)
		if board.mode == "Room" and board.firstSession then board.firstSession:hit("InGarden") end
	end
	board.characterConnection = player.CharacterAdded:Connect(spawn)
	if player.Character then
		task.spawn(spawn, player.Character)
	end
end

local settleReward
local function closeBoard(board)
	if board.closing then return end
	closing[board] = true
	board.closing = true
	-- B2: a lockstep round's reward held for the save is settled now, so CloseProgress.drain saves it.
	if board.lockstep and board.lockstep.rewardHeld then
		board.lockstep.rewardHeld = false
		Progress.recordScore(board.profile, board.round.score)
		Progress.recordTrials(board.profile, board.peakChain, board.round.score, board.round.maxClears)
		settleReward(board.player, board)
	end
	if board.welcome then board.welcome:destroy()end
	-- Garden Dash: a race still running pays nothing; what had finished is drained below (nil while Dash is off).
	if garden.dashHost then
		local ok, problem = pcall(garden.dashHost.leave, garden.dashHost, board)
		if not ok then warn("[Dash] leave: " .. tostring(problem)) end
	end
	-- Garden finds: live sparkles and unsaved claims go; a find write in flight is settled below, then CloseProgress.drain.
	if garden.findsHost then
		local ok, problem = pcall(garden.findsHost.leave, garden.findsHost, board)
		if not ok then warn("[Finds] leave: " .. tostring(problem)) end
	end
	-- Garden fruit: an unsaved claim goes; a fruit write in flight is settled below, then CloseProgress.drain.
	if garden.fruitHost then
		local ok, problem = pcall(garden.fruitHost.leave, garden.fruitHost, board)
		if not ok then warn("[Fruit] leave: " .. tostring(problem)) end
	end
	-- Sleepy Nest: writes not yet sent go; a nest write in flight is settled below, then CloseProgress.drain.
	if garden.nestHost then
		local ok, problem = pcall(garden.nestHost.leave, garden.nestHost, board)
		if not ok then warn("[Nest] leave: " .. tostring(problem)) end
	end
	-- Onboarding v3: the per-session follow capture (FirstSession's table choice) goes with the player.
	pcall(function() require(ReplicatedStorage.Shared.Onboard).forget(board.player) end)
	-- The Hush: the passage record is forgotten (nil while the build ceiling is off).
	if garden.hushHost then
		local ok, problem = pcall(garden.hushHost.leave, garden.hushHost, board)
		if not ok then warn("[Hush] leave: " .. tostring(problem)) end
	end
	-- Island edges: the safe spot is forgotten (nil while the build ceiling is off).
	if garden.boundsHost then
		local ok, problem = pcall(garden.boundsHost.leave, garden.boundsHost, board)
		if not ok then warn("[Bounds] leave: " .. tostring(problem)) end
	end
	garden:remove(board.player.UserId)
	petHello.state:remove(board.player.UserId)
	if board.petContact then board.petContact:destroy()end
	task.spawn(function()
		local settled = 0
		if garden.dashHost then
			local from = os.clock()
			local ok, problem = pcall(garden.dashHost.settle, garden.dashHost, board)
			if not ok then warn("[Dash] settle: " .. tostring(problem)) end
			settled = os.clock() - from
		end
		-- Code review: a find write in flight is settled too, so the Play date write below is not skipped as pending.
		if garden.findsHost then
			local from = os.clock()
			local ok, problem = pcall(garden.findsHost.settle, garden.findsHost, board)
			if not ok then warn("[Finds] settle: " .. tostring(problem)) end
			settled += os.clock() - from
		end
		if garden.fruitHost then
			local from = os.clock()
			local ok, problem = pcall(garden.fruitHost.settle, garden.fruitHost, board)
			if not ok then warn("[Fruit] settle: " .. tostring(problem)) end
			settled += os.clock() - from
		end
		if garden.nestHost then
			local from = os.clock()
			local ok, problem = pcall(garden.nestHost.settle, garden.nestHost, board)
			if not ok then warn("[Nest] settle: " .. tostring(problem)) end
			settled += os.clock() - from
		end
		-- Code review: queued Play date / parkGames counts are saved once on leave (the flush loop
		-- stops at closing), unless a write for them is still in flight or ambiguous.
		if (board.parkPending or 0) > 0 and not board.parkInFlight and board.nursery and not board.nursery.pending then
			pcall(Nursery.parkPlay, board.nursery, HttpService:GenerateGUID(false), board.parkPending, board.profile.companionId,
				math.min(board.parkFetchPending or 0, board.parkPending))
		end
		local ok, reason = CloseProgress.drain(Nursery, board.nursery, board.earnedPayout, {
			profileFlush = function() return Progress.flushOnce(board.profile) end,
			dash = garden.dashHost and garden.dashHost:drain(board) or nil,
			timeout = CloseProgress.remaining(settled),
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
-- Slice A analytics: funnel step 8 on any Stars sink; session totals on leave.
Economy.onSink = function(player)
	local board = boards[player]
	if board and board.firstSession then board.firstSession:hit("FirstSpend") end
end
Players.PlayerRemoving:Connect(function(player)
	local board = boards[player]
	if board then
		Economy.eventNow(player, "SessionRounds", board.sessionRounds or 0)
		if board.nursery and board.nursery.state and type(board.nursery.state.nectar) == "number" then
			Economy.eventNow(player, "SessionEndWallet", board.nursery.state.nectar)
		end
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
	if kind=="parkThrow"then
		local result=require(script.ParkThrowHost).request(board,garden,player.UserId,packet,now,function()
			garden:syncOne(player.UserId,gardenInput(board))
		end)
		if result and player.Parent then parkResult:FireClient(player,result)end
		garden:publish()
		return
	end
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

-- Saved ownership is stronger than the transient pending latch. Duplicate Skip
-- acknowledgements must never regress Applied back to Retrying after commit.
local function settledWelcomeStatus(board,sequence)
	if not board.welcome or sequence~=board.runSequence then return nil end
	if NurseryCatalog.isOwned(inventory(board),"pip")then return "Applied"end
	if board.welcome.grantPending then return "Retrying"end
	return nil
end
-- token (optional): the client's drop token, stamped on the new ball (Part attribute DropToken)
-- so the client can hand its ghost to that Part even when the Part beats the ack (v890 QA).
local function acceptedDrop(board,value,now,isDemo,token)
	if board.closing or board.mode~="Board"or board.menuPaused or board.round.over or not canProgress(board)
		or(board.field and(not board.field:canDrop(board.sim.drops)or not Simulation.canDrop(board.sim)))
		or typeof(value)~="number"or not(value>=0 and value<=1)or now-board.lastDrop<Config.DropInterval then return false end
	board.lastDrop=now
	if board.welcome then welcomeOpener(board)end -- the First Hatch: a late-loading switch still counts from drop one
	if not Simulation.drop(board.sim,value)then return false end
	if roundRecorder then roundRecorder.drop(board,value)end
	if token then local dropped=board.sim.eggs[#board.sim.eggs];if dropped and dropped.id==board.sim.fallingId then dropped.dropToken=token end end
	board.runDay=RunDay.onDrop(board.runDay,board.sim.drops,Daily.dayOf(board.nursery.adapter.now()))
	if board.welcome and not isDemo then board.welcome:acceptedDrop()end
	publishState(board)
	if board.firstSession then
		board.firstSession:hit("FirstDrop")
		if board.sim.drops==1 then board.firstSession:roundStarted()end
	end
	return true
end

-- Deck network S4: a drop refused only by the drop interval or the contact gate may wait
-- (BoardNet.QueueSeconds, one deep); every other refusal is final. Same checks as
-- acceptedDrop, so the rate stays bounded.
local function dropRetryable(board,value,now)
	if board.closing or board.mode~="Board"or board.menuPaused or board.round.over or not canProgress(board)
		or typeof(value)~="number"or not(value>=0 and value<=1)or #board.sim.eggs>=Config.MaxEggs then return false end
	if board.field and not board.field:canDrop(board.sim.drops)then return false end
	return now-board.lastDrop<Config.DropInterval or not Simulation.canDrop(board.sim)
end

-- Why a drop was refused, for the ack (presentation and the harness; never a rule).
local function dropRefusal(board,value,now)
	if typeof(value)~="number"or not(value>=0 and value<=1)then return "Aim"end
	if board.round.over then return "RoundOver"end
	if board.field and not board.field:canDrop(board.sim.drops)then return "Budget"end
	if #board.sim.eggs>=Config.MaxEggs then return "Full"end
	if now-board.lastDrop<Config.DropInterval then return "Interval"end
	if not Simulation.canDrop(board.sim)then return "Gate"end
	return "Spawn" -- a ball rests in the spawn space
end

local function onBoardRequest(player, action, value, sticker)
	local board = boards[player]
	if not board then return end
	local now = os.clock()
	if action=="petAppearance" then
		local usable=if board.closing then "Closing"else canProgress(board)
		local packet,changed=PetAppearance.request(board.petPreferences,board.profile,value,now,usable,
			function(petId)return NurseryCatalog.isOwned(inventory(board),petId)end,Progress.setPetAppearance,
			-- Charm ownership (slice D earned rules, Customization Egg charmUnlocks) is checked against the
			-- save for any request that would show a charm, including visibility-only (plan §3.4).
			function(shape)return PetAppearance.earned(shape,board.nursery.state)end)
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
		if action=="drop" then BoardNet.ack(board,player,BoardNet.dropToken(sticker),false,"Closing") end
		if action=="appearance" then appearanceResult:FireClient(player,{slot="pair",seq=0,id="",status="Rejected",
			reason="Closing",revision=board.appearance.revision,themeId=board.profile.theme,stickerId=board.profile.sticker,backgroundId=board.profile.background}) end
		return
	end
	if (action == "sound" or action == "motion" or action == "companion"
		or action == "family" or action == "drop" or action == "reset" or action == "preset" or action == "restart" or action == "item")
		and not canProgress(board) then
		-- Deck network S4: a refused tokened drop is answered, so the client's latch opens.
		if action == "drop" then BoardNet.ack(board,player,BoardNet.dropToken(sticker),false,"Unavailable") end
		return
	end
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
	if action == "whiteSecond" then
		-- Free White second colour (Spencer 2026-11-19), saved in the profile record. Only pets this
		-- build draws (PetRigDefinitions); never on a profile that failed to load (the write would be lost).
		if type(value) ~= "table" or type(value.petId) ~= "string" or type(value.on) ~= "boolean" then return end
		if not canProgress(board) or board.closing or board.profile.loadFailed then return end
		if not require(ReplicatedStorage.Shared.PetRigDefinitions)[value.petId] or not NurseryCatalog.isOwned(inventory(board), value.petId) then return end
		if board.whiteSecondAt and now - board.whiteSecondAt < .25 then return end
		board.whiteSecondAt = now
		local map = table.clone(board.profile.whiteSecond or {})
		if (map[value.petId] == true) == value.on then return end
		map[value.petId] = if value.on then true else nil
		Progress.setSetting(board.profile, "whiteSecond", map)
		publishPetAppearance(board)
		Progress.requestFlush(board.profile)
		return
	end
	if action == "deckJuice" then
		-- Levels matter S3: {kind, id}. Known and unlocked from the save, or ignored (DeckJuiceState).
		if type(value) ~= "table" then return end
		if not canProgress(board) or board.closing or board.profile.loadFailed then return end
		local DeckJuice = require(script.DeckJuiceState)
		if board.juiceAt and now - board.juiceAt < DeckJuice.Throttle then return end
		board.juiceAt = now
		local map = DeckJuice.choose(board.profile.deckJuice, board.nursery.state, value.kind, value.id)
		if not map then return end
		Progress.setSetting(board.profile, "deckJuice", map)
		petHello.social(board)
		if DeckJuice.flushDue(board, now) then Progress.requestFlush(board.profile) end
		return
	end
	if action == "menuColours" then
		-- Toy Shell R1.1 Settings: "Menu colours: Match my deck / Classic Shell" (client paint only).
		if value ~= nil or not canProgress(board) then return end
		local classic = board.profile.menuClassic ~= true
		Progress.setSetting(board.profile, "menuClassic", classic)
		board.folder:SetAttribute("MenuColours", if classic then "classic" else "deck")
		return
	end
	if action == "greetings" then
		-- R6 Settings: "Let visitors greet my pet". Off withdraws a wave that is running.
		if value ~= nil or not canProgress(board) then return end
		local off = board.profile.greetOff ~= true
		Progress.setSetting(board.profile, "greetOff", off)
		petHello.social(board)
		if off then petHello.state:cancel(player.UserId) end
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
	if action=="welcomeActive"then
		if type(value)=="boolean"and board.welcome and not hasPet(board)then board.welcomeWindowActive=value end
		return
	elseif action=="deckShown"then
		-- The First Hatch (architect review): one-time events, never a v3 step (FirstSession records each name once)
		if board.firstSession then board.firstSession:record("DeckShown")end
		return
	elseif action=="eggTapped"then
		if board.firstSession and hasPet(board)then board.firstSession:record("EggTapped")end
		return
	elseif action=="onboardEvent"then
		-- Onboarding v2: a one-time event from the client's list only (Onboard.Events), for a save that owns a pet;
		-- FirstSession records each name once. Nothing is granted or saved.
		local ok,known=pcall(function()return require(ReplicatedStorage.Shared.Onboard).Events[value]==true end)
		if type(value)=="string"and ok and known and board.firstSession and hasPet(board)then board.firstSession:record(value)end
		return
	elseif action=="petLead"then
		-- Onboarding v3 brief section 1 (Onboard "lead"): the Bear leads the player to the nest (GardenState:lead, the
		-- rules in Shared.PetLead). Presentation only: it moves the asker's own garden pet, nothing is granted or saved.
		-- value = {kind = "start", route = {Vector3...}} (the trail route from the pet to the nest's prompt), or "back"
		-- (a nudge), "stop" (paused, parked, done) or "cheer" (the jump-spin; also with `allset2`).
		if type(value)~="table"or type(value.kind)~="string"then return end
		-- a stop always ends the lead, whatever the switches say now (ConfigService may turn `lead` off mid-lead)
		if value.kind=="stop"then garden:leadEnd(player.UserId);return end
		local Lead=require(ReplicatedStorage.Shared.PetLead)
		local okOn,leadOn,allSetOn=pcall(function()
			local Onboard=require(ReplicatedStorage.Shared.Onboard)
			return Onboard.leadOn(),Onboard.on("allset2")
		end)
		if not okOn or not hasPet(board)or board.mode~="Room"or board.closing then return end
		local kind=value.kind
		if kind=="cheer"then
			if not(leadOn or allSetOn)or now-(board.leadCheerAt or -math.huge)<1 then return end
			board.leadCheerAt=now
			garden:leadCheer(player.UserId)
			return
		end
		if not leadOn then return end
		-- each kind at most once every Asks.gap s, and a bounded number of starts a session
		if kind~="back"and kind~="start"then return end
		board.leadAskAt=board.leadAskAt or {}
		if now-(board.leadAskAt[kind]or -math.huge)<Lead.Asks.gap then return end
		board.leadAskAt[kind]=now
		if kind=="back"then garden:leadBack(player.UserId);return end
		board.leadStarts=(board.leadStarts or 0)+1
		if board.leadStarts>Lead.Asks.starts then return end
		local character=player.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		local actor=garden.actors[player.UserId]
		if not root or not actor then return end
		local sample=require(ReplicatedStorage.Shared.GardenActivity).sample(actor,workspace:GetServerTimeNow())
		local pet=sample and sample.position
		if not pet or Lead.flat(pet,root.Position)>Lead.Far then return end
		local Corner=require(ReplicatedStorage.Shared.EggCorner)
		local nest=Corner.nestSpot()
		local skip={}
		for _,other in ipairs(Players:GetPlayers())do if other.Character then table.insert(skip,other.Character)end end
		-- water is hit (IgnoreWater false) so the ground below refuses it: no route point, and so no poof, on water
		local groundParams=RaycastParams.new();groundParams.RespectCanCollide=true;groundParams.FilterType=Enum.RaycastFilterType.Exclude
		groundParams.IgnoreWater=false
		groundParams.FilterDescendantsInstances=skip
		local skipSolid=table.clone(skip);table.insert(skipSolid,workspace.Terrain)
		local solidParams=RaycastParams.new();solidParams.RespectCanCollide=true;solidParams.FilterType=Enum.RaycastFilterType.Exclude
		solidParams.FilterDescendantsInstances=skipSolid
		local route=type(value.route)=="table"and value.route or nil
		local raw={}
		for i,point in ipairs(route or {})do if i>Lead.Route.max+1 then return end;raw[i]=point end
		local points=Lead.clean(raw,{pet=pet,nest=nest,
			ground=function(p)
				local hit=workspace:Raycast(p+Vector3.new(0,Lead.Route.ground,0),Vector3.new(0,-Lead.Route.ground*2,0),groundParams)
				if not hit or hit.Material==Enum.Material.Water then return nil end
				return hit.Position.Y
			end,
			-- a fence, a wall or a prop between two route points at the pet's body height (the ground is not one)
			clear=function(a,b)
				local up=Vector3.new(0,Lead.Route.body,0)
				local d=(b+up)-(a+up)
				return d.Magnitude<.05 or workspace:Raycast(a+up,d,solidParams)==nil
			end})
		if not points then return end
		local goal=Lead.trim(points,Lead.Arrive)
		goal=goal[#goal]
		if Lead.flat(goal,nest)>Lead.Route.goalNear then return end
		local ok=garden:lead(player.UserId,Lead.simplify(Lead.trim(points,Lead.Arrive)),goal,nest)
		if ok and board.firstSession then pcall(function()board.firstSession:record("LeadStarted")end)end
		return
	elseif action=="firstStand"then
		-- Beta (37) note 1: the first hatch's Bear stands where its egg opened (FirstHatchStory, Onboard "stork"), then
		-- follows. Presentation only (GardenState:stand): a spot on solid ground near the owner, a few asks a session.
		-- Only during the first hatch's hand-off: armed when the starter receipt's ack arrives (Meet; the nursery
		-- request's "ack"), spent by the one stand it honours; any other time it is ignored.
		if not board.firstStandArmed then return end
		if type(value)~="table"or typeof(value.at)~="Vector3"or type(value.hold)~="number"or value.hold~=value.hold then return end
		local okOn,storyOn=pcall(function()return require(ReplicatedStorage.Shared.Onboard).storyOn()end)
		if not(okOn and storyOn)or not hasPet(board)or board.mode~="Room"or board.closing then return end
		board.firstStands=(board.firstStands or 0)+1
		if board.firstStands>4 then return end
		local character=player.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		local at=value.at
		if not root or at.X~=at.X or at.Y~=at.Y or at.Z~=at.Z then return end
		local flat=Vector3.new(at.X-root.Position.X,0,at.Z-root.Position.Z)
		if flat.Magnitude>14 or math.abs(at.Y-root.Position.Y)>8 then return end
		local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Exclude
		local skip={}
		for _,other in ipairs(Players:GetPlayers())do if other.Character then table.insert(skip,other.Character)end end
		params.FilterDescendantsInstances=skip
		local hit=workspace:Raycast(at+Vector3.new(0,3,0),Vector3.new(0,-6,0),params)
		if not hit or math.abs(hit.Position.Y-at.Y)>.6 then return end
		local spot=Vector3.new(at.X,hit.Position.Y+.025,at.Z)
		local toOwner=Vector3.new(root.Position.X-spot.X,0,root.Position.Z-spot.Z)
		if garden:stand(player.UserId,spot,if toOwner.Magnitude>.01 then math.atan2(toOwner.X,toOwner.Z)else nil,value.hold)then
			board.firstStandSpent,board.firstStandArmed=board.firstStandArmed,nil -- once per receipt (the ack's resends never re-arm it)
		end
		return
	elseif action=="welcomeInput"then
		if board.welcome and type(value)=="table"and value.sequence==board.runSequence and now-(board.welcomeInputAt or -math.huge)>=.1 then
			board.welcomeInputAt=now;board.welcome:input();publishWelcome(board)
		end
		return
	elseif action=="welcomeSkip"then
		local sequence=type(value)=="table"and value.sequence or nil
		local welcome=board.welcome
		local settled=settledWelcomeStatus(board,sequence)
		if settled then
			if player.Parent then welcomeResult:FireClient(player,{sequence=sequence,status=settled})end
			return
		end
		if not welcome or sequence~=board.runSequence or board.mode~="Board"or board.menuPaused or hasPet(board)
			or not canProgress(board)or not welcome:requestGrant("skip",sequence)then
			if player.Parent then welcomeResult:FireClient(player,{sequence=sequence,status="Rejected",reason="Unavailable"})end
			return
		end
		if board.firstSession then board.firstSession:record("OnbSkipWelcome")end
		publishWelcome(board);grantWelcome(player,board)
		return
	end
	if action == "pause" then
		if typeof(value) == "boolean" then
			if roundRecorder and board.menuPaused ~= value then roundRecorder.pause(board, value) end
			board.menuPaused = value
		end
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
		-- Slice E: owned and renderable in this build (SessionProfile.usable).
		if board.mode == "Room" and pet and SessionProfile.usable(inventory(board), pet.id)
			and value ~= board.profile.companionId and now - board.lastCompanionChange >= 0.35 then
			board.lastCompanionChange = now
			gardenCareHost:switch(board,pet.id)
		end
		return
	end
	if action == "mode" then
		if now - board.lastModeChange < Config.ModeSwitchInterval or value == board.mode
			or (value ~= "Board" and (value ~= "Room" or not hasPet(board))) then
			return
		end
        if value=="Board"and board.round.over and hasPet(board)and RunReturn.classify(board,canProgress(board),true)=="Preserve"then return end
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
            local refreshed=RunReturn.enter(board,canProgress(board),hasPet(board),reset)
            -- A completed field can leave Room only after exact saved payout
            -- permits its fresh replacement. Active fields resume unchanged.
            if board.round.over and hasPet(board)and not refreshed then return end
        end
		board.mode = value
		if roundRecorder and board.menuPaused then roundRecorder.pause(board, false) end
		board.menuPaused = false
		Lounge.setMode(player.Character, player.UserId, value, board.profile.theme)
		board.folder:SetAttribute("Mode", value)
		garden:sync(gardenInputs());garden:publish()
		if value == "Room" and board.firstSession then
			board.firstSession:record("FirstSessionLoungeVisit")
			if player.Character then board.firstSession:hit("InGarden") end
		end
		return
	end
	if board.mode ~= "Board" then
		if action == "drop" then BoardNet.ack(board,player,BoardNet.dropToken(sticker),false,"NotBoard") end
		return
	end
	if action == "drop" then
		-- B4: after a desync fallback the server runs the round: today's drop becomes a host input.
		if board.lockstep then if not ClientSim.serverInput(board,"drop",value,BoardNet.dropToken(sticker))then BoardNet.ack(board,player,BoardNet.dropToken(sticker),false,"ClientSim")end;return end
		if board.welcome then board.welcome:input()end
		local token=BoardNet.dropToken(sticker)
		if acceptedDrop(board,value,now,false,token) then BoardNet.ack(board,player,token,true)
		elseif token and not board.pendingDrop and dropRetryable(board,value,now) then
			board.pendingDrop={aim=value,token=token,expires=now+BoardNet.QueueSeconds}
		else BoardNet.ack(board,player,token,false,if board.pendingDrop then "Busy"else dropRefusal(board,value,now)) end
	elseif action == "item" then
		-- B2: items are inputs on the BoardClientSim remote (B4: or host inputs on a server-run round).
		if board.lockstep then ClientSim.serverInput(board,"item",type(value)=="table"and BoardItems.safeId(value.id)or nil);return end
		-- Round items: accepted while paused (the carousel freezes the round).
		local ok, result = BoardItems.request(board, value, { resetId = board.folder:GetAttribute("ResetId"),
			ready = canProgress(board), now = now, budget = board.field and board.field.budget })
		if ok then
			-- Slice D (win_each_item): which item kinds this round used, as a 4-bit mask.
			board.itemKinds = bit32.bor(board.itemKinds or 0, Nursery.itemKindBit(result.id))
			if roundRecorder then roundRecorder.item(board, result.id) end
			local position = result.position
			BoardItems.event(board, board.folder, { kind = "used", id = result.id, eggId = result.eggId,
				x = position and position.X or nil, y = position and position.Y or nil, lostStar = result.lostStar ~= nil })
			publishState(board)
			syncVisuals(board)
		elseif result ~= "Stale" and result ~= "Malformed" and result ~= "Throttled" then
			BoardItems.event(board, board.folder, { kind = "refused", id = type(value) == "table" and BoardItems.safeId(value.id) or nil, reason = result })
		end
	elseif action == "restart" then
		-- Pocket Menu restart: same field template, new seed; its own 3 s cooldown.
		if now - board.lastReset < Config.ResetInterval or now - (board.lastRestart or -math.huge) < 3 then return end
		if RunReturn.restart(board, canProgress(board), hasPet(board), value, function(target, preset) reset(target, preset, "template") end) then
			board.lastReset, board.lastRestart = now, now
			board.menuPaused = false
		end
	elseif action == "reset" or action == "preset" then
		if board.payoutPending then return end
		if now - board.lastReset < Config.ResetInterval then
			return
		end
		if action == "reset" then
			if not RunReturn.retry(board, canProgress(board), hasPet(board), value, reset) then return end
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
end
-- Deck net audit: in Studio, a board folder DeckNetSim ("/netsim <rtt> [jitter] [loss]") holds this player's
-- board requests (reset, mode, pause, today's-path drops) for one simulated round trip, in order; the
-- client driver holds its lockstep messages the same way. Live: never (IsStudio), so this is a direct call.
local requestNetSim = {}
local requestNetSimOn = RunService:IsStudio()
request.OnServerEvent:Connect(function(player, action, value, sticker)
	local link = requestNetSim[player]
	local board = boards[player]
	local config = if requestNetSimOn and board then DeckNetSim.parse(board.folder:GetAttribute(DeckNetSim.Attribute)) else nil
	if not config and not (link and link:size() > 0) then onBoardRequest(player, action, value, sticker); return end
	if not link then link = DeckNetSim.link(config, 1, player.UserId); requestNetSim[player] = link end
	link.config = config -- nil (just switched off): no more delay, still behind what it holds
	link:push(os.clock(), { action = action, value = value, sticker = sticker })
end)
if RunService:IsStudio() then
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, link in pairs(requestNetSim) do
			for _, item in ipairs(link:due(now) or {}) do
				local ok, problem = pcall(onBoardRequest, player, item.action, item.value, item.sticker)
				if not ok then warn("[DeckNetSim] board request failed:", problem) end
			end
			if link:size() == 0 and (player.Parent == nil or not link.config) then requestNetSim[player] = nil end
		end
	end)
end

local messages = {
	NeedNectar = "Earn more Stars in a field run.", NeedStars="Earn more Stars in a field run.", RevisionChanged = "Your progress updated. Refresh your preview.",
	Busy = "Finishing your last hatch action…", Pending = "Retry the previous action while it saves.",
	Retrying = "Saving is delayed. Your result will stay the same when retried.",
	SessionLost = "This hatch session moved to another server. Rejoin to continue.",
	Locked = "Your previous session is closing. Please wait a moment.",
	Temporary = "Loading your save. Please wait before spending Stars.",
	BalanceLimit = "Your Stars wallet is full, so this round's Stars could not be added.",
	DayChanged = "A new day just started. Open the gift again for today's stamp.",
	DailyClaimed = "Today's stamp is already on your card.",
}

-- One-time coach cards (onboarding v1): queued bits save when the hatching save is idle
-- (no busy command, pending write or payout), one write for everything queued. The write
-- ORs bits in, so an ambiguous one left to the background Nursery.retry loop is harmless:
-- the loop waits for the saved mask to cover the queue, then stops.
local function flushCoach(player, board)
	if board.coachFlushing then return end
	board.coachFlushing = true
	board.coachFlushStart = os.clock()
	task.spawn(function()
		local tries = 0
		while boards[player] == board and not board.closing and tries < 60 and os.clock() - (board.coachFlushStart or 0) < 900 do
			local queued = CoachMarks.mask(board.coachPending)
			if queued == 0 or CoachMarks.covers(board.nursery.state.coachMask, queued) then board.coachPending = nil; break end
			-- Quiet window (code review): a coach write bumps the save revision, so it waits until no
			-- player command (hatch, buy, equip...) arrived for 10 s and 10 s passed since the card was
			-- queued; a first Hatch tap right after the Hatch card never meets "Busy"/"RevisionChanged".
			local quiet = os.clock() - math.max(board.lastNurseryCommand or -math.huge, board.coachQueuedAt or -math.huge) >= 10
			if quiet and canProgress(board) and not board.nurseryBusy and not board.nursery.busy and not board.nursery.pending and not board.payoutPending then
				tries += 1
				board.nurseryBusy = true
				local ok, reason = Nursery.coachMark(board.nursery, queued)
				board.nurseryBusy = false
				if boards[player] ~= board then break end
				if not ok and reason == "InvalidCoach" then board.coachPending = nil; break end
				publishNursery(board)
			end
			task.wait(2)
		end
		board.coachFlushing = false
	end)
end

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
	-- (the welcome gift neither: its own loop waits for a free save, and it must not hold the coach bits' flush back)
	if action ~= "coachMark" and action ~= "welcomeGift" and action ~= "giftEgg" then board.lastNurseryCommand = os.clock() end
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
	-- v2 Bunny: adopt an earned pet for its fixed Star price (EarnedPets.Rules[petId].stars), from
	-- the Companions Pets page. Idempotent by the client's operation id; owning it already (the
	-- 7th-stamp grant got there first) is "AlreadyOwned" with no charge; a save that has earned it
	-- gets it free ("EarnedFree", the grant). Replies ride FaceplateResult with kind="adopt".
	-- "Pending" (another write holds the save, maybe an earlier adopt) answers "Retrying", never
	-- "nothing was spent".
	if action=="petAdopt"then
		local v=if type(value)=="table"then value else {}
		local opId=if type(v.id)=="string"and #v.id>=1 and #v.id<=80 then v.id else nil
		local petId=if type(v.petId)=="string"and #v.petId<=32 then v.petId else nil
		local price=if type(v.price)=="number"then v.price else nil
		local function reply(status,reason)faceplateResult:FireClient(player,{kind="adopt",id=opId,petId=petId,status=status,reason=reason,revision=board.nursery.state.revision})end
		if not opId or not petId or not price then reply("Rejected","InvalidAdopt");return end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then reply("Rejected","Throttled");return end
		board.lastHatchRequest=os.clock()
		if board.nurseryBusy or board.payoutPending then reply("Rejected","Busy");return end
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		local ok,reason=Nursery.adoptPet(board.nursery,opId,petId,price)
		if reason=="Pending"then reason="Retrying"end
		-- Analytics name the species (the account id "blip" is the Bunny's slot); logged before the
		-- leave check, as faceplateBuy does.
		local species=string.lower(Pets.byId[petId]and Pets.byId[petId].name or petId)
		if ok and reason=="Saved"then
			Economy.command(player,"Adopt_"..species,walletBefore,board.nursery.state.nectar,board.nursery.state)
			Economy.event(player,"PetAdopted",1,{species})
		elseif ok and reason=="EarnedFree"and not board.earnedRunning then
			-- (A running grant loop logs PetEarned itself.)
			Economy.event(player,"PetEarned",1,{petId})
		end
		board.nurseryBusy=false;if boards[player]~=board then return end
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
			if ok and type(itemId)=="string"and not board.wardrobeEquipLogged then board.wardrobeEquipLogged=true;Economy.event(player,"WardrobeEquip",1,{itemId})end
		end
		board.nurseryBusy=false;if boards[player]~=board then return end
		publishNursery(board);publishState(board);publishPetAppearance(board)
		reply(if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason);return
	end

	-- Ball themes (hatching v11, batch R1): fixed Star price, server-validated,
	-- idempotent by the client's operation id (bound to theme + price); equip any
	-- owned or free theme. Replies ride FaceplateResult with kind="ballTheme".
	if action=="ballThemeBuy"or action=="ballThemeEquip"then
		local v=if type(value)=="table"then value else {}
		local opId=if type(v.id)=="string"and #v.id<=80 then v.id else nil
		local themeId=if type(v.themeId)=="string"and #v.themeId<=32 then v.themeId else nil
		local function reply(status,reason)faceplateResult:FireClient(player,{kind="ballTheme",action=action,id=opId,themeId=themeId,status=status,reason=reason,revision=board.nursery.state.revision})end
		if not opId or not themeId then reply("Rejected","InvalidBallTheme");return end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then reply("Rejected","Throttled");return end
		board.lastHatchRequest=os.clock()
		if board.nurseryBusy or board.payoutPending then reply("Rejected","Busy");return end
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		local ok,reason
		if action=="ballThemeBuy"then
			ok,reason=Nursery.buyBallTheme(board.nursery,opId,themeId,if type(v.price)=="number"then v.price else nil,v.equip~=false)
			if ok and reason~="AlreadyOwned"then Economy.command(player,"BallTheme_"..themeId,walletBefore,board.nursery.state.nectar,board.nursery.state)end
		else
			ok,reason=Nursery.equipBallTheme(board.nursery,opId,themeId)
		end
		board.nurseryBusy=false;if boards[player]~=board then return end
		publishNursery(board);publishState(board)
		reply(if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason);return
	end

	-- v2 Stat Eggs (V2-PET-AND-SNACKS-SCOPE 2.4, V2-FEEDING-RUNES 2.5): buy and hatch one egg into the
	-- pouch, or feed one snack. Idempotent by the client's op id (keep it across Retrying and
	-- timeouts); a saved receipt replays read-only. The live checks (pet out, no round, park, care
	-- or carry, the 1.5 s feed cooldown) are here; the save checks are in StatEggState.
	if action=="statEggBuy"or action=="snackFeed"then
		local v=if type(value)=="table"then value else {}
		local opId=if type(v.id)=="string"and #v.id>=1 and #v.id<=80 then v.id else nil
		local petId=if type(v.petId)=="string"and #v.petId<=32 then v.petId else nil
		local function reply(status,reason,receipt)snackResult:FireClient(player,{id=opId,action=action,status=status,reason=reason,receipt=receipt,revision=board.nursery.state.revision})end
		if not opId or not petId then reply("Rejected","InvalidSnack");return end
		local saved=StatEggState.receipt(board.nursery.state,opId)
		-- The gift chain's Snack Egg (v.gift): its own op replays from `gifts.snack` (the receipt ring keeps 32).
		local giftSnack=action=="statEggBuy"and v.gift==true and require(ReplicatedStorage.Shared.GiftEggs).record(board.nursery.state,"snack")or nil
		if giftSnack and giftSnack.op~=opId then reply("Rejected","AlreadyGranted");return end
		if saved or giftSnack then
			-- Read-only proof; Hatching checks the digest (same request or OperationConflict).
			local ok,reason,receipt
			if action=="statEggBuy"then ok,reason,receipt=Nursery.statEggBuy(board.nursery,opId,petId,v.free==true,if type(v.quote)=="string"then v.quote else "",v.gift==true)
			else ok,reason,receipt=Nursery.snackFeed(board.nursery,opId,v.snackId,petId)end
			reply(if ok then "Saved"else "Rejected",reason,receipt);return
		end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then reply("Rejected","Throttled");return end
		if board.nurseryBusy or board.payoutPending then reply("Rejected","Busy");return end
		if petId~=board.profile.companionId then reply("Rejected","PetNotOut");return end
		if action=="snackFeed"then
			if board.mode~="Room"then reply("Rejected","InRound");return end
			local actor=garden.actors[player.UserId]
			if actor and(actor.park or actor.care or actor.dash or actor.toyReservation)then reply("Rejected","PetBusy");return end
			if os.clock()-(board.lastFeedAt or -math.huge)<StatEggCatalog.FeedCooldown then reply("Rejected","Throttled");return end
		end
		board.lastHatchRequest=os.clock()
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		local ok,reason,receipt
		if action=="statEggBuy"then
			if type(v.free)~="boolean"or type(v.quote)~="string"or #v.quote>64 or(v.gift~=nil and type(v.gift)~="boolean")then ok,reason=false,"InvalidStatEgg"
			elseif v.gift==true and not require(ReplicatedStorage.Shared.Onboard).on("gifts")then ok,reason=false,"NotReady"
			else ok,reason,receipt=Nursery.statEggBuy(board.nursery,opId,petId,v.free,v.quote,v.gift==true)end
		else
			ok,reason,receipt=Nursery.snackFeed(board.nursery,opId,v.snackId,petId)
		end
		if ok and reason~="AlreadySaved"then snackEffects(player,board,action,receipt,walletBefore)end
		board.nurseryBusy=false;if boards[player]~=board then return end
		publishNursery(board);publishState(board)
		reply(if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason,receipt);return
	end

	-- v2 pet names: buy one Names Egg (8 Stars, one new piece) or rename a pet (free). The egg is
	-- idempotent by the client's op id (keep it across Retrying); a saved receipt replays read-only.
	-- Renames store piece ids only; the save checks are in NameState.
	if action=="nameEggBuy"or action=="petName"then
		local v=if type(value)=="table"then value else {}
		local opId=if type(v.id)=="string"and #v.id>=1 and #v.id<=80 then v.id else nil
		local function reply(status,reason,receipt)nameResult:FireClient(player,{id=opId,action=action,status=status,reason=reason,receipt=receipt,revision=board.nursery.state.revision})end
		if not opId then reply("Rejected","InvalidName");return end
		if action=="nameEggBuy"then
			if type(v.quote)~="string"or #v.quote>64 then reply("Rejected","InvalidNameEgg");return end
			if NameState.receipt(board.nursery.state,opId)then
				-- Read-only replay, still throttled (code review).
				if os.clock()-(board.lastNameReplay or -math.huge)<.3 then reply("Rejected","Throttled");return end
				board.lastNameReplay=os.clock()
				local ok,reason,receipt=Nursery.nameEggBuy(board.nursery,opId,v.quote)
				reply(if ok then "Saved"else "Rejected",reason,receipt);return
			end
		end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then reply("Rejected","Throttled");return end
		if board.nurseryBusy or board.payoutPending then reply("Rejected","Busy");return end
		board.lastHatchRequest=os.clock()
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		local ok,reason,receipt
		if action=="nameEggBuy"then
			ok,reason,receipt=Nursery.nameEggBuy(board.nursery,opId,v.quote)
			if ok and reason~="AlreadySaved"and type(receipt)=="table"then
				Economy.command(player,"NameEgg",walletBefore,board.nursery.state.nectar,board.nursery.state)
				Economy.event(player,"EggOpened_name",1,{tostring(receipt.piece),tostring(receipt.mode)})
			end
		else
			local petId=if type(v.petId)=="string"and #v.petId<=32 then v.petId else nil
			local pieces=if type(v.pieces)=="table"then v.pieces else nil
			if not petId or not pieces then ok,reason=false,"InvalidName"
			else ok,reason=Nursery.setPetName(board.nursery,petId,pieces)end
		end
		board.nurseryBusy=false;if boards[player]~=board then return end
		publishNursery(board);publishState(board)
		reply(if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason,receipt);return
	end

	-- The gift chain's Paint and Toy cranks (GiftEggs, Onboard "gifts"; ONBOARDING-FUN-PASS section 2). The client asks
	-- when the player turns the machine for a gift. GiftEggHost owns the order (a saved record first, the switch, one loop
	-- a board, the tries); HatchProgress.giftEgg gives it once per save inside UpdateAsync, only when its trigger holds.
	-- giftSeen: the gift card was closed (its reveal replays on a rejoin until then).
	if action=="giftEgg"or action=="giftSeen"then
		local v=if type(value)=="table"then value else {}
		local kind=if type(v.kind)=="string"and require(ReplicatedStorage.Shared.GiftEggs).Crankable[v.kind]then v.kind else nil
		local opId=if type(v.id)=="string"and #v.id>=1 and #v.id<=80 then v.id else nil
		local function reply(status,reason,record)
			if boards[player]==board then giftResult:FireClient(player,{id=opId,kind=kind,action=action,status=status,reason=reason,gift=record,revision=board.nursery.state.revision})end
		end
		if not kind then reply("Rejected","InvalidGift");return end
		local Gifts=require(ReplicatedStorage.Shared.GiftEggs)
		if action=="giftEgg"then
			if os.clock()-(board.lastGiftAsk or -math.huge)<.5 then reply("Rejected","Throttled");return end
			board.lastGiftAsk=os.clock()
		end
		if action=="giftSeen"then
			-- once per gift (seen never goes back), so a replay costs no write; still spaced from other saves
			if os.clock()-(board.lastGiftSeen or -math.huge)<.5 then reply("Rejected","Throttled");return end
			board.lastGiftSeen=os.clock()
			if board.nurseryBusy or board.payoutPending or not canProgress(board)then reply("Rejected","Busy");return end
			board.nurseryBusy=true
			local called,ok,reason=pcall(Nursery.giftSeen,board.nursery,kind)
			board.nurseryBusy=false
			if boards[player]~=board then return end
			if not called then warn("[Gift] "..tostring(ok));reply("Rejected","Unavailable");return end
			publishNursery(board)
			reply(if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason);return
		end
		task.spawn(function()
			local ok,problem=pcall(require(script.GiftEggHost).request,{
				saved=function()return Gifts.publicRecord(kind,Gifts.record(board.nursery.state,kind))end,
				on=function()return require(ReplicatedStorage.Shared.Onboard).on("gifts")end,
				running=function()return board.giftRunning==true end,
				setRunning=function(on)board.giftRunning=on==true end,
				alive=function()return boards[player]==board and not board.closing end,
				free=function()return canProgress(board)and not board.nurseryBusy and not board.nursery.busy and not board.payoutPending end,
				grant=function()
					board.nurseryBusy=true
					local okNest,nestOn=pcall(function()return require(ReplicatedStorage.Shared.Onboard).on("nest")end)
					local called,granted,why,record=pcall(Nursery.giftEgg,board.nursery,kind,{nest=not okNest or nestOn==true,mask=board.coachPending})
					board.nurseryBusy=false -- always freed, even when the call threw
					if not called then warn("[Gift] "..tostring(granted));return false,"Unavailable"end
					if granted and why=="Saved"and type(record)=="table"then Economy.event(player,"EggOpened_gift",1,{kind,tostring(record.item)})end
					return granted,why,record
				end,
				wait=function(seconds)task.wait(seconds)end,
				publish=function()if boards[player]==board then publishNursery(board);publishState(board)end end,
				reply=reply,
			})
			if not ok then board.giftRunning=false;warn("[Gift] "..tostring(problem));reply("Rejected","Unavailable")end
		end)
		return
	end

	-- The welcome gift (ONBOARDING-V3-BRIEF section 3, Onboard "allset2"; Spencer OK'd it 2026-11-27): the client asks
	-- once when "You're all set!" shows. WelcomeGiftHost owns the order (paid first, the switch, one loop a board, the
	-- tries); HatchProgress.welcomeGift pays +5 once per save inside UpdateAsync, only on a save owed it whose three
	-- guide facts are saved. A refusal or a slow save never holds the card: the client shows the gift only on Saved.
	if action=="welcomeGift"then
		local function reply(status,reason,stars)
			if boards[player]==board then welcomeGiftResult:FireClient(player,{status=status,reason=reason,stars=stars})end
		end
		task.spawn(function()
			local ok,problem=pcall(require(script.WelcomeGiftHost).request,{
				paid=function()return require(ReplicatedStorage.Shared.WelcomeGift).paid(board.nursery.state)end,
				on=function()return require(ReplicatedStorage.Shared.Onboard).on("allset2")end,
				running=function()return board.welcomeGiftRunning==true end,
				setRunning=function(on)board.welcomeGiftRunning=on==true end,
				alive=function()return boards[player]==board and not board.closing end,
				free=function()return canProgress(board)and not board.nurseryBusy and not board.nursery.busy and not board.payoutPending end,
				grant=function()
					local walletBefore=board.nursery.state.nectar
					board.nurseryBusy=true
					local okNest,nestOn=pcall(function()return require(ReplicatedStorage.Shared.Onboard).on("nest")end)
					local called,granted,why=pcall(Nursery.welcomeGift,board.nursery,{nest=not okNest or nestOn==true,mask=board.coachPending})
					board.nurseryBusy=false -- always freed, even when the call threw
					if not called then warn("[WelcomeGift] "..tostring(granted));return false,"Unavailable"end
					local after=board.nursery.state.nectar
					if granted and why=="Saved"and after>walletBefore then Economy.source(player,after-walletBefore,after,"Gameplay","WelcomeGift")end
					return granted,why
				end,
				wait=function(seconds)task.wait(seconds)end,
				publish=function()if boards[player]==board then publishNursery(board);publishState(board)end end,
				reply=reply,
			})
			if not ok then board.welcomeGiftRunning=false;warn("[WelcomeGift] "..tostring(problem));reply("Rejected","Unavailable")end
		end)
		return
	end

	-- One-time coach cards (onboarding v1): the client names a card it has shown; the bit
	-- queues on the board and saves through Nursery.coachMark when the save is idle
	-- (flushCoach). Unknown ids are dropped; a bit already saved or queued costs nothing.
	if action=="coachMark"then
		if not CoachMarks.validId(value)then return end
		if not CoachMarks.allows(value)then return end
		if board.firstSession then
			if value=="gardenIntro"then board.firstSession:hit("GardenWalkthrough")
			elseif value=="hatch"or value=="style"or value=="companions"or value=="quests"or value=="book"then board.firstSession:hit("FirstMachine",value)end
		end
		local bit=CoachMarks.bit(value)
		if CoachMarks.covers(board.nursery.state.coachMask,bit)or CoachMarks.covers(board.coachPending,bit)then return end
		board.coachPending=CoachMarks.merge(board.coachPending,bit)
		board.coachQueuedAt=os.clock()
		flushCoach(player,board)
		return
	end

	-- Collection book milestone claim (play-forever F1): the server computes the page
	-- percent from the save; the client sends only {id = opId, milestoneId}. Idempotent by
	-- the op id (bound to milestone + reward). Replies ride FaceplateResult with kind="book";
	-- `faceplate` names the book-only plate when this claim granted it.
	if action=="bookClaim"then
		local v=if type(value)=="table"then value else {}
		local opId=if type(v.id)=="string"and #v.id<=80 then v.id else nil
		local milestoneId=if type(v.milestoneId)=="string"and #v.milestoneId<=40 then v.milestoneId else nil
		local milestone=BookCatalog.milestone(milestoneId)
		local granted,paid=nil,0
		local function reply(status,reason)faceplateResult:FireClient(player,{kind="book",action=action,id=opId,milestoneId=milestoneId,
			reward=if paid>0 then paid else nil,faceplate=granted,
			status=status,reason=reason,revision=board.nursery.state.revision})end
		if not opId or not milestone then reply("Rejected","InvalidMilestone");return end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then reply("Rejected","Throttled");return end
		board.lastHatchRequest=os.clock()
		if board.nurseryBusy or board.payoutPending then reply("Rejected","Busy");return end
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		-- Slice C: any book-only plate (Bookworm, Stargazer...) this claim grants or repairs.
		local platesBefore=Nursery.bookPlatesOwned(board.nursery.state)
		local ok,reason=Nursery.bookClaim(board.nursery,opId,milestone.id,if type(v.reward)=="number"then v.reward else nil)
		if ok and board.nursery.state.nectar>walletBefore then paid=board.nursery.state.nectar-walletBefore;Economy.source(player,paid,board.nursery.state.nectar,"Gameplay","BookMilestone")end
		if ok and reason~="AlreadySaved"and reason~="AlreadyClaimed"then Economy.event(player,"BookMilestone",1,{milestone.id})end
		if ok then
			local platesAfter=Nursery.bookPlatesOwned(board.nursery.state)
			for _,plateId in ipairs(Nursery.bookPlateIds())do
				if platesAfter[plateId]and not platesBefore[plateId]then granted=plateId;break end
			end
		end
		board.nurseryBusy=false;if boards[player]~=board then return end
		publishNursery(board);publishState(board)
		reply(if ok then(if reason=="AlreadyClaimed"then "AlreadyClaimed"else "Saved")elseif reason=="Retrying"then "Retrying"else "Rejected",reason);return
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
		if ok and action=="questClaim"and reason~="AlreadyClaimed"and board.firstSession then board.firstSession:hit("FirstQuest")end
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
  if ok and reason~="AlreadySaved"and(action=="toyBuy"or action=="featureBuy")then Economy.eggOpened(player,itemKind,saved)end
  if ok and action=="toyBuy"then board.toyBought=true end
  if ok and action=="toyEquip"and board.toyBought and board.firstSession then board.firstSession:hit("ToyGiven")end
  if reason=="Retrying"then board[itemKind.."Waiting"]=quote end
  board.nurseryBusy=false;if boards[player]~=board then return end
  publishNursery(board);publishState(board)
  sendItemResult(board,itemKind,quote,if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason,saved);return
 end
	-- Paint pots (PAINT-SHINE-DRESS-PLAN): never sold now (Spencer, beta 38: "we want a gacha focused game"; pots come
	-- only from the Paint Egg). PaintPotHost answers a buy that already committed (beta 38) and refuses every other one
	-- as NotSold: no charge, no write. This only hands it the board.
	if PaintPotState.isAction(action)then
		PaintPotHost.request({
			state=function()return board.nursery.state end,
			publish=function()publishNursery(board);publishState(board)end,
			reply=function(quote,status,reason,receipt)sendPotResult(board,quote,status,reason,receipt)end,
		},action,value,revision)
		return
	end
	if MaterialState.isAction(action)then
		local quote=if type(value)=="table"and type(value.id)=="string"and #value.id<=100 then {id=value.id,action=action,petId=value.petId}else nil
		local canonical=MaterialState.quote(action,value,revision)
		local receipt,same=MaterialState.find(board.nursery.state,canonical)
		if receipt and same then publishNursery(board);sendMaterialResult(board,quote,"Saved","AlreadySaved",MaterialState.publicReceipt(receipt));return end
		local pending=board.nursery.pending
		local samePending=pending and pending.kind=="material"and MaterialState.same(pending.candidate.quote,canonical)
		if samePending and(board.nurseryBusy or board.nursery.busy or board.payoutPending or os.clock()-(board.lastHatchRequest or -math.huge)<.3)then sendMaterialResult(board,quote,"Retrying","Busy");return end
		if action=="materialBuy"and not samePending and not MaterialCatalog.available(ReplicatedStorage:FindFirstChild("PetMaterials"),ReplicatedStorage:FindFirstChild("PetMaterialsTwoTone"))then sendMaterialResult(board,quote,"Rejected","MaterialsUnavailable");return end
		if os.clock()-(board.lastHatchRequest or -math.huge)<.3 then sendMaterialResult(board,quote,"Rejected","Throttled");return end
		board.lastHatchRequest=os.clock()
		if board.nurseryBusy or board.payoutPending then sendMaterialResult(board,quote,"Rejected","Busy");return end
		board.nurseryBusy=true;publishNursery(board)
		local walletBefore=board.nursery.state.nectar
		local ok,reason,saved=Nursery.materialCommand(board.nursery,action,value,revision)
		if ok then Economy.command(player,action,walletBefore,board.nursery.state.nectar,board.nursery.state)end
		if ok and reason~="AlreadySaved"and action=="materialBuy"then Economy.eggOpened(player,"material",saved)end
		if reason=="Retrying"then board.materialWaiting=quote end
		board.nurseryBusy=false;if boards[player]~=board then return end
		publishNursery(board);publishState(board)
		sendMaterialResult(board,quote,if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason,saved);return
	end
	local isHue=HueState.isAction(action)
	if action ~= "hatch" and action ~= "ack" and action ~= "daily" and not isHue then return end
	-- The first hatch's Meet acks the starter receipt, then asks for the hand-off (firstStand): arm it (once) here, as the
	-- ack arrives, whatever the save then says (the stand's ask does not wait for the ack's write).
	do
		local last = board.nursery and board.nursery.state and board.nursery.state.lastHatch
		if action == "ack" and type(last) == "table" and last.starter == true and last.id == value and board.firstStandSpent ~= value then board.firstStandArmed = value end
	end
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
	if ok and reason ~= "AlreadySaved" then
		Economy.command(player, action, walletBefore, board.nursery.state.nectar, board.nursery.state)
		if action == "hatch" and board.firstSession then board.firstSession:record("FirstHatch") end
		if action == "hueBuy" then Economy.eggOpened(player, "hue", receipt) end
		-- Customization Egg (slice 4): the day-7 wallet check reads this sink.
		if action == "lookBuy" then Economy.eggOpened(player, "look", receipt) end
		if action == "daily" and type(board.nursery.state.stamps) == "number" and board.nursery.state.stamps > 0 then
			Economy.event(player, "StampAdded", ((board.nursery.state.stamps - 1) % 7) + 1)
		end
	end
	-- Slice E: the stamp that meets an earned pet's rule starts its grant (also covers a
	-- claim whose write was ambiguous and committed later: owed() reads the saved stamps).
	if action == "daily" then grantEarned(player, board) end
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

settleReward = function(player, board)
	if board.payoutRunning then return end
	local amount = board.field.outcome.reward
	board.folder:SetAttribute("FieldSuccess", board.field.outcome.success)
	board.folder:SetAttribute("FieldReason", board.field.outcome.reason)
	board.folder:SetAttribute("FieldFinalStage", board.field.outcome.rootStage)
	local summary = { family = board.runFamily, day = RunDay.forSummary(board.runDay, Daily.dayOf(board.nursery.adapter.now())), success = board.field.outcome.success,
		clean = board.field.outcome.success and amount == 8, score = board.round.score, chain = board.peakChain,
		clears = board.round.maxClears, drops = board.sim.drops, heat = board.runHeat,
		maxTier = math.clamp(board.maxTier or 0, 0, #Config.Tiers), goalsMet = board.field.outcome.rootStage,
		templateId = board.field.descriptor.id,
		-- Lifetime counters (play-forever F1): merges this round, accepted item uses (BoardItems).
		merges = math.clamp(board.merges or 0, 0, 10000), itemsUsed = math.clamp(board.itemSeq or 0, 0, 64),
		-- Slice D: item kinds used this round (bits swap 1, pop 2, bomb 4, magnet 8).
		itemKinds = bit32.band(board.itemKinds or 0, 15) }
	board.settledRounds = (board.settledRounds or 0) + 1
	if board.firstSession then board.firstSession:roundSettled() end
	-- Slice F: the companion at the end of the round earns the bond XP. It rides in a copy of
	-- the boost table so the close-drain path (CloseProgress passes payout.boost) carries it too.
	local passBoost = StoreService.boost(board)
	local boost = { multiplier = passBoost.multiplier, bonus = passBoost.bonus, petId = board.profile.companionId }
	board.earnedPayout = { sequence = board.runSequence, amount = amount, summary = summary, saved = false, boost = boost }
	board.payoutPending, board.payoutRunning = true, true
	board.folder:SetAttribute("RewardStatus", "Saving")
	task.spawn(function()
		local failures = 0
		while boards[player] == board and not board.closing and board.payoutPending do
			local wait = 2
			if not board.closing and not board.nurseryBusy and not board.nursery.busy then
				local ok, reason = Nursery.award(board.nursery, board.runSequence, amount, summary, boost, boost.petId)
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
						-- Growth cuts: the Welcome bonus is its own source, so it is never read as round income.
						local starter = if type(saved.starter) == "number" and saved.starter > 0 then saved.starter else 0
						local balance = Nursery.public(board.nursery).nectar
						Economy.source(player, saved.total - starter, balance - starter, "Gameplay", "RoundReward:" .. (summary.heat or "medium"))
						if starter > 0 then Economy.source(player, starter, balance, "Onboarding", "StarterBonus") end
					end
					Economy.event(player, if summary.success then "RoundWon" else "RoundLost")
					board.sessionRounds = (board.sessionRounds or 0) + 1
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

grantWelcome=function(player,board)
	if board.starterRunning or hasPet(board)then return end
	local welcome=board.welcome
	local sequence=board.runSequence
	if welcome and not welcome.grantPending and not welcome:requestGrant("charge",sequence)then return end
	board.starterRunning=true;publishWelcome(board)
	task.spawn(function()
		while boards[player]==board and not board.closing and not hasPet(board)and board.runSequence==sequence and board.welcome==welcome do
			if board.profileReady and not board.nurseryBusy and not board.nursery.busy then
				local handle=board.nursery
				local walletBefore=handle.state.nectar
				-- Onboard "allset2" (beta and Studio only): this new save is owed the one-time welcome gift.
				local okGift,owed=pcall(function()return require(ReplicatedStorage.Shared.Onboard).on("allset2")end)
				-- Onboard "gifts" (beta and Studio only): this new save is owed the gift chain's three free cranks.
				local okChain,chain=pcall(function()return require(ReplicatedStorage.Shared.Onboard).on("gifts")end)
				local ok,reason=Nursery.grantStarter(handle,okGift and owed==true,okChain and chain==true)
				if boards[player]~=board or board.closing or board.nursery~=handle then break end
				-- The save is authoritative even if a reset happened during the yielding write.
				-- A stale Welcome owner cannot replay a cinematic or another reward.
				local owned=hasPet(board)
				if owned then
					if handle.state.nectar>walletBefore then Economy.source(player,handle.state.nectar-walletBefore,handle.state.nectar,"Gameplay","WelcomeRound")end
					-- Skip starts at legacy rank0: normalize only AFTER atomic Bear/+6 proof.
					if board.profile.rank<1 then Progress.chargeHatch(board.profile,math.max(0,Pets.byId.pip.charge-board.profile.charge))end
					board.profile.companionId="pip"
					publishCompanion(board)
					if board.firstSession then board.firstSession:hit("BearMet")end
				end
				publishNursery(board);publishState(board)
				if board.runSequence~=sequence or board.welcome~=welcome then break end
				if owned then
					break
				elseif not ok and(reason=="InvalidData"or reason=="InvalidStarter")then
					if welcome then welcome:grantRejected()end
					if player.Parent then welcomeResult:FireClient(player,{sequence=sequence,status="Rejected",reason=reason})end
					publishWelcome(board);break
				elseif not ok and player.Parent then welcomeResult:FireClient(player,{sequence=sequence,status="Retrying",reason=reason})end
			end
			task.wait(2)
		end
		-- Nursery's independent retry loop can prove ownership while this task sleeps;
		-- reconcile the legacy profile and ack from that same saved proof as well.
		if boards[player]==board and not board.closing and hasPet(board)then
			if board.profile.rank<1 then Progress.chargeHatch(board.profile,math.max(0,Pets.byId.pip.charge-board.profile.charge))end
			board.profile.companionId="pip";publishCompanion(board)
			publishNursery(board);publishState(board)
			if board.firstSession then board.firstSession:hit("BearMet")end
			if board.runSequence==sequence and board.welcome==welcome and player.Parent then welcomeResult:FireClient(player,{sequence=sequence,status="Applied"})end
		end
		board.starterRunning=false
	end)
end

-- Pet Park (FeatureFlags.Park, slice K1). Finished playground activities queue on the board and
-- save through Nursery.parkPlay under the quest-claim busy rules: stats.parkGames, today's Play
-- date count and +4 Stars once a day at 3. After today's Play date is paid, further counts
-- coalesce into one write a minute. Each write carries an op id; playDate.op proves what
-- committed, so a retried (ambiguous) write is subtracted exactly once.
-- Both immediate and recovered commits use one durable receipt/finalizer. A later wallet
-- purchase cannot inflate or hide the original Play date payment in analytics.
local function finishParkFlight(player, board, flight)
	return require(script.ParkGameCommit).finish(board, flight, Nursery, {
		now = os.clock,
		source = function(amount, balance) Economy.source(player, amount, balance, "Gameplay", "PlayDate") end,
		event = function() Economy.event(player, "PlayDateDone", 1) end,
	})
end
local function flushParkGames(player, board)
	if board.parkFlushing then return end
	board.parkFlushing = true
	task.spawn(function()
		while boards[player] == board and not board.closing and ((board.parkPending or 0) > 0 or board.parkInFlight) do
			local pause = 2
			local flight = board.parkInFlight
			if flight and Nursery.parkCommitted(board.nursery, flight.id) then
				finishParkFlight(player, board, flight)
			elseif flight and board.nursery.pending and board.nursery.pending.id == flight.id then
				-- Ambiguous write: the background Nursery.retry loop settles it; wait for its proof.
			else
				board.parkInFlight = nil
				local quiet = Nursery.playDateDone(board.nursery) and os.clock() - (board.parkSavedAt or -math.huge) < 60
				if (board.parkPending or 0) > 0 and not quiet and canProgress(board) and not board.nurseryBusy and not board.nursery.busy
					and not board.nursery.pending and not board.payoutPending then
					local nextFlight = { id = HttpService:GenerateGUID(false), count = board.parkPending,
						fetches = math.min(board.parkFetchPending or 0, board.parkPending) }
					board.parkInFlight = nextFlight
					board.nurseryBusy = true; publishNursery(board)
					local ok, reason = Nursery.parkPlay(board.nursery, nextFlight.id, nextFlight.count, board.profile.companionId, nextFlight.fetches)
					board.nurseryBusy = false
					if boards[player] ~= board then break end
					if Nursery.parkCommitted(board.nursery, nextFlight.id) then
						finishParkFlight(player, board, nextFlight)
					elseif not ok and reason ~= "Retrying" then
						board.parkInFlight = nil
						if reason == "InvalidParkPlay" or reason == "InvalidData" then board.parkPending = 0;board.parkFetchPending = 0;board.folder:SetAttribute("ParkGamesPending",0)end
					end
					publishNursery(board); publishState(board)
				elseif quiet then pause = 5 end
			end
			task.wait(pause)
		end
		board.parkFlushing = false
	end)
end
-- The director exists only with the flag on (garden.park stays nil otherwise: v568 snapshot).
ParkDirector.attach(garden, { enabled = FeatureFlags.Park == true,
	busy = function(ownerId)
		local player = Players:GetPlayerByUserId(ownerId); local board = player and boards[player]
		return board ~= nil and board.petContact ~= nil and board.petContact.lease ~= nil
	end,
	speedLevel = function(ownerId)
		-- Levels matter S1: the thrower's companion's saved Speed (never a public attribute).
		local player = Players:GetPlayerByUserId(ownerId); local board = player and boards[player]
		local state = board and not board.closing and board.nursery and board.nursery.state
		local petId = state and board.profile and board.profile.companionId
		if not petId or not NurseryCatalog.isOwned(state.inventoryMask, petId) then return nil end
		return require(ReplicatedStorage.Shared.StatCatalog).levelFor(require(script.StatState).xp(state, petId, "speed"))
	end,
	finished = function(ownerId, activityId)
		local player = Players:GetPlayerByUserId(ownerId); local board = player and boards[player]
		if not board or board.closing then return end
		board.parkPending = (board.parkPending or 0) + 1
		-- v2 S0: fetches are counted apart (stats.fetches), riding the same park write.
		if activityId == "fetch" then board.parkFetchPending = math.min(board.parkPending, (board.parkFetchPending or 0) + 1) end
		board.folder:SetAttribute("ParkGamesPending",board.parkPending)
		flushParkGames(player, board)
	end })

-- Garden Dash (FeatureFlags.GardenDash): nil and nothing made with the build ceiling off. Its own protected
-- connections; the garden carries the host so a close can reach it.
do
	local ok, problem = pcall(function()
		garden.dashHost = require(script.DashHost).mount({ remotes = remotes, shared = gardenShared, room = workspace, garden = garden,
			boards = boards, players = Players, nursery = Nursery, economy = Economy, canProgress = canProgress, gardenInput = gardenInput,
			publishNursery = publishNursery, publishState = publishState, dayOf = Daily.dayOf, den = denLive })
	end)
	if not ok then warn("[Dash] not mounted: " .. tostring(problem)) end
end
-- Garden finds (FeatureFlags.GardenFinds): nil and nothing made with the build ceiling off. Its own protected
-- connections; the garden carries the host so a close can reach it. Active play: no round, hatch, race or carry.
do
	local ok, problem = pcall(function()
		garden.findsHost = require(script.FindsHost).mount({ remotes = remotes, garden = garden, boards = boards, players = Players,
			nursery = Nursery, canProgress = canProgress, publishNursery = publishNursery, publishState = publishState, dayOf = Daily.dayOf,
			active = function(board) local state = petState(board); return state.alive and not state.conflict end,
			up = petsUp })
	end)
	if not ok then warn("[Finds] not mounted: " .. tostring(problem)) end
end
-- Garden fruit (GARDEN-PLAY-BRIEF-2 section 5, Alive `fruit`): nil and nothing made with the ceiling closed (live). Its
-- own remote (GardenFruit) and protected connections: a fruit my pet ate pays Heart XP after the server's checks.
do
	local ok, problem = pcall(function()
		garden.fruitHost = require(script.FruitHost).mount({ remotes = remotes, garden = garden, boards = boards,
			nursery = Nursery, canProgress = canProgress, publishNursery = publishNursery, publishState = publishState })
	end)
	if not ok then warn("[Fruit] not mounted: " .. tostring(problem)) end
end
-- The Sleepy Nest (Onboarding v3 slice C, Onboard.on("nest")): nil and nothing made with the v3 build ceiling off; the
-- remotes come the first time the switch is on. The first egg lands on the first garden arrival. Its own protected
-- connections; the garden carries the host so a close can reach it.
do
	local ok, problem = pcall(function()
		garden.nestHost = require(script.NestHost).mount({ remotes = remotes, boards = boards, nursery = Nursery,
			canProgress = canProgress, publishNursery = publishNursery, publishState = publishState, economy = Economy,
			notify = function(board, name) if board.firstSession then board.firstSession:hit(name) end end })
	end)
	if not ok then warn("[Nest] not mounted: " .. tostring(problem)) end
end
-- Island edges (FeatureFlags.IslandBounds, WORLD-PASS-2026-11-22 item 5): nil and nothing made with the build ceiling
-- off. Wall top-ups and the safe-spot return on its own protected connection; Lounge tells it about the server's own
-- teleports (spawn, FallCatch), which stays the last resort.
do
	local ok, problem = pcall(function()
		local host = require(script.IslandBoundsHost).mount({ boards = boards,
			spawnFrame = function(board, view)
				return Lounge.spawnFrame(board.player.UserId % 5 + 1, view.humanoid, view.root, workspace:FindFirstChild("EggDropLounge"))
			end,
			regions = function()
				-- Every open extra region together (the tier, the Play Den, the Hush); nil when none, as before.
				local out = nil
				local function add(list) if list then out = out or {}; for _, region in ipairs(list) do table.insert(out, region) end end end
				if tierHost ~= nil and tierHost.open then add(Tier.BoundsRegions) end
				local den = denLive()
				if den then add(DenLayout.boundsRegions(den)) end
				if hushHost ~= nil and hushHost.open then add(Hush.BoundsRegions) end
				return out
			end })
		garden.boundsHost = host
		if host then Lounge.moved = function(player) host:moved(player) end end
	end)
	if not ok then warn("[Bounds] not mounted: " .. tostring(problem)) end
end
-- Bumble balls (GARDEN-PLAY-BRIEF 1, Alive `balls`): nil and nothing made with the ceiling off (live). Its own remote
-- (BumbleBall), protected connections and a 1 s timer; reads the garden's pets for their nose-bunts, never writes them.
do
	local ok, problem = pcall(function()
		require(script.BumbleBallHost).mount({ remotes = remotes, players = Players, garden = garden })
	end)
	if not ok then warn("[Balls] not mounted: " .. tostring(problem)) end
end
-- The Hush (FeatureFlags.Hush, HUSH-GREYBOX-BUILD-PLAN): nil and nothing made with the build ceiling off. The greybox, the
-- open cave, the passage (the pet carried with its owner) and the evacuation, on its own protected connections.
do
	local ok, problem = pcall(function()
		hushHost = require(script.HushHost).mount({ boards = boards, remotes = remotes, garden = garden,
			room = function() return workspace:FindFirstChild("EggDropLounge") end,
			carry = function(board, spot) board.groundAnchor = spot; return garden:carry(board.player.UserId, spot) end,
			arrived = function(player, spot) if garden.boundsHost then garden.boundsHost:arrived(player, spot) end end })
		garden.hushHost = hushHost
	end)
	if not ok then warn("[Hush] not mounted: " .. tostring(problem)) end
end
-- The upper tier, greybox T0 (FeatureFlags.Tier, UPPER-TIER-BUILD-PLAN): nil and nothing made with the build ceiling
-- off. The terrace, the switchback, the ring boxes standing aside, the evacuation; players only (pets wait at the foot).
do
	local ok, problem = pcall(function()
		tierHost = require(script.TierHost).mount({ boards = boards, garden = garden,
			room = function() return workspace:FindFirstChild("EggDropLounge") end,
			arrived = function(player, spot) if garden.boundsHost then garden.boundsHost:arrived(player, spot) end end,
			-- Pets go up (TierPets): pets up there come down with the tier closing or the pets' switch turning off.
			carry = function(board, spot, leavePark)
				local carried = garden:carry(board.player.UserId, spot, leavePark)
				if carried then board.groundAnchor = spot; board.upAnchor = nil end
				return carried
			end,
			petsUp = function() return TierPets.on() and PetCatchup.on() end })
		garden.tierHost = tierHost
	end)
	if not ok then warn("[Tier] not mounted: " .. tostring(problem)) end
end
-- The Play Den, step A (FeatureFlags.PlayDen, PLAY-DEN-BUILD-PLAN): nil and nothing made with the build ceiling off. The
-- greybox, the open cave, the pets' floor; the switch off moves everyone in there (and their pets) to the doorstep first.
do
	local ok, problem = pcall(function()
		denHost = require(script.DenHost).mount({ boards = boards, garden = garden,
			room = function() return workspace:FindFirstChild("EggDropLounge") end,
			carry = function(board, spot) board.groundAnchor = spot; return garden:carry(board.player.UserId, spot) end,
			arrived = function(player, spot) if garden.boundsHost then garden.boundsHost:arrived(player, spot) end end,
			hushOpen = function() return hushHost ~= nil and hushHost.open == true end })
		garden.denHost = denHost
	end)
	if not ok then warn("[Den] not mounted: " .. tostring(problem)) end
end


-- Levels matter: when the runtime switch flips, every player gets a fresh snapshot (medal credit) and
-- board attributes (deck juice). Only this server writes the attribute; it is not read here.
require(ReplicatedStorage.Shared.Levels).changed():Connect(function()
	for _, board in pairs(table.clone(boards)) do
		if not board.closing then
			local ok, problem = pcall(publishNursery, board)
			if not ok then warn("[Levels] refresh: " .. tostring(problem)) end
		end
	end
end)

-- B2 client-run board (B2-plan.md): a lockstep round's authoritative events feed the same
-- consumers as the merge loop below. Progress (best score, trials) is written only while the save
-- is usable, and once more with the round's final values at settle (both only rise).
local lockstepHooks
lockstepHooks = {
	drop = function(player, board, drops)
		board.runDay=RunDay.onDrop(board.runDay,drops,Daily.dayOf(board.nursery.adapter.now()))
		if board.firstSession then
			board.firstSession:hit("FirstDrop")
			if drops==1 then board.firstSession:roundStarted()end
		end
	end,
	item = function(player, board, result)
		BoardItems.event(board, board.folder, { kind = "used", id = result.id, eggId = result.eggId,
			x = result.x, y = result.y, lostStar = result.lostStar ~= nil })
	end,
	merge = function(player, board, merge, score, chain, clears)
		if canProgress(board) then
			Progress.recordScore(board.profile, score)
			Progress.recordTrials(board.profile, chain, score, clears)
		end
		if board.firstSession then board.firstSession:hit("FirstMerge") end
		-- B4: on a live session the owner's mirror played this merge; the event is Studio-only there.
		if ClientSim.mergeEvents(board) then
			feedback:FireClient(player, Vector2.new(merge.x, merge.y), merge.tier, chain, Vector2.new(merge.fromX, merge.fromY),
				Vector2.new(merge.otherX, merge.otherY), merge.id, merge.cleared, board.folder:GetAttribute("ResetId"), BoardNet.tick(board), merge.firstId, merge.secondId)
		end
		for _, grant in ipairs(merge.grants or {}) do
			BoardItems.event(board, board.folder, { kind = grant.kind, id = grant.id, x = merge.x, y = merge.y })
		end
	end,
	bursts = function(player, board, bursts)
		for _, burst in ipairs(bursts) do
			BoardItems.event(board, board.folder, { kind = "burst", id = "bomb", x = burst.x, y = burst.y, count = #burst.ids })
		end
	end,
	over = function(player, board)
		local lockstep = board.lockstep
		if not canProgress(board) then
			-- Held until the save is usable (Heartbeat above); the board itself never waits.
			lockstep.rewardHeld = true
			board.payoutPending = true
			board.folder:SetAttribute("RewardStatus", "Saving")
			return
		end
		Progress.recordScore(board.profile, board.round.score)
		Progress.recordTrials(board.profile, board.peakChain, board.round.score, board.round.maxClears)
		settleReward(player, board)
	end,
}

local accumulator = 0
local merged = {}
RunService.Heartbeat:Connect(function(dt)
	garden:step(dt,gardenInputs)
	petHello.state:step()
	-- G1: the round runs Config.Pace simulation seconds per real second (same fixed
	-- step, more steps). Everything stepped below is in simulation time; the Welcome
	-- timers and the published grace are converted back to real seconds.
	accumulator = math.min(accumulator + dt * Config.Pace, Config.FixedStep * 11)
	while accumulator >= Config.FixedStep do
		accumulator -= Config.FixedStep
		for player, board in pairs(boards) do
			if board.lockstep then continue end -- B2: stepped once per Heartbeat below, to the client's tick
			if board.welcome and not hasPet(board)then
				local welcome=board.welcome
				local active=not board.closing and board.mode=="Board"and not board.round.over and not board.menuPaused and canProgress(board)and board.welcomeWindowActive==true
				welcome:step(Config.FixedStep/Config.Pace,active)
				if welcome:replayDue()then board.welcomeReplay=(board.welcomeReplay or 0)+1 end
				if active and require(script.WelcomeSeed).needsRefresh(board.sim)then
					board.sim=require(script.WelcomeSeed).refresh(Simulation,board.sim)
					-- Same run/charge/score/demo epoch. Only bounded simulation contents refresh.
					syncVisuals(board);publishState(board)
				end
				local ticket=welcome:demoTicket()
				if ticket and active and welcome:tryDemo(ticket,function()
					if board.welcome~=welcome or board.runSequence~=ticket.generation or hasPet(board)then return false end
					return acceptedDrop(board,require(script.WelcomeSeed).DemoAim,os.clock(),true)
				end)then
					if board.firstSession then board.firstSession:record("OnbIdleDemo")end
					publishWelcome(board)
				end
			end
			if board.closing or board.mode ~= "Board" or board.round.over or board.menuPaused
				or not canProgress(board) then
				continue
			end
			board.playTime += Config.FixedStep
			local wasReady = Simulation.canDrop(board.sim)
			table.clear(merged)
			Simulation.step(board.sim, Config.FixedStep, merged, board.impacts)
			BoardNet.stepped(board)
			board.round:step(board.sim.eggs, Config.FixedStep, board.sim.drops)
			for _, merge in ipairs(merged) do
				if board.welcome then require(script.WelcomeSeed).afterMerge(board.sim)end
				board.chain = if board.playTime - board.lastMerge <= 1.25 then board.chain + 1 else 1
				board.peakChain = math.max(board.peakChain, board.chain)
				board.maxTier = math.max(board.maxTier or 0, merge.tier)
				board.lastMerge = board.playTime
				board.merges += 1
				if merge.cleared then
					board.round.maxClears += 1
				end
				board.round.score += Config.mergeScore(merge.tier, board.chain, merge.cleared)
				if roundRecorder then roundRecorder.merge(board, merge, board.chain) end
				Progress.recordScore(board.profile, board.round.score)
				-- The First Hatch: the Welcome opener's chain never opens Trials (no rare hatch in the first minute).
				if not(board.welcome and board.welcome.combo)then
					Progress.recordTrials(board.profile, board.chain, board.round.score, board.round.maxClears)
				end
				if board.field then board.field:observe(merge,{sequence=board.runSequence,ordinal=board.merges,chain=board.chain,playTime=board.playTime}) end
				local welcomeCombo=board.welcome and board.welcome.combo
				if welcomeCombo and not hasPet(board)then
					local welcome=board.welcome
					-- One combo per chain (code review: counting by drop number let a quick second drop take the
					-- first drop's later merges, so two drops could hatch the Bear). A chain that a second drop
					-- extends inside the chain window still counts once.
					if board.chain==1 then
						welcome.combos=math.min(welcome.combos+1,welcomeCombo)
						board.folder:SetAttribute("WelcomeCombos",welcome.combos)
						if welcome.combos>=welcomeCombo then grantWelcome(player,board)end
					end
				elseif not hasPet(board) and board.profile.rank < 1 then
					Progress.chargeHatch(board.profile, merge.tier)
				end
				if board.firstSession then
					board.firstSession:hit("FirstMerge")
				end
				feedback:FireClient(player, merge.position, merge.tier, board.chain, merge.from, merge.other, merge.id, merge.cleared, board.folder:GetAttribute("ResetId"), BoardNet.tick(board), merge.firstId, merge.secondId)
				for _, id in ipairs(merge.powerUps or {}) do
					local granted = BoardItems.grant(board, id)
					if granted then BoardItems.event(board, board.folder, { kind = granted, id = id, x = merge.position.X, y = merge.position.Y }) end
				end
			end
			-- Bomb bursts happen inside the step, outside `merged`: nothing scores.
			if board.sim.bursts then
				if roundRecorder then roundRecorder.burst(board, #board.sim.bursts) end
				for _, burst in ipairs(board.sim.bursts) do
					BoardItems.event(board, board.folder, { kind = "burst", id = "bomb", x = burst.position.X, y = burst.position.Y, count = #burst.ids })
				end
				board.sim.bursts = nil
				publishState(board)
			end
			if not hasPet(board)and(board.profile.rank>=1 or(board.welcome and board.welcome.grantPending))then grantWelcome(player,board)end
			if board.field then
				local oldPhase, oldStage = board.field.phase, board.field.rootStage
				local expired=board.field:expireChain(board.playTime,board.lastMerge)
				local result = board.field:step(board.sim.eggs, Config.FixedStep, board.sim.drops, board.round.over)
				if result then
					board.round.over = true
					if roundRecorder then roundRecorder.finish(board) end
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
		local lockstep=board.lockstep
		if lockstep then
			if ClientSim.advance(board,now,dt,lockstepHooks)then publishState(board)end
			-- The nursery-save wait holds the reward only, never the board.
			if lockstep.rewardHeld and board.lockstep==lockstep and canProgress(board)and not board.closing then
				lockstep.rewardHeld=false;lockstepHooks.over(player,board)
			end
		end
		local pendingDrop=board.pendingDrop
		if pendingDrop then
			if acceptedDrop(board,pendingDrop.aim,now,false,pendingDrop.token) then board.pendingDrop=nil;BoardNet.ack(board,player,pendingDrop.token,true)
			elseif now>pendingDrop.expires or not dropRetryable(board,pendingDrop.aim,now) then
				board.pendingDrop=nil;BoardNet.ack(board,player,pendingDrop.token,false,"Queue"..dropRefusal(board,pendingDrop.aim,now))
			end
		end
		BoardNet.beginParts(board, now)
		syncVisuals(board)
		BoardNet.endParts(board)
		-- B3: a lockstep owner draws its own host; its snapshot stream rests while the session is live.
		if ClientSim.streaming(board) then BoardNet.publish(board, player, now) end
		if now - (board.lastPressurePublish or 0) >= .1 then
			publishWelcome(board)
			board.lastPressurePublish = now
			board.folder:SetAttribute("DangerY", board.round.overflowY or Config.OverflowY)
			board.folder:SetAttribute("OverflowPressure", if board.round.over then 0 else board.round.danger or 0)
			board.folder:SetAttribute("OverflowGraceLeft", if board.round.over then 0 else (board.round.graceLeft or 0) / Config.Pace)
		end
		local batch = {}
		for id, impact in pairs(board.impacts) do
			if board.parts[id] and now - (impact.egg.lastImpact or -math.huge) >= 0.12 then
				impact.egg.lastImpact = now
				table.insert(batch, { id, impact.normal, impact.speed })
			end
		end
		if #batch > 0 then
			impactsRemote:FireClient(player, batch, board.folder:GetAttribute("ResetId"), BoardNet.tick(board))
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
					-- Paint pots (review item 3): a settled buy replies through publishNursery (potWaiting); a refusal here.
					if boards[player]==board and pending and pending.kind=="pot"and not ok and reason~="Retrying"then sendPotResult(board,{id=pending.candidate.quote.id,action="potBuy"},"Rejected",reason)end
					if boards[player]==board and pending and(pending.kind=="toy"or pending.kind=="feature")and not ok and reason~="Retrying"then sendItemResult(board,pending.kind,pending.candidate.quote,"Rejected",reason)end
					if pending then settleSnack(player,board,pending,ok,reason)end
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
						-- First-session funnel: a join whose first read failed can still be a brand-new save.
						if candidateProfile.newSave == true then board.profile.newSave = true end
						local replacement = Nursery.load(player.UserId, candidateProfile)
						replacement.statPetOf = function() return board.profile.companionId end
						replacement.restricted = PaidRandomPolicy.cached(player)
						if boards[player] ~= board or board.closing then Nursery.release(replacement); return end
						board.nursery = replacement
						board.nurseryBusy = false
						board.profileReady = SessionProfile.hydrate(board.profile, replacement)
						if board.profileReady then
							publishPetAppearance(board)
							board.folder:SetAttribute("SaveStatus", nil)
							board.firstSession = board.firstSession or FirstSession.new(player, board.profile)
							board.selectedFamily = NurseryCatalog.family(board.profile.companionId) or "pip"
							board.mode = if hasPet(board) then "Room" else "Board"
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
							board.folder:SetAttribute("MenuColours", if board.profile.menuClassic then "classic" else "deck")
							petHello.social(board)
							Lounge.setMode(player.Character, player.UserId, board.mode, board.profile.theme)
							Lounge.setAppearance(player.Character, board.profile.theme)
							if board.firstSession then board.firstSession:hit("BoardReady") end
							-- Slice E repair-on-reload: a pet already earned but not granted yet.
							grantEarned(player, board)
						elseif replacement.status == "Ready" then
							-- Never enable play over a dirty/unhydrated provisional profile.
							Nursery.release(replacement)
							replacement.status = "Unavailable"
						end
					else
						local pending=board.nursery.pending
						Nursery.renew(board.nursery)
						if pending and board.nursery.pending~=pending then settleSnack(player,board,pending,true,"Saved")end
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
	hook.OnInvoke = function(player, action, value)
		local board = boards[player]
		if not board or board.round.over then return nil, "NoRound" end
		if board.lockstep then return nil, "ClientSim" end -- B2: the client's host must see every change
		-- itemsOn/grant also work in the Welcome round (no field) so the belt chip and
		-- carousel can be checked on a fresh Studio save; using an item still needs a
		-- field (BoardItems.request refuses NotLive), and `star` needs the field queue.
		local itemAction = action == "itemsOn" or action == "star" or action == "grant"
		if not board.field and not itemAction then return nil, "NoField" end
		if action == "plain" or action == "tidy" then
			board.field.rootStage = board.field.goalCount
			board.sim.drops = FieldRun.Budget
			if action == "plain" then board.field.bonusHeight = -1 else table.clear(board.sim.eggs) end
			publishState(board)
			return board.runHeat
		end
		-- Studio only: switch items on for this round (guided/first rounds keep them off).
		if action == "itemsOn" then
			board.itemsOn = true
			publishState(board)
			return true
		end
		-- Round items: "star" marks Next and Then as power-up balls (item `value`,
		-- default pop); "grant" puts `value` straight on the belt. Items must be on.
		if action == "star" or action == "grant" then
			local id = BoardItems.safeId(value) or "pop"
			if not board.itemsOn then return nil, "ItemsOff" end
			if action == "grant" then
				local granted = BoardItems.grant(board, id)
				if granted then BoardItems.event(board, board.folder, { kind = granted, id = id }) end
			else
				if not board.sim.queue then return nil, "NoQueue" end
				board.sim.stars = board.sim.stars or {}
				for lookahead = 0, 1 do board.sim.stars[(board.sim.drops + lookahead) % #board.sim.queue + 1] = id end
			end
			publishState(board)
			return id
		end
		return nil, "UnknownAction"
	end
	hook.Parent = game:GetService("ServerStorage")
	-- v2 pet names: stat XP through a real save transaction (level-ups grant name pieces there).
	local statHook = Instance.new("BindableFunction")
	statHook.Name = "EggDropStatTestGrant"
	statHook.OnInvoke = function(player, petId, statId, xp)
		local board = boards[player]
		if not board then return false, "NoBoard" end
		local ok, why = Nursery.studioGrantStat(board.nursery, petId, statId, xp)
		publishNursery(board); publishState(board)
		return ok, why
	end
	statHook.Parent = game:GetService("ServerStorage")
end

game:BindToClose(function()
	for _, board in pairs(boards) do closeBoard(board) end
	local deadline = os.clock() + 25
	while next(closing) and os.clock() < deadline do task.wait(.1) end
end)
