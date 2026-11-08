-- Real LocalScript text metrics, pure solved casing + passive print. No sends.
-- Capture normal phone DROP below A and its newly freed print gap; dense roots
-- retain the original caption order and every existing input rectangle.
return function(client,parent,onlySize)
 local Layout=require(client.DeckLayout);local Dispenser=require(client.DropDispenser);local Art=require(client.DeckArt)
 local Shared=game.ReplicatedStorage.Shared;local Stickers=require(Shared.DeckStickers);local Config=require(Shared.BoardConfig)
 local Text=game:GetService("TextService");local cases={};local glyphMeasurements={};local ratio=(Config.Width+.8)/(Config.Height+.8)
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(1800,1000);root.Parent=parent
 local label=Instance.new("TextLabel");label.Parent=root
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function overlaps(a,b)return a.x<b.x+b.w and a.x+a.w>b.x and a.y<b.y+b.h and a.y+a.h>b.y end
 local ok,err=pcall(function()
 for _,size in ipairs(if onlySize then {onlySize}else {Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
  local short=size.X>=350 and size.X>=size.Y*1.2 and size.Y<280
  local cap=if short then 12 else 14
  local qh=math.ceil(Text:GetTextSize("Next",12,Art.Font.Body,Vector2.new(1000,100)).Y)+4
  local mark=Text:GetTextSize("III",12,Art.Font.Counter,Vector2.new(1000,100));local d=math.max(18,math.ceil(math.max(mark.X,mark.Y))+6)
  local l=Layout.resolve(size,ratio,{utilityWidth=Text:GetTextSize("Lounge",cap,Art.Font.Action,Vector2.new(1000,100)).X+14,
   lineHeight=qh,queueHeight=math.max(qh+d+10,qh*2+8),walletLineHeight=Text:GetTextSize("0",18,Art.Font.Counter,Vector2.new(1000,100)).Y+4,countWidth=Text:GetTextSize("24/24",12,Art.Font.Counter,Vector2.new(1000,100)).X+4})
  Layout.fitInstruments(l,Dispenser.preferredHeight({budget=24},l.meter.w,l.meter.h))
  local face=Instance.new("Frame");face.BackgroundTransparency=1;face.Position=UDim2.fromOffset(l.shell.x+5,l.shell.y+4);face.Size=UDim2.fromOffset(l.shell.w-10,l.shell.h-8);face.Parent=root
  local host=Instance.new("Frame");host.Parent=face;Stickers.paint(host,"star");local pixels=host.StickerPixels
  for _,word in ipairs({"DROP","FALLING","SETTLE","SAVING"})do
   label.Text=word;Art.type(label,"Supporting",l.short);label.Font=Art.Font.Action
   local width=math.min(l.right.w-8,l.shell.w-16,math.max(l.dropSize,Art.textWidth(label)+8));local height=Art.textHeight(label,width,16)
   local x=math.clamp(l.drop.x+l.dropSize/2-width/2,l.shell.x+8,l.shell.x+l.shell.w-width-8)
   local caption
   if word~="SETTLE"and(not l.short or word~="DROP")then
    local belowFirst=l.lateral and not l.roomy and not l.short and not l.dense
    local candidates=if belowFirst then {l.drop.y+l.dropSize+4,l.drop.y-height-4,l.queue.y+l.queue.h+4}else {l.drop.y-height-4,l.drop.y+l.dropSize+4,l.queue.y+l.queue.h+4}
    for _,y in ipairs(candidates)do
     local r={x=x,y=y,w=width,h=height};local free=y>=l.shell.y+8 and y+height<=l.shell.y+l.shell.h-8
     for _,o in ipairs({l.queue,l.meter,l.menu,l.lounge,l.dpad,l.drop,l.bezel,l.walletVisual or l.wallet,l.quest,l.tray})do if overlaps(r,o)then free=false end end
     if free then caption=r;break end
    end
   end
   local seat=Stickers.layoutPrint(host,l,caption)
   assert(seat and seat.w>=16,string.format("no lower casing patch %s %s",tostring(size),word))
   assert(seat.x>=l.shell.x+9 and seat.x+seat.w<=l.shell.x+l.shell.w-9 and seat.y>=l.shell.y+9 and seat.y+seat.h<=l.shell.y+l.shell.h-9)
   for _,o in ipairs({l.queue,l.meter,l.walletVisual or l.wallet,l.quest,l.menu,l.lounge,l.dpad,l.bezel})do assert(not overlaps(seat,o),"print overlaps instrument/control "..word.." "..tostring(size))end
   if caption then assert(not overlaps(seat,caption))end
   assert(not overlaps(seat,l.drop)and seat.rotation==-15 and seat.visibleFraction>=.75,"tilted ink crosses A")
   settle();local nativeGlyph=host.StickerPixels.PrintedInk.StarGlyph
   table.insert(glyphMeasurements,{root=tostring(size),state=word,print=seat.printSize,grip=l.right.w,nativeBounds=tostring(nativeGlyph.TextBounds),rotation=host.Rotation,captionBelowA=caption~=nil and caption.y>=l.drop.y+l.dropSize+4,dense=l.dense==true})
   if l.roomy then
    assert(seat.printSize/l.right.w>=.60 and seat.printSize/l.right.w<=.78,"roomy print did not use grip width")
    settle();local glyph=host.StickerPixels.PrintedInk.StarGlyph
    assert(glyph.TextBounds.X+4>=l.right.w*.60,"roomy native star glyph too small for grip: "..tostring(glyph.TextBounds).." grip="..l.right.w)
   end
   assert(not host.Active and not host.Selectable and host.StickerPixels==pixels and host.Visible)
   assert(Stickers.layoutPrint(host,l,caption)==seat and host.StickerPixels==pixels,"unchanged print rebuilt")
   table.insert(cases,tostring(size).." "..word.." independent count/caption and fixed inputs")
  end
  -- Wallet shares the right rail in dense modes; an exact-value width change
  -- mutates the same solved layout and must revoke the cached seat.
  local before=Stickers.layoutPrint(host,l,nil)
  l.walletVisual={x=l.wallet.x,y=l.wallet.y,w=l.wallet.w+1,h=l.wallet.h}
  local after=Stickers.layoutPrint(host,l,nil)
  assert(after~=before,"mutated wallet width retained stale print cache")
  if after then assert(not overlaps(after,l.walletVisual))else assert(not host.Visible)end
  face:Destroy()
 end
 end)
 root:Destroy();assert(ok,err);return{passed=#cases,cases=cases,glyphMeasurements=glyphMeasurements,measurement="native TextBounds plus outline; actual ink visibility needs capture"}
end
