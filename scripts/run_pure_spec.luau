-- Offline runner for the pure deck-network specs (no Studio):
--   build/luau-cli/luau.exe scripts/run_pure_spec.luau
-- Provides the two Roblox globals the pure modules and specs touch (Random) and passes the
-- modules in directly.
if not Random then
 -- xorshift32, enough for synthetic schedules
 Random={}
 Random.__index=Random
 function Random.new(seed)
  return setmetatable({state=bit32.bxor(math.floor(seed or os.clock()*1e6)%4294967296,2463534242)},Random)
 end
 function Random:NextNumber(lo,hi)
  local x=self.state
  x=bit32.bxor(x,bit32.lshift(x,13));x=bit32.bxor(x,bit32.rshift(x,17));x=bit32.bxor(x,bit32.lshift(x,5))
  self.state=x
  local unit=x/4294967296
  if lo==nil then return unit end
  return lo+(hi-lo)*unit
 end
end
local modules={
 Snapshots=require("../src/client/BoardSnapshots"),
 Codec=require("../src/shared/BoardSnapshotCodec"),
 Random=Random,
 DropIntent=require("../src/client/DropIntent"),
 GhostFlight=require("../src/client/GhostFlight"),
}
local failures=0
for _,name in ipairs({"BoardSnapshots","DropIntent","GhostFlight"})do
 local spec=require("./"..name..".spec")
 local ok,result=pcall(spec,nil,nil,modules)
 if ok then
  print(string.format("PASS %s (%d cases)",name,result.passed))
  for _,case in ipairs(result.cases)do print("  - "..case)end
 else
  failures+=1;print("FAIL "..name..": "..tostring(result))
 end
end
if failures>0 then error(failures.." spec(s) failed")end
