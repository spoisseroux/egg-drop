-- "Get Stars" sheet: game passes and Robux Stars packs.
-- Presentation only. The server owns prompts, eligibility, the paid-random-items
-- gate and every grant; this view draws the latest StoreState snapshot, asks the
-- server to prompt, and words StoreResult for the player. It opens as a child
-- page of the egg shop, so the egg shop stays the single presentation owner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Art = require(script.Parent.DeckArt)
local EggArt = require(script.Parent.EggArt)
local Stars = require(script.Parent.StarText)
local Catalog = require(ReplicatedStorage.Shared.StoreCatalog)

local View = {}
View.__index = View

View.Idle = "Roblox asks you to confirm before you buy anything."
View.Opening = "Opening the Roblox purchase window…"
View.BestTag = "Most Stars per Robux"
View.Rejected = table.freeze({
	NotConfigured = "Coming soon! This isn't in the shop yet.",
	Owned = "You already own this one.",
	Restricted = "Stars packs aren't available for your account.",
	AlreadyClaimed = "You already claimed your Starter pack.",
	Loading = "The shop is still loading. Try again in a moment.",
	Throttled = "One moment, then try again.",
	Unknown = "That isn't available right now. Nothing was bought.",
	Unavailable = "That isn't available right now. Nothing was bought.",
})

View.Badges = table.freeze({
	doubleStars = tostring(Catalog.DoubleStarsMultiplier) .. "×",
	supporter = "+" .. tostring(Catalog.SupporterRoundBonus),
})

function View.price(robux)
	return "R$ " .. tostring(robux)
end

-- Before the first snapshot: list the passes from the shared catalog as loading
-- and keep packs hidden, matching the server's fail-closed policy gate.
local function fallbackState()
	local passes = {}
	for _, pass in ipairs(Catalog.Passes) do
		table.insert(passes, { key = pass.key, name = pass.name, blurb = pass.blurb, price = pass.price,
			owned = false, available = false })
	end
	return { passes = passes, products = {}, packsAllowed = false, ready = false }
end

local function tile(parent, name, z)
	local node = Instance.new("TextButton")
	node.Name, node.Text, node.BorderSizePixel, node.ZIndex = name, "", 0, z
	node.BackgroundColor3, node.TextColor3, node.Font, node.TextSize = Art.Raised, Art.Silver, Art.Font.Action, 14
	node.Parent = parent
	Art.bind(node, { BackgroundColor3 = "raised" })
	Art.button(node, 10)
	return node
end

-- style: "buy" (filled, ink lettering), "owned" (outlined word), "quiet" (recessed).
local function pill(parent, content, style, compact)
	local frame = Art.frame(parent, "Price", if style == "buy" then "accent" else "inset",
		UDim2.fromOffset(0, 0), UDim2.fromOffset(72, 32), parent.ZIndex + 1)
	Art.corner(frame, 8)
	frame:SetAttribute("PillStyle", style)
	if style == "owned" then Art.stroke(frame, "accent", 0.1, 2) end
	local label = Art.text(frame, "Label", content, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1),
		if style == "buy" then "ink" elseif style == "owned" then "text" else "muted", 16)
	Art.type(label, "Action", compact)
	label.TextWrapped = false
	local width = math.max(72, Art.textWidth(label) + 16)
	local height = math.max(if compact then 30 else 34, Art.textHeight(label, width, 0) + 6)
	frame.Size = UDim2.fromOffset(width, height)
	return frame, width, height
end

