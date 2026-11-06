local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Art = require(script.Parent.DeckArt)
local Catalog = require(ReplicatedStorage.Shared.EggCatalog)
local FamilyCrest = require(script.Parent.FamilyCrest)
local Menu = {}
Menu.__index = Menu

local names = { pip = "Pip", puddle = "Puddle", wick = "Wick", orbit = "Orbit" }
local function text(parent, name, content, y, height, color, size)
	local node = Art.text(parent, name, content, UDim2.fromOffset(8, y), UDim2.new(1, -16, 0, height), color or Art.Silver, size or 13)
	node.TextXAlignment = Enum.TextXAlignment.Left
	Art.fitText(node, size or 13, 10, 0, true)
	return node
end
local function button(parent, name, caption, x, y, width, action)
	local b = Instance.new("TextButton")
	b.Name, b.Text = name, caption
	b.Position, b.Size = UDim2.new(x, 4, 0, y), UDim2.new(width, -8, 0, 44)
	b.BackgroundColor3, b.TextColor3 = Art.Raised, Art.Silver
	b.Font, b.TextSize, b.BorderSizePixel, b.ZIndex = Enum.Font.GothamBold, 14, 0, 32
	b.Parent = parent
	Art.button(b, 9); Art.fitText(b, 14, 10, 6, true)
	b.Activated:Connect(action)
	return b
end

