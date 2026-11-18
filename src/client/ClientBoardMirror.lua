-- Client-run board B3 (artifacts/qa-2026-11-17-v887/B3-plan.md): on a lockstep round the owner's deck
-- draws the client's own round host (ClientRoundDriver), not the server's Parts or snapshot stream.
--   * One local, unparented source Part per host ball (`Mirror_<id>`, attributes Tier, EggId = the
--     real ball id, BoardSerial, PowerUp, ItemMark), moved every render step to the host position
--     interpolated between the last two fixed steps, and fed to the deck's own addView/removeView,
--     so the renderer, LCD, faces and themes run unchanged.
--   * The host's step events (merges, impacts, grants, drops) play through the deck's presentation
--     hooks in the frame that first draws them (a tap is drawn the frame it lands, a merge the frame
--     the balls touch).
--   * `value(name)` serves the round's published attributes from the host (provisional HUD values);
--     the deck reads them through clientUI.attr. The replicated folder is never written. When the
--     server's RoundOver arrives the server's values stand again (compared first: Studio counter).
-- B4: after a rollback (the driver swapped in the server-corrected host) drawn balls ease to the
-- corrected positions (`rollback`); replayed steps never play juice.
-- Presentation only: nothing here is sent to the server or decides an outcome. Flag off (no lockstep
-- round ever starts) the mirror owns nothing and every hook in init.client.lua falls through.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.BoardConfig)
local Items = require(Shared.RoundItems)
local Sim = require(Shared.BoardSim)
local L = require(Shared.BoardLockstep)

local Mirror = {}
Mirror.__index = Mirror
Mirror.LateLimit = 0.25 -- an event this old (hidden or throttled deck) keeps its state, skips the juice
Mirror.MaxQueue = 64
Mirror.ImpactCooldown = 0.12 -- per ball, as the server's BoardImpact batches
Mirror.RenderAction = "EggDropDeckMirror"
Mirror.MaxSamples = 96

local FIXED = Config.FixedStep
local PACE = Config.Pace
-- The round's published attributes the host decides (publishState / BoardItems.publish).
local PROVISIONAL = {
	Drops = true, NextTier = true, PreviewTier1 = true, PreviewTier2 = true,
	NextPowerUp = true, PreviewPowerUp1 = true, PreviewPowerUp2 = true,
	ItemBelt = true, ItemSeq = true, ItemArmed = true,
	Merges = true, Chain = true, PeakChain = true, MaxClears = true, Score = true,
	FieldPhase = true, FieldStage = true, FieldObjective = true, FieldReady = true,
	OverflowPressure = true, OverflowGraceLeft = true,
}
Mirror.Provisional = PROVISIONAL
local LOOKAHEAD = { NextTier = 0, PreviewTier1 = 1, PreviewTier2 = 2, NextPowerUp = 0, PreviewPowerUp1 = 1, PreviewPowerUp2 = 2 }
-- Compared with the server's values when its RoundOver arrives.
local SETTLE = { "Score", "Merges", "PeakChain", "MaxClears", "Drops", "FieldStage", "FieldPhase" }

local function push(list, value)
	if #list >= Mirror.MaxSamples then table.remove(list, 1) end
	table.insert(list, value)
end

local function newStats()
	return {
		frames = 0, syncSum = 0, syncMax = 0, adopted = 0, released = {}, merges = 0, lateMerges = 0,
		impacts = 0, grants = 0, drops = 0, tapToBallMs = {}, tapToBallFrames = {}, mergeDelayMs = {},
		mergeDelayFrames = {}, settle = { checked = 0, diffs = {}, notOver = 0 }, mergeChecked = 0,
		mergeDiffs = 0, mergeMissing = 0, viewRetries = 0,
		-- B4 rollback: corrections, the largest timeline offset, the largest per-frame ease, pops.
		corrections = 0, offsetMax = 0, corrMaxFrame = 0, easing = 0, popAdded = 0, popRemoved = 0, popFar = 0, replayedMerges = 0,
	}
