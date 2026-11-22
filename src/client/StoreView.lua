-- "Get Stars": game passes and Robux Stars packs, in the Toy Shell look (Spencer
-- 2026-11-21, "It doesn't match the other UI at all??"; Fable's brief and mocks in
-- artifacts/stars-store-2026-11-21/, plan STORE-RESTYLE-PLAN-2026-11-21.md).
--
-- The Hatch eggs screen with offers where the eggs were: a list of cream tiles on the
-- left (icon, name, one line, price or OWNED), one tray on the right (the selected
-- offer's icon on the stage, what you get, one green Buy key), the shared header
-- (Get Stars, the wallet, back). Pick, read, Buy.
--
-- Presentation only. The server owns prompts, eligibility, the paid-random-items gate
-- and every grant; this view draws the latest StoreState snapshot, asks the server to
-- prompt, and words StoreResult for the player. It opens as a child page of Hatch eggs
-- (EggHatchView.attachStore): Hatch eggs hides its own panel and keeps its dim, so the
-- egg shop stays the single presentation, Back and controller-focus owner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Kit = require(script.Parent.DeckKit)
local Stars = require(script.Parent.StarText)
local Catalog = require(ReplicatedStorage.Shared.StoreCatalog)
local UICopy = require(ReplicatedStorage.Shared.UICopy)

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

-- The drawn badge an offer shows until its icon image has loaded (or when it has none).
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

-- Pure: the pack that really gives the most Stars for each Robux among what this
-- player can still buy. Computed from the snapshot so the tag is never a guess
-- (the Starter pack while it is unclaimed).
function View.bestValue(products)
	local bestKey, bestRatio, count = nil, 0, 0
	for _, product in ipairs(products or {}) do
		if not product.claimed and (tonumber(product.price) or 0) > 0 then
			count += 1
			local ratio = (tonumber(product.stars) or 0) / product.price
			if ratio > bestRatio then bestKey, bestRatio = product.key, ratio end
		end
	end
	return if count >= 2 then bestKey else nil
end
function View:bestValueKey(products)
	return View.bestValue(products)
end

-- Pure: the offers in list order for a snapshot. Passes first, then (only when packs are
-- allowed and the snapshot is ready) the Starter pack until it is claimed, then the packs.
-- Each offer: {key, kind = "pass" | "pack", name, price, stars, owned, enabled, reason,
-- best}. reason: nil (buyable), "owned", "loading" or "soon".
function View.offers(state)
	state = state or fallbackState()
	local list = {}
	local ready = state.ready == true
	for _, pass in ipairs(state.passes or {}) do
		local reason = if pass.owned then "owned" elseif not ready then "loading" elseif not pass.available then "soon" else nil
		table.insert(list, { key = pass.key, kind = "pass", name = pass.name, price = pass.price, owned = pass.owned == true,
			enabled = reason == nil, reason = reason, blurb = pass.blurb })
	end
	if state.packsAllowed == true and ready then
		local products = state.products or {}
		local best = View.bestValue(products)
		for _, product in ipairs(products) do
			if not (product.once and product.claimed) then
				local reason = if product.available then nil else "soon"
				table.insert(list, { key = product.key, kind = "pack", name = product.name, price = product.price,
					stars = tonumber(product.stars) or 0, once = product.once == true, owned = false,
					enabled = reason == nil, reason = reason, best = best == product.key, blurb = product.blurb })
			end
		end
	end
	return list
end

-- Pure: the offer a fresh open selects: the first one that can be bought, else the first.
function View.openingKey(offers)
	for _, offer in ipairs(offers) do if offer.enabled then return offer.key end end
	return if offers[1] then offers[1].key else nil
end

-- Pure: the row's one line under the name.
function View.subLine(offer)
	if offer.kind == "pass" then return UICopy.get("store.sub." .. offer.key) end
	if offer.once then return UICopy.get("store.sub.starter", { stars = offer.stars }) end
	return UICopy.get("store.sub.pack", { stars = offer.stars })
end

-- Pure: the tray's blurb.
function View.blurb(offer)
	if offer.kind == "pass" or offer.once then
		local entry = if offer.kind == "pass" then Catalog.PassByKey[offer.key] else Catalog.ProductByKey[offer.key]
		return offer.blurb or (entry and entry.blurb) or ""
	end
	return UICopy.get("store.blurb." .. offer.key)
end

-- Pure: the tray's "what you get" rows, {label, value}.
function View.gets(offer, balance)
	if offer.kind == "pack" then
		return { { UICopy.get("store.starsRow"), "+" .. tostring(offer.stars) },
			{ UICopy.get("store.walletAfter"), tostring((tonumber(balance) or 0) + offer.stars) } }
	end
	local first = if offer.key == "supporter"
		then { UICopy.get("store.gets.supporter"), UICopy.get("store.gets.supporterValue") }
		else { UICopy.get("store.gets.doubleStars"), UICopy.get("store.gets.doubleStarsValue") }
	return { first, { UICopy.get("store.keepsWorking"), UICopy.get("store.foreverValue") } }
end

-- Pure: the Buy key's text and whether it can be pressed.
function View.buyKey(offer, cooling)
	if not offer then return UICopy.get("store.loading"), false end
	if offer.reason == "owned" then return UICopy.get("store.owned"), false end
	if offer.reason == "loading" then return UICopy.get("store.loading"), false end
	if offer.reason == "soon" then return UICopy.get("store.soon"), false end
	if cooling then return UICopy.get("store.opening"), false end
	return UICopy.get("store.buy", { price = offer.price }), true
end

-- Pure: chrome geometry. Hatch eggs passes its own (View.shopGeometry) through attachStore
-- so both panels match; this copy is the fallback for specs and a missing host.
function View.defaultGeometry(W, H, phone)
	if phone then
		return { phone = true, W = W, H = H, list = { x = 20, y = 64, w = 226, h = H - 84 }, rowH = 56, rowGap = 8,
			pane = { x = 252, y = 64, w = W - 20 - 252, h = H - 84 }, pad = 12, actionH = 44 }
	end
	return { phone = false, W = 848, H = 608, list = { x = 24, y = 84, w = 334, h = 452 }, rowH = 72, rowGap = 12,
		pane = { x = 368, y = 84, w = 456, h = 452 }, pad = 16, actionH = 56 }
end

-- An offer icon: a rounded, ink-stroked square with the uploaded image, and the drawn
-- badge under it until the image has loaded (an id still in moderation renders blank).
local function iconBox(parent, name, size, radius, stroke)
	local box = Kit.frame(parent, name, "well", UDim2.new(), UDim2.fromOffset(size, size), radius)
	box.BackgroundTransparency = 0
	Kit.stroke(box, "ink", stroke, 0)
	local badge = Kit.text(box, "Title", "", "stars", { Name = "Badge", Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = math.max(11, math.floor(size * .36)) })
	Kit.fixedText(badge)
	local image = Instance.new("ImageLabel")
	image.Name, image.BackgroundTransparency, image.BorderSizePixel = "Image", 1, 0
	image.Size, image.ZIndex, image.Visible, image.ScaleType = UDim2.fromScale(1, 1), box.ZIndex + 2, false, Enum.ScaleType.Fit
	image.Parent = box
	Kit.corner(image, radius)
	return box
end

function View.new(parent, options)
	options = options or {}
	local z = options.z or 70
	local shade = Instance.new("Frame")
	shade.Name, shade.BackgroundTransparency, shade.BorderSizePixel = "StoreView", 1, 0
	shade.Size, shade.ZIndex, shade.Active, shade.Visible = UDim2.fromScale(1, 1), z, true, false
	shade.Parent = parent
	local self = setmetatable({
		shade = shade,
		reduceEffects = options.reduceEffects or function() return false end,
		request = options.request or function() end,
		geometry = options.geometry,
		state = fallbackState(), balance = 0, message = View.Idle, messageKind = "info",
		promptToken = 0, cooling = false, offers = {}, rows = {}, list = {}, iconReady = {}, iconTries = {},
	}, View)
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if shade.Visible then self:layout() end
	end)
	local selection = GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		local node = GuiService.SelectedObject
		if shade.Visible and self.body and node and node:IsDescendantOf(self.body) then self:ensureVisible(node) end
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

