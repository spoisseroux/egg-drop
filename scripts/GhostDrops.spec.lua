-- Deck network S5: ghost lifetimes with a fake host (no deck needed).
-- Studio: require(PlayerScripts.Client.ZZSpecs.GhostDrops)(PlayerScripts.Client, gui)
return function(client,gui)
 local Ghosts=require(client.GhostDrops)
 local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function host()
  local h={views={},added={},removed={},rebound={},drawn={}}
  h.constants=setmetatable({bounce=.64},{__index=Config})
  h.resetId=function()return 1 end
  h.canShow=function()return true end
  h.add=function(source)h.views[source]=true;table.insert(h.added,source)end
  h.remove=function(source)h.views[source]=nil;table.insert(h.removed,source)end
  h.rebind=function(source,eggId)table.insert(h.rebound,eggId)end
  h.hasView=function(eggId)return h.drawn[eggId]==true end
  h.obstacles=function(out)table.clear(out)end
  h.onContact=function()end
  return h
 end
 local made={}
 local function ghosts(h)local g=Ghosts.new(h);table.insert(made,g);return g end
 local function part(y)
  local p=Instance.new("Part");p.Anchored=true;p.Position=Vector3.new(0,y,0);p.Parent=gui;return p
 end
 local ok,problem=pcall(function()
  test("a late ack (the server ball is already drawn) fades the ghost instead of binding it",function()
   local h=host();local g=ghosts(h)
   local ghost=g:spawn(1,.5,1,os.clock())
   assert(ghost and h.views[ghost.source],"spawned and drawn")
   h.drawn[42]=true -- its Part and first sample beat the ack: the real view exists
   g:ack(1,true,42)
   assert(#h.rebound==0,"never rebinds the drawn id to the ghost")
   assert(not g:holds(42)and ghost.state=="fading"and g.stats.late==1,"fades, holds nothing")
   g:step(os.clock()+Ghosts.FadeSeconds+.05)
   assert(not h.views[ghost.source]and g:count()==0,"removed after the fade")
  end)
  test("a held server ball is reported as holding until its handoff, then shown once",function()
   local h=host();local g=ghosts(h)
   local ghost=g:spawn(2,.5,1,os.clock())
   g:ack(2,true,43)
   assert(h.rebound[1]==43 and g:holds(43))
   local server=part(10)
   local shown=0
   assert(g:holdSpawn(43,server,function()shown+=1 end),"held for the ghost")
   assert(g:holding(server),"boardContentReady must skip it")
   -- Ghost rests at the floor; the drawn server ball reaches it: blend, then hand over.
   ghost.flight.resting,ghost.state=true,"resting";ghost.flight.x,ghost.flight.y=0,.72
   server.Position=Vector3.new(0,.72,0)
   local now=os.clock()
   g:step(now);g:step(now+Ghosts.BlendSeconds+.02)
   assert(shown==1 and not g:holding(server)and g:count()==0 and g.stats.handoffs==1,"handed over once: shown="..shown)
   server:Destroy()
  end)
  test("a server ball that merges before the handoff takes the ghost and shows nothing",function()
   local h=host();local g=ghosts(h)
   g:spawn(3,.5,1,os.clock());g:ack(3,true,44)
   local server=part(9);local shown=0
   g:holdSpawn(44,server,function()shown+=1 end)
   assert(g:serverGone(44)and g:count()==0 and not g:holding(server))
   assert(shown==0,"the Part left: its view is never shown")
   server:Destroy()
  end)
  test("two hosts' ghosts step independently: destroying one never stops the other",function()
  local h1,h2=host(),host();local g1,g2=Ghosts.new(h1),Ghosts.new(h2)
  table.insert(made,g2)
  local ghost=g2:spawn(8,.5,1,os.clock());g2:ack(8,false) -- fading
  g1:destroy()
  local t=os.clock()
  while g2:count()>0 and os.clock()-t<1 do game:GetService("RunService").RenderStepped:Wait()end
  assert(g2:count()==0 and not h2.views[ghost.source],"the survivor's render step still runs")
 end)
 test("at most MaxLive ghosts at once; the next tap shows no ghost",function()
  local h=host();local g=ghosts(h)
  for token=20,19+Ghosts.MaxLive do assert(g:spawn(token,.5,1,os.clock()))end
  assert(g:spawn(99,.5,1,os.clock())==nil and g:count()==Ghosts.MaxLive and g.stats.capped==1)
  g:clear()
 end)

 test("an unknown tier spawns nothing",function()
   local h=host();local g=ghosts(h)
   assert(g:spawn(4,.5,99,os.clock())==nil and g:spawn(5,.5,nil,os.clock())==nil and #h.added==0)
  end)
  test("a refused ack fades; clear removes every ghost and releases held views",function()
   local h=host();local g=ghosts(h)
   local a=g:spawn(6,.5,1,os.clock());g:ack(6,false)
   assert(a.state=="fading")
   g:spawn(7,.5,1,os.clock());g:ack(7,true,45)
   local server=part(8);local shown=0
   g:holdSpawn(45,server,function()shown+=1 end)
   g:clear()
   assert(g:count()==0 and shown==1 and not g:holding(server))
   server:Destroy()
  end)
 end)
 for _,g in ipairs(made)do g:destroy()end
 assert(ok,problem)
 return {passed=#cases,cases=cases}
end