end

-- o: board (the replicated folder), driver (ClientRoundDriver), and the deck's hooks:
--   add(source), remove(source), hasView(source) -> bool, hideServer() (removes every non-mirror
--   view), released() (re-adds the server Parts' views), merge(m, serial, late), impacts(batch, serial),
--   drop(count, serial), grant(kind, id, serial, late), changed(hud, score, belt, objective).
function Mirror.new(o)
	local self = setmetatable({
		o = o, board = o.board, driver = o.driver, state = nil, attached = false, settled = false,
		parts = {}, mine = setmetatable({}, { __mode = "k" }), live = {}, prevX = {}, prevY = {},
		queue = {}, mergeLog = {}, note = {}, grantsPlayed = 0, grantsSeen = 0,
		playedSerial = nil, playedMerges = {}, playedGrants = 0, objectiveCache = {}, beltCache = {}, frame = 0,
		lastDrops = 0, tap = nil, stats = newStats(), connections = {},
	}, Mirror)
	self.driver.attach({
		beforeStep = function(state) self:beforeStep(state) end,
		afterStep = function(state, events, impacts) self:afterStep(state, events, impacts) end,
		input = function(state, input, ok, result) self:input(state, input, ok, result) end,
		stop = function(state, reason) if state == self.state then self:release(reason or "Stop") end end,
		rollback = function(state, oldHost) self:rollback(state, oldHost) end,
		replayed = function(state, events) self:replayed(state, events) end,
		stats = function() return self:publicStats() end,
		resetStats = function() self:resetStats() end,
	})
	RunService:BindToRenderStep(Mirror.RenderAction, Enum.RenderPriority.First.Value + 1, function()
		local ok, problem = pcall(self.sync, self)
		if not ok then warn("[ClientBoardMirror] " .. tostring(problem)) end
	end)
	for _, name in ipairs({ "RoundOver", "FieldPhase" }) do
		table.insert(self.connections, self.board:GetAttributeChangedSignal(name):Connect(function()
			self:serverOver()
		end))
	end
	return self
end

function Mirror:destroy()
	pcall(function() RunService:UnbindFromRenderStep(Mirror.RenderAction) end)
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	self.driver.attach(nil)
	if self.state then self:release("Destroy") end
end

-- ── Ownership ─────────────────────────────────────────────────────────────

-- The mirror draws this round (its serial is the lockstep round's).
function Mirror:owns(serial)
	local state = self.state
	return state ~= nil and serial ~= nil and serial == state.resetId
end
function Mirror:isMine(source) return self.mine[source] == true end
-- A server Part (or any other source) of an owned round gets no view.
function Mirror:hides(source)
	local state = self.state
	if not state or self.mine[source] then return false end
	return source:GetAttribute("BoardSerial") == state.resetId
end
-- Provisional values are served until the server's round end.
function Mirror:serving()
	return not self.settled and self:owns(self.board:GetAttribute("ResetId"))
end
function Mirror:serves(name)
	return PROVISIONAL[name] == true and self:serving()
end

-- ── Provisional values ────────────────────────────────────────────────────

local function fieldReady(state)
	local host = state.host
	local board = host.board
	-- As the server's FieldReady: a menu pause is not part of it (canAim already blocks the tap).
	return host.phase == "Playing" and not host.over and board.drops < host.budget and Sim.canDrop(board)
end

function Mirror:objective()
	local raw = self.board:GetAttribute("FieldObjective")
	local host = self.state.host
	local cache = self.objectiveCache
	if cache.raw == raw and cache.stage == host.stage and cache.progress == host.progress and cache.read then return cache.value end
	cache.raw, cache.stage, cache.progress, cache.read = raw, host.stage, host.progress, true
	cache.value = raw
	if type(raw) ~= "string" or raw == "" then return raw end
	if cache.decodedRaw ~= raw then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		cache.decodedRaw, cache.decoded = raw, if ok and type(decoded) == "table" then decoded else nil
	end
	local decoded = cache.decoded
	if not decoded then return raw end
	-- FieldRun:public's step / progress / target / complete, from the host's stage and progress.
	local goal = host.goals[host.stage + 1]
	decoded.step = host.stage + 1
	decoded.progress = if goal then host.progress else 0
	decoded.target = if goal then goal.target else 0
	decoded.complete = goal == nil
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, decoded)
	cache.value = if ok then encoded else raw
	return cache.value
end

-- (value, true) for a name the host decides on an owned round, else (nil, false): read the folder.
function Mirror:value(name)
	if not PROVISIONAL[name] then return nil, false end
	local state = self.state
	if not state or self.settled or self.board:GetAttribute("ResetId") ~= state.resetId then return nil, false end
	local host = state.host
	local board = host.board
	local lookahead = LOOKAHEAD[name]
	if lookahead then
		-- A queue slot not revealed yet holds the placeholder (tier 1, no star): better than the
		-- server's value, which is for the server's own (older) drop count (code review).
		if name == "NextTier" or name == "PreviewTier1" or name == "PreviewTier2" then return Sim.nextTier(board, lookahead), true end
		return Sim.powerUpAt(board, lookahead), true
	elseif name == "Drops" then return board.drops, true
	elseif name == "Score" then return host.score, true
	elseif name == "Chain" then return host.chain, true
	elseif name == "Merges" then return host.merges, true
	elseif name == "PeakChain" then return host.peakChain, true
	elseif name == "MaxClears" then return host.clears, true
	elseif name == "FieldPhase" then return host.phase, true
	elseif name == "FieldStage" then return host.stage, true
	elseif name == "FieldObjective" then return self:objective(), true
	elseif name == "ItemSeq" then return host.itemSeq, true
	elseif name == "ItemArmed" then return board.armed or "", true
	elseif name == "ItemBelt" then
		local cache = self.beltCache
		if cache.seq ~= host.itemSeq or cache.count ~= #host.belt or cache.host ~= host then
			cache.seq, cache.count, cache.host = host.itemSeq, #host.belt, host
			cache.value = Items.encodeBelt(host.belt)
		end
		return cache.value, true
	elseif name == "FieldReady" then
		-- Before the server's hello ack the deck cannot drop yet; the server's value stands.
		if not state.hello then return nil, false end
		return fieldReady(state), true
	elseif name == "OverflowPressure" then
		return if host.over then 0 else host.danger, true
	elseif name == "OverflowGraceLeft" then
		if host.over or host.overflowTicks <= 0 then return 0, true end
		return math.max(0, (host.graceTicks - host.overflowTicks) * FIXED) / PACE, true
	end
	return nil, false
end

-- ── Driver hooks (Heartbeat) ──────────────────────────────────────────────

function Mirror:beforeStep(state)
	if state ~= self.state then return end
	local prevX, prevY = self.prevX, self.prevY
	for _, egg in ipairs(state.host.board.eggs) do
		prevX[egg.id], prevY[egg.id] = egg.x, egg.y
	end
end

local function enqueue(self, event)
	local queue = self.queue
	if #queue >= Mirror.MaxQueue then table.remove(queue, 1) end
	table.insert(queue, event)
end

local function pairKey(firstId, secondId) return tostring(firstId) .. ":" .. tostring(secondId) end

function Mirror:afterStep(state, events, impacts)
	if state ~= self.state then return end
	local now = os.clock()
	for _, merge in ipairs(events.merges) do
		enqueue(self, { kind = "merge", m = merge, at = now, frame = self.frame })
		for _, grant in ipairs(merge.grants or {}) do
			enqueue(self, { kind = "grant", grant = grant.kind, id = grant.id, at = now, frame = self.frame })
			self.grantsPlayed += 1
		end
		self.mergeLog[pairKey(merge.firstId, merge.secondId)] = merge
	end
	-- The strongest impact per ball this frame (kept on its record; the server batches per Heartbeat).
	for id, impact in pairs(impacts) do
		local record = self.parts[id]
		if record and impact.speed > (record.impactSpeed or 0) then
			record.impactSpeed, record.nx, record.ny = impact.speed, impact.nx, impact.ny
		end
	end
end

function Mirror:input(state, input, ok, result)
	if state ~= self.state and self.state ~= nil then return end
	if input.kind == "drop" and ok and type(result) == "table" then
		self.tap = { id = result.id, at = os.clock(), frame = self.frame }
	end
end

-- ── B4: rollback ──────────────────────────────────────────────────────────

-- The driver swapped a corrected host in (same tick as the old one). Every ball both hosts have
-- keeps drawing where the old host had it: a visual offset (old - new) that sync eases away, at most
-- L.MaxCorrection studs a frame. A ball the new host does not have (or with another tier: a
-- different merge) is redrawn at once, as is one corrected farther than L.PopDistance (counted pops).
function Mirror:rollback(state, oldHost)
	if state ~= self.state then return end
	local stats = self.stats
	stats.corrections += 1
	local board = state.host.board
	local now, before = {}, {}
	for _, egg in ipairs(board.eggs) do now[egg.id] = egg end
	for _, egg in ipairs(oldHost and oldHost.board.eggs or {}) do before[egg.id] = egg end
	local prevX, prevY = self.prevX, self.prevY
	table.clear(prevX)
	table.clear(prevY)
	for id, egg in pairs(now) do prevX[id], prevY[id] = egg.x, egg.y end
	for id, record in pairs(self.parts) do
		local egg = now[id]
		if not egg or egg.tier ~= record.tier then
			self.o.remove(record.part)
			record.part:Destroy()
			self.parts[id] = nil
			stats.popRemoved += 1
		else
			local old = before[id]
			local ox = (if old then old.x else record.x) - egg.x + (record.ox or 0)
			local oy = (if old then old.y else record.y) - egg.y + (record.oy or 0)
			local distance = math.sqrt(ox * ox + oy * oy)
			if distance > stats.offsetMax then stats.offsetMax = distance end
			if distance > L.PopDistance then
				ox, oy = 0, 0
				stats.popFar += 1
			end
			if distance > 0 then record.ox, record.oy = ox, oy else record.ox, record.oy = nil, nil end
		end
	end
	for id in pairs(now) do
		if not before[id] then stats.popAdded += 1 end
	end
end

-- A replay step's merges (never played: their juice belongs to the past) for the Studio merge log.
function Mirror:replayed(state, events)
	if state ~= self.state then return end
	for _, merge in ipairs(events.merges) do
		self.mergeLog[pairKey(merge.firstId, merge.secondId)] = merge
		self.stats.replayedMerges += 1
	end
end

-- ── Server events (init.client.lua) ───────────────────────────────────────

-- The server's BoardMerge for an owned round: compared with the local merge (Studio counter).
function Mirror:serverMerge(tier, chain, id, cleared, firstId, secondId)
	local key = pairKey(firstId, secondId)
	local mine = self.mergeLog[key]
	self.stats.mergeChecked += 1
	if not mine then self.stats.mergeMissing += 1; return end
	self.mergeLog[key] = nil
	if mine.tier ~= tier or mine.chain ~= chain or mine.id ~= id or mine.cleared ~= cleared then
		self.stats.mergeDiffs += 1
	end
end

-- The server's grant / full ItemEvent for `serial`: true when the mirror already showed it (an
-- owned round, or a released one whose local grants the server has not caught up with).
function Mirror:grantPlayed(serial)
	if self:owns(serial) then
		self.grantsSeen += 1
		return true
	end
	if serial ~= nil and serial == self.playedSerial and self.playedGrants > 0 then
		self.playedGrants -= 1
		return true
	end
	return false
