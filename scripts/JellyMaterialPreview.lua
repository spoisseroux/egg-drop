-- Studio CLIENT preview only. No renderer/catalog/save/Lighting mutation.
-- require(fixture).new(clientModuleFolder, PlayerGui, {size=Vector2.new(1280,720)})
-- :waitReady(15), :preset(1..6), :set({daylight=0,angle=35,alpha=.15}), :report(), :destroy().
local Run=game:GetService("RunService")
local Storage=game:GetService("ReplicatedStorage")
local Lighting=game:GetService("Lighting")
local Preview={Version=3}
local columns={{id="standard",label="Standard"},{id="gloss",label="Gloss"},{id="metal",label="Metal (legacy)"},{id="jelly",label="Jelly · candidate"}}
local body={Body=true,Head=true,EarL=true,EarR=true,Tail=true,HandL=true,HandR=true,FootL=true,FootR=true}
local secondary={Muzzle=true,EarInnerL=true,EarInnerR=true}
Preview.Presets={
 {name="day-front",daylight=1,angle=0,expression="neutral",time=.8},
 {name="day-three-quarter",daylight=1,angle=35,expression="neutral",time=.8},
 {name="night-three-quarter",daylight=0,angle=35,expression="neutral",time=.8},
 {name="day-blink",daylight=1,angle=0,expression="neutral",time=.075},
 {name="day-joy",daylight=1,angle=35,expression="joy",time=.8},
 {name="day-back-occlusion-check",daylight=1,angle=160,expression="neutral",time=.8},
}
local function node(class,parent,properties)
 local object=Instance.new(class);for key,value in pairs(properties)do object[key]=value end;object.Parent=parent;return object
end
local function label(parent,name,text,position,size,color)
 return node("TextLabel",parent,{Name=name,Text=text,Position=position,Size=size,BackgroundTransparency=1,TextColor3=color or Color3.fromRGB(239,242,235),Font=Enum.Font.BuilderSans,TextSize=13,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Active=false})
end
local function attributes(item)
 local rows={};for key,value in pairs(item:GetAttributes())do table.insert(rows,key.."="..tostring(value))end;table.sort(rows);return table.concat(rows,";")
end
local function sourceSnapshot(sources)
 local rows={}
 for _,source in ipairs(sources)do
  for _,item in ipairs(source:GetDescendants())do
   if item:IsA("MeshPart")then table.insert(rows,item:GetFullName().."|"..item.MeshId.."|"..item.TextureID.."|"..tostring(item.Size).."|"..tostring(item.CFrame))
   elseif item:IsA("SurfaceAppearance")then
    table.insert(rows,item:GetFullName().."|"..tostring(item.ColorMap).."|"..tostring(item.RoughnessMap).."|"..tostring(item.MetalnessMap).."|"..tostring(item.AlphaMode).."|"..tostring(item.Color).."|"..tostring(item.EmissiveStrength).."|"..attributes(item))
   end
  end
 end
 table.sort(rows);return table.concat(rows,"\n")
end
local function appearance(palette,finish,nativeJelly)
 return{body=if palette=="roseTide"then "rose"else "original",bodyRank=if palette=="roseTide"then 3 else 0,
  secondary=if palette=="roseTide"then "tide"else "default",finish=if finish=="jelly"and not nativeJelly then "gloss"else finish,
  charmVisible=true,charmShape="dot",wearables={Neck="bellcollar"},toyId="none",featureStages={horns=0,claws=0,wings=0}}
end
local function packClone(source,parent)
 local clone=source:Clone();clone.Name=source.Name.."_IsolatedPreview";clone.Parent=parent;return clone
