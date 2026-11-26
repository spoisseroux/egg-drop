-- Beta 35 (Spencer 2026-11-26): the world heard from the player's head, facing the camera's yaw; the camera's own
-- listener for shots (Scriptable, Fixed), no character, death, a camera far off, or the gate off. Pure checks only.
return function(client)
	local Listener = require(client.AudioListener)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
	local function nearV(a, b, eps) return (a - b).Magnitude <= (eps or 1e-6) end

	test("the head while the player's own camera follows them; the camera for every shot and every missing piece", function()
		local head, behind = Vector3.new(10, 5, 0), Vector3.new(10, 12, 14)
		local function state(over)
			local s = { on = true, cameraType = "Custom", head = head, alive = true, camera = behind }
			for k, v in pairs(over or {}) do s[k] = v end
			return s
		end
		assert(Listener.choose(state()) == "head")
		for _, kind in ipairs({ "Follow", "Track", "Attach" }) do assert(Listener.choose(state({ cameraType = kind })) == "head", kind) end
		-- The Pocket Deck's parked lens, the egg machine's shot, a pet focus and the Dash race are all Scriptable.
		local checks = {
			{ { cameraType = "Scriptable" }, "shot" }, { { cameraType = "Fixed" }, "shot" }, { { cameraType = "Watch" }, "shot" },
			{ { on = false }, "off" }, { { alive = false }, "dead" }, { { camera = head + Vector3.new(0, 0, Listener.Spec.far + 1) }, "far" },
		}
		for _, row in ipairs(checks) do
			local where, why = Listener.choose(state(row[1]))
			assert(where == "camera" and why == row[2], tostring(why) .. " vs " .. row[2])
		end
		local noHead = state();noHead.head = nil
		assert(select(2, Listener.choose(noHead)) == "no character")
		assert(Listener.choose(nil) == "camera" and Listener.choose({}) == "camera")
		-- The garden camera's own reach (WorldFeel caps zoom at 22) never counts as far.
		assert(Listener.choose(state({ camera = head + Vector3.new(0, 10, 22) })) == "head")
		assert(Listener.choose(state({ alive = nil })) == "head", "no Humanoid read is alive")
	end)

	test("a switch is eased over `ease` seconds both ways, and a frame hitch never jumps it", function()
		local w, t = 1, 0
		while w > 0 do w = Listener.toward(w, 0, 1 / 60); t += 1 / 60 end
		assert(near(t, Listener.Spec.ease, 1 / 60 + 1e-9), "to the head in " .. t)
		w, t = 0, 0
		while w < 1 do w = Listener.toward(w, 1, 1 / 60); t += 1 / 60 end
		assert(near(t, Listener.Spec.ease, 1 / 60 + 1e-9), "to the camera in " .. t)
		assert(near(Listener.toward(0, 1, 10), .25 / Listener.Spec.ease), "a 10 s hitch counts as .25 s")
		assert(Listener.toward(0 / 0, 0, 0) == 1, "a broken weight starts at the camera")
		assert(Listener.toward(.5, .5, 1 / 60) == .5)
	end)

	test("at the head: level, the camera's yaw; at the camera: its own look; in between, blended", function()
		local head, cam = Vector3.new(0, 5, 0), Vector3.new(0, 15, 15)
		local look = (head - cam).Unit -- looking down at the avatar from behind and above
		local up = Vector3.new(0, 1, 0):Cross(look):Cross(look) * -1
		local at, facing = Listener.place(head, cam, look, up, 0, 0)
		assert(nearV(at, head) and nearV(facing, Vector3.new(0, 0, -1)), "head, facing the camera's yaw, level")
		at, facing = Listener.place(head, cam, look, up, 1, 0)
		assert(nearV(at, cam) and nearV(facing, look), "the camera itself")
		at, facing = Listener.place(head, cam, look, up, .5, 0)
		assert(nearV(at, Vector3.new(0, 10, 7.5)) and near(facing.Magnitude, 1) and facing.Y < 0 and facing.Y > look.Y, "half way")
		-- Lean: studs toward the camera, never past it.
		at = Listener.place(head, cam, look, up, 0, 2)
		assert(near((at - head).Magnitude, 2) and nearV((at - head).Unit, (cam - head).Unit))
		at = Listener.place(head, head + Vector3.new(0, 0, 1), look, up, 0, 5)
		assert(nearV(at, head + Vector3.new(0, 0, 1)))
		-- Straight down: the camera's up gives the yaw (the top of the screen is "ahead"). Nothing at all: -Z.
		local down = Listener.flatLook(Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
		assert(nearV(down, Vector3.new(1, 0, 0)))
		assert(nearV(Listener.flatLook(Vector3.new(0, -1, 0), Vector3.new(0, 0, 0)), Vector3.new(0, 0, -1)))
		-- Panning matches the screen: the listener's right is the camera's right, whichever way the avatar faces.
		local camRight = look:Cross(Vector3.new(0, 1, 0)).Unit
		local _, f = Listener.place(head, cam, look, up, 0, 0)
		assert(nearV(f:Cross(Vector3.new(0, 1, 0)).Unit, camRight), "left and right follow the camera")
	end)

	return { passed = #cases, cases = cases }
end