end

-- A released round (takeover): the server's late merges the mirror already played are skipped.
function Mirror:alreadyPlayed(serial, firstId, secondId)
	if serial == nil or serial ~= self.playedSerial then return false end
	local key = pairKey(firstId, secondId)
	if self.playedMerges[key] then
		self.playedMerges[key] = nil
		return true
	end
	return false
end

-- The server's round end: its values stand from here (results and rewards are the server's); the
-- drawn board stays the mirror's until the reset. One publishState can reach the client over more
-- than one replication batch (Studio: RoundOver arrived before FieldPhase), so the switch waits for
-- the server's Complete phase too, and the comparison runs once the batch has surely landed.
function Mirror:serverOver()
	local board = self.board
	if board:GetAttribute("RoundOver") ~= true or board:GetAttribute("FieldPhase") ~= "Complete" or self.settled then return end
	local state = self.state
	local serial = board:GetAttribute("ResetId")
	if not state or not self:owns(serial) then return end
	local mine = {}
	for _, name in ipairs(SETTLE) do mine[name] = self:value(name) end
	local over = state.host.over
	self.settled = true
	self.o.changed(true, true, true, true)
	task.delay(0.5, function()
		if self.state ~= state or board:GetAttribute("ResetId") ~= serial then return end
		local settle = self.stats.settle
		settle.checked += 1
		if not over then settle.notOver += 1 end
		for _, name in ipairs(SETTLE) do
			local server = board:GetAttribute(name)
			if server ~= mine[name] then
				settle.diffs[name] = (settle.diffs[name] or 0) + 1
				settle.last = name .. ": server " .. tostring(server) .. " / mirror " .. tostring(mine[name])
			end
		end
	end)
