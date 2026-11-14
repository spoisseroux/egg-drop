-- Coordinates are local to the CoreUISafeInsets focus root, in physical pixels.
local Row={}
function Row.layout(width,bondWidth,pickup)
 local height,gap,edge=48,8,12
 local maximum=math.max(150,math.min(190,width-edge*2-height-gap-(if pickup then height+gap else 0)))
 local cardW=math.clamp(math.ceil(bondWidth or 150),150,maximum)
 local right=width-edge
 local pickupX=right-height
 local cardRight=if pickup then pickupX-gap else right
 return{height=height,back={x=edge,y=edge,w=height,h=height},
  pickup={x=pickupX,y=edge,w=height,h=height},
  bond={x=cardRight-cardW,y=edge,w=cardW,h=height},gap=gap}
end
return Row
