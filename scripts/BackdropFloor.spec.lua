-- Themed background -> canopy keeps the see-through garden floor (fd65cf3 review).
-- Fixture-only: builds its own backdrop host, never touches the live board.
return function(client,parent)
 local Art=require(client.DeckArt);local Backdrop=require(client.DeckBackdrop)
 local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
 local GuiService=game:GetService("GuiService")
 local root=Instance.new("Frame");root.Name="_BackdropFloorSpec";root.Size=UDim2.fromOffset(733,307);root.Parent=parent
 local cases={};local function test(n,f)f();table.insert(cases,n)end
 local expected=(1-Backdrop.ExteriorOpacity)*math.clamp(GuiService.PreferredTransparency,0,1)
 local function near(a,b)return math.abs(a-b)<.002 end
 -- The visible floor is either the composite host fill or the themed surface's own root.
 local function floor(host)
  if host.BackgroundTransparency<.999 then return host.BackgroundTransparency end
  for _,child in ipairs(host:GetChildren())do
   if child:IsA("GuiObject")and child.Visible and child.BackgroundTransparency<.999 and child.Size==UDim2.fromScale(1,1)then return child.BackgroundTransparency end
  end
  return 1
 end
 local ok,err=pcall(function()
  Art.backdrop(root);local host=root:FindFirstChild("ExteriorComposite");assert(host,"backdrop host missing")
  test("plain canopy starts with the see-through floor",function()
   Art.updateBackdrop(root,0,true,false,false);assert(near(host.BackgroundTransparency,expected),"canopy floor="..host.BackgroundTransparency)
  end)
  test("a themed background owns the floor once, without doubling it",function()
   Art.setBackground(root,"creek",Themes.ById.ice);Art.updateBackdrop(root,1,true,false,false)
   assert(host.BackgroundTransparency==1,"host fill doubled the themed floor");assert(floor(host)<1,"themed path lost the floor")
  end)
  test("switching back to the untinted canopy restores the floor",function()
   Art.setBackground(root,"canopy",nil);Art.updateBackdrop(root,2,true,false,false)
   assert(near(host.BackgroundTransparency,expected),"floor vanished after themed -> canopy: "..host.BackgroundTransparency)
  end)
  test("themed -> themed canopy still shows a floor",function()
   Art.setBackground(root,"lantern",Themes.ById.ice);Art.updateBackdrop(root,3,true,false,false)
   Art.setBackground(root,"canopy",Themes.ById.ice);Art.updateBackdrop(root,4,true,false,false)
   assert(floor(host)<1,"no floor on the themed canopy")
  end)
 end)
 root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
