local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PipVisual = require(script.Parent.PipVisual)

local Room = {}
Room.__index = Room

local ink = Color3.fromRGB(255, 241, 207)
local mint = Color3.fromRGB(168, 239, 181)
local dark = Color3.fromRGB(31, 24, 53)
local violet = Color3.fromRGB(93, 71, 141)
local roomCamera = CFrame.lookAt(Vector3.new(11, 13, 17), Vector3.new(0, 6, -2))
local greetingCamera = CFrame.lookAt(Vector3.new(4, 8.2, 3.8), Vector3.new(0, 5.8, -5))

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
	node.TextColor3 = ink
	node.Font = Enum.Font.Code
	node.TextSize = 16
	node.ZIndex = 9
	node.Parent = parent
	return node
end

local function tween(object, seconds, properties)
	local motion = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), properties)
	motion:Play()
	return motion
end

function Room.new(gui, board, audio, onReturn, onMusic)
	local controls = frame(gui, "LoungeControls", UDim2.new(0.9, 0, 0, 102), UDim2.new(0.5, 0, 1, -16), dark, 8)
	controls.AnchorPoint = Vector2.new(0.5, 1)
	controls.Visible = false
	local max = Instance.new("UISizeConstraint")
	max.MaxSize = Vector2.new(410, 102)
	max.Parent = controls
	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(1, -12, 0, 29)
	heading.Position = UDim2.fromOffset(6, 5)
	heading.BackgroundTransparency = 1
	heading.Text = "LOUNGE  /  PIP"
	heading.TextColor3 = mint
	heading.TextSize = 17
	heading.Font = Enum.Font.Code
	heading.ZIndex = 9
	heading.Parent = controls
	local greet = button(controls, "GreetPip", "Greet Pip", UDim2.fromOffset(3, 37), violet)
	local leave = button(controls, "OpenHandheld", "Open handheld", UDim2.new(0.5, 1, 0, 37), violet)
	local music = button(controls, "Music", "Music on", UDim2.new(0.5, 0, 0, 78), dark)
	music.AnchorPoint = Vector2.new(0.5, 0)
	music.Size = UDim2.fromOffset(132, 24)
	music.TextSize = 13

	local top = frame(gui, "ShutterTop", UDim2.fromScale(1, 0), UDim2.fromScale(0, 0), dark, 50)
	local bottom = frame(gui, "ShutterBottom", UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), dark, 50)
	bottom.AnchorPoint = Vector2.new(0, 1)
	top.Visible, bottom.Visible = false, false
	top.Active, bottom.Active = true, true
	local strip = frame(top, "Scanline", UDim2.new(1, 0, 0, 2), UDim2.fromScale(0, 1), mint, 51)
	strip.AnchorPoint = Vector2.new(0, 1)

	local self = setmetatable({
		board = board,
		controls = controls,
		top = top,
		bottom = bottom,
		audio = audio,
		mode = "Board",
		target = "Board",
		music = music,
	}, Room)
	greet.Activated:Connect(function()
		if self.busy or not self.pip then
			return
		end
		self.pip:greet()
		audio:play("pet")
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
		if not self.busy then
			onReturn()
		end
	end)
	music.Activated:Connect(onMusic)
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
		if self.pip then
			self.pip:update(dt)
		end
	end)
	return self
end

function Room:setMusicLabel(muted)
	self.music.Text = if muted then "Music off" else "Music on"
end

function Room:show(mode)
	local camera = workspace.CurrentCamera
	if self.cameraTween then
		self.cameraTween:Cancel()
		self.cameraTween = nil
	end
	if mode == "Room" then
		self.pip = PipVisual.new(workspace, Vector3.new(0, 4.23, -5))
		if camera then
			self.savedCamera = { type = camera.CameraType, transform = camera.CFrame, fov = camera.FieldOfView }
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = roomCamera
			camera.FieldOfView = 53
		end
		self.pip:greet()
	else
		if self.pip then
			self.pip:destroy()
			self.pip = nil
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
			self.audio:play(if self.mode == "Room" then "pet" else "menu")
			tween(self.bottom, 0.25, { Size = UDim2.fromScale(1, 0) })
			tween(self.top, 0.25, { Size = UDim2.fromScale(1, 0) }).Completed:Wait()
			self.top.Visible, self.bottom.Visible = false, false
		end
		self.busy = false
	end)
end

return Room
