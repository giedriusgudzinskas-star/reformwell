# Apply selected proofreading fixes to data.js.
# Strings in data.js are \u-escaped ASCII, so we escape search+replace the same way.
#   python apply-fixes.py 1,2,3,...
import os, sys, json

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(ROOT, "..", "data.js")
fixes = json.load(open(os.path.join(ROOT, "_lt-fixes.json"), encoding="utf-8"))
idxs = [int(x) for x in sys.argv[1].split(",")] if len(sys.argv) > 1 else []

def esc(s):
    return "".join(("\\u%04x" % ord(c)) if ord(c) > 127 else c for c in s)

raw = open(DATA, encoding="utf-8").read()
applied, notfound = [], []
for i in idxs:
    fx = fixes[i]
    o = esc(fx["original"]); n = esc(fx["fixed"])
    if o in raw:
        cnt = raw.count(o)
        raw = raw.replace(o, n)
        applied.append((i, cnt, fx["original"], fx["fixed"]))
    else:
        notfound.append(i)

open(DATA, "w", encoding="utf-8").write(raw)
print(f"Applied {len(applied)} fixes; not-found {len(notfound)}: {notfound}\n")
for i, cnt, o, n in applied:
    print(f"#{i} (x{cnt}):")
    print(f"   - {o}")
    print(f"   + {n}\n")
