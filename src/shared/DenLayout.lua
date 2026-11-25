-- The Play Den's numbers (PLAY-DEN-BUILD-PLAN.md, architect verdict applied). Shared and pure: every piece of den code
-- (the greybox, the prompts, the Dash anchor, the pet floor, catch-up, the island bounds, the trail) reads a layout
-- from here, and nothing else hard-codes a den number. Two variants:
--   "pocket" (step A): today's small pocket behind the CaveBlocker, measured in Studio R5 (floor y 4.0 from z -101 to
--     -113, back rock z -114.2, roof 15.0 to 18.6) and the ground grid (flat 4.0 for x about -10..-6, rising past -12
--     and -4). About 7 x 12 of flat floor: three bays (the Dash gate, one roped niche, the Deck table).
--   "room" (step B): the enlarged room from the island session's generated Shared.CliffDenData (`den`), used only when
--     the server set the workspace attribute `CliffDen` at start. A schema mismatch or a missing field is no layout at
--     all (the den stays closed with one warning): the pocket is gone on such a server, so it is never a fallback.
--
-- A layout: {variant, floorY, roofY, room = box, wait = box, floors = {box...}, mouth = {x1, x2, z, top}, sign = CFrame,
-- lanterns = {{at = Vector3, post = bool}...}, board = CFrame, bays = {{id, kind, frame = CFrame}...}, pin = Vector3,
-- doorstep = {at, facing, landing}}. Boxes are {min, max} Vector3s. A bay's frame stands on the floor and looks the way
-- its object faces (toward the players): local -Z is out of the bay, local X is its right hand.
local World=require(script.Parent.HollowWorldLayout).V7
local Layout={}
Layout.Schema=1                 -- CliffDenData.schema this file reads
Layout.BayKinds=table.freeze({"dash","niche","deck","niche","niche"}) -- step B's bays in order (Fable's table)
Layout.Light=table.freeze({color="#FFC98A",range=14,brightness=1.2}) -- four of them: the whole light budget
-- Each kind's footprint in its bay frame (x1, z1, x2, z2; -z toward the players), before the pets' Grow.
Layout.Kinds=table.freeze({
	dash=table.freeze({foot=table.freeze({-2.4,-1.0,2.4,.5}),prompt=Vector3.new(0,3.2,0)}),
	deck=table.freeze({foot=table.freeze({-2.1,-3.0,2.1,1.5}),prompt=Vector3.new(0,3.4,0)}),
	niche=table.freeze({foot=table.freeze({-1.6,-1.6,1.6,.8})}),
})
Layout.Grow=1.5       -- pet-blocked footprints are the furniture grown by this much
Layout.WaitApron=3    -- the waiting area reaches this far out of the mouth (a crowd of eight is never pushed out)
Layout.Below=2        -- the room's boxes start this far under the floor (cliff-top players never count)

local function v(t)return Vector3.new(t[1],t[2],t[3])end
local function box(a,b)
	return table.freeze({min=Vector3.new(math.min(a.X,b.X),math.min(a.Y,b.Y),math.min(a.Z,b.Z)),
		max=Vector3.new(math.max(a.X,b.X),math.max(a.Y,b.Y),math.max(a.Z,b.Z))})
end
Layout.box=box
local function facing(at,toward)return CFrame.lookAt(at,Vector3.new(toward.X,at.Y,toward.Z))end
local function ground(x,z)return World.groundY(x,z)end
-- Pure: is p inside b, grown by `slack` on every side?
function Layout.inBox(b,p,slack)
	if typeof(p)~="Vector3"or p.X~=p.X or p.Y~=p.Y or p.Z~=p.Z then return false end
	slack=slack or 0
	return p.X>=b.min.X-slack and p.X<=b.max.X+slack and p.Y>=b.min.Y-slack and p.Y<=b.max.Y+slack
		and p.Z>=b.min.Z-slack and p.Z<=b.max.Z+slack
end
local function inPlan(b,x,z,slack)
	slack=slack or 0
	return x>=b.min.X-slack and x<=b.max.X+slack and z>=b.min.Z-slack and z<=b.max.Z+slack
end

