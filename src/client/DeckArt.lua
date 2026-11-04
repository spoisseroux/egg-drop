local Art = {}

for name, hex in pairs({
	Backdrop = "#10151C", Ink = "#0B1016", Surface = "#1A2430", Raised = "#263443",
	Line = "#465B70", Silver = "#E8F0F6", Muted = "#A8BACB", Cyan = "#38C9F4", Amber = "#FFCA47",
}) do
	Art[name] = Color3.fromHex(hex)
end

local function node(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

function Art.corner(parent, radius)
	return node("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
end

function Art.stroke(parent, color, transparency, thickness)
	return node("UIStroke", parent, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = color,
		Thickness = thickness or 1, Transparency = transparency or 0,
	})
end

function Art.shade(parent, top, bottom)
	return node("UIGradient", parent, {
		Rotation = 90, Color = ColorSequence.new(Color3.new(top, top, top), Color3.new(bottom, bottom, bottom)),
	})
end

function Art.frame(parent, name, color, position, size, z)
	return node("Frame", parent, {
		Name = name, Position = position, Size = size, BackgroundColor3 = color,
		BorderSizePixel = 0, ZIndex = z or parent.ZIndex, Active = false,
	})
end

function Art.text(parent, name, content, position, size, color, textSize, font)
	return node("TextLabel", parent, {
		Name = name, Text = content, Position = position, Size = size, TextColor3 = color,
		TextSize = textSize, Font = font or Enum.Font.Code, BackgroundTransparency = 1,
		ZIndex = parent.ZIndex + 1, Active = false,
	})
end

function Art.pixels(parent, name, rows, colors, unit, position, z)
	local sprite = Art.frame(parent, name, Art.Ink, position,
		UDim2.fromOffset(#rows[1] * unit, #rows * unit), z)
	sprite.BackgroundTransparency = 1
	for y, row in ipairs(rows) do
		local start = 1
		while start <= #row do
			local symbol = row:sub(start, start)
			local stop = start + 1
			while row:sub(stop, stop) == symbol do
				stop += 1
			end
			if colors[symbol] then
				Art.frame(sprite, "Pixel", colors[symbol], UDim2.fromOffset((start - 1) * unit, (y - 1) * unit),
					UDim2.fromOffset((stop - start) * unit, unit))
			end
			start = stop
		end
	end
	return sprite
end

local eggMark = { "..X..", ".....", "..X..", ".....", "..X..", ".X.X.", "X...X", "X..XX", ".XXX." }

function Art.insignia(parent, unit, position, tint, z)
	return Art.pixels(parent, "DropMark", eggMark, { X = tint }, unit, position, z)
end

function Art.panel(parent, radius, accent)
	parent.BackgroundColor3 = Art.Surface
	Art.corner(parent, radius)
	Art.shade(parent, 1, 0.8)
	Art.stroke(parent, Art.Line, 0.1)
	local mark = Art.frame(parent, "Accent", accent or Art.Cyan, UDim2.fromOffset(16, 0), UDim2.fromOffset(32, 2))
	Art.corner(mark, 1)
end

function Art.button(button, radius)
	button.AutoButtonColor = false
	Art.corner(button, radius)
	local border = Art.stroke(button, Art.Line, 0.12)
	button.MouseButton1Down:Connect(function()
		if button.Interactable then
			border.Color = Art.Cyan
		end
	end)
	local function restore()
		border.Color = if button == game:GetService("GuiService").SelectedObject
			then Art.Cyan else Art.Line
	end
	button.MouseButton1Up:Connect(restore)
	button.MouseLeave:Connect(restore)
	button.SelectionGained:Connect(function() border.Color = Art.Cyan end)
	button.SelectionLost:Connect(function() border.Color = Art.Line end)
	return border
end

function Art.deck(backdrop, shell, bezel)
	backdrop.BackgroundColor3 = Art.Backdrop
	Art.shade(backdrop, 1, 0.58)
	Art.shade(shell, 1, 0.67)
	Art.shade(bezel, 1, 0.77)
	local seam = Art.frame(shell, "MoldSeam", Art.Ink, UDim2.fromOffset(5, 5), UDim2.new(1, -10, 1, -10))
	seam.BackgroundTransparency = 1
	Art.corner(seam, 13)
	Art.stroke(seam, Art.Ink, 0.35)
	for _, side in ipairs({ 0, 1 }) do
		local screw = Art.frame(shell, "Screw", Art.Ink,
			UDim2.new(side, if side == 0 then 15 else -23, 1, -22), UDim2.fromOffset(8, 8))
		Art.corner(screw, 4)
		Art.stroke(screw, Art.Line)
		Art.frame(screw, "Slot", Art.Line, UDim2.fromOffset(2, 3), UDim2.fromOffset(4, 1)).Rotation = -28
	end
	local stripe = Art.frame(shell, "CartridgeStripe", Art.Cyan, UDim2.fromOffset(15, 12), UDim2.fromOffset(2, 10))
	Art.corner(stripe, 1)
	Art.insignia(shell, 2, UDim2.fromOffset(22, 7), Art.Cyan, shell.ZIndex + 1)
	local glint = Art.frame(bezel, "LensGlint", Art.Silver,
		UDim2.new(0, 14, 0, 2), UDim2.new(1, -28, 0, 1))
	glint.BackgroundTransparency = 0.65
end

return Art