function View:backButton()
	return self.header and self.header.back.root or nil
end

function View:focusTarget()
	local row = self.selectedKey and self.rows[self.selectedKey]
	if row and row.Parent and row.Interactable and row.Selectable then return row end
	for _, offer in ipairs(self.offers) do
		if offer.button.Parent and offer.button.Interactable and offer.button.Selectable then return offer.button end
	end
	return self:backButton()
end

function View:getControllerFocus()
	if not self.shade.Visible then return nil end
	return { root = self.shade, epoch = self.shade:GetAttribute("ControllerEpoch") or 0,
		target = function() return self:focusTarget() end, fallback = self:backButton(),
		ensure = function(node) self:ensureVisible(node) end }
end

function View:ensureVisible(node)
	local body = self.body
	if not body or not node or not node:IsDescendantOf(body) then return end
	local window = if body.Size.Y.Scale == 0 and body.Size.Y.Offset > 0 then body.Size.Y.Offset else body.AbsoluteSize.Y
	local scale = if body.AbsoluteSize.Y > 0 then window / body.AbsoluteSize.Y else 1
	local top = (node.AbsolutePosition.Y - body.AbsolutePosition.Y) * scale + body.CanvasPosition.Y
	local height = node.AbsoluteSize.Y * scale
	local current = body.CanvasPosition.Y
	local wanted = if height > window or top < current then math.max(0, top - 4)
		elseif top + height > current + window then top + height + 4 - window else current
	body.CanvasPosition = Vector2.new(0, math.clamp(wanted, 0, math.max(0, body.CanvasSize.Y.Offset - window)))
