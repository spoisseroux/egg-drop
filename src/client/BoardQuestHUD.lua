local Art=require(script.Parent.DeckArt)
local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
local Quest={};Quest.__index=Quest
function Quest.new(parent)
	local host=Art.frame(parent,"ActiveQuest",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),parent.ZIndex+3)
	host.ClipsDescendants=true;Art.corner(host,8)
	local title=Art.text(host,"Instruction","Match on LEFT",UDim2.fromOffset(4,1),UDim2.new(1,-8,0,21),Art.Silver,14)
	Art.type(title,"Body")
	local diagram=Art.frame(host,"PairDiagram",Art.Ink,UDim2.fromOffset(4,24),UDim2.new(1,-8,0,28));diagram.BackgroundTransparency=1
	for i,entry in ipairs({{.18,2},{.48,2},{.84,3}})do
		local ball=Art.frame(diagram,"Piece"..i,Config.Tiers[entry[2]].color,UDim2.new(entry[1],-11,.5,-11),UDim2.fromOffset(22,22))
		Art.corner(ball,20);Art.shade(ball,1,.7)
		Art.fitText(Art.text(ball,"Mark",Config.Tiers[entry[2]].mark,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Art.Ink,11),11,8,0)
	end
	Art.text(diagram,"Plus","+",UDim2.new(.33,-5,0,4),UDim2.fromOffset(10,20),Art.Silver,14)
	Art.text(diagram,"Arrow","→",UDim2.new(.65,-6,0,4),UDim2.fromOffset(14,20),Art.Silver,14)
	local progress=Art.text(host,"Steps","LEFT ○   RIGHT ○",UDim2.new(0,4,1,-15),UDim2.new(1,-8,0,14),Art.Muted,10)
	Art.type(progress,"Supporting",true)
	local self=setmetatable({host=host,title=title,diagram=diagram,progress=progress},Quest)
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:update(self.stage or 0,self.phase,self.visible) end)
	return self
end
function Quest:update(stage,phase,visible,compactHint)
	if compactHint~=nil then self.compactHint=compactHint end
	self.stage,self.phase,self.visible=stage,phase,visible
	self.host.Visible=visible==true
	local height=self.host.AbsoluteSize.Y
	local compact=self.compactHint==true or height<60
	local heading=if height>=90 then 44 else 22
	self.diagram.Visible,self.progress.Visible=not compact,not compact
	self.title.Size=if compact then UDim2.new(1,-8,1,0) else UDim2.new(1,-8,0,heading)
	self.title.Position=UDim2.fromOffset(4,0)
	Art.type(self.title,"Body",compact)
	if compact then self.title.TextSize=12 end
	self.diagram.Position=UDim2.fromOffset(4,heading+2)
	self.diagram.Size=UDim2.new(1,-8,0,26)
	self.progress.Position,self.progress.Size=UDim2.new(0,4,1,-20),UDim2.new(1,-8,0,18)
	self.title.Text=if phase=="Settling" then (if compact then "Settling…" else "Settling · keep it low")
		elseif stage>=2 then (if compact then "Both sides ✓" else "Both sides done! Keep it low")
		elseif compact then "II + II → "..(if stage==0 then "LEFT" else "RIGHT")
		else "Match two IIs on "..(if stage==0 then "LEFT" else "RIGHT")
	if compact then
		self.title.TextWrapped=false
		local candidates
		local meaning
		if phase=="Settling" then
			candidates={"Settling…","Settling","Wait"};meaning="Settling · keep it low"
		elseif stage>=2 then
			candidates={"Both sides ✓","Sides done ✓","Done ✓","Done"};meaning="Both sides complete"
		elseif stage==0 then
			candidates={"II + II on LEFT","II+II LEFT","← II+II","←II+II"};meaning="Match two tier-II pieces on LEFT"
		else
			candidates={"II + II on RIGHT","II+II RIGHT","II+II →","II+II→"};meaning="Match two tier-II pieces on RIGHT"
		end
		self.title:SetAttribute("AccessibleLabel",meaning)
		local width=math.max(1,self.host.AbsoluteSize.X-8)
		for _,caption in ipairs(candidates) do
			self.title.Text=caption
			if Art.textWidth(self.title)<=width then break end
		end
	end
	if not compact then
		local titleH=Art.textHeight(self.title,self.host.AbsoluteSize.X-8,22)
		local progressH=Art.textHeight(self.progress,self.host.AbsoluteSize.X-8,18)
		local showDiagram=titleH+progressH+32<=height
		self.diagram.Visible=showDiagram
		self.title.Size=UDim2.new(1,-8,0,titleH)
		self.diagram.Position=UDim2.fromOffset(4,titleH+2)
		self.progress.Visible=titleH+progressH+4<=height
		self.progress.Position,self.progress.Size=UDim2.new(0,4,1,-progressH),UDim2.new(1,-8,0,progressH)
	end
	self.progress.Text=(if stage>=1 then "LEFT ✓" else "LEFT ○").."   "..(if stage>=2 then "RIGHT ✓" else "RIGHT ○")
end
return Quest
