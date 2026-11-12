-- Exact production publisher plus real simulation ID allocation. No sessions,
-- rewards, user input, profile writes or fabricated ball snapshots.
return function(server,client,hostSource)
 local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
 local Http=game:GetService("HttpService");local Sim=require(server.BoardSimulation);local Gate=require(client.BoardContentGate)
 assert(type(hostSource)=="string","pass current init.server source as argument three")
 local first=assert(hostSource:find("local function syncVisuals(board)",1,true));local last=assert(hostSource:find("local function reset(board",first,true))
 local install=assert(loadstring("return function(Config,HttpService)\n"..hostSource:sub(first,last-1).."\nreturn syncVisuals\nend"))()
 local publish=install(Config,Http);local folder=Instance.new("Folder");folder.Name="_BoardContentPublication";folder.Parent=workspace
 local board={folder=folder,parts={}};local cases={};local function test(name,f)f();table.insert(cases,name)end
 local function reset()
  folder:ClearAllChildren();table.clear(board.parts)
  board.sim=Sim.new("Springy",board.sim and board.sim.serial or 10,{starter={{x=-2,tier=1},{x=2,tier=1}}})
  folder:SetAttribute("ResetId",board.sim.serial);publish(board)
 end
 local function verify(serial)
  local content=Http:JSONDecode(folder:GetAttribute("BoardContent"))
  assert(folder:GetAttribute("ResetId")==serial and content.serial==serial)
  for _,part in ipairs(folder:GetChildren())do assert(part:GetAttribute("BoardSerial")==serial)end
  assert(Gate.ready(folder),"published run content did not satisfy its client gate")
 end
 local ok,problem=pcall(function()
  reset();local serial=folder:GetAttribute("ResetId")
  test("real drops and merge allocations preserve one presentation reset serial",function()
   for i=1,8 do
    assert(Sim.drop(board.sim,if i%2==0 then .25 else .75))
    for _=1,240 do Sim.step(board.sim,Config.FixedStep,{})end
    publish(board);verify(serial);task.wait()
   end
   assert(board.sim.serial>serial,"simulation never allocated a new ball ID")
  end)
  test("existing mistagged parts are repaired without changing ball identity",function()
   local part=assert(folder:GetChildren()[1]);local id=part:GetAttribute("EggId")
   part:SetAttribute("BoardSerial",board.sim.serial+100);publish(board)
   assert(part:GetAttribute("EggId")==id and part:GetAttribute("BoardSerial")==serial);verify(serial)
  end)
  test("a fresh reset replaces old content while an active exact serial resumes",function()
   assert(not Gate.ready(folder,serial));reset();local fresh=folder:GetAttribute("ResetId")
   assert(fresh~=serial and Gate.ready(folder,serial));verify(fresh)
  end)
 end)
 folder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,realSimulationAndPublisher=true}
end
