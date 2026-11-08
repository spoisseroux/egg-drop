-- Six authored smooth physical prints, shared by shell, Style and worn devices.
-- Rounded/rotated primitives form an ivory silhouette behind one colored print.
local Art={}
local ivory=Color3.fromHex("#FFF5DF")
local colors={star="#FFBE39",glitch="#28C9C0",seed="#F57C91",wick="#FF8245",club="#39C6A2",lantern="#FFC74B"}
local function shape(parent,name,x,y,w,h,color,round,rotation)
 local f=Instance.new("Frame");f.Name,f.BorderSizePixel,f.BackgroundColor3=name,0,color
 f.AnchorPoint=Vector2.new(.5,.5);f.Position,f.Size=UDim2.fromScale(x,y),UDim2.fromScale(w,h)
 f.Rotation=rotation or 0;f.Active,f.Selectable,f.ZIndex=false,false,parent.ZIndex;f.Parent=parent
 if round then local c=Instance.new("UICorner");c.CornerRadius=UDim.new(round,0);c.Parent=f end
 return f
end
local silhouettes={
 star=true,
 glitch=function(g,c)
  shape(g,"Top",.52,.26,.62,.20,c,.10);shape(g,"Middle",.43,.49,.78,.24,c,.12)
  shape(g,"Foot",.56,.73,.62,.20,c,.1);shape(g,"Spark",.82,.15,.12,.12,c,.06)
  shape(g,"Offset",.14,.78,.12,.12,c,.06)
 end,
 seed=function(g,c)
  shape(g,"Seed",.48,.61,.72,.66,c,.48,-18);shape(g,"Stem",.50,.27,.10,.28,c,.5,18)
  shape(g,"Leaf",.64,.18,.35,.18,c,.5,-35)
 end,
 wick=function(g,c)
  shape(g,"FlameBase",.50,.65,.80,.54,c,.48);shape(g,"FlameTip",.52,.36,.42,.50,c,.08,32)
  shape(g,"FlameCurl",.32,.48,.26,.42,c,.5,24)
 end,
 club=function(g,c)
  shape(g,"LeftLeaf",.30,.47,.40,.43,c,.5,-25);shape(g,"RightLeaf",.70,.47,.40,.43,c,.5,25)
  shape(g,"CrownLeaf",.50,.28,.43,.43,c,.5);shape(g,"Stem",.50,.73,.19,.40,c,.16)
  shape(g,"Foot",.50,.87,.40,.12,c,.25)
 end,
 lantern=function(g,c)
  shape(g,"Lantern",.50,.55,.62,.57,c,.16);shape(g,"Roof",.50,.27,.76,.13,c,.18)
  shape(g,"Foot",.50,.84,.76,.13,c,.18)
  shape(g,"HandleLeft",.37,.16,.09,.22,c,.4,-18);shape(g,"HandleRight",.63,.16,.09,.22,c,.4,18)
  shape(g,"HandleTop",.50,.075,.23,.09,c,.4)
 end,
}
local function group(root,name,color,inset,z)
 local g=Instance.new("Frame");g.Name,g.BackgroundTransparency,g.BackgroundColor3=name,1,color
 g.Position,g.Size=UDim2.fromOffset(inset,inset),UDim2.new(1,-inset*2,1,-inset*2)
 g.Active,g.Selectable,g.ZIndex=false,false,z;g.Parent=root;return g
end
function Art.paint(host,id)
 host.Active,host.Selectable=false,false
 if host:IsA("TextLabel")then host.Text=""end
 host.BackgroundTransparency=1;host.Visible=silhouettes[id]~=nil and host:GetAttribute("StickerPrintSpace")~=false
 if host:GetAttribute("StickerArtId")==id then return end
 host:SetAttribute("StickerArtId",id)
 local old=host:FindFirstChild("StickerPixels");if old then old:Destroy()end
 if not silhouettes[id]then return end
 local root=Instance.new("Frame");root.Name,root.Size,root.BackgroundTransparency="StickerPixels",UDim2.fromScale(1,1),1
 root.Active,root.Selectable,root.ZIndex=false,false,host.ZIndex;root.Parent=host
 root:SetAttribute("SmoothPrint",true)
 local color=Color3.fromHex(colors[id]);local paper=group(root,"DieCut",ivory,0,root.ZIndex)
 local ink=group(root,"PrintedInk",color,2,root.ZIndex+1);local spot=group(root,"SpotInk",ivory,4,root.ZIndex+2)
 if id=="star"then
  -- A conventional five-point star is one native outline, with no overlapping
  -- arm seams. Scaling is decorative only; functional labels never use this.
  local glyph=Instance.new("TextLabel");glyph.Name="StarGlyph";glyph.Text="★";glyph.Font=Enum.Font.SourceSans
  glyph.AnchorPoint=Vector2.new(.5,.5);glyph.Position=UDim2.fromScale(.5,.5);glyph.Size=UDim2.fromOffset(100,100)
  glyph.BackgroundTransparency=1;glyph.BorderSizePixel=0
  glyph.TextColor3=color;glyph.TextWrapped=false;glyph.TextScaled=false;glyph.TextSize=100
  glyph.Active,glyph.Selectable,glyph.ZIndex=false,false,ink.ZIndex;glyph.Parent=ink
  local outline=Instance.new("UIStroke");outline.Name="DieCutStroke";outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
  outline.Color,outline.Thickness,outline.LineJoinMode=ivory,2,Enum.LineJoinMode.Round;outline.Parent=glyph
  paper:SetAttribute("OutlineOwner","PrintedInk.StarGlyph.DieCutStroke")
  local scale=Instance.new("UIScale");scale.Name="GlyphScale";scale.Parent=glyph
  local base=68 -- Native SourceSans ★ at the 100px font cap; Largest needs ~5% headroom.
  local lastWidth,lastInherited
  local function sizeGlyph()
   local absolute=host.AbsoluteSize.X;if absolute<=0 then return end
   local width=if host.Size.X.Scale==0 and host.Size.X.Offset>0 then host.Size.X.Offset else absolute
   local inherited=absolute/width
   if lastWidth==width and lastInherited==inherited then return end;lastWidth,lastInherited=width,inherited
   scale.Scale=.90*width/base;outline.Thickness=2/(scale.Scale*inherited)
  end
  -- The print owns this signal, so changing styles releases it with the old ink.
  ink:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeGlyph);sizeGlyph()
 else silhouettes[id](paper,ivory);silhouettes[id](ink,color)end
 if id=="wick"then shape(spot,"WarmCore",.48,.62,.22,.38,ivory,.45,-12)
 elseif id=="lantern"then shape(spot,"Window",.50,.54,.16,.35,ivory,.2)
 elseif id=="club"then shape(spot,"Crest",.50,.48,.13,.27,ivory,.4)
 elseif id=="star"then shape(spot,"PrintGlint",.46,.43,.12,.035,ivory,.4,-18)
 else shape(spot,"PrintGlint",.37,.36,.15,.055,ivory,.4,-18)end
