local Art = require(script.Parent.DeckArt)
local Daily = require(game:GetService("ReplicatedStorage").Shared.DailyContracts)
local Feedback = require(script.Parent.RecapFeedback)

local familyNames = { pip = "Pip", puddle = "Puddle", wick = "Wick", orbit = "Orbit" }
local ranks = { "I", "II", "III" }

local Recap = {}
Recap.__index = Recap

local function fitText(label, maximum)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 9
	limit.MaxTextSize = maximum
	limit.Parent = label
end

function Recap.new(parent, audio, reduceEffects)
	local frame = Art.frame(parent, "Recap", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 11)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	local stats = Art.frame(frame, "Stats", Art.Ink, UDim2.fromOffset(12, 46), UDim2.new(1, -24, 1, -136))
	stats.BackgroundTransparency = 1
	local values, scales, accents = {}, {}, {}
	for index, caption in ipairs({ "SCORE / BEST", "BEST CHAIN", "TIER V CLEARS" }) do
		local tile = Art.frame(stats, "Stat" .. index, Art.Ink, UDim2.new((index - 1) / 3, 2, 0, 0),
			UDim2.new(1 / 3, -4, 1, 0))
		Art.corner(tile, 5)
		local scale = Instance.new("UIScale")
		scale.Parent = tile
		scales[index] = scale
		local accent = Art.frame(tile, "PopAccent", Art.Leaf, UDim2.new(0, 3, 1, -3), UDim2.new(1, -6, 0, 2))
		accent.BackgroundTransparency = 1
		accents[index] = accent
		fitText(Art.text(tile, "Label", caption, UDim2.fromOffset(2, 2), UDim2.new(1, -4, 0, 12),
			Art.Muted, 11), 11)
		local value = Art.text(tile, "Value", "", UDim2.fromOffset(3, 14), UDim2.new(1, -6, 1, -16),
			if index == 1 then Art.Amber else Art.Silver, 26)
		fitText(value, 26)
		values[index] = value
	end
	local goal = Art.frame(frame, "Goal", Art.Raised, UDim2.new(0, 12, 1, -88), UDim2.new(1, -24, 0, 30))
	Art.corner(goal, 5)
	local title = Art.text(goal, "Heading", "", UDim2.fromOffset(6, 1), UDim2.new(1, -12, 0, 14),
		Art.Cyan, 13, Enum.Font.GothamBold)
	fitText(title, 13)
	local detail = Art.text(goal, "Progress", "", UDim2.fromOffset(6, 15), UDim2.new(1, -12, 0, 12), Art.Silver, 12)
	fitText(detail, 12)
	local track = Art.frame(goal, "Track", Art.Ink, UDim2.new(0, 6, 1, -4), UDim2.new(1, -12, 0, 2))
	local fill = Art.frame(track, "Fill", Art.Cyan, UDim2.fromOffset(0, 0), UDim2.fromScale(0, 1))
	local nectarIcon = Art.frame(goal, "NectarIcon", Art.Amber, UDim2.fromOffset(7, 4), UDim2.fromOffset(14, 18))
	Art.corner(nectarIcon, 8)
	Art.leaf(nectarIcon, "Leaf", UDim2.fromOffset(6, -3), UDim2.fromOffset(8, 5), Art.Leaf, -25)
	nectarIcon.Visible = false
	local earnedGraphic = Art.text(goal, "EarnedNectar", "+0 NECTAR", UDim2.fromOffset(27, 0), UDim2.new(.52, -28, 0, 26), Art.Amber, 26, Enum.Font.GothamBold)
	fitText(earnedGraphic, 26)
	earnedGraphic.TextXAlignment = Enum.TextXAlignment.Left
	local bankGraphic = Art.text(goal, "SavedEggBank", "", UDim2.new(.52, 0, 0, 0), UDim2.new(.48, -6, 0, 26), Art.Leaf, 13, Enum.Font.GothamBold)
	fitText(bankGraphic, 13)
	earnedGraphic.Visible, bankGraphic.Visible = false, false
	local detailsButton = Instance.new("TextButton")
	detailsButton.Name, detailsButton.Text, detailsButton.Size = "Details", "Details", UDim2.fromOffset(90, 44)
	detailsButton.BackgroundColor3, detailsButton.TextColor3 = Art.Ink, Art.Silver
	detailsButton.Font, detailsButton.TextSize, detailsButton.BorderSizePixel = Enum.Font.GothamBold, 14, 0
	detailsButton.ZIndex, detailsButton.Visible, detailsButton.Parent = goal.ZIndex + 3, false, goal
	Art.button(detailsButton, 8); Art.fitText(detailsButton, 14, 10, 4, false)
	local summary = Art.frame(goal, "RewardChips", Art.Raised, UDim2.fromOffset(6, 52), UDim2.new(1, -12, 1, -54))
	summary.BackgroundTransparency, summary.Visible = 1, false
	local componentLabels = {}
	for index, caption in ipairs({ "Quest", "Daily" }) do
		local chip = Art.frame(summary, caption .. "Chip", Art.Ink, UDim2.new((index - 1) * .5, 1, 0, 0), UDim2.new(.5, -3, 0, 36))
		Art.corner(chip, 8)
		local label = Art.text(chip, "Value", caption .. " +0", UDim2.fromOffset(4, 0), UDim2.new(1, -8, 1, 0), if index == 1 then Art.Leaf else Art.Amber, 18, Enum.Font.GothamBold)
		fitText(label, 18)
		componentLabels[index] = label
	end
	local eggGoal = Art.text(summary, "EggGoal", "", UDim2.fromOffset(4, 40), UDim2.new(1, -8, 0, 32), Art.Silver, 13)
	fitText(eggGoal, 13)
	eggGoal.TextWrapped = true
	local transfer = Art.frame(goal, "NectarTransfer", Art.Amber, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), goal.ZIndex + 4)
	transfer.BackgroundTransparency, transfer.Visible = 1, false
	local chips = {}
	for index = 1, 6 do
		local chip = Art.frame(transfer, "Drop" .. index, Art.Amber, UDim2.fromOffset(0, 0), UDim2.fromOffset(7, 10))
		Art.corner(chip, 5)
		chip.Visible = false
		chips[index] = chip
	end
	local receipt = Instance.new("ScrollingFrame")
	receipt.Name, receipt.BackgroundTransparency, receipt.BorderSizePixel = "Receipt", 1, 0
	receipt.ScrollBarThickness, receipt.ScrollBarImageColor3 = 3, Art.Leaf
	receipt.ZIndex = goal.ZIndex + 1
	receipt.ScrollingDirection, receipt.ElasticBehavior = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.Never
	receipt.Visible, receipt.Parent = false, goal
	local self = setmetatable({ frame = frame, stats = stats, goal = goal, values = values, title = title, detail = detail,
		fill = fill, receiptScroll = receipt, receiptRows = {}, scales = scales, accents = accents,
		nectarIcon = nectarIcon, earnedGraphic = earnedGraphic, bankGraphic = bankGraphic, transfer = transfer, chips = chips,
		detailsButton = detailsButton, summary = summary, componentLabels = componentLabels, eggGoal = eggGoal }, Recap)
	detailsButton.Activated:Connect(function() self:setDetails(not self.detailsOpen) end)
	self.feedback = Feedback.new(function(sample) self:paintFeedback(sample) end, audio, reduceEffects)
	-- Any hidden ancestor also ends the sequence; returning to this receipt shows
	-- final values and cannot replay its sound or transfer.
	local ancestor = frame
	self.visibilityConnections = {}
	while ancestor and ancestor:IsA("GuiObject") do
		local object = ancestor
		table.insert(self.visibilityConnections, object:GetPropertyChangedSignal("Visible"):Connect(function()
			if not object.Visible then self.feedback:cancel(); self.fieldMode = false end
		end))
		ancestor = ancestor.Parent
	end
	frame.Destroying:Connect(function()
		self.feedback:cancel()
		for _, connection in ipairs(self.visibilityConnections) do connection:Disconnect() end
	end)
	return self
