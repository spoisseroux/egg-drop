"""Index retained native JSON once per suite; never run Studio or edit runtime.

python scripts/summarize_aero_verification.py             # regenerate TEST-INDEX.md
python scripts/summarize_aero_verification.py --check     # verify index is current
python scripts/summarize_aero_verification.py --self-test # parser/counting contracts
"""
import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "artifacts/aero-garden-2026-11-09"


def unwrap(value):
    for _ in range(4):
        if not isinstance(value, dict) or "content" not in value:
            return value
        texts = [block["text"] for block in value["content"] if block.get("type") == "text"]
        if len(texts) != 1 or value.get("isError"):
            raise ValueError("Expected one successful native JSON text block")
        value = json.loads(texts[0])
    raise ValueError("Unexpected nesting of native tool wrappers")


def sequence(value):
    if isinstance(value, list):
        result = value
    elif isinstance(value, dict) and set(value) == {str(i) for i in range(1, len(value) + 1)}:
        result = [value[str(i)] for i in range(1, len(value) + 1)]
    else:
        raise ValueError("Expected a case list or contiguous 1-based numeric-key case map")
    if not result or any(not isinstance(case, str) or not case for case in result):
        raise ValueError("Case evidence must contain nonempty named cases")
    return tuple(result)


def cases_of(result):
    if isinstance(result, dict) and "cases" in result:
        cases = sequence(result["cases"])
        claimed = result.get("passed")
        if claimed is not None and (type(claimed) is not int or claimed != len(cases)):
            raise ValueError(f"passed={claimed!r} disagrees with {len(cases)} retained cases")
        return cases
    return sequence(result)


def rows(value, default_suite=None):
    if isinstance(value, dict) and "suites" in value:
        value = value["suites"]
    if isinstance(value, dict) and "ok" in value and "result" in value:
        if not default_suite:
            raise ValueError("Single-suite evidence needs an explicit suite identity")
        return [(default_suite, value)]
    if isinstance(value, list):
        if not all(isinstance(row, dict) and "suite" in row and "ok" in row for row in value):
            raise ValueError("Expected named suite-result rows")
        return [(row["suite"], row) for row in value]
    if isinstance(value, dict):
        return [(name, row) for name, row in value.items()
                if isinstance(row, dict) and "ok" in row and "result" in row]
    raise ValueError("Unrecognized suite-result envelope")


@dataclass(frozen=True)
class Evidence:
    cases: tuple
    file: str
    cohort: str


def apply_batch(selected, value, filename, cohort, default_suite=None, unresolved=None):
    failures = []
    for name, row in rows(value, default_suite):
        if row["ok"] is not True:
            failures.append(name)
            if unresolved is not None:
                unresolved[name] = filename
            continue
        cases = cases_of(row["result"])
        if "count" in row and row["count"] != len(cases):
            raise ValueError(f"{filename}/{name}: count disagrees with retained array")
        selected[name] = Evidence(cases, filename, cohort)
        if unresolved is not None:
            unresolved.pop(name, None)
    return failures


def count(selected):
    return sum(len(entry.cases) for entry in selected.values())


def table(selected):
    lines = ["| Suite | Cases | Selected raw evidence |", "|---|---:|---|"]
    for name, entry in sorted(selected.items()):
        lines.append(f"| {name} | {len(entry.cases)} | [{entry.file}]({entry.file}) · {entry.cohort} |")
    return lines


