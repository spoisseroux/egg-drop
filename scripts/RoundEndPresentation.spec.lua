return function(client,parent)
 local End=require(client.RoundEndPresentation);local Copy=require(client.FieldQuestText)
 local Catalog=require(game.ReplicatedStorage.Shared.FieldObjectives)
 local roots={};local cases={};local function test(name,f)f();table.insert(cases,name)end
 local function make(over)
  local b=Instance.new("Folder");b.Parent=parent;table.insert(roots,b)
  local d=Catalog.create("creek_crossing",17)
  local view={sequence=71,templateId=d.id,title=d.title,dynamics={id=d.dynamics.id,label=d.dynamics.label},goals=game:GetService("HttpService"):JSONDecode(game:GetService("HttpService"):JSONEncode(d.goals)),step=1,progress=0,target=1,complete=false}
  for k,v in pairs({ResetId=8,RunSequence=71,Mode="Board",RoundOver=over==true,FieldPhase="Playing",FieldFinalStage=0,FieldSuccess=false,FieldReason=""})do b:SetAttribute(k,v)end
  local host=Instance.new("Frame");host.Size=UDim2.fromOffset(300,64);host:SetAttribute("RoundEndStrip",true);host.Parent=parent;table.insert(roots,host)
  local control={owns=true,reduced=false,view=view,target=host}
  local e=End.new(b,{readView=function()return control.view end,owns=function()return control.owns end,reduced=function()return control.reduced end,target=function()return control.target end})
  table.insert(roots,e)
  local function ball(id,serial)
   local p=Instance.new("Part");p.Anchored=true;p.Position=Vector3.new(id*.1,3,0);p.Size=Vector3.one;p:SetAttribute("Tier",2);p:SetAttribute("EggId",id);p:SetAttribute("BoardSerial",serial or 8);p.Parent=b;return p
  end
  local function final(success,stage)
   stage=stage or(if success then 2 else 1);control.view.step=stage+1;control.view.complete=stage==2;control.view.progress=0;control.view.target=if stage==2 then 0 else 1
   b:SetAttribute("FieldPhase","Complete");b:SetAttribute("FieldSuccess",success);b:SetAttribute("FieldFinalStage",stage)
   b:SetAttribute("FieldReason",if success then view.title.." complete"else "Overflow");b:SetAttribute("RoundOver",true)
  end
  return e,b,control,ball,final
 end
 local ok,err=pcall(function()
  test("witnessed current run starts once and final descriptor and balls are immutable",function()
   local e,b,c,ball,final=make();e:observe();local p=ball(1);ball(2,7);final(true);local frozen=e:observe()
   assert(frozen and e.active and e.starts==1 and #frozen.balls==1)
   p.Position=Vector3.new(4,8,0);c.view.goals[1].zone.kind="right";b:SetAttribute("FieldStage",0)
   assert(e:observe()==frozen and frozen.balls[1].y~=0 and frozen.objective.goals[1].zone.kind=="center"and e.starts==1)
   assert(table.isfrozen(frozen)and table.isfrozen(frozen.balls)and table.isfrozen(frozen.objective.goals[1]))
  end)
  test("RoundOver before terminal attributes waits for matching complete descriptor",function()
   local e,b,c,ball,final=make();e:observe();ball(1);b:SetAttribute("RoundOver",true);assert(e:observe()==nil)
   b:SetAttribute("FieldSuccess",true);assert(e:observe()==nil);b:SetAttribute("FieldPhase","Complete");assert(e:observe()==nil)
   b:SetAttribute("FieldFinalStage",2);b:SetAttribute("FieldReason",c.view.title.." complete");assert(e:observe()==nil)
   final(true);assert(e:observe()and e.starts==1)
  end)
  test("terminal attributes before RoundOver do not start or snapshot early",function()
   local e,b,c,ball,final=make();e:observe();ball(1);final(false);b:SetAttribute("RoundOver",false)
   assert(e:observe()==nil and e.starts==0);b:SetAttribute("RoundOver",true);assert(e:observe()and e.starts==1)
  end)
  test("historical over true and stale sequence descriptors remain static",function()
   local e,b,c,ball,final=make(true);ball(1);final(true);assert(e:observe()and not e.active and e.starts==0)
   b:SetAttribute("RunSequence",72);assert(e:observe()==nil);c.view.sequence=72;assert(e:observe()and e.starts==0)
  end)
  test("snapshot includes at most six current visible balls and no other board parts",function()
   local e,b,c,ball,final=make();e:observe();for i=1,10 do ball(i)end;ball(20,7);local hidden=ball(21);hidden.Transparency=1
   local outside=ball(22);outside.Position=Vector3.new(100,100,0);final(true);assert(#e:observe().balls==6)
  end)
  test("quick replay retires old art and a new run requires its own false edge",function()
   local e,b,c,ball,final=make();e:observe();ball(1);final(true);e:observe();e:step(.05);assert(e.layer)
   b:SetAttribute("ResetId",9);b:SetAttribute("RunSequence",72);assert(e:observe()==nil and not e.layer and not e.active)
   c.view.sequence=72;assert(e:observe()and e.starts==1);b:SetAttribute("RoundOver",false);e:observe();b:SetAttribute("RoundOver",true);e:observe();assert(e.starts==1,"same already-observed run replayed")
  end)
  test("one run owner hands off to recap without a restart or descriptor replacement",function()
   local e,b,c,ball,final=make();e:observe();ball(1);final(true);e:observe();e:step(.1);local age=e.age
   local nextTarget=Instance.new("Frame");nextTarget.Size=UDim2.fromOffset(320,64);nextTarget.Parent=parent;table.insert(roots,nextTarget);c.target=nextTarget
   e:step(.05);assert(e.target==nextTarget and e.age>age and e.starts==1 and #e.nodes==1 and #e.pieces==12)
  end)
  test("overflow uses three falling seeds and reduced motion remains stable",function()
   local e,b,c,ball,final=make();e:observe();ball(1);final(false);e:observe();e:step(.05);assert(#e.pieces==3)
   c.reduced=true;e:step(.01);local p=e.nodes[1].node.Position;e:step(.1);assert(not e.active and e.nodes[1].node.Position==p)
   for _,node in ipairs(e.pieces)do assert(not node.Visible)end
  end)
  test("hidden or covered owner cancels immediately and reopening cannot replay",function()
   local e,b,c,ball,final=make();e:observe();ball(1);final(true);e:observe();e:step(.05);c.owns=false;e:step(.01);assert(not e.active and not e.layer)
   c.owns=true;e:step(.01);assert(e.layer and not e.active and e.starts==1)
  end)
  test("quiet gap settles without queuing effects and mute has no visual dependency",function()
   local e,b,c,ball,final=make();e:observe();ball(1);final(true);e:observe();e:step(.3);assert(not e.active and e.age==End.Duration)
   assert(#e.pieces==12 and e.starts==1);for _,node in ipairs(e.layer:GetDescendants())do assert(not node:IsA("Sound")and not node:IsA("ParticleEmitter"));if node:IsA("GuiObject")then assert(not node.Active and not node.Selectable)end end
  end)
  test("real recap reserves decoration after pending copy and before Saved breakdown",function()
   local Recap=require(client.RoundRecap);local Eggs=require(game.ReplicatedStorage.Shared.EggCatalog)
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(420,400);host.Parent=parent;table.insert(roots,host)
   local recap=Recap.new(host,nil,function()return true end);recap.frame.Visible=true;recap.endArt.Visible=true
   local result={sequence=71,status="Saving",success=true,stage=2,reason="Complete",award=8,daily=0,balance=8,recipe=Eggs.ById.meadow}
   recap:updateField(result);recap:layoutField(400)
   local copyBottom=recap.goal.Position.Y.Offset+recap.detail.Position.Y.Offset+recap.detail.Size.Y.Offset
   assert(recap.endArt.Position.Y.Offset>=copyBottom+7 and recap.endArt.Size.X.Offset>100,"pending strip overlaps saving copy or retains default bounds")
   assert(recap.fieldBody.CanvasSize.Y.Offset>=recap.endArt.Position.Y.Offset+64)
   result.status="Saved";result.reward={sequence=71,total=8,base=8,daily=0,contracts={}};recap:updateField(result);recap:layoutField(400)
   assert(recap.endArt.Position.Y.Offset>=recap.earnedGraphic.Size.Y.Offset+8)
   assert(recap.detailsContent.Position.Y.Offset>=recap.endArt.Position.Y.Offset+recap.endArt.Size.Y.Offset,"Saved breakdown overlaps owned strip")
   assert(recap.displayReward==8 and not recap.feedback.active)
  end)
  test("result goals state completed marks and actual seeded locations without scenario jargon",function()
   local e,b,c,ball,final=make();e:observe();final(false);local frozen=e:observe();local result=Copy.results(frozen.objective,frozen.stage)
   assert(result:sub(1,5)=="Goals"and not result:find("of 2",1,true)and result:find("✓ Match I + I in CENTER",1,true))
   assert(result:find("○ Make III or higher on "..frozen.objective.goals[2].zone.kind:upper(),1,true))
   assert(not result:find("Creek crossing",1,true)and not result:find("Soft banks",1,true))
  end)
 end)
 for _,r in ipairs(roots)do if typeof(r)=="Instance"then r:Destroy()else r:destroy()end end
 assert(ok,err);return{passed=#cases,cases=cases}
end