end

function Recap:isVisible()
	local object = self.frame
	while object and object:IsA("GuiObject") do
		if not object.Visible then return false end
		object = object.Parent
	end
	return self.frame.Parent ~= nil
end

function Recap:paintFeedback(sample)
	self.presentation = sample
	local targets = self.statTargets
	if targets then
		for index, target in ipairs(targets) do
			local progress = if sample then sample.stats[index] else 1
			local number = math.floor(target * (1 - (1 - progress) ^ 3) + .0001)
			self.values[index].Text = if index == 1 then string.format("%d / %d", number, self.statBest or 0)
				elseif index == 2 then "×" .. number else tostring(number)
			local pop = if progress > 0 and progress < 1 then math.sin(progress * math.pi) else 0
			self.scales[index].Scale = 1 + pop * .075
			self.accents[index].BackgroundTransparency = 1 - pop * .8
			self.values[index].TextTransparency = if sample then (1 - progress) * .25 else 0
			self.values[index].Position = UDim2.fromOffset(3 + (1 - progress) * 7, 14)
		end
	end
	if self.displayReward ~= nil then
		local amount = if sample then math.floor(self.displayReward * sample.earned) else self.displayReward
		self.earnedGraphic.Text = string.format("+%d NECTAR", amount)
		self.bankGraphic.Text = string.format("Egg bank %d/%d", self.displayBalance, self.displayCost)
	end
	if self.finalTitle then
		self.title.Text = if sample and self.displayReward then
			string.format("Nectar +%d · Egg bank %d/%d", math.floor(self.displayReward * sample.earned), self.displayBalance, self.displayCost)
			else self.finalTitle
	end
	self.transfer.Visible = sample ~= nil and self.hasReceipt == true and (self.displayReward or 0) > 0
	local landed = false
	local tall = (self.layoutHeight or 0) >= 300
	local destinationX, destinationY = if tall then .55 else .87, if tall then 32 else 5
	for index, chip in ipairs(self.chips) do
		local phase = if sample then math.clamp(sample.transfer * 1.65 - (index - 1) * .12, 0, 1) else 0
		chip.Visible = self.transfer.Visible and index <= math.min(6, self.displayReward or 0) and phase > 0 and phase < 1
		chip.Position = UDim2.new(.12 + (destinationX - .12) * phase, -3, 0, 5 + (destinationY - 5) * phase + math.sin(phase * math.pi) * 9)
		chip.Rotation = -15 + phase * 30
		chip.BackgroundTransparency = phase * .4
		if sample and phase > .85 and phase < 1 then landed = true end
	end
	self.nectarIcon.Rotation = if landed then -8 else 0
	self.bankGraphic.TextColor3 = if landed then Art.Amber else Art.Leaf
	self.fill.BackgroundColor3 = if landed then Art.Amber else Art.Cyan
