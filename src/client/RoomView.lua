local PetFocusKey=require(script.Parent.PetFocusKey)
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PetFocusUI = require(script.Parent.PetFocusUI)
local FocusTransition=require(script.Parent.FocusTransition)
local FocusCharacterVisibility=require(script.Parent.FocusCharacterVisibility)
local PetAffection=require(script.Parent.PetAffection)
local HollowAmbience=require(script.Parent.HollowAmbience)

local PetFactory=require(script.Parent.PetFactory)
local GardenClient=require(script.Parent.GardenClient)
local GardenActivity=require(ReplicatedStorage.Shared.GardenActivity)
local RoomCompanions = require(script.Parent.RoomCompanions)
local PetFollow = require(script.Parent.PetFollow)
local PetGreetingShot = require(script.Parent.PetGreetingShot)
local PetPrestige = require(script.Parent.PetPrestige)
local PetReactions = require(script.Parent.PetReactions)
local PetRigBounds=require(script.Parent.PetRigBounds)
local Art = require(script.Parent.DeckArt)
local DeckTransition = require(script.Parent.DeckTransition)
local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)

local Room = {}
Room.__index = Room

local function createPet(parent,origin,pet,masteryMask,rank,legacy,appearance,options)
	return PetFactory.create(parent,origin,pet,masteryMask,rank,legacy,appearance,options)
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
		transition = DeckTransition.new(gui, board:FindFirstChild("Tray",true), audio, reduceEffects), audio = audio,
		mode = "Board", target = "Board", lastSwitchAt = -math.huge,
		shownPet = Pets[1], menuOpen = false, overlayOpen = overlayOpen,
		companions = RoomCompanions.new(progress.Parent, createPet, reduceEffects),
		reduceEffects = reduceEffects, connections = {},
	}, Room)
	self.garden=GardenClient.new(progress.Parent)
 self.coos=require(script.Parent.PetCooScheduler).new(audio)
	self.focusTransition=FocusTransition.new(gui,reduceEffects)
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
			return self.focusing and not self.focusTransitioning and self.mode == "Room" and not self.busy and not self.overlayOpen()
				and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
		end,
	})
	self.care=require(script.Parent.GardenCareClient).new(self,gui)
	self.careArms=require(script.Parent.AvatarCarePose).new()
	local function watch(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(self.connections, connection)
		return connection
	end
	watch(RunService.PreAnimation,function()if self.careArms then self.careArms:restore()end end)
	watch(RunService.PreSimulation,function()
		if not self.careArms then return end
		local pose=require(script.Parent.PetCarePose)
		if self.pet and self.pet.careState=="Carried"then self.careArms:hold(Players.LocalPlayer.Character,pose.targets(self.pet))end
		for _,entry in pairs(self.companions.active)do if entry.visual.careState=="Carried"and entry.root then self.careArms:hold(entry.root.Parent,pose.targets(entry.visual))end end
	end)
	watch(progress:GetAttributeChangedSignal("PetAppearance"),function()self:refreshPetAppearance()end)
 watch(progress:GetAttributeChangedSignal("PetAppearanceRevision"),function()self:refreshPetAppearance()end)
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
	watch(Players.LocalPlayer.CharacterRemoving,function(character)if self.focusing then self:useRoomCamera(false)end;self.removingCharacter=character;self.returnRoamShot=nil;if self.focusUI then self.focusUI:cancelPointer()end;self:setPetContact(false);if self.stations then self.stations:refresh()end end)
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
        if self.focusKey then self.focusKey:disable()end
		self.returnRoamShot=nil
		if self.mode == "Room" then self:useRoomCamera(false) end
	end)
	watch(RunService.RenderStepped, function(dt)
        local serverNow=workspace:GetServerTimeNow()
  if self.ambience then
   self.ambience:step(dt,workspace.CurrentCamera,self.mode=="Room"and self.target=="Room"and not self.busy and not self.menuOpen and not self.overlayOpen()and not self.arrivalPlacementPending and not self.removingCharacter and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox(),self.reduceEffects())
  end
		self:retryArrivalPlacement()
		self:updateControls()
        if self.focusing and not self.focusExiting and(self.focusUI.windowActive==false or GuiService.MenuIsOpen or self.overlayOpen()or self.menuOpen or self.target~="Room")then self:useRoomCamera(false)end
		local gardenFocus=self.focusing and self.mode=="Room"and not self.busy and not self.overlayOpen()and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()and self.focusUI.windowActive~=false
		if self.pet and gardenFocus then self.garden:focus(true,self.shownPet.id)else self.garden:focus(false)end
		self.garden:step(dt)
		if self.care then self.care:step()end

		if self.pet then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            self.pet.personalPlayEnabled=self.mode=="Room"and self.target=="Room"and not self.busy and not self.focusing and not self.focusTransitioning and not self.menuOpen and not self.overlayOpen()and not GuiService.MenuIsOpen and not self.arrivalPlacementPending and not self.removingCharacter and self.focusUI.windowActive~=false and root~=nil and humanoid~=nil and humanoid.Health>0
			if self.focusing and not self.focusTransitioning then
				local shot = self.greetingCamera
				if not root or not humanoid or humanoid.Health <= 0 or not shot or shot.root ~= root
					or shot.camera ~= workspace.CurrentCamera then self:useRoomCamera(false)
				else self:reframeFocus()end
			end
			local reduced=self.reduceEffects()
			self.pet.reducedEffects=reduced
			if root and character~=self.removingCharacter and humanoid and humanoid.Health>0 and not self.focusing and not self.busy and not self.arrivalPlacementPending then
				local actor=self.garden:renderActor(Players.LocalPlayer.UserId,self.shownPet.id,character)
                self.pet.personalPlayEnabled=self.pet.personalPlayEnabled and actor~=nil and actor.mode=="Room"
                self.pet.personalActorIdentity=actor and(tostring(actor.characterId)..":"..tostring(actor.petGeneration))or nil
                self.pet.personalIdleUntil=if actor and actor.behavior=="follow"then actor.endTime+3.5 else 0
				if actor then self.followState=PetFollow.activity(self.pet,actor,serverNow,dt,self.followState,reduced)
				else self.followState = PetFollow.step(self.pet, root, dt, self.followState,reduced)end
			else self.followState=nil;PetFollow.rest(self.pet)end
			if self.focusing and self.reduceEffects() and self.cameraTween then
				self:cancelCameraTween()
				if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = PetGreetingShot.Fov end
			end
			self.pet.cosmeticSeed=Players.LocalPlayer.UserId
            self.pet.cosmeticTime=serverNow
            -- Close-up petting (boop squash, fast wag, the 1 s pose change) renders every
            -- frame instead of the 15 Hz pose cadence. One focused pet only.
            if self.pet.petting or(self.pet.boopAt and os.clock()-self.pet.boopAt<.25)then self.pet.poseDirty=true end
            self.pet:update(dt)
			self.pet.focused=self.focusing==true
			PetPrestige.update(self.pet, dt, self.reduceEffects())
		end
		if self.mode=="Room"then self.companions:update(dt,serverNow)end
  if self.coos then
   local root=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
   local humanoid=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
   self.coos:step(serverNow,{enabled=self.mode=="Room"and self.target=="Room"and not self.busy and not self.focusing and not self.focusTransitioning and not self.menuOpen and not self.overlayOpen()and not self.arrivalPlacementPending and not self.removingCharacter and self.focusUI.windowActive~=false and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()and humanoid~=nil and humanoid.Health>0,listener=root and root.Position,identity=root,camera=workspace.CurrentCamera},self.pet,self.companions.active)
  end
		if not self.focusKey then self.focusKey=PetFocusKey.new()end
        self.focusKey:update(workspace.CurrentCamera,self.pet,gardenFocus)
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
	local unobscured = self.mode == "Room" and not self.focusing and not self.busy and not self.focusTransitioning
		and not self.menuOpen and not self.overlayOpen() and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
	if self.canRoam then unobscured=self.canRoam() end
	self.controls.Visible = unobscured
	if self.focusUI then self.focusUI:setActive(self.focusing and self.mode == "Room") end
	local held=self.pet and(self.pet.careState=="Carried"or self.pet.careState=="Docked")
	if self.petPrompt then self.petPrompt.Enabled = unobscured and not held and not self:stationInReach() end
	if self.petClick then self.petClick.MaxActivationDistance = if unobscured and not held then 9 else 0 end
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
 if self:stationInReach()then return false end
	local now = os.clock()
	if now - (self.lastPetAt or -math.huge) < 0.45 then return false end
	if not self:focusPet() then return false end
	self.lastPetAt = now
	return true
end

function Room:requestSwitch(callback,careReleased)
	if not careReleased and self.care then
		local actor=self.care:actor()
		if actor and actor.care then self.care:release(function()self:requestSwitch(callback,true)end);return end
	end
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
    if self.focusing then self:useRoomCamera(false)end
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
	local rendered=self.garden:renderActor(Players.LocalPlayer.UserId,pet.id,character)
	local dock=rendered and rendered.care and rendered.care.state=="Docked"
	local position = if dock then GardenActivity.vector(rendered.to)else oldOrigin or (if root then root.Position - root.CFrame.LookVector * 3 + root.CFrame.RightVector * 2.6 else Vector3.new(0, 4.025, -5))
	local rank, legacy = PetPrestige.read(self.progress, pet)
	self.pet = (self.createPet or createPet)(workspace, position, pet, self.progress:GetAttribute("MasteryMask"), rank, legacy,self.garden:appearance(self.progress,pet.id))
    self.pet.cosmeticSeed=Players.LocalPlayer.UserId
    local shown=self.pet
    shown.onRigChanged=function()
     if not self.destroyed and self.pet==shown and self.affection then self.affection:rebind(shown)end
    end
    self.pet.cosmeticTime=workspace:GetServerTimeNow()
	self.pet.focusPose=self.focusing==true;self.focusGeometry=nil
	self.pet.origin = if dock then position else Vector3.new(position.X, PetFollow.ground(position, self.pet, oldOrigin and oldOrigin.Y), position.Z)
	self.pet.model:SetAttribute("CompanionOwnerId", Players.LocalPlayer.UserId)
	self.pet.model:SetAttribute("LocalCompanion", true)
 if self.affection then self.affection:setPet(self.pet)end
	self.pet.yaw = if self.focusing and oldYaw then oldYaw elseif root then math.atan2(root.CFrame.LookVector.X, root.CFrame.LookVector.Z) else 0
	if dock then require(script.Parent.PetCarePose).set(self.pet,"Docked");self.pet.yaw=rendered.yaw or 0;self.pet:update(0)end
	self.followState = nil
	self:refreshPetAppearance()
	-- The local pet is not rendered while the deck is up, so a round's ending
	-- reaction waits for the pet's next appearance (within 30 s) and plays then.
	local pending=self.pendingPlayReaction;self.pendingPlayReaction=nil
	if pending and os.clock()-pending.at<=30 then self:cheerPet(pending.kind,.9)end
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
	if not self.reduceEffects()and not dock then self.pet:greet() end
	self.heading.Text = "Sprout Hollow · "..pet.name.." · "..Pets.collectionSummary(owned,trials,self.progress:GetAttribute("InventoryMask"))
	self:updateControls()
end

function Room:refreshPetAppearance()
	if not self.garden or not self.shownPet then return end
	local appearance=self.garden:appearance(self.progress,self.shownPet.id)
	if self.appearancePet~=self.shownPet.id or self.appearanceCharm~=appearance.charmVisible then
		self.appearancePet,self.appearanceCharm=self.shownPet.id,appearance.charmVisible
		self.focusGeometry=nil
	end
	if self.pet and self.pet.applyAppearance then
  local before=self.pet.featureRevision;self.pet:applyAppearance(appearance)
  if before~=self.pet.featureRevision then self.focusGeometry=nil end
 end
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

function Room:hideFocusCharacter(character)
    if self.focusVisibility and self.focusVisibility.character==character and not self.focusVisibility.released then return end
    self:restoreFocusCharacter()
    self.focusVisibility=FocusCharacterVisibility.acquire(character)
end
function Room:restoreFocusCharacter()
    local scope=self.focusVisibility;self.focusVisibility=nil
    if scope then scope:release()end
end

function Room:restoreCamera(keepFocusCover)
    self:restoreFocusCharacter()
    if not keepFocusCover then
        if self.focusTransition and not self.focusTransition.destroyed then self.focusTransition:cancel()end
        self.focusTransitioning,self.focusExiting=false,false
    end
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

function Room:useRoomCamera(animate,arriving)
    if self.focusTransition and (self.focusing or self.greetingCamera or self.focusTransitioning)and not self.destroyed then
        if self.focusExiting then return false end
        self.focusExiting=true;self.focusTransitioning=true
        self.focusEpoch=(self.focusEpoch or 0)+1
        if self.focusUI then self.focusUI:cancelPointer()end
        self:setPetContact(false)
        local token=self.focusTransition:begin()
        task.spawn(function()
            if not self.focusTransition:cover(token)then return end
            self:_useRoomCamera(false,arriving)
            self.focusExiting=false
            self.focusTransition:reveal(token)
            if self.focusTransition:owns(token)then self.focusTransitioning=false;self:updateControls()end
        end)
        return true
    end
    return self:_useRoomCamera(animate,arriving)
end
function Room:_useRoomCamera(animate, arriving)
    self:restoreFocusCharacter()
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
		self:restoreCamera(true)
		return
	end
	local greeting = self.greetingCamera
	if self.viewportChanged then self.viewportChanged:Disconnect(); self.viewportChanged = nil end
	self.focusAspect = nil
	if not self.savedCamera or self.savedCamera.camera ~= camera then
		self:restoreCamera(true)
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
        -- The public actor kept moving independently of the private shot. Sample
        -- its newest authoritative pose before revealing the roaming camera.
        local actor=self.garden:get(Players.LocalPlayer.UserId,self.shownPet.id,root.Parent)
        local sample=actor and GardenActivity.sample(actor,workspace:GetServerTimeNow())
        local origin=sample and sample.position or self.focusPublicOrigin or self.pet.origin
        self.pet.origin=origin
        self.pet.yaw=sample and sample.yaw or self.focusPublicYaw or self.pet.yaw
        self.pet.gardenFocus=false
        if self.pet.applyGardenPose then self.pet:applyGardenPose(sample or {expression="neutral"})end
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
	if rig=="zivvi"or rig=="ovelle"or rig=="bear"then return PetGreetingShot.captureFocusedSubject(pet)end
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

function Room.greetingVisualBlocks(lounge,floor,rootPosition,reach)
 local blocks={}
 -- A tiny nonqueryable leaf can cover the lens completely at close range.
 -- Collect rendered descendants once per plan, never by visual size or physics.
 for _,part in ipairs(lounge:GetDescendants())do
  if part:IsA("BasePart")and part~=floor and not part:IsA("Terrain")
   and 1-(1-part.Transparency)*(1-part.LocalTransparencyModifier)<.99 then
   local cf,size=part.CFrame,part.Size
   local mesh=part:FindFirstChildOfClass("SpecialMesh")
   if mesh then
    cf*=CFrame.new(mesh.Offset)
    -- Managed lounge meshes are primitives; their rendered bounds follow Scale.
    -- FileMesh resources retain their authored Part bounds (no vertex-data API).
    if mesh.MeshType~=Enum.MeshType.FileMesh then
     local scale=mesh.Scale;size*=Vector3.new(math.abs(scale.X),math.abs(scale.Y),math.abs(scale.Z))
    end
   end
   if(cf.Position-rootPosition).Magnitude<=reach+size.Magnitude*.5 then
    table.insert(blocks,{source=part,Parent=part.Parent,CFrame=cf,Size=size})
   end
  end
 end
 return blocks
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
	local safeTop=topInset.Y+(self.focusUI.controlHeight or 44)+24
	local animationRise=.55*(self.pet.worldScale or 1)
	local reach=PetGreetingShot.maximumReach(size,aspect,crestReserve,camera.ViewportSize.Y,safeTop,animationRise)
	local visualBlocks=Room.greetingVisualBlocks(lounge,floor,root.Position,reach)
	local ownerParts={}
	local owner=root.Parent
	if owner then for _,part in ipairs(owner:GetDescendants())do
		if part:IsA("BasePart")and part.Transparency<.99 then table.insert(ownerParts,part)end
	end end
	local groundQueries,candidates=0,0
	local plan=PetGreetingShot.plan({
		rootPosition=root.Position,forward=root.CFrame.LookVector,size=size,silhouette=silhouette,focusEnvelope=focusEnvelope,crestPixelReserve=crestReserve,viewportHeight=camera.ViewportSize.Y,safeTopInset=safeTop,safeBottomInset=bottomInset.Y,safeLeftInset=topInset.X,safeRightInset=bottomInset.X,animationTopReserve=animationRise,
		centerOffset=CFrame.Angles(0,self.pet.yaw or 0,0):VectorToObjectSpace(bounds.Position-self.pet.origin),
		actualOrigin=self.focusPublicOrigin or self.pet.origin,aspect=aspect,floor={cf=floor.CFrame,size=floor.Size},preferredBearing=self.focusStageBearing,preferredOrigin=self.focusStageOrigin,
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
    -- Called only after an opaque rendered frame. The close-up owns this local
    -- character mask; public avatars and the authoritative pet remain intact.
    local shot=self.greetingCamera
    self:hideFocusCharacter(shot and shot.root and shot.root.Parent)
	self:cancelCameraTween()
	self.pet.origin, self.pet.yaw = plan.origin, plan.yaw
	self.focusStageOrigin,self.focusStageBearing=plan.origin,plan.bearing
	if self.garden and self.focusing and self.focusUI.windowActive~=false and not self.overlayOpen()and not GuiService.MenuIsOpen then
		self.garden:focus(true,self.shownPet.id)
	end
	self.pet.focusPose=true
	self.pet.lastFrame = -1
	self.pet:update(0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame, camera.Focus, camera.FieldOfView = plan.camera, CFrame.new(plan.target), plan.fov
	self.focusAspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	self.focusGeometry=Room.focusGeometryKey(camera,self.pet.rigRevision)
	if self.focusUI then self.focusUI:cancelPointer() end
end

function Room.focusGeometryKey(camera,rigRevision)
	local top,bottom=GuiService:GetGuiInset()
	return tostring(camera.ViewportSize)..":"..tostring(top)..":"..tostring(bottom)..":"..tostring(rigRevision or 0)
end

function Room:reframeFocus()
	local shot, camera = self.greetingCamera, workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not self.focusing or not shot or not self.pet or not camera or shot.camera ~= camera
		or shot.root ~= root or not root or self.mode ~= "Room" then return false end
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then return false end
	local geometry=Room.focusGeometryKey(camera,self.pet.rigRevision)
	if self.focusGeometry==geometry or self.focusTransitioning then return true end
	local lounge = workspace:FindFirstChild("EggDropLounge")
	local floor = lounge and lounge:FindFirstChild("Floor")
	if not floor then self:useRoomCamera(false);return false end
	local plan = self:planGreeting(camera, root, floor)
	if not plan then self:useRoomCamera(false);return false end
	-- Resize changes only the geometry. The original pre-focus restore snapshot,
	-- pet origin, root and generation remain untouched for Back/respawn handling.
	self.focusTransitioning=true
    local epoch=self.focusEpoch;local token=self.focusTransition:begin()
    task.spawn(function()
        if not self.focusTransition:cover(token)then return end
        if self.focusing and self.focusEpoch==epoch and workspace.CurrentCamera==camera then self:applyFocusPlan(plan,camera)end
        self.focusTransition:reveal(token)
        if self.focusTransition:owns(token)then self.focusTransitioning=false end
    end)
    return true
end

function Room:focusPet()
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local lounge = workspace:FindFirstChild("EggDropLounge")
	local floor = lounge and lounge:FindFirstChild("Floor")
	if self.focusing then return self:reactPet(false) end
 if self:stationInReach()then return false end
	if not camera or not self.pet or self.mode ~= "Room" or not root or not floor or self.focusTransitioning then return false end
    local actor=self.garden:get(Players.LocalPlayer.UserId,self.shownPet.id,character)
    local public=actor and GardenActivity.sample(actor,workspace:GetServerTimeNow())
    if public and(public.position-root.Position).Magnitude>7 then
        self.focusUI:showFeedback("Let your pet come closer, then try again")
        return false
    end
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
    self.focusPublicOrigin,self.focusPublicYaw=self.pet.origin,self.pet.yaw
    self.focusTransitioning=true
    if self.garden then self.garden:focus(true,self.shownPet.id)end
    local epoch=self.focusEpoch;local token=self.focusTransition:begin()
    task.spawn(function()
        if not self.focusTransition:cover(token)then return end
        if not self.focusing or self.focusEpoch~=epoch or self.destroyed or workspace.CurrentCamera~=camera
            or Players.LocalPlayer.Character~=character or not self.greetingCamera or self.pet~=self.greetingCamera.pet then
            if self.focusTransition:owns(token)then self:useRoomCamera(false)end
            return
        end
        -- Keep the covered shot pending until the public pause is confirmed.
        local deadline=os.clock()+.85;local accepted
        repeat
            local current=self.garden.snapshot and self.garden.snapshot.actors[tostring(Players.LocalPlayer.UserId)]
            accepted=current and current.mode=="Focus"and current.requestGeneration==self.garden.focusSeq
            if accepted or not self.focusTransition:owns(token)then break end
            RunService.Heartbeat:Wait()
        until os.clock()>=deadline
        if not self.focusTransition:owns(token)or self.focusEpoch~=epoch then return end
        if not accepted then
            self:_useRoomCamera(false)
            self.focusUI:showFeedback("Let your pet come closer, then try again")
            self.focusTransition:reveal(token)
            if self.focusTransition:owns(token)then self.focusTransitioning=false;self:updateControls()end
            return
        end
        local current=self.garden.snapshot.actors[tostring(Players.LocalPlayer.UserId)]
        local public=GardenActivity.sample(current,workspace:GetServerTimeNow())
        if public then self.focusPublicOrigin,self.focusPublicYaw=public.position,public.yaw end
        local confirmedPlan=self:planGreeting(camera,root,floor)
        if not confirmedPlan then self:useRoomCamera(false);return end
        self:applyFocusPlan(confirmedPlan,camera)
        if self.pet.applyGardenPose then self.pet:applyGardenPose({action="focus",actionPhase=0,expression="curious",actionId="focus-"..epoch,generation=epoch})end
        self.audio:play(self.shownPet.cue)
        if self.focusUI then self.focusUI:retireRoamHint()end
        self.focusTransition:reveal(token)
        if self.focusTransition:owns(token)then self.focusTransitioning=false;self:updateControls()end
    end)
    if self.viewportChanged then self.viewportChanged:Disconnect()end
    self.viewportChanged=camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if not self.destroyed and self.focusing and self.focusEpoch==epoch and workspace.CurrentCamera==camera then self:reframeFocus()end
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
 if active and (self.focusTransitioning or(self.focusUI and self.focusUI.windowActive==false))then return false end
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
	if self.removingCharacter==Players.LocalPlayer.Character or not self.focusing or self.mode~="Room"or self.busy or self.focusTransitioning or self.menuOpen or self.overlayOpen()or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()
		or not self.pet or not self.greetingCamera or self.greetingCamera.root~=root or self.greetingCamera.camera~=workspace.CurrentCamera then return false end
 self.petContactActive,self.contactPet=true,self.pet;self.pet.petting=true
 if self.affection then self.affection:begin(self.reduceEffects())end
 local now=os.clock()
 -- Every touch starts with a boop: a 0.15 s squash (not under Reduced Effects) and
 -- the pet's cue at a random pitch from 0.96 to 1.08. Holding then builds the pose.
 if not self.reduceEffects()then self.pet.boopAt=now end
 if now-(self.lastContactChirpAt or -math.huge)>=.25 then
  self.boopRandom=self.boopRandom or Random.new()
  self.lastContactChirpAt=now;self.lastReactionAudioAt=now;self.audio:play(self.shownPet.cue,self.boopRandom:NextNumber(.96,1.08),.3)
 end
 self.contactContext={pet=self.pet,root=root,camera=workspace.CurrentCamera,shot=self.greetingCamera}
 if self.petContactIntent then self.petContactIntent:begin(self.shownPet.id,self.contactContext)end
 if self.audio and self.audio.setPurr then self.audio:setPurr(true)end
 return true
end

function Room:contactEligible(context)
 if not context or self.destroyed or not self.petContactActive or not self.focusing or self.mode~="Room"or self.busy or self.focusTransitioning or self.menuOpen or self.overlayOpen()or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()then return false end
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
-- Deck play reaches the local pet: "cheer" (tier III+ merge or chain 3+, at most
-- every 1.5 s), "win" (double hop) or "loss" (startled, then sleepy). Visual and a
-- chirp only; the pet's server state and other players' views never change.
function Room:cheerPet(kind,delay)
 local pet=self.pet;local now=os.clock()+(delay or 0)
 if(not pet or pet.destroyed)and kind~="cheer"then self.pendingPlayReaction={kind=kind,at=now};return false end
 if not pet or pet.destroyed or self.focusing then return false end
 if not PetReactions.trigger(pet,kind,now)then return false end
 pet.poseDirty=true;pet.model:SetAttribute("PlayReaction",kind)
 if kind~="loss"and self.shownPet and self.shownPet.cue and now-(self.lastCheerAudioAt or -math.huge)>=.6 then
  self.lastCheerAudioAt=now
  local cue,speed=self.shownPet.cue,if kind=="win"then 1.18 else 1.12
  if(delay or 0)>0 then task.delay(delay,function()if self.pet==pet and not self.destroyed then self.audio:play(cue,speed,.32)end end)
  else self.audio:play(cue,speed,.32)end
 end
 return true
end

function Room:reactPet(petting)
 if self.focusUI and self.focusUI.windowActive==false then return false end
	if self.focusTransitioning then return false end
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
        self.endedRoomSerial=if self.progress:GetAttribute("RoundOver")==true then self.progress:GetAttribute("ResetId")else nil
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
                if destination=="Board"and self.boardContentReady then
                    self.transition:setContentCover(true)
                    while not self.destroyed and self.switchEpoch==epoch and self.target==destination
                        and not self.boardContentReady(self.endedRoomSerial)do task.wait()end
                    if self.destroyed or self.switchEpoch~=epoch then return end
                end
				-- A replicated destination can change while the curtain is moving.
				if self.target==destination then
					local changed=self.mode~=destination
					if changed and self.mode=="Room" and destination=="Board" then self:captureReturnRoam() end
					self.mode=destination
					self:show(destination,token~=nil and self.transition:owns(token))
                    self.transition:setContentCover(false)
                    if destination=="Board"then self.endedRoomSerial=nil end
					if changed and destination=="Room" and not self.overlayOpen() and not GuiService.MenuIsOpen then
						self.audio:play(self.shownPet.cue)
					end
					if token then self.transition:reveal(destination=="Board",token) end
					-- Keep Meet/focus from snapshotting an unfinished lounge camera move.
					if self.cameraTween and self.cameraTween.PlaybackState==Enum.PlaybackState.Playing then
						self.cameraTween.Completed:Wait()
					end
				else
					self.transition:setContentCover(false)
					self.transition:hide(token)
				end
				first=false
			end
		end)
		if self.switchEpoch~=epoch or self.destroyed then return end
		self.transition:setContentCover(false)
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
 if self.care then self.care:destroy();self.care=nil end
 if self.careArms then self.careArms:destroy();self.careArms=nil end
 if self.coos then self.coos:destroy();self.coos=nil end
	self.destroyed = true
 if self.focusKey then self.focusKey:destroy();self.focusKey=nil end
 if self.petContactIntent then self.petContactIntent:destroy()end
	if self.focusTransition then self.focusTransition:destroy()end
	if self.toyPrompt then self.toyPrompt:destroy();self.toyPrompt=nil end
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
	if self.transition.contentCover then self.transition.contentCover:Destroy()end
	self.transition.shade:Destroy()
end

return Room
