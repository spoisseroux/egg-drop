-- Run explicitly in Studio Edit mode after the first Rojo asset sync/reconnect.
-- The source model retains asset references; some Rojo reification paths cannot
-- assign immutable MeshPart resources. This tool repairs those existing parts.
-- No runtime scripts require this file and no mesh upload is performed.
local manifest=game:GetService("HttpService"):JSONDecode([=[[{"model":"Zivvi","name":"Zivvi__Body","mesh":"rbxassetid://101744911812859","size":[0.8975480198860168,0.7699999809265137,0.7490717172622681]},{"model":"Zivvi","name":"Zivvi__CharmDot","mesh":"rbxassetid://110307091587010","size":[0.2954423129558563,0.2999999523162842,0.2909539043903351]},{"model":"Zivvi","name":"Zivvi__FootL","mesh":"rbxassetid://132619926689641","size":[0.48359110951423645,0.25999999046325684,0.4870062470436096]},{"model":"Zivvi","name":"Zivvi__FootR","mesh":"rbxassetid://130872625091974","size":[0.48359110951423645,0.25999999046325684,0.4870062470436096]},{"model":"Zivvi","name":"Zivvi__HandL","mesh":"rbxassetid://99533724168974","size":[0.24673016369342804,0.26999998092651367,0.23376299440860748]},{"model":"Zivvi","name":"Zivvi__HandR","mesh":"rbxassetid://77393504339291","size":[0.24673016369342804,0.26999998092651367,0.23376299440860748]},{"model":"Zivvi","name":"Zivvi__Cheeks","mesh":"rbxassetid://124546489202664","size":[1.284000039100647,0.10999995470046997,0.12005305290222168]},{"model":"Zivvi","name":"Zivvi__EyeL","mesh":"rbxassetid://87089896433313","size":[0.1679999977350235,0.19530004262924194,0.11012250185012817]},{"model":"Zivvi","name":"Zivvi__EyeR","mesh":"rbxassetid://78534872131515","size":[0.1679999977350235,0.19530004262924194,0.11012250185012817]},{"model":"Zivvi","name":"Zivvi__GlintL","mesh":"rbxassetid://138728932402251","size":[0.041999995708465576,0.03915679454803467,0.029163658618927002]},{"model":"Zivvi","name":"Zivvi__GlintR","mesh":"rbxassetid://115058347829717","size":[0.041999995708465576,0.03915679454803467,0.025582045316696167]},{"model":"Zivvi","name":"Zivvi__Head","mesh":"rbxassetid://72493624428113","size":[1.6346789598464966,0.9389916062355042,0.9231194257736206]},{"model":"Zivvi","name":"Zivvi__Mouth","mesh":"rbxassetid://87760086069523","size":[0.7879999876022339,0.22840553522109985,0.13872411847114563]},{"model":"Zivvi","name":"Zivvi__Teeth","mesh":"rbxassetid://79606368127779","size":[0.6339460015296936,0.12401032447814941,0.048030585050582886]},{"model":"Zivvi","name":"Zivvi__CuffTrimL","mesh":"rbxassetid://113875857934512","size":[0.30529043078422546,0.3400000035762787,0.32974773645401]},{"model":"Zivvi","name":"Zivvi__CuffTrimR","mesh":"rbxassetid://131703383336296","size":[0.30529043078422546,0.3400000035762787,0.32974773645401]},{"model":"Ovelle","name":"Ovelle__Body","mesh":"rbxassetid://136931485133107","size":[0.6706952452659607,0.6799999475479126,0.57396399974823]},{"model":"Ovelle","name":"Ovelle__CharmDot","mesh":"rbxassetid://136501904883745","size":[0.2954423129558563,0.2999999523162842,0.29095393419265747]},{"model":"Ovelle","name":"Ovelle__CuffL","mesh":"rbxassetid://93761802109739","size":[0.608527421951294,0.45766374468803406,0.4020000100135803]},{"model":"Ovelle","name":"Ovelle__CuffR","mesh":"rbxassetid://133577426773720","size":[0.608527421951294,0.45766374468803406,0.4020000100135803]},{"model":"Ovelle","name":"Ovelle__FootL","mesh":"rbxassetid://79191599828881","size":[0.18258033692836761,0.18000000715255737,0.21428275108337402]},{"model":"Ovelle","name":"Ovelle__FootR","mesh":"rbxassetid://98207904192401","size":[0.18258032202720642,0.18000000715255737,0.21428275108337402]},{"model":"Ovelle","name":"Ovelle__HandL","mesh":"rbxassetid://75207025874170","size":[0.23192636668682098,0.2149999737739563,0.2045426219701767]},{"model":"Ovelle","name":"Ovelle__HandR","mesh":"rbxassetid://113813878429737","size":[0.23192636668682098,0.2149999737739563,0.2045426219701767]},{"model":"Ovelle","name":"Ovelle__Cheeks","mesh":"rbxassetid://91540540154468","size":[1.0700000524520874,0.11000001430511475,0.06342768669128418]},{"model":"Ovelle","name":"Ovelle__EyeL","mesh":"rbxassetid://74340840307496","size":[0.17399999499320984,0.22133994102478027,0.07549425959587097]},{"model":"Ovelle","name":"Ovelle__EyeR","mesh":"rbxassetid://77322688780626","size":[0.17399999499320984,0.22133994102478027,0.07549425959587097]},{"model":"Ovelle","name":"Ovelle__GlintL","mesh":"rbxassetid://94776935908864","size":[0.04350000619888306,0.044268012046813965,0.017687439918518066]},{"model":"Ovelle","name":"Ovelle__GlintR","mesh":"rbxassetid://118434971397639","size":[0.04350000619888306,0.044268012046813965,0.01632702350616455]},{"model":"Ovelle","name":"Ovelle__Head","mesh":"rbxassetid://118081868538500","size":[1.655747413635254,0.7630000114440918,0.8112310171127319]},{"model":"Ovelle","name":"Ovelle__Mouth","mesh":"rbxassetid://97664255468192","size":[0.21799999475479126,0.08702075481414795,0.011334031820297241]},{"model":"Ovelle","name":"Ovelle__CuffTrimL","mesh":"rbxassetid://85374189867055","size":[0.46673399209976196,0.30081549286842346,0.2275465428829193]},{"model":"Ovelle","name":"Ovelle__CuffTrimR","mesh":"rbxassetid://138582020914315","size":[0.4950927197933197,0.3172574043273926,0.2275465726852417]}]]=])
local function sameAsset(a,b)
 return type(a)=="string"and string.match(a,"%d+")==string.match(b,"%d+")
