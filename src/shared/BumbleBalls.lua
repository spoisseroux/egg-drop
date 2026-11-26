-- Bumble balls (GARDEN-PLAY-BRIEF section 1, Fable 2026-11-26; Spencer: "some animal crossing like balls that everyone
-- and the pets can interact with ... handle server client interaction well and bad connections"). Shared and pure:
-- the three balls, their homes and leash, the kick numbers, the server's checks and the client's blend maths.
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
Balls.List=table.freeze({
	table.freeze({id="felt",home=Vector2.new(-30,27)}),
	table.freeze({id="wicker",home=Vector2.new(42,-11)}), -- brief (42, -6) was 6.6 from the Dash line
	table.freeze({id="cork",home=Vector2.new(58,30)}),
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
-- Pure: the launch velocity along the walker's heading (a plan vector; nil when it has none).
function Balls.launch(heading,jumping)
	if not Balls.finite(heading)then return nil end
	local h=flat(heading)
	if h.Magnitude<1e-3 then return nil end
	local along,up=if jumping then Balls.JumpFlat else Balls.KickFlat,if jumping then Balls.JumpUp else Balls.KickUp
	return h.Unit*along+Vector3.new(0,up,0)
end

-- Server checks --------------------------------------------------------------------------------------------------
-- Pure: a velocity inside the jump kick's envelope (in plan up to JumpFlat, up 0..JumpUp, both with SpeedSlack), or nil
-- when it is not a finite Vector3. A velocity already inside is returned as the same value.
function Balls.clamp(velocity,scale)
	if not Balls.finite(velocity)then return nil end
	scale=scale or 1
	local maxFlat,maxUp=Balls.JumpFlat*Balls.SpeedSlack*scale,Balls.JumpUp*Balls.SpeedSlack*scale
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
-- Pure: the squash `elapsed` after a hit of `strength` (0..1): vertical squash fraction.
function Balls.squash(strength,elapsed)
	if elapsed<0 or elapsed>=Balls.SquashTime then return 0 end
	return Balls.Squash*math.clamp(strength,0,1)*(1-ease(elapsed/Balls.SquashTime))
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
