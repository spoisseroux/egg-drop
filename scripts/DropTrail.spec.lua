-- Studio Client. Drop trail (DropTrail; V3-LEVELS-BUILD-PLAN-2026-11-22 S3): twelve pooled pieces, no
-- Instances per drop, only a ball made at the launch point is followed, a predicted ball's copy takes
-- over, landing and bouncing end it, and Reduced Motion and AliveBudget level 2 cut it. Reads only: the
-- fake balls are never written.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DropTrail)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Trail=require(client.DropTrail)
 local Budget=require(client.AliveBudget)
 local Juice=require(game.ReplicatedStorage.Shared.DeckJuiceCatalog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local root=Instance.new("Frame");root.Name="_DropTrailSpec";root.Size=UDim2.fromOffset(354,594);root.BackgroundTransparency=1;root.Parent=parent
 local views={}
 local scale=30
 local function project(p)return Vector2.new(177+p.X*scale,594-p.Y*scale),scale end
 -- A frozen stand-in for a drawn ball: moving it makes a new Position, and nothing may write to it.
 local function ball(x,y)return{Position=Vector3.new(x,y,0),Size=Vector3.new(1,1,1)}end
 local realLevel=Budget.level
 local ok,problem=pcall(function()
  local trail=Trail.new(root,{views=views,project=project,launchY=17.8})
  local made=#root:GetDescendants()
  local function shown()local n=0;for _,piece in ipairs(trail.pieces)do if piece.frame.Visible then n+=1 end end;return n end
  local function fall(source,from,seconds,now,tier)
   views[source]={tier=tier or 2};source.Position=Vector3.new(0,from,0)
   local accepted=trail:added(source,now)
   local y,v=from,10
   for k=1,math.floor(seconds*60)do v=math.min(38,v+32/60);y-=v/60;source.Position=Vector3.new(0,y,0);trail:step(now+k/60)end
   return accepted,y
  end
  test("a style for every trail in the catalogue; unknown ids and nil draw nothing",function()
   for _,row in ipairs(Juice.ByKind.trail)do assert(Trail.Styles[row.id],row.id)end
   assert(Trail.Pieces==12 and #trail.pieces==12)
   for _,id in ipairs({"nope","classic",5})do trail:setStyle(id);assert(trail.style==nil)end
   trail:setStyle(nil);trail:setOwner(true,false)
   assert(fall(ball(),17.8,.5,10)==false and shown()==0 and trail.active==0)
  end)
  test("pose: bounded sizes, transparency 0..1, gone at the end, the same every time",function()
   for id in pairs(Trail.Styles)do
    for k=1,12 do for s=0,20 do
     local x,y,size,fade=Trail.pose(id,k,s/20)
     local x2,y2,size2,fade2=Trail.pose(id,k,s/20)
     assert(x==x2 and y==y2 and size==size2 and fade==fade2)
     assert(math.abs(x)<=.7 and math.abs(y)<=1 and size>0 and size<=1.1 and fade>=0 and fade<=1,id.." "..k)
    end;assert(select(4,Trail.pose(id,k,1))>=.999)end
   end
  end)
  for _,id in ipairs({"bubble","comet"})do
   test(id..": follows the dropped ball with at most twelve pieces and makes nothing",function()
    trail:setStyle(id);trail:setOwner(true,false);trail:clear()
    local emitted=trail.stats.emitted
    local source=ball();local accepted,y=fall(source,17.8,.6,20)
    assert(accepted and trail.stats.emitted>emitted+3 and shown()>=2 and shown()<=12 and trail.active==shown())
    assert(#root:GetDescendants()==made,"no Instances per drop")
    for _,piece in ipairs(trail.pieces)do
     if piece.active then
      local _,bally=project(Vector2.new(0,y)),594-y*scale
      assert(piece.y<bally,"behind the ball, never over its face")
      assert(not piece.frame.Active and not piece.frame.Selectable and piece.frame.AbsoluteSize.X>=3)
     end
    end
    -- fifteen drops on top of each other stay inside the pool
    for n=1,15 do fall(ball(),17.8,.12,30+n*.12)end
    assert(shown()<=12 and #root:GetDescendants()==made)
    for k=1,90 do trail:step(40+k/60)end
    assert(shown()==0 and trail.active==0 and trail.source==nil,"all gone")
    table.clear(views)
   end)
  end
  test("only a ball first drawn at the launch point: a merge result or the pile is never followed",function()
   trail:setStyle("comet")
   local low=ball();views[low]={tier=3};low.Position=Vector3.new(0,9.6,0)
   assert(not trail:added(low,50)and not Trail.isLaunch(9.6,17.8)and Trail.isLaunch(14,17.8)and Trail.isLaunch(17.8,17.8))
  end)
  test("landing, a bounce and the time limit end it",function()
   local source=ball();fall(source,17.8,.3,60);assert(trail.source==source)
   for k=1,12 do trail:step(60.3+k/60)end;assert(trail.source==nil,"landed")
   fall(source,17.8,.3,62);source.Position+=Vector3.new(0,1,0);trail:step(62.32);assert(trail.source==nil,"bounced")
   source.Position=Vector3.new(0,17.8,0);assert(trail:added(source,64))
   for k=1,80 do source.Position-=Vector3.new(0,.05,0);trail:step(64+k/60)end
   assert(trail.source==nil,"time limit");trail:clear();table.clear(views)
  end)
  test("a predicted ball's server copy takes the trail over; another tier or a far ball does not",function()
   local ghost,real=ball(),ball()
   local _,y=fall(ghost,17.8,.2,70)
   views[ghost]=nil;real.Position=Vector3.new(.3,y+.4,0);views[real]={tier=2}
   trail:step(70.22);assert(trail.source==real)
   views[real]=nil;local other=ball();other.Position=real.Position;views[other]={tier=4}
   local far=ball();far.Position=real.Position+Vector3.new(0,-6,0);views[far]={tier=2}
   trail:step(70.24);assert(trail.source==nil);trail:clear();table.clear(views)
  end)
  test("cut under Reduced Motion, at level 2, when hidden and after destroy; a cover clears at once",function()
   assert(Trail.allowed(false,0)and Trail.allowed(false,1)and not Trail.allowed(true,0)and not Trail.allowed(false,2))
   trail:setOwner(true,true);assert(fall(ball(),17.8,.3,80)==false and shown()==0)
   trail:setOwner(false,false);assert(fall(ball(),17.8,.3,82)==false and shown()==0)
   trail:setOwner(true,false)
   Budget.level=function()return 2 end;assert(fall(ball(),17.8,.3,84)==false and shown()==0)
   Budget.level=realLevel
   assert(fall(ball(),17.8,.3,86)and shown()>0);trail:setOwner(false,false);assert(shown()==0 and trail.source==nil)
   trail:setOwner(true,false);fall(ball(),17.8,.3,88);trail:setOwner(true,true);assert(shown()==0,"Reduced Motion turned on mid-drop")
   table.clear(views)
  end)
  test("it never writes to a ball or a view",function()
   trail:setOwner(true,false)
   local source=table.freeze({Position=Vector3.new(0,17.5,0),Size=Vector3.new(1,1,1)});views[source]=table.freeze({tier=2})
   assert(trail:added(source,90));for k=1,30 do trail:step(90+k/60)end
   trail:destroy();trail:destroy();assert(not trail:added(source,91));trail:step(91);assert(#root:GetDescendants()==0)
  end)
 end)
 Budget.level=realLevel
 root:Destroy();assert(ok,problem)
 return{passed=#cases,cases=cases}
end
