-- Native Client art fixtures; no audio assets, transactions or uploaded images.
return function(client, parent)
	local Egg = require(client.EggArt)
	local View = require(client.EggHatchView)
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "_EggArtSpec", UDim2.fromOffset(568, 390), 1, parent
	local cases, views = {}, {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function foreground(host, button)
		assert(host.ZIndex > button.ZIndex)
		for _, node in ipairs(host:GetDescendants()) do
			assert(not node:IsA("ImageLabel") and not node:IsA("ImageButton") and not node:IsA("TextLabel"))
			if node:IsA("GuiObject") then assert(node.ZIndex > button.ZIndex and not node.Active and not node.Selectable) end
		end
	end
	local function fixture(width, height)
		root.Size = UDim2.fromOffset(width, height); task.wait(.04)
		local view = View.new(root, { play = function() end }, function() return true end, function() error("art fixture must never send") end)
		table.insert(views, view)
		view:open({ status = "Ready", revision = 1, nectar = 24 })
		local deadline = os.clock() + 2
		local compact = height < 280
		local function settled()
			local column = view.body:FindFirstChild("EggColumn")
			return view.shade.AbsoluteSize == Vector2.new(width, height) and view.compactShop == compact and column
				and column.Recipe_meadow.AbsoluteSize.Y == (if compact then 44 else 83)
		end
		repeat task.wait(.03) until settled() or os.clock() > deadline
		assert(settled(), "egg art layout did not settle")
		return view
	end
	local ok, problem = pcall(function()
		test("original Meadow and Sprout silhouettes have distinct motifs and no input capture", function()
			local meadow = Egg.create(root, "meadow", UDim2.fromOffset(0, 0), UDim2.fromOffset(64, 82), 10)
			local sprout = Egg.create(root, "sprout", UDim2.fromOffset(80, 0), UDim2.fromOffset(64, 82), 10)
			assert(meadow.Pattern:FindFirstChild("MeadowSpot") and not meadow.Pattern:FindFirstChild("SproutStem"))
			assert(sprout.Pattern:FindFirstChild("SproutStem") and sprout.Pattern:FindFirstChild("LeafLeft") and not sprout.Pattern:FindFirstChild("MeadowSpot"))
			assert(not meadow.Active and not meadow.Selectable and not sprout.Active)
			meadow:Destroy(); sprout:Destroy()
		end)
		test("wide recipe eggs render above their buttons with full names and prices", function()
			local view = fixture(568, 390)
			for _, id in ipairs({ "meadow", "sprout" }) do
				local button = view.body.EggColumn:FindFirstChild("Recipe_" .. id)
				assert(button.Egg.Visible and button.Egg:GetAttribute("RecipeId") == id)
				foreground(button.Egg, button)
				assert(button.RecipeName.TextFits and button.Cost.TextFits)
			end
			assert(view.wallet.Visible and view.wallet.NectarDrop.Visible)
			view:close()
		end)
		test("350px compact recipes retain 24px foreground artwork and complete text", function()
			local view = fixture(350, 279)
			for _, id in ipairs({ "meadow", "sprout" }) do
				local button = view.body.EggColumn:FindFirstChild("Recipe_" .. id)
				assert(button.Egg.Visible and button.Egg.AbsoluteSize.X == 24 and button.AbsoluteSize.Y == 44)
				foreground(button.Egg, button)
				assert(button.RecipeName.TextFits and button.Cost.TextFits, "compact recipe text: " .. id)
			end
			view:close()
		end)
		test("the egg stand follows recipe selection without rebuilding transactions", function()
			local view = fixture(568, 390)
			assert(view:selectRecipe("sprout"))
			local scene = view.body.EggColumn.EggStand
			assert(scene.Egg:GetAttribute("RecipeId") == "sprout" and scene.Egg.Pattern:FindFirstChild("LeafLeft"))
			assert(scene.Egg.ZIndex > scene.ZIndex and view.selected == "sprout")
			view:close()
		end)
	end)
	for _, view in ipairs(views) do view:close(); view.shade:Destroy() end
	root:Destroy(); assert(ok, problem)
	return { passed = #cases, cases = cases }
end
