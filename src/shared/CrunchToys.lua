-- Crunchy toys round the garden (GARDEN-PLAY-BRIEF 2026-11-26 section 2, Fable): two dry leaf heaps, a row of six pop
-- pods, a pebble tray and three rattle gourds on a twig arch. Nice to stomp; sound first. Pure data and maths here
-- (CrunchToysClient builds and drives them): no instances, no remotes. Each client watches the characters and pets it
-- already has and reacts on its own, so two players see their own crunches; nothing replicates and nothing is saved.
-- Gate: the Alive `crunch` switch (AliveCrunch, the beta place or Studio, ConfigService `alive_crunch`); off, nothing
-- is built. Every number is a [PLACEHOLDER]; the spots were chosen off the v7 surface map (grass under every footprint)
-- and are checked against GardenClearance by scripts/CrunchToys.spec.lua. Raycast them in Studio.
local Toys={}
Toys.Feature="crunch"
Toys.Budget=120                   -- parts in all (the brief)
Toys.Cull=table.freeze({phone=90,desktop=150})
Toys.Rate=1/30                    -- the loop's step while something is near
Toys.Sleep=.5                     -- how often a sleeping loop looks again
Toys.Reach=5                      -- a root more than this over a toy's base is above it (a jump over, not through)
Toys.OtherRange=30                -- other players' crunches are heard only this close to me
Toys.Gains=table.freeze({own=1,ownPet=.5,other=.4,otherPet=.2,world=.6}) -- world: a pod's re-inflating creak
Toys.Pitch=.06                    -- every layer's pitch varies this much either way
Toys.PetReactGap=3                -- one startle per pet this often at most
Toys.Buzz=table.freeze({heap="creak",pop="crack1",gravel="settle"}) -- Haptics patterns, the local player only

-- The pieces ------------------------------------------------------------------------------------------------------
Toys.Heap=table.freeze({width=5,height=1.2,colours=table.freeze({"#C98A3C","#A8552E","#E0B24F"}),
	-- {dx, dz, width x, height, width z, colour}: three mounds make one heap (the first is the big one)
	mounds=table.freeze({table.freeze({0,0,5,1.2,4.6,1}),table.freeze({.8,-.5,3.4,1.0,3.0,2}),table.freeze({-.9,.7,3.0,.85,2.6,3})}),
	leaves=8,leafSize=Vector3.new(.78,.05,.5),
	burst=14,burstTime=1.5,lie=.4,fade=.4, -- cards fly and flutter down 1.5 s, lie .4 s, fade .4 s
	flat=.3,squash=.12,reheap=20,     -- flattens to 30% in .12 s, heaps back over 20 s
	reach=2.4,radius=2.6})
Toys.Pod=table.freeze({count=6,across=.9,tall=.75,colour="#9DBF6A",dome="#C9DDA0",domeAcross=.5,domeTall=.36,
	flat=.22,spread=1.18,pop=.06,reinflate=6,inflate=.8,overshoot=.08,reach=.9,radius=.6,
	bend=6,spacing=1.5})                 -- the row: six along an arc of radius 6, 1.5 apart
Toys.Tray=table.freeze({size=Vector2.new(6,4),board=Vector2.new(.32,.3),frame="#6B4A2E",gravel="#B9B2A3",
	pebbles=6,pebbleColours=table.freeze({"#9C968A","#C9C2B4","#ABA393"}),stride=1.5,hop=.35,hopTime=.28,radius=3.6})
Toys.Gourd=table.freeze({count=3,colour="#D8B56A",cord="#8A6A3C",bark="#6B4A2E",bar=2.35,span=3.4,post=.2,gap=1.05,
	cordLength=.32,neck=Vector3.new(.36,.5,.36),body=Vector3.new(.74,.68,.74), -- 1.1 tall from neck top to foot
	swing=25,decay=.5,period=1,settle=2,neighbour=.35,reach=1.0,radius=1.9})

