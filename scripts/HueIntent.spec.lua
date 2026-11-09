-- Captured fixed-item operations and receipt/snapshot ordering, without remotes.
return function(client)
 local Intent=require(client.HueIntent);local H=require(game.ReplicatedStorage.Shared.HueCatalog)
 local cases={};local function test(n,f)f();table.insert(cases,n)end
 local function state(rev)return {revision=rev or 7,status="Ready",nectar=24,inventoryMask=127,petHues={pip={main=H.emptyCounts(),secondary=H.emptyCounts()}},hueInventory={rose=3,tide=1,citrus=0,iris=0,reset=2}}end
 local function fixture(s)
  local f={sent={},serial=0};f.intent=Intent.new({id=function()f.serial+=1;return "i"..f.serial end,send=function(a,v,r)table.insert(f.sent,{action=a,value=v,revision=r})end});f.intent:update(s or state());return f
 end
 local function proof(f,revision)
  local p=f.intent.pending;return {id=p.value.id,action=p.action,petId=p.value.petId,revision=revision or 8}
 end
 test("Hue purchase captures catalog and one operation without client-selected roll",function()
  local f=fixture();assert(f.intent:hatch());assert(not f.intent:hatch());assert(#f.sent==1);local v=f.sent[1].value
  assert(v.catalogVersion==H.CatalogVersion and v.itemId==nil and v.petId==nil and v.id:match("^7:"))
 end)
 test("pending result routes to exact acknowledgment and prevents another purchase",function()
  local s=state();s.pendingHueResult={id="result-A",itemId="rose"};local f=fixture(s)
  assert(not f.intent:hatch());assert(not f.intent:store("result-B"));assert(f.intent:store("result-A"));assert(f.sent[1].value.resultId=="result-A")
 end)
 test("Use binds pet channel counts and exact pending result without mutating snapshot",function()
  local s=state();s.petHues.pip.secondary.rose=2;local f=fixture(s)
  assert(f.intent:use("pip","secondary","rose","result-A"));local v=f.sent[1].value
  assert(v.petId=="pip"and v.channel=="secondary"and v.counts.rose==2 and v.pendingResultId=="result-A")
  v.counts.rose=4;assert(s.petHues.pip.secondary.rose==2 and s.hueInventory.rose==3)
 end)
 test("reply before snapshot stays pending; matching saved revision resolves",function()
  local f=fixture();assert(f.intent:use("pip","main","rose"));local r=proof(f)
  assert(f.intent:receive({id=r.id,petId="pip",action=r.action,status="Saved",receipt=r}));assert(f.intent.pending)
  f.intent:update(state(8));assert(not f.intent.pending and f.intent.receipt==r)
  assert(not f.intent:update(state(6))and f.intent.state.revision==8)
 end)
 test("snapshot before reply resolves exact committed operation",function()
  local f=fixture();assert(f.intent:use("pip","main","reset"));local r=proof(f);local s=state(8);s.lastHueResult=r;f.intent:update(s)
  assert(not f.intent.pending and f.intent.receipt==r)
 end)
 test("retry reuses complete original payload; rejection releases next genuine operation",function()
  local f=fixture();assert(f.intent:use("pip","secondary","reset"));local p=f.intent.pending
  assert(f.intent:receive({id=p.value.id,petId="pip",action=p.action,status="Retrying"}));assert(f.intent:retry());assert(f.sent[1].value==f.sent[2].value and f.sent[1].revision==f.sent[2].revision)
  assert(f.intent:receive({id=p.value.id,petId="pip",action=p.action,status="Rejected",reason="RevisionChanged"}));assert(not f.intent.pending);assert(f.intent:use("pip","main","tide"));assert(f.sent[3].value.id~=p.value.id)
 end)
 test("ordinary inventory operation omits pending receipt association",function()
  local f=fixture();assert(f.intent:use("pip","main","rose"));assert(f.sent[1].value.pendingResultId==nil)
 end)
 test("legacy redemption binds migration and exact paid token and purchase",function()
  local s=state();s.hueMigrationId="migration-1";s.legacyHueEgg={token="token-1",purchaseId="purchase-1"};local f=fixture(s)
  assert(f.intent:legacyRedeem("iris"));local v=f.sent[1].value;assert(v.migrationId=="migration-1"and v.token=="token-1"and v.purchaseId=="purchase-1"and v.itemId=="iris")
 end)
 return cases
end
