local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PipVisual = require(script.Parent.PipVisual)
local PuddleVisual = require(script.Parent.PuddleVisual)
local Palette = require(ReplicatedStorage.Shared.DeckPalette)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)

local Room = {}
Room.__index = Room

local roomCamera = CFrame.lookAt(Vector3.new(11, 13, 17), Vector3.new(0, 6, -2))
local greetingCamera = CFrame.lookAt(Vector3.new(4, 8.2, 3.8), Vector3.new(0, 5.8, -5))
local visuals = { PipVisual, PuddleVisual }

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
	node.TextColor3 = Palette.Ink
	node.Font = Enum.Font.GothamMedium
	node.TextSize = 14
	node.ZIndex = 9
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 9)
	round.Parent = node
	node.Parent = parent
	return node
end

local function tween(object, seconds, properties)
	local motion = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), properties)
	motion:Play()
	return motion
end

function Room.new(gui, board, progress, audio, onReturn, onCustomize, isPickerOpen)
	local controls = frame(gui, "LoungeControls", UDim2.new(0.9, 0, 0, 110), UDim2.new(0.5, 0, 1, -16), Palette.Ink, 8)
	controls.AnchorPoint = Vector2.new(0.5, 1)
	controls.Visible = false
	local max = Instance.new("UISizeConstraint")
	max.MaxSize = Vector2.new(430, 110)
	max.Parent = controls
	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(0.56, 0, 0, 44)
	heading.Position = UDim2.fromScale(0.025, 0)
	heading.BackgroundTransparency = 1
	heading.Text = "Pip’s lounge"
	heading.TextColor3 = Palette.Paper
	heading.TextSize = 17
	heading.Font = Enum.Font.GothamBold
	heading.ZIndex = 9
	heading.Parent = controls
	local switch = button(controls, "SwitchPet", "", UDim2.new(0.60, 0, 0, 2), Palette.Panel)
	switch.Size = UDim2.new(0.375, 0, 0, 44)
	local greet = button(controls, "GreetPet", "Say hi", UDim2.new(0.025, 0, 0, 51), Palette.Panel)
	greet.Size = UDim2.new(0.29, 0, 0, 44)
	local leave = button(controls, "OpenHandheld", "Open deck", UDim2.new(0.335, 0, 0, 51), Palette.Primary)
	leave.Size = UDim2.new(0.33, 0, 0, 44)
	local customize = button(controls, "Customize", "Customize", UDim2.new(0.685, 0, 0, 51), Palette.Panel)
	customize.Size = UDim2.new(0.29, 0, 0, 44)

	local top = frame(gui, "ShutterTop", UDim2.fromScale(1, 0), UDim2.fromScale(0, 0), Palette.Backdrop, 50)
	local bottom = frame(gui, "ShutterBottom", UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), Palette.Backdrop, 50)
	bottom.AnchorPoint = Vector2.new(0, 1)
	top.Visible, bottom.Visible = false, false
	top.Active, bottom.Active = true, true
	local strip = frame(top, "Scanline", UDim2.new(1, 0, 0, 2), UDim2.fromScale(0, 1), Palette.Primary, 51)
	strip.AnchorPoint = Vector2.new(0, 1)

	local self = setmetatable({
		board = board,
		progress = progress,
		controls = controls,
		heading = heading,
		switch = switch,
		top = top,
		bottom = bottom,
		audio = audio,
		mode = "Board",
		target = "Board",
		petIndex = 1,
	}, Room)
	switch.Activated:Connect(function()
		local owned = progress:GetAttribute("OwnedPets") or 0
		if self.mode == "Room" and not self.busy and not isPickerOpen() and owned > 1 then
			self:showPet(self.petIndex % owned + 1)
			audio:play(Pets[self.petIndex].cue)
		end
	end)
	greet.Activated:Connect(function()
		if self.busy or isPickerOpen() or not self.pet then
			return
		end
		self.pet:greet()
		audio:play(Pets[self.petIndex].cue)
		local camera = workspace.CurrentCamera
		if camera then
			if self.cameraTween then
				self.cameraTween:Cancel()
			end
			self.cameraTween = tween(camera, 0.58, { CFrame = greetingCamera })
			local closeup = self.cameraTween
			task.delay(2.7, function()
				if self.mode == "Room" and not self.busy and self.cameraTween == closeup then
					self.cameraTween = tween(camera, 0.75, { CFrame = roomCamera })
				end
			end)
		end
	end)
	leave.Activated:Connect(function()
		if not self.busy and not isPickerOpen() then
			onReturn()
		end
	end)
	customize.Activated:Connect(function()
		if not self.busy then
			onCustomize()
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if self.mode == "Room" and humanoid then
			task.defer(function()
				local camera = workspace.CurrentCamera
				if self.mode == "Room" and camera then
					camera.CameraType = Enum.CameraType.Scriptable
					camera.CFrame = roomCamera
					camera.FieldOfView = 53
				end
			end)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if self.pet then
			self.pet:update(dt)
		end
	end)
	return self
end

function Room:choosePet(name)
	local owned = self.progress:GetAttribute("OwnedPets") or 0
	for index = 1, owned do
		if Pets[index].name == name then
			self.petIndex = index
			return
		end
	end
end

function Room:showPet(index)
	local owned = math.max(1, self.progress:GetAttribute("OwnedPets") or 0)
	self.petIndex = math.clamp(index, 1, owned)
	if self.pet then
		self.pet:destroy()
	end
	self.pet = visuals[self.petIndex].new(workspace, Vector3.new(0, 4.23, -5))
	self.pet:greet()
	self.heading.Text = string.format("%s  ·  %d/%d", Pets[self.petIndex].name, owned, #Pets)
	self.switch.Visible = owned > 1
	self.switch.Text = "View " .. Pets[self.petIndex % owned + 1].name
end

function Room:show(mode)
	local camera = workspace.CurrentCamera
	if self.cameraTween then
		self.cameraTween:Cancel()
		self.cameraTween = nil
	end
	if mode == "Room" then
		self:showPet(self.petIndex)
		if camera then
			self.savedCamera = { type = camera.CameraType, transform = camera.CFrame, fov = camera.FieldOfView }
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = roomCamera
			camera.FieldOfView = 53
		end
	else
		if self.pet then
			self.pet:destroy()
			self.pet = nil
		end
		if camera and self.savedCamera then
			camera.CFrame = self.savedCamera.transform
			camera.FieldOfView = self.savedCamera.fov
			camera.CameraType = self.savedCamera.type
			self.savedCamera = nil
		end
	end
	self.controls.Visible = mode == "Room"
	self.board.Visible = mode == "Board"
end

function Room:setMode(mode)
	self.target = mode
	if self.busy or self.mode == mode then
		return
	end
	self.busy = true
	task.spawn(function()
		while self.mode ~= self.target do
			self.top.Visible, self.bottom.Visible = true, true
			tween(self.bottom, 0.23, { Size = UDim2.fromScale(1, 0.51) })
			tween(self.top, 0.23, { Size = UDim2.fromScale(1, 0.51) }).Completed:Wait()
			self.mode = self.target
			self:show(self.mode)
			self.audio:play(if self.mode == "Room" then Pets[self.petIndex].cue else "menu")
			tween(self.bottom, 0.25, { Size = UDim2.fromScale(1, 0) })
			tween(self.top, 0.25, { Size = UDim2.fromScale(1, 0) }).Completed:Wait()
			self.top.Visible, self.bottom.Visible = false, false
		end
		self.busy = false
	end)
end

return Room
