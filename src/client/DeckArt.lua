local Art = {}

-- Stable interface roles; player finishes only tint the physical casing/backing.
Art.Type = { Reward = 34, Heading = 26, Action = 18, Body = 16, Supporting = 14, Compact = 12 }
Art.Space = { Small = 4, Related = 8, Group = 16, Panel = 24 }
for name, hex in pairs({
	Backdrop = "#232620", Ink = "#282722", Surface = "#353630", Raised = "#45483E", Inset = "#292C27",
	Line = "#8D9E8E", Silver = "#F5F6F1", Muted = "#CDD1C7", Amber = "#FFBF50",
	Leaf = "#A8DE78", Orange = "#FFBF50", Canopy = "#303B31", Field = "#2B332C",
	Focus = "#83D7EF", Danger = "#FF907B", LCD = "#D2E5BB", LCDInk = "#213D37",
}) do
	Art[name] = Color3.fromHex(hex)
end
-- Existing consumers use Cyan for affirmative fills. Focus has its own role.
Art.Cyan = Art.Leaf

local function node(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

function Art.corner(parent, radius)
	local curve = parent:FindFirstChildOfClass("UICorner") or node("UICorner", parent, {})
	curve.CornerRadius = UDim.new(0, radius)
	return curve
end

function Art.stroke(parent, color, transparency, thickness)
	return node("UIStroke", parent, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = color,
		Thickness = thickness or 1, Transparency = transparency or 0,
	})
end

function Art.shade(parent, top, bottom)
	local gradient = parent:FindFirstChildOfClass("UIGradient") or node("UIGradient", parent, {})
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(top, top, top), Color3.new(bottom, bottom, bottom))
	return gradient
end

function Art.frame(parent, name, color, position, size, z)
	return node("Frame", parent, {
		Name = name, Position = position, Size = size, BackgroundColor3 = color,
		BorderSizePixel = 0, ZIndex = z or parent.ZIndex, Active = false,
	})
end

-- Passive glass instruments share one recessed face; their children remain data,
-- never action seats or focus targets. All depth stays inside the solved rectangle.
function Art.instrument(parent)
	parent.BackgroundColor3=Color3.fromHex("#2B352D")
	parent.ClipsDescendants=true
	Art.corner(parent,8);Art.shade(parent,.78,1)
	if not parent:FindFirstChild("InsetShadow")then
		local top=Art.frame(parent,"InsetShadow",Art.Ink,UDim2.fromOffset(3,1),UDim2.new(1,-6,0,2),parent.ZIndex+1)
		top.BackgroundTransparency=.18;Art.corner(top,1)
		local lip=Art.frame(parent,"InsetLip",Art.Line,UDim2.new(0,4,1,-2),UDim2.new(1,-8,0,1),parent.ZIndex+1)
		lip.BackgroundTransparency=.65
	end
	return parent
end

function Art.text(parent, name, content, position, size, color, textSize, font)
	return node("TextLabel", parent, {
		Name = name, Text = content, Position = position, Size = size, TextColor3 = color,
		TextSize = textSize, Font = font or Enum.Font.Gotham, BackgroundTransparency = 1,
		ZIndex = parent.ZIndex + 1, Active = false,
	})
end

-- Opt-in for bounded button/readout text. Repeated layouts reuse the same objects.
function Art.fitText(label, maximum, minimum, padding, wrapped)
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
		or node("UITextSizeConstraint", label, { Name = "TextBounds" })
	limit.MaxTextSize = maximum or 16
	limit.MinTextSize = math.min(minimum or 12, limit.MaxTextSize)
	label.TextScaled = true
	label.TextWrapped = wrapped == true
	label.TextTruncate = Enum.TextTruncate.None
	local inset = label:FindFirstChildOfClass("UIPadding") or node("UIPadding", label, { Name = "TextInset" })
	local gap = padding or 6
	inset.PaddingLeft, inset.PaddingRight = UDim.new(0, gap), UDim.new(0, gap)
	inset.PaddingTop, inset.PaddingBottom = UDim.new(0, 2), UDim.new(0, 2)
	return limit
end

