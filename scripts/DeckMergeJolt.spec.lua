return function(client,parent)
 local Jolt=require(client.DeckMergeJolt);local Backdrop=require(client.DeckBackdrop);local Art=require(client.DeckArt)
 local folder=Instance.new("Folder");folder.Parent=parent;local cases={};local owners={}
 local function test(name,run)run();table.insert(cases,name)end
 local function make()
  local shell=Instance.new("Frame");shell.Position=UDim2.fromOffset(45,30);shell.Parent=folder
  local rim=Instance.new("Frame");rim.Position=UDim2.fromOffset(60,55);rim.Parent=folder
  local field=Instance.new("Frame");field.Position=UDim2.fromOffset(75,70);field.Parent=folder
  local j=Jolt.new({shell,rim});table.insert(owners,j);j:setOwner(true,1,false);return j,shell,rim,field
 end
 local ok,problem=pcall(function()
  test("accepted serial and merge ID debounce a single bounded held curve",function()
   local j=make();assert(j:emit(1,10,4,1,false,0)and not j:emit(1,10,4,1,false,0))
   for i=0,100 do j:update(i*.001);assert(j.offset.Magnitude<=7.000001)end
   assert(not j:emit(0,11,5,2,true,.11))
  end)
  test("clear and chains cap at twelve pixels without adding or erasing stronger recoil",function()
   local j=make();assert(j:emit(1,1,5,5,true,0));assert(not j:emit(1,2,2,1,false,.01))
   assert(j.active.amplitude==12);j:update(.22*.16);assert(math.abs(j.offset.Magnitude-12)<.00001)
   assert(j:emit(1,3,5,2,true,.04)and j.active.amplitude==12)
  end)
  test("all tier peaks and durations match the accepted recipe",function()
   for _,recipe in ipairs({{2,false,3,.11},{3,false,5,.14},{4,false,7,.17},{5,false,9,.19},{5,true,12,.22}})do
    local j,shell=make();local base=shell.Position
    assert(j:emit(1,1,recipe[1],1,recipe[2],0))
    assert(j.active.amplitude==recipe[3]and j.active.duration==recipe[4])
    j:update(recipe[4]*.16);assert(math.abs(j.offset.Magnitude-recipe[3])<.00001)
    j:update(recipe[4]);assert(shell.Position==base and j.offset==Vector2.zero)
    j:emit(1,2,recipe[1],2,recipe[2],1);assert(math.abs(j.active.amplitude-math.min(12,recipe[3]*1.12))<.00001)
   end
  end)
  test("exterior tint and underlays flatten once while BoardBacking is transparent",function()
   local home=Instance.new("Frame");home.Parent=folder;Art.backdrop(home)
   local composite=home.ExteriorComposite
   assert(home.BackgroundTransparency==1 and composite:IsA("CanvasGroup")and math.abs(composite.GroupTransparency-.08)<.00001)
   assert(composite.BackgroundTransparency==0 and composite:FindFirstChild("CanopyArt")and composite:FindFirstChildOfClass("UIGradient"))
   home:Destroy()
  end)
  test("only registered presentation roots move and return exactly",function()
   local j,shell,rim,field=make();local a,b,c=shell.Position,rim.Position,field.Position
   j:emit(1,1,5,1,false,0)
   for i=0,40 do j:update(i/200);assert(field.Position==c)end
   assert(shell.Position==a and rim.Position==b and j.offset==Vector2.zero)
  end)
  test("one device root carries hardware LCD HUD and hit targets with identical signed translation",function()
   local root=Instance.new("Frame");root.Position=UDim2.fromOffset(13,17);root.Parent=folder
   local children={}
   for _,name in ipairs({"Shell","Tray","Hud","DropHitbox","AimRail"})do local c=Instance.new("Frame");c.Name=name;c.Position=UDim2.fromOffset(4,5);c.Parent=root;table.insert(children,c)end
   local j=Jolt.new({root});table.insert(owners,j);j:setOwner(true,9,false);j:emit(9,1,5,2,true,0);j:update(.04)
   -- UDim pixel offsets quantize each translated component. Compare the
   -- observed signed displacement within one native pixel, not float equality.
   local displacement=Vector2.new(root.Position.X.Offset-13,root.Position.Y.Offset-17)
   assert(j.offset.Magnitude>0 and displacement.Magnitude>0 and(displacement-j.offset).Magnitude<1.5)
   for _,child in ipairs(children)do assert(child.Parent==root and child.Position==UDim2.fromOffset(4,5))end
   j:setOwner(true,9,true);assert(root.Position==UDim2.fromOffset(13,17))
  end)
  test("fixed screen X keeps logical aim through signed twelve pixel recoil and resize",function()
   local pointer,left,width=170,100,280
   local expected=(pointer-left)/width
   for _,dx in ipairs({-12,-7.75,0,7.75,12})do
    assert(math.abs(Jolt.normalizedAim(pointer,left+dx,width,dx)-expected)<.000001)
   end
   -- Resize changes only the authored tray rectangle, never the recoil bias.
   left,width=80,420;expected=(pointer-left)/width
   for _,dx in ipairs({-12,0,12})do assert(math.abs(Jolt.normalizedAim(pointer,left+dx,width,dx)-expected)<.000001)end
   assert(Jolt.normalizedAim(-100,left+12,width,12)==0 and Jolt.normalizedAim(1000,left-12,width,-12)==1)
  end)
  test("pointer compensation follows quantized native root displacement and resets on rebase",function()
   local j,shell=make();j:emit(1,42,5,3,true,0);j:update(.04)
   local applied=j:appliedOffset();local left,width,pointer=100,280,170
   assert(applied.X==shell.Position.X.Offset-j.nodes[1].base.X.Offset)
   assert(math.abs(j:pointerAim(pointer,left+applied.X,width)-.25)<.000001)
   j:reset();shell.Position=UDim2.fromOffset(122,98);j:rebase()
   assert(j:appliedOffset()==Vector2.zero and math.abs(j:pointerAim(pointer,80,360)-.25)<.000001)
  end)
  test("mode overlay reduced and serial changes clear motion and scope duplicate IDs",function()
   local j,shell=make();local base=shell.Position;j:emit(1,1,4,1,false,0);j:update(.02)
   j:setOwner(false,1,false);assert(shell.Position==base)
   j:setOwner(true,1,true);assert(not j:emit(1,2,5,3,true,.03)and j.offset==Vector2.zero)
   j:setOwner(true,2,false);assert(j:emit(2,1,2,1,false,.04))
  end)
  test("reflow captures a fresh authored base after reset without accumulated displacement",function()
   local j,shell=make();j:emit(1,1,5,2,true,0);j:update(.03);j:reset()
   local base=UDim2.fromOffset(120,98);shell.Position=base;j:rebase();j:emit(1,2,3,1,false,1);j:update(2)
   assert(shell.Position==base)
  end)
  test("motif compositor preserves an opaque theme floor and intrinsic quieter marks",function()
   local root=Instance.new("Frame");root.Parent=folder;local b=Backdrop.new(root)
   b:configure("creek",{backdrop=Color3.fromHex("#124358"),face=Color3.fromHex("#069FC3"),highlight=Color3.fromHex("#B4E9EB"),buttons=Color3.fromHex("#225577"),trim=Color3.fromHex("#FFE9A6")})
   assert(b.root.BackgroundTransparency==0 and Backdrop.MotifOpacity==.88)
   local first,second=b.bands[1].pieces[1],b.bands[9].pieces[1]
   assert(math.abs(first.body.BackgroundTransparency-(1-.66*.88))<.000001)
   assert(math.abs(second.body.BackgroundTransparency-(1-.45*.88))<.000001)
   b:destroy()
  end)
 end)
 for _,owner in ipairs(owners)do owner:destroy()end;folder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