end

-- ── Adopt / release ───────────────────────────────────────────────────────

function Mirror:adopt(state)
	self.state, self.attached, self.settled = state, false, false
	-- A round starts empty: a drop made before the first render step still gets its cue.
	self.lastDrops = 0
	table.clear(self.note)
	table.clear(self.objectiveCache)
	table.clear(self.queue)
	table.clear(self.mergeLog)
	self.grantsPlayed, self.grantsSeen = 0, 0
	self.stats.adopted += 1
end

function Mirror:release(reason)
	local state = self.state
	if not state then return end
	self.state, self.attached, self.settled = nil, false, false
	self.stats.released[reason] = (self.stats.released[reason] or 0) + 1
	-- Every mirror view leaves before a server view comes back (viewsById is keyed by ball id).
	for id, record in pairs(self.parts) do
		self.o.remove(record.part)
		record.part:Destroy()
		self.parts[id] = nil
	end
	table.clear(self.prevX)
	table.clear(self.prevY)
	table.clear(self.queue)
	-- What was played locally and not yet seen from the server stays skipped (code review: after a
	-- takeover the server, behind the client, replays those merges and grants).
	self.playedSerial, self.playedMerges = state.resetId, self.mergeLog
	self.playedGrants = math.max(0, (self.grantsPlayed or 0) - (self.grantsSeen or 0))
	self.mergeLog = {}
	self.tap = nil
	self.o.released()
	self.o.changed(true, true, true, true)
