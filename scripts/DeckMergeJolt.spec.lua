return function(client,parent)
 local Jolt=require(client.DeckMergeJolt);local Backdrop=require(client.DeckBackdrop)
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
   for i=0,100 do j:update(i*.001);assert(j.offset.Magnitude<=3.000001)end
   assert(not j:emit(0,11,5,2,true,.11))
  end)
  test("clear and chains cap at four pixels without adding or erasing stronger recoil",function()
   local j=make();assert(j:emit(1,1,5,5,true,0));assert(not j:emit(1,2,2,1,false,.01))
   assert(j.active.amplitude==4);j:update(.18*.16);assert(math.abs(j.offset.Magnitude-4)<.00001)
   assert(j:emit(1,3,5,2,true,.04)and j.active.amplitude==4)
  end)
  test("absolute base transform returns exactly and never moves field or input targets",function()
   local j,shell,rim,field=make();local a,b,c=shell.Position,rim.Position,field.Position
   j:emit(1,1,5,1,false,0)
   for i=0,40 do j:update(i/200);assert(field.Position==c)end
   assert(shell.Position==a and rim.Position==b and j.offset==Vector2.zero)
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
