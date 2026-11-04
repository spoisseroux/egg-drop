local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Art = require(script.Parent.DeckArt)
local Portrait = require(script.Parent.PetPortrait)

local Journal = {}
Journal.__index = Journal

function Journal.new(gui, make, label, onVisit)
	local shade = make("Frame", "PetJournal", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Art.Ink, BorderSizePixel = 0,
		BackgroundTransparency = 0.30, Active = true, Visible = false, ZIndex = 20,
	}, gui)
	local card = make("Frame", "Card", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 0, 244), BorderSizePixel = 0, ZIndex = 21,
	}, shade)
	make("UISizeConstraint", "Limit", { MaxSize = Vector2.new(384, 244) }, card)
	Art.panel(card, 12)
	local title = label("TextLabel", "Title", "", card)
	title.Size = UDim2.new(1, 0, 0, 40)
	title.TextColor3 = Art.Cyan
	title.Font = Enum.Font.Code
	title.TextSize = 16
	title.ZIndex = 22
	local self = setmetatable({ shade = shade, title = title, cards = {}, portraits = {} }, Journal)
	for index, pet in ipairs(Pets) do
		local entry = label("TextButton", pet.name, "", card, Art.Raised)
		entry.Position = UDim2.new((index - 1) % 2 * 0.5, 7, 0, 42 + math.floor((index - 1) / 2) * 68)
		entry.Size = UDim2.new(0.5, -14, 0, 60)
		entry.ZIndex = 22
		Art.button(entry, 6)
		local well = Art.frame(entry, "PortraitWell", Art.Ink, UDim2.fromOffset(5, 8), UDim2.fromOffset(42, 44))
		Art.corner(well, 4)
		local name = Art.text(entry, "Species", pet.name, UDim2.fromOffset(53, 9), UDim2.new(1, -56, 0, 20),
			Art.Silver, 15, Enum.Font.GothamBold)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local status = Art.text(entry, "Status", "", UDim2.fromOffset(53, 31), UDim2.new(1, -56, 0, 20),
			Art.Muted, 11, Enum.Font.GothamMedium)
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextTruncate = Enum.TextTruncate.AtEnd
		self.cards[index] = entry
		entry.Activated:Connect(function()
			if self.shade.Visible and index <= self.owned then
				self:close()
				onVisit(index)
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

function Journal:open(owned, companionId, selected)
	self.owned = owned
	self.title.Text = string.format("PET JOURNAL  ·  %02d/%02d", owned, #Pets)
	for index, entry in ipairs(self.cards) do
		local pet = Pets[index]
		local unlocked = index <= owned
		local equipped = pet.id == companionId
		entry.Status.Text = if equipped then "Equipped" elseif unlocked then "Equip" else "Hatch at " .. pet.charge
		entry.Status.TextColor3 = if equipped then Art.Cyan else Art.Muted
		entry.Species.TextColor3 = if unlocked then Art.Silver else Art.Muted
		if not self.portraits[index] or self.portraits[index].unlocked ~= unlocked then
			if self.portraits[index] then
				self.portraits[index].sprite:Destroy()
			end
			self.portraits[index] = {
				unlocked = unlocked,
				sprite = Portrait.create(entry.PortraitWell, pet, 3, UDim2.fromScale(0.5, 0.5), 23, not unlocked),
			}
		end
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