end

function Recap:height(available)
	return if self.frame.Visible then math.clamp(available - 10, 178, 236) else 236
end

function Recap:update(score, peakChain, clears, nextPet, charge, nextRare, rareProgress, best)
	self.statTargets, self.statBest = { score, peakChain, clears }, best or 0
	-- Field recaps own their animated/pinned title. This function is also used by
	-- legacy welcome recaps and is called on every HUD refresh.
	if self.fieldMode and self.frame.Visible then self:paintFeedback(self.presentation); return end
	self.finalTitle, self.displayReward = nil, nil
	self.title.Visible, self.detail.Visible = true, true
	self.earnedGraphic.Visible, self.bankGraphic.Visible, self.nectarIcon.Visible, self.receiptScroll.Visible = false, false, false, false
	self.detailsButton.Visible, self.summary.Visible = false, false
	self:paintFeedback(self.presentation)
	local progress = 1
	if nextPet then
		local needed = nextPet.charge
		self.title.Text = "Next hatch · " .. nextPet.name
		self.detail.Text = string.format("%d/%d charge · %d to go", charge, needed, math.max(0, needed - charge))
		progress = charge / needed
	elseif nextRare then
		local trial = nextRare.trial
		self.title.Text = nextRare.name .. " · this round"
		self.detail.Text = string.format("%s %d/%d · resets on retry", trial.readout, rareProgress, trial.target)
		progress = rareProgress / trial.target
	else
		self.title.Text = "Collection complete"
		self.detail.Text = string.format("Next run · beat %d points", best)
	end
	self.fill.Parent.Visible = nextPet ~= nil or nextRare ~= nil
	self.fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
