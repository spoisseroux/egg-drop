local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Art = require(script.Parent.DeckArt)
local Catalog = require(ReplicatedStorage.Shared.EggCatalog)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local FamilyCrest = require(script.Parent.FamilyCrest)
local Portrait = require(script.Parent.PetPortrait)
local EggArt = require(script.Parent.EggArt)
local Menu = {}
Menu.__index = Menu

local names = { pip = "Pip", puddle = "Puddle", wick = "Wick", orbit = "Orbit" }
local function text(parent, name, content, y, height, color, size)
	local node = Art.text(parent, name, content, UDim2.fromOffset(8, y), UDim2.new(1, -16, 0, height), color or Art.Silver, size or 13)
	node.TextXAlignment = Enum.TextXAlignment.Left
	Art.fitText(node, size or 13, 10, 0, true)
	return node
end
local function button(parent, name, caption, action)
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Size = name, caption, UDim2.fromOffset(100, 44)
	b.BackgroundColor3, b.TextColor3 = Art.Raised, Art.Silver
	b.Font, b.TextSize, b.BorderSizePixel, b.ZIndex = Enum.Font.GothamBold, 14, 0, parent.ZIndex + 1
	b.Parent = parent
	Art.button(b, 10); Art.fitText(b, 14, 10, 6, true)
	b.Activated:Connect(action)
	return b
end
local function decoration(parent, name, position, size, color, radius)
	local node = Art.frame(parent, name, color, position, size, parent.ZIndex + 1)
	Art.corner(node, radius or 8)
	return node
end
local function destinationArt(host, kind)
	if kind == "eggs" then
		EggArt.create(host, "meadow", UDim2.fromScale(.10, .02), UDim2.fromScale(.80, .96), host.ZIndex + 1)
	elseif kind == "pets" then
		local portrait = Portrait.create(host, Pets.byId.pip, 4, UDim2.fromScale(.5, .5), host.ZIndex + 2)
		local scale = Instance.new("UIScale")
		scale.Name, scale.Parent = "DisplayScale", portrait
	else
		local deck = decoration(host, "Handheld", UDim2.fromScale(.03, .20), UDim2.fromScale(.94, .58), Art.Leaf, 8)
		local screen = decoration(deck, "Screen", UDim2.fromScale(.30, .14), UDim2.fromScale(.42, .72), Art.Ink, 3)
		decoration(screen, "ScreenSprout", UDim2.fromScale(.40, .32), UDim2.fromScale(.22, .42), Art.Leaf, 2)
		decoration(deck, "Rocker", UDim2.fromScale(.09, .43), UDim2.fromScale(.15, .15), Art.Canopy, 2)
		decoration(deck, "DropButton", UDim2.fromScale(.80, .37), UDim2.fromScale(.13, .24), Art.Orange, 100)
	end
end
local function contractArt(host, index)
	if index == 1 then
		FamilyCrest.create(host, "pip", 0, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), host.ZIndex + 1)
	elseif index == 2 then
		for _, x in ipairs({ .05, .43 }) do
			local ring = decoration(host, "ChainLink", UDim2.fromScale(x, .22), UDim2.fromScale(.51, .55), Art.Amber, 100)
			ring.BackgroundTransparency, ring.Rotation = 1, -28
			Art.stroke(ring, Art.Amber, 0, 2)
		end
	else
		local star = decoration(host, "ScoreDiamond", UDim2.fromScale(.24, .20), UDim2.fromScale(.52, .58), Art.Orange, 3)
		star.Rotation = 45
		decoration(host, "ScoreGlint", UDim2.fromScale(.44, .34), UDim2.fromScale(.13, .24), Art.Silver, 2)
	end
end

