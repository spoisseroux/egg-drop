local Shared = game:GetService("ReplicatedStorage").Shared
local Palette = require(Shared.DeckPalette)
local Themes = require(Shared.DeckThemes)
local Stickers = require(Shared.DeckStickers)
local Trials = require(Shared.PocketTrials)

local Picker = {}
Picker.__index = Picker

function Picker.new(gui, make, label, onPreview, onClose, onApply, onSetting)
	local shade = make("Frame", "DeckPicker", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.Ink,
		BackgroundTransparency = 0.35, BorderSizePixel = 0, Active = true, Visible = false, ZIndex = 20,
	}, gui)
	local scroll = make("ScrollingFrame", "Scroll", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.Primary, ElasticBehavior = Enum.ElasticBehavior.Never,
	}, shade)
	local card = make("Frame", "Card", {
		AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Palette.Paper, ZIndex = 21, BorderSizePixel = 0,
	}, scroll)
	local function layout()
		local size = scroll.AbsoluteSize
		local height = math.max(size.Y, 296)
		scroll.CanvasSize = UDim2.fromOffset(size.X, height)
		scroll.ScrollingEnabled = height > size.Y
		card.Size = UDim2.fromOffset(math.clamp(size.X - 24, 1, 354), 284)
		card.Position = UDim2.fromOffset(size.X / 2, (height - 284) / 2)
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
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
		shade = shade, scroll = scroll, shell = shell, bezel = bezel, buttonA = buttonA,
		sticker = sticker, choices = { Shell = {}, Sticker = {} }, tabs = {}, rows = {},
		onPreview = onPreview, onClose = onClose,
	}, Picker)
	for index, tab in ipairs({ "Shell", "Sticker", "Club" }) do
		local control = button(tab .. "Tab", tab, UDim2.new((index - 1) / 3, 7, 0, 4),
			UDim2.new(1 / 3, -14, 0, 44), Palette.Panel)
		self.tabs[tab] = control
		control.Activated:Connect(function()
			self:showTab(tab)
		end)
		if tab == "Club" then
			continue
		end
		local catalog = if tab == "Shell" then Themes else Stickers
		local columns = if tab == "Shell" then #catalog.Order else 3
		for slot, id in ipairs(catalog.Order) do
			local option = catalog.ById[id]
			local width = 1 / columns
			local swatch = button(id, option.name, UDim2.new((slot - 1) % columns * width, 5, 0, 137 + math.floor((slot - 1) / columns) * 47),
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
	local cancel = button("Cancel", "Close", UDim2.new(0, 9, 1, -50), UDim2.new(0.5, -13, 0, 44), Palette.Panel)
	local apply = button("Apply", "Equip", UDim2.new(0.5, 4, 1, -50), UDim2.new(0.5, -13, 0, 44), Palette.Primary)
	self.cancel, self.apply = cancel, apply
	local function clubLabel(name, content, y, size, background)
		local row = label("TextLabel", name, content, card, background)
		row.Position, row.Size = UDim2.fromOffset(9, y), UDim2.new(1, -18, 0, 27)
		row.TextSize, row.ZIndex, row.Visible = size, 22, false
		row.TextColor3 = Palette.Ink
		return row
	end
	self.clubHeader = clubLabel("TrialHeading", "", 51, 16)
	for index, goal in ipairs(Trials.Goals) do
		local row = clubLabel("Trial" .. goal.bit, "", 80 + (index - 1) * 30, 13, Palette.Panel)
		make("UICorner", "Curve", { CornerRadius = UDim.new(0, 6) }, row)
		self.rows[index] = row
	end
	self.reward = clubLabel("Reward", "", 166, 12)
	self.sound = button("SoundSetting", "", UDim2.fromOffset(9, 190), UDim2.new(0.5, -13, 0, 44), Palette.Panel)
	self.motion = button("MotionSetting", "", UDim2.new(0.5, 4, 0, 190), UDim2.new(0.5, -13, 0, 44), Palette.Panel)
	self.sound.TextSize, self.motion.TextSize = 14, 14
	self.sound.Activated:Connect(function()
		onSetting("sound")
	end)
	self.motion.Activated:Connect(function()
		onSetting("motion")
	end)
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
	self.active = active
	local club = active == "Club"
	self.shell.Visible = not club
	self.apply.Visible = not club
	self.cancel.Size = UDim2.new(if club then 1 else 0.5, if club then -18 else -13, 0, 44)
	self.clubHeader.Visible, self.reward.Visible, self.sound.Visible, self.motion.Visible = club, club, club, club
	for _, row in ipairs(self.rows) do
		row.Visible = club
	end
	for tab, control in pairs(self.tabs) do
		control.BackgroundColor3 = if tab == active then Palette.Primary else Palette.Panel
	end
	for tab, choices in pairs(self.choices) do
		local visible = tab == active
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

function Picker:updateClub(owned, mask, peak, score, sound, reduced, systemReduced)
	self.sound.Text = "SFX: " .. sound
	self.motion.Text = if systemReduced then "Motion: Roblox" elseif reduced then "Motion: Low" else "Motion: Full"
	self.motion.Interactable = not systemReduced
	self.motion.Selectable = not systemReduced
	local count = 0
	for index, goal in ipairs(Trials.Goals) do
		local done = bit32.band(mask, goal.bit) ~= 0
		local current = if index == 1 then peak elseif index == 2 then score else 0
		local detail = if done then "DONE" elseif index == 3 then "" else string.format("  %d/%d", current, goal.target)
		self.rows[index].Text = (if done then goal.name .. "   " else goal.hint .. "   ") .. detail
		self.rows[index].BackgroundColor3 = if done then Palette.Primary else Palette.Panel
		count += if done then 1 else 0
	end
	self.clubHeader.Text = string.format("POCKET TRIALS   %d/%d", count, #Trials.Goals)
	self.reward.Text = if mask == Trials.All then "Club sticker ready in the Sticker tab" else "Finish all three to earn the Club sticker"
	for id, stroke in pairs(self.choices.Sticker) do
		local available = Stickers.canEquip(id, owned, mask)
		local swatch = stroke.Parent
		local sticker = Stickers.ById[id]
		swatch.Interactable = available
		swatch.Selectable = available
		swatch.Text = if available then sticker.name elseif sticker.trials then "Club trials" else "Hatch " .. sticker.name
		swatch.BackgroundColor3 = if available then sticker.color or Palette.Panel else Palette.Panel
	end
end

function Picker:open(themeId, stickerId)
	self.scroll.CanvasPosition = Vector2.zero
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