end
local function valid(part,expected)
 if not part or not part:IsA("MeshPart")or not sameAsset(part.MeshId,expected.mesh)then return false end
 local s=part.MeshSize;return s.X>0 and s.Y>0 and s.Z>0
end
return function(assets,options)
 assert(not game:GetService("RunService"):IsRunning(),"Pet asset repair is Edit-only")
 assets=assets or game:GetService("ReplicatedStorage"):FindFirstChild("PetAssets")
 assert(assets and assets:IsA("Folder"),"Trusted PetAssets folder missing")
 options=options or {};local limit=math.clamp(math.floor(options.limit or 8),1,#manifest)
 local result={expected=#manifest,valid=0,repaired=0,attempted=0,remaining=0,failures={},parts={}}
 local service=game:GetService("AssetService")
 for _,expected in ipairs(manifest)do
  local model=assets:FindFirstChild(expected.model)
  local part=model and model:FindFirstChild(expected.name)
  local before=valid(part,expected)
  if not before and not options.validateOnly and result.attempted<limit and part and part:IsA("MeshPart")then
   result.attempted+=1
   local temporary
   local ok,err=pcall(function()
    temporary=service:CreateMeshPartAsync(Content.fromUri(expected.mesh),{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Automatic})
    local frame,size=part.CFrame,part.Size
    part:ApplyMesh(temporary);part.CFrame=frame;part.Size=size
   end)
   if temporary then temporary:Destroy()end
   if not ok then table.insert(result.failures,{name=expected.name,error=tostring(err)})end
   if valid(part,expected)then result.repaired+=1 end
  end
  local nowValid=valid(part,expected)
  if nowValid then result.valid+=1 else result.remaining+=1 end
  table.insert(result.parts,{name=expected.name,valid=nowValid,mesh=if part and part:IsA("MeshPart")then part.MeshId else "missing"})
 end
 result.complete=result.valid==#manifest
 return result
end
