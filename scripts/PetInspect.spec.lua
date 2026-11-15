-- QA v685 R6: the visitor pet profile card (src/client/PetInspect.lua) and the hello pose.
-- Pure parts only (rows, button state, geometry, wave curve, board record); the card with
-- two real accounts is a manual check.
-- Run (Client): require(game.Players.LocalPlayer.PlayerScripts.Client.ZZSpecs.PetInspect)(game.Players.LocalPlayer.PlayerScripts.Client)
return function(client)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Inspect = require(client.PetInspect)
	local Pose = require(client.PetHelloPose)
	local Rules = require(Shared.PetHelloRules)
	local Wearables = require(Shared.WearableCatalog)
	local UICopy = require(Shared.UICopy)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end

	test("the card lists every wearable slot, then charm, finish and toy", function()
		local rows = Inspect.rows("bear", nil)
		assert(#rows == #Wearables.Tabs + 3)
		for index, tab in ipairs(Wearables.Tabs) do
			assert(rows[index].key == tab.id and rows[index].label == tab.label and rows[index].empty and rows[index].value == UICopy.get("inspect.empty"))
		end
		assert(rows[#rows - 2].key == "charm" and rows[#rows - 2].empty and rows[#rows - 2].value == UICopy.get("inspect.hidden"))
		assert(rows[#rows - 1].key == "finish" and rows[#rows - 1].value == "Standard")
		assert(rows[#rows].key == "toy" and rows[#rows].empty)
		-- A dressed pet: the first item the Bear sells shows by name in its slot.
		local item = Wearables.forPet("bear").order[1]
		assert(item, "the Bear sells no wearables")
		local worn = {}
		worn[item.keys[1]] = item.id
		rows = Inspect.rows("bear", { wearables = worn, charmVisible = true, charmShape = "heart", finish = "gloss", toyId = "ball" })
		local seen = false
		for index = 1, #Wearables.Tabs do
			if rows[index].value == item.name and not rows[index].empty then seen = true end
		end
		assert(seen, "worn item missing")
		assert(rows[#rows - 2].value == "Heart" and not rows[#rows - 2].empty)
		assert(rows[#rows - 1].value == "Gloss" and rows[#rows].value == "Ball" and not rows[#rows].empty)
		-- Unknown ids fall back, never error.
		rows = Inspect.rows("bear", { wearables = { Hat = "no_such_hat" }, finish = "nope", toyId = "nope", charmShape = 5, charmVisible = true })
		assert(rows[1].empty and rows[#rows - 1].value == "Standard" and rows[#rows].empty and rows[#rows - 2].value == "Snowflake")
	end)

	test("Say hello: off, sent, cooling, far, busy, ready (in that order)", function()
		local key, ready = Inspect.helloState({ off = true, sent = true, cooling = true, distance = 1, free = true })
		assert(key == "inspect.off" and not ready)
		key, ready = Inspect.helloState({ sent = true, cooling = true, distance = 1, free = true }); assert(key == "inspect.sent" and not ready)
		key, ready = Inspect.helloState({ cooling = true, distance = 1, free = true }); assert(key == "inspect.wait" and not ready)
		key, ready = Inspect.helloState({ distance = Rules.HelloRange + .01, free = true }); assert(key == "inspect.closer" and not ready)
		key, ready = Inspect.helloState({ free = true }); assert(key == "inspect.closer" and not ready)
		key, ready = Inspect.helloState({ distance = 2, free = false }); assert(key == "inspect.busy" and not ready)
		key, ready = Inspect.helloState({ distance = Rules.HelloRange, free = true }); assert(key == "inspect.hello" and ready)
		for _, name in ipairs({ "off", "sent", "wait", "closer", "busy", "hello", "prompt", "gone", "close", "spin", "owner", "bond", "setting.on", "setting.off" }) do
			assert(UICopy.has("inspect." .. name), "UICopy inspect." .. name)
		end
	end)

	test("the card fits a phone and a desktop screen", function()
		for _, screen in ipairs({ { 812, 354 }, { 844, 390 }, { 1280, 720 }, { 1920, 1080 } }) do
			local g = Inspect.geometry(screen[1], screen[2])
			assert(g.compact == (screen[2] < 500))
			assert(g.W <= screen[1] - 24 and g.H <= screen[2] - 58 - 12, ("card %dx%d on %dx%d"):format(g.W, g.H, screen[1], screen[2]))
			assert(g.rightW >= 3 * 76, "slot cells narrower than 76 px")
			assert(g.rowH >= 30 and g.button >= 38 and g.preview >= 150)
			assert(g.rows * Inspect.Columns >= #Wearables.Tabs + 3)
		end
	end)

	test("the wave: a glance in and out with two sweeps; Reduced Motion one small raise", function()
		assert(select(1, Pose.curve(-1)) == 0 and select(1, Pose.curve(Rules.Duration)) == 0)
		local peaks, last, rising = 0, 0, false
		for step = 0, 130 do
			local age = step / 100
			local glance, hand = Pose.curve(age, false)
			assert(glance >= 0 and glance <= 1 and hand >= 0 and hand <= 1.9)
			if age < Rules.GlanceIn or age > Rules.GlanceIn + Rules.Wave then assert(hand == 0) end
			if hand > last then rising = true elseif hand < last and rising then peaks += 1; rising = false end
			last = hand
		end
		assert(peaks == 2, "expected two waves, saw " .. peaks)
		assert(select(1, Pose.curve(Rules.Duration * .5, false)) == 1)
		local calm = 0
		for step = 0, 130 do
			local _, hand = Pose.curve(step / 100, true)
			calm = math.max(calm, hand)
		end
		assert(calm > .5 and calm <= .7)
	end)

	test("a board's hello record is read only for the pet it names", function()
		local board = Instance.new("Folder")
		board:SetAttribute("CompanionId", "bear"); board:SetAttribute("CompanionGeneration", 4)
		assert(Pose.read(board) == nil and Pose.read(nil) == nil)
		board:SetAttribute(Rules.Attribute, game:GetService("HttpService"):JSONEncode({ id = 1, from = 5, at = 10, petId = "bear", petGeneration = 4 }))
		local hello = Pose.read(board)
		assert(hello and hello.from == 5 and hello.at == 10 and Pose.read(board) == hello)
		board:SetAttribute("CompanionGeneration", 5); assert(Pose.read(board) == nil)
		board:SetAttribute("CompanionGeneration", 4); board:SetAttribute("CompanionId", "pip"); assert(Pose.read(board) == nil)
		board:SetAttribute("CompanionId", "bear"); board:SetAttribute(Rules.Attribute, "not json"); assert(Pose.read(board) == nil)
		board:SetAttribute(Rules.Attribute, "{\"id\":1}"); assert(Pose.read(board) == nil)
		board:SetAttribute(Rules.Attribute, nil); assert(Pose.read(board) == nil)
		-- The pose: toward the greeter, never while the owner has the pet.
		local visual = { origin = Vector3.zero, yaw = 0, hello = { at = 0, from = 0 }, helloTarget = Vector3.new(5, 0, 5) }
		local yaw, hand, expression = Pose.sample(visual, Rules.Duration * .5, false)
		assert(math.abs(yaw - math.rad(45)) < 1e-3 and hand > 0 and expression == "pleased")
		yaw, hand, expression = Pose.sample(visual, Rules.Duration * .5, true)
		assert(yaw == 0 and hand == 0 and expression == nil)
		visual.helloTarget = Vector3.new(0, 0, -5)
		yaw = Pose.sample(visual, Rules.Duration * .5, false)
		assert(math.abs(math.abs(yaw) - Pose.MaxYaw) < 1e-3, "the glance is clamped")
		board:Destroy()
	end)

	return cases
end
