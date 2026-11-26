-- Bumble balls (GARDEN-PLAY-BRIEF section 1, Fable 2026-11-26; Spencer: "some animal crossing like balls that everyone
-- and the pets can interact with ... handle server client interaction well and bad connections"). Shared and pure:
-- the five balls, their homes, feel and leash, the kick numbers, the server's checks and the client's blend maths.
-- BallMotion holds the sim. Every number is a [PLACEHOLDER] to tune in Studio.
--
-- Switch: the Alive feature `balls` (FeatureFlags.AliveBalls, the beta place or Studio, ConfigService `alive_balls`,
-- missing = on; owner chat `/alive balls on|off|clear`). Off: the server ignores kicks and the clients build nothing.
--
-- Networking (the brief's model): a ball is an anchored client part drawn from a kick record
-- {id, n, origin, velocity, startTime} on workspace:GetServerTimeNow(). The kicker draws its own predicted record at
-- once and sends one reliable remote; the server checks reach, rate and speed, stamps startTime and n, steps the sim once
-- for the rest spot and broadcasts. Nothing is streamed, nothing is simulated by Roblox physics.
local Balls={}

Balls.Radius=1.2          -- diameter 2.4 (knee to waist)
Balls.Leash=22            -- studs from home; the sim reflects off it
-- Homes: off Routes.ArrivalToHub, the parks and the Dash (Felt south of the Toy Lawn, Wicker on the fountain lawn
-- outside the BubbleSpring wet box, Cork by the arrival path). Raycast-check in Studio. [PLACEHOLDER]
-- GARDEN-PLAY-BRIEF-2 section 1 (beta 35, Spencer: "Can the balls be like animal crossing soccer balls ... i like them
-- tho"): two livelier rubber balls with our own round panels, never a pentagon sports ball. Stripe at the brief's (-60, 6);
-- Patch 20 west of the brief's (20, -22), which is in the stream (BumbleBalls.spec: the sim's boxes and GardenClearance).
Balls.List=table.freeze({
	table.freeze({id="felt",home=Vector2.new(-30,27),feel="steady"}),
	table.freeze({id="wicker",home=Vector2.new(42,-11),feel="steady"}), -- brief (42, -6) was 6.6 from the Dash line
	table.freeze({id="cork",home=Vector2.new(58,30),feel="steady"}),
	table.freeze({id="patch",home=Vector2.new(0,-24),feel="lively"}), -- brief (20, -22) is in Water_Stream; the nearest open lawn
	table.freeze({id="stripe",home=Vector2.new(-60,6),feel="lively"}),
})
local byId={}
for _,ball in ipairs(Balls.List)do byId[ball.id]=ball end
Balls.ById=table.freeze(byId)

-- The kick (the client sees it; the server only clamps).
Balls.KickReach=1.9       -- the root within this of the ball's surface, in plan
Balls.KickHeight=4        -- and within this of its centre in height
Balls.KickSpeed=4         -- the walker moving faster than this (studs/s, in plan)
Balls.KickFacing=.2       -- and heading at the ball (cosine)
Balls.KickFlat,Balls.KickUp=26,9
Balls.JumpFlat,Balls.JumpUp=32,13   -- a running jump kicks harder
Balls.KickGap=.3          -- the same client kicks the same ball at most this often
-- Each ball's feel: its kick and running jump (flat + up), the bounces' restitution, its squash and roll. Steady is the
-- first three (the numbers above); lively is Patch and Stripe (brief 2: kick 30 + 11, jump 36 + 15, .70 / .55 / .40,
-- squash 18%, rest in about 3.2 s: a little less roll drag, so it runs on after the bounces; worst 3.15 s from home).
Balls.Feels=table.freeze({
	steady=table.freeze({kickFlat=26,kickUp=9,jumpFlat=32,jumpUp=13,restitution=table.freeze({.55,.42,.30}),squash=.12,rollDrag=1.2,rollFriction=3}),
	lively=table.freeze({kickFlat=30,kickUp=11,jumpFlat=36,jumpUp=15,restitution=table.freeze({.70,.55,.40}),squash=.18,rollDrag=.95,rollFriction=2.4}),
})
-- Pure: a ball's feel (steady for an unknown id).
function Balls.feel(id)
	local ball=byId[id]
	return Balls.Feels[ball and ball.feel or "steady"]or Balls.Feels.steady
end
-- The fastest launch any ball takes (the sim's clamp for a ball is its own feel's; this bounds them all).
Balls.MaxJumpFlat,Balls.MaxJumpUp=36,15

-- The server's checks.
Balls.Reach=6             -- the root at the server within this of the ball (plan distance)
Balls.ReachHeight=8       -- and within this in height
Balls.RateCount,Balls.RateWindow=4,1   -- kicks per player per window (seconds)
Balls.ClientWindow=1.25   -- the client holds itself to a longer window, so packet jitter never meets the server's
Balls.SpeedSlack=1.05     -- the clamp allows this much over the jump kick
Balls.OriginSlack=4.5     -- a claimed origin within this of the server's ball (now or Lag ago) is used as sent
Balls.Lag=.3
Balls.BallGap=.1          -- at most one accepted kick per ball this often
Balls.BuntScale=.4        -- a pet's nose-bunt is a kick at 40%

-- Rolling home.
Balls.HomeSlack=4         -- a ball resting further than this from home is "away"
Balls.AbandonRadius=30    -- nobody's root within this
Balls.AbandonAfter=20     -- for this long: it rolls home
Balls.HomeSpeed=3

-- The client's blend.
Balls.Blend=.15           -- someone else's kick: from where the ball is drawn
Balls.Correct=.2          -- a refused or contested kick of mine
Balls.Fade=.25            -- over FadeGap: shrink, move, grow
Balls.FadeGap=12
Balls.Keep=.05            -- under this the records agree
Balls.Squash=.12          -- per bounce, at full strength
Balls.SquashTime=.14
Balls.CullPhone,Balls.CullDesktop=90,150

local function finite(n)return type(n)=="number"and n==n and n~=math.huge and n~=-math.huge end
function Balls.finite(v)return typeof(v)=="Vector3"and finite(v.X)and finite(v.Y)and finite(v.Z)end
local function flat(v)return Vector3.new(v.X,0,v.Z)end
Balls.flat=flat
function Balls.planDistance(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end

-- Switch ---------------------------------------------------------------------------------------------------------
function Balls.ceiling()return require(script.Parent.Alive).ceiling("balls")end
function Balls.on()return require(script.Parent.Alive).on("balls")end

-- Kick (client) --------------------------------------------------------------------------------------------------
-- Pure: does a root at `root` moving at `velocity` kick a ball drawn at `ball`?
function Balls.kicks(root,velocity,ball)
	if not(Balls.finite(root)and Balls.finite(velocity)and Balls.finite(ball))then return false end
	local move=flat(velocity)
	if move.Magnitude<=Balls.KickSpeed then return false end
	if math.abs(root.Y-ball.Y)>Balls.KickHeight then return false end
	local to=flat(ball-root)
	local gap=to.Magnitude
	if gap-Balls.Radius>Balls.KickReach then return false end
	if gap<1e-3 then return true end
	return move.Unit:Dot(to.Unit)>Balls.KickFacing
end
-- Pure: the launch velocity along the walker's heading (a plan vector; nil when it has none), in ball `id`'s feel
-- (steady when nil).
function Balls.launch(heading,jumping,id)
	if not Balls.finite(heading)then return nil end
	local h=flat(heading)
	if h.Magnitude<1e-3 then return nil end
	local feel=Balls.feel(id)
	local along,up=if jumping then feel.jumpFlat else feel.kickFlat,if jumping then feel.jumpUp else feel.kickUp
	return h.Unit*along+Vector3.new(0,up,0)
end

-- Server checks --------------------------------------------------------------------------------------------------
-- Pure: a velocity inside ball `id`'s jump kick envelope (its feel: in plan up to jumpFlat, up 0..jumpUp, both with
-- SpeedSlack; steady when nil), or nil when it is not a finite Vector3. A velocity already inside is returned as is.
function Balls.clamp(velocity,scale,id)
	if not Balls.finite(velocity)then return nil end
	scale=scale or 1
	local feel=Balls.feel(id)
	local maxFlat,maxUp=feel.jumpFlat*Balls.SpeedSlack*scale,feel.jumpUp*Balls.SpeedSlack*scale
	local h=flat(velocity)
	local up=velocity.Y
	if h.Magnitude<=maxFlat and up>=0 and up<=maxUp then return velocity end
	if h.Magnitude>maxFlat then h=h.Unit*maxFlat end
	return h+Vector3.new(0,math.clamp(up,0,maxUp),0)
end
-- Pure: is the root close enough to the ball?
function Balls.inReach(root,ball)
	if not(Balls.finite(root)and Balls.finite(ball))then return false end
	return Balls.planDistance(root,ball)<=Balls.Reach and math.abs(root.Y-ball.Y)<=Balls.ReachHeight
end
-- Pure: a sliding-window limiter. `history` is the player's accepted kick times; true (and the time recorded) when
-- fewer than RateCount fall inside the last `window` (default RateWindow; the client uses ClientWindow).
function Balls.allow(history,now,window)
	window=window or Balls.RateWindow
	local kept=0
	for i=#history,1,-1 do
		if now-history[i]>=window then table.remove(history,i)else kept+=1 end
	end
	if kept>=Balls.RateCount then return false end
	table.insert(history,now)
	return true
end
-- Pure: the origin the server uses. The client's own when it is within OriginSlack of where the server has the ball now
-- (or Lag ago: a moving ball the packet chased), else the server's (a contested kick: the kicker blends to it).
function Balls.origin(claimed,serverNow,serverBefore)
	if not Balls.finite(claimed)then return serverNow,false end
	local gap=(claimed-serverNow).Magnitude
	if serverBefore then gap=math.min(gap,(claimed-serverBefore).Magnitude)end
	if gap<=Balls.OriginSlack then return claimed,true end
	return serverNow,false
end

-- Blend (client) -------------------------------------------------------------------------------------------------
local function ease(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end
Balls.ease=ease
-- Pure: how a new record meets the ball where it is drawn: "keep" (they agree), "blend" (an offset that decays) or
-- "fade" (over FadeGap: shrink, move, grow).
function Balls.blendMode(gap)
	if gap<=Balls.Keep then return "keep"end
	if gap>Balls.FadeGap then return "fade"end
	return "blend"
end
-- Pure: the drawn offset `elapsed` into a blend of `duration` that started at `offset` (decays to zero, smoothly).
function Balls.offset(offset,elapsed,duration)
	if duration<=0 or elapsed>=duration then return Vector3.zero end
	return offset*(1-ease(elapsed/duration))
end
-- Pure: the fade: the scale (1 -> 0 over the first half, 0 -> 1 over the second) and whether the ball is drawn at the
-- new record yet.
function Balls.fade(elapsed,duration)
	if duration<=0 or elapsed>=duration then return 1,true end
	local u=elapsed/duration
	if u<.5 then return 1-ease(u*2),false end
	return ease((u-.5)*2),true
end
-- Pure: the squash `elapsed` after a hit of `strength` (0..1): vertical squash fraction (ball `id`'s feel).
function Balls.squash(strength,elapsed,id)
	if elapsed<0 or elapsed>=Balls.SquashTime then return 0 end
	local most=if id then Balls.feel(id).squash else Balls.Squash
	return most*math.clamp(strength,0,1)*(1-ease(elapsed/Balls.SquashTime))
end

-- Wire ------------------------------------------------------------------------------------------------------------
-- A record as it goes over the remote (Vector3s replicate exactly, so every observer plans the same arc).
function Balls.pack(record,rest)
	return{id=record.id,n=record.n,origin=record.origin,velocity=record.velocity,startTime=record.startTime,
		kind=record.kind,target=record.target,fade=record.fade,bunt=record.bunt,by=record.by,seq=record.seq,rest=rest}
end
-- Pure: a record from the wire, or nil when it is malformed.
function Balls.unpack(packet)
	if type(packet)~="table"or not byId[packet.id]then return nil end
	if type(packet.n)~="number"or not finite(packet.startTime)then return nil end
	if not Balls.finite(packet.origin)or not Balls.finite(packet.velocity)then return nil end
	if packet.kind=="home"and not Balls.finite(packet.target)then return nil end
	return{id=packet.id,n=packet.n,origin=packet.origin,velocity=packet.velocity,startTime=packet.startTime,
		kind=if packet.kind=="home"then "home"else nil,target=if packet.kind=="home"then packet.target else nil,
		fade=packet.fade==true,bunt=packet.bunt==true,by=packet.by,seq=packet.seq,
		rest=if Balls.finite(packet.rest)then packet.rest else nil}
end

return table.freeze(Balls)