function View.new(parent, options)
	options = options or {}
	local z = options.z or 70
	local shade = Art.frame(parent, "StoreView", "ink", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), z)
	shade.BackgroundTransparency, shade.Active, shade.Visible = 1, true, false
	local card = Art.frame(shade, "Card", "panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(560, 420), z + 1)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	Art.panel(card, 16, "accent")
	local heading = Art.text(card, "Heading", "Get Stars", UDim2.fromOffset(12, 6), UDim2.fromOffset(200, 24), "text", 20)
	heading.ZIndex = z + 3
	local wallet = Art.frame(card, "Wallet", Art.Canopy, UDim2.fromOffset(12, 4), UDim2.fromOffset(120, 29), z + 2)
	local drop = EggArt.nectar(wallet, UDim2.fromOffset(3, 5), UDim2.fromOffset(19, 20), z + 3)
	local amount = Art.text(wallet, "Stars", "0", UDim2.fromOffset(24, 0), UDim2.fromOffset(60, 24), "reward", 16)
	amount.ZIndex = z + 4
	local body = Instance.new("ScrollingFrame")
	body.Name, body.BackgroundTransparency, body.BorderSizePixel, body.ZIndex = "Body", 1, 0, z + 2
	body.ClipsDescendants, body.ScrollBarThickness = true, 4
	body.ScrollingDirection, body.ElasticBehavior = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.Never
	body.Selectable = false
	body.Parent = card
	Art.bind(body, { ScrollBarImageColor3 = "accent" })
	local close = Instance.new("TextButton")
	close.Name, close.BorderSizePixel, close.ZIndex, close.Size = "Close", 0, z + 6, UDim2.fromOffset(44, 44)
	close.BackgroundColor3, close.TextColor3 = Art.Raised, Art.Silver
	close.Parent = card
	Art.bind(close, { BackgroundColor3 = "raised", TextColor3 = "text" })
	Art.button(close, 10)
	Art.bareClose(close)
	local status = Art.text(card, "Status", View.Idle, UDim2.fromOffset(12, 0), UDim2.fromOffset(200, 20), "muted", 14)
	status.ZIndex = z + 3
	local self = setmetatable({
		shade = shade, card = card, heading = heading, wallet = wallet, walletDrop = drop, amount = amount,
		body = body, closeButton = close, status = status,
		reduceEffects = options.reduceEffects or function() return false end,
		request = options.request or function() end,
		state = fallbackState(), balance = 0, message = View.Idle, messageKind = "info",
		promptToken = 0, cooling = false, offers = {},
	}, View)
	close.Activated:Connect(function() self:close("close") end)
	Art.watchTextPreference(shade, function() return shade.Visible end, function() self:layout() end)
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if shade.Visible then self:layout() end
	end)
	local selection = GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		local node = GuiService.SelectedObject
		if shade.Visible and node and node:IsDescendantOf(body) then self:ensureVisible(node) end
	end)
	shade.Destroying:Connect(function()
		self.destroyed = true
		selection:Disconnect()
	end)
	return self
end

function View:isOpen()
	return self.shade.Visible
end

function View:ownsInput()
	if not self.shade.Visible or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return false end
	local ancestor = self.shade
	while ancestor do
		if ancestor:IsA("GuiObject") and (not ancestor.Visible or not ancestor.Interactable)
			or ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
		ancestor = ancestor.Parent
	end
	return self.shade.Parent ~= nil
end

function View:bumpControllerEpoch()
	self.shade:SetAttribute("ControllerEpoch", (self.shade:GetAttribute("ControllerEpoch") or 0) + 1)
end

function View:focusTarget()
	for _, offer in ipairs(self.offers) do
		if offer.button.Parent and offer.button.Interactable and offer.button.Selectable then return offer.button end
	end
	return self.closeButton
end

function View:getControllerFocus()
	if not self.shade.Visible then return nil end
	return { root = self.shade, epoch = self.shade:GetAttribute("ControllerEpoch") or 0,
		target = function() return self:focusTarget() end, fallback = self.closeButton,
		ensure = function(node) self:ensureVisible(node) end }
end

function View:ensureVisible(node)
	local body = self.body
	if not node or not node:IsDescendantOf(body) then return end
	local window = body.AbsoluteSize.Y
	local top = node.AbsolutePosition.Y - body.AbsolutePosition.Y + body.CanvasPosition.Y
	local height = node.AbsoluteSize.Y
	local current = body.CanvasPosition.Y
	local wanted = if height > window or top < current then math.max(0, top - 4)
		elseif top + height > current + window then top + height + 4 - window else current
	body.CanvasPosition = Vector2.new(0, math.clamp(wanted, 0, math.max(0, body.CanvasSize.Y.Offset - window)))
end

function View:setMessage(text, kind)
	self.message, self.messageKind = text or View.Idle, kind or "info"
	if self.shade.Visible then self:layout() end
end

function View:setBalance(balance)
	balance = tonumber(balance)
	if not balance or balance == self.balance then return end
	self.balance = balance
	if self.shade.Visible then self:layout() end
end

function View:setState(snapshot)
	if type(snapshot) ~= "table" or type(snapshot.passes) ~= "table" or type(snapshot.products) ~= "table" then return false end
	self.state = snapshot
	if self.shade.Visible then self:layout() end
	return true
