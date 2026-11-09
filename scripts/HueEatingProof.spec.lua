return function(client)
 local Proof=require(client.HueEatingProof);local H=require(game.ReplicatedStorage.Shared.HueCatalog);local cases={}
 local function test(n,f)f();table.insert(cases,n)end
 local function fixture()
  local counts=H.emptyCounts();counts.rose=2
  local p={action="hueUse",revision=10,value={id="10:bite",petId="puddle",itemId="rose",channel="secondary",counts=counts,pendingResultId="jar"}}
  local before={revision=10,hueInventory={rose=3}};local afterCounts=table.clone(counts);afterCounts.rose=3
  local r={id=p.value.id,action="hueUse",outcome="Applied",cost=0,catalogVersion=H.CatalogVersion,revision=11,petId="puddle",itemId="rose",channel="secondary",countsBefore=counts,countsAfter=afterCounts,inventoryBefore=3,inventoryAfter=2,acknowledgedResultId="jar"}
  local after={revision=11,hueInventory={rose=2},petHues={puddle={secondary=afterCounts}}}
  return Proof.new(),p,before,r,after
 end
 test("saved receipt waits for exact durable snapshot, then presents once",function()
  local proof,p,before,r,after=fixture();assert(proof:capture(p,before,"visible-1"))
  assert(not proof:take(r,before,"visible-1"));local token=proof:take(r,after,"visible-1");assert(token and token.petId=="puddle"and token.itemId=="rose")
  assert(not proof:take(r,after,"visible-1")and not proof:capture(p,before,"visible-1"))
 end)
 test("snapshot can arrive first; unrelated receipt never completes it",function()
  local proof,p,before,r,after=fixture();assert(proof:capture(p,before,"v"));local other=table.clone(r);other.id="other"
  assert(not proof:take(other,after,"v")and proof:take(r,after,"v"))
 end)
 test("wrong recipient, dose, stock, result ID or revision cannot start a bite",function()
  for _,mutate in ipairs({function(r)r.petId="pip"end,function(r)r.channel="main"end,function(r)r.itemId="tide"end,function(r)r.acknowledgedResultId="other"end,function(r)r.revision=10 end,function(r)r.inventoryBefore=4;r.inventoryAfter=3 end,function(r)r.countsAfter=H.emptyCounts()end})do
   local proof,p,before,r,after=fixture();proof:capture(p,before,"v");mutate(r);assert(not proof:take(r,after,"v"))
  end
 end)
 test("reset, capped, empty stock and page-open receipts never arm",function()
  local proof,p,before,r,after=fixture();assert(not proof:take(r,after,"v"));p.value.itemId="reset";assert(not proof:capture(p,before,"v"))
  p.value.itemId="rose";p.value.counts.rose=5;assert(not proof:capture(p,before,"v"));p.value.counts.rose=2;before.hueInventory.rose=0;assert(not proof:capture(p,before,"v"))
 end)
 test("cancel, layout or recipient generation replacement retires outstanding presentation",function()
  local proof,p,before,r,after=fixture();proof:capture(p,before,"old");assert(not proof:take(r,after,"new")and not proof:take(r,after,"old"))
  proof:capture(p,before,"new");proof:cancel();assert(not proof:take(r,after,"new"))
 end)
 return cases
end
