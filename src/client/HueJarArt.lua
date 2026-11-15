-- One rounded pigment fill in a compact clear jar. Passive native art.
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
 local fill=Art.frame(host,"PigmentFill",color,UDim2.fromScale(.20,.43),UDim2.fromScale(.60,.37),host.ZIndex+2);Art.corner(fill,10)
 local surface=blob(host,"FillSurface",.20,.37,.60,.15,color);surface.ZIndex=host.ZIndex+3
 local glow=blob(host,"PigmentHighlight",.28,.49,.045,.17,Color3.new(1,1,1),8);glow.BackgroundTransparency=.65;glow.ZIndex=host.ZIndex+4
 if id=="reset"then
  local seal=Art.text(fill,"ReturnSeal","↶",UDim2.fromScale(.15,.05),UDim2.fromScale(.7,.8),Color3.fromHex("#373DA0"),28,Art.Font.Action);seal.TextScaled=true
 end
 for i,y in ipairs({.16,.23})do local rim=blob(host,"Rim"..i,.13,y,.74,.08,Color3.fromHex("#E9FFFF"));Art.stroke(rim,ink,.1,1)end
 local lid=Art.frame(host,"PaleLid",Color3.fromHex("#E9FFFF"),UDim2.fromScale(.12,.13),UDim2.fromScale(.76,.10),host.ZIndex+4);Art.corner(lid,7)
 local shoulder=blob(host,"ShoulderReflection",.20,.31,.08,.25,Color3.new(1,1,1),12);shoulder.BackgroundTransparency=.10;shoulder.ZIndex=host.ZIndex+5
 return host
end
return Jar
