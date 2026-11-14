-- Cosmetic charm forms. The "dot" id renders the snowflake mesh (its label is Snowflake).
-- Stored future IDs survive even when this renderer cannot draw them.
--
-- Free shapes (dot, ring, pebble) have no rule. Earned shapes (overnight 2026-11-14, slice D;
-- SYSTEMS-SCOPE 4.3) carry a rule and are checked statelessly with Catalog.earned(id, facts):
--   facts = { stamps = <lifetime stamps>, claimed = <book milestone ids>, stats = <lifetime
--             counters>, bond = <petId -> xp> }   (Catalog.facts(state) builds it)
-- Every rule is monotonic (claims, stamps and counters never go down), so a shape once
-- earned is always earned and nothing is written to the save.
--   heart: the book's Wardrobe page claimed at 100%
--   star:  four weekly bonuses (stats.weeklyBonuses, counted from this build on)
--   leaf:  14 stamps. Its rule is here for the server and the UI, but it stays out of
--          Order and ById until its mesh ships (VISUAL-BRIEF 3: Leaf is new art).
-- `mesh` names the authored charm mesh in PetAssets.Bear (PetCharms draws it); a shape
-- without its mesh in the place renders as the default.
local Catalog={Version=2,SelectionsEnabled=true,Default="dot",Order=table.freeze({"dot","ring","pebble","heart","star"}),
 ById=table.freeze({dot=table.freeze({name="Snowflake"}),ring=table.freeze({name="Ring"}),pebble=table.freeze({name="Pebble"}),
  heart=table.freeze({name="Heart",rule="wardrobe100",mesh="Bear__CharmHeart"}),
  star=table.freeze({name="Star",rule="weekly4",mesh="Bear__CharmStar"})})}
Catalog.Rules=table.freeze({
 wardrobe100=table.freeze({kind="claimed",id="wardrobe.100"}),
 weekly4=table.freeze({kind="stat",key="weeklyBonuses",need=4}),
 stamps14=table.freeze({kind="stamps",need=14}),
})
-- Shapes held back until their art ships: rule ids reserved, never selectable.
Catalog.Reserved=table.freeze({leaf=table.freeze({name="Leaf",rule="stamps14",mesh="Bear__CharmLeaf"})})
function Catalog.known(id)return type(id)=="string"and Catalog.ById[id]~=nil end
function Catalog.validStored(id)return type(id)=="string"and #id>=1 and #id<=64 and id:match("^[a-z][a-z0-9_%-]*$")~=nil end
function Catalog.renderShape(id)return if Catalog.known(id)then id else Catalog.Default end
-- The rule row of a shape, or nil for a free (or unknown) shape.
function Catalog.rule(id)
 local entry=type(id)=="string"and Catalog.ById[id]
 return if entry and entry.rule then Catalog.Rules[entry.rule]else nil
end
local function count(value)return if type(value)=="number"and value==value and value>=0 then value else 0 end
-- have, need for a rule against facts (need is 1 for a claim).
local function measure(rule,facts)
 facts=if type(facts)=="table"then facts else {}
 if rule.kind=="claimed"then
  return if type(facts.claimed)=="table"and table.find(facts.claimed,rule.id)~=nil then 1 else 0,1
 elseif rule.kind=="stat"then
  return count(type(facts.stats)=="table"and facts.stats[rule.key]),rule.need
 elseif rule.kind=="stamps"then
  return count(facts.stamps),rule.need
 end
 return 0,1
end
-- True when the player may select the shape: a free shape always, an earned shape once its
-- rule is met. Unknown ids are never earned.
function Catalog.earned(id,facts)
 if not Catalog.known(id)then return false end
 local rule=Catalog.rule(id)
 if not rule then return true end
 local have,need=measure(rule,facts)
 return have>=need
end
-- Progress toward a shape for the UI: {have, need, earned}; free shapes are {1, 1, true}.
function Catalog.progress(id,facts)
 local rule=Catalog.rule(id)
 if not Catalog.known(id)then return {have=0,need=1,earned=false}end
 if not rule then return {have=1,need=1,earned=true}end
 local have,need=measure(rule,facts)
 return {have=math.min(have,need),need=need,earned=have>=need}
end
-- facts from a hatching save or its public snapshot (both carry stamps, stats, book.claimed
-- and, once bond levels ship, bond).
function Catalog.facts(state)
 if type(state)~="table"then return {stamps=0,claimed={},stats={},bond={}}end
 local book=state.book
 return {stamps=count(state.stamps),claimed=if type(book)=="table"and type(book.claimed)=="table"then book.claimed else {},
  stats=if type(state.stats)=="table"then state.stats else {},bond=if type(state.bond)=="table"then state.bond else {}}
end
return table.freeze(Catalog)
