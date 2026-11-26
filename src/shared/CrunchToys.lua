-- Crunchy toys round the garden (GARDEN-PLAY-BRIEF 2026-11-26 section 2, Fable): two dry leaf heaps, a row of six pop
-- pods, a crackle slab (GARDEN-PLAY-BRIEF-2 section 3: amber sugar-glass tiles that crack underfoot, in place of the
-- pebble tray's gravel) and three rattle gourds on a twig arch. Nice to stomp; sound first. Brief 2 section 2 (Spencer:
-- "more exaggerated movement from the asmr toys"): every toy anticipates .05 s, overshoots and settles in two wobbles. Pure data and maths here
-- (CrunchToysClient builds and drives them): no instances, no remotes. Each client watches the characters and pets it
-- already has and reacts on its own, so two players see their own crunches; nothing replicates and nothing is saved.
-- Gate: the Alive `crunch` switch (AliveCrunch, the beta place or Studio, ConfigService `alive_crunch`); off, nothing
-- is built. Every number is a [PLACEHOLDER]; the spots were chosen off the v7 surface map (grass under every footprint)
-- and are checked against GardenClearance by scripts/CrunchToys.spec.lua. Raycast them in Studio.
local Toys={}
Toys.Feature="crunch"
Toys.Budget=175                   -- parts in all (brief 2: the slab's 63 in place of the tray's 11)
Toys.Cull=table.freeze({phone=90,desktop=150})
Toys.Rate=1/30                    -- the loop's step while something is near
Toys.Sleep=.5                     -- how often a sleeping loop looks again
Toys.Reach=5                      -- a root more than this over a toy's base is above it (a jump over, not through)
Toys.OtherRange=30                -- other players' crunches are heard only this close to me
Toys.Gains=table.freeze({own=1,ownPet=.5,other=.4,otherPet=.2,world=.6}) -- world: a pod's re-inflating creak
Toys.Pitch=.06                    -- every layer's pitch varies this much either way
Toys.PetReactGap=3                -- one startle per pet this often at most
Toys.Buzz=table.freeze({heap="creak",pop="crack1",crack="crack1",shatter="crack2"}) -- Haptics patterns, the local player only
Toys.Anticipate=.05               -- brief 2: every toy gathers itself this long before it moves

-- The pieces ------------------------------------------------------------------------------------------------------
Toys.Heap=table.freeze({width=5,height=1.2,colours=table.freeze({"#C98A3C","#A8552E","#E0B24F"}),
	-- {dx, dz, width x, height, width z, colour}: three mounds make one heap (the first is the big one)
	mounds=table.freeze({table.freeze({0,0,5,1.2,4.6,1}),table.freeze({.8,-.5,3.4,1.0,3.0,2}),table.freeze({-.9,.7,3.0,.85,2.6,3})}),
	leaves=8,leafSize=Vector3.new(.78,.05,.5),
	-- Brief 2: 24 cards from one pool fly 3.5 up and 4 out, spinning 2 turns, down in 2.2 s; lie .4 s, fade .4 s.
	burst=24,burstTime=2.2,lie=.4,fade=.4,cardUp=3.5,cardOut=4,cardTurns=2,cardGravity=26,cardFall=3.4,
	-- Brief 2: a .05 s gather (lift 4%), flat to 12% in .08 s, springs to 45% (.16 s) and sags to 34% (.6 s, two
	-- wobbles); heaps back over 12 s, ending in a puff 10% past full (.8 s). The mounds shudder 8 degrees twice (.5 s).
	lift=.04,flat=.12,squash=.08,spring=.45,springTime=.16,sag=.34,sagTime=.6,reheap=12,puff=.10,puffTime=.8,
	shudder=8,shudderTime=.5,
	reach=2.4,radius=2.6})
-- Pods (FABLE-REVIEW-B35 Fix 2: six identical olive balls said nothing): a bigger body in three greens along the row,
-- a puckered nub on top and three sepals at the base that stay put when the pod flattens, so the squash reads against
-- them. Each pod has its own yaw and a height scale of .9 to 1.1 from its index: a litter, not a rank.
Toys.Pod=table.freeze({count=6,across=1.1,tall=.9,colours=table.freeze({"#9DBF6A","#B5CC6E","#8DB37A"}),
	dome="#E9DCA6",domeAcross=.34,domeTall=.2,
	sepals=3,sepal=Vector3.new(.6,.05,.32),sepalColour="#4F7F3A",sepalTilt=20,sepalPast=.25,
	heightLow=.9,heightHigh=1.1,
	-- Brief 2: a .05 s gather (6% taller), flat to 12% and 1.45 wide; after 6 s it re-inflates over 1.1 s, 25% past full
	-- and back in two wobbles. The nub pings 2.5 up, tumbling, and lands on the flat pod; the neighbours lean away 12
	-- degrees (peak at .2 s, settled by .7 s).
	gather=.06,flat=.12,spread=1.45,pop=.06,reinflate=6,inflate=1.1,overshoot=.25,reach=1.0,radius=.85,
	nubUp=2.5,nubGravity=36,nubTurns=2,nubDrift=.35,nubHop=.25,nubHopTime=.22,lean=12,leanTime=.7,
	bend=6,spacing=1.7})                 -- the row: six along an arc of radius 6, 1.7 apart
