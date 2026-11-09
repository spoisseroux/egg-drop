return function(client)
 local Readiness=require(client.PetAssetReadiness);local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local now,jobs=0,{}
  local q=Readiness.new({now=function()return now end,load=function(parts,complete)table.insert(jobs,{parts=parts,complete=complete})end,timeout=2,retryDelay=1})
  return q,jobs,function(value)now=value;q:step()end
 end
 test("two synchronous consumers share one family load and both wait for its whole result",function()
  local q,jobs=fixture();local source={};local calls=0
  q:request("pip",source,"v1",{"head","body"},3,function(ok)if ok then calls+=1 end end)
  q:request("pip",source,"v1",{"head","body"},1,function(ok)if ok then calls+=1 end end)
  assert(#jobs==1 and calls==0 and not q:ready("pip",source,"v1"));jobs[1].complete(true)
  assert(calls==2 and q:ready("pip",source,"v1"))
 end)
 test("a denied required mesh cannot publish ready and one bounded retry is allowed",function()
  local q,jobs,at=fixture();local source={};local passed=false
  q:request("pip",source,"v1",{},3,function(ok)passed=ok end);jobs[1].complete(false,"HeadDenied")
  assert(not passed and not q:ready("pip",source,"v1"));at(1.1);assert(#jobs==2)
  jobs[2].complete(false,"HeadDenied");at(10);assert(#jobs==2 and not passed)
 end)
 test("timeout quarantines a late success while the underlying concurrency slot remains bounded",function()
  local q,jobs,at=fixture();local source={};local passed=false
  q:request("pip",source,"v1",{},3,function(ok)passed=ok end);at(2.1)
  assert(not passed and q.active==1);jobs[1].complete(true)
  assert(not passed and not q:ready("pip",source,"v1")and q.active==0)
 end)
 test("queued owner and hatch work outrank visitors without exceeding two running jobs",function()
  local q,jobs=fixture();local source={}
  for _,item in ipairs({{"a",1},{"b",1},{"visitor",1},{"owner",3}})do q:request(item[1],source,item[1],{item[1]},item[2],function()end)end
  assert(#jobs==2 and q.active==2);jobs[1].complete(true)
  assert(#jobs==3 and jobs[3].parts[1]=="owner"and q.active==2)
 end)
 test("cancelled lifetime gets no notification while the shared family cache remains useful",function()
  local q,jobs=fixture();local source={};local calls=0
  local ticket=q:request("pip",source,"v1",{},3,function()calls+=1 end);ticket:cancel();jobs[1].complete(true)
  assert(calls==0 and q:ready("pip",source,"v1"))
 end)
 test("a new template signature cannot receive an old family completion",function()
  local q,jobs=fixture();local source={};local old,new=0,0
  q:request("pip",source,"v1",{},3,function()old+=1 end)
  q:request("pip",source,"v2",{},3,function(ok)if ok then new+=1 end end)
  jobs[1].complete(true);assert(old==0 and new==0 and not q:ready("pip",source,"v2"))
  jobs[2].complete(true);assert(new==1 and q:ready("pip",source,"v2"))
 end)
 test("expired queued visitor cannot build an unbounded late backlog",function()
  local q,jobs,at=fixture();local source={}
  for _,id in ipairs({"a","b","c"})do q:request(id,source,id,{},1,function()end)end
  at(3);jobs[1].complete(true);jobs[2].complete(true);at(20)
  assert(#jobs<=4 and not q:ready("c",source,"c"))
 end)
 test("fresh owner demand can rearm a never-started queued family after slots recover",function()
  local q,jobs,at=fixture();local source={};local ready=false
  for _,id in ipairs({"a","b","visitor"})do q:request(id,source,id,{},1,function()end)end
  at(2.1);jobs[1].complete(true);jobs[2].complete(true)
  assert(q.active==0 and not q:ready("visitor",source,"visitor"))
  q:request("visitor",source,"visitor",{},3,function(ok)ready=ok end)
  assert(#jobs==3 and q.active==1);jobs[3].complete(true)
  assert(ready and q:ready("visitor",source,"visitor"))
 end)
 return{passed=#cases,cases=cases}
end
