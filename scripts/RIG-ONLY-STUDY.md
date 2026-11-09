# Controlled lighting and rig-only comparison

These are temporary QA tools, excluded from `default.project.json`. They send no remotes and change no profiles, ownership, rewards, or production source. The archived renderer measures bb8c60b rig implementation cost **inside today's garden**, not historical place performance. Older captures whose native lighting was not recorded must be labeled **uncontrolled clock**, including the prior requested-noon benchmark metadata.

## Install in Edit

Regenerate locally only when changing these QA sources:

```powershell
python scripts/package_rig_study_harness.py
```

Using the existing trusted Edit source loader, put `scripts/InstallRigStudyHarness.lua` into one temporary ModuleScript named `QAInstallRigStudyHarness`. Call its returned function:

```lua
require(game.ReplicatedStorage.QAInstallRigStudyHarness)()
```

The installer creates `ReplicatedStorage._RigOnlyQAHarness` (5 modules) and `ReplicatedStorage._RigStudyArchive_bb8c60b` (21 exact archived dependency modules). It refuses to replace existing folders. The archived revision and source hashes are stored on the folders and in `artifacts/aero-garden-2026-11-09/rig-study-archive-manifest.json`. Zivvi/Ovelle reuse the unchanged approved mounted meshes; the other5 use their actual archived procedural renderers. All archived Shared requires route into the archive namespace.

## Fresh single-client Play checks

Stop other local test servers and retire any existing visual study before testing. Keep actual controls quiet during sampling. Run in one real client VM, preserving globals between commands:

```lua
local storage=game.ReplicatedStorage
local qa=storage._RigOnlyQAHarness
local client=game.Players.LocalPlayer.PlayerScripts.Client
return require(qa.ClockSpec)(client,qa.Study) --3 cases
```

```lua
local storage=game.ReplicatedStorage
local qa=storage._RigOnlyQAHarness
local client=game.Players.LocalPlayer.PlayerScripts.Client
return require(qa.ComparisonSpec)(client,qa.Study,qa.Comparison,storage._RigStudyArchive_bb8c60b) --3 cases
```

The clock test deliberately introduces competing native Lighting/Atmosphere/grade/lamp changes. It verifies a late-render hold, exposes collection-time drift honestly, and restores the exact prior environment. The comparison smoke rounds use6 warmup/12 sample frames and cannot produce an accepted performance ratio.

## Six bounded benchmark rounds

Use identical accepted origin/camera/graphics for every candidate. Defaults below use the existing study's lawn origin and seven-actor lineup. Override `fixture.origin`, `cameraTarget`, `cameraOffset` or `fov` only before the first round to reproduce an already approved camera; keep them fixed thereafter. The study adds one identical analytic ball and hides ordinary UI for both candidates; no actual shared toy reservation is changed.

```lua
local storage=game.ReplicatedStorage
_G.rigQA=require(storage._RigOnlyQAHarness.Comparison).new(
 game.Players.LocalPlayer.PlayerScripts.Client,
 storage._RigOnlyQAHarness.Study,
 storage._RigStudyArchive_bb8c60b,
 {fixture={hour=12,origin=Vector3.new(-8,4.025,8),view="lineup",motion="sequence",cadence=15,preset="neutral"}}
)
```

Run and store each returned table separately. Each round has180 warmup and180 measured frames. Balanced order:

```lua
return _G.rigQA:runRound("archived",1)
```

```lua
return _G.rigQA:runRound("current",1)
```

```lua
return _G.rigQA:runRound("current",2)
```

```lua
return _G.rigQA:runRound("archived",2)
```

```lua
return _G.rigQA:runRound("archived",3)
```

```lua
return _G.rigQA:runRound("current",3)
```

```lua
return _G.rigQA:summary()
```

Collect the six raw outputs and the summary. Every measured frame checks actual native lighting against the intended environment and the actual camera against the pinned camera. Outputs include requested/actual ClockTime, derived actual daylight, exposure/brightness/ambient, atmosphere/grade, all managed lamps, graphics settings, current-world vs fixture counts, UI/background-toy state, revision, source hashes, pose cadence and appearance. The timed rig CPU includes Follow and sampled visual updates; frame time remains a separate whole-frame measurement. Camera/lighting/ball/metadata work is excluded from that timed rig block and identical across candidates.

A round is valid only if every measured frame remains controlled and current-world counts/toy/UI/graphics stay stable. The summary reports ratios only after3 valid180-frame rounds per candidate with at least180 warmup, identical environment/camera/graphics/background/appearance/motion and7 actors+1 analytic toy. Compare absolute p50/p95 milliseconds and each raw round; investigate repeated >10% p95 regressions. This is local Studio rig-only evidence, not a physical-phone or service-backed guarantee. For midnight, destroy the session and repeat a new session with `hour=0`; do not pool sun/night rounds.

## Cleanup

Before stopping Play:

```lua
if _G.rigQA then _G.rigQA:destroy();_G.rigQA=nil end
```

Each completed round already destroys its study and restores pre-round camera/UI/environment. Session destruction also retires an in-progress sampler. Stop Play, then remove only the marked temporary folders in Edit:

```lua
assert(not game:GetService("RunService"):IsRunning())
for _,name in ipairs({"_RigOnlyQAHarness","_RigStudyArchive_bb8c60b"})do
 local folder=game.ReplicatedStorage:FindFirstChild(name)
 if folder then assert(folder:GetAttribute("FixtureOnly")==true);folder:Destroy()end
end
```

Remove the temporary `QAInstallRigStudyHarness` loader and any separately installed QA spec/driver modules before publication. Do not change or remove production `Shared`, `Client`, or `PetAssets`.
