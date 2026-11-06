local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Art = require(script.Parent.DeckArt)
local Portrait = require(script.Parent.PetPortrait)

local Journal = {}
Journal.__index = Journal
local CARD_HEIGHT = 378
local LIST_HEIGHT = (math.ceil(#Pets / 2) + #Pets.rares) * 55 - 3
local familyNames = { pip = "Pip", puddle = "Puddle", wick = "Wick", orbit = "Orbit" }
local rankNames = { [0] = "Unranked", "I", "II", "III" }

function Journal.new(gui, make, label, onVisit, onTrack, onGoals)
	local shade = make("Frame", "PetJournal", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Art.Ink, BorderSizePixel = 0,
		BackgroundTransparency = 1, Active = true, Visible = false, ZIndex = 20,
	}, gui)
	local card = make("Frame", "Card", {
		AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 21,
		Position = UDim2.fromScale(0.5, 0.5),
	}, shade)
	local scroll = make("ScrollingFrame", "Scroll", {
		Size = UDim2.new(1, -16, 1, -100), Position = UDim2.fromOffset(8, 40),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 22,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Art.Cyan, ElasticBehavior = Enum.ElasticBehavior.Never,
		CanvasSize = UDim2.fromOffset(0, LIST_HEIGHT),
	}, card)
	local function layout()
		local size = shade.AbsoluteSize
		card.Size = UDim2.fromOffset(math.clamp(size.X - 24, 1, 400),
			math.clamp(size.Y - (if size.Y < 220 then 8 else 40), 1, CARD_HEIGHT))
	end
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
	Art.panel(card, 12)
	local title = label("TextLabel", "Title", "", card)
	title.Size = UDim2.new(1, 0, 0, 34)
	title.TextColor3 = Art.Cyan
	title.Font = Enum.Font.Code
	title.TextSize = 16
	title.ZIndex = 22
	Art.fitText(title, 16, 11, 12)
	local self = setmetatable({ shade = shade, card = card, scroll = scroll, title = title, cards = {}, portraits = {}, onGoals = onGoals }, Journal)
	for index, pet in ipairs(Pets.collection) do
		local entry = label("TextButton", pet.name, "", scroll, Art.Raised)
		local column = if pet.trial then 0 else (index - 1) % 2 * 0.5
		local row = if pet.trial then math.ceil(#Pets / 2) + index - #Pets - 1 else math.floor((index - 1) / 2)
		entry.Position = UDim2.new(column, 3, 0, 2 + row * 55)
		entry.Size = UDim2.new(if pet.trial then 1 else 0.5, -10, 0, 50)
		entry.ZIndex = 22
		Art.button(entry, 6)
		local well = Art.frame(entry, "PortraitWell", Art.Ink, UDim2.fromOffset(5, 5), UDim2.fromOffset(36, 36))
		Art.corner(well, 4)
		local name = Art.text(entry, "Species", if pet.trial then pet.name .. "  ·  Rare" else pet.name,
			UDim2.fromOffset(47, 4), UDim2.new(1, -51, 0, 20),
			Art.Silver, 15, Enum.Font.GothamBold)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		Art.fitText(name, 15, 10, 0)
		local status = Art.text(entry, "Status", "", UDim2.fromOffset(47, 22), UDim2.new(1, -51, 0, 25),
			Art.Muted, 11, Enum.Font.GothamMedium)
		status.TextXAlignment = Enum.TextXAlignment.Left
		Art.fitText(status, 11, 9, 0, true)
		local statusInset = status:FindFirstChildOfClass("UIPadding")
		statusInset.PaddingTop, statusInset.PaddingBottom = UDim.new(0, 0), UDim.new(0, 0)
		if pet.trial then
			local track = Art.text(entry, "Track", "TRACK & PLAY", UDim2.new(1, -91, 0, 5),
				UDim2.fromOffset(87, 16), Art.Cyan, 10, Enum.Font.GothamBold)
			track.TextXAlignment = Enum.TextXAlignment.Right
			track.Visible = false
		end
		self.cards[index] = entry
		entry.Activated:Connect(function()
			if self.shade.Visible and entry.Interactable then
				self:close()
				if entry:FindFirstChild("Track") and entry.Track.Visible then
					onTrack(pet)
				else
					onVisit(pet)
				end
			end
		end)
	end
	local close = label("TextButton", "Close", "Close", card, Art.Ink)
	close.Position = UDim2.new(0.25, 0, 1, -52)
	close.Size = UDim2.new(0.5, 0, 0, 44)
	close.ZIndex = 22
	close.TextColor3 = Art.Silver
	Art.button(close, 6)
	Art.fitText(close, 15, 12, 8)
	close.Activated:Connect(function()
		self:close()
	end)
	self.closeButton = close
	if onGoals then
		close.Position, close.Size = UDim2.new(0, 8, 1, -52), UDim2.new(0.5, -12, 0, 44)
		local goals = label("TextButton", "FamilyGoals", "Family goals", card, Art.Canopy)
		goals.Position, goals.Size = UDim2.new(0.5, 4, 1, -52), UDim2.new(0.5, -12, 0, 44)
		goals.ZIndex, goals.TextColor3 = 22, Art.Silver
		Art.button(goals, 6)
		Art.fitText(goals, 15, 10, 8, true)
		goals.Activated:Connect(function() self:openFamilyGoals() end)
		self.goalsButton = goals
	end
	return self
end

function Journal:openFamilyGoals()
	if not self.shade.Visible or not self.onGoals then return end
	self:close()
	self.onGoals()
end

function Journal:open(owned, trials, companionId, selected, tracked, inventoryMask, masteryRanks)
	self.title.Text = string.format("PET JOURNAL  ·  %02d/%02d", Pets.ownedCount(owned, trials, inventoryMask), #Pets.collection)
	for index, entry in ipairs(self.cards) do
		local pet = Pets.collection[index]
		local unlocked = Pets.isUnlocked(pet, owned, trials, inventoryMask)
		local equipped = unlocked and pet.id == companionId
		local trackable = inventoryMask == nil and pet.trial ~= nil and not unlocked
		local family = pet.family or pet.id
		local rank = math.clamp(math.floor(tonumber(masteryRanks and masteryRanks[family]) or 0), 0, 3)
		entry.Status.Text = if unlocked then (if equipped then "Equipped" else "Equip") .. "\n"
			.. (familyNames[family] or family) .. " · " .. rankNames[rank]
			elseif inventoryMask ~= nil then "Hatch from eggs"
			elseif pet.trial then pet.trial.hint else pet.charge .. " charge to hatch"
		if pet.trial then
			entry.Track.Visible = trackable
			entry.Track.Text = if tracked == pet then "TRACKED · PLAY" else "TRACK & PLAY"
			entry.Species.Text = if trackable then pet.name else pet.name .. "  ·  Rare"
			entry.Species.Size = UDim2.new(1, if trackable then -140 else -51, 0, 20)
		end
		entry.Status.TextColor3 = if equipped then Art.Cyan else Art.Muted
		entry.Species.TextColor3 = if pet.trial then Art.Amber elseif unlocked then Art.Silver else Art.Muted
		if not self.portraits[index] or self.portraits[index].unlocked ~= unlocked then
			if self.portraits[index] then
				self.portraits[index].sprite:Destroy()
			end
			self.portraits[index] = {
				unlocked = unlocked,
				sprite = Portrait.create(entry.PortraitWell, pet, 2, UDim2.fromScale(0.5, 0.5), 23, not unlocked),
			}
		end
		entry.Interactable = unlocked or trackable
		entry.Selectable = entry.Interactable
	end
	self.shade.Visible = true
	self.scroll.CanvasPosition = Vector2.zero
	self.previousSelection = GuiService.SelectedObject
	if selected then
		GuiService.SelectedObject = if self.cards[1].Selectable then self.cards[1] else self.closeButton
	end
end

function Journal:close()
	if self.shade.Visible then
		local selected = GuiService.SelectedObject
		self.shade.Visible = false
		if selected and selected:IsDescendantOf(self.shade) then
			GuiService.SelectedObject = self.previousSelection
		end
	end
end

return Journal
