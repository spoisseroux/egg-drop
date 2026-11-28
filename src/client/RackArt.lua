-- The slice 2 picks' art (ROTATION-2-BRIEF 1 and 2: "a plate card is its texture on the handheld silhouette (ImageLabel,
-- no viewport); a ball card is its five circles (BallThemes.circle)"; a toy card is the toy in that colour). Used by the
-- Today's picks sheet (RackPicks) and the Deck Egg's reveal (GiftStage's 2D fallback, RackShop.mount's deckArt).
--   plate(parent, id, position, size, z)   the handheld: rounded body, the plate's texture, its screen and buttons, a trim
--                                          in the plate's accent. -> the Frame
--   balls(parent, id, position, size, z)   the theme's five ball sizes in a row (rich text circles). -> the TextLabel
--   toyEntry(toyId, skinId)                a still ViewportFrame of the toy wearing the colour, CardPreviewCache's
--                                          entry shape ({viewport, camera, extra}), or false
-- No clock, nothing animated (posed once, calm under Reduced Motion).
local Shared=game:GetService("ReplicatedStorage").Shared
local Plates=require(Shared.DeckThemes)
local Balls=require(Shared.BallThemes)
local Art={}
Art.Aspect=.66        -- the handheld's width / height
Art.Screen="#D8F2DE"  -- the screen's mint (the plate is the colour around it)
Art.ToyYaw=-.5

local function hex(value,fallback)
	local ok,color=pcall(Color3.fromHex,value or "")
	return if ok then color else fallback or Color3.new(1,1,1)
end
local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props)do n[k]=v end
	n.Parent=parent
	return n
end
local function corner(parent,scale)node("UICorner",parent,{CornerRadius=UDim.new(scale,0)})end

function Art.plate(parent,id,position,size,z)
	local theme=Plates.ById[id]
	z=z or 1
	local holder=node("Frame",parent,{Name="PlateArt",BackgroundTransparency=1,Position=position or UDim2.new(),Size=size or UDim2.fromScale(1,1),ZIndex=z})
	local body=node("Frame",holder,{Name="Handheld",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,.9),
		BackgroundColor3=hex(theme and theme.deep,Color3.fromHex("#5A6B7A")),BorderSizePixel=0,ZIndex=z+1})
	node("UIAspectRatioConstraint",body,{AspectRatio=Art.Aspect,DominantAxis=Enum.DominantAxis.Height})
	corner(body,.14)
	if theme and type(theme.texture)=="string"then
		local image=node("ImageLabel",body,{Name="Plate",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=theme.texture,
			ScaleType=Enum.ScaleType.Crop,ZIndex=z+2})
		corner(image,.14)
	end
	node("UIStroke",body,{Thickness=2,Color=hex(theme and theme.accent,Color3.new(1,1,1)),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	local ink=hex(theme and theme.ink,Color3.fromHex("#0E0F12"))
	local screen=node("Frame",body,{Name="Screen",Position=UDim2.fromScale(.13,.09),Size=UDim2.fromScale(.74,.42),BackgroundColor3=hex(Art.Screen),
		BorderSizePixel=0,ZIndex=z+3})
	corner(screen,.12)
	node("UIStroke",screen,{Thickness=1.5,Color=ink,Transparency=.2})
	-- the pad and two buttons, in the plate's ink
	local function dot(name,x,y,s)
		local d=node("Frame",body,{Name=name,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(s,s*Art.Aspect),
			BackgroundColor3=ink,BorderSizePixel=0,ZIndex=z+3})
		corner(d,1)
	end
	dot("ButtonA",.74,.66,.14);dot("ButtonB",.58,.74,.14)
	node("Frame",body,{Name="PadX",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.27,.7),Size=UDim2.fromScale(.24,.05),BackgroundColor3=ink,BorderSizePixel=0,ZIndex=z+3})
	node("Frame",body,{Name="PadY",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.27,.7),Size=UDim2.fromScale(.08,.16),BackgroundColor3=ink,BorderSizePixel=0,ZIndex=z+3})
	holder:SetAttribute("PlateId",id)
	return holder
end

-- The five ball sizes as one line of rich-text circles, sized to the label's height (measured once: it never animates).
function Art.ballText(id,textSize)
	local parts={}
	for tier=1,5 do table.insert(parts,Balls.circle(tier,textSize,id))end
	return table.concat(parts," ")
end
function Art.balls(parent,id,position,size,z)
	local label=node("TextLabel",parent,{Name="BallArt",BackgroundTransparency=1,Position=position or UDim2.new(),Size=size or UDim2.fromScale(1,1),
		ZIndex=z or 1,RichText=true,TextScaled=false,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,
		TextYAlignment=Enum.TextYAlignment.Center,Text=""})
	label.AutoLocalize=false
	local function fit()
		local w,h=label.AbsoluteSize.X,label.AbsoluteSize.Y
		if w<2 or h<2 then return end
		-- the biggest ball is 1.3x the text size times its tier scale; five in a row with gaps fit the width
		local size=math.max(6,math.floor(math.min(h*.42,w/9)))
		label.Text=Art.ballText(id,size)
	end
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	if label.Text==""then label.Text=Art.ballText(id,14)end
	label:SetAttribute("BallTheme",id)
	return label
end

-- A still toy in its colour (PetToyGeometry tints the one named part: ToySkinLook). CardPreviewCache's entry shape.
function Art.toyEntry(toyId,skinId)
	local Toys=require(script.Parent.PetToyGeometry)
	local viewport=Instance.new("ViewportFrame");viewport.Name="CardPreview";viewport.BackgroundTransparency=1;viewport.Size=UDim2.fromScale(1,1)
	pcall(function()require(script.Parent.DeckKit).petLight(viewport)end)
	local world=Instance.new("WorldModel");world.Parent=viewport
	local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
	local ok,handle=pcall(Toys.create,world,toyId,1,skinId)
	if not ok or not handle then viewport:Destroy();return false end
	pcall(function()if Toys.setSparks then Toys.setSparks(handle,false)end end)
	local framed=pcall(function()
		local box,extent=handle.model:GetBoundingBox()
		local half=math.tan(math.rad(camera.FieldOfView/2))
		local distance=math.max(extent.X,extent.Y,extent.Z)*.5/half*1.35+extent.Z*.5
		local direction=(CFrame.Angles(0,Art.ToyYaw,0)*CFrame.Angles(-.28,0,0)).LookVector
		camera.CFrame=CFrame.lookAt(box.Position-direction*distance,box.Position)
	end)
	if not framed then pcall(handle.destroy,handle);viewport:Destroy();return false end
	local entry={viewport=viewport,camera=camera,extra=handle}
	viewport.Destroying:Connect(function()entry.dead=true end)
	return entry
end

return Art
