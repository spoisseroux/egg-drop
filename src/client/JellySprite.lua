-- Bounded inexpensive stepped rendition used after LCD allocation/paint failure.
-- Physics pose is continuous; only this display quantizes to a logical screen grid.
local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
local Sprite={};Sprite.__index=Sprite
Sprite.GridWidth=64
-- Separate upright native glyphs keep the authored font and center. The small
-- bounded catalog is measured only on creation or a preference invalidation.
local markSizes={}
function Sprite.invalidateMarkSizes()table.clear(markSizes)end
function Sprite.markSize(mark)
	local preference=game:GetService("GuiService").PreferredTextSize
	local byMark=markSizes[preference]
	if not byMark then byMark={};markSizes[preference]=byMark end
	local cached=byMark[mark]
	if cached then return cached end
	local bounds=game:GetService("TextService"):GetTextSize(mark,15,Enum.Font.GothamMedium,Vector2.new(10000,10000))
	cached=UDim2.fromOffset(math.max(30,math.ceil(bounds.X)+2),math.max(22,math.ceil(bounds.Y)+2))
	byMark[mark]=cached;return cached
end
local function frame(parent,name,color)
	local node=Instance.new("Frame");node.Name,node.BackgroundColor3,node.BorderSizePixel=name,color,0
	node.Active,node.Selectable,node.Visible=false,false,false;node.ZIndex=parent.ZIndex;node.Parent=parent
	return{node=node}
end
local function place(slot,x,y,w,h,cellX,cellY)
	local writes=0
	local shown=w>0 and h>0
	if shown then
		local left,top=math.round(x*cellX),math.round(y*cellY)
		local width,height=math.round((x+w)*cellX)-left,math.round((y+h)*cellY)-top
		shown=width>0 and height>0
		if slot.x~=left or slot.y~=top then slot.node.Position=UDim2.new(.5,left,.5,top);slot.x,slot.y=left,top;writes+=1 end
		if slot.w~=width or slot.h~=height then slot.node.Size=UDim2.fromOffset(width,height);slot.w,slot.h=width,height;writes+=1 end
	end
	if slot.shown~=shown then slot.node.Visible=shown;slot.shown=shown;writes+=1 end
	return writes
end
function Sprite.new(parent,source,options)
	options=options or {}
	local color=source.Color;local deep=color:Lerp(Color3.fromHex("#142D20"),.65)
	local body=frame(parent,source.Name,deep).node;body.BackgroundTransparency=1;body.AnchorPoint=Vector2.new(.5,.5)
	local gridWidth=options.gridWidth or Sprite.GridWidth
	local gridHeight=math.round(gridWidth*(Config.Height+.8)/(Config.Width+.8))
	local radius=source.Size.X/2
	local bands=math.clamp(math.round(radius*gridWidth/(Config.Width+.8)),5,9)
	local self=setmetatable({body=body,radius=radius,position=source.Position,axis=Vector2.yAxis,strength=.16,age=0,
		phase=source:GetAttribute("EggId")*.73,gridWidth=gridWidth,gridHeight=gridHeight,bandCount=bands,rims={},fills={},fillBounds={}},Sprite)
	for index=1,bands do
		self.rims[index]=frame(body,"Rim"..index,deep)
		local fill=frame(body,"Gel"..index,if index<=bands/2 then color:Lerp(Color3.new(1,1,1),.16*(1-(index-1)/bands))else color:Lerp(deep,.24*(index/bands)))
		self.fills[index]=fill
		local gradient=Instance.new("UIGradient");gradient.Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(.78,.78,.78));gradient.Parent=fill.node
		self.fillBounds[index]={}
	end
	self.glints={frame(body,"Glint",Color3.fromHex("#F4F8E9")),frame(body,"GlintStep",Color3.fromHex("#F4F8E9"))}
	self.glint=self.glints[1].node;body.Visible=true
	return self
