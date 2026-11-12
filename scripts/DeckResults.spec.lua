-- Studio Client. In-deck results (UI-SPEC-2026-11-12 5.3): Stars count-up, payout,
-- pending save, loss, compact, and the two-target Replay/Leave focus. Replaces the
-- CompactRecap, RewardPresentation and RoundRecapClarity specs of the floating recap.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckResults)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Results=require(client.DeckResults);local Kit=require(client.DeckKit)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_DeckResultsSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local host=Instance.new("Frame");host.Size=UDim2.fromOffset(848,608);host.BackgroundTransparency=1;host.Parent=gui
 local inner=Instance.new("Frame");inner.Size=UDim2.fromScale(1,1);inner.BackgroundTransparency=1;inner.Parent=host
 local reduced,cues=false,{}
 local audio={group={Volume=1},deviceActive=true,deviceEpoch=0}
 function audio:play(name,pitch,volume)table.insert(cues,{name=name,pitch=pitch});return true end
 function audio:stopOwner()end
 local view=Results.new(inner,{audio=audio,reduce=function()return reduced end})
 local actions={};view:on("replay",function()table.insert(actions,"replay")end);view:on("leave",function()table.insert(actions,"leave")end)
 local function receipt(sequence,total)
  return{status="Saved",receiptPending=false,sequence=sequence,reward={sequence=sequence,total=total,base=6,daily=total-6,contracts={}}}
 end
 local function data(sequence,total,changes)
  local value={outcome="clear",title="Creek crossing",difficulty="Medium",total=total,earned=total,balance=140,
   rows={{name="Round win",amount=6},{name="Daily quests",amount=total-6}},
   goals={{text="Match I + I in CENTER",short="II centre",done=true},{text="Make III or higher on RIGHT",short="III RIGHT",done=true}},
   score=2340,best=2210,chain=4,newBest=true,strip="Chain 3 merges ★+3",stripRight="You can hatch an egg",result=receipt(sequence,total)}
  for key,item in pairs(changes or {})do value[key]=item end
  return value
 end
 local function step(seconds)
  if view.feedback.connection then view.feedback.connection:Disconnect();view.feedback.connection=nil end
  local left=seconds;while left>1e-6 do local dt=math.min(.01,left);view.feedback:step(dt);left-=dt end
 end
 local ok,problem=pcall(function()
  test("results open on Replay with the exact Stars total, payout rows, goals and metrics",function()
   view:show(data(901,12),false)
   assert(view.visible and view.focus==1 and view.eyebrow.Text=="ROUND CLEAR")
   assert(view.rows[1].name.Text=="Round win"and view.rows[1].amount.Text=="6"and view.rows[2].amount.Text=="+6")
   assert(view.totalAmount.Text=="★ 12"and view.wallet.amount.Text=="140"and view.goalsCount.Text=="2/2")
   assert(view.metrics[1].Text=="2340"and view.metrics[3].Text=="×4"and view.newBest.root.Visible)
   assert(view.stripText.Text:find("Chain 3 merges",1,true)and view.hintRight.Text=="Replay keeps Medium.")
  end)
  test("Stars count up from 0 once per saved receipt, one rising charge tick per Star",function()
   assert(view.feedback.active and view.totalText.Text=="+0 Stars","count starts at 0")
   step(.7);local mid=tonumber(view.totalText.Text:match("%+(%d+)"));assert(mid and mid>0 and mid<12,"partial "..view.totalText.Text)
   step(1.5);assert(not view.feedback.active and view.totalText.Text=="+12 Stars")
   local ticks=0;for _,cue in ipairs(cues)do if cue.name=="charge"then ticks+=1 end end;assert(ticks>=1 and ticks<=12)
   local starts=view.feedback.starts;view:hide();view:show(data(901,12),false)
   assert(view.feedback.starts==starts and view.totalText.Text=="+12 Stars","reopening the same receipt cannot replay")
  end)
  test("first A finishes the count-up, the second replays; B always leaves",function()
   table.clear(actions);view:hide();view:show(data(902,9),false);assert(view.feedback.active)
   assert(view:confirm()and #actions==0 and view.totalText.Text=="+9 Stars","first press only skips the count")
   assert(view:confirm()and actions[1]=="replay")
   assert(view:back()and actions[2]=="leave"and view.focus==2)
  end)
  test("left/right move between exactly two targets and never wrap",function()
   view.focus=1;view:paintFocus()
   assert(view:move(-1)and view.focus==1);assert(view:move(1)and view.focus==2);assert(view:move(1)and view.focus==2)
   assert(view.ring.root.Visible and view.ring.target==view.leave)
  end)
  test("a pending save disables Replay, reads Saving… and moves focus to Leave",function()
   table.clear(actions);view:hide()
   view:show(data(903,0,{pending=true,result={status="Saving",sequence=903}}),false)
   local replay=Kit.buttonState(view.replay)
   assert(not replay.enabled and replay.label.Text=="Saving…"and view.focus==2 and view.totalText.Text=="Saving…")
   assert(view:move(-1)and view.focus==2,"focus cannot land on a disabled Replay")
   view:confirm();assert(actions[1]=="leave")
  end)
  test("a loss reads 0 Stars and No Stars this round with Replay still the primary",function()
   view:hide();view:show(data(904,0,{outcome="overflow",loss=true,rows={},result=receipt(904,0)}),false)
   assert(view.eyebrow.Text=="OVERFLOW"and view.totalText.Text=="0 Stars"and view.rows[1].name.Text=="No Stars this round")
   assert(Kit.buttonState(view.replay).enabled and view.focus==1)
  end)
  test("Reduced Motion shows the final value with no count-up",function()
   reduced=true;view:hide();view:show(data(905,7),false)
   assert(not view.feedback.active and view.totalText.Text=="+7 Stars");reduced=false
  end)
  test("compact results (417x299) keep Replay/Leave at 48 px and the short goal copy",function()
   host.Size=UDim2.fromOffset(417,299);view:hide();view:show(data(906,5),true);task.wait()
   assert(view.compact and view.replay.AbsoluteSize.Y>=44 and view.leave.AbsoluteSize.Y>=44)
   assert(view.goals[1].text.Text=="II centre"and view.rows[1].name.Text=="Total")
  end)
 end)
 view:hide();gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
