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

-- Material pool4 needs actual conditional fractions (18.1818%,81.8182%).
-- A separate API preserves all existing whole-percent disclosures.
function OddsText.preciseList(probabilities,places)
 places=places or 4
 assert(type(places)=="number"and places%1==0 and places>=1 and places<=6,"Invalid odds precision")
 local factor=10^places;local target=100*factor;local total=0
 for _,p in ipairs(probabilities)do if valid(p)and p<math.huge then total+=p end end
 local result={};if total<=0 then for i=1,#probabilities do result[i]="0%"end;return result end
 local units,remainder,order,used={},{},{},0
 for i,p in ipairs(probabilities)do
  local exact=if valid(p)and p<math.huge then p/total*target else 0
  units[i]=if exact>0 then math.max(1,math.floor(exact))else 0
  remainder[i]=exact-math.floor(exact);used+=units[i];table.insert(order,i)
 end
 table.sort(order,function(a,b)if math.abs(remainder[a]-remainder[b])>1e-9 then return remainder[a]>remainder[b]end;return a<b end)
 local left=target-used
 if left>=0 then
  for _,i in ipairs(order)do if left<=0 then break end;if units[i]>0 then units[i]+=1;left-=1 end end
 else
  table.sort(order,function(a,b)return units[a]>units[b]end)
  for _,i in ipairs(order)do if left>=0 then break end;local take=math.min(units[i]-1,-left);if take>0 then units[i]-=take;left+=take end end
 end
 for i,u in ipairs(units)do
  local number=string.format("%."..places.."f",u/factor):gsub("0+$",""):gsub("%.$","")
  result[i]=number.."%"
 end
 return result
end
return table.freeze(OddsText)