end

function View:pulseWallet()
	if self.reduceEffects() or not self.shade.Visible then return end
	local scale = self.walletDrop:FindFirstChild("GrantPulse") or Instance.new("UIScale")
	scale.Name, scale.Scale, scale.Parent = "GrantPulse", 1.35, self.walletDrop
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- StoreResult from the server. Works while closed too: the next open starts
-- from the idle line, and the wallet follows the authoritative snapshot.
function View:handleResult(result)
	if type(result) ~= "table" then return end
	self.promptToken += 1
	self.cooling = false
	if result.kind == "product" then
		local stars = tonumber(result.stars) or 0
		if tonumber(result.balance) then self.balance = tonumber(result.balance) end
		self:setMessage(string.format("+%s added. You have %s.", Stars.amount(stars), Stars.amount(self.balance)), "reward")
		self:pulseWallet()
	elseif result.kind == "pass" then
		local name
		for _, pass in ipairs(self.state.passes) do
			if pass.key == result.key then
				name = pass.name
				pass.owned = true
			end
		end
		self:setMessage((name or "Your pass") .. " is yours. Thank you!", "reward")
	elseif result.kind == "rejected" then
		self:setMessage(View.Rejected[result.reason] or View.Rejected.Unavailable, "notice")
	end
end

function View:prompt(key)
	if not self:ownsInput() or self.cooling then return false end
	-- The server throttles prompts to one a second; a short quiet window keeps a
	-- double tap from turning into a "try again" message.
	self.cooling = true
	self.promptToken += 1
	local token = self.promptToken
	self:setMessage(View.Opening, "info")
	if self.onAccepted then self.onAccepted("confirm") end
	self.request("prompt", key)
	task.delay(1.2, function()
		if self.promptToken == token then self.cooling = false end
	end)
	return true
end

function View:open(balance)
	if tonumber(balance) then self.balance = tonumber(balance) end
	self:bumpControllerEpoch()
	if not self.shade.Visible then
		self.previousSelection = GuiService.SelectedObject
		self.body.CanvasPosition = Vector2.zero
		self.message, self.messageKind, self.cooling = View.Idle, "info", false
	end
	self.shade.Visible = true
	self:layout()
	self.request("open")
	if self.onOpened then self.onOpened() end
	if self:ownsInput() and string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then
		GuiService.SelectedObject = self:focusTarget()
	end
end

function View:close(reason)
	if not self.shade.Visible then return end
	self:bumpControllerEpoch()
	self.promptToken += 1
	self.cooling = false
	self.shade.Visible = false
	if (reason == nil or reason == "close" or reason == "back") and self.onAccepted then self.onAccepted("back") end
	local restore = GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)
	if self.onClosed then self.onClosed(reason or "close") end
	if restore then
		local previous = self.previousSelection
		GuiService.SelectedObject = if previous and previous.Parent then previous else nil
	end
end

-- The pack that really gives the most Stars for each Robux among what this
-- player can still buy. Computed from the snapshot so the tag is never a guess.
function View:bestValueKey(products)
	local bestKey, bestRatio, count = nil, 0, 0
	for _, product in ipairs(products) do
		if not product.claimed and (tonumber(product.price) or 0) > 0 then
			count += 1
			local ratio = (tonumber(product.stars) or 0) / product.price
			if ratio > bestRatio then bestKey, bestRatio = product.key, ratio end
		end
	end
	return if count >= 2 then bestKey else nil
end

