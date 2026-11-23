-- Coordinates are local to the CoreUISafeInsets focus root, in physical pixels.
local Row={}
-- v2 S3 / Stat Snacks: Stats and Snacks buttons. Spencer 2026-11-20: they sit at the bottom left,
-- stacked (Snacks at the bottom, Stats above it), out of the top row and clear of the snack tray,
-- which opens bottom centre. Given the root `height`; without it (or with no room) they hide.
Row.StatsWidth=112
Row.SnacksWidth=112
-- Beta 12 U2: the stat chip's pieces (StatsPanel.statChip), 22 tall: `6 | icon 14 | 4 | word | 5 | disc | 2`, or without
-- the word `6 | icon 14 | 5 | disc | 2`. wordW: the word's width (nil = none); digitsW: a two-digit level's width (nil =
-- one digit: the 18 pt disc), which makes the disc a pill with 5 pt sides. {w, iconX, wordX, discX, discW}.
Row.ChipDisc=18
function Row.chip(wordW,digitsW)
 local discW=math.max(Row.ChipDisc,math.ceil(digitsW or 0)+10)
 local x=6+14
 local out={iconX=6}
 if wordW then out.wordX=x+4;x+=4+math.ceil(wordW)+5 else x+=5 end
 out.discX=x;out.discW=discW
 out.w=x+discW+2
 return out
end
-- Pure: the pet tag card's width for its name and chip, `12 | name | 10 | chip | 10`, clamped; and the room left for
-- the name (which truncates first).
function Row.tagWidth(nameW,chipW,low,high)
 local width=math.clamp(12+math.ceil(nameW)+10+chipW+10,low or 120,high or 220)
 return width,width-12-10-chipW-10
end
-- range (beta 12 U2, the stat chip card): {min, max} card widths in place of 150 to 190; the card keeps its right edge.
function Row.layout(width,bondWidth,pickup,stats,snacks,height,range)
 local h,gap,edge=48,8,12
 local low,high=if range then range[1]else 150,if range then range[2]else 190
 local maximum=math.max(low,math.min(high,width-edge*2-h-gap-(if pickup then h+gap else 0)))
 local cardW=math.clamp(math.ceil(bondWidth or low),low,maximum)
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