function Menu.new(parent, callbacks)
	local shade = Art.frame(parent, "DeckMenu", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 28)
	shade.BackgroundTransparency, shade.Active, shade.Visible = 1, true, false
	local card = Art.frame(shade, "Card", Art.Surface, UDim2.fromScale(.5, .5), UDim2.fromOffset(520, 540), 29)
	card.AnchorPoint = Vector2.new(.5, .5); Art.panel(card, 16, Art.Leaf)
	local heading = text(card, "Heading", "POCKET MENU", 4, 22, Art.Silver, 18)
	heading.Font = Enum.Font.GothamBold
	local wallet = decoration(card, "Wallet", UDim2.fromOffset(8, 26), UDim2.fromOffset(164, 22), Art.Canopy, 8)
	EggArt.nectar(wallet, UDim2.fromOffset(3, 2), UDim2.fromOffset(17, 18), wallet.ZIndex + 1)
	local nectar = text(wallet, "Nectar", "0 nectar", 0, 22, Art.Amber, 16)
	nectar.Position, nectar.Size = UDim2.fromOffset(24, 0), UDim2.new(1, -28, 1, 0)
	local body = Instance.new("ScrollingFrame")
	body.Name, body.BackgroundTransparency, body.BorderSizePixel, body.ZIndex = "Body", 1, 0, 30
	body.ScrollBarThickness, body.ScrollBarImageColor3 = 4, Art.Leaf
	body.ScrollingDirection, body.ElasticBehavior, body.Parent = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.Never, card
	local cue = Art.frame(card, "MoreBelow", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(8, 16), 40)
	cue.BackgroundTransparency = 1
	for _, stroke in ipairs({ { 0, 45 }, { 3, -45 } }) do
		local line = Art.frame(cue, "Chevron", Art.Leaf, UDim2.fromOffset(stroke[1], 6), UDim2.fromOffset(5, 2), 41)
		line.Rotation = stroke[2]
	end
	local self = setmetatable({ shade = shade, card = card, parent = parent, heading = heading, wallet = wallet, body = body,
		nectar = nectar, callbacks = callbacks, pages = {}, tabs = {}, destinations = {}, daily = {}, dailyCards = {},
		families = {}, familyText = {}, familyHints = {}, moreCue = cue, page = "play", state = {} }, Menu)
	self.closeButton = button(card, "Close", "×", function() self:activate("close") end)
	self.closeButton.TextSize = 24
	Art.fitText(self.closeButton, 24, 18, 0, false)
	self.resumeButton = button(card, "Deck", "Play / resume", function() self:activate("play") end)
	self.resumeButton.BackgroundColor3, self.resumeButton.TextColor3 = Art.Leaf, Art.Ink
	self.dailyButton = button(card, "DailyBonus", "Daily gift +6", function() self:activate("daily") end)
	for _, key in ipairs({ "play", "daily", "mastery" }) do
		local page = Art.frame(body, key, Art.Ink, UDim2.fromOffset(0, 0), UDim2.new(1, -6, 0, 300), 31)
		page.BackgroundTransparency = 1
		self.pages[key] = page
	end
	for index, entry in ipairs({ { "play", "Play" }, { "daily", "Daily" }, { "mastery", "Mastery" } }) do
		self.tabs[entry[1]] = button(card, "Tab_" .. entry[1], entry[2], function() self:setPage(entry[1]) end)
	end
	for _, entry in ipairs({ { "Eggs", "Hatch eggs", "eggs", "18+ nectar" }, { "Pets", "Pet journal", "pets", "Companions" },
		{ "Style", "Deck style", "style", "Make it yours" } }) do
		local destination = button(self.pages.play, entry[1], entry[2], function() self:activate(entry[3]) end)
		destination.TextTransparency = 1
		local illustration = Art.frame(destination, "Illustration", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(64, 64), destination.ZIndex + 1)
		illustration.BackgroundTransparency = 1
		destinationArt(illustration, entry[3])
		local title = text(destination, "Title", entry[2], 78, 22, Art.Silver, 14)
		title.TextXAlignment, title.Font = Enum.TextXAlignment.Center, Enum.Font.GothamBold
		local subtitle = text(destination, "Subtitle", entry[4], 102, 18, Art.Muted, 11)
		subtitle.TextXAlignment = Enum.TextXAlignment.Center
		table.insert(self.destinations, { button = destination, art = illustration, title = title, subtitle = subtitle, kind = entry[3] })
	end
	local recipePanel = decoration(self.pages.play, "EggGoalPanel", UDim2.fromOffset(0, 140), UDim2.new(1, 0, 0, 44), Art.Canopy, 10)
	EggArt.create(recipePanel, "meadow", UDim2.fromOffset(7, 5), UDim2.fromOffset(25, 34), recipePanel.ZIndex + 1)
	self.recipePanel = recipePanel
	self.recipe = text(recipePanel, "EggGoal", "Mixed Meadow · 0/18 nectar", 0, 44, Art.Silver, 13)
	self.recipe.Position, self.recipe.Size = UDim2.fromOffset(39, 0), UDim2.new(1, -47, 1, 0)
	self.playHint = text(self.pages.play, "NectarPurpose", "Win both root patches to earn nectar. Keep the pile low for +2.", 194, 36, Art.Muted, 12)
	for index = 1, 3 do
		local panel = decoration(self.pages.daily, "Contract" .. index, UDim2.fromOffset(0, 0), UDim2.fromOffset(100, 104), Art.Raised, 10)
		local icon = Art.frame(panel, "Illustration", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(26, 26), panel.ZIndex + 1)
		icon.BackgroundTransparency = 1; contractArt(icon, index)
		local title = text(panel, "Title", "Loading…", 36, 26, Art.Silver, 13)
		title.TextXAlignment, title.Font = Enum.TextXAlignment.Center, Enum.Font.GothamBold
		local count = text(panel, "Count", "0/1", 64, 18, Art.Silver, 16)
		count.TextXAlignment = Enum.TextXAlignment.Center
		local reward = text(panel, "Reward", "+0 nectar", 82, 16, Art.Amber, 11)
		reward.TextXAlignment = Enum.TextXAlignment.Center
		local track = decoration(panel, "Track", UDim2.new(0, 5, 1, -5), UDim2.new(1, -10, 0, 3), Art.Ink, 3)
		local fill = decoration(track, "Fill", UDim2.fromOffset(0, 0), UDim2.fromScale(0, 1), Art.Leaf, 3)
		self.daily[index] = title
		self.dailyCards[index] = { panel = panel, art = icon, title = title, count = count, reward = reward, fill = fill, complete = false, amount = 0 }
	end
	self.dailyHint = text(self.pages.daily, "GiftExplanation", "The daily gift is separate from contracts. Completed contracts pay automatically after a round.", 116, 42, Art.Muted, 12)
	text(self.pages.mastery, "FamilyHeading", "FAMILY MASTERY", 0, 24, Art.Leaf, 16)
	self.familyNote = text(self.pages.mastery, "FamilyNote", "Pick a family for your next round.", 27, 36, Art.Muted, 12)
	for index, family in ipairs(Catalog.Families) do
		local y = 70 + (index - 1) * 132
		local b = button(self.pages.mastery, "Family_" .. family, names[family], function() self:activate("family", family) end)
		b.Position, b.Size = UDim2.new(0, 4, 0, y), UDim2.new(.44, -8, 0, 44)
		FamilyCrest.create(b, family, 0, UDim2.fromOffset(6, 10), UDim2.fromOffset(24, 24), b.ZIndex + 2, true)
		b:FindFirstChildOfClass("UIPadding"):Destroy(); b.TextTransparency = 1
		local caption = Art.text(b, "FamilyName", names[family], UDim2.fromOffset(36, 0), UDim2.new(1, -42, 1, 0), Art.Silver, 14, Enum.Font.GothamBold)
		caption.TextXAlignment = Enum.TextXAlignment.Left; Art.fitText(caption, 14, 10, 0, false)
		self.families[family] = b
		self.familyText[family] = text(self.pages.mastery, "Progress_" .. family, "Not discovered", y, 44, Art.Silver, 12)
		self.familyText[family].Position, self.familyText[family].Size = UDim2.new(.44, 4, 0, y), UDim2.new(.56, -12, 0, 44)
		self.familyHints[family] = text(self.pages.mastery, "Reward_" .. family, "", y + 47, 78, Art.Muted, 11)
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if not self.layingOut then self:layoutContents() end end)
	body:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:refreshScrollCue() end)
	self:setPage("play"); self:layout()
	return self
