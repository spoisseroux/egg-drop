local Art = require(script.Parent.DeckArt)
local Daily = require(game:GetService("ReplicatedStorage").Shared.DailyContracts)
local Feedback = require(script.Parent.RecapFeedback)
local EggArt = require(script.Parent.EggArt)
local EggCatalog = require(game:GetService("ReplicatedStorage").Shared.EggCatalog)

local ranks = { "I", "II", "III" }

local SaveNotice=require(script.Parent.SaveNotice)
local Receipt=require(script.Parent.RunReceipt)
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
	local frame = Art.frame(parent, "Recap", "ink", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 11)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	local stats = Art.frame(frame, "Stats", "ink", UDim2.fromOffset(12, 46), UDim2.new(1, -24, 1, -136))
	stats.BackgroundTransparency = 1
	local values, scales, accents = {}, {}, {}
	for index, caption in ipairs({ "SCORE / BEST", "BEST CHAIN", "TIER V CLEARS" }) do
		local tile = Art.frame(stats, "Stat" .. index, "ink", UDim2.new((index - 1) / 3, 2, 0, 0),
			UDim2.new(1 / 3, -4, 1, 0))
		Art.corner(tile, 5)
		local scale = Instance.new("UIScale")
		scale.Parent = tile
		scales[index] = scale
		local accent = Art.frame(tile, "PopAccent", Art.Leaf, UDim2.new(0, 3, 1, -3), UDim2.new(1, -6, 0, 2))
		accent.BackgroundTransparency = 1
		accents[index] = accent
		fitText(Art.text(tile, "Label", caption, UDim2.fromOffset(2, 2), UDim2.new(1, -4, 0, 12),
			"muted", 11), 11)
		local value = Art.text(tile, "Value", "", UDim2.fromOffset(3, 14), UDim2.new(1, -6, 1, -16),
			if index == 1 then Art.Amber else "text", 26)
		fitText(value, 26)
		values[index] = value
	end
	local goal = Art.frame(frame, "Goal", "raised", UDim2.new(0, 12, 1, -88), UDim2.new(1, -24, 0, 30))
	Art.corner(goal, 5)
	local title = Art.text(goal, "Heading", "", UDim2.fromOffset(6, 1), UDim2.new(1, -12, 0, 14),
		Art.Cyan, 13, Enum.Font.GothamBold)
	fitText(title, 13)
	local detail = Art.text(goal, "Progress", "", UDim2.fromOffset(6, 15), UDim2.new(1, -12, 0, 12), "text", 12)
	fitText(detail, 12)
	local track = Art.frame(goal, "Track", "ink", UDim2.new(0, 6, 1, -4), UDim2.new(1, -12, 0, 2))
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
	Art.bind(detailsButton,{BackgroundColor3="ink",TextColor3="text"});Art.button(detailsButton, 8); Art.fitText(detailsButton, 14, 10, 4, false)
	local summary = Art.frame(goal, "RewardChips", "raised", UDim2.fromOffset(6, 52), UDim2.new(1, -12, 1, -54))
	summary.BackgroundTransparency, summary.Visible = 1, false
	local componentLabels = {}
	for index, caption in ipairs({ "Quest", "Daily" }) do
		local chip = Art.frame(summary, caption .. "Chip", "ink", UDim2.new((index - 1) * .5, 1, 0, 0), UDim2.new(.5, -3, 0, 36))
		Art.corner(chip, 8)
		local label = Art.text(chip, "Value", caption .. " +0", UDim2.fromOffset(4, 0), UDim2.new(1, -8, 1, 0), if index == 1 then Art.Leaf else Art.Amber, 18, Enum.Font.GothamBold)
		fitText(label, 18)
		componentLabels[index] = label
	end
	local eggGoal = Art.text(summary, "EggGoal", "", UDim2.fromOffset(4, 40), UDim2.new(1, -8, 0, 32), "text", 13)
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
	-- Field receipts have one scrolling center. The outcome and decision footer are outside it.
	local body=Instance.new("ScrollingFrame")
	body.Name,body.BackgroundTransparency,body.BorderSizePixel,body.ZIndex="FieldBody",1,0,frame.ZIndex+1
	body.ScrollBarThickness,body.ScrollBarImageColor3=4,Art.Leaf
	body.ScrollingDirection,body.ElasticBehavior=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never
	body.Visible,body.Parent=false,frame
	local eggPanel=Art.frame(goal,"SelectedEgg","inset",UDim2.fromOffset(0,88),UDim2.new(1,0,0,116),goal.ZIndex+1)
	Art.corner(eggPanel,12);eggPanel.Visible=false
	local eggDrawing=Art.frame(eggPanel,"ArtWell","inset",UDim2.fromOffset(10,10),UDim2.fromOffset(52,76),eggPanel.ZIndex+1)
	eggDrawing.BackgroundTransparency=1
	local shortfall=Art.text(eggPanel,"Shortfall","",UDim2.fromOffset(76,66),UDim2.new(1,-88,0,24),"muted",14)
	local personalBest=Art.frame(stats,"PersonalBest","ink",UDim2.fromOffset(0,0),UDim2.fromOffset(100,64))
	personalBest.BackgroundTransparency=1
	local bestCaption=Art.text(personalBest,"Label","Personal best",UDim2.fromOffset(0,0),UDim2.new(1,0,0,24),"muted",14)
	local bestValue=Art.text(personalBest,"Value","0",UDim2.fromOffset(0,26),UDim2.new(1,0,0,32),"text",24,Enum.Font.GothamBold)
	personalBest.Visible=false
	local promotion=Art.text(goal,"FamilyPromotion","",UDim2.fromOffset(4,0),UDim2.new(1,-8,0,24),Art.Leaf,12)
	promotion.TextXAlignment=Enum.TextXAlignment.Left;promotion.Visible=false
	local self = setmetatable({ promotionLabel=promotion, frame = frame, stats = stats, goal = goal, values = values, title = title, detail = detail,
		fill = fill, receiptScroll = receipt, receiptRows = {}, scales = scales, accents = accents,
		nectarIcon = nectarIcon, earnedGraphic = earnedGraphic, bankGraphic = bankGraphic, transfer = transfer, chips = chips,
		detailsButton = detailsButton, summary = summary, componentLabels = componentLabels, eggGoal = eggGoal,
		fieldBody=body,eggPanel=eggPanel,eggDrawing=eggDrawing,shortfall=shortfall,bestMetric=personalBest,bestCaption=bestCaption,bestValue=bestValue }, Recap)
	detailsButton.Activated:Connect(function() self:activateDetails() end)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if self.fieldMode then self:layoutField(frame.AbsoluteSize.Y) end end)
	Art.watchTextPreference(frame,function()return self:isVisible()end,function()if self.onPreferredLayout then self.onPreferredLayout() else self:layoutField(frame.AbsoluteSize.Y) end end)
	self.saveDetail=Art.text(body,"SaveInstruction","",UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),Art.Amber,14)
	self.saveDetail.TextXAlignment,self.saveDetail.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Top
	self.saveDetail.Visible=false
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
			self.values[index].Text = if index == 1 then (if self.fieldMode then tostring(number) else string.format("%d / %d", number, self.statBest or 0))
				elseif index == 2 then "×" .. number else tostring(number)
			local pop = if progress > 0 and progress < 1 then math.sin(progress * math.pi) else 0
			self.scales[index].Scale = 1 + pop * .075
			self.accents[index].BackgroundTransparency = 1 - pop * .8
			self.values[index].TextTransparency = if sample then (1 - progress) * .25 else 0
			self.values[index].Position = UDim2.fromOffset(3 + (1 - progress) * 7, if self.fieldMode then 26 else 14)
		end
	end
	if self.displayReward ~= nil then
		local amount = if sample then math.floor(self.displayReward * sample.earned) else self.displayReward
		self.earnedGraphic.Text = string.format("+%d nectar", amount)
		self.bankGraphic.Text = string.format("Nectar saved: %d", self.displayBalance)
	end
	if self.finalTitle then
		self.title.Text = if sample and self.displayReward then
			string.format("Nectar +%d · Saved %d/%d", math.floor(self.displayReward * sample.earned), self.displayBalance, self.displayCost)
			else self.finalTitle
	end
	self.transfer.Visible = sample ~= nil and self.hasReceipt == true and (self.displayReward or 0) > 0
	local landed = false
	local tall = (self.layoutHeight or 0) >= 300
	local destinationX, destinationY = .55, 135
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
	self.fieldBody.Visible,self.eggPanel.Visible,self.bestMetric.Visible=false,false,false
	self.goal.Parent,self.stats.Parent=self.frame,self.frame
	self.goal.BackgroundTransparency=0
	if not self.title:FindFirstChildOfClass("UITextSizeConstraint") then fitText(self.title,13) end
	if not self.detail:FindFirstChildOfClass("UITextSizeConstraint") then fitText(self.detail,12) end
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
	self.updatingField = true
	local saving = result.status ~= "Saved"
	local loading = not saving and result.receiptPending == true
	local reward = if not saving and not loading then result.reward else nil
	if reward and result.sequence ~= nil and reward.sequence ~= result.sequence then reward = nil; loading = true end
	local balance,cost=result.balance,result.recipe.cost
	local recipeId
	for id,recipe in pairs(EggCatalog.ById) do if recipe==result.recipe or recipe.name==result.recipe.name then recipeId=id;break end end
	-- Publish all canonical display data before hasReceipt or any GuiObject writes.
	self.displayRecipe,self.displayRecipeId,self.displayReward,self.displayBalance,self.displayCost=
		result.recipe,recipeId,if reward then reward.total else nil,balance,cost
	self.hasReceipt,self.fieldMode=reward~=nil,true
	self.fieldHeading=Receipt.outcome(result)
	self.promotionLabel.Text=Receipt.promotion(reward)or""
	self.title.Text = if loading then "Loading receipt…"
		elseif saving then (if result.status == "Saving" then "Saving your rewards…" else "Reward save delayed · retrying") else
		string.format("Nectar +%d · quest %d + daily %d", result.award, math.max(0, result.award - result.daily), result.daily)
	local egg = if balance >= cost then result.recipe.name .. " · ready to hatch"
		else string.format("%s · %d/%d · need %d nectar", result.recipe.name, balance, cost, cost - balance)
 local hint=if result.reason=="Overflow"and(result.stage or 0)>=2 then "Both goals done · clear the overflow line"
  elseif result.reason=="Overflow"then "Merge below the line to clear its warning."
  elseif result.success then "Both goals and 24 drops earn nectar for eggs."
  else Receipt.questHint(result)
	self.fullFieldDetail = if loading then "Waiting for this round's saved receipt."
		elseif saving then "Rewards appear after saving. Please wait." else hint .. "\n" .. egg
	self.shortFieldDetail = if loading then "Waiting for this round's saved receipt."
		elseif saving then "Please wait for your saved receipt." else egg
	self.detail.Text = self.fullFieldDetail
	self.detail.TextWrapped = true
	self.detail.Visible, self.receiptScroll.Visible = not self.hasReceipt, self.hasReceipt
	self.nectarIcon.Visible = self.hasReceipt
	if reward then
		if self.detailsSequence ~= reward.sequence then self.detailsOpen = false; self.detailsSequence = reward.sequence;self.fieldBody.CanvasPosition=Vector2.zero end
		self.componentLabels[1].Text = string.format("Quest +%d", reward.base or 0)
		self.componentLabels[2].Text = string.format("Daily +%d", reward.daily or 0)
		self.eggGoal.Text = egg
		-- The total and saved egg balance remain pinned while the receipt scrolls.
		self.title.Text = string.format("Nectar +%d · Saved %d/%d", reward.total, balance, cost)
		local lines = { string.format("Quest nectar +%d", reward.base or 0), string.format("Daily contracts total +%d", reward.daily or 0) }
		if self.statTargets then
			table.insert(lines,"Score "..self.statTargets[1].." · Personal best "..(self.statBest or 0))
			table.insert(lines,"Longest chain ×"..self.statTargets[2].." · Tier V clears "..self.statTargets[3])
		end
  local fieldDetails=Receipt.questDetails(result)
  if fieldDetails then table.insert(lines,fieldDetails)end
  if not result.success then table.insert(lines,Receipt.questHint(result))end
		for _, id in ipairs(reward.contracts or {}) do
			for _, contract in ipairs(Daily.Definitions) do
				if contract.id == id then table.insert(lines, string.format("%s · %d nectar", contract.title, contract.reward)); break end
			end
		end
		local family = Receipt.familyName(reward.family)
		local marks = reward.masteryPoints or 0
		table.insert(lines, if marks > 0 then string.format("%s mastery +%d %s", family, marks, if marks == 1 then "mark" else "marks")
			else "No family marks · finish both goals and 24 drops")
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
					UDim2.new(1, -14, 0, 24), if line:find("unlocked!", 1, true) then Art.Amber else "text", 12)
				row.TextXAlignment, row.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
				Art.type(row,"Body",false)
				row.TextWrapped=true
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
	self.updatingField=false
	local height=self.pendingFieldHeight or self.frame.AbsoluteSize.Y
	self.pendingFieldHeight=nil
	self:layoutField(height)
	self.feedback:observe(result, self:isVisible())
	self:paintFeedback(if self.feedback.active then self.presentation else nil)
