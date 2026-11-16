-- Studio Client. QA v735 D1: the Pocket Deck handheld never leaves the safe area.
-- Fails if any part of the drawn handheld (bumpers, body, plate, glass, screen, d-pad,
-- MENU, A, B / Items and its caption, wordmark, LED) is outside the root, or above the
-- Roblox top-bar keep-out on a phone, at 812x354, 844x390, 926x428 and two tablet sizes,
-- on the first layout and on a later one (hidden, laid out at another size, shown again).
-- The soft drop shadow is not part of the handheld and may fade past the edge.
-- QA v751 P1 (stricter): on a phone every drawn part keeps MARGIN (8) px or more to the
-- left, right and bottom edges and to the bottom edge of Roblox's top bar; the body keeps
-- one locked aspect (Screen.Fit.aspect) and is centred in that safe area. Sizes include
-- Spencer's phone (2622x1206 physical: 874x402 logical, 750x402 inside the side insets)
-- and the keep-out includes this client's real GuiService.TopbarInset.
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
 local MARGIN=8
 local phones={Vector2.new(812,354),Vector2.new(844,390),Vector2.new(926,428),Vector2.new(874,402),Vector2.new(750,402),
  Vector2.new(724,375),Vector2.new(667,375),Vector2.new(568,320)}
 local tablets={Vector2.new(1024,710),Vector2.new(1180,762)}
 local keeps={{116,58},{208,58},{132,44}}
 do -- the real top bar on this client (no fixture): GuiService.TopbarInset
  local inset=game:GetService("GuiService").TopbarInset
  if inset.Height>0 and inset.Min.X>0 then table.insert(keeps,{math.floor(inset.Min.X),math.floor(inset.Height)})end
 end
 local shellNames={"ShoulderL","ShoulderR","Band","Faceplate","FinishOverlay","PlateOverlay","Glass","GlassLip","Screen","LCD",
  "DPad","DPadWell","AWell","MenuPill","ButtonA","ButtonB","ButtonItem","Wordmark","WordmarkShadow","Led"}
 local function shown(node,root)
  local p=node
  while p and p~=root do if p:IsA("GuiObject")and not p.Visible then return false end;p=p.Parent end
  return true
 end
 -- Every drawn part inside [0, W] x [topLimit, H] of the root. Returns a signature of the rects.
 local function audit(deckRoot,o,W,H,topLimit,label,margin)
  margin=margin or 0
  local parts={};local seen=0
  local function check(node,name)
   local p,s=node.AbsolutePosition-o,node.AbsoluteSize
   if s.X<=0 or s.Y<=0 then return end
   seen+=1
   local where=string.format("%s %s at %d,%d %dx%d in %dx%d (top limit %d)",label,name,p.X,p.Y,s.X,s.Y,W,H,topLimit)
   assert(p.X>=margin-.5,where..": inside the left margin")
   assert(p.X+s.X<=W-margin+.5,where..": inside the right margin")
   assert(p.Y>=topLimit+margin-.5,where..": inside the margin under the top limit")
   assert(p.Y+s.Y<=H-margin+.5,where..": inside the bottom margin")
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
     assert(r.x>=MARGIN and r.y>=(top or kh)+MARGIN and r.x+r.w<=W-MARGIN and r.y+r.h<=H-MARGIN,string.format("%s %s %d,%d %dx%d leaves the safe area less its %d px margin",label,name,r.x,r.y,r.w,r.h,MARGIN))
    end
    inside(g.body,"body");inside(g.shell.shoulderL,"bumper L");inside(g.shell.shoulderR,"bumper R");inside(g.shell.plate,"plate")
    inside(g.glass,"glass");inside(g.screen,"screen");inside(g.board,"board");inside(g.dpad,"d-pad");inside(g.menu,"MENU");inside(g.menuHit,"MENU hit")
    inside(g.aHit,"A");inside(g.item,"Items");inside(g.itemHit,"Items hit")
    if g.wordmark then inside(g.wordmark,"wordmark")end
    if g.led then inside(g.led,"LED")end
    local Fit=Screen.Fit
    assert(Fit.margin>=MARGIN,"Fit.margin is at least "..MARGIN)
    -- Aspect-locked, centred in the safe area under the bar, and as large as fits there.
    local b=g.body;local shellTop=math.min(g.shell.shoulderL.y,g.shell.shoulderR.y)
    assert(math.abs(b.w/b.h-Fit.aspect)<.03,string.format("%s body %dx%d is not %.2f:1",label,b.w,b.h,Fit.aspect))
    local left,right,above,below=b.x,W-(b.x+b.w),shellTop-kh,H-(b.y+b.h)
    assert(math.abs(left-right)<=1,string.format("%s not centred across: %d / %d",label,left,right))
    assert(math.abs(above-below)<=2,string.format("%s not centred down: %d / %d",label,above,below))
    assert(left>=MARGIN and right>=MARGIN and above>=MARGIN and below>=MARGIN,string.format("%s margins %d %d %d %d",label,left,right,above,below))
    assert(math.min(left,right)<=MARGIN+1 or math.min(above,below)<=MARGIN+3,string.format("%s shell is smaller than it needs to be: margins %d %d %d %d",label,left,right,above,below))
    -- Both bumpers ride the body's top edge and mirror each other.
    assert(g.shell.shoulderL.y+g.shell.shoulderL.h<=b.y+g.shell.shoulderL.h and g.shell.shoulderL.x-b.x==b.x+b.w-(g.shell.shoulderR.x+g.shell.shoulderR.w),label.." bumpers mirror")
    -- The wordmark stays clear of the body's corner curve.
    assert(g.wordmark and g.led,label.." keeps its wordmark and LED")
    if g.wordmark then assert(g.wordmark.x-b.x>=26 and g.wordmark.y-b.y>=22,label.." wordmark crowds the corner")end
    -- The glass sits inside the plate with plate showing above and below it.
    assert(g.glass.y-g.body.y==Fit.crown and g.body.y+g.body.h-(g.glass.y+g.glass.h)==Fit.chin,label.." crown and chin")
    assert(g.glass.y+g.glass.h<=g.shell.plate.y+g.shell.plate.h-2,label.." glass inside the plate")
    for _,r in ipairs({g.dpad,g.menu,g.aHit,g.item})do assert(r.y+r.h<=g.body.y+g.body.h-6,label.." control inside the body")end
    assert(g.board.h>=170 and math.abs(g.board.w/g.board.h-aspect)<.02,label.." board keeps its aspect and a playable size")
   end end
  end)
  test("QA v775 note 14: the board reaches the bottom row of the screen, level with the side cards, on a tidy rounded base",function()
   -- Spencer's fixture (750x402) and two more phones: the board is the full height of the
   -- screen's layout rows, so its bottom edge is on the same line as the HUD cards beside
   -- it and 3 px (the screen's own padding) above the glass's inner edge; never higher.
   for _,size in ipairs({Vector2.new(750,402),Vector2.new(844,390),Vector2.new(568,320)})do
    local g=Screen.resolveCompact(size.X,size.Y,aspect,116,58)
    local label=string.format("%dx%d",size.X,size.Y)
    local bottom=g.board.y+g.board.h
    assert(bottom==g.y1,string.format("%s board bottom %d is not the screen's last row %d",label,bottom,g.y1))
    assert(g.board.y==g.y0,label.." board starts on the screen's first row")
    local under=g.screen.y+g.screen.h-bottom
    assert(under>=0 and under<=3,string.format("%s board stops %d px above the screen's bottom edge",label,under))
    assert(math.abs((g.board.y-g.screen.y)-under)<=1,label.." board is centred down the screen")
   end
   -- The rows under the floor are the tray's base, in the banks' tone (not a dark strip).
   local LCD=require(client.JellyLCD)
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(163,273);host.Parent=gui
   local lcd=assert(LCD.new(host,{backend="span"}),"span board")
   local function at(x,y)return buffer.readu32(lcd.background,(y*LCD.Width+x)*4)end
   local mid=math.floor(LCD.Width/2)
   assert(at(mid,LCD.Height-1)==lcd.tones.bank and at(0,LCD.Height-1)==lcd.tones.bank and at(LCD.Width-1,LCD.Height-1)==lcd.tones.bank,"the base under the floor is the bank tone, edge to edge")
   assert(at(2,LCD.Height-4)==lcd.tones.bank,"the base joins the corner banks")
   assert(at(mid,LCD.Height-4)~=lcd.tones.bank,"the well above the floor is not base")
   assert(at(mid,0)~=lcd.tones.bank,"no lip along the top")
   lcd:destroy()
   -- The board's corner mask takes the colour of the screen around it.
   local Art=require(client.DeckArt)
   local mask=Art.lcdCorners(host,Color3.fromHex("#201D32"))
   local panel=Color3.fromHex("#152525")
   assert(Art.tintLcdCorners(mask,panel)and mask:GetAttribute("MaskColor")==panel:ToHex())
   local strips=0
   for _,strip in ipairs(mask:GetChildren())do strips+=1;assert(strip.BackgroundColor3==panel,"mask strip keeps the old bezel colour")end
   assert(strips==48 and not Art.tintLcdCorners(nil,panel)and not Art.tintLcdCorners(mask,"red"))
   host:Destroy()
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
    local function run(tag)return audit(s.root,root.AbsolutePosition,size.X,size.Y,top,label.." "..tag,if case.phone then MARGIN else 0)end
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
      local signature=audit(deck,backdrop.AbsolutePosition,size.X,size.Y,if case.phone then kh else 0,label,if case.phone then MARGIN else 0)
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
