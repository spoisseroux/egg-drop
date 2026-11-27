"""Run the Garden Dash server and client specs (slices S6, S7) in the Luau command line tool, with Roblox mocks (no Studio).

    python scripts/run_dash_server_specs.py [path to luau.exe] [base commit] [live commit]
    DASH_SPECS="ParkDirector MedalEggs" ...   other specs by name (some need engine parts the mocks do not have)

Bundles src/shared and src/server of this tree, plus the same folders of two commits read with git: `base` (the
commit this slice starts from, for the off-parity JSON) and `live` (the published build, for the cross-version
save check). Each tree has its own module cache and its own `game`; the mocks (offline_roblox.luau) are shared.
The specs are the same files Studio runs from ZZSpecs; DashCrossVersion.spec needs the two old trees, so it is
offline only.
"""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUAU = str(Path(sys.argv[1]).resolve()) if len(sys.argv) > 1 else str(ROOT / "build/luau-cli/luau.exe")
BASE = sys.argv[2] if len(sys.argv) > 2 else "46ab954"
LIVE = sys.argv[3] if len(sys.argv) > 3 else "aeae2d9"
ONLY = os.environ.get("DASH_SPECS", "").split()
SPECS = ["Dash", "DashConfig", "DashWire", "DashDirector", "DashState", "DashPrize", "DashGating", "DashHost",
         "DashOffParity", "DashCrossVersion", "CloseProgress", "GardenHour", "GardenHourBook",
         # Beta (12) QA quick fixes: pet catch-up (G1), the fresh-save key switch (T1), finds near the player (G2).
         "PetCatchup", "CatchupConfig", "GardenState", "ProgressKey", "FreshSave", "FindsState", "FindsHost",
         # Garden life round 3 and the nest remodel (beta 12 QA O2): the nest's spot and the pets kept off it.
         "NestSpot",
         # Beta (12) QA Dash and Deck UI: the start grid (U5).
         "DashGrid",
         # The Hush greybox (HUSH-GREYBOX-BUILD-PLAN): the gate and data, the switch, the host; the island edges it extends.
         "Hush", "HushConfig", "HushHost", "IslandBounds", "IslandBoundsHost",
         # The upper tier, greybox T0 (UPPER-TIER-BUILD-PLAN).
         "Tier", "TierConfig", "TierHost",
         # The Play Den, step A (PLAY-DEN-BUILD-PLAN).
         "PlayDen", "DenConfig", "DenHost",
         # The egg corner (EGG-CORNER-BUILD-PLAN): its numbers and switches.
         "EggCorner",
         # The Sleepy Nest landmark (NEST-LANDMARK-LOOK): its numbers and states.
         "NestLandmark",
         # Beta (17) QA U8: the care hold the owner never asked for (forced), offline too.
         "GardenCare",
         # Beta 17 world (WORLD-ALIVE-LOOK): the Dash fete set and the river stones.
         "DashFete",
         # The park sites and the Hollow (WORLD-ALIVE-LOOK section 2): the pinned arrival and grove, the multi-site director.
         "ParkSites", "MultipleParks", "ParkDirector",
         # The Top Lawn's toys x1.25 (ROUND7-LOOK 7): every k = 1 site pinned, the scaled toys, seats and slots.
         "ParkToyScale",
         # Beta (34) QA: park walks go round the toys (ParkRoute), every leg on every site walked.
         "ParkRoute",
         # The cliff path / Play Den / terrace top (CLIFF-DEN-ISLAND-SCOPE): the beta's server-start swap and its data.
         "CliffDen",
         # Live growth cuts G1 + G2, ported to the beta (PORT-TO-BETA.md): the Welcome bonus and the first hello (pure
         # and the HatchProgress fixture).
         "StarterBonus", "FirstHello",
         # Pets go up and the Top Lawn (WORLD-FINISH-LOOK slices A and B).
         "TierPets",
         # The world finish art (WORLD-FINISH-ART-BUILD.md): the mount and its data.
         "WorldFinish",
         # The hill's sound zones and night (WORLD-FINISH-LOOK slice F).
         "HillNight",
         # Beta 34 QA Pocket Deck: the goals as plain instructions (GoalWords).
         "GoalWords",
         # Bumble balls (GARDEN-PLAY-BRIEF 1): the shared sim, the checks and the blend maths; the host and the pets' bunt.
         "BumbleBalls", "BumbleBallHost",
         # GARDEN-PLAY-BRIEF-2: pets go round the garden's solid props (GardenKeepOut); the fruit's Heart XP (GardenFruit).
         "GardenKeepOut", "GardenFruit",
         # AERO-JUICE-BRIEF (beta 36) section 3: the Aero hatch screens' palettes, contrast, bubbles and switch.
         "HatchAero",
         # "This week" (GARDEN-PLAY-BRIEF-2 section 8): the weekly wardrobe pick's rotation, prices, listing and purchase.
         "ThisWeek",
         # The petting screen (ONBOARDING-V3-BRIEF section 4, switch pet2): the heart, the lean, the mitten, the spots.
         "PetCuddle"]
