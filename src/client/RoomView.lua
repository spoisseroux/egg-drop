local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PetFocusUI = require(script.Parent.PetFocusUI)
local PetAffection=require(script.Parent.PetAffection)
local HollowAmbience=require(script.Parent.HollowAmbience)

local PetFactory=require(script.Parent.PetFactory)
local GardenClient=require(script.Parent.GardenClient)
local GardenActivity=require(ReplicatedStorage.Shared.GardenActivity)
local GardenLayout=require(ReplicatedStorage.Shared.GardenLayout)
local GardenToyVisual=require(script.Parent.GardenToyVisual)
local RoomCompanions = require(script.Parent.RoomCompanions)
local PetFollow = require(script.Parent.PetFollow)
local PetGreetingShot = require(script.Parent.PetGreetingShot)
local PetPrestige = require(script.Parent.PetPrestige)
local PetRigBounds=require(script.Parent.PetRigBounds)
local Art = require(script.Parent.DeckArt)
local DeckTransition = require(script.Parent.DeckTransition)
local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)

local Room = {}
Room.__index = Room

local function createPet(parent,origin,pet,masteryMask,rank,legacy,appearance)
	return PetFactory.create(parent,origin,pet,masteryMask,rank,legacy,appearance)
end

local function frame(parent, name, size, position, color, z)
	local node = Instance.new("Frame")
	node.Name = name
	node.Size = size
	node.Position = position
	node.BackgroundColor3 = color
	node.BorderSizePixel = 0
	node.ZIndex = z
	node.Parent = parent
	return node
end

local function button(parent, name, title, position, tint)
	local node = Instance.new("TextButton")
	node.Name = name
	node.Size = UDim2.new(0.5, -4, 0, 44)
	node.Position = position
	node.BackgroundColor3 = tint
	node.BorderSizePixel = 0
	node.Text = title
	node.TextColor3 = if tint == Art.Cyan then Art.Ink else Art.Silver
	node.Font = Enum.Font.GothamMedium
	node.TextSize = 14
	node.ZIndex = 9
	node.Parent = parent
	Art.button(node, 6)
	Art.fitText(node, 14, 10, 5)
	return node
end

local function tween(object, seconds, properties)
	local motion = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), properties)
	motion:Play()
	return motion
end

