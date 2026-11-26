-- Deck net audit (artifacts/qa-2026-11-26-beta35/DECK-NET-AUDIT.md): artificial latency for the Pocket
-- Deck's remotes, so a bad connection can be felt in Studio and measured offline. Pure: no services.
--
-- Studio only: the owner's chat "/netsim <rtt ms> [jitter ms] [loss %]" (or "/netsim off") sets the board
-- folder attribute DeckNetSim = "rtt,jitter,loss". The client driver then holds every BoardClientSim
-- message it sends for one round trip and the server holds the player's BoardRequest actions (reset,
-- mode, today's-path drops) for one round trip. Every server message on a lockstep round answers a
-- client message, so a delay on the way up times every answer like a real round trip.
--
-- A link is reliable and ordered, as RemoteEvents are: each item leaves `share` x (rtt +/- jitter)
-- after it was pushed, never before the item ahead of it (head-of-line). A lost packet (probability
-- loss) is resent after a further round trip plus 100 ms, and holds everything behind it, as a
-- reliable resend does.
local NetSim = {}
NetSim.Attribute = "DeckNetSim"
NetSim.MaxRtt = 3000 -- ms
NetSim.MaxJitter = 1000 -- ms
NetSim.MaxLoss = 50 -- percent
NetSim.ResendExtra = 0.1 -- s, on top of a round trip, for a lost packet

local function clampNumber(value, maximum)
	local n = tonumber(value)
	if n == nil or n ~= n then return nil end
	return math.clamp(math.floor(n + 0.5), 0, maximum)
end

-- {rtt, jitter, loss} (ms, ms, percent) from the attribute text, or nil (off).
function NetSim.parse(text)
	if type(text) ~= "string" then return nil end
	local a, b, c = string.match(text, "^%s*([%d%.]+)%s*,?%s*([%d%.]*)%s*,?%s*([%d%.]*)%s*$")
	local rtt = clampNumber(a, NetSim.MaxRtt)
	if not rtt then return nil end
	local jitter = if b ~= "" then clampNumber(b, NetSim.MaxJitter) else 0
	local loss = if c ~= "" then clampNumber(c, NetSim.MaxLoss) else 0
	if jitter == nil or loss == nil then return nil end
	if rtt == 0 and jitter == 0 and loss == 0 then return nil end
	return { rtt = rtt, jitter = jitter, loss = loss }
end

function NetSim.format(config)
	if not config then return nil end
	return string.format("%d,%d,%d", config.rtt, config.jitter or 0, config.loss or 0)
end

-- A chat line: the attribute text to set, false for "off", nil when it is not a /netsim command
-- (or a malformed one).
function NetSim.command(message)
	if type(message) ~= "string" then return nil end
	local rest = string.match(string.lower(message), "^%s*/netsim%s*(.-)%s*$")
	if rest == nil then return nil end
	if rest == "off" or rest == "0" or rest == "" then return false end
	local a, b, c = string.match(rest, "^(%d+)%s*(%d*)%s*(%d*)$")
	if not a then return nil end
	local config = NetSim.parse(a .. "," .. b .. "," .. c)
	return if config then NetSim.format(config) else false
end

-- A one-way reliable ordered link. config: {rtt, jitter, loss} (ms) or nil (no delay); share: the part of
-- the round trip this link carries (1 = all of it, 0.5 = one way); seed: the loss / jitter dice.
function NetSim.link(config, share, seed)
	local random = Random.new(seed or 1)
	local link = { config = config, share = share or 1, queue = {}, head = 1, tail = 0, last = -math.huge, lastPushAt = nil,
		pushed = 0, lost = 0, delivered = 0, maxDelay = 0 }
	function link:delay()
		local c = self.config
		if not c then return 0 end
		local rtt = c.rtt / 1000
		local jitter = (c.jitter or 0) / 1000
		local d = self.share * math.max(0, rtt + jitter * (random:NextNumber() * 2 - 1))
		if (c.loss or 0) > 0 and random:NextNumber() * 100 < c.loss then
			self.lost += 1
			d += rtt + NetSim.ResendExtra
		end
		return d
	end
	-- Queues `item` at `now`; returns its release time. Items pushed at the same `now` (one frame's
	-- messages) travel together, as one packet does.
	function link:push(now, item)
		self.pushed += 1
		local at = if now == self.lastPushAt then self.last else math.max(now + self:delay(), self.last)
		self.last, self.lastPushAt = at, now
		self.tail += 1
		self.queue[self.tail] = { at = at, item = item, sent = now }
		return at
	end
	-- Every item due at `now`, oldest first (removed from the link).
	function link:due(now)
		local out = nil
		while self.head <= self.tail and self.queue[self.head].at <= now do
			local entry = self.queue[self.head]
			self.queue[self.head] = nil
			self.head += 1
			self.delivered += 1
			local delay = now - entry.sent
			if delay > self.maxDelay then self.maxDelay = delay end
			out = out or {}
			table.insert(out, entry.item)
		end
		if self.head > self.tail then self.head, self.tail = 1, 0 end
		return out
	end
	function link:size() return self.tail - self.head + 1 end
	-- Everything still held, oldest first (a link switched off hands its queue over at once).
	function link:flush()
		local out = {}
		for index = self.head, self.tail do table.insert(out, self.queue[index].item) end
		table.clear(self.queue)
		self.head, self.tail = 1, 0
		return out
	end
	return link
end

return table.freeze(NetSim)
