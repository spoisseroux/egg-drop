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
 -- QA v751 P1 follow-up: on Spencer's phone (750x402) both goals show above the action stack.
 test("750x402 phone: two goals fit above the four-button stack, nothing under Replay",function()
  local screen=Screen.new({parent=root,overlayParent=root,viewRoot=root})
  screen:layout(Vector2.new(750,402),(Config.Width+.8)/(Config.Height+.8),{kx=116,kh=58})
  local result=Results.new(screen.resultsContent,{starMesh=false,reduce=function()return true end})
  local d=data(false);d.outcome="clear";d.earned=6;d.total=6
  d.goals={{short="LEFT",done=true},{short="RIGHT",done=true}}
  result:show(d,screen:resultsView());task.wait()
  local view=result.inPlace
  assert(not view.grid and not view.scrollActions,"this phone uses the plain four-button stack")
  local top=view.actions.AbsolutePosition.Y
  for i=1,2 do
   local label=view.goalLabels[i]
   assert(label.Visible and label.AbsolutePosition.Y+label.AbsoluteSize.Y<=top+.5,"goal "..i.." runs under the actions")
   assert(label.AbsolutePosition.Y+label.AbsoluteSize.Y<=view.goals.AbsolutePosition.Y+view.goals.AbsoluteSize.Y+.5,"goal "..i.." is clipped by the goals pane")
   assert(label.TextBounds.Y<=label.AbsoluteSize.Y+.5,"goal "..i.." text is taller than its row")
  end
  assert(view.goalLabels[1].AbsolutePosition.Y>=view.goalTitle.AbsolutePosition.Y+view.goalTitle.AbsoluteSize.Y-.5,"first goal overlaps the title")
  for _,id in ipairs({1,3,5,2})do assert(view.buttons[id].AbsoluteSize.Y>=44,"action "..id.." under 44 px")end
  result:hide();result.inPlace:destroy();screen.root:Destroy();screen.results:Destroy()
 end)
 -- QA v735 D6: the results polish.
 test("results polish: full Star turn, display headline, eased entry, payout columns, wallet at the foot, 2 x 2 actions",function()
  local C=require(client.CelebrationKit)
  local screen=Screen.new({parent=root,overlayParent=root,viewRoot=root})
  -- 999x460: the widest phone root. Since QA v751 P1 (aspect-locked shell) the right pane is
  -- 176 px or wider, the 2 x 2 grid's minimum, only from about there up; narrower phones
  -- (Spencer's 750x402 has a 141 px pane) use the four-button stack.
  screen:layout(Vector2.new(999,460),(Config.Width+.8)/(Config.Height+.8),{kx=116,kh=58})
  local result=Results.new(screen.resultsContent,{starMesh=false,reduce=function()return false end})
  local d=data(false);d.outcome="clear";d.tidy=true;d.earned=13;d.total=13
  d.rows={{name="Round win",amount=5},{name="Tidy stack",amount=1,signed=true},{name="Supporter",amount=7,signed=true}}
  d.goals={{short="LEFT",done=true},{short="RIGHT",done=false}}
  result:show(d,screen:resultsView())
  local view=result.inPlace;local R=view.regions
  -- The three panes share one top and height.
  assert(R.middle.y==R.left.y and R.middle.h==R.left.h and R.right.h==R.left.h,"panes are not level")
  -- Headline: the display face, slanted, the words at 24 px or fitted, never under 15.
  assert(view.title.Text=="TIDY WIN!"and view.title.FontFace==C.displayFont(),"headline is not the display font")
  assert(view.title.TextSize*(view.headlineFit or 1)>=15,"headline shrank under 15 px")
  -- Payout: names left, amounts in their own right-aligned column; the wallet chip at the pane's foot.
  assert(view.rows[2].Text=="Tidy stack"and view.amounts[2].Text=="+1"and view.amounts[1].Text=="5","payout columns")
  assert(view.amounts[2].TextXAlignment==Enum.TextXAlignment.Right and view.amounts[2].Position.X.Offset>view.rows[2].Position.X.Offset+view.rows[2].Size.X.Offset,"amount column right of the names")
  assert(view.wallet.root.Parent==view.left,"wallet chip is not in the payout pane")
  -- QA v751 P5: the chip uses the 3D WalletStar like every other Stars counter.
  do
   local Kit=require(client.DeckKit);local WalletStar=require(client.WalletStar)
   local spec=Kit.WalletSpec[view.wallet.height]
   assert(spec and spec.star>=WalletStar.MinSize and view.wallet.star.Size.X.Offset>=WalletStar.MinSize,"results wallet Star is under WalletStar.MinSize")
   assert(view.wallet.star3D and view.wallet.star3D.state~="2D","results wallet did not ask for the 3D Star (state "..tostring(view.wallet.star3D and view.wallet.star3D.state)..")")
   local chip=view.wallet.root
   assert(chip.AbsolutePosition.Y+chip.AbsoluteSize.Y<=view.left.AbsolutePosition.Y+view.left.AbsoluteSize.Y+.5 and chip.AbsolutePosition.Y>=view.payout.AbsolutePosition.Y+view.payout.AbsoluteSize.Y-.5,"wallet chip sits in the pane's foot, under the payout rows")
  end
  -- Goals: all rows above the actions, the count in the title.
  assert(view.goalTitle.Text=="Goals  1/2","goal count "..view.goalTitle.Text)
  assert(view.grid,"2 x 2 actions expected at this width")
  local b1,b3,b5,b2=view.buttons[1],view.buttons[3],view.buttons[5],view.buttons[2]
  assert(b1.Position.Y.Offset==b3.Position.Y.Offset and b5.Position.Y.Offset==b2.Position.Y.Offset and b5.Position.Y.Offset>b1.Position.Y.Offset,"grid rows")
  for _,button in ipairs({b1,b3,b5,b2})do assert(button.Size.X.Offset>=44 and button.Size.Y.Offset>=44,"target under 44")end
  local goalsBottom=view.goalLabels[2].Position.Y.Offset+view.goalLabels[2].Size.Y.Offset
  assert(goalsBottom<=view.goals.Size.Y.Offset,"a goal row sits under the actions")
  -- Entry: nothing shown on the first frame, everything at rest by 1 s, no jump in the dim.
  view.opened=os.clock();view.settled=nil;view:step()
  assert(view.root.BackgroundTransparency>.95 and view.middle.GroupTransparency>.95 and view.left.GroupTransparency==1 and view.right.GroupTransparency==1,"entry does not start hidden")
  view.opened=os.clock()-.11;view:step();local a=view.root.BackgroundTransparency
  view.opened=os.clock()-.13;view:step();local b=view.root.BackgroundTransparency
  assert(math.abs(a-b)<.2,"the dim jumps (was .45 to 0 at 0.12 s)")
  view.opened=os.clock()-1.2;view:step()
  assert(view.root.BackgroundTransparency==0 and view.left.GroupTransparency==0 and view.right.GroupTransparency==0 and view.middle.GroupTransparency==0,"entry not finished by 1 s")
  assert(view.left.Position==UDim2.fromOffset(R.left.x,R.left.y)and view.right.Position==UDim2.fromOffset(R.right.x,R.right.y)and view.middle.Position==UDim2.fromOffset(R.middle.x,R.middle.y),"panes not at rest")
  assert(math.abs(view.star.scale.Scale-1)<1e-6 and view.headline.root.Rotation==-3,"Star and headline not at rest")
  -- The Star turns all the way round at 45 degrees a second; the face hides on the back.
  local function at(seconds)view.opened=os.clock()-seconds;view:step();return view.star.wantYaw end
  assert(math.abs(at(2)-90)<2 and not view.face.face.Visible,"quarter turn")
  assert(math.abs(at(4)-180)<2 and not view.face.face.Visible,"back")
  assert(math.abs(at(6)-270)<2,"three quarters")
  local front=at(8.02);assert(front<3 and view.face.face.Visible,"front again after a full turn, got "..front)
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
