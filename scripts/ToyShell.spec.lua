-- Studio Client. Toy Shell restyle (UI-RETRO-RESTYLE-2026-11-19 + Revision 1): every
-- sold deck has a `toyShell` palette (book-only plates fall back to Classic), menus follow
-- the equipped deck or Classic Shell (Settings > Menu colours), text reads its surface
-- (ink on cream and lemon, white on shell, tray and well), the moving checker stays inside
-- the rounded corners, rests under Reduced Motion and pauses while hidden, the header
-- plate follows the title, and the deck HUD labels sit on coloured tabs.
-- Usage: require(PlayerScripts.Client.ZZSpecs.ToyShell)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Kit=require(client.DeckKit);local Art=require(client.DeckArt)
 local Themes=require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local gui=Instance.new("ScreenGui");gui.Name="_ToyShellSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local savedTheme,savedMenu,savedReduced,savedEffects=Art.getTheme(),Art.MenuColours,Kit.reduced,Kit.reducedEffects
 local ok,problem=pcall(function()
  local holder=Instance.new("Frame");holder.Size=UDim2.fromOffset(900,600);holder.BackgroundTransparency=1;holder.Parent=gui

  test("every sold deck has its own Toy Shell; book-only plates use Classic; fixed roles are shared",function()
   local seen={}
   for _,id in ipairs(Themes.Order)do
    local t=Themes.ById[id].toy
    assert(t and t~=Themes.ToyClassic and Themes.Plates[id].toyShell,id.." has a toyShell row")
    assert(t.cream==Color3.fromHex("#FFF4DC")and t.selected==Color3.fromHex("#FFE14D")and t.go==Color3.fromHex("#43DB5F")and t.stage==Color3.fromHex("#4A1D3A"),id.." fixed roles")
    assert(not seen[t.shell:ToHex()],id.." shell is its own");seen[t.shell:ToHex()]=true
   end
   for _,id in ipairs(Themes.BookOnly)do assert(Themes.ById[id].toy==Themes.ToyClassic,id.." falls back to Classic")end
   assert(Themes.ToyClassic.shell==Color3.fromHex("#2E55E6")and Themes.ToyClassic.tag==Color3.fromHex("#FF8FC0"))
  end)

  test("menus follow the deck, Classic ignores it, and the deck's own screen always follows its plate",function()
   Art.setMenuColours("deck");Art.applyTheme(Themes.ById.night_orb)
   local sheet=Kit.frame(holder,"Sheet","panel",UDim2.new(),UDim2.fromOffset(200,100))
   assert(sheet.BackgroundColor3==Themes.ById.night_orb.toy.shell)
   assert(Art.setMenuColours("classic")and sheet.BackgroundColor3==Themes.ToyClassic.shell and not Art.setMenuColours("classic"))
   local deck=Instance.new("Frame");deck.BackgroundTransparency=1;deck.Size=UDim2.fromOffset(200,100);deck.Parent=holder
   Art.plateSurface(deck)
   local lcd=Kit.frame(deck,"LCD","well",UDim2.new(),UDim2.fromScale(1,1))
   assert(lcd.BackgroundColor3==Themes.ById.night_orb.toy.well,"the deck screen keeps its plate under Classic")
   Art.applyTheme(Themes.ById.honey);assert(lcd.BackgroundColor3==Themes.ById.honey.toy.well and sheet.BackgroundColor3==Themes.ToyClassic.shell)
   Art.setMenuColours("deck");assert(sheet.BackgroundColor3==Themes.ById.honey.toy.shell)
   sheet:Destroy();deck:Destroy()
  end)

  test("text reads its surface: ink on cream tiles and keys, white on trays; a hand-set colour is kept",function()
   local tile=Kit.tile(holder,"Tile",{size=UDim2.fromOffset(160,80)})
   local name=Kit.text(tile,"Name","Rose jar","text");local soft=Kit.text(tile,"Small","0 of 5","soft")
   assert(tile:GetAttribute("ToySurface")=="light"and name.TextColor3==Kit.color("ink")and soft.TextColor3==Kit.color("inkSoft"))
   local tray=Kit.card(holder,"Tray");local line=Kit.text(tray,"Body","Something","text");local digits=Kit.text(tray,"Counter","20","stars")
   assert(line.TextColor3==Kit.color("text")and digits.TextColor3==Kit.Color.stars,"white and gold on a tray")
   local priced=Kit.text(tile,"Counter","12","stars");assert(priced.TextColor3==Kit.color("ink"),"gold text never on cream")
   local star=Kit.icon(tile,"star",18);assert(star.ImageColor3==Kit.Color.stars,"the Star shape stays gold on cream")
   local kept=Kit.text(tray,"Body","Hand","text");kept.TextColor3=Color3.fromHex("#FF0000")
   Art.applyTheme(Themes.ById.brick);assert(kept.TextColor3==Color3.fromHex("#FF0000"),"a caller's own colour survives a repaint")
   assert(name.TextColor3==Kit.color("ink")and line.TextColor3==Kit.color("text"))
   tile:Destroy();tray:Destroy()
  end)

  test("copy inside an Art control reads its fill: ink on cream and go, the disabled grey on a disabled key, white on a tray tab",function()
   local key=Instance.new("TextButton");key.Size=UDim2.fromOffset(200,60);key.Parent=holder
   local title=Art.text(key,"Title","Starter pack",UDim2.new(),UDim2.fromOffset(180,20),"text",16)
   Art.button(key,10);Art.control(key,false,true)
   assert(key.BackgroundColor3==Art.toyPalette().cream and title.TextColor3==Art.toyPalette().ink,"ink on a cream control")
   Art.control(key,true,true);assert(key.BackgroundColor3==Art.toyPalette().go and title.TextColor3==Art.toyPalette().ink,"ink on go")
   Art.control(key,false,false);assert(title.TextColor3==Art.ToyDisabled.text,"disabled grey on a disabled key")
   local tab=Instance.new("TextButton");tab.Size=UDim2.fromOffset(120,44);tab.Parent=holder
   local word=Art.text(tab,"Word","Quests",UDim2.new(),UDim2.fromOffset(100,20),"text",16)
   Art.button(tab,10);Art.tab(tab,false,true);Art.repaintUnder(tab)
   assert(tab.BackgroundColor3==Art.toyPalette().tray and word.TextColor3==Art.toyPalette().onShell,"white on an unselected tab's tray")
   key:Destroy();tab:Destroy()
  end)

  test("keys: primary go, the rest cream, all with ink labels and a 2 px inside outline",function()
   local b,state=Kit.button(holder,"Key",{text="Leave"})
   local p,ps=Kit.button(holder,"Go",{variant="primary",text="Hatch",glyph="A"})
   for _,s in ipairs({state,ps})do
    assert(s.stroke.Thickness==2 and s.stroke.Color==Kit.color("ink")and s.label.TextColor3==Kit.color("ink"))
    local okInner,pos=pcall(function()return s.stroke.BorderStrokePosition end)
    assert(not okInner or pos==Enum.BorderStrokePosition.Inner,"the outline sits inside the rect")
   end
   assert(state.fill.BackgroundColor3==Kit.color("cream")and ps.fill.BackgroundColor3==Kit.color("go"))
   b:Destroy();p:Destroy()
  end)

  test("the checker stays inside the rounded corners, runs one looping tween, rests under Reduced Motion and pauses while hidden",function()
   Kit.reduced=function()return false end;Kit.setReducedEffects(false)
   local sheet=Kit.frame(holder,"Shell","panel",UDim2.new(),UDim2.fromOffset(400,300),16)
   local ctl=Kit.shellPattern(sheet);settle()
   local h=ctl.holder
   -- 2026-11-21: inset ceil(16 * 0.293) = 5, plus the outline (none here) and 1 px.
   assert(h.ClipsDescendants and h.Position==UDim2.fromOffset(6,6)and h.Size==UDim2.new(1,-12,1,-12),"inset 5 + 1")
   local outlined=Kit.frame(holder,"Outlined","panel",UDim2.new(),UDim2.fromOffset(200,100),16);Kit.stroke(outlined)
   local octl=Kit.shellPattern(outlined);assert(octl.holder.Position==UDim2.fromOffset(9,9),"inside a 3 px outline: 5 + 3 + 1")
   outlined:Destroy()
   -- 2026-11-22: a pattern over a root that outlives it drops its link when its content is rebuilt.
   local keep=Kit.frame(holder,"Keep","panel",UDim2.new(),UDim2.fromOffset(200,100),16)
   for _=1,3 do
    local content=Kit.frame(keep,"Content",nil,UDim2.new(),UDim2.fromScale(1,1))
    local pattern=Kit.shellPattern(content)
    assert(pattern.fade.BackgroundColor3==keep.BackgroundColor3 and pattern.watchingFill(),"follows the root's fill")
    content:Destroy();settle();assert(not pattern.watchingFill(),"link dropped with the content")
   end
   keep:Destroy()
   assert(Kit.patternInset(30)==9 and Kit.patternInset(16)==5)
   assert(ctl.tile.Image==Kit.Checker.image and ctl.tile.TileSize==UDim2.fromOffset(32,32)and math.abs(ctl.tile.ImageTransparency-.91)<.001)
   assert(ctl.running and h:GetAttribute("PatternRunning"),"moving while shown")
   assert(Kit.shellPattern(sheet)==ctl,"one pattern per surface")
   local child=Kit.frame(sheet,"Card","raised",UDim2.new(),UDim2.fromOffset(50,50));assert(h.ZIndex<child.ZIndex,"under every child")
   task.wait(.6);local x=ctl.tile.Position.X.Offset;assert(x>-32 and x<0,"travelling down and to the right")
   sheet.Visible=false;settle();assert(not ctl.running,"paused while hidden");local held=ctl.tile.Position
   task.wait(.3);assert(ctl.tile.Position==held,"stays put while hidden")
   sheet.Visible=true;settle();assert(ctl.running)
   Kit.setReducedEffects(true);assert(not ctl.running and ctl.tile.Position==UDim2.fromOffset(-32,-32),"Motion: Low rests at offset 0")
   Kit.setReducedEffects(false);Kit.reduced=function()return true end;ctl.sync()
   assert(not ctl.running and ctl.tile.Position==UDim2.fromOffset(-32,-32),"Reduced Motion rests at offset 0")
   Kit.reduced=savedReduced;ctl.sync()
   sheet:Destroy();settle();assert(not ctl.running or not h.Parent)
  end)

  test("header plate sits behind the title in the screen tint, stops where the title stops, and keeps the title rect",function()
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(848,100);host.BackgroundTransparency=1;host.Parent=gui
   local h=Kit.header(host,{title="Customize",tint="companions",width=848})
   local g=h.geometry;local plate=h.plate
   assert(h.title.Position==UDim2.fromOffset(g.title.x,g.title.y)and h.title.Size==UDim2.fromOffset(g.title.w,g.title.h),"title rect unchanged")
   assert(plate.Visible and plate.Position.X.Offset==g.title.x-Kit.PlatePad and plate.Face.BackgroundColor3==Kit.Tint.companions)
   assert(h.title.TextColor3==Kit.color("ink")and plate.ZIndex<h.title.ZIndex)
   local w=plate.Size.X.Offset
   h.setTitle("A very long translated screen title that runs past the wallet and the back key")
   assert(plate.Size.X.Offset<=g.title.w+Kit.PlatePad and plate.Size.X.Offset>w,"the plate follows the text and stops with the title")
   local plain=Kit.header(host,{title="Settings",wallet=false,width=848});assert(plain.plate.Face.BackgroundColor3==Kit.color("tag"),"no tint: the deck's tag")
   host:Destroy()
  end)

  test("HUD labels sit on coloured tabs with ink text, same text and place",function()
   local card=Kit.card(holder,"Score");card.Size=UDim2.fromOffset(160,80)
   local label=Kit.text(card,"Label","SCORE","dim",{Position=UDim2.fromOffset(10,5),Size=UDim2.fromOffset(140,14),TextSize=12})
   local before=label.Position
   assert(Kit.hudTabs(card)==1);settle()
   local tab=Kit.hudTabOf(label)
   assert(tab and tab.BackgroundColor3==Kit.HudTabColors.SCORE and label.TextColor3==Kit.color("ink")and label.Position==before)
   assert(tab.ZIndex<label.ZIndex and tab.Size.X.Offset>8 and tab.Size.X.Offset<=148)
   assert(Kit.hudTabColor("EGGS LEFT")==Kit.HudTabColors.EGGS and Kit.hudTabColor("hello")==nil)
   card:Destroy()
  end)
  holder:Destroy()
 end)
 Kit.reduced=savedReduced;Kit.setReducedEffects(savedEffects)
 Art.setMenuColours(savedMenu);if savedTheme then Art.applyTheme(savedTheme)end
 gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