end

function Recap:updateField(result)
	self.fieldMode = true
	local saving = result.status ~= "Saved"
	local loading = not saving and result.receiptPending == true
	local reward = if not saving and not loading then result.reward else nil
	if reward and result.sequence ~= nil and reward.sequence ~= result.sequence then reward = nil; loading = true end
	self.hasReceipt = reward ~= nil
	self.fieldHeading = if result.reason == "Overflow" then "Tray overflowed"
		elseif result.success then "Both sides complete!"
		elseif result.stage == 0 then "LEFT goal missed" else "RIGHT goal missed"
	self.title.Text = if loading then "Loading receipt…"
		elseif saving then (if result.status == "Saving" then "Saving your rewards…" else "Reward save delayed · retrying") else
		string.format("Nectar +%d · quest %d + daily %d", result.award, math.max(0, result.award - result.daily), result.daily)
	local balance, cost = result.balance, result.recipe.cost
	local egg = if balance >= cost then result.recipe.name .. " · ready to hatch"
		else string.format("%s · %d/%d · need %d nectar", result.recipe.name, balance, cost, cost - balance)
	local hint = if result.reason == "Overflow" then "Merge below the line to clear its warning."
		elseif result.success then "Your quest earns nectar for eggs."
		elseif result.stage == 0 then "Make II + II on LEFT, then RIGHT."
		else "LEFT is done. Make II + II on RIGHT."
	self.fullFieldDetail = if loading then "Waiting for this round's saved receipt."
		elseif saving then "Rewards appear after saving. Please wait." else hint .. "\n" .. egg
	self.shortFieldDetail = if loading then "Waiting for this round's saved receipt."
		elseif saving then "Please wait for your saved receipt." else egg
	self.detail.Text = self.fullFieldDetail
	self.detail.TextWrapped = true
	self.detail.Visible, self.receiptScroll.Visible = not self.hasReceipt, self.hasReceipt
	self.nectarIcon.Visible = self.hasReceipt
	if reward then
		if self.detailsSequence ~= reward.sequence then self.detailsOpen = false; self.detailsSequence = reward.sequence end
		self.componentLabels[1].Text = string.format("Quest +%d", reward.base or 0)
		self.componentLabels[2].Text = string.format("Daily +%d", reward.daily or 0)
		self.eggGoal.Text = egg
		-- The total and saved egg balance remain pinned while the receipt scrolls.
		self.title.Text = string.format("Nectar +%d · Egg bank %d/%d", reward.total, balance, cost)
		local lines = { string.format("Quest nectar +%d", reward.base or 0), string.format("Daily contracts total +%d", reward.daily or 0) }
		if not result.success then
			table.insert(lines, if result.reason == "Overflow" and result.stage >= 2 then "Both sides done · clear the overflow line"
				elseif result.reason == "Overflow" then "Clear the overflow warning before retrying"
				elseif result.stage == 0 then "Next round: match on LEFT, then RIGHT"
				elseif result.stage == 1 then "LEFT done · match on RIGHT next round"
				else "Both sides done · survive all 24 drops")
		end
		for _, id in ipairs(reward.contracts or {}) do
			for _, contract in ipairs(Daily.Definitions) do
				if contract.id == id then table.insert(lines, string.format("%s · %d nectar", contract.title, contract.reward)); break end
			end
		end
		local family = familyNames[reward.family] or reward.family or "Family"
		local marks = reward.masteryPoints or 0
		table.insert(lines, if marks > 0 then string.format("%s mastery +%d %s", family, marks, if marks == 1 then "mark" else "marks")
			else "No family marks · finish quest and 24 drops")
		if (reward.promotedTo or 0) > 0 then table.insert(lines, family .. " rank " .. (ranks[reward.promotedTo] or "III") .. " unlocked!") end
		local mastery = result.mastery
		if mastery then
			table.insert(lines, family .. " next: " .. mastery.nextGoal)
			if mastery.rank == 2 and mastery.missingChallenges and #mastery.missingChallenges > 0 then
				table.insert(lines, "Rank III still needs:")
				for _, condition in ipairs(mastery.missingChallenges) do table.insert(lines, condition) end
			end
			if mastery.rewardHint then table.insert(lines, mastery.rewardHint) end
		end
		table.insert(lines, result.recipe.name .. " · costs " .. cost .. " nectar")
		table.insert(lines, if balance >= cost then "Ready to hatch · " .. balance .. "/" .. cost .. " nectar"
			else string.format("%d/%d nectar · need %d more", balance, cost, cost - balance))
		local signature = table.concat(lines, "\n")
		if self.receiptSignature ~= signature then
			self.receiptSignature, self.receiptLines = signature, lines
			self.receiptScroll:ClearAllChildren()
			self.receiptRows = {}
			self.receiptScroll.CanvasPosition = Vector2.zero
			for index, line in ipairs(lines) do
				local row = Art.text(self.receiptScroll, "Line" .. index, line, UDim2.fromOffset(5, (index - 1) * 24),
					UDim2.new(1, -14, 0, 24), if line:find("unlocked!", 1, true) then Art.Amber else Art.Silver, 12)
				row.TextXAlignment, row.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
				Art.fitText(row, 12, 9, 0, false)
				local padding = row:FindFirstChildOfClass("UIPadding")
				padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 0), UDim.new(0, 0)
				table.insert(self.receiptRows, row)
			end
			self.receiptScroll.CanvasSize = UDim2.fromOffset(0, #lines * 24)
		end
	else
		self.receiptLines, self.receiptSignature = nil, nil
		self.receiptScroll:ClearAllChildren()
		self.receiptRows = {}
	end
	self.finalTitle = self.title.Text
	self.displayReward, self.displayBalance, self.displayCost = if reward then reward.total else nil, balance, cost
	-- This bar always represents the committed snapshot, even while decorative
	-- earned drops travel towards the bank. No transient balance is invented.
	self.fill.Parent.Visible = self.hasReceipt
	self.fill.Size = UDim2.fromScale(math.clamp(balance / cost, 0, 1), 1)
	self:layoutField(self.frame.AbsoluteSize.Y)
	self.feedback:observe(result, self:isVisible())
	self:paintFeedback(if self.feedback.active then self.presentation else nil)
end

function Recap:scrollReceipt(direction)
	if not self.hasReceipt or not self.frame.Visible or type(direction) ~= "number" or direction == 0 then return false end
	if self.detailsButton.Visible and not self.detailsOpen then self:setDetails(true); return true end
	if not self.receiptScroll.Visible then return false end
	local scroll = self.receiptScroll
	local rowHeight = self.receiptRowHeight or 24
	local page = math.max(rowHeight, math.floor(scroll.AbsoluteSize.Y / rowHeight) * rowHeight)
	local maximum = math.max(0, scroll.CanvasSize.Y.Offset - scroll.AbsoluteSize.Y)
	local current = scroll.CanvasPosition.Y
	local nextPosition = math.clamp(current + (if direction > 0 then page else -page), 0, maximum)
	scroll.CanvasPosition = Vector2.new(0, nextPosition)
	return nextPosition ~= current
end

function Recap:setDetails(open)
	self.detailsOpen = open == true
	self:layoutField(self.layoutHeight or self.frame.AbsoluteSize.Y)
end

function Recap:layoutField(height)
	self.layoutHeight = height
	if self.hasReceipt then
		local tall = height >= 300
		local statsHeight = if tall then 58 elseif height >= 236 then 34 else 0
		self.stats.Visible = statsHeight > 0
		self.stats.Position, self.stats.Size = UDim2.fromOffset(12, 42), UDim2.new(1, -24, 0, statsHeight)
		local y = if tall then 106 elseif statsHeight > 0 then 82 else 40
		local goalHeight = math.max(0, height - 58 - y)
		self.goal.Position, self.goal.Size, self.goal.Visible = UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, goalHeight), goalHeight > 0
		local headingHeight = if goalHeight < 45 then 14 else 26
		self.title.Visible = goalHeight < 45
		self.earnedGraphic.Visible, self.bankGraphic.Visible = goalHeight >= 45, goalHeight >= 45
		self.title:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = if goalHeight < 45 then 13 else 22
		local iconWidth = if goalHeight < 45 then 11 else 17
		self.nectarIcon.Position, self.nectarIcon.Size = UDim2.fromOffset(5, 2), UDim2.fromOffset(iconWidth, headingHeight - 3)
		self.title.Position, self.title.Size = UDim2.fromOffset(iconWidth + 9, 0), UDim2.new(1, -iconWidth - 15, 0, headingHeight)
		self.fill.Parent.Position, self.fill.Parent.Size = UDim2.fromOffset(6, headingHeight), UDim2.new(1, -12, 0, 2)
		self.receiptScroll.Position = UDim2.fromOffset(2, headingHeight + 2)
		self.receiptScroll.Size = UDim2.new(1, -4, 1, -headingHeight - 4)
		self.detailsButton.Visible, self.summary.Visible = tall, tall and not self.detailsOpen
		self.detailsButton.Text = if self.detailsOpen then "Less" else "Details"
		self.detailsButton.Position = UDim2.new(1, -96, 0, 0)
		self.receiptScroll.Visible = not tall or self.detailsOpen == true
		if tall then
			self.earnedGraphic.Position, self.earnedGraphic.Size = UDim2.fromOffset(27, 0), UDim2.new(1, -129, 0, 28)
			self.bankGraphic.Position, self.bankGraphic.Size = UDim2.fromOffset(27, 28), UDim2.new(1, -129, 0, 16)
			self.fill.Parent.Position = UDim2.fromOffset(6, 46)
			self.receiptScroll.Position, self.receiptScroll.Size = UDim2.fromOffset(2, 50), UDim2.new(1, -4, 1, -52)
		else
			self.earnedGraphic.Position, self.earnedGraphic.Size = UDim2.fromOffset(27, 0), UDim2.new(.52, -28, 0, 26)
			self.bankGraphic.Position, self.bankGraphic.Size = UDim2.new(.52, 0, 0, 0), UDim2.new(.48, -6, 0, 26)
		end
		local rowHeight = if height < 160 then 12 else 24
		self.receiptRowHeight = rowHeight
		for index, row in ipairs(self.receiptRows) do
			row.Position, row.Size = UDim2.fromOffset(5, (index - 1) * rowHeight), UDim2.new(1, -14, 0, rowHeight)
			row:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = if rowHeight == 12 then 10 else 12
		end
		self.receiptScroll.CanvasSize = UDim2.fromOffset(0, #self.receiptRows * rowHeight)
		self.receiptScroll.ScrollingEnabled = self.receiptScroll.CanvasSize.Y.Offset > self.receiptScroll.AbsoluteSize.Y
		return
	end
	self.title:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 13
	self.detailsButton.Visible, self.summary.Visible = false, false
	self.title.Visible = true
	self.earnedGraphic.Visible, self.bankGraphic.Visible = false, false
	self.nectarIcon.Visible = false
	local statsHeight = if height >= 210 then 50 elseif height >= 190 then 34 else 0
	self.detail.Text = if height < 160 then self.shortFieldDetail or self.detail.Text else self.fullFieldDetail or self.detail.Text
	self.stats.Visible = statsHeight > 0
	self.stats.Position, self.stats.Size = UDim2.fromOffset(12, 46), UDim2.new(1, -24, 0, statsHeight)
	local y = 46 + (if statsHeight > 0 then statsHeight + 6 else 0)
	local goalHeight = math.max(0, height - 52 - y - 6)
	self.goal.Position, self.goal.Size = UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, goalHeight)
	self.goal.Visible = goalHeight >= 20
	local headingHeight = math.min(18, math.floor(goalHeight * .42))
	self.title.Position, self.title.Size = UDim2.fromOffset(6, 0), UDim2.new(1, -12, 0, headingHeight)
	self.detail.Position, self.detail.Size = UDim2.fromOffset(6, headingHeight), UDim2.new(1, -12, 1, -headingHeight - 2)
end

return Recap