end
local function overlap(a,b)
 return a.x<b.x+b.w+4 and a.x+a.w>b.x-4 and a.y<b.y+b.h+4 and a.y+a.h>b.y-4
end
function Art.printSeat(l,caption)
 local shell=l.shell;local factor=1.2247448714 -- rotated square at -15 degrees
 local left=math.max(shell.x+9,if l.lateral then l.bezel.x+l.bezel.w+4 else shell.x+shell.w*.52)
 local right,bottom=shell.x+shell.w-9,shell.y+shell.h-9
 local maximum=math.floor(math.min(256,(if l.lateral then l.right.w else shell.w*.36)*.76,(right-left)/factor))
 local obstacles={l.queue,l.meter,l.walletVisual or l.wallet,l.quest,l.menu,l.lounge,l.dpad,l.drop,l.bezel}
 if caption then table.insert(obstacles,caption)end
 if l.speakerVisible then table.insert(obstacles,l.speaker)end
 local preferredX=l.right.x+l.right.w*.5
 local preferredY=(l.meter.y+l.meter.h+l.drop.y)*.5
 for size=maximum,16,-1 do
  local extent=size*factor
  local xs={preferredX-extent/2,left,right-extent}
  local ys={preferredY-extent/2,l.meter.y+l.meter.h+8,l.drop.y-extent-8,bottom-extent,shell.y+9}
  for _,r in ipairs(obstacles)do table.insert(xs,r.x+r.w+5);table.insert(xs,r.x-extent-5);table.insert(ys,r.y+r.h+5);table.insert(ys,r.y-extent-5)end
  local best,score
  for _,x in ipairs(xs)do for _,y in ipairs(ys)do
   if x>=left and x+extent<=right and y>=shell.y+9 and y+extent<=bottom then
    local r={x=x,y=y,w=extent,h=extent,printSize=size,rotation=-15,visibleFraction=1};local free=true
    for _,o in ipairs(obstacles)do if overlap(r,o)then free=false;break end end
    if free then local distance=(x+extent/2-preferredX)^2+(y+extent/2-preferredY)^2;if not score or distance<score then best,score=r,distance end end
   end
  end end
  if best then return best end
 end
 return nil
end
local seatCache=setmetatable({},{__mode="k"})
function Art.layoutPrint(host,l,caption)
 local last=seatCache[host];local wallet=l.walletVisual or l.wallet
 local x,y,w,h=if caption then caption.x else -1,if caption then caption.y else -1,if caption then caption.w else -1,if caption then caption.h else -1
 if last and last.layout==l and last.x==x and last.y==y and last.w==w and last.h==h and last.wx==wallet.x and last.wy==wallet.y and last.ww==wallet.w and last.wh==wallet.h then return last.seat end
 local seat=Art.printSeat(l,caption);seatCache[host]={layout=l,x=x,y=y,w=w,h=h,wx=wallet.x,wy=wallet.y,ww=wallet.w,wh=wallet.h,seat=seat}
 host:SetAttribute("StickerPrintSpace",seat~=nil)
 if seat then
  local pad=(seat.w-seat.printSize)/2
  host.Position=UDim2.fromOffset(seat.x+pad-l.shell.x-5,seat.y+pad-l.shell.y-4)
  host.Size=UDim2.fromOffset(seat.printSize,seat.printSize);host.Rotation=seat.rotation
  host:SetAttribute("InkVisibleFraction",seat.visibleFraction)
 end
 host.Visible=seat~=nil and silhouettes[host:GetAttribute("StickerArtId")]~=nil
 return seat
end
return Art
