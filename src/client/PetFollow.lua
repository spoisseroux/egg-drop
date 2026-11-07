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

function Follow.rest(visual)
	visual.gaitPhase,visual.gaitWeight=0,0
end

function Follow.step(visual, root, dt, state, reduced)
	state = state or {}
	local changedRoot=state.root~=root
	state.root=root
	if changedRoot then state.groundIn,state.groundY=0,nil end
	visual.reducedEffects=reduced==true
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
	local traveled=Vector3.new(visual.origin.X-old.X,0,visual.origin.Z-old.Z).Magnitude
	if changedRoot or far or reduced then
		Follow.rest(visual);state.travelSpeed=0
	else
		local speed=if dt>0 then traveled/dt else 0
		state.travelSpeed=(state.travelSpeed or 0)+(speed-(state.travelSpeed or 0))*(1-math.exp(-12*dt))
		local weight=math.clamp((state.travelSpeed-.025)/3.5,0,1)
		visual.gaitWeight=if weight<.002 then 0 else weight
		if visual.gaitWeight==0 then visual.gaitPhase=0
		else
			-- Distance drives slow steps; fast following never aliases into a tremor.
			local cycles=math.min(traveled/(1.45*(visual.worldScale or 1)),dt*3.5)
			visual.gaitPhase=((visual.gaitPhase or 0)+cycles*math.pi*2)%(math.pi*2)
		end
	end
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
