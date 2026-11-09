-- Uses the real fixed-step production solver; isolated state, no persistence/live claim.
-- Pass {Simulation,Round,FieldRun,Config,Objectives} plus current Benchmark module.
return function(dependencies,Benchmark,options)
 options=options or {};local count=options.count or 6
 local rows={};local templates={"ripple_relay","bank_bounce","mirror_marks"}
 for _,id in ipairs(templates)do
  local result=Benchmark.run(dependencies,{templateId=id,policy="goal_aware",firstSeed=40001,count=count,yieldEach=true})
  local orientations={};local wins=0
  for _,sample in ipairs(result.samples)do
   if sample.success then
    assert(sample.drops==24 and sample.stages==2 and sample.baseReward>=6 and not sample.overflow)
    Benchmark.replay(dependencies,sample);wins+=1
    orientations[sample.seed%2]=true
   end
  end
  assert(wins>=3,"Need three production 24-drop completions for "..id)
  if id~="ripple_relay"then assert(orientations[0]and orientations[1],"Both seeded bank orientations must complete: "..id)end
  table.insert(rows,result)
 end
 return{passed=#rows,rows=rows,persistentWrites=false,liveState=false,evidence="production solver 24-drop wins plus exact trace replay; no native input claim"}
end
