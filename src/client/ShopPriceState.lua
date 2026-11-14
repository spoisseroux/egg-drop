local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Price={}
function Price.shortfall(cost,balance)
 return math.max(0,(tonumber(cost)or 0)-(tonumber(balance)or 0))
end
function Price.need(cost,balance)
 local missing=Price.shortfall(cost,balance)
 return if missing>0 then Copy.get(if missing==1 then "qa.shortfallOne"else "qa.shortfall",{count=missing})else ""
end
return Price
