-- A soft placeholder while a preview's art loads (launch candidate, 2026-11-17): a light
-- well with one gentle sweep instead of a dark empty tile. One tween per shimmer, cancelled
-- the moment the art is ready (or the frame goes away). Reduced Motion: the still well only.
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Shimmer = {}
Shimmer.Period = 1.3
Shimmer.Peak = 0.84 -- the sweep's brightest transparency (white over the well)

-- frame: the placeholder (its own colour stays); returns {stop = function, sweep = Frame}.
function Shimmer.attach(frame, reduced)
	local sweep = Instance.new("Frame")
	sweep.Name = "Shimmer"
	sweep.BackgroundColor3 = Color3.new(1, 1, 1)
	sweep.BorderSizePixel = 0
	sweep.Size = UDim2.fromScale(1, 1)
	sweep.ZIndex = frame.ZIndex + 1
	sweep.Active = false
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then corner:Clone().Parent = sweep end
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 18
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.38, 1), NumberSequenceKeypoint.new(0.5, Shimmer.Peak),
		NumberSequenceKeypoint.new(0.62, 1), NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = sweep
	sweep.Parent = frame
	local still = if reduced == nil then GuiService.ReducedMotionEnabled else reduced
	local tween
	if not still then
		tween = TweenService:Create(gradient, TweenInfo.new(Shimmer.Period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) })
		tween:Play()
	else
		sweep.Visible = false
	end
	local handle = { sweep = sweep, stopped = false }
	function handle.stop()
		if handle.stopped then return end
		handle.stopped = true
		if tween then tween:Cancel() end
		sweep:Destroy()
	end
	frame.Destroying:Connect(handle.stop)
	return handle
end
return Shimmer
