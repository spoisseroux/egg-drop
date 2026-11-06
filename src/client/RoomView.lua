local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PipVisual = require(script.Parent.PipVisual)
local PuddleVisual = require(script.Parent.PuddleVisual)
local BonusPetVisual = require(script.Parent.BonusPetVisual)
local RoomCompanions = require(script.Parent.RoomCompanions)
local PetFollow = require(script.Parent.PetFollow)
local PetPrestige = require(script.Parent.PetPrestige)
local Art = require(script.Parent.DeckArt)
local DeckTransition = require(script.Parent.DeckTransition)
local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)

local Room = {}
Room.__index = Room

local visuals = { pip = PipVisual, puddle = PuddleVisual }

local function createPet(parent, origin, pet, masteryMask, rank, legacy)
	local visual = visuals[pet.family or pet.id] or BonusPetVisual
	local result = visual.new(parent, origin, pet)
	if legacy == nil then
		local index = table.find({ "pip", "puddle", "wick", "orbit" }, pet.family or pet.id)
		legacy = index and bit32.band(masteryMask or 0, bit32.lshift(1, index - 1)) ~= 0
	end
	PetPrestige.attach(result, pet, rank or 0, legacy)
	return result
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
	-- A small roaming pill replaces the always-open five-button panel.
	local controls = frame(gui, "LoungeControls", UDim2.fromOffset(180, 48), UDim2.new(1, -12, 0, 12), Art.Surface, 8)
	controls.AnchorPoint = Vector2.new(1, 0)
	controls.Visible = false
	Art.panel(controls, 10)
	local menu = button(controls, "Menu", "Menu", UDim2.fromOffset(4, 2), Art.Raised)
	local leave = button(controls, "OpenHandheld", "Deck", UDim2.fromOffset(92, 2), Art.Cyan)
	menu.Size, leave.Size = UDim2.fromOffset(84, 44), UDim2.fromOffset(84, 44)
	-- Retain these handles for the welcome guide and old controller restoration.
	local heading = Art.text(controls, "Heading", "Sprout Hollow", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), Art.Silver, 12)
	local welcome = Art.text(controls, "FirstVisit", "", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), Art.Muted, 11)
	local greet = button(controls, "GreetPet", "Say hi", UDim2.fromOffset(0, 0), Art.Raised)
	heading.Visible, welcome.Visible, greet.Visible = false, false, false
	local self = setmetatable({
		board = board, progress = progress, controls = controls, heading = heading,
		welcome = welcome, greetButton = greet, menuButton = menu,
		transition = DeckTransition.new(gui, board.Tray), audio = audio,
		mode = "Board", target = "Board", lastSwitchAt = -math.huge,
		shownPet = Pets[1], menuOpen = false, overlayOpen = overlayOpen,
		companions = RoomCompanions.new(progress.Parent, createPet, reduceEffects),
		reduceEffects = reduceEffects,
	}, Room)
	menu.Activated:Connect(function()
		if self.mode == "Room" and not self.busy and not self.focusing and not overlayOpen() then
			if self.onOpenMenu then self.onOpenMenu() else onCollection() end
		end
	end)
	greet.Activated:Connect(function() self:interactPet() end)
	leave.Activated:Connect(function()
		if not self.busy and not overlayOpen() then self:requestSwitch(onReturn) end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if self.mode == "Room" and humanoid then
			self.followState = nil
			task.defer(function() if self.mode == "Room" then self:useRoomCamera(false) end end)
		end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if self.mode == "Room" then self:useRoomCamera(false) end
	end)
	RunService.RenderStepped:Connect(function(dt)
		self:updateControls()
		if self.pet then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if self.focusing and humanoid and humanoid.MoveDirection.Magnitude > 0.05 then self:useRoomCamera(false) end
			if root and not self.focusing then self.followState = PetFollow.step(self.pet, root, dt, self.followState) end
			if self.focusing and self.focusMotion then
				local motion = self.focusMotion
				motion.time += dt
				local alpha = math.clamp(motion.time / 0.45, 0, 1)
				alpha = alpha * alpha * (3 - 2 * alpha)
				self.pet.origin = motion.from:Lerp(motion.to, alpha)
				self.pet.yaw = motion.yawFrom + motion.yawDelta * alpha
				if motion.time >= 0.45 then self.focusMotion = nil end
			end
			self.pet:update(dt)
			PetPrestige.update(self.pet, dt, self.reduceEffects())
			self.companions:update(dt)
		end
	end)
	for _, attribute in ipairs({ "MasteryRanks", "MasteryMask" }) do
		progress:GetAttributeChangedSignal(attribute):Connect(function()
			if self.mode == "Room" and self.pet then self:showPet(self.shownPet) end
		end)
	end
	return self