-- The crackle slab (brief 2 section 3, Spencer: "the gravel thing should crack like those cracky things asmr trend"): the
-- tray's timber frame round a dark Slate bed under ten amber sugar-glass tiles (5 x 2). Each tile is three shards flush
-- when whole and two hidden crack lines on its joints. Each tile is turned 3 to 8 degrees (alternate ways), sized to fit
-- its cell, so the joints run skew and it is not a grid. States: 0 whole; 1 hairline (lines show, dips .03); 2 shattered
-- (shards tilt 8 to 15 degrees, drop .08, part .06; chips hop). A step adds 1 to its tile and .08 s later a line runs into
-- one or two whole neighbours; a jump landing shatters its tile and cracks every neighbour; steps on shattered tiles only
-- throw chips. Untouched 8 s, each tile heals a state every 4 s (shards ease flat over 1.2 s, lines fade, a warm gloss).
Toys.Slab=table.freeze({size=Vector2.new(6,4),board=Vector2.new(.32,.3),frame="#6B4A2E",bed="#4A4640",bedThick=.1,
	cols=5,rows=2,tile=Vector3.new(1.05,.14,1.6),yawLow=3,yawHigh=8,grout=.97,
	glass="#E8B45A",transparency=.25,gloss="#FFD98A",line="#FFF3D6",lineWidth=.03,lineThick=.012,
	shardLow=.28,shardHigh=.38,dip=.03,drop=.08,gap=.06,tiltLow=8,tiltHigh=15,
	crackTime=.3,shatterTime=.45,healTime=1.2,lineDelay=.08,
	chips=8,chipsShatter=3,chipsStep=2,chip=Vector3.new(.2,.06,.16),chipHop=.7,chipSkitter=.7,chipTime=.55,chipLie=.5,chipFade=.3,
	stride=1.2,landDrop=1.0,fallStep=.2,idle=8,healEvery=4,radius=3.6})
Toys.Tray=Toys.Slab -- the same frame and footprint the pebble tray had
-- Gourds (FABLE-REVIEW-B35 Fix 3: read as a small brown hurdle beside a pillar): a wider arch on foot stones with
-- accent cord wraps on the bar's ends, and three bigger gourds that are not alike.
Toys.Gourd=table.freeze({count=3,cord="#8A6A3C",bark="#6B4A2E",bar=2.35,span=4.6,post=.3,gap=1.35,
	cordLength=.32,neck=Vector3.new(.44,.6,.44),
	-- {across, tall, colour} per gourd
	bodies=table.freeze({table.freeze({1.0,.92,"#D8B56A"}),table.freeze({.88,.8,"#C98F4A"}),table.freeze({1.08,1.0,"#E6CC8E"})}),
	stone=Vector3.new(1.0,.28,.8),stoneColour="#9C968A",stoneYaws=table.freeze({15,-25}),
	wrap=Vector2.new(.25,.3),wrapColour="#E8785A", -- Cylinder .25 long, .3 across (the lantern accent)
	-- Brief 2: a .05 s pull back (6 degrees), a 55 degree swing settling over 3.5 s; each knocks the next in a chain
	-- (.6 of its push, .12 s later); each twists 20 degrees; the bar dips .15 and flexes 6 degrees toward the bump.
	pull=6,swing=55,decay=.85,period=1.1,settle=3.5,neighbour=.6,chain=.12,twist=20,twistPeriod=1.4,
	dip=.15,flex=6,barTime=.9,reach=1.0,radius=2.9})

-- Where (XZ; the client seats them on the ground). Moved from the brief's spots onto clear grass:
--   heaps  (-22, 38) -> (-26, 37) under the trees west of lamp 7; (-12, -44) -> (-13, -40) north of lamp 4
--   pods   (20, 34) -> (15, 38.5) (the brief's spot is half on the stream's path)
--   tray   (44, 12) -> (42, 12) beside the fountain lawn, clear of the west rest dais (brief 2: the crackle slab, same spot)
--   gourds (78, 56) -> (76, 63.5): the brief's spot is on the arrival path; the arch runs along it, 6 studs off;
--          Fable B35: 3 more along the arch's normal away from the path (and the pillar's plinth) -> (77.22, 66.24)
Toys.Places=table.freeze({
	heaps=table.freeze({table.freeze({id="leaf_heap_1",x=-26,z=37,yaw=.4}),table.freeze({id="leaf_heap_2",x=-13,z=-40,yaw=-.9})}),
	pods=table.freeze({id="pop_pods",x=15,z=38.5,yaw=.35}),
	tray=table.freeze({id="crackle_slab",x=42,z=12,yaw=.15}),
	gourds=table.freeze({id="rattle_gourds",x=77.22,z=66.24,yaw=math.atan2(-16,-36)}), -- the bar along the arrival path
})

