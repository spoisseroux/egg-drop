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
 local hue=recipeId=="hue"
 local cream=Color3.fromHex("#FFF3B9")
 local tint=if hue then Color3.fromHex("#56D4DD")else cream
 local shadow=shape(host,"GroundShadow",.14,.87,.72,.10,Art.Ink);shadow.BackgroundTransparency=.70
 local shell=Art.frame(host,"Shell",tint,UDim2.fromScale(0,0),UDim2.fromScale(1,1),host.ZIndex+2);shell.BackgroundTransparency=1
 local lower=shape(shell,"LowerShell",if hue then .23 else .14,.28,if hue then .57 else .72,.63,tint)
 local crown=shape(shell,"Crown",if hue then .30 else .23,.07,if hue then .43 else .52,.66,tint)
 Art.shade(lower,1,.72);Art.shade(crown,1,.89)
 Art.stroke(lower,if hue then Color3.fromHex("#137C9D")else Color3.fromHex("#C9AF54"),.28,1)
 local motif=Art.frame(host,"Pattern",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),host.ZIndex+4);motif.BackgroundTransparency=1
 if hue then
  for i,x in ipairs({.26,.39,.52,.65})do shape(motif,"ShoulderDrop"..i,x,.37,.09,.15,({Color3.fromHex("#FF327A"),Color3.fromHex("#008DFF"),Color3.fromHex("#FFCC00"),Color3.fromHex("#9350FF")})[i],-10)end
  for i=0,3 do shape(motif,"Scallop"..i,.25+i*.13,.28,.18,.12,Color3.fromHex("#C8FAEC"),-10)end
 else
  shape(motif,"CitronHalfBelt",.18,.65,.35,.07,Color3.fromHex("#A8C922"),-12)
  for i,data in ipairs({{.28,.36,-24},{.58,.49,18},{.36,.70,-16}})do shape(motif,"CobaltRainSeed"..i,data[1],data[2],.13,.17,Color3.fromHex("#3355DA"),data[3])end
 end
 local glint=shape(host,"ShellGlint",.31,.20,.10,.22,Color3.new(1,1,1),22);glint.ZIndex,glint.BackgroundTransparency=host.ZIndex+7,.14
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
 local edge=Instance.new("UIStroke");edge.Name="AmberEdge";edge.Color=Color3.fromHex("#A75C0A");edge.Thickness=1;edge.Transparency=0;edge.Parent=glyph
 glyph.TextSize=18;glyph.Active,glyph.Selectable=false,false;glyph.ZIndex=host.ZIndex+1;glyph.Parent=host
 local glint=shape(host,"StarGlint",.37,.34,.16,.065,Color3.fromHex("#FFF6DA"),-28)
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
