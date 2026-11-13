-- Studio Client. QA 2026-11-13 slice Q1 (Pocket Deck round + results): the world
-- camera freeze, the whole-deck merge shake (and its Reduced Motion cut), Goals rows
-- and the side-panel personality, Kit.tabs keeping its pill inside the track, item
-- icons and the "+ Magnet" grant toast, settle feedback and the first-drop idle hint,
-- the results Star (constant spin, silver miss look, lose cue) and the flourish tail.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckRoundQA)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Kit=require(client.DeckKit);local Assets=require(client.DeckAssets)
 local Screen=require(client.DeckScreen)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function near(a,b,e)return math.abs(a-b)<=(e or .51)end
 local aspect=(11+.8)/(19+.8)
 local gui=Instance.new("ScreenGui");gui.Name="_DeckRoundQASpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local realReduced=Kit.reduced
 local function motion(reduced)Kit.reduced=function()return reduced end end
 local ok,problem=pcall(function()
  test("camera freeze: Scriptable while the deck is up, the previous type back on exit, never stealing a camera someone else took",function()
   local Lock=require(client.DeckCameraLock)
   local camera=Instance.new("Camera");camera.CameraType=Enum.CameraType.Custom
   camera.CFrame=CFrame.new(1,2,3)*CFrame.Angles(0,.4,0)
   local lock=Lock.new()
   assert(lock:freeze(camera)and lock:isFrozen()and camera.CameraType==Enum.CameraType.Scriptable,"frozen")
   assert(camera.CFrame==CFrame.new(1,2,3)*CFrame.Angles(0,.4,0),"the view does not move")
   assert(lock:freeze(camera)and camera.CameraType==Enum.CameraType.Scriptable,"idempotent")
   assert(lock:release()and camera.CameraType==Enum.CameraType.Custom,"released to Custom")
   assert(not lock:release(),"release twice is a no-op")
   lock:freeze(camera);camera.CameraType=Enum.CameraType.Fixed
   lock:release();assert(camera.CameraType==Enum.CameraType.Fixed,"a camera taken over meanwhile is left alone")
   assert(not lock:freeze(nil),"no camera, no freeze")
   camera:Destroy()
  end)
  test("Kit.tabs: the pill never leaves the track (click + the owner's re-select, rapid switches) and lands on its segment",function()
   motion(false)
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(500,100);host.BackgroundTransparency=1;host.Parent=gui
   local tabs=Kit.tabs(host,{"Faceplates","Backgrounds","Balls"},355,44,16,{"faceplate","pattern","smiley"});settle()
   local track,pill=tabs.root,tabs.root.Pill
   local x,size=tabs.pillRect(3);assert(x+size.X==355-4,"last segment ends at the inner edge")
   assert(tabs.squashX(240,240,7,116)<=355-4-(116+7),"squash clamped at the right edge")
   assert(tabs.squashX(4,4,7,116)>=4,"squash clamped at the left edge")
   local function rightEdge()return pill.AbsolutePosition.X+pill.AbsoluteSize.X end
   local limit=track.AbsolutePosition.X+track.AbsoluteSize.X-4+1
   -- Click on Balls, then the owner's applyTab selects it again in the same frame.
   tabs.select(3);tabs.select(3)
   local worst,started=0,os.clock()
   while os.clock()-started<Kit.Motion.tab+.15 do worst=math.max(worst,rightEdge());game:GetService("RunService").RenderStepped:Wait()end
   assert(worst<=limit,"pill stayed inside the track (worst "..worst..", limit "..limit..")")
   assert(near(pill.Position.X.Offset,x,1)and near(pill.Size.X.Offset,size.X,1),"landed on the Balls segment")
   -- Rapid switches.
   tabs.select(1);task.wait(.03);tabs.select(3);task.wait(.02);tabs.select(2);tabs.select(3)
   worst,started=0,os.clock()
   while os.clock()-started<Kit.Motion.tab+.15 do worst=math.max(worst,rightEdge());game:GetService("RunService").RenderStepped:Wait()end
   assert(worst<=limit and near(pill.Position.X.Offset,x,1)and near(pill.Size.X.Offset,size.X,1),"rapid switches still land inside")
   local _,first=tabs.pillRect(1)
   motion(true);tabs.select(1);assert(pill.Position.X.Offset==4 and pill.Size.X.Offset==first.X,"Reduced Motion snaps")
   Kit.reduced=realReduced;host:Destroy()
  end)
  test("merge shake: the whole deck moves with the jolt, hardware hit rects stay put, Reduced Motion cuts it, layout keeps it",function()
   motion(false)
   local root=Instance.new("Frame");root.Size=UDim2.fromOffset(1920,1080);root.BackgroundTransparency=1;root.Parent=gui
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(Vector2.new(1920,1080),aspect);s:setVisible(true);settle()
   local base=s.root.AbsolutePosition
   local hits={}
   for _,hit in ipairs(s:shakeHits())do hits[hit]=hit.AbsolutePosition end
   assert(Screen.shakeOffset(Vector2.new(2.6,-1.2),false)==Vector2.new(3,-1)and Screen.shakeOffset(Vector2.new(3,3),true)==Vector2.zero)
   assert(s:setShake(Vector2.new(3,-2),false));settle()
   assert((s.root.AbsolutePosition-(base+Vector2.new(3,-2))).Magnitude<.6,"shell + LCD moved")
   for hit,at in pairs(hits)do assert((hit.AbsolutePosition-at).Magnitude<.6,hit:GetFullName().." hit rect moved")end
   s:layout(Vector2.new(1920,1080),aspect);settle()
   assert((s.root.AbsolutePosition-(base+Vector2.new(3,-2))).Magnitude<.6,"a layout mid-shake keeps the offset")
   for hit,at in pairs(hits)do assert((hit.AbsolutePosition-at).Magnitude<.6,"hit rect stays after layout")end
   s:setShake(Vector2.new(3,-2),true);settle()
   assert((s.root.AbsolutePosition-base).Magnitude<.6,"Reduced Motion: no shake")
   for hit,at in pairs(hits)do assert((hit.AbsolutePosition-at).Magnitude<.6)end
   motion(true);s:setShake(Vector2.new(4,4),false);settle();assert((s.root.AbsolutePosition-base).Magnitude<.6,"Kit.reduced() also cuts it")
   Kit.reduced=realReduced;root:Destroy()
  end)
  test("Goals rows: even gaps for 1-3 goals, check centred on the text, colour circles capped at the text size",function()
   for _,lines in ipairs({{1},{2},{1,2},{2,2},{1,1,1},{2,2,2},{1,2,1}})do
    local rows,gap=Screen.goalRows(lines)
    local G=Screen.GoalRows
    assert(rows[1].y==G.top and rows[#rows].y+rows[#rows].h<=G.bottom,"rows inside the card")
    for i,r in ipairs(rows)do
     assert(math.abs((r.checkY+G.check/2)-r.textH/2)<=1,"check centred on the text block")
     if i>1 then assert(r.y-(rows[i-1].y+rows[i-1].h)==gap,"even gap")end
    end
   end
   local capped=Screen.capCircles('Match <font color="#1" size="21">●</font> + <font color="#2" size="9">●</font>',16)
   assert(capped:find('size="16"',1,true)and capped:find('size="9"',1,true)and not capped:find('size="21"',1,true))
   local root=Instance.new("Frame");root.Size=UDim2.fromOffset(1920,1080);root.BackgroundTransparency=1;root.Parent=gui
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(Vector2.new(1920,1080),aspect);settle()
   local BallThemes=require(game.ReplicatedStorage.Shared.BallThemes)
   s:setHud({score=0,goals={{text="Match "..BallThemes.circle(5,14).." + "..BallThemes.circle(5,14).." in CENTER",progress=0,target=1},
    {text="Make "..BallThemes.circle(3,14).." or bigger on RIGHT",progress=0,target=1}},next={1,1,1},eggsLeft=24,budget=24})
   local h=s.hud;local card=h.goals[1].row.Parent
   assert(card.Size==UDim2.fromOffset(s.geometry.column,244)and card.Position==UDim2.fromOffset(s.geometry.pad,188),"Goals card rect unchanged")
   local a,b=h.goals[1],h.goals[2]
   assert(a.text.TextYAlignment==Enum.TextYAlignment.Center,"goal text centred on its row")
   for n in string.gmatch(a.text.Text,'size="(%d+)"')do assert(tonumber(n)<=a.text.TextSize,"circle capped at the text size")end
   assert(b.row.Position.Y.Offset>a.row.Position.Y.Offset+a.row.Size.Y.Offset,"rows do not overlap")
   assert(not h.goals[3].row.Visible)
   root:Destroy()
  end)
  test("side panels: seams on the tall panes, quests tint on Goals and Daily quests, a sticker multiplier, Fredoka name, hint caps; rects unchanged",function()
   local root=Instance.new("Frame");root.Size=UDim2.fromOffset(1920,1080);root.BackgroundTransparency=1;root.Parent=gui
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(Vector2.new(1920,1080),aspect);s:setVisible(true)
   s:setHud({score=10,goals={{text="Make 2 merges anywhere",progress=1,target=2}},daily={{title="Finish 3 rounds",progress=1,target=3}},next={1,2,3},eggsLeft=20,budget=24,difficulty="Easy",multiplier="×0.8",input="Keyboard"})
   settle()
   local hud=s.hudRoot;local h=s.hud
   local expected={Score={12,96},Chain={116,64},Goals={188,244},DailyQuests={440,156},Next={12,140},EggsLeft={160,96},Difficulty={264,72},WinPays={344,84},Controls={436,160}}
   for name,r in pairs(expected)do
    local c=hud:FindFirstChild(name);assert(c and c.Position.Y.Offset==r[1]and c.Size.Y.Offset==r[2],name.." rect unchanged")
   end
   if Assets.Personality.seam then
    assert(hud.Goals:FindFirstChild("Seam")and hud.Goals.Seam.Visible,"Goals pane is stitched")
    assert(not(hud.Score:FindFirstChild("Seam")and hud.Score.Seam.Visible),"short panes stay plain")
   end
   assert(h.goalsEyebrow:FindFirstChild("TintDot")and hud.DailyQuests.Eyebrow:FindFirstChild("TintDot"),"tint dot + eyebrow")
   assert(h.goalsEyebrow.TextColor3==Kit.Tint.quests,"tinted eyebrow")
   s:setHud({score=10,goals={},statusLabel="Settling…",next={1,1,1},eggsLeft=0,budget=24})
   assert(h.goalsEyebrow.TextColor3==Kit.Color.stars and h.goalsEyebrow.Text=="SETTLING…","status line in Stars gold")
   assert(h.diffChip.root:GetAttribute("ChipKind")=="sticker","the multiplier is the sticker")
   assert(h.diffName.FontFace.Family==Kit.DisplayFace.Family,"difficulty name in the display face")
   local caps=0
   for _,slot in ipairs(h.controls)do local g=slot.holder:FindFirstChild("Glyph");if g and g:GetAttribute("GlyphCap")then caps+=1 end end
   assert(caps>=2,"B and M are the deck's grey caps")
   root:Destroy()
  end)
  test("item icons: four vector icons inside their box, on the carousel, belt chip, phone button and the + Magnet toast",function()
   local Icons=require(client.ItemIcons);local Items=require(game.ReplicatedStorage.Shared.RoundItems)
   local Carousel=require(client.ItemCarousel)
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(400,600);host.BackgroundTransparency=1;host.Parent=gui
   for _,id in ipairs(Icons.Kinds)do
    assert(Items.ById[id]and Icons.source(id)~=nil,id)
    local icon=Icons.new(host,48,id);settle()
    assert(icon:GetAttribute("ItemId")==id and #icon:GetChildren()>1,id.." drawn")
    for _,part in ipairs(icon:GetDescendants())do
     if part:IsA("Frame")and part.Rotation==0 then
      local p,sz=part.AbsolutePosition-icon.AbsolutePosition,part.AbsoluteSize
      assert(p.X>=-1 and p.Y>=-1 and p.X+sz.X<=49 and p.Y+sz.Y<=49,id.." part inside the box")
     end
    end
    icon:Destroy()
   end
   local c=Carousel.new(host);c:place(UDim2.fromOffset(20,0),UDim2.fromOffset(330,580),false)
   c:setBelt({"magnet","pop"});c:setChipVisible(true);assert(c:open());settle()
   assert(c.caps.mid.icon:GetAttribute("ItemId")=="magnet"and not c.caps.mid.glyph.Visible,"carousel shows the icon")
   assert(c.slotIcons[1]:GetAttribute("ItemId")=="magnet"and c.slotIcons[2]:GetAttribute("ItemId")=="pop"and c.slotIcons[3]:GetAttribute("ItemId")==nil,"belt chip slots")
   assert(not c.dots[1].Visible and c.dots[3].Visible,"empty slots keep the dim dot")
   c:close()
   assert(Carousel.grantText("magnet")=="+ Magnet"and Carousel.grantText("nope")==nil)
   assert(c:showGrant("magnet")and c.lastGrant=="+ Magnet"and c.grant.root.Visible and c.grant.icon:GetAttribute("ItemId")=="magnet")
   assert(c.grant.line.Text==Carousel.GrantLine,"says where it came from")
   task.wait(Carousel.GrantHold+Carousel.NoteFade+.3);assert(not c.grant.root.Visible,"toast fades")
   c:destroy()
   local root=Instance.new("Frame");root.Size=UDim2.fromOffset(844,390);root.BackgroundTransparency=1;root.Parent=gui
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(Vector2.new(844,390),aspect,{kx=116,kh=58});s:setVisible(true)
   s:setItems(2,Items.ById.pop.glyph,Items.ById.pop.color,"pop")
   assert(s.itemButton.icon:GetAttribute("ItemId")=="pop"and not s.itemButton.glyph.Visible and s.itemButton.glyph.Text==Items.ById.pop.glyph,"phone button icon")
   s:setItems(0);assert(s.itemButton.glyph.Visible and s.itemButton.glyph.Text=="B","empty belt: plain B")
   root:Destroy();host:Destroy()
  end)
  test("settle feedback and the first-drop idle hint: rules, ticks, device glyphs, first drop hides it, Reduced Motion is static",function()
   local Hints=require(client.BoardHints)
   assert(Hints.idleText("Keyboard"):find("Space",1,true)and Hints.idleText("Gamepad"):find("A to drop",1,true)and Hints.idleText("Touch"):find("Drag",1,true))
   assert(Hints.firstRun("Welcome",0)and not Hints.firstRun("Welcome",1)and not Hints.firstRun("Live",0))
   assert(not Hints.idleWanted({firstRun=true,live=true,idleFor=5.9})and Hints.idleWanted({firstRun=true,live=true,idleFor=6}))
   assert(not Hints.idleWanted({firstRun=true,live=true,idleFor=9,dropped=true})and not Hints.idleWanted({firstRun=false,live=true,idleFor=9}))
   assert(Hints.settleProgress(2)==.5 and Hints.settleProgress(9)==1)
   local t=Hints.ticksBetween(nil,0);assert(#t==1 and t[1]==1)
   t=Hints.ticksBetween(.5,2.1);assert(#t==2 and t[1]==2 and t[2]==3)
   local played={}
   local audio={play=function(_,cue,pitch)table.insert(played,cue)return true end}
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(400,600);host.BackgroundTransparency=1;host.Parent=gui
   local hints=Hints.new(host,{audio=audio});hints:place(UDim2.fromOffset(20,0),UDim2.fromOffset(330,580))
   local base={presented=true,live=true,firstRun=true,input="Keyboard",reduced=false}
   hints:step(100,base);assert(not hints.hint.Visible,"not before ~6 s")
   hints:step(106.1,base);assert(hints.hint.Visible and hints.hintText.Text==Hints.idleText("Keyboard"),"shows after 6 s idle")
   local gp=table.clone(base);gp.input="Gamepad";hints:step(106.2,gp);assert(hints.hintText.Text==Hints.idleText("Gamepad"),"follows the device")
   local red=table.clone(base);red.reduced=true;hints:step(107,red)
   assert(hints.hint.Position==UDim2.new(.5,0,.3,0)and hints.hintScale.Scale==1,"Reduced Motion: still")
   hints:noteDrop();hints:step(120,base);assert(not hints.hint.Visible,"the first drop hides it for good")
   local st={presented=true,settling=true,live=false,firstRun=false,input="Keyboard",reduced=false}
   hints:step(200,st);assert(hints.settle.Visible and #played==1 and played[1]==Hints.TickCue,"chip + first tick")
   hints:step(201.05,st);hints:step(202.5,st);assert(#played==3 and hints.settleFill.Size.X.Scale>.6,"ticks and the bar fills")
   st.presented=false;hints:step(203,st);assert(not hints.settle.Visible,"hidden off the board")
   hints:destroy();host:Destroy()
  end)
  test("results Star: one constant spin from opening (re-shows never reset it), silver on a miss from the first frame, lose cue once",function()
   local Results=require(client.DeckResults)
   assert(Results.spinYaw(0)==0 and near(Results.spinYaw(2),2*Results.SpinRate,.01)and Results.spinYaw(8)<360)
   assert(Results.missLook({outcome="missed",pending=true})and Results.missLook({outcome="overflow"})and not Results.missLook({outcome="clear",pending=true}))
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(848,608);host.BackgroundTransparency=1;host.Parent=gui
   local inner=Instance.new("Frame");inner.Size=UDim2.fromScale(1,1);inner.BackgroundTransparency=1;inner.Parent=host
   local cues={}
   local audio={group={Volume=1},deviceActive=true,deviceEpoch=0}
   function audio:play(name)table.insert(cues,name);return true end
   function audio:stopOwner()end
   local view=Results.new(inner,{audio=audio,reduce=function()return false end,starMesh=false})
   local data={outcome="missed",title="Bank pair",difficulty="Easy",pending=true,earned=0,balance=10,rows={},goals={},score=10,best=20,chain=1}
   view:show(data,false)
   assert(view.star.mode=="glass","silver before the save lands")
   local origin=view.spinOrigin;assert(origin)
   task.wait(.1);local landed=table.clone(data);landed.pending=false;landed.loss=true
   view:show(landed,false);view:show(landed,false)
   assert(view.spinOrigin==origin,"re-showing never restarts the spin")
   local n=0;for _,cue in ipairs(cues)do if cue=="lose"then n+=1 end end
   assert(n==1,"lose plays once per results screen ("..n..")")
   view:hide();cues={}
   local win={outcome="clear",title="Creek",difficulty="Easy",earned=5,balance=15,rows={{name="Round win",amount=5}},goals={},score=10,best=20,chain=1}
   view:show(win,false);assert(view.star.mode=="gold");local o2=view.spinOrigin
   task.wait(.15);view:show(win,false);view.star.setSpin(0,0)
   view:stepIdle();assert(view.spinOrigin==o2,"touch / repaint keeps the origin")
   for _,cue in ipairs(cues)do assert(cue~="lose","no lose cue on a win")end
   view:hide();host:Destroy()
  end)
  test("flourish: a finished count-up releases its voices (they play out); an interrupted one fades them",function()
   local Feedback=require(client.RecapFeedback)
   local calls={release=0,fade=0,stop=0}
   local audio={group={Volume=1},deviceActive=true,deviceEpoch=0}
   function audio:play()return true end
   function audio:releaseOwner()calls.release+=1;return 1 end
   function audio:fadeOwner(_,seconds)calls.fade+=1;assert(seconds==Feedback.TailFade);return 1 end
   function audio:stopOwner()calls.stop+=1 end
   local f=Feedback.new(function()end,audio,false)
   local result={status="Saved",receiptPending=false,sequence=7001,reward={sequence=7001,total=3}}
   assert(f:observe(result,true))
   for _=1,40 do if not f.active then break end;f:step(.2)end
   assert(not f.active and calls.release>=1 and calls.fade==0 and calls.stop==0,"finished: released, not cut")
   local g=Feedback.new(function()end,audio,false)
   assert(g:observe({status="Saved",receiptPending=false,sequence=7002,reward={sequence=7002,total=3}},true))
   g:step(.1);g:cancel();assert(calls.fade==1 and calls.stop==0,"interrupted: faded")
  end)
 end)
 Kit.reduced=realReduced
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