function Menu.new(parent, callbacks)
	local shade = Art.frame(parent, "DeckMenu", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 28)
	shade.BackgroundTransparency, shade.Active, shade.Visible = 1, true, false
	local card = Art.frame(shade, "Card", Art.Surface, UDim2.fromScale(.5, .5), UDim2.fromOffset(500, 540), 29)
	card.AnchorPoint = Vector2.new(.5, .5); Art.panel(card, 16, Art.Leaf)
	local heading = text(card, "Heading", "POCKET MENU", 8, 26, Art.Leaf, 20)
	local close = button(card, "Close", "Back to game", 0, 0, 1, function() callbacks.close() end)
	close.Position, close.Size = UDim2.new(0, 12, 1, -56), UDim2.new(1, -24, 0, 44)
	local body = Instance.new("ScrollingFrame")
	body.Name, body.Position, body.Size = "Body", UDim2.fromOffset(12, 42), UDim2.new(1, -24, 1, -106)
	body.BackgroundTransparency, body.BorderSizePixel, body.ScrollBarThickness, body.ZIndex = 1, 0, 4, 30
	body.ScrollingDirection, body.ElasticBehavior, body.Parent = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.Never, card
	local nectar = text(body, "Nectar", "NECTAR · 0", 0, 26, Art.Amber, 20)
	text(body, "ExplainNectar", "Win quests: +6 nectar, +2 for a low pile. Spend it on eggs.", 28, 36, Art.Muted, 12)
	local egg = Art.frame(body, "Egg", Art.Leaf, UDim2.fromOffset(10, 71), UDim2.fromOffset(25, 32), 31)
	Art.corner(egg, 20); Art.stroke(egg, Art.Silver)
	local recipe = text(body, "EggGoal", "Meadow egg · 0/18 nectar", 68, 38, Art.Silver, 14)
	recipe.Position, recipe.Size = UDim2.fromOffset(45, 68), UDim2.new(1, -53, 0, 38)
	text(body, "EggExplanation", "Choose an egg when ready. Each hatch costs nectar; your next goal stays available.", 109, 36, Art.Muted, 12)
	local buttons = {}
	for index, entry in ipairs({ {"Eggs", "Hatch eggs", "eggs"}, {"Pets", "Pet journal", "pets"}, {"Style", "Style & sound", "style"}, {"Deck", "Play / resume", "play"} }) do
		buttons[index] = button(body, entry[1], entry[2], (index - 1) % 2 * .5, 151 + math.floor((index - 1) / 2) * 50, .5, function() callbacks[entry[3]]() end)
	end
	text(body, "DailyHeading", "TODAY'S CONTRACTS", 258, 24, Art.Leaf, 16)
	local daily = {}
	for i = 1, 3 do daily[i] = text(body, "Contract" .. i, "Loading contract…", 285 + (i - 1) * 43, 39, Art.Silver, 13) end
	local dailyButton = button(body, "DailyBonus", "Daily gift · +6 nectar", 0, 420, 1, function() callbacks.daily() end)
	text(body, "FamilyHeading", "FAMILY MASTERY", 475, 24, Art.Leaf, 16)
	local familyNote = text(body, "FamilyNote", "Pick a family for your NEXT round. Wins +1, clean wins +2; duplicates +1.", 502, 36, Art.Muted, 12)
	local families, familyText, familyHints = {}, {}, {}
	for index, family in ipairs(Catalog.Families) do
		local y = 545 + (index - 1) * 132
		families[family] = button(body, "Family_" .. family, names[family], 0, y, .44, function() callbacks.family(family) end)
		FamilyCrest.create(families[family], family, 0, UDim2.fromOffset(6, 10), UDim2.fromOffset(24, 24), 34, true)
		families[family]:FindFirstChildOfClass("UIPadding"):Destroy()
		families[family].TextTransparency = 1
		local caption = Art.text(families[family], "FamilyName", names[family], UDim2.fromOffset(36, 0),
			UDim2.new(1, -42, 1, 0), Art.Silver, 14, Enum.Font.GothamBold)
		caption.TextXAlignment = Enum.TextXAlignment.Left
		Art.fitText(caption, 14, 10, 0, false)
		familyText[family] = text(body, "Progress_" .. family, "Not discovered", y, 44, Art.Silver, 12)
		familyText[family].Position, familyText[family].Size = UDim2.new(.44, 4, 0, y), UDim2.new(.56, -12, 0, 44)
		familyHints[family] = text(body, "Reward_" .. family, "I badge · II finish · III family effect", y + 47, 78, Art.Muted, 11)
	end
	text(body, "ScoreExplanation", "Score and chains measure your run and complete contracts. Nectar buys eggs. Prestige shows family mastery.", 905, 48, Art.Muted, 12)
	text(body, "QuestExplanation", "QUEST: II + II makes III. Merge on the glowing LEFT side, then RIGHT. Larger matching pairs count too.", 961, 56, Art.Leaf, 12)
	body.CanvasSize = UDim2.fromOffset(0, 1028)
	-- Pinned page tabs keep daily contracts and mastery reachable on short phones.
	local pages, tabs = {}, {}
	for index, entry in ipairs({ { "play", "Play", 360 }, { "daily", "Daily", 220 }, { "mastery", "Mastery", 608 } }) do
		local page = Art.frame(body, entry[1], Art.Ink, UDim2.fromOffset(0, 0), UDim2.new(1, -5, 0, entry[3]), 31)
		page.BackgroundTransparency, page.Visible = 1, entry[1] == "play"
		pages[entry[1]] = page
	end
	local nodes = body:GetChildren()
	for _, node in ipairs(nodes) do
		if node:IsA("GuiObject") and not pages[node.Name] then
			local name, y = node.Name, node.Position.Y.Offset
			local key = if name == "DailyHeading" or name == "DailyBonus" or name:match("^Contract") then "daily"
				elseif name == "FamilyHeading" or name == "FamilyNote" or name:match("^Family_") or name:match("^Progress_") or name:match("^Reward_") then "mastery" else "play"
			node.Parent = pages[key]
			if key == "daily" then y -= 258 elseif key == "mastery" then y -= 475
			else
				local positions = { Eggs = 0, Pets = 0, Style = 50, Deck = 50, Egg = 113, EggGoal = 110,
					EggExplanation = 155, ExplainNectar = 195, ScoreExplanation = 238, QuestExplanation = 294 }
				y = positions[name] or y
			end
			node.Position = UDim2.new(node.Position.X.Scale, node.Position.X.Offset, 0, y)
		end
	end
	nectar.Parent, nectar.Position, nectar.Size = card, UDim2.new(.55, 0, 0, 9), UDim2.new(.45, -12, 0, 24)
	heading.Size = UDim2.new(.55, -16, 0, 26)
	body.Position, body.Size = UDim2.fromOffset(12, 94), UDim2.new(1, -24, 1, -158)
	local self = setmetatable({ shade = shade, card = card, body = body, nectar = nectar, recipe = recipe, daily = daily,
		dailyButton = dailyButton, families = families, familyText = familyText, familyHints = familyHints, familyNote = familyNote,
		closeButton = close, pages = pages, tabs = tabs }, Menu)
	for index, entry in ipairs({ { "play", "Play" }, { "daily", "Daily" }, { "mastery", "Mastery" } }) do
		tabs[entry[1]] = button(card, "Tab_" .. entry[1], entry[2], (index - 1) / 3, 42, 1 / 3, function() self:setPage(entry[1]) end)
	end
	self:setPage("play")
	local function layout()
		local height = math.min(620, math.max(135, parent.AbsoluteSize.Y - (if parent.AbsoluteSize.Y < 280 then 8 else 24)))
		card.Size = UDim2.fromOffset(math.min(520, math.max(1, parent.AbsoluteSize.X - 24)), height)
		local compact = height < 280
		close.Position = if compact then UDim2.new(1, -94, 0, 4) else UDim2.new(0, 12, 1, -56)
		close.Size = if compact then UDim2.fromOffset(86, 44) else UDim2.new(1, -24, 0, 44)
		close.Text = if compact then "Back" else "Back to game"
		if compact then
			heading.Size, heading.Position = UDim2.new(1, -108, 0, 22), UDim2.fromOffset(8, 3)
			nectar.Position, nectar.Size = UDim2.fromOffset(8, 25), UDim2.new(1, -108, 0, 19)
		else
			heading.Size, heading.Position = UDim2.new(.55, -16, 0, 26), UDim2.fromOffset(8, 8)
			nectar.Position, nectar.Size = UDim2.new(.55, 0, 0, 9), UDim2.new(.45, -12, 0, 24)
		end
		for _, tab in pairs(tabs) do tab.Position = UDim2.new(tab.Position.X.Scale, tab.Position.X.Offset, 0, if compact then 50 else 42) end
		body.Position, body.Size = UDim2.fromOffset(12, if compact then 100 else 94), UDim2.new(1, -24, 1, if compact then -108 else -158)
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout); layout()
	return self
