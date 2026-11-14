-- Celebration kit (UI-SPEC-REDESIGN-CELEBRATIONS-2026-11-12, sections 1 and 2;
-- BUILD-PLAN architect change 2). Every piece here is drawn from frames, live
-- text and the existing DeckKit; no atlas sprites, so DeckAssets stays as it is.
--   C.display / C.setDisplay  Display font role (Builder Extended Bold, Builder
--                             Sans ExtraBold fallback)
--   C.headline                slanted tag + big line + underline (hatch stage)
--   C.banner                  centred big line with speed lines (results)
--   C.star                    2D Star token: glyph layers, gloss, rays, glow
--   C.sparkle                 four-point twinkle
--   C.rewardButton            gold "reward" Kit button with an egg mark
local TextService=game:GetService("TextService")
local Kit=require(script.Parent.DeckKit)
local Assets=require(script.Parent.DeckAssets)
local C={}

C.Gold=Color3.fromHex("#FFC14D");C.GoldDeep=Color3.fromHex("#A8620F");C.GoldLight=Color3.fromHex("#FFE39A")
C.Stage=Color3.fromHex("#06070B");C.Ink=Color3.fromHex("#0E0F12");C.White=Color3.new(1,1,1)
C.Confetti={Color3.fromHex("#FFC14D"),Color3.fromHex("#76F6B0"),Color3.fromHex("#FF8FB1"),Color3.fromHex("#8FD3FF"),Color3.fromHex("#FFFFFF")}

-- New sound cue names (sections 1.7 and 2.9). Placeholder sounds are wired in BoardAudio (placeholderIds); Spencer's audio replaces them.
C.Cues={"reveal_hush","spot_on","streak_whoosh","reveal_shimmer","tag_slam","name_slam","desc_tick","spin_whoosh",
 "shimmer_loop","reveal_out","goal_tick","row_flip","star_land","stars_total","new_best","egg_ready","meter_fill","win","lose"}

-- Display role. Builder Extended is checked once per session; when the family
-- cannot load, every registered label moves to Builder Sans ExtraBold.
C.DisplayFace=Font.new("rbxasset://fonts/families/BuilderExtended.json",Enum.FontWeight.Bold)
C.FallbackFace=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.ExtraBold)
C.displayAvailable=nil
local displayLabels=setmetatable({},{__mode="k"})
local probing=false
function C.displayFont()return if C.displayAvailable==false then C.FallbackFace else C.DisplayFace end
function C.useFallback()
 C.displayAvailable=false
 for label in pairs(displayLabels)do if label.Parent then label.FontFace=C.FallbackFace end end
end
local function probe()
 if probing or C.displayAvailable~=nil then return end;probing=true
 task.spawn(function()
  local ok,size=pcall(function()
   local params=Instance.new("GetTextBoundsParams")
   params.Text="WONDER";params.Font=C.DisplayFace;params.Size=40;params.Width=2000
   return TextService:GetTextBoundsAsync(params)
  end)
  if ok and typeof(size)=="Vector2"and size.X>0 then C.displayAvailable=true else C.useFallback()end
 end)
end
function C.setDisplay(label)
 displayLabels[label]=true;label.FontFace=C.displayFont();label:SetAttribute("KitRole","Display");probe()
 return label
end
-- Display text. Sizes below 12 are raised to 12 (the smallest text rule).
function C.display(parent,content,size,color,props)
 local label=Kit.node("TextLabel",parent,{Name=props and props.Name or "Display",BackgroundTransparency=1,Text=content or "",
  TextSize=math.max(12,math.floor(size+.5)),TextColor3=color or C.White,TextXAlignment=Enum.TextXAlignment.Left,
  TextYAlignment=Enum.TextYAlignment.Center,ZIndex=parent.ZIndex+1,Active=false,Size=UDim2.fromOffset(10,size+4)})
 C.setDisplay(label)
 if props then for key,value in pairs(props)do if key~="Name"then label[key]=value end end end
 return label
