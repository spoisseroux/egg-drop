-- Footer hint glyphs per device (QA v2 R2.5, the ControllerFocus slice). Menu footers
-- showed gamepad glyphs to everyone ("A Hatch" while the keyboard's A key moves left).
-- One table maps each footer action to the chip its device actually uses, so every
-- footer reads the same: gamepad + / A / B / LB, keyboard WASD / ENTER / BKSP / Q/E,
-- touch none (the row is tapped). The keys are the menus' real ContextAction bindings
-- (init.client: Space/Return/KeypadEnter + ButtonA confirm, Backspace + ButtonB back,
-- Q/E + LB/RB tabs, arrows/WASD + D-pad browse). Words: UICopy "input.action.*",
-- the once-only legend line: UICopy "input.legend.<device>".
-- R1 (Hatch eggs footer) and R4 (Wardrobe / Customize footers) build their chips with
-- HintGlyphs.rows({{"browse",label},{"confirm",label},{"back",label}}, kind).
local Glyphs={}

Glyphs.Actions={"browse","confirm","back","tab"}
Glyphs.Map={
 Gamepad={browse="+",confirm="A",back="B",tab="LB"},
 Keyboard={browse="WASD",confirm="ENTER",back="BKSP",tab="Q/E"},
 Touch={},
}
-- The legend line for each device (UICopy keys).
Glyphs.Legend={Gamepad="input.legend.gamepad",Keyboard="input.legend.keyboard",Touch="input.legend.touch"}

-- "Gamepad" | "Keyboard" | "Touch" from a UserInputType (nil = keyboard and mouse).
function Glyphs.kindOf(inputType)
 if inputType==nil then return "Keyboard"end
 if inputType==Enum.UserInputType.Touch then return "Touch"end
 if string.match(inputType.Name,"^Gamepad")then return "Gamepad"end
 return "Keyboard"
end

-- The chip text for `action` on device `kind`, or nil when that device shows no chip.
function Glyphs.glyph(action,kind)
 local map=Glyphs.Map[kind or "Keyboard"]or Glyphs.Map.Keyboard
 return map[action]
end

-- The confirm chip is the accent one on every device.
function Glyphs.accent(action)return action=="confirm"end

-- {{action,label},...} -> {{glyph,label},...} for `kind`; rows without a chip are dropped
-- (touch footers keep only the legend line).
function Glyphs.rows(rows,kind)
 local out={}
 for _,row in ipairs(rows)do
  local glyph=Glyphs.glyph(row[1],kind)
  if glyph then table.insert(out,{glyph,row[2],row[1]})end
 end
 return out
end

-- UICopy key of the line explaining this device's chips.
function Glyphs.legendKey(kind)return Glyphs.Legend[kind or "Keyboard"]or Glyphs.Legend.Keyboard end

return Glyphs
