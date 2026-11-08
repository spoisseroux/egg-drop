-- Native ScreenGui geometry + deterministic clock; no real appearance requests.
return function(client,parent)
 local Background=require(client.DeckBackdrop);local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(733,307);root.Parent=parent
 local preview=Instance.new("Frame");preview.Size=UDim2.fromOffset(102,68);preview.Parent=parent
 local surface=Background.new(root);local cases={}
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function test(n,f)f();table.insert(cases,n)end
 local function geometry()
  local size=surface.root.AbsoluteSize
  for _,b in ipairs(surface.bands)do
   assert(b.host.ClipsDescendants and b.canvas.Size.X.Offset>=size.X*2-.1)
   assert(b.canvas.Position.X.Offset<=0 and b.canvas.Position.X.Offset+b.canvas.Size.X.Offset>=size.X,"wave opened viewport edge")
   assert(math.abs(b.canvas.Position.Y.Offset+b.top)<.1,"stale owner vertical crop")
   assert(b.host.Position.Y.Offset==math.floor((b.row-1)*size.Y/8+.5))
   assert(math.abs(b.pieces[3].body.Position.X.Scale-b.pieces[1].body.Position.X.Scale-.25)<1e-6,"four half-viewport motif cells must tile2viewport canvas")
  end
 end
 local ok,err=pcall(function()
 settle();surface:configure("creek",Themes.ById.ice);surface:update(root,0,true,false);settle();surface:update(root,0,true,false)
 local count=#surface.root:GetDescendants()+1;local first=surface.bands[1].host
 test("one16-band545-instance surface includes256 actual motif frames",function()assert(#surface.bands==16 and surface.stats.primitives==256 and count==545 and surface.stats.created==count);geometry()end)
 for _,id in ipairs({"creek","lantern"})do test(id.." full period is closed and covers edges",function()
  surface:configure(id,Themes.ById.ice);surface:update(root,0,true,false)
  -- New pattern lease begins at zero; sample full exact period with integer harmonics.
  local before={};for i,b in ipairs(surface.bands)do before[i]=b.canvas.Position end
  for i=1,96 do surface:update(root,i*.25,true,false);geometry()end
  for i,b in ipairs(surface.bands)do assert((b.canvas.Position.X.Offset-before[i].X.Offset)^2<1e-7,"loop endpoint jumped")end
  assert(#surface.root:GetDescendants()+1==count and surface.bands[1].host==first)
 end)end
 test("same-clock updates cap15Hz and hidden/reduced steady writes are zero",function()
  surface:update(root,30,true,false);local ticks=surface.stats.ticks
  surface:update(root,30.001,true,false);surface:update(root,30.002,true,false);assert(surface.stats.ticks==ticks)
  surface:update(root,31,false,false);local writes=surface.stats.writes
  for i=1,20 do surface:update(root,31+i,false,false)end;assert(surface.stats.writes==writes)
  surface:update(root,52,true,true);writes=surface.stats.writes
  for i=1,20 do surface:update(root,52+i,true,true)end;assert(surface.stats.writes==writes)
 end)
 test("reduced board preview resize and return recompose same16 hosts once",function()
  for _,owner in ipairs({preview,root})do
   surface:update(owner,80,true,true);settle();surface:update(owner,80,true,true);geometry()
   assert(surface.root.Parent==owner and surface.bands[1].host==first and #surface.root:GetDescendants()+1==count)
   local writes=surface.stats.writes;surface:update(owner,81,true,true);assert(surface.stats.writes==writes)
  end
  root.Size=UDim2.fromOffset(568,160);settle();surface:update(root,82,true,true);geometry()
  local writes=surface.stats.writes;surface:update(root,83,true,true);assert(surface.stats.writes==writes)
 end)
 test("exterior phase pauses while independent inspected owner advances",function()
  surface:update(root,84,true,false);surface:update(root,85,true,false);local phase=surface.elapsed
  surface:update(preview,86,true,false);surface:update(preview,90,true,false)
  surface:update(root,91,true,false);assert(surface.elapsed==phase,"preview consumed confirmed phase")
 end)
 test("destroy removes all bands and stays idempotent",function()surface:destroy();surface:destroy();assert(not first.Parent and not surface.root.Parent)end)
 end)
 surface:destroy();root:Destroy();preview:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
