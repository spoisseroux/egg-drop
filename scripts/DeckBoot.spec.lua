-- Studio Client. The Pocket Deck boot (UI-SPEC-2026-11-12 section 6) and the
-- faceplate shop's pure pane logic (5.5). Isolated instances only.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckBoot)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Boot=require(client.DeckBoot);local Shop=require(client.FaceplateShop)
 local Themes=require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
 local RunService=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_DeckBootSpec";gui.Parent=parent
 local ok,err=pcall(function()
  test("frame schedule matches boot-timing.json: 24 frames, 1.67 s",function()
   assert(#Boot.Starts==24 and Boot.TotalMs==1670)
   assert(Boot.frameAt(0)==0 and Boot.frameAt(79)==0 and Boot.frameAt(80)==1)
   assert(Boot.frameAt(810)==14 and Boot.frameAt(1260)==21 and Boot.frameAt(1669)==23)
   assert(Boot.frameAt(1670)==nil and Boot.frameAt(-1)==nil)
   local offset,size=Boot.rect(14);assert(offset==Vector2.new(424,456)and size==Vector2.new(212,152))
   assert(Boot.Sounds[1].cue=="deck_boot"and Boot.Sounds[1].atMs==810)
  end)
  test("skip is refused before 150 ms and accepted after",function()
   assert(not Boot.canSkip(0)and not Boot.canSkip(149)and Boot.canSkip(150))
  end)
  local now=0;local cues={}
  local audio={};function audio:play(name)table.insert(cues,{name=name,at=now});return false end
  function audio:fadeCue(name)table.insert(cues,{name="fade:"..name,at=now});return true end
  local host=Instance.new("Frame");host.Size=UDim2.fromOffset(848,608);host.Parent=gui
  local boot=Boot.new(host,{audio=audio,clock=function()return now end})
  local function step(ms)now+=ms/1000;RunService.Heartbeat:Wait();RunService.Heartbeat:Wait()end
  test("plays frames from one clock and fires deck_boot at 810 ms (no-op sound)",function()
   local done;boot:play({done=function(skipped)done={skipped=skipped}end})
   assert(host.Visible and boot.playing)
   step(400);assert(host:GetAttribute("BootFrame")==7)
   assert(#cues==0)
   step(420);assert(host:GetAttribute("BootFrame")==14)
   assert(#cues==1 and cues[1].name=="deck_boot")
   step(900);assert(not boot.playing and not host.Visible and done and done.skipped==false)
  end)
  test("any input from 150 ms skips to the end and fades deck_boot",function()
   table.clear(cues);now=0
   local done;boot:play({done=function(skipped)done=skipped end})
   step(100);assert(not boot:skip()and boot.playing,"skip before 150 ms must be ignored")
   step(200);assert(boot:skip())
   assert(not boot.playing and not host.Visible and done==true and host:GetAttribute("BootSkipped")==true)
   assert(cues[#cues].name=="fade:deck_boot")
  end)
  -- QA v735 D2: the deck's own power-on (Transition:reveal) always reaches its last frame.
  test("the deck power-on: dark while held, no input skips it, the last frame lingers into the fade",function()
   table.clear(cues);now=0
   boot:hold(Color3.new(.1,.1,.2))
   assert(host.Visible and not boot.playing and boot.fixed.ImageTransparency==1 and host.BackgroundColor3==Color3.new(.1,.1,.2),"held: a dark screen, no sprite")
   boot:release();assert(not host.Visible and boot.fixed.ImageTransparency==0 and host.BackgroundColor3==Color3.new(0,0,0),"released")
   boot:hold();local done
   boot:play({noSkip=true,linger=true,done=function(skipped)done={skipped=skipped}end})
   assert(boot.playing and boot.inputConnection==nil and boot.fixed.ImageTransparency==0,"playing with no skip listener")
   local seen={}
   for _=1,34 do step(50);local f=host:GetAttribute("BootFrame");if f and f>=0 then seen[f]=true end end
   for f=1,23 do assert(seen[f],"frame "..f.." was not shown")end
   assert(not boot.playing and done and done.skipped==false and host:GetAttribute("BootSkipped")==false,"ended on its own")
   assert(host.Visible,"the last frame stays up for the fade (no lit frame in between)")
   local finished
   task.spawn(function()finished=boot:fade(.2)end)
   step(100);assert(host.Visible and host.BackgroundTransparency>.2 and host.BackgroundTransparency<.8 and boot.fixed.ImageTransparency==host.BackgroundTransparency,"fading together")
   step(150);assert(finished==true and not host.Visible and host.BackgroundTransparency==0 and boot.fixed.ImageTransparency==0,"fade done; host reset for the next boot")
   -- A plain play (no linger) still hides at once, and a cancel during a lingering boot hides too.
   now=0;boot:play({noSkip=true,linger=true});step(300);boot:finish(false);assert(not host.Visible,"a cancelled power-on does not linger")
  end)
  test("Reduced Motion: frame 21 for 0.4 s with deck_boot at 0 ms",function()
   table.clear(cues);now=0
   boot:play({reduced=true})
   assert(host:GetAttribute("BootFrame")==21 and cues[1].name=="deck_boot"and cues[1].at==0)
   step(300);assert(boot.playing and host:GetAttribute("BootFrame")==21)
   step(150);assert(not boot.playing)
  end)
  test("a lost route ends the boot without skipping",function()
   now=0;local owned=true;local done
   boot:play({owns=function()return owned end,done=function(s)done=s end})
   step(50);owned=false;step(10)
   assert(not boot.playing and done==false)
  end)
  test("accent tints only the ink sheet",function()
   boot:setAccent(Color3.fromHex("#FF7AD9"))
   assert(boot.ink.ImageColor3==Color3.fromHex("#FF7AD9")and boot.fixed.ImageColor3==Color3.new(1,1,1))
   assert(boot.ink.ResampleMode==Enum.ResamplerMode.Pixelated)
  end)
  -- QA v2 R6.1: the phone handheld boots in its lit screen, inside the glass, and a
  -- faceplate skins the whole plate (full texture, not the old centre crop).
  test("phone handheld (812x354): the boot plays in the screen; the plate is the full faceplate",function()
   local Screen=require(client.DeckScreen);local Assets=require(client.DeckAssets)
   local size=Vector2.new(812,354);local aspect=(11+.8)/(19+.8)
   local root=Instance.new("Frame");root.Size=UDim2.fromOffset(size.X,size.Y);root.BackgroundTransparency=1;root.Parent=gui
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
   task.wait()
   local g=s.geometry;local o=root.AbsolutePosition
   local p=s.bootHost.AbsolutePosition-o
   assert(p.X==g.screen.x and p.Y==g.screen.y and s.bootHost.AbsoluteSize==Vector2.new(g.screen.w,g.screen.h),"boot in the screen rect")
   assert(g.screen.x>g.glass.x and g.screen.y>g.glass.y and g.screen.x+g.screen.w<g.glass.x+g.glass.w,"screen inside the glass")
   local id=Themes.Order[2]or Themes.Order[1]
   s:setTheme(id,Themes.ById[id])
   assert(s.plate.Image==Assets.Faceplate[id]and s.plate.ImageRectSize==Vector2.zero and s.plate.Visible,"full faceplate on the phone plate")
   assert(s.band.Visible and s.shoulders[1].Visible and s.led.Visible,"handheld shell drawn")
   root:Destroy()
  end)
  -- Faceplate shop pane logic (pure).
  test("shop pane: equipped, owned, buy, short, locked",function()
   local facts={totalWins=0,faceplates={"tidepool"}}
   assert(Shop.status("sherbet",{equipped="sherbet",wallet=0,facts=facts}).kind=="equipped")
   assert(Shop.status("stone",{equipped="sherbet",wallet=0,facts=facts}).kind=="owned")
   assert(Shop.status("tidepool",{equipped="sherbet",wallet=0,facts=facts}).kind=="owned")
   local buy=Shop.status("aurora_glass",{equipped="sherbet",wallet=60,facts=facts})
   assert(buy.kind=="buy"and buy.price==60 and buy.button=="★ Buy 60"and buy.enabled)
   local short=Shop.status("night_orb",{equipped="sherbet",wallet=106,facts=facts})
   assert(short.kind=="short"and short.text=="14 more Stars needed"and not short.enabled)
   local locked=Shop.status("gloaming",{equipped="sherbet",wallet=999,facts=facts})
   assert(locked.kind=="locked"and locked.button==nil)
   assert(select(1,Shop.tileStatus("honey",{equipped="sherbet",wallet=0,facts=facts}))=="🔒 Win 1")
  end)
  test("shop grid moves four ways without wrapping",function()
   assert(Shop.step(1,-1,0,16)==1 and Shop.step(1,0,-1,16)==1)
   assert(Shop.step(1,1,0,16)==2 and Shop.step(1,0,1,16)==5)
   assert(Shop.step(4,1,0,16)==4 and Shop.step(16,0,1,16)==16 and Shop.step(14,1,0,16)==15)
  end)
  test("every plate has a texture, accent and dark-well LCD palette",function()
   for _,id in ipairs(Themes.Order)do
    local t=Themes.ById[id]
    assert(string.match(t.texture,"^rbxassetid://%d+$"),id)
    local base=t.lcd.base;assert(base.R+base.G+base.B<.5,id.." well must be dark")
    assert(t.lcd.guide.R+t.lcd.guide.G+t.lcd.guide.B>base.R+base.G+base.B,id)
   end
  end)
 end)
 gui:Destroy()
 if not ok then error(err,0)end
 return cases
end