end

function View:setMessage(text, kind)
	self.message, self.messageKind = text or View.Idle, kind or "info"
	if self.shade.Visible then self:paintPane() end
end

function View:setBalance(balance)
	balance = tonumber(balance)
	if not balance or balance == self.balance then return end
	self.balance = balance
	if self.header and self.header.wallet then self.header.wallet.set(balance) end
	if self.shade.Visible then self:paintPane() end
end

function View:setState(snapshot)
	if type(snapshot) ~= "table" or type(snapshot.passes) ~= "table" or type(snapshot.products) ~= "table" then return false end
	self.state = snapshot
	if self.shade.Visible then self:layout() end
	return true
end

-- The wallet in the header counts up and flashes on its own (Kit.wallet earn juice).
function View:pulseWallet()
	if self.header and self.header.wallet then self.header.wallet.set(self.balance) end
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
		self:pulseWallet()
		self:setMessage(string.format("+%s added. You have %s.", Stars.amount(stars), Stars.amount(self.balance)), "reward")
	elseif result.kind == "pass" then
		local name
		for _, pass in ipairs(self.state.passes) do
			if pass.key == result.key then
				name = pass.name
				pass.owned = true
			end
		end
		self:setMessage((name or "Your pass") .. " is yours. Thank you!", "reward")
		if self.shade.Visible then self:layout() end
	elseif result.kind == "rejected" then
		self:setMessage(View.Rejected[result.reason] or View.Rejected.Unavailable, "notice")
	end
end

function View:offerFor(key)
	for _, offer in ipairs(self.list) do if offer.key == key then return offer end end
	return nil
end

function View:prompt(key)
	if not self:ownsInput() or self.cooling then return false end
	local offer = self:offerFor(key)
	if offer and not offer.enabled then return false end
	-- The server throttles prompts to one a second; a short quiet window keeps a
	-- double tap from turning into a "try again" message.
	self.cooling = true
	self.promptToken += 1
	local token = self.promptToken
	self:setMessage(View.Opening, "info")
	if self.onAccepted then self.onAccepted("confirm") end
	self.request("prompt", key)
	task.delay(1.2, function()
		if self.promptToken == token then
			self.cooling = false
			if self.shade.Visible then self:paintPane() end
		end
	end)
	return true
end

-- Enter / Space / the Buy key: prompt the selected offer.
function View:buySelected()
	if not self.selectedKey then return false end
	return self:prompt(self.selectedKey)
end

function View:select(key, animate)
	if not key or not self:offerFor(key) then return false end
	local changed = self.selectedKey ~= key
	self.selectedKey = key
	self:paintRows()
	self:paintPane()
	if self.rows[key] then self:ensureVisible(self.rows[key]) end
	if changed and animate and self.stageIcon and not self.reduceEffects() then Kit.boing(self.stageIcon) end
	return changed
end