-- Parts, counted as the client builds them (the spec holds it to Toys.Budget).
function Toys.partCount()
	local H,P,S,G=Toys.Heap,Toys.Pod,Toys.Slab,Toys.Gourd
	local heaps=#Toys.Places.heaps*(#H.mounds+H.leaves)+H.burst -- one burst pool, shared by both heaps
	local pods=P.count*(2+P.sepals)                             -- body, nub and three sepals
	local tray=4+1+S.cols*S.rows*(3+2)+S.chips                  -- four boards, the bed, 3 shards + 2 lines a tile, the chips
	local gourds=3+2+2+G.count*3                                -- posts, bar, foot stones, cord wraps; cord, neck, body each
	return heaps+pods+tray+gourds+1                             -- and the one invisible part the sounds hang from
end

-- Pure geometry ---------------------------------------------------------------------------------------------------
-- Pod i's own yaw (radians) and height scale (.9 to 1.1), fixed by its index.
function Toys.podLook(i)
	local P=Toys.Pod
	return Toys.hash(7,i,1)*math.pi*2,P.heightLow+(P.heightHigh-P.heightLow)*Toys.hash(7,i,2)
end
local function turn(yaw,x,z)
	local c,s=math.cos(yaw),math.sin(yaw)
	return x*c+z*s,-x*s+z*c -- CFrame.Angles(0, yaw, 0) applied to (x, 0, z)
end
Toys.turn=turn
-- The pods' XZ, in order along the arc.
function Toys.podSpots()
	local P,at=Toys.Pod,Toys.Places.pods
	local out={}
	local step=2*math.asin(P.spacing/(2*P.bend))
	for i=1,P.count do
		local a=(i-(P.count+1)/2)*step
		local lx,lz=P.bend*math.sin(a),P.bend*(1-math.cos(a))-P.bend*(1-math.cos(step*(P.count-1)/2))/2
		local dx,dz=turn(at.yaw,lx,lz)
		table.insert(out,Vector2.new(at.x+dx,at.z+dz))
	end
	return out
end
-- The gourds' hanging points on the bar (local X along the bar), XZ.
function Toys.gourdSpots()
	local G,at=Toys.Gourd,Toys.Places.gourds
	local out={}
	for i=1,G.count do
		local dx,dz=turn(at.yaw,(i-(G.count+1)/2)*G.gap,0)
		table.insert(out,Vector2.new(at.x+dx,at.z+dz))
	end
	return out
end
-- Every footprint the spec checks: {id, x, z, r}.
function Toys.footprints()
	local out={}
	for _,h in ipairs(Toys.Places.heaps)do table.insert(out,{id=h.id,x=h.x,z=h.z,r=Toys.Heap.radius})end
	for i,p in ipairs(Toys.podSpots())do table.insert(out,{id="pop_pod_"..i,x=p.X,z=p.Y,r=Toys.Pod.radius})end
	local pods=Toys.Places.pods
	table.insert(out,{id=pods.id,x=pods.x,z=pods.z,r=Toys.Pod.spacing*(Toys.Pod.count-1)/2+Toys.Pod.radius})
	local tray=Toys.Places.tray
	table.insert(out,{id=tray.id,x=tray.x,z=tray.z,r=Toys.Tray.radius})
	local g=Toys.Places.gourds
	table.insert(out,{id=g.id,x=g.x,z=g.z,r=Toys.Gourd.radius})
	return out
end

-- Pure contact ----------------------------------------------------------------------------------------------------
-- Does the step from a to b (XZ) pass within r of c?
function Toys.crossed(ax,az,bx,bz,cx,cz,r)
	local dx,dz=bx-ax,bz-az
	local length=dx*dx+dz*dz
	local t=if length<1e-9 then 1 else math.clamp(((cx-ax)*dx+(cz-az)*dz)/length,0,1)
	local ex,ez=cx-(ax+t*dx),cz-(az+t*dz)
	return ex*ex+ez*ez<=r*r
end
-- Inside the tray's gravel (a point in the tray's own frame)?
function Toys.inTray(lx,lz)
	local T=Toys.Tray
	return math.abs(lx)<=T.size.X/2-T.board.X and math.abs(lz)<=T.size.Y/2-T.board.X
