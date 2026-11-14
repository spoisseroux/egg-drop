"""Sync Egg Drop's English strings to the experience's cloud localization table.

Run on every build, before publishing:

    python scripts/export_localization_csv.py     # regenerate the CSV from UICopy + catalogues
    python scripts/sync_localization.py           # push adds/changes, retire removed strings

Roblox's automatic translation then translates the new/changed source strings (languages
and auto-translate are on in Creator Hub). Translations already on the table are kept;
an entry whose English source changed gets a new identifier, so it is re-translated.

Auth: an Open Cloud API key with the `legacy-universe:manage` scope for universe
10774758591, read from ROBLOX_LOCALIZATION_KEY (env, or ~/.claude/.env). Without a key,
`--emit DIR` writes the PATCH bodies so the coordinator can send them through the Studio
MCP `open_cloud_invoke` (same scope must be granted in Studio's Assistant MCP Permissions).

State: assets/localization/synced.json remembers what this script last pushed (key ->
source, context, example) so a string removed from the game is deleted from the table
(only entries this script created; captured or hand-made entries are never touched).
"""
import argparse
import csv
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(ROOT, "assets", "localization", "egg-drop-strings.csv")
STATE_PATH = os.path.join(ROOT, "assets", "localization", "synced.json")
UNIVERSE_ID = 10774758591
API = "https://apis.roblox.com/legacy-localization-tables/v1"
DEFAULT_BATCH = 50  # the API refuses 100 per PATCH although /limits reports 300


def load_key():
    key = os.environ.get("ROBLOX_LOCALIZATION_KEY")
    if key:
        return key.strip()
    env = os.path.join(os.path.expanduser("~"), ".claude", ".env")
    if os.path.exists(env):
        with open(env, encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("ROBLOX_LOCALIZATION_KEY="):
                    return line.split("=", 1)[1].strip().strip('"')
    return None


def read_csv(path):
    rows = {}
    with open(path, encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            key = (row.get("Key") or "").strip()
            source = row.get("Source") or ""
            if not key or not source:
                continue
            rows[key] = {"source": source, "context": row.get("Context") or "", "example": row.get("Example") or ""}
    return rows


def load_state():
    if not os.path.exists(STATE_PATH):
        return {}
    with open(STATE_PATH, encoding="utf-8") as fh:
        return json.load(fh).get("entries", {})


def save_state(entries):
    with open(STATE_PATH, "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"schema": 1, "universeId": UNIVERSE_ID, "entries": dict(sorted(entries.items()))}, fh, indent=1, ensure_ascii=False)
        fh.write("\n")


def ident(key, e):
    return {"key": key, "context": e["context"], "source": e["source"]}


def plan(current, previous):
    """Entries to upsert (new or changed) and to delete (removed or replaced identifiers)."""
    upserts, deletes = [], []
    for key, e in current.items():
        old = previous.get(key)
        if old == e:
            continue
        if old and (old["source"] != e["source"] or old["context"] != e["context"]):
            deletes.append({"identifier": ident(key, old), "delete": True})
        upserts.append({"identifier": ident(key, e), "metadata": {"example": e["example"]}})
    for key, old in previous.items():
        if key not in current:
            deletes.append({"identifier": ident(key, old), "delete": True})
    return upserts, deletes


def request(method, path, key, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("x-api-key", key)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    delay = 1.0
    for _ in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as res:
                raw = res.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as err:
            if err.code == 429 or err.code >= 500:
                time.sleep(delay)
                delay *= 2
                continue
            raise SystemExit(f"{method} {path} -> {err.code}: {err.read().decode('utf-8', 'replace')[:400]}")
    raise SystemExit(f"{method} {path}: gave up after retries")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--csv", default=CSV_PATH)
    parser.add_argument("--dry-run", action="store_true", help="print the plan, send nothing")
    parser.add_argument("--emit", metavar="DIR", help="write PATCH bodies to DIR instead of sending (MCP route)")
    parser.add_argument("--table-id", help="skip the table lookup")
    parser.add_argument("--mark-synced", action="store_true", help="record the CSV as synced (after an --emit batch was sent)")
    args = parser.parse_args()

    current = read_csv(args.csv)
    previous = load_state()
    if args.mark_synced:
        save_state(current)
        print(f"marked {len(current)} entries as synced")
        return
    upserts, deletes = plan(current, previous)
    ops = deletes + upserts  # deletes first: a changed source frees its old identifier
    print(f"{len(current)} strings; {len(upserts)} add/update, {len(deletes)} delete")
    if args.dry_run or not ops:
        return

    batches = [ops[i:i + DEFAULT_BATCH] for i in range(0, len(ops), DEFAULT_BATCH)]
    if args.emit:
        os.makedirs(args.emit, exist_ok=True)
        for n, batch in enumerate(batches, 1):
            with open(os.path.join(args.emit, f"patch-{n:02d}.json"), "w", encoding="utf-8") as fh:
                json.dump({"entries": batch}, fh, ensure_ascii=False)
        print(f"wrote {len(batches)} PATCH bodies to {args.emit}; send each to "
              f"PATCH /legacy-localization-tables/v1/localization-table/tables/<tableId>, then run --mark-synced")
        return

    key = load_key()
    if not key:
        raise SystemExit("No ROBLOX_LOCALIZATION_KEY (env or ~/.claude/.env). Use --emit DIR for the MCP route.")
    table_id = args.table_id
    if not table_id:
        info = request("POST", f"/autolocalization/games/{UNIVERSE_ID}/autolocalizationtable", key, {})
        table_id = info.get("autoLocalizationTableId")
        if not table_id:
            raise SystemExit(f"no table id in {info}")
    limits = request("GET", "/localization-table/limits", key)
    size = max(1, min(DEFAULT_BATCH, (((limits.get("tableOperationLimits") or {}).get("maxEntriesPerUpdate")) or DEFAULT_BATCH) - 1))
    batches = [ops[i:i + size] for i in range(0, len(ops), size)]
    failed = 0
    for batch in batches:
        res = request("PATCH", f"/localization-table/tables/{table_id}?gameId={UNIVERSE_ID}", key, {"entries": batch})
        bad = res.get("failedEntriesAndTranslations") or []
        failed += len(bad)
        for f in bad[:5]:
            print("FAILED", json.dumps(f)[:300], file=sys.stderr)
    if failed:
        raise SystemExit(f"{failed} entries failed; state not updated (rerun after fixing)")
    save_state(current)
    print(f"synced to table {table_id}: {len(upserts)} add/update, {len(deletes)} delete")


if __name__ == "__main__":
    main()
