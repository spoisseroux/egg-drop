-- Studio Client presentation fixtures; no remotes or persistent inventory changes.
return function(client, parent)
	local Journal = require(client.PetJournal)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Pets, Catalog = require(Shared.PetCatalog), require(Shared.EggCatalog)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_JournalPurposeSpec", UDim2.fromOffset(360, 198), 1, parent
	local views, cases = {}, {}
	local function make(class, name, properties, owner)
		local node = Instance.new(class)
		node.Name = name
		for key, value in pairs(properties) do node[key] = value end
		node.Parent = owner
		return node
	end
	local function label(class, name, content, owner, background)
		return make(class, name, { Text = content, BackgroundTransparency = if background then 0 else 1,
			BackgroundColor3 = background or Color3.new(), BorderSizePixel = 0, TextColor3 = Color3.new(1, 1, 1) }, owner)
	end
	local function test(name, run) run(); table.insert(cases, name) end
	local function fixture(withGoals)
		local visits, tracks, goals = 0, 0, 0
		local view
		view = Journal.new(root, make, label, function() visits += 1 end, function() tracks += 1 end,
			if withGoals then function() assert(not view.shade.Visible, "close before routing"); goals += 1 end else nil)
		table.insert(views, view)
		return view, function() return visits, tracks, goals end
	end
	local ok, problem = pcall(function()
		test("a rare-only inventory inherits its family rank without unlocking the base pet", function()
			local view, counts = fixture(true)
			view:open(0, 0, "foxfire_wick", false, nil, Catalog.bit("foxfire_wick"), { wick = 3 })
			local rare, base = view.cards[Pets.byId.foxfire_wick.index], view.cards[Pets.byId.wick.index]
			assert(rare.Interactable and rare.Status.Text:find("Equipped", 1, true) and rare.Status.Text:find("Wick · III", 1, true))
			assert(not base.Interactable and base.Status.Text == "Hatch from eggs")
			assert(view.title.Text:find("01/07", 1, true))
			local visits, tracks, goals = counts(); assert(visits == 0 and tracks == 0 and goals == 0)
			view:close()
		end)
		test("family goals routes once after closing and issues no equip or track action", function()
			local view, counts = fixture(true)
			view:open(0, 0, "foxfire_wick", false, nil, Catalog.bit("foxfire_wick"), { wick = 2 })
			view:openFamilyGoals(); view:openFamilyGoals()
			local visits, tracks, goals = counts()
			assert(not view.shade.Visible and visits == 0 and tracks == 0 and goals == 1)
		end)
		test("legacy constructor preserves centered close and optional rank arguments", function()
			local view, counts = fixture(false)
			view:open(1, 0, "pip", false)
			assert(view.goalsButton == nil and view.closeButton.Position.X.Scale == 0.25 and view.closeButton.Size.X.Scale == 0.5)
			assert(view.cards[1].Status.Text:find("Pip · Unranked", 1, true))
			view:openFamilyGoals(); assert(view.shade.Visible)
			view:close(); assert(not view.shade.Visible)
			local visits, tracks, goals = counts(); assert(visits == 0 and tracks == 0 and goals == 0)
		end)
		test("compact and portrait journal shows complete rows and 44px footer controls", function()
			local view = fixture(true)
			for _, height in ipairs({ 160, 198, 600 }) do
				root.Size = UDim2.fromOffset(360, height); task.wait(0.06)
				view:open(0, 0, "foxfire_wick", false, nil, Catalog.mask({ "foxfire_wick", "eclipse_orbit", "puddle" }),
					{ wick = 3, orbit = 2, puddle = 1 }); task.wait(0.06)
				assert(view.scroll.AbsoluteSize.Y >= 52 and view.title.TextFits, "header/row safe area at " .. height)
				for _, node in ipairs({ view.closeButton, view.goalsButton }) do
					assert(node.AbsoluteSize.Y == 44 and node.TextFits)
					assert(node.AbsolutePosition.Y >= view.scroll.AbsolutePosition.Y + view.scroll.AbsoluteSize.Y)
					assert(node.AbsolutePosition.Y + 44 <= root.AbsolutePosition.Y + height)
				end
				for _, entry in ipairs(view.cards) do
					assert(entry.Species.TextFits and entry.Status.TextFits, "full name/status at " .. height .. ": " .. entry.Name)
					assert(entry.Status.Position.Y.Offset + entry.Status.Size.Y.Offset <= entry.Size.Y.Offset)
					assert(entry.PortraitWell.Position.Y.Offset + entry.PortraitWell.Size.Y.Offset <= entry.Size.Y.Offset)
				end
				view.scroll.CanvasPosition = Vector2.new(0, math.max(0, view.scroll.CanvasSize.Y.Offset - view.scroll.AbsoluteSize.Y)); task.wait(0.06)
				local last = view.cards[#view.cards]
				assert(last.AbsolutePosition.Y >= view.scroll.AbsolutePosition.Y - 1)
				assert(last.AbsolutePosition.Y + last.AbsoluteSize.Y <= view.scroll.AbsolutePosition.Y + view.scroll.AbsoluteSize.Y + 1)
				assert(view.card.AbsoluteSize.Y == (if height == 600 then 378 else height - 8))
				view:close()
			end
		end)
	end)
	for _, view in ipairs(views) do view:close(); view.shade:Destroy() end
	root:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases }
end
