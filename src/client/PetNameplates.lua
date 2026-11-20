-- v2 pet names: the little cream name tag over a pet in the garden (V2-CUTE-ICONS-AND-NAMES
-- 2.4). Your own pet's tag shows whenever it has a name; another player's shows only when you
-- are near it (NearRange), never across the map, so there is no cloud of names. Hidden during a
-- round (the board is not in Room mode) and for a pet with no name (the species is no news).
-- Text is built from piece ids (PetNameText); AutoLocalize is off: a name is a proper name.
local Players=game:GetService("Players")
local Kit=require(script.Parent.DeckKit)
local NameText=require(script.Parent.PetNameText)
local Plates={}
Plates.__index=Plates
Plates.NearRange=20
Plates.TextSize=14
Plates.Height=26
Plates.Refresh=.2

local function headOf(visual)
	for _,entry in ipairs(visual.pieces or {})do if entry.name=="Head"and entry.part then return entry.part end end
	local model=visual.model
	return model and(model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true))
end

-- Pure: the tag's width for a name (text plus the pill's padding).
function Plates.width(text)
	return math.ceil(Kit.measure(text,"Strong",Plates.TextSize).X)+22
end
-- Pure: whether another player's tag shows.
function Plates.showOther(named,distance,boardMode)
	return named==true and boardMode=="Room"and type(distance)=="number"and distance<=Plates.NearRange
end

function Plates.new(parent)
	return setmetatable({parent=parent,tags={},clock=0},Plates)
end
function Plates:make(key)
	local gui=Instance.new("BillboardGui")
	gui.Name="EggDropNameplate";gui.ResetOnSpawn=false;gui.AlwaysOnTop=false;gui.LightInfluence=0
	gui.Size=UDim2.fromOffset(80,Plates.Height+4);gui.ClipsDescendants=false
	gui:SetAttribute("NameplateKey",key)
	local pill=Instance.new("Frame");pill.Name="Pill";pill.AnchorPoint=Vector2.new(.5,0);pill.Position=UDim2.new(.5,0,0,0)
	pill.Size=UDim2.new(1,0,0,Plates.Height);pill.BackgroundColor3=Kit.Color.cream or Color3.fromHex("#FFF4DC");pill.BorderSizePixel=0;pill.Parent=gui
	Kit.corner(pill,999)
	local stroke=Instance.new("UIStroke");stroke.Color=Kit.Color.ink;stroke.Thickness=2;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=pill
	-- The lip: a darker band under the pill (Toy Shell keys).
	local lip=Instance.new("Frame");lip.Name="Lip";lip.AnchorPoint=Vector2.new(.5,0);lip.Position=UDim2.new(.5,0,0,3)
	lip.Size=UDim2.new(1,0,0,Plates.Height);lip.BackgroundColor3=Kit.Color.ink;lip.BorderSizePixel=0;lip.ZIndex=0;lip.Parent=gui
	Kit.corner(lip,999)
	local label=Instance.new("TextLabel");label.Name="Name";label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
	label.FontFace=Kit.Type.Strong[3];label.TextSize=Plates.TextSize;label.TextColor3=Kit.Color.ink;label.AutoLocalize=false
	label.TextXAlignment=Enum.TextXAlignment.Center;label.ZIndex=2;label.Parent=pill
	gui.Parent=self.parent
	return {gui=gui,label=label,text=nil}
end
function Plates:place(key,visual,text,maxDistance)
	local tag=self.tags[key]
	local head=visual and not visual.destroyed and headOf(visual)
	if not head then if tag then tag.gui.Enabled=false end;return end
	if not tag then tag=self:make(key);self.tags[key]=tag end
	if tag.text~=text then
		tag.text=text;tag.label.Text=text
		tag.gui.Size=UDim2.fromOffset(Plates.width(text),Plates.Height+4)
	end
	if tag.gui.Adornee~=head then
		tag.gui.Adornee=head
		tag.gui.StudsOffsetWorldSpace=Vector3.new(0,head.Size.Y*.5+.9,0)
	end
	tag.gui.MaxDistance=maxDistance
	tag.gui.Enabled=true
	tag.seen=true
end
-- ctx: own = {visual, petId, state, mode}, others = RoomCompanions.active, localRoot (BasePart).
function Plates:step(dt,ctx)
	self.clock-=dt
	if self.clock>0 then return end
	self.clock=Plates.Refresh
	for _,tag in pairs(self.tags)do tag.seen=false end
	local own=ctx.own
	if own and own.visual and own.mode=="Room"then
		local text,named=NameText.own(own.state,own.petId)
		if named then self:place("own",own.visual,text,80)end
	end
	local root=ctx.localRoot
	for player,entry in pairs(ctx.others or {})do
		if typeof(player)=="Instance"and player~=Players.LocalPlayer and entry.visual and entry.board and root then
			local text,named=NameText.ofBoard(entry.board,entry.pet and entry.pet.id)
			local head=headOf(entry.visual)
			local distance=head and(head.Position-root.Position).Magnitude
			if Plates.showOther(named,distance,entry.board:GetAttribute("Mode"))then
				self:place("u"..player.UserId,entry.visual,text,Plates.NearRange+6)
			end
		end
	end
	for key,tag in pairs(self.tags)do
		if not tag.seen then tag.gui:Destroy();self.tags[key]=nil end
	end
end
function Plates:clear()
	for key,tag in pairs(self.tags)do tag.gui:Destroy();self.tags[key]=nil end
end
function Plates:destroy()self:clear()end
return Plates
