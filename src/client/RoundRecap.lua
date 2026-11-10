local Stars=require(script.Parent.StarText)
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
			if index == 1 then Art.Amber else "text", 26, Art.Font.Counter)
		fitText(value, 26)
		values[index] = value
	end
	local goal = Art.frame(frame, "Goal", "raised", UDim2.new(0, 12, 1, -88), UDim2.new(1, -24, 0, 30))
	Art.corner(goal, 5)
	local title = Art.text(goal, "Heading", "", UDim2.fromOffset(6, 1), UDim2.new(1, -12, 0, 14),
		Art.Cyan, 13, Art.Font.Heading)
	fitText(title, 13)
	local detail = Art.text(goal, "Progress", "", UDim2.fromOffset(6, 15), UDim2.new(1, -12, 0, 12), "text", 12)
	Art.bind(title,{TextColor3=function()return Color3.fromHex("#173D36")end});Art.bind(detail,{TextColor3=function()return Color3.fromHex("#173D36")end})
	fitText(detail, 12)
	local track = Art.frame(goal, "Track", "ink", UDim2.new(0, 6, 1, -4), UDim2.new(1, -12, 0, 2))
	local fill = Art.frame(track, "Fill", Art.Cyan, UDim2.fromOffset(0, 0), UDim2.fromScale(0, 1))
    local nectarIcon=EggArt.stars(goal,UDim2.fromOffset(7,4),UDim2.fromOffset(14,18),goal.ZIndex+1)
    nectarIcon.Name="NectarIcon"
	nectarIcon.Visible = false
	local earnedGraphic = Art.text(goal, "EarnedNectar", "+0 Stars", UDim2.fromOffset(27, 0), UDim2.new(.52, -28, 0, 26), Art.Amber, 26, Art.Font.Reward)
	fitText(earnedGraphic, 26)
	earnedGraphic.TextXAlignment = Enum.TextXAlignment.Left
	local bankGraphic = Art.text(goal, "SavedEggBank", "", UDim2.new(.52, 0, 0, 0), UDim2.new(.48, -6, 0, 26), Art.Leaf, 13, Art.Font.Counter)
	fitText(bankGraphic, 13)
	earnedGraphic.Visible, bankGraphic.Visible = false, false
	local detailsButton = Instance.new("TextButton")
	detailsButton.Name, detailsButton.Text, detailsButton.Size = "Details", "Details", UDim2.fromOffset(90, 44)
	detailsButton.BackgroundColor3, detailsButton.TextColor3 = Art.Ink, Art.Silver
	detailsButton.Font, detailsButton.TextSize, detailsButton.BorderSizePixel = Art.Font.Action, 14, 0
	detailsButton.ZIndex, detailsButton.Visible, detailsButton.Parent = goal.ZIndex + 3, false, goal
	Art.bind(detailsButton,{BackgroundColor3="ink",TextColor3="text"});Art.button(detailsButton, 8); Art.fitText(detailsButton, 14, 10, 4, false)
	local summary = Art.frame(goal, "RewardChips", "raised", UDim2.fromOffset(6, 52), UDim2.new(1, -12, 1, -54))
	summary.BackgroundTransparency, summary.Visible = 1, false
	local componentLabels = {}
	for index, caption in ipairs({ "Quest", "Daily" }) do
		local chip = Art.frame(summary, caption .. "Chip", "ink", UDim2.new((index - 1) * .5, 1, 0, 0), UDim2.new(.5, -3, 0, 36))
		Art.corner(chip, 8)
		local label = Art.text(chip, "Value", caption .. " +0", UDim2.fromOffset(4, 0), UDim2.new(1, -8, 1, 0), if index == 1 then Art.Leaf else Art.Amber, 18, Art.Font.Counter)
		fitText(label, 18)
		componentLabels[index] = label
	end
	local eggGoal = Art.text(summary, "EggGoal", "", UDim2.fromOffset(4, 40), UDim2.new(1, -8, 0, 32), "text", 13)
	fitText(eggGoal, 13)
	eggGoal.TextWrapped = true
	local transfer = Art.frame(goal, "NectarTransfer", Art.Amber, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), goal.ZIndex + 4)
	transfer.BackgroundTransparency, transfer.Visible = 1, false
	local chips = {}
	for index = 1, 5 do
		local chip = EggArt.stars(transfer,UDim2.fromOffset(0,0),UDim2.fromOffset(7,10),transfer.ZIndex+1)
        chip.Name="Drop"..index
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
	local bestValue=Art.text(personalBest,"Value","0",UDim2.fromOffset(0,26),UDim2.new(1,0,0,32),"text",24,Art.Font.Counter)
	personalBest.Visible=false
	local promotion=Art.text(goal,"FamilyPromotion","",UDim2.fromOffset(4,0),UDim2.new(1,-8,0,24),Art.Leaf,12)
	promotion.TextXAlignment=Enum.TextXAlignment.Left;promotion.Visible=false
	local detailsContent=Art.frame(body,"DetailsContent","panel",UDim2.fromOffset(0,0),UDim2.fromOffset(1,1),body.ZIndex+1)
 detailsContent.BackgroundTransparency=1;detailsContent.Visible=false
 local endArt=Art.frame(body,"RoundFinishStrip",Art.Ink,UDim2.fromOffset(8,0),UDim2.fromOffset(100,64),body.ZIndex+1)
 endArt.BackgroundTransparency=1;endArt.ClipsDescendants=true;endArt.Visible=false;endArt:SetAttribute("RoundEndStrip",true)
 local bottleScale=Instance.new("UIScale");bottleScale.Name="SavedPop";bottleScale.Parent=nectarIcon
 local sourceGlows={}
 for i,label in ipairs(componentLabels)do
  local glow=Art.frame(goal,"SourceGlow"..i,Art.Amber,UDim2.fromOffset(0,0),UDim2.fromOffset(1,1),goal.ZIndex)
  glow.BackgroundTransparency=1;Art.corner(glow,6);sourceGlows[i]=glow
 end
 local self = setmetatable({endArt=endArt,detailsContent=detailsContent,detailCards={},bottleScale=bottleScale,sourceGlows=sourceGlows, promotionLabel=promotion, frame = frame, stats = stats, goal = goal, values = values, title = title, detail = detail,
		fill = fill, receiptScroll = receipt, receiptRows = {}, scales = scales, accents = accents,
		nectarIcon = nectarIcon, earnedGraphic = earnedGraphic, bankGraphic = bankGraphic, transfer = transfer, chips = chips,
		detailsButton = detailsButton, summary = summary, componentLabels = componentLabels, eggGoal = eggGoal,
		fieldBody=body,eggPanel=eggPanel,eggDrawing=eggDrawing,shortfall=shortfall,bestMetric=personalBest,bestCaption=bestCaption,bestValue=bestValue }, Recap)
	detailsButton.Activated:Connect(function() self:activateDetails() end)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if self.fieldMode then self:layoutField(frame.AbsoluteSize.Y) end end)
	Art.watchTextPreference(frame,function()return self:isVisible()end,function()if self.onPreferredLayout then self.onPreferredLayout() else self:layoutField(frame.AbsoluteSize.Y) end end)
	self.saveDetail=Art.text(body,"SaveInstruction","",UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),Art.Amber,14)
	self.saveDetail.TextXAlignment,self.saveDetail.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Top
	Art.bind(self.saveDetail,{TextColor3=function()return Color3.fromHex("#173D36")end});self.saveDetail.Visible=false
	self.feedback = Feedback.new(function(sample) self:paintFeedback(sample) end, audio, reduceEffects,function()return self:isVisible()and(not self.ownsFeedback or self.ownsFeedback())end)
 body:GetPropertyChangedSignal("CanvasPosition"):Connect(function()self:paintFeedback(self.presentation)end)
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
	local gui=frame:FindFirstAncestorOfClass("ScreenGui")
 if gui then
  table.insert(self.visibilityConnections,gui:GetPropertyChangedSignal("Enabled"):Connect(function()
   if not gui.Enabled then self.feedback:cancel()
   else task.defer(function()if self.frame.Parent and self.fieldMode and self.lastFieldResult then self.feedback:observe(self.lastFieldResult,self:isVisible())end end)end
  end))
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
	local gui=self.frame:FindFirstAncestorOfClass("ScreenGui")
 return self.frame.Parent~=nil and(not gui or(gui.Enabled and gui.Parent~=nil))
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
 if self.displayReward~=nil then
  self.earnedGraphic.Text=Stars.format("+%d Stars",self.displayReward)
  self.bankGraphic.Text=Stars.format("Stars saved: %d",self.displayBalance)
 end
 if self.finalTitle then self.title.Text=self.finalTitle end
 self.bottleScale.Scale=1+(if sample then sample.pop or 0 else 0)*.12
 self.nectarIcon.Rotation=if sample then (sample.pop or 0)*-6 else 0
 for i,glow in ipairs(self.sourceGlows)do
  glow.Visible=self.hasReceipt==true and self.componentLabels[i].Visible
  glow.BackgroundTransparency=1-(if sample then sample.sources or 0 else 0)*.18
 end
 self.fill.BackgroundColor3=if sample and(sample.settle or 0)<1 and(sample.settle or 0)>0 then Art.Amber else Art.Cyan
 local function within(node,viewport)
  local p,z,q,t=node.AbsolutePosition,node.AbsoluteSize,viewport.AbsolutePosition,viewport.AbsoluteSize
  return p.X>=q.X-.5 and p.Y>=q.Y-.5 and p.X+z.X<=q.X+t.X+.5 and p.Y+z.Y<=q.Y+t.Y+.5
 end
 local anchors=self.fieldMode==true and self.hasReceipt==true and self:isVisible()and self.fieldBody.AbsoluteSize.Y>0
  and within(self.nectarIcon,self.fieldBody)and within(self.fill.Parent,self.fieldBody)
 anchors=false -- Receipt feedback has no egg-progress transfer destination.
 self.transferAnchorsVisible=anchors
 self.transfer.Visible=anchors and sample~=nil and(self.displayReward or 0)>0 and(sample.transfer or 0)>0 and(sample.transfer or 0)<1
 local origin=self.transfer.AbsolutePosition
 local start=self.nectarIcon.AbsolutePosition+self.nectarIcon.AbsoluteSize*.5-origin
 local destination=self.fill.Parent.AbsolutePosition+self.fill.Parent.AbsoluteSize*.5-origin
 for index,chip in ipairs(self.chips)do
  local phase=if sample then math.clamp((sample.transfer or 0)*1.5-(index-1)*.125,0,1)else 0
  chip.Visible=self.transfer.Visible and index<=math.min(5,self.displayReward or 0)and phase>0 and phase<1
  if chip.Visible then
   local point=start:Lerp(destination,phase)+Vector2.new(0,-math.sin(phase*math.pi)*math.min(22,math.abs(destination.X-start.X)*.12+10))
   chip.Position=UDim2.fromOffset(point.X-3,point.Y-5);chip.Rotation=-15+phase*30;chip.GoldStar.TextTransparency=phase*.35;chip.StarGlint.BackgroundTransparency=phase*.35
  end
 end
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
 self.detailsContent.Visible=false
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