-- Where (XZ; the client seats them on the ground). Moved from the brief's spots onto clear grass:
--   heaps  (-22, 38) -> (-26, 37) under the trees west of lamp 7; (-12, -44) -> (-13, -40) north of lamp 4
--   pods   (20, 34) -> (15, 38.5) (the brief's spot is half on the stream's path)
--   tray   (44, 12) -> (42, 12) beside the fountain lawn, clear of the west rest dais
--   gourds (78, 56) -> (76, 63.5): the brief's spot is on the arrival path; the arch runs along it, 6 studs off
Toys.Places=table.freeze({
	heaps=table.freeze({table.freeze({id="leaf_heap_1",x=-26,z=37,yaw=.4}),table.freeze({id="leaf_heap_2",x=-13,z=-40,yaw=-.9})}),
	pods=table.freeze({id="pop_pods",x=15,z=38.5,yaw=.35}),
	tray=table.freeze({id="pebble_tray",x=42,z=12,yaw=.15}),
	gourds=table.freeze({id="rattle_gourds",x=76,z=63.5,yaw=math.atan2(-16,-36)}), -- the bar along the arrival path
})

-- Parts, counted as the client builds them (the spec holds it to Toys.Budget).
function Toys.partCount()
	local H,P,T,G=Toys.Heap,Toys.Pod,Toys.Tray,Toys.Gourd
	local heaps=#Toys.Places.heaps*(#H.mounds+H.leaves)+H.burst -- one burst pool, shared by both heaps
	local pods=P.count*2                                        -- body and dome
	local tray=4+1+T.pebbles                                    -- four boards, the gravel bed, the pebbles that hop
	local gourds=3+G.count*3                                    -- two posts and the bar; cord, neck and body each
	return heaps+pods+tray+gourds+1                             -- and the one invisible part the sounds hang from
end

-- Pure geometry ---------------------------------------------------------------------------------------------------
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

-- A heap: state {hitAt, before} (nil hitAt: full). Its height now, 0..1 of the full mound.
function Toys.heapLevel(state,now)
	local H=Toys.Heap
	if not state or not state.hitAt then return 1 end
	local t=now-state.hitAt
	if t<H.squash then return state.before+(H.flat-state.before)*ease(t/H.squash)end
	return H.flat+(1-H.flat)*math.clamp((t-H.squash)/H.reheap,0,1)
end
-- A walk or jump through: the heap flattens; returns the cards to burst and the crunch's gain (a flat heap is a
-- smaller crunch and a smaller burst).
function Toys.heapHit(state,now)
	local H=Toys.Heap
	local before=Toys.heapLevel(state,now)
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
-- how seen it is (1 seen, 0 gone). The same seed and card always fly the same way.
function Toys.card(seed,i,t)
	local H=Toys.Heap
	local a=hash(seed,i,1)*math.pi*2
	local r0=.4+hash(seed,i,2)*1.5
	local y0=H.height*.85*math.sqrt(math.max(0,1-(r0/(H.width/2))^2))
	local speed,up,tau=3+hash(seed,i,3)*4,4.5+hash(seed,i,4)*2,.4
	local g,fall=26,1.6+hash(seed,i,5)*.6 -- every card is down inside 1.5 s
	local out=r0+speed*tau*(1-math.exp(-t/tau))
	local t1=(up+fall)/g
	local y
	if t<t1 then y=y0+up*t-.5*g*t*t
	else y=y0+up*t1-.5*g*t1*t1-fall*(t-t1)end
	y=math.max(.04,y)
	local flutter=if t>t1 then .3*math.sin(math.pi*2*1.6*t+hash(seed,i,6)*6)else 0
	local x,z=math.cos(a)*out-math.sin(a)*flutter,math.sin(a)*out+math.cos(a)*flutter
	local landed=y<=.04
	local rx=if landed then 0 else math.sin(t*7+i)*.9
	local rz=if landed then 0 else math.cos(t*5.3+i*2)*.7
	local seen=1-math.clamp((t-H.burstTime-H.lie)/H.fade,0,1)
	return Vector3.new(x,y,z),rx,a+t*(2+hash(seed,i,7)*3),rz,seen
