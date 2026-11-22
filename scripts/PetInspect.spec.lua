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
		local rows = Inspect.rows("pip", nil)
		assert(#rows == #Wearables.Tabs + 3)
		for index, tab in ipairs(Wearables.Tabs) do
			assert(rows[index].key == tab.id and rows[index].label == tab.label and rows[index].empty and rows[index].value == UICopy.get("inspect.empty"))
		end
		assert(rows[#rows - 2].key == "charm" and rows[#rows - 2].empty and rows[#rows - 2].value == UICopy.get("inspect.hidden"))
		assert(rows[#rows - 1].key == "finish" and rows[#rows - 1].value == "Standard")
		assert(rows[#rows].key == "toy" and rows[#rows].empty)
		-- A dressed pet: the first item the Bear sells shows by name in its slot.
		local item = Wearables.forPet("pip").order[1]
		assert(item, "the Bear sells no wearables")
		local worn = {}
		worn[item.keys[1]] = item.id
		rows = Inspect.rows("pip", { wearables = worn, charmVisible = true, charmShape = "heart", finish = "gloss", toyId = "ball" })
		local seen = false
		for index = 1, #Wearables.Tabs do
			if rows[index].value == item.name and not rows[index].empty then seen = true end
		end
		assert(seen, "worn item missing")
		assert(rows[#rows - 2].value == "Heart" and not rows[#rows - 2].empty)
		assert(rows[#rows - 1].value == "Gloss" and rows[#rows].value == "Ball" and not rows[#rows].empty)
		-- Unknown ids fall back, never error.
		rows = Inspect.rows("pip", { wearables = { Hat = "no_such_hat" }, finish = "nope", toyId = "nope", charmShape = 5, charmVisible = true })
		assert(rows[1].empty and rows[#rows - 1].value == "Standard" and rows[#rows].empty and rows[#rows - 2].value == "Snowflake")
	end)

	test("Levels matter: a gated item still worn keeps its name while gates are off", function()
		local Levels = require(Shared.Levels)
		for _, on in ipairs({ true, false }) do
			Levels.inject({ flags = { LevelsMatter = on }, studio = true, shipped = { gates = true } })
			local rows = Inspect.rows("pip", { wearables = { Hat = "beanie_lime" } })
			Levels.inject(nil)
			assert(rows[1].value == "Lime Pom Beanie" and not rows[1].empty)
		end
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
			-- v2 S4: phone Outfit rows are 26 px (they share the body with the Stats tab).
			assert(g.rowH >= (if g.compact then 26 else 30) and g.button >= 38 and g.preview >= 150)
			assert(g.rows * Inspect.Columns >= #Wearables.Tabs + 3)
			assert(g.gridH <= g.bodyH and g.statsH <= g.bodyH and g.tileH >= 44, "a tab overflows the body")
			assert(g.compareW < g.rightW / 2, "Compare crowds Say hello")
		end
	end)

	test("v2 S4: the Stats tab reads levels only, clamped, and localises the words", function()
		local Http = game:GetService("HttpService")
		local Catalog = require(Shared.StatCatalog)
		assert(Inspect.statsModel(nil, "pip") == nil and Inspect.statsModel("not json", "pip") == nil)
		assert(Inspect.statsModel("{\"pets\":{}}", "pip") == nil and Inspect.statsModel("{\"pets\":{\"pip\":{}}}", "pip") == nil)
		local raw = Http:JSONEncode({ v = 1, pets = { pip = { levels = { heart = 52, power = 29, energy = 31, jump = 44, speed = 18, smarts = 27 }, total = 201, keeper = "Bloom Keeper" } } })
		local m = Inspect.statsModel(raw, "pip")
		assert(m and #m.stats == 6 and m.total == 201)
		for index, id in ipairs(Catalog.Order) do assert(m.stats[index].id == id) end
		assert(m.stats[1].tier == UICopy.get("stats.tier.bloom") and m.stats[5].tier == "", "tier word from 25 up")
		assert(m.keeper == UICopy.get("stats.keeper", { name = UICopy.get("stats.tier.bloom") }))
		-- Malformed values never show past the catalogue; the total is re-added, never trusted.
		raw = Http:JSONEncode({ pets = { pip = { levels = { heart = 500, power = -3, energy = "x", jump = 12.7 }, total = 9999 } } })
		m = Inspect.statsModel(raw, "pip")
		assert(m.stats[1].level == 99 and m.stats[2].level == 1 and m.stats[3].level == 1 and m.stats[4].level == 12 and m.total == 99 + 1 + 1 + 12 + 1 + 1)
		assert(Inspect.statsModel(raw, "other") == nil)
		for _, name in ipairs({ "tab.stats", "tab.outfit", "compare", "you", "statsPrivate", "statsNone" }) do
			assert(UICopy.has("inspect." .. name), "UICopy inspect." .. name)
		end
		assert(UICopy.get("inspect.you", { count = 41 }) == "You 41")
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

	test("v859: Say hello does not flicker with the pet's busy/free steps", function()
		local memo = {}
		assert(Inspect.stableFree(memo, true, 0) == true)
		assert(Inspect.stableFree(memo, false, .1) == true, "one busy step flips the button")
		assert(Inspect.stableFree(memo, true, .3) == true and memo.since == nil)
		assert(Inspect.stableFree(memo, false, 1) == true)
		assert(Inspect.stableFree(memo, false, 1 + Inspect.FreeHold - .01) == true)
		assert(Inspect.stableFree(memo, false, 1 + Inspect.FreeHold) == false, "a held change lands")
		assert(Inspect.stableFree(memo, true, 3) == false and Inspect.stableFree(memo, true, 3 + Inspect.FreeHold) == true)
	end)

	test("v859: Drag to turn keeps a fixed orbit on the spin axis", function()
		local viewport = Instance.new("ViewportFrame"); viewport.Size = UDim2.fromOffset(156, 300)
		local lens = Instance.new("Camera"); lens.FieldOfView = 30
		local visual = { rigRevision = 1, rigBoundsFrame = CFrame.new(.09, 1.03, 0), rigBoundsSize = Vector3.new(1.37, 2.06, 1.34) }
		local probe = setmetatable({ spin = 0, card = { visual = visual, lens = lens, viewport = viewport } }, { __index = Inspect })
		probe:fitCamera()
		local first = lens.CFrame
		assert(math.abs(first.X) < 1e-6, "camera off the spin axis")
		-- Turned 45 degrees with an arm up: the box widens to 1.85 and rises a little.
		probe.spin = math.rad(45); visual.rigBoundsSize = Vector3.new(1.85, 2.2, 1.85); visual.rigBoundsFrame = CFrame.new(.03, 1.1, .03)
		probe:fitCamera()
		assert((lens.CFrame.Position - first.Position).Magnitude < 1e-6, "the orbit moved while turning")
		-- A new rig (appearance) at a turned angle never zooms out from the turn alone.
		visual.rigRevision = 2; probe:fitCamera()
		assert(lens.CFrame.Z <= first.Z * 1.08 + 1e-3, ("orbit zoomed out %.2f -> %.2f"):format(first.Z, lens.CFrame.Z))
		viewport:Destroy(); lens:Destroy()
	end)

	return cases
end
