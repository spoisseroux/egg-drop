-- Native Client layout fixtures only; no remotes, purchases or inventory grants.
return function(client, parent)
	local View = require(client.EggHatchView)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_CompactEggShopSpec", UDim2.fromOffset(568, 160), 1, parent
	local cases, views = {}, {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function resize(width, height, view)
		root.Size = UDim2.fromOffset(width, height)
		local expectedCompact = view and view.state.lastHatch == nil and height < 280
		local margin = if expectedCompact or (view and view.state.lastHatch and height < 200) then 16 else 32
		local cardHeight = math.clamp(height - margin, 1, 580)
		local deadline = os.clock() + 2
		local function arrived()
			if root.AbsoluteSize ~= Vector2.new(width, height) then return false end
			if not view then return true end
			return view.shade.AbsoluteSize == Vector2.new(width, height) and view.compactShop == expectedCompact
				and view.card.AbsoluteSize.Y == cardHeight and (view.state.lastHatch~=nil or view.body.AbsoluteSize.Y == cardHeight-view.body.Position.Y.Offset-(view.footerHeight or 44)-(if expectedCompact then 8 else 18))
		end
		repeat task.wait(0.03) until arrived() or os.clock() >= deadline
		assert(root.AbsoluteSize == Vector2.new(width, height), "fixture size did not settle: " .. tostring(root.AbsoluteSize))
		if view then
			assert(view.shade.AbsoluteSize == Vector2.new(width, height), "shop surface size: " .. tostring(view.shade.AbsoluteSize))
			assert(view.compactShop == expectedCompact, "shop compact mode: " .. tostring(view.compactShop) .. ", expected " .. tostring(expectedCompact))
			assert(view.card.AbsoluteSize.Y == cardHeight, "shop card height: " .. view.card.AbsoluteSize.Y)
			if not view.state.lastHatch then assert(view.body.AbsoluteSize.Y == cardHeight-view.body.Position.Y.Offset-(view.footerHeight or 44)-(if expectedCompact then 8 else 18), "shop body excludes measured header/footer: " .. view.body.AbsoluteSize.Y) end
		end
	end
	local function snapshot(nectar, result)
		return { status = "Ready", revision = 10, nectar = nectar or 18, lastHatch = result,
			dailyAvailable = true, dailyDay = "20000", dailyBonus = 6, misses = 3 }
	end
	local function fixture()
		local sent = {}
		local view = View.new(root, { play = function() end }, function() return true end, function(command, value)
			table.insert(sent, { command, value })
		end)
		table.insert(views, view)
		view:open(snapshot())
		return view, sent
	end
	local function fullyVisible(node, scroll)
		return node.AbsolutePosition.Y >= scroll.AbsolutePosition.Y - 0.1
			and node.AbsolutePosition.Y + node.AbsoluteSize.Y <= scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y + 0.1
	end
	local function scrollTo(view, node)
		local scroll = view.body
		local contentY = node.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
		local maximum = math.max(0, scroll.CanvasSize.Y.Offset - scroll.AbsoluteSize.Y)
		scroll.CanvasPosition = Vector2.new(0, math.clamp(contentY, 0, maximum))
		task.wait(0.04)
		assert(fullyVisible(node, scroll), "complete scroll target: " .. node.Name)
	end
	local ok, problem = pcall(function()
		test("160/198/236 safe heights show both complete recipes and separate 44px controls", function()
			for _, height in ipairs({ 160, 198, 236 }) do
				resize(568, height)
				local view = fixture(); resize(568, height, view)
				assert(view.compactShop and view.card.AbsoluteSize.Y == height - 16)
				for _, id in ipairs({ "meadow", "sprout" }) do
					local recipe = view.body.EggColumn:FindFirstChild("Recipe_" .. id)
					assert(recipe.AbsoluteSize.Y == 44 and fullyVisible(recipe, view.body))
					assert(recipe.RecipeName.TextFits and recipe.Cost.TextFits, "half-width recipe text: " .. id)
				end
				local meadow, sprout = view.body.EggColumn.Recipe_meadow, view.body.EggColumn.Recipe_sprout
				assert(meadow.Position.Y.Offset == 0 and sprout.Position.Y.Offset == 0)
				assert(meadow.AbsolutePosition.X + meadow.AbsoluteSize.X < sprout.AbsolutePosition.X)
				assert(view.heading.TextFits and view.nectar.TextFits)
				assert(view.closeButton.AbsoluteSize.Y == 44 and view.closeButton.AbsoluteSize.X == 44 and view.closeButton.TextFits)
				assert(view.action.AbsoluteSize.Y == 44 and view.action.TextFits)
				assert(view.closeButton.AbsolutePosition.Y + 44 <= view.body.AbsolutePosition.Y + 0.1)
				assert(view.body.AbsolutePosition.Y + view.body.AbsoluteSize.Y < view.action.AbsolutePosition.Y)
				assert(view.action.AbsolutePosition.Y + 44 <= root.AbsolutePosition.Y + height)
				assert(not view.note.Visible and not view.meetButton.Visible)
				assert(view.body.OutcomeColumn.Position.X.Offset == 0, "compact shop uses one scroll column even on wide phones")
				view:close()
			end
		end)
		test("selecting Sprout uses its 24 nectar cost and exact missing amount", function()
			resize(568, 160)
			local view, sent = fixture(); resize(568, 160, view)
			view.body.CanvasPosition = Vector2.new(0, view.body.EggColumn.DailyNectar.Position.Y.Offset)
			assert(view:selectRecipe("sprout") and view.selected == "sprout")
			task.wait(0.04)
			assert(fullyVisible(view.body.EggColumn.Recipe_sprout, view.body), "the selected recipe stays visible above its purchase action")
			assert(view.body.CanvasPosition.Y == view.body.EggColumn.Recipe_sprout.Position.Y.Offset)
			assert(view.action.Text:find("need 6 nectar", 1, true) and view.body.EggColumn.Recipe_sprout.Cost.Text:find("24", 1, true))
			view:update(snapshot(24)); task.wait(0.05)
			assert(view.action.Text == "Hatch Sprout Focused · 24 nectar" and view.action.Interactable and #sent == 0)
			view:close()
		end)
		test("narrow 350x279 shop keeps both complete recipe names and costs readable", function()
			resize(350, 279)
			local view, sent = fixture(); resize(350, 279, view)
			local meadow, sprout = view.body.EggColumn.Recipe_meadow, view.body.EggColumn.Recipe_sprout
			for _, row in ipairs({ meadow, sprout }) do
				assert(row.AbsoluteSize.Y == 44 and fullyVisible(row, view.body))
				assert(row.RecipeName.TextFits and row.Cost.TextFits, "narrow recipe text: " .. row.Name)
				assert(row.AbsolutePosition.X >= view.body.AbsolutePosition.X)
				assert(row.AbsolutePosition.X + row.AbsoluteSize.X <= view.body.AbsolutePosition.X + view.body.AbsoluteSize.X)
			end
			assert(meadow.AbsolutePosition.X + meadow.AbsoluteSize.X < sprout.AbsolutePosition.X)
			view:selectRecipe("sprout"); view:update(snapshot(24)); task.wait(0.04)
			assert(view.action.Text == "Hatch Sprout Focused · 24 nectar" and view.action.TextFits and view.action.Interactable and #sent == 0)
			assert(view.closeButton.AbsoluteSize.Y == 44 and view.action.AbsoluteSize.Y == 44)
			view:close()
		end)
		test("compact errors and save state remain visible and clear when retried", function()
			resize(568, 160)
			local view, sent = fixture(); resize(568, 160, view)
			for _, message in ipairs({ "One moment…", "Your hatch progress updated. Try again." }) do
				view:setError(message); task.wait(0.03)
				assert(view.heading.Visible and view.nectar.Visible and view.heading.Text == "Try again")
				assert(view.nectar.Text:find("try again", 1, true) and view.heading.TextFits and view.nectar.TextFits)
			end
			view:send("hatch", "meadow"); task.wait(0.03)
			assert(view.errorMessage == nil and view.heading.Text == "Saving…" and not view.nectar.Text:find("Progress updated", 1, true) and #sent == 1)
			view:update(snapshot(0)); task.wait(0.03)
			assert(view.heading.Text == "Hatch eggs" and view.nectar.Text == "0 nectar")
			local unavailable = snapshot(0); unavailable.status = "SessionLost"
			view:update(unavailable); view:setError("This hatch session moved to another server. Rejoin to continue.")
			assert(view.heading.Text == "Save unavailable" and view.nectar.Text:find("rejoin", 1, true) and not view.action.Interactable)
			view:update(snapshot(0))
			view:setError("One moment…")
			resize(390, 740, view)
			assert(view.note.Visible, "normal rotation must expose its notice")
			assert(view.note.Text == "One moment…", "normal rotation notice: " .. view.note.Text)
			assert(view.heading.Text == "Hatch eggs", "normal rotation heading: " .. view.heading.Text)
			view:update(snapshot(24, { id = "error-result-fixture", petId = "pip", family = "pip" })); task.wait(0.04)
			assert(not view.heading.Visible and not view.nectar.Visible and not view.note.Visible and view.meetButton.Visible)
			view:close()
		end)
		test("daily gift, every hatch odd and rare protection remain completely reachable", function()
			resize(568, 160)
			local view = fixture(); resize(568, 160, view)
			local daily, odds = view.body.EggColumn.DailyNectar, view.body.OutcomeColumn
			assert(daily.AbsoluteSize.Y == 44 and daily.Interactable and daily.TextFits)
			scrollTo(view, daily)
			local count = 0
			for _, row in ipairs(odds:GetChildren()) do
				if row.Name:match("^Outcome_") then
					count += 1; scrollTo(view, row)
					assert(row:FindFirstChild("Name").TextFits and row.Probability.TextFits)
				end
			end
			assert(count == 7)
			scrollTo(view, odds.RareProtection); assert(odds.RareProtection.TextFits and odds.RareProtection.Text:find("3 / 7", 1, true))
			scrollTo(view, odds.Duplicates); assert(odds.Duplicates.TextFits)
			view:close()
		end)
		test("rotation resets normal shop geometry while preserving selection and bounded scroll", function()
			resize(568, 160)
			local view = fixture(); resize(568, 160, view)
			view:selectRecipe("sprout"); view.body.CanvasPosition = Vector2.new(0, 100)
			resize(390, 740, view)
			assert(view.selected == "sprout", "rotation changed selected recipe: " .. view.selected)
			assert(view.note.Visible, "normal shop notice did not return")
			assert(view.card.AbsoluteSize.Y == 580 and view.body.EggColumn.Recipe_sprout.AbsoluteSize.Y == 83)
			assert(view.closeButton.Position.Y.Scale == 0 and view.closeButton.Text=="×", "normal close stays in header")
			assert(math.abs(view.action.Size.X.Scale - 1) < 0.00001, "normal action width scale: " .. view.action.Size.X.Scale)
			for _,node in ipairs({view.heading,view.wallet,view.nectar,view.note,view.closeButton}) do
				assert(fullyVisible(node,view.card),"rotated header outside card: "..node.Name)
				assert(node.AbsolutePosition.X>=view.card.AbsolutePosition.X and node.AbsolutePosition.X+node.AbsoluteSize.X<=view.card.AbsolutePosition.X+view.card.AbsoluteSize.X,"rotated header width: "..node.Name)
				assert(node.AbsolutePosition.Y+node.AbsoluteSize.Y<=view.body.AbsolutePosition.Y,"header covers shop body: "..node.Name)
			end
			assert(view.heading.TextFits and view.nectar.TextFits and view.note.TextFits,"normal header must remain readable after rotation")
			assert(view.heading.AbsolutePosition.X+view.heading.AbsoluteSize.X<=view.closeButton.AbsolutePosition.X,"title covers corner X")
			assert(view.wallet.AbsolutePosition.Y+view.wallet.AbsoluteSize.Y<=view.note.AbsolutePosition.Y,"wallet covers notice")
			assert(view.body.CanvasPosition.Y == 100 and view.body.CanvasPosition.Y <= view.body.CanvasSize.Y.Offset - view.body.AbsoluteSize.Y)
			resize(568, 160, view)
			assert(view.compactShop and view.selected == "sprout" and view.body.CanvasPosition.Y == 100)
			view.body.CanvasPosition = Vector2.new(0, view.body.CanvasSize.Y.Offset - view.body.AbsoluteSize.Y)
			resize(390, 740, view)
			assert(view.body.CanvasPosition.Y >= 0 and view.body.CanvasPosition.Y <= math.max(0, view.body.CanvasSize.Y.Offset - view.body.AbsoluteSize.Y))
			assert(view.closeButton.TextFits and view.action.TextFits and view.body.EggColumn.Recipe_sprout.RecipeName.TextFits)
			view:close()
		end)
		test("compact shop transitions preserve both 44px hatch result actions", function()
			resize(568, 160)
			local view, sent = fixture()
			view:update(snapshot(24, { id = "compact-result-fixture", petId = "foxfire_wick", family = "wick", rare = true })); task.wait(0.06)
			assert(not view.compactShop and view.meetButton.Visible and not view.body.Visible)
			for _, node in ipairs({ view.meetButton, view.action, view.closeButton }) do assert(node.AbsoluteSize.Y == 44 and node.TextFits) end
			assert(view.meetButton.Interactable and view.action.Interactable and (view.action.Text == "Play again" or view.action.Text=="Play") and view.state.lastHatch.id=="compact-result-fixture" and #sent == 0)
			assert(view.closeButton.AbsolutePosition.Y + 44 <= view.meetButton.AbsolutePosition.Y)
			view:close()
		end)
		test("reopening keeps the purchased recipe and cost explicit in the pinned action", function()
			resize(568, 160)
			local view, sent = fixture(); resize(568, 160, view)
			view:selectRecipe("sprout"); view:update(snapshot(24)); view:close()
			view:open(snapshot(24)); resize(568, 160, view)
			assert(view.selected == "sprout" and view.action.Text == "Hatch Sprout Focused · 24 nectar")
			assert(view.action.Visible and view.action.Interactable and view.action.TextFits and #sent == 0)
			assert(view.action.AbsolutePosition.Y + 44 <= root.AbsolutePosition.Y + root.AbsoluteSize.Y)
			view:close()
		end)
	end)
	for _, view in ipairs(views) do view:close(); view.shade:Destroy() end
	root:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases }
end
