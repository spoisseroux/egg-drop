-- Shared original registered shell art. Passive shop/result/crack decoration.
local Art = require(script.Parent.DeckArt)
local Egg = {}

local function shape(parent, name, x, y, width, height, color, rotation)
	local node = Art.frame(parent, name, color, UDim2.fromScale(x, y), UDim2.fromScale(width, height), parent.ZIndex + 1)
	node.Rotation = rotation or 0
	Art.corner(node, 1000)
	return node
end

local Assets=require(script.Parent.EggArtAssets)
-- One connected ovoid fallback, drawn as adjacent horizontal strips rather than
-- overlapping pills. Used while owned image content loads or when an ID is empty.
local function fallback(parent,kind)
 local host=Art.frame(parent,"FallbackOvoid",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),parent.ZIndex)
 host.BackgroundTransparency=1
 local tint=if kind=="hue"then Color3.fromHex("#56D4DD")elseif kind=="material"then Color3.fromHex("#DCD0EF")else Color3.fromHex("#FFF3B9")
 for row=0,47 do
  local t=(row+.5)/48
  local width=.67*math.sin(math.pi*t)^.52*(.80+.30*t)
  local strip=Art.frame(host,"ShellRow"..row,tint,UDim2.fromScale((1-width)/2,.07+row*.82/48),UDim2.fromScale(width,.82/48+.001),host.ZIndex+1)
  strip.BackgroundColor3=tint:Lerp(Color3.fromHex("#8A8090"),t*.12)
 end
 if kind=="hue"then
  for i,data in ipairs({{.39,.39,"#FF327A"},{.52,.37,"#008DFF"},{.41,.52,"#FFCC00"},{.55,.50,"#9350FF"}})do shape(host,"FruitPetal"..i,data[1],data[2],.11,.14,Color3.fromHex(data[3]),-20)end
 elseif kind=="material"then
  shape(host,"FoldedRibbon",.30,.43,.39,.09,Color3.fromHex("#21B6AD"),-25)
  shape(host,"RibbonFold",.45,.49,.24,.08,Color3.fromHex("#527BDC"),25)
 else
  for i,data in ipairs({{.33,.31,-24},{.57,.43,18},{.39,.64,-16}})do shape(host,"CobaltRainSeed"..i,data[1],data[2],.12,.16,Color3.fromHex("#3355DA"),data[3])end
  shape(host,"CitronSprout",.23,.60,.29,.035,Color3.fromHex("#A8C922"),-7)
 end
 shape(host,"ShellGlint",.32,.23,.035,.14,Color3.new(1,1,1),25)
 return host
end
function Egg.create(parent, recipeId, position, size, z, name)
 local host=Art.frame(parent,name or "Egg",Art.Ink,position,size,z or parent.ZIndex+1)
 host.BackgroundTransparency,host.Active,host.Selectable=1,false,false
 host:SetAttribute("RecipeId",recipeId)
 local kind=if recipeId=="hue"then "hue"elseif recipeId=="material"then "material"else "companion"
 host:SetAttribute("EggAssetKind",kind)
 local square=Art.frame(host,"RegisteredShell",Art.Ink,UDim2.fromScale(.5,.5),UDim2.fromScale(1,1),host.ZIndex+1)
 square.AnchorPoint=Vector2.new(.5,.5);square.BackgroundTransparency=1
 local aspect=Instance.new("UIAspectRatioConstraint");aspect.AspectRatio=1;aspect.DominantAxis=Enum.DominantAxis.Width;aspect.AspectType=Enum.AspectType.FitWithinMaxSize;aspect.Parent=square
 local shadow=shape(square,"GroundShadow",.26,.925,.48,.035,Art.Ink);shadow.BackgroundTransparency=.73
 local backup=fallback(square,kind)
 local shell=Instance.new("ImageLabel");shell.Name="ShellImage";shell.BackgroundTransparency=1;shell.Size=UDim2.fromScale(1,1)
 shell.Image=Assets[kind]or "";shell.ScaleType=Enum.ScaleType.Fit;shell.Active,shell.Selectable=false,false;shell.ZIndex=square.ZIndex+5;shell.Parent=square
 local function loaded()backup.Visible=shell.Image==""or not shell.IsLoaded end
 shell:GetPropertyChangedSignal("IsLoaded"):Connect(loaded);loaded()
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
