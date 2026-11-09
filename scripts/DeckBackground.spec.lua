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
  assert(surface.root.ClipsDescendants,"only exterior print must clip")
  assert(surface.stats.pitch>=36 and surface.stats.pitch<=80)
  assert(surface.stats.motifWidth>=10 and surface.stats.motifWidth<=32)
  for _,b in ipairs(surface.bands)do
   assert(not b.host.ClipsDescendants and b.canvas.Size.X.Offset>=size.X*2-.1)
   assert(math.abs(b.canvas.Position.X.Offset)<=20.01 and math.abs(b.canvas.Position.Y.Offset)<=12.01,"unbounded print drift")
   assert(b.host.Size==UDim2.fromOffset(size.X,size.Y)and b.top==0)
   for _,p in ipairs(b.pieces)do assert(p.body.Size.X.Offset<=32 and p.body.Size.Y.Offset<=32,"oversized screen-scaled motif")end
   assert(b.pieces[1].body.Position.X.Scale==0 and b.pieces[2].body.Position.X.Scale==0,"motifs still scale with full viewport")
  end
 end
 local ok,err=pcall(function()
 settle();surface:configure("creek",Themes.ById.ice);surface:update(root,0,true,false);settle();surface:update(root,0,true,false)
 local count=#surface.root:GetDescendants()+1;local first=surface.bands[1].host
 test("one16-band545-instance surface includes256 actual motif frames",function()assert(#surface.bands==16 and surface.stats.primitives==256 and count==545 and surface.stats.created==count);geometry()end)
 for _,id in ipairs({"canopy","creek","lantern"})do test(id.." full period is closed and covers edges",function()
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
  root.Size=UDim2.fromOffset(1649,971);settle();surface:update(root,81,true,true);geometry();assert(surface.stats.pitch==64 and surface.stats.motifWidth==28)
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