end
function Sprite:impact(normal,speed)
	self.axis=normal;self.strength=math.clamp(speed/34,.16,.48);self.age=0
end
function Sprite:paint(rx,ry,angle,cx,cy,cellX,cellY)
	local writes=0
	local c,s=math.cos(angle),math.sin(angle)
	local a=c*c/(rx*rx)+s*s/(ry*ry)
	local b=2*c*s*(1/(rx*rx)-1/(ry*ry))
	local cc=s*s/(rx*rx)+c*c/(ry*ry)
	local extentX=math.sqrt((rx*c)^2+(ry*s)^2)
	local extentY=math.sqrt((rx*s)^2+(ry*c)^2)
	local scale=self.gridWidth/(Config.Width+.8)
	local worldX=(cx/self.gridWidth-.5)*(Config.Width+.8)
	local worldY=Config.Height/2-(cy/self.gridHeight-.5)*(Config.Height+.8)
	for index=1,self.bandCount do
		local y0=math.round(-extentY+(index-1)*2*extentY/self.bandCount)
		local y1=math.round(-extentY+index*2*extentY/self.bandCount)
		local y=(y0+y1)/2
		local discriminant=(b*y)^2-4*a*(cc*y*y-1)
		local left,right=0,0
		if discriminant>0 then
			local half=math.sqrt(discriminant)
			left,right=math.round((-b*y-half)/(2*a)),math.round((-b*y+half)/(2*a))
			local bankInset=math.max(0,Config.Bank-(worldY-y1/scale))
			left=math.max(left,math.ceil((-Config.Width/2+bankInset-worldX)*scale))
			right=math.min(right,math.floor((Config.Width/2-bankInset-worldX)*scale))
			y0=math.max(y0,math.ceil((worldY-Config.Height)*scale));y1=math.min(y1,math.floor(worldY*scale))
		end
		writes+=place(self.rims[index],left,y0,right-left,y1-y0,cellX,cellY)
		local fy0=y0+(if index==1 then 1 else 0);local fy1=y1-(if index==self.bandCount then 1 else 0)
		local fl,fr=left+1,right-1
		writes+=place(self.fills[index],fl,fy0,fr-fl,fy1-fy0,cellX,cellY)
		local bounds=self.fillBounds[index];bounds.left,bounds.right,bounds.top,bounds.bottom=fl,fr,fy0,fy1
	end
	-- Highlights are unrotated screen-space bars. Each is mathematically inset
	-- into an actual visible fill band; rotated-parent clipping is never assumed.
	local glintX,glintY,glintW,glintH,stepH=0,0,0,0,0
	for index=math.max(1,math.floor(self.bandCount*.25)),math.floor(self.bandCount/2)do
		local bounds=self.fillBounds[index]
		if bounds.left<0 and bounds.right-bounds.left>=2 and bounds.bottom>bounds.top then
			glintX=math.max(bounds.left,math.min(math.round(-extentX*.32),bounds.right-1))
			glintY=math.max(bounds.top,math.min(-1,bounds.bottom-1))
			glintW=math.max(0,math.min(math.max(1,math.round(math.min(rx,ry)*.45)),bounds.right-glintX,-glintX))
			glintH=if glintY<0 then 1 else 0
			stepH=if glintY+1<math.min(0,bounds.bottom)then 1 else 0
			break
		end
	end
	writes+=place(self.glints[1],glintX,glintY,glintW,glintH,cellX,cellY)
	writes+=place(self.glints[2],glintX+1,glintY+1,math.max(0,glintW-2),if glintH>0 then stepH else 0,cellX,cellY)
	return writes