end
-- How loud a crunch is for whoever made it (`kind` own / ownPet / other / otherPet), `distance` from me.
function Toys.gain(kind,distance)
	local g=Toys.Gains[kind]
	if not g then return 0 end
	if(kind=="other"or kind=="otherPet")and not(type(distance)=="number"and distance<=Toys.OtherRange)then return 0 end
	return g
end
local function ease(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
Toys.ease=ease
-- Pure: 0 at u = 0, up to 1 at `rise` (eased), then back to 0 in two wobbles (two full swings, dying away) by u = 1.
function Toys.wobble(u,rise)
	rise=rise or .3
	if u<=0 or u>=1 then return 0 end
	if u<rise then return ease(u/rise)end
	local k=(u-rise)/(1-rise)
	return math.cos(k*math.pi*4)*(1-k)^2
end
-- Pure: 0 -> 1 over u in 0..1, overshooting to 1 + `over` at `rise`, then settling in two wobbles.
function Toys.spring(u,over,rise)
	rise=rise or .3
	if u<=0 then return 0 end
	if u>=1 then return 1 end
	if u<rise then return ease(u/rise)*(1+over)end
	return 1+over*Toys.wobble(u,rise)
end

-- A heap: state {hitAt, before} (nil hitAt: full). Its height now, 0..1 of the full mound (up to 1 + puff in the puff).
function Toys.heapLevel(state,now)
	local H=Toys.Heap
	if not state or not state.hitAt then return 1 end
	local t=now-state.hitAt
	local b=state.before or 1
	local a=Toys.Anticipate
	local top=b*(1+H.lift)
	if t<a then return b+(top-b)*ease(t/a)end
	t-=a
	if t<H.squash then return top+(H.flat-top)*ease(t/H.squash)end
	t-=H.squash
	if t<H.springTime then return H.flat+(H.spring-H.flat)*ease(t/H.springTime)end
	t-=H.springTime
	if t<H.sagTime then return H.spring+(H.sag-H.spring)*Toys.spring(t/H.sagTime,.25)end
	t-=H.sagTime
	local climb=H.reheap-H.puffTime
	if t<climb then return H.sag+(1-H.sag)*ease(t/climb)end
	t-=climb
	if t<H.puffTime then return 1+H.puff*Toys.wobble(t/H.puffTime,.35)end
	return 1
end
-- How long a hit takes to settle back to full; when its rebound (the spring up, the asmr_flake) comes.
function Toys.heapTime()
	local H=Toys.Heap
	return Toys.Anticipate+H.squash+H.springTime+H.sagTime+H.reheap
end
function Toys.heapRebound()return Toys.Anticipate+Toys.Heap.squash end
-- The mounds' shudder (radians) `now`: 8 degrees, twice, from the moment it squashes.
function Toys.heapShudder(state,now)
	local H=Toys.Heap
	if not state or not state.hitAt then return 0 end
	local u=(now-state.hitAt-Toys.Anticipate)/H.shudderTime
	if u<=0 or u>=1 then return 0 end
	return math.rad(H.shudder)*math.sin(u*math.pi*4)*(1-u*.5)
end
-- A walk or jump through: the heap flattens; returns the cards to burst and the crunch's gain (a flat heap is a
-- smaller crunch and a smaller burst).
function Toys.heapHit(state,now)
	local H=Toys.Heap
	local before=math.min(1,Toys.heapLevel(state,now))
	local fresh=math.clamp((before-H.flat)/(1-H.flat),0,1)
	state.hitAt,state.before=now,before
	return math.clamp(math.floor(H.burst*fresh+.5),2,H.burst),.45+.55*fresh
end
local function hash(seed,i,k)
	local x=math.sin(seed*12.9898+i*78.233+k*37.719)*43758.5453
	return x-math.floor(x)
end
Toys.hash=hash
-- One burst card t seconds in: offset from the heap's centre (studs, the ground at y 0), its turn (x, y, z radians) and
-- how seen it is (1 seen, 0 gone). The same seed and card always fly the same way. Brief 2: each rises 2.6 to 3.5 over
-- where it started, goes 2.8 to 4 out, turns 2 times about the up axis on the way (one way or the other) and tumbles,
-- then flutters down, on the ground by Heap.burstTime.
local function cardShape(seed,i)
	local H=Toys.Heap
	local r0=.3+hash(seed,i,2)*1.2
	local y0=H.height*.85*math.sqrt(math.max(0,1-(r0/(H.width/2))^2))
	local rise=H.cardUp*(.75+.25*hash(seed,i,4))
	local g=H.cardGravity
	local up=math.sqrt(2*g*rise)
	local fall=H.cardFall*(.85+.3*hash(seed,i,5))
	local t1=(up+fall)/g
	local y1=y0+up*t1-.5*g*t1*t1
	local land=t1+math.max(0,y1-.04)/fall
	return r0,y0,up,fall,t1,y1,land
