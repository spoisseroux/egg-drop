-- Original tiny fruit silhouettes inside a clear, short jar. Passive native art.
local Art=require(script.Parent.DeckArt)
local Jar={}
local pigments={rose="#FF327A",tide="#008DFF",citrus="#FFCC00",iris="#9350FF",reset="#C8F3ED"}
local function blob(parent,name,x,y,w,h,color,rotation)
 local n=Art.frame(parent,name,color,UDim2.fromScale(x,y),UDim2.fromScale(w,h),parent.ZIndex+1)
 Art.corner(n,100);n.Rotation=rotation or 0;return n
end
function Jar.create(parent,id,position,size,z)
 local host=Art.frame(parent,"Jar_"..id,Color3.new(1,1,1),position,size,z or parent.ZIndex+1)
 host.BackgroundTransparency=1;host.Active,host.Selectable=false,false;host:SetAttribute("ItemId",id)
 local ink=Color3.fromHex("#234D61");local color=Color3.fromHex(pigments[id]or pigments.reset)
 local glass=blob(host,"Glass",.13,.20,.74,.68,Color3.fromHex("#E7FFFF"));glass.BackgroundTransparency=.65
 Art.stroke(glass,ink,.08,1)
 local fruit=Art.frame(host,"Fruit",color,UDim2.fromScale(.18,.24),UDim2.fromScale(.64,.58),host.ZIndex+2);fruit.BackgroundTransparency=1
 if id=="rose"then
  blob(fruit,"BerryL",.05,.25,.55,.65,color,-12);blob(fruit,"BerryR",.43,.16,.53,.66,color,12)
  blob(fruit,"CutLeaf",.34,.02,.51,.21,Color3.fromHex("#2E963E"),-24)
 elseif id=="tide"then
  blob(fruit,"DropTip",.32,.04,.37,.65,color,-26);blob(fruit,"DropBase",.13,.32,.76,.60,color)
  blob(fruit,"Curl",.55,.01,.28,.08,ink,-35)
 elseif id=="citrus"then
  local wedge=blob(fruit,"GoldenWedge",.12,.20,.77,.62,color,-20);Art.corner(wedge,5)
  local face=blob(fruit,"Facet",.22,.29,.51,.34,Color3.fromHex("#FFE97C"),-20);Art.corner(face,3)
  blob(fruit,"Rind",.19,.73,.67,.09,Color3.fromHex("#BF7600"),-20)
 elseif id=="iris"then
  blob(fruit,"PlumL",.09,.19,.57,.70,color,-12);blob(fruit,"PlumR",.43,.16,.47,.67,Color3.fromHex("#7035CF"),12)
  blob(fruit,"SplitBloom",.48,.30,.05,.48,Color3.fromHex("#DFA6FF"),8);blob(fruit,"Leaf",.45,.02,.43,.18,Color3.fromHex("#338E50"),-24)
 else
  blob(fruit,"DewTop",.35,.02,.32,.67,color,-18);local pear=blob(fruit,"DewPear",.14,.32,.73,.60,color);pear.BackgroundTransparency=.3
  local seal=Art.text(fruit,"ReturnSeal","↶",UDim2.fromScale(.15,.17),UDim2.fromScale(.7,.65),Color3.fromHex("#373DA0"),28,Art.Font.Action);seal.TextScaled=true
 end
 for i,y in ipairs({.16,.23})do local rim=blob(host,"Rim"..i,.13,y,.74,.08,Color3.fromHex("#E9FFFF"));Art.stroke(rim,ink,.1,1)end
 local shoulder=blob(host,"ShoulderReflection",.20,.31,.08,.25,Color3.new(1,1,1),12);shoulder.BackgroundTransparency=.10;shoulder.ZIndex=host.ZIndex+5
 return host
end
return Jar
