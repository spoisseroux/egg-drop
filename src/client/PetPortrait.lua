local Art = require(script.Parent.DeckArt)

local GardenMaps=require(game:GetService("ReplicatedStorage").Shared.PetPortraitDefinitions)
local Definitions=require(game:GetService("ReplicatedStorage").Shared.PetRigDefinitions)
local Palette=require(game:GetService("ReplicatedStorage").Shared.PetPalette)
local Portrait = {}
local sprites = {
	pip = {
		".............", "....l...l....", "...lll.lll...", "....lllL.....", "....BBBBB....",
		"...BHHMMMB...", "..BHMMMMMMB..", "..BMFMMMFMB..", "..BMMMFMMMB..", "..BDMMMMMDB..",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	bloom_pip = {
		"......o......", ".....oOo.....", "...l..o..l...", "....lllLl....", "....BBBBB....",
		"...BHHMMMB...", "..BHMMMMMMB..", "..BMFMMMFMB..", "..BMMMFMMMB..", "..BDMMMMMDB..",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	puddle = {
		".............", ".........BB..", "........BHMB.", "........BDMB.", ".....BBBBMB..",
		"...BBHMMMMB..", "..BHMMMMMMMB.", ".BHMFMMMFMMB.", ".BMMMMFMMMMB.", ".BDMMMMMMMDB.",
		"..BBDDDDDBB..", "....BBBBB....", ".............",
	},
	wick = {
		".............", "......l......", ".....llL.....", "....lLlLL....", "....lLHHl....",
		"...BlllLLB...", "..BHHMMMMMB..", "..BHMMMMMMB..", "..BMFMMMFMB..", "..BDMMFMMDB..",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	foxfire_wick = {
		"...l.....l...", "...lL...Ll...", "...llL.Lll...", "....lHLHl....", "....lllll....",
		"...BLLLLLB...", "..BHHMMMMMB..", "..BHMMMMMMB..", "..BMFMMMFMB..", "..BDMMFMMDB..",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	orbit = {
		"..........H..", ".........HLH.", "....BBBBB.H..", "...BHHMMMB...", "..BHMMMMMMB..",
		"..BMFMMMFMB..", "..BMMMFMMMB..", ".LBMMMMMMMBl.", "LHBMMMMMDlL..", ".LlLllLlLB...",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	eclipse_orbit = {
		".........ll..", "........lBB..", "....BBBBBlB..", "...BHHMMMB...", "..BHMMMMMMB..",
		"..BMFMMMFMB..", "l.BMMMFMMMB.l", "llBMMMMMMMBlL", ".llMMMMMDlll.", "...lllllll...",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
}

sprites.pip=GardenMaps.zivvi;sprites.puddle=GardenMaps.ovelle

local cached=setmetatable({},{__mode="k"})
local function colorsFor(pet,locked,appearance)
	local color = if locked then Art.Line else pet.color
	local accent = if locked then Art.Muted elseif pet.id == "pip" then Color3.fromHex("#A9E34B")
		elseif pet.accent then pet.accent elseif pet.id == "wick" then Art.Amber else Art.Cyan
	local colors = {
		B = Art.Ink, F = Art.Ink, M = color, H = color:Lerp(Art.Silver, 0.7),
		D = color:Lerp(Art.Ink, 0.38), L = accent:Lerp(Art.Ink, 0.25), l = accent,
		o = color, O = if locked then Art.Line else Art.Amber,
	}
 local definition=Definitions[pet.id]
 if not definition and not locked then
  local resolved=Palette.resolve(pet.id,appearance)
  if resolved then color=resolved.body;accent=resolved.secondary;colors.M=color;colors.H=color:Lerp(Art.Silver,.45);colors.D=color:Lerp(Art.Ink,.38);colors.l=accent;colors.L=accent:Lerp(Art.Ink,.25)end
 end
 if definition then
  local p=definition.palette;local resolved=Palette.resolve(pet.id,appearance);local secondary=resolved.secondary
  if not locked then color=resolved.body end
  colors.M=color;colors.H=color:Lerp(Art.Silver,.45);colors.D=if locked then Art.Muted else Color3.fromHex(p.blush)
  colors.F=if locked then Art.Ink else Color3.fromHex(p.face);colors.I=if locked then Art.Line else Color3.fromHex(p.ivory)
  colors.S=if locked then Art.Muted else secondary;colors.L=colors.S:Lerp(Art.Ink,.25)
 end
 return colors,color,definition
end
function Portrait.apply(sprite,appearance)
 local entry=cached[sprite];if not entry then return false end
 local colors,body,definition=colorsFor(entry.pet,entry.locked,appearance)
 for _,slot in ipairs(entry.slots)do local color=colors[slot.symbol];if slot.node.BackgroundColor3~=color then slot.node.BackgroundColor3=color end end
 sprite:SetAttribute("BodyColor",body);if definition then sprite:SetAttribute("SecondaryColor",colors.S)end
 return true
end
function Portrait.create(parent,pet,unit,position,z,locked,appearance)
 local colors,color,definition=colorsFor(pet,locked,appearance)
 local sprite=Art.pixels(parent,"Portrait",sprites[pet.id],colors,unit,position,z)
 sprite.AnchorPoint=Vector2.new(.5,.5)
 local slots={};local nodes=sprite:GetChildren();local index=0
 for _,row in ipairs(sprites[pet.id])do
  local x=1
  while x<=#row do
   local symbol=string.sub(row,x,x);local stop=x+1
   while string.sub(row,stop,stop)==symbol do stop+=1 end
   if colors[symbol]then index+=1;table.insert(slots,{node=nodes[index],symbol=symbol})end
   x=stop
  end
 end
 cached[sprite]={pet=pet,locked=locked,slots=slots}
 sprite.Destroying:Connect(function()cached[sprite]=nil end)
 Portrait.apply(sprite,appearance)
 return sprite
end
return Portrait
