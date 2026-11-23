-- The Sleepy Nest (ONBOARDING-V3-PLAN-2026-11-23 section 2 and the architect review): constants, the welcome-week
-- gift table, the `public.nest` snapshot shape, and pure clock helpers. Shared and pure: no service, no save access.
-- The switch is Onboard.on("nest"); with it off there is no snapshot key and no write (NestState / NestHost own those).
--
-- Saved entry (hatching save `nest`, never in valid(), never sanitised at load: it fails closed, FindsState pattern):
--   {at=<unix s the egg landed>, n=<eggs hatched, 0 and up>, gift=<stored gift id string or a Stars number>,
--    op=<claim proof>, receipt=<last claim>, tucked=<bool>, pet=<pet id stored at land>}
-- A bad `n` reads as WeekLength (week done: after-week eggs only); a bad `at`, or one more than FutureSlack ahead,
-- gets a fresh land write that keeps `n`. The clock is server time only. No skip of any kind, ever.
local Nest={}

Nest.Hours=8                    -- an egg is ready this long after it lands
Nest.Seconds=Nest.Hours*3600
Nest.WeekLength=7               -- welcome week: the first seven eggs, counted by eggs hatched, never by days
Nest.AfterWeekStars=4           -- every egg after the seventh: Stars only (the 2x pass never applies)
Nest.OwnedCap=20                -- a hat or neck piece the pet already owns (or its rig has none) pays its price, at most this
Nest.ToyOwnedStars=20           -- the toy egg when every toy is owned
Nest.FutureSlack=86400          -- an `at` further ahead than this is malformed
Nest.ReadyPing=14               -- studs: the one soft ping when a ready egg comes this near
Nest.Charm="nest"               -- the Nest Charm: an earned rule (n >= WeekLength), no saved data
-- Where the nest stands (beta 12 QA O2, GARDEN-LIFE-NEST-LOOK 4, spot A): the plaza's east rim, root -Z facing the
-- plaza's middle. Y is the walk map's ground (the client raycasts it). Shared: NestClient draws the nest here and the
-- server keeps pets off it (LoungeWorldV7Art: one GardenBlockedRegion box, Block wide, behind Onboard.ceiling).
-- Fallback B, if Studio shows A blocked: (-22.5, 4.07, 5.5), same facing.
Nest.Spot=Vector3.new(-17.5,4.07,-2.5)
Nest.Facing=Vector3.new(-30,4.07,-4)
Nest.Block=5.5                  -- studs: the square pets walk round

-- The welcome-week gifts, egg 1 to 7, fixed and shown from the moment the egg lands (never rolled). `stars` is
-- always paid with the egg. Item kinds pick at land time and store the pick in `gift`:
--   hat / neck  the cheapest common piece with no level gate FOR THE PET STORED AT LAND (`perPet`): hats and neck
--               pieces are per pet, so check that pet's rig has one; when it has none, or the pet owns it, the
--               gift is Stars instead: min(price, OwnedCap) (no rig item at all: OwnedCap)
--   toy         the next unowned toy in ToyCatalog.PaidOrder (fixed order); all owned: ToyOwnedStars instead
--   charm       the Nest Charm (Nest.Charm), welcome week only
-- Stars face value 100; with the hat (about 40), neck piece (about 40) and toy (20) the week is worth about 200 Stars.
Nest.Gifts=table.freeze({
	table.freeze({kind="hat",stars=10,perPet=true}),
	table.freeze({kind="stars",stars=15}),
	table.freeze({kind="toy",stars=5}),
	table.freeze({kind="stars",stars=15}),
	table.freeze({kind="neck",stars=10,perPet=true}),
	table.freeze({kind="stars",stars=20}),
	table.freeze({kind="charm",stars=25,item=Nest.Charm}),
})
Nest.AfterWeek=table.freeze({kind="stars",stars=Nest.AfterWeekStars})

