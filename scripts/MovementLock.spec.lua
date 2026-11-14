-- QA v2 R2.1 / R2.2: one ref-counted movement lock. Fake controls only (the shared lock
-- and the real PlayerModule are never touched): reasons count once, the last release
-- enables, a walk held when the lock closes is cleared, controls that were already
-- disabled are never enabled by us, and ModalCursor's open edge drives "modal".
-- Usage: require(PlayerScripts.Client.ZZSpecs.MovementLock)(PlayerScripts.Client, PlayerGui)
return function(client,_parent)
 local Lock=require(client.MovementLock)
 local Cursor=require(client.ModalCursor)
 local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 local function fakeControls(enabled)
  local c={controlsEnabled=enabled~=false,disables=0,enables=0}
  function c:Disable()self.controlsEnabled=false;self.disables+=1 end
  function c:Enable()self.controlsEnabled=true;self.enables+=1 end
  return c
 end
 -- A held walk: a move vector the controls would keep feeding until stopped.
 local function fixture(enabled)
  local f={controls=fakeControls(enabled),walk=Vector3.new(0,0,-1),velocity=Vector3.new(0,0,-16)}
  f.lock=Lock.new({controls=function()return f.controls end,stop=function()f.walk=Vector3.zero;f.velocity=Vector3.zero end})
  return f
 end
 test("reasons are reference counted; only the last release enables",function()
  local f=fixture()
  assert(f.lock:acquire("modal")==true and f.controls.disables==1 and not f.controls.controlsEnabled)
  assert(f.lock:acquire("focus")==false and f.lock:count()==2 and f.controls.disables==1)
  assert(f.lock:acquire("modal")==false and f.lock:count()==2,"same reason counts once")
  assert(f.lock:release("modal")==false and f.controls.enables==0 and not f.controls.controlsEnabled,"focus still holds")
  assert(f.lock:release("modal")==false and f.lock:count()==1,"double release is a no-op")
  assert(f.lock:release("focus")==true and f.controls.enables==1 and f.controls.controlsEnabled and not f.lock:isLocked())
  assert(f.lock:release("focus")==false and f.controls.enables==1)
 end)
 test("a walk held when the lock closes is cleared at once",function()
  local f=fixture()
  f.lock:set("modal",true)
  assert(f.walk==Vector3.zero and f.velocity==Vector3.zero,"held move vector and velocity cleared")
  assert(f.lock.stops==1)
  f.lock:set("modal",false)
  assert(f.walk==Vector3.zero,"release never restores the old walk")
 end)
 test("controls disabled by someone else are never enabled by the lock",function()
  local f=fixture(false)
  f.lock:acquire("deck");f.lock:release("deck")
  assert(f.controls.enables==0 and f.controls.disables==0 and not f.controls.controlsEnabled)
 end)
 test("enforce re-disables controls enabled behind the lock, and only while held",function()
  local f=fixture()
  assert(f.lock:enforce()==false,"idle lock enforces nothing")
  f.lock:acquire("modal");f.controls:Enable();f.walk=Vector3.new(1,0,0)
  assert(f.lock:enforce()==true and not f.controls.controlsEnabled and f.walk==Vector3.zero)
  assert(f.lock:enforce()==false,"already disabled")
  f.lock:release("modal");assert(f.controls.controlsEnabled)
 end)
 test("a lock taken before the PlayerModule exists closes on the first enforce",function()
  local f=fixture();local present=false
  local lock=Lock.new({controls=function()return if present then f.controls else nil end,stop=function()f.walk=Vector3.zero end})
  lock:acquire("deck");assert(f.controls.disables==0)
  present=true;assert(lock:enforce()==true and f.controls.disables==1)
  lock:release("deck");assert(f.controls.enables==1 and f.controls.controlsEnabled)
 end)
 test("ModalCursor's open edge takes and drops the modal reason",function()
  local f=fixture();local open=false
  local cursor=Cursor.new({isOpen=function()return open end,movement=f.lock})
  cursor:step();assert(not f.lock:holds("modal"))
  open=true;cursor:step();assert(f.lock:holds("modal")and not f.controls.controlsEnabled and f.walk==Vector3.zero)
  cursor:step();assert(f.controls.disables==1,"no re-disable per frame")
  f.lock:acquire("focus");open=false;cursor:step()
  assert(not f.lock:holds("modal")and f.lock:holds("focus")and not f.controls.controlsEnabled,"focus keeps the avatar still")
  f.lock:release("focus");assert(f.controls.controlsEnabled)
  open=true;cursor:step();cursor:destroy()
  assert(not f.lock:holds("modal")and f.controls.controlsEnabled,"destroy lets go")
 end)
 return{passed=#cases,cases=cases}
end
