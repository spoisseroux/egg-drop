-- Native Client fixtures. Callback counters replace remotes and account writes.
return function(client, parent)
	local Menu = require(client.DeckMenu)
	local Mastery = require(game:GetService("ReplicatedStorage").Shared.FamilyMastery)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_MenuPolishSpec", UDim2.fromOffset(568, 390), 1, parent
	local views, cases = {}, {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function snapshot()
		return { status = "Ready", nectar = 24, inventoryMask = 127, dailyAvailable = true, dailyBonus = 6,
			contracts = { { id = "runs", title = "Finish 2 quests", progress = 1, target = 2, reward = 4 },
				{ id = "chain", title = "Chain 3 merges", progress = 3, target = 3, reward = 3, claimed = true },
				{ id = "score", title = "Score 500", progress = 250, target = 500, reward = 3 } },
			mastery = { pip = 60, wick = 25 }, masteryDetails = { pip = Mastery.describe(60, 7), wick = Mastery.describe(25, 5) } }
	end
	local function fixture()
		local calls, callbacks = {}, {}
		for _, key in ipairs({ "close", "eggs", "pets", "style", "play", "daily", "family" }) do
			callbacks[key] = function(value) table.insert(calls, { key, value }) end
		end
		local menu = Menu.new(root, callbacks)
		table.insert(views, menu)
		menu:update(snapshot(), "pip", "wick", 500, 3, 1000, "sprout"); menu:open()
		return menu, calls
	end
	local function resize(menu, width, height)
		root.Size = UDim2.fromOffset(width, height)
		local cardHeight = math.min(620, math.max(135, height - (if height < 280 then 8 else 24)))
		local compact = cardHeight < 300
		local bodyHeight = cardHeight - (if compact then 100 else 120) - 8
		local deadline = os.clock() + 2
		repeat task.wait(.03) until (menu.shade.AbsoluteSize == Vector2.new(width, height)
			and menu.card.AbsoluteSize.Y == cardHeight and menu.body.AbsoluteSize.Y == bodyHeight) or os.clock() >= deadline
		assert(menu.card.AbsoluteSize.Y == cardHeight and menu.body.AbsoluteSize.Y == bodyHeight, "menu layout did not settle")
	end
	local function inside(node, host)
		return node.AbsolutePosition.X >= host.AbsolutePosition.X - .1 and node.AbsolutePosition.Y >= host.AbsolutePosition.Y - .1
			and node.AbsolutePosition.X + node.AbsoluteSize.X <= host.AbsolutePosition.X + host.AbsoluteSize.X + .1
			and node.AbsolutePosition.Y + node.AbsoluteSize.Y <= host.AbsolutePosition.Y + host.AbsoluteSize.Y + .1
	end
	local ok, problem = pcall(function()
		test("header wallet and separate 44px tabs fit compact and portrait screens", function()
			local menu = fixture()
			for _, size in ipairs({ Vector2.new(568, 160), Vector2.new(350, 279), Vector2.new(568, 390), Vector2.new(390, 740) }) do
				resize(menu, size.X, size.Y)
				assert(menu.heading.TextFits and menu.nectar.TextFits and menu.nectar.Text == "24 nectar")
				assert(menu.wallet.NectarDrop.Visible and menu.wallet.AbsolutePosition.X + menu.wallet.AbsoluteSize.X < menu.resumeButton.AbsolutePosition.X)
				assert(menu.closeButton.AbsoluteSize.Y == 44 and menu.closeButton.TextFits)
				for _, tab in pairs(menu.tabs) do
					assert(tab.AbsoluteSize.Y == 44 and tab.TextFits and inside(tab, menu.card))
					assert(menu.body.AbsolutePosition.Y - tab.AbsolutePosition.Y - 44 >= 7.9)
				end
			end
			menu:close()
		end)
		test("play destinations have distinct foreground illustrations and one pinned resume action", function()
			local menu, calls = fixture(); resize(menu, 568, 390); menu:setPage("play")
			assert(#menu.destinations == 3 and menu.resumeButton.Visible and not menu.dailyButton.Visible)
			for _, item in ipairs(menu.destinations) do
				assert(item.art.Visible and #item.art:GetChildren() > 0 and item.title.TextFits and item.subtitle.TextFits)
				assert(item.art.ZIndex > item.button.ZIndex)
				assert(menu:activate(item.kind))
			end
			assert(menu:activate("play") and menu:activate("close"))
			assert(#calls == 5 and calls[1][1] == "eggs" and calls[2][1] == "pets" and calls[3][1] == "style" and calls[4][1] == "play" and calls[5][1] == "close")
			menu:close()
		end)
		test("all contracts and the separate gift remain visible even in 160px landscape", function()
			local menu, calls = fixture(); resize(menu, 568, 160); menu:setPage("daily"); task.wait(.03)
			assert(menu.dailyButton.Visible and not menu.resumeButton.Visible and menu.dailyButton.AbsoluteSize.Y == 44 and inside(menu.dailyButton, menu.card))
			for _, row in ipairs(menu.dailyCards) do
				assert(row.panel.AbsoluteSize.Y >= 44 and inside(row.panel, menu.body))
				assert(row.title.TextFits and row.count.TextFits and row.reward.TextFits)
			end
			assert(menu.dailyCards[1].count.Text == "1/2" and math.abs(menu.dailyCards[1].fill.Size.X.Scale - .5) < .001)
			assert(menu.dailyCards[2].complete and menu.dailyCards[2].fill.Size.X.Scale == 1)
			assert(menu:activate("daily") and #calls == 1 and calls[1][1] == "daily")
			menu:close()
		end)
		test("claimed gift is distinct from earned contract rewards and cannot claim again", function()
			local menu, calls = fixture(); resize(menu, 350, 279); menu:setPage("daily")
			local state = snapshot(); state.dailyAvailable = false
			menu:update(state, "pip", "wick", 0, 0, 0, "meadow"); task.wait(.03)
			assert(menu.dailyButton.Text == "Gift claimed" and not menu.dailyButton.Interactable and not menu:activate("daily") and #calls == 0)
			assert(menu.dailyCards[2].reward.Text == "Earned" and menu.dailyCards[1].reward.Text == "+4 nectar")
			menu:close()
		end)
		test("scroll cues reflect overflow and vanish at the final reachable content", function()
			local menu = fixture(); resize(menu, 568, 160); menu:setPage("daily"); task.wait(.03)
			assert(menu.moreCue.Visible and menu.body.ScrollBarImageTransparency == 0)
			menu.body.CanvasPosition = Vector2.new(0, menu.body.CanvasSize.Y.Offset - menu.body.AbsoluteSize.Y); task.wait(.03)
			assert(not menu.moreCue.Visible and menu.body.ScrollingEnabled)
			resize(menu, 390, 740); menu:setPage("daily"); task.wait(.03)
			assert(not menu.moreCue.Visible and not menu.body.ScrollingEnabled and menu.body.ScrollBarImageTransparency == 1)
			menu:close()
		end)
		test("mastery keeps exact missing win conditions and completed family crests", function()
			local menu = fixture(); resize(menu, 350, 279); menu:setPage("mastery"); task.wait(.03)
			assert(menu.familyHints.wick.Text:find("Win with a chain of 3", 1, true) and not menu.familyHints.wick.Text:find("Clean win", 1, true))
			assert(menu.familyHints.pip.Text:find("Family mastered", 1, true) and menu.families.pip.FamilyCrest:GetAttribute("Rank") == 3)
			assert(menu.familyHints.wick.TextFits and menu.families.wick.FamilyName.TextFits and menu.families.wick.AbsoluteSize.Y == 44)
			menu:close()
		end)
	end)
	for _, menu in ipairs(views) do menu:close(); menu.shade:Destroy() end
	root:Destroy(); assert(ok, problem)
	return { passed = #cases, cases = cases }
end