end
-- Width estimate for Display text before layout. Builder Extended runs about
-- 18% wider than Builder Sans ExtraBold; boxes take 26% so the text always fits.
function C.measure(content,size)
 local base=TextService:GetTextSize(content,math.max(1,size),Enum.Font.BuilderSansExtraBold,Vector2.new(10000,10000))
 local wide=if C.displayAvailable==false then 1.04 else 1.26
 return Vector2.new(math.ceil(base.X*wide),math.ceil(base.Y))
end

local function gradient(parent,rotation,keys)
 local points={}
 for _,k in ipairs(keys)do table.insert(points,NumberSequenceKeypoint.new(k[1],k[2]))end
 return Kit.node("UIGradient",parent,{Rotation=rotation,Transparency=NumberSequence.new(points)})
end
C.gradient=gradient

-- Sparkle: two crossing bars that fade toward their tips, and a bright core.
function C.sparkle(parent,size,color)
 local root=Kit.frame(parent,"Sparkle",nil,UDim2.new(),UDim2.fromOffset(size,size));root.AnchorPoint=Vector2.new(.5,.5)
 local thick=math.max(2,math.floor(size*.14))
 for index,dims in ipairs({{size,thick,0},{thick,size,90}})do
  local bar=Kit.frame(root,"Bar"..index,nil,UDim2.fromScale(.5,.5),UDim2.fromOffset(dims[1],dims[2]),999)
  bar.AnchorPoint=Vector2.new(.5,.5);bar.BackgroundTransparency=0;bar.BackgroundColor3=color or C.White
  gradient(bar,dims[3],{{0,1},{.5,0},{1,1}})
 end
 local core=Kit.frame(root,"Core",nil,UDim2.fromScale(.5,.5),UDim2.fromOffset(thick+2,thick+2),999)
 core.AnchorPoint=Vector2.new(.5,.5);core.BackgroundTransparency=0;core.BackgroundColor3=C.White
 return root
end
-- Fade every drawn part of a sparkle (0 = full, 1 = gone).
function C.fadeSparkle(root,transparency)
 for _,child in ipairs(root:GetChildren())do if child:IsA("Frame")then child.BackgroundTransparency=transparency end end
end

-- Speed lines: three bars, longest first, slanted like the headline.
local function speedLines(parent,side,height,color)
 local width=math.floor(height*2.1)
 local holder=Kit.frame(parent,"SpeedLines",nil,UDim2.new(),UDim2.fromOffset(width,height))
 local bars={}
 for index,share in ipairs({1,.78,.56})do
  local h=math.max(3,math.floor(height*.13))
  local bar=Kit.frame(holder,"Line"..index,nil,UDim2.new(),UDim2.fromOffset(math.floor(width*share),h),2)
  bar.BackgroundTransparency=0;bar.BackgroundColor3=color
  bar.AnchorPoint=Vector2.new(if side<0 then 1 else 0,.5)
  bar.Position=UDim2.new(if side<0 then 1 else 0,side*(index-1)*height*.12,0,height*(.28+(index-1)*.22))
  bars[index]=bar
 end
 return holder,bars
end

