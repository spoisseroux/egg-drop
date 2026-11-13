-- Read-only production topology gate; call after settled Board, no purchase/reset.
return function(gui)
 local overlay=gui.Backdrop:FindFirstChild("TrayOverlay",true);local fx=overlay.MergeEffects.FieldFeedback
 local cases={}
 assert(fx.ClipsDescendants and not fx.Active and not fx.Selectable,"feedback must be passive and clipped")
 table.insert(cases,"passive tray-local feedback owner")
 local marks=0
 for _,node in ipairs(overlay:GetChildren())do
  if node.Name=="Mark"then assert(node.ZIndex>fx.ZIndex and node.Rotation==0,"feedback obscures upright tier marks");marks+=1 end
 end
 assert(marks>0,"a live piece is required for mark layering proof")
 table.insert(cases,"live upright marks above halo and fragments")
 local halo,fragments=0,0
 for _,node in ipairs(fx:GetChildren())do
  assert(not node.Active and not node.Selectable)
  if node.Name=="ChainFeedback"then assert(node:IsA("TextLabel")and not node.TextScaled)end
  if node.Name:match("^Halo")then halo+=1 elseif node.Name:match("^Fragment")then fragments+=1 end
  assert(node.ZIndex<overlay.DangerChip.ZIndex,"feedback obscures the danger chip")
 end
 assert(halo==4 and fragments==24,"unexpected feedback pool capacity")
 table.insert(cases,"four halos and twenty-four fragments below pressure words")
 return cases
end