# Client specs: the Dash, Things, Finds, onboarding v3 and garden life modules (with Wind, AmbientAudio and AliveBudget) as they are, small stand-ins for the screens they borrow, and
# RoomView's hooks cut out of RoomView.lua (the rest of it needs an engine). One realm: the mocks answer IsServer and
# IsStudio true.
CLIENT = ["DashPredict", "DashCamera", "DashFade", "DashHints", "DashInput", "DashHud", "DashClient", "DashSheets", "DeckResultsLayout", "FocusRow", "TipChime",
          "FindsClient", "ThingsTrail", "ThingsTips", "LifeSim", "GardenLife", "Wind", "AliveBudget", "AmbientAudio",
          "BearNeeds", "FollowBear", "NestClient", "TomorrowStrip", "GardenHourPets", "AeroKit",
          "HushClient", "DenClient", "DashLine", "WorldFeel", "LifeSceneSim", "LifeScene", "WorldMotion",
          "GroundDressing", "LifePet", "EggMachineClient",
          # Beta (17) QA U2, U4, U6, U8: the cursor registry, the preview's UI scale, the shadow spot, the set-down search.
          "Beta17Fixes",
          # Beta (17) U1: the HUD chip rules (the play date ticket, the egg ticket's slot order).
          "HudChips",
          # The ASMR hatch and the vibration cap (ASMR-AND-SCALE-LOOK 1, 2): the variation picker, the beat schedule, the gate.
          "HatchAsmr",
          # Beta (19): the Bear's eye in his head (the curious glance, PetEyeGlance).
          "PetEyeGlance",
          # Live growth cuts G1 + G2, ported to the beta (PORT-TO-BETA.md): the strip, the nudge, the coach rules, the
          # trail, pill and calm deck rules.
          "TomorrowChips", "ResultsNudge", "GrowthCoach", "GrowthG2", "GrowthPort",
          # The hill at night (WORLD-FINISH-LOOK slice F): the lanterns, the glow-caps, the terrace fireflies.
          "HillNightClient",
          # The First Hatch (onboarding-2026-11-26): the crack ritual's clock hold.
          "CrackRitual",
          # Player scale (player-scale-2026-11-26): the knob.
          "PlayerScale",
          # Beta (34) notes: the Wobble Egg on the crag (GARDEN-PLAY-BRIEF 3).
          "WobbleEgg",
          # Beta 34 QA Pocket Deck: the computer text knob.
          "DeckText",
          # Bumble balls (GARDEN-PLAY-BRIEF 1): one ball's drawn state (predict, join mid-arc, blend, correct, fade).
          "BumbleBallView",
          # The garden's crunchy toys (GARDEN-PLAY-BRIEF 2026-11-26 section 2): spots, budget, switch, timings, the client.
          "CrunchToys",
          # The garden's drift lanterns and seed fluff (GARDEN-PLAY-BRIEF section 4): spots, heights, night, the client.
          "DriftLanterns",
          # Beta (34) QA: the walk feel (eased legs, turns, corners) and the pause's look round (PetWalkBeats).
          "PetWalk",
          # Beta (35) water: the world heard from the player's head (AudioListener's choice, blend and facing).
          "AudioListener",
          # Beta (35): every egg comes out of the machine (the one path: every egg type and every buy send).
          "EggDelivery",
          # GARDEN-PLAY-BRIEF-2 section 7: the Dash start balloon (DashBalloon: its cues, motion, parts and stillness).
          "DashBalloon",
          # Beta (35) deck net audit: one deck round through the client path under simulated latency, jitter and loss.
          "DeckNetFeel",
          # Onboarding v2 (qa-2026-11-26-beta35/ONBOARDING-V2.md): the five steps' rules, the safe reveal card.
          "OnboardV2", "RevealLayout", "EggCrackPaths",
          # AERO-JUICE-BRIEF 1 and 2: the Aero Glass palette and shading, the Pocket Deck juice pass, the UI counters.
          "AeroJuice"]
