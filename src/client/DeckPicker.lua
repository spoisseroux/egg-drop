local Shared = game:GetService("ReplicatedStorage").Shared
local Palette = require(Shared.DeckPalette)
local Themes = require(Shared.DeckThemes)
local Stickers = require(Shared.DeckStickers)

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

	local function tile(parent, name, position, size, color)
		local part = make("Frame", name, {
			Position = position, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 22,
		}, parent)
		make("UICorner", "Curve", { CornerRadius = UDim.new(0, 5) }, part)
		return part
	end

	local shell = tile(card, "Preview", UDim2.new(0.5, -34, 0, 49), UDim2.fromOffset(68, 86), Palette.Shell)
	local bezel = tile(shell, "Bezel", UDim2.fromOffset(7, 7), UDim2.fromOffset(54, 49), Palette.Rim)
	local screen = tile(bezel, "Screen", UDim2.fromOffset(3, 3), UDim2.fromOffset(48, 43), Palette.Tray)
	tile(screen, "SmallEgg", UDim2.fromOffset(12, 31), UDim2.fromOffset(8, 8), Palette.JellyBlue)
	tile(screen, "BigEgg", UDim2.fromOffset(24, 26), UDim2.fromOffset(13, 13), Palette.Ember)
	tile(shell, "Left", UDim2.fromOffset(9, 65), UDim2.fromOffset(7, 7), Palette.Ink)
	tile(shell, "Right", UDim2.fromOffset(18, 65), UDim2.fromOffset(7, 7), Palette.Ink)
	local buttonA = tile(shell, "A", UDim2.fromOffset(48, 63), UDim2.fromOffset(9, 9), Palette.Primary)
	tile(shell, "Customize", UDim2.fromOffset(23, 77), UDim2.fromOffset(10, 4), Palette.Ink)
	tile(shell, "Lounge", UDim2.fromOffset(36, 77), UDim2.fromOffset(10, 4), Palette.Ink)
	local sticker = label("TextLabel", "Sticker", "", shell, Palette.Primary)
	sticker.Position = UDim2.fromOffset(26, 62)
	sticker.Size = UDim2.fromOffset(13, 13)
	sticker.TextSize = 12
	sticker.Rotation = -11
	sticker.ZIndex = 23
	make("UICorner", "Curve", { CornerRadius = UDim.new(0, 3) }, sticker)

	local function button(name, title, position, size, color)
		local control = label("TextButton", name, title, card, color)
		control.Position, control.Size = position, size
		control.ZIndex = 22
		make("UICorner", "Curve", { CornerRadius = UDim.new(0, 8) }, control)
		return control
	end
	local self = setmetatable({
		shade = shade, shell = shell, bezel = bezel, buttonA = buttonA,
		sticker = sticker, choices = { Shell = {}, Sticker = {} }, tabs = {},
		onPreview = onPreview, onClose = onClose,
	}, Picker)
	for index, tab in ipairs({ "Shell", "Sticker" }) do
		local control = button(tab .. "Tab", tab, UDim2.new((index - 1) / 2, 9, 0, 4),
			UDim2.new(0.5, -13, 0, 44), Palette.Panel)
		self.tabs[tab] = control
		control.Activated:Connect(function()
			self:showTab(tab)
		end)
		local catalog = if tab == "Shell" then Themes else Stickers
		for slot, id in ipairs(catalog.Order) do
			local option = catalog.ById[id]
			local width = 1 / #catalog.Order
			local swatch = button(id, option.name, UDim2.new((slot - 1) * width, 5, 0, 138),
				UDim2.new(width, -9, 0, 44), option.buttons or option.color or Palette.Panel)
			swatch.TextSize = 12
			swatch.TextWrapped = true
			self.choices[tab][id] = make("UIStroke", "Selection", {
				Color = Palette.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Enabled = false,
			}, swatch)
			swatch.Activated:Connect(function()
				if tab == "Shell" then
					self:select(id, self.stickerId)
				else
					self:select(self.themeId, id)
				end
			end)
		end
	end
	local cancel = button("Cancel", "Cancel", UDim2.new(0, 9, 0, 189), UDim2.new(0.5, -13, 0, 44), Palette.Panel)
	local apply = button("Apply", "Equip", UDim2.new(0.5, 4, 0, 189), UDim2.new(0.5, -13, 0, 44), Palette.Primary)
	cancel.Activated:Connect(function()
		self:close()
	end)
	apply.Activated:Connect(function()
		local themeId, stickerId = self.themeId, self.stickerId
		self:close()
		onApply(themeId, stickerId)
	end)
	return self
end

function Picker:showTab(active)
	for tab, choices in pairs(self.choices) do
		local visible = tab == active
		self.tabs[tab].BackgroundColor3 = if visible then Palette.Primary else Palette.Panel
		for _, stroke in pairs(choices) do
			stroke.Parent.Visible = visible
		end
	end
end

function Picker:select(themeId, stickerId)
	self.themeId, self.stickerId = themeId, stickerId
	local theme = Themes.ById[themeId]
	self.shell.BackgroundColor3 = theme.shell
	self.bezel.BackgroundColor3 = theme.trim
	self.buttonA.BackgroundColor3 = theme.buttons
	Stickers.paint(self.sticker, stickerId)
	for choice, stroke in pairs(self.choices.Shell) do
		stroke.Enabled = choice == themeId
	end
	for choice, stroke in pairs(self.choices.Sticker) do
		stroke.Enabled = choice == stickerId
	end
	self.onPreview(themeId, stickerId)
end

function Picker:open(themeId, stickerId, owned)
	for id, stroke in pairs(self.choices.Sticker) do
		local available = Stickers.canEquip(id, owned)
		local swatch = stroke.Parent
		local sticker = Stickers.ById[id]
		swatch.Interactable = available
		swatch.Selectable = available
		swatch.Text = if available then sticker.name else "Hatch " .. sticker.name
		swatch.BackgroundColor3 = if available then sticker.color or Palette.Panel else Palette.Panel
	end
	self.shade.Visible = true
	self:showTab("Shell")
	self:select(themeId, stickerId)
end

function Picker:close()
	if self.shade.Visible then
		self.shade.Visible = false
		self.onClose()
	end
end

return Picker
