-- Pet names (v2, V2-CUTE-ICONS-AND-NAMES-2026-11-20 section 2). A name is one or two curated
-- pieces; nobody ever types. Pieces belong to the account; the chosen name is saved per pet
-- (server: NameState). The server stores and sends piece ids, never text; every client builds
-- the text from this catalogue, so there is nothing to filter (see the text-filter note in
-- PLAY-BUILD / TODO for 2026-11-20).
--
-- Frozen at ship (architect review 2026-11-20): piece ids and their order are APPEND-ONLY and an
-- id is never reused or renamed (display text may change). A piece is retired with
-- `retired=true`, never deleted: it leaves the Names Egg pool but stays owned, usable and shown.
-- EggOrder (the restricted players' fixed order) is the egg pieces in catalogue order, so it is
-- append-only too. Bump PoolVersion whenever the egg pool's membership, a retirement or Price
-- changes (scripts/NameCatalog.spec.lua checks the ids against a committed golden list).
--
-- Lanes: starter (free with the first pet), egg (Names Egg, 8 Stars, never a duplicate), stat
-- (any owned pet reaches the level), keeper (the best owned pet's total level; Champion: any
-- stat of any owned pet at 99), book (claimed collection book milestones).
local Catalog={}

Catalog.Version=1
Catalog.PoolVersion=1
Catalog.Price=8
Catalog.MaxPieces=2 -- a name is one or two different pieces
Catalog.Attribute="PetNames" -- the public board attribute: {v=1, pets={[petId]={ids}}}
Catalog.LaneOrder=table.freeze({"starter","egg","stat","keeper","book"})

local pieces={
	-- Starter (6).
	{id="biscuit",text="Biscuit",lane="starter"},{id="puddle",text="Puddle",lane="starter"},
	{id="tuesday",text="Tuesday",lane="starter"},{id="parade",text="Parade",lane="starter"},
	{id="button",text="Button",lane="starter"},{id="sprinkle",text="Sprinkle",lane="starter"},
	-- Names Egg (20), in the restricted fixed order.
	{id="velvet",text="Velvet",lane="egg"},{id="sidequest",text="Sidequest",lane="egg"},
	{id="bureau",text="Bureau",lane="egg"},{id="mooncrumb",text="Mooncrumb",lane="egg"},
	{id="almost",text="Almost",lane="egg"},{id="marmalade",text="Marmalade",lane="egg"},
	{id="teacup",text="Teacup",lane="egg"},{id="thunderbun",text="Thunderbun",lane="egg"},
	{id="noodle",text="Noodle",lane="egg"},{id="overture",text="Overture",lane="egg"},
	{id="pocketful",text="Pocketful",lane="egg"},{id="moonboots",text="Moonboots",lane="egg"},
	{id="crumpet",text="Crumpet",lane="egg"},{id="detour",text="Detour",lane="egg"},
	{id="waffle",text="Waffle",lane="egg"},{id="stardust",text="Stardust",lane="egg"},
	{id="dumpling",text="Dumpling",lane="egg"},{id="keepsake",text="Keepsake",lane="egg"},
	{id="apricot",text="Apricot",lane="egg"},{id="afterparty",text="Afterparty",lane="egg"},
	-- Stats (18): per stat, levels 10, 25 and 50 on any owned pet.
	{id="cuddle",text="Cuddle",lane="stat",stat="heart",level=10},{id="sweetpea",text="Sweetpea",lane="stat",stat="heart",level=25},
	{id="heartsong",text="Heartsong",lane="stat",stat="heart",level=50},
	{id="bonk",text="Bonk",lane="stat",stat="power",level=10},{id="mighty",text="Mighty",lane="stat",stat="power",level=25},
	{id="thunderpaw",text="Thunderpaw",lane="stat",stat="power",level=50},
	{id="fizz",text="Fizz",lane="stat",stat="energy",level=10},{id="sparky",text="Sparky",lane="stat",stat="energy",level=25},
	{id="lightning",text="Lightning",lane="stat",stat="energy",level=50},
	{id="boing",text="Boing",lane="stat",stat="jump",level=10},{id="hopscotch",text="Hopscotch",lane="stat",stat="jump",level=25},
	{id="moonbounce",text="Moonbounce",lane="stat",stat="jump",level=50},
	{id="zoomies",text="Zoomies",lane="stat",stat="speed",level=10},{id="speedy",text="Speedy",lane="stat",stat="speed",level=25},
	{id="rocket",text="Rocket",lane="stat",stat="speed",level=50},
	{id="hmm",text="Hmm",lane="stat",stat="smarts",level=10},{id="clever",text="Clever",lane="stat",stat="smarts",level=25},
	{id="professor",text="Professor",lane="stat",stat="smarts",level=50},
	-- Keeper tiers (4): the best owned pet's total level; Champion is any stat at 99.
	{id="sprout",text="Sprout",lane="keeper",total=60},{id="bloom",text="Bloom",lane="keeper",total=150},
	{id="starbloom",text="Starbloom",lane="keeper",total=450},{id="champion",text="Champion",lane="keeper",anyLevel=99},
	-- Book (4): claimed collection book milestones (24 at ship; claims are never removed).
	{id="dogear",text="Dogear",lane="book",claimed=1},{id="bookworm",text="Bookworm",lane="book",claimed=10},
	{id="footnote",text="Footnote",lane="book",claimed=12},{id="librarian",text="Librarian",lane="book",claimed=24},
}
local byId,eggOrder,laneCount={},{},{}
for index,piece in ipairs(pieces)do
	piece.index=index
	assert(byId[piece.id]==nil,"duplicate name piece id "..piece.id)
	byId[piece.id]=table.freeze(piece)
	laneCount[piece.lane]=(laneCount[piece.lane]or 0)+1
	if piece.lane=="egg"then table.insert(eggOrder,piece.id)end
end
for index,piece in ipairs(pieces)do pieces[index]=byId[piece.id]end
Catalog.Pieces=table.freeze(pieces)
Catalog.ById=table.freeze(byId)
Catalog.EggOrder=table.freeze(eggOrder)
Catalog.LaneCount=table.freeze(laneCount)

function Catalog.piece(id)return if type(id)=="string"then byId[id]else nil end
function Catalog.text(id)local piece=Catalog.piece(id);return piece and piece.text or nil end
local function isOwned(owned,id)
	if type(owned)~="table"then return false end
	if owned[id]==true then return true end
	return table.find(owned,id)~=nil
end
-- A set from an owned list (or a set already).
function Catalog.ownedSet(owned)
	local set={}
	if type(owned)=="table"then
		for key,value in pairs(owned)do
			if type(value)=="string"then set[value]=true elseif value==true and type(key)=="string"then set[key]=true end
		end
	end
	return set
end

-- The text of a name from its ids. Any unknown id (an older catalogue on this client) shows the
-- fallback for the whole name, never half a name. Nil or empty ids = the fallback.
function Catalog.display(ids,fallback)
	if type(ids)~="table"or #ids==0 or #ids>Catalog.MaxPieces then return fallback end
	local words={}
	for _,id in ipairs(ids)do
		local text=Catalog.text(id)
		if not text then return fallback end
		table.insert(words,text)
	end
	return table.concat(words," ")
end

-- A valid choice for a rename: 0..2 known, distinct ids, each owned. Returns ok, reason.
function Catalog.validChoice(ids,owned)
	if type(ids)~="table"or #ids>Catalog.MaxPieces then return false,"InvalidName"end
	local count=0;for _ in pairs(ids)do count+=1 end
	if count~=#ids then return false,"InvalidName"end
	local seen={}
	for _,id in ipairs(ids)do
		if not byId[id]then return false,"UnknownPiece"end
		if seen[id]then return false,"SamePiece"end
		seen[id]=true
		if not isOwned(owned,id)then return false,"NotOwned"end
	end
	return true
end

-- Earned pieces (stat, keeper, book) for `progress` = {levels = { {statId=level,...} per owned
-- pet }, claimed = n}. Catalogue order, so the order ids are added is the same on every retry.
function Catalog.earned(piece,progress)
	local levels=type(progress)=="table"and type(progress.levels)=="table"and progress.levels or {}
	if piece.lane=="stat"then
		for _,pet in ipairs(levels)do if type(pet[piece.stat])=="number"and pet[piece.stat]>=piece.level then return true end end
		return false
	elseif piece.lane=="keeper"then
		for _,pet in ipairs(levels)do
			if piece.anyLevel then
				for _,level in pairs(pet)do if type(level)=="number"and level>=piece.anyLevel then return true end end
			else
				local total=0;for _,level in pairs(pet)do if type(level)=="number"then total+=level end end
				if total>=piece.total then return true end
			end
		end
		return false
	elseif piece.lane=="book"then
		return type(progress.claimed)=="number"and progress.claimed>=piece.claimed
	end
	return false
end
function Catalog.earnedIds(progress)
	local result={}
	for _,piece in ipairs(pieces)do
		if(piece.lane=="stat"or piece.lane=="keeper"or piece.lane=="book")and Catalog.earned(piece,progress)then table.insert(result,piece.id)end
	end
	return result
end
function Catalog.starterIds()
	local result={}
	for _,piece in ipairs(pieces)do if piece.lane=="starter"then table.insert(result,piece.id)end end
	return result
end

-- The Names Egg pool: egg pieces not owned and not retired, in EggOrder.
function Catalog.remaining(owned)
	local set=Catalog.ownedSet(owned)
	local result={}
	for _,id in ipairs(eggOrder)do if not set[id]and not byId[id].retired then table.insert(result,id)end end
	return result
end
function Catalog.selectionMode(restricted)return if restricted==false then "random"else "fixed"end
-- Fixed mode: the first piece of the pool. Random: one equally likely piece from `unit` in [0, 1).
function Catalog.pick(remaining,mode,unit)
	local n=#remaining
	if n==0 then return nil end
	if mode~="random"then return remaining[1]end
	if type(unit)~="number"or unit~=unit then return nil end
	return remaining[math.clamp(math.floor(unit*n)+1,1,n)]
end
-- The quote the card showed. Any commit moves the count and serial, so a stale quote is
-- "PoolChanged" with no charge. At most ~40 characters (the request caps it at 64).
function Catalog.quoteKey(mode,remaining,serial)
	local n=if type(remaining)=="table"then #remaining else 0
	local nextId=if mode~="random"and n>0 then remaining[1]else ""
	return string.format("%d|%d|%s|%d|%s|%d",Catalog.PoolVersion,Catalog.Price,if mode=="random"then "r"else "f",n,nextId,
		if type(serial)=="number"and serial==serial and serial>=0 and serial%1==0 then serial else 0)
end

-- What unlocks a piece, for the locked tile and the hint: {lane, stat?, level?, total?, anyLevel?, claimed?}.
function Catalog.requirement(id)
	local piece=Catalog.piece(id)
	if not piece then return nil end
	return {lane=piece.lane,stat=piece.stat,level=piece.level,total=piece.total,anyLevel=piece.anyLevel,claimed=piece.claimed}
end

return table.freeze(Catalog)