end
function Toys.cardLand(seed,i)return(select(7,cardShape(seed,i)))end
function Toys.card(seed,i,t)
	local H=Toys.Heap
	local a=hash(seed,i,1)*math.pi*2
	local r0,y0,up,fall,t1,y1,land=cardShape(seed,i)
	local g=H.cardGravity
	local out=r0+H.cardOut*(.7+.3*hash(seed,i,3))*(1-math.exp(-t/.5))
	local y
	if t<t1 then y=y0+up*t-.5*g*t*t
	else y=y1-fall*(t-t1)end
	y=math.max(.04,y)
	local landed=t>=land
	local flutter=if t>t1 and not landed then .35*math.sin(math.pi*2*1.6*t+hash(seed,i,6)*6)else 0
	local x,z=math.cos(a)*out-math.sin(a)*flutter,math.sin(a)*out+math.cos(a)*flutter
	local rx=if landed then 0 else math.sin(t*7+i)*1.1
	local rz=if landed then 0 else math.cos(t*5.3+i*2)*.9
	local way=if hash(seed,i,7)<.5 then -1 else 1
	local spin=way*H.cardTurns*math.pi*2*ease(math.min(t,land)/land)
	local seen=1-math.clamp((t-H.burstTime-H.lie)/H.fade,0,1)
	return Vector3.new(x,y,z),rx,a+spin,rz,seen
end
function Toys.cardLife()return Toys.Heap.burstTime+Toys.Heap.lie+Toys.Heap.fade end

-- A pod popped at `poppedAt` (nil: ready). Its height and width scales now, and its phase (ready / flat / inflating).
function Toys.podScale(poppedAt,now)
	local P=Toys.Pod
	if not poppedAt then return 1,1,"ready"end
	local t=now-poppedAt
	local a=Toys.Anticipate
	if t<a then local k=ease(t/a);return 1+P.gather*k,1-P.gather*.5*k,"flat"end
	local hy,hw=1+P.gather,1-P.gather*.5
	if t<a+P.pop then local k=ease((t-a)/P.pop);return hy+(P.flat-hy)*k,hw+(P.spread-hw)*k,"flat"end
	if t<P.reinflate then return P.flat,P.spread,"flat"end
	local u=(t-P.reinflate)/P.inflate
	if u>=1 then return 1,1,"ready"end
	local sy=P.flat+(1-P.flat)*Toys.spring(u,P.overshoot/(1-P.flat))
	local sxz=P.spread+(1-P.spread)*ease(u/.3)
	if sy>1 then sxz-=(sy-1)*.4 end -- thinner as it stands taller
	return sy,sxz,"inflating"
end
-- The nub's flight from a pop: studs over its seat on the pod's top, its tumble (radians), its drift out (studs), and
-- whether it has landed (once, for the asmr_pop). It leaves at the pop, pings 2.5 up, lands on the flat pod and hops
-- once more; it rides the pod back up as it re-inflates.
function Toys.podNubFlight()
	local P=Toys.Pod
	return 2*math.sqrt(2*P.nubUp/P.nubGravity)
end
function Toys.podNub(poppedAt,now)
	local P=Toys.Pod
	if not poppedAt then return 0,0,0,false end
	local t=now-poppedAt-Toys.Anticipate
	if t<=0 then return 0,0,0,false end
	local flight=Toys.podNubFlight()
	if t<flight then
		local v=math.sqrt(2*P.nubGravity*P.nubUp)
		local u=t/flight
		return v*t-.5*P.nubGravity*t*t,P.nubTurns*math.pi*2*u,P.nubDrift*math.sin(math.pi*u),false
	end
	t-=flight
	if t<P.nubHopTime then
		local k=t/P.nubHopTime
		return P.nubHop*4*k*(1-k),math.rad(40)*math.sin(math.pi*k),0,true -- whole turns in the air: upright again
	end
	return 0,0,0,true
end
-- A neighbour's lean away from a pop (radians), `now`: up to 12 degrees by .2 s, back in two wobbles by .7 s.
function Toys.podLean(at,now)
	local P=Toys.Pod
	if not at then return 0 end
	return math.rad(P.lean)*Toys.wobble((now-at)/P.leanTime,.3)
end

-- A gourd bumped at `at` with `push` (-1..1 of the full swing). Its swing (radians about the bar) now; 0 once settled.
-- Brief 2: it pulls back 6 degrees for .05 s, swings 55 and settles over 3.5 s.
function Toys.gourdAngle(at,push,now)
	local G=Toys.Gourd
	if not at then return 0 end
	local t=now-at
	if t<0 or t>=G.settle then return 0 end
	local a=Toys.Anticipate
	if t<a then return-math.rad(G.pull)*push*ease(t/a)end
	t-=a
	local back=math.rad(G.pull)*push*(1-ease(t/.08))
	return math.rad(G.swing)*push*math.exp(-t/G.decay)*math.sin(math.pi*2*t/G.period)-back