-- W / S / Up / Down (init.client routes them while the store is open).
function View:move(delta)
	if #self.list == 0 then return false end
	local index = 1
	for i, offer in ipairs(self.list) do if offer.key == self.selectedKey then index = i end end
	local nextIndex = math.clamp(index + delta, 1, #self.list)
	if nextIndex == index then return false end
	self:select(self.list[nextIndex].key, true)
	local row = self.rows[self.selectedKey]
	if row then
		self:ensureVisible(row)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade) then GuiService.SelectedObject = row end
	end
	return true
end

function View:open(balance)
	if tonumber(balance) then self.balance = tonumber(balance) end
	self:bumpControllerEpoch()
	if not self.shade.Visible then
		self.previousSelection = GuiService.SelectedObject
		self.message, self.messageKind, self.cooling = View.Idle, "info", false
		self.selectedKey = nil
		if self.body then self.body.CanvasPosition = Vector2.zero end
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

-- ── Chrome ────────────────────────────────────────────────────────────────────
function View:buildChrome(view)
	if self.root then self.root:Destroy() end
	local phone = view ~= nil
	local geometry = self.geometry or View.defaultGeometry
	local g = geometry(if phone then view.W else 848, if phone then view.H else 608, phone)
	self.g, self.chromeKey = g, if phone then string.format("%dx%d", view.W, view.H) else "regular"
	table.clear(self.rows)
	local root = Kit.frame(self.shade, "StoreRoot", nil, UDim2.new(), UDim2.fromScale(1, 1))
	root.ZIndex = self.shade.ZIndex + 1
	self.root = root
	local panel = Kit.frame(root, "Panel", "panel", UDim2.fromScale(.5, .5), UDim2.fromOffset(g.W, g.H), 30)
	panel.Active, panel.ZIndex = true, root.ZIndex + 1
	self.panel, self.panelScale = panel, Kit.node("UIScale", panel, { Scale = 1 })
	local body = panel
	if phone then
		panel.BackgroundTransparency = 1
		local sheet = Kit.sheet(panel, g.W, g.H)
		body = Kit.frame(panel, "Content", nil, UDim2.new(), UDim2.fromScale(1, 1))
		body.ZIndex = sheet.ZIndex + 3
	else
		panel.AnchorPoint, panel.ClipsDescendants = Vector2.new(.5, .5), true
		Kit.stroke(panel)
		Kit.shellPattern(panel, 30)
		local gradient = Kit.frame(panel, "Gradient", nil, UDim2.new(), UDim2.fromScale(1, 1))
		gradient.BackgroundTransparency, gradient.BackgroundColor3 = 0, Color3.new(1, 1, 1)
		Kit.node("UIGradient", gradient, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)),
			Transparency = NumberSequence.new(.97, .88) })
	end
	self.content = body
	self.header = Kit.header(body, { title = UICopy.get("store.title"), eyebrow = UICopy.get("store.eyebrow"), tint = "results",
		compact = phone, width = g.W, left = 24, onBack = function() self:close("back") end })
	self.header.back.root.Selectable = true
	if self.header.wallet then self.header.wallet.set(self.balance) end
	-- The list: a scrolling column of offer tiles.
	local list = Instance.new("ScrollingFrame")
	list.Name, list.BackgroundTransparency, list.BorderSizePixel = "Body", 1, 0
	list.ZIndex, list.ClipsDescendants, list.ScrollBarThickness = body.ZIndex + 1, true, 4
	list.ScrollingDirection, list.ElasticBehavior, list.Selectable = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.Never, false
	list.Position, list.Size = UDim2.fromOffset(g.list.x - 3, g.list.y - 3), UDim2.fromOffset(g.list.w, g.list.h + 6)
	Kit.paint(list, "ScrollBarImageColor3", "soft")
	list.Parent = body
	self.body = list
	-- The tray: stage with the icon, name + chip, blurb, what you get, message, Buy.
	local pane = Kit.card(body, "OfferPane", nil, { pad = g.pad, seam = not phone })
	pane.Position, pane.Size = UDim2.fromOffset(g.pane.x, g.pane.y), UDim2.fromOffset(g.pane.w, g.pane.h)
	self.pane = pane
	local p = g.pad
	local wellR = if phone then { x = p, y = p, w = 138, h = 138 } else { x = p, y = p, w = g.pane.w - p * 2, h = 152 }
	local well = Kit.previewWell(pane, "OfferWell", UDim2.fromOffset(wellR.x, wellR.y), UDim2.fromOffset(wellR.w, wellR.h), 12)
	local iconSize = math.min(wellR.h - 28, if phone then 100 else 124)
	local stageIcon = iconBox(well, "StageIcon", iconSize, if phone then 16 else 20, 3)
	stageIcon.AnchorPoint, stageIcon.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
	stageIcon.ZIndex = well.ZIndex + 4
	self.stageIcon = stageIcon
	for index, spec in ipairs({ { -.34, -.22, 16 }, { .36, -.1, 12 }, { .3, .3, 10 } }) do
		local spark = Kit.text(well, "Title", "✦", if index == 2 then "text" else "stars",
			{ Name = "Sparkle" .. index, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, spec[1] * wellR.w, .5, spec[2] * wellR.h),
				Size = UDim2.fromOffset(spec[3] * 2, spec[3] * 2), TextSize = spec[3] * 2, TextXAlignment = Enum.TextXAlignment.Center })
		spark.ZIndex = well.ZIndex + 3
	end
	local tx = if phone then wellR.x + wellR.w + 12 else p
	local tw = g.pane.w - tx - p
	local y = if phone then p else wellR.y + wellR.h + 12
	self.offerName = Kit.text(pane, "Title", "", "text", { Name = "OfferName", Position = UDim2.fromOffset(tx, y),
		Size = UDim2.fromOffset(tw - 96, if phone then 24 else 30), TextSize = if phone then 18 else 24, TextTruncate = Enum.TextTruncate.AtEnd })
	self.offerChip = Kit.chip(pane, "", "sticker", if phone then 22 else 26)
	self.offerChip.root.AnchorPoint = Vector2.new(1, .5)
	self.offerChip.root.Position = UDim2.fromOffset(tx + tw, y + (if phone then 12 else 15))
	y += if phone then 26 else 32
	self.offerBlurb = Kit.text(pane, "Body", "", "soft", { Name = "OfferBlurb", Position = UDim2.fromOffset(tx, y),
		Size = UDim2.fromOffset(tw, if phone then 30 else 40), TextSize = if phone then 12 else 15, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top })
	y += if phone then 32 else 44
	if not phone then
		Kit.text(pane, "Label", string.upper(UICopy.get("store.whatYouGet")), "dim", { Name = "GetsLabel",
			Position = UDim2.fromOffset(tx, y), Size = UDim2.fromOffset(tw, 16), TextSize = 12 })
		y += 20
	end
	self.getsTop, self.getsX, self.getsW = y, tx, tw
	self.gets = Kit.frame(pane, "Gets", nil, UDim2.fromOffset(tx, y), UDim2.fromOffset(tw, 10))
	local buttonY = g.pane.h - p - g.actionH
	self.status = Kit.text(pane, "Small", View.Idle, "soft", { Name = "Status", Position = UDim2.fromOffset(tx, buttonY - (if phone then 34 else 40)),
		Size = UDim2.fromOffset(tw, if phone then 30 else 36), TextSize = if phone then 12 else 14, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom })
	local buy = Kit.button(pane, "BuyButton", { variant = "primary", text = "", glyph = "A", size = Vector2.new(tw, g.actionH),
		textSize = if phone then 16 else nil, selectable = true })
	buy.Position = UDim2.fromOffset(tx, buttonY)
	buy.Activated:Connect(function() self:buySelected() end)
	self.buyButton = buy
	-- Footer (desktop): hint chips left, the free-earn line right.
	self.hintRow = nil
	if not phone then
		local row = Kit.frame(body, "Hints", nil, UDim2.fromOffset(24, 566), UDim2.fromOffset(420, 24))
		self.hintRow = row
		Kit.text(body, "Small", UICopy.get("store.free"), "dim", { Name = "FreeLine", Position = UDim2.fromOffset(424, 566),
			Size = UDim2.fromOffset(400, 24), TextXAlignment = Enum.TextXAlignment.Right })
		self:paintHints()
	end
	self:warmIcons()
