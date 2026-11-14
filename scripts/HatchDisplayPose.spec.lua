return function(client)
 local P=require(client.HatchDisplayPose);local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 test("one generic forward reveal clears same-side shells before recognition settles",function()
  for _,kind in ipairs({"companion","toy","hue","material","feature"})do
   local before=P.sample(.94,kind,false);local first=P.sample(1.1,kind,false);local endPose=P.sample(1.55,kind,false)
   assert(before.heroAlpha==0 and first.heroAlpha==0 and endPose.heroAlpha==1)
   assert(endPose.shellAlpha==0 and endPose.shellScale<=.200001 and endPose.forward==.08)
   local recognition=P.sample(1.20,kind,false)
   assert(recognition.heroAlpha>0 and recognition.shellAlpha==0 and recognition.capAlpha==0,"transparent hero shows lingering shell")
   local previous=0
   for i=0,100 do local s=P.sample(i*.05,kind,false)
    assert(s.forward>=previous and s.hop>=0 and s.heroScale>0 and s.shellScale>0);previous=s.forward
    assert(s.inputLocked~=s.receiptReady)
   end
  end
 end)
 test("receipt unlock is separate from decorative tail and exact per payload",function()
  for _,row in ipairs({{"companion",2.65,4.4},{"toy",2.2,3.1},{"hue",2.2,3.1}})do
   assert(not P.sample(row[2]-.001,row[1],false).receiptReady)
   local ready=P.sample(row[2],row[1],false)
   assert(ready.receiptReady and not ready.inputLocked and ready.decorativeActive)
   assert(not P.sample(row[3],row[1],false).decorativeActive)
  end
 end)
 test("visible smile eyes survive joy and full blink compresses complete eye owner",function()
  assert(P.sample(2.10,"companion",false).eye==.95 and P.sample(2.75,"companion",false).eye==.90)
  assert(P.sample(1.64,"companion",false).blink==.06)
  assert(P.sample(1.73,"companion",false).blink==1)
 end)
 test("reduced effects has one bounded fade and no hop or shell movement",function()
  for _,kind in ipairs({"companion","toy"})do
   local s=P.sample(.15,kind,true)
   assert(s.receiptReady and not s.decorativeActive and s.heroAlpha==1 and s.heroScale==1)
   assert(s.hop==0 and s.rock==0 and s.shellAlpha==0 and s.blink==1 and s.toyTilt==0)
  end
 end)
 return{passed=#cases,cases=cases}
end
