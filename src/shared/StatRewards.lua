-- What each stat level brings (V3-LEVELS-BUILD-PLAN-2026-11-22, S1). Pure and derived: nothing is
-- saved or claimed for a reward. Rows come from the catalogues that own them (name pieces, tricks,
-- level gates, medals, garden perks, deck juice) plus one hand row; a row exists only while its part
-- is on (Levels) and its catalogue row ships.
--
-- Row: { id, stat, level, kind, copy, part, ref, name?, nameCopy?, area? }
--   kind     "medal" | "gate" | "trick" | "juice" | "look" | "book" | "name". A "gate" is bought with
--            Stars once the level is reached; everything else is free.
--   copy     the UICopy key of its line; `name` (catalogue English) or `nameCopy` (another UICopy key)
--            fills {name}. Rewards.text(row, UICopy.get) does both.
--   ref      the id in its own catalogue (item, theme, plate, piece, trick, tier, perk or juice id)
--   area     gate rows: "wardrobe" | "balls" | "plates" (which shop); juice rows: the juice kind
local Shared=script.Parent
local Stats=require(Shared.StatCatalog)
local Levels=require(Shared.Levels)
local Names=require(Shared.NameCatalog)
local Bond=require(Shared.BondCatalog)
local Variants=require(Shared.WearableVariants)
local Balls=require(Shared.BallThemes)
local Plates=require(Shared.DeckThemes)
local Medals=require(Shared.Medals)
local Perks=require(Shared.ParkPerks)
local Juice=require(Shared.DeckJuiceCatalog)
local Rewards={}
Rewards.Kinds=table.freeze({"medal","gate","trick","juice","look","book","name"}) -- also the order inside one level
Rewards.BookHintLevel=5 -- Smarts of the best pet: "where to find" on empty Book pages
local rank={};for index,kind in ipairs(Rewards.Kinds)do rank[kind]=index end

-- Every row of the parts that are on, unsorted.
local function collect()
 local rows={}
 local function add(row)
  row.order=#rows+1
  table.insert(rows,row)
 end
 if Levels.on("track")then
  for index,unlock in ipairs(Bond.Unlocks)do
   add({id="trick_"..unlock.id,stat="heart",level=Bond.HeartLevels[index],kind="trick",copy="stats.reward.trick",nameCopy=unlock.copy,part="track",ref=unlock.id})
  end
  for _,piece in ipairs(Names.Pieces)do
   if not piece.retired then
    if piece.lane=="stat"then
     add({id="name_"..piece.id,stat=piece.stat,level=piece.level,kind="name",copy="stats.reward.name",name=piece.text,part="track",ref=piece.id})
    elseif piece.lane=="keeper"and piece.anyLevel then
     for _,stat in ipairs(Stats.Order)do
      add({id="name_"..piece.id.."_"..stat,stat=stat,level=piece.anyLevel,kind="name",copy="stats.reward.name",name=piece.text,part="track",ref=piece.id})
     end
    end
   end
  end
  for _,perk in ipairs(Perks.Rows)do
   add({id=perk.id,stat=perk.stat,level=perk.level,kind="look",copy="stats.reward."..perk.id,part="track",ref=perk.id,area=perk.area})
  end
  add({id="bookHints",stat="smarts",level=Rewards.BookHintLevel,kind="book",copy="stats.reward.bookHints",part="track",ref="bookHints"})
 end
 if Levels.on("gates")then
  local function gated(id,entry,area)
   if entry and entry.gate and entry.gate.stat then
    add({id=area.."_"..id,stat=entry.gate.stat,level=entry.gate.level,kind="gate",copy="stats.reward.item",name=entry.name,part="gates",ref=id,area=area})
   end
  end
  for _,row in ipairs(Variants.Rows)do gated(row.id,row,"wardrobe")end
  for _,id in ipairs(Balls.Gated)do gated(id,Balls.ById[id],"balls")end
  for _,id in ipairs(Plates.Gated)do gated(id,Plates.ById[id],"plates")end
 end
 if Levels.on("medals")then
  for _,stat in ipairs(Stats.Order)do
   for _,tier in ipairs(Medals.Tiers)do
    add({id="medal_"..stat.."_"..tier.id,stat=stat,level=tier.level,kind="medal",copy="medal."..tier.id,part="medals",ref=tier.id})
   end
  end
 end
 if Levels.on("juice")then
  for _,row in ipairs(Juice.Rows)do
   if row.gate.stat then
    add({id="juice_"..row.id,stat=row.gate.stat,level=row.gate.level,kind="juice",copy="stats.reward."..row.id,part="juice",ref=row.id,area=row.kind})
   end
  end
 end
 return rows
end
local cache={}
local function index()
 local key=Levels.key()
 local found=cache[key]
 if found then return found end
 local byStat={};for _,stat in ipairs(Stats.Order)do byStat[stat]={}end
 for _,row in ipairs(collect())do table.insert(byStat[row.stat],row)end
 for _,list in pairs(byStat)do
  table.sort(list,function(a,b)
   if a.level~=b.level then return a.level<b.level end
   if a.kind~=b.kind then return rank[a.kind]<rank[b.kind]end
   return a.order<b.order
  end)
  for _,row in ipairs(list)do table.freeze(row)end
  table.freeze(list)
 end
 found=table.freeze(byStat)
 cache[key]=found
 return found
end
local empty=table.freeze({})
local function whole(value)return type(value)=="number"and value==value end

-- Every row of a stat, by level, then medal, gate, trick, juice, look, book, name.
function Rewards.forStat(stat)return index()[stat]or empty end
-- The first `count` rows above `level` (default 1).
function Rewards.upcoming(stat,level,count)
 local out={}
 if not whole(level)then return out end
 for _,row in ipairs(Rewards.forStat(stat))do
  if row.level>level then
   table.insert(out,row)
   if #out>=(count or 1)then break end
  end
 end
 return out
end
-- The next row above `level`, or nil (top level, or the parts are off).
function Rewards.next(stat,level)return Rewards.upcoming(stat,level,1)[1]end
-- Rows a level-up from `from` to `to` brings (from < row.level <= to).
function Rewards.earned(stat,from,to)
 local out={}
 if not whole(from)or not whole(to)then return out end
 for _,row in ipairs(Rewards.forStat(stat))do
  if row.level>from and row.level<=to then table.insert(out,row)end
 end
 return out
end
-- Total-level showpieces (not on a stat's track): {id, total, name, ref, area, kind = "gate"}.
function Rewards.totals()
 local out={}
 if Levels.on("gates")then
  for _,row in ipairs(Variants.Rows)do
   if row.gate and row.gate.total then
    table.insert(out,table.freeze({id="wardrobe_"..row.id,total=row.gate.total,kind="gate",copy="stats.reward.item",name=row.name,part="gates",ref=row.id,area="wardrobe"}))
   end
  end
  table.sort(out,function(a,b)return a.total<b.total end)
 end
 return out
end
-- The row's words. `get` is UICopy.get.
function Rewards.text(row,get)
 if row.nameCopy then return get(row.copy,{name=get(row.nameCopy)})end
 if row.name then return get(row.copy,{name=row.name})end
 return get(row.copy)
end
-- "Where to find" hints in the Book: any owned pet's Smarts ({petId={statId=level}}).
function Rewards.bookHints(levels)
 if not Levels.on("track")or type(levels)~="table"then return false end
 for _,row in pairs(levels)do
  if type(row)=="table"and whole(row.smarts)and row.smarts>=Rewards.BookHintLevel then return true end
 end
 return false
end
return table.freeze(Rewards)
