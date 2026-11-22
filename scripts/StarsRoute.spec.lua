-- Studio Client. Where Back from the Get Stars page goes (StarsRoute, live fixes 2026-11-22).
-- Pure: fake screens only, nothing opens in the game.
-- Usage: require(PlayerScripts.Client.ZZSpecs.StarsRoute)(PlayerScripts.Client, PlayerGui)
return function(client)
 local Route=require(client.StarsRoute)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 -- A fake client: `open` is the set of open screens; `log` what was opened, in order.
 local function rig(open,options)
  options=options or {}
  local r={open=open,log={},machine=options.machine,allowed=true,refuse=options.refuse or {}}
  local function screen(kind,args)
   return{isOpen=function()return r.open[kind]==true end,
    capture=function()if options.uncapturable==kind then return nil end;return args end,
    open=function(got)
     table.insert(r.log,kind);r.got=got
     r.machine=nil -- every real open clears it
     if not r.refuse[kind]then r.open[kind]=true end
     return r.refuse[kind]and false or nil -- some real opens return nothing
    end}
  end
  r.deps={hubOpen=function()return r.open.machineHub==true end,canReopen=function()return r.allowed end,
   getMachineReturn=function()return r.machine end,setMachineReturn=function(id)r.machine=id end,
   wardrobe={isOpen=function()return r.open.wardrobe==true end,petId=function()return "blip"end,
    open=function(petId)table.insert(r.log,"wardrobe:"..petId);r.open.wardrobe=true end},screens={}}
  for _,kind in ipairs(Route.Order)do r.deps.screens[kind]=screen(kind,{kind=kind,petId="blip"})end
  function r.closeAll()table.clear(r.open);r.machine=nil end
  return r
 end
 test("the garden and the Pocket menu need no reopener (true, never nil)",function()
  assert(Route.capture(rig({}).deps)==true,"garden")
  assert(Route.capture(rig({machineHub=true}).deps)==true,"Pocket menu goes through machineReturn")
 end)
 test("every screen reopens with what it was showing, once everything is closed",function()
  for _,kind in ipairs(Route.Order)do
   local r=rig({[kind]=true});local back=Route.capture(r.deps)
   assert(type(back)=="function",kind);r.closeAll()
   assert(back()==true and #r.log==1 and r.log[1]==kind and r.got.kind==kind and r.got.petId=="blip",kind)
  end
 end)
 test("a screen that cannot come back as it was leaves the garden, not the one under it",function()
  for _,kind in ipairs({"hue","hub"})do
   assert(Route.capture(rig({[kind]=true},{uncapturable=kind}).deps)==true,kind)
  end
  local r=rig({hue=true,hub=true},{uncapturable="hue"})
  assert(Route.capture(r.deps)==true,"never falls through to Companions")
 end)
 test("the Wardrobe comes back on top of its base, and not at all if the base refuses",function()
  local r=rig({hub=true,wardrobe=true});local back=Route.capture(r.deps);r.closeAll()
  assert(back()and table.concat(r.log,",")=="hub,wardrobe:blip",table.concat(r.log,","))
  r=rig({hub=true,wardrobe=true},{refuse={hub=true}});back=Route.capture(r.deps);r.closeAll()
  assert(back()==false and table.concat(r.log,",")=="hub","no Wardrobe alone")
  r=rig({wardrobe=true});back=Route.capture(r.deps);r.closeAll()
  assert(back()and table.concat(r.log,",")=="wardrobe:blip")
 end)
 test("the way back to the Pocket menu survives, only for the screen it belongs to",function()
  for kind,machine in pairs(Route.Machine)do
   local r=rig({[kind]=true},{machine=machine});local back=Route.capture(r.deps);r.closeAll()
   assert(back()and r.machine==machine,kind.." keeps "..machine)
  end
  local r=rig({quests=true},{machine="companions"});local back=Route.capture(r.deps);r.closeAll()
  assert(back()and r.machine==nil,"a stale marker is not restored")
  r=rig({hub=true},{machine="companions",refuse={hub=true}});back=Route.capture(r.deps);r.closeAll()
  assert(back()==false and r.machine==nil,"nor for a screen that refused")
 end)
 test("the gate is asked again on Back: a round or a hatch result means nothing opens",function()
  local r=rig({book=true});local back=Route.capture(r.deps);r.closeAll();r.allowed=false
  assert(back()==false and #r.log==0)
 end)
 return{passed=#cases,cases=cases}
end
