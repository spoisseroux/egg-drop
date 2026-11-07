local Art=require(script.Parent.DeckArt)
local Quest={};Quest.__index=Quest
function Quest.new(parent)
	local host=Art.frame(parent,"ActiveQuest",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),parent.ZIndex+3)
	host.ClipsDescendants=true;host.BackgroundTransparency=1;Art.corner(host,8)
	local title=Art.text(host,"Instruction","Match on LEFT",UDim2.fromOffset(4,1),UDim2.new(1,-8,0,21),Art.Silver,14)
	Art.type(title,"Body")
	local progress=Art.text(host,"Steps","LEFT ○   RIGHT ○",UDim2.new(0,4,1,-15),UDim2.new(1,-8,0,14),Art.Muted,10)
	Art.type(progress,"Supporting",true)
	local self=setmetatable({host=host,title=title,progress=progress},Quest)
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:update(self.stage or 0,self.phase,self.visible) end)
	return self
end
-- Measure the caption and ticker as one close vertical pack. Welcome coaching
-- keeps its independently solved full well; only field presentation calls this.
function Quest:preferredHeight(width,available,compact)
	local textService=game:GetService("TextService")
	local size=if compact then 12 else 16
	local titleH,progressH=22,18
	for _,caption in ipairs({"Match two IIs on RIGHT","Both sides done · keep it low","Settling · keep it low"})do
		local bounds=textService:GetTextSize(caption,size,Enum.Font.Gotham,Vector2.new(math.max(1,width-8),10000))
		titleH=math.max(titleH,math.ceil(bounds.Y)+4)
	end
	for _,caption in ipairs({"LEFT ○   RIGHT ○","LEFT ✓   RIGHT ✓"})do
		local bounds=textService:GetTextSize(caption,12,Enum.Font.Gotham,Vector2.new(math.max(1,width-8),10000))
		progressH=math.max(progressH,math.ceil(bounds.Y)+4)
	end
	return math.min(available,if compact then math.max(20,titleH)else titleH+progressH+10)
end
function Quest:update(stage,phase,visible,compactHint)
	if compactHint~=nil then self.compactHint=compactHint end
	self.stage,self.phase,self.visible=stage,phase,visible
	self.host.Visible=visible==true
	local height,width=self.host.AbsoluteSize.Y,self.host.AbsoluteSize.X
	local compact=if self.compactHint~=nil then self.compactHint else height<60
	local key=table.concat({stage,phase or "",tostring(compact),height,width,game:GetService("GuiService").PreferredTextSize.Name},"|")
	if self.layoutKey==key then return end
	self.layoutKey=key
	Art.type(self.title,"Body",compact);if compact then self.title.TextSize=12 end
	Art.type(self.progress,"Supporting",true)
	self.title.Position=UDim2.fromOffset(4,if compact then 0 else 4)
	self.title.Size=if compact then UDim2.new(1,-8,1,0)else UDim2.new(1,-8,0,22)
	self.title.Text=if phase=="Settling" then (if compact then "Settling…"else "Settling · keep it low")
		elseif stage>=2 then (if compact then "Both sides ✓"else "Both sides done · keep it low")
		elseif compact then "II + II on "..(if stage==0 then "LEFT"else "RIGHT")
		else "Match two IIs on "..(if stage==0 then "LEFT"else "RIGHT")
	if compact then
		self.title.TextWrapped=false
		local candidates,meaning
		if phase=="Settling"then candidates={"Settling…","Settling","Wait"};meaning="Settling · keep it low"
		elseif stage>=2 then candidates={"Both sides ✓","Sides done ✓","Done ✓","Done"};meaning="Both sides done · keep it low"
		elseif stage==0 then candidates={"II + II on LEFT","II+II LEFT","← II+II","←II+II"};meaning="Match two tier-II pieces on LEFT"
		else candidates={"II + II on RIGHT","II+II RIGHT","II+II →","II+II→"};meaning="Match two tier-II pieces on RIGHT"end
		self.title:SetAttribute("AccessibleLabel",meaning)
		for _,caption in ipairs(candidates)do self.title.Text=caption;if Art.textWidth(self.title)<=math.max(1,width-8)then break end end
	end
	self.progress.Text=(if stage>=1 then "LEFT ✓"else "LEFT ○").."   "..(if stage>=2 then "RIGHT ✓"else "RIGHT ○")
	if not compact then
		local titleH=Art.textHeight(self.title,width-8,22)
		local progressH=Art.textHeight(self.progress,width-8,18)
		self.title.Size=UDim2.new(1,-8,0,titleH)
		self.progress.Position,self.progress.Size=UDim2.fromOffset(4,4+titleH+3),UDim2.new(1,-8,0,progressH)
		self.progress.Visible=4+titleH+3+progressH+3<=height
	else self.progress.Visible=false end
end
return Quest
