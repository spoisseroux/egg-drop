-- Data-driven wearable slots and staged features (PET-STYLE-GUIDE.md "Character creation").
-- Pure: reads a rig definition's generated `attachments`, `slots`, `features` and `exclusions`.
-- A blocked item is hidden, never unequipped; an earned feature stage is kept while hidden.
--
-- Wearables are a map slotKey -> item id. slotKey is the slot name, or slot..side for
-- per-side slots ("EarPiercingL"). Items and their meshes come from the definition, so
-- granting an item later only needs the saved map; nothing here knows a specific item.
local Rules={}
local MaxStage=5
local function stage(n)return if type(n)=="number"and n==n and n%1==0 and n>=0 and n<=MaxStage then n else 0 end
local function list(definition)return type(definition)=="table"and type(definition.attachments)=="table"and definition.attachments or {}end
local function keyOf(definition,a)
 local slot=(definition.slots or {})[a.slot]
 if slot and slot.perSide and a.side then return a.slot..a.side end
 return a.slot
end
-- Every equippable item on this rig: {key, slot, side, item, parts={names}}.
function Rules.items(definition)
 local byKey,order={},{}
 for _,a in ipairs(list(definition))do if a.item then
  local key=keyOf(definition,a);local id=key.."="..a.item
  local row=byKey[id]
  if not row then row={key=key,slot=a.slot,side=if key~=a.slot then a.side else nil,item=a.item,parts={}};byKey[id]=row;table.insert(order,row)end
  table.insert(row.parts,a.name)
 end end
 return order
end
-- Drops unknown slots and items, so a stale or future save never errors on this rig.
function Rules.normalize(definition,wearables)
 local result={};if type(wearables)~="table"then return result end
 local known={};for _,row in ipairs(Rules.items(definition))do known[row.key.."="..row.item]=true end
 for key,item in pairs(wearables)do if type(key)=="string"and type(item)=="string"and known[key.."="..item]then result[key]=item end end
 return result
end
function Rules.signature(wearables)
 local rows={};for key,item in pairs(wearables or {})do table.insert(rows,key.."="..item)end
 table.sort(rows);return table.concat(rows,";")
end
-- True when the rig has authored meshes for every stage of a feature.
function Rules.hasFeature(definition,id)
 local feature=type(definition)=="table"and type(definition.features)=="table"and definition.features[id]
 if not feature then return false end
 local found={}
 for _,a in ipairs(list(definition))do if a.feature==id then found[a.stage]=true end end
 for n=1,feature.stages or MaxStage do if not found[n]then return false end end
 return true
end
local function flagsOf(definition,key,item)
 local flags={}
 for _,a in ipairs(list(definition))do if a.item==item and keyOf(definition,a)==key and a.flags then
  for flag,on in pairs(a.flags)do if on then flags[flag]=true end end
 end end
 return flags
end
-- Resolve what shows. featureStages are the shown stages (0..earned) per feature id.
-- Returns {show={attachment defs}, suppress={piece=true}, blocked={target=true},
--  stages={id=shown stage after blocking}, charmLift=studs at rig size, charmCenterHidden=bool}.
function Rules.resolve(definition,featureStages,wearables)
 wearables=Rules.normalize(definition,wearables);featureStages=type(featureStages)=="table"and featureStages or {}
 local blocked={}
 for _,rule in ipairs(type(definition)=="table"and definition.exclusions or {})do
  for key,item in pairs(wearables)do
   local slot=key
   for _,a in ipairs(list(definition))do if a.item==item and keyOf(definition,a)==key then slot=a.slot;break end end
   if slot==rule.blocker then
    local flags=flagsOf(definition,key,item)
    local applies=(rule.whenFlag==nil or flags[rule.whenFlag]==true)and(rule.unlessFlag==nil or flags[rule.unlessFlag]~=true)
    if applies then for _,target in ipairs(rule.hides)do blocked[target]=true end end
   end
  end
 end
 local occupied={};for key in pairs(wearables)do
  for _,a in ipairs(list(definition))do if keyOf(definition,a)==key and a.item==wearables[key]then occupied[a.slot]=true;break end end
 end
 local stages={}
 for id,feature in pairs(type(definition)=="table"and definition.features or {})do
  local n=stage(featureStages[id])
  -- One item per slot: a wearable in the feature's slot (a backpack on Back) hides the feature.
  if blocked[feature.slot]or occupied[feature.slot]then n=0 end
  stages[id]=n
 end
 local show,suppress,neutral={},{},{}
 for _,a in ipairs(list(definition))do
  local visible=false
  if a.feature then visible=stages[a.feature]~=nil and stages[a.feature]==a.stage
  elseif a.item then
   visible=wearables[keyOf(definition,a)]==a.item and not blocked[a.slot]and not(a.anchor and blocked[a.slot.."@"..a.anchor])
  end
  if visible then
   table.insert(show,a)
   -- A neutralOnly swap (the Blep) replaces only the neutral frame: the default stays for
   -- every other expression, so it is marked rather than suppressed.
   for _,piece in ipairs(a.replaces or {})do if a.flags and a.flags.neutralOnly then neutral[piece]=true else suppress[piece]=true end end
  end
 end
 local lift=0;local rule=type(definition)=="table"and definition.charmLift
 if rule and(stages[rule.feature]or 0)>=rule.fromStage then lift=rule.lift end
 return {show=show,suppress=suppress,neutral=neutral,blocked=blocked,stages=stages,wearables=wearables,charmLift=lift,
  charmCenterHidden=blocked.Charm==true or blocked["Charm@CharmCenter"]==true}
end
-- Anchor frame in rig space (runtime axes), scaled. Surface anchors: +Y leaves the surface.
function Rules.anchorFrame(definition,name,scale)
 local frame=type(definition)=="table"and definition.anchorFrames and definition.anchorFrames[name]
 if not frame then
  local p=type(definition)=="table"and definition.anchors and definition.anchors[name]
  if not p then return nil end
  return CFrame.new(p[1]*(scale or 1),p[2]*(scale or 1),p[3]*(scale or 1)),nil
 end
 local p,r=frame.position,frame.rotation;local s=scale or 1
 return CFrame.new(p[1]*s,p[2]*s,p[3]*s,r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9]),frame.channel
end
return table.freeze(Rules)