end

function Room:updateControls()
	local unobscured = self.mode == "Room" and not self.focusing and not self.busy
		and not self.menuOpen and not self.overlayOpen()
	self.controls.Visible = unobscured
	if self.petPrompt then self.petPrompt.Enabled = unobscured end
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
	if self.mode ~= "Room" or self.busy or self.focusing or self.overlayOpen() or self.menuOpen or not self.pet then return false end
	local now = os.clock()
	if now - (self.lastPetAt or -math.huge) < 0.45 then return false end
	self.lastPetAt = now
	self:focusPet()
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
	local owned = self.progress:GetAttribute("OwnedPets") or 0
	local trials = self.progress:GetAttribute("TrialMask") or 0
	if not pet or not Pets.isUnlocked(pet, owned, trials, self.progress:GetAttribute("InventoryMask")) then pet = Pets[1] end
	self.shownPet = pet
	local oldOrigin = self.pet and self.pet.origin
	local oldYaw = self.pet and self.pet.yaw
	if self.pet then self.pet:destroy() end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = oldOrigin or (if root then root.Position - root.CFrame.LookVector * 3 + root.CFrame.RightVector * 2.6 else Vector3.new(0, 4.025, -5))
	local rank, legacy = PetPrestige.read(self.progress, pet)
	self.pet = createPet(workspace, position, pet, self.progress:GetAttribute("MasteryMask"), rank, legacy)
	self.pet.origin = Vector3.new(position.X, PetFollow.ground(position, self.pet, oldOrigin and oldOrigin.Y), position.Z)
	self.pet.model:SetAttribute("CompanionOwnerId", Players.LocalPlayer.UserId)
	self.pet.model:SetAttribute("LocalCompanion", true)
	self.pet.yaw = if self.focusing and oldYaw then oldYaw elseif root then math.atan2(root.CFrame.LookVector.X, root.CFrame.LookVector.Z) else 0
	self.followState = nil
	local body = self.pet.model.PrimaryPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "PetInteraction", "Say hi", pet.name
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.ClickablePrompt, prompt.RequiresLineOfSight, prompt.HoldDuration = true, false, 0
	prompt.MaxActivationDistance, prompt.UIOffset = 9, Vector2.new(0, 22)
	prompt.Enabled, prompt.Parent = false, body
	prompt.Triggered:Connect(function(who) if who == nil or who == Players.LocalPlayer then self:interactPet() end end)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance, click.Parent = 9, body
	click.MouseClick:Connect(function(who) if who == Players.LocalPlayer then self:interactPet() end end)
	self.petPrompt, self.petClick = prompt, click
	if not self.reduceEffects() then self.pet:greet() end
	self.heading.Text = string.format("Sprout Hollow · %s · %d/%d", pet.name,
		Pets.ownedCount(owned, trials, self.progress:GetAttribute("InventoryMask")), #Pets.collection)
	self:updateControls()
end

function Room:cancelCameraTween()
	if self.cameraTween then
		self.cameraTween:Cancel()
		self.cameraTween = nil
	end
end

function Room:restoreCamera()
	self:cancelCameraTween()
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
	if saved and saved.camera.Parent then
		saved.camera.CFrame = saved.transform
		saved.camera.Focus = saved.focus
		saved.camera.FieldOfView = saved.fov
		saved.camera.CameraType = saved.type
	end
end

function Room:useRoomCamera(animate)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if not self.savedCamera or self.savedCamera.camera ~= camera then
		self:restoreCamera()
		self.savedCamera = {
			camera = camera, type = camera.CameraType, transform = camera.CFrame,
			focus = camera.Focus, fov = camera.FieldOfView,
		}
	else
		self:cancelCameraTween()
	end
	self.focusing = false
	self.focusMotion, self.followState = nil, nil
	self.focusEpoch = (self.focusEpoch or 0) + 1
	self.greetButton.Text = "Say hi"
	self:updateControls()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.FieldOfView = 65
	if root and not self.roamed then
		local target = root.Position + Vector3.new(0, 1, 0)
		camera.CFrame = CFrame.lookAt(target + Vector3.new(5, 6, 12), target)
	end
	self.roamed = true
	camera.CameraType = Enum.CameraType.Custom
end

function Room:focusPet()
	local camera = workspace.CurrentCamera
	if not camera or not self.pet or self.mode ~= "Room" then return end
	self:cancelCameraTween()
	self.focusing = true
	self.greetButton.Text = "Roam"
	self.audio:play(self.shownPet.cue)
	if not self.reduceEffects() then self.pet:greet() end
	self.menuOpen = false
	self:updateControls()
	-- Stage the pet ahead of the player, with the camera BETWEEN them. The
	-- avatar then stays behind the camera instead of blocking the pet's face.
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local forward = if root then Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) else Vector3.new(0, 0, -1)
	if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) else forward = forward.Unit end
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local _, size = self.pet.model:GetBoundingBox()
	local portrait = camera.ViewportSize.X < camera.ViewportSize.Y
	local distance = math.max(if portrait then 5.1 else 4.6, size.Y * 1.55)
	local destinationOrigin = if root then root.Position + forward * (distance + 2.8) else self.pet.origin
	destinationOrigin = Vector3.new(destinationOrigin.X, PetFollow.ground(destinationOrigin, self.pet, self.pet.origin.Y), destinationOrigin.Z)
	local target = destinationOrigin + Vector3.new(0, math.max(1.35, size.Y * 0.52), 0)
	local cameraPosition = target - forward * distance + right * 0.55 + Vector3.new(0, 0.65, 0)
	local destination = CFrame.lookAt(cameraPosition, target)
	local facing = cameraPosition - destinationOrigin
	local wantedYaw = math.atan2(facing.X, facing.Z)
	local currentYaw = self.pet.yaw or wantedYaw
	self.focusMotion = { from = self.pet.origin, to = destinationOrigin, time = 0,
		yawFrom = currentYaw, yawDelta = math.atan2(math.sin(wantedYaw - currentYaw), math.cos(wantedYaw - currentYaw)) }
	camera.CameraType = Enum.CameraType.Scriptable
	local epoch = (self.focusEpoch or 0) + 1
	self.focusEpoch = epoch
	if self.reduceEffects() then
		self.pet.origin, self.pet.yaw, self.focusMotion = destinationOrigin, wantedYaw, nil
		self.pet:update(0)
		camera.CFrame, camera.Focus, camera.FieldOfView = destination, CFrame.new(target), 43
	else
		self.cameraTween = tween(camera, 0.45, { CFrame = destination, Focus = CFrame.new(target), FieldOfView = 43 })
	end
	task.delay(2.8, function()
		if self.mode == "Room" and not self.busy and self.focusing and self.focusEpoch == epoch
			and workspace.CurrentCamera == camera then self:useRoomCamera(false) end
	end)
