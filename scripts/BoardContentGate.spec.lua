return function(client)
 local Gate=require(client.BoardContentGate);local cases={}
 local function test(name,f)f();table.insert(cases,name)end
 local function source(id,serial,tier)
  return {GetAttribute=function(_,key)return({EggId=id,BoardSerial=serial,Tier=tier})[key]end}
 end
 test("new reset serial alone cannot expose the prior pile",function()
  assert(not Gate.matches(8,7,{serial=7,ids={1,2}},{source(1,7,1),source(2,7,1)}))
  assert(not Gate.matches(8,7,{serial=8,ids={}},{source(1,7,1)}))
 end)
 test("content waits for every exact serial-tagged ball and its tier",function()
  local content={serial=8,ids={1,2}}
  assert(not Gate.matches(8,7,content,{source(1,8,1)}))
  assert(not Gate.matches(8,7,content,{source(1,8,1),source(2,8,nil)}))
  assert(not Gate.matches(8,7,content,{source(1,8,1),source(2,7,1)}))
  assert(Gate.matches(8,7,content,{source(1,8,1),source(2,8,2)}))
 end)
 test("ended return requires a fresh serial even if old contents are complete",function()
  assert(not Gate.matches(7,7,{serial=7,ids={1}},{source(1,7,1)}))
  assert(Gate.matches(8,7,{serial=8,ids={} },{}))
 end)
 test("active field resume accepts its same exact pile without reset",function()
  assert(Gate.matches(7,nil,{serial=7,ids={1,2}},{source(2,7,2),source(1,7,1)}))
 end)
 test("extra duplicate or unlisted balls block first paint",function()
  assert(not Gate.matches(8,7,{serial=8,ids={1}},{source(1,8,1),source(1,8,1)}))
  assert(not Gate.matches(8,7,{serial=8,ids={}},{source(4,8,1)}))
 end)
 return {passed=#cases,cases=cases}
end