SPECS += CLIENT
# Client specs that run only when named in DASH_SPECS (not in the default run): the Aero waterfall layers.
CLIENT_EXTRA = ["AeroFalls"]
STUBS = {
    "PetFollow": "return{CadenceCap=3,stride=function()return 2 end,bob=function()return 0 end,rest=function(v)v.gaitWeight=0 end,weight=function(s)return math.clamp((s-.03)/1.6,0,1)end}",
    "PetFactory": "return{}", "DeckKit": "return{focusable=function(object)return object.ok==true end}", "NotificationRail": "return{}",
    "ConfirmDialog": "return{isOpen=function()return false end}",
    # The deck net audit's round-end case: RoundEndPresentation's art helpers (observe never draws).
    "DeckArt": "return{Ink=Color3.new(0,0,0),Amber=Color3.new(1,.7,0),Leaf=Color3.new(0,1,0)}",
    # Garden hour E: PetFace reads HollowClock.lastDaylight (the spec sets it); the real clock needs Lighting. GardenLife
    # and PetMaterials gate on hourOn (no Aero look offline: off; their specs swap it).
    "HollowClock": "return{daylight=function()return 1 end,hourOn=function()return false end}",
}


def client_modules():
    out = {f"client/{name}": source for name, source in STUBS.items()}
    for pattern in ("Dash*.lua", "Things*.lua", "Finds*.lua", "NoticeCards.lua", "Life*.lua", "GardenLife.lua", "Wind*.lua",
                    "AmbientAudio.lua", "AmbientPerches.lua", "AudioListener.lua", "AliveBudget.lua", "AeroAdditions.lua", "AeroFalls.lua",
                    # The island re-export: the Aero world kit (split crowns, falls sheets, rocks).
                    "AeroKit.lua", "AeroFountain.lua",
                    # Onboarding v3 A+B: the needs, the tour gate, the station label tips and the pill's quiet stage.
                    "BearNeeds.lua", "NeedBubble.lua", "BubbleHold.lua", "WorldFeelClient.lua", "CoachCards.lua", "StationAttract*.lua", "LoungeStations.lua",
                    "JournalPromptPriority.lua", "FirstSpendGuide.lua",
                    # Onboarding v3 D+E: the nest in the garden and the See you tomorrow strip.
                    "NestClient.lua", "TomorrowStrip.lua", "DeckResultsLayout.lua", "FocusRow.lua", "TipChime.lua",
                    # Garden hour E: the pet mood rules and the face that feeds them.
                    "PetFace.lua", "PetExpression.lua", "PetIdleBeats.lua", "PetCoo*.lua", "CareFeedbackData.lua",
                    "PetNightSurfaces.lua", "PetMaterial*.lua",
                    # The Hush: the passage's fade and the region effects.
                    "HushClient.lua",
                    # The Play Den: its prompts.
                    "DenClient.lua",
                    # Beta 14 garden life: the arch chimes (WorldMotion).
                    "WorldMotion.lua", "WorldDressingClient.lua",
                    # The egg corner: the machine's motion, cranks and reveal hold.
                    "EggMachineClient.lua",
                    # Beta (16) B3: the hatch reveal's aim.
                    "HatchAim.lua",
                    # Beta (17) QA U2 and U4: the modal cursor registry and the UI scale space.
                    "ModalCursor.lua", "UIScaleSpace.lua",
                    # Beta (17) R13: Hatch another waits out the server's request spacing.
                    "HatchFlow.lua",
                    # Beta (17) U1: the HUD chip rules.
                    "HudChips.lua",
                    # The ASMR hatch: its schedule and the one vibration module.
                    "HatchAsmr.lua", "Haptics.lua",
                    # Beta (19): the curious glance.
                    "PetEyeGlance.lua",
                    # Live growth cuts G1 + G2 (ported): the strip, the nudge, the round-two pill, the trail, the calm deck.
                    "TomorrowChips.lua", "ResultsNudge.lua", "GrowthNudge.lua", "PetTrail.lua", "DeckCalm.lua", "PetLookAt.lua",
                    # The hill at night (WORLD-FINISH-LOOK slice F).
                    "HillNightClient.lua",
                    # The First Hatch: the crack ritual.
                    "CrackRitual.lua",
                    # Beta 34 QA: the Pocket Deck's computer text knob.
                    "DeckText.lua",
                    # Bumble balls: the drawn state (the look and the controller are bundled, never required offline).
                    "BumbleBall*.lua",
                    # The garden's crunchy toys.
                    "CrunchToysClient.lua",
                    # The garden's drift lanterns.
                    "DriftLanternsClient.lua",
                    # Beta (34): the look round in a walk's pause.
                    "PetWalkBeats.lua",
                    # Beta (35) deck net audit: the client-run deck's driver and mirror.
                    "ClientRoundDriver.lua", "ClientBoardMirror.lua", "RoundEndPresentation.lua", "FieldQuestText.lua", "StarText.lua",
                    # Onboarding v2: the steps' pure rules (BearNeeds reads the guide's) and the reveal card's layout.
                    "OnboardV2.lua", "RevealLayout.lua", "EggCrackPaths.lua", "EggCrack3D.lua",
                    # AERO-JUICE-BRIEF 1 and 2: the bubble shading, the deck juice layer, its UI half and the faces.
                    "AeroShade.lua", "AeroJuice.lua", "AeroUI.lua", "BallFaces.lua"):
        for path in sorted((ROOT / "src/client").glob(pattern)):
            out[f"client/{path.stem}"] = path.read_text(encoding="utf-8")
    room = (ROOT / "src/client/RoomView.lua").read_text(encoding="utf-8")
    hooks = room[room.index("function Room:enterDash("):room.index("function Room:retryArrivalPlacement()")]
    out["client/RoomViewDash"] = (
        "local Room={};Room.__index=Room\nlocal WorldFeel=require(game:GetService(\"ReplicatedStorage\").Shared.WorldFeel)\n"
        "Room.lock=require(script.Parent.MovementLock).new({})\nlocal MovementLock={shared=function()return Room.lock end}\n"
        "Room.hidden=0\nlocal FocusCharacterVisibility={acquire=function(character)Room.hidden+=1;local scope={character=character}\n"
        "function scope:release()if not self.released then self.released=true;Room.hidden-=1 end end\nreturn scope end}\n"
        "local GuiService={}\nRoom.gui=GuiService\nlocal PetGreetingShot={capture=function(camera,root)return{camera=camera,root=root,position=root and root.Position,"
        "transform=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView}end,\nrestore=function(saved,camera,root)if not saved or saved.camera~=camera or "
        "saved.root~=root or not root then return false end;camera.CFrame,camera.Focus,camera.FieldOfView=saved.transform,saved.focus,saved.fov;return true end}\n"
        + hooks + "\nreturn Room")
    init = (ROOT / "src/client/init.client.lua").read_text(encoding="utf-8")
    modal = init[init.index("clientUI.anyModalOpen=function(others)"):init.index("-- QA v2 R2.1/R2.2: the same edge")]
    out["client/InitModal"] = "return function(clientUI,isPickerOpen,journal,nurseryView,gameMenu,modal)\n" + modal + "\nreturn clientUI.anyModalOpen\nend"
    out["client/MovementLock"] = (ROOT / "src/client/MovementLock.lua").read_text(encoding="utf-8")
    out["client/EggEntryScan"] = egg_entry_scan()
    return out