-- Centred banner headline (results 2.2/2.5): big line with an offset shadow and
-- three speed lines either side; the whole group is rotated.
function C.banner(parent,options)
 local size=options.size or 44
 local root=Kit.frame(parent,"Headline",nil,UDim2.new(),UDim2.fromOffset(10,10));root.AnchorPoint=Vector2.new(.5,.5)
 root.Rotation=options.rotation or -3
 local scale=Kit.node("UIScale",root,{Scale=1})
 local shadow=C.display(root,"",size,options.shadowColor or C.Gold,{Name="Shadow",TextXAlignment=Enum.TextXAlignment.Center})
 local main=C.display(root,"",size,C.White,{Name="Line",TextXAlignment=Enum.TextXAlignment.Center})
 main.ZIndex=shadow.ZIndex+1
 -- Translation (v1 track C fit pass): the box is sized to the English text, so a longer
 -- translation shrinks to fit (never above the design size) instead of clipping.
 if Kit.translating then
  for _,label in ipairs({main,shadow})do
   label.TextScaled=true;Kit.node("UITextSizeConstraint",label,{MaxTextSize=size,MinTextSize=math.min(size,12)})
  end
 end
 local lineH=math.floor(size*.9)
 local left,leftBars=speedLines(root,-1,lineH,options.lineColor or C.Gold)
 local right,rightBars=speedLines(root,1,lineH,options.lineColor or C.Gold)
 local api={root=root,scale=scale,label=main,shadow=shadow}
 function api.set(text,lineColor,shadowColor)
  main.Text,shadow.Text=text,text
  local w=C.measure(text,size).X+8;local h=size+8
  local lw=left.Size.X.Offset;local gap=math.floor(size*.3)
  root.Size=UDim2.fromOffset(w+2*(lw+gap),h)
  main.Position,main.Size=UDim2.fromOffset(lw+gap,0),UDim2.fromOffset(w,h)
  local drop=math.max(2,math.floor(size*.07))
  shadow.Position,shadow.Size=UDim2.fromOffset(lw+gap+drop,drop),UDim2.fromOffset(w,h)
  left.Position=UDim2.fromOffset(0,(h-lineH)/2+drop);right.Position=UDim2.fromOffset(lw+gap+w+gap,(h-lineH)/2-drop)
  for _,bar in ipairs(leftBars)do bar.BackgroundColor3=lineColor end
  for _,bar in ipairs(rightBars)do bar.BackgroundColor3=lineColor end
  shadow.TextColor3=shadowColor or lineColor
 end
 api.set(options.text or "",options.lineColor or C.Gold,options.shadowColor)
 return api
end

-- Slanted headline (hatch stage 1.2): an accent tag strip, the big white line
-- with an accent shadow, and an accent underline; rotated as one group.
-- The pivot is the group's top-left corner region: AnchorPoint (0,0) keeps the
-- left edge where the layout puts it.
function C.headline(parent,options)
 local tagSize,lineSize=options.tagSize or 26,options.lineSize or 80
 local root=Kit.frame(parent,"Headline",nil,UDim2.new(),UDim2.fromOffset(10,10))
 root.Rotation=options.rotation or -4
 local tag=Kit.frame(root,"Tag",nil,UDim2.fromOffset(math.floor(lineSize*.08),0),UDim2.fromOffset(10,10),3);tag.BackgroundTransparency=0
 local tagText=C.display(tag,"",tagSize,C.Ink,{Name="TagText",TextXAlignment=Enum.TextXAlignment.Center})
 local shadow=C.display(root,"",lineSize,C.Gold,{Name="Shadow"})
 local main=C.display(root,"",lineSize,C.White,{Name="Line"});main.ZIndex=shadow.ZIndex+1
 local underline=Kit.frame(root,"Underline",nil,UDim2.new(),UDim2.fromOffset(10,math.max(3,math.floor(lineSize*.08))),2)
 underline.BackgroundTransparency=0
 local api={root=root,tag=tag,tagText=tagText,label=main,shadow=shadow,underline=underline}
 function api.set(tagValue,line,accent,showTag)
  tagText.Text,main.Text,shadow.Text=tagValue or "",line or "",line or ""
  local tw=C.measure(tagText.Text,tagSize);local lw=C.measure(main.Text,lineSize)
  local tagH=if showTag~=false and tagText.Text~=""then math.floor(tagSize*1.45)else 0
  tag.Visible=tagH>0;tag.Size=UDim2.fromOffset(tw.X+math.floor(tagSize*1.1),tagH);tagText.Size=UDim2.fromScale(1,1)
  tag.BackgroundColor3=accent;underline.BackgroundColor3=accent;shadow.TextColor3=accent
  local lineH=math.floor(lineSize*1.1);local y=if tagH>0 then tagH-math.floor(lineSize*.08)else 0
  main.Position,main.Size=UDim2.fromOffset(0,y),UDim2.fromOffset(lw.X+8,lineH)
  local drop=math.max(2,math.floor(lineSize*.06))
  shadow.Position,shadow.Size=UDim2.fromOffset(drop,y+drop),main.Size
  underline.Position=UDim2.fromOffset(0,y+lineH-math.floor(lineSize*.02));underline.Size=UDim2.fromOffset(math.floor((lw.X+8)*.86),underline.Size.Y.Offset)
  root.Size=UDim2.fromOffset(lw.X+8+drop,y+lineH+underline.Size.Y.Offset+4)
 end
 return api