end

function Menu:activate(key, value)
	if not self.shade.Visible then return false end
	if key == "daily" and not self.dailyButton.Interactable then return false end
	if key == "family" and (not self.families[value] or not self.families[value].Interactable) then return false end
	local callback = self.callbacks[key]
	if not callback then return false end
	callback(value)
	return true
end

function Menu:layout()
	if self.layingOut then return end
	self.layingOut = true
	local size = self.parent.AbsoluteSize
	local height = math.min(620, math.max(135, size.Y - (if size.Y < 280 then 8 else 24)))
	local width = math.min(560, math.max(1, size.X - 24))
	self.card.Size = UDim2.fromOffset(width, height)
	local compact = height < 300
	self.compact = compact
	local y, walletY = if compact then 4 else 8, if compact then 24 else 34
	local leftWidth = math.max(1, width - 190)
	self.heading.Position, self.heading.Size = UDim2.fromOffset(8, y - 2), UDim2.fromOffset(leftWidth, 22)
	self.wallet.Position, self.wallet.Size = UDim2.fromOffset(8, walletY), UDim2.fromOffset(math.min(210, leftWidth), if compact then 20 else 22)
	self.closeButton.Position, self.closeButton.Size = UDim2.new(1, -52, 0, y), UDim2.fromOffset(44, 44)
	for _, action in ipairs({ self.resumeButton, self.dailyButton }) do
		action.Position, action.Size = UDim2.new(1, -172, 0, y), UDim2.fromOffset(112, 44)
	end
	local tabY = if compact then 48 else 68
	for index, key in ipairs({ "play", "daily", "mastery" }) do
		self.tabs[key].Position, self.tabs[key].Size = UDim2.new((index - 1) / 3, 4, 0, tabY), UDim2.new(1 / 3, -8, 0, 44)
	end
	local top = tabY + 52
	self.body.Position, self.body.Size = UDim2.fromOffset(12, top), UDim2.new(1, -24, 1, -top - 8)
	self.moreCue.Position, self.moreCue.Size = UDim2.new(1, -11, 1, -24), UDim2.fromOffset(8, 16)
	self:layoutContents()
	self.layingOut = false