-- Rows are rebuilt only for changed canonical receipt data. They remain inert
-- children of the one fieldBody owner; no second scrolling/focus surface exists.
function Recap:buildDetails(result,reward,lines)
 self.detailsContent:ClearAllChildren();self.receiptScroll:ClearAllChildren()
 self.detailCards,self.receiptRows={},{}
 local function card(kind,caption,value,pair)
  local frame=Art.frame(self.detailsContent,"Detail_"..(#self.detailCards+1),"raised",UDim2.fromOffset(0,0),UDim2.fromOffset(1,1),self.detailsContent.ZIndex+1)
  Art.corner(frame,8);Art.bind(frame,{BackgroundColor3=function()return Color3.fromHex("#F5EFD9")end});frame:SetAttribute("ReceiptSection",kind)
  local icon=Art.frame(frame,"Icon","accent",UDim2.fromOffset(10,10),UDim2.fromOffset(18,18),frame.ZIndex+1);Art.corner(icon,if kind=="contract"then 8 else 4)
  if kind=="contract"then icon.BackgroundTransparency=1;EggArt.nectar(icon,UDim2.fromOffset(2,0),UDim2.fromOffset(14,18),icon.ZIndex+1)
  elseif kind=="score"or kind=="best"then icon.Rotation=45
  elseif kind=="chain"then Art.frame(icon,"Link","ink",UDim2.fromOffset(5,2),UDim2.fromOffset(8,14),icon.ZIndex+1)end
  local title=Art.text(frame,"Label",caption,UDim2.fromOffset(38,8),UDim2.fromOffset(1,1),"text",14)
  title.TextXAlignment,title.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Top;Art.type(title,"Body",true)
  table.insert(self.receiptRows,title)
  local counter
  if value then
   counter=Art.text(frame,"Value",value,UDim2.fromOffset(10,0),UDim2.fromOffset(1,1),"text",18,Art.Font.Counter)
   Art.type(counter,"Counter");counter.TextSize=18;counter.TextXAlignment=Enum.TextXAlignment.Left
   table.insert(self.receiptRows,counter)
  end
  Art.bind(title,{TextColor3=function()return Color3.fromHex("#173D36")end});if counter then Art.bind(counter,{TextColor3=function()return Color3.fromHex("#173D36")end})end
  local entry={frame=frame,title=title,value=counter,pair=pair==true,kind=kind}
  table.insert(self.detailCards,entry);return entry
 end
 if self.statTargets then
  card("score","Score",tostring(self.statTargets[1]),true)
  card("best","Personal best",tostring(self.statBest or 0),true)
  card("chain","Longest chain","×"..self.statTargets[2],true)
  card("clears","Tier V clears",tostring(self.statTargets[3]),true)
 end
 -- Exact payout components already have one summary above this detail section.
 local skip=self.statTargets and 4 or 2
 local unique={}
 local checklist=Receipt.questDetails(result);local unfinished=if checklist then Receipt.questHint(result)else nil
 -- The last two canonical lines repeat the live egg facts already in summary.
 -- Keep them in receiptLines/signature for history/tests, omit the visual repeat.
 for i=skip+1,math.max(skip,#lines-2)do
  local line=lines[i];local found=unfinished~=nil and line==unfinished
  for _,definition in ipairs(Daily.Definitions)do
   if line==Stars.format("%s · %d Stars",definition.title,definition.reward)then card("contract",definition.title,"+"..definition.reward,true);found=true;break end
  end
  if not found and not unique[line]then
   unique[line]=true
   card("fact",line,nil,false)
  end
 end
end

function Recap:updateField(result)
	self.updatingField = true
 self.lastFieldResult=result
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
	if reward then self.earnedGraphic.Text=Stars.format("+%d Stars",reward.total);self.bankGraphic.Text=Stars.format("Stars saved: %d",balance)end
 self.hasReceipt,self.fieldMode=reward~=nil,true
	self.fieldHeading=Receipt.outcome(result)
	self.promotionLabel.Text=""
	self.title.Text = if loading then "Loading receipt…"
		elseif saving then (if result.status == "Saving" then "Saving your rewards…" else "Reward save delayed · retrying") else
		Stars.format("Stars +%d · quest %d + daily %d", result.award, math.max(0, result.award - result.daily), result.daily)
	local egg = if balance >= cost then result.recipe.name .. " · ready to hatch"
		else Stars.format("%s · %d/%d · need %d Stars", result.recipe.name, balance, cost, cost - balance)
 local hint=if result.reason=="Overflow"and(result.stage or 0)>=2 then "Both goals done · clear the overflow line"
  elseif result.reason=="Overflow"then "Merge below the line to clear its warning."
  elseif result.success then "Both goals and 24 drops earn Stars for eggs."
  else Receipt.questHint(result)
	self.fullFieldDetail = if loading then "Waiting for this round's saved receipt."
		elseif saving then "Rewards appear after saving. Please wait." else hint .. "\n" .. egg
	self.shortFieldDetail = if loading then "Waiting for this round's saved receipt."
		elseif saving then "Please wait for your saved receipt." else egg
	self.detail.Text = self.fullFieldDetail
	self.detail.TextWrapped = true
	self.detail.Visible,self.receiptScroll.Visible=not self.hasReceipt,false
	self.nectarIcon.Visible = self.hasReceipt
	if reward then
		if self.detailsSequence ~= reward.sequence then self.detailsOpen = true; self.detailsSequence = reward.sequence;self.fieldBody.CanvasPosition=Vector2.zero end
		self.componentLabels[1].Text = string.format("Quest +%d", reward.base or 0)
		self.componentLabels[2].Text = string.format("Daily +%d", reward.daily or 0)
		self.eggGoal.Text = egg
		-- The total and saved egg balance remain pinned while the receipt scrolls.
		self.title.Text = Stars.format("Stars +%d · Saved %d/%d", reward.total, balance, cost)
		local lines = { Stars.format("Quest Stars +%d", reward.base or 0), string.format("Daily contracts total +%d", reward.daily or 0) }
		if self.statTargets then
			table.insert(lines,"Score "..self.statTargets[1].." · Personal best "..(self.statBest or 0))
			table.insert(lines,"Longest chain ×"..self.statTargets[2].." · Tier V clears "..self.statTargets[3])
		end
  local fieldDetails=Receipt.questDetails(result)
  if fieldDetails then table.insert(lines,fieldDetails)end
  if not result.success then table.insert(lines,Receipt.questHint(result))end
		for _, id in ipairs(reward.contracts or {}) do
			for _, contract in ipairs(Daily.Definitions) do
				if contract.id == id then table.insert(lines, Stars.format("%s · %d Stars", contract.title, contract.reward)); break end
			end
		end
		table.insert(lines, result.recipe.name .. " · costs " .. cost .. " Stars")
		table.insert(lines, if balance >= cost then "Ready to hatch · " .. balance .. "/" .. cost .. " Stars"
			else Stars.format("%d/%d Stars · need %d more", balance, cost, cost - balance))
		local signature = table.concat(lines, "\n")
		if self.receiptSignature ~= signature then
			self.receiptSignature, self.receiptLines = signature, lines
   self:buildDetails(result,reward,lines)

		end
	else
		self.receiptLines, self.receiptSignature = nil, nil
		self.receiptScroll:ClearAllChildren();self.detailsContent:ClearAllChildren()
  self.detailCards={};self.receiptRows={}
	end
	self.finalTitle = self.title.Text
	self.displayReward, self.displayBalance, self.displayCost = if reward then reward.total else nil, balance, cost
	-- This bar always represents the committed snapshot, even while decorative
	-- earned drops travel towards the bank. No transient balance is invented.
	self.fill.Parent.Visible = false
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
		local scroll=self.fieldBody
	local page=math.max(28,math.floor(scroll.AbsoluteSize.Y/28)*28)
	local maximum=math.max(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)
	local before=scroll.CanvasPosition.Y
	scroll.CanvasPosition=Vector2.new(0,math.clamp(before+(if direction>0 then page else -page),0,maximum))
	return scroll.CanvasPosition.Y~=before
end
-- Compatibility entry points keep controller callers on the always-open receipt.
function Recap:activateDetails()return false end
function Recap:revealFirstDetail()end
function Recap:setDetails()self.detailsOpen=true;self:layoutField(self.layoutHeight or self.frame.AbsoluteSize.Y)end
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
		if self.frame.Parent and gui and gui.Enabled and gui.Parent and self.fieldMode and self:isVisible()and self.onContentLayout then
   self.onContentLayout();self:revealFirstDetail();self.detailsRevealOrigin=nil
  end
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
 local viewport=math.max(1,height-top-bottom)
 place(self.fieldBody,pad,top,width+8,viewport)
 self.fieldBody.Visible=true;self.goal.Parent=self.fieldBody;self.goal.BackgroundTransparency=1
 self.receiptScroll.Visible=false;self.detailsOpen=true;self.detailsContent.Visible=self.hasReceipt==true
 local noticeInset=0;self.saveDetail.Visible=self.saveNotice~=nil
 if self.saveNotice then
  Art.type(self.saveDetail,"Body",true);self.saveDetail.Text=(if self.saveOutcome then self.saveOutcome.."\n"else "")..self.saveNotice.detail
  local h=Art.textHeight(self.saveDetail,width-16,24);place(self.saveDetail,8,0,width-16,h);noticeInset=h+8
 end
 self.noticeInset=noticeInset
 self.goal.Visible=true;self.summary.Visible=false
 self.title.Visible,self.detail.Visible=not self.hasReceipt,not self.hasReceipt
 self.earnedGraphic.Visible,self.nectarIcon.Visible=self.hasReceipt,self.hasReceipt
 self.bankGraphic.Visible=false
 self.eggPanel.Visible,self.detailsButton.Visible=false,false
 self.stats.Visible,self.bestMetric.Visible=false,false
 self.promotionLabel.Visible=false
 Art.type(self.title,"Body",true);Art.type(self.detail,"Body",true)
 local titleH=Art.textHeight(self.title,width-16,24);place(self.title,8,0,width-16,titleH)
 local detailH=Art.textHeight(self.detail,width-16,28);place(self.detail,8,titleH+8,width-16,detailH)
 local total=titleH+8+detailH
 self.twoColumn=false
 if self.hasReceipt then
  Art.type(self.earnedGraphic,"Reward",true);self.earnedGraphic.TextXAlignment=Enum.TextXAlignment.Left
  local ink=Color3.fromHex("#173D36")
  Art.bind(self.earnedGraphic,{TextColor3=function()return ink end})
  local content=math.max(1,width-16)
  local heroH=Art.textHeight(self.earnedGraphic,math.max(1,content-34),28)
  place(self.nectarIcon,8,math.max(2,(heroH-24)/2),24,24)
  place(self.earnedGraphic,42,0,math.max(1,content-34),heroH)
  local y=heroH+8
  for i,label in ipairs(self.componentLabels)do
   label.Parent=self.goal;Art.type(label,"Counter",true);label.TextXAlignment=Enum.TextXAlignment.Left
   label.Visible=true;Art.bind(label,{TextColor3=function()return ink end})
   local h=Art.textHeight(label,content,22);place(label,8,y,content,h)
   place(self.sourceGlows[i],6,y-2,content+4,h+4);y+=h+4
  end
  self.eggPanel.Visible,self.detailsButton.Visible,self.eggGoal.Visible,self.shortfall.Visible=false,false,false,false
  self.fill.Parent.Visible=false;self.transfer.Visible=false
  self.summaryLayout={earned={x=8,y=0,w=content,h=y},twoColumn=false}
  if self.endArt.Visible then place(self.endArt,8,noticeInset+y,content,64);y+=72 end
  self.detailsTop=y+4
  local detailsWidth=content;local pairW=(detailsWidth-8)/2
  local pairsFit=detailsWidth>=280
  local rowY=0;local cardIndex=1
  while cardIndex<=#self.detailCards do
   local entry=self.detailCards[cardIndex]
   local paired=pairsFit and entry.pair and self.detailCards[cardIndex+1]and self.detailCards[cardIndex+1].pair
   local count=if paired then 2 else 1;local cardW=if paired then pairW else detailsWidth
   local rowH=0
   for offset=0,count-1 do
    local item=self.detailCards[cardIndex+offset];Art.type(item.title,"Body",true)
    local valueW,vh=0,0
    if item.value then
     Art.type(item.value,"Counter");item.value.TextSize=18
     valueW=math.min(cardW-20,Art.textWidth(item.value)+2);vh=Art.textHeight(item.value,valueW,24)
    end
    local titleW=math.max(1,cardW-48-valueW-(if item.value then 6 else 0))
    local inline=item.value~=nil and titleW>=80
    if not inline then
     titleW=math.max(1,cardW-48)
     if item.value then valueW=titleW;vh=Art.textHeight(item.value,valueW,24)end
    end
    local th=Art.textHeight(item.title,titleW,22)
    item.titleHeight,item.valueHeight,item.valueWidth,item.titleWidth,item.inline=th,vh,valueW,titleW,inline
    rowH=math.max(rowH,if inline then math.max(34,math.max(th,vh)+12)elseif item.value then th+vh+20 else th+16)
   end
   for offset=0,count-1 do
    local item=self.detailCards[cardIndex+offset]
    place(item.frame,offset*(cardW+8),rowY,cardW,rowH)
    place(item.title,38,if item.inline then (rowH-item.titleHeight)/2 else 8,item.titleWidth,item.titleHeight)
    if item.value then
     item.value.TextXAlignment=if item.inline then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
     place(item.value,if item.inline then cardW-10-item.valueWidth else 38,if item.inline then (rowH-item.valueHeight)/2 else 12+item.titleHeight,if item.inline then item.valueWidth else cardW-48,item.valueHeight)
    end
    item.frame:SetAttribute("InlineFact",item.inline)
   end
   rowY+=rowH+8;cardIndex+=count
  end
  place(self.detailsContent,8,noticeInset+self.detailsTop,detailsWidth,math.max(0,rowY-8))
  total=self.detailsTop+math.max(0,rowY-8)
 else
  for _,label in ipairs(self.componentLabels)do label.Visible=false end
  if self.endArt.Visible then place(self.endArt,8,noticeInset+total+8,math.max(1,width-16),64);total+=72 end
 end
 self.bodyContentHeight=total+noticeInset+4
 place(self.goal,0,noticeInset,width,if self.hasReceipt then self.detailsTop-12 else total)
 self.transfer.Parent=self.goal;place(self.transfer,0,0,width,self.goal.Size.Y.Offset)
 self.fieldBody.CanvasSize=UDim2.fromOffset(0,self.bodyContentHeight)
 self.fieldBody.ScrollingEnabled=self.bodyContentHeight>viewport
 self.fieldBody.CanvasPosition=Vector2.new(0,math.clamp(self.fieldBody.CanvasPosition.Y,0,math.max(0,self.bodyContentHeight-viewport)))
 self:paintFeedback(self.presentation)
 self:queueChromeFit(table.concat({width,self.bodyContentHeight,tostring(self.detailsOpen==true),game:GetService("GuiService").PreferredTextSize.Name},"|"))
end

return Recap