def generate(directory):
    used = {}

    def read(filename):
        raw = (directory / filename).read_bytes()
        used[filename] = hashlib.sha256(raw).hexdigest()
        return unwrap(json.loads(raw.decode("utf-8-sig")))

    server, server_unresolved = {}, {}
    apply_batch(server, read("server-final153.json"), "server-final153.json", "consolidated baseline", unresolved=server_unresolved)
    server_base = count(server)
    server_first_fail = apply_batch(server, read("server-late-pacing-first.json"), "server-late-pacing-first.json", "late pacing", unresolved=server_unresolved)
    apply_batch(server, read("server-pet-appearance19.json"), "server-pet-appearance19.json", "fresh fixture reload", "PetAppearance", server_unresolved)
    apply_batch(server, read("server-relocated-toy-final.json"), "server-relocated-toy-final.json", "final relocated toy", unresolved=server_unresolved)
    if server_unresolved:
        raise ValueError(f"Unresolved latest server failures; older passes cannot certify them: {server_unresolved}")

    largest = {}
    apply_batch(largest, read("client-full-largest.json"), "client-full-largest.json", "Largest matrix")
    medium, medium_unresolved = {}, {}
    medium_failures = apply_batch(medium, read("client-full-medium-first.json"), "client-full-medium-first.json", "Medium first run", unresolved=medium_unresolved)
    medium_initial = count(medium)
    medium_initial_suites = len(medium)
    apply_batch(medium, read("journal-medium-corrected.json"), "journal-medium-corrected.json", "Medium corrected label", "JournalPurpose", medium_unresolved)
    if medium_unresolved:
        raise ValueError(f"Unresolved Medium failures: {medium_unresolved}")
    if set(medium) != set(largest) or any(len(medium[name].cases) != len(largest[name].cases) for name in largest):
        raise ValueError("Corrected Medium and Largest baseline suite identities/counts differ")
    client, client_unresolved = dict(largest), {}
    apply_batch(client, read("client-late-focus-charm.json"), "client-late-focus-charm.json", "late native; preference not retained", unresolved=client_unresolved)
    apply_batch(client, read("client-relocated-toy-final.json"), "client-relocated-toy-final.json", "final relocated toy; preference not retained", unresolved=client_unresolved)
    # The transcript's 13-case pass is not raw evidence until actually saved.
    supplemental = "client-pet-focus-ui13.json"
    if (directory / supplemental).exists():
        apply_batch(client, read(supplemental), supplemental, "fresh final focus UI", "PetFocusUI", client_unresolved)
    primary = {name: entry for name, entry in client.items() if name in largest}
    additional = {name: entry for name, entry in client.items() if name not in largest}
    focus_count = len(client["PetFocusUI"].cases)
    pending = focus_count < 13
    if client_unresolved:
        raise ValueError(f"Unresolved latest client failures; older passes cannot certify them: {client_unresolved}")
    first_client_failures = []
    for filename in ("client-regressions-first.json", "focus-new-collector-first-native.json", "server-relocated-toy-first-runner.json"):
        first_client_failures.append((filename, apply_batch({}, read(filename), filename, "diagnostic only")))

    lines = ["# Aero garden native test index", "",
        "Generated from retained JSON by `python scripts/summarize_aero_verification.py`. This index does not run tests, certify source equality or publication, or replace actual controls/render evidence.", "",
        "## Unique current suite results", "",
        f"- **Server: {count(server)} cases across {len(server)} suite identities.** Baseline {server_base}; replace ToyReturn 11→23 (+12), ToyHost 4→5 (+1), PetAppearance 15→19 (+4), WorldRoutes 6→8 (+2): **153 + 12 + 1 + 4 + 2 = 172**.",
        f"- **Client core: {count(primary)} cases across {len(primary)} suite identities.** Largest baseline {count(largest)}; replace HueCharmIntent 5→7 (+2) and GardenToyClient 8→10 (+2): **197 + 2 + 2 = 201**.",
        f"- **Additional focus: {count(additional)} cases across {len(additional)} additional suite identities.** These are outside the original 30-suite matrix; the selected counts appear below.",
        f"- **All client suite identities together: {count(client)} cases across {len(client)} suites**, with repeated preferences/reruns counted once per suite.", ""]
    if pending:
        lines += [f"**Raw-evidence gap:** the retained PetFocusUI result contains **{focus_count}** cases. A later 13-case pass was reported in the root transcript, but its raw output is not yet saved here. Expected total after that one replacement: **292 client cases / 36 suites**. Save the fresh result as `{supplemental}` and regenerate; this index does not invent the missing case.", ""]
    else:
        lines += ["The fresh 13-case PetFocusUI raw result is retained; the expected **292 client cases / 36 suites** is supported by the selected files.", ""]
    expected = (count(server), len(server), count(primary), len(primary), count(client), len(client))
    if expected != (172, 19, 201, 30, 291 if pending else 292, 36):
        raise ValueError(f"Unexpected reconciled counts; review new evidence before indexing: {expected}")
    lines += ["## Server selection", ""] + table(server)
    lines += ["", "## Client core selection", ""] + table(primary)
    lines += ["", "## Additional focus selection", ""] + table(additional)
    lines += ["", "## Preferences and scope", "",
        f"- Original Largest matrix: **{count(largest)} / {len(largest)}**. Original Medium first run: **{medium_initial} / {medium_initial_suites} passing suites**, with {', '.join(medium_failures)} failed; its corrected 3-case rerun completes **{count(medium)} / {len(medium)}**. These repeated preferences are coverage, not extra unique cases.",
        "- The current 201-case core is a consolidation of that baseline and later native updates. The late file does not retain text preference; do not describe this as a newly recorded complete 201-case run at both Medium and Largest.",
        "- Counts follow actual retained case arrays, including Luau's 1-based numeric-key maps. Every present `passed`/`count` claim is checked against array length. Latest successful results replace the same suite; case lists from multiple revisions are never concatenated.",
        "- Final relocation files replace earlier results for their rerun suites. Any unresolved failure in an ordered late/final batch stops generation; the tool cannot silently fall back to an older passing row. Known failed-first records are superseded only by an explicit later pass of that same suite.",
        "- Internal assertions, 1,296×7 palette inputs, projection checks, frames, synthetic actors, care awards and repeated runs are not additional cases. Lighting/comparator QA and human-control/visual evidence are separate; no missing raw QA result is added here.",
        "- Native Studio fixtures do not establish physical-phone behavior, live DataStore rejoin, service outages, extended cooperative play, or publication.", "",
        "## Failed-first and correction trail", "",
        f"- [server-late-pacing-first.json](server-late-pacing-first.json): {', '.join(server_first_fail)} failed in that first late batch. [server-pet-appearance19.json](server-pet-appearance19.json) retains its fresh 19-case pass after fixture reload. Successful reruns of other suites replace baseline rows without increasing their counts.",
        "- [server-final153.json](server-final153.json) is already a consolidation. Its recorded provenance identifies three corrected runner signatures and the reviewed dry-world care mock correction; its 153 is not summed with older batches.",
        "- [client-full-medium-first.json](client-full-medium-first.json): JournalPurpose failed on the obsolete Foxfire Wick label. [journal-medium-corrected.json](journal-medium-corrected.json) preserves the corrected 3-case pass, with Kiprik's stable `foxfire_wick` route still checked."]
    for filename, failures in first_client_failures:
        lines.append(f"- [{filename}]({filename}): failed-first suites **{', '.join(failures)}**. Later passing selections above supersede these failures; they are not extra cases.")
    lines += ["- The relocated WorldRoutes first runner omitted its required current `LoungeArt.Source` argument. Its corrected final 8-case raw result is selected, while the failed runner artifact remains retained."]
    lines += ["- HueCharmIntent's first failure exposed an uninitialized shape-control table; GreetingLifecycle/PetFocusUI first attempts lacked current helper methods in their isolated mocks. The corrected runs remain separately retained.",
        "- [bridge-anchor-first-FAILED.json](bridge-anchor-first-FAILED.json) remains a failed diagnostic, not a pass. The dynamic bridge observation was later corrected to require a destination-bank crossing and a stable arrival within 3 studs before autonomous play; it does not claim dynamic exact-offset arrival. The independent static route fixture retains its <0.1-stud endpoint gate.",
        "- The original [two-client-focus-occlusion-FAILED.png](two-client-focus-occlusion-FAILED.png) remains unattributed. Repeated clear native shots do not diagnose that original image. GreetingOcclusion proves the separately reproduced tiny/nonqueryable-decor class.", "",
        "## Raw source fingerprints", "", "| Raw JSON | SHA-256 |", "|---|---|"]
    lines += [f"| [{name}]({name}) | `{digest}` |" for name, digest in sorted(used.items())]
    lines += ["", "Regenerate after saving new raw results. `--check` fails if this index is stale or a retained count disagrees with its actual cases.", ""]
    return "\n".join(lines), {"server": count(server), "server_suites": len(server), "client_core": count(primary),
        "client_core_suites": len(primary), "client_additional": count(additional), "client_total": count(client),
        "client_suites": len(client), "missing_raw_focus_ui13": pending}


