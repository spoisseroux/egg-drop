-- Original16px print motifs shared by Style, the shell and the worn SurfaceGui.
-- Runs are built only when the ID changes; resizing scales the same passive pixels.
local Art={}
local masks={
 star={"0000000100000000","0000001110000000","0000001110000000","0000011111000000","0111111111111100","0011111111111000","0001111111110000","0000111111100000","0001111111110000","0001111111110000","0011111011111000","0011100000111000","0111000000011100","0000000000000000","0000000000000000","0000000000000000"},
 glitch={"0000000000000000","0000001100001100","0011001100001100","0011111111000000","0001111111100000","0000011111111000","1111111111111110","1111111111111110","0000011111100000","0000011111101100","0000001111001100","0011001100000000","0011001100011000","0000000000011000","0000000000000000","0000000000000000"},
 seed={"0000000011100000","0000000111110000","0000001111100000","0000011111000000","0000001100000000","0000011110000000","0000111111000000","0001111111100000","0011111111110000","0011111111110000","0001111111100000","0001111111100000","0000111111000000","0000011110000000","0000001100000000","0000000000000000"},
 wick={"0000000110000000","0000001110000000","0000011111000000","0000011111100000","0000111111100000","0001111111110000","0001111111110000","0011111111111000","0011111111111000","0111111111111100","0111111111111100","0011111111111000","0011111111111000","0001111111110000","0000111111000000","0000000000000000"},
 club={"0000011111100000","0001111111111000","0011111111111100","0011111111111100","0011111111111100","0011111111111100","0011111111111100","0011111111111100","0001111111111000","0001111111111000","0000111111110000","0000011111100000","0000001111000000","0000000110000000","0000000000000000","0000000000000000"},
}
local palettes={star={"#493313","#DFA742","#FFE29A","#FFF4C8"},glitch={"#203A35","#4B9D8C","#A4D4C1","#ECF9D5"},seed={"#462824","#CE765E","#EAA48C","#FFE0AD"},wick={"#532C2B","#DC6E35","#F9AB63","#FFF0B0"},club={"#163D38","#3B9E8E","#81D6C4","#EAD58B"}}
masks.lantern={"0000001111000000","0000011001100000","0000010000100000","0000111111110000","0001111111111000","0000111111110000","0000111111110000","0000111111110000","0000111111110000","0000111111110000","0000111111110000","0000111111110000","0001111111111000","0001111111111000","0000011111100000","0000000000000000"}
palettes.lantern={"#563A28","#BC763C","#FFD47D","#FFF1BA"}
local function filled(mask,x,y)return y>=1 and y<=16 and x>=1 and x<=16 and mask[y]:sub(x,x)=="1"end
local function tone(id,mask,x,y)
 if not filled(mask,x,y)then return nil end
 if not filled(mask,x-1,y)or not filled(mask,x+1,y)or not filled(mask,x,y-1)or not filled(mask,x,y+1)then return 1 end
 if id=="lantern"and y>=6 and y<=11 and x>=7 and x<=10 then return 4 end
 if id=="seed"and y<=5 then return if x<9 then 3 else 2 end
 if id=="wick"and y>=8 and x>=6 and x<=9 then return 4 end
 if id=="club"and((x==7 or x==8)and y>=4 and y<=10 or y==6 and x>=5 and x<=10)then return 4 end
 return if x+y<13 then 4 elseif x-y<2 then 3 else 2
end
function Art.paint(host,id)
 local mask=masks[id];host.Active,host.Selectable=false,false
 if host:IsA("TextLabel")then host.Text=""end
 host.BackgroundTransparency=1;host.Visible=mask~=nil and host:GetAttribute("StickerPrintSpace")~=false
 if host:GetAttribute("StickerArtId")==id then return end
 host:SetAttribute("StickerArtId",id)
 local old=host:FindFirstChild("StickerPixels");if old then old:Destroy()end
 if not mask then return end
 local root=Instance.new("Frame");root.Name,root.Size,root.BackgroundTransparency="StickerPixels",UDim2.fromScale(1,1),1
 root.Active,root.Selectable,root.ZIndex=false,false,host.ZIndex;root.Parent=host
 local colors={};for i,hex in ipairs(palettes[id])do colors[i]=Color3.fromHex(hex)end
 for y=1,16 do local x=1
  while x<=16 do local color=tone(id,mask,x,y);local first=x;x+=1
   while x<=16 and tone(id,mask,x,y)==color do x+=1 end
   if color then local run=Instance.new("Frame");run.Name="PixelRun";run.BorderSizePixel=0;run.BackgroundColor3=colors[color]
    run.Position,run.Size=UDim2.fromScale((first-1)/16,(y-1)/16),UDim2.fromScale((x-first)/16,1/16)
    run.Active,run.Selectable,run.ZIndex=false,false,root.ZIndex;run.Parent=root
   end
  end
 end
