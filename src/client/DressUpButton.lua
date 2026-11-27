-- Paint, Shine, Dress (PAINT-SHINE-DRESS-PLAN): the "Dress up" button on the pet focus view. A module of its own so
-- PetFocusUI keeps one line (`require(script.Parent.DressUpButton).attach(self)`, after buildStatsButton) while the
-- petting screen is being rebuilt there. It owns its layout: it sits on the focus card's row, just above the Stats
-- button, and follows that button and the screen size. Nothing is built without `callbacks.dressUp`; the button
-- shows only while the Alive `paint` switch is on (DressUp.on), so off is today's focus view exactly.
-- Dress up opens over the focus view and its Back returns there (architect review, answer 5). Gamepad: R1 while the
-- focus view owns input.
local ContextActionService=game:GetService("ContextActionService")
local Kit=require(script.Parent.DeckKit)
local DressUp=require(script.Parent.DressUp)
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Button={Gap=8,Size=Vector2.new(112,48),Key=Enum.KeyCode.ButtonR1}
local serial=0
-- Pure: where the button goes, given the Stats button's rect (x, y, w, h); nil when there is no Stats button.
function Button.place(stats,size)
	size=size or Button.Size
	if not stats then return nil end
	return {x=stats.x,y=math.max(0,stats.y-Button.Gap-size.Y),w=math.max(stats.w,size.X),h=size.Y}
end
function Button.attach(focus)
	local callbacks=focus and focus.callbacks
	if type(callbacks)~="table"or type(callbacks.dressUp)~="function"or not focus.panel then return nil end
	serial+=1
	local b=Kit.button(focus.panel,"DressUpButton",{text=UICopy.get("paint.door"),showGlyph=false,size=Button.Size,textSize=17,selectable=false})
	b.ZIndex=8;for _,d in ipairs(b:GetDescendants())do if d:IsA("GuiObject")then d.ZIndex+=7 end end
	b.Visible=false
	focus.dressUpButton=b
	local function open()
		if not focus.active or(focus.canOwnInput and not focus:canOwnInput())or not DressUp.on()then return false end
		return callbacks.dressUp()==true
	end
	local function layout()
		local stats=focus.statsButton
		local on=DressUp.on()and stats~=nil and stats.Visible
		local g=on and Button.place({x=stats.Position.X.Offset,y=stats.Position.Y.Offset,w=stats.Size.X.Offset,h=stats.Size.Y.Offset})
		b.Visible=g~=nil and g~=false
		if g then b.AnchorPoint=Vector2.zero;b.Position=UDim2.fromOffset(g.x,g.y);b.Size=UDim2.fromOffset(g.w,g.h)end
	end
	table.insert(focus.connections,b.Activated:Connect(open))
	if focus.statsButton then
		for _,property in ipairs({"Position","Size","Visible"})do
			table.insert(focus.connections,focus.statsButton:GetPropertyChangedSignal(property):Connect(layout))
		end
	end
	table.insert(focus.connections,focus.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
	pcall(function()table.insert(focus.connections,DressUp.changed():Connect(layout))end)
	local action="EggDropDressUp"..serial
	ContextActionService:BindActionAtPriority(action,function(_,state)
		if not focus.active or not b.Visible or(focus.canOwnInput and not focus:canOwnInput())then return Enum.ContextActionResult.Pass end
		if state==Enum.UserInputState.Begin then open()end
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value,Button.Key)
	b.Destroying:Connect(function()ContextActionService:UnbindAction(action)end)
	layout()
	return b
end
return Button
