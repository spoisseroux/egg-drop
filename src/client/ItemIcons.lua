-- Round item icons (QA 2026-11-13 Q1 item 9): Swap, Pop, Bomb and Magnet drawn in
-- the house icon style (UI-PERSONALITY T10: filled silhouettes, round ends, one
-- highlight). Used by the item carousel, the desktop belt chip, the phone item
-- button and the "+ Magnet" grant toast.
-- An uploaded PNG (assets/ui/items/<id>.png, scripts/build_item_icons.py) wins when
-- RoundItems.IconImages[id] holds its id; until then the vector icon below draws
-- with Frames only (every rect in scale units of a square holder, so it scales with
-- tweened sizes and never needs a re-layout).
local Shared=game:GetService("ReplicatedStorage").Shared
local Items=require(Shared.RoundItems)
local Icons={}
Icons.Light=Color3.fromHex("#F3F4F6")
Icons.Ink=Color3.fromHex("#0E0F12")
Icons.Spark=Color3.fromHex("#FFE27A")
Icons.Kinds={"swap","pop","bomb","magnet"}

local function blob(parent,name,cx,cy,w,h,color,rotation,z)
 local f=Instance.new("Frame")
 f.Name=name;f.BorderSizePixel=0;f.BackgroundColor3=color;f.BackgroundTransparency=0
 f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromScale(cx,cy);f.Size=UDim2.fromScale(w,h)
 f.Rotation=rotation or 0;f.ZIndex=parent.ZIndex+(z or 1);f.Active=false;f.Selectable=false
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(.5,0);c.Parent=f
 f.Parent=parent
 return f
end

local draw={}
-- Two arrows trading places: right on top, left below.
function draw.swap(h,color)
 for row=0,1 do
  local y=if row==0 then .35 else .65
  local dir=if row==0 then 1 else -1
  local tip=.5+dir*.31
  blob(h,"Shaft",.5-dir*.04,y,.58,.13,color)
  blob(h,"Head",tip-dir*.085,y-.085,.27,.13,color,dir*45,2)
  blob(h,"Head",tip-dir*.085,y+.085,.27,.13,color,-dir*45,2)
 end
 blob(h,"Shine",.3,.35,.1,.05,Icons.Light,0,3).BackgroundTransparency=.35
end
-- A burst: four crossing round bars (eight rays) and a bright core.
function draw.pop(h,color)
 for index=0,3 do
  local long=index%2==0
  blob(h,"Ray",.5,.5,.14,if long then .86 else .66,color,index*45)
 end
 local core=blob(h,"Core",.5,.5,.4,.4,color:Lerp(Icons.Light,.55),0,2)
 local ring=Instance.new("UIStroke");ring.Color=color;ring.Thickness=1.5;ring.Parent=core
 blob(h,"Shine",.43,.42,.1,.1,Icons.Light,0,3)
end
-- A round bomb with a cap, a fuse and a spark; one highlight.
function draw.bomb(h,color)
 blob(h,"Body",.45,.58,.66,.66,color)
 blob(h,"Cap",.66,.32,.2,.13,color:Lerp(Icons.Ink,.45),40,2)
 blob(h,"Fuse",.76,.2,.05,.17,color:Lerp(Icons.Ink,.6),40,2)
 for index=0,1 do blob(h,"Spark",.84,.12,.05,.22,Icons.Spark,index*90,3)end
 blob(h,"Spark",.84,.12,.04,.14,Icons.Spark,45,3);blob(h,"Spark",.84,.12,.04,.14,Icons.Spark,-45,3)
 blob(h,"Shine",.32,.46,.14,.1,Icons.Light,-30,3).BackgroundTransparency=.3
end
-- A horseshoe magnet: two legs with light tips and a round bend (seventeen overlapping
-- discs along the half circle, so no clipping or masking is needed).
function draw.magnet(h,color)
 local cx,cy,r,t=.5,.56,.2,.2
 for _,x in ipairs({cx-r,cx+r})do
  blob(h,"Leg",x,(.2+cy)/2,t,cy-.2,color)
  blob(h,"Tip",x,.21,t,.13,Icons.Light,0,2)
 end
 for index=0,16 do
  local a=math.pi*index/16
  blob(h,"Bend",cx+math.cos(a)*r,cy+math.sin(a)*r,t,t,color)
 end
 blob(h,"Shine",cx-r-.02,cy+.08,.06,.06,Icons.Light,0,3).BackgroundTransparency=.35
end
Icons.draw=draw

-- Pure: which source an icon uses ("image" with an uploaded id, else "vector").
function Icons.source(id)
 local images=Items.IconImages
 if images and type(images[id])=="string"and images[id]~=""then return "image"end
 return if draw[id]then "vector"else nil
end

-- A square holder (`size` px, or scale 1 when size is nil) showing item `id`.
function Icons.new(parent,size,id)
 local holder=Instance.new("Frame")
 holder.Name="ItemIcon";holder.BackgroundTransparency=1;holder.BorderSizePixel=0;holder.Active=false;holder.Selectable=false
 holder.AnchorPoint=Vector2.new(.5,.5);holder.Position=UDim2.fromScale(.5,.5)
 holder.Size=if size then UDim2.fromOffset(size,size)else UDim2.fromScale(1,1)
 holder.ZIndex=parent.ZIndex+1
 local aspect=Instance.new("UIAspectRatioConstraint");aspect.AspectRatio=1;aspect.Parent=holder
 holder.Parent=parent
 Icons.set(holder,id)
 return holder
end
-- Repaint (only when the id changes). nil clears the holder.
function Icons.set(holder,id)
 if holder:GetAttribute("ItemId")==id and holder:GetAttribute("Painted")then return false end
 for _,child in ipairs(holder:GetChildren())do if child:IsA("GuiObject")then child:Destroy()end end
 holder:SetAttribute("ItemId",id);holder:SetAttribute("Painted",true)
 local item=id and Items.ById[id]
 local source=item and Icons.source(id)
 holder:SetAttribute("IconSource",source)
 if not source then return true end
 if source=="image"then
  local image=Instance.new("ImageLabel")
  image.Name="Image";image.BackgroundTransparency=1;image.Image=Items.IconImages[id];image.Size=UDim2.fromScale(1,1)
  image.ZIndex=holder.ZIndex+1;image.Parent=holder
 else
  draw[id](holder,item.color)
 end
 return true
end

return Icons