end
function Sprite:render(position,dt,now,project,drawSprite,reduced)
	self.propertyWrites=0
	self.age+=dt
	local delta=position-self.position;self.position=self.position:Lerp(position,1-math.exp(-34*dt))
	local stretch=math.clamp(-delta.Y/self.radius*.22,0,.15)
	local wave=self.strength*math.exp(-4.7*self.age)
	local floorSqueeze=if self.axis.Y>.85 then .09*math.clamp(1-(position.Y-self.radius)/.15,0,1)else 0
	local squeeze=wave*math.cos(self.age*17)+floorSqueeze-stretch
	local breathe=math.sin(now*2.4+self.phase)*.017
	if reduced then wave,squeeze,breathe=0,0,0 end
	local offset=self.axis*self.radius*squeeze*.82
	local center=self.position-Vector3.new(offset.X,offset.Y,0)
	local height=math.clamp(1-squeeze+breathe,.56,1.48)
	local angle=if reduced then 0 else math.atan2(self.axis.X,self.axis.Y)+math.sin(self.age*19)*wave*.44
	if drawSprite then
		local point,pixels=project(Vector2.new(center.X,center.Y))
		local cellX=pixels*(Config.Width+.8)/self.gridWidth
		local cellY=self.body.Parent.AbsoluteSize.Y/self.gridHeight
		if cellX<=0 or cellY<=0 then return center,1/height,height,angle,math.sin(self.age*20)*wave*2 end
		local cx,cy=math.round(point.X/cellX),math.round(point.Y/cellY)
		local px,py=math.round(cx*cellX),math.round(cy*cellY)
		if self.px~=px or self.py~=py then self.body.Position=UDim2.fromOffset(px,py);self.px,self.py=px,py;self.propertyWrites+=1 end
		local diameter=self.radius*pixels*2
		if self.diameter~=diameter then self.body.Size=UDim2.fromOffset(diameter,diameter);self.diameter=diameter;self.propertyWrites+=1 end
		local radius=self.radius*self.gridWidth/(Config.Width+.8)
		local rx,ry=math.round(radius/height*4)/4,math.round(radius*height*4)/4
		local angleKey=math.round(angle*math.max(rx,ry)*4)
		local nearBoundary=math.abs(center.X)+math.max(rx,ry)/(self.gridWidth/(Config.Width+.8))>Config.Width/2-.2 or center.Y-math.max(rx,ry)/(self.gridWidth/(Config.Width+.8))<Config.Bank+.2 or center.Y+math.max(rx,ry)/(self.gridWidth/(Config.Width+.8))>Config.Height-.2
		local clipX,clipY=if nearBoundary then cx else 0,if nearBoundary then cy else 0
		if self.rx~=rx or self.ry~=ry or self.angleKey~=angleKey or self.cellX~=cellX or self.cellY~=cellY or self.clipX~=clipX or self.clipY~=clipY then
			self.propertyWrites+=self:paint(rx,ry,angleKey/(math.max(rx,ry)*4),cx,cy,cellX,cellY)
			self.rx,self.ry,self.angleKey,self.cellX,self.cellY,self.clipX,self.clipY=rx,ry,angleKey,cellX,cellY,clipX,clipY
		end
	end
	return center,1/height,height,angle,math.sin(self.age*20)*wave*2
end
-- Sparse static grain for the emergency procedural surface. This is deliberately
-- a reduced pixel rendition; the pooled LCD is the complete logical framebuffer.
function Sprite.texture(parent)
	local host=frame(parent,"FallbackGrain",Color3.fromHex("#54783E")).node
	host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.ZIndex=2;host.Visible=true
	for y=3,17,2 do for x=-4,4,2 do
		local dot=frame(host,"Grain",Color3.fromHex("#54783E")).node;dot.BackgroundTransparency=.82
		dot.Position=UDim2.fromScale(.5+x/(Config.Width+.8),.5-(y-Config.Height/2)/(Config.Height+.8))
		dot.Size=UDim2.fromScale(1/Sprite.GridWidth,1/math.round(Sprite.GridWidth*(Config.Height+.8)/(Config.Width+.8)));dot.Visible=true
	end end
	return host
end
function Sprite:destroy()if self.destroyed then return end;self.destroyed=true;self.body:Destroy()end
return Sprite
