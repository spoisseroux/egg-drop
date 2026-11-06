-- Studio Client presentation fixtures. No remotes, live boards, or persistent writes.
return function(client, parent)
	local Recap = require(client.RoundRecap)
	local Menu = require(client.DeckMenu)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Mastery, Catalog, Daily = require(Shared.FamilyMastery), require(Shared.EggCatalog), require(Shared.DailyContracts)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_RewardPresentationSpec", UDim2.fromOffset(360, 236), 1, parent
	local recap = Recap.new(root)
	recap.frame.Visible = true
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function result(changes)
		local value = { success = true, stage = 2, reason = "Completed", status = "Saved", award = 18, daily = 10,
			balance = 20, recipe = Catalog.ById.meadow, selectedFamily = "pip",
			reward = { family = "wick", base = 8, daily = 10, total = 18, masteryPoints = 2, promotedTo = 0,
				contracts = { "runs", "chain", "score" } }, mastery = Mastery.describe(2, 0) }
		for key, item in pairs(changes or {}) do value[key] = item end
		return value
	end
	local function hasLine(fragment)
		for _, line in ipairs(recap.receiptLines or {}) do if line:find(fragment, 1, true) then return true end end
		return false
	end
	local menu
	local ok, problem = pcall(function()
		test("all three contracts use canonical names and component rewards", function()
			recap:updateField(result())
			assert(recap.title.Text:find("Nectar +18", 1, true) and recap.title.Text:find("20/18", 1, true))
			assert(hasLine("Quest nectar +8") and hasLine("Daily contracts total +10"))
			for _, contract in ipairs(Daily.Definitions) do
				assert(hasLine(contract.title .. " · " .. contract.reward .. " nectar"))
			end
			assert(hasLine("Wick mastery +2 marks") and hasLine("Wick next: 1 mark to rank I"))
		end)
		test("daily-only failed quest grants no family marks", function()
			recap:updateField(result({ success = false, stage = 0, award = 6, daily = 6,
				reward = { family = "wick", base = 0, daily = 6, total = 6, masteryPoints = 0, promotedTo = 0, contracts = { "chain", "score" } },
				mastery = Mastery.describe(0, 0) }))
			assert(recap.fieldHeading == "LEFT goal missed" and hasLine("Quest nectar +0"))
			assert(hasLine("No family marks") and not hasLine("mastery +1") and not hasLine("mastery +2"))
		end)
		test("played family owns the next goal even after another family is selected", function()
			recap:updateField(result({ selectedFamily = "pip", mastery = Mastery.describe(25, 5) }))
			assert(hasLine("Wick next: Win with a chain of 3") and not hasLine("Pip next:"))
			assert(hasLine("Win with a chain of 3") and not hasLine("Clean win") and not hasLine("Win with 500 points"))
		end)
		test("committed promotion is announced with its next goal", function()
			local value = result({ mastery = Mastery.describe(10, 0) })
			value.reward.promotedTo = 2
			recap:updateField(value)
			assert(hasLine("Wick rank II unlocked!") and hasLine("15 marks to rank III"))
		end)
		test("overflow after both goals explains survival without asking to redo goals", function()
			local value = result({ success = false, stage = 2, reason = "Overflow" })
			value.reward.masteryPoints = 0
			recap:updateField(value)
			assert(recap.fieldHeading == "Tray overflowed" and hasLine("Both sides done · clear the overflow line"))
			assert(hasLine("finish quest and 24 drops") and not hasLine("win both sides to earn them"))
		end)
		test("loading a matching receipt hides previous balances and promotions", function()
			recap:updateField(result({ receiptPending = true, balance = 987654 }))
			assert(recap.title.Text == "Loading receipt…" and not recap.receiptScroll.Visible)
			assert(not recap.detail.Text:find("987654", 1, true) and #recap.receiptRows == 0 and recap.receiptLines == nil)
		end)
		test("an unresolved save cannot present an old receipt", function()
			recap:updateField(result({ status = "Saving", balance = 987654 }))
			assert(recap.title.Text == "Saving your rewards…" and not recap.receiptScroll.Visible)
			assert(not recap.detail.Text:find("987654", 1, true) and recap.receiptLines == nil)
		end)
		test("compact receipt keeps costs pinned and scrolls complete readable rows", function()
			for _, height in ipairs({ 128, 166, 198, 236 }) do
				root.Size = UDim2.fromOffset(360, height); task.wait(0.06)
				recap:updateField(result({ mastery = Mastery.describe(25, 0) })); task.wait(0.06)
				assert(recap.title.TextFits and recap.title.Text:find("20/18", 1, true), "pinned total/egg cost at " .. height)
				assert(recap.goal.Position.Y.Offset + recap.goal.Size.Y.Offset <= height - 58)
				local scroll = recap.receiptScroll
				assert(scroll.ZIndex > recap.goal.ZIndex and recap.receiptRows[1].ZIndex > scroll.ZIndex, "receipt draws above goal panel")
				assert(scroll.AbsoluteSize.Y >= recap.receiptRowHeight, "whole row viewport at " .. height)
				for _, row in ipairs(recap.receiptRows) do
					assert(row.TextFits and row.AbsoluteSize.Y <= scroll.AbsoluteSize.Y, "readable receipt row at " .. height .. ": " .. row.Text)
				end
				scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.CanvasSize.Y.Offset - scroll.AbsoluteSize.Y)); task.wait(0.06)
				local last = recap.receiptRows[#recap.receiptRows]
				assert(last.AbsolutePosition.Y >= scroll.AbsolutePosition.Y - 1)
				assert(last.AbsolutePosition.Y + last.AbsoluteSize.Y <= scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y + 1,
					"last reward line reachable at " .. height)
			end
		end)
		test("receipt navigation reaches both bounds without moving footer selection", function()
			root.Size = UDim2.fromOffset(360, 166); task.wait(0.06)
			recap:updateField(result({ mastery = Mastery.describe(25, 0) })); task.wait(0.06)
			local GuiService = game:GetService("GuiService")
			local selected = GuiService.SelectedObject
			local iterations = 0
			while recap:scrollReceipt(1) do iterations += 1; assert(iterations < 100) end
			assert(recap.receiptScroll.CanvasPosition.Y == recap.receiptScroll.CanvasSize.Y.Offset - recap.receiptScroll.AbsoluteSize.Y)
			assert(not recap:scrollReceipt(1) and GuiService.SelectedObject == selected)
			while recap:scrollReceipt(-1) do iterations += 1; assert(iterations < 100) end
			assert(recap.receiptScroll.CanvasPosition.Y == 0 and not recap:scrollReceipt(-1))
			recap:updateField(result({ receiptPending = true })); assert(not recap:scrollReceipt(1))
		end)
		test("menu names missing win conditions and clamps completed rank III", function()
			root.Size = UDim2.fromOffset(360, 236)
			local noop = function() end
			menu = Menu.new(root, { close = noop, eggs = noop, pets = noop, style = noop, play = noop, daily = noop, family = noop })
			menu:update({ status = "Ready", inventoryMask = Catalog.mask({ "pip", "wick" }), nectar = 20,
				mastery = { pip = 60, wick = 25 }, masteryDetails = { pip = Mastery.describe(60, 7), wick = Mastery.describe(25, 5) } },
				"pip", "wick", 500, 3, 800, "meadow")
			menu:setPage("mastery"); menu:open(); task.wait(0.08)
			assert(menu.familyHints.wick.Text:find("Win with a chain of 3", 1, true))
			assert(not menu.familyHints.wick.Text:find("Clean win", 1, true) and not menu.familyHints.wick.Text:find("Win with 500 points", 1, true))
			assert(menu.familyHints.pip.Text:find("Family mastered", 1, true) and not menu.familyText.pip.Text:find("60/25", 1, true))
			assert(menu.familyHints.wick.TextFits and menu.familyHints.pip.TextFits)
			assert(menu.closeButton.AbsoluteSize.Y == 44 and menu.closeButton.TextFits)
		end)
	end)
	if menu then menu:close(); menu.shade:Destroy() end
	root:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases }
end
