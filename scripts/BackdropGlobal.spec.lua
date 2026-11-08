-- An enabled real Global ScreenGui with an opaque23 card and24 preview.
-- Clone Art's module state so fixture ownership never competes with the live game.
return function(client,parent)
 local Shared=game.ReplicatedStorage.Shared;local Theme=require(Shared.DeckThemes).ById.sherbet
 local class=require(client.DeckBackdrop);local artModule=client.DeckArt:Clone();artModule.Name="_GlobalBackdropFixtureArt";artModule.Parent=client
 local Art=require(artModule)
 local gui=Instance.new("ScreenGui");gui.Name="_BackdropGlobal";gui.DisplayOrder=parent.DisplayOrder+1;gui.Enabled=true;gui.ZIndexBehavior=Enum.ZIndexBehavior.Global;gui.Parent=parent.Parent
 local home=Instance.new("Frame");home.Name="Exterior";home.ZIndex=1;home.Size=UDim2.fromOffset(733,307);home.Parent=gui
 local card=Instance.new("Frame");card.Name="OpaqueCard";card.ZIndex=23;card.Size=UDim2.fromOffset(180,112);card.Parent=gui
 local preview=Instance.new("Frame");preview.Name="Preview";preview.ZIndex=24;preview.Position=UDim2.fromOffset(12,12);preview.Size=UDim2.fromOffset(102,68);preview.ClipsDescendants=true;preview.Parent=card
 local name=Instance.new("TextLabel");name.Name="Name";name.ZIndex=40;name.Text="Canopy";name.Size=UDim2.fromOffset(64,44);name.Position=UDim2.fromOffset(116,12);name.Parent=card
 local close=Instance.new("TextButton");close.Name="Close";close.ZIndex=60;close.Text="X";close.Size=UDim2.fromOffset(44,44);close.Position=UDim2.fromOffset(136,68);close.Parent=card
 local cases={};local surface
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function test(n,f)f();table.insert(cases,n)end
 local function snapshot(root)
  local rows={{node=root,z=root.ZIndex}};for _,n in ipairs(root:GetDescendants())do if n:IsA("GuiObject")then table.insert(rows,{node=n,z=n.ZIndex})end end;return rows
 end
 local function above(rows,host)
  for _,r in ipairs(rows)do assert(r.node.ZIndex>host.ZIndex and r.node.ZIndex<name.ZIndex and r.node.ZIndex<close.ZIndex,"borrowed paint hidden/over chrome "..r.node.Name)end
  local base=rows[1].node.ZIndex
  for _,r in ipairs(rows)do assert(r.node.ZIndex-base==r.z-rows[1].z,"relative paint order changed")end
 end
 local function restored(rows)for _,r in ipairs(rows)do assert(r.node.ZIndex==r.z,"exterior depth not restored: "..r.node.Name)end end
 local ok,err=pcall(function()
  settle();Art.backdrop(home);Art.setBackground(home,"canopy",Theme);Art.updateBackdrop(home,0,true,true,false)
  local canopy=home.CanopyArt;local layers=snapshot(canopy)
  test("Global confirmed Canopy is above opaque preview with exact relative order",function()
   Art.setBackgroundPreview(preview,"canopy",Theme,true);Art.updateBackdrop(home,1,false,true,true);settle()
   assert(canopy.Parent==preview);above(layers,preview)
  end)
  test("Canopy owner Z changes rebase once and restore original exterior depths",function()
   preview.ZIndex=30;Art.updateBackdrop(home,2,false,true,true);above(layers,preview)
   local changes=0;local connections={};for _,r in ipairs(layers)do table.insert(connections,r.node:GetPropertyChangedSignal("ZIndex"):Connect(function()changes+=1 end))end
   Art.updateBackdrop(home,3,false,true,true);Art.updateBackdrop(home,4,false,true,true);assert(changes==0)
   for _,c in ipairs(connections)do c:Disconnect()end
   Art.setBackgroundPreview(preview,nil,nil,false);Art.updateBackdrop(home,5,true,true,false);assert(canopy.Parent==home);restored(layers)
  end)
  surface=class.new(home);surface:configure("creek",Theme);surface:update(home,0,true,true);settle();surface:update(home,0,true,true)
  local rows=snapshot(surface.root);local first=surface.bands[1].host
  test("Global locked Creek borrows existing16 hosts above preview",function()
   preview.ZIndex=24;surface:update(preview,1,true,true);settle();surface:update(preview,1,true,true)
   assert(surface.root.Parent==preview and surface.bands[1].host==first);above(rows,preview)
   assert(#surface.root:GetDescendants()+1==545)
  end)
  test("pattern owner Z and exterior return keep order and reduced steady writes",function()
   preview.ZIndex=30;surface:update(preview,2,true,true);above(rows,preview)
   local writes=surface.stats.writes;surface:update(preview,3,true,true);assert(surface.stats.writes==writes)
   surface:update(home,4,true,true);settle();surface:update(home,4,true,true);restored(rows)
   assert(surface.bands[1].host==first and #surface.root:GetDescendants()+1==545)
  end)
  test("explicit host switch release and same-step destroy retain borrowed roots",function()
   surface:destroy() -- prior isolated class cases are complete; one Art-managed pool now.
   local host=preview:Clone();host.Name="TemporaryHost";host.Parent=card
   Art.setBackgroundPreview(host,"creek",Theme,true);Art.updateBackdrop(home,6,false,true,true);local root=host.PatternSurface
   local count=#root:GetDescendants()+1
   Art.setBackgroundPreview(preview,"creek",Theme,true)
   assert(root.Parent==home,"switch failed to return previous owner synchronously")
   Art.updateBackdrop(home,7,false,true,true);assert(root.Parent==preview)
   Art.setBackgroundPreview(host,nil,nil,false);host:Destroy()
   assert(root.Parent==preview and Art.isBackgroundPreviewVisible(preview))
   Art.setBackgroundPreview(preview,nil,nil,false);assert(root.Parent==home)
   Art.updateBackdrop(home,8,true,true,false)
   Art.setBackgroundPreview(preview,"creek",Theme,true);Art.updateBackdrop(home,9,false,true,true)
   assert(root.Parent==preview and #root:GetDescendants()+1==count and count==545)
   Art.setBackgroundPreview(preview,nil,nil,false)
  end)
  test("unexpected recursive host destruction repairs only missing renderers",function()
   local function host()local h=Instance.new("Frame");h.ZIndex=24;h.Size=UDim2.fromOffset(102,68);h.Parent=card;return h end
   local lostHost=host();Art.setBackgroundPreview(lostHost,"creek",Theme,true);Art.updateBackdrop(home,10,false,true,true)
   local lost=lostHost.PatternSurface;lostHost:Destroy() -- no explicit release: exceptional deferred-signal path
   local nextHost=host();Art.setBackgroundPreview(nextHost,"creek",Theme,true);Art.updateBackdrop(home,11,false,true,true)
   local repaired=nextHost.PatternSurface
   assert(repaired and repaired~=lost and not lost.Parent and #repaired:GetDescendants()+1==545)
   Art.updateBackdrop(home,12,false,true,true);assert(nextHost.PatternSurface==repaired)
   Art.setBackgroundPreview(nextHost,nil,nil,false);nextHost:Destroy()
   local lostCanopy=host();Art.setBackgroundPreview(lostCanopy,"canopy",Theme,true);Art.updateBackdrop(home,13,false,true,true)
   local oldCanopy=lostCanopy.CanopyArt;lostCanopy:Destroy()
   local finalHost=host();Art.setBackgroundPreview(finalHost,"canopy",Theme,true);Art.updateBackdrop(home,14,false,true,true)
   assert(finalHost.CanopyArt and finalHost.CanopyArt~=oldCanopy and not oldCanopy.Parent)
   Art.setBackgroundPreview(finalHost,"creek",Theme,true);Art.updateBackdrop(home,15,false,true,true)
   assert(finalHost.PatternSurface==repaired,"Canopy repair replaced healthy pattern pool")
   Art.setBackgroundPreview(finalHost,"canopy",Theme,true);Art.updateBackdrop(home,16,false,true,true)
   local finalCanopy=finalHost.CanopyArt
   home:Destroy();settle();Art.updateBackdrop(home,17,true,true,true)
   assert(not finalCanopy.Parent and not repaired.Parent,"backing teardown retained/revived borrowed renderers")
   finalHost:Destroy()
  end)

 end)
 if surface then surface:destroy()end;gui:Destroy();artModule:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
