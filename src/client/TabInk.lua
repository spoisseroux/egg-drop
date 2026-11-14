-- QA v2 R3.6 (shot 194541): tab labels vanished until the tab was clicked again.
-- Cause: Kit.tabs paints the selected label (and icon) with the bound role "ink"
-- (DeckArt.bind keeps a repaint for the theme), but paints the others with the
-- constant "soft", which writes the colour once and leaves the old "ink" binding in
-- place. The next DeckArt.applyTheme (equipping or previewing a faceplate, a theme
-- refresh) repainted every once-selected label ink-dark on the dark track: gone,
-- until a click re-ran select. The real fix belongs in DeckKit's paint (a constant
-- role must replace a binding on that property); until then this keeps every label's
-- binding current by painting both states as bound functions.
local Kit=require(script.Parent.DeckKit)
local TabInk={}

-- Pure: the colour a tab label (or icon) should have.
function TabInk.colorFor(selected)
 return if selected then Kit.color("ink")else Kit.Color.soft
end

-- Repaint every label / icon of a Kit.tabs api as bound functions for `index`.
function TabInk.paint(tabs,index)
 for i,label in ipairs(tabs.labels or {})do
  local on=i==index
  Kit.paint(label,"TextColor3",function()return TabInk.colorFor(on)end)
  local icon=tabs.icons and tabs.icons[i]
  if icon then Kit.tintIcon(icon,function()return TabInk.colorFor(on)end)end
 end
end

-- Wrap a Kit.tabs api once: every select (click, owner, Q / E) repaints bound.
-- Kit.tabs' own Activated handler calls api.select through the table, so it is covered.
function TabInk.guard(tabs)
 if not tabs or tabs.tabInkGuarded then return tabs end
 local select=tabs.select
 tabs.select=function(index)
  select(index)
  TabInk.paint(tabs,index)
 end
 tabs.tabInkGuarded=true
 TabInk.paint(tabs,tabs.selected or 1)
 return tabs
end

return TabInk