end
-- Physical casing print: lower outer right, never across an instrument or caption.
-- The action button can occlude the print; it remains the independent input seat.
local function overlap(a,b)
 return a.x<b.x+b.w+4 and a.x+a.w>b.x-4 and a.y<b.y+b.h+4 and a.y+a.h>b.y-4
end
function Art.printSeat(l,caption)
 local shell=l.shell
 local left=math.max(shell.x+9,if l.lateral then l.bezel.x+l.bezel.w+3 else shell.x+shell.w*.55)
 local right,bottom=shell.x+shell.w-9,shell.y+shell.h-9
 local maximum=math.floor(math.min(124,(if l.lateral then l.right.w else shell.w*.3)*.8,right-left))
 local upper=math.max(shell.y+9,l.drop.y-maximum*.5)
 if not l.lateral then upper=math.max(upper,l.bezel.y+l.bezel.h+4)end
 if caption and caption.y+caption.h<=l.drop.y then upper=math.max(upper,caption.y+caption.h+4)end
 local obstacles={l.queue,l.meter,l.walletVisual or l.wallet,l.quest,l.menu,l.lounge,l.dpad}
 if caption then table.insert(obstacles,caption)end
 for size=maximum,16,-1 do
  local cx=l.right.x+l.right.w*.72
  local cy=l.drop.y+l.dropSize+size*.12
  local xs={math.clamp(cx-size/2,left,math.max(left,right-size)),right-size,left}
  local ys={math.clamp(cy-size/2,upper,math.max(upper,bottom-size)),bottom-size,upper}
  for _,r in ipairs(obstacles)do table.insert(xs,r.x+r.w+4);table.insert(xs,r.x-size-4);table.insert(ys,r.y+r.h+4);table.insert(ys,r.y-size-4)end
  local best,score
  for _,x in ipairs(xs)do for _,y in ipairs(ys)do
   if x>=left and x+size<=right and y>=upper and y+size<=bottom then
    local r={x=x,y=y,w=size,h=size};local free=true
    for _,o in ipairs(obstacles)do if overlap(r,o)then free=false;break end end
    if free then local distance=(x+size/2-cx)^2+(y+size/2-cy)^2;if not score or distance<score then best,score=r,distance end end
   end
  end end
  if best then return best end
 end
 return nil
end
local seatCache=setmetatable({},{__mode="k"})
function Art.layoutPrint(host,l,caption)
 local last=seatCache[host]
 local wallet=l.walletVisual or l.wallet
 local x,y,w,h=if caption then caption.x else -1,if caption then caption.y else -1,if caption then caption.w else -1,if caption then caption.h else -1
 if last and last.layout==l and last.x==x and last.y==y and last.w==w and last.h==h and last.wx==wallet.x and last.wy==wallet.y and last.ww==wallet.w and last.wh==wallet.h then return last.seat end
 local seat=Art.printSeat(l,caption);seatCache[host]={layout=l,x=x,y=y,w=w,h=h,wx=wallet.x,wy=wallet.y,ww=wallet.w,wh=wallet.h,seat=seat}
 host:SetAttribute("StickerPrintSpace",seat~=nil)
 if seat then
  host.Position=UDim2.fromOffset(seat.x-l.shell.x-5,seat.y-l.shell.y-4)
  host.Size=UDim2.fromOffset(seat.w,seat.h)
 end
 host.Visible=seat~=nil and masks[host:GetAttribute("StickerArtId")]~=nil
 return seat
end
return Art
