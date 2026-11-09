-- One display name for the existing authoritative wallet.
local Stars={}
function Stars.name(amount)return if tonumber(amount)==1 then "Star"else "Stars"end
function Stars.amount(amount)return tostring(amount).." "..Stars.name(amount)end
function Stars.format(pattern,...)
 local text=string.format(pattern,...)
 return (string.gsub(text,"(%d+) Stars",function(n)return n.." "..Stars.name(n)end))
end
return Stars
