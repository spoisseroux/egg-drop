-- Native draw-order ownership + exact raster pixels; no actual field requests.
return function(client,parent)
 local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
 local LCD=require(client.JellyLCD);local Palette=require(game.ReplicatedStorage.Shared.JellyPalette)
 local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(354,594);root.Parent=parent
 local cases={};local displays={};local optionalImage=false
 local function test(name,run)run();table.insert(cases,name)end
 local function regions()
  local host=Instance.new("Frame");host.Name="TargetRegions";host.Size=UDim2.fromScale(1,1);host.BackgroundTransparency=1;host.ZIndex=2;host.Parent=root
  for i,x in ipairs({-2.6,2.6})do
   local f=Instance.new("Frame");f.Name="Region"..i;f.Position=UDim2.fromScale(.5+x/(Config.Width+.8),.025);f.AnchorPoint=Vector2.new(.5,0)
   f.Size=UDim2.new(0,2,.95,0);f.BackgroundColor3=Color3.fromHex("#466853");f.BackgroundTransparency=.35;f.ZIndex=2;f.Parent=host
  end
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
  test("thin span thresholds share the LCD subtree below every opaque gel row and existing rail masks",function()
   assert(lcd:attachRegions(host));assert(host.Parent==lcd.label and host.ZIndex==3)
   for _,row in ipairs(lcd.surface.rowHosts)do assert(row.ZIndex>host.ZIndex and row.Parent==lcd.label)end
   assert(#lcd.label:GetDescendants()==count+3 and lcd.surface.stats.dynamicAllocated==allocated)
   local foreground=0
   for _,f in ipairs(lcd.surface.static)do if f.ZIndex>host.ZIndex then foreground+=1 end end
   assert(foreground>0,"underlay no longer masked by existing outside/rail ink")
   lcd:setRegions(true,"left",2.6,-1.6,1.6);assert(draw(lcd)==before,"underlay changed opaque gel pixels")
  end)
  test("native and sprite threshold hosts retain 2px width at compact and roomy sizes",function()
   for _,width in ipairs({172,354,560})do
    root.Size=UDim2.fromOffset(width,width*(Config.Height+.8)/(Config.Width+.8))
    game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()
    for _,line in ipairs(host:GetChildren())do assert(line.Size.X.Scale==0 and line.Size.X.Offset==2 and line.AbsoluteSize.X<=2.01)end
   end
  end)
  test("theme refresh retains underlay owner and the bounded pool; LCD release restores sprite underlay",function()
   local pool=lcd.surface.pool[1].node
   for _,id in ipairs(Themes.Order)do assert(lcd:setPalette(Themes.ById[id].lcd));assert(host.Parent==lcd.label and lcd.surface.pool[1].node==pool and draw(lcd)==before)end
   lcd:destroy();assert(host.Parent==root and host.ZIndex==2 and host.Region1.ZIndex==2)
  end)
  local image=LCD.new(root,{backend="image"})
  if image then
   table.insert(displays,image);optionalImage=true
   test("image background changes only the two exact one-cell threshold columns and keeps gel opaque",function()
    image:setRegions(false,"left",2.6,-1.6,1.6);local tone=draw(image)
    local original=buffer.fromstring(buffer.tostring(image.background))
    image:setRegions(true,"left",2.6,-1.6,1.6)
    local expected={[math.floor(LCD.Width*(.5-2.6/(Config.Width+.8)))]=true,[math.floor(LCD.Width*(.5+2.6/(Config.Width+.8)))]=true}
    local changed=0
    for y=0,LCD.Height-1 do for x=0,LCD.Width-1 do
     local offset=(y*LCD.Width+x)*4
     if buffer.readu32(original,offset)~=buffer.readu32(image.background,offset)then
      assert(expected[x],"region filled interior column "..x);changed+=1
     end
    end end
    assert(changed>20 and changed<=LCD.Height*2,"threshold is missing or wider than one cell")
    assert(draw(image)==tone,"threshold painted over an opaque gel")
    local left=buffer.tostring(image.background)
    image:setRegions(true,"right",2.6,-1.6,1.6)
    assert(buffer.tostring(image.background)==left,"active side recolored a region fill")
   end)
   test("center objective adds only its two boundary columns",function()
    image:setRegions(true,"left",2.6,-1.6,1.6);local original=buffer.fromstring(buffer.tostring(image.background))
    image:setRegions(true,"center",2.6,-1.6,1.6)
    local expected={[math.floor(LCD.Width*(.5-1.6/(Config.Width+.8)))]=true,[math.floor(LCD.Width*(.5+1.6/(Config.Width+.8)))]=true}
    local changed=0
    for y=0,LCD.Height-1 do for x=0,LCD.Width-1 do local offset=(y*LCD.Width+x)*4
     if buffer.readu32(original,offset)~=buffer.readu32(image.background,offset)then assert(expected[x]);changed+=1 end
    end end
    assert(changed>20 and changed<=LCD.Height*2)
   end)
  end
 end)
 for _,lcd in ipairs(displays)do lcd:destroy()end;root:Destroy();assert(ok,problem)
 return {passed=#cases,cases=cases,imageAvailable=optionalImage,spanPool=1536,extraCanvases=0,actualRasterGate="capture ball crossing active left/right region"}
end
