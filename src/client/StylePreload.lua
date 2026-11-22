-- Launch candidate (Spencer, 2026-11-17): Deck style tiles showed dark or empty until their
-- textures loaded, for players too. After the garden has loaded, this warms every image the
-- Deck style screen draws (the mini deck's shell sprites, each faceplate texture and finish
-- overlay) through the shared UIAssetWarmup queue at background priority 0, a few at a time.
-- The tiles ask the same queue at priority 1 when Deck style opens, so anything still
-- missing jumps ahead (just in time), and anything already warm answers at once.
-- The 3D preview grids (Customize jars, Toys, charms, Wardrobe pets and wearables, material
-- templates) draw meshes and textures, not images: their asset folders get one low-priority
-- ContentProvider:PreloadAsync after the images. Ball themes are drawn from frames (no assets).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Levels = require(ReplicatedStorage.Shared.Levels)

local Preload = {}
Preload.Batch = 3 -- images handed to the queue per step
Preload.Gap = 0.4 -- seconds between batches
Preload.Settle = 4 -- seconds after the garden appears before the first batch
Preload.GardenWait = 30 -- give up waiting for the garden after this long and warm anyway
-- 3D preview folders (ReplicatedStorage), in the order players meet them.
Preload.Folders = table.freeze({ "PetToyAssets", "JarAssets", "PetCharmAssets", "PetMaterials", "PetMaterialsTwoTone", "PetAssets" })