def self_test():
    assert cases_of({"passed": 2, "cases": {"2": "b", "1": "a"}}) == ("a", "b")
    try:
        cases_of({"passed": 3, "cases": ["a", "b"]})
    except ValueError:
        pass
    else:
        raise AssertionError("Mismatched claimed count accepted")
    wrapped = {"content": [{"type": "text", "text": '{"ok":true,"result":["a"]}'}]}
    selected, unresolved = {}, {}
    apply_batch(selected, unwrap(wrapped), "base.json", "test", "S")
    apply_batch(selected, {"S": {"ok": False, "result": "failed"}}, "failed.json", "test", unresolved=unresolved)
    assert count(selected) == 1 and unresolved == {"S": "failed.json"}
    apply_batch(selected, {"S": {"ok": True, "result": ["a", "b"]}}, "new.json", "test", unresolved=unresolved)
    assert count(selected) == 2 and selected["S"].file == "new.json" and not unresolved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test(); print("PASS: wrapper, numeric map, claimed-count mismatch and replace-without-double-count contracts"); return
    output, summary = generate(DIRECTORY)
    target = DIRECTORY / "TEST-INDEX.md"
    if args.check:
        if not target.exists() or target.read_text(encoding="utf-8") != output:
            raise SystemExit("TEST-INDEX.md is stale; regenerate from current raw results")
    else:
        target.write_text(output, encoding="utf-8")
    print(json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