end

function Menu:layoutContents()
	local small = self.body.AbsoluteSize.Y < 112
	local destinationHeight = if small then 44 else 124
	for index, item in ipairs(self.destinations) do
		item.button.Position, item.button.Size = UDim2.new((index - 1) / 3, 2, 0, 0), UDim2.new(1 / 3, -6, 0, destinationHeight)
		item.art.Position = if small then UDim2.fromOffset(5, 8) else UDim2.new(.5, -32, 0, 6)
		item.art.Size = if small then UDim2.fromOffset(26, 28) else UDim2.fromOffset(64, 64)
		if item.kind == "pets" then item.art.Portrait.DisplayScale.Scale = if small then .46 else 1 end
		item.title.Position = if small then UDim2.fromOffset(36, 2) else UDim2.fromOffset(4, 78)
		item.title.Size = if small then UDim2.new(1, -40, 0, 40) else UDim2.new(1, -8, 0, 22)
		item.title.TextXAlignment = if small then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		item.subtitle.Visible = not small
	end
	self.recipePanel.Position = UDim2.fromOffset(0, destinationHeight + 12)
	self.playHint.Position = UDim2.fromOffset(8, destinationHeight + 64)
	self.pageHeights = { play = destinationHeight + 108, daily = (if small then 44 else 104) + 56, mastery = 608 }
	local dailyHeight = if small then 44 else 104
	for index, row in ipairs(self.dailyCards) do
		row.panel.Position, row.panel.Size = UDim2.new((index - 1) / 3, 2, 0, 0), UDim2.new(1 / 3, -6, 0, dailyHeight)
		row.art.Position = if small then UDim2.fromOffset(4, 20) else UDim2.new(.5, -13, 0, 6)
		row.art.Size = if small then UDim2.fromOffset(11, 14) else UDim2.fromOffset(26, 26)
		row.title.Position, row.title.Size = UDim2.fromOffset(4, if small then 1 else 36), UDim2.new(1, -8, 0, if small then 16 else 26)
		row.count.Position = if small then UDim2.fromOffset(17, 19) else UDim2.fromOffset(4, 64)
		row.count.Size = if small then UDim2.new(.65, -17, 0, 17) else UDim2.new(1, -8, 0, 18)
		row.reward.Position = if small then UDim2.new(.65, 0, 0, 19) else UDim2.fromOffset(4, 82)
		row.reward.Size = if small then UDim2.new(.35, -4, 0, 17) else UDim2.new(1, -8, 0, 16)
		row.reward.Text = if row.complete then (if small then "✓" else "Earned") else (if small then "+" .. row.amount else "+" .. row.amount .. " nectar")
		Art.fitText(row.title, if small then 11 else 13, 9, 0, true)
		Art.fitText(row.count, if small then 11 else 16, 9, 0, false)
		Art.fitText(row.reward, 11, 9, 0, false)
	end
	self.dailyHint.Position = UDim2.fromOffset(8, dailyHeight + 12)
	for key, page in pairs(self.pages) do page.Size = UDim2.new(1, -6, 0, self.pageHeights[key]) end
	self.body.CanvasSize = UDim2.fromOffset(0, self.pageHeights[self.page] or 0)
	self.body.CanvasPosition = Vector2.new(0, math.clamp(self.body.CanvasPosition.Y, 0, math.max(0, self.body.CanvasSize.Y.Offset - self.body.AbsoluteSize.Y)))
	self:refreshScrollCue()
