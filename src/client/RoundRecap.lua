local Art = require(script.Parent.DeckArt)
local Daily = require(game:GetService("ReplicatedStorage").Shared.DailyContracts)

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

function Recap.new(parent)
	local frame = Art.frame(parent, "Recap", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 11)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	local stats = Art.frame(frame, "Stats", Art.Ink, UDim2.fromOffset(12, 46), UDim2.new(1, -24, 1, -136))
	stats.BackgroundTransparency = 1
	local values = {}
	for index, caption in ipairs({ "SCORE / BEST", "BEST CHAIN", "TIER V CLEARS" }) do
		local tile = Art.frame(stats, "Stat" .. index, Art.Ink, UDim2.new((index - 1) / 3, 2, 0, 0),
			UDim2.new(1 / 3, -4, 1, 0))
		Art.corner(tile, 5)
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
	local receipt = Instance.new("ScrollingFrame")
	receipt.Name, receipt.BackgroundTransparency, receipt.BorderSizePixel = "Receipt", 1, 0
	receipt.ScrollBarThickness, receipt.ScrollBarImageColor3 = 3, Art.Leaf
	receipt.ZIndex = goal.ZIndex + 1
	receipt.ScrollingDirection, receipt.ElasticBehavior = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.Never
	receipt.Visible, receipt.Parent = false, goal
	return setmetatable({ frame = frame, stats = stats, goal = goal, values = values, title = title, detail = detail,
		fill = fill, receiptScroll = receipt, receiptRows = {} }, Recap)
end

function Recap:height(available)
	return if self.frame.Visible then math.clamp(available - 10, 178, 236) else 236
end

function Recap:update(score, peakChain, clears, nextPet, charge, nextRare, rareProgress, best)
	self.values[1].Text = string.format("%d / %d", score, best or 0)
	self.values[2].Text = "×" .. peakChain
	self.values[3].Text = tostring(clears)
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
	local saving = result.status ~= "Saved"
	local loading = not saving and result.receiptPending == true
	local reward = if not saving and not loading then result.reward else nil
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
	if reward then
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
	self.fill.Parent.Visible = false
	self:layoutField(self.frame.AbsoluteSize.Y)
end

function Recap:scrollReceipt(direction)
	if not self.hasReceipt or not self.frame.Visible or not self.receiptScroll.Visible or type(direction) ~= "number" or direction == 0 then return false end
	local scroll = self.receiptScroll
	local rowHeight = self.receiptRowHeight or 24
	local page = math.max(rowHeight, math.floor(scroll.AbsoluteSize.Y / rowHeight) * rowHeight)
	local maximum = math.max(0, scroll.CanvasSize.Y.Offset - scroll.AbsoluteSize.Y)
	local current = scroll.CanvasPosition.Y
	local nextPosition = math.clamp(current + (if direction > 0 then page else -page), 0, maximum)
	scroll.CanvasPosition = Vector2.new(0, nextPosition)
	return nextPosition ~= current
end

function Recap:layoutField(height)
	if self.hasReceipt then
		local statsHeight = if height >= 236 then 34 else 0
		self.stats.Visible = statsHeight > 0
		self.stats.Position, self.stats.Size = UDim2.fromOffset(12, 42), UDim2.new(1, -24, 0, statsHeight)
		local y = if statsHeight > 0 then 82 else 40
		local goalHeight = math.max(0, height - 58 - y)
		self.goal.Position, self.goal.Size, self.goal.Visible = UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, goalHeight), goalHeight > 0
		local headingHeight = if goalHeight < 45 then 14 else 18
		self.title.Position, self.title.Size = UDim2.fromOffset(6, 0), UDim2.new(1, -12, 0, headingHeight)
		self.receiptScroll.Position = UDim2.fromOffset(2, headingHeight)
		self.receiptScroll.Size = UDim2.new(1, -4, 1, -headingHeight - 2)
		local rowHeight = if height < 160 then 14 else 24
		self.receiptRowHeight = rowHeight
		for index, row in ipairs(self.receiptRows) do
			row.Position, row.Size = UDim2.fromOffset(5, (index - 1) * rowHeight), UDim2.new(1, -14, 0, rowHeight)
			row:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = if rowHeight == 14 then 11 else 12
		end
		self.receiptScroll.CanvasSize = UDim2.fromOffset(0, #self.receiptRows * rowHeight)
		self.receiptScroll.ScrollingEnabled = self.receiptScroll.CanvasSize.Y.Offset > self.receiptScroll.AbsoluteSize.Y
		return
	end
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
