-- Working v8 guards. Historical validators deliberately do not call this module.
local Guard={}
local kinds={"hue","material","toy","feature"}
function Guard.other(state,own)
 if state.lastHatch and own~="companion"then return true end
 for _,kind in ipairs(kinds)do
  if kind~=own then
   local cap=kind:sub(1,1):upper()..kind:sub(2)
   if state[kind.."Reservation"]or state["pending"..cap.."Result"]then return true end
  end
 end
 return false
end
function Guard.valid(state)
 local count=if state.lastHatch then 1 else 0
 for _,kind in ipairs(kinds)do
  local cap=kind:sub(1,1):upper()..kind:sub(2)
  if state[kind.."Reservation"]then count+=1 end
  if state["pending"..cap.."Result"]then count+=1 end
 end
 return count<=1
end
return Guard
