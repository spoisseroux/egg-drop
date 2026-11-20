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
  -- 2026-11-15: the receipt unlocks with the name slam (pets 2.05 = RevealStage lead-in 1.05
  -- + its 1.0 s input beat; items 1.65 = HatchItemStage's name slam).
  assert(P.BearReady==require(client.RevealStage).LeadIn+require(client.RevealStage).InputAt)
  for _,row in ipairs({{"companion",2.05,4.4},{"toy",1.65,3.1},{"hue",1.65,3.1}})do
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
  -- Pets keep their 150 ms fade; items cross-fade at 0.30 to 0.45 and name at 0.6 (v2, section 4).
  local s=P.sample(.15,"companion",true)
  assert(s.receiptReady and not s.decorativeActive and s.heroAlpha==1 and s.heroScale==1)
  assert(s.hop==0 and s.rock==0 and s.shellAlpha==0 and s.blink==1 and s.toyTilt==0)
  local early,ready=P.sample(.15,"toy",true),P.sample(.6,"toy",true)
  assert(not early.receiptReady and early.crack==1 and early.shellAlpha==1,"the egg shows its crack already drawn")
  assert(ready.receiptReady and ready.heroAlpha==1 and ready.shellAlpha==0 and ready.hop==0 and ready.rock==0 and ready.toyTilt==0)
  assert(P.sample(.89,"toy",true,"Rare").receiptReady==false and P.sample(.9,"toy",true,"Rare").receiptReady,"a Rare under Reduced Motion names at 0.9")
 end)
 test("v2 jackpot: a Rare item holds through the wind-up, bursts at 1.72 and names at 3.15",function()
  local Rarity=require(client.HatchRarityCue)
  local T=Rarity.timing("Rare","toy",false);assert(T.burst==1.72 and T.ready==3.15 and T.jackpot and T.bodyAt>.73 and T.bodyAt<.75)
  assert(Rarity.timing("Common","toy",false).burst==.98 and Rarity.timing("Uncommon","hue",false).ready==1.65,"Common and Uncommon keep today's clock")
  assert(not Rarity.timing("Rare","companion",false).jackpot,"pets keep their clock")
  -- The egg holds its crack through the wind-up; the shell opens only at the burst.
  for _,t in ipairs({.95,1.2,1.5,1.69})do local s=P.sample(t,"toy",false,"Rare");assert(s.opening==0 and s.shellAlpha==1 and s.heroAlpha==0,"opened early at "..t)end
  local lift=P.sample(1.3,"toy",false,"Rare");assert(lift.eggLift>.9 and lift.shiver>0,"lifted and shivering in the wind-up")
  local freeze=P.sample(1.71,"toy",false,"Rare");assert(freeze.eggSY<.9 and freeze.eggSX>1.1,"the freeze squashes the egg")
  assert(P.sample(2.0,"toy",false,"Rare").opening>.9 and P.sample(2.5,"toy",false,"Rare").heroAlpha==1)
  assert(not P.sample(3.149,"toy",false,"Rare").receiptReady and P.sample(3.15,"toy",false,"Rare").receiptReady)
  -- Squash keeps volume (within 3%) at every frame, every tier.
  for _,tier in ipairs({"Common","Uncommon","Rare"})do
   for i=0,280 do local s=P.sample(i/60,"toy",false,tier);assert(math.abs(s.eggSX*s.eggSY-1)<.03,"volume at "..i/60)end
  end
 end)
 return{passed=#cases,cases=cases}
end
