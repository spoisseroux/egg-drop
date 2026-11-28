-- The garden's prop keep-outs for pets (GARDEN-PLAY-BRIEF-2 section 4; Spencer, beta 35 note 4: "pets shouldnt clip
-- thru the meshes"). Pets are server actors moved along planned paths, never physics, and most garden props are drawn
-- by the clients (the Aero kit's trees, the crunchy toys) or merged into one world mesh, so nothing stops a pet but
-- this list. Pure: shared data only (WorldAeroKit, HollowWorldLayout, CrunchToys), no instances.
--
-- One list: {id, x, z, r, kind, feature?}. `solid` things are walked round with Clearance more (a pet's half-width):
-- tree trunks, lamp posts, the fountain's stone basin, the Wobble Egg's crag, the gourd arch, the pebble tray's frame.
-- `soft` things (the leaf heaps, the pop pods) are walked through: they squash. `feature` names
-- the Alive switch that builds the prop (no feature: the world's own); a prop that is not built keeps nothing out.
-- Not here: the stations (the Journal's care cradle is where a pet is set down, the egg corner has its own blocked
-- box), the rest daises (pets rest on them), water (already the planner's wet list) and the Bumble balls: they roll
-- (a static circle would be wrong as soon as one is kicked) and the felt ball's home is the toy lawn's own pet spot
-- (GardenLayout.Lawn), so a resting ball needs the server's live record, not this list.
--
-- The server's pet planner (GardenPathPlanner / GardenWalkability) reads KeepOut.regions(on): one circle record per
-- solid prop, r grown by Clearance, in the same list as the wet boxes. Every number is a [PLACEHOLDER] until a Studio
-- capture per prop.
local Shared=script.Parent
local World=require(Shared.HollowWorldLayout)
local KeepOut={}
KeepOut.Feature="keepout"     -- the Alive switch (beta and Studio; missing = on)
KeepOut.Clearance=.6          -- studs kept between a pet's centre and a solid prop's edge (the brief)
-- Trunk radius at crown scale 1 (the merged W7_Trunks bark, about 1.2 across at the root flare) [PLACEHOLDER]; the two
-- landmark trees have their own.
KeepOut.Trunk=.6
KeepOut.TrunkOf=table.freeze({Landmark_HatchTree=2.2,Landmark_BlossomPointTree=1.1})
KeepOut.Lamp=.45              -- a lamp post's foot
KeepOut.Fountain=table.freeze({x=52,z=3,r=4.6})   -- the kit's stone basin (8.9 x 5.64; the spring box is inside it)
KeepOut.Wobble=table.freeze({x=17,z=-45,r=2.6})   -- the crag's egg (4.7 across) and its collar

local cache={}
-- Every keep-out, solid and soft, built or not: {id, x, z, r, kind, feature?}. Frozen and cached. Beta 38: the trunks
-- of the graded trees (TreeGrades.kit while the grades are on; `graded` nil asks TreeGrades.on) at their grown radius.
function KeepOut.all(graded)
	local okGrades,Grades=pcall(function()return require(Shared.TreeGrades)end)
	if graded==nil then graded=okGrades and Grades.on()or false end
	local key=if graded then "graded"else "today"
	if cache[key]then return cache[key]end
	local out={}
	local function add(id,x,z,r,kind,feature)
		table.insert(out,table.freeze({id=id,x=x,z=z,r=r,kind=kind,feature=feature}))
	end
	-- Tree trunks: each kit crown's pivot is its trunk top (AeroKit: WorldPivot), straight over the trunk.
	local okKit,Kit=pcall(function()return require(Shared.WorldAeroKit)end)
	if okKit and graded and okGrades then Kit=Grades.kit(Kit,true)end
	for _,crown in ipairs(okKit and type(Kit)=="table"and Kit.crowns or {})do
		local pivot=crown.pivot
		if type(pivot)=="table"and type(pivot[1])=="number"and type(pivot[3])=="number"then
			local s=if type(crown.trunk)=="number"then crown.trunk elseif type(crown.scale)=="number"then crown.scale else 1
			local r=KeepOut.TrunkOf[crown.tree]or KeepOut.Trunk*s
			add("trunk "..tostring(crown.tree),pivot[1],pivot[3],r,"solid",nil)
		end
	end
	for i,lamp in ipairs(World.Lamps or {})do add("lamp "..i,lamp.X,lamp.Z,KeepOut.Lamp,"solid",nil)end
	add("fountain",KeepOut.Fountain.x,KeepOut.Fountain.z,KeepOut.Fountain.r,"solid",nil)
	add("wobble egg",KeepOut.Wobble.x,KeepOut.Wobble.z,KeepOut.Wobble.r,"solid","wobble")
	-- The crunchy toys: the gourd arch and the tray's timber frame are solid; heaps and pods squash.
	local okToys,Toys=pcall(function()return require(Shared.CrunchToys)end)
	if okToys then
		for _,foot in ipairs(Toys.footprints())do
			local solid=foot.id==Toys.Places.gourds.id or foot.id==Toys.Places.tray.id
			-- The pods' whole-row circle is the row's bounding circle, not a pod: never a keep-out of its own.
			if foot.id~=Toys.Places.pods.id then add(foot.id,foot.x,foot.z,foot.r,if solid then "solid"else "soft",Toys.Feature)end
		end
	end
	cache[key]=table.freeze(out)
	return cache[key]
end

-- The solid keep-outs that are built: on(feature) -> boolean answers each prop's Alive switch (nil: every prop built).
function KeepOut.solids(on,graded)
	local out={}
	for _,entry in ipairs(KeepOut.all(graded))do
		if entry.kind=="solid"and(entry.feature==nil or on==nil or on(entry.feature)==true)then table.insert(out,entry)end
	end
	return out
end

-- The planner's circle records (GardenWalkability): {KeepOut = true, Parent = true, Name, X, Z, R} with R = r +
-- Clearance. `Parent` is there so code that skips a removed wet part (part.Parent == nil) keeps the record.
function KeepOut.regions(on,graded)
	local out={}
	for _,entry in ipairs(KeepOut.solids(on,graded))do
		table.insert(out,table.freeze({KeepOut=true,Parent=true,Name=entry.id,X=entry.x,Z=entry.z,R=entry.r+KeepOut.Clearance}))
	end
	return out
end

-- The lead's plants (beta 40, Spencer: "the pet runs thru meshes when showing you to something"). The lead's route is
-- the client's PathfindingService way, and the navigation mesh and the server's rays see only collidable parts: the
-- understory (UnderstoryClient: client-drawn, nothing collides) and the frond bushes (WorldDressing, CanCollide off)
-- are invisible to both. So the lead keeps these out too, as circles of their own kind "plant" (never in `solids` or
-- `regions`: the everyday pet planner and the understory's own placement rules are unchanged). Understory clumps are
-- built under the Alive `scene` switch (their feature); the frond bushes are the world's own (the first MaxBushes, on
-- the ground: never one on the cliff tiers above a lawn). Hedges and fence posts have no shared layout data yet (they
-- are in the merged world mesh, which the navmesh does see where it collides).
KeepOut.Plant=table.freeze({understory=.85,frond=.7}) -- of a plant's half-width: a bush's rim is sparse leaves [PLACEHOLDER]
local plantCache=nil
function KeepOut.plants()
	if plantCache then return plantCache end
	local out={}
	local function add(id,x,z,r,feature)
		if type(x)=="number"and type(z)=="number"and type(r)=="number"and r>0 then
			table.insert(out,table.freeze({id=id,x=x,z=z,r=r,kind="plant",feature=feature}))
		end
	end
	local okU,U=pcall(function()return require(Shared.Understory)end)
	if okU and type(U)=="table"then
		for _,kind in ipairs(U.Kinds or {})do
			for i,row in ipairs(U.rows(kind))do
				local ok,r=pcall(U.radius,kind,row)
				if ok then add(kind.." "..i,row[1],row[3],r*KeepOut.Plant.understory,U.Feature)end
			end
		end
	end
	local okD,Dressing=pcall(function()return require(Shared.WorldDressing)end)
	if okD and type(Dressing)=="table"and World.WorldVersion=="v7"then
		for i,entry in ipairs(Dressing.Bushes or {})do
			if i>(Dressing.MaxBushes or math.huge)then break end
			local onGround=type(World.groundY)~="function"or math.abs(entry[2]-World.groundY(entry[1],entry[3]))<2
			local ok,_,size=pcall(function()return Dressing.bushPlacement(entry)end)
			if onGround and ok and typeof(size)=="Vector3"then add("frond "..i,entry[1],entry[3],math.max(size.X,size.Z)*.5*KeepOut.Plant.frond,nil)end
		end
	end
	plantCache=table.freeze(out)
	return plantCache
end
-- Everything the lead keeps its route clear of: the built solids and the built plants (on as KeepOut.solids).
function KeepOut.lead(on,graded)
	local out=KeepOut.solids(on,graded)
	for _,entry in ipairs(KeepOut.plants())do
		if entry.feature==nil or on==nil or on(entry.feature)==true then table.insert(out,entry)end
	end
	return out
end
-- The lead's circles as planner records (GardenWalkability), r grown by Clearance: the server's lead walks round them.
function KeepOut.leadRegions(on,graded)
	local out={}
	for _,entry in ipairs(KeepOut.lead(on,graded))do
		table.insert(out,table.freeze({KeepOut=true,Parent=true,Name=entry.id,X=entry.x,Z=entry.z,R=entry.r+KeepOut.Clearance}))
	end
	return out
end

-- Pure geometry (XZ) ----------------------------------------------------------------------------------------------
-- The distance from (px, pz) to the segment a-b.
function KeepOut.toSegment(px,pz,ax,az,bx,bz)
	local dx,dz=bx-ax,bz-az
	local length=dx*dx+dz*dz
	local t=if length<1e-12 then 0 else math.clamp(((px-ax)*dx+(pz-az)*dz)/length,0,1)
	local ex,ez=px-(ax+t*dx),pz-(az+t*dz)
	return math.sqrt(ex*ex+ez*ez)
end
-- The first entry of `list` ({x, z, r} or records {X, Z, R}) the segment a-b (Vector3, XZ) passes within r + grow of.
function KeepOut.hit(a,b,list,grow)
	grow=grow or 0
	for _,entry in ipairs(list)do
		local x,z,r=entry.x or entry.X,entry.z or entry.Z,entry.r or entry.R
		if KeepOut.toSegment(x,z,a.X,a.Z,b.X,b.Z)<r+grow then return entry end
	end
	return nil
end

return table.freeze(KeepOut)
