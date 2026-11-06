local Art = require(script.Parent.DeckArt)

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
	return setmetatable({ frame = frame, stats = stats, goal = goal, values = values, title = title, detail = detail, fill = fill }, Recap)
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
	self.fieldHeading = if result.reason == "Overflow" then "Tray overflowed"
		elseif result.success then "Both sides complete!"
		elseif result.stage == 0 then "LEFT goal missed" else "RIGHT goal missed"
	self.title.Text = if saving then (if result.status == "Saving" then "Saving your rewards…" else "Reward save delayed · retrying") else
		string.format("Nectar +%d · quest %d + daily %d", result.award, math.max(0, result.award - result.daily), result.daily)
	local balance, cost = result.balance, result.recipe.cost
	local egg = if balance >= cost then result.recipe.name .. " · ready to hatch"
		else string.format("%s · %d/%d · need %d nectar", result.recipe.name, balance, cost, cost - balance)
	local hint = if result.reason == "Overflow" then "Merge below the line to clear its warning."
		elseif result.success then "Your quest earns nectar for eggs."
		elseif result.stage == 0 then "Make II + II on LEFT, then RIGHT."
		else "LEFT is done. Make II + II on RIGHT."
	self.fullFieldDetail = if saving then "Rewards appear after saving. Please wait." else hint .. "\n" .. egg
	self.shortFieldDetail = if saving then "Please wait for your saved receipt." else egg
	self.detail.Text = self.fullFieldDetail
	self.detail.TextWrapped = true
	self.fill.Parent.Visible = false
	self:layoutField(self.frame.AbsoluteSize.Y)
end

function Recap:layoutField(height)
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