end
-- Its twist about its cord (radians): 20 degrees, dying with the swing.
function Toys.gourdTwist(at,push,now)
	local G=Toys.Gourd
	if not at then return 0 end
	local t=now-at-Toys.Anticipate
	if t<=0 or t>=G.settle then return 0 end
	return math.rad(G.twist)*push*math.exp(-t/G.decay)*math.sin(math.pi*2*t/G.twistPeriod)
end
-- The bar after a bump at `at` by gourd `side` (-1 at one end, 0 the middle, 1 the other): how far it dips (studs) and
-- its flex (radians about the across axis; the bumped end goes down).
function Toys.barBend(at,side,now)
	local G=Toys.Gourd
	if not at then return 0,0 end
	local u=(now-at-Toys.Anticipate)/G.barTime
	if u<=0 or u>=1 then return 0,0 end
	local w=Toys.wobble(u,.2)
	return G.dip*w,-math.rad(G.flex)*(side or 0)*w
end

-- The crackle slab -----------------------------------------------------------------------------------------------
-- Pure: the ten tiles in the slab's own frame (y 0 the ground): {i, col, row, x, z, yaw, size, shards = {{z, length}},
-- lines = {z}}. Each tile turned 3 to 8 degrees, alternate ways, and shrunk to fit its cell.
local slabTiles=nil
function Toys.slabTiles()
	if slabTiles then return slabTiles end
	local S=Toys.Slab
	local inner=Vector2.new(S.size.X-S.board.X*2,S.size.Y-S.board.X*2)
	local cell=Vector2.new(inner.X/S.cols,inner.Y/S.rows)
	local out={}
	for row=1,S.rows do
		for col=1,S.cols do
			local i=(row-1)*S.cols+col
			local way=if(row+col)%2==0 then 1 else -1
			local yaw=math.rad(S.yawLow+(S.yawHigh-S.yawLow)*hash(31,i,1))*way
			local w,h=S.tile.X,S.tile.Z
			local c,sn=math.abs(math.cos(yaw)),math.abs(math.sin(yaw))
			local k=math.min(1,cell.X/(w*c+h*sn),cell.Y/(w*sn+h*c))*S.grout
			local size=Vector3.new(w*k,S.tile.Y,h*k)
			local f1=S.shardLow+(S.shardHigh-S.shardLow)*hash(31,i,2)
			local f3=S.shardLow+(S.shardHigh-S.shardLow)*hash(31,i,3)
			local lengths={size.Z*f1,size.Z*(1-f1-f3),size.Z*f3}
			local shards,lines,z={},{},-size.Z/2
			for n,length in ipairs(lengths)do
				table.insert(shards,table.freeze({z=z+length/2,length=length,
					tilt=math.rad(S.tiltLow+(S.tiltHigh-S.tiltLow)*hash(31,i,3+n))*(if n==1 then 1 elseif n==3 then -1 elseif hash(31,i,7)<.5 then 1 else -1),
					roll=math.rad(3+4*hash(31,i,8+n))*(if hash(31,i,11+n)<.5 then 1 else -1),
					out=if n==1 then -1 elseif n==3 then 1 else 0}))
				z+=length
				if n<3 then table.insert(lines,z)end
			end
			table.insert(out,table.freeze({i=i,col=col,row=row,x=-inner.X/2+cell.X*(col-.5),z=-inner.Y/2+cell.Y*(row-.5),
				yaw=yaw,size=size,shards=table.freeze(shards),lines=table.freeze(lines)}))
		end
	end
	slabTiles=table.freeze(out)
	return slabTiles
end
-- Pure: the tile under a point in the slab's frame (its cell), or nil off the tiles.
function Toys.slabTileAt(lx,lz)
	local S=Toys.Slab
	local inner=Vector2.new(S.size.X-S.board.X*2,S.size.Y-S.board.X*2)
	if math.abs(lx)>inner.X/2 or math.abs(lz)>inner.Y/2 then return nil end
	local col=math.clamp(math.floor((lx+inner.X/2)/(inner.X/S.cols))+1,1,S.cols)
	local row=math.clamp(math.floor((lz+inner.Y/2)/(inner.Y/S.rows))+1,1,S.rows)
	return(row-1)*S.cols+col
end
-- Pure: a tile's neighbours, sides only, or (`all`) the corners too.
function Toys.slabNeighbours(i,all)
	local S=Toys.Slab
	local col,row=(i-1)%S.cols+1,math.floor((i-1)/S.cols)+1
	local out={}
	for dr=-1,1 do
		for dc=-1,1 do
			if(dr~=0 or dc~=0)and(all or dr==0 or dc==0)then
				local c,r=col+dc,row+dr
				if c>=1 and c<=S.cols and r>=1 and r<=S.rows then table.insert(out,(r-1)*S.cols+c)end
			end
		end
	end
	return out