end

-- Star token (2.4): the 3D StarToken mesh when it loads, else a 2D glyph star
-- (shadow, body with a dark-gold stroke, a lighter facet, a gloss dot); rays
-- and a glow behind either. `mode` "gold" or "glass" (missed round).
-- options.mesh=false keeps the 2D star (fixtures, fallback specs).
function C.star(parent,size,options)
 local root=Kit.frame(parent,"StarToken",nil,UDim2.new(),UDim2.fromOffset(size,size));root.AnchorPoint=Vector2.new(.5,.5)
 local scale=Kit.node("UIScale",root,{Scale=1})
 -- Soft round glow (a stretched 9-slice focus glow showed its slice rectangle).
 local glow=Kit.node("Frame",root,{Name="Glow",BackgroundColor3=C.Gold,BackgroundTransparency=.55,BorderSizePixel=0,
  AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1.7,1.7),ZIndex=root.ZIndex+1})
 Kit.node("UICorner",glow,{CornerRadius=UDim.new(.5,0)})
 Kit.node("UIGradient",glow,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})})
 local rays=Kit.frame(root,"Rays",nil,UDim2.fromScale(.5,.5),UDim2.fromOffset(size*2.5,size*2.5));rays.AnchorPoint=Vector2.new(.5,.5)
 rays.ZIndex=root.ZIndex+1
 for index=1,12 do
  local w=math.max(4,math.floor(size*(if index%2==0 then .10 else .2)))
  local ray=Kit.frame(rays,"Ray"..index,nil,UDim2.fromScale(.5,.5),UDim2.new(0,w,1,0));ray.AnchorPoint=Vector2.new(.5,.5)
  ray.BackgroundTransparency=0;ray.BackgroundColor3=C.Gold;ray.Rotation=(index-1)*30
  gradient(ray,90,{{0,1},{.06,.62},{.42,.86},{.5,1},{1,1}})
 end
 local body=Kit.frame(root,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=rays.ZIndex+2
 local glyph=math.floor(size*1.18)
 local function layer(name,color,offset,textSize)
  return Kit.node("TextLabel",body,{Name=name,BackgroundTransparency=1,Text="★",TextColor3=color,TextSize=textSize or glyph,
   FontFace=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.Bold),AnchorPoint=Vector2.new(.5,.5),
   Position=UDim2.new(.5,offset.X,.5,offset.Y),Size=UDim2.fromScale(1.2,1.2),ZIndex=body.ZIndex+1})
 end
 local shadow=layer("Shadow",C.GoldDeep,Vector2.new(0,math.floor(size*.05)))
 local main=layer("Main",C.Gold,Vector2.zero);main.ZIndex+=1
 local stroke=Kit.node("UIStroke",main,{Color=C.GoldDeep,Thickness=math.max(1.5,size*.022),Transparency=0})
 local facet=layer("Facet",C.GoldLight,Vector2.new(-math.floor(size*.04),-math.floor(size*.05)),math.floor(glyph*.62));facet.ZIndex+=2;facet.TextTransparency=.35
 local gloss=Kit.frame(body,"Gloss",nil,UDim2.fromScale(.4,.33),UDim2.fromOffset(math.floor(size*.2),math.floor(size*.09)),999)
 gloss.AnchorPoint=Vector2.new(.5,.5);gloss.BackgroundTransparency=.15;gloss.BackgroundColor3=C.White;gloss.Rotation=-18;gloss.ZIndex=main.ZIndex+3
 local rayList={}
 for _,ray in ipairs(rays:GetChildren())do if ray:IsA("Frame")then table.insert(rayList,ray)end end
 -- 3D StarToken (EggModels.Star) in one small ViewportFrame over the glyph;
 -- the glyph stays as the fallback while loading or when creation fails.
 local viewport=Kit.node("ViewportFrame",root,{Name="StarToken3D",BackgroundTransparency=1,BorderSizePixel=0,Visible=false,
  AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1.3,1.3),ZIndex=body.ZIndex+6,
  Ambient=Color3.fromRGB(196,186,168),LightColor=Color3.fromRGB(255,244,224),LightDirection=Vector3.new(-.6,-1,-1.6)})
 local api={root=root,scale=scale,body=body,rays=rays,glow=glow,main=main,size=size,mode="gold",viewport=viewport,has3D=false,yaw=0,planar=0}
 -- QA 2026-11-13: the missed-round Star is an opaque silver token. Glass at 50%
 -- in a ViewportFrame drew its back faces through the front (the doubled side
 -- band) and picked up the default sky's tint (a purple flash before grey).
 local function paintPart()
  local part=api.part;if not part then return end
  local glass=api.mode=="glass"
  part.TextureID=if glass then ""else api.texture
  part.Color=if glass then C.StarSilver else Color3.new(1,1,1)
  part.Transparency=0
  part.Material=Enum.Material.SmoothPlastic
 end
 function api.setMode(mode)
  api.mode=mode
  local glass=mode=="glass"
  main.TextColor3=if glass then Color3.fromHex("#2B393B")else C.Gold
  main.TextTransparency=if glass then .35 else 0
  stroke.Color=if glass then Color3.fromHex("#C6CED1")else C.GoldDeep;stroke.Transparency=if glass then .15 else 0
  shadow.Visible,facet.Visible,gloss.Visible,glow.Visible,rays.Visible=not glass,not glass,not glass,not glass,not glass
  paintPart()
 end
 -- flare 0..1 brightens and grows the rays (finale); 0 is the idle glow.
 function api.setRays(rotation,flare)
  if api.rayRotation~=rotation then api.rayRotation=rotation;rays.Rotation=rotation end
  if api.rayFlare==flare then return end
  api.rayFlare=flare
  local s=1+.25*flare;rays.Size=UDim2.fromOffset(size*2.5*s,size*2.5*s)
  for _,ray in ipairs(rayList)do ray.BackgroundTransparency=.25-.25*flare end
  glow.BackgroundTransparency=.55-.25*flare
 end
 -- Spin: `yaw` (degrees about +Y) turns the 3D token; the 2D fallback uses
 -- `planar` (in-plane degrees) instead. Writes only on change.
 function api.setSpin(yaw,planar)
  api.wantYaw=yaw
  if api.has3D then
   if root.Rotation~=0 then root.Rotation=0 end
   if api.yaw~=yaw and api.part then api.yaw=yaw;api.part.CFrame=CFrame.Angles(0,math.rad(yaw),0)end
  elseif root.Rotation~=planar then root.Rotation=planar end
  api.planar=planar
 end
 api.setMode((options and options.mode)or "gold");api.setRays(0,0)
 if options==nil or options.mesh~=false then
  local building=true -- a template that is already loaded swaps in at once
  C.loadStarMesh(function(template)
   if not template or not root.Parent or api.has3D then return end
   local Models=require(game:GetService("ReplicatedStorage").Shared.EggModels).Star
   -- Paint (mode colour, texture) and pose before the part is parented, so the
   -- first frame it renders in is already the final look.
   local part=template:Clone();part.CFrame=CFrame.Angles(0,math.rad(api.wantYaw or 0),0)
   api.part,api.texture=part,Models.colorMap
   paintPart()
   part.Parent=viewport
   local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
   -- Fill about 82% of the viewport height (the 164 px Star in a 200 px box).
   local distance=(Models.size.Y*.5)/math.tan(math.rad(15))/.82+Models.size.Z*.5
   camera.CFrame=CFrame.lookAt(Vector3.new(0,0,distance),Vector3.zero)
   api.has3D=true;api.yaw=nil;api.setSpin(api.wantYaw or 0,api.planar)
   -- A Star already on screen cross-fades from the 2D glyph (no pop); one not yet
   -- shown swaps at once.
   if not building and root.Visible and root.AbsoluteSize.X>0 and not Kit.reduced()then
    viewport.ImageTransparency=1;viewport.Visible=true;root.Rotation=0
    local tween=game:GetService("TweenService"):Create(viewport,TweenInfo.new(C.StarFade,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{ImageTransparency=0})
    tween.Completed:Connect(function()if api.part==part then body.Visible=false end end)
    tween:Play()
   else
    viewport.ImageTransparency=0;body.Visible=false;viewport.Visible=true
   end
  end)
  building=false
 end
 return api
end
C.StarSilver=Color3.fromHex("#C9D3DA")
C.StarFade=.25
-- Boot preload (QA 2026-11-13): build the one StarToken template early so the
-- results Star never pops in a second late. Safe to call more than once.
function C.preloadStarMesh()C.loadStarMesh(function()end)end

-- One StarToken template per session: created once with AssetService (MeshId
-- cannot be set from scripts), sized from EggModels (it arrives at raw scale),
-- then cloned per view. `starMeshState`: nil, "loading", "ready" or "failed".
local starTemplate,starState,starWaiters=nil,nil,{}
function C.starMeshState()return starState end
function C.loadStarMesh(callback)
 if starState=="ready"then callback(starTemplate);return end
 if starState=="failed"then callback(nil);return end
 table.insert(starWaiters,callback)
 if starState=="loading"then return end
 starState="loading"
 task.spawn(function()
  local ok,result=pcall(function()
   local Models=require(game:GetService("ReplicatedStorage").Shared.EggModels).Star
   local AssetService=game:GetService("AssetService")
   -- Precise render fidelity: the viewport camera sits far back (FOV 30), and an
   -- automatic LOD drew a coarse side band that read as a doubled texture.
   local meshOptions={RenderFidelity=Enum.RenderFidelity.Precise,CollisionFidelity=Enum.CollisionFidelity.Box}
   local made,part=pcall(function()return AssetService:CreateMeshPartAsync(Content.fromUri(Models.mesh),meshOptions)end)
   if not made then part=AssetService:CreateMeshPartAsync(Models.mesh,meshOptions)end
   pcall(function()part.DoubleSided=false end)
   part.Name="StarToken";part.Size=Models.size;part.TextureID=Models.colorMap
   part.Material=Enum.Material.SmoothPlastic;part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
   return part
  end)
  if ok and result then starTemplate,starState=result,"ready"
  else starState="failed";warn("Star token mesh could not be created; using the 2D Star: "..tostring(result))end
  local waiting=starWaiters;starWaiters={}
  for _,waiter in ipairs(waiting)do task.spawn(waiter,starTemplate)end
 end)
end

-- Gold reward button (results Hatch). Kit.button's "reward" variant with the
-- Heading role, a larger size and an ink egg mark before the label.
function C.rewardButton(parent,name,text,size,textSize,glyph)
 local button,state=Kit.button(parent,name,{variant="reward",text=text,size=size,textSize=textSize,glyph=glyph,selectable=false})
 Kit.setFontRole(state.label,"Heading");state.label.TextSize=textSize
 local egg=Kit.frame(state.content,"EggMark",nil,UDim2.new(),UDim2.fromOffset(math.floor(textSize*.62),math.floor(textSize*.8)),999)
 egg.BackgroundTransparency=0;egg.BackgroundColor3=C.Ink;egg.LayoutOrder=1
 if state.glyph then state.glyph.LayoutOrder=0 end
 return button,state
end

return C