-- Step A: the pocket ----------------------------------------------------------------------------------------------
local function pocket()
	local floorY,roofY=4,15
	local mouth=table.freeze({x1=-14.8,x2=2.9,z=-100,top=roofY})
	local function bay(id,kind,x,z,toward)
		local at=Vector3.new(x,floorY,z)
		return table.freeze({id=id,kind=kind,frame=facing(at,at+toward)})
	end
	local boardAt=Vector3.new(4,ground(4,-95),-95)
	return table.freeze({
		variant="pocket",floorY=floorY,roofY=roofY,
		room=box(Vector3.new(-12.5,floorY-Layout.Below,-114.5),Vector3.new(-1.5,roofY,-99.5)),
		wait=box(Vector3.new(mouth.x1,floorY-Layout.Below,-114.5),Vector3.new(mouth.x2,roofY,mouth.z+Layout.WaitApron)),
		-- The pets: the flat floor less a stud, and the apron from the mouth to the home Floor's edge (it ends at z -90,
		-- less its 1-stud margin), overlapping both by half a stud.
		floors=table.freeze({
			box(Vector3.new(-10.5,floorY-Layout.Below,-113),Vector3.new(-4.5,floorY+3,-99.5)),
			box(Vector3.new(-12,floorY-Layout.Below,-100),Vector3.new(1,floorY+3,-88.5)),
		}),
		mouth=mouth,
		sign=facing(Vector3.new(-6,8.9,-99.6),Vector3.new(-6,8.9,-90)),
		lanterns=table.freeze({
			table.freeze({at=Vector3.new(-13.6,ground(-13.6,-98.4),-98.4),post=true}),
			table.freeze({at=Vector3.new(2.2,ground(2.2,-98.4),-98.4),post=true}),
			table.freeze({at=Vector3.new(-9.4,9,-113.6),post=false}),
			table.freeze({at=Vector3.new(-4.6,9,-113.6),post=false}),
		}),
		board=facing(boardAt,boardAt+Vector3.new(0,0,10)),
		bays=table.freeze({
			bay("bay1","dash",-10,-105,Vector3.new(1,0,0)),
			bay("bay2","niche",-9.6,-111.6,Vector3.new(0,0,1)),
			bay("bay3","deck",-6.4,-111.4,Vector3.new(0,0,1)),
		}),
		pin=Vector3.new(-6,ground(-6,-96),-96),
		doorstep=table.freeze({at=Vector3.new(-6,4.6,-87),facing=Vector3.new(-6,4.6,-70),landing=Vector3.new(-6,4.625,-84)}),
	})
end
Layout.Pocket=pocket()