-- Functional text keeps a real size and preferred-text support. Layout owns wrapping.
function Art.type(label, role, compact)
	local sizes = { Reward = 26, Heading = 20, Action = 16, Body = 14, Supporting = 12 }
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then constraint:Destroy() end
	local inset=label:FindFirstChildOfClass("UIPadding")
	if inset then inset.PaddingTop,inset.PaddingBottom=UDim.new(0,0),UDim.new(0,0) end
	label.TextScaled = false
	label.TextSize = if compact then (sizes[role] or 14) else (Art.Type[role] or 16)
	label.Font = if role == "Reward" or role == "Heading" or role == "Action" then Enum.Font.GothamBold else Enum.Font.Gotham
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
	return label
end

function Art.close(button)
	button.Name,button.Text="Close","×"
	button:SetAttribute("AccessibleLabel","Close")
	Art.type(button,"Heading",false)
	button.TextSize=26
	button.TextWrapped=false
	local inset=button:FindFirstChildOfClass("UIPadding")
	if inset then inset.PaddingLeft,inset.PaddingRight=UDim.new(0,0),UDim.new(0,0) end
	return button
end

function Art.textHeight(label,width,minimum)
	local inset=label:FindFirstChildOfClass("UIPadding")
	local horizontal=if inset then inset.PaddingLeft.Offset+inset.PaddingRight.Offset+(inset.PaddingLeft.Scale+inset.PaddingRight.Scale)*width else 0
	local measured=game:GetService("TextService"):GetTextSize(label.Text,label.TextSize,label.Font,Vector2.new(math.max(1,width-horizontal),10000))
	return math.max(minimum or 0,math.ceil(measured.Y)+4)
end
function Art.textWidth(label,content)
	return math.ceil(game:GetService("TextService"):GetTextSize(content or label.Text,label.TextSize,label.Font,Vector2.new(10000,10000)).X)+8
end
function Art.actionHeight(label,width)
	return math.max(44,Art.textHeight(label,width,0)+12)
end
-- One invalidation listener per component; hidden sheets reflow on open.
function Art.watchTextPreference(owner,visible,reflow)
	local queued,alive=false,true
	local connection=game:GetService("GuiService"):GetPropertyChangedSignal("PreferredTextSize"):Connect(function()
		owner:SetAttribute("TextPreferenceDirty",true)
		if queued or not visible() then return end
		queued=true
		task.defer(function()
			game:GetService("RunService").Heartbeat:Wait()
			queued=false
			if alive and owner.Parent and visible() then reflow();owner:SetAttribute("TextPreferenceDirty",false) end
		end)
	end)
	owner.Destroying:Connect(function()alive=false;connection:Disconnect()end)
	return connection
end

-- Common sheet chrome keeps actual value data separate from title/status copy.
-- Widgets/connections remain owned by their sheet; this only styles and places.
function Art.bareClose(button)
	Art.close(button)
	if button:GetAttribute("BareClose")then return button end
	button:SetAttribute("BareClose",true)
	local border=button:FindFirstChildOfClass("UIStroke")
	button.BackgroundTransparency=1
	local pressed=false
	local function paint()
		local focused=game:GetService("GuiService").SelectedObject==button
		button.BackgroundTransparency=if pressed then .80 elseif focused then .94 else 1
		if border then border.Color=Art.Focus;border.Transparency=if focused or pressed then .05 else 1 end
	end
	button.SelectionGained:Connect(paint);button.SelectionLost:Connect(function()pressed=false;paint()end)
	button.MouseButton1Down:Connect(function()pressed=true;paint()end)
	button.MouseButton1Up:Connect(function()pressed=false;paint()end)
	button.MouseLeave:Connect(function()pressed=false;paint()end)
	paint();return button
end
local function clearInset(label)
	local inset=label:FindFirstChildOfClass("UIPadding");if inset then inset:Destroy()end
