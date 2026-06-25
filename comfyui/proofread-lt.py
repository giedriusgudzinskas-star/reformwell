# Reformwell - conservative Lithuanian proofreading pass over all prose in data.js
# using GPT-4o. Proposes a fix ONLY for genuine errors (wrong case/declension,
# mistranslation/wrong word for context, unnatural calque, illogical sentence).
# Writes proposals to _lt-fixes.json for human review BEFORE applying.
#
#   $env:OPENAI_API_KEY="sk-..."; python proofread-lt.py [LIMIT]
import os, sys, json, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(ROOT, "..", "data.js")
OUT = os.path.join(ROOT, "_lt-fixes.json")
KEY = os.environ.get("OPENAI_API_KEY", "").strip()
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 0
if not KEY: print("no key"); sys.exit(1)

raw = open(DATA, encoding="utf-8-sig").read()
s = raw.find("{"); e = raw.rfind("}")
d = json.loads(raw[s:e+1])

strings, seen = [], set()
def add(t):
    if t and isinstance(t, str) and len(t.split()) > 2 and t not in seen:
        seen.add(t); strings.append(t)
biz = d.get("business", {})
add(biz.get("heroSub"))
for v in biz.get("valueProps", []): add(v.get("body"))
for v in biz.get("faq", []): add(v.get("a")); add(v.get("q"))
add(biz.get("aboutCopy"))
for c in d.get("conditions", []):
    add(c.get("overview"))
    for k in ("whoIsThisFor","expectedOutcomes","seeADoctorIf"):
        for x in c.get(k, []): add(x)
    for key in ("shortProgram","longProgram"):
        for ph in c.get(key, {}).get("phases", []):
            add(ph.get("focus"))
            for ex in ph.get("exercises", []):
                add(ex.get("cues")); add(ex.get("progression")); add(ex.get("why"))

if LIMIT: strings = strings[:LIMIT]
print("unique prose strings:", len(strings))

INSTR = (
    "Tu esi profesionalus lietuvių kalbos redaktorius. Tekstas yra fizioterapijos/reabilitacijos "
    "produkto turinys, verstas iš anglų kalbos automatiniu būdu. Kiekvienai eilutei pateik pataisymą "
    "TIK jei joje yra TIKRA klaida: netaisyklinga linksniuotė/giminė/derinimas, vertimo klaida ar "
    "kontekstui netinkamas žodis (pvz. 'prikimęs' apie skausmą), nenatūralus anglicizmas/kalkė, arba "
    "nelogiškas/iškraipytas sakinys. NEKEISK teksto, kuris jau taisyklingas ir natūralus (netaisyk vien "
    "dėl stiliaus). Išlaikyk prasmę, medicininius terminus, mandagumo formą (daugiskaitos 'jūs'). "
    "Grąžink TIK JSON masyvą, be markdown. Kiekvienam PAKEISTAM elementui: "
    '{"i": numeris, "fixed": "taisytas tekstas", "reason": "trumpa priežastis lietuviškai"}. '
    "Nepataisytų eilučių NEįtrauk."
)

def call(batch, base):
    lines = "\n".join(f"{base+j}. {t}" for j, t in enumerate(batch))
    body = {"model":"gpt-4o","temperature":0,"max_tokens":2000,
        "messages":[{"role":"user","content": INSTR + "\n\nEILUTĖS:\n" + lines}]}
    req = urllib.request.Request("https://api.openai.com/v1/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={"Authorization":"Bearer "+KEY,"Content-Type":"application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        out = json.loads(r.read().decode("utf-8"))
    txt = out["choices"][0]["message"]["content"].strip().replace("```json","").replace("```","").strip()
    return json.loads(txt)

B = 20
fixes = []
for i in range(0, len(strings), B):
    batch = strings[i:i+B]
    for attempt in range(4):
        try:
            arr = call(batch, i)
            for item in arr:
                idx = item.get("i")
                if idx is None or idx < 0 or idx >= len(strings): continue
                orig = strings[idx]
                fx = item.get("fixed","").strip()
                if fx and fx != orig:
                    fixes.append({"original": orig, "fixed": fx, "reason": item.get("reason","")})
            print(f"  batch {i//B+1}/{(len(strings)+B-1)//B}: +{len(arr)} flagged")
            break
        except urllib.error.HTTPError as ex:
            if ex.code in (429,500,502,503): time.sleep(5*(attempt+1)); continue
            print("HTTP", ex.code, ex.read().decode()[:200]); break
        except Exception as ex:
            if attempt < 3: time.sleep(3); continue
            print("ERR batch", i//B+1, ex)
    json.dump(fixes, open(OUT,"w",encoding="utf-8"), ensure_ascii=False, indent=1)
    time.sleep(0.3)

print(f"\nProposed fixes: {len(fixes)}  saved to {OUT}")
