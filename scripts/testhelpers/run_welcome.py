"""Execute real Luau Welcome/solver source with only Roblox Vector2/color shims."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/welcome-offline.luau"
PRELUDE = r'''
local V={};local mt={}
function V.new(x,y)return setmetatable({X=x,Y=y},mt)end
mt.__index=function(v,key)
 if key=="Magnitude"then return math.sqrt(v.X*v.X+v.Y*v.Y)
 elseif key=="Unit"then local n=math.sqrt(v.X*v.X+v.Y*v.Y);return V.new(v.X/n,v.Y/n)
 elseif key=="Dot"then return function(a,b)return a.X*b.X+a.Y*b.Y end end
end
mt.__add=function(a,b)return V.new(a.X+b.X,a.Y+b.Y)end
mt.__sub=function(a,b)return V.new(a.X-b.X,a.Y-b.Y)end
mt.__unm=function(a)return V.new(-a.X,-a.Y)end
mt.__mul=function(a,b)if type(a)=="number"then a,b=b,a end;return V.new(a.X*b,a.Y*b)end
mt.__div=function(a,b)return V.new(a.X/b,a.Y/b)end
local Vector2=V;V.zero=V.new(0,0);V.xAxis=V.new(1,0);V.yAxis=V.new(0,1)
local Color3={fromHex=function(h)return h end}
'''

def module(name, relative, replacements=None):
    source = (ROOT / relative).read_text(encoding="utf-8")
    for old, new in (replacements or {}).items():
        assert old in source, (relative, old)
        source = source.replace(old, new)
    return f"\nlocal {name}=(function()\n{source}\nend)()\n"

text = PRELUDE
text += module("Items", "src/shared/RoundItems.lua")
text += module("Config", "src/shared/BoardConfig.lua", {
    'local Palette = require(script.Parent.DeckPalette)': 'local Palette = {}',
    'local Pico8 = require(script.Parent.Pico8)': 'local Pico8 = {}',
})
imports = {
    'local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)': '',
    'local Items = require(game:GetService("ReplicatedStorage").Shared.RoundItems)': '',
}
text += module("Simulation", "src/server/BoardSimulation.lua", imports)
text += module("Round", "src/server/BoardRound.lua", {list(imports)[0]: ''})
text += module("Seed", "src/server/WelcomeSeed.lua", {'local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)': ''})
text += module("Welcome", "src/server/WelcomeState.lua")
text += module("Progress", "src/shared/WelcomeProgress.lua")
text += module("Toys", "src/shared/ToyCatalog.lua")
text += module("Eggs", "src/shared/EggCatalog.lua", {'local Pets = require(script.Parent.PetCatalog)': 'local Pets={byId={pip={index=1},blip={index=8}}}'})
text += module("Guide", "src/client/FirstSpendGuide.lua", {
    'local Shared=game:GetService("ReplicatedStorage").Shared': '',
    'local Toys=require(Shared.ToyCatalog)': '',
    'local Eggs=require(Shared.EggCatalog)': '',
})
text += module("SeedSpec", "scripts/WelcomeSeed.spec.lua")
text += module("StateSpec", "scripts/WelcomeState.spec.lua")
text += module("SpendSpec", "scripts/FirstSpendGuide.spec.lua")
text += '''
local result=SeedSpec(nil,nil,{Seed=Seed,Simulation=Simulation,Config=Config,Round=Round})
print("SOLVER tested="..result.tested.." min="..result.minFirstMerge.." max="..result.maxFirstMerge.." universalProof=false")
local state=StateSpec(nil,nil,{Welcome=Welcome,Progress=Progress})
print("WelcomeState: "..state.passed.." passed")
local spend=SpendSpec(nil,nil,{Guide=Guide,Toys=Toys})
print("FirstSpendGuide: "..spend.passed.." passed")
'''
OUT.parent.mkdir(exist_ok=True)
OUT.write_text(text, encoding="utf-8")
raise SystemExit(subprocess.run([str(ROOT / "build/luau-cli/luau.exe"), str(OUT)], cwd=ROOT).returncode)
