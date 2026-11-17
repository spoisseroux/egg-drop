-- Deck network S4: the client drop intent (throttle, not-ready latch, ack, tap sound).
-- Studio: require(PlayerScripts.Client.ZZSpecs.DropIntent)(PlayerScripts.Client, gui).
-- Offline: luau scripts/run_pure_spec.luau.
return function(client,_,modules)
 modules=modules or {}
 local Intent=modules.DropIntent or require(client.DropIntent)
 local cases={};local function test(name,run)run();table.insert(cases,name)end

 test("a tap sends at once, then the latch holds until the ack and a ready board",function()
  local i=Intent.new()
  assert(i:allow(0))
  local token=i:send(0,1)
  assert(token==1 and i.latched)
  assert(not i:allow(.3),"latched before the ack")
  assert(i:ack(token,true,false)=="accepted")
  assert(not i:allow(.35),"still latched: the board is not ready (contact gate)")
  i:fieldReady(true)
  assert(i:allow(.5),"ready again")
 end)

 test("an ack that finds the board ready opens the latch at once (no contact gate)",function()
  local i=Intent.new();local token=i:send(0,1)
  assert(i:ack(token,true,true)=="accepted"and i:allow(.25))
 end)

 test("own throttle: taps under the drop interval are ignored",function()
  local i=Intent.new();local token=i:send(0,1);i:ack(token,true,true)
  local ok,why=i:allow(.15);assert(not ok and why=="Throttled")
  assert(i:allow(.21))
 end)

 test("a refusal opens the latch, drops the prediction and its tap sound",function()
  local i=Intent.new();local token=i:send(0,5)
  assert(i:shownDrops(4)==5,"the tap shows its drop")
  assert(i:ack(token,false,true)=="refused")
  assert(i:shownDrops(4)==4,"back to the server's count")
  assert(not i:consumeTapSound(.1),"the refused tap's sound is not credited to a later drop")
  assert(i:allow(.25))
 end)

 test("a lost ack never locks the deck (latch timeout)",function()
  local i=Intent.new();i:send(0,1)
  assert(not i:allow(1))
  assert(i:shownDrops(0)==1,"the tap's count shows while the ack is out")
  assert(i:allow(Intent.LatchTimeout+.01)and i.stats.timeouts==1)
  assert(i:shownDrops(0)==0,"a lost ack stops the dispenser over-counting")
 end)

 test("the Drops attribute skips the sound once per tap that played it",function()
  local i=Intent.new();local token=i:send(0,1);i:ack(token,true,true)
  assert(i:consumeTapSound(.3),"this drop's sound was the tap's")
  assert(not i:consumeTapSound(.4),"a later drop (Welcome demo) plays its own")
  i:send(1,2)
  assert(not i:consumeTapSound(1+Intent.TapSoundWindow+.1),"a stale tap does not swallow a sound")
 end)

 test("stale or unknown acks are ignored; tokens stay in 1-65535",function()
  local i=Intent.new()
  assert(i:ack(42,true,true)==nil and i:ack("x",true,true)==nil)
  i.token=65535;local token=i:send(0,1);assert(token==1,"wraps to 1, never 0")
 end)

 test("a reset or round end forgets pending taps",function()
  local i=Intent.new();i:send(0,3);i:clear()
  assert(not i.latched and i:shownDrops(0)==0 and next(i.pending)==nil)
 end)

 test("the shown count follows the server once it catches up",function()
  local i=Intent.new();local token=i:send(0,7)
  assert(i:shownDrops(6)==7);i:ack(token,true,true)
  assert(i:shownDrops(7)==7 and i.predicted==nil)
 end)

 test("ghost gate: the touch-down opens the latch without waiting for FieldReady",function()
  local i=Intent.new();i.ghostGate=true
  local token=i:send(0,1)
  assert(not i:allow(.25),"in flight")
  i:contact(token)
  assert(i:allow(.3),"touched down locally")
 end)

 test("ghost gate: the gate time opens it too; an older token's contact does not",function()
  local i=Intent.new();i.ghostGate=true
  local first=i:send(0,1);i:ack(first,true,false)
  i:fieldReady(true)
  local second=i:send(1,2)
  i:contact(first)
  assert(not i:allow(1.25),"the old ghost's touch-down is not this drop's")
  assert(i:allow(1+Intent.GateSeconds+.01),"the contact gate's time has passed")
 end)

 test("readyAhead: only for our own recent drop, only with the ghost gate",function()
  local i=Intent.new()
  assert(not i:readyAhead(0),"no ghost gate: never")
  i.ghostGate=true
  assert(not i:readyAhead(0),"no drop sent yet")
  local token=i:send(0,1);i:contact(token)
  assert(i:readyAhead(.3),"our drop's gate, already open")
  assert(not i:readyAhead(Intent.AheadSeconds+.1),"too long ago: FieldReady=false means something else")
 end)

 return {passed=#cases,cases=cases}
end
