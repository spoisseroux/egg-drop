-- Odds disclosure text (PLAY-FOREVER BUILD-PLAN F1, architect change 6): always a
-- percentage. One value rounds to a whole percent ("33%"); a tiny non-zero chance reads
-- "<1%" so it never shows as 0%. `list` rounds a whole table of odds by largest
-- remainder so the shown percentages add up to exactly 100% (1/3 each: 34%, 33%, 33%).
local OddsText={}

local function valid(p)return type(p)=="number"and p==p and p>0 end

function OddsText.format(probability)
 if not valid(probability)then return "0%"end
 if probability>=1 then return "100%"end
 local percent=probability*100
 if percent<.5 then return "<1%"end
 return string.format("%d%%",math.clamp(math.floor(percent+.5),1,99))
end

-- probabilities: array of numbers (any positive scale; normalised here). Returns an
-- array of strings in the same order whose whole percentages sum to 100.
function OddsText.list(probabilities)
 local total,out=0,{}
 for _,p in ipairs(probabilities)do if valid(p)then total+=p end end
 if total<=0 then for i=1,#probabilities do out[i]="0%"end;return out end
 local whole,rest,used={}, {},0
 for i,p in ipairs(probabilities)do
  local exact=if valid(p)then p/total*100 else 0
  whole[i]=math.floor(exact);rest[i]=exact-whole[i];used+=whole[i]
 end
 local order={};for i=1,#probabilities do order[i]=i end
 -- Largest remainder first; ties keep the published order.
 table.sort(order,function(a,b)if math.abs(rest[a]-rest[b])>1e-9 then return rest[a]>rest[b]end;return a<b end)
 local left=100-used
 for _,i in ipairs(order)do if left<=0 then break end;if valid(probabilities[i])then whole[i]+=1;left-=1 end end
 -- With more than one possible outcome none reads 100% (a tiny other chance still exists).
 local count=0;for _,p in ipairs(probabilities)do if valid(p)then count+=1 end end
 for i,p in ipairs(probabilities)do
  local shown=if count>1 then math.min(whole[i],99)else whole[i]
  out[i]=if not valid(p)then "0%"elseif shown<1 then "<1%"else string.format("%d%%",shown)
 end
 return out
end

return table.freeze(OddsText)