end

-- The deck rebuilt its views (ResetId): the next sync hides server views and re-adds the mirror's.
function Mirror:reattach()
	self.attached = false
end

-- ── Render step ───────────────────────────────────────────────────────────

local function makePart(self, egg, state)
	local part = Instance.new("Part")
	part.Name = "Mirror_" .. egg.id
	part.Shape = Enum.PartType.Ball
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Size = Vector3.one * egg.radius * 2
	part.Color = Config.Tiers[egg.tier].color
	part.Position = Vector3.new(egg.x, egg.y, 0)
	part:SetAttribute("Tier", egg.tier)
	part:SetAttribute("EggId", egg.id)
	part:SetAttribute("BoardSerial", state.resetId)
	local record = { part = part, x = egg.x, y = egg.y, star = false, mark = nil, tier = egg.tier }
	self.parts[egg.id] = record
	self.mine[part] = true
	return record
end

function Mirror:sync()
	local started = os.clock()
	local current = self.driver.round()
	if current ~= self.state then
		if self.state then self:release("Replaced") end
		if current then self:adopt(current) end
	end
	local state = self.state
	if not state then return end
	local serial = self.board:GetAttribute("ResetId")
	if serial ~= state.resetId then return end -- the deck's serial has not reached this round yet
	local o = self.o
	if not self.attached then
		self.attached = true
		o.hideServer()
	end
	local host = state.host
	local board = host.board
	local alpha = self.driver.alpha()
	local live, prevX, prevY = self.live, self.prevX, self.prevY
	table.clear(live)
	local tap = self.tap
	for _, egg in ipairs(board.eggs) do
		local id = egg.id
		live[id] = true
		local record = self.parts[id] or makePart(self, egg, state)
		local px, py = prevX[id] or egg.x, prevY[id] or egg.y
		local x, y = px + (egg.x - px) * alpha, py + (egg.y - py) * alpha
		-- B4: a rollback's offset, eased away (at most L.MaxCorrection studs this frame).
		local ox, oy = record.ox, record.oy
		if ox then
			local distance = math.sqrt(ox * ox + oy * oy)
			local step = math.min(L.MaxCorrection, math.max(distance * 0.35, 0.02))
			local stats = self.stats
			if distance <= step then
				record.ox, record.oy = nil, nil
			else
				local keep = (distance - step) / distance
				record.ox, record.oy = ox * keep, oy * keep
				x += record.ox
				y += record.oy
				stats.easing += 1
			end
			local applied = math.min(step, distance)
			if applied > stats.corrMaxFrame then stats.corrMaxFrame = applied end
		end
		local part = record.part
		if record.x ~= x or record.y ~= y then
			record.x, record.y = x, y
			part.Position = Vector3.new(x, y, 0)
		end
		-- syncVisuals' marks: a star ball; an armed Bomb, or a Magnet still pulling.
		local star = egg.powerUp ~= nil
		if record.star ~= star then record.star = star; part:SetAttribute("PowerUp", star) end
		local mark = if egg.mark == "magnet" and egg.hasContact and egg.magnetTicks <= 0 then nil else egg.mark
		if record.mark ~= mark then record.mark = mark; part:SetAttribute("ItemMark", mark) end
		if not o.hasView(part) then
			o.add(part)
			if o.hasView(part) then
				if tap and tap.id == id then
					push(self.stats.tapToBallMs, (os.clock() - tap.at) * 1000)
					push(self.stats.tapToBallFrames, self.frame - tap.frame)
					self.tap, tap = nil, nil
				end
			else
				self.stats.viewRetries += 1
			end
		end
	end
	for id, record in pairs(self.parts) do
		if not live[id] then
			o.remove(record.part)
			record.part:Destroy()
			self.parts[id] = nil
			prevX[id], prevY[id] = nil, nil
		end
	end
	-- A drop: its sound, jolt and hint, the frame its ball is drawn.
	if board.drops ~= self.lastDrops then
		if board.drops > self.lastDrops then
			self.stats.drops += 1
			o.drop(board.drops, serial)
		end
		self.lastDrops = board.drops
	end
	-- Step events, oldest first.
	local now = os.clock()
	local queue = self.queue
	if #queue > 0 then
		self.queue = {}
		for _, event in ipairs(queue) do
			local late = now - event.at > Mirror.LateLimit
			if event.kind == "merge" then
				self.stats.merges += 1
				if late then self.stats.lateMerges += 1 end
				push(self.stats.mergeDelayMs, (now - event.at) * 1000)
				push(self.stats.mergeDelayFrames, self.frame - event.frame)
				o.merge(event.m, serial, late)
			elseif event.kind == "grant" then
				self.stats.grants += 1
				o.grant(event.grant, event.id, serial, late)
			end
		end
	end
	-- Impacts: the strongest per ball since the last frame, 0.12 s apart per ball.
	local batch = nil
	for id, record in pairs(self.parts) do
		local speed = record.impactSpeed
		if speed then
			record.impactSpeed = nil
			if now - (record.lastImpact or -math.huge) >= Mirror.ImpactCooldown and o.hasView(record.part) then
				record.lastImpact = now
				batch = batch or {}
				table.insert(batch, { id, Vector2.new(record.nx, record.ny), speed })
			end
		end
	end
	if batch then
		self.stats.impacts += #batch
		o.impacts(batch, serial)
	end
	-- Readers keyed on attribute signals (HUD, items, the quest layout) hear the host's changes.
	if not self.settled then
		local note = self.note
		local ready = state.hello and fieldReady(state)
		local hud = note.drops ~= board.drops or note.phase ~= host.phase or note.ready ~= ready
			or note.armed ~= board.armed or note.revealed ~= state.revealed or note.over ~= host.over
			or note.paused ~= host.paused or note.hello ~= state.hello
		local score = note.score ~= host.score or note.chain ~= host.chain or note.merges ~= host.merges
		local belt = note.belt ~= #host.belt or note.seq ~= host.itemSeq
		local objective = note.stage ~= host.stage or note.progress ~= host.progress
		if hud or score or belt or objective then
			note.drops, note.phase, note.ready, note.armed, note.revealed = board.drops, host.phase, ready, board.armed, state.revealed
			note.over, note.paused, note.hello = host.over, host.paused, state.hello
			note.score, note.chain, note.merges, note.belt, note.seq = host.score, host.chain, host.merges, #host.belt, host.itemSeq
			note.stage, note.progress = host.stage, host.progress
			o.changed(hud or belt, score, belt, objective)
		end
	end
	self.frame += 1
	local stats = self.stats
	local cost = os.clock() - started
	stats.frames += 1
	stats.syncSum += cost
	if cost > stats.syncMax then stats.syncMax = cost end
