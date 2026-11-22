-- Deck juice (V3-LEVELS-BUILD-PLAN-2026-11-22, S3). Data and rules only: which merge pop, drop trail
-- and start flourish a player may pick. Cosmetic: the sim, the score, the RNG and the board hash never
-- read this. An id is unlocked by any owned pet's level; "classic" (today's look) is always there.
-- Ids and kinds are append-only, levels may only be lowered.
--
-- The saved choice is profile.deckJuice = {pop=id, trail=id, start=id} (PlayerProgress): missing is
-- classic, unknown ids are kept (a later build may know them) and draw as classic.
local Shared=script.Parent
local Gate=require(Shared.LevelGate)
local Levels=require(Shared.Levels)
local Juice={}
Juice.Classic="classic"
Juice.Attribute="DeckJuice" -- the board attribute: JSON {pop, trail, start} after resolve; nil while off
Juice.Kinds=table.freeze({"pop","trail","start"})
Juice.IdLength=32
Juice.KindLength=16
Juice.KindLimit=8 -- frozen: kinds kept from a later build
local rows={
 {id="confetti",kind="pop",name="Confetti",gate={stat="power",level=5}},
 {id="fizz",kind="pop",name="Fizz",gate={stat="power",level=15}},
 {id="bubble",kind="trail",name="Bubble trail",gate={stat="power",level=30}},
 {id="comet",kind="trail",name="Comet trail",gate={stat="power",level=45}},
 {id="ready",kind="start",name="Ready, steady",gate={stat="energy",level=5}},
 {id="lightning",kind="start",name="Lightning lid",gate={stat="energy",level=20}},
}
local byId,byKind={},{}
for _,kind in ipairs(Juice.Kinds)do byId[kind]={};byKind[kind]={}end
for index,row in ipairs(rows)do
 assert(byId[row.kind]and not byId[row.kind][row.id]and row.id~=Juice.Classic and #row.id<=Juice.IdLength and Gate.valid(row.gate),"DeckJuiceCatalog: row "..index)
 table.freeze(row.gate);table.freeze(row)
 byId[row.kind][row.id]=row;table.insert(byKind[row.kind],row)
end
for _,kind in ipairs(Juice.Kinds)do table.freeze(byId[kind]);table.freeze(byKind[kind])end
Juice.Rows=table.freeze(rows)
Juice.ByKind=table.freeze(byKind)

function Juice.row(kind,id)
 local set=type(kind)=="string"and byId[kind]
 return if set and type(id)=="string"then set[id]else nil
end
function Juice.isKind(kind)return type(kind)=="string"and byId[kind]~=nil end
-- A choice this build knows: a row of that kind, or classic.
function Juice.known(kind,id)
 return Juice.isKind(kind)and(id==Juice.Classic or Juice.row(kind,id)~=nil)
end
-- Unlocked for these levels ({petId={statId=level}}). Nothing but classic while the part is off.
function Juice.unlocked(kind,id,levels)
 if not Juice.isKind(kind)then return false end
 if id==Juice.Classic then return true end
 local row=Juice.row(kind,id)
 return row~=nil and Levels.on("juice")and Gate.met(levels,row.gate)
end
-- The saved table as this build reads it: well-formed short strings (unknown kinds and ids kept,
-- at most KindLimit, this build's kinds first), nil when nothing is left.
function Juice.decode(value)
 if type(value)~="table"then return nil end
 local out,n={},0
 local function take(kind)
  local id=value[kind]
  if n<Juice.KindLimit and type(id)=="string"and #id>=1 and #id<=Juice.IdLength then out[kind]=id;n+=1 end
 end
 for _,kind in ipairs(Juice.Kinds)do take(kind)end
 local others={}
 for kind in pairs(value)do
  if type(kind)=="string"and #kind>=1 and #kind<=Juice.KindLength and not byId[kind]then table.insert(others,kind)end
 end
 table.sort(others)
 for _,kind in ipairs(others)do take(kind)end
 return if n>0 then out else nil
end
-- What every client draws: each kind's saved id if it is known and unlocked, else classic.
function Juice.resolve(saved,levels)
 local out={}
 for _,kind in ipairs(Juice.Kinds)do
  local id=type(saved)=="table"and saved[kind]or nil
  out[kind]=if type(id)=="string"and Juice.unlocked(kind,id,levels)then id else Juice.Classic
 end
 return out
end
return table.freeze(Juice)
