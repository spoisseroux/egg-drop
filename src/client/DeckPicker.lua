local Shared = game:GetService("ReplicatedStorage").Shared
local Palette = require(Shared.DeckPalette)
local Themes = require(Shared.DeckThemes)
local Stickers = require(Shared.DeckStickers)
local Trials = require(Shared.PocketTrials)
local Art = require(script.Parent.DeckArt)

local Picker = {}
Picker.__index = Picker
local CARD_HEIGHT = 320
local trialIcons = {
	{ ".XX....", "X..X...", "X..XXX.", ".XX..X.", "...X.X.", "....XX." },
	{ ".....X.", ".....X.", "...X.X.", "...X.X.", ".X.X.X.", ".X.X.X." },
	{ "...X...", "..XXX..", ".XX.XX.", ".X.X.X.", ".XX.XX.", "..XXX.." },
}

function Picker.new(gui, make, label, onPreview, onClose, onApply, onSetting)
	local shade = make("Frame", "DeckPicker", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Art.Ink,
		BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, Visible = false, ZIndex = 20,
	}, gui)
	local scroll = make("ScrollingFrame", "Scroll", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Art.Cyan, ElasticBehavior = Enum.ElasticBehavior.Never,
	}, shade)
	local card = make("Frame", "Card", {
		AnchorPoint = Vector2.new(0.5, 0), ZIndex = 21, BorderSizePixel = 0,
	}, scroll)
	local function layout()
		local size = scroll.AbsoluteSize
		local height = math.max(size.Y, CARD_HEIGHT + 40)
		scroll.CanvasSize = UDim2.fromOffset(size.X, height)
		scroll.ScrollingEnabled = height > size.Y
		card.Size = UDim2.fromOffset(math.clamp(size.X - 40, 1, 354), CARD_HEIGHT)
		card.Position = UDim2.fromOffset(size.X / 2, (height - CARD_HEIGHT) / 2)
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
	Art.panel(card, 12)

	local function tile(parent, name, position, size, color)
		local part = make("Frame", name, {
			Position = position, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 22,
		}, parent)
		make("UICorner", "Curve", { CornerRadius = UDim.new(0, 5) }, part)
		return part
	end

	local display = tile(card, "Display", UDim2.fromOffset(9, 56), UDim2.new(1, -18, 0, 94), Art.Ink)
	Art.stroke(display, Art.Line)
	local shell = tile(display, "Preview", UDim2.new(0.5, -51, 0, 15), UDim2.fromOffset(102, 63), Palette.Shell)
	Art.shade(shell, 1, 0.75)
	Art.stroke(shell, Art.Muted, 0.45)
	local previewName = Art.text(display, "PreviewName", "", UDim2.fromOffset(9, 68),
		UDim2.new(0.5, -64, 0, 16), Art.Muted, 11)
	previewName.TextXAlignment = Enum.TextXAlignment.Left
	local deckId = Art.text(display, "Model", "PD·01", UDim2.new(0.5, 57, 0, 68),
		UDim2.new(0.5, -67, 0, 16), Art.Muted, 11)
	deckId.TextXAlignment = Enum.TextXAlignment.Right
	local bezel = tile(shell, "Bezel", UDim2.fromOffset(29, 5), UDim2.fromOffset(44, 53), Palette.Rim)
	local screen = tile(bezel, "Screen", UDim2.fromOffset(4, 3), UDim2.fromOffset(36, 47), Palette.Tray)
	tile(screen, "SmallEgg", UDim2.fromOffset(6, 34), UDim2.fromOffset(8, 8), Palette.JellyBlue)
	tile(screen, "BigEgg", UDim2.fromOffset(17, 29), UDim2.fromOffset(13, 13), Palette.Ember)
	tile(shell, "AimRocker", UDim2.fromOffset(7, 25), UDim2.fromOffset(16, 7), Palette.Ink)
	local buttonA = tile(shell, "A", UDim2.fromOffset(80, 23), UDim2.fromOffset(13, 13), Palette.Primary)
	tile(shell, "Customize", UDim2.fromOffset(8, 46), UDim2.fromOffset(14, 4), Palette.Ink)
	tile(shell, "Lounge", UDim2.fromOffset(8, 54), UDim2.fromOffset(14, 4), Palette.Ink)
	local sticker = label("TextLabel", "Sticker", "", shell, Palette.Primary)
	sticker.Position = UDim2.fromOffset(80, 40)
	sticker.Size = UDim2.fromOffset(13, 13)
	sticker.TextSize = 12
	sticker.Rotation = -11
	sticker.ZIndex = 23
	make("UICorner", "Curve", { CornerRadius = UDim.new(0, 3) }, sticker)

	local function button(name, title, position, size, color)
		local control = label("TextButton", name, title, card, color)
		control.Position, control.Size = position, size
		control.ZIndex = 22
		Art.button(control, 6)
		control.TextColor3 = Art.Silver
		return control
	end
	local self = setmetatable({
		shade = shade, scroll = scroll, shell = shell, bezel = bezel, buttonA = buttonA,
		display = display, previewName = previewName,
		sticker = sticker, choices = { Shell = {}, Sticker = {} }, tabs = {}, rows = {},
		onPreview = onPreview, onClose = onClose,
	}, Picker)
	for index, tab in ipairs({ "Shell", "Sticker", "Club" }) do
		local control = button(tab .. "Tab", tab, UDim2.new((index - 1) / 3, 7, 0, 6),
			UDim2.new(1 / 3, -14, 0, 44), Art.Raised)
		local bar = Art.frame(control, "SelectedTab", Art.Cyan, UDim2.new(0.25, 0, 1, -3), UDim2.new(0.5, 0, 0, 2))
		Art.corner(bar, 1)
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
			local swatch = button(id, option.name, UDim2.new((slot - 1) % columns * width, 5, 0, 156 + math.floor((slot - 1) / columns) * 49),
				UDim2.new(width, -9, 0, 44), Art.Raised)
			swatch.TextSize = 12
			swatch.TextWrapped = true
			swatch.TextYAlignment = Enum.TextYAlignment.Bottom
			make("UIPadding", "LabelInset", { PaddingBottom = UDim.new(0, 4) }, swatch)
			Art.text(swatch, "Chip", if tab == "Shell" then "■" else option.mark or "–",
				UDim2.fromOffset(0, 2), UDim2.new(1, 0, 0, 21), option.buttons or option.color or Art.Muted, 19)
			self.choices[tab][id] = make("UIStroke", "Selection", {
				Color = Art.Cyan, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Enabled = false,
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
	local cancel = button("Cancel", "Close", UDim2.new(0, 9, 1, -50), UDim2.new(0.5, -13, 0, 44), Art.Ink)
	local apply = button("Apply", "Equip", UDim2.new(0.5, 4, 1, -50), UDim2.new(0.5, -13, 0, 44), Art.Cyan)
	apply.TextColor3 = Art.Ink
	self.cancel, self.apply = cancel, apply
	local function clubLabel(name, content, y, size, background)
		local row = label("TextLabel", name, content, card, background)
		row.Position, row.Size = UDim2.fromOffset(9, y), UDim2.new(1, -18, 0, 27)
		row.TextSize, row.ZIndex, row.Visible = size, 22, false
		row.TextColor3 = Art.Silver
		return row
	end
	self.clubHeader = clubLabel("TrialHeading", "", 53, 16)
	self.clubHeader.Font = Enum.Font.Code
	self.clubHeader.TextColor3 = Art.Cyan
	for index, goal in ipairs(Trials.Goals) do
		local row = Art.frame(card, "Trial" .. goal.bit, Art.Raised, UDim2.fromOffset(9, 81 + (index - 1) * 37),
			UDim2.new(1, -18, 0, 34), 22)
		Art.corner(row, 5)
		Art.pixels(row, "Badge", trialIcons[index], { X = Art.Cyan }, 2, UDim2.fromOffset(10, 9))
		local title = Art.text(row, "Goal", goal.hint, UDim2.fromOffset(34, 0), UDim2.new(1, -105, 1, -1),
			Art.Silver, 13, Enum.Font.GothamMedium)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		local status = Art.text(row, "Progress", "", UDim2.new(1, -66, 0, 0), UDim2.new(0, 57, 1, -1), Art.Muted, 12)
		status.TextXAlignment = Enum.TextXAlignment.Right
		local track = Art.frame(row, "Track", Art.Ink, UDim2.new(0, 34, 1, -4), UDim2.new(1, -44, 0, 2))
		local fill = Art.frame(track, "Fill", Art.Cyan, UDim2.fromOffset(0, 0), UDim2.fromScale(0, 1))
		self.rows[index] = { frame = row, title = title, status = status, fill = fill }
	end
	self.reward = clubLabel("Reward", "", 193, 12)
	Art.insignia(self.reward, 1, UDim2.fromOffset(5, 9), Art.Amber, 23)
	self.sound = button("SoundSetting", "", UDim2.fromOffset(9, 223), UDim2.new(0.5, -13, 0, 44), Art.Raised)
	self.motion = button("MotionSetting", "", UDim2.new(0.5, 4, 0, 223), UDim2.new(0.5, -13, 0, 44), Art.Raised)
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
	self.display.Visible = not club
	self.apply.Visible = not club
	self.cancel.Size = UDim2.new(if club then 1 else 0.5, if club then -18 else -13, 0, 44)
	self.clubHeader.Visible, self.reward.Visible, self.sound.Visible, self.motion.Visible = club, club, club, club
	for _, row in ipairs(self.rows) do
		row.frame.Visible = club
	end
	for tab, control in pairs(self.tabs) do
		control.BackgroundColor3 = if tab == active then Art.Raised else Art.Ink
		control.TextColor3 = if tab == active then Art.Cyan else Art.Silver
		control.SelectedTab.Visible = tab == active
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
	self.previewName.Text = theme.name:upper()
	self.shell.BackgroundColor3 = theme.face or theme.shell
	self.shell.AimRocker.BackgroundColor3 = theme.rocker or Palette.Ink
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
		local row = self.rows[index]
		row.title.Text = if goal == Trials.HighRoller then (if done then "Bloom Pip unlocked" else "Bloom Pip · Score " .. goal.target)
			elseif done then goal.name else goal.hint
		row.status.Text = if done then "✓ DONE" elseif index == 3 then "0/1" else string.format("%d/%d", current, goal.target)
		row.status.TextColor3 = if done then Color3.fromHex("#A9E34B") else Art.Muted
		row.fill.Size = UDim2.fromScale(if done then 1 else math.min(1, current / goal.target), 1)
		row.fill.BackgroundColor3 = if done then Color3.fromHex("#A9E34B") else Art.Cyan
		count += if done then 1 else 0
	end
	self.clubHeader.Text = string.format("POCKET TRIALS   %d/%d", count, #Trials.Goals)
	local clubComplete = Trials.clubComplete(mask)
	self.reward.Text = if clubComplete then "Club sticker ready in the Sticker tab" else "Finish all three to earn the Club sticker"
	self.reward.TextColor3 = if clubComplete then Art.Amber else Art.Muted
	for id, stroke in pairs(self.choices.Sticker) do
		local available = Stickers.canEquip(id, owned, mask)
		local swatch = stroke.Parent
		local sticker = Stickers.ById[id]
		swatch.Interactable = available
		swatch.Selectable = available
		swatch.Text = if available then sticker.name elseif sticker.trials then "Club trials" else "Hatch " .. sticker.name
		swatch.TextColor3 = if available then Art.Silver else Art.Muted
		swatch.Chip.TextColor3 = if available then sticker.color or Art.Muted else Art.Muted
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
