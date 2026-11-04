local Shared = game:GetService("ReplicatedStorage").Shared
local Palette = require(Shared.DeckPalette)
local Themes = require(Shared.DeckThemes)

local Picker = {}
Picker.__index = Picker

function Picker.new(gui, make, label, onPreview, onClose, onApply)
	local shade = make("Frame", "DeckPicker", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.Ink,
		BackgroundTransparency = 0.35, BorderSizePixel = 0, Active = true, Visible = false, ZIndex = 20,
	}, gui)
	local card = make("Frame", "Card", {
		Size = UDim2.new(1, -24, 0, 244), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Palette.Paper, ZIndex = 21, BorderSizePixel = 0,
	}, shade)
	make("UISizeConstraint", "Width", { MaxSize = Vector2.new(354, 244) }, card)
	make("UICorner", "Curve", { CornerRadius = UDim.new(0, 15) }, card)
	local heading = label("TextLabel", "Heading", "Customize your deck", card)
	heading.Position = UDim2.fromOffset(0, 6)
	heading.Size = UDim2.new(1, 0, 0, 30)
	heading.TextColor3 = Palette.Ink
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 18
	heading.ZIndex = 22

	local function tile(parent, name, position, size, color)
		local part = make("Frame", name, {
			Position = position, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 22,
		}, parent)
		make("UICorner", "Curve", { CornerRadius = UDim.new(0, 5) }, part)
		return part
	end

	local shell = tile(card, "Preview", UDim2.new(0.5, -34, 0, 40), UDim2.fromOffset(68, 86), Palette.Shell)
	local bezel = tile(shell, "Bezel", UDim2.fromOffset(7, 7), UDim2.fromOffset(54, 49), Palette.Rim)
	local screen = tile(bezel, "Screen", UDim2.fromOffset(3, 3), UDim2.fromOffset(48, 43), Palette.Tray)
	tile(screen, "SmallEgg", UDim2.fromOffset(12, 31), UDim2.fromOffset(8, 8), Palette.JellyBlue)
	tile(screen, "BigEgg", UDim2.fromOffset(24, 26), UDim2.fromOffset(13, 13), Palette.Ember)
	tile(shell, "DPad", UDim2.fromOffset(10, 67), UDim2.fromOffset(16, 5), Palette.Ink)
	tile(shell, "DPadStem", UDim2.fromOffset(15, 62), UDim2.fromOffset(5, 15), Palette.Ink)
	local buttonA = tile(shell, "A", UDim2.fromOffset(48, 63), UDim2.fromOffset(9, 9), Palette.Primary)
	local buttonB = tile(shell, "B", UDim2.fromOffset(37, 70), UDim2.fromOffset(8, 8), Palette.Primary)

	local function button(name, title, position, size, color)
		local control = label("TextButton", name, title, card, color)
		control.Position, control.Size = position, size
		control.ZIndex = 22
		make("UICorner", "Curve", { CornerRadius = UDim.new(0, 8) }, control)
		return control
	end
	local self = setmetatable({
		shade = shade, shell = shell, bezel = bezel, buttonA = buttonA, buttonB = buttonB,
		choices = {}, onPreview = onPreview, onClose = onClose,
	}, Picker)
	for index, id in ipairs(Themes.Order) do
		local theme = Themes.ById[id]
		local swatch = button(id, theme.name, UDim2.new((index - 1) / 4, 9, 0, 136),
			UDim2.new(0.25, -12, 0, 44), theme.buttons)
		self.choices[id] = make("UIStroke", "Selection", {
			Color = Palette.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Enabled = false,
		}, swatch)
		swatch.Activated:Connect(function()
			self:select(id)
		end)
	end
	local cancel = button("Cancel", "Cancel", UDim2.new(0, 9, 0, 189), UDim2.new(0.5, -13, 0, 44), Palette.Panel)
	local apply = button("Apply", "Equip", UDim2.new(0.5, 4, 0, 189), UDim2.new(0.5, -13, 0, 44), Palette.Primary)
	cancel.Activated:Connect(function()
		self:close()
	end)
	apply.Activated:Connect(function()
		local id = self.selected
		self:close()
		onApply(id)
	end)
	return self
end

function Picker:select(id)
	self.selected = id
	local theme = Themes.ById[id]
	self.shell.BackgroundColor3 = theme.shell
	self.bezel.BackgroundColor3 = theme.trim
	self.buttonA.BackgroundColor3 = theme.buttons
	self.buttonB.BackgroundColor3 = theme.buttons
	for choice, stroke in pairs(self.choices) do
		stroke.Enabled = choice == id
	end
	self.onPreview(id)
end

function Picker:open(id)
	self.shade.Visible = true
	self:select(id)
end

function Picker:close()
	if self.shade.Visible then
		self.shade.Visible = false
		self.onClose()
	end
end

return Picker
