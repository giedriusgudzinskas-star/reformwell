# Project brief — Reformwell

*A reusable, professional brief for this product. Use it to onboard a designer, developer,
copywriter, or AI assistant, or as the master prompt to regenerate/extend the site.*

---

## The prompt (copy-paste ready)

> Build a professional, trustworthy e-commerce website for a solo founder selling **self-guided
> physical-therapy programs** for the most common injuries and functional problems. Each condition
> ships in two products: a **short "Relief & Reset"** plan (3–4 weeks, to calm a flare-up) and a
> **full "Rehab & Resilience"** program (8–12 weeks, to rebuild strength and prevent recurrence).
>
> **Conditions to cover:** low back pain, neck & upper-back pain, shoulder / rotator cuff, knee
> pain (patellofemoral / runner's knee), plantar fasciitis, tennis & golfer's elbow, hip & glute,
> ankle-sprain recovery.
>
> **For each program**, provide a plain-language overview, who it's for, **red-flag "see a clinician
> first" warnings**, and a phased plan where every exercise lists sets, reps, tempo/hold, form cues,
> a progression/regression, and the rehab rationale ("why").
>
> **Brand & design:** calm, clinical, premium — a blend of a modern physiotherapy clinic and a
> polished direct-to-consumer health brand. Accessible (WCAG AA), conversion-oriented, mobile-first.
>
> **Commerce:** product catalog, cart, and checkout that connects to no-code payment providers
> (Stripe Payment Links / Gumroad) so a non-technical founder can take payment and deliver files
> automatically. Deployable free as a static site (GitHub Pages).
>
> **Compliance:** prominent medical disclaimers throughout; content reviewed for clinical safety;
> testimonials clearly marked as placeholders until real, consented reviews exist. These programs
> are a complement to professional care, never a replacement for in-person assessment.

---

## Positioning

- **Audience:** adults 25–60 with common aches and injuries who want a credible, structured plan
  instead of random YouTube videos — at a fraction of the cost of repeated clinic visits.
- **Promise:** the same progressive logic a good physiotherapist uses (settle → restore movement →
  rebuild strength), packaged to follow at home.
- **Tone:** reassuring, honest, plain-language. Tells you when to push, when to ease off, and when
  to stop and see a clinician.

## Product & pricing

| Tier | Price | What it is |
|------|------:|------------|
| Relief & Reset | $39 | One short 3–4 week program |
| Full Rehab & Resilience | $89 | One full 8–12 week program |
| All-Access bundle | $149 | Every program, both versions, future updates |

Digital delivery (PDF + tracker + quick-start). Instant download, kept forever, free updates.

## Guardrails (non-negotiable)

1. Keep medical disclaimers and red-flag warnings visible — they ship with the product.
2. Put a real, named, qualified physiotherapist behind the brand before launch.
3. Replace placeholder testimonials with genuine, consented reviews.
4. Add real Terms of Service, Privacy Policy, and refund terms; check local regulations for
   selling health/exercise guidance.

## Tech

Static site (HTML/CSS/vanilla JS). All content in `data.js`. No backend; payments via no-code
links. See `README.md` for run, edit, payment, and deployment instructions.
