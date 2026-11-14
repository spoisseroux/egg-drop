-- Weekly shelf (overnight 2026-11-14, slice C; SYSTEMS-SCOPE 3.1). Three spotlighted items at
-- 20% off, picked from the catalogues by the week number alone: pure, deterministic, and no
-- server state. Server and client compute the same shelf from the same week.
--
--   Shelf.week(now)              the shelf week of a unix time (Monday start, 05:00 UTC roll,
--                                the same week as the weekly quests)
--   Shelf.weekOfDay(day)         the same from a day number (the snapshot's `dailyDay`)
--   Shelf.slots(week)            { {kind, id, full, price}, ... } up to three, in slot order;
--                                {} while FeatureFlags.WeeklyShelf is off
--   Shelf.price(kind, id, week)  the discounted price when `id` is on that week's shelf, else nil
--
-- kind is "wearable", "faceplate" or "ball". Slots:
--   1. a recolour variant (rows with from == week first, otherwise any released variant)
--   2. a wearable that is not a variant
--   3. a faceplate in even weeks, a ball theme in odd weeks
-- Never deluxe, book-only or free. A wearable's shelf price applies to that item id for any
-- pet that sells it; the pools are read from the Bear (ShelfPet), today's only seller.
-- Picks use rendezvous hashing: the highest hash(week, Salt, id) wins, so adding catalogue
-- items mid-week changes a slot only when the new item outranks the current pick. A slot
-- never shows its own previous pick again (when the pool has another choice).
local Shared=script.Parent
local Flags=require(Shared.FeatureFlags)
local Daily=require(Shared.DailyContracts)
local Rotation=require(Shared.QuestRotation)
local Wear=require(Shared.WearableCatalog)
local Variants=require(Shared.WearableVariants)
local Plates=require(Shared.DeckThemes)
local Balls=require(Shared.BallThemes)

local Shelf={Version=1,Salt=1,Discount=.2,ShelfPet="pip"}
Shelf.Kinds=table.freeze({"wearable","faceplate","ball"})

function Shelf.weekOfDay(day)return Rotation.week(tonumber(day)or 0)end
function Shelf.week(now)return Shelf.weekOfDay(Daily.dayOf(if type(now)=="number"then now else os.time()))end
-- 20% off, rounded to the nearest Star: 15 -> 12, 30 -> 24, 60 -> 48, 20 -> 16, 40 -> 32.
function Shelf.discounted(price)
 return price-math.floor(price*Shelf.Discount+.5)
end

-- FNV-1a over "week:salt:id" (32-bit; bit32.bxor and a split multiply keep it exact).
local function hash(week,salt,id)
 local text=tostring(week)..":"..tostring(salt)..":"..id
 local h=2166136261
 for i=1,#text do
  h=bit32.bxor(h,string.byte(text,i))
  -- h * 16777619 mod 2^32, without leaving the exact double range.
  local low=bit32.band(h,0xFFFF)
  local high=bit32.rshift(h,16)
  h=(low*16777619+(high*16777619%65536)*65536)%4294967296
 end
 return h
end
Shelf.hash=hash

-- Pools, each a list of {id, full} sorted by id. `week` gates variant rows that carry `from`.
function Shelf.pools(week)
 local variants,wearables,plates,balls={},{},{},{}
 for _,item in ipairs(Wear.forPet(Shelf.ShelfPet,week).order)do
  if type(item.price)=="number"and item.price>0 then
   if item.variant then
    local row=Variants.ById[item.id]
    table.insert(variants,{id=item.id,full=item.price,fresh=row~=nil and row.from==week})
   else table.insert(wearables,{id=item.id,full=item.price})end
  end
 end
 for _,id in ipairs(Plates.Order)do
  local price=Plates.price(id);local theme=Plates.ById[id]
  if price and theme and theme.tier~="deluxe"and not Plates.isBookOnly(id)then table.insert(plates,{id=id,full=price})end
 end
 for _,id in ipairs(Balls.Order)do
  local price=Balls.price(id);local theme=Balls.ById[id]
  if price and theme and theme.tier~="deluxe"then table.insert(balls,{id=id,full=price})end
 end
 local function byId(a,b)return a.id<b.id end
 table.sort(variants,byId);table.sort(wearables,byId);table.sort(plates,byId);table.sort(balls,byId)
 return {variant=variants,wearable=wearables,faceplate=plates,ball=balls}
end

-- The highest-hash row of a pool, skipping `avoid` when another row exists.
local function pick(pool,week,avoid)
 local best,bestHash
 for _,row in ipairs(pool)do
  if row.id~=avoid or #pool==1 then
   local h=hash(week,Shelf.Salt,row.id)
   if best==nil or h>bestHash or(h==bestHash and row.id<best.id)then best,bestHash=row,h end
  end
 end
 return best
end
-- Slot shapes: which pool a slot draws from in a week, and how far back its previous pick is
-- (slot 3 alternates kind, so its previous pick of the same kind is two weeks back).
Shelf.LookBack=12
local steps={1,1,2}
local function candidates(slot,week,pools)
 if slot==1 then
  local fresh={}
  for _,row in ipairs(pools.variant)do if row.fresh then table.insert(fresh,row)end end
  return if #fresh>0 then fresh else pools.variant,"wearable"
 elseif slot==2 then return pools.wearable,"wearable"end
 local kind=if week%2==0 then "faceplate"else "ball"
 return pools[kind],kind
end
-- The shelf for `week` from an explicit pool source (poolsOf(week) -> Shelf.pools shape).
-- Pure and uncached; the specs feed it altered catalogues.
--
-- A slot never repeats its previous pick: pick(week) is the best row that is not the
-- previous pick. That chain has no stored start, so it is anchored instead: walking back,
-- the first week whose best row is neither of the previous week's two best rows is certain
-- (the previous pick is always one of those two), and the picks are replayed forward from
-- there. The walk is usually zero or one step; LookBack bounds it.
function Shelf.compute(week,poolsOf)
 local memo={}
 local function poolsAt(w)
  local found=memo[w]
  if not found then found=poolsOf(w);memo[w]=found end
  return found
 end
 local result={}
 for slot=1,3 do
  local step=steps[slot]
  local start=week
  for _=1,Shelf.LookBack do
   local list=candidates(slot,start,poolsAt(start))
   local before=candidates(slot,start-step,poolsAt(start-step))
   local best=pick(list,start,nil)
   if best==nil or #list<=1 then break end
   local first=pick(before,start-step,nil)
   local second=if first then pick(before,start-step,first.id)else nil
   if(first==nil or best.id~=first.id)and(second==nil or best.id~=second.id)then break end
   start-=step
  end
  local current=pick((candidates(slot,start,poolsAt(start))),start,nil)
  for w=start+step,week,step do
   current=pick((candidates(slot,w,poolsAt(w))),w,current and current.id)
  end
  if current then
   local _,kind=candidates(slot,week,poolsAt(week))
   table.insert(result,table.freeze({kind=kind,id=current.id,full=current.full,price=Shelf.discounted(current.full)}))
  end
 end
 return table.freeze(result)
end
local cache={}
local empty=table.freeze({})
function Shelf.slots(week)
 if Flags.WeeklyShelf~=true or type(week)~="number"or week~=week or week%1~=0 or math.abs(week)>1e9 then return empty end
 local found=cache[week]
 if found then return found end
 local result=Shelf.compute(week,Shelf.pools)
 -- A small bounded memo (the catalogues are fixed for the life of a server).
 local n=0;for _ in pairs(cache)do n+=1 end
 if n>=16 then table.clear(cache)end
 cache[week]=result
 return result
end
function Shelf.price(kind,id,week)
 if type(kind)~="string"or type(id)~="string"then return nil end
 for _,slot in ipairs(Shelf.slots(week))do
  if slot.kind==kind and slot.id==id then return slot.price end
 end
 return nil
end
-- True when `id` of `kind` is on that week's shelf.
function Shelf.has(kind,id,week)return Shelf.price(kind,id,week)~=nil end
return table.freeze(Shelf)
