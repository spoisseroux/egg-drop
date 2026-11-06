local Art=require(script.Parent.DeckArt)
local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
local Quest={};Quest.__index=Quest
function Quest.new(parent)
	local host=Art.frame(parent,"ActiveQuest",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),parent.ZIndex+3)
	host.ClipsDescendants=true;Art.corner(host,8)
	local title=Art.text(host,"Instruction","Match on LEFT",UDim2.fromOffset(4,1),UDim2.new(1,-8,0,21),Art.Silver,14)
	Art.fitText(title,15,9,0,true)
	local diagram=Art.frame(host,"PairDiagram",Art.Ink,UDim2.fromOffset(4,24),UDim2.new(1,-8,0,28));diagram.BackgroundTransparency=1
	for i,entry in ipairs({{.18,2},{.48,2},{.84,3}})do
		local ball=Art.frame(diagram,"Piece"..i,Config.Tiers[entry[2]].color,UDim2.new(entry[1],-11,.5,-11),UDim2.fromOffset(22,22))
		Art.corner(ball,20);Art.shade(ball,1,.7)
		Art.fitText(Art.text(ball,"Mark",Config.Tiers[entry[2]].mark,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Art.Ink,11),11,8,0)
	end
	Art.text(diagram,"Plus","+",UDim2.new(.33,-5,0,4),UDim2.fromOffset(10,20),Art.Silver,14)
	Art.text(diagram,"Arrow","→",UDim2.new(.65,-6,0,4),UDim2.fromOffset(14,20),Art.Silver,14)
	local progress=Art.text(host,"Steps","LEFT ○   RIGHT ○",UDim2.new(0,4,1,-15),UDim2.new(1,-8,0,14),Art.Muted,10)
	Art.fitText(progress,11,8,0)
	return setmetatable({host=host,title=title,diagram=diagram,progress=progress},Quest)
end
function Quest:update(stage,phase,visible)
	self.host.Visible=visible
	local compact=self.host.AbsoluteSize.Y<60
	self.diagram.Visible,self.progress.Visible=not compact,not compact
	self.title.Size=if compact then UDim2.new(1,-8,1,-2)else UDim2.new(1,-8,0,21)
	self.title.Text=if phase=="Settling"then "Settling · keep it low"elseif stage>=2 then "Both sides done! Keep it low"elseif compact then "Match two IIs · "..(if stage==0 then "LEFT"else"RIGHT")else "Match two IIs on "..(if stage==0 then "LEFT"else"RIGHT")
	self.progress.Text=(if stage>=1 then "LEFT ✓"else"LEFT ○").."   "..(if stage>=2 then "RIGHT ✓"else"RIGHT ○")
end
return Quest