end
local function vector(v)return{x=v.X,y=v.Y,z=v.Z}end
function Preview.new(client,parent,options)
 assert(Run:IsStudio()and Run:IsClient(),"JellyMaterialPreview must execute in Studio Client")
 assert(typeof(parent)=="Instance","Explicit disposable GUI parent required")
 options=options or {}
 assert(not options.useRendererOpacity or options.nativeJellyProfile,"Renderer opacity proof requires native Jelly profile")
 local activeColumns=columns
 if options.columns then
  assert(#options.columns==4,"Four comparison columns required")
  activeColumns={};local seen={};local labels={standard="Standard",gloss="Gloss",matte="Matte",metal="Metal (legacy)",jelly="Jelly · candidate"}
  for _,id in ipairs(options.columns)do assert(labels[id]and not seen[id],"Unknown/duplicate comparison finish");seen[id]=true;table.insert(activeColumns,{id=id,label=labels[id]})end
 end
 local Factory=require(client.PetFactory);local Materials=require(client.PetMaterials);local Config=require(client.PetMaterialConfig)
 local Readiness=require(client.PetAssetReadiness)
 local source=assert(Storage:FindFirstChild("PetMaterials"),"Native material pack missing")
 local twoSource=assert(Storage:FindFirstChild("PetMaterialsTwoTone"),"Native two-tone pack missing")
 local assets=assert(Storage:FindFirstChild("PetAssets"),"PetAssets missing")
 local bear=assert(assets:FindFirstChild("Bear"),"Real Bear mesh template missing")
 local sources={source,twoSource,bear}
 local baseline=sourceSnapshot(sources)
 local gui=node("ScreenGui",parent,{Name="_JellyMaterialPreview",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=190,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local root=node("Frame",gui,{Name="Fixture",BackgroundColor3=Color3.fromRGB(20,29,30),BorderSizePixel=0,ClipsDescendants=true})
 local scratch=node("Folder",gui,{Name="DisposableMaterialCopies"})
 local pack,twoPack=packClone(source,scratch),packClone(twoSource,scratch)
 local owner=Materials.new({templates=pack,twoToneTemplates=twoPack})
 local jellyPack,jellyTwoPack=packClone(source,scratch),packClone(twoSource,scratch)
 jellyPack.Name="JellyOnlyTemplates";jellyTwoPack.Name="JellyOnlyTwoToneTemplates"
 if options.nativeJellyProfile then
  assert(type(Materials.transparency)=="function"and Config.FinishProfiles.jelly=="BodyJelly","Load current Jelly renderer sources first")
  for _,pair in ipairs({{jellyPack,"BodyGloss","BodyJelly"},{jellyTwoPack,"BodyTwoToneGloss","BodyTwoToneJelly"}})do
   if not Materials.template(pair[1],pair[3])then
    local template=assert(Materials.template(pair[1],pair[2])):Clone()
    template.Name=pair[3];template:SetAttribute("MaterialProfile",pair[3]);template:SetAttribute("NativeVerified",false);template.Parent=pair[1]
   end
  end
 end
 local jellyOwner=Materials.new({templates=jellyPack,twoToneTemplates=jellyTwoPack})
 local readiness=Readiness.new({limit=2,timeout=12})
 local api={gui=gui,root=root,cells={},state={daylight=1,angle=0,expression="neutral",time=.8,alpha=.15,headAlpha=.08,earAlpha=.12,secondaryAlpha=.08,candidateMaps=options.allowUnverified==true},size=options.size or Vector2.new(1280,720),destroyed=false,sourceBaseline=baseline}
 local title=label(root,"Title","JELLY · NATIVE BEAR MATERIAL STUDY",UDim2.fromOffset(12,6),UDim2.new(1,-24,0,22))
 title.Font=Enum.Font.BuilderSansBold;title.TextSize=16
 api.caption=label(root,"Caption","",UDim2.fromOffset(12,29),UDim2.new(1,-24,0,30),Color3.fromRGB(189,206,200))
 label(root,"Limitations","Local viewport lighting · roughness proof in report · world shadows NOT proven",UDim2.new(0,12,1,-24),UDim2.new(1,-24,0,20),Color3.fromRGB(244,204,131))
 local palettes=if options.palette and options.palette~="both"then {options.palette}else {"original","roseTide"}
 for _,p in ipairs(palettes)do assert(p=="original"or p=="roseTide","Unknown palette")end
 api.palettes=palettes
 for row,palette in ipairs(palettes)do for col,column in ipairs(activeColumns)do
  local cellRoot=node("Frame",root,{Name=palette.."_"..column.id,BackgroundColor3=Color3.fromRGB(36,48,48),BorderSizePixel=0,ClipsDescendants=true})
  local header=label(cellRoot,"Finish",column.label,UDim2.fromOffset(6,1),UDim2.new(1,-12,0,18))
  local paletteLabel=label(cellRoot,"Palette",if palette=="original"then "Original · current neutral"else "Rose body / Tide secondary",UDim2.fromOffset(6,19),UDim2.new(1,-12,0,16),Color3.fromRGB(175,199,192));paletteLabel.TextSize=11
  local viewport=node("ViewportFrame",cellRoot,{Name="NativeViewport",Position=UDim2.fromOffset(2,37),Size=UDim2.new(1,-4,1,-39),BackgroundColor3=Color3.fromRGB(64,67,63),BorderSizePixel=0,LightDirection=Vector3.new(-.35,-1,-.6),ImageColor3=Color3.new(1,1,1)})
  local skySource=Lighting:FindFirstChildOfClass("Sky")
  local sky=if skySource then skySource:Clone()else Instance.new("Sky");sky.Name="LocalReflectionCubemap";sky.Parent=viewport
  local world=node("WorldModel",viewport,{Name="IsolatedBearWorld"})
  local camera=node("Camera",viewport,{Name="FixedComparisonCamera",FieldOfView=26});viewport.CurrentCamera=camera
  -- Actual geometry behind the model reveals alpha; it is not a screen-space overlay.
  for stripe=0,17 do
   node("Part",world,{Name="Stripe"..stripe,Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,
    Size=Vector3.new(.24,3.5,.03),CFrame=CFrame.new(-2.04+stripe*.24,1.2,-.85),Material=Enum.Material.SmoothPlastic,
    Color=if stripe%2==0 then Color3.fromRGB(30,39,43)else Color3.fromRGB(240,229,207)})
  end
  node("Part",world,{Name="ContactPlane",Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,Size=Vector3.new(6,.04,5),CFrame=CFrame.new(0,-.04,0),Color=Color3.fromRGB(83,93,83),Material=Enum.Material.SmoothPlastic})
  local visual=Factory.new(world,Vector3.zero,{id="pip",name="Bear"},.72,appearance(palette,column.id,options.nativeJellyProfile==true),{readiness=readiness,priority=3,twoTone=options.twoTone})
  visual.worldContext=options.worldContext==true;visual.allowUnverifiedFinish=options.allowUnverified==true;visual.cosmeticSeed=0;visual.poseCadence=0;visual.emissionEnabled=true
  local cell={root=cellRoot,viewport=viewport,camera=camera,visual=visual,column=column.id,palette=palette,row=row,col=col,header=header}
  table.insert(api.cells,cell)
 end end
 function api:resize(size)
  assert(typeof(size)=="Vector2"and size.X>=640 and size.Y>=300,"Use at least640x300 physical pixels")
  self.size=size;root.Size=UDim2.fromOffset(size.X,size.Y)
  local gap=6;local w=(size.X-24-gap*3)/4;local h=(size.Y-92-gap*(#palettes-1))/#palettes
  -- A common fixed body envelope, not per-finish normalization. Same camera for all columns/rows.
  local aspect=(w-4)/(h-39)
  local target=Vector3.new(0,.82,0)
  local distance=math.max(1.10,1.05/aspect)/math.tan(math.rad(13))*1.10
  local cf=CFrame.lookAt(target+Vector3.new(0,.10,distance),target)
  for _,cell in ipairs(self.cells)do
   cell.root.Position=UDim2.fromOffset(12+(cell.col-1)*(w+gap),64+(cell.row-1)*(h+gap));cell.root.Size=UDim2.fromOffset(w,h);cell.camera.CFrame=cf
  end
 end
 function api:useRoughness(id)
  assert(type(id)=="string"and id:match("^rbxassetid://[1-9]%d*$"),"Explicit uploaded roughness asset URI required")
  -- Texture edits are restricted to disposable Jelly clones and these two profiles.
  -- If Studio security denies this property, fail explicitly; never fake map proof.
  local changed=0
  for _,localPack in ipairs({jellyPack,jellyTwoPack})do
   for _,template in ipairs(localPack:GetChildren())do
    if template:IsA("SurfaceAppearance")and(template.Name==(if options.nativeJellyProfile then "BodyJelly"else "BodyGloss")or template.Name==(if options.nativeJellyProfile then "BodyTwoToneJelly"else "BodyTwoToneGloss"))then
     local before={color=template.ColorMap,metal=template.MetalnessMap,normal=template.NormalMap,alpha=template.AlphaMode}
     local ok,why=pcall(function()template.RoughnessMap=id end)
     assert(ok,"Studio must assign the uploaded RoughnessMap to disposable Jelly templates: "..tostring(why))
     assert(template.ColorMap==before.color and template.MetalnessMap==before.metal and template.NormalMap==before.normal and template.AlphaMode==before.alpha,"Non-roughness map changed")
     changed+=1
    end
   end
  end
  assert(changed>=2,"Jelly Gloss/two-tone Gloss candidate templates missing")
  if self.roughnessTicket then self.roughnessTicket:cancel()end
  self.roughnessId=id;self.roughnessReady=false
  self.roughnessTicket=require(client.UIAssetWarmup).shared:request({id},function(ok,reason)
   if not self.destroyed then self.roughnessReady=ok;self.roughnessReason=reason end
  end,3)
  return self:set({})
 end
 function api:assertSourcesUnchanged()
  assert(sourceSnapshot(sources)==baseline,"Source mesh/material pack mutated during preview")
  return true
 end
 function api:set(values)
  assert(not self.destroyed,"Preview destroyed")
  for key,value in pairs(values or {})do self.state[key]=value end
  local state=self.state
  assert(state.daylight==0 or state.daylight==1,"Use discrete day1/night0")
  assert(type(state.alpha)=="number"and state.alpha>=0 and state.alpha<=.35,"Invalid probe alpha")
  assert(type(state.headAlpha)=="number"and state.headAlpha>=0 and state.headAlpha<=.35,"Invalid head alpha")
  assert(type(state.earAlpha)=="number"and state.earAlpha>=0 and state.earAlpha<=.35,"Invalid ear/tail alpha")
  assert(type(state.secondaryAlpha)=="number"and state.secondaryAlpha>=0 and state.secondaryAlpha<=.35,"Invalid secondary alpha")
  assert(type(state.angle)=="number"and math.abs(state.angle)<=360,"Invalid yaw")
  if options.useRendererOpacity then assert(state.alpha==Config.JellyAlphaByPart.Body and state.headAlpha==Config.JellyAlphaByPart.Head and state.earAlpha==Config.JellyAlphaByPart.EarL and state.secondaryAlpha==Config.JellyAlphaByPart.Muzzle,"Renderer opacity uses actual Config constants, not manual overrides")end
  self.caption.Text=(if state.candidateMaps then "UNVERIFIED CANDIDATE MAPS · "else "PRODUCTION CAPABILITIES · ")..(if state.daylight==1 then "DAY"else "NIGHT").."  · yaw"..state.angle.."° · "..state.expression.." · Jelly body"..math.floor(state.alpha*100+.5).."% / head"..math.floor(state.headAlpha*100+.5).."% / ears-tail"..math.floor(state.earAlpha*100+.5).."% / secondary"..math.floor(state.secondaryAlpha*100+.5).."% · roughness"..(if self.roughnessId then ".25 candidate"else ".14 PROXY")
  readiness:step()
  for _,cell in ipairs(self.cells)do
   local visual=cell.visual
   visual.allowUnverifiedFinish=state.candidateMaps==true
   visual.yaw=math.rad(state.angle);visual.expression=state.expression;visual.time=state.time;visual.cosmeticTime=state.time;visual.poseDirty=true
   visual:update(0)
   cell.viewport.Ambient=if state.daylight==1 then Color3.fromRGB(142,148,143)else Color3.fromRGB(38,45,60)
   cell.viewport.LightColor=if state.daylight==1 then Color3.fromRGB(238,235,220)else Color3.fromRGB(97,113,154)
   -- Reuse actual Materials tint/profile/emission logic with local explicit daylight.
   for _,entry in ipairs(visual.pieces)do
    if cell.column=="jelly"and self.roughnessId and entry.materialSurface
     and(entry.materialProfile=="BodyGloss"or entry.materialProfile=="BodyTwoToneGloss"or entry.materialProfile=="BodyJelly"or entry.materialProfile=="BodyTwoToneJelly")and entry.materialSurface.RoughnessMap~=self.roughnessId then
     entry.materialSurface:Destroy();entry.materialSurface=nil;entry.materialProfile=nil
    end
    (if cell.column=="jelly"then jellyOwner else owner):paint(entry,visual,state.daylight)
    local alpha=0
    if cell.column=="jelly"and not entry.role then alpha=if entry.name=="Head"then state.headAlpha elseif entry.name=="EarL"or entry.name=="EarR"or entry.name=="Tail"then state.earAlpha elseif body[entry.name]then state.alpha elseif secondary[entry.name]then state.secondaryAlpha else 0 end
    local base=entry.baseTransparency or 0
    local final=if options.useRendererOpacity then Materials.transparency(entry,visual,entry.renderHidden)elseif entry.renderHidden then 1 else 1-(1-base)*(1-alpha)
    entry.part.Transparency=final;entry.lastTransparency=final
   end
  end
  self:assertSourcesUnchanged()
  return self:report()
 end
 function api:preset(index)
  local preset=assert(Preview.Presets[index],"Unknown capture preset")
  return self:set(preset)
 end
 function api:report()
  local report={version=Preview.Version,nativeReady=true,size={x=self.size.X,y=self.size.Y},state=table.clone(self.state),rows={},sourceUnchanged=self:assertSourcesUnchanged(),roughnessProxy=if self.roughnessId then nil else 36/255,roughnessAsset=self.roughnessId,roughnessReady=self.roughnessReady,roughnessFailure=self.roughnessReason,finalRoughnessTarget=64/255,worldShadowProof=false,localLighting=true,productionChanges=false,allowUnverified=self.state.candidateMaps==true,productionReady=true,profileMode=if options.nativeJellyProfile then "BodyJelly"else "GlossAlias",opacityOwner=if options.useRendererOpacity then "PetMaterials.transparency"else "fixture-manual"}
  for _,cell in ipairs(self.cells)do
   local visual=cell.visual
   local row={palette=cell.palette,finish=cell.column,backend=visual.backend,scale=visual.scale,worldScale=visual.worldScale,twoTone=visual.twoTone,worldContext=visual.worldContext,faces=0,visibleFacesOpaque=true,bodyTransparencies={},wearables=0,visibleWearablesOpaque=true,charms=0,visibleCharmsOpaque=true,profiles={},sourceMeshes={},bounds={min={x=1e9,y=1e9,z=1e9},max={x=-1e9,y=-1e9,z=-1e9}},frustumFits=true}
   local selectedProfile=Config.FinishProfiles[if cell.column=="jelly"and not options.nativeJellyProfile then "gloss"else cell.column]
   local expected=if visual.twoTone then Config.TwoToneProfiles[selectedProfile]else selectedProfile
   row.expectedBodyProfile=expected;row.actualBodyProfile=nil
   for _,entry in ipairs(visual.pieces)do
    local part=entry.part
    if entry.name=="Body"then
     row.actualBodyProfile=entry.materialProfile
     row.bodyProfileVerified=entry.materialSurface~=nil and(entry.materialProfile=="BodyTwoTone"or entry.materialSurface:GetAttribute("NativeVerified")==true)
     row.bodyMaps=if entry.materialSurface then {color=entry.materialSurface.ColorMap,roughness=entry.materialSurface.RoughnessMap,metalness=entry.materialSurface.MetalnessMap,alphaMode=tostring(entry.materialSurface.AlphaMode)}else nil
    end
    if entry.materialProfile then row.profiles[entry.materialProfile]=true end
    if part:IsA("MeshPart")then row.sourceMeshes[entry.name]=part.MeshId end
    if entry.role=="attachment"then row.wearables+=1;if not entry.renderHidden and part.Transparency>0 then row.visibleWearablesOpaque=false end
    elseif entry.role=="charm"then if not entry.renderHidden then row.charms+=1;if part.Transparency>0 then row.visibleCharmsOpaque=false end end
    elseif not body[entry.name]and not secondary[entry.name]then row.faces+=1;if not entry.renderHidden and part.Transparency>0 then row.visibleFacesOpaque=false end
    else row.bodyTransparencies[entry.name]=part.Transparency end
    if part.Transparency<1 then
     for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
      local p=part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5)
      for _,key in ipairs({"x","y","z"})do local n=if key=="x"then p.X elseif key=="y"then p.Y else p.Z;row.bounds.min[key]=math.min(row.bounds.min[key],n);row.bounds.max[key]=math.max(row.bounds.max[key],n)end
      local eye=cell.camera.CFrame:PointToObjectSpace(p);local depth=-eye.Z
      local tangent=math.tan(math.rad(cell.camera.FieldOfView*.5));local a=math.max(.01,cell.viewport.AbsoluteSize.X)/math.max(.01,cell.viewport.AbsoluteSize.Y)
      if depth<=0 or math.abs(eye.X)>depth*tangent*a*.96 or math.abs(eye.Y)>depth*tangent*.96 then row.frustumFits=false end
     end end end
    end
   end
   row.ready=visual.backend=="AuthoredMesh"and row.actualBodyProfile==expected and row.wearables>0 and row.charms>0 and row.visibleFacesOpaque and row.visibleWearablesOpaque and row.visibleCharmsOpaque
   report.nativeReady=report.nativeReady and row.ready and(not self.roughnessId or self.roughnessReady==true)
   report.productionReady=report.productionReady and row.ready and row.bodyProfileVerified==true and cell.column~="jelly"
   table.insert(report.rows,row)
  end
  return report
 end
 function api:waitReady(timeout)
  local deadline=os.clock()+math.clamp(timeout or 15,0,20)
  repeat
   self:set({});local report=self:report()
   if report.nativeReady then return report end
   Run.Heartbeat:Wait()
  until os.clock()>=deadline or self.destroyed
  return self:report()
 end
 function api:destroy()
  if self.destroyed then return end
  self:assertSourcesUnchanged();self.destroyed=true
  if self.roughnessTicket then self.roughnessTicket:cancel();self.roughnessTicket=nil end
  for _,cell in ipairs(self.cells)do cell.visual:destroy()end
  gui:Destroy()
 end
 gui.Destroying:Connect(function()if not api.destroyed then api:destroy()end end)
 api:resize(api.size);api:set({})
 if options.roughnessId then api:useRoughness(options.roughnessId)end
 return api
end
return Preview
