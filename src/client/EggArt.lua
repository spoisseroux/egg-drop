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
-- One connected ovoid fallback, drawn as adjacent registered strips rather than
-- overlapping pills. Used while owned image content loads or when an ID is empty.
local motifs={
 companion={{.39,.39,.12,.16,"3355DA",-24},{.63,.51,.12,.16,"3355DA",18},{.45,.72,.12,.16,"3355DA",-16},{.37,.62,.29,.035,"A8C922",-7}},
 hue={{.445,.46,.11,.14,"FF327A",-20},{.575,.44,.11,.14,"008DFF",-20},{.465,.59,.11,.14,"FFCC00",-20},{.605,.57,.11,.14,"9350FF",-20}},
 material={{.495,.475,.39,.09,"21B6AD",-25},{.57,.53,.24,.08,"527BDC",25}},
 toy={{.36,.35,.12,.06,"205D74",-45},{.47,.29,.15,.055,"205D74",0},{.61,.36,.14,.06,"205D74",45},{.62,.60,.14,.14,"F16F65",0}},
 feature={{.32,.35,.06,.18,"59315F",-30},{.65,.35,.06,.18,"59315F",30},{.47,.65,.055,.13,"88D7BD",-25},{.52,.65,.055,.13,"88D7BD",25}},
}
local function shellWidth(y)
 local t=math.clamp((y-.07)/.82,0,1)
 return .67*math.sin(math.pi*t)^.52*(.80+.30*t)
end
local function ellipse(shape,x)
 local angle=math.rad(shape[6]or 0);local c,s=math.cos(angle),math.sin(angle)
 local a,b=shape[3]/2,shape[4]/2;local dx=x-shape[1]
 local A=s*s/(a*a)+c*c/(b*b);local B=2*dx*c*s*(1/(a*a)-1/(b*b));local C=dx*dx*(c*c/(a*a)+s*s/(b*b))-1
 local d=B*B-4*A*C;if d<=0 then return nil end
 return shape[2]+(-B-math.sqrt(d))/(2*A),shape[2]+(-B+math.sqrt(d))/(2*A)
end
local function fallback(parent,kind,section)
 local host=Art.frame(parent,"FallbackOvoid",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),parent.ZIndex)
 host.BackgroundTransparency=1;host:SetAttribute("NativeSection",section or "whole")
 local tint=if kind=="hue"then Color3.fromHex("#56D4DD")elseif kind=="material"or kind=="feature"then Color3.fromHex("#DCD0EF")elseif kind=="toy"then Color3.fromHex("#F4CE79")else Color3.fromHex("#FFF3B9")
 -- Complementary vertical strips share the same ovoid and twelve-tooth seam.
 -- Only columns inside the silhouette allocate a GuiObject; no cloned clip trees.
 for column=0,47 do
  local x=(column+.5)/48;local extent=math.abs(x-.5)*2;local top,bottom
  for row=0,95 do local y=.07+(row+.5)*.82/96
   if shellWidth(y)>=extent then top=top or (.07+row*.82/96);bottom=.07+(row+1)*.82/96 end
  end
  if top then
   local phase=(x*12)%1;local seam=.5+(1-math.abs(phase*2-1))*14/384-7/384
   if section=="upper"then bottom=math.min(bottom,seam)elseif section=="lower"then top=math.max(top,seam)end
   if bottom>top then
    local strip=Art.frame(host,"ShellColumn"..column,tint,UDim2.fromScale(column/48,top),UDim2.fromScale(1/48+.0001,bottom-top),host.ZIndex+1)
    local light,dark=tint:Lerp(Color3.new(1,1,1),.16),tint:Lerp(Color3.fromHex("#8A8090"),.14)
    local gradient=Instance.new("UIGradient");gradient.Rotation=90
    gradient.Color=ColorSequence.new(light:Lerp(dark,math.clamp((top-.07)/.82,0,1)),light:Lerp(dark,math.clamp((bottom-.07)/.82,0,1)));gradient.Parent=strip
    for index,motif in ipairs(motifs[kind])do
     local a,b=ellipse(motif,x)
     if a then a,b=math.max(a,top),math.min(b,bottom);if b>a then
      Art.frame(host,"Pattern"..index.."Column"..column,Color3.fromHex(motif[5]),UDim2.fromScale(column/48,a),UDim2.fromScale(1/48+.0001,b-a),host.ZIndex+2)
     end end
    end
    local a,b=ellipse({.345,.30,.028,.14,"FFFFFF",25},x)
    if a then a,b=math.max(a,top),math.min(b,bottom);if b>a then Art.frame(host,"ShellGlint"..column,Color3.new(1,1,1),UDim2.fromScale(column/48,a),UDim2.fromScale(1/48+.0001,b-a),host.ZIndex+3)end end
   end
  end
 end
 return host
end
function Egg.create(parent, recipeId, position, size, z, name, section)
 local host=Art.frame(parent,name or "Egg",Art.Ink,position,size,z or parent.ZIndex+1)
 host.BackgroundTransparency,host.Active,host.Selectable=1,false,false
 host:SetAttribute("RecipeId",recipeId)
 local kind=if recipeId=="hue"or recipeId=="material"or recipeId=="toy"or recipeId=="feature"then recipeId else "companion"
 section=section or "whole";host:SetAttribute("ShellSection",section)
 host:SetAttribute("EggAssetKind",kind)
 local square=Art.frame(host,"RegisteredShell",Art.Ink,UDim2.fromScale(.5,.5),UDim2.fromScale(1,1),host.ZIndex+1)
 square.AnchorPoint=Vector2.new(.5,.5);square.BackgroundTransparency=1
 local aspect=Instance.new("UIAspectRatioConstraint");aspect.AspectRatio=1;aspect.DominantAxis=Enum.DominantAxis.Width;aspect.AspectType=Enum.AspectType.FitWithinMaxSize;aspect.Parent=square
 if section=="whole"then local shadow=shape(square,"GroundShadow",.26,.925,.48,.035,Art.Ink);shadow.BackgroundTransparency=.73 end
 local backup=fallback(square,kind,section)

 local shell=Instance.new("ImageLabel");shell.Name="ShellImage";shell.BackgroundTransparency=1;shell.Size=UDim2.fromScale(1,1)
 shell.Image=Assets.Atlas or Assets[kind]or ""
 if Assets.Atlas then shell.ImageRectOffset=Vector2.new(Assets.Columns[kind]*Assets.Pixels,Assets.Sections[section]*Assets.Pixels);shell.ImageRectSize=Vector2.one*Assets.Pixels end
 shell.ScaleType=Enum.ScaleType.Fit;shell.Active,shell.Selectable=false,false;shell.ZIndex=square.ZIndex+5;shell.Parent=square
 local function loaded()if backup and backup.Parent then backup.Visible=shell.Image==""or not shell.IsLoaded end end
 shell:GetPropertyChangedSignal("IsLoaded"):Connect(loaded);loaded()
 return host
end

function Egg.createPiece(parent,recipeId,section,position,size,z,name)return Egg.create(parent,recipeId,position,size,z,name,section)end

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
