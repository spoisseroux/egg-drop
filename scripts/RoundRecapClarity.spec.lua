return function(client,parent)
 local Recap=require(client.RoundRecap);local Copy=require(client.FieldQuestText)
 local Objectives=require(game.ReplicatedStorage.Shared.FieldObjectives);local Eggs=require(game.ReplicatedStorage.Shared.EggCatalog)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(580,600);root.Parent=parent
 local view=Recap.new(root,nil,true);view.frame.Visible=true;local cases={}
 local descriptor=Objectives.create("creek_crossing",17)
 local objective={sequence=71,templateId=descriptor.id,title=descriptor.title,dynamics={id=descriptor.dynamics.id,label=descriptor.dynamics.label},goals=descriptor.goals,step=1,progress=0,target=1,complete=false}
 local result={sequence=71,status="Saved",success=false,stage=0,reason="Incomplete",award=6,daily=6,balance=24,recipe=Eggs.ById.meadow,objective=objective,
  reward={sequence=71,total=6,base=0,daily=6,contracts={}}}
 local function count(copy,fragment)local n,start=0,1;while true do local a,b=copy:find(fragment,start,true);if not a then return n end;n+=1;start=b+1 end end
 local ok,err=pcall(function()
  view:update(630,4,2,nil,0,nil,0,740);view:updateField(result)
  local visible={};local metrics={}
  for _,card in ipairs(view.detailCards)do
   assert(card.kind~="source","Quest/Daily component repeated in details");metrics[card.kind]=true;table.insert(visible,card.title.Text)
  end
  local copy=table.concat(visible,"\n");local first=Copy.goal(objective.goals[1]);local second=Copy.goal(objective.goals[2])
  assert(view.fieldHeading=="0 of 2 goals"and view.earnedGraphic.Text=="+6 Stars"and view.componentLabels[1].Text=="Quest +0"and view.componentLabels[2].Text=="Daily +6")
  assert(count(copy,first)==1 and count(copy,second)==1 and not copy:find("unfinished",1,true)and not copy:find("of 2",1,true))
  assert(not copy:find("Creek crossing",1,true)and not copy:find("Soft banks",1,true)and metrics.score and metrics.best and metrics.chain and metrics.clears)
  assert(view.receiptLines[1]=="Quest Stars +0"and view.receiptLines[2]=="Daily contracts total +6","canonical stored receipt component lines changed")
  table.insert(cases,"one exact payout summary and one goal checklist preserve all historical metrics and receipt facts")
  result.objective=nil;view:updateField(result)
  local fallback={};for _,card in ipairs(view.detailCards)do table.insert(fallback,card.title.Text)end
  assert(table.concat(fallback,"\n"):find("Complete both goals in your next round",1,true),"missing descriptor must retain one helpful historical fallback")
  table.insert(cases,"historical result without verified checklist retains its one unfinished hint")
 end)
 root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
