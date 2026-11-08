return function(client)
 local Intent=require(client.PetContactIntent);local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local now,eligible=0,true;local sent,saved={},{}
  local c=Intent.new({now=function()return now end,eligible=function()return eligible end,
   send=function(action,value)table.insert(sent,{action,value})end,saved=function(receipt)table.insert(saved,receipt.id)end})
  return c,sent,saved,function(dt)now+=dt end,function(value)eligible=value end
 end
 local function grant(c,id)return{granted=true,requestGeneration=c.active.generation,leaseId=id or "lease1",petId=c.active.petId}end
 local function award(c,id)return{status="Saved",requestGeneration=c.active.generation,leaseId=c.active.lease,petId=c.active.petId,
  receipt={id=id or "award1",sequence=1,day="20765",petId=c.active.petId}}end
 test("begin has only generation and current pet; no amount or clock",function()
  local c,s=fixture();c:begin("pip",{});assert(#s==1 and s[1][1]=="begin"and s[1][2].requestGeneration==1 and s[1][2].petId=="pip")
  assert(s[1][2].amount==nil and s[1][2].duration==nil and s[1][2].day==nil)
 end)
 test("grant admits string-only pulses at bounded three per second",function()
  local c,s,_,advance=fixture();c:begin("pip",{});assert(c:receive(grant(c)));for _=1,120 do c:step();advance(1/60)end
  local count=0;for _,v in ipairs(s)do if v[1]=="pulse"then count+=1;assert(v[2]=="lease1")end end;assert(count>=5 and count<=6)
 end)
 test("no grant produces no pulses and no auto retries",function()
  local c,s,_,advance=fixture();c:begin("pip",{});for _=1,60 do advance(.1);c:step()end;assert(#s==1)
 end)
 test("late grant is immediately ended and cannot acquire a new gesture",function()
  local c,s=fixture();c:begin("pip",{});local old=grant(c);c:cancel();c:begin("puddle",{});assert(not c:receive(old))
  assert(s[#s][1]=="end"and s[#s][2]=="lease1"and c.active.petId=="puddle"and c.active.lease==nil)
 end)
 test("owner loss ends once and never resumes without a fresh begin",function()
  local c,s,_,_,eligible=fixture();c:begin("pip",{});c:receive(grant(c));eligible(false);c:step();c:step();c:cancel()
  assert(s[#s][1]=="end"and #s==2 and c.active==nil);eligible(true);c:step();assert(#s==2)
 end)
 test("only current saved receipt shows one glyph",function()
  local c,_,saved=fixture();c:begin("pip",{});c:receive(grant(c));local p=award(c)
  assert(c:receive(p)and #saved==1);assert(not c:receive(p)and #saved==1)
 end)
 test("wrong pet lease generation and malformed receipt never display",function()
  local c,_,saved=fixture();c:begin("pip",{});c:receive(grant(c))
  for _,key in ipairs({"petId","leaseId","requestGeneration"})do local p=award(c);p[key]="wrong";assert(not c:receive(p))end
  local p=award(c);p.receipt.sequence=0;assert(not c:receive(p));assert(#saved==0)
 end)
 test("saved after contact timeout or close never replays on return",function()
  local c,_,saved,_,eligible=fixture();c:begin("pip",{});c:receive(grant(c));local p=award(c)
  eligible(false);assert(not c:receive(p));c:step();eligible(true);c:begin("pip",{});c:receive(grant(c,"lease2"));assert(not c:receive(p)and #saved==0)
 end)
 test("denied contact keeps visual eligibility but has no pulse/retry",function()
  local c,s=fixture();c:begin("pip",{});c:receive({granted=false,requestGeneration=1,petId="pip"});c:step()
  assert(#s==1 and c.active.denied and not c.active.lease)
 end)
 test("historical hatch balance/receipt-shaped snapshots are ignored",function()
  local c,_,saved=fixture();c:begin("pip",{});c:receive(grant(c));assert(not c:receive({nectar=50,lastPetAward={id="old",sequence=1,petId="pip"}})and #saved==0)
 end)
 test("different granted lease cannot overwrite current one",function()
  local c,s=fixture();c:begin("pip",{});c:receive(grant(c));assert(not c:receive(grant(c,"other")))
  assert(c.active.lease=="lease1"and s[#s][1]=="end"and s[#s][2]=="other")
 end)
 test("destroy ends once disconnects intent and rejects late delivery",function()
  local c,s=fixture();c:begin("pip",{});local p=grant(c);c:receive(p);c:destroy();local n=#s;c:destroy();c:step();assert(not c:receive(p)and #s==n)
 end)
 return cases
end
