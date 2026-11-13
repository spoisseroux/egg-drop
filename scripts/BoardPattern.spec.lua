-- Studio Client. The deck background drawn inside the board well (UI-SPEC-REDESIGN-MENUS 5):
-- Art.setBackground feeds a registered board pattern (canopy / creek / lantern) in one
-- tone at 6%, cells ~23 px on the 163 px phone board and 40 px on desktop, static,
-- bounded pool; the exterior pattern is skipped under the compact (phone) rule.
-- Scratch frames only. Art.setBackground is global: re-equip a background (or rejoin)
-- afterwards so the live board pattern shows the equipped one again.
-- Usage: require(PlayerScripts.Client.ZZSpecs.BoardPattern)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Art=require(client.DeckArt);local Backdrop=require(client.DeckBackdrop)
 local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
 local RunService=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do RunService.Heartbeat:Wait()end end
 local theme=Themes.ById[Themes.Order[1]]
 local host=Instance.new("Frame");host.Name="_BoardPatternSpec";host.Size=UDim2.fromOffset(163,277);host.BackgroundTransparency=1;host.Parent=parent
 local exterior=Instance.new("Frame");exterior.Name="_BoardPatternExterior";exterior.Size=UDim2.fromOffset(812,354);exterior.BackgroundTransparency=1;exterior.Parent=parent
 local ok,problem=pcall(function()
  local root=Art.boardPattern(host);settle()
  test("registering twice reuses one bounded pool",function()
   assert(Art.boardPattern(host)==root and root.Name=="BoardPattern"and root.ClipsDescendants)
   assert(#root:GetChildren()==Backdrop.BoardColumns*Backdrop.BoardRows)
  end)
  for _,id in ipairs({"canopy","creek","lantern"})do
   test(id.." is fed by Art.setBackground in one 6% tone",function()
    Art.setBackground(Instance.new("Frame"),id,theme);settle()
    local stats=Art.boardPatternStats(host);assert(root.Visible and stats.visible>20,"visible motifs="..tostring(stats.visible))
    local tone=Backdrop.boardTone(theme)
    for _,motif in ipairs(root:GetChildren())do if motif.Visible then
     assert(motif.BackgroundColor3==tone and motif.ZIndex==root.ZIndex)
     if id=="creek"then assert(motif.BackgroundTransparency==1 and motif.UIStroke.Enabled and math.abs(motif.UIStroke.Transparency-.94)<1e-6)
     else assert(math.abs(motif.BackgroundTransparency-.94)<1e-6 and not motif.UIStroke.Enabled)end
    end end
   end)
  end
  test("cell is about 23 px on the phone board and 40 px on desktop",function()
   assert(Backdrop.boardCell(163)==23 and Backdrop.boardCell(300)==40 and Backdrop.boardCell(500)==40)
   assert(Art.boardPatternStats(host).cell==23)
  end)
  test("the whole well is covered at phone and desktop sizes",function()
   for _,size in ipairs({Vector2.new(163,277),Vector2.new(360,605)})do
    host.Size=UDim2.fromOffset(size.X,size.Y);settle()
    for _,id in ipairs({"canopy","creek","lantern"})do
     Art.setBackground(Instance.new("Frame"),id,theme);settle()
     local maxX,maxY=0,0
     for _,motif in ipairs(root:GetChildren())do if motif.Visible then
      maxX=math.max(maxX,motif.Position.X.Offset+motif.Size.X.Offset);maxY=math.max(maxY,motif.Position.Y.Offset+motif.Size.Y.Offset)
     end end
     local cell=Backdrop.boardCell(size.X)
     assert(maxX>=size.X-cell*1.1 and maxY>=size.Y-cell*1.1,id.." leaves a bare edge at "..tostring(size))
    end
   end
  end)
  test("depth follows the renderer and no geometry is written while nothing changes",function()
   Art.setBoardPatternDepth(host,3);assert(root.ZIndex==3)
   for _,motif in ipairs(root:GetChildren())do assert(motif.ZIndex==3)end
   local writes=Art.boardPatternStats(host).writes
   for _=1,10 do Art.setBackground(Instance.new("Frame"),"lantern",theme)end;settle()
   assert(Art.boardPatternStats(host).writes==writes,"repeat background writes")
  end)
  test("the exterior pattern is skipped under the compact rule, previews still draw",function()
   Art.backdrop(exterior);Art.setBackground(exterior,"creek",theme)
   Art.setBackdropCase(exterior,{x=0,y=0,w=812,h=354});Art.updateBackdrop(exterior,0,true,true,false)
   local surface=exterior:FindFirstChild("PatternSurface",true)
   assert(not surface or not surface.Visible,"compact exterior pattern drew")
   exterior.Size=UDim2.fromOffset(1920,1080);settle()
   Art.setBackdropCase(exterior,{x=0,y=0,w=1200,h=700});Art.updateBackdrop(exterior,1,true,true,false)
   surface=exterior:FindFirstChild("PatternSurface",true);assert(surface and surface.Visible,"desktop exterior pattern missing")
  end)
 end)
 host:Destroy();exterior:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases,note="Art.setBackground is global: re-equip or re-enter Board to restore the live pattern"}
end