-- The `public.nest` snapshot shape (NestState builds it; only while Onboard.on("nest")). Shape doc only:
--   at       number   unix seconds the egg landed (server clock)
--   readyAt  number   at + Seconds
--   left     number   seconds until ready at snapshot time, Nest.left (0 = ready); clients count down from readyAt
--   ready    boolean  Nest.ready at snapshot time
--   n        integer  eggs hatched so far (0 = the first egg is growing)
--   egg      integer  this egg's number, n + 1 ("Egg {count} of 7" while egg <= WeekLength)
--   week     boolean  n >= WeekLength (welcome week done)
--   gift     table    {kind = "hat"|"neck"|"toy"|"charm"|"stars", item = <catalog id or nil>, stars = <total Stars>}
--                     (an owned or missing item already shows as kind "stars" with its swapped Stars added)
--   tucked   boolean  Tuck in pressed for this egg
--   pet      string   the pet id stored at land (hat and neck gifts are for this pet)
-- Missing key = no nest (switch off, or no egg landed yet).
Nest.PublicShape=table.freeze({at="number",readyAt="number",left="number",ready="boolean",n="integer",egg="integer",
	week="boolean",gift="table",tucked="boolean",pet="string"})

local function finite(value)
	return type(value)=="number"and value==value and value~=math.huge and value~=-math.huge
end
-- Eggs hatched as a count: an integer 0 and up, anything else reads as WeekLength (fails closed: no week gifts).
function Nest.count(n)
	if finite(n)and n%1==0 and n>=0 then return n end
	return Nest.WeekLength
end
-- The gift row for the next egg after `n` hatched (egg n + 1).
function Nest.gift(n)
	n=Nest.count(n)
	return Nest.Gifts[n+1]or Nest.AfterWeek
end
function Nest.weekDone(n)return Nest.count(n)>=Nest.WeekLength end
-- The Nest Charm is earned once the seventh egg has hatched.
function Nest.charm(n)return Nest.weekDone(n)end
-- Is an entry's `at` usable at `now`? A finite number no more than FutureSlack ahead.
function Nest.sane(entry,now)
	if type(entry)~="table"or not finite(entry.at)or not finite(now)then return false end
	return entry.at<=now+Nest.FutureSlack
end
-- Seconds grown: min(elapsed, Seconds), clamped at 0 (a slightly future `at` is "just landed"). nil = no egg.
function Nest.grown(entry,now)
	if not Nest.sane(entry,now)then return nil end
	return math.clamp(now-entry.at,0,Nest.Seconds)
end
-- Ready to hatch at `now`? A missing or malformed entry is never ready.
function Nest.ready(entry,now)
	local grown=Nest.grown(entry,now)
	return grown~=nil and grown>=Nest.Seconds
end
-- Seconds until ready (0 when ready); nil when there is no usable egg.
function Nest.left(entry,now)
	local grown=Nest.grown(entry,now)
	if grown==nil then return nil end
	return Nest.Seconds-grown
end
-- Growth 0..1 and the look it shows: "small" (to 1/3), "glow" (to 2/3), "rocking" (to ready), "ready". nil = no egg.
function Nest.progress(entry,now)
	local grown=Nest.grown(entry,now)
	return if grown==nil then nil else grown/Nest.Seconds
end
function Nest.look(entry,now)
	local p=Nest.progress(entry,now)
	if p==nil then return nil end
	if p>=1 then return "ready"end
	if p<1/3 then return "small"end
	if p<2/3 then return "glow"end
	return "rocking"
end
-- The chip and label clock for `left` seconds: ("hours", h) above one hour, then ("minutes", m), then ("ready").
-- Rounded up, so it never reads 0 before the egg is ready (UICopy onb3.nest.hours / minutes / ready).
function Nest.countdown(left)
	if not finite(left)or left<=0 then return "ready",nil end
	if left>3600 then return "hours",math.ceil(left/3600)end
	return "minutes",math.max(1,math.ceil(left/60))
end
return table.freeze(Nest)
