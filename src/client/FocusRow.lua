-- Coordinates are local to the CoreUISafeInsets focus root, in physical pixels.
local Row={}
-- v2 S3 / Stat Snacks: Stats and Snacks buttons. Spencer 2026-11-20: they sit at the bottom left,
-- stacked (Snacks at the bottom, Stats above it), out of the top row and clear of the snack tray,
-- which opens bottom centre. Given the root `height`; without it (or with no room) they hide.
Row.StatsWidth=112
Row.SnacksWidth=112
function Row.layout(width,bondWidth,pickup,stats,snacks,height)
 local h,gap,edge=48,8,12
 local maximum=math.max(150,math.min(190,width-edge*2-h-gap-(if pickup then h+gap else 0)))
 local cardW=math.clamp(math.ceil(bondWidth or 150),150,maximum)
 local right=width-edge
 local pickupX=right-h
 local cardRight=if pickup then pickupX-gap else right
 local cardX=cardRight-cardW
 local statsRect,snacksRect
 if type(height)=="number"then
  -- Below the Back key's row, with room for both stacked.
  local bottom=height-edge
  local top=edge+h+gap
  local y=bottom-h
  if snacks and y>=top then snacksRect={x=edge,y=y,w=Row.SnacksWidth,h=h};y-=h+gap end
  if stats and y>=top then statsRect={x=edge,y=y,w=Row.StatsWidth,h=h}end
 end
 return{height=h,back={x=edge,y=edge,w=h,h=h},
  pickup={x=pickupX,y=edge,w=h,h=h},
  bond={x=cardX,y=edge,w=cardW,h=h},stats=statsRect,snacks=snacksRect,gap=gap,
  leftColumn=if statsRect or snacksRect then edge+math.max(statsRect and statsRect.w or 0,snacksRect and snacksRect.w or 0)else 0}
end
return Row
