-- Hear the world from the player, not the camera (Spencer, beta 35, 2026-11-26: "can its sound be based on the player
-- location not the camera's?"). Roblox hears every 3D Sound from the camera by default, and the garden's third-person
-- camera sits 10 to 22 studs behind and above the avatar, so a fountain or a waterfall you walk right up to was still
-- heard from 15+ studs away (and its rolloff was tuned around that).
--
-- The listener (SoundService:SetListener, ListenerType.CFrame) is put at the avatar's head, turned to the CAMERA's yaw:
-- distance is measured from the player, but left and right still match the screen (turned to the head's own facing, a
-- sound on screen-left would pan right whenever the avatar walks toward the camera). Pitch is left level.
--
-- Back to the camera's own listener (ListenerType.Camera) when the view is not the player's: no character or no head
-- (spawning, deck reloads), dead, the camera Scriptable or Fixed (the Pocket Deck's parked lens, the egg machine's shot,
-- a pet's focus shot, the Garden Dash race with the avatar hidden at the gate), or the camera more than `far` studs from
-- the head. Every switch is eased over `ease` seconds (position and facing blended), never a jump; fully on the camera
-- it is the engine's own Camera listener again, so cinematics sound exactly as they did.
--
-- Side effects, on every 3D Sound in the place (pets' chimes, crunchy toys, Bumble balls, the Wobble Egg, birds,
-- crickets, the avatar's own Roblox footsteps and jumps): they are heard from the head, so what the player is next to
-- is louder than before (typically 3 to 8 dB for things within reach; most of those have a min distance of 6 to 8,
-- inside which nothing changes) and what is behind the avatar but in front of the camera is a little quieter. 2D sounds
-- (UI, music, the deck, the coos and the brook bed, all parented to SoundService) are not affected at all.
--
-- Gated with the beta's water mix (AmbientAudio's quiet gate: Aero.on(), the beta place or Studio): off, the listener
-- is never touched and the live game hears from the camera as before. One owner: AmbientAudio.new (auto) starts it,
-- destroy gives the listener back to the camera.
local Listener = {}
Listener.Name = "EggDropListener"
--   far     camera further than this from the head (studs): the camera's own listener (WorldFeel caps zoom at 22)
--   ease    seconds for a whole head <-> camera switch
--   lean    studs from the head toward the camera (0: at the head; a knob if the avatar's own footsteps are too loud)
--   sample  seconds between reads of the gate
Listener.Spec = table.freeze({ far = 45, ease = .35, lean = 0, sample = .25 })
-- Camera types that follow the avatar. Anything else (Scriptable, Fixed, Watch, Orbital) is a shot: the camera hears.
Listener.Following = table.freeze({ Custom = true, Follow = true, Track = true, Attach = true })

-- Pure. state: {on, cameraType (its Name), head (Vector3 or nil), alive (false only when dead), camera (Vector3)}.
-- Returns "head" or "camera", and why.
function Listener.choose(state)
	if type(state) ~= "table" or state.on ~= true then return "camera", "off" end
	if not Listener.Following[state.cameraType] then return "camera", "shot" end
	if typeof(state.head) ~= "Vector3" then return "camera", "no character" end
	if state.alive == false then return "camera", "dead" end
	if typeof(state.camera) ~= "Vector3" then return "camera", "no camera" end
	local away = (state.camera - state.head).Magnitude
	if away ~= away or away > Listener.Spec.far then return "camera", "far" end
	return "head", "player"
end

-- Pure. The blend weight (0 at the head, 1 at the camera) one step toward `goal`, a whole switch in `ease` seconds.
function Listener.toward(weight, goal, dt)
	if type(weight) ~= "number" or weight ~= weight then weight = 1 end
	dt = math.clamp(if type(dt) == "number" and dt == dt then dt else 0, 0, .25)
	local most = dt / Listener.Spec.ease
	return math.clamp(weight + math.clamp(goal - weight, -most, most), 0, 1)
end

-- Pure. The level facing of a camera: its look with the height taken out; looking straight down, its up (which points
-- up the screen); never zero.
function Listener.flatLook(look, up)
	for _, v in ipairs({ look, up }) do
		if typeof(v) == "Vector3" then
			local flat = Vector3.new(v.X, 0, v.Z)
			if flat.Magnitude > .05 then return flat.Unit end
		end
	end
	return Vector3.new(0, 0, -1)
end

-- Pure. Where the listener is and which way it faces, `weight` of the way from the head (level, the camera's yaw) to
-- the camera (its own look). lean: studs from the head toward the camera (never past it).
function Listener.place(head, cameraAt, look, up, weight, lean)
	weight = math.clamp(weight or 0, 0, 1)
	local from = head
	local toCamera = cameraAt - head
	local away = toCamera.Magnitude
	if (lean or 0) > 0 and away > 1e-6 then from = head + toCamera.Unit * math.min(lean, away) end
	local at = from + (cameraAt - from) * weight
	local flat = Listener.flatLook(look, up)
	local facing = flat * (1 - weight) + (if typeof(look) == "Vector3" and look.Magnitude > 1e-6 then look.Unit else flat) * weight
	if facing.Magnitude < 1e-6 then facing = flat end
	return at, facing.Unit
end

-- Runtime. options: {on = function -> boolean (the gate)}. Returns {stop = function}; stop gives the listener back to
-- the camera. A throw inside the step stops it (said once) and gives the camera back: never a stuck listener.
function Listener.start(options)
	options = options or {}
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local SoundService = game:GetService("SoundService")
	local on = options.on or function() return false end
	local warnOnce = options.warn or warn
	local state = { weight = 1, kind = "Camera", clock = math.huge, gate = false, stopped = false }
	local function toCamera()
		if state.kind ~= "Camera" then
			state.kind = "Camera"
			pcall(function() SoundService:SetListener(Enum.ListenerType.Camera) end)
		end
	end
	local function step(dt)
		state.clock += dt
		if state.clock >= Listener.Spec.sample then
			state.clock = 0
			local ok, value = pcall(on)
			state.gate = ok and value == true
		end
		local camera = workspace.CurrentCamera
		if not camera then toCamera();return end
		local frame = camera.CFrame
		local player = Players.LocalPlayer
		local character = player and player.Character
		local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local headAt = if head and head:IsA("BasePart") then head.Position else nil
		local goal = Listener.choose({ on = state.gate, cameraType = camera.CameraType.Name, head = headAt,
			alive = not humanoid or humanoid.Health > 0, camera = frame.Position })
		-- A head that vanished mid-blend: the camera at once (nothing to blend from).
		if not headAt then state.weight = 1 end
		state.weight = Listener.toward(state.weight, if goal == "camera" then 1 else 0, dt)
		if state.weight >= 1 then toCamera();return end
		local at, facing = Listener.place(headAt, frame.Position, frame.LookVector, frame.UpVector, state.weight, Listener.Spec.lean)
		SoundService:SetListener(Enum.ListenerType.CFrame, CFrame.lookAt(at, at + facing))
		state.kind = "CFrame"
	end
	-- After the camera has moved this frame, so the listener never lags it by one.
	RunService:BindToRenderStep(Listener.Name, Enum.RenderPriority.Camera.Value + 1, function(dt)
		if state.stopped then return end
		local ok, problem = pcall(step, dt)
		if not ok then
			state.stopped = true
			warnOnce("[Listener] " .. tostring(problem) .. " (back to the camera)")
			pcall(function() RunService:UnbindFromRenderStep(Listener.Name) end)
			state.kind = "CFrame"
			toCamera()
		end
	end)
	return {
		state = state,
		stop = function()
			if state.stopped then return end
			state.stopped = true
			pcall(function() RunService:UnbindFromRenderStep(Listener.Name) end)
			state.kind = "CFrame"
			toCamera()
		end,
	}
end

return Listener
