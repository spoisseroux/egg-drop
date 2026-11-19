"""Pocket Pals v2 stat curve (scope 2026-11-19). Proposal numbers, not shipped.
XP needed to BE level L (1..99):  xp(L) = floor(n^3/40 + 2*n^2 + 12*n),  n = L-1
Run: python xp_curve.py   (prints the tables used in V2-SCOPE-2026-11-19.md, writes xp_table.csv)
"""
import csv, math, os
CAP = 99
def xp(level):
    n = level - 1
    return (n**3 + 80*n**2 + 480*n) // 40          # integer form of n^3/40 + 2n^2 + 12n
def level(points):
    l = 1
    while l < CAP and points >= xp(l + 1): l += 1
    return l
FRESH = 100   # first 100 XP per stat per day counts double
# XP per day in ONE stat before the Fresh bonus, by player type (see scope section 3.4)
RATES = {  # stat: (casual 5 rounds + 5 min, daily 10 rounds + 10 min, engaged 15 rounds + 15 min)
    "Pop":    (125, 250, 375),
    "Poise":  ( 90, 210, 375),
    "Heart":  ( 40,  80, 120),
    "Tumble": ( 40,  90, 140),
    "Fetch":  ( 30,  70, 110),
    "Wonder": ( 90, 150, 220),
}
def days(target, per_day):
    return math.ceil(target / (per_day + min(per_day, FRESH)))
if __name__ == "__main__":
    marks = [2, 3, 5, 10, 25, 50, 75, 90, 99]
    print("level  xp_to_reach  gap_from_prev  pct_of_99")
    for l in marks:
        print(f"{l:>5}  {xp(l):>11,}  {xp(l)-xp(l-1):>13,}  {xp(l)/xp(CAP)*100:>8.1f}%")
    half = next(l for l in range(1, CAP + 1) if xp(l) >= xp(CAP) / 2)
    print("half of the XP to 99 is reached at level", half)
    print("\nPlay days to reach a level (Fresh bonus included), one stat:")
    for stat, (c, d, e) in RATES.items():
        row = "  ".join(f"L{l}: {days(xp(l), c):>4}/{days(xp(l), d):>4}/{days(xp(l), e):>4}" for l in (10, 25, 50, 75, 99))
        print(f"{stat:<7} casual/daily/engaged  {row}")
    print("\nDays to max every stat (slowest stat decides):")
    for i, name in enumerate(("casual", "daily", "engaged")):
        print(f"  {name}: {max(days(xp(CAP), r[i]) for r in RATES.values())} play days")
    print("\nFirst session (Welcome round + 4 rounds, a pet, one park game, one fetch):")
    first = {"Pop": 110, "Poise": 70, "Heart": 20, "Tumble": 12, "Fetch": 8, "Wonder": 40}
    total = 0
    for stat, raw in first.items():
        got = raw + min(raw, FRESH); l = level(got); total += l
        print(f"  {stat:<7} {got:>4} XP -> level {l}")
    print("  total level", total, "of", 6 * CAP)
    # Bond -> Heart conversion (x4): every Bond trick stays unlocked
    bond = [0, 25, 75, 150, 250, 350, 475, 600, 725, 850]
    print("\nBond xp x4 -> Heart level:", [level(b * 4) for b in bond])
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "xp_table.csv"), "w", newline="") as f:
        w = csv.writer(f); w.writerow(["level", "xp_to_reach", "xp_from_previous_level"])
        for l in range(1, CAP + 1): w.writerow([l, xp(l), xp(l) - xp(l - 1) if l > 1 else 0])