function Room.new(gui, board, progress, audio, onReturn, onCustomize, onCollection, overlayOpen, reduceEffects, onEggs)
	-- Two separate passive-backed circles keep the same named action targets.
	local controls = frame(gui, "LoungeControls", UDim2.fromOffset(104, 48), UDim2.new(1, -12, 0, 12), Art.Surface, 8)
	controls.AnchorPoint = Vector2.new(1, 0)
	controls.Visible = false
	controls.BackgroundTransparency=1
	local menu = button(controls, "Menu", "Menu", UDim2.fromOffset(0, 0), Art.Raised)
	local leave = button(controls, "OpenHandheld", "Deck", UDim2.fromOffset(56, 0), Art.Cyan)
	menu.Size, leave.Size = UDim2.fromOffset(48,48),UDim2.fromOffset(48,48)
	Art.dockCircle(menu,"menu");Art.dockCircle(leave,"deck")
	menu.BackgroundTransparency,leave.BackgroundTransparency=Art.dockTransparency(GuiService.PreferredTransparency),Art.dockTransparency(GuiService.PreferredTransparency)
	-- Retain these handles for the welcome guide and old controller restoration.
	local heading = Art.text(controls, "Heading", "Sprout Hollow", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), Art.Silver, 12)
	local welcome = Art.text(controls, "FirstVisit", "", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), Art.Muted, 11)
	local greet = button(controls, "GreetPet", "Say hi", UDim2.fromOffset(0, 0), Art.Raised)
	heading.Visible, welcome.Visible, greet.Visible = false, false, false
	local self = setmetatable({
		board = board, progress = progress, controls = controls, heading = heading,
		welcome = welcome, greetButton = greet, menuButton = menu,
		transition = DeckTransition.new(gui, board.Tray, audio, reduceEffects), audio = audio,
		mode = "Board", target = "Board", lastSwitchAt = -math.huge,
		shownPet = Pets[1], menuOpen = false, overlayOpen = overlayOpen,
		companions = RoomCompanions.new(progress.Parent, createPet, reduceEffects),
		reduceEffects = reduceEffects, connections = {},
	}, Room)
	self.garden=GardenClient.new(progress.Parent)
	self.gardenToy=GardenToyVisual.new(workspace,GardenLayout.Toy)
	self.companions.garden=self.garden
	self.ambience=HollowAmbience.new()
 self.affection=PetAffection.new(workspace,function(index)
  if self.petContactActive and self:contactEligible(self.contactContext)then self.audio:play(self.shownPet.cue,if index%2==0 then .96 else 1.06,.26)end
 end)
	self.focusUI = PetFocusUI.new(gui, {
		back = function() if self.focusing then self:useRoomCamera(false) end end,
		greet = function()return self:reactPet(false)end,
		pet = function()return self:reactPet(true)end,
		petContact=function(active)return self:setPetContact(active)end,
		charmToggle=function(visible)return self:setCharmVisible(visible)end,
		canOwnInput = function() return not self.busy and not self.overlayOpen() end,
		canReact = function()
			return self.focusing and self.mode == "Room" and not self.busy and not self.overlayOpen()
				and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
		end,
	})
	local function watch(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(self.connections, connection)
		return connection
	end
	watch(progress:GetAttributeChangedSignal("PetAppearance"),function()self:refreshPetAppearance()end)
	local appearanceRemote=ReplicatedStorage.Remotes:FindFirstChild("PetAppearanceResult")
	if appearanceRemote then watch(appearanceRemote.OnClientEvent,function(packet)
		local pending=self.charmPending
		if type(packet)=="table"and type(packet.lastSeq)=="number"then self.charmSeq=math.max(self.charmSeq or 0,packet.lastSeq)end
		if pending and type(packet)=="table"and packet.petId==pending.petId and packet.seq==pending.seq and packet.status~="Applied"then
			self.charmPending=nil;self:refreshPetAppearance()
		end
	end)end
	watch(GuiService:GetPropertyChangedSignal("PreferredTransparency"),function()
		menu.BackgroundTransparency,leave.BackgroundTransparency=Art.dockTransparency(GuiService.PreferredTransparency),Art.dockTransparency(GuiService.PreferredTransparency)
	end)
	menu.Activated:Connect(function()
		if self.mode == "Room" and not self.busy and not self.focusing and not overlayOpen() then
			if self.onOpenMenu then self.onOpenMenu() else onCollection() end
		end
	end)
	greet.Activated:Connect(function() self:interactPet() end)
	leave.Activated:Connect(function()
		if not self.busy and not overlayOpen() then self:requestSwitch(onReturn) end
	end)
	watch(Players.LocalPlayer.CharacterRemoving,function(character)self.removingCharacter=character;self.returnRoamShot=nil;if self.focusUI then self.focusUI:cancelPointer()end;self:setPetContact(false);if self.stations then self.stations:refresh()end end)
	watch(Players.LocalPlayer.CharacterAdded, function(character)
		-- Cancel against the old character immediately; waiting for Humanoid must not retain a lock.
		self.removingCharacter=nil
		self.returnRoamShot=nil
		self.transition:hide()
		self:releaseFocusMovement()
		if self.focusing then self:useRoomCamera(false) end
		local humanoid = character:WaitForChild("Humanoid", 5)
		if self.mode == "Room" and humanoid and Players.LocalPlayer.Character == character then
			self.followState = nil
			task.defer(function()
				if self.mode == "Room" and Players.LocalPlayer.Character == character then self:useRoomCamera(false) end
			end)
		end
	end)
	watch(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		self.returnRoamShot=nil
		if self.mode == "Room" then self:useRoomCamera(false) end
	end)
	watch(RunService.RenderStepped, function(dt)
  if self.ambience then
   self.ambience:step(dt,workspace.CurrentCamera,self.mode=="Room"and self.target=="Room"and not self.busy and not self.menuOpen and not self.overlayOpen()and not self.arrivalPlacementPending and not self.removingCharacter and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox(),self.reduceEffects())
  end
		self:retryArrivalPlacement()
		self:updateControls()
		local gardenFocus=self.focusing and self.mode=="Room"and not self.busy and not self.overlayOpen()and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()and self.focusUI.windowActive~=false
		if self.pet and gardenFocus then self.garden:focus(true,self.shownPet.id,self.pet.origin,self.pet.yaw)else self.garden:focus(false)end
		self.garden:step(dt)
		if self.gardenToy then
			local visible=self.mode=="Room"and self.target=="Room"and not self.busy and not self.overlayOpen()and self.focusUI.windowActive~=false
			self.gardenToy:setVisible(visible)
			if visible then self.gardenToy:update(GardenActivity.sampleToy(self.garden.snapshot and self.garden.snapshot.toy,workspace:GetServerTimeNow()),dt,self.reduceEffects())end
		end
		if self.pet then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if self.focusing then
				local shot = self.greetingCamera
				if not root or not humanoid or humanoid.Health <= 0 or not shot or shot.root ~= root
					or shot.camera ~= workspace.CurrentCamera then self:useRoomCamera(false)
				else self:reframeFocus()end
			end
			local reduced=self.reduceEffects()
			self.pet.reducedEffects=reduced
			if root and character~=self.removingCharacter and humanoid and humanoid.Health>0 and not self.focusing and not self.busy and not self.arrivalPlacementPending then
				local actor=self.garden:get(Players.LocalPlayer.UserId,self.shownPet.id,character)
				if actor then self.followState=PetFollow.activity(self.pet,actor,workspace:GetServerTimeNow(),dt,self.followState,reduced)
				else self.followState = PetFollow.step(self.pet, root, dt, self.followState,reduced)end
			else self.followState=nil;PetFollow.rest(self.pet)end
			if self.focusing and self.reduceEffects() and self.cameraTween then
				self:cancelCameraTween()
				if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = PetGreetingShot.Fov end
			end
			self.pet:update(dt)
			self.pet.focused=self.focusing==true
			PetPrestige.update(self.pet, dt, self.reduceEffects())
		end
		if self.mode=="Room"then self.companions:update(dt)end
		if self.focusUI then self.focusUI:update(workspace.CurrentCamera, self.pet, self.petPrompt and self.petPrompt.Enabled) end
  self:updatePetContact(dt)
	end)
	for _, attribute in ipairs({ "MasteryRanks", "MasteryMask" }) do
		watch(progress:GetAttributeChangedSignal(attribute), function()
			if self.mode == "Room" and self.pet then self:showPet(self.shownPet) end
		end)
	end
	watch(gui.Destroying, function() self:destroy() end)
	return self
end

function Room:stationInReach()
	return self.stations~=nil and self.stations:inReach()
end

function Room:updateControls()
	if self.stations then self.stations:refresh() end
	local unobscured = self.mode == "Room" and not self.focusing and not self.busy
		and not self.menuOpen and not self.overlayOpen() and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
	if self.canRoam then unobscured=self.canRoam() end
	self.controls.Visible = unobscured
	if self.focusUI then self.focusUI:setActive(self.focusing and self.mode == "Room") end
	if self.petPrompt then self.petPrompt.Enabled = unobscured and not self:stationInReach() end
	if self.petClick then self.petClick.MaxActivationDistance = if unobscured then 9 else 0 end
end

function Room:setMenuOpen(open)
	self.menuOpen = open == true
	self:updateControls()
end

function Room:collapseControls()
	self:setMenuOpen(false)
end

function Room:interactPet()
 if self.focusUI and self.focusUI.windowActive==false then return false end
	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return false end
	if not self.focusing and self.canRoam and not self.canRoam() then return false end
	if self.mode ~= "Room" or self.busy or self.overlayOpen() or self.menuOpen or not self.pet then return false end
	if self.focusing then return self:reactPet(false) end
	local now = os.clock()
	if now - (self.lastPetAt or -math.huge) < 0.45 then return false end
	if not self:focusPet() then return false end
	self.lastPetAt = now
	return true
end

function Room:requestSwitch(callback)
	if self.busy or self.switchQueued then
		return
	end
	local remaining = Config.ModeSwitchInterval - (os.clock() - self.lastSwitchAt)
	if remaining <= 0 then
		callback()
		return
	end
	local origin = self.mode
	self.switchQueued = true
	task.delay(remaining, function()
		self.switchQueued = false
		if not self.busy and self.mode == origin and self.target == origin then
			callback()
		end
	end)
end

function Room:choosePet(pet)
	self.requestedPet = pet
end

function Room:showPet(pet)
	if self.focusUI then self.focusUI:cancelPointer()end
	self:setPetContact(false)
	local owned = self.progress:GetAttribute("OwnedPets") or 0
	local trials = self.progress:GetAttribute("TrialMask") or 0
	if not pet or not Pets.isUnlocked(pet, owned, trials, self.progress:GetAttribute("InventoryMask")) then pet = Pets[1] end
	self.shownPet = pet
	local oldOrigin = self.pet and self.pet.origin
	local oldYaw = self.pet and self.pet.yaw
	if self.pet then self.pet.focusPose=false;self.pet:destroy() end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = oldOrigin or (if root then root.Position - root.CFrame.LookVector * 3 + root.CFrame.RightVector * 2.6 else Vector3.new(0, 4.025, -5))
	local rank, legacy = PetPrestige.read(self.progress, pet)
	self.pet = createPet(workspace, position, pet, self.progress:GetAttribute("MasteryMask"), rank, legacy,self.garden:appearance(self.progress,pet.id))
	self.pet.focusPose=self.focusing==true;self.focusGeometry=nil
	self.pet.origin = Vector3.new(position.X, PetFollow.ground(position, self.pet, oldOrigin and oldOrigin.Y), position.Z)
	self.pet.model:SetAttribute("CompanionOwnerId", Players.LocalPlayer.UserId)
	self.pet.model:SetAttribute("LocalCompanion", true)
 if self.affection then self.affection:setPet(self.pet)end
	self.pet.yaw = if self.focusing and oldYaw then oldYaw elseif root then math.atan2(root.CFrame.LookVector.X, root.CFrame.LookVector.Z) else 0
	self.followState = nil
	self:refreshPetAppearance()
	local body = self.pet.model.PrimaryPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "PetInteraction", "Say hi", pet.name
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.ClickablePrompt, prompt.RequiresLineOfSight, prompt.HoldDuration = true, false, 0
	prompt.MaxActivationDistance, prompt.UIOffset = 9, Vector2.new(0, 22)
	prompt.Enabled, prompt.Parent = false, body
	prompt.Triggered:Connect(function(who)
		if (who==nil or who==Players.LocalPlayer) and self.petPrompt==prompt and prompt.Enabled and not self:stationInReach() then self:interactPet() end
	end)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance, click.Parent = 9, body
	click.MouseClick:Connect(function(who) if who == Players.LocalPlayer then self:interactPet() end end)
	self.petPrompt, self.petClick = prompt, click
	if not self.reduceEffects() then self.pet:greet() end
	self.heading.Text = string.format("Sprout Hollow · %s · %d/%d", pet.name,
		Pets.ownedCount(owned, trials, self.progress:GetAttribute("InventoryMask")), #Pets.collection)
	self:updateControls()
end

function Room:refreshPetAppearance()
	if not self.garden or not self.shownPet then return end
	local appearance=self.garden:appearance(self.progress,self.shownPet.id)
	if self.appearancePet~=self.shownPet.id or self.appearanceCharm~=appearance.charmVisible then
		self.appearancePet,self.appearanceCharm=self.shownPet.id,appearance.charmVisible
		self.focusGeometry=nil
	end
	if self.pet and self.pet.applyAppearance then self.pet:applyAppearance(appearance)end
	if self.focusUI and self.focusUI.setCharmVisible then
		local supported=self.shownPet.id=="pip"or self.shownPet.id=="puddle"
		self.focusUI:setCharmVisible(if supported then appearance.charmVisible else nil,self.charmPending~=nil,self.pet and self.pet.secondaryColor)
	end
end
function Room:setCharmVisible(visible)
	if type(visible)~="boolean"or self.charmPending or not self.focusing or self.mode~="Room"or self.busy or self.overlayOpen()then return false end
	if self.shownPet.id~="pip"and self.shownPet.id~="puddle"then return false end
	self:setPetContact(false)
	self.charmSeq=(self.charmSeq or 0)+1
	self.charmPending={petId=self.shownPet.id,seq=self.charmSeq}
	self:refreshPetAppearance()
	ReplicatedStorage.Remotes.BoardRequest:FireServer("petAppearance",{petId=self.shownPet.id,visible=visible,seq=self.charmSeq})
	return true
end

function Room:cancelCameraTween()
	if self.cameraTween then
		self.cameraTween:Cancel()
		self.cameraTween = nil
	end
end

function Room:cameraIdentity()
	local character=Players.LocalPlayer.Character
	return workspace.CurrentCamera,character and character:FindFirstChild("HumanoidRootPart"),
		character and character:FindFirstChildOfClass("Humanoid")
end

-- Capture only the outgoing free-roam view, before savedCamera restores its separate
-- pre-Room owner. Greeting Back must finish first so Scriptable framing never leaks.
function Room:captureReturnRoam()
	self.returnRoamShot=nil
	if self.arrivalPlacementPending or self.arrivalUnplaced then self.arrivalPlacementPending=nil;return false end
	if self.destroyed or self.mode~="Room" then return false end
	if self.focusing or self.greetingCamera then self:useRoomCamera(false) end
	local camera,root,humanoid=self:cameraIdentity()
	if not camera or not camera.Parent or camera.CameraType~=Enum.CameraType.Custom
		or not root or not root.Parent or not humanoid or humanoid.Health<=0 then return false end
	self.returnRoamShot=PetGreetingShot.capture(camera,root)
	return true
end

function Room:restoreCamera()
	if self.pet then self.pet.focusPose=false;self.pet.focused=false end
	if self.focusUI then self.focusUI:cancelPointer()end
	self:setPetContact(false)
	self:releaseFocusMovement()
	self:cancelCameraTween()
	self.greetingCamera = nil
	self.focusAspect = nil
	self.focusing = false
	self.focusMotion, self.followState = nil, nil
	self.focusEpoch = (self.focusEpoch or 0) + 1
	self.greetButton.Text = "Say hi"
	self:updateControls()
	if self.viewportChanged then
		self.viewportChanged:Disconnect()
		self.viewportChanged = nil
	end
	local saved = self.savedCamera
	self.savedCamera = nil
	local camera=self:cameraIdentity()
	if saved and saved.camera == camera and saved.camera.Parent then
		saved.camera.CFrame = saved.transform
		saved.camera.Focus = saved.focus
		saved.camera.FieldOfView = saved.fov
		saved.camera.CameraType = saved.type
	end
end

function Room:retryArrivalPlacement()
	if self.arrivalPlacementPending and not self.destroyed and self.mode=="Room" and self.target=="Room" then
		self:useRoomCamera(false)
	end
end

function Room:useRoomCamera(animate, arriving)
	self.focusStageOrigin,self.focusStageBearing=nil,nil
	if self.garden then self.garden:focus(false)end
	if self.focusUI then self.focusUI:cancelPointer()end
	self:setPetContact(false)
	self:releaseFocusMovement()
	if arriving then self.arrivalPlacementPending=true;self.arrivalUnplaced=true end
	local placing=self.arrivalPlacementPending==true
	local camera,root,humanoid=self:cameraIdentity()
	-- Arrival owns a one-shot placement until every live camera subject exists.
	-- A streamed/respawning root must not turn this into an ordinary roam callback.
	if placing and (not camera or not camera.Parent or not root or not root.Parent
		or not humanoid or humanoid.Health<=0) then return false end
	local returning=if placing then self.returnRoamShot else nil
	if placing then self.arrivalPlacementPending=nil;self.arrivalUnplaced=false;self.returnRoamShot=nil end
	if not camera then
		self:restoreCamera()
		return
	end
	local greeting = self.greetingCamera
	if self.viewportChanged then self.viewportChanged:Disconnect(); self.viewportChanged = nil end
	self.focusAspect = nil
	if not self.savedCamera or self.savedCamera.camera ~= camera then
		self:restoreCamera()
		self.savedCamera = {
			camera = camera, type = camera.CameraType, transform = camera.CFrame,
			focus = camera.Focus, fov = camera.FieldOfView,
		}
	else
		self:cancelCameraTween()
	end
	self.greetingCamera = nil
	self.focusing = false
	if self.pet then self.pet.focusPose=false;self.pet.focused=false end
	self.focusMotion, self.followState = nil, nil
	self.focusEpoch = (self.focusEpoch or 0) + 1
	self.greetButton.Text = "Say hi"
	self:updateControls()
	if humanoid then
		camera.CameraSubject = humanoid
	end
	local restored = PetGreetingShot.restore(greeting, camera, root)
	if not restored and placing then restored=PetGreetingShot.restore(returning,camera,root) end
	if greeting and self.pet and root then
		local origin
		if restored and greeting.pet == self.pet then
			origin = greeting.petOrigin + root.Position - greeting.position
			self.pet.yaw = greeting.petYaw
		else
			origin = root.Position - root.CFrame.LookVector * 3 + root.CFrame.RightVector * 2.6
			self.pet.yaw = math.atan2(root.CFrame.LookVector.X, root.CFrame.LookVector.Z)
		end
		self.pet.origin = Vector3.new(origin.X, PetFollow.ground(origin, self.pet, origin.Y), origin.Z)
		self.pet.lastFrame = -1
		self.pet:update(0)
	end
	if not restored then camera.FieldOfView = 65 end
	if root and (placing or not self.roamed) and not restored then
		local target = root.Position + Vector3.new(0, 1, 0)
		camera.CFrame = CFrame.lookAt(target + Vector3.new(5, 6, 12), target)
		camera.Focus = CFrame.new(target)
	end
	self.roamed = true
	camera.CameraType = Enum.CameraType.Custom
end

function Room.captureFocusSubject(pet,family)
	local rig=pet.model:GetAttribute("RigId")
	if rig=="zivvi"or rig=="ovelle"then return PetGreetingShot.captureFocusedSubject(pet)end
	local fields={"greeting","focusPose","gaitWeight","movementBob","affectionTilt","lastFrame"}
	local saved={};for i,key in ipairs(fields)do saved[i]=pet[key]end
	pet.greeting=if family=="pip"or family=="puddle"then 2 else 0
	pet.focusPose,pet.gaitWeight,pet.movementBob,pet.affectionTilt=true,0,0,0
	pet:update(0)
	local bounds,size=PetRigBounds.get(pet)
	local silhouette=PetGreetingShot.captureSilhouette(pet,bounds)
	for i,key in ipairs(fields)do pet[key]=saved[i]end
	pet:update(0)
	return bounds,size,silhouette
end

function Room:planGreeting(camera, root, floor)
	local started=os.clock()
	local lounge = floor.Parent
	local bounds,size,silhouette,focusEnvelope,sweepCached=Room.captureFocusSubject(self.pet,self.shownPet.family or self.shownPet.id)
	local exclude = {self.pet.model}
	for _, player in ipairs(Players:GetPlayers()) do if player.Character then table.insert(exclude,player.Character) end end
	local params=RaycastParams.new()
	params.FilterDescendantsInstances,params.RespectCanCollide=exclude,true
	local aspect=camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y)
	local crestReserve=PetPrestige.crestReserve(self.pet)
	local topInset,bottomInset=GuiService:GetGuiInset()
	local safeTop=topInset.Y
	local animationRise=.55*(self.pet.worldScale or 1)
	local reach=PetGreetingShot.maximumReach(size,aspect,crestReserve,camera.ViewportSize.Y,safeTop,animationRise)
	local visualBlocks={}
	local ownerParts={}
	local owner=root.Parent
	if owner then for _,part in ipairs(owner:GetDescendants())do
		if part:IsA("BasePart")and part.Transparency<.99 then table.insert(ownerParts,part)end
	end end
	for _, part in ipairs(lounge:GetChildren()) do
		if part:IsA("BasePart") and part~=floor and part.Transparency<.9
			and (part.Size.Magnitude>=2 or part.Name:find("Sign") or part.Name:find("FieldGuide"))
			and (part.Position-root.Position).Magnitude<=reach+part.Size.Magnitude*.5 then table.insert(visualBlocks,part) end
	end
	local groundQueries,candidates=0,0
	local plan=PetGreetingShot.plan({
		rootPosition=root.Position,forward=root.CFrame.LookVector,size=size,silhouette=silhouette,focusEnvelope=focusEnvelope,crestPixelReserve=crestReserve,viewportHeight=camera.ViewportSize.Y,safeTopInset=safeTop,safeBottomInset=bottomInset.Y,safeLeftInset=topInset.X,safeRightInset=bottomInset.X,animationTopReserve=animationRise,
		centerOffset=CFrame.Angles(0,self.pet.yaw or 0,0):VectorToObjectSpace(bounds.Position-self.pet.origin),
		aspect=aspect,floor={cf=floor.CFrame,size=floor.Size},preferredBearing=self.focusStageBearing,preferredOrigin=self.focusStageOrigin,
		ground=function(position)
			groundQueries += 1
			local hit=workspace:Raycast(position+Vector3.new(0,8,0),Vector3.new(0,-80,0),params)
			return hit and hit.Position.Y+.025 or nil
		end,
		clear=function(position,target,origin)
			candidates += 1
			if workspace:Raycast(position,target-position,params)
				or workspace:Raycast(root.Position,origin+Vector3.new(0,1,0)-root.Position,params) then return false end
			local right=CFrame.lookAt(position,target).RightVector*math.max(size.X,size.Z)*.5
			for _,point in ipairs({target,origin+Vector3.new(0,.25,0),target+Vector3.new(0,size.Y*.5,0),target-right,target+right,origin+Vector3.new(0,.12,0)-right,origin+Vector3.new(0,.12,0)+right})do
				if workspace:Raycast(position,point-position,params)
					or PetGreetingShot.segmentBlocked(position,point,visualBlocks)
					or PetGreetingShot.segmentBlocked(position,point,ownerParts)then return false end
			end
			return true
		end,
	})
	-- Local visual diagnostics are read-only presentation evidence, never rewards.
	self.pet.model:SetAttribute("GreetingPlanMs", (os.clock() - started) * 1000)
	self.pet.model:SetAttribute("GreetingCandidates", candidates)
	self.pet.model:SetAttribute("GreetingGroundQueries", groundQueries)
	self.pet.model:SetAttribute("GreetingVisualBlockers", #visualBlocks)
	self.pet.model:SetAttribute("GreetingAccepted", plan ~= nil)
	self.pet.model:SetAttribute("GreetingSweepPoints",if focusEnvelope then #focusEnvelope.points else 0)
	self.pet.model:SetAttribute("GreetingSweepSamples",if focusEnvelope then focusEnvelope.sweepSamples else 0)
	self.pet.model:SetAttribute("GreetingSweepCached",sweepCached==true)
	self.pet.model:SetAttribute("GreetingOwnerDistance",if plan then(plan.origin-root.Position).Magnitude else nil)
	self.pet.model:SetAttribute("GreetingStageBearing",if plan then plan.bearing else nil)
	self.pet.model:SetAttribute("GreetingBodyFraction",if plan then plan.bodyFraction else nil)
	self.pet.model:SetAttribute("GreetingFitLimited",if plan then plan.fitLimited else nil)
	self.pet.model:SetAttribute("GreetingLimitingPart",if plan then plan.limitingPart else nil)
	self.pet.model:SetAttribute("GreetingLimitingEdge",if plan then plan.limitingEdge else nil)
	-- Missing/blocked/streamed scenery leaves roaming and interaction usable.
	return plan
end

function Room:applyFocusPlan(plan, camera)
	self:cancelCameraTween()
	self.pet.origin, self.pet.yaw = plan.origin, plan.yaw
	self.focusStageOrigin,self.focusStageBearing=plan.origin,plan.bearing
	if self.garden and self.focusing and self.focusUI.windowActive~=false and not self.overlayOpen()and not GuiService.MenuIsOpen then
		self.garden:focus(true,self.shownPet.id,plan.origin,plan.yaw)
	end
	self.pet.focusPose=true
	self.pet.lastFrame = -1
	self.pet:update(0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame, camera.Focus, camera.FieldOfView = plan.camera, CFrame.new(plan.target), plan.fov
	self.focusAspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	self.focusGeometry=Room.focusGeometryKey(camera)
	if self.focusUI then self.focusUI:cancelPointer() end
end

function Room.focusGeometryKey(camera)
	local top,bottom=GuiService:GetGuiInset()
	return tostring(camera.ViewportSize)..":"..tostring(top)..":"..tostring(bottom)
end

function Room:reframeFocus()
	local shot, camera = self.greetingCamera, workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not self.focusing or not shot or not self.pet or not camera or shot.camera ~= camera
		or shot.root ~= root or not root or self.mode ~= "Room" then return false end
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then return false end
	local geometry=Room.focusGeometryKey(camera)
	if self.focusGeometry==geometry then return true end
	local lounge = workspace:FindFirstChild("EggDropLounge")
	local floor = lounge and lounge:FindFirstChild("Floor")
	if not floor then self:useRoomCamera(false);return false end
	local plan = self:planGreeting(camera, root, floor)
	if not plan then self:useRoomCamera(false);return false end
	-- Resize changes only the geometry. The original pre-focus restore snapshot,
	-- pet origin, root and generation remain untouched for Back/respawn handling.
	self:applyFocusPlan(plan, camera)
	return true
end

function Room:focusPet()
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local lounge = workspace:FindFirstChild("EggDropLounge")
	local floor = lounge and lounge:FindFirstChild("Floor")
	if self.focusing then return self:reactPet(false) end
	if not camera or not self.pet or self.mode ~= "Room" or not root or not floor then return false end
	local plan = self:planGreeting(camera, root, floor)
	if not plan then return false end
	self:cancelCameraTween()
	self.greetingCamera=PetGreetingShot.capture(camera,root)
	self.greetingCamera.pet,self.greetingCamera.petOrigin,self.greetingCamera.petYaw=self.pet,self.pet.origin,self.pet.yaw
	self.focusing,self.menuOpen=true,false
	self.focusMotion,self.followState=nil,nil
	self.greetButton.Text="Roam"
	self.focusEpoch=(self.focusEpoch or 0)+1
	self:lockFocusMovement(character)
	if self.mode ~= "Room" or not self.focusing or workspace.CurrentCamera ~= camera
		or Players.LocalPlayer.Character ~= character or root.Parent ~= character then
		self:useRoomCamera(false)
		return false
	end
	-- Stage both in one callback. Only FOV settles; no lens path crosses the pet.
	self.pet.origin,self.pet.yaw=plan.origin,plan.yaw
	self.focusStageOrigin,self.focusStageBearing=plan.origin,plan.bearing
	if self.garden then self.garden:focus(true,self.shownPet.id,plan.origin,plan.yaw)end
	self.pet.focusPose=true
	if self.pet.applyGardenPose then self.pet:applyGardenPose({action="focus",actionPhase=0,expression="curious",actionId="focus-"..self.focusEpoch,generation=self.focusEpoch})end
	if not self.reduceEffects() then self.pet:greet() end
	self.pet.lastFrame = -1
	self.pet:update(0)
	camera.CameraType=Enum.CameraType.Scriptable
	camera.CFrame,camera.Focus=plan.camera,CFrame.new(plan.target)
	camera.FieldOfView=if self.reduceEffects() then plan.fov else 48
	self:updateControls()
	self.audio:play(self.shownPet.cue)
	if not self.reduceEffects() then self.cameraTween=tween(camera,.20,{FieldOfView=plan.fov}) end
	if self.focusUI then self.focusUI:retireRoamHint()end
	self.focusAspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	self.focusGeometry=Room.focusGeometryKey(camera)
	if self.viewportChanged then self.viewportChanged:Disconnect() end
	local epoch = self.focusEpoch
	self.viewportChanged = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if not self.destroyed and self.focusing and self.focusEpoch == epoch and workspace.CurrentCamera == camera then
			self:reframeFocus()
		end
	end)

	return true
end

function Room:lockFocusMovement(character)
	if self.focusLock then return end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local lock = { character = character, release = PetFocusUI.lockHumanoid(humanoid) }
	self.focusLock = lock
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0) end
	local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if playerModule then
		local ok, controls = pcall(function() return require(playerModule):GetControls() end)
		if self.focusLock ~= lock then return end
		if ok and controls then
			local enabled = if type(controls.controlsEnabled) == "boolean" then controls.controlsEnabled
				elseif type(controls.enabled) == "boolean" then controls.enabled else true
			lock.controls, lock.restoreControls = controls, enabled
			if enabled then pcall(function() controls:Disable() end) end
		end
	end
end

function Room:releaseFocusMovement()
	local lock = self.focusLock
	if not lock then return end
	self.focusLock = nil
	lock.release()
	if lock.controls and lock.restoreControls then pcall(function() lock.controls:Enable() end) end
end

function Room:setPetContact(active)
 if active and self.focusUI and self.focusUI.windowActive==false then return false end
	if not active then
		if not self.petContactActive then return false end
		self.petContactActive=false
		if self.contactPet then
			self.contactPet.petting=false
			if self.contactPet.applyGardenPose then self.contactPet.affection=0 end
		end
		self.contactPet=nil;self.contactContext=nil
  if self.petContactIntent then self.petContactIntent:cancel()end
  if self.affection then self.affection:clear()end
		if self.audio and self.audio.setPurr then self.audio:setPurr(false)end
		return true
	end
	if self.petContactActive then return true end
	local root=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if self.removingCharacter==Players.LocalPlayer.Character or not self.focusing or self.mode~="Room"or self.busy or self.menuOpen or self.overlayOpen()or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()
		or not self.pet or not self.greetingCamera or self.greetingCamera.root~=root or self.greetingCamera.camera~=workspace.CurrentCamera then return false end
 self.petContactActive,self.contactPet=true,self.pet;self.pet.petting=true
 if self.affection then self.affection:begin(self.reduceEffects())end
 local now=os.clock()
 if not self.reduceEffects()and now-(self.lastContactChirpAt or -math.huge)>=1.5 and now-(self.lastReactionAudioAt or -math.huge)>=.7 then
  self.lastContactChirpAt=now;self.lastReactionAudioAt=now;self.audio:play(self.shownPet.cue,1.04,.26)
 end
 self.contactContext={pet=self.pet,root=root,camera=workspace.CurrentCamera,shot=self.greetingCamera}
 if self.petContactIntent then self.petContactIntent:begin(self.shownPet.id,self.contactContext)end
 if self.audio and self.audio.setPurr then self.audio:setPurr(true)end
 return true
end

function Room:contactEligible(context)
 if not context or self.destroyed or not self.petContactActive or not self.focusing or self.mode~="Room"or self.busy or self.menuOpen or self.overlayOpen()or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()then return false end
 local root,humanoid
 local character=Players.LocalPlayer.Character
 if character then root=character:FindFirstChild("HumanoidRootPart");humanoid=character:FindFirstChildOfClass("Humanoid")end
 return character~=self.removingCharacter and self.pet==context.pet and self.greetingCamera==context.shot and root==context.root and root~=nil and humanoid and humanoid.Health>0 and workspace.CurrentCamera==context.camera
  and self.focusUI and self.focusUI.windowActive~=false and self.focusUI:contactValid()
end
function Room:updatePetContact(dt)
 local active=self.petContactActive and self:contactEligible(self.contactContext)
 if self.petContactActive and not active then self:setPetContact(false)end
 if self.petContactIntent then self.petContactIntent:step()end
 if self.affection then self.affection:step(dt,active==true,self.reduceEffects())end
end
function Room:reactPet(petting)
 if self.focusUI and self.focusUI.windowActive==false then return false end
	if not self.focusing or self.mode ~= "Room" or self.busy or self.overlayOpen() or GuiService.MenuIsOpen
		or self.menuOpen or UserInputService:GetFocusedTextBox()or not self.pet or not self.greetingCamera then return false end
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if self.greetingCamera.root ~= root or self.greetingCamera.camera ~= workspace.CurrentCamera then
		self:useRoomCamera(false)
		return false
	end
	local now = os.clock()
	if now - (self.lastReactionAt or -math.huge) < (if petting then 0.45 else 0.6) then return false end
	self.lastReactionAt = now
	-- Reactions stay in the already accepted camera shot. No replanning, movement,
	-- persistence mutation or reward event is involved in greeting/petting.
	if not self.pet.applyGardenPose then self.pet.affection=.9 end
	if not petting and not self.reduceEffects() then self.pet:greet() end
	if self.focusUI and self.focusUI.retireFocusHint then self.focusUI:retireFocusHint()end
	if not petting and now - (self.lastReactionAudioAt or -math.huge) >= 0.7 then
		self.lastReactionAudioAt = now
		self.audio:play(self.shownPet.cue, if petting then 1.04 else 1, if petting then 0.42 else 0.7)
	end
	return true
end

function Room:show(mode, animate)
	self.welcome.Visible = false
	if mode == "Room" then
		local meet = self.requestedPet ~= nil
		self.welcomeNext = nil
		local equipped = Pets.byId[self.progress:GetAttribute("CompanionId")]
		self:showPet(self.requestedPet or equipped)
		self.requestedPet = nil
		self:useRoomCamera(animate,true)
		if meet then
			local epoch, visual = self.focusEpoch, self.pet
			task.delay(0.35, function()
				if not self.destroyed and self.mode == "Room" and self.target == "Room" and self.pet == visual
					and self.focusEpoch == epoch then self:focusPet() end
			end)
		end
	else
		if self.arrivalPlacementPending then self.returnRoamShot=nil end
		self.arrivalPlacementPending=nil
		self.companions:clear()
		if self.pet then
			self.pet.focusPose=false
			self.pet:destroy()
			self.pet = nil
		end
  if self.affection then self.affection:setPet(nil)end
		self.petPrompt, self.petClick, self.focusMotion = nil, nil, nil
		self:restoreCamera()
	end
	self.menuOpen = false
	self:updateControls()
	self.board.Visible = mode == "Board"
	if mode == "Room" and string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then
		GuiService.SelectedObject = self.controls.OpenHandheld
	elseif mode == "Board" and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.controls) then
		GuiService.SelectedObject = nil
	end
end

function Room:setBusy(value)
	if self.busy==value then return end
	self.busy=value
	if self.onPresentationOwnerChanged then self.onPresentationOwnerChanged()end
end
-- Initial entry and replicated mode changes share one runner/input lock.
function Room:driveModes(initial)
	if self.busy or self.destroyed then return end
	self.switchEpoch=(self.switchEpoch or 0)+1
	local epoch=self.switchEpoch
	self:setBusy(true)
	task.spawn(function()
		local token
		local ok,problem=pcall(function()
			local first=initial == true
			while not self.destroyed and self.switchEpoch==epoch and (first or self.mode~=self.target) do
				local destination=self.target
				token=self.transition:begin(destination=="Board",if first then "initial" else "arrival")
				if token then
					if self.mode=="Room" then self:cancelCameraTween() end
					self.transition:cover(not first and self.mode=="Board",token)
				end
				if self.destroyed or self.switchEpoch~=epoch then return end
				-- A replicated destination can change while the curtain is moving.
				if self.target==destination then
					local changed=self.mode~=destination
					if changed and self.mode=="Room" and destination=="Board" then self:captureReturnRoam() end
					self.mode=destination
					self:show(destination,token~=nil and self.transition:owns(token))
					if changed and destination=="Room" and not self.overlayOpen() and not GuiService.MenuIsOpen then
						self.audio:play(self.shownPet.cue)
					end
					if token then self.transition:reveal(destination=="Board",token) end
					-- Keep Meet/focus from snapshotting an unfinished lounge camera move.
					if self.cameraTween and self.cameraTween.PlaybackState==Enum.PlaybackState.Playing then
						self.cameraTween.Completed:Wait()
					end
				else
					self.transition:hide(token)
				end
				first=false
			end
		end)
		if self.switchEpoch~=epoch or self.destroyed then return end
		if token then self.transition:hide(token) end
		self:setBusy(false)
		self:updateControls()
		if not ok then warn("Pocket Deck presentation:",problem) end
	end)
end

function Room:setMode(mode)
	if mode~="Room" then
		if self.arrivalPlacementPending then self.returnRoamShot=nil end
		self.arrivalPlacementPending=nil
	end
	if self.target~=mode then self.lastSwitchAt=os.clock() end
	self.target=mode
	self.transition:refresh()
	if mode~="Room" and self.focusing then self:useRoomCamera(false) end
	if not self.busy and self.mode~=mode then self:driveModes(false) end
end

function Room:startPresentation(mode)
	self.target=mode
	self:driveModes(true)
end

function Room:destroy()
	if self.destroyed then return end
	self.destroyed = true
 if self.petContactIntent then self.petContactIntent:destroy()end
	if self.garden then self.garden:destroy()end
	if self.gardenToy then self.gardenToy:destroy();self.gardenToy=nil end
 if self.affection then self.affection:destroy()end
	if self.ambience then self.ambience:destroy();self.ambience=nil end
	self.arrivalUnplaced=nil
	self.arrivalPlacementPending=nil
	self.returnRoamShot=nil
	self.switchEpoch=(self.switchEpoch or 0)+1
	self.focusEpoch = (self.focusEpoch or 0) + 1
	self:restoreCamera()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	if self.stations then self.stations:destroy() end
	self.companions:clear()
	if self.pet then self.pet:destroy(); self.pet = nil end
	self.petPrompt, self.petClick = nil, nil
	self.focusUI:destroy()
	self.controls:Destroy()
	self.transition:hide()
	self.transition.shade:Destroy()
end

return Room