end
function Art.sheetHeader(width,heading,wallet,amount,glyph,close,options)
	options=options or {};local pad=options.pad or 10;local top=options.top or 0
	Art.type(heading,if options.status then "Body"else "Heading",true)
	Art.type(amount,"Body",true);clearInset(heading);clearInset(amount)
	amount.Text=tostring(options.amount or 0);amount.TextWrapped=false;amount.TextXAlignment=Enum.TextXAlignment.Left
	amount:SetAttribute("AccessibleLabel",amount.Text.." nectar")
	wallet.BackgroundTransparency=1
	local amountW=Art.textWidth(amount)+2;local glyphW,gap=18,4
	local walletW=glyphW+gap+amountW
	local closeX=width-pad-44
	local minimumLeft=pad+walletW+6
	local right=closeX-6
	local secondary=options.secondary;local secondaryW,secondaryH=0,44
	if secondary then Art.type(secondary,"Action",true);secondaryW=math.max(44,Art.textWidth(secondary)+12);secondaryH=Art.actionHeight(secondary,secondaryW)end
	local full,short=options.title or "",options.shortTitle or options.title or ""
	local function intrinsic(content)return Art.textWidth(heading,content)end
	local secondaryHeader=secondary and secondaryH<=44 and right-minimumLeft-secondaryW-8>=intrinsic(short)
	if secondaryHeader then right-=secondaryW+8 end
	local available=math.max(1,right-minimumLeft)
	heading.Text=if intrinsic(full)<=available then full else short
	heading:SetAttribute("AccessibleLabel",options.accessibleTitle or full)
	heading.TextWrapped=intrinsic(heading.Text)>available
	heading.TextXAlignment=Enum.TextXAlignment.Center
	local titleW=math.min(available,intrinsic(heading.Text))
	local titleH=Art.textHeight(heading,titleW,0)
	local rowH=math.max(44,titleH,Art.textHeight(amount,amountW,0))
	local titleX=math.clamp((width-titleW)/2,minimumLeft,math.max(minimumLeft,right-titleW))
	heading.Position,heading.Size=UDim2.fromOffset(titleX,top+(rowH-titleH)/2),UDim2.fromOffset(titleW,titleH)
	wallet.Position,wallet.Size=UDim2.fromOffset(pad,top),UDim2.fromOffset(walletW,rowH)
	glyph.Position,glyph.Size=UDim2.fromOffset(0,(rowH-20)/2),UDim2.fromOffset(glyphW,20);glyph.Visible=true
	amount.Position,amount.Size=UDim2.fromOffset(glyphW+gap,0),UDim2.fromOffset(amountW,rowH);amount.Visible=true
	close.Position,close.Size=UDim2.fromOffset(closeX,top+(rowH-44)/2),UDim2.fromOffset(44,44)
	if secondaryHeader then secondary.Position,secondary.Size=UDim2.fromOffset(closeX-8-secondaryW,top+(rowH-44)/2),UDim2.fromOffset(secondaryW,44)end
	return{height=top+rowH,rowHeight=rowH,secondaryHeader=secondaryHeader==true,secondaryWidth=secondaryW,secondaryHeight=secondaryH,walletWidth=walletW,titleFull=full}
end
function Art.dockTransparency(preference)return .18*math.clamp(preference,0,1)end
function Art.dockCircle(button,kind)
	button.Text=if kind=="menu"then "Menu"else "Open deck";button.TextTransparency=1;button.BackgroundColor3=Art.Surface;Art.corner(button,24)
	button:SetAttribute("AccessibleLabel",if kind=="menu"then "Menu"else "Deck")
	local glyph=Art.frame(button,"DockGlyph",Art.Silver,UDim2.new(.5,-12,.5,-12),UDim2.fromOffset(24,24),button.ZIndex+1);glyph.BackgroundTransparency=1
	if kind=="menu"then
		for index=0,2 do local bar=Art.frame(glyph,"Bar",Art.Silver,UDim2.fromOffset(2,4+index*7),UDim2.fromOffset(20,2),glyph.ZIndex);Art.corner(bar,1)end
	else
		local deck=Art.frame(glyph,"Handheld",Art.Silver,UDim2.fromOffset(0,4),UDim2.fromOffset(24,16),glyph.ZIndex);deck.BackgroundTransparency=1;Art.corner(deck,4);Art.stroke(deck,Art.Silver,0,1)
		local screen=Art.frame(deck,"Screen",Art.LCD,UDim2.fromOffset(8,3),UDim2.fromOffset(8,10),deck.ZIndex);Art.corner(screen,1)
		Art.frame(deck,"Rocker",Art.Silver,UDim2.fromOffset(3,7),UDim2.fromOffset(3,3),deck.ZIndex)
		Art.corner(Art.frame(deck,"A",Art.Silver,UDim2.fromOffset(19,7),UDim2.fromOffset(3,3),deck.ZIndex),2)
	end
	return button
