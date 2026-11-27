-- The trees in three grades (GARDEN-B38-BRIEF 4a, Fable; Spencer's beta 37 note 16 "bigger trees"). Shared and pure:
-- which tree grows how much, and the Aero kit's crown data graded to match, so every reader (AeroKit's parts, the
-- grove and its fruit, the pets' keep-outs, the balloons, the leaf litter) sees the same trees.
--   Round and tall shade trees (12): trunk and crown x1.35, the crown x1.45 wide; three on the rim (01, 13, 20) x1.6.
--   Blossom fruit trees (7): x1.15, so the fruit stays near eye level. Hatch tree and Blossom Point: unchanged.
--   Every tree +-5% from its name, so no two match.
-- A trunk scales about its root and its crown about its pivot (the trunk top), which moves up the grown trunk: bigger
-- crowns start higher. Same meshes, scaled: no new triangles.
--
-- Behind the Alive `scene` switch, and only once the trunk pack is uploaded and confirmed (WorldAeroTrunks.ready, from
-- scripts/build_world_aero_kit_assets.py --trunks --confirm): until then Grades.on() is false and every reader keeps
-- today's trees (the merged trunks, every crown at its own scale). Never an error: a bad module reads as not ready.
local Shared=script.Parent
local Grades={}
Grades.Feature="scene"
-- trunk: the trunk's (and the crown's height) multiplier; wide: the crown's across (X and Z) on top of that.
Grades.Kinds=table.freeze({
	round=table.freeze({trunk=1.35,wide=1.45/1.35}),
	tall=table.freeze({trunk=1.35,wide=1.45/1.35}),
	rim=table.freeze({trunk=1.6,wide=1.45/1.35}),
	blossom=table.freeze({trunk=1.15,wide=1}),
	landmark=table.freeze({trunk=1,wide=1}),
})
Grades.Rim=table.freeze({Tree_01_round=true,Tree_13_round=true,Tree_20_round=true})
Grades.Vary=.05
-- The leaf litter under a graded tree: today's 5 across times the trunk's grade, at most LitterMost (Fable: 5 to 6.5).
Grades.LitterMost=6.5

local function hash(text)
	local h=5381
	for k=1,#text do h=(h*33+string.byte(text,k))%2147483647 end
	local x=math.sin(h*12.9898)*43758.5453
	return x-math.floor(x)
end
-- Pure: a tree's kind by its name.
function Grades.kind(tree)
	if type(tree)~="string"or string.sub(tree,1,9)=="Landmark_"then return "landmark"end
	if Grades.Rim[tree]then return "rim"end
	if string.find(tree,"_round",1,true)then return "round"end
	if string.find(tree,"_tall",1,true)then return "tall"end
	if string.find(tree,"_blossom",1,true)then return "blossom"end
	return "landmark"
end
-- Pure: {trunk, tall, wide} for a tree: trunk the trunk's scale multiplier, tall the crown's height multiplier (the
-- trunk's), wide the crown's across multiplier (tall x Kinds.wide). Landmarks and unknown trees: 1, 1, 1 (no +-5%).
function Grades.of(tree)
	local kind=Grades.kind(tree)
	local K=Grades.Kinds[kind]
	if kind=="landmark"then return table.freeze({trunk=1,tall=1,wide=1})end
	local vary=1+Grades.Vary*(2*hash(tree)-1)
	local trunk=K.trunk*vary
	return table.freeze({trunk=trunk,tall=trunk,wide=trunk*K.wide})
end

-- The trunk pack's data (WorldAeroTrunks), or nil when it cannot be read.
function Grades.trunks()
	local ok,data=pcall(function()return require(Shared:FindFirstChild("WorldAeroTrunks"))end)
	if ok and type(data)=="table"and type(data.trunks)=="table"and type(data.meshes)=="table"then return data end
	return nil
end
-- Is the trunk pack confirmed (ids uploaded and read back)? data: WorldAeroTrunks (nil reads it).
function Grades.ready(data)
	data=data or Grades.trunks()
	return type(data)=="table"and data.ready==true and type(data.trunks)=="table"and #data.trunks>0
end
-- Are the grades on: the pack ready and the Alive `scene` switch on. Never throws.
function Grades.on(data)
	if not Grades.ready(data)then return false end
	local ok,on=pcall(function()
		local Alive=require(Shared.Alive)
		return Alive.on(Grades.Feature)
	end)
	return ok and on==true
end

local function vector(list)return Vector3.new(list[1],list[2],list[3])end
local function list(v)return{v.X,v.Y,v.Z}end
local graded=setmetatable({},{__mode="k"})
-- Pure: the Aero kit's data (WorldAeroKit) graded, or `kit` itself when `on` is false. Each graded crown keeps its
-- fields and gets: pivot (moved up its grown trunk: root + (pivot - root) x trunk), scale (x tall), wide (its across
-- on top of scale), trunk (the trunk's own scale: its placement's x trunk), grade. Crowns without a trunk row (the
-- landmarks, a tree the pack does not hold) are left as they are, with trunk = their scale. Cached per kit table.
function Grades.kit(kit,on,trunks)
	if not on or type(kit)~="table"or type(kit.crowns)~="table"then return kit end
	trunks=trunks or Grades.trunks()
	local cache=graded[kit]
	if cache and cache.trunks==trunks then return cache.out end
	local roots={}
	for _,row in ipairs(type(trunks)=="table"and trunks.trunks or {})do roots[row.tree]=row end
	local out=table.clone(kit)
	local crowns={}
	for i,crown in ipairs(kit.crowns)do
		local row=roots[crown.tree]
		local c=table.clone(crown)
		if row and type(row.root)=="table"then
			local g=Grades.of(crown.tree)
			local root,pivot=vector(row.root),vector(crown.pivot)
			c.pivot=list(root+(pivot-root)*g.trunk)
			c.scale=crown.scale*g.tall
			c.wide=g.wide/g.tall
			c.trunk=(row.scale or crown.scale)*g.trunk
			c.grade=g
		else
			c.trunk=crown.scale
		end
		crowns[i]=table.freeze(c)
	end
	out.crowns=table.freeze(crowns)
	out.graded=true
	out=table.freeze(out)
	graded[kit]={trunks=trunks,out=out}
	return out
end
-- Pure: a crown's size multiplier as a Vector3 (X and Z by `wide`), from a kit crown (graded or not).
function Grades.scaleOf(crown)
	local s=crown.scale or 1
	local w=crown.wide or 1
	return Vector3.new(s*w,s,s*w)
end
-- Pure: the litter plate's size under tree `tree` (today's `size`): graded, x trunk, at most LitterMost.
function Grades.litter(tree,size,on)
	if not on then return size end
	local g=Grades.of(tree)
	if g.trunk==1 then return size end
	return math.min(Grades.LitterMost,size*g.trunk)
end
return table.freeze(Grades)
