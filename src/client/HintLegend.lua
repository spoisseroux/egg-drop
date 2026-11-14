-- QA v2 R2.5 slice (shot 194125, R4 owns the Wardrobe and Customize footers):
-- "what do these controls mean?" The footer row is built from R2's HintGlyphs for the
-- device in use (gamepad + / A / B / LB, keyboard WASD / ENTER / BKSP / Q/E; keyboard
-- A moves left, so a gamepad "A" chip was wrong there) and rebuilt when the device
-- changes. It is explained once: the first open of each screen this session shows
-- that device's legend sentence (UICopy input.legend.*) in place of the chips, which
-- come back after a few seconds or the first press. Touch has no chips: the legend
-- line stays. Phones have no footer (the first tap selects, the second acts).
local UserInputService=game:GetService("UserInputService")
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local Glyphs=require(script.Parent.HintGlyphs)
local Legend={Seconds=6,seen={}}

-- Pure: should the legend show on this open (first open of the screen this session)?
function Legend.shouldShow(seen,screen)return not(seen and seen[screen])end
-- Pure: the legend sentence for a device kind ("Gamepad" / "Keyboard" / "Touch").
function Legend.text(kind)return UICopy.get(Glyphs.legendKey(kind))end
-- footer: a frame (width x 24). rows: {{action,label},...} (HintGlyphs actions).
-- Returns an api: open() (once per screen per session), dismiss(), setLabel(action,
-- text), kind, rows (the built chips: {glyph,label,action,chip,text}).
function Legend.attach(footer,width,screen,rows)
 local api={shown=false,labels={},kind=nil,built={}}
 for _,row in ipairs(rows)do api.labels[row[1]]=row[2]end
 local hints=Kit.frame(footer,"Hints",nil,UDim2.new(),UDim2.fromOffset(width,24))
 local label=Kit.text(footer,"Small","","soft",{Name="HintLegend",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(width,24),
  TextTruncate=Enum.TextTruncate.AtEnd,Visible=false})
 api.hints,api.label=hints,label
 local function paint()
  local touch=api.kind=="Touch"
  local showLegend=api.shown or touch
  label.Visible=showLegend;hints.Visible=not showLegend
  label.Text=Legend.text(api.kind)
  footer:SetAttribute("HintLegend",showLegend);footer:SetAttribute("HintKind",api.kind)
 end
 function api.build(kind)
  api.kind=kind
  for _,child in ipairs(hints:GetChildren())do child:Destroy()end
  table.clear(api.built)
  local list={};for _,row in ipairs(rows)do table.insert(list,{row[1],api.labels[row[1]]or row[2]})end
  local x=0
  for _,row in ipairs(Glyphs.rows(list,kind))do
   local chip=Kit.glyph(hints,row[1],false,22,true);chip.Position=UDim2.fromOffset(x,1)
   local text=Kit.text(hints,"Small",row[2],"soft",{Position=UDim2.fromOffset(x+chip.Size.X.Offset+6,0),Size=UDim2.fromOffset(120,24),AutomaticSize=Enum.AutomaticSize.X})
   table.insert(api.built,{glyph=row[1],label=row[2],action=row[3],chip=chip,text=text})
   x+=chip.Size.X.Offset+6+Kit.measure(row[2],"Small",14).X+18
  end
  paint()
 end
 function api.setLabel(action,text)
  if api.labels[action]==text then return end
  api.labels[action]=text
  for _,b in ipairs(api.built)do if b.action==action then api.build(api.kind);return end end
 end
 local token=0
 function api.dismiss()
  token+=1
  if not api.shown then return false end
  api.shown=false;paint();return true
 end
 function api.open(force)
  if not force and not Legend.shouldShow(Legend.seen,screen)then return false end
  Legend.seen[screen]=true
  api.shown=true;paint()
  token+=1;local mine=token
  task.delay(Legend.Seconds,function()if token==mine then api.dismiss()end end)
  return true
 end
 api.build(Glyphs.kindOf(UserInputService:GetLastInputType()))
 local connection=UserInputService.LastInputTypeChanged:Connect(function(inputType)
  local kind=Glyphs.kindOf(inputType)
  if kind~=api.kind and footer.Parent then api.build(kind)end
 end)
 footer.Destroying:Connect(function()connection:Disconnect()end)
 return api
end

return Legend
