-- Coordinates are local to the CoreUISafeInsets focus root, in physical pixels.
local Row={}
-- v2 S3 `stats`: a 112 px Stats button left of the card, when the row has room for it
-- beside Back (otherwise row.stats is nil and the button hides).
Row.StatsWidth=112
function Row.layout(width,bondWidth,pickup,stats)
 local height,gap,edge=48,8,12
 local maximum=math.max(150,math.min(190,width-edge*2-height-gap-(if pickup then height+gap else 0)))
 local cardW=math.clamp(math.ceil(bondWidth or 150),150,maximum)
 local right=width-edge
 local pickupX=right-height
 local cardRight=if pickup then pickupX-gap else right
 local cardX=cardRight-cardW
 local statsRect
 if stats and cardX-gap-Row.StatsWidth>=edge+height+gap then statsRect={x=cardX-gap-Row.StatsWidth,y=edge,w=Row.StatsWidth,h=height}end
 return{height=height,back={x=edge,y=edge,w=height,h=height},
  pickup={x=pickupX,y=edge,w=height,h=height},
  bond={x=cardX,y=edge,w=cardW,h=height},stats=statsRect,gap=gap}
end
return Row
