-- Studio Client. QA v735 D1: the Pocket Deck handheld never leaves the safe area.
-- Fails if any part of the drawn handheld (bumpers, body, plate, glass, screen, d-pad,
-- MENU, A, B / Items and its caption, wordmark, LED) is outside the root, or above the
-- Roblox top-bar keep-out on a phone, at 812x354, 844x390, 926x428 and two tablet sizes,
-- on the first layout and on a later one (hidden, laid out at another size, shown again).
-- The soft drop shadow is not part of the handheld and may fade past the edge.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckFit)(PlayerScripts.Client, PlayerGui)
-- Live:  require(...DeckFit)(PlayerScripts.Client, PlayerGui, true) with the deck open
--        (Mode = Board). It resizes PlayerGui.EggDrop.Backdrop to each size, audits the
--        real deck and puts the Backdrop back. Run it again after leaving and reopening
--        the deck: the rects must equal the first run's (kept in _G.DeckFitLive).
return function(client,parent,live,screenModule)
 -- `screenModule`: another DeckScreen to audit (used once to prove this spec fails on the
 -- pre-fix layout; see artifacts/qa-2026-11-15-v735/QA-TRIAGE.md D1).
 local Screen=require(screenModule or client.DeckScreen);local Kit=require(client.DeckKit)
 local aspect=(11+.8)/(19+.8)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local phones={Vector2.new(812,354),Vector2.new(844,390),Vector2.new(926,428)}
 local tablets={Vector2.new(1024,710),Vector2.new(1180,762)}
 local keeps={{116,58},{208,58},{132,44}}
 local shellNames={"ShoulderL","ShoulderR","Band","Faceplate","FinishOverlay","PlateOverlay","Glass","GlassLip","Screen","LCD",
  "DPad","DPadWell","AWell","MenuPill","ButtonA","ButtonB","ButtonItem","Wordmark","WordmarkShadow","Led"}
 local function shown(node,root)
  local p=node
  while p and p~=root do if p:IsA("GuiObject")and not p.Visible then return false end;p=p.Parent end
  return true
 end
 -- Every drawn part inside [0, W] x [topLimit, H] of the root. Returns a signature of the rects.
 local function audit(deckRoot,o,W,H,topLimit,label)
  local parts={};local seen=0
  local function check(node,name)
   local p,s=node.AbsolutePosition-o,node.AbsoluteSize
   if s.X<=0 or s.Y<=0 then return end
   seen+=1
   local where=string.format("%s %s at %d,%d %dx%d in %dx%d (top limit %d)",label,name,p.X,p.Y,s.X,s.Y,W,H,topLimit)
   assert(p.X>=-.5,where..": past the left edge")
   assert(p.X+s.X<=W+.5,where..": past the right edge")
   assert(p.Y>=topLimit-.5,where..": above the top limit")
   assert(p.Y+s.Y<=H+.5,where..": past the bottom edge")
   table.insert(parts,string.format("%s=%d,%d,%d,%d",name,p.X,p.Y,s.X,s.Y))
  end
  for _,name in ipairs(shellNames)do
   local node=deckRoot:FindFirstChild(name)
   if node and node:IsA("GuiObject")and shown(node,deckRoot)then check(node,name)end
  end
  local item=deckRoot:FindFirstChild("ButtonItem")
  local caption=item and item:FindFirstChild("Caption",true)
  if caption and shown(caption,deckRoot)then check(caption,"ItemCaption")end
  local menu=deckRoot:FindFirstChild("MenuPill")
  for _,node in ipairs(if menu then menu:GetDescendants()else{})do
   if node:IsA("GuiButton")and shown(node,deckRoot)then check(node,"MenuHit")end
  end
  assert(seen>=10,label..": only "..seen.." handheld parts were drawn")
  return table.concat(parts,";")
 end
 local gui=Instance.new("ScreenGui");gui.Name="_DeckFitSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local ok,problem=xpcall(function()
  test("phone geometry: the body, bumpers, glass and controls resolve inside the root, under the keep-out",function()
   for _,size in ipairs(phones)do for _,keep in ipairs(keeps)do
    local W,H=size.X,size.Y;local kx,kh=keep[1],keep[2]
    local g=Screen.resolveCompact(W,H,aspect,kx,kh)
    local label=string.format("%dx%d keep %dx%d",W,H,kx,kh)
    assert(g.phone and g.W==W and g.H==H,label.." root size kept")
    local function inside(r,name,top)
     assert(r.x>=0 and r.y>=(top or kh)and r.x+r.w<=W and r.y+r.h<=H,string.format("%s %s %d,%d %dx%d leaves the safe area",label,name,r.x,r.y,r.w,r.h))
    end
    inside(g.body,"body");inside(g.shell.shoulderL,"bumper L");inside(g.shell.shoulderR,"bumper R");inside(g.shell.plate,"plate")
    inside(g.glass,"glass");inside(g.screen,"screen");inside(g.board,"board");inside(g.dpad,"d-pad");inside(g.menu,"MENU");inside(g.menuHit,"MENU hit")
    inside(g.aHit,"A");inside(g.item,"Items");inside(g.itemHit,"Items hit")
    if g.wordmark then inside(g.wordmark,"wordmark")end
    if g.led then inside(g.led,"LED")end
    local Fit=Screen.Fit
    assert(g.body.x==Fit.side and g.body.x+g.body.w==W-Fit.side and g.body.y+g.body.h==H-Fit.side,label.." body margins")
    assert(g.shell.shoulderL.y>=kh+1 and g.shell.shoulderL.y<=kh+4,label.." bumpers start just under the top bar, got "..g.shell.shoulderL.y)
    -- The glass sits inside the plate with plate showing above and below it.
    assert(g.glass.y-g.body.y==Fit.crown and g.body.y+g.body.h-(g.glass.y+g.glass.h)==Fit.chin,label.." crown and chin")
    assert(g.glass.y+g.glass.h<=g.shell.plate.y+g.shell.plate.h-2,label.." glass inside the plate")
    for _,r in ipairs({g.dpad,g.menu,g.aHit,g.item})do assert(r.y+r.h<=g.body.y+g.body.h-6,label.." control inside the body")end
    assert(g.board.h>=180 and math.abs(g.board.w/g.board.h-aspect)<.02,label.." board keeps its aspect and a playable size")
   end end
  end)
  test("tablet geometry: the whole handheld resolves inside the root",function()
   for _,size in ipairs(tablets)do
    local g=Screen.resolve(size,aspect,{kx=208,kh=58})
    local label=string.format("%dx%d",size.X,size.Y)
    assert(not g.phone,label.." is not the phone layout")
    local rise=-require(client.DeckAssets).Layout.shoulderL[2]*g.s
    assert(g.deck.x>=0 and g.deck.x+g.deck.w<=size.X and g.deck.y-rise>=0 and g.deck.y+g.deck.h<=size.Y,
     string.format("%s deck %d,%d %dx%d leaves the root",label,g.deck.x,g.deck.y,g.deck.w,g.deck.h))
    assert(g.contentScale>=1,label.." LCD text is not scaled under its authored size, got "..g.contentScale)
   end
  end)
  test("built deck: every drawn part is inside the safe area on the first layout and on a later one",function()
   local all={}
   for _,size in ipairs(phones)do table.insert(all,{size=size,phone=true})end
   for _,size in ipairs(tablets)do table.insert(all,{size=size,phone=false})end
   for _,case in ipairs(all)do
    local size=case.size;local label=string.format("built %dx%d",size.X,size.Y)
    local root=Instance.new("Frame");root.Name="Root";root.Size=UDim2.fromOffset(size.X,size.Y);root.BackgroundTransparency=1;root.Parent=gui
    local s=Screen.new({parent=root,overlayParent=root,viewRoot=root})
    s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true);task.wait()
    assert((s.geometry.phone==true)==case.phone,label.." layout family")
    local top=if case.phone then 58 else 0
    -- Measured from the outer root: on a tablet the deck root is the fitted deck itself.
    local function run(tag)return audit(s.root,root.AbsolutePosition,size.X,size.Y,top,label.." "..tag)end
    local first=run("first open")
    local key=s.root:GetAttribute("LayoutKey")
    -- Close, lay out for another screen and keep-out, come back: the same rects.
    s:setVisible(false);s:layout(Vector2.new(568,320),aspect,{kx=132,kh=44});s:layout(Vector2.new(1920,1080),aspect,{kx=116,kh=58});task.wait()
    s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true);task.wait()
    local again=run("later open")
    assert(again==first,label.." later open differs from the first:\n"..first.."\n"..again)
    assert(s.root:GetAttribute("LayoutKey")==key,label.." layout key")
    root:Destroy()
   end
  end)
  if live then
   test("live deck: the real handheld is inside the safe area at every size, and the same as the last open",function()
    local player=game:GetService("Players").LocalPlayer
    local backdrop=parent.EggDrop.Backdrop;local deck=parent.EggDropDeck.DeckHost.PocketDeck
    local board=game:GetService("ReplicatedStorage").EggDropBoards[tostring(player.UserId)]
    assert(board:GetAttribute("Mode")=="Board"and deck.Visible,"open the Pocket Deck first (Mode = Board)")
    local before={backdrop.Position,backdrop.Size,parent:GetAttribute("FixtureKeepOut")}
    _G.DeckFitLive=_G.DeckFitLive or{}
    local okLive,err=pcall(function()
     local all={}
     for _,size in ipairs(phones)do table.insert(all,{size=size,phone=true})end
     for _,size in ipairs(tablets)do table.insert(all,{size=size,phone=false})end
     for _,case in ipairs(all)do
      local size=case.size;local label=string.format("live %dx%d",size.X,size.Y)
      parent:SetAttribute("FixtureKeepOut",if case.phone then Vector2.new(116,58)else nil)
      backdrop.Position=UDim2.fromOffset(20,if case.phone then 0 else 4);backdrop.Size=UDim2.fromOffset(size.X,size.Y)
      task.wait(.4)
      local _,kh=Kit.keepOut()
      local signature=audit(deck,backdrop.AbsolutePosition,size.X,size.Y,if case.phone then kh else 0,label)
      local last=_G.DeckFitLive[label]
      assert(last==nil or last==signature,label.." differs from the last open:\n"..tostring(last).."\n"..signature)
      _G.DeckFitLive[label]=signature
     end
    end)
    backdrop.Position=before[1];backdrop.Size=before[2];parent:SetAttribute("FixtureKeepOut",before[3])
    _G.DeckFitLiveRuns=(_G.DeckFitLiveRuns or 0)+(if okLive then 1 else 0)
    if not okLive then error(err,0)end
   end)
  end
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return #cases.." passed: "..table.concat(cases," | ")..(if live then " (live runs: "..tostring(_G.DeckFitLiveRuns)..")"else "")
end
