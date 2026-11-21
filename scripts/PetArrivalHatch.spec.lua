-- Studio Client. Round 3 (Spencer 2026-11-20: "the bunny should have an awesome hatch animation
-- like the bear! make it epic"): the earned pet's arrival hatch host (PetArrivalHatch).
--  * Pure: the Bunny's result is Rare; the host clock runs past the tier line (Reduced Motion's
--    sting sits after the pet's 0.15 s fade); a press settles only once the receipt is ready;
--    B / Esc close a settled stage; every character key is sunk.
--  * Live: its own gui (DisplayOrder 16, full screen), the movement lock and the rail hold while
--    it is up, the clock held at zero until the scene is ready, the tier line and foley played
--    through the audio passed in, Meet / B close once and report which.
-- Usage: require(PlayerScripts.Client.ZZSpecs.PetArrivalHatch)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Hatch=require(client.PetArrivalHatch)
 local Rarity=require(client.HatchRarityCue)
 local Pose=require(client.HatchDisplayPose)
 local Stage=require(client.RevealStage)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-3)end
 local hatches={}
 local ok,problem=pcall(function()
  test("pure: the Bunny is Rare, the clock outlasts the tier line, skips wait for the receipt",function()
   local result,tier=Hatch.result("blip")
   assert(tier=="Rare"and result.rare==true and result.petId=="blip"and result.id=="arrival:blip")
   assert(select(2,Hatch.result("pip"))=="Common")
   local T=Rarity.timing("Rare","companion",false)
   assert(Hatch.clockEnd("Rare",false)==T.duration,"the full clock already covers the line")
   local calm=Hatch.clockEnd("Rare",true)
   assert(calm>Rarity.Reduced.stingAt and calm>Rarity.timing("Rare","companion",true).duration,"the calm sting still plays")
   assert(not Hatch.canSkip(0,"Rare",false)and not Hatch.canSkip(T.ready-.01,"Rare",false)and Hatch.canSkip(T.ready,"Rare",false))
   assert(T.ready==Pose.BearReady and Stage.LeadIn+Stage.InputAt==T.ready,"the pet clock is unchanged")
   local K=Enum.KeyCode
   assert(Hatch.keyAction(K.ButtonB,true)=="close"and Hatch.keyAction(K.Escape,false)=="settle"and Hatch.keyAction(K.W,true)=="sink"and Hatch.keyAction(K.Space,false)=="sink")
   for _,key in ipairs({K.Space,K.W,K.A,K.S,K.D,K.E,K.Up,K.Down,K.Left,K.Right,K.ButtonA,K.ButtonB,K.Return,K.Escape})do
    assert(table.find(Hatch.Keys,key),key.Name.." would reach the character")
   end
   assert(Hatch.DisplayOrder==16 and Hatch.Priority==Enum.ContextActionPriority.High.Value+830)
  end)
  test("live: own gui, movement lock, rail hold, clock held for the scene, tier line; Meet and B close once",function()
   local Lock=require(client.MovementLock).shared()
   local Rail=require(client.NotificationRail)
   local played={};local audio={deviceActive=true}
   function audio:play(name)table.insert(played,name);return false end
   function audio:stopOwner()end
   local hatch=Hatch.new(parent,audio);table.insert(hatches,hatch)
   assert(hatch.gui.DisplayOrder==16 and hatch.gui.IgnoreGuiInset and hatch.gui.ScreenInsets==Enum.ScreenInsets.None and not hatch.gui.Enabled)
   local done={}
   assert(hatch:play("blip",{onDone=function(meet)table.insert(done,meet)end}))
   assert(hatch:isOpen()and hatch.gui.Enabled and hatch.stage and hatch.stage.jackpot,"the Bunny's stage is a jackpot")
   assert(Lock:holds(Hatch.LockReason)and Hatch.railHeld()and Rail.held(),"movement locked, rail held")
   assert(not hatch:play("blip",{}),"one at a time")
   -- Drive both clocks by hand (no frames run inside this case).
   if hatch.clock then hatch.clock:Disconnect();hatch.clock=nil end
   local stage=hatch.stage
   if stage.connection then stage.connection:Disconnect();stage.connection=nil end
   hatch.scene.ready=false;hatch:step(.1);assert(hatch.age==0,"held until the scene is ready")
   hatch.scene.ready=true
   for _=1,30 do hatch:step(.1);stage:step(.1)end
   assert(near(hatch.age,3.0,1e-6)and table.find(played,"rarity_rare")and table.find(played,"egg_wobble")and table.find(played,"egg_crack_glint"),"the tier line and foley")
   assert(not table.find(played,"reveal_hush")and not table.find(played,"new_best")and table.find(played,"tag_slam"))
   assert(stage:isSettled()and stage.lead.done)
   assert(stage:confirm()and #done==1 and done[1]==true,"Meet")
   assert(not hatch:isOpen()and not Lock:holds(Hatch.LockReason)and not Hatch.railHeld()and not hatch.gui.Enabled and hatch.stage==nil)
   assert(not hatch:finish(true)and #done==1,"once")
   -- B / Esc on a settled stage closes without Meet.
   assert(hatch:play("blip",{onDone=function(meet)table.insert(done,meet)end}))
   assert(hatch:finish(false)and done[2]==false and not Lock:holds(Hatch.LockReason))
   hatch:destroy()
  end)
 end)
 for _,hatch in ipairs(hatches)do pcall(function()hatch:destroy()end)end
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
