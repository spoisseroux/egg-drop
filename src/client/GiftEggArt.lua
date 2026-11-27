-- The wrapped egg and its bow, drawn from GUI instances (GIFT-ART-BRIEF, the kit): an egg (a rounded frame .78 x 1,
-- white to #C9F1FF, a 2 px ink stroke), a pink band down it and one across meeting 42% from the top, a bow there (two
-- pink loops at +-28 degrees and a deep pink knot) and the Aero glint (a 2 px white bar upper left, a dot below right).
-- One drawing at every size (36 px chip, 44 px pill icon, 28 px tag); the numbers are GiftArt's. Also the bow alone
-- (the card's corner) and the silhouettes (the nest Peek's disc). No images, no uploads.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GiftArt=require(Shared:WaitForChild("GiftArt"))
local Draw={}
local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent
	return n
end
Draw.node=node
local function round(parent,r)return node("UICorner",parent,{CornerRadius=r or UDim.new(.5,0)})end
local function piece(parent,name,p,color,z,props)
	local f=node("Frame",parent,{Name=name,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(p.x,p.y),Size=UDim2.fromOffset(p.w,p.h),
		Rotation=p.rot or 0,BackgroundColor3=color,BorderSizePixel=0,ZIndex=z,Active=false})
	for k,v in pairs(props or {})do f[k]=v end
	return f
end

-- The egg `height` px tall in `parent`, centred at `at` (UDim2, default the parent's centre). -> {holder, bow (the
-- frame holding the loops and knot: rotate it to wiggle), egg}
function Draw.egg(parent,height,at,z)
	z=z or(parent:IsA("GuiObject")and parent.ZIndex+1 or 2)
	local L=GiftArt.eggLayout(height)
	local holder=node("Frame",parent,{Name="WrappedEgg",AnchorPoint=Vector2.new(.5,.5),Position=at or UDim2.fromScale(.5,.5),
		Size=UDim2.fromOffset(L.w,L.h),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z,Active=false})
	local egg=piece(holder,"Egg",L.egg,Color3.new(1,1,1),z)
	round(egg)
	node("UIGradient",egg,{Rotation=90,Color=ColorSequence.new(GiftArt.color("eggTop"),GiftArt.color("eggBottom"))})
	node("UIStroke",egg,{Color=GiftArt.color("ink"),Thickness=GiftArt.Egg.stroke})
	local down=piece(holder,"BandDown",L.bandDown,GiftArt.color("pink"),z+1);round(down,UDim.new(0,math.max(2,L.bandDown.w/2)))
	local across=piece(holder,"BandAcross",L.bandAcross,GiftArt.color("pink"),z+1);round(across,UDim.new(.5,0))
	local bow=node("Frame",holder,{Name="Bow",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(L.knot.x,L.knot.y),
		Size=UDim2.fromOffset(L.w,L.h*.3),BackgroundTransparency=1,ZIndex=z+2,Active=false})
	local cx,cy=L.w/2,L.h*.15
	for _,key in ipairs({"loopL","loopR"})do
		local p=L[key]
		local loop=piece(bow,key,{x=cx+(p.x-L.knot.x),y=cy+(p.y-L.knot.y),w=p.w,h=p.h,rot=p.rot},GiftArt.color("pink"),z+2)
		round(loop)
		node("UIStroke",loop,{Color=GiftArt.color("deep"),Thickness=1})
	end
	local knot=piece(bow,"Knot",{x=cx,y=cy,w=L.knot.w,h=L.knot.h},GiftArt.color("deep"),z+3);round(knot)
	local glint=piece(holder,"Glint",L.glint,Color3.new(1,1,1),z+4);round(glint)
	local dot=piece(holder,"GlintDot",L.dot,Color3.new(1,1,1),z+4);round(dot)
	return{holder=holder,bow=bow,egg=egg}
end
-- The bow alone, `size` px across (the card's corner): two loops, two short tails and the knot. -> the frame
function Draw.bow(parent,size,at,z)
	z=z or parent.ZIndex+1
	local holder=node("Frame",parent,{Name="Bow",AnchorPoint=Vector2.new(.5,.5),Position=at or UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(size,size),
		BackgroundTransparency=1,ZIndex=z,Active=false})
	local c=size/2
	for i,sign in ipairs({-1,1})do
		local tail=piece(holder,"Tail"..i,{x=c+sign*size*.13,y=c+size*.26,w=size*.16,h=size*.42,rot=sign*22},GiftArt.color("deep"),z)
		round(tail,UDim.new(0,3))
		local loop=piece(holder,"Loop"..i,{x=c+sign*size*.24,y=c-size*.04,w=size*.44,h=size*.3,rot=sign*GiftArt.Egg.loopAngle},GiftArt.color("pink"),z+1)
		round(loop)
		node("UIStroke",loop,{Color=GiftArt.color("deep"),Thickness=2})
	end
	local knot=piece(holder,"Knot",{x=c,y=c-size*.02,w=size*.22,h=size*.22},GiftArt.color("deep"),z+2);round(knot)
	piece(holder,"Shine",{x=c-size*.3,y=c-size*.1,w=2,h=size*.12,rot=-30},Color3.new(1,1,1),z+3)
	return holder
end
-- A silhouette (GiftArt.silhouette(kind)) inside `disc` (its shapes in shares of the disc). `paper` cuts with the disc.
function Draw.silhouette(disc,kind,paper,z)
	z=z or disc.ZIndex+1
	local out=node("Frame",disc,{Name="Silhouette",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=z,Active=false})
	for i,s in ipairs(GiftArt.silhouette(kind))do
		local tone=if s.tone=="paper"then(paper or Color3.new(1,1,1))else GiftArt.color("ink")
		local f=node("Frame",out,{Name="Shape"..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(s.x,s.y),Size=UDim2.fromScale(s.w,s.h),
			Rotation=s.rot,BackgroundColor3=tone,BorderSizePixel=0,ZIndex=z+(if s.tone=="paper"then 1 else 0),Active=false})
		if s.shape=="round"then round(f)
		elseif s.shape=="ring"then
			round(f);f.BackgroundTransparency=1
			node("UIStroke",f,{Color=tone,Thickness=3})
		else round(f,UDim.new(.14,0))end
	end
	return out
end
-- Fades a drawn group to `alpha` (0..1 opacity), each piece from its own drawn transparency (kept the first time).
function Draw.fade(root,alpha)
	local function one(o,key)
		local base=o:GetAttribute("GiftBase"..key)
		if base==nil then base=o[key];o:SetAttribute("GiftBase"..key,base)end
		local want=1-(1-base)*alpha
		if o[key]~=want then o[key]=want end
	end
	for _,o in ipairs(root:GetDescendants())do
		if o:IsA("GuiObject")and o.Name~="Hit"then
			one(o,"BackgroundTransparency")
			if o:IsA("TextLabel")or o:IsA("TextButton")then one(o,"TextTransparency")end
			if o:IsA("ImageLabel")or o:IsA("ImageButton")then one(o,"ImageTransparency")end
		elseif o:IsA("UIStroke")then one(o,"Transparency")end
	end
end
return Draw
