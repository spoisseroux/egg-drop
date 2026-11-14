-- Studio Client. UI personality P2 surfaces (UI-PERSONALITY-SCOPE-2026-11-13 T2, T6,
-- T7, T11): lips on things you press, seams on panes you read, sticker chips, the LCD
-- dot grid, boing and tab squash, all cut under Reduced Motion; missing asset ids
-- create no instance; a converted tile keeps its rect, hit area and focus flags.
-- Usage: require(PlayerScripts.Client.ZZSpecs.KitSurfaces)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Kit=require(client.DeckKit);local Assets=require(client.DeckAssets)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function lum(c)
  local function ch(v)return if v<=.03928 then v/12.92 else((v+.055)/1.055)^2.4 end
  return .2126*ch(c.R)+.7152*ch(c.G)+.0722*ch(c.B)
 end
 local function contrast(a,b)local x,y=lum(a),lum(b);return(math.max(x,y)+.05)/(math.min(x,y)+.05)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local gui=Instance.new("ScreenGui");gui.Name="_KitSurfacesSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local realReduced=Kit.reduced
 local savedSeam,savedDots=Assets.Personality.seam,Assets.Personality.dotGrid
 -- motion(reduced): true turns Reduced Motion on, false lets motion play.
 local function motion(reduced)Kit.reduced=function()return reduced end end
 local ok,problem=pcall(function()
  local holder=Instance.new("Frame");holder.Size=UDim2.fromOffset(900,600);holder.BackgroundTransparency=1;holder.Parent=gui

  test("lip rules: tiles 4 px (3 on phones), secondary 4 / 3, primary ledge 6, ghost settles 2 with no ledge",function()
   assert(Kit.tileLip(false)==4 and Kit.tileLip(true)==3)
   local l,d=Kit.buttonLip("primary",false);assert(l==6 and d==6)
   l,d=Kit.buttonLip("primary",true);assert(l==6 and d==6,"the primary ledge stays 6 on phones")
   l,d=Kit.buttonLip("secondary",false);assert(l==4 and d==4)
   l,d=Kit.buttonLip("secondary",true);assert(l==3 and d==3)
   l,d=Kit.buttonLip("ghost",false);assert(l==0 and d==2)
   local s,ss=Kit.button(holder,"Secondary",{text="Leave"});assert(ss.edge.Visible and ss.edge.Position.Y.Offset==4 and ss.lip==4)
   local p,ps=Kit.button(holder,"Primary",{variant="primary",text="Hatch"});assert(ps.edge.Visible and ps.edge.Position.Y.Offset==6)
   local c,cs=Kit.button(holder,"Phone",{text="Back",size=Vector2.new(120,44)});assert(cs.edge.Position.Y.Offset==3 and cs.lip==3)
   local g,gs=Kit.button(holder,"Ghost",{variant="ghost",text="Skip"});assert(not gs.edge.Visible and gs.lip==2)
   assert(Kit.buttonState(s)==ss and Kit.buttonState(p)==ps,"buttons[button] state keys stay")
   for _,b in ipairs({s,p,c,g})do b:Destroy()end
  end)

  test("press drops the face onto the lip and back; Kit.pulse still settles; the hit rect never moves",function()
   motion(false)
   local b,state=Kit.button(holder,"Press",{text="Replay"});b.Position=UDim2.fromOffset(20,20);settle()
   local before=b.AbsolutePosition
   state.pressed=true;Kit.paintButton(b);task.wait(Kit.Motion.pressDown+.04)
   assert(state.content.Position.Y.Offset==4 and state.fill.Position.Y.Offset==4 and state.edge.Visible,"face rests on the lip")
   assert(b.AbsolutePosition==before,"hit rect stays put")
   state.pressed=false;Kit.paintButton(b);task.wait(Kit.Motion.pressUp+.04)
   assert(state.content.Position.Y.Offset==0 and state.fill.Position.Y.Offset==0)
   Kit.pulse(b);task.wait(Kit.Motion.pressDown+.02);assert(state.pressed and state.content.Position.Y.Offset==4)
   task.wait(Kit.Motion.pressDown+Kit.Motion.pressUp+.1);assert(not state.pressed and state.content.Position.Y.Offset==0)
   b:Destroy();Kit.reduced=realReduced
  end)

  test("tile: same rect, hit area and focus flags as the hand-built tile; lip under the face, face under content",function()
   local old=Kit.node("TextButton",holder,{Name="Old",Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
    Position=UDim2.fromOffset(371,147),Size=UDim2.fromOffset(104,88),ZIndex=holder.ZIndex+1})
   local tile,state=Kit.tile(holder,"New",{selectable=false,radius=12,position=UDim2.fromOffset(371,147),size=UDim2.fromOffset(104,88)})
   local label=Kit.text(tile,"Strong","Sherbet","text",{Position=UDim2.fromOffset(8,51),Size=UDim2.fromOffset(90,16)})
   settle()
   assert(tile:IsA("TextButton")and tile.AbsolutePosition==old.AbsolutePosition and tile.AbsoluteSize==old.AbsoluteSize,"rect unchanged")
   assert(tile.ZIndex==old.ZIndex and tile.Selectable==old.Selectable and tile.Active==old.Active,"hit area and focus flags unchanged")
   assert(Kit.tileState(tile)==state and tile:GetAttribute("KitTile")and tile:GetAttribute("KitLip")==4)
   assert(state.lipFrame.ZIndex<state.face.ZIndex and state.face.ZIndex<label.ZIndex,"lip, face, content order")
   assert(state.lipFrame.AbsolutePosition.Y==tile.AbsolutePosition.Y+4 and state.face.AbsolutePosition==tile.AbsolutePosition)
   -- The caller keeps painting the button; the face and lip follow.
   tile.BackgroundColor3=Color3.fromRGB(40,80,70);task.wait()
   assert(state.face.BackgroundColor3==tile.BackgroundColor3 and state.lipFrame.BackgroundColor3==tile.BackgroundColor3:Lerp(Kit.Color.black,.38))
   motion(false)
   Kit.pressTile(tile,true);task.wait(Kit.Motion.pressDown+.04)
   assert(tile.AbsolutePosition==old.AbsolutePosition,"press leaves the hit rect")
   assert(state.face.AbsolutePosition.Y==tile.AbsolutePosition.Y+4 and state.lipFrame.AbsolutePosition.Y==tile.AbsolutePosition.Y+4,"face drops onto the lip")
   assert(state.face.AbsoluteSize==tile.AbsoluteSize,"nothing resizes on press")
   Kit.pressTile(tile,false);task.wait(Kit.Motion.pressUp+.04);assert(state.face.AbsolutePosition==tile.AbsolutePosition)
   Kit.setTileLip(tile,3);assert(tile:GetAttribute("KitLip")==3 and state.lipFrame.Position.Y.Offset==3)
   state.setSelected(true);assert(state.stroke.Thickness==2 and state.stroke.Transparency==0)
   old:Destroy();tile:Destroy();Kit.reduced=realReduced
  end)

  test("a converted screen keeps its grid: Deck style plates sit where Shop.Regular puts them, with a 4 px lip",function()
   local Shop=require(client.FaceplateShop);local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(900,640);host.BackgroundTransparency=1;host.Parent=gui
   local shop=Shop.new(host,{})
   local R=Shop.Regular
   for index=1,#shop.tiles do
    local col,row=(index-1)%4,math.floor((index-1)/4)
    local b=shop.tiles[index].button
    assert(b.Name=="Tile_"..Themes.Order[index]and b.Position==UDim2.fromOffset(R.grid[1]+col*(R.tile[1]+R.gap),R.grid[2]+row*(R.tile[2]+R.gap)))
    assert(b.Size==UDim2.fromOffset(R.tile[1],R.tile[2])and b.Selectable==false and b:GetAttribute("KitLip")==4)
   end
   assert(R.gap>=4+3,"the lip fits the grid gap with room to spare")
   host:Destroy()
  end)

  test("seam: 6 px inside information panes, white 12%, dropped under 150 px; missing id creates nothing",function()
   Assets.Personality.seam=nil
   local bare=Kit.card(holder,"Bare",nil,{seam=true});bare.Size=UDim2.fromOffset(300,300)
   assert(bare:FindFirstChild("Seam")==nil and bare:GetAttribute("KitSeam"),"no id, no instance")
   Assets.Personality.seam="rbxassetid://1"
   local card=Kit.card(holder,"Pane",nil,{seam=true});card.Size=UDim2.fromOffset(328,392);settle()
   local seam=card:FindFirstChild("Seam");assert(seam and seam.Visible)
   assert(seam.Position==UDim2.fromOffset(6,6)and seam.Size==UDim2.new(1,-12,1,-12))
   for _,piece in ipairs(seam:GetChildren())do
    assert(piece:IsA("ImageLabel")and math.abs(piece.ImageTransparency-.88)<.001 and piece.ZIndex<=card.ZIndex,"seam sits under content at 12%")
   end
   assert(seam.Corners.ScaleType==Enum.ScaleType.Slice and seam.Top.ScaleType==Enum.ScaleType.Tile,"stitches tile, corners slice")
   card.Size=UDim2.fromOffset(452,72);settle();assert(not seam.Visible,"dropped under 150 px")
   card.Size=UDim2.fromOffset(452,150);settle();assert(seam.Visible)
   assert(Kit.seamAllowed(150)and not Kit.seamAllowed(149))
   local plain=Kit.card(holder,"Plain",nil,{});assert(plain:FindFirstChild("Seam")==nil,"only panes asking for it")
   bare:Destroy();card:Destroy();plain:Destroy()
   Assets.Personality.seam=savedSeam
  end)

  test("dot grid: 6 px tiles at about 6% white under the art; missing id creates nothing",function()
   Assets.Personality.dotGrid=nil
   local w=Kit.well(holder,"Empty",UDim2.new(),UDim2.fromOffset(200,150));assert(w:FindFirstChild("DotGrid")==nil)
   local f=Kit.frame(holder,"Board","well",UDim2.new(),UDim2.fromOffset(200,150),12);assert(Kit.dotGrid(f)==nil and #f:GetChildren()==1)
   Assets.Personality.dotGrid="rbxassetid://1"
   local well=Kit.well(holder,"Egg",UDim2.new(),UDim2.fromOffset(200,150))
   local art=Kit.frame(well,"Art",nil,UDim2.new(),UDim2.fromScale(1,1))
   local grid=well:FindFirstChild("DotGrid")
   assert(grid and grid.ScaleType==Enum.ScaleType.Tile and grid.TileSize==UDim2.fromOffset(6,6)and math.abs(grid.ImageTransparency-.94)<.001)
   assert(grid.ZIndex<art.ZIndex and not grid.Active,"under the art, never a target")
   assert(Kit.dotGrid(well)==grid,"one per well")
   w:Destroy();f:Destroy();well:Destroy()
   Assets.Personality.dotGrid=savedDots
  end)

  test("sticker: solid colour, ink text, cream 2 px border, 4 degree tilt, shadow; never under 22 px; grid chips stay plain",function()
   motion(false)
   local chip=Kit.chip(holder,"★ 8","sticker",26)
   assert(chip.root:GetAttribute("ChipKind")=="sticker"and math.abs(chip.root.Rotation)==4)
   local face,shadow=chip.root.StickerFace,chip.root.StickerShadow
   assert(face.Visible and shadow.Visible and face.BackgroundColor3==Kit.Color.stars and chip.label.TextColor3==Kit.Color.ink)
   local border=face.StickerBorder;assert(border.Thickness==2 and border.Color==Kit.Sticker.cream)
   assert(chip.root.BackgroundTransparency==1 and not chip.root.KitStroke.Enabled and chip.label.TextSize>=12)
   assert(shadow.ZIndex<face.ZIndex and face.ZIndex<chip.label.ZIndex)
   assert(chip.root:FindFirstChild("BoingScale"),"lands with an overshoot")
   chip.set("RARE","sticker",Kit.Tint.style);assert(face.BackgroundColor3==Kit.Tint.style)
   for _,c in ipairs({Kit.Color.stars,Kit.Tint.style,Color3.fromHex("#C3C8D0"),Color3.fromHex("#9BE3A8"),Color3.fromHex("#8CC8FF"),Color3.fromHex("#E6B3FF")})do
    assert(contrast(Kit.Color.ink,c)>=4.5,"ink on a sticker keeps 4.5:1")
   end
   chip.set("OWNED","gold");assert(chip.root.Rotation==0 and not face.Visible and chip.root.BackgroundTransparency==0 and chip.root.KitStroke.Enabled)
   local small=Kit.chip(holder,"★ 8","sticker",20);assert(small.root:GetAttribute("ChipKind")=="gold"and small.root.Rotation==0,"no sticker under 22 px")
   local plain=Kit.chip(holder,"OWNED",nil,22);assert(plain.root:FindFirstChild("StickerFace")==nil and plain.root.Rotation==0)
   assert(Kit.stickerAllowed(22,3,false)and not Kit.stickerAllowed(21)and not Kit.stickerAllowed(26,2)and not Kit.stickerAllowed(26,3,true))
   -- A chip whose owner animates its own UIScale (results "New best") is never double-scaled.
   local best=Kit.chip(holder,"NEW BEST","gold",26);local own=Kit.node("UIScale",best.root,{Scale=1})
   best.set("NEW BEST","sticker");assert(best.root:FindFirstChild("BoingScale")==nil and own.Scale==1)
   for _,c in ipairs({chip,small,plain,best})do c.root:Destroy()end
   Kit.reduced=realReduced
  end)

  test("R3.8 header ? circle: 44 hit on both sizes, left of the capsule, title stops 12 px before it; none without a family",function()
   for _,compact in ipairs({false,true})do
    for _,W in ipairs({848,812,568})do
     local g=Kit.headerGeometry(W,compact,96,24,true)
     assert(g.help and g.helpHit.w==44 and g.helpHit.h==44,"44 hit")
     assert(g.help.x+g.help.w==g.wallet.x-8 and g.help.h==g.controlH and g.help.y==g.wallet.y,"8 px left of the capsule, same line")
     assert(g.title.x+g.title.w<=g.help.x-12,"title stops before the ?")
     local plain=Kit.headerGeometry(W,compact,96,24)
     assert(plain.help==nil and plain.title.w>g.title.w,"no ? without help")
    end
   end
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(848,100);host.BackgroundTransparency=1;host.Parent=gui
   local h=Kit.header(host,{title="Hatch eggs",tint="hatch",width=848})
   assert(h.help and h.help.root:GetAttribute("HelpId")=="hatch"and h.help.root.AbsoluteSize==Vector2.new(44,44))
   assert(h.help.root.Selectable==false and h.help.root:GetAttribute("AccessibleLabel")~=nil)
   local hub=Kit.header(host,{title="Pocket menu",tint=Kit.Sticker.cream,width=848});assert(hub.help==nil,"the hub has no ?")
   local opened;local saved=Kit.onHelp;Kit.onHelp=function(id)opened=id;return true end
   Kit.openHelp("hatch");Kit.onHelp=saved;assert(opened=="hatch")
   host:Destroy()
  end)
  test("Reduced Motion cuts boing, sticker landing, press travel and tab squash",function()
   motion(false)
   local box=Kit.frame(holder,"Box","raised",UDim2.new(),UDim2.fromOffset(80,40))
   Kit.boing(box);local scale=box:FindFirstChild("BoingScale");assert(scale and scale.Scale<1,"boing starts at 0.96")
   task.wait(Kit.BoingTime+.08);assert(math.abs(scale.Scale-1)<.01,"boing settles at 1")
   local owned=Kit.frame(holder,"Owned",nil,UDim2.new(),UDim2.fromOffset(80,40));local own=Kit.node("UIScale",owned,{Scale=1})
   Kit.boing(owned);assert(owned:FindFirstChild("BoingScale")==nil and own.Scale==1,"never fights an owner's UIScale")
   motion(true)
   local still=Kit.frame(holder,"Still","raised",UDim2.new(),UDim2.fromOffset(80,40))
   Kit.boing(still);assert(still:FindFirstChild("BoingScale")==nil,"no boing")
   local chip=Kit.chip(holder,"★ 8","sticker",26);assert(chip.root:FindFirstChild("BoingScale")==nil,"no landing")
   local b,state=Kit.button(holder,"Snap",{text="Leave"})
   state.pressed=true;Kit.paintButton(b);assert(state.content.Position.Y.Offset==4,"press snaps")
   local tile,ts=Kit.tile(holder,"SnapTile",{});Kit.pressTile(tile,true);assert(ts.pad.PaddingTop.Offset==4,"tile press snaps")
   local tabs=Kit.tabs(holder,{"Faceplates","Backgrounds","Balls"},520,44,16)
   local segment=(520-8)/3
   tabs.select(3);-- UDim2 offsets are integers: a 170.67 px segment is stored as 171.
   assert(math.abs(tabs.root.Pill.Size.X.Offset-segment)<1 and math.abs(tabs.root.Pill.Position.X.Offset-(4+2*segment))<1,"no squash, snapped")
   motion(false)
   -- Track the widest frame over the travel (one fixed sample missed it on uneven frames).
   tabs.select(1)
   local widest,started=0,os.clock()
   while os.clock()-started<Kit.Motion.tab do widest=math.max(widest,tabs.root.Pill.Size.X.Offset);game:GetService("RunService").RenderStepped:Wait()end
   assert(widest>segment+1,"the pill stretches along its travel")
   task.wait(Kit.Motion.tab+.1);assert(math.abs(tabs.root.Pill.Size.X.Offset-segment)<1 and math.abs(tabs.root.Pill.Position.X.Offset-4)<1,"and settles")
   for _,o in ipairs({box,owned,still,chip.root,b,tile,tabs.root})do o:Destroy()end
   Kit.reduced=realReduced
  end)
  holder:Destroy()
 end)
 Kit.reduced=realReduced;Assets.Personality.seam,Assets.Personality.dotGrid=savedSeam,savedDots
 gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
