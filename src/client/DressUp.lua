-- Paint, Shine, Dress (PAINT-SHINE-DRESS-PLAN): the one "Dress up" door. Its switch, its words and its tabs.
-- With the Alive `paint` switch off every function here answers "today": no override, today's tab list.
--   DressUp.on()            the switch (Alive paint: beta and Studio only); `DressUp.forced` is a spec seam
--   DressUp.install(UICopy)  the PaintCopy override into UICopy.get (once, from init.client)
--   DressUp.tabs()           Colour (hue), Shine (finish), Outfit (outfit: opens the Wardrobe), Charm (charm)
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Alive=require(Shared:WaitForChild("Alive"))
local PaintCopy=require(Shared:WaitForChild("PaintCopy"))
local UICopy=require(Shared:WaitForChild("UICopy"))
local DressUp={Feature="paint",forced=nil}
function DressUp.on()
	if DressUp.forced~=nil then return DressUp.forced==true end
	local ok,on=pcall(Alive.on,DressUp.Feature)
	return ok and on==true
end
function DressUp.install(copy)PaintCopy.install(copy or UICopy,DressUp.on)end
-- The Dress up tab row (same shape as HueEggView.tabList's rows).
function DressUp.tabs()
	return {
		{id="hue",label=UICopy.get("paint.tab.colour"),icon="drop"},
		{id="finish",label=UICopy.get("paint.tab.shine"),icon="sphere"},
		{id="outfit",label=UICopy.get("paint.tab.outfit"),icon="shirt"},
		{id="charm",label=UICopy.get("paint.tab.charm"),icon="sparkle"},
	}
end
function DressUp.changed()return Alive.changed(DressUp.Feature)end
return DressUp
