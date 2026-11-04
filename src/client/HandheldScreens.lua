local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Screens = {}
local tag = "EggDropHandheld"

function Screens.start(trays, config)
	local devices = {}
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.125 then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local active = {}
		for _, device in ipairs(CollectionService:GetTagged(tag)) do
			local screen = device:FindFirstChild("Screen")
			local board = trays:FindFirstChild(tostring(device:GetAttribute("BoardUserId")))
			if screen and board and (screen.Position - camera.CFrame.Position).Magnitude <= 34 then
				active[device] = true
				local view = devices[device]
				if not view then
					local surface = Instance.new("SurfaceGui")
					surface.Name = "LiveTray"
					surface.Face = Enum.NormalId.Front
					surface.CanvasSize = Vector2.new(84, 87)
					surface.LightInfluence = 0
					surface.MaxDistance = 34
					surface.Active = false
					surface.Parent = screen
					view = { surface = surface, dots = {} }
					devices[device] = view
				end
				local eggs = {}
				for _, egg in ipairs(board:GetChildren()) do
					if not egg:IsA("BasePart") then
						continue
					end
					eggs[egg] = true
					local dot = view.dots[egg]
					if not dot then
						dot = Instance.new("Frame")
						dot.Name = "Egg"
						dot.AnchorPoint = Vector2.new(0.5, 0.5)
						dot.BackgroundColor3 = egg.Color
						dot.BorderSizePixel = 0
						dot.Size = UDim2.fromScale(egg.Size.X / config.Width, egg.Size.Y / config.Height)
						local corner = Instance.new("UICorner")
						corner.CornerRadius = UDim.new(1, 0)
						corner.Parent = dot
						dot.Parent = view.surface
						view.dots[egg] = dot
					end
					dot.Position = UDim2.fromScale(0.5 + egg.Position.X / config.Width, 1 - egg.Position.Y / config.Height)
				end
				for egg, dot in pairs(view.dots) do
					if not eggs[egg] then
						dot:Destroy()
						view.dots[egg] = nil
					end
				end
			end
		end
		for device, view in pairs(devices) do
			if not active[device] then
				view.surface:Destroy()
				devices[device] = nil
			end
		end
	end)
end

return Screens