end

function Room:show(mode, animate)
	self.welcome.Visible = false
	if mode == "Room" then
		local meet = self.requestedPet ~= nil
		self.welcomeNext = nil
		local equipped = Pets.byId[self.progress:GetAttribute("CompanionId")]
		self:showPet(self.requestedPet or equipped)
		self.requestedPet = nil
		self:useRoomCamera(animate)
		if meet then
			task.delay(0.35, function()
				if self.mode == "Room" and self.pet then self:focusPet() end
			end)
		end
	else
		self.companions:clear()
		if self.pet then
			self.pet:destroy()
			self.pet = nil
		end
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

function Room:setMode(mode)
	if self.target ~= mode then
		self.lastSwitchAt = os.clock()
	end
	self.target = mode
	if self.busy or self.mode == mode then
		return
	end
	self.busy = true
	task.spawn(function()
		while self.mode ~= self.target do
			local animate = not self.reduceEffects()
			if animate then
				if self.mode == "Room" then
					self:cancelCameraTween()
				end
				self.transition:cover(self.mode == "Board")
			end
			animate = animate and not self.reduceEffects()
			if self.mode ~= self.target then
				self.mode = self.target
				self:show(self.mode, animate)
				self.audio:play(if self.mode == "Room" then self.shownPet.cue else "menu")
			end
			if animate then
				self.transition:reveal(self.mode == "Board")
				if self.cameraTween and self.cameraTween.PlaybackState == Enum.PlaybackState.Playing then
					self.cameraTween.Completed:Wait()
				end
			else
				self.transition:hide()
			end
		end
		self.busy = false
	end)
end

return Room
