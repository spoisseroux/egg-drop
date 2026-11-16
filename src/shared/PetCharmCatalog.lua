-- Cosmetic charm forms. The "dot" id renders the snowflake mesh (its label is Snowflake).
-- Stored future IDs survive even when this renderer cannot draw them.
--
-- Every shape carries a rule, checked with Catalog.usable(id, facts) (alias Catalog.earned):
--   facts = { stamps = <lifetime stamps>, claimed = <book milestone ids>, stats = <lifetime
--             counters>, bond = <petId -> xp>, charmUnlocks = <egg shape -> true> }
--             (Catalog.facts(state) builds it from a hatching save or its public snapshot)
-- Egg shapes (Customization Egg, plan 2026-11-16 §2.3): dot, ring and pebble are owned only when
-- the save's `charmUnlocks` holds them (rare egg drops; a save from before the egg keeps all
-- three, a new save starts with none). There are no free shapes any more.
-- Earned shapes (overnight 2026-11-14, slice D; SYSTEMS-SCOPE 4.3) are rule-derived and not
-- written to the save. Every earned rule is monotonic (claims, stamps and counters never go
-- down), so a shape once earned is always earned. Rule for later: an earned rule may only ever
-- be loosened; tightening one would take the charm away.
--   heart: the book's Wardrobe page claimed at 100%
--   star:  four weekly bonuses (stats.weeklyBonuses, counted from this build on)
--   leaf:  14 stamps (mesh shipped 2026-11-14: Bear__CharmLeaf, build_bear_charm_leaf.py).
--          Selectable like Heart and Star; Reserved is empty until the next held-back shape.
-- `mesh` names the authored charm mesh in PetAssets.Bear (PetCharms draws it); a shape
-- without its mesh in the place renders as the default. `Default` is only that render fallback
-- for an unknown stored shape: it does not mean owned.
local Catalog={Version=2,SelectionsEnabled=true,Default="dot",Order=table.freeze({"dot","ring","pebble","heart","star","leaf"}),
 ById=table.freeze({dot=table.freeze({name="Snowflake",rule="egg"}),ring=table.freeze({name="Ring",rule="egg"}),pebble=table.freeze({name="Pebble",rule="egg"}),
  heart=table.freeze({name="Heart",rule="wardrobe100",mesh="Bear__CharmHeart"}),
  star=table.freeze({name="Star",rule="weekly4",mesh="Bear__CharmStar"}),
  leaf=table.freeze({name="Leaf",rule="stamps14",mesh="Bear__CharmLeaf"})})}
Catalog.Rules=table.freeze({
 egg=table.freeze({kind="egg"}),
 wardrobe100=table.freeze({kind="claimed",id="wardrobe.100"}),
 weekly4=table.freeze({kind="stat",key="weeklyBonuses",need=4}),
 stamps14=table.freeze({kind="stamps",need=14}),
})
-- Customization Egg (plan 2026-11-16 §2.3): the shapes the egg can drop, in published order
-- (Snowflake, Ring, Pebble). Owned ones are saved in the hatching `charmUnlocks`.
Catalog.EggShapes=table.freeze({"dot","ring","pebble"})
-- Shapes held back until their art ships: rule ids reserved, never selectable.
Catalog.Reserved=table.freeze({})
function Catalog.known(id)return type(id)=="string"and Catalog.ById[id]~=nil end
function Catalog.validStored(id)return type(id)=="string"and #id>=1 and #id<=64 and id:match("^[a-z][a-z0-9_%-]*$")~=nil end
function Catalog.renderShape(id)return if Catalog.known(id)then id else Catalog.Default end
-- The rule row of a shape, or nil for an unknown shape.
function Catalog.rule(id)
 local entry=type(id)=="string"and Catalog.ById[id]
 return if entry and entry.rule then Catalog.Rules[entry.rule]else nil
end
local function count(value)return if type(value)=="number"and value==value and value>=0 then value else 0 end
-- have, need for a rule against facts (need is 1 for a claim or an egg shape).
local function measure(rule,facts,id)
 facts=if type(facts)=="table"then facts else {}
 if rule.kind=="egg"then
  return if type(facts.charmUnlocks)=="table"and facts.charmUnlocks[id]==true then 1 else 0,1
 elseif rule.kind=="claimed"then
  return if type(facts.claimed)=="table"and table.find(facts.claimed,rule.id)~=nil then 1 else 0,1
 elseif rule.kind=="stat"then
  return count(type(facts.stats)=="table"and facts.stats[rule.key]),rule.need
 elseif rule.kind=="stamps"then
  return count(facts.stamps),rule.need
 end
 return 0,1
end
-- True when the player may wear the shape: an egg shape once owned, an earned shape once its
-- rule is met. Unknown ids, and every shape without facts, are never usable (fails closed).
function Catalog.earned(id,facts)
 if not Catalog.known(id)then return false end
 local rule=Catalog.rule(id)
 if not rule then return true end
 local have,need=measure(rule,facts,id)
 return have>=need
end
-- Plan §2.3 name. `unlocks` (optional) stands in for facts.charmUnlocks.
function Catalog.usable(id,facts,unlocks)
 if unlocks~=nil then
  local merged=if type(facts)=="table"then table.clone(facts)else {}
  merged.charmUnlocks=unlocks;facts=merged
 end
 return Catalog.earned(id,facts)
end
function Catalog.isEggShape(id)return table.find(Catalog.EggShapes,id)~=nil end
-- Progress toward a shape for the UI: {have, need, earned}.
function Catalog.progress(id,facts)
 local rule=Catalog.rule(id)
 if not Catalog.known(id)then return {have=0,need=1,earned=false}end
 if not rule then return {have=1,need=1,earned=true}end
 local have,need=measure(rule,facts,id)
 return {have=math.min(have,need),need=need,earned=have>=need}
end
-- facts from a hatching save or its public snapshot (both carry stamps, stats, book.claimed,
-- bond and charmUnlocks).
function Catalog.facts(state)
 if type(state)~="table"then return {stamps=0,claimed={},stats={},bond={},charmUnlocks={}}end
 local book=state.book
 return {stamps=count(state.stamps),claimed=if type(book)=="table"and type(book.claimed)=="table"then book.claimed else {},
  stats=if type(state.stats)=="table"then state.stats else {},bond=if type(state.bond)=="table"then state.bond else {},
  charmUnlocks=if type(state.charmUnlocks)=="table"then state.charmUnlocks else {}}
end
return table.freeze(Catalog)
