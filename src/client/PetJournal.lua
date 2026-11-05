local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Art = require(script.Parent.DeckArt)
local Portrait = require(script.Parent.PetPortrait)

local Journal = {}
Journal.__index = Journal
local CARD_HEIGHT = 244

function Journal.new(gui, make, label, onVisit)
	local shade = make("Frame", "PetJournal", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Art.Ink, BorderSizePixel = 0,
		BackgroundTransparency = 0.30, Active = true, Visible = false, ZIndex = 20,
	}, gui)
	local scroll = make("ScrollingFrame", "Scroll", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Art.Cyan, ElasticBehavior = Enum.ElasticBehavior.Never,
	}, shade)
	local card = make("Frame", "Card", {
		AnchorPoint = Vector2.new(0.5, 0), BorderSizePixel = 0, ZIndex = 21,
	}, scroll)
	local function layout()
		local size = scroll.AbsoluteSize
		local height = math.max(size.Y, CARD_HEIGHT + 12)
		scroll.CanvasSize = UDim2.fromOffset(size.X, height)
		scroll.ScrollingEnabled = height > size.Y
		card.Size = UDim2.fromOffset(math.clamp(size.X - 24, 1, 384), CARD_HEIGHT)
		card.Position = UDim2.fromOffset(size.X / 2, (height - CARD_HEIGHT) / 2)
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
	Art.panel(card, 12)
	local title = label("TextLabel", "Title", "", card)
	title.Size = UDim2.new(1, 0, 0, 34)
	title.TextColor3 = Art.Cyan
	title.Font = Enum.Font.Code
	title.TextSize = 16
	title.ZIndex = 22
	local self = setmetatable({ shade = shade, scroll = scroll, title = title, cards = {}, portraits = {} }, Journal)
	for index, pet in ipairs(Pets.collection) do
		local entry = label("TextButton", pet.name, "", card, Art.Raised)
		entry.Position = UDim2.new((index - 1) % 2 * 0.5, 7, 0, 36 + math.floor((index - 1) / 2) * 51)
		entry.Size = UDim2.new(if pet.trial then 1 else 0.5, -14, 0, 46)
		entry.ZIndex = 22
		Art.button(entry, 6)
		local well = Art.frame(entry, "PortraitWell", Art.Ink, UDim2.fromOffset(5, 5), UDim2.fromOffset(36, 36))
		Art.corner(well, 4)
		local name = Art.text(entry, "Species", if pet.trial then pet.name .. "  ·  Rare" else pet.name,
			UDim2.fromOffset(47, 4), UDim2.new(1, -51, 0, 20),
			Art.Silver, 15, Enum.Font.GothamBold)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local status = Art.text(entry, "Status", "", UDim2.fromOffset(47, 23), UDim2.new(1, -51, 0, 17),
			Art.Muted, 11, Enum.Font.GothamMedium)
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextTruncate = Enum.TextTruncate.AtEnd
		self.cards[index] = entry
		entry.Activated:Connect(function()
			if self.shade.Visible and entry.Interactable then
				self:close()
				onVisit(pet)
			end
		end)
	end
	local close = label("TextButton", "Close", "Close", card, Art.Ink)
	close.Position = UDim2.new(0.25, 0, 1, -52)
	close.Size = UDim2.new(0.5, 0, 0, 44)
	close.ZIndex = 22
	close.TextColor3 = Art.Silver
	Art.button(close, 6)
	close.Activated:Connect(function()
		self:close()
	end)
	self.closeButton = close
	return self
end

function Journal:open(owned, trials, companionId, selected)
	self.title.Text = string.format("PET JOURNAL  ·  %02d/%02d", Pets.ownedCount(owned, trials), #Pets.collection)
	for index, entry in ipairs(self.cards) do
		local pet = Pets.collection[index]
		local unlocked = Pets.isUnlocked(pet, owned, trials)
		local equipped = pet.id == companionId
		entry.Status.Text = if equipped then "Equipped" elseif unlocked then "Equip"
			elseif pet.trial then pet.trial.hint else "Hatch at " .. pet.charge
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
		entry.Interactable = unlocked
		entry.Selectable = unlocked
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