-- Step B: from CliffDenData ------------------------------------------------------------------------------------------
-- CliffDenData (schema 1) `den`:
--   floorY = number; roofY = number (the lowest roof over the bays); room = {min = {x,y,z}, max = {x,y,z}} (PlayDen);
--   mouth = {x1, x2, z, top}; sign = {at = {x,y,z}, facing = {x,y,z}}; lanterns = four {at = {x,y,z}, post = bool};
--   bays = five {at = {x,y,z}, facing = {x,y,z}} (kinds by order: Layout.BayKinds); board = {at, facing};
--   pin = {x,y,z}; doorstep = {at, facing, landing}.
-- Answers the layout, or nil and why.
local function num(x)return type(x)=="number"and x==x and math.abs(x)<1e5 end
local function vec(t)return type(t)=="table"and num(t[1])and num(t[2])and num(t[3])end
local function spot(t)return type(t)=="table"and vec(t.at)and vec(t.facing)end
function Layout.fromData(data)
	if type(data)~="table"then return nil,"no data"end
	if data.schema~=Layout.Schema then return nil,"schema "..tostring(data.schema).." (wants "..Layout.Schema..")"end
	local d=data.den
	if type(d)~="table"then return nil,"no den"end
	if not num(d.floorY)or not num(d.roofY)then return nil,"floorY / roofY"end
	if type(d.room)~="table"or not vec(d.room.min)or not vec(d.room.max)then return nil,"room"end
	local m=d.mouth
	if type(m)~="table"or not num(m.x1)or not num(m.x2)or not num(m.z)or not num(m.top)or m.x2<=m.x1 then return nil,"mouth"end
	if not spot(d.sign)or not spot(d.board)or not vec(d.pin)then return nil,"sign / board / pin"end
	if type(d.doorstep)~="table"or not spot(d.doorstep)or not vec(d.doorstep.landing)then return nil,"doorstep"end
	if type(d.lanterns)~="table"or #d.lanterns~=4 then return nil,"lanterns"end
	for _,l in ipairs(d.lanterns)do if type(l)~="table"or not vec(l.at)then return nil,"lantern"end end
	if type(d.bays)~="table"or #d.bays~=#Layout.BayKinds then return nil,"bays"end
	for _,b in ipairs(d.bays)do if not spot(b)then return nil,"bay"end end
	local floorY,roofY=d.floorY,d.roofY
	local lo,hi=v(d.room.min),v(d.room.max)
	local room=box(Vector3.new(lo.X,floorY-Layout.Below,lo.Z),Vector3.new(hi.X,roofY,hi.Z))
	local outZ=m.z+Layout.WaitApron
	local bays,lanterns={},{}
	for i,b in ipairs(d.bays)do
		local at=v(b.at)
		bays[i]=table.freeze({id="bay"..i,kind=Layout.BayKinds[i],frame=facing(at,v(b.facing))})
	end
	for i,l in ipairs(d.lanterns)do lanterns[i]=table.freeze({at=v(l.at),post=l.post==true})end
	return table.freeze({
		variant="room",floorY=floorY,roofY=roofY,room=room,
		wait=box(Vector3.new(math.min(lo.X,m.x1),floorY-Layout.Below,lo.Z),Vector3.new(math.max(hi.X,m.x2),roofY,math.max(hi.Z,outZ))),
		floors=table.freeze({
			box(Vector3.new(lo.X+1,floorY-Layout.Below,lo.Z+1),Vector3.new(hi.X-1,floorY+3,hi.Z)),
			box(Vector3.new(m.x1+1,floorY-Layout.Below,math.min(m.z,hi.Z)-.5),Vector3.new(m.x2-1,floorY+3,-88.5)),
		}),
		mouth=table.freeze({x1=m.x1,x2=m.x2,z=m.z,top=m.top}),
		sign=facing(v(d.sign.at),v(d.sign.facing)),lanterns=table.freeze(lanterns),
		board=facing(v(d.board.at),v(d.board.facing)),bays=table.freeze(bays),pin=v(d.pin),
		doorstep=table.freeze({at=v(d.doorstep.at),facing=v(d.doorstep.facing),landing=v(d.doorstep.landing)}),
	})
end

-- Which layout this server uses. env (specs): {cliffDen = bool, data = table}. The game reads the `CliffDen` attribute
-- (set at server start) and Shared.CliffDenData. Answers the layout, or nil and why.
local cache={}
function Layout.current(env)
	local cliff,data
	if env then cliff,data=env.cliffDen==true,env.data
	else
		cliff=workspace:GetAttribute("CliffDen")==true
		if not cliff then return Layout.Pocket end
		if cache.done then return cache.layout,cache.why end
		local ok,module=pcall(function()return require(script.Parent:FindFirstChild("CliffDenData"))end)
		data=if ok then module else nil
	end
	if not cliff then return Layout.Pocket end
	local layout,why=Layout.fromData(data)
	if not env then cache.done,cache.layout,cache.why=true,layout,why end
	return layout,why
end

-- Questions ----------------------------------------------------------------------------------------------------------
-- In the room itself (floorY - Below up to the roof; slack studs grown in plan).
function Layout.inRoom(L,p,slack)
	if L==nil or typeof(p)~="Vector3"or p.X~=p.X or p.Y~=p.Y or p.Z~=p.Z then return false end
	return p.Y>=L.room.min.Y and p.Y<=L.room.max.Y and inPlan(L.room,p.X,p.Z,slack or 0)