end

function Menu:refreshScrollCue()
	local overflow = self.body.CanvasSize.Y.Offset > self.body.AbsoluteSize.Y + 1
	self.body.ScrollingEnabled = overflow
	self.body.ScrollBarImageTransparency = if overflow then 0 else 1
	self.moreCue.Visible = overflow and self.body.CanvasPosition.Y + self.body.AbsoluteSize.Y < self.body.CanvasSize.Y.Offset - 1
end

function Menu:update(state, selected, runFamily, score, chain, best, recipeId)
	state = state or {}; self.state = state
	self.nectar.Text = tostring(state.nectar or 0) .. " nectar"
	local recipe = Catalog.ById[recipeId] or Catalog.ById.meadow
	self.recipe.Text = recipe.name .. " · " .. (state.nectar or 0) .. "/" .. recipe.cost .. " nectar"
	local egg = self.recipePanel:FindFirstChild("Egg")
	if egg and egg:GetAttribute("RecipeId") ~= (recipeId or "meadow") then
		egg:Destroy(); EggArt.create(self.recipePanel, recipeId or "meadow", UDim2.fromOffset(7, 5), UDim2.fromOffset(25, 34), self.recipePanel.ZIndex + 1)
	end
	self.dailyButton.Text = if state.dailyAvailable then "Daily gift +" .. (state.dailyBonus or 6) else "Gift claimed"
	self.dailyButton.Interactable = state.dailyAvailable == true and state.status == "Ready"
	self.dailyButton.BackgroundColor3 = if self.dailyButton.Interactable then Art.Amber else Art.Raised
	self.dailyButton.TextColor3 = if self.dailyButton.Interactable then Art.Ink else Art.Muted
	self.dailyHint.Text = if state.dailyAvailable then "Claim your separate daily gift above. Contracts pay automatically after a round."
		else "Daily gift claimed. Finish rounds to complete these contracts; fresh goals arrive tomorrow."
	for index, row in ipairs(self.dailyCards) do
		local contract = state.contracts and state.contracts[index]
		local progress, target = if contract then contract.progress or 0 else 0, if contract then contract.target or 1 else 1
		row.title.Text = if contract then contract.name or contract.title or contract.id else "First pet unlocks"
		row.count.Text = string.format("%d/%d", math.min(progress, target), target)
		row.complete, row.amount = contract and (contract.claimed or contract.complete) == true or false, if contract then contract.reward or 0 else 0
		row.fill.Size = UDim2.fromScale(math.clamp(progress / math.max(1, target), 0, 1), 1)
		row.fill.BackgroundColor3 = if row.complete then Art.Amber else Art.Leaf
	end
	for family, b in pairs(self.families) do
		local owned = false
		for _, pet in ipairs(Pets.collection) do if (pet.family or pet.id) == family and Catalog.isOwned(state.inventoryMask, pet.id) then owned = true end end
		local points = state.mastery and state.mastery[family] or 0
		local detail = state.masteryDetails and state.masteryDetails[family]
		local rank = if detail then detail.rank else (state.masteryRanks and state.masteryRanks[family] or 0)
		local missing = detail and detail.missingChallenges
		self.familyHints[family].Text = if not owned then "Hatch a member of this family to begin mastery."
			elseif rank >= 3 then "Family mastered\nBloom family effect unlocked"
			elseif detail and detail.nextGoal then "Next: " .. detail.nextGoal
				.. (if rank == 2 and missing and #missing > 0 then "\nStill needed: " .. table.concat(missing, " · ") else "")
				.. (if detail.rewardHint then "\n" .. detail.rewardHint else "")
			else "I badge · II finish · III family effect"
		b.Interactable, b.BackgroundColor3 = owned and state.status == "Ready", if selected == family then Art.Canopy else Art.Raised
		FamilyCrest.update(b.FamilyCrest, family, rank, not owned)
		b.Text = names[family] .. (if selected == family then " ✓" else ""); b.FamilyName.Text = b.Text
		self.familyText[family].Text = if not owned then "Discover a family member in eggs"
			elseif rank >= 3 then string.format("Rank III · mastered\n%d total marks", points)
			else string.format("Rank %s · %d/%d marks", ({ [0] = "—", "I", "II", "III" })[rank] or "III", points, if rank == 0 then 3 elseif rank == 1 then 10 else 25)
	end
	self.familyNote.Text = "Next: " .. (names[selected] or "Pip") .. " · This round: " .. (names[runFamily] or "Pip") .. ". Wins +1, clean +2; duplicates +1."
	self.card:SetAttribute("RunScore", score or 0); self.card:SetAttribute("RunChain", chain or 0); self.card:SetAttribute("PersonalBest", best or 0)
	self:layoutContents()
end

function Menu:setPage(key)
	if not self.pages[key] then return end
	self.page = key
	for name, page in pairs(self.pages) do page.Visible = name == key end
	for name, tab in pairs(self.tabs) do tab.BackgroundColor3 = if name == key then Art.Canopy else Art.Raised end
	self.resumeButton.Visible, self.dailyButton.Visible = key == "play", key == "daily"
	self.body.CanvasPosition = Vector2.zero
	self:layoutContents()
end
function Menu:open()
	self.shade.Visible = true; self:layout()
	if string.match(game:GetService("UserInputService"):GetLastInputType().Name, "^Gamepad") then GuiService.SelectedObject = self.closeButton end
end
function Menu:close()
	self.shade.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade) then GuiService.SelectedObject = nil end
end
return Menu
