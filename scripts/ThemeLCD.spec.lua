-- Isolated native span pool. No default renderer or economy state is mutated.
return function(client,parent)
 local LCD=require(client.JellyLCD);local Themes=require(game.ReplicatedStorage.Shared.DeckThemes);local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(354,594);root.Parent=parent
 local v=assert(LCD.new(root,{backend="span",maxSpans=1536}));local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 local function packed(c)return math.floor(c.R*255+.5)+math.floor(c.G*255+.5)*256+math.floor(c.B*255+.5)*65536+4278190080 end
 local ok,err=pcall(function()
 for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end
 v:beginFrame();v:drawGuide(Vector2.new(LCD.Width/3,20));v:draw(Vector2.new(LCD.Width/2,LCD.Height/2),5,5,0,Config.Tiers[1].color,0);assert(v:finishFrame());v.label.Visible=true
 local gel={};for y=45,61 do for x=25,39 do local o=(y*LCD.Width+x)*4;local n=buffer.readu32(v.pixels,o);if n~=buffer.readu32(v.background,o)then gel[o]=n end end end
 local pool,first,count=v.surface.pool,v.surface.pool[1].node,#v.surface.root:GetDescendants()
 for _,id in ipairs(Themes.Order)do test(id.." static roles preserve gel/pool/current owner",function()
  assert(v:setPalette(Themes.ById[id].lcd));assert(v.surface.pool==pool and pool[1].node==first and #v.surface.root:GetDescendants()==count)
  assert(v:getStats().dynamicCreated==1536 and v.label.Visible and not v.failed)
  for offset,n in pairs(gel)do assert(buffer.readu32(v.pixels,offset)==n,"live gel recolored by chrome palette")end
  -- x=0,y=0 is the authored outer rim (edge~-1.67), not exterior.
  -- Bottom-left lies outside the sloped bank; verify every static role separately.
  for _,sample in ipairs({{0,0,"rim"},{0,LCD.Height-1,"outside"},{1,0,"rail"},{3,7,"dither"},{math.floor(LCD.Width/2),math.floor(LCD.Height/2),"base"}})do
   local offset=(sample[2]*LCD.Width+sample[1])*4
   assert(buffer.readu32(v.background,offset)==packed(Themes.ById[id].lcd[sample[3]]),id.." static "..sample[3].." sample ("..sample[1]..","..sample[2]..")")
  end
  assert(buffer.readu32(v.pixels,(21*LCD.Width+math.floor(LCD.Width/3))*4)==packed(Themes.ById[id].lcd.guide),"guide retained old palette")
 end)end
 test("failed repaint is explicit sticky failure for existing cheap-owner bridge",function()
  v.surface.paint=function()error("injected palette paint failure")end
  local target=if v.boardPalette==Themes.ById.sherbet.lcd then Themes.ById.ice.lcd else Themes.ById.sherbet.lcd
  assert(not v:setPalette(target)and v.failed and not v.label.Visible)
 end)
 end)
 v:destroy();root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