end

function Art.leaf(parent, name, position, size, tint, rotation, z)
	local leaf = Art.frame(parent, name, tint, position, size, z)
	Art.corner(leaf, 1000)
	leaf.Rotation = rotation or 0
	local vein = Art.frame(leaf, "Vein", Art.Ink, UDim2.new(0.5, -1, 0.18, 0), UDim2.new(0, 2, 0.64, 0))
	vein.BackgroundTransparency = 0.8
	Art.corner(vein, 1)
	return leaf
end

local backdropMotion=setmetatable({},{__mode="k"})
Art.BackdropPeriod=12
function Art.backdrop(parent)
	parent.BackgroundColor3 = Art.Backdrop
	parent.ClipsDescendants = true
	Art.shade(parent, 1, 0.76)
	if parent:FindFirstChild("CanopyArt") then return end
	local art = Art.frame(parent, "CanopyArt", Art.Backdrop, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	art.BackgroundTransparency = 1
	local motion={entries={},resting=true,elapsed=0};backdropMotion[parent]=motion
	parent.Destroying:Connect(function()backdropMotion[parent]=nil end)
	-- Broad silhouettes read as an outdoor setting, even around a small phone deck.
	for index, data in ipairs({
		{ -0.18, -0.38, 0.65, 0.78, Art.Canopy },
		{ 0.66, -0.30, 0.54, 0.72, Art.Canopy },
		{ -0.18, 0.67, 0.67, 0.70, Art.Field },
		{ 0.45, 0.78, 0.77, 0.52, Art.Field },
	}) do
		local shape = Art.frame(art, "Canopy" .. index, data[5], UDim2.fromScale(data[1], data[2]),
			UDim2.fromScale(data[3], data[4]))
		local corner = Art.corner(shape, 1)
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	for index, data in ipairs({ {0.04, 0.38, -28}, {0.93, 0.53, 32}, {0.10, 0.85, 38}, {0.87, 0.08, -35} }) do
		local leaf = Art.leaf(art, "Leaf" .. index, UDim2.fromScale(data[1], data[2]),
			UDim2.fromOffset(18, 36), Art.Line, data[3])
		leaf.BackgroundTransparency = 0.5
		table.insert(motion.entries,{node=leaf,position=leaf.Position,rotation=leaf.Rotation,phase=index*math.pi/2,x=3,y=4})
	end
	for index, data in ipairs({{0.03, 0.18}, {0.19, 0.92}, {0.95, 0.83}, {0.78, 0.06}}) do
		local seed = Art.frame(art, "Seed" .. index, Art.Leaf, UDim2.fromScale(data[1], data[2]), UDim2.fromOffset(4, 4))
		Art.corner(seed, 2)
		seed.BackgroundTransparency = 0.35
		table.insert(motion.entries,{node=seed,position=seed.Position,rotation=seed.Rotation,phase=index*math.pi/2+.4,x=4,y=3})
	end
end

-- The existing board render clock calls this once. No new connection, GUI walk,
-- tween, or allocation runs per frame; hidden/reduced presentation rests at base.
function Art.updateBackdrop(parent,now,visible,reduced)
	local motion=backdropMotion[parent]
	if not motion then return end
	if not visible or reduced then
		if not motion.resting then
			for _,entry in ipairs(motion.entries)do entry.node.Position=entry.position;entry.node.Rotation=entry.rotation end
			motion.resting=true
		end
		motion.lastTime=nil
		return
	end
	motion.elapsed=(motion.elapsed+(if motion.lastTime then math.max(0,now-motion.lastTime)else 0))%Art.BackdropPeriod
	motion.lastTime=now;motion.resting=false
	local phase=motion.elapsed/Art.BackdropPeriod*math.pi*2
	for _,entry in ipairs(motion.entries)do
		entry.node.Position=entry.position+UDim2.fromOffset(math.sin(phase+entry.phase)*entry.x,math.sin(phase*2+entry.phase)*entry.y)
		entry.node.Rotation=entry.rotation+math.sin(phase+entry.phase)*2
	end
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
	Art.shade(parent, 1, 0.91)
	Art.stroke(parent, Art.Line, 0.28, 2)
	local highlight = Art.frame(parent, "MoldHighlight", Art.Silver, UDim2.fromOffset(radius + 4, 3),
		UDim2.new(1, -(radius + 4) * 2, 0, 1))
	highlight.BackgroundTransparency = 0.77
	local mark = Art.frame(parent, "Accent", accent or Art.Leaf, UDim2.new(0.5, -13, 1, -5), UDim2.fromOffset(26, 2))
	Art.corner(mark, 1)
end

function Art.button(button, radius)
	button.AutoButtonColor = false
	Art.corner(button, radius)
	local border = Art.stroke(button, Art.Line, 0.22)
	button.MouseButton1Down:Connect(function()
		if button.Interactable then
			border.Color = Art.Focus
		end
	end)
	local function restore()
		border.Color = if button == game:GetService("GuiService").SelectedObject
			then Art.Focus else Art.Line
	end
	button.MouseButton1Up:Connect(restore)
	button.MouseLeave:Connect(restore)
	button.SelectionGained:Connect(function() border.Color = Art.Focus end)
	button.SelectionLost:Connect(function() border.Color = Art.Line end)
	return border
end

function Art.deck(backdrop, shell, bezel)
	Art.backdrop(backdrop)
	Art.shade(shell, 1, 0.88)
	Art.shade(bezel, 1, 0.9)
	local seam = Art.frame(shell, "MoldSeam", Art.Ink, UDim2.fromOffset(5, 5), UDim2.new(1, -10, 1, -10))
	seam.BackgroundTransparency = 1
	local seamCurve = Art.corner(seam, 13)
	local shellCurve = shell:FindFirstChildOfClass("UICorner")
	if shellCurve then
		local function followCurve()
			seamCurve.CornerRadius = UDim.new(0, math.max(1, shellCurve.CornerRadius.Offset - 5))
		end
		followCurve()
		shellCurve:GetPropertyChangedSignal("CornerRadius"):Connect(followCurve)
	end
	Art.stroke(seam, Art.Ink, 0.58)
	for _, side in ipairs({ 0, 1 }) do
		local screw = Art.frame(shell, "Screw", Art.Ink,
			UDim2.new(side, if side == 0 then 15 else -23, 1, -22), UDim2.fromOffset(8, 8))
		Art.corner(screw, 4)
		Art.stroke(screw, Art.Line)
		Art.frame(screw, "Slot", Art.Line, UDim2.fromOffset(2, 3), UDim2.fromOffset(4, 1)).Rotation = -28
	end
	Art.leaf(shell, "SproutLeaf", UDim2.fromOffset(16, 10), UDim2.fromOffset(7, 12), Art.Leaf, -35, shell.ZIndex + 1)
	Art.insignia(shell, 2, UDim2.fromOffset(28, 7), Art.Ink, shell.ZIndex + 1)
	local glint = Art.frame(bezel, "LensGlint", Art.Silver,
		UDim2.new(0, 14, 0, 2), UDim2.new(1, -28, 0, 1))
	glint.BackgroundTransparency = 0.65
end

function Art.tintBackdrop(parent,theme)
	parent.BackgroundColor3=theme.backdrop or Art.Backdrop
	local art=parent:FindFirstChild("CanopyArt")
	if not art then return end
	for _,node in ipairs(art:GetChildren())do
		if node:IsA("Frame")then
			if node.Name:find("Canopy")then node.BackgroundColor3=theme.band or Art.Canopy
			else node.BackgroundColor3=theme.trim or Art.Leaf end
		end
	end
end
return Art
