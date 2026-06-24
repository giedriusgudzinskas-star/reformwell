# Reformwell - independent image QC using GPT-4o vision.
# Compares each exercise photo against its intended description and flags mismatches.
# API key read from env OPENAI_API_KEY (never stored in this file).
#
#   $env:OPENAI_API_KEY="sk-..."; python qc-images.py [LIMIT]
#
# Writes/updates _qc-results.json (resumable: already-judged slugs are skipped).
import os, sys, json, base64, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(ROOT, "..", "assets", "exercises")
RESULTS = os.path.join(ROOT, "_qc-results.json")
KEY = os.environ.get("OPENAI_API_KEY", "").strip()
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 0

if not KEY:
    print("ERROR: OPENAI_API_KEY not set"); sys.exit(1)

man = json.load(open(os.path.join(ROOT, "exercise-prompts.json"), encoding="utf-8-sig"))
exercises = man["exercises"]

results = {}
if os.path.exists(RESULTS):
    try: results = json.load(open(RESULTS, encoding="utf-8"))
    except Exception: results = {}

INSTRUCTION = (
    "You are a meticulous physiotherapy content reviewer. You are shown a PHOTO meant to "
    "illustrate one specific exercise, plus the exercise NAME and the INTENDED body "
    "position/movement. Judge ONLY whether the photo correctly and clearly depicts THIS exercise. "
    "A teal motion arrow may be intentionally overlaid to show movement direction - that is fine, do NOT flag it. "
    "Respond with ONLY compact JSON, no markdown, exactly: "
    '{"verdict":"match|minor|mismatch","problem":"short or empty","fix":"short regeneration hint or empty"}. '
    "verdict=match: clearly correct. minor: mostly right, small issue, still usable. "
    "mismatch: wrong exercise/body part, anatomically wrong or impossible, or too unclear to tell - needs regeneration."
)

def pose_of(e):
    p = e.get("prompt", "")
    cut = p.find(", photorealistic")
    return p[:cut] if cut > 0 else p

def call(name, pose, b64):
    body = {
        "model": "gpt-4o",
        "temperature": 0,
        "max_tokens": 200,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": INSTRUCTION + f"\n\nEXERCISE NAME: {name}\nINTENDED POSITION/MOVEMENT: {pose}"},
                {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b64, "detail": "low"}},
            ],
        }],
    }
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request("https://api.openai.com/v1/chat/completions", data=data,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=90) as r:
        out = json.loads(r.read().decode("utf-8"))
    return out["choices"][0]["message"]["content"].strip()

targets = exercises[:LIMIT] if LIMIT else exercises
done = sum(1 for e in targets if e["slug"] in results)
print(f"Targets: {len(targets)}  already done: {done}")

n = 0
for e in targets:
    slug = e["slug"]
    if slug in results:
        continue
    img = os.path.join(ASSETS, slug + ".jpg")
    if not os.path.exists(img):
        results[slug] = {"verdict": "missing", "problem": "no jpg file", "fix": ""}
        continue
    b64 = base64.b64encode(open(img, "rb").read()).decode("ascii")
    pose = pose_of(e)
    for attempt in range(4):
        try:
            raw = call(e["name"], pose, b64)
            raw = raw.replace("```json", "").replace("```", "").strip()
            v = json.loads(raw)
            v["name"] = e["name"]
            results[slug] = v
            n += 1
            print(f"  {v.get('verdict','?'):8} {slug}")
            break
        except urllib.error.HTTPError as ex:
            msg = ex.read().decode("utf-8")[:200]
            if ex.code in (429, 500, 502, 503):
                time.sleep(5 * (attempt + 1)); continue
            print(f"  HTTP {ex.code} {slug}: {msg}"); results[slug] = {"verdict": "error", "problem": f"HTTP {ex.code}", "fix": ""}; break
        except Exception as ex:
            if attempt < 3:
                time.sleep(3); continue
            print(f"  ERR {slug}: {ex}"); results[slug] = {"verdict": "error", "problem": str(ex)[:120], "fix": ""}
    # save incrementally every 5
    if n % 5 == 0:
        json.dump(results, open(RESULTS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    time.sleep(0.3)

json.dump(results, open(RESULTS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
# summary
from collections import Counter
c = Counter(v.get("verdict") for v in results.values())
print("\n=== SUMMARY ===")
for k, n2 in c.most_common():
    print(f"  {k}: {n2}")
print(f"Total judged: {len(results)}  saved to {RESULTS}")
