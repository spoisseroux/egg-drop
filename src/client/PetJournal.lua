local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.DeckPalette)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)

local Journal = {}
Journal.__index = Journal

function Journal.new(gui, make, label, onVisit)
	local shade = make("Frame", "PetJournal", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.Ink, BorderSizePixel = 0,
		BackgroundTransparency = 0.30, Active = true, Visible = false, ZIndex = 20,
	}, gui)
	local card = make("Frame", "Card", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 0, 244), BackgroundColor3 = Palette.Paper, BorderSizePixel = 0, ZIndex = 21,
	}, shade)
	make("UISizeConstraint", "Limit", { MaxSize = Vector2.new(384, 244) }, card)
	make("UICorner", "Corner", { CornerRadius = UDim.new(0, 14) }, card)
	local title = label("TextLabel", "Title", "", card)
	title.Size = UDim2.new(1, 0, 0, 40)
	title.TextColor3 = Palette.Ink
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.ZIndex = 22
	local self = setmetatable({ shade = shade, title = title, cards = {} }, Journal)
	for index, pet in ipairs(Pets) do
		local entry = label("TextButton", pet.name, "", card, pet.color)
		entry.Position = UDim2.new((index - 1) % 2 * 0.5, 10, 0, 45 + math.floor((index - 1) / 2) * 69)
		entry.Size = UDim2.new(0.5, -20, 0, 59)
		entry.TextWrapped = true
		entry.TextSize = 13
		entry.ZIndex = 22
		make("UICorner", "Corner", { CornerRadius = UDim.new(0, 9) }, entry)
		self.cards[index] = entry
		entry.Activated:Connect(function()
			if self.shade.Visible and index <= self.owned then
				self:close()
				onVisit(index)
			end
		end)
	end
	local close = label("TextButton", "Close", "Close", card, Palette.Panel)
	close.Position = UDim2.new(0.25, 0, 1, -52)
	close.Size = UDim2.new(0.5, 0, 0, 44)
	close.ZIndex = 22
	make("UICorner", "Corner", { CornerRadius = UDim.new(0, 9) }, close)
	close.Activated:Connect(function()
		self:close()
	end)
	self.closeButton = close
	return self
end

function Journal:open(owned, companionId, selected)
	self.owned = owned
	self.title.Text = string.format("Pet journal   %d / %d", owned, #Pets)
	for index, entry in ipairs(self.cards) do
		local pet = Pets[index]
		local unlocked = index <= owned
		entry.Text = pet.name .. "\n" .. (if pet.id == companionId then "Equipped companion"
			elseif unlocked then "Equip companion" else string.format("Hatch at %d charge", pet.charge))
		entry.BackgroundColor3 = if unlocked then pet.color else Palette.Panel
		entry.Interactable = unlocked
		entry.Selectable = unlocked
	end
	self.shade.Visible = true
	self.previousSelection = GuiService.SelectedObject
	if selected then
		GuiService.SelectedObject = self.cards[1] or self.closeButton
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
