# Reformwell — physical-therapy program store

> *Guided recovery, on your own schedule.*

A professional, fully static website that sells self-guided physical-therapy programs for the
most common injuries and functional problems. Each condition comes in two versions: a short
**Relief & Reset** plan (3–4 weeks) and a full **Rehab & Resilience** program (8–12 weeks).

No build step, no framework, no backend — just HTML, CSS, and vanilla JavaScript. It runs by
opening a file and deploys free to GitHub Pages.

## What's in here

| File | What it does |
|------|--------------|
| `index.html` | Landing page (hero, programs, pricing, FAQ, about) |
| `program.html` | Program detail page — renders any program from `?slug=` |
| `data.js` | **All site content** (brand, copy, pricing, and the 8 programs) |
| `main.js` | Renders the pages, runs the cart, and handles checkout |
| `styles.css` | The full design system |
| `serve.ps1` | A tiny local web server for previewing (Windows/PowerShell) |

The 8 programs cover: low back pain, neck & upper-back pain, shoulder / rotator cuff,
knee pain, plantar fasciitis, tennis & golfer's elbow, hip & glute, and ankle-sprain recovery.

## Run it locally

Because the site loads `data.js`, you need to open it through a web server (not by
double-clicking the HTML file). From this folder:

```powershell
powershell -ExecutionPolicy Bypass -File serve.ps1 -Port 8787
```

Then open <http://localhost:8787> in your browser.

## Edit the content

Everything you'd want to change lives in `data.js` — prices, copy, exercises, FAQs.
Change `business.pricing`, edit any program's exercises, or tweak the brand copy, then refresh.

## The downloadable program PDFs

The actual products buyers receive live in `downloads/` — one branded PDF per program
(16 total: a short and a full version for each of the 8 conditions). Each PDF has a cover,
the condition overview, red-flag warnings, the full phased exercise plan, self-care tips,
expected outcomes, a 6-week progress tracker, and the medical disclaimer.

To regenerate them after editing `data.js` (uses headless Microsoft Edge — no install needed):

```powershell
powershell -ExecutionPolicy Bypass -File make-pdfs.ps1
```

`print.html` is the print-optimized template the PDFs are rendered from. Upload the files in
`downloads/` to Gumroad/Stripe so each purchase delivers the matching PDF.

## Add an image to each exercise (ComfyUI)

Every exercise can show an illustration next to it — on the program pages **and** in the PDFs.
The pictures are generated for free with [ComfyUI](https://github.com/comfyanonymous/ComfyUI) and
the whole set uses one consistent "soft 3D illustration" style.

Everything lives in `comfyui/`:

| File | What it does |
|------|--------------|
| `COMFYUI-GUIDE.md` | **Start here** — full beginner walkthrough (install, model, settings, batching) |
| `EXERCISE-PROMPTS.md` | 257 ready-to-paste prompts, one per exercise, with the exact filename to save |
| `exercise-prompts.json` | The same data for tools/scripts (slug, filename, prompt, shared negative) |
| `import-images.ps1` | Copies your generated images into `assets/exercises/` with the correct names |

The site finds an image by turning the exercise name into a **slug** (e.g. *Glute Bridge* →
`glute-bridge`) and loading `assets/exercises/glute-bridge.png`. Until that file exists, a tidy
placeholder is shown, so the site always looks finished. You can add images gradually — start with
the short "Relief & Reset" exercises, which appear first for each condition. After importing, run
`make-pdfs.ps1` to put the images into the downloadable PDFs too.

## Connect payments (go live)

The storefront is complete; you just connect a payment provider. **No server or coding required.**

1. Create a product for each program on **Gumroad** (easiest — it delivers the file
   automatically) or **Stripe Payment Links** (lowest fees).
2. Copy each product's payment link.
3. Paste them into `PAYMENT_LINKS` at the top of `main.js`, keyed by SKU
   (e.g. `"low-back-pain__short": "https://buy.stripe.com/..."`).

Until links are added, the **Checkout** button shows the full step-by-step setup guide.
The complete guide is also in `_payment-guide.txt`.

## Deploy free to GitHub Pages

```powershell
# from this folder, once payments/content are ready
git init
git add .
git commit -m "Reformwell storefront"
gh repo create reformwell --public --source . --remote origin --push
gh api -X POST repos/<you>/reformwell/pages -f "source[branch]=main" -f "source[path]=/"
```

Your site goes live at `https://<your-username>.github.io/reformwell/`.

## ⚠️ Important — medical & legal

This site sells health products. The medical disclaimers and "see a clinician first"
red-flag warnings (written by a clinical-safety reviewer) are part of the product and
**must stay visible**. Before taking real money:

- Replace the **example testimonials** in `data.js` with genuine, consented reviews.
- Have a qualified physiotherapist review the program content and put a real, named
  clinician behind the brand.
- Consider local regulations for selling health/exercise guidance and add proper
  Terms of Service and Privacy Policy pages.