end
-- In the waiting area (the room and the apron just outside the mouth), grown by `slack` in plan only.
function Layout.inWait(L,p,slack)
	if L==nil or typeof(p)~="Vector3"or p.X~=p.X or p.Y~=p.Y or p.Z~=p.Z then return false end
	local w=L.wait
	return p.Y>=w.min.Y and p.Y<=w.max.Y and inPlan(w,p.X,p.Z,slack or 0)
end
-- The pets' floor while `open` is true (DenHost's own flag): the room's floor and the apron to the home Floor.
function Layout.petFloor(L,p,open)
	if open~=true or L==nil or typeof(p)~="Vector3"then return false end
	for _,b in ipairs(L.floors)do if Layout.inBox(b,p,0)then return true end end
	return false
end
-- The furniture's footprints, grown by `grow` (default Grow): {name, frame, x1, z1, x2, z2} in the bay frame.
function Layout.feet(L,grow)
	grow=grow or Layout.Grow
	local out={}
	for _,bay in ipairs(L.bays)do
		local f=Layout.Kinds[bay.kind].foot
		table.insert(out,{name=bay.id,frame=bay.frame,x1=f[1]-grow,z1=f[2]-grow,x2=f[3]+grow,z2=f[4]+grow})
	end
	table.insert(out,{name="board",frame=L.board,x1=-2.1-grow,z1=-.4-grow,x2=2.1+grow,z2=.4+grow})
	for i,l in ipairs(L.lanterns)do
		if l.post then table.insert(out,{name="lantern"..i,frame=CFrame.new(l.at),x1=-.3-grow,z1=-.3-grow,x2=.3+grow,z2=.3+grow})end
	end
	return out
end
-- As parts (PetRegions boxes at floor height): {name, cframe, size}.
function Layout.footprints(L,grow)
	local out={}
	for _,f in ipairs(Layout.feet(L,grow))do
		local base=f.frame.Position
		local mid=f.frame*CFrame.new((f.x1+f.x2)/2,L.floorY+.5-base.Y,(f.z1+f.z2)/2)
		table.insert(out,{name=f.name,cframe=mid,size=Vector3.new(f.x2-f.x1,1,f.z2-f.z1)})
	end
	return out
end
-- Safe ground for catch-up landings and the island bounds: a pet floor cell (half a stud in) clear of every footprint.
function Layout.safeCell(L,x,z)
	if L==nil or type(x)~="number"or type(z)~="number"or x~=x or z~=z then return false end
	local on=false
	for _,b in ipairs(L.floors)do if inPlan(b,x,z,-.5)then on=true;break end end
	if not on then return false end
	for _,f in ipairs(Layout.feet(L))do
		local p=f.frame:PointToObjectSpace(Vector3.new(x,f.frame.Position.Y,z))
		if p.X>=f.x1 and p.X<=f.x2 and p.Z>=f.z1 and p.Z<=f.z2 then return false end
	end
	return true
end
-- IslandBounds regions: the room and the apron, from FallDepth under the floor; inside it a root has left only below it.
Layout.FallDepth=8
function Layout.boundsRegions(L)
	local w=L.wait
	return table.freeze({table.freeze({name="den",min=Vector3.new(w.min.X-2,L.floorY-Layout.FallDepth,w.min.Z-2),
		max=Vector3.new(w.max.X+2,L.roofY+10,w.max.Z),fallY=L.floorY-Layout.FallDepth,safe=function(x,z)return Layout.safeCell(L,x,z)end})})
end
-- Where each prompt stands: {gate = Vector3?, deck = Vector3?, board = Vector3}.
function Layout.prompts(L)
	local out={board=(L.board*CFrame.new(0,3.6,-.6)).Position}
	for _,bay in ipairs(L.bays)do
		local kind=Layout.Kinds[bay.kind]
		if kind.prompt then
			local key=if bay.kind=="dash"then "gate"else bay.kind
			if not out[key]then out[key]=(bay.frame*CFrame.new(kind.prompt)).Position end
		end
	end
	return out
end
-- The Dash gate's bay (the den's race anchor faces from it), or nil.
function Layout.bay(L,kind)
	for _,bay in ipairs(L.bays)do if bay.kind==kind then return bay end end
	return nil
end
return table.freeze(Layout)