-- Pure: every image id the Deck style screen draws, deduplicated, in a stable order (the
-- equipped look's shell first, then faceplates in their published order).
function Preload.styleImages(assets, themes)
	assets = assets or require(script.Parent.DeckAssets)
	themes = themes or require(ReplicatedStorage.Shared.DeckThemes)
	local out, seen = {}, {}
	local function add(id) if type(id) == "string" and id ~= "" and not seen[id] then seen[id] = true; table.insert(out, id) end end
	for _, key in ipairs({ "band", "plateOverlay", "glass", "dpadDisc", "dpadArrows", "buttonBase", "wordmark" }) do add(assets.Image[key]) end
	local ordered = {}
	for id, theme in pairs(themes.ById) do table.insert(ordered, { id = id, order = theme.order or math.huge }) end
	table.sort(ordered, function(a, b) if a.order ~= b.order then return a.order < b.order end; return a.id < b.id end)
	for _, entry in ipairs(ordered) do
		local theme = themes.ById[entry.id]
		-- Levels matter: a gated plate's art only while gates are on (an owned one loads when it is drawn).
		if theme.gate ~= nil and not Levels.on("gates") then continue end
		add(assets.Faceplate[entry.id] or theme.texture)
		if type(theme.overlay) == "table" then add(theme.overlay.image) end
	end
	return out
end

-- Spencer 2026-11-21: "we need to preload the textures ... for everything like the eggs too".
-- Every image the menus and hatch screens draw, read from the asset tables themselves (any
-- "rbxassetid://<n>" string inside them, nested tables included): the Get Stars icons first,
-- then the deck shell, egg art, the hatch stage, round items. Style images follow.
Preload.MenuModules = table.freeze({
	{ shared = "StoreCatalog", key = "Icons" }, { client = "DeckAssets" }, { client = "EggArtAssets" },
	{ shared = "EggModels" }, { client = "HatchDisplayAssets" }, { shared = "RoundItems" },
	{ client = "MedalView", key = "Art", part = "medals" },
})
function Preload.collectImages(value, out, seen, visited)
	visited = visited or {}
	if type(value) == "string" then
		local id = value:match("^rbxassetid://(%d+)$")
		if id and not seen["rbxassetid://" .. id] then seen["rbxassetid://" .. id] = true; table.insert(out, "rbxassetid://" .. id) end
	elseif type(value) == "table" and not visited[value] then
		visited[value] = true
		-- Stable order: sorted keys, so the queue is the same every session.
		local keys = {}
		for k in pairs(value) do table.insert(keys, k) end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do
			-- `mesh` fields (EggModels, HatchDisplayAssets) hold mesh ids: asked for as images they
			-- fail ("Asset type does not match requested type") and retry in this same queue.
			if not (type(k) == "string" and k:lower():find("mesh", 1, true)) then Preload.collectImages(value[k], out, seen, visited) end
		end
	end
	return out
end
function Preload.menuImages(modules)
	local out, seen = {}, {}
	-- DeckAssets lists every faceplate: the gated ones are styleImages' business.
	for _, theme in pairs(require(ReplicatedStorage.Shared.DeckThemes).ById) do if theme.gate ~= nil and theme.texture then seen[theme.texture] = true end end
	for _, spec in ipairs(modules or Preload.MenuModules) do
		if spec.part and not Levels.on(spec.part) then continue end
		local ok, data = pcall(function()
			local module = if spec.shared then ReplicatedStorage.Shared:FindFirstChild(spec.shared) else script.Parent:FindFirstChild(spec.client)
			return module and require(module)
		end)
		if ok and data then Preload.collectImages(if spec.key then data[spec.key] else data, out, seen) end
	end
	return out
end
-- Pure: menu images first, then Deck style's, deduplicated.
function Preload.allImages()
	local out, seen = {}, {}
	for _, list in ipairs({ Preload.menuImages(), Preload.styleImages() }) do
		for _, raw in ipairs(list) do
			local id = Preload.canonical(raw)
			if type(id) == "string" and not seen[id] then seen[id] = true; table.insert(out, id) end
		end
	end
	return out
end

-- Pure: the queue's id form, so callers can ask "is this one warm?".
local function canonical(uri)
	local id = type(uri) == "string" and (uri:match("^rbxassetid://(%d+)$") or uri:match("^(%d+)$"))
	return if id then "rbxassetid://" .. id else uri
end
Preload.canonical = canonical

-- options (specs): warm (UIAssetWarmup instance), wait, gardenReady(), preload(items), folders.
function Preload.new(options)
	options = options or {}
	local self = {
		warm = options.warm or require(script.Parent.UIAssetWarmup).shared,
		wait = options.wait or task.wait,
		gardenReady = options.gardenReady or function() return workspace:FindFirstChild("EggDropLounge") ~= nil end,
		preload = options.preload or function(items) ContentProvider:PreloadAsync(items) end,
		folders = options.folders,
		images = options.images or Preload.allImages(),
		ready = {}, failed = {}, boosted = {}, started = false, done = false, stopped = false,
	}
	return setmetatable(self, { __index = Preload })
end
-- Levels matter: the switch came on after this list was made: what it adds joins the background pass.
function Preload:extend(images)
	local seen = {}
	for _, uri in ipairs(self.images) do seen[canonical(uri)] = true end
	for _, uri in ipairs(images or Preload.allImages()) do
		local id = canonical(uri)
		if not seen[id] then
			seen[id] = true
			table.insert(self.images, uri)
			if self.done then self.warm:request({ id }, function(ok) if ok then self.ready[id] = true else self.failed[id] = true end; self:progress() end, 0) end
		end
	end
end
function Preload:isReady(uri) return self.ready[canonical(uri)] == true end
function Preload:stop() self.stopped = true end
-- Background pass: wait for the game and the garden, then warm in small batches.
function Preload:run()
	if self.started then return end
	self.started = true
	if not game:IsLoaded() then game.Loaded:Wait() end
	local waited = 0
	while not self.gardenReady() and waited < Preload.GardenWait and not self.stopped do waited += self.wait(0.5) or 0.5 end
	self.wait(Preload.Settle)
	self:report("StylePreloadStartedAt", os.clock())
	local index = 1
	while index <= #self.images and not self.stopped do
		local pending = 0
		for i = index, math.min(#self.images, index + Preload.Batch - 1) do
			local id = canonical(self.images[i])
			pending += 1
			self.warm:request({ id }, function(ok)
				pending -= 1
				if ok then self.ready[id] = true else self.failed[id] = true end
				self:progress()
			end, 0)
		end
		index += Preload.Batch
		-- Never more than one batch ahead of the queue: the deck tiles (priority 1) and the
		-- garden's own loads keep the engine slots.
		local spent = 0
		repeat spent += self.wait(Preload.Gap) or Preload.Gap until pending <= 0 or spent > 6 or self.stopped
	end
	-- 3D preview folders: one engine call each, after the images.
	for _, name in ipairs(self.folders or Preload.Folders) do
		if self.stopped then break end
		local folder = if typeof(name) == "Instance" then name else ReplicatedStorage:FindFirstChild(name)
		if folder then pcall(self.preload, { folder }) end
		self.wait(Preload.Gap)
	end
	self.done = true
	self:report("StylePreloadDoneAt", os.clock())
end
-- QA readout (live progress, readable from outside this module): attributes on `reportTo`
-- (the shared preload uses the PlayerGui). Specs pass no target.
function Preload:report(name, value) if self.reportTo then pcall(self.reportTo.SetAttribute, self.reportTo, name, value) end end
function Preload:progress()
	local n = 0
	for _ in pairs(self.ready) do n += 1 end
	self:report("StylePreloadReady", n); self:report("StylePreloadTotal", #self.images)
end

-- Just in time (Deck style opens): every style image not warm yet goes to the queue at the
-- tiles' priority. Safe before start() (it only asks the shared queue).
function Preload:warmNow()
	for _, uri in ipairs(self.images) do
		local id = canonical(uri)
		if not self.ready[id] and not self.boosted[id] then
			self.boosted[id] = true
			self.warm:request({ id }, function(ok)
				self.boosted[id] = nil
				if ok then self.ready[id] = true else self.failed[id] = true end
				self:progress()
			end, 1)
		end
	end
end
function Preload.boost()
	local shared = Preload.shared or Preload.start()
	if shared then shared:warmNow() end
end
-- Started once from the client entry (no top-level local there).
function Preload.start()
	if Preload.shared then return Preload.shared end
	local player = Players.LocalPlayer
	if not player then return nil end
	Preload.shared = Preload.new()
	Preload.shared.reportTo = player:FindFirstChildOfClass("PlayerGui")
	Levels.changed():Connect(function() if Levels.switch() and not Preload.shared.stopped then Preload.shared:extend() end end)
	task.spawn(function() Preload.shared:run() end)
	return Preload.shared
end
return Preload
