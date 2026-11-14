-- Studio Server. QA v2 R4.4: the free "Original colour" reset (hueClear). One channel
-- back to empty doses, no jar and no Stars, server-validated (owned pet, exact current
-- counts, not already original), idempotent by id, and its receipt keeps the saved
-- hatching record valid. Isolated stores only (the HueProgress fixture).
-- Usage: require(ServerScriptService.Server.ZZSpecs.HueClear)(ServerScriptService.Server)
return function(server)
 local H=require(server.HatchProgress);local S=require(server.HueState)
 local Hue=require(game.ReplicatedStorage.Shared.HueCatalog)
 local cases={};local function test(name,f)f();table.insert(cases,name)end
 local function copy(x)if type(x)~="table"then return x end;local r={};for k,v in pairs(x)do r[k]=copy(v)end;return r end
 local function fixture()
  local db={player_1={rank=4,trials=31}}
  local c={now=1000,n=0,rolls=0,unit=.01}
  local a={now=function()return c.now end,guid=function()c.n+=1;return"server-"..c.n end,random=function()c.rolls+=1;return c.unit end,wait=function()end}
  a.update=function(key,transform)local output=transform(copy(db[key]));if output then db[key]=copy(output)end;return copy(output)end
  local h=H.load(1,{},a);assert(h.status=="Ready");for n=1,30 do assert(H.award(h,n,8))end
  return h,c
 end
 local function request(h,fields)
  local r=h.state.revision;local v=copy(fields or{});v.id=v.id or(tostring(r)..":clear-"..tostring(h.state.operationSeq+1));v.catalogVersion=Hue.CatalogVersion;return v,r
 end
 local function command(h,action,fields)
  local q,r=request(h,fields);local ok,why,receipt=H.hueCommand(h,action,q,r);assert(ok,why);assert(S.valid(h.state),"invalid state after "..action);return q,r,receipt
 end
 local function dose(h,c,item,pet,channel)
  c.unit=(table.find(Hue.RollOrder,item)-.5)/#Hue.RollOrder;command(h,"hueBuy",{})
  command(h,"hueUse",{itemId=item,petId=pet,channel=channel,counts=S.row(h.state,pet)[channel],pendingResultId=h.state.pendingHueResult.id})
 end
 test("clears one channel for free: no Stars, no jars, the other channel kept",function()
  local h,c=fixture();dose(h,c,"rose","pip","main");dose(h,c,"rose","pip","main");dose(h,c,"tide","pip","secondary")
  local stars,jars=h.state.nectar,copy(h.state.hueInventory)
  assert(h.state.petHues.pip.main.rose==2 and h.state.petHues.pip.legacyLocked.main==true)
  local q,r,receipt=command(h,"hueClear",{petId="pip",channel="main",counts=S.row(h.state,"pip").main})
  assert(Hue.doseStrength(h.state.petHues.pip.main)==0 and h.state.petHues.pip.secondary.tide==1,"one channel only")
  assert(h.state.nectar==stars and h.state.hueInventory.rose==jars.rose and h.state.hueInventory.reset==jars.reset,"free")
  assert(h.state.petHues.pip.legacyLocked.main==false,"like a Reset Hue jar, the channel unlocks")
  assert(receipt and receipt.cost==0 and receipt.action=="hueClear"and receipt.countsBefore.rose==2)
  local ok,why=H.hueCommand(h,"hueClear",q,r);assert(ok and why=="AlreadySaved","replay is the saved proof")
 end)
 test("refuses already-original, stale counts, unowned or malformed requests without writing",function()
  local h,c=fixture();dose(h,c,"citrus","pip","main")
  local revision=h.state.revision
  local q,r=request(h,{petId="pip",channel="secondary",counts=Hue.emptyCounts()})
  local ok,why=H.hueCommand(h,"hueClear",q,r);assert(not ok and why=="AlreadyOriginal")
  q,r=request(h,{petId="pip",channel="main",counts={rose=1,tide=0,citrus=0,iris=0}})
  ok,why=H.hueCommand(h,"hueClear",q,r);assert(not ok and why=="CountsChanged")
  q,r=request(h,{petId="pip",channel="sideways",counts=S.row(h.state,"pip").main});ok,why=H.hueCommand(h,"hueClear",q,r);assert(not ok and why=="InvalidHue")
  q,r=request(h,{petId="pip",channel="main",counts=S.row(h.state,"pip").main,itemId="reset"});ok,why=H.hueCommand(h,"hueClear",q,r);assert(not ok and why=="InvalidHue","no extra fields")
  q,r=request(h,{petId="nobody",channel="main",counts=Hue.emptyCounts()});ok,why=H.hueCommand(h,"hueClear",q,r);assert(not ok and why=="InvalidHue")
  assert(h.state.revision==revision and h.state.petHues.pip.main.citrus==1 and S.valid(h.state))
 end)
 test("a forged hueClear receipt (counts after not empty) fails validation",function()
  local h,c=fixture();dose(h,c,"iris","pip","main")
  command(h,"hueClear",{petId="pip",channel="main",counts=S.row(h.state,"pip").main})
  local state=copy(h.state);local r=state.lastHueResult
  r.countsAfter={rose=0,tide=0,citrus=0,iris=1};state.hueItemReceipts[r.id]=copy(r)
  assert(not S.valid(state),"receipt must end at the original colour")
 end)
 return{passed=#cases,cases=cases}
end
