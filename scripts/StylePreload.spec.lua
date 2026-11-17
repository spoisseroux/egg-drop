-- Launch candidate (2026-11-17): Deck style art warms in the background after the garden
-- loads, in small low-priority batches, and jumps the queue when Deck style opens. Pure:
-- a fake warm queue and clock; no engine requests.
return function(client)
	local Preload = require(client.StylePreload)
	local Assets = require(client.DeckAssets)
	local Themes = require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
	local Shimmer = require(client.LoadingShimmer)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function fakeQueue()
		local q = { calls = {}, answer = true }
		function q:request(ids, callback, priority)
			table.insert(self.calls, { id = ids[1], priority = priority, callback = callback })
			if self.answer ~= nil then callback(self.answer) end
			return { cancel = function() end }
		end
		return q
	end

	test("the image list covers every faceplate, its finish overlay and the mini deck's shell", function()
		local images = Preload.styleImages()
		local set = {}
		for _, id in ipairs(images) do assert(not set[id], "duplicate " .. id); set[id] = true end
		for id, theme in pairs(Themes.ById) do
			assert(set[Assets.Faceplate[id] or theme.texture], "faceplate " .. id .. " missing")
			if type(theme.overlay) == "table" then assert(set[theme.overlay.image], "overlay of " .. id .. " missing") end
		end
		for _, key in ipairs({ "band", "plateOverlay", "glass", "dpadDisc", "dpadArrows", "buttonBase", "wordmark" }) do
			assert(set[Assets.Image[key]], "shell sprite " .. key .. " missing")
		end
		assert(images[#images] ~= nil and #images <= 64, "a bounded list (" .. #images .. ")")
	end)

	test("background pass: waits for the garden, then every image at priority 0 in batches of " .. Preload.Batch, function()
		local q = fakeQueue()
		local waits, gardenChecks, folders = 0, 0, {}
		local p = Preload.new({ warm = q, images = { "rbxassetid://1", "rbxassetid://2", "rbxassetid://3", "rbxassetid://4" },
			wait = function(t) waits += 1; return t end,
			gardenReady = function() gardenChecks += 1; return gardenChecks >= 3 end,
			preload = function(items) table.insert(folders, items[1]) end,
			folders = { Instance.new("Folder") } })
		p:run()
		assert(gardenChecks >= 3, "it did not wait for the garden")
		assert(#q.calls == 4 and p.done, "every image requested once")
		for _, call in ipairs(q.calls) do assert(call.priority == 0, "background priority") end
		assert(p:isReady("rbxassetid://3") and p:isReady("3"), "ready by either id form")
		assert(#folders == 1, "the 3D preview folders get one preload each")
		p:run(); assert(#q.calls == 4, "a second run does nothing")
	end)

	test("opening Deck style asks again at the tiles' priority, only for what is not warm", function()
		local q = fakeQueue(); q.answer = nil
		local p = Preload.new({ warm = q, images = { "rbxassetid://7", "rbxassetid://8" } })
		p.ready["rbxassetid://7"] = true
		p:warmNow()
		assert(#q.calls == 1 and q.calls[1].id == "rbxassetid://8" and q.calls[1].priority == 1, "just in time, priority 1")
		p:warmNow(); assert(#q.calls == 1, "no duplicate while one is in flight")
		q.calls[1].callback(true); assert(p:isReady("rbxassetid://8"))
	end)

	test("the loading placeholder sweeps, stops once, and stays still under Reduced Motion", function()
		local frame = Instance.new("Frame")
		local moving = Shimmer.attach(frame, false)
		assert(moving.sweep.Parent == frame and moving.sweep.Visible)
		moving.stop(); moving.stop()
		assert(moving.stopped and frame:FindFirstChild("Shimmer") == nil)
		local still = Shimmer.attach(frame, true)
		assert(not still.sweep.Visible, "Reduced Motion: no sweep")
		frame:Destroy(); assert(still.stopped, "destroyed with its frame")
	end)

	return { passed = #cases, cases = cases }
end
