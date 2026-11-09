-- QA-only smoke/lifecycle coverage. Short rounds are deliberately ineligible as perf evidence.
return function(client,driver,comparison,archive)
 local Compare=require(comparison);local Run=game:GetService("RunService");local cases={};local session
 local ok,err=pcall(function()
  assert(archive:GetAttribute("SourceRevision")=="bb8c60bdfac1fff1f77669b918c2b34da14cfad0"and archive:GetAttribute("FixtureOnly")==true)
  local count=0;for _,module in ipairs(archive:GetDescendants())do if module:IsA("ModuleScript")then count+=1 end end;assert(count==21)
  local original=require(archive.Shared.PetCatalog);local current=require(game.ReplicatedStorage.Shared.PetCatalog)
  assert(original.byId.wick.name=="Wick"and current.byId.wick.name=="Tikket"and original.byId.wick.id==current.byId.wick.id)
  assert(require(archive.Shared.PetRigDefinitions).wick==nil and require(game.ReplicatedStorage.Shared.PetRigDefinitions).wick.id=="tikket")
  table.insert(cases,"verified21-module bb8c60b archive preserves its actual names/rig dependencies outside current Shared")
  session=Compare.new(client,driver,archive,{fixture={origin=Vector3.new(2000,4.025,0),hour=12}})
  local modern=session:runRound("current",1,{warmupFrames=6,frames=12})
  local old=session:runRound("archived",1,{warmupFrames=6,frames=12})
  assert(modern.valid and old.valid and modern.frames==12 and old.frames==12 and modern.controlledFrames==12 and old.controlledFrames==12)
  assert(modern.study.fixtureActorCount==7 and old.study.fixtureActorCount==7 and modern.study.activeToyFixture and old.study.activeToyFixture)
  assert(modern.study.sourceRevision=="current-working-tree"and old.study.sourceRevision==archive:GetAttribute("SourceRevision"))
  assert(modern.study.subjects[3].id=="wick"and old.study.subjects[3].id=="wick"and modern.study.subjects[3].backend~=old.study.subjects[3].backend)
  assert(not session.active and session:summary().rigCPUDeltaPercent==nil,"short smoke rounds masqueraded as production evidence")
  table.insert(cases,"real archived/current factories run same7actor+toy scope with measured light/camera and bounded timing")
  local finished=false;local cancelled=false
  task.spawn(function()local success=pcall(function()session:runRound("current",2,{warmupFrames=180,frames=180})end);cancelled=not success;finished=true end)
  Run.Heartbeat:Wait();session:destroy();for _=1,3 do Run.Heartbeat:Wait()end
  assert(finished and cancelled and not session.active,"retired comparison retained sample clock")
  table.insert(cases,"comparison retirement cancels a waiting round and restores the underlying study owner")
 end)
 if session then session:destroy()end;assert(ok,err);return cases
end
