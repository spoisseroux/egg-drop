-- Actual GUI fixtures for one unchanged device and its in-place results region contract.
return function(client,parent)
 local Screen=require(client.DeckScreen)
 local Results=require(client.DeckResults)
 local Feedback=require(client.RecapFeedback)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Config=require(Shared.BoardConfig)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local root=Instance.new("Frame");root.Name="_InPlaceResultsSpec";root.Size=UDim2.fromOffset(1280,720);root.Parent=parent
 local function data(pending)
  return {outcome="missed",title="Creek crossing",difficulty="Easy",nextDifficulty="Medium",pending=pending,earned=if pending then 0 else 1,total=1,balance=12,
   rows={{name="Good effort",amount=1}},todayEarned=1,goals={{text="Make a green or larger on the left",short="Green on left",done=false}},score=100,best=200,chain=3,canLeave=true,
   result={status=if pending then "Pending"else "Saved",receiptPending=false,sequence=3,reward=if pending then nil else {sequence=3,total=1}}}
 end
 local ok,err=pcall(function()
 test("phone and desktop results use the exact gameplay LCD and region coordinates",function()
  for _,size in ipairs({Vector2.new(812,354),Vector2.new(1280,720),Vector2.new(640,360)})do
   local g=Screen.resolve(size,(Config.Width+.8)/(Config.Height+.8),{kx=116,kh=58})
   local v=Screen.resultsRegions(g)
   local lcd=if g.phone then g.screen else g.lcd
   assert(v.lcd.x==lcd.x and v.lcd.y==lcd.y and v.W==lcd.w and v.H==lcd.h)
   assert(math.abs(v.center.x+v.lcd.x-g.board.x)<.001 and math.abs(v.center.y+v.lcd.y-g.board.y)<.001)
   for _,r in ipairs({v.left,v.center,v.right})do assert(r.x>=0 and r.y>=0 and r.x+r.w<=v.W+.001 and r.y+r.h<=v.H+.001,"region outside existing LCD")end
  end
 end)
 test("four-direction results focus never buys or restarts on difficulty arrows",function()
  local screen=Screen.new({parent=root,overlayParent=root,viewRoot=root})
  local g=screen:layout(Vector2.new(812,354),.6,{kx=116,kh=58})
  local before={root=screen.root.Position,size=screen.root.Size,plate=screen.plate.Position,lcd=screen.lcd.Position,a=screen.buttons.A.holder.Position}
  local result=Results.new(screen.resultsContent,{starMesh=false,reduce=function()return true end})
  local replay,hatch,shift=0,0,0
  result:on("replay",function()replay+=1 end);result:on("hatch",function()hatch+=1 end);result:on("heatShift",function(d)shift+=d end)
  result:show(data(false),screen:resultsView())
  assert(result.inPlace and result.focus==1)
  assert(result:target(5).Visible,"store route remains visible even when an egg is not affordable")
  result:move2D(0,1);assert(result.focus==3)
  result:move2D(1,0);assert(shift==1 and replay==0 and hatch==0,"directional heat selection must not activate a purchase/reset")
  result:move2D(0,1);assert(result.focus==5);result:confirm();assert(hatch==1)
  assert(screen.root.Position==before.root and screen.root.Size==before.size and screen.plate.Position==before.plate and screen.lcd.Position==before.lcd and screen.buttons.A.holder.Position==before.a,"results changed physical device")
  result:show(data(true),screen:resultsView());result.focus=2;result:move2D(0,-1);assert(result.focus==2,"pending actions cannot take focus")
  result:hide();assert(screen.root.Position==before.root and screen.lcd.Position==before.lcd)
  result.inPlace.opened=-100;result:show(data(false),screen:resultsView())
  assert(result.inPlace.opened>0,"a new round reused the previous round entrance clock")
  local opened=result.inPlace.opened;result:show(data(false),screen:resultsView())
  assert(result.inPlace.opened==opened,"same open receipt update restarted entrance")
  result:hide()
  result.inPlace:destroy();screen.root:Destroy();screen.results:Destroy()
 end)
 test("wrapped payout and goal rows include actual label line spacing",function()
  local screen=Screen.new({parent=root,overlayParent=root,viewRoot=root})
  screen:layout(Vector2.new(812,354),.6,{kx=116,kh=58})
  local result=Results.new(screen.resultsContent,{starMesh=false,reduce=function()return true end})
  local d=data(false)
  d.rows={{name=string.rep("Long effort award ",8),amount=1},{name="Next payout",amount=0}}
  d.goals={{text=string.rep("Make a green or larger on the left ",6),done=false},{text="Next goal",done=false}}
  result:show(d,screen:resultsView())
  game:GetService("RunService").RenderStepped:Wait()
  local view=result.inPlace
  for _,pair in ipairs({{view.rows[1],view.rows[2]},{view.goalLabels[1],view.goalLabels[2]}})do
   local a,b=pair[1],pair[2]
   assert(a.LineHeight==1.25 and a.TextBounds.Y>32,"fixture must actually wrap into several lines")
   assert(a.TextBounds.Y<=a.Size.Y.Offset+1,"wrapped row clipped by missing line spacing")
   assert(a.Position.Y.Offset+a.Size.Y.Offset+6<=b.Position.Y.Offset,"next row overlaps wrapped content")
  end
  result:hide();result.inPlace:destroy();screen.root:Destroy();screen.results:Destroy()
 end)
 test("positive loss receipt is gold and zero receipt is silver",function()
  assert(not Results.missLook({outcome="missed",loss=false,earned=1,pending=false}))
  assert(Results.missLook({outcome="missed",loss=true,earned=0,pending=false}))
 end)
 test("instance count window ends by650ms and default feedback stays unchanged",function()
  local f=Feedback.new(function()end,nil,false,function()return true end)
  f:setCountWindow(.30,.35)
  assert(f:observe({status="Saved",sequence=42,reward={sequence=42,total=20}},true))
  assert(f:countAt(.299)==0 and f:countAt(.65)==20 and f.countEnd<=.65)
  assert(not f:observe({status="Saved",sequence=42,reward={sequence=42,total=20}},true),"same receipt must not count twice")
  f:cancel()
  local old=Feedback.new(function()end,nil,false,function()return true end)
  assert(old:observe({status="Saved",sequence=43,reward={sequence=43,total=2}},true))
  assert(old:countAt(.59)==0 and old:countAt(.6)==1,"legacy default changed")
  old:cancel()
 end)
 end)
 root:Destroy();assert(ok,err)
 return {passed=#cases,cases=cases}
end
