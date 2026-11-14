-- Qualified zero-goal loss payouts through the real fenced award transaction.
return function(server)
 local H=require(server.HatchProgress)
 local Daily=require(game:GetService("ReplicatedStorage").Shared.DailyContracts)
 local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 local function copy(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
 local function fixture()
  local db,c={},{now=1700000000,serial=0,fail=nil}
  local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "loss"..c.serial end,random=function()return .1 end,wait=function()end,
   update=function(key,transform)
    if c.fail=="before"then c.fail=nil;error("store unavailable")end
    local value=transform(copy(db[key]));if value then db[key]=copy(value)end
    if c.fail=="after"then c.fail=nil;error("response lost")end
    return copy(value)
   end}
  local h=H.load(1,{rank=1},adapter)
  return h,c,db
 end
 local function summary(changes)
  local s={family="pip",day=Daily.dayOf(1700000000),success=false,clean=false,score=100,chain=3,clears=0,drops=6,heat="medium",goalsMet=0,merges=3,itemsUsed=0,maxTier=2}
  for k,v in pairs(changes or {})do s[k]=v end
  return s
 end
 test("effort and goal awards retain existing pass and supporter order",function()
  for _,goals in ipairs({0,1})do
   for _,mult in ipairs({1,2})do for _,bonus in ipairs({0,1})do
    local h=fixture();local before=h.state.nectar
    assert(H.award(h,1,0,summary({goalsMet=goals}),{multiplier=mult,bonus=bonus}))
    local base=if goals==0 then 1 else 2
    assert(h.state.nectar==before+base*mult+bonus and h.state.lastRunReward.missPay==base)
    local balance=h.state.nectar
    assert(H.award(h,1,0,summary({goalsMet=goals}),{multiplier=mult,bonus=bonus})and h.state.nectar==balance,"same sequence paid twice")
   end end
  end
 end)
 test("score, merge and drop boundaries do not pay effort early",function()
  for key,value in pairs({score=99,merges=2,drops=5})do
   local h=fixture();local before=h.state.nectar
   assert(H.award(h,1,0,summary({[key]=value}),{}))
   assert(h.state.nectar==before and h.state.lastRunReward.missPay==0,key)
  end
  local h=fixture();local before=h.state.nectar
  assert(H.award(h,1,0,summary({score=0,merges=0,drops=0}),{bonus=1}))
  assert(h.state.nectar==before+1,"existing Supporter flat bonus is unchanged")
 end)
 test("ambiguous writes and frozen candidate recovery pay exactly once",function()
  for _,failure in ipairs({"before","after"})do
   local h,c=fixture();local before=h.state.nectar
   local run=summary();c.fail=failure
   local ok,why=H.award(h,1,0,run,{multiplier=2,bonus=1})
   assert(not ok and why=="Retrying")
   run.score=0;run.merges=0;run.drops=0
   assert(H.retry(h))
   assert(h.state.nectar==before+3 and h.state.lastRunReward.missPay==1,"captured qualifying summary must survive retry")
   assert(H.award(h,1,0,summary(),{multiplier=2,bonus=1})and h.state.nectar==before+3)
  end
 end)
 test("normal win reward remains unchanged",function()
  local h=fixture();local before=h.state.nectar
  assert(H.award(h,1,6,summary({success=true,drops=24,goalsMet=2}),{multiplier=2,bonus=1}))
  assert(h.state.nectar==before+13 and h.state.lastRunReward.missPay==0)
 end)
 return {passed=#cases,cases=cases}
end
