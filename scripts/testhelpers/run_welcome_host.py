"""Run actual Welcome host functions with deterministic task/save boundary fakes."""
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[2]
s=(ROOT/'src/server/init.server.lua').read_text(encoding='utf-8')
drop=s[s.index('local function acceptedDrop('):s.index('request.OnServerEvent:Connect(',s.index('local function acceptedDrop('))]
grant=s[s.index('grantWelcome=function('):s.index('\n-- Pet Park (FeatureFlags.Park',s.index('grantWelcome=function('))]
status=s[s.index('local function settledWelcomeStatus('):s.index('local function acceptedDrop(')]
pre='''
local Welcome=require("../src/server/WelcomeState")
local boards={};local player={Parent=true};local calls,acks,sources,jobs={}, {}, {}, {}
local function hasPet(b)return b.nursery.owned==true end
local function inventory(b)return b.nursery.owned end
local NurseryCatalog={isOwned=function(value,pet)return value==true and pet=="pip"end}
local function canProgress(b)return b.ready==true end
local function publishWelcome()end
local function publishState()end
local function publishNursery()end
local function publishCompanion()end
local Progress={chargeHatch=function(profile,amount)
 assert(hasPet(boards[player]),"legacy rank write before atomic ownership proof")
 profile.charge+=amount;profile.rank=1
end}
local Nursery={}
local implementation
function Nursery.grantStarter(handle)table.insert(calls,handle);return implementation(handle)end
local Economy={source=function(_,amount,balance)table.insert(sources,{amount,balance})end}
local welcomeResult={FireClient=function(_,_,packet)table.insert(acks,packet)end}
local task={spawn=function(fn)table.insert(jobs,coroutine.create(fn))end,wait=function()coroutine.yield()end}
local Pets={byId={pip={charge=6}}}
local Simulation={drop=function(sim,aim)
 sim.attempts=(sim.attempts or 0)+1
 if sim.reject then return false end
 sim.drops+=1;sim.lastAim=aim;return true
end,canDrop=function()return true end}
local Config={DropInterval=.5}
local Daily={dayOf=function()return "5"end}
local RunDay={onDrop=function()return "5"end}
local typeof=type
local grantWelcome
'''
tests='''
local passed=0
local function fixture()
 calls,acks,sources,jobs={},{},{},{}
 local w=Welcome.new(1);for i=1,6 do w:step(.5,true)end
 local board={nursery={owned=false,state={nectar=0},adapter={now=function()return 0 end}},profile={rank=0,charge=0},profileReady=true,
  runSequence=1,welcome=w,mode="Board",sim={drops=0},round={over=false},ready=true,lastDrop=-math.huge}
 boards[player]=board
 implementation=function(handle)handle.owned=true;handle.state.nectar+=6;return true end
 return board,w
end
local function resume(index)
 local ok,problem=coroutine.resume(jobs[index or 1]);assert(ok,problem)
end
-- Immediate proof and repeated calls converge without advancing legacy rank early.
do
 local b,w=fixture();assert(w:requestGrant("skip",1));grantWelcome(player,b);resume()
 assert(#calls==1 and b.nursery.state.nectar==6 and b.profile.rank==1 and #acks==1 and acks[1].status=="Applied")
 grantWelcome(player,b);assert(#jobs==1 and #calls==1 and #sources==1);passed+=1
end
-- Three rapid duplicates after commit must all carry the stronger saved proof,
-- even while WelcomeState's transient grantPending flag remains set.
do
 local b,w=fixture();assert(w:requestGrant("skip",1))
 assert(settledWelcomeStatus(b,1)=="Retrying")
 grantWelcome(player,b);resume()
 assert(w.grantPending==true)
 for i=1,3 do assert(settledWelcomeStatus(b,1)=="Applied")end
 assert(settledWelcomeStatus(b,2)==nil)
 assert(#calls==1 and b.nursery.state.nectar==6);passed+=1
end
-- Background retry can prove ownership while the host sleeps. It must normalize
-- rank and ack without calling grantStarter for a second candidate.
do
 local b,w=fixture();assert(w:requestGrant("skip",1))
 implementation=function()return false,"Retrying"end
 grantWelcome(player,b);resume()
 assert(#calls==1 and b.profile.rank==0 and acks[1].status=="Retrying")
 b.nursery.owned=true;b.nursery.state.nectar=6;resume()
 assert(#calls==1 and b.profile.rank==1 and acks[2].status=="Applied"and not b.starterRunning);passed+=1
end
-- A reset during the yielding transaction may retain its saved ownership but
-- cannot emit an Applied acknowledgement for a superseded run.
do
 local b,w=fixture();w:requestGrant("skip",1)
 implementation=function(h)h.owned=true;h.state.nectar=6;coroutine.yield();return true end
 grantWelcome(player,b);resume();b.runSequence=2;b.welcome=Welcome.new(2);resume()
 assert(b.profile.rank==1 and #acks==0 and #calls==1 and b.nursery.state.nectar==6);passed+=1
end
-- Replacing the nursery handle while a write yields cannot claim its old proof
-- on a fresh handle or advance the unrelated legacy profile.
do
 local b,w=fixture();w:requestGrant("skip",1)
 implementation=function(h)h.owned=true;h.state.nectar=6;coroutine.yield();return true end
 grantWelcome(player,b);resume();b.nursery={owned=false,state={nectar=0}};resume()
 assert(b.profile.rank==0 and #acks==0 and #sources==0 and not b.starterRunning);passed+=1
end
-- Shared drop helper rejects unsafe/stale state, preserves manual aim and counts
-- a server demo once through WelcomeState rather than double-counting in host.
do
 local b,w=fixture()
 b.menuPaused=true;assert(not acceptedDrop(b,.123,10,false));b.menuPaused=false
 b.ready=false;assert(not acceptedDrop(b,.123,10,false));b.ready=true
 assert(not acceptedDrop(b,0/0,10,false))
 assert(acceptedDrop(b,.123,10,false)and b.sim.lastAim==.123 and w.drops==1)
 assert(not acceptedDrop(b,.4,10.1,false))
 b,w=fixture();for i=1,50 do w:step(.5,true)end
 local ticket=w:demoTicket();assert(ticket)
 assert(w:tryDemo(ticket,function()return acceptedDrop(b,.5,20,true)end))
 assert(w.drops==1 and w.demoUsed and b.sim.drops==1)
 assert(not w:tryDemo(ticket,function()error("duplicate demo")end));passed+=1
end
print("WelcomeHost: "..passed.." passed (actual extracted host functions)")
'''
out=ROOT/'build/welcome-host-offline.luau';out.parent.mkdir(exist_ok=True)
out.write_text(pre+'\n'+status+'\n'+drop+'\n'+grant+'\n'+tests,encoding='utf-8')
raise SystemExit(subprocess.run([str(ROOT/'build/luau-cli/luau.exe'),str(out)],cwd=ROOT).returncode)
