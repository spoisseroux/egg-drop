"""Export Egg Drop's player-facing strings to a Roblox localization table CSV.

v1 track C (translations). Writes assets/localization/egg-drop-strings.csv with the
columns Roblox's localization table upload takes: Key, Source, Context, Example.

  * UICopy (src/shared/UICopy.lua): every leaf key, `ui.<key>`.
  * Shared catalogues (item, ball, faceplate, background, finish, toy, quest, store,
    round-item, wearable and book names, pitches and descriptions): `catalog.<Module>.<path>`.
    Pet names are left out on purpose (they stay as named; see LOCALIZATION.md).
  * Literal strings still hard-coded in client UI code (not in UICopy yet) go to a
    separate review list, artifacts/localization/hardcoded-strings.csv (File, Line, Text,
    Note), not to the upload: Roblox captures them at runtime, and many are halves of
    sentences built by concatenation (flagged "fragment"), which a table entry cannot fix.

Context stays empty: in a Roblox table Context is an instance path, and an entry with a
Context only applies to that one instance. Where the string is shown, and a filled-in
example for `{placeholder}` strings, go in Example instead.

The shared modules are evaluated with the Luau CLI (build/luau-cli/luau.exe) and stub
Roblox globals, so the catalogues are read as the game reads them.

Usage: python scripts/export_localization_csv.py [--out PATH] [--review PATH]
"""
import argparse
import csv
import io
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "src", "shared")
CLIENT = os.path.join(ROOT, "src", "client")
LUAU = os.path.join(ROOT, "build", "luau-cli", "luau.exe")
DEFAULT_OUT = os.path.join(ROOT, "assets", "localization", "egg-drop-strings.csv")
DEFAULT_REVIEW = os.path.join(ROOT, "artifacts", "localization", "hardcoded-strings.csv")

# Catalogue modules whose text players read. PetCatalog is read for descriptions only.
CATALOGS = [
    "BallThemes", "DeckThemes", "DeckBackgrounds", "DeckStickers", "MaterialCatalog", "ToyCatalog",
    "HueCatalog", "FeatureCatalog", "PetCharmCatalog", "WearableCatalog", "RoundItems", "QuestCatalog",
    "StoreCatalog", "BookCatalog", "AppearanceCatalog", "FieldObjectives", "EggCatalog", "PetCatalog",
]
# Fields that hold player-facing text.
TEXT_FIELDS = {"name", "names", "title", "sub", "description", "blurb", "pitch", "effect", "short", "label",
               "text", "line", "per", "promise"}
# Where each UICopy section shows (Example column).
SECTION_NOTES = {
    "hatch": "Hatch eggs screen", "style": "Deck style screen", "results": "Round results screen",
    "shop": "Shop status and errors", "items": "Round item notes", "menu": "Pause menu",
    "hub": "Pocket menu (machine hub)", "pause": "Pause menu", "quests": "Quest log",
    "wardrobe": "Wardrobe screen", "companions": "Companions screen", "pet": "Petting reward",
    "book": "Collection book", "park": "Pet Park chip", "stamp": "Stamp card", "report": "Bug report sheet",
    "onboarding": "First-round coaching", "coach": "First-round coaching",
}
SAMPLE = {"count": 3, "heat": "Medium", "low": 6, "high": 8, "pet": "Bear", "reward": 5, "item": "Squeaky Bone",
          "owned": 3, "total": 12, "target": 3, "name": "Pet Park"}