end

function Menu:update(state, selected, runFamily, score, chain, best, recipeId)
	state = state or {}
	self.nectar.Text = "NECTAR · " .. (state.nectar or 0)
	local recipe = Catalog.ById[recipeId] or Catalog.ById.meadow
	self.recipe.Text = recipe.name .. " · " .. (state.nectar or 0) .. "/" .. recipe.cost .. " nectar"
	self.dailyButton.Text = if state.dailyAvailable then "Claim daily gift · +6 nectar" else "Daily gift claimed · back tomorrow"
	self.dailyButton.Interactable = state.dailyAvailable == true and state.status == "Ready"
	local contracts = state.contracts or {}
	for i, node in ipairs(self.daily) do
		local c = contracts[i]
		node.Text = if c then string.format("%s · %d/%d · %s", c.name or c.title or c.id, c.progress or 0, c.target or 1,
			if c.claimed or c.complete then "✓ earned" else "+" .. (c.reward or 0) .. " nectar") else "Contracts appear after your first pet."
	end
	for family, b in pairs(self.families) do
		local owned = false
		for _, pet in ipairs(require(ReplicatedStorage.Shared.PetCatalog).collection) do
			if (pet.family or pet.id) == family and Catalog.isOwned(state.inventoryMask, pet.id) then owned = true end
		end
		local points = state.mastery and state.mastery[family] or 0
		local detail = state.masteryDetails and state.masteryDetails[family]
		local rank = if detail then detail.rank else (state.masteryRanks and state.masteryRanks[family] or 0)
		local nextGoal = if detail then detail.nextGoal else nil
		local missing = if detail then detail.missingChallenges else nil
		self.familyHints[family].Text = if not owned then "Hatch a member of this family to begin mastery."
			elseif rank >= 3 then "Family mastered\nBloom family effect unlocked"
			elseif nextGoal then "Next: " .. nextGoal
				.. (if rank == 2 and missing and #missing > 0 then "\nStill needed: " .. table.concat(missing, " · ") else "")
				.. (if detail.rewardHint then "\n" .. detail.rewardHint else "")
			else "I badge · II finish · III family effect"
		b.Interactable, b.BackgroundColor3 = owned and state.status == "Ready", if selected == family then Art.Canopy else Art.Raised
		FamilyCrest.update(b.FamilyCrest, family, rank, not owned)
		b.Text = names[family] .. (if selected == family then " ✓" else "")
		b.FamilyName.Text = b.Text
		self.familyText[family].Text = if not owned then "Discover a family member in eggs"
			elseif rank >= 3 then string.format("Rank III · mastered\n%d total marks", points) else
			string.format("Rank %s · %d/%d marks%s", ({[0]="—", "I", "II", "III"})[rank] or "III", points,
				if rank == 0 then 3 elseif rank == 1 then 10 else 25, "")
	end
	self.familyNote.Text = "Next: " .. (names[selected] or "Pip") .. " · This round: " .. (names[runFamily] or "Pip") .. ". Wins +1, clean +2; duplicates +1."
	self.card:SetAttribute("RunScore", score or 0); self.card:SetAttribute("RunChain", chain or 0); self.card:SetAttribute("PersonalBest", best or 0)
end

function Menu:setPage(key)
	for name, page in pairs(self.pages) do page.Visible = name == key end
	for name, tab in pairs(self.tabs) do tab.BackgroundColor3 = if name == key then Art.Canopy else Art.Raised end
	self.body.CanvasPosition = Vector2.zero
	self.body.CanvasSize = UDim2.fromOffset(0, ({ play = 360, daily = 220, mastery = 608 })[key] or 360)
end

function Menu:open()
	self.shade.Visible = true
	if string.match(game:GetService("UserInputService"):GetLastInputType().Name, "^Gamepad") then GuiService.SelectedObject = self.closeButton end
end
function Menu:close()
	self.shade.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade) then GuiService.SelectedObject = nil end
end
return Menu