end

-- ── Studio stats (through the driver's EggDropClientSim bindable) ────────

local function summary(list)
	if #list == 0 then return nil end
	local sorted = table.clone(list)
	table.sort(sorted)
	local sum = 0
	for _, value in ipairs(sorted) do sum += value end
	return { n = #sorted, median = sorted[math.ceil(#sorted / 2)], max = sorted[#sorted], mean = sum / #sorted }
end

function Mirror:publicStats()
	local s = self.stats
	return {
		owning = self.state ~= nil, attached = self.attached, settled = self.settled, parts = (function()
			local n = 0
			for _ in pairs(self.parts) do n += 1 end
			return n
		end)(),
		frames = s.frames, syncMeanUs = if s.frames > 0 then s.syncSum / s.frames * 1e6 else 0, syncMaxUs = s.syncMax * 1e6,
		adopted = s.adopted, released = table.clone(s.released), merges = s.merges, lateMerges = s.lateMerges,
		impacts = s.impacts, grants = s.grants, drops = s.drops, viewRetries = s.viewRetries,
		tapToBallMs = summary(s.tapToBallMs), tapToBallFrames = summary(s.tapToBallFrames),
		mergeDelayMs = summary(s.mergeDelayMs), mergeDelayFrames = summary(s.mergeDelayFrames),
		settle = { checked = s.settle.checked, notOver = s.settle.notOver, diffs = table.clone(s.settle.diffs), last = s.settle.last },
		mergeChecked = s.mergeChecked, mergeDiffs = s.mergeDiffs, mergeMissing = s.mergeMissing,
		corrections = s.corrections, offsetMax = s.offsetMax, corrMaxFrame = s.corrMaxFrame, easing = s.easing,
		popAdded = s.popAdded, popRemoved = s.popRemoved, popFar = s.popFar, replayedMerges = s.replayedMerges,
	}
end

function Mirror:resetStats() self.stats = newStats() end

return Mirror