HARNESS = r'''
local Sources = SOURCES
local Any
Any = setmetatable({}, {
 __index = function() return Any end, __newindex = function() end, __call = function() return Any end,
 __add = function() return Any end, __sub = function() return Any end, __mul = function() return Any end,
 __div = function() return Any end, __unm = function() return Any end, __mod = function() return Any end,
 __pow = function() return Any end, __idiv = function() return Any end, __len = function() return 0 end,
 __concat = function() return "" end, __lt = function() return false end, __le = function() return false end,
 __tostring = function() return "Any" end,
})
local loaded = {}
local Shared
local load
local function handle(name) return { __module = name } end
Shared = setmetatable({}, { __index = function(_, name) return handle(name) end })
local function req(target)
 if type(target) == "table" and rawget(target, "__module") then return load(target.__module) end
 return Any
end
load = function(name)
 if loaded[name] ~= nil then return loaded[name] end
 local source = Sources[name]
 if not source then loaded[name] = Any; return Any end
 local chunk, problem = loadstring(source, "=" .. name)
 if not chunk then error(name .. ": " .. tostring(problem)) end
 local env = setmetatable({ script = { Parent = Shared, Name = name }, require = req, warn = function() end },
  { __index = function(_, key) local v = _G[key]; if v ~= nil then return v end; return Any end })
 setfenv(chunk, env)
 local ok, result = pcall(chunk)
 if not ok then io_err = (io_err or "") .. name .. ": " .. tostring(result) .. "\n"; result = Any end
 loaded[name] = result
 return result
end
local function emit(kind, key, text, note)
 text = string.gsub(text, "\n", "\\n")
 print(kind .. "\31" .. key .. "\31" .. text .. "\31" .. (note or ""))
end
-- UICopy leaves.
local UICopy = load("UICopy")
for _, key in ipairs(UICopy.keys()) do emit("ui", key, UICopy.Table and (function()
 local node = UICopy.Table
 for part in string.gmatch(key, "[^%.]+") do node = node[part] end
 return node end)() or key, UICopy.get(key, SAMPLE)) end
-- Catalogues.
local fields = FIELDS
local skipPetNames = { PetCatalog = true }
for _, name in ipairs(CATALOG_LIST) do
 local module = load(name)
 local seen = {}
 local function walk(node, path, depth)
  if type(node) ~= "table" or node == Any or seen[node] or depth > 7 then return end
  seen[node] = true
  local keys = {}
  for k in pairs(node) do if type(k) == "string" or type(k) == "number" then table.insert(keys, k) end end
  table.sort(keys, function(a, b)
   if type(a) == type(b) then return a < b end
   return type(a) == "number"
  end)
  for _, k in ipairs(keys) do
   local v = node[k]
   local child = if path == "" then tostring(k) else path .. "." .. tostring(k)
   if type(v) == "string" and type(k) == "string" and skipPetNames[name] and k == "name" then
    emit("pet", name .. "." .. child, v, k)
   elseif type(v) == "string" and type(k) == "string" and fields[k] then
    emit("catalog", name .. "." .. child, v, k)
   elseif type(v) == "table" and type(k) == "string" and k == "names" then
    for i, item in ipairs(v) do if type(item) == "string" then emit("catalog", name .. "." .. child .. "." .. i, item, "names") end end
   elseif type(v) == "table" then
    walk(v, child, depth + 1)
   end
  end
 end
 walk(module, "", 0)
 -- Pet descriptions sit on the pet entries (PetCatalog sets pet.description).
end
if io_err then print("err\31\31" .. string.gsub(io_err, "\n", " | ") .. "\31") end
'''


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[" + text + "]" + eq + "]"


def lua_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return long_string(value)
    if isinstance(value, dict):
        return "{" + ",".join("[ " + lua_value(k) + " ]=" + lua_value(v) for k, v in value.items()) + "}"
    if isinstance(value, (list, tuple, set)):
        return "{" + ",".join(lua_value(v) for v in value) + "}"
    raise TypeError(value)


