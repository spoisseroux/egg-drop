-- Daily stamp chip (QA v685 R10). The stamp card lives in Quests (QA v2 R3.8) and stays
-- there; this small chip on the Hatch eggs header shows it where Stars are spent:
-- "✓ 3/7" once today's stamp is on the card, "3/7" with a bright dot while today's
-- stamp is still waiting. A tap or click opens Quests on the daily tab.
--
-- Presentation only: it reads the same snapshot fields as StampCardView (`stamps`,
-- `stampCard`, `dailyAvailable`) and never claims anything. It sits left of the header's
-- wallet / help circle and narrows the title's box by its own width; when the title
-- would not fit beside it, the chip hides.
local Shared=game:GetService("ReplicatedStorage").Shared
local Kit=require(script.Parent.DeckKit)
local StampCardView=require(script.Parent.StampCardView)
local UICopy=require(Shared.UICopy)
local Chip={};Chip.__index=Chip
Chip.Gap=8      -- to the control on its right
Chip.TitleGap=12

-- Pure: {text, done, count, total} for a nursery snapshot.
function Chip.model(state)
 local card=StampCardView.model(state)
 local done=not card.available
 return{done=done,count=card.filled,total=StampCardView.Length,
  text=UICopy.get(if done then "stampChip.done"else "stampChip.open",{count=card.filled,total=StampCardView.Length})}
end
-- Pure: the chip's rect in a header of geometry `g` (Kit.headerGeometry), or nil when a
-- title `titleWidth` px wide starting at `left` would not fit beside it.
function Chip.place(g,width,left,titleWidth)
 local anchor=g.help or g.wallet or g.back
 local h=g.controlH
 local x=anchor.x-Chip.Gap-width
 if x-Chip.TitleGap<left+titleWidth then return nil end
 return{x=x,y=g.centerY-h/2,w=width,h=h}
end

-- header: a Kit.header api. options.onOpen(): open Quests. options.compact: phone sizes.
function Chip.new(header,options)
 options=options or {}
 local compact=options.compact==true
 local self=setmetatable({header=header,compact=compact,onOpen=options.onOpen},Chip)
 local button=Kit.node("TextButton",header.root,{Name="StampChip",Text="",AutoButtonColor=false,BackgroundTransparency=1,
  ZIndex=header.root.ZIndex+5,Selectable=false,Visible=false})
 button:SetAttribute("AccessibleLabel",UICopy.get("stampChip.label"))
 -- The visible pill is shorter than the 36 / 44 px hit rect.
 local pillH=if compact then 26 else 30
 local pill=Kit.frame(button,"Pill","well",UDim2.new(0,0,.5,-pillH/2),UDim2.new(1,0,0,pillH),999)
 local stroke=Kit.stroke(pill)
 local dot=Kit.frame(pill,"Today",nil,UDim2.new(0,9,.5,-4),UDim2.fromOffset(8,8),999)
 dot.BackgroundTransparency=0;dot.BackgroundColor3=Kit.Color.stars
 local label=Kit.text(pill,"Strong","","text",{Name="Count",Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=if compact then 13 else 14})
 Kit.fixedText(label) -- a counter (✓ 3/7): never sent for translation
 self.button,self.pill,self.stroke,self.dot,self.label,self.pillH=button,pill,stroke,dot,label,pillH
 button.Activated:Connect(function()if self.onOpen then self.onOpen()end end)
 return self
end
function Chip:set(state)
 local model=Chip.model(state)
 self.model=model
 local label=self.label
 label.Text=model.text
 -- Today's stamp waiting: a gold dot before the count and a gold rim; done: a quiet pill.
 self.dot.Visible=not model.done
 label.TextColor3=if model.done then Kit.Color.soft else Kit.Color.text
 self.stroke.Color=if model.done then Kit.Stroke.color else Kit.Color.stars
 self.stroke.Transparency=if model.done then Kit.Stroke.transparency else .35
 local textW=Kit.measure(model.text,"Strong",label.TextSize).X
 local lead=if model.done then 0 else 14
 label.Position=UDim2.fromOffset(lead/2,0)
 self.width=math.ceil(textW+lead+22)
 self.button:SetAttribute("StampDone",model.done);self.button:SetAttribute("StampCount",model.count)
 self:layout()
end
-- Call after the header lays itself out (it resets the title's box).
function Chip:layout()
 local header=self.header
 local g=header.geometry
 if not g or not self.width then self.button.Visible=false;return end
 local title=header.title
 local titleW=Kit.measure(title.Text,"Title",title.TextSize).X
 local rect=Chip.place(g,self.width,header.left or 24,titleW)
 self.button.Visible=rect~=nil
 if not rect then return end
 self.button.Position=UDim2.fromOffset(rect.x,rect.y);self.button.Size=UDim2.fromOffset(rect.w,rect.h)
 title.Size=UDim2.fromOffset(math.max(0,rect.x-Chip.TitleGap-title.Position.X.Offset),title.Size.Y.Offset)
end
function Chip:destroy()self.button:Destroy()end
return Chip
