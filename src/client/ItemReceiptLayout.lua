-- Shared bounded receipt composition for Hue, Material, Toy and Feature items.
local Art=require(script.Parent.DeckArt)
local Receipt={}
local function place(n,x,y,w,h)n.Position,n.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)end
function Receipt.layout(art,copy,width,availableHeight,short)
 Art.type(copy,"Body",short);copy.Visible=true
 local side=if short then math.min(110,math.max(1,(availableHeight or 118)-8),math.max(1,width*.38))else math.min(200,math.max(1,width-16))
 if short then
  local x=side+16;local textW=math.max(1,width-x-4);local textH=Art.textHeight(copy,textW,24)
  place(art,4,4,side,side);place(copy,x,4+math.max(0,(side-textH)/2),textW,textH);copy.TextXAlignment=Enum.TextXAlignment.Left
  return math.max(side,textH)+8
 end
 local textW=math.max(1,width-16);local textH=Art.textHeight(copy,textW,24)
 place(art,(width-side)/2,4,side,side);place(copy,8,side+12,textW,textH);copy.TextXAlignment=Enum.TextXAlignment.Center
 return side+textH+20
end
return Receipt