end

function View:paintHints()
	local row = self.hintRow
	if not row then return end
	local HintGlyphs = require(script.Parent.HintGlyphs)
	local kind = HintGlyphs.kindOf(UserInputService:GetLastInputType())
	for _, child in ipairs(row:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	local x = 0
	for _, pair in ipairs(HintGlyphs.rows({ { "browse", UICopy.get("input.action.browse") }, { "confirm", UICopy.get("store.hints.buy") },
		{ "back", UICopy.get("input.action.back") } }, kind)) do
		local chip = Kit.glyph(row, pair[1], false, 22, true)
		chip.Position = UDim2.fromOffset(x, 1)
		x += chip.Size.X.Offset + 6
		Kit.text(row, "Small", pair[2], "soft", { Name = "Hint_" .. pair[2], Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(120, 24),
			AutomaticSize = Enum.AutomaticSize.X })
		x += math.ceil(Kit.measure(pair[2], "Small", 14).X) + 18
	end
	row:SetAttribute("HintInput", kind)
end

-- Icons: each id loads on its own (one still in moderation never blocks the rest); the
-- badge shows until it has. A failed id retries every 4 s while the page is open, 10 times.
function View:warmIcons()
	local warm = require(script.Parent.UIAssetWarmup).shared
	for key, uri in pairs(Catalog.Icons or {}) do
		if not self.iconReady[uri] and not self.iconTries[uri] then
			self.iconTries[uri] = 0
			local function ask(retry)
				local request = if retry then warm.retry else warm.request
				request(warm, { uri }, function(ok)
					if self.destroyed then return end
					if ok then
						self.iconReady[uri] = true
						if self.shade.Visible then self:paintRows(); self:paintPane() end
					else
						self.iconTries[uri] += 1
						if self.iconTries[uri] < 10 then
							task.delay(4, function() if not self.destroyed and not self.iconReady[uri] then ask(true) end end)
						end
					end
				end, 1)
			end
			local _ = key
			ask(false)
		end
	end
end

-- Paints an iconBox for an offer: the image once it has loaded, else the badge.
function View:paintIcon(box, offer)
	local uri = Catalog.Icons and Catalog.Icons[offer.key]
	local ready = uri ~= nil and self.iconReady[uri] == true
	local image, badge = box:FindFirstChild("Image"), box:FindFirstChild("Badge")
	if image then
		image.Image = if ready then uri else ""
		image.Visible = ready
	end
	if badge then
		badge.Visible = not ready
		badge.Text = if offer.kind == "pass" then (View.Badges[offer.key] or "★") else tostring(offer.stars)
	end
	box:SetAttribute("IconReady", ready)
end

-- ── The list ──────────────────────────────────────────────────────────────────
function View:renderList()
	local g, list = self.g, self.body
	local phone = g.phone
	local canvas = list.CanvasPosition
	local previous = GuiService.SelectedObject
	local focusKey = previous and previous:IsDescendantOf(list) and previous:GetAttribute("OfferKey") or nil
	for _, child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	table.clear(self.rows)
	table.clear(self.offers)
	self.list = View.offers(self.state)
	if not self.selectedKey or not self:offerFor(self.selectedKey) then self.selectedKey = View.openingKey(self.list) end
	local column = Kit.frame(list, "Column", nil, UDim2.fromOffset(0, 0), UDim2.fromOffset(g.list.w, 1))
	local packs = 0
	for _, offer in ipairs(self.list) do if offer.kind == "pack" then packs += 1 end end
	column:SetAttribute("PacksShown", packs > 0)
	local w = g.list.w - 10
	local passesOnly = packs == 0
	-- 44 px rows at least everywhere (touch); a phone list scrolls when they don't all fit.
	local rowH = if phone then 52 else g.rowH
	local rowGap = if phone then 6 else 8
	if passesOnly then rowH = math.max(rowH, if phone then 60 else 80) end
	-- Desktop: all seven fit the 452 px window with both eyebrows (Fable's mock: 50 px rows).
	if not phone and not passesOnly then rowH = 50 end
	local y = 3
	local lastKind
	for _, offer in ipairs(self.list) do
		if not phone and offer.kind ~= lastKind and not passesOnly then
			Kit.text(column, "Label", string.upper(UICopy.get(if offer.kind == "pass" then "store.boosts" else "store.packs")), "dim",
				{ Name = if offer.kind == "pass" then "BoostsHeading" else "PacksHeading", Position = UDim2.fromOffset(8, y),
					Size = UDim2.fromOffset(w, 18), TextSize = 12 })
			y += 20
		elseif phone and lastKind and offer.kind ~= lastKind then
			y += 4
		end
		lastKind = offer.kind
		local n = Kit.tile(column, (if offer.kind == "pass" then "Pass_" else "Product_") .. offer.key,
			{ radius = 12, compact = phone, selectable = true })
		n:SetAttribute("OfferKey", offer.key)
		n.Position, n.Size = UDim2.fromOffset(3, y), UDim2.fromOffset(w, rowH)
		local key = offer.key
		n.Activated:Connect(function()
			if not self:ownsInput() then return end
			if self.selectedKey == key then self:buySelected() else self:select(key, true); Kit.boing(n) end
		end)
		n.SelectionGained:Connect(function() if self.selectedKey ~= key then self:select(key, true) end end)
		local iconSize = math.min(rowH - 12, if phone then 38 else 44)
		local icon = iconBox(n, "Icon", iconSize, 8, 2)
		icon.Position = UDim2.fromOffset(10, math.floor((rowH - iconSize) / 2))
		icon.ZIndex = n.ZIndex + 2
		local tx = 10 + iconSize + 10
		local priceW = if offer.owned then (if phone then 78 else 92) else (if phone then 64 else 76)
		local name = Kit.text(n, "Name", offer.name, "text", { Name = "OfferName", TextTruncate = Enum.TextTruncate.AtEnd,
			TextSize = if phone then 15 else 18 })
		local nameW = w - tx - priceW - 8
		while name.TextSize > 11 and Kit.measure(offer.name, "Name", name.TextSize).X > nameW do name.TextSize -= 1 end
		local showSub = not phone or passesOnly
		if showSub then
			name.Position, name.Size = UDim2.fromOffset(tx, rowH / 2 - (if phone then 19 else 22)), UDim2.fromOffset(nameW, if phone then 20 else 24)
			Kit.text(n, "Small", View.subLine(offer), "soft", { Name = "OfferLine", Position = UDim2.fromOffset(tx, rowH / 2 + 2),
				Size = UDim2.fromOffset(nameW, 18), TextSize = if phone then 12 else 14, TextTruncate = Enum.TextTruncate.AtEnd })
		else
			name.Position, name.Size = UDim2.fromOffset(tx, 0), UDim2.fromOffset(nameW, rowH)
		end
		if offer.owned then
			local chip = Kit.chip(n, UICopy.get("store.ownedChip"), "plain", if phone then 22 else 26)
			chip.root.AnchorPoint, chip.root.Position = Vector2.new(1, .5), UDim2.new(1, -10, .5, 0)
			chip.root.ZIndex = n.ZIndex + 2
			chip.root.Name = "OwnedChip"
		else
			Kit.text(n, "Counter", View.price(offer.price), if offer.enabled then "text" else "soft", { Name = "Price",
				Position = UDim2.fromOffset(w - priceW - 10, 0), Size = UDim2.fromOffset(priceW, rowH), TextSize = if phone then 15 else 18,
				TextXAlignment = Enum.TextXAlignment.Right })
		end
		if offer.best then
			local sticker = Kit.chip(n, UICopy.get("store.best"), "sticker", if phone then 18 else 22)
			sticker.root.Name = "BestValue"
			sticker.root.AnchorPoint, sticker.root.Position = Vector2.new(1, .5), UDim2.new(1, -8, 0, 2)
			sticker.root.ZIndex = n.ZIndex + 4
		end
		n:SetAttribute("Owned", offer.owned)
		n:SetAttribute("AccessibleLabel", offer.name .. ", " .. View.subLine(offer) .. ", "
			.. (if offer.owned then UICopy.get("store.owned") else View.price(offer.price)))
		self.rows[offer.key] = n
		table.insert(self.offers, { key = offer.key, button = n })
		y += rowH + rowGap
	end
	if phone then
		y += 2
		Kit.text(column, "Small", UICopy.get("store.free"), "soft", { Name = "FreeLine", Position = UDim2.fromOffset(8, y),
			Size = UDim2.fromOffset(w - 8, 32), TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		y += 34
	end
	local window = list.Size.Y.Offset
	column.Size = UDim2.fromOffset(g.list.w, y)
	list.CanvasSize = UDim2.fromOffset(0, y + 4)
	list.ScrollingEnabled = y + 4 > window
	list:SetAttribute("Scrolls", y + 4 > window)
	list.CanvasPosition = Vector2.new(0, math.clamp(canvas.Y, 0, math.max(0, y + 4 - window)))
	self:paintRows()
	if focusKey and self:ownsInput() then
		local target = self.rows[focusKey] or self:focusTarget()
		if target then GuiService.SelectedObject = target end
	end
end

function View:paintRows()
	for _, offer in ipairs(self.list) do
		local n = self.rows[offer.key]
		if n and n.Parent then
			local selected = self.selectedKey == offer.key
			local state = Kit.tileState(n)
			if state and state.setSelected then state.setSelected(selected) end
			n:SetAttribute("Selected", selected)
			local icon = n:FindFirstChild("Icon")
			if icon then self:paintIcon(icon, offer) end
		end
	end
end

-- ── The tray ──────────────────────────────────────────────────────────────────
function View:paintPane()
	if not self.pane then return end
	local offer = self.selectedKey and self:offerFor(self.selectedKey)
	local phone = self.g.phone
	self.pane:SetAttribute("OfferKey", offer and offer.key or nil)
	if offer then
		self:paintIcon(self.stageIcon, offer)
		self.offerName.Text = offer.name
		local chipText = if offer.kind == "pack" then "★ " .. tostring(offer.stars)
			elseif offer.owned then UICopy.get("store.ownedChip") else UICopy.get("store.forever")
		self.offerChip.set(chipText, "sticker")
		self.offerBlurb.Text = if offer.owned then UICopy.get("store.thanks") else View.blurb(offer)
	else
		self.offerName.Text, self.offerBlurb.Text = UICopy.get("store.title"), ""
		self.offerChip.set("", "sticker")
	end
	self.offerChip.root.Visible = offer ~= nil
	-- What you get.
	for _, child in ipairs(self.gets:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	local rowH, gap = if phone then 24 else 30, if phone then 4 else 6
	local rows = if offer then View.gets(offer, self.balance) else {}
	for index, pair in ipairs(rows) do
		local r = Kit.frame(self.gets, "Get" .. index, "well", UDim2.fromOffset(0, (index - 1) * (rowH + gap)), UDim2.fromOffset(self.getsW, rowH), 8)
		r.BackgroundTransparency = 0
		Kit.text(r, "Body", pair[1], "text", { Name = "Label", Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(self.getsW * .6, rowH),
			TextSize = if phone then 12 else 15, TextTruncate = Enum.TextTruncate.AtEnd })
		Kit.text(r, "Counter", pair[2], "text", { Name = "Value", Position = UDim2.fromOffset(self.getsW * .55, 0),
			Size = UDim2.fromOffset(self.getsW * .45 - 10, rowH), TextSize = if phone then 13 else 16, TextXAlignment = Enum.TextXAlignment.Right })
	end
	self.gets.Size = UDim2.fromOffset(self.getsW, math.max(1, #rows * (rowH + gap)))
	-- Message line over the key.
	self.status.Text = self.message
	Kit.paint(self.status, "TextColor3", if self.messageKind == "reward" then "stars" elseif self.messageKind == "notice" then "text" else "soft")
	self.status:SetAttribute("MessageKind", self.messageKind)
	-- The one green key.
	local text, enabled = View.buyKey(offer, self.cooling)
	Kit.setText(self.buyButton, text)
	Kit.setEnabled(self.buyButton, enabled)
	Kit.setGlyphVisible(self.buyButton, not phone or not Kit.lastInputTouch())
	self.buyButton:SetAttribute("OfferKey", offer and offer.key or nil)
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
		local phone = Kit.compactRule(size.X, size.Y)
		local view = nil
		if phone then
			local top = Kit.sheetTop(self.shade)
			view = { W = math.floor(size.X), H = math.max(1, math.floor(size.Y) - top), top = top }
		end
		local key = if view then string.format("%dx%d", view.W, view.H) else "regular"
		if self.chromeKey ~= key or not self.root or not self.root.Parent then self:buildChrome(view) end
		local panel = self.panel
		if view then
			panel.AnchorPoint, panel.Position, panel.Size = Vector2.zero, UDim2.fromOffset(0, view.top), UDim2.fromOffset(view.W, view.H)
			self.panelScale.Scale = 1
		else
			panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromOffset(848, 608)
			self.panelScale.Scale = math.max(.1, math.min(1.2, (size.X - 24) / 848, (size.Y - 24) / 608))
		end
		if self.header.wallet then self.header.wallet.set(self.balance) end
		self:renderList()
		self:paintPane()
	until not self.layoutDirty or self.destroyed
	self.layingOut = false
end

return View