end

function Recap:scrollReceipt(direction)
	if not self.hasReceipt or not self:isVisible() or type(direction)~="number" or direction==0 then return false end
	if not self.detailsOpen then self:setDetails(true);return true end
	local scroll=self.fieldBody
	local page=math.max(28,math.floor(scroll.AbsoluteSize.Y/28)*28)
	local maximum=math.max(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)
	local before=scroll.CanvasPosition.Y
	scroll.CanvasPosition=Vector2.new(0,math.clamp(before+(if direction>0 then page else -page),0,maximum))
	return scroll.CanvasPosition.Y~=before
end
function Recap:activateDetails()
 if not self.hasReceipt or not self:isVisible()or not self.detailsButton.Visible or not self.detailsButton.Interactable then return false end
 self:setDetails(not self.detailsOpen)
 if self.onAccepted then self.onAccepted("tab")end
 return true
end
function Recap:setDetails(open)
	self.detailsOpen=open==true
	self:layoutField(self.layoutHeight or self.frame.AbsoluteSize.Y)
	if self.detailsOpen then
		local maximum=math.max(0,self.fieldBody.CanvasSize.Y.Offset-self.fieldBody.AbsoluteSize.Y)
		self.fieldBody.CanvasPosition=Vector2.new(0,math.min(math.max(0,(self.detailsTop or 56)+(self.noticeInset or 0)-56),maximum))
	else self.fieldBody.CanvasPosition=Vector2.zero end