def egg_entry_scan():
    """Beta (35), the standing rule "all eggs have the crank animation": what EggDelivery.spec reads from the tree. Every
    `"...Buy"` send named anywhere in src (file by file), and the sources the hand-offs live in."""
    buys = {}
    for path in sorted((ROOT / "src").rglob("*.lua")):
        for action in sorted(set(re.findall(r'"([a-z][A-Za-z]*Buy)"', path.read_text(encoding="utf-8")))):
            buys.setdefault(action, []).append(path.relative_to(ROOT).as_posix())
    sources = {name: (ROOT / f"src/client/{file}").read_text(encoding="utf-8")
               for name, file in (("init", "init.client.lua"), ("SnackHost", "SnackHost.lua"), ("HatchCinematic", "HatchCinematic.lua"))}

    def long(text):
        level = 1
        while f"]{'=' * level}]" in text:
            level += 1
        return f"[{'=' * level}[\n{text}]{'=' * level}]"
    rows = ",".join(f'{action}={{{",".join(repr(p) for p in paths)}}}' for action, paths in buys.items())
    texts = ",".join(f"{name}={long(text)}" for name, text in sources.items())
    return f"return{{buys={{{rows}}},sources={{{texts}}}}}"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True).stdout.decode("utf-8")


def files(commit):
    """{"shared/X": source} for every plain module (no init scripts, no nested folders)."""
    out = {}
    for side in ("shared", "server"):
        if commit is None:
            for path in sorted((ROOT / "src" / side).glob("*.lua")):
                if not path.name.startswith("init."):
                    out[f"{side}/{path.stem}"] = path.read_text(encoding="utf-8")
        else:
            for name in git("ls-tree", "--name-only", f"{commit}:src/{side}").split():
                if name.endswith(".lua") and not name.startswith("init."):
                    out[f"{side}/{name[:-4]}"] = git("show", f"{commit}:src/{side}/{name}")
    return out


