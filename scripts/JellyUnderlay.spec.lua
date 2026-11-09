-- Native draw-order ownership + exact raster pixels; no actual field requests.
return function(client,parent)
 local LCD=require(client.JellyLCD);local Palette=require(game.ReplicatedStorage.Shared.JellyPalette)
 local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(354,594);root.Parent=parent
 local cases={};local displays={};local optionalImage=false
 local function test(name,run)run();table.insert(cases,name)end
 local function regions()
  local host=Instance.new("Frame");host.Name="TargetRegions";host.Size=UDim2.fromScale(1,1);host.BackgroundTransparency=1;host.ZIndex=2;host.Parent=root
  for i=1,3 do local f=Instance.new("Frame");f.Name="Region"..i;f.Position=UDim2.fromScale((i-1)/3,0);f.Size=UDim2.fromScale(1/3,1);f.BackgroundColor3=Color3.fromHex("#466853");f.BackgroundTransparency=.79;f.ZIndex=2;f.Parent=host end
  return host
 end
 local function draw(lcd)
  lcd:beginFrame();lcd:draw(Vector2.new(13,45),7,7,0,Palette.byTier[1].body,0);assert(lcd:finishFrame())
  return buffer.readu32(lcd.pixels,(45*LCD.Width+13)*4)
 end
 local ok,problem=pcall(function()
  local lcd=assert(LCD.new(root,{backend="span"}));table.insert(displays,lcd);local host=regions()
  local allocated=lcd.surface.stats.dynamicAllocated;local count=#lcd.label:GetDescendants()
  local before=draw(lcd)
  test("span regions share the LCD subtree below every opaque gel row and existing rail masks",function()
   assert(lcd:attachRegions(host));assert(host.Parent==lcd.label and host.ZIndex==3)
   for _,row in ipairs(lcd.surface.rowHosts)do assert(row.ZIndex>host.ZIndex and row.Parent==lcd.label)end
   assert(#lcd.label:GetDescendants()==count+4 and lcd.surface.stats.dynamicAllocated==allocated)
   local foreground=0
   for _,f in ipairs(lcd.surface.static)do if f.ZIndex>host.ZIndex then foreground+=1 end end
   assert(foreground>0,"underlay no longer masked by existing outside/rail ink")
   lcd:setRegions(true,"left",2.6,-1.6,1.6);assert(draw(lcd)==before,"underlay changed opaque gel pixels")
  end)
  test("theme refresh retains underlay owner and the bounded pool; LCD release restores sprite underlay",function()
   local pool=lcd.surface.pool[1].node
   for _,id in ipairs(Themes.Order)do assert(lcd:setPalette(Themes.ById[id].lcd));assert(host.Parent==lcd.label and lcd.surface.pool[1].node==pool and draw(lcd)==before)end
   lcd:destroy();assert(host.Parent==root and host.ZIndex==2 and host.Region1.ZIndex==2)
  end)
  local image=LCD.new(root,{backend="image"})
  if image then
   table.insert(displays,image);optionalImage=true
   test("opaque image tints background before raster and preserves every overlapping gel tone",function()
    image:setRegions(false,"left",2.6,-1.6,1.6);local tone=draw(image)
    local old=buffer.readu32(image.background,(35*LCD.Width+13)*4)
    image:setRegions(true,"left",2.6,-1.6,1.6);assert(old~=buffer.readu32(image.background,(35*LCD.Width+13)*4),"empty side background did not change")
    assert(draw(image)==tone,"highlight washed over the ball")
    local first=buffer.fromstring(buffer.tostring(image.pixels))
    image:setRegions(true,"right",2.6,-1.6,1.6);draw(image)
    for y=38,51 do for x=6,20 do
     local offset=(y*LCD.Width+x)*4
     if buffer.readu32(image.pixels,offset)~=buffer.readu32(image.background,offset)then
      assert(buffer.readu32(image.pixels,offset)==buffer.readu32(first,offset),"gel rim/light recolored")
     end
    end end
   end)
  end
 end)
 for _,lcd in ipairs(displays)do lcd:destroy()end;root:Destroy();assert(ok,problem)
 return {passed=#cases,cases=cases,imageAvailable=optionalImage,spanPool=1536,extraCanvases=0,actualRasterGate="capture ball crossing active left/right region"}
end
