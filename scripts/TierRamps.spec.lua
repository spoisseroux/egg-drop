-- Studio Client. Vivid egg tier ramps (UI-SPEC-REDESIGN-MENUS 6.2): the five
-- deep/body/light hexes, tier V violet, a motif per tier (drawn only by the free Marbles
-- theme since batch 2026-11-13), no tier numerals, no outline role, and the LCD shading/bloom
-- rules. Every ball theme keeps the hue family per size and five distinct sizes (BallThemes).
-- Pure data plus an isolated span LCD on a scratch frame; never touches the live board.
-- Usage: require(PlayerScripts.Client.ZZSpecs.TierRamps)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Palette=require(game.ReplicatedStorage.Shared.JellyPalette)
 local Pico8=require(game.ReplicatedStorage.Shared.Pico8)
 local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
 local LCD=require(client.JellyLCD)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function linear(v)return if v<=.04045 then v/12.92 else((v+.055)/1.055)^2.4 end
 local function luminance(c)return .2126*linear(c.R)+.7152*linear(c.G)+.0722*linear(c.B)end
 local function contrast(a,b)local x,y=luminance(a),luminance(b);return(math.max(x,y)+.05)/(math.min(x,y)+.05)end
 local function hex(c)return "#"..c:ToHex():upper()end
 local expected={
  {"#0A3FD6","#2E8BFF","#8FE1FF","plain"},{"#E0400A","#FF8A1A","#FFD45C","bands"},{"#04963F","#22E06A","#B4FF7A","speckles"},
  {"#C4126F","#FF4DA6","#FFB0DC","stars"},{"#5B21D6","#A66BFF","#E3C8FF","dots"},
 }
 local root=Instance.new("Frame");root.Name="_TierRampsSpec";root.Size=UDim2.fromOffset(354,594);root.BackgroundTransparency=1;root.Parent=parent
 local lcd
 local ok,problem=pcall(function()
  test("five ramps match the spec table and resolve from the legacy server colours",function()
   assert(#Palette.byTier==5 and #Pico8.TierRamps==5)
   for tier,row in ipairs(expected)do
    local roles=Palette.byTier[tier]
    assert(hex(roles.deep)==row[1]and hex(roles.body)==row[2]and hex(roles.light)==row[3],"tier "..tier.." ramp")
    assert(roles.motifKind==Palette.Motifs[row[4]],"tier "..tier.." motif")
    assert(Palette.resolve(Config.Tiers[tier].color)==roles and Palette.resolve(roles.body)==roles and Palette.resolve(tier)==roles)
    assert(luminance(roles.deep)<luminance(roles.body)and luminance(roles.body)<luminance(roles.light),"tier "..tier.." ramp order")
   end
  end)
  test("tier V is violet, clear of orange tier II and gold Stars",function()
   local h,s=Palette.byTier[5].body:ToHSV()
   assert(h>.70 and h<.80 and s>.5,"tier V hue="..h)
   local h2=Palette.byTier[2].body:ToHSV();local star=Color3.fromHex("#FFC14D"):ToHSV()
   assert(math.abs(h-h2)>.3 and math.abs(h-star)>.3)
  end)
  test("no tier numerals: no mark roles or threshold (batch 2026-11-13 R1)",function()
   for _,roles in ipairs(Palette.byTier)do assert(roles.mark==nil and roles.markShadow==nil)end
   assert(Palette.MarkMinRadius==nil)
  end)
  test("Smileys and Marbles use these ramps; Marbles alone keeps the motifs",function()
   local Themes=require(game.ReplicatedStorage.Shared.BallThemes)
   for tier,row in ipairs(expected)do
    for _,id in ipairs({"smileys","marbles"})do
     local r=Themes.ById[id].ramps[tier];assert(r.deep==row[1]and r.body==row[2]and r.light==row[3],id.." tier "..tier)
    end
    assert(LCD.themeTones(Themes.get("marbles"),tier)[6]==Palette.byTier[tier].motifKind,"Marbles motif "..tier)
    assert(LCD.themeTones(Themes.get("smileys"),tier)[6]==1,"Smileys has no motif "..tier)
   end
  end)
  test("motif is white 23% over the body and every tier past I has one",function()
   local kinds={}
   for tier,roles in ipairs(Palette.byTier)do
    local mixed=roles.body:Lerp(Color3.new(1,1,1),.23)
    assert(math.abs(roles.motif.R-mixed.R)<.003 and math.abs(roles.motif.G-mixed.G)<.003 and math.abs(roles.motif.B-mixed.B)<.003)
    assert(not kinds[roles.motifKind],"motif repeats");kinds[roles.motifKind]=true
   end
  end)
  lcd=assert(LCD.new(root,{backend="span",maxSpans=1536}))
  local function tones(color)local t=LCD.tones(color);return{[t[1]]="deep",[t[2]]="body",[t[3]]="light",[t[4]]="glint",[t[5]]="motif"}end
  local function census(color)
   local roles=tones(color);local seen,bloom,other={},0,0
   for y=0,LCD.Height-1 do for x=0,LCD.Width-1 do
    local o=(y*LCD.Width+x)*4;local p=buffer.readu32(lcd.pixels,o)
    if roles[p]then seen[roles[p]]=(seen[roles[p]]or 0)+1 elseif p~=buffer.readu32(lcd.background,o)then bloom+=1 end
   end end
   return seen,bloom
  end
  test("LCD eggs have no outline: deep only lower-right, light upper-left, white glint",function()
   local center=Vector2.new(LCD.Width/2,LCD.Height*.45)
   for tier,entry in ipairs(Config.Tiers)do
    local r=entry.radius*LCD.Width/(Config.Width+.8);lcd:beginFrame();lcd:draw(center,r,r,0,entry.color,0)
    local seen=census(entry.color);assert(seen.body and seen.light and seen.deep and seen.glint,"tier "..tier.." misses a ramp role")
    -- The top-left edge pixel is lit, never the deep shade (the old dark rim).
    local x,y=math.floor(center.X-r*.62),math.floor(center.Y-r*.62)
    local p=buffer.readu32(lcd.pixels,(y*LCD.Width+x)*4);assert(tones(entry.color)[p]~="deep","tier "..tier.." has a dark upper rim")
   end
  end)
  test("bloom lands on the well around each egg, stronger for the matching egg, never over another egg",function()
   local center=Vector2.new(LCD.Width/2,LCD.Height*.45);local r=Config.Tiers[3].radius*LCD.Width/(Config.Width+.8)
   lcd:beginFrame();lcd:draw(center,r,r,0,Config.Tiers[3].color,0);local _,normal=census(Config.Tiers[3].color)
   lcd:beginFrame();lcd:draw(center,r,r,0,Config.Tiers[3].color,0,true);local _,strong=census(Config.Tiers[3].color)
   assert(normal>0 and strong>normal,"bloom "..normal.." match "..strong)
   -- A later egg's bloom never overwrites an earlier egg's body.
   lcd:beginFrame();lcd:draw(center,r,r,0,Config.Tiers[3].color,0)
   local before=census(Config.Tiers[3].color)
   lcd:draw(center+Vector2.new(r*2.05,0),r,r,0,Config.Tiers[1].color,0)
   local after=census(Config.Tiers[3].color)
   assert(after.body==before.body and after.light==before.light,"bloom covered a neighbour")
   lcd.bloom=false;lcd:beginFrame();lcd:draw(center,r,r,0,Config.Tiers[3].color,0);local _,none=census(Config.Tiers[3].color);lcd.bloom=nil
   assert(none==0,"bloom switch")
  end)
  test("well is a banded gradient with a top shadow and lighter banks, no rail or rim rows",function()
   local t=lcd.tones;assert(#t.bands==LCD.ShadowRows+LCD.GradientBands)
   local function at(x,y)return buffer.readu32(lcd.background,(y*LCD.Width+x)*4)end
   -- Every pixel in a row away from the banks is that row's band: no edge colour.
   for _,y in ipairs({0,1,3,20,50,80})do
    local band=t.bands[LCD.bandOfRow(y)]
    for x=0,LCD.Width-1 do assert(at(x,y)==band,"row "..y.." x "..x.." is not its band")end
   end
   local function lum(p)return(p%256)*.2126+(math.floor(p/256)%256)*.7152+(math.floor(p/65536)%256)*.0722 end
   assert(lum(t.bands[1])<lum(t.bands[LCD.ShadowRows+1]),"top inner shadow")
   assert(lum(t.bands[LCD.ShadowRows+1])>lum(t.bands[#t.bands]),"gradient darkens toward the floor")
   assert(at(1,LCD.Height-6)==t.bank and lum(t.bank)>lum(t.bands[#t.bands]),"lighter bank")
  end)
 end)
 if lcd then lcd:destroy()end;root:Destroy();assert(ok,problem)
 return{passed=#cases,cases=cases}
end