function View:renderBody(plannedWidth, compact, short)
	local body = self.body
	local previous = GuiService.SelectedObject
	local focusName = previous and previous:IsDescendantOf(body) and previous.Name or nil
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(self.offers)
	local rect = Art.scrollContentRect(body, plannedWidth)
	local x, w = rect.x, rect.width
	local column = Art.frame(body, "Column", "ink", UDim2.fromOffset(0, 0), UDim2.fromOffset(plannedWidth, 1), body.ZIndex)
	column.BackgroundTransparency = 1
	local state = self.state
	local pad = if compact then 8 else 10
	local y = 4

	local function line(parent, name, content, role, color, lx, ly, lw, align)
		local node = Art.text(parent, name, content, UDim2.fromOffset(lx, ly), UDim2.fromOffset(lw, 20), color or "text", 16)
		Art.type(node, role, compact)
		node.TextXAlignment = align or Enum.TextXAlignment.Left
		local h = Art.textHeight(node, lw, 0)
		node.Size = UDim2.fromOffset(lw, h)
		return node, h
	end
	local function copy(name, content, role, color)
		local _, h = line(column, name, content, role, color, x, y, w)
		y += h + (if role == "Action" then 6 else 8)
	end
	local function register(button, key, enabled)
		button.Interactable, button.Selectable = enabled, enabled
		button:SetAttribute("OfferKey", key)
		Art.control(button, false, enabled)
		table.insert(self.offers, { key = key, button = button })
		if enabled then button.Activated:Connect(function() self:prompt(key) end) end
	end

	-- One full-width offer: words on the left, price on the right (below when narrow).
	local function offerRow(name, spec)
		local button = tile(column, name, body.ZIndex + 1)
		local price, pw, ph = pill(button, spec.pill, spec.style, compact)
		local hasArt = spec.star or spec.badge ~= nil
		local art = if hasArt then (if compact then 30 else 40) else 0
		local artGap = if hasArt then 8 else 0
		local side = w >= 360
		local textX = pad + art + artGap
		local textW = math.max(1, w - textX - pad - (if side then pw + 10 else 0))
		local info = Art.frame(button, "Info", "ink", UDim2.fromOffset(textX, pad), UDim2.fromOffset(textW, 1), button.ZIndex)
		info.BackgroundTransparency = 1
		local ty = 0
		local _, titleH = line(info, "Title", spec.title, "Action", "text", 0, ty, textW)
		ty += titleH
		if spec.detail then
			local _, detailH = line(info, "Detail", spec.detail, "Supporting", "muted", 0, ty + 2, textW)
			ty += detailH + 2
		end
		for index, note in ipairs(spec.notes) do
			local _, noteH = line(info, "Note" .. index, note.text, "Supporting", note.color, 0, ty + 2, textW)
			ty += noteH + 2
		end
		info.Size = UDim2.fromOffset(textW, ty)
		local h
		if side then
			h = math.max(44, ty + pad * 2, ph + pad * 2)
			info.Position = UDim2.fromOffset(textX, math.floor((h - ty) / 2))
			price.Position = UDim2.fromOffset(w - pad - pw, math.floor((h - ph) / 2))
		else
			h = math.max(art, ty) + pad * 2 + 8 + ph
			price.Position, price.Size = UDim2.fromOffset(pad, h - pad - ph), UDim2.fromOffset(w - pad * 2, ph)
		end
		if hasArt then
			local blockH = if side then h else math.max(art, ty) + pad * 2
			local well = Art.frame(button, if spec.star then "StarWell" else "BoostWell", "inset",
				UDim2.fromOffset(pad, math.floor((blockH - art) / 2)), UDim2.fromOffset(art, art), button.ZIndex + 1)
			Art.corner(well, 10)
			if spec.star then
				Art.stroke(well, "reward", 0.15, 2)
				EggArt.nectar(well, UDim2.fromOffset(4, 4), UDim2.fromOffset(art - 8, art - 8), button.ZIndex + 2)
			else
				-- Decorative emblem; the row's own words carry the meaning.
				local emblem = Art.text(well, "Emblem", spec.badge, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), "reward", 18, Art.Font.Heading)
				Art.fitText(emblem, if compact then 16 else 20, 10, 2, false)
			end
		end
		button.Position, button.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
		register(button, spec.key, spec.enabled)
		y += h + 8
		return button
	end

	-- A short phone leads with a whole offer; the framing copy closes the list instead.
	local function framing()
		copy("Intro", "Stars hatch eggs. You always earn them free by playing rounds and quests.", "Supporting", "muted")
		if short then copy("IdleNote", View.Idle, "Supporting", "muted") end
	end
	if not short then framing() end

	copy("BoostsHeading", "Boosts", "Action")
	for _, pass in ipairs(state.passes) do
		local notes, style, enabled = {}, "buy", false
		local label = View.price(pass.price)
		if pass.owned then
			label, style = "Owned", "owned"
		elseif not state.ready then
			style = "quiet"
			table.insert(notes, { text = "Loading…", color = "muted" })
		elseif not pass.available then
			style = "quiet"
			table.insert(notes, { text = "Coming soon", color = "muted" })
		else
			enabled = true
		end
		local row = offerRow("Pass_" .. pass.key, { key = pass.key, title = pass.name, detail = pass.blurb, badge = View.Badges[pass.key] or "★",
			notes = notes, pill = label, style = style, enabled = enabled })
		row:SetAttribute("Owned", pass.owned == true)
	end

	-- Paid-random-items rule: with packs disallowed, no Stars product is drawn at all.
	local products = if state.packsAllowed == true then state.products else {}
	column:SetAttribute("PacksShown", #products > 0)
	if not state.ready then
		copy("PacksLoading", "Checking what else is available…", "Supporting", "muted")
	elseif #products > 0 then
		local best = self:bestValueKey(products)
		local function productNotes(product)
			local notes = {}
			if best == product.key then table.insert(notes, { text = View.BestTag, color = "reward" }) end
			if not product.available and not product.claimed then table.insert(notes, { text = "Coming soon", color = "muted" }) end
			return notes
		end
		y += 4
		copy("PacksHeading", "Stars packs", "Action")
		local grid, claimedOnce = {}, {}
		for _, product in ipairs(products) do
			if product.once and product.claimed then
				table.insert(claimedOnce, product)
			elseif product.once then
				-- The one-time starter leads the section until it is claimed.
				local row = offerRow("Product_" .. product.key, { key = product.key, star = true,
					title = product.name .. " · " .. Stars.amount(product.stars),
					detail = product.blurb or "One per player.", notes = productNotes(product),
					pill = View.price(product.price), style = if product.available then "buy" else "quiet",
					enabled = product.available == true })
				row:SetAttribute("Featured", true)
			else
				table.insert(grid, product)
			end
		end
		if #grid > 0 then
			-- Measure the unbreakable words and the price before choosing columns.
			local probe = Art.text(column, "Measure", "", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), "text", 16)
			probe.Visible = false
			local minimum = 72
			for _, product in ipairs(grid) do
				Art.type(probe, "Supporting", compact)
				for word in tostring(product.name):gmatch("%S+") do
					probe.Text = word
					minimum = math.max(minimum, Art.textWidth(probe))
				end
				Art.type(probe, "Action", compact)
				probe.Text = Stars.amount(product.stars)
				minimum = math.max(minimum, Art.textWidth(probe))
				probe.Text = View.price(product.price)
				minimum = math.max(minimum, Art.textWidth(probe) + 16)
			end
			probe:Destroy()
			local columns = math.clamp(math.floor((w + 8) / (minimum + pad * 2 + 8)), 1, #grid)
			if columns == 3 and #grid == 4 then columns = 2 end
			column:SetAttribute("PackColumns", columns)
			-- Bigger packs draw a slightly bigger star inside one shared well height.
			local glyph = if compact then 26 else 44
			local smallest = if compact then 18 else 28
			local built, rowHeights = {}, {}
			for index, product in ipairs(grid) do
				local _, cw = Art.gridCell(w, (index - 1) % columns, columns, 8)
				local inner = cw - pad * 2
				local button = tile(column, "Product_" .. product.key, body.ZIndex + 1)
				local info = Art.frame(button, "Info", "ink", UDim2.fromOffset(pad, pad), UDim2.fromOffset(inner, 1), button.ZIndex)
				info.BackgroundTransparency = 1
				local star = math.floor(smallest + (glyph - smallest) * (if #grid > 1 then (index - 1) / (#grid - 1) else 1))
				EggArt.nectar(info, UDim2.fromOffset(math.floor((inner - star) / 2), math.floor((glyph - star) / 2)), UDim2.fromOffset(star, star), button.ZIndex + 1)
				local ty = glyph + 2
				local center = Enum.TextXAlignment.Center
				local _, amountH = line(info, "Amount", Stars.amount(product.stars), "Action", "reward", 0, ty, inner, center)
				ty += amountH
				local _, nameH = line(info, "Title", product.name, "Supporting", "muted", 0, ty, inner, center)
				ty += nameH
				for noteIndex, note in ipairs(productNotes(product)) do
					local _, noteH = line(info, "Note" .. noteIndex, note.text, "Supporting", note.color, 0, ty + 2, inner, center)
					ty += noteH + 2
				end
				info.Size = UDim2.fromOffset(inner, ty)
				local price, _, ph = pill(button, View.price(product.price), if product.available then "buy" else "quiet", compact)
				price.Size = UDim2.fromOffset(inner, ph)
				local needed = pad + ty + 6 + ph + pad
				local group = math.floor((index - 1) / columns) + 1
				rowHeights[group] = math.max(rowHeights[group] or 44, needed)
				built[index] = { button = button, info = info, price = price, textH = ty, priceH = ph, product = product }
			end
			for index, entry in ipairs(built) do
				local group = math.floor((index - 1) / columns) + 1
				local gx, cw = Art.gridCell(w, (index - 1) % columns, columns, 8)
				local gy = y
				for n = 1, group - 1 do gy += rowHeights[n] + 8 end
				local h = rowHeights[group]
				entry.button.Position, entry.button.Size = UDim2.fromOffset(x + gx, gy), UDim2.fromOffset(cw, h)
				-- Words stay top-aligned so stars and amounts line up across a row.
				entry.price.Position = UDim2.fromOffset(pad, h - pad - entry.priceH)
				register(entry.button, entry.product.key, entry.product.available == true)
			end
			for _, h in ipairs(rowHeights) do y += h + 8 end
		end
		for _, product in ipairs(claimedOnce) do
			local row = offerRow("Product_" .. product.key, { key = product.key, title = product.name,
				detail = "One per player. You already have yours.", notes = {}, pill = "Claimed", style = "quiet", enabled = false })
			row:SetAttribute("Claimed", true)
		end
	end

	if short then framing() end
	y = math.max(1, y - 4)
	column.Size = UDim2.fromOffset(plannedWidth, y)
	if focusName then
		local target = column:FindFirstChild(focusName)
		if not (target and target.Interactable and target.Selectable) then target = self.closeButton end
		if self:ownsInput() then GuiService.SelectedObject = target end
	end
	return y
end

function View:layout()
	if self.destroyed then return end
	if self.layingOut then
		self.layoutDirty = true
		return
	end
	self.layingOut = true
	repeat
		self.layoutDirty = false
		local size = self.shade.AbsoluteSize
		local width = math.max(1, math.min(640, size.X - 16))
		local maxHeight = math.max(1, math.min(720, size.Y - 16))
		local short = size.Y < 280
		local compact = short or width < 400
		self.compact = compact
		self.card.Size = UDim2.fromOffset(width, self.card.Size.Y.Offset)
		local plan = Art.sheetHeader(width, self.heading, self.wallet, self.amount, self.walletDrop, self.closeButton,
			{ pad = 12, top = 0, amount = self.balance, title = "Get Stars", shortTitle = "Stars", accessibleTitle = "Get Stars" })
		local status = self.status
		status.Text = self.message
		-- A grant or a refusal is the news; the idle reassurance stays quiet.
		Art.type(status, if self.messageKind == "info" then "Supporting" else "Body", compact)
		Art.bind(status, { TextColor3 = if self.messageKind == "reward" then "reward" elseif self.messageKind == "notice" then "text" else "muted" })
		status:SetAttribute("MessageKind", self.messageKind)
		-- Short phones keep the idle reassurance in the scroll; results are always pinned.
		local pinned = not short or self.message ~= View.Idle
		status.Visible = pinned
		local statusH = if pinned then Art.textHeight(status, width - 24, 0) else 0
		local edge = if short then 4 else 10
		local top = plan.height + (if short then 0 else 4)
		local canvas = self.body.CanvasPosition
		local contentH = self:renderBody(width - 24, compact, short)
		local statusGap = if pinned then 6 else 0
		local room = math.max(1, maxHeight - top - statusGap - statusH - edge)
		local bodyH = math.min(contentH, room)
		local height = top + bodyH + statusGap + statusH + edge
		self.card.Size = UDim2.fromOffset(width, height)
		self.body.Position, self.body.Size = UDim2.fromOffset(12, top), UDim2.fromOffset(width - 24, bodyH)
		self.body.CanvasSize = UDim2.fromOffset(0, contentH)
		self.body.ScrollingEnabled = contentH > bodyH
		self.body.CanvasPosition = Vector2.new(0, math.clamp(canvas.Y, 0, math.max(0, contentH - bodyH)))
		status.Position, status.Size = UDim2.fromOffset(12, top + bodyH + statusGap), UDim2.fromOffset(width - 24, math.max(1, statusH))
	until not self.layoutDirty or self.destroyed
	self.layingOut = false
end

return View
