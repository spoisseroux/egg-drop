-- Presentation data + actual five-part legacy fallback; never mutates a live board.
return function(client,parent)
 local Palette=require(game.ReplicatedStorage.Shared.JellyPalette)
 local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
 local Jelly=require(client.JellyVisual)
 local folder=Instance.new("Folder");folder.Name="_JellyPaletteSpec";folder.Parent=workspace
 local cases,views,sources={},{},{}
 local function test(name,run)run();table.insert(cases,name)end
 local function luminance(c)
  local function linear(v)return if v<=.04045 then v/12.92 else((v+.055)/1.055)^2.4 end
  return .2126*linear(c.R)+.7152*linear(c.G)+.0722*linear(c.B)
 end
 local function fixture(tier)
  local source=Instance.new("Part");source.Name="Palette"..tier;source.Size=Vector3.one*Config.Tiers[tier].radius*2
  source.Color=Config.Tiers[tier].color;source.Position=Vector3.new(0,8,0);source:SetAttribute("EggId",tier)
  local view=Jelly.new(folder,source);table.insert(views,view);table.insert(sources,source);return view,source
 end
 local ok,problem=pcall(function()
  test("legacy and vivid tier colors resolve identically without changing physical config",function()
   local expected={.72,1.04,1.43,1.88,2.35}
   for tier,roles in ipairs(Palette.byTier)do
    assert(Palette.resolve(tier)==roles and Palette.resolve(Config.Tiers[tier].color)==roles and Palette.resolve(roles.body)==roles)
    assert(Config.Tiers[tier].radius==expected[tier] and Config.Tiers[tier].mark==({"I","II","III","IV","V"})[tier])
    assert(luminance(roles.rim)<luminance(roles.lower)and luminance(roles.lower)<luminance(roles.body)and luminance(roles.body)<luminance(roles.upper))
    assert((luminance(roles.body)+.05)/(luminance(roles.mark)+.05)>=4.5,"tier "..tier.." center cannot support Roman ink")
   end
   local color=Color3.fromHex("#35BCA8");assert(Palette.resolve(color)==Palette.resolve(color)and Palette.resolve(color).body==color)
   assert(Config.DropInterval==.35 and Config.FixedStep==1/120 and Config.MaxEggs==32)
  end)
  test("five fixed fallback layers are passive colored once and never change the source pose",function()
   for tier,roles in ipairs(Palette.byTier)do
    local view,source=fixture(tier);local original=source.CFrame;local size,color=source.Size,source.Color
    assert(#view.model:GetChildren()==5 and view.rim.part.Color==roles.rim and view.lower.part.Color==roles.lower and view.body.part.Color==roles.body and view.fleck.part.Color==roles.upper and view.glint.part.Color==roles.glint)
    for _,part in ipairs(view.model:GetChildren())do assert(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch and not part.CastShadow)end
    local count=#view.model:GetDescendants()
    for _,angle in ipairs({0,math.pi/4,math.pi/2,-math.pi/4})do
     view:impact(Vector2.new(math.sin(angle),math.cos(angle)),20)
     for frame=1,20 do view:render(source.Position,1/60,frame/60,nil,nil,false)end
     local delta=view.glint.part.Position-view.rim.part.Position
     assert(delta.X<0 and delta.Y>0,"fallback light turned away from upper-left")
    end
    view:render(source.Position,0,1,nil,nil,true);local rest=view.glint.part.CFrame
    view:render(source.Position,0,999,nil,nil,true);assert(view.glint.part.CFrame==rest and #view.model:GetDescendants()==count)
    assert(source.CFrame==original and source.Size==size and source.Color==color,"feedback changed physical source")
   end
  end)
 end)
 for _,view in ipairs(views)do view:destroy()end;for _,source in ipairs(sources)do source:Destroy()end;folder:Destroy()
 assert(ok,problem);return{passed=#cases,cases=cases,tiers=#Palette.byTier,fallbackParts=5}
end
