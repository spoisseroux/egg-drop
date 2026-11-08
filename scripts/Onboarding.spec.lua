-- Run in Studio Client with production Client modules and a PlayerGui parent.
-- Presentation fixtures do not alter inventory, rewards, or a live board.
return function(client, parent)
	local Recap = require(client.RoundRecap)
	local Guide = require(client.FirstHatchGuide)
	local Art = require(client.DeckArt)
	local View = require(client.EggHatchView)
	local Catalog = require(game.ReplicatedStorage.Shared.EggCatalog)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.Parent = "_OnboardingSpec", UDim2.fromOffset(360, 236), parent
	root.BackgroundTransparency = 1
	local recap = Recap.new(root)
	recap.frame.Visible = true
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function result(overrides)
		local value = { success = false, reason = "Root patches incomplete", stage = 0, status = "Saved",
			award = 6, daily = 6, balance = 12, recipe = Catalog.ById.meadow }
		for key, item in pairs(overrides or {}) do value[key] = item end
		return value
	end
	local ok, problem = pcall(function()
		test("daily-only failed quest remains a failure with committed balance", function()
			recap:updateField(result())
			assert(recap.fieldHeading == "0 of 2 goals")
			assert(recap.title.Text:find("quest 0", 1, true) and recap.title.Text:find("daily 6", 1, true))
			assert(recap.detail.Text:find("12/18", 1, true) and recap.detail.Text:find("need 6", 1, true))
		end)
		test("right target and overflow explanations use terminal state", function()
			recap:updateField(result({ stage = 1 })); assert(recap.fieldHeading == "1 of 2 goals")
			recap:updateField(result({ stage = 2, reason = "Overflow" })); assert(recap.fieldHeading == "Overflow")
		end)
		test("transient save error never displays old balance as a receipt", function()
			recap:updateField(result({ status = "Saving" })); assert(recap.title.Text == "Saving your rewards…")
			recap:updateField(result({ status = "Saving is delayed. Your result will stay the same when retried." }))
			assert(recap.title.Text:find("retrying", 1, true) and not recap.detail.Text:find("12/18", 1, true))
		end)
		test("selected recipe uses saved balance without adding the payout twice", function()
			recap:updateField(result({ success = true, stage = 2, award = 8, daily = 0, balance = 23, recipe = Catalog.ById.sprout }))
			assert(recap.fieldHeading == "Round complete" and recap.detail.Text:find("23/24", 1, true))
			recap:updateField(result({ balance = 24, recipe = Catalog.ById.sprout })); assert(recap.detail.Text:find("ready to hatch", 1, true))
		end)
		test("compact pending recap keeps readable status out of pinned footer",function()
			for _,height in ipairs({128,166,198,236}) do
				root.Size=UDim2.fromOffset(360,height);task.wait(.06)
				recap:update(630,3,0,nil,0,nil,0,700);recap:updateField(result());task.wait(.06)
				assert(recap.title.TextFits and recap.detail.TextFits)
				assert(recap.fieldBody.Position.Y.Offset+recap.fieldBody.Size.Y.Offset<=height-60)
				assert(not recap.title.TextScaled and recap.title.TextSize>=14)
			end
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
			assert(guide:step(2,1,1,0,Enum.UserInputType.Keyboard,"I",true,true)=="Merge for Pip")
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
