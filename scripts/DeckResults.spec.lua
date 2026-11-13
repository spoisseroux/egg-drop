-- Studio Client. In-deck results (UI-SPEC-2026-11-12 5.3, redesigned by
-- UI-SPEC-REDESIGN-CELEBRATIONS 2): Star count-up, payout, pending save, loss,
-- compact, focus with the Hatch button, headline choice and the next egg meter.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckResults)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Results=require(client.DeckResults);local Kit=require(client.DeckKit)
 local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_DeckResultsSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local host=Instance.new("Frame");host.Size=UDim2.fromOffset(848,608);host.BackgroundTransparency=1;host.Parent=gui
 local inner=Instance.new("Frame");inner.Size=UDim2.fromScale(1,1);inner.BackgroundTransparency=1;inner.Parent=host
 local reduced,cues=false,{}
 local audio={group={Volume=1},deviceActive=true,deviceEpoch=0}
 function audio:play(name,pitch,volume)table.insert(cues,{name=name,pitch=pitch});return true end
 function audio:stopOwner()end
 local view=Results.new(inner,{audio=audio,reduce=function()return reduced end})
 local actions={}
 view:on("replay",function()table.insert(actions,"replay")end);view:on("leave",function()table.insert(actions,"leave")end)
 view:on("hatch",function()table.insert(actions,"hatch")end)
 local function receipt(sequence,total)
  return{status="Saved",receiptPending=false,sequence=sequence,reward={sequence=sequence,total=total,base=6,daily=total-6,contracts={}}}
 end
 local function data(sequence,total,changes)
  local value={outcome="clear",title="Creek crossing",difficulty="Medium",total=total,earned=total,balance=140,
   rows={{name="Round win",amount=6},{name="Daily quests",amount=total-6}},
   goals={{text="Match I + I in CENTER",short="II centre",done=true},{text="Make III or higher on RIGHT",short="III RIGHT",done=true}},
   score=2340,best=2210,chain=4,newBest=true,strip="Chain 3 merges ★+3",stripRight="You can hatch an egg",eggName="Toy Egg",eggCost=8,
   quest={scope="daily",title="Win 2 rounds",count=1,target=2,moved=1},result=receipt(sequence,total)}
  for key,item in pairs(changes or {})do value[key]=item end
  return value
 end
 local function step(seconds)
  if view.feedback.connection then view.feedback.connection:Disconnect();view.feedback.connection=nil end
  local left=seconds;while left>1e-6 do local dt=math.min(.01,left);view.feedback:step(dt);left-=dt end
 end
 local ok,problem=pcall(function()
  -- Pure rules.
  test("headline: first match wins (tidy, new best, Hard, win, missed, overflow)",function()
   assert(Results.headline({outcome="clear",tidy=true,newBest=true,level=3})=="TIDY WIN!")
   assert(Results.headline({outcome="clear",newBest=true,level=3})=="NEW BEST!")
   assert(Results.headline({outcome="clear",level=3})=="SPICY WIN!"and Results.headline({outcome="clear",difficulty="Hard"})=="SPICY WIN!")
   assert(Results.headline({outcome="clear",level=1})=="ROUND CLEAR!")
   local text,missed=Results.headline({outcome="missed",tidy=true});assert(text=="SO CLOSE!"and missed)
   text,missed=Results.headline({outcome="overflow"});assert(text=="TOO TALL!"and missed)
  end)
  test("next egg meter: one segment per Star, full at the egg cost, at most 10 segments",function()
   local m=Results.meter(6,8);assert(m.segments==8 and m.filled==6 and not m.ready and m.label=="6/8")
   m=Results.meter(8,8);assert(m.filled==8 and m.ready and m.label=="Ready to hatch!")
   m=Results.meter(140,8);assert(m.filled==8 and m.ready and m.held==8)
   m=Results.meter(0,8);assert(m.filled==0 and m.label=="0/8")
   m=Results.meter(8,16);assert(m.segments==10 and m.filled==5 and m.label=="8/16")
   m=Results.meter(-3,nil);assert(m.cost==8 and m.filled==0)
  end)
  test("focus order: desktop Replay, Hatch, Leave; phone Leave, shortcut or Hatch, Difficulty, Replay",function()
   local function same(a,b)if #a~=#b then return false end;for i=1,#a do if a[i]~=b[i]then return false end end;return true end
   assert(same(Results.order(false,false),{1,2})and same(Results.order(false,true),{1,5,2}))
   assert(same(Results.order(true,false,true),{2,4,3,1})and same(Results.order(true,true,true),{2,5,3,1})and same(Results.order(true,false,false),{2,3,1}))
   assert(same(Results.phoneOrder(true),{2,4,3,1}))
  end)
  test("warm line uses the pet's name and rotates",function()
   assert(Results.warmLine("Bear",0)=="Bear still thinks you're great.")
   assert(Results.warmLine("Bear",1)=="Bear saw that last merge. Bear was impressed.")
   assert(Results.warmLine("Bear",5)==Results.warmLine("Bear",2))
  end)
  -- View.
  test("results open on Replay with the exact Stars total, payout rows, goals, metrics and strip",function()
   view:show(data(901,12),false)
   assert(view.visible and view.focus==1 and view.eyebrow.Text=="NEW BEST!")
   assert(view.rows[1].name.Text=="Round win"and view.rows[1].amount.Text=="6"and view.rows[2].amount.Text=="+6")
   assert(view.totalAmount.Text=="★ 12"and view.goalsCount.Text=="2/2")
   assert(view.metrics[1].Text=="2,340"and view.metrics[3].Text=="×4")
   assert(view.questTitle.Text=="Win 2 rounds"and view.questMoved.Text=="+1 this round"and view.questCountText.Text=="1/2")
   assert(view.hintRight.Text:find("Replay keeps Medium.",1,true))
   assert(view.star.root and view.unit.Visible and not view.missText.Visible)
  end)
  test("Stars count up from 0 once per saved receipt, one rising count blip per Star; wallet and meter count with it",function()
   assert(view.feedback.active and view.totalText.Text=="+0","count starts at 0")
   assert(view.wallet.amount.Text=="128","wallet starts at the balance before this payout")
   step(.75);local mid=tonumber(view.totalText.Text:match("%+(%d+)"));assert(mid and mid>0 and mid<12,"partial "..view.totalText.Text)
   assert(view.skipHint.Visible and not view.hints.Visible,"A Skip the count while counting")
   step(2);assert(not view.feedback.active and view.totalText.Text=="+12"and view.wallet.amount.Text=="140")
   assert(view.hints.Visible and not view.skipHint.Visible and view.newBest.root.Visible)
   local ticks,land,total=0,0,0
   for _,cue in ipairs(cues)do if cue.name=="count_blip"then ticks+=1 elseif cue.name=="star_land"then land+=1 elseif cue.name=="stars_total"then total+=1 end end
   assert(ticks>=1 and ticks<=12 and land==1 and total==1)
   local starts=view.feedback.starts;view:hide();view:show(data(901,12),false)
   assert(view.feedback.starts==starts and view.totalText.Text=="+12","reopening the same receipt cannot replay")
  end)
  test("first A finishes the count-up, the second replays; B always leaves",function()
   table.clear(actions);view:hide();view:show(data(902,9),false);assert(view.feedback.active)
   assert(view:confirm()and #actions==0 and view.totalText.Text=="+9","first press only skips the count")
   assert(view:confirm()and actions[1]=="replay")
   assert(view:back()and actions[2]=="leave"and view.focus==2)
  end)
  test("left/right move between exactly two targets and never wrap",function()
   view.focus=1;view:paintFocus()
   assert(view:move(-1)and view.focus==1);assert(view:move(1)and view.focus==2);assert(view:move(1)and view.focus==2)
   assert(view.ring.root.Visible and view.ring.target==view.leave)
  end)
  test("an affordable egg adds the gold Hatch button between Replay and Leave",function()
   table.clear(actions);view:hide();view:show(data(907,6,{canHatch=true}),false);view:confirm()
   assert(view.hatch.Visible and view.hatch.Position==UDim2.fromOffset(432,484)and view.leave.Size==UDim2.fromOffset(160,64))
   assert(Kit.buttonState(view.hatch).variant=="reward")
   view.focus=1;assert(view:move(1)and view.focus==5);assert(view:move(1)and view.focus==2);assert(view:move(-1)and view.focus==5)
   assert(view:confirm()and actions[1]=="hatch")
   view:hide();view:show(data(908,6,{canHatch=false}),false);view:confirm()
   assert(not view.hatch.Visible and view.leave.Size==UDim2.fromOffset(392,64))
  end)
  test("a pending save disables Replay and Hatch, reads Saving… and moves focus to Leave",function()
   table.clear(actions);view:hide()
   view:show(data(903,0,{pending=true,canHatch=true,result={status="Saving",sequence=903}}),false)
   local replay=Kit.buttonState(view.replay)
   assert(not replay.enabled and replay.label.Text=="Saving…"and view.focus==2 and view.totalText.Text=="Saving…")
   assert(not Kit.buttonState(view.hatch).enabled)
   assert(view:move(-1)and view.focus==2,"focus cannot land on a disabled Replay or Hatch")
   view:confirm();assert(actions[1]=="leave")
  end)
  test("a loss shows the glass Star, No Stars this time, the warm line and Try again",function()
   view:hide();view:show(data(904,0,{outcome="overflow",loss=true,rows={},petName="Bear",result=receipt(904,0)}),false)
   assert(view.eyebrow.Text=="TOO TALL!"and view.missText.Visible and not view.totalText.Visible and view.rows[1].name.Text=="No Stars this round")
   assert(view.star.mode=="glass"and view.warmText.Visible and view.warmText.Text:find("Bear",1,true))
   assert(Kit.buttonState(view.replay).enabled and Kit.buttonState(view.replay).label.Text=="Try again"and view.focus==1)
   assert(view.meterStatus.Text=="8/8"or view.meterStatus.Text=="Ready to hatch!")
  end)
  test("Reduced Motion shows the final value with no count-up",function()
   reduced=true;view:hide();view:show(data(905,7),false)
   assert(not view.feedback.active and view.totalText.Text=="+7"and view.star.root.Rotation==0);reduced=false
  end)
  test("Star token: 3D mesh when it loads, the 2D glyph Star as the fallback, glass on a miss",function()
   -- Fallback path: no mesh requested, so the glyph Star shows and the viewport stays hidden.
   local fbHost=Instance.new("Frame");fbHost.Size=UDim2.fromOffset(848,608);fbHost.BackgroundTransparency=1;fbHost.Parent=gui
   local fbInner=Instance.new("Frame");fbInner.Size=UDim2.fromScale(1,1);fbInner.BackgroundTransparency=1;fbInner.Parent=fbHost
   local fallback=Results.new(fbInner,{reduce=function()return true end,starMesh=false})
   fallback:show(data(911,6),false)
   assert(not fallback.star.has3D and fallback.star.body.Visible and not fallback.star.viewport.Visible,"2D fallback Star must show")
   fallback.star.setSpin(90,12);assert(fallback.star.root.Rotation==12,"2D fallback spins in-plane")
   fallback:show(data(912,0,{outcome="missed",loss=true,rows={},result=receipt(912,0)}),false)
   assert(fallback.star.mode=="glass"and fallback.star.body.Visible,"2D glass Star on a miss")
   fallback:hide();fbHost:Destroy()
   -- Mesh path: once loaded (or failed) the view shows exactly one of the two.
   local C=require(client.CelebrationKit)
   local waited=0
   while C.starMeshState()=="loading"and waited<5 do waited+=task.wait(.1)end
   view:hide();view:show(data(913,6),false);view:confirm();task.wait()
   if C.starMeshState()=="ready"then
    assert(view.star.has3D and view.star.viewport.Visible and not view.star.body.Visible,"3D Star replaces the glyph")
    assert(view.star.part and view.star.part.Size==require(game.ReplicatedStorage.Shared.EggModels).Star.size,"StarToken sized from EggModels")
    view.star.setSpin(45,30);assert(view.star.root.Rotation==0,"3D spins about +Y, not in-plane")
    view:hide();view:show(data(914,0,{outcome="missed",loss=true,rows={},result=receipt(914,0)}),false)
    assert(view.star.mode=="glass"and view.star.part.TextureID==""and view.star.part.Transparency>0,"pale glass Star on a miss")
   else
    assert(view.star.body.Visible and not view.star.viewport.Visible,"mesh unavailable: the 2D Star stays")
   end
  end)
  test("compact results (417x299) keep Replay/Leave at 48 px and the short goal copy",function()
   host.Size=UDim2.fromOffset(417,299);view:hide();view:show(data(906,5),true);task.wait()
   assert(view.compact and view.replay.AbsoluteSize.Y>=44 and view.leave.AbsoluteSize.Y>=44)
   assert(view.goals[1].text.Text=="II centre"and view.rows[1].name.Text=="Total")
   host.Size=UDim2.fromOffset(848,608)
  end)
  test("phone results: Hatch takes the shortcut cell and joins the focus order",function()
   view:hide()
   local v={phone=true,W=748,H=294,kx=0,kh=0,hx=26,cw=229,ch=154,actionY=228,off=32,mg=38,top=60}
   host.Size=UDim2.fromOffset(748,294)
   view:show(data(909,6,{canHatch=true,questDone="Win 2 rounds"}),v);view:confirm()
   assert(view.phone and view.hatch.Visible and not view.questButton.Visible and view.questTarget==nil)
   assert(Kit.buttonState(view.hatch).label.Text=="Hatch Toy Egg")
   view.focus=2;assert(view:move(1)and view.focus==5);assert(view:move(1)and view.focus==3);assert(view:move(1)and view.focus==1)
   view:hide();view:show(data(910,6,{canHatch=false,questDone=nil}),v)
   assert(not view.hatch.Visible and view.questButton.Visible and view.questText.Text=="Win 2 rounds 1/2")
   host.Size=UDim2.fromOffset(848,608)
  end)
  test("Leave copy (UICopy results.leave.*): every layout branch uses the same keys and the label fits its button",function()
   local keys={UICopy.get("results.leave.wide"),UICopy.get("results.leave.mid"),UICopy.get("results.leave.narrow")}
   local function fits(button)
    local s=Kit.buttonState(button);local label=s.label.Text
    assert(table.find(keys,label),"Leave label comes from UICopy: "..label)
    assert(26+10+Kit.measure(label,"Button",s.label.TextSize).X<=button.AbsoluteSize.X,"Leave label fits its button: "..label)
    return label
   end
   -- Pure rule: wide when it fits, then mid, then narrow.
   assert(Results.leaveText(392,function(t)return #t*10 end)==keys[1]and Results.leaveText(170,function(t)return #t*8 end)==keys[2]
    and Results.leaveText(100,function(t)return #t*10 end)==keys[3])
   view:hide();host.Size=UDim2.fromOffset(848,608);view:show(data(911,6,{canHatch=false}),false);task.wait()
   assert(fits(view.leave)==keys[1],"desktop Leave 392 reads "..keys[1])
   view:hide();view:show(data(912,6,{canHatch=true}),false);task.wait()
   assert(fits(view.leave)==keys[3],"desktop Leave beside Hatch (160) reads "..keys[3])
   view:hide();host.Size=UDim2.fromOffset(417,299);view:show(data(913,5),true);task.wait();fits(view.leave)
   local v={phone=true,W=748,H=294,kx=0,kh=0,hx=26,cw=229,ch=154,actionY=228,off=32,mg=38,top=60}
   view:hide();host.Size=UDim2.fromOffset(748,294);view:show(data(914,6),v);task.wait();fits(view.leave)
   -- Wallet line: the voiced copy, the same key in every branch.
   assert(view.saved.Text==UICopy.get("results.saved.done")or view.saved.Text==UICopy.get("results.saved.pending"))
   view:hide();host.Size=UDim2.fromOffset(848,608)
  end)
 end)
 view:hide();gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