def run_luau():
    sources = {}
    for fname in os.listdir(SHARED):
        if fname.endswith(".lua"):
            with io.open(os.path.join(SHARED, fname), encoding="utf-8") as handle:
                sources[fname[:-4]] = handle.read()
    script = (HARNESS.replace("SOURCES", lua_value(sources))
              .replace("SAMPLE", lua_value(SAMPLE))
              .replace("FIELDS", "{" + ",".join(k + "=true" for k in sorted(TEXT_FIELDS)) + "}")
              .replace("CATALOG_LIST", lua_value(CATALOGS)))
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "export.luau")
        with io.open(path, "w", encoding="utf-8") as handle:
            handle.write(script)
        result = subprocess.run([LUAU, path], capture_output=True)
    out = result.stdout.decode("utf-8", "replace")
    if result.returncode != 0:
        sys.exit("luau failed:\n" + result.stderr.decode("utf-8", "replace") + out[-2000:])
    rows = []
    for line in out.splitlines():
        parts = line.split("\x1f")
        if len(parts) != 4:
            continue
        if parts[0] == "err":
            print("warning: module errors while loading:", parts[2], file=sys.stderr)
            continue
        rows.append(tuple(parts))
    return rows


def wearable_rows():
    """Wearable item names live in the rig definitions' JSON (WearableCatalog.forPet reads them)."""
    import json
    rows = []
    for fname in ("BearRigDefinition.lua", "PetRigDefinitions.lua", "NewBabyRigDefinitions.lua"):
        path = os.path.join(SHARED, fname)
        if not os.path.exists(path):
            continue
        with io.open(path, encoding="utf-8") as handle:
            text = handle.read()
        for blob in re.findall(r"JSONDecode\(\[(=*)\[(.*?)\]\1\]", text, re.S):
            try:
                data = json.loads(blob[1])
            except ValueError:
                continue
            if isinstance(data, dict) and "wearableItems" in data:  # one rig (BearRigDefinition)
                data = {data.get("legacyId") or data.get("id") or "pet": data}
            pets = data.items() if isinstance(data, dict) else []
            for pet_id, definition in pets:
                for item in (definition.get("wearableItems") or []) if isinstance(definition, dict) else []:
                    if isinstance(item, dict) and isinstance(item.get("name"), str):
                        rows.append(("catalog", "WearableCatalog.%s.%s.name" % (pet_id, item.get("id")), item["name"], "name"))
    return rows


# --- hard-coded client strings -------------------------------------------------------
STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
UI_LINE = re.compile(r'(\.Text\s*=|Kit\.text\(|\btxt\(|\btext\(|\btext\s*=|setText\(|\blabel\(|\.set\(|AccessibleLabel|ActionText|ObjectText|toast|warmLine|headline)')
NOT_TEXT = {
    "Body", "BodyMedium", "Small", "Label", "Strong", "Title", "Name", "Button", "Heading", "Counter", "CounterL",
    "Display", "Action", "Supporting", "text", "soft", "dim", "stars", "accent", "danger", "good", "ink", "white",
    "panel", "raised", "well", "selected", "line", "plain", "gold", "sticker", "reward", "primary", "secondary",
    "ghost", "destructive", "AccessibleLabel", "TextColor3", "BackgroundColor3", "ImageColor3", "Color",
}


def is_text(s):
    if len(s) < 2 or s in NOT_TEXT or "rbxasset" in s or "://" in s:
        return False
    if not re.search(r"[A-Za-z]{2}", s):
        return False
    if re.fullmatch(r"[a-z][A-Za-z0-9_]*", s):  # ids, keys, attribute names
        return False
    if re.fullmatch(r"[A-Z][a-z]+[A-Z][A-Za-z0-9]*", s):  # Instance names like PetName, NewDot
        return False
    if re.fullmatch(r"[A-Za-z0-9_]+\.[A-Za-z0-9_.]+", s):  # UICopy keys, dotted paths
        return False
    if s.startswith("#") or s.startswith("%") and not re.search(r"[A-Za-z]{3}", s):
        return False
    if "<" in s and ">" in s and not re.search(r">[^<]*[A-Za-z]{3}", s):
        return False
    return True


