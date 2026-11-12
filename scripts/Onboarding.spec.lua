-- Run in Studio Client with production Client modules and a PlayerGui parent.
-- Presentation fixtures do not alter inventory, rewards, or a live board.
return function(client, parent)
	local Results = require(client.DeckResults)
	local Guide = require(client.FirstHatchGuide)
	local Art = require(client.DeckArt)
	local View = require(client.EggHatchView)
	local Catalog = require(game.ReplicatedStorage.Shared.EggCatalog)
	local Pets = require(game.ReplicatedStorage.Shared.PetCatalog)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.Parent = "_OnboardingSpec", UDim2.fromOffset(360, 236), parent
	root.BackgroundTransparency = 1
	-- The round result renders inside the deck LCD (848x608 authored).
	local resultsHost = Instance.new("Frame")
	resultsHost.Size, resultsHost.BackgroundTransparency, resultsHost.Parent = UDim2.fromOffset(848, 608), 1, root
	local inner = Instance.new("Frame")
	inner.Size, inner.BackgroundTransparency, inner.Parent = UDim2.fromScale(1, 1), 1, resultsHost
	local recap = Results.new(inner, {})
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function result(overrides)
		local value = { outcome = "missed", title = "Bank pair", difficulty = "Medium", total = 6, earned = 6, balance = 12,
			rows = { { name = "Round win", amount = 0 }, { name = "Daily quests", amount = 6 } },
			goals = { { text = "Make III or higher on LEFT", short = "III LEFT", done = false }, { text = "Make III or higher on RIGHT", short = "III RIGHT", done = false } } }
		for key, item in pairs(overrides or {}) do value[key] = item end
		return value
	end
	local ok, problem = pcall(function()
		test("daily-only failed quest remains a failure with committed balance", function()
			recap:show(result(), false)
			assert(recap.eyebrow.Text == "GOALS MISSED" and recap.goalsCount.Text == "0/2")
			assert(recap.rows[2].name.Text == "Daily quests" and recap.rows[2].amount.Text == "+6")
			assert(recap.wallet.amount.Text == "12" and recap.totalAmount.Text == "★ 6")
		end)
		test("right target and overflow explanations use terminal state", function()
			recap:show(result({ goals = { { text = "Left", done = true }, { text = "Right", done = false } } }), false)
			assert(recap.goalsCount.Text == "1/2")
			recap:show(result({ outcome = "overflow" }), false); assert(recap.eyebrow.Text == "OVERFLOW")
			recap:show(result({ outcome = "clear" }), false); assert(recap.eyebrow.Text == "ROUND CLEAR")
		end)
		test("transient save error never displays old balance as a receipt", function()
			recap:show(result({ pending = true }), false)
			assert(recap.totalText.Text == "Saving…" and recap.saved.Text == "Saving…" and recap.totalAmount.Text == "…")
			local replay = require(client.DeckKit).buttonState(recap.replay)
			assert(not replay.enabled and replay.label.Text == "Saving…" and recap.focus == 2, "pending save must disable Replay and focus Leave")
		end)
		test("loss shows no Stars rather than an invented payout", function()
			recap:show(result({ loss = true, total = 0, earned = 0, rows = {} }), false)
			assert(recap.totalText.Text == "0 Stars" and recap.rows[1].name.Text == "No Stars this round")
		end)
		test("compact results keep readable copy and 44 px actions",function()
			resultsHost.Size = UDim2.fromOffset(417, 299)
			recap:show(result(), true); task.wait(.06)
			for _, label in ipairs({ recap.eyebrow, recap.totalText, recap.rows[1].name }) do assert(label.TextSize >= 12) end
			assert(recap.replay.AbsoluteSize.Y >= 44 and recap.leave.AbsoluteSize.Y >= 44)
			resultsHost.Size = UDim2.fromOffset(848, 608)
		end)
		local nodes = {}
		for _, name in ipairs({"rail", "rocker", "drop", "meter", "status"}) do
			local node = Instance.new(if name == "status" then "TextLabel" else "Frame")
			node.Name, node.Size, node.Parent = name, UDim2.fromOffset(140, 38), root
			nodes[name] = node
		end
		-- Match the production compact status role before Guide measures candidate copy.
		Art.type(nodes.status,"Body",true)
		nodes.status.TextWrapped=true
		local guide = Guide.new(nodes.rail, nodes.rocker, nodes.drop, nodes.meter, nodes.status)
		test("shallow welcome coaching preserves each input and semantic phase",function()
			for _,entry in ipairs({{Enum.UserInputType.Keyboard,"Space"},{Enum.UserInputType.Gamepad1,"A"},{Enum.UserInputType.Touch,"Drag"}}) do
				local caption=guide:step(0,0,0,0,entry[1],"I",true,true)
				assert(caption:find(entry[2],1,true) and not caption:find("\n",1,true))
				nodes.status.Text=caption;task.wait(.03);assert(nodes.status.TextFits,caption)
			end
			local match=guide:step(1,0,0,0,Enum.UserInputType.Keyboard,"II",true,true)
			local first,last=match:find("II",1,true);assert(first and match:find("II",last+1,true),match)
			nodes.status.Text=match;task.wait(.03);assert(nodes.status.TextFits,match)
			local hatch=guide:step(2,1,1,0,Enum.UserInputType.Keyboard,"I",true,true)
			assert(hatch=="Merge for "..Pets.byId.pip.name or hatch=="HATCH "..Pets.byId.pip.name:upper())
			nodes.status.Text=hatch;task.wait(.03);assert(nodes.status.TextFits,hatch)
		end)
		test("first field coaching responds to stage, overlays, first win and compact height", function()
			task.wait(.06)
			assert(guide:fieldStep(0, 0, true) and guide.field.heading.Text == "MATCH ON LEFT")
			assert(guide:fieldStep(1, 0, true) and guide.field.heading.Text == "MATCH ON RIGHT")
			assert(guide:fieldStep(2, 0, true) and guide.field.compact.Text == "Both done · keep it low")
			assert(not guide:fieldStep(0, 0, false))
			assert(guide:fieldStep(0, 0, true) and guide.field.host.BackgroundTransparency == 0)
			assert(not guide:fieldStep(0, 1, true))
			nodes.status.Size = UDim2.fromOffset(100, 20); task.wait(.06)
			guide:fieldStep(0, 0, true); task.wait(.06)
			assert(guide.field.compact.Visible and guide.field.compact.TextFits)
		end)
		test("starter reveal receives a copy with the correct egg goal", function()
			root.Size = UDim2.fromOffset(560, 540)
			local view = View.new(root, { play = function() end }, function() return true end, function() end)
			local input = { id = "fixture-pip", petId = "pip", starter = true, family = "pip" }
			view:open({status = "Ready", revision = 1, nectar = 6, lastHatch = input})
			assert(view.cinematic.result.starterGoal:find("6/18", 1, true))
			assert(input.starterGoal == nil, "Presentation mutated committed result")
			view:close()
			view:open({status = "Ready", revision = 2, nectar = 24, lastHatch = input})
			assert(view.cinematic.result.starterGoal:find("ready", 1, true))
			view:close(); view.shade:Destroy()
		end)
	end)
	root:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases }
end
