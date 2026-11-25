"""Run DashCourse.spec and DashSim.spec in the Luau command line tool (no Studio).

    python scripts/run_dash_specs.py [path to luau.exe] [heats]

Bundles the three shared modules and the specs into one file, with a `require` that only knows them, and hands
DashCourse.spec the world numbers (ground grid, parks, bridge) read from the repository.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUAU = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "build/luau-cli/luau.exe")
HEATS = sys.argv[2] if len(sys.argv) > 2 else "10000"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


ground = json.loads(read("assets/world/world-v7-walk.json"))["ground"]
heights = ",".join(str(-999 if v is None else v) for row in ground["heights"] for v in row)
layout, park = read("src/shared/HollowWorldLayout.lua"), read("src/shared/ParkLayout.lua")
v7 = layout[layout.index("local V7="):]
span = re.search(r"MainBridge=table.freeze\(\{center=Vector3.new\(([^)]*)\),size=Vector3.new\(([^)]*)\)", v7)
c, s = ([float(v) for v in g.split(",")] for g in span.groups())
lamps = [g.split(",") for g in re.findall(r"Vector3.new\(([^)]*)\)", v7[v7.index("Lamps=points("):v7.index("LitLamps")])]
stations = [(x, z) for x, z in re.findall(r"(?:Eggs|Journal|Customize|ToyLawn)=CFrame.new\(([-\d.]+),[-\d.]+,([-\d.]+)\)", v7)]
# Every park site spec (the arrival, the old grove and the Hollow), each with its own radii: the course keeps clear of all.
parks = re.findall(r"Specs\.\w+=table\.freeze\(\{id=\"\w+\",x=(-?\d+),z=(-?\d+),rx=(\d+),rz=(\d+)", park)
radius = parks[0][2:]
assert len(lamps) == 7 and len(stations) == 4 and len(parks) == 3

modules = "\n".join(
    f"sources.{name}=function(script,require)\n{read(f'src/shared/{name}.lua')}\nend"
    for name in ("DashCourse", "DashStats", "DashSim", "DashGrid"))
# The start grid numbers the course script measures the waiting pad with (DashCourse.spec checks DashGrid agrees).
script = read("scripts/build_dash_course.py")
grid = re.search(r"START_STEP, FUNNEL, POST_HALF_WIDTH = ([\d.]+), \(([\d.]+), ([\d.]+)\), ([\d.]+)", script).groups()
lane_step = re.search(r"LANES, LANE_STEP = \d+, ([\d.]+)", script).group(1)
specs = "\n".join(
    f"specs.{name}=(function()\n{read(f'scripts/{name}.spec.lua')}\nend)()" for name in ("DashCourse", "DashSim"))
bundle = f"""
local sources,loaded,specs={{}},{{}},{{}}
{modules}
local Shared=setmetatable({{}},{{__index=function(_,name)return name end}})
local function load(name)
 if loaded[name]==nil then loaded[name]=sources[name]({{Parent=Shared}},load)end
 return loaded[name]
end
local H={{{heights}}}
local function groundY(x,z)
 local fx,fz=(x-({ground['x0']}))/{ground['step']},(z-({ground['z0']}))/{ground['step']}
 local i,j=math.floor(fx),math.floor(fz)
 local function at(a,b)return H[b*{ground['nx']}+a+1]end
 local u,v=fx-i,fz-j
 return at(i,j)*(1-u)*(1-v)+at(i+1,j)*u*(1-v)+at(i,j+1)*(1-u)*v+at(i+1,j+1)*u*v
end
local world={{groundY=groundY,span={{{c[0]},{c[2]},{s[0]},{s[2]},{c[1]}+{s[1]}/2}},
 radius={{{','.join(radius)}}},parks={{{','.join('{%s,%s,%s,%s}' % p for p in parks)}}},
 lamps={{{','.join('{%s,%s}' % (l[0], l[2]) for l in lamps)}}},stations={{{','.join('{%s,%s}' % p for p in stations)}}},
 grid={{startStep={grid[0]},funnel={{{grid[1]},{grid[2]}}},post={grid[3]},laneStep={lane_step}}}}}
local require=load
{specs}
local failed=0
for _,name in ipairs({{"DashCourse","DashSim"}})do
 local start=os.clock()
 local ok,result=xpcall(function()return specs[name](nil,Shared,if name=="DashCourse"then world else{{heats={HEATS}}})end,function(e)return tostring(e).."\\n"..debug.traceback()end)
 if ok then
  print(string.format("PASS %s (%d cases, %.1f s)",name,result.passed,os.clock()-start))
  for _,case in ipairs(result.cases)do print("  - "..case)end
 else failed+=1;print("FAIL "..name..": "..result)end
end
if failed>0 then error(failed.." spec(s) failed")end
"""
with tempfile.TemporaryDirectory() as folder:
    path = os.path.join(folder, "dash_specs.luau")
    Path(path).write_text(bundle, encoding="utf-8")
    sys.exit(subprocess.run([LUAU, "-O2", path]).returncode)