end
-- Pure: a footstep on tile i. levels {[i] = 0..2} is changed in place; answers what happened ("crack", "shatter" or
-- "chips") and the neighbours the line runs into .08 s later (one or two of the whole ones beside it; roll(lo, hi)).
function Toys.slabStep(levels,i,roll)
	local level=levels[i]or 0
	if level>=2 then return "chips",{}end
	levels[i]=level+1
	local whole={}
	for _,j in ipairs(Toys.slabNeighbours(i,false))do if(levels[j]or 0)==0 then table.insert(whole,j)end end
	local runs={}
	local want=if roll(0,1)<.5 then 1 else 2
	while #runs<want and #whole>0 do
		table.insert(runs,table.remove(whole,math.clamp(math.floor(roll(1,#whole+1)),1,#whole)))
	end
	return if level+1>=2 then "shatter"else "crack",runs
end
-- Pure: the line running into a neighbour: +1 only if it is still whole. Answers whether it cracked.
function Toys.slabRun(levels,j)
	if(levels[j]or 0)~=0 then return false end
	levels[j]=1
	return true
end
-- Pure: a jump landing on tile i: it shatters, every neighbour (corners too) at least hairline. Answers the tiles
-- that changed, {i, from, to}.
function Toys.slabLand(levels,i)
	local out={}
	local from=levels[i]or 0
	if from<2 then levels[i]=2;table.insert(out,{i=i,from=from,to=2})end
	for _,j in ipairs(Toys.slabNeighbours(i,true))do
		local was=levels[j]or 0
		if was<1 then levels[j]=1;table.insert(out,{i=j,from=was,to=1})end
	end
	return out
end
-- Pure: a tile's drawn pose for a crack amount c (0 whole, 1 hairline, 2 shattered; between while it moves): each
-- shard's offset in the tile's frame (CFrame, the tile's centre on the bed), and how seen the lines are (0..1).
function Toys.slabPose(tile,c,lines)
	local S=Toys.Slab
	local dip=S.dip*math.clamp(c,0,1)
	local broken=math.max(0,c-1) -- may overshoot past 1 in the spring
	local out={}
	for _,shard in ipairs(tile.shards)do
		-- The middle shard sinks a little further; the outer two part from it along the tile; each tips on its own
		-- centre (one edge up, one pressed into the bed), like a stamped sugar pane.
		local drop=dip+S.drop*broken*(if shard.out==0 then 1.3 else 1)
		table.insert(out,CFrame.new(0,-drop,shard.z+shard.out*S.gap*broken)*CFrame.Angles(shard.tilt*broken,0,shard.roll*broken))
	end
	return out,math.clamp(lines or c,0,1)
end
-- Pure: a chip's hop t seconds after it flew from a tile: offset (studs) along its own heading, its spin (radians) and
-- how seen it is. It hops .7 up, skitters .7 out with one small hop more, lies, then fades.
function Toys.chip(seed,k,t)
	local S=Toys.Slab
	if t<0 then return Vector3.zero,0,0 end
	local reach=S.chipSkitter*(.6+.4*hash(seed,k,1))
	local out=reach*(1-math.exp(-t*4.5))
	local y=0
	local first=S.chipTime*.65
	if t<first then local u=t/first;y=S.chipHop*(.7+.3*hash(seed,k,2))*4*u*(1-u)
	elseif t<S.chipTime then local u=(t-first)/(S.chipTime-first);y=.12*4*u*(1-u)end
	local spin=math.min(t,S.chipTime)/S.chipTime*math.pi*2*(1+hash(seed,k,3))
	local seen=1-math.clamp((t-S.chipTime-S.chipLie)/S.chipFade,0,1)
	return Vector3.new(0,y,-out),spin,seen
end
function Toys.chipLife()local S=Toys.Slab;return S.chipTime+S.chipLie+S.chipFade end

-- Sound -----------------------------------------------------------------------------------------------------------
-- New takes (scripts/synth_asmr.py, not made yet): drop each uploaded id in. 0 = not uploaded, and the stand-in layers
-- below play instead. Once a toy has any take, its takes play alone (each is a dry transient over a soft body already).
Toys.NewTakes=table.freeze({
	leaf_crunch_a=0,leaf_crunch_b=0,leaf_crunch_c=0,leaf_crunch_d=0,
	gourd_rattle_a=0,gourd_rattle_b=0,gourd_rattle_c=0,
	-- Brief 2 section 3: the slab's own (empty slots): a thin snap with a tinkle tail, and the chips' tinkle.
	glass_crackle_a=0,glass_crackle_b=0,glass_crackle_c=0,glass_crackle_d=0,
	glass_tinkle_a=0,glass_tinkle_b=0,glass_tinkle_c=0,
})
-- Per sound: the new take's name and its volume, then the stand-in layers {cue family, takes, speed, volume, delay}
-- from ids we already have (BoardAudio.AsmrIds and snack_crunch_feast): a dry transient over a soft body.
Toys.Voices=table.freeze({
	heap=table.freeze({take="leaf_crunch",takes=4,volume=.9,layers=table.freeze({
		table.freeze({"asmr_flake",{"a","b","c","d","e"},1,.8,0}),
		table.freeze({"snack_crunch_feast",nil,1.12,.45,.02})})}),
	pop=table.freeze({layers=table.freeze({
		table.freeze({"asmr_pop",{"a","b","c"},1.15,.7,0}),
		table.freeze({"asmr_egg_set",{"a","b","c"},.82,.3,.015})})}),
	creak=table.freeze({layers=table.freeze({table.freeze({"asmr_creak",{"a","b","c"},1.25,.32,0})})}),
	-- Brief 2: the heap's rebound and the pod nub's landing.
	rebound=table.freeze({layers=table.freeze({table.freeze({"asmr_flake",{"a","b","c","d","e"},1.1,.55,0})})}),
	nub=table.freeze({layers=table.freeze({table.freeze({"asmr_pop",{"a","b","c"},1.3,.4,0})})}),
	-- The crackle slab: pitch 8% either way and never the same take twice running (Toys.layers' memory).
	crack=table.freeze({take="glass_crackle",takes=4,volume=.85,pitch=.08,layers=table.freeze({
		table.freeze({"asmr_crack1",{"a","b","c"},1,.75,0})})}),
	shatter=table.freeze({pitch=.08,layers=table.freeze({
		table.freeze({"asmr_crack2",{"a","b","c"},1,.85,0}),
		table.freeze({"asmr_flake",{"a","b","c","d","e"},1.25,.5,.02})})}),
	chips=table.freeze({take="glass_tinkle",takes=3,volume=.6,pitch=.08,layers=table.freeze({
		table.freeze({"asmr_flake",{"a","b","c","d","e"},1.6,.32,0})})}),
	heal=table.freeze({pitch=.08,layers=table.freeze({table.freeze({"asmr_creak",{"a","b","c"},1.3,.3,0})})}),
	rattle=table.freeze({take="gourd_rattle",takes=3,volume=.8,layers=table.freeze({
		table.freeze({"asmr_flake",{"a","b","c","d","e"},1.45,.5,0}),
		table.freeze({"asmr_flake",{"a","b","c","d","e"},1.6,.35,.07}),
		table.freeze({"asmr_egg_set",{"a","b","c"},.75,.25,.02})})}),
})
-- Pure: the layers to play for a sound, {cue, speed, volume, delay}. roll(lo, hi) is the random source; takes holds
-- the new takes' ids (Toys.NewTakes by default). memory (optional, a table the caller keeps): the last name picked per
-- family, so the same take never plays twice running.
function Toys.layers(sound,roll,takes,memory)
	takes=takes or Toys.NewTakes
	local voice=Toys.Voices[sound]
	if not voice then return{}end
	local spread=voice.pitch or Toys.Pitch
	local function pitch(speed)return speed*roll(1-spread,1+spread)end
	local function pick(family,names)
		local n=math.clamp(math.floor(roll(1,#names+1)),1,#names)
		if memory and #names>1 and memory[family]==names[n]then n=n%#names+1 end
		if memory then memory[family]=names[n]end
		return names[n]
	end
	if voice.take then
		local ready={}
		for i=1,voice.takes do
			local cue=voice.take.."_"..string.char(96+i)
			if type(takes[cue])=="number"and takes[cue]>0 then table.insert(ready,cue)end
		end
		if #ready>0 then
			return{{cue=pick(voice.take,ready),speed=pitch(1),volume=voice.volume,delay=0}}
		end
	end
	local out={}
	for _,layer in ipairs(voice.layers)do
		local family,names=layer[1],layer[2]
		local cue=family
		if names then cue=family.."_"..pick(family,names)end
		table.insert(out,{cue=cue,speed=pitch(layer[3]),volume=layer[4],delay=layer[5]})
	end
	return out
end
-- Every cue a stand-in can name (the client resolves each once).
function Toys.cues()
	local out,seen={},{}
	for _,voice in pairs(Toys.Voices)do
		for _,layer in ipairs(voice.layers)do
			for _,n in ipairs(layer[2]or{false})do
				local cue=if n then layer[1].."_"..n else layer[1]
				if not seen[cue]then seen[cue]=true;table.insert(out,cue)end
			end
		end
	end
	table.sort(out)
	return out
end

return table.freeze(Toys)
