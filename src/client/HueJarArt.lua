-- Jar art for every place a jar shows (Customize cards, odds rows, receipts, the reveal).
-- Slice 3 (2026-11-16): the approved 3D paint-pot family (JarModel) in a ViewportFrame for hue
-- jars, finish jars and the charm capsule; the flat pigment jar below is the fallback while the
-- meshes are not in the place. Passive native art, no input.
local Art=require(script.Parent.DeckArt)
local JarModel=require(script.Parent.JarModel)
local Jar={}
local pigments={rose="#FF327A",tide="#008DFF",citrus="#FFCC00",iris="#9350FF",reset="#C8F3ED",gloss="#58DDC2",matte="#7FD8C6",jelly="#58DDC2",charm="#B79BFF"}
local function blob(parent,name,x,y,w,h,color,rotation)
 local n=Art.frame(parent,name,color,UDim2.fromScale(x,y),UDim2.fromScale(w,h),parent.ZIndex+1)
 Art.corner(n,100);n.Rotation=rotation or 0;return n
end
function Jar.create(parent,id,position,size,z)
 local host=Art.frame(parent,"Jar_"..id,Color3.new(1,1,1),position,size,z or parent.ZIndex+1)
 host.BackgroundTransparency=1;host.Active,host.Selectable=false,false;host:SetAttribute("ItemId",id)
 if JarModel.viewport(host,id)then host:SetAttribute("JarArt","model");return host end
 host:SetAttribute("JarArt","flat")
 if string.sub(tostring(id),1,6)=="charm_"then id="charm"end
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
-- The jar on a Customize card (CustomizeCards): drawn inside the card's swatch, once per item.
function Jar.card(button,id)
 local parts=button:FindFirstChild("CardParts");local swatch=parts and parts:FindFirstChild("Swatch")
 if not swatch then return nil end
 local existing=swatch:FindFirstChild("CardJar")
 if existing and existing:GetAttribute("ItemId")==id then return existing end
 if existing then existing:Destroy()end
 local host=Jar.create(swatch,id,UDim2.fromScale(-.05,-.05),UDim2.fromScale(1.1,1.1),swatch.ZIndex+1)
 host.Name="CardJar"
 for _,child in ipairs(swatch:GetChildren())do if child.Name:match("^Icon_")then child.Visible=false end end
 return host
end
-- A small jar in a card's bottom-right corner (hue cards keep the pet preview in the swatch).
function Jar.badge(button,id)
 local existing=button:FindFirstChild("JarBadge")
 if existing and existing:GetAttribute("ItemId")==id then existing.Visible=true;return existing end -- dress hides card children each pass
 if existing then existing:Destroy()end
 local side=math.clamp(math.floor(button.Size.Y.Offset*.42),22,36)
 local host=Jar.create(button,id,UDim2.new(1,-side-6,1,-side-4),UDim2.fromOffset(side,side),button.ZIndex+3)
 host.Name="JarBadge";return host
end
-- A charm shape on its own in a ViewportFrame (Book Charms page, Customize charm cards).
function Jar.charmView(parent,shape,position,size,z)
 local Shape=require(script.Parent.CharmShapeModel)
 local model=Shape.build(shape,Color3.fromHex("#FFCB3D"));if not model then return nil end
 local frame=Instance.new("ViewportFrame");frame.Name="CharmShapeView";frame.BackgroundTransparency=1;frame.Position=position;frame.Size=size
 frame.Active=false;frame.Selectable=false;frame.ZIndex=z or parent.ZIndex+1;frame:SetAttribute("CharmShape",shape)
 frame.Ambient=Color3.fromRGB(170,170,180);frame.LightDirection=Vector3.new(-.4,-1,-.6)
 local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=frame;frame.CurrentCamera=camera
 Shape.fit(model,CFrame.identity,1);model.Parent=frame
 camera.CFrame=CFrame.lookAt(Vector3.new(0,.15,2.6),Vector3.zero)
 frame.Parent=parent
 return frame
end
-- The charm shape itself on a Customize charm card (inside the card's swatch). A locked shape
-- shows faded under its lock.
function Jar.charmCard(button,shape,locked)
 local parts=button:FindFirstChild("CardParts");local swatch=parts and parts:FindFirstChild("Swatch")
 if not swatch then return nil end
 local frame=swatch:FindFirstChild("CharmShapeView")
 if not frame or frame:GetAttribute("CharmShape")~=shape then
  if frame then frame:Destroy()end
  frame=Jar.charmView(swatch,shape,UDim2.new(),UDim2.fromScale(1,1),swatch.ZIndex+1)
  if not frame then return nil end
 end
 frame.ImageTransparency=if locked then .55 else 0
 for _,child in ipairs(swatch:GetChildren())do if child.Name:match("^Icon_")then child.Visible=locked==true;child.ZIndex=frame.ZIndex+1 end end
 return frame
end
return Jar
