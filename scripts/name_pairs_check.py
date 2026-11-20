"""Pet names: list every name the catalogue can make and flag joins that need a human look.

Reads the piece texts from src/shared/NameCatalog.lua, builds every single piece and every
ordered pair of two different pieces (52 pieces: 52 + 2,652 names), and checks each joined
name, with and without its space, for words on a small blocklist. A hit is a prompt for the
pair read in V2-CUTE-ICONS-AND-NAMES-2026-11-20 2.5, not a verdict; change a piece rather than
block a pair. Writes the full list to --out for the printed read.

    python scripts/name_pairs_check.py [--out artifacts/v2-naming-build/all-names.txt]
"""
import argparse
import itertools
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Short on purpose: substrings that should never appear across a join in an all-ages game.
BLOCK = ["ass", "butt", "poo", "pee", "fart", "sex", "nud", "kill", "dead", "die", "drug", "beer",
         "wine", "gun", "hate", "nazi", "fag", "cum", "tit", "dick", "cock", "porn", "rape", "slut",
         "whore", "damn", "hell", "crap", "piss", "shit", "fuck", "bitch", "nig", "spic", "kike"]


def pieces():
    text = open(os.path.join(ROOT, "src", "shared", "NameCatalog.lua"), encoding="utf-8").read()
    return re.findall(r'\{id="([a-z]+)",text="([^"]+)"', text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out")
    args = parser.parse_args()
    found = pieces()
    words = [t for _, t in found]
    pairs = list(itertools.permutations(words, 2))
    names = list(words) + [a + " " + b for a, b in pairs]
    inside = [(w, b) for w in words for b in BLOCK if b in w.lower()]
    flagged = []
    for a, b in pairs:
        squashed = (a + b).lower()
        for word in BLOCK:
            # Only a hit the join creates (not one already inside either piece).
            if word in squashed and word not in a.lower() and word not in b.lower():
                flagged.append((a + " " + b, word))
    if args.out:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
        with open(args.out, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(names) + "\n")
    print("%d pieces, %d names (%d single, %d pairs)" % (len(words), len(names), len(words), len(names) - len(words)))
    print("inside a piece (read once): %s" % (", ".join("%s (%s)" % x for x in inside) or "none"))
    print("flagged across a join: %d" % len(flagged))
    for name, word in flagged:
        print("  %-24s %s" % (name, word))
    longest = max(names, key=len)
    print("longest: %s (%d characters)" % (longest, len(longest)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
