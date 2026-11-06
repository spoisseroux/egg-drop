-- Every-frame position and heading; only ground sampling is throttled.
local Players = game:GetService("Players")
local Follow = {}

function Follow.ground(position, visual, fallback)
	local params = RaycastParams.new()
	local exclude = { visual.model }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(exclude, player.Character) end
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y + 0.025 else fallback or 4.025
end

function Follow.step(visual, root, dt, state)
	state = state or {}
	dt = math.clamp(dt, 0, 0.1)
	local desired = root.Position - root.CFrame.LookVector * 3 + root.CFrame.RightVector * 2.6
	state.groundIn = (state.groundIn or 0) - dt
	local far = (visual.origin - desired).Magnitude > 40
	if state.groundIn <= 0 or far then
		state.groundIn = 0.10
		state.groundY = Follow.ground(desired, visual, state.groundY)
	end
	local target = Vector3.new(desired.X, state.groundY or visual.origin.Y, desired.Z)
	local delta = Vector3.new(target.X - visual.origin.X, 0, target.Z - visual.origin.Z)
	local old = visual.origin
	visual.origin = if far then target else old:Lerp(target, 1 - math.exp(-10 * dt))
	local toward = if delta.Magnitude > 0.30 then delta else Vector3.new(root.Position.X - old.X, 0, root.Position.Z - old.Z)
	if toward.Magnitude > 0.05 then
		local wanted = math.atan2(toward.X, toward.Z) -- pet fronts face +Z
		local yaw = visual.yaw or wanted
		local angle = math.atan2(math.sin(wanted - yaw), math.cos(wanted - yaw))
		visual.yaw = yaw + angle * (1 - math.exp(-11 * dt))
	end
	return state
end

return Follow