def tree(name, commit):
    sources = files(commit)
    if commit is None:
        sources.update(client_modules())
    body = "\n".join(
        f'trees.{name}["{path}"]=function(script,require,game)\n{source}\nend' for path, source in sources.items())
    return f"trees.{name}={{}}\n{body}"


specs = ONLY or SPECS
for name in specs:
    assert (ROOT / f"scripts/{name}.spec.lua").exists(), name
bundle = "\n".join([
    "local trees={}",
    tree("new", None), tree("base", BASE), tree("live", LIVE),
    "local specs={}",
    "\n".join(f"specs.{name}=function(game,require)\n{(ROOT / f'scripts/{name}.spec.lua').read_text(encoding='utf-8')}\nend"
              for name in specs),
    f"local ORDER={{{','.join(repr(name) for name in specs)}}}",
    f"local CLIENT={{{','.join(name + '=true' for name in CLIENT + CLIENT_EXTRA)}}}",
    (ROOT / "scripts/offline_roblox.luau").read_text(encoding="utf-8"),
])
lines = bundle.splitlines()


def where(match):
    """A bundle line as file:line."""
    number = int(match.group(1))
    for at in range(min(number, len(lines)) - 1, -1, -1):
        start = re.match(r'(?:specs\.(\w+)|trees\.(\w+)\["([\w/]+)"\])=function\(', lines[at])
        if start:
            spec, which, path = start.groups()
            name = f"scripts/{spec}.spec.lua" if spec else f"{which}:src/{path}.lua"
            return f"{name}:{number - at - 1}"
    return match.group(0)


with tempfile.TemporaryDirectory() as folder:
    path = os.path.join(folder, "dash_server_specs.luau")
    Path(path).write_text(bundle, encoding="utf-8")
    run = subprocess.run([LUAU, "-O1", path], capture_output=True)
    text = (run.stdout + run.stderr).decode("utf-8", "replace")
    print(re.sub(r"\S*dash_server_specs\.luau:(\d+)", where, text))
    sys.exit(run.returncode)