end
local function place(node,x,y,w,h)
	node.Position,node.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
end
function Recap:setSaveNotice(notice,outcome)
	if SaveNotice.key(self.saveNotice)==SaveNotice.key(notice) and self.saveOutcome==outcome then return false end
	self.saveNotice,self.saveOutcome=notice,outcome
	if self.fieldMode then self:layoutField(self.layoutHeight or self.frame.AbsoluteSize.Y)end
	return true
end
function Recap:queueChromeFit(key)
	if self.contentLayoutKey==key then return end
	self.contentLayoutKey=key
	if not self.onContentLayout or self.chromeFitQueued then return end
	self.chromeFitQueued=true
	task.defer(function()
		self.chromeFitQueued=false
		local gui=self.frame:FindFirstAncestorOfClass("ScreenGui")
		if self.frame.Parent and gui and gui.Enabled and gui.Parent and self.fieldMode and self:isVisible()and self.onContentLayout then self.onContentLayout()end
	end)
end
function Recap:layoutField(height)
	self.layoutHeight=height
	if self.updatingField then self.pendingFieldHeight=height;return end
	if not self.fieldMode then return end
	local compact=if self.compactLayout~=nil then self.compactLayout else height<300
	local pad=if compact then 8 else 12
	local top=self.headerInset or(if compact then 30 else 56)
	local bottom=self.footerInset or(if compact then 60 else 68)
	local width=math.max(1,(self.layoutWidth or self.frame.AbsoluteSize.X)-pad*2-8)
	place(self.fieldBody,pad,top,width+8,math.max(1,height-top-bottom))
	self.fieldBody.Visible=true;self.goal.Parent=self.fieldBody;self.goal.BackgroundTransparency=1
	local noticeInset=0;self.saveDetail.Visible=self.saveNotice~=nil
	if self.saveNotice then
		Art.type(self.saveDetail,"Body",true)
		self.saveDetail.Text=(if self.saveOutcome then self.saveOutcome.."\n"else "")..self.saveNotice.detail
		local h=Art.textHeight(self.saveDetail,width-8,24);place(self.saveDetail,4,0,width-8,h);noticeInset=h+6
	end
	self.noticeInset=noticeInset
	self.goal.Visible=true;self.summary.Visible=false
	self.title.Visible,self.detail.Visible=not self.hasReceipt,not self.hasReceipt
	self.earnedGraphic.Visible,self.nectarIcon.Visible=self.hasReceipt,self.hasReceipt
	self.bankGraphic.Visible=false -- the compact egg line carries the exact live balance
	self.eggPanel.Visible,self.detailsButton.Visible=self.hasReceipt,self.hasReceipt
	self.stats.Visible,self.bestMetric.Visible=false,false -- quiet metrics retain exact Details rows
	Art.type(self.title,"Body",true);Art.type(self.detail,"Body",true)
	local titleH=Art.textHeight(self.title,width-8,24);place(self.title,4,0,width-8,titleH)
	local detailH=Art.textHeight(self.detail,width-8,28);place(self.detail,4,titleH+6,width-8,detailH)
	local total=titleH+6+detailH
	self.promotionLabel.Visible=false
	if self.hasReceipt then
		Art.type(self.earnedGraphic,"Heading",true)
		local heroH=Art.textHeight(self.earnedGraphic,width-42,28)
		place(self.nectarIcon,6,math.max(0,(heroH-24)/2),18,24)
		place(self.earnedGraphic,34,0,width-38,heroH)
		local y=heroH+6;local visible=0;local sourceH=0
		for _,label in ipairs(self.componentLabels)do
			label.Parent=self.goal
			Art.type(label,"Supporting",true);label.TextXAlignment=Enum.TextXAlignment.Left
			label.Visible=not label.Text:match("%+0$")
			if label.Visible then visible+=1;sourceH=math.max(sourceH,Art.textHeight(label,(width-8)/2,16))end
		end
		local column=0
		for _,label in ipairs(self.componentLabels)do
			place(label,4+column*(width-8)/math.max(1,visible),y,(width-8)/math.max(1,visible),math.max(sourceH,Art.textHeight(label,width-8,16)))
			if label.Visible then column+=1 end
		end
		if visible>0 then y+=sourceH+6 end
		self.promotionLabel.Visible=self.promotionLabel.Text~=""
		if self.promotionLabel.Visible then
			Art.type(self.promotionLabel,"Supporting",true);local h=Art.textHeight(self.promotionLabel,width-8,18)
			place(self.promotionLabel,4,y,width-8,h);y+=h+6
		end
		local eggY=y
		self.eggPanel.BackgroundTransparency=1
		self.eggGoal.Parent,self.bankGraphic.Parent=self.eggPanel,self.eggPanel
		Art.type(self.eggGoal,"Body",true);Art.type(self.bankGraphic,"Body",true);Art.type(self.shortfall,"Supporting",true)
		local name=if self.displayRecipeId=="meadow"then "Meadow"elseif self.displayRecipeId=="sprout"then "Sprout"else self.displayRecipe.name
		self.eggGoal.Text=string.format("%s · %d/%d",name,self.displayBalance,self.displayCost)
		self.shortfall.Text=if self.displayBalance>=self.displayCost then "Ready to hatch"else string.format("%d more to hatch",self.displayCost-self.displayBalance)
		Art.bind(self.shortfall,{TextColor3=function()return if self.displayBalance>=self.displayCost then Art.Leaf else Art.paletteColor("muted") end})
		self.bankGraphic.Text=string.format("Nectar saved: %d",self.displayBalance)
		local textW=math.max(1,width-48)
		local eggTitleH=Art.textHeight(self.eggGoal,textW,18);local shortH=Art.textHeight(self.shortfall,textW,16)
		local eggH=math.max(44,eggTitleH+4+shortH+8)
		place(self.eggPanel,0,eggY,width,eggH)
		place(self.eggGoal,44,0,textW,eggTitleH);place(self.shortfall,44,eggTitleH+4,textW,shortH)
		place(self.bankGraphic,44,0,textW,Art.textHeight(self.bankGraphic,textW,18))
		self.eggGoal.TextXAlignment,self.bankGraphic.TextXAlignment,self.shortfall.TextXAlignment=Enum.TextXAlignment.Left,Enum.TextXAlignment.Left,Enum.TextXAlignment.Left
		self.fill.Parent.Parent=self.eggPanel;self.fill.Parent.ZIndex=self.eggPanel.ZIndex+1;self.fill.ZIndex=self.eggPanel.ZIndex+2
		place(self.fill.Parent,44,eggH-3,textW,3)
		place(self.eggDrawing,4,math.max(0,(eggH-40)/2),32,40)
		local recipeId=self.displayRecipeId or "meadow"
		if self.drawnRecipe~=recipeId then
			self.eggDrawing:ClearAllChildren();self.drawnRecipe=recipeId
			EggArt.create(self.eggDrawing,recipeId,UDim2.fromOffset(4,4),UDim2.fromOffset(24,32),self.eggDrawing.ZIndex+1)
		end
		y=eggY+eggH+6
		Art.type(self.detailsButton,"Body",true)
		self.detailsButton.Text=if self.detailsOpen then "Hide details"else "Round details"
		local detailsH=Art.actionHeight(self.detailsButton,width)
		place(self.detailsButton,0,y,width,detailsH);self.detailsTop=y+detailsH+6
		local rowsHeight=0;self.receiptRowHeight=28
		for index,row in ipairs(self.receiptRows)do
			Art.type(row,"Body",true);local h=Art.textHeight(row,width-16,28)
			place(row,8,rowsHeight,width-16,h);rowsHeight+=h+(if index<#self.receiptRows then 6 else 0)
		end
		self.receiptScroll.Parent=self.goal;self.receiptScroll.Visible=self.detailsOpen==true
		self.receiptScroll.ScrollingEnabled=false;self.receiptScroll.ScrollBarThickness=0
		place(self.receiptScroll,0,self.detailsTop,width,rowsHeight);self.receiptScroll.CanvasSize=UDim2.fromOffset(0,rowsHeight)
		total=if self.detailsOpen then self.detailsTop+rowsHeight+4 else y+detailsH+4
	else
		for _,label in ipairs(self.componentLabels)do label.Visible=false end
		self.receiptScroll.Visible=false
	end
	self.bodyContentHeight=total+noticeInset
	place(self.goal,0,noticeInset,width,total)
	self.fieldBody.CanvasSize=UDim2.fromOffset(0,self.bodyContentHeight)
	self.fieldBody.ScrollingEnabled=self.bodyContentHeight>self.fieldBody.AbsoluteSize.Y
	self.fieldBody.CanvasPosition=Vector2.new(0,math.clamp(self.fieldBody.CanvasPosition.Y,0,math.max(0,self.bodyContentHeight-self.fieldBody.Size.Y.Offset)))
	self:queueChromeFit(table.concat({width,self.bodyContentHeight,tostring(self.detailsOpen==true),game:GetService("GuiService").PreferredTextSize.Name},"|"))
end

return Recap
