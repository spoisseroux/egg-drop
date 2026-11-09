-- Original, asset-free field-guide illustrations. Pure decoration: no input,
-- uploaded images, particles, runtime animation or inventory state.
local Art = require(script.Parent.DeckArt)
local Egg = {}

local function shape(parent, name, x, y, width, height, color, rotation)
	local node = Art.frame(parent, name, color, UDim2.fromScale(x, y), UDim2.fromScale(width, height), parent.ZIndex + 1)
	node.Rotation = rotation or 0
	Art.corner(node, 1000)
	return node
end

function Egg.create(parent, recipeId, position, size, z, name)
	local host = Art.frame(parent, name or "Egg", Art.Ink, position, size, z or parent.ZIndex + 1)
	host.BackgroundTransparency, host.Active, host.Selectable = 1, false, false
	host:SetAttribute("RecipeId", recipeId)
	local sprout = recipeId == "sprout"
	local cream = Color3.fromHex("#FFF0C8")
	local tint = if sprout then Color3.fromHex("#E1EDAD") else cream
	local shadow = shape(host, "GroundShadow", .14, .87, .72, .10, Art.Ink)
	shadow.BackgroundTransparency = .65
	local shell = Art.frame(host, "Shell", tint, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), host.ZIndex + 2)
	shell.BackgroundTransparency = 1
	shape(shell, "LowerShell", .17, .26, .66, .65, tint)
	shape(shell, "Crown", .25, .08, .50, .65, tint)
	local motif = Art.frame(host, "Pattern", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), host.ZIndex + 4)
	motif.BackgroundTransparency = 1
	if sprout then
		shape(motif, "SproutStem", .47, .42, .07, .26, Art.Canopy)
		shape(motif, "LeafLeft", .28, .40, .23, .13, Art.Canopy, 32)
		shape(motif, "LeafRight", .50, .30, .23, .14, Art.Canopy, -34)
		shape(motif, "SeedDot", .44, .73, .12, .09, Art.Leaf)
	else
		shape(motif, "MeadowSpot", .28, .38, .15, .12, Art.Leaf:Lerp(Art.Canopy, .25), -25)
		shape(motif, "MeadowSpot", .55, .57, .16, .12, Art.Canopy, 22)
		shape(motif, "MeadowSpot", .35, .73, .14, .11, Art.Leaf:Lerp(Art.Canopy, .25), -18)
	end
	local glint = shape(host, "ShellGlint", .31, .23, .09, .15, Color3.new(1, 1, 1), 24)
	glint.ZIndex, glint.BackgroundTransparency = host.ZIndex + 7, .18
	return host
end

-- Legacy API/node name remains for existing wallet layout owners.
function Egg.nectar(parent,position,size,z)
 local host=Art.frame(parent,"NectarDrop",Art.Ink,position,size,z or parent.ZIndex+1)
 host.BackgroundTransparency,host.Active,host.Selectable=1,false,false
 host:SetAttribute("CurrencySymbol","Stars")
 local glyph=Instance.new("TextLabel");glyph.Name="GoldStar";glyph.BackgroundTransparency=1;glyph.BorderSizePixel=0
 glyph.Size=UDim2.fromScale(1,1);glyph.Text="★";glyph.Font=Enum.Font.SourceSans;glyph.TextColor3=Color3.fromHex("#FFD069")
 glyph:SetAttribute("AccessibleLabel","Star")
 glyph.TextSize=18;glyph.Active,glyph.Selectable=false,false;glyph.ZIndex=host.ZIndex+1;glyph.Parent=host
 local glint=shape(host,"StarGlint",.37,.34,.12,.08,Color3.fromHex("#FFF6DA"),-20)
 glint.ZIndex=host.ZIndex+2
 local function fit()
  local size=host.AbsoluteSize
  glyph.TextSize=math.max(1,math.min(100,math.floor(math.min(size.X/.72,size.Y)*.88)))
 end
 host:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit);fit()
 return host
end
Egg.stars=Egg.nectar

return Egg