# Literals in these positions are instance names, roles or keys, not text.
NAME_POSITIONS = [
    re.compile(r'\bName\s*=\s*"[^"]*"'),
    re.compile(r'(?:Kit\.frame|Kit\.tile|Kit\.button|Kit\.well|Kit\.island|Kit\.modalShade|Kit\.node|\bnode|Instance\.new|'
               r'FindFirstChild\w*|WaitForChild|FindFirstAncestor\w*|SetAttribute|GetAttribute|GetPropertyChangedSignal|IsA|'
               r'GetService|Kit\.icon|Kit\.paint|\bpaint|Kit\.color|colorOf|UICopy\.get|UICopy\.has)\(\s*(?:[^"(),]*,\s*)?"[^"]*"'),
    # Local text(parent, name, ...) / label(parent, name, ...) helpers: the second argument is a name or role.
    re.compile(r'\b(?:text|label|txt)\(\s*[^",()]+,\s*"[^"]*"'),
]


def client_strings():
    rows = []
    for fname in sorted(os.listdir(CLIENT)):
        if not fname.endswith(".lua"):
            continue
        with io.open(os.path.join(CLIENT, fname), encoding="utf-8") as handle:
            for number, line in enumerate(handle, 1):
                code = line.split("--", 1)[0] if not line.lstrip().startswith("--") else ""
                if not code or not UI_LINE.search(code):
                    continue
                for pattern in NAME_POSITIONS:
                    code = pattern.sub("", code)
                for match in STRING.finditer(code):
                    text = match.group(1).replace('\\"', '"')
                    if not is_text(text) or text.endswith("_"):
                        continue
                    note = "fragment (sentence built from parts)" if text != text.strip() else ""
                    rows.append((fname, number, text, note))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", default=DEFAULT_OUT)
    parser.add_argument("--review", default=DEFAULT_REVIEW, help="hard-coded client strings review list")
    args = parser.parse_args()

    rows = run_luau() + wearable_rows()
    # Pet names stay as named (LOCALIZATION.md): never exported, wherever they appear.
    pet_names = {source for kind, _, source, _ in rows if kind == "pet"}
    rows = [row for row in rows if row[0] != "pet" and row[2] not in pet_names]

    entries, by_source = [], {}
    counts = {"ui": 0, "catalog": 0}
    for kind, key, source, extra in rows:
        source = source.replace("\\n", "\n")
        if not source.strip():
            continue
        if kind == "ui":
            note = SECTION_NOTES.get(key.split(".")[0], "Menu text")
            if "{" in source:
                note += "; e.g. " + extra
            full_key = "ui." + key
        else:
            if not is_text(source):  # colours, ids
                continue
            note = "Catalogue %s (%s)" % (key.split(".")[0], extra)
            full_key = "catalog." + key
        # Roblox matches captured text on Source (+ Context): one entry per Source.
        if source in by_source:
            entry = by_source[source]
            if full_key not in entry["also"] and len(entry["also"]) < 4:
                entry["also"].append(full_key)
            continue
        entry = {"Key": full_key, "Source": source, "Context": "", "Example": note, "also": []}
        by_source[source] = entry
        entries.append(entry)
        counts[kind] += 1

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with io.open(args.out, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\r\n")
        writer.writerow(["Key", "Source", "Context", "Example"])
        for entry in entries:
            example = entry["Example"]
            if entry["also"]:
                example += "; also " + ", ".join(entry["also"])
            writer.writerow([entry["Key"], entry["Source"], entry["Context"], example])
    print("wrote %s: %d strings (UICopy %d, catalogues %d)"
          % (os.path.relpath(args.out, ROOT), len(entries), counts["ui"], counts["catalog"]))

    review = [row for row in client_strings() if row[2] not in pet_names]
    os.makedirs(os.path.dirname(args.review), exist_ok=True)
    with io.open(args.review, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\r\n")
        writer.writerow(["File", "Line", "Text", "Note", "InUpload"])
        for fname, number, text, note in review:
            writer.writerow(["src/client/" + fname, number, text, note, "yes" if text in by_source else ""])
    fragments = sum(1 for row in review if row[3])
    print("wrote %s: %d hard-coded client strings (%d fragments)" % (os.path.relpath(args.review, ROOT), len(review), fragments))


if __name__ == "__main__":
    main()