end
function Toys.cardLife()return Toys.Heap.burstTime+Toys.Heap.lie+Toys.Heap.fade end

-- A pod popped at `poppedAt` (nil: ready). Its height and width scales now, and its phase (ready / flat / inflating).
function Toys.podScale(poppedAt,now)
	local P=Toys.Pod
	if not poppedAt then return 1,1,"ready"end
	local t=now-poppedAt
	if t<P.pop then local k=ease(t/P.pop);return 1+(P.flat-1)*k,1+(P.spread-1)*k,"flat"end
	if t<P.reinflate then return P.flat,P.spread,"flat"end
	local k=(t-P.reinflate)/P.inflate
	if k>=1 then return 1,1,"ready"end
	local up=ease(k)+P.overshoot*math.sin(k*math.pi)
	return P.flat+(1-P.flat)*up,P.spread+(1-P.spread)*ease(k),"inflating"
end

-- A gourd bumped at `at` with `push` (-1..1 of the full swing). Its swing (radians about the bar) now; 0 once settled.
function Toys.gourdAngle(at,push,now)
	local G=Toys.Gourd
	if not at then return 0 end
	local t=now-at
	if t<0 or t>=G.settle then return 0 end
	return math.rad(G.swing)*push*math.exp(-t/G.decay)*math.sin(math.pi*2*t/G.period)
end
-- A pebble's hop t seconds in (studs up).
function Toys.pebbleHop(t)
	local T=Toys.Tray
	if t<0 or t>=T.hopTime then return 0 end
	local k=t/T.hopTime
	return T.hop*4*k*(1-k)
end

-- Sound -----------------------------------------------------------------------------------------------------------
-- New takes (scripts/synth_asmr.py, not made yet): drop each uploaded id in. 0 = not uploaded, and the stand-in layers
-- below play instead. Once a toy has any take, its takes play alone (each is a dry transient over a soft body already).
Toys.NewTakes=table.freeze({
	leaf_crunch_a=0,leaf_crunch_b=0,leaf_crunch_c=0,leaf_crunch_d=0,
	gravel_step_a=0,gravel_step_b=0,gravel_step_c=0,gravel_step_d=0,
	gourd_rattle_a=0,gourd_rattle_b=0,gourd_rattle_c=0,
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
	gravel=table.freeze({take="gravel_step",takes=4,volume=.8,layers=table.freeze({
		table.freeze({"asmr_egg_set",{"a","b","c"},1.35,.45,0}),
		table.freeze({"asmr_flake",{"a","b","c","d","e"},.8,.35,.01})})}),
	rattle=table.freeze({take="gourd_rattle",takes=3,volume=.8,layers=table.freeze({
		table.freeze({"asmr_flake",{"a","b","c","d","e"},1.45,.5,0}),
		table.freeze({"asmr_flake",{"a","b","c","d","e"},1.6,.35,.07}),
		table.freeze({"asmr_egg_set",{"a","b","c"},.75,.25,.02})})}),
})
-- Pure: the layers to play for a sound, {cue, speed, volume, delay}. roll(lo, hi) is the random source; takes holds
-- the new takes' ids (Toys.NewTakes by default).
function Toys.layers(sound,roll,takes)
	takes=takes or Toys.NewTakes
	local voice=Toys.Voices[sound]
	if not voice then return{}end
	local function pitch(speed)return speed*roll(1-Toys.Pitch,1+Toys.Pitch)end
	if voice.take then
		local ready={}
		for i=1,voice.takes do
			local cue=voice.take.."_"..string.char(96+i)
			if type(takes[cue])=="number"and takes[cue]>0 then table.insert(ready,cue)end
		end
		if #ready>0 then
			return{{cue=ready[math.clamp(math.floor(roll(1,#ready+1)),1,#ready)],speed=pitch(1),volume=voice.volume,delay=0}}
		end
	end
	local out={}
	for _,layer in ipairs(voice.layers)do
		local family,names=layer[1],layer[2]
		local cue=family
		if names then cue=family.."_"..names[math.clamp(math.floor(roll(1,#names+1)),1,#names)]end
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
