/* Reformwell — site renderer, cart, and checkout
   All content is read from window.SITE_DATA (data.js). */

(function () {
  "use strict";
  var D = window.SITE_DATA || {};
  var biz = D.business || {};
  var design = D.design || {};
  var conditions = D.conditions || [];
  var safety = D.safety || {};
  var P = biz.pricing || { shortUSD: 0, longUSD: 0 };

  /* ---------------------------------------------------------------
     PAYMENT LINKS — connect real checkout here.
     Create a Stripe Payment Link or Gumroad product for each item,
     then paste its URL below. Keys are the SKUs (see skuFor()).
     Example:  "low-back-pain__short": "https://buy.stripe.com/abc123"
     While these are empty, Checkout shows setup instructions.
  --------------------------------------------------------------- */
  var PAYMENT_LINKS = {
    "low-back-pain__short":       "https://buy.stripe.com/test_cNi3co3rYcTL0Pm0Eie7m00",
    "low-back-pain__long":        "https://buy.stripe.com/test_14AaEQ3rY7zr55CaeSe7m01",
    "neck-pain__short":           "https://buy.stripe.com/test_6oU3co5A6g5X0Pm4Uye7m02",
    "neck-pain__long":            "https://buy.stripe.com/test_5kQbIU9Qm8Dv8hO9aOe7m03",
    "shoulder__short":            "https://buy.stripe.com/test_eVqcMY6Ea2f79lScn0e7m04",
    "shoulder__long":             "https://buy.stripe.com/test_5kQcMY8Mi2f77dK4Uye7m05",
    "knee-pain__short":           "https://buy.stripe.com/test_dRm9AM3rY4nfgOkdr4e7m06",
    "knee-pain__long":            "https://buy.stripe.com/test_7sY7sE3rY1b341y2Mqe7m07",
    "plantar-fasciitis__short":   "https://buy.stripe.com/test_4gM00ce6Cf1T1Tq1Ime7m08",
    "plantar-fasciitis__long":    "https://buy.stripe.com/test_28EfZae6C9Hz2XuaeSe7m09",
    "tennis-elbow__short":        "https://buy.stripe.com/test_7sY28kaUq6vn1Tq2Mqe7m0a",
    "tennis-elbow__long":         "https://buy.stripe.com/test_7sY28kbYubPH1Tq3Que7m0b",
    "hip-glute__short":           "https://buy.stripe.com/test_4gMcMYfaG6vn1Tq1Ime7m0c",
    "hip-glute__long":            "https://buy.stripe.com/test_aFa28k5A63jbdC8fzce7m0d",
    "ankle-sprain__short":        "https://buy.stripe.com/test_cNifZa1jQaLD8hOfzce7m0e",
    "ankle-sprain__long":         "https://buy.stripe.com/test_aFa3co4w23jbbu086Ke7m0f",
    "all-access":                 "https://buy.stripe.com/test_eVq28kfaG1b3dC81Ime7m0g"
  };

  // ---- helpers ----
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }
  function $(sel, root) { return (root || document).querySelector(sel); }
  function el(id) { return document.getElementById(id); }
  function money(n) { return "€" + n; }
  function qs(name) {
    var m = new RegExp("[?&]" + name + "=([^&]+)").exec(location.search);
    return m ? decodeURIComponent(m[1]) : null;
  }
  function shortSku(slug) { return slug + "__short"; }
  function longSku(slug) { return slug + "__long"; }

  // Build the image filename for an exercise from its name.
  // MUST stay identical to the slug logic that names files in assets/exercises/.
  function exSlug(name) {
    return String(name == null ? "" : name).toLowerCase()
      .replace(/&/g, " and ")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");
  }
  // <img> that shows a clean placeholder if the picture hasn't been generated yet.
  // Uses the stored English `img` slug so translated exercise names don't break image lookup.
  function exImage(e) {
    var slug = (e && e.img) ? e.img : exSlug(e && e.name ? e.name : e);
    var name = (e && e.name) ? e.name : String(e);
    var src = "assets/exercises/" + slug + ".jpg";
    return '<div class="ex-media">' +
      '<img class="ex-img" loading="lazy" alt="' + esc(name) + '" src="' + esc(src) + '" ' +
      'onerror="this.style.display=&#39;none&#39;;this.parentNode.classList.add(&#39;is-empty&#39;)">' +
      "</div>";
  }

  // Build a SKU catalogue (sku -> {title, price, slug, kind})
  var SKUS = {};
  conditions.forEach(function (c) {
    SKUS[shortSku(c.slug)] = {
      title: c.name + " — " + (c.shortProgram ? c.shortProgram.name : "Relief & Reset"),
      price: P.shortUSD, slug: c.slug, kind: "short"
    };
    SKUS[longSku(c.slug)] = {
      title: c.name + " — " + (c.longProgram ? c.longProgram.name : "Full Rehab"),
      price: P.longUSD, slug: c.slug, kind: "long"
    };
  });
  if (P.bundleUSD) {
    SKUS["all-access"] = { title: "All-Access — every program", price: P.bundleUSD, slug: "all-access", kind: "bundle" };
  }

  // ---- cart (localStorage) ----
  var CART_KEY = "reformwell_cart_v1";
  function readCart() {
    try { return JSON.parse(localStorage.getItem(CART_KEY)) || []; }
    catch (e) { return []; }
  }
  function writeCart(items) {
    localStorage.setItem(CART_KEY, JSON.stringify(items));
    renderCart();
  }
  function addToCart(sku) {
    if (!SKUS[sku]) return;
    var items = readCart();
    if (items.indexOf(sku) === -1) items.push(sku); // digital goods: one of each
    writeCart(items);
    openDrawer();
  }
  function removeFromCart(sku) {
    writeCart(readCart().filter(function (s) { return s !== sku; }));
  }
  function cartTotal(items) {
    return items.reduce(function (t, s) { return t + (SKUS[s] ? SKUS[s].price : 0); }, 0);
  }

  function renderCart() {
    var items = readCart();
    var count = el("cartCount");
    if (count) {
      count.textContent = items.length;
      count.hidden = items.length === 0;
    }
    var body = el("cartBody");
    if (body) {
      if (!items.length) {
        body.innerHTML = '<div class="cart-empty">Your cart is empty.<br>Browse the programs to get started.</div>';
      } else {
        body.innerHTML = items.map(function (s) {
          var it = SKUS[s];
          return '<div class="cart-line"><div class="cl-main">' +
            '<div class="cl-title">' + esc(it.title) + '</div>' +
            '<button class="cl-remove" data-remove="' + esc(s) + '">Pašalinti</button>' +
            '</div><div class="cl-price">' + money(it.price) + '</div></div>';
        }).join("");
      }
    }
    var tot = el("cartTotal");
    if (tot) tot.textContent = money(cartTotal(items));
  }

  // ---- drawer / overlay / modal ----
  function openDrawer() { el("drawer").classList.add("open"); el("overlay").classList.add("open"); }
  function closeDrawer() { el("drawer").classList.remove("open"); el("overlay").classList.remove("open"); }
  function openModal(html) { el("modalContent").innerHTML = html; el("modal").classList.add("open"); }
  function closeModal() { el("modal").classList.remove("open"); }

  function checkout() {
    var items = readCart();
    if (!items.length) return;
    var missing = items.filter(function (s) { return !PAYMENT_LINKS[s]; });
    if (missing.length) {
      var guide = biz.paymentSetupGuide || "Prijunkite Stripe Payment Links arba Gumroad, kad galėtumėte priimti mokėjimus.";
      openModal(
        '<h3>Prijunkite mokėjimus, kad pradėtumėte pardavinėti</h3>' +
        '<p class="muted">Tai visiškai parengta parduotuvė. Kad priimtumėte realius mokėjimus, prijunkite mokėjimų tiekėją — nereikia nei serverio, nei programavimo. Įklijuokite kiekvieno produkto mokėjimo nuorodą į <b>PAYMENT_LINKS</b> faile <code>main.js</code>.</p>' +
        '<pre>' + esc(guide) + '</pre>'
      );
      return;
    }
    if (items.length === 1) {
      window.location.href = PAYMENT_LINKS[items[0]];
    } else {
      openModal(
        '<h3>Užbaikite pirkimą</h3>' +
        '<p class="muted">Kiekviena programa yra atskiras skaitmeninis produktas. Spustelėkite, kad apmokėtumėte kiekvieną:</p>' +
        items.map(function (s) {
          return '<a class="btn btn-primary btn-block" style="margin-bottom:10px" target="_blank" rel="noopener" href="' +
            esc(PAYMENT_LINKS[s]) + '">' + esc(SKUS[s].title) + " — " + money(SKUS[s].price) + "</a>";
        }).join("")
      );
    }
  }

  // ---- shared chrome (nav, cart wiring) ----
  function wireChrome() {
    var nav = el("nav");
    if (nav) {
      window.addEventListener("scroll", function () {
        nav.classList.toggle("scrolled", window.scrollY > 8);
      });
    }
    var toggle = el("navToggle"), links = el("navLinks");
    if (toggle && links) toggle.addEventListener("click", function () { links.classList.toggle("open"); });

    var cb = el("cartBtn"); if (cb) cb.addEventListener("click", openDrawer);
    var dc = el("drawerClose"); if (dc) dc.addEventListener("click", closeDrawer);
    var ov = el("overlay"); if (ov) ov.addEventListener("click", closeDrawer);
    var co = el("checkoutBtn"); if (co) co.addEventListener("click", checkout);
    var mc = el("modalClose"); if (mc) mc.addEventListener("click", closeModal);
    var modal = el("modal"); if (modal) modal.addEventListener("click", function (e) { if (e.target === modal) closeModal(); });

    document.addEventListener("click", function (e) {
      var r = e.target.closest("[data-remove]");
      if (r) removeFromCart(r.getAttribute("data-remove"));
      var a = e.target.closest("[data-add]");
      if (a) { e.preventDefault(); addToCart(a.getAttribute("data-add")); }
    });

    var y = el("year"); if (y) y.textContent = "2026";
    var disc = el("disclaimer");
    if (disc) disc.textContent = (safety.globalDisclaimer || biz.medicalDisclaimer || "");
    renderCart();
  }

  // scroll reveal
  function wireReveal() {
    var els = document.querySelectorAll(".reveal");
    if (!("IntersectionObserver" in window) || !els.length) {
      els.forEach(function (n) { n.classList.add("in"); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); } });
    }, { threshold: 0.12 });
    els.forEach(function (n) { io.observe(n); });
  }

  function wireAccordions(root) {
    (root || document).querySelectorAll(".acc-q").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var item = btn.parentElement;
        var ans = btn.nextElementSibling;
        var open = item.classList.toggle("open");
        ans.style.maxHeight = open ? ans.scrollHeight + "px" : "0";
      });
    });
  }

  // =====================================================
  //  INDEX PAGE
  // =====================================================
  function renderIndex() {
    el("heroHeadline").textContent = biz.heroHeadline || "Klinikų sukurtos reabilitacijos programos";
    el("heroSub").textContent = biz.heroSub || "";
    if (biz.heroCta) el("heroCta").textContent = biz.heroCta;
    el("footerTagline").textContent = design.tagline || "";

    // value props (icons defined here so they always render, regardless of data encoding)
    var vpIcons = ["🩺", "🏠", "💶", "🛡️", "📈", "⏱️"];
    el("valueProps").innerHTML = (biz.valueProps || []).map(function (v, i) {
      return '<div class="feature reveal"><div class="ficon">' + (vpIcons[i] || "✓") + "</div>" +
        "<h3>" + esc(v.title) + "</h3><p>" + esc(v.body) + "</p></div>";
    }).join("");

    // catalog
    el("catalog").innerHTML = conditions.map(function (c) {
      var sp = c.shortProgram || {}, lp = c.longProgram || {};
      var overview = (c.overview || "").slice(0, 130);
      return '<a class="pcard reveal" href="program.html?slug=' + encodeURIComponent(c.slug) + '">' +
        '<div class="pcard-banner">' + bodyIcon(c.slug) + "</div>" +
        '<div class="pcard-body">' +
          '<div class="pcard-tags"><span class="pill pill--primary">' + esc(sp.durationWeeks || "Trumpa") + "</span>" +
          '<span class="pill">' + esc(lp.durationWeeks || "Pilna") + "</span></div>" +
          "<h3>" + esc(c.name) + "</h3>" +
          '<p class="desc">' + esc(overview) + (c.overview && c.overview.length > 130 ? "…" : "") + "</p>" +
          '<div class="pcard-meta"><span>📋 2 versijos</span><span>🏠 Tinka namams</span></div>' +
          '<div class="pcard-foot"><span><span class="from">nuo </span><span class="price">' + money(P.shortUSD) + "</span></span>" +
          '<span class="btn btn-outline" style="min-height:36px;padding:0 14px">Žiūrėti →</span></div>' +
        "</div></a>";
    }).join("");

    // how it works
    el("howItWorks").innerHTML = (biz.howItWorks || []).map(function (s, i) {
      var title = (s.step || "").replace(/^\d+\.\s*/, "");
      return '<div class="step reveal"><div class="num">' + (i + 1) + "</div>" +
        "<h3>" + esc(title) + "</h3><p>" + esc(s.detail) + "</p></div>";
    }).join("");

    // pricing
    el("pricingRationale").textContent = (P.rationale || "");
    var tiers = [
      {
        name: "Palengvinimas ir atstatymas", price: P.shortUSD, sub: "/programa",
        desc: "Tikslingas 3–4 savaičių planas neseniam paūmėjimui nuraminti ir judesiui sugrąžinti.",
        feats: ["Viena trumpa pasirinkta programa", "Savaitės po savaitės planas (PDF)", "Aiškūs nurodymai + progresavimas", "Žalios/geltonos/raudonos simptomų gairės", "Lieka jums visam laikui"],
        popular: false, cta: "Peržiūrėti programas", href: "#programs"
      },
      {
        name: "Pilna reabilitacija ir atsparumas", price: P.longUSD, sub: "/programa",
        desc: "8–12 savaičių programa jėgai atstatyti ir rizikai, kad tai pasikartos, sumažinti.",
        feats: ["Viena pilna pasirinkta reabilitacijos programa", "Nuoseklios fazės iki grįžimo prie veiklos", "Spausdinamas pažangos sekiklis + savitestai", "Viskas, kas yra „Palengvinimo ir atstatymo“ plane", "Nemokami atnaujinimai visam laikui"],
        popular: true, cta: "Peržiūrėti programas", href: "#programs"
      }
    ];
    if (P.bundleUSD) tiers.push({
      name: "Visa prieiga", price: P.bundleUSD, sub: "vienkartinis",
      desc: "Visos trumpos ir pilnos programos visam kūnui. Geriausias pasirinkimas nuolatinei priežiūrai.",
      feats: ["Visos bibliotekos programos", "Tiek trumpos, tiek pilnos versijos", "Įtrauktos visos būsimos programos", "Idealu pasikartojančioms ar kelioms problemoms"],
      popular: false, cta: "Pridėti paketą", href: "", sku: "all-access"
    });

    el("tiers").innerHTML = tiers.map(function (t) {
      var btn = t.sku
        ? '<a class="btn btn-primary btn-block" href="#" data-add="' + esc(t.sku) + '">' + esc(t.cta) + "</a>"
        : '<a class="btn ' + (t.popular ? "btn-primary" : "btn-outline") + ' btn-block" href="' + esc(t.href) + '">' + esc(t.cta) + "</a>";
      return '<div class="tier ' + (t.popular ? "popular" : "") + ' reveal">' +
        (t.popular ? '<span class="pill pill--accent pop-badge">Populiariausia</span>' : "") +
        "<h3>" + esc(t.name) + "</h3>" +
        '<div class="price">' + money(t.price) + " <small>" + esc(t.sub) + "</small></div>" +
        '<p class="tdesc">' + esc(t.desc) + "</p>" +
        "<ul>" + t.feats.map(function (f) { return "<li>" + esc(f) + "</li>"; }).join("") + "</ul>" +
        btn +
        '<div class="guarantee">30 dienų pinigų grąžinimo garantija</div></div>';
    }).join("");

    // testimonials
    el("testimonials").innerHTML = (biz.testimonialsPlaceholder || []).map(function (q) {
      var initials = esc(q.name || "?").split(" ").map(function(w){return w[0];}).join("").slice(0,2);
      return '<div class="quote reveal"><div class="stars">★★★★★</div>' +
        "<blockquote>" + esc(q.quote) + "</blockquote>" +
        '<div class="who"><div class="who-avatar">' + initials + '</div><div><b>' + esc(q.name) + "</b>" + esc(q.detail || "") + "</div></div></div>";
    }).join("");

    // about
    el("aboutCopy").textContent = biz.aboutCopy || "";

    // faq
    el("faqList").innerHTML = (biz.faq || []).map(faqItem).join("");

    // footer program links
    el("footerPrograms").innerHTML = conditions.slice(0, 6).map(function (c) {
      return '<li><a href="program.html?slug=' + encodeURIComponent(c.slug) + '">' + esc(c.name) + "</a></li>";
    }).join("");

    // refund policy link
    var rl = el("refundLink");
    if (rl) rl.addEventListener("click", function (e) {
      e.preventDefault();
      openModal("<h3>Grąžinimo politika</h3><p>" + esc(biz.refundPolicy || "") + "</p>");
    });

    wireAccordions();
  }

  function faqItem(f) {
    return '<div class="acc-item"><button class="acc-q">' + esc(f.q) +
      '<span class="chev">▾</span></button><div class="acc-a"><p>' + esc(f.a) + "</p></div></div>";
  }

  function bodyIcon(slug) {
    var m = {
      "low-back-pain": "🔻", "neck-pain": "🦒", "shoulder": "💪",
      "knee-pain": "🦵", "plantar-fasciitis": "🦶", "tennis-elbow": "🎾",
      "hip-glute": "🍑", "ankle-sprain": "🦴"
    };
    return m[slug] || "🩹";
  }

  // =====================================================
  //  PROGRAM PAGE
  // =====================================================
  function renderProgram() {
    var slug = qs("slug");
    var c = conditions.filter(function (x) { return x.slug === slug; })[0];
    var root = el("programRoot");
    if (!c) {
      root.innerHTML = '<div class="container section"><h2>Programa nerasta</h2><p><a href="index.html">← Grįžti į visas programas</a></p></div>';
      return;
    }
    document.title = c.name + " — Reformwell";
    var saf = (safety.perCondition || []).filter(function (s) { return s.slug === slug; })[0] || {};

    var sp = c.shortProgram || {}, lp = c.longProgram || {};

    function list(arr, cls) {
      if (!arr || !arr.length) return "";
      return '<ul class="info-list ' + (cls || "") + '">' + arr.map(function (x) { return "<li>" + esc(x) + "</li>"; }).join("") + "</ul>";
    }

    function programHTML(p, id) {
      if (!p || !p.phases) return "";
      var meta = [];
      if (p.durationWeeks) meta.push("⏱ " + esc(p.durationWeeks));
      if (p.sessionsPerWeek) meta.push("📅 " + esc(p.sessionsPerWeek));
      if (p.timePerSession) meta.push("⏳ " + esc(p.timePerSession));

      var PREVIEW = 2;
      var totalEx = p.phases.reduce(function (t, ph) { return t + (ph.exercises || []).length; }, 0);
      var lockedEx = Math.max(0, totalEx - PREVIEW);
      var lockedPhases = Math.max(0, p.phases.length - 1);

      function renderEx(e) {
        var dose = [e.sets ? e.sets + " serijos" : "", e.reps ? e.reps : "", e.tempoOrHold ? "· " + e.tempoOrHold : ""].filter(Boolean).join(" × ").replace("× ·", "·");
        return '<div class="ex">' + exImage(e) +
          '<div class="ex-body"><div class="ex-head"><span class="ex-name">' + esc(e.name) + "</span>" +
          '<span class="ex-dose">' + esc(dose) + "</span></div>" +
          '<div class="ex-row"><b>Kaip:</b> ' + esc(e.cues) + "</div>" +
          (e.progression ? '<div class="ex-row"><b>Pažanga:</b> ' + esc(e.progression) + "</div>" : "") +
          (e.why ? '<div class="ex-row why"><b>Kodėl:</b> ' + esc(e.why) + "</div>" : "") +
          "</div></div>";
      }

      var firstPhase = p.phases[0];
      var previewExs = (firstPhase.exercises || []).slice(0, PREVIEW).map(renderEx).join("");

      var fazLabel = lockedPhases === 1 ? "fazės" : "fazių";
      var lockMsg = "Dar <strong>" + lockedEx + " pratimų</strong>" +
        (lockedPhases > 0 ? " ir <strong>" + lockedPhases + " " + fazLabel + "</strong>" : "") +
        " — tik PDF versijoje.";
      var lockGate = '<div class="lock-gate">' +
        '<div class="lock-icon">🔒</div>' +
        '<p class="lock-msg">' + lockMsg + "</p>" +
        '<a class="btn btn-primary" href="#buy" onclick="var b=document.querySelector(\'.buy-box\');if(b){b.scrollIntoView({behavior:\'smooth\'});}return false;">Gauti pilną programą</a>' +
        "</div>";

      var phasesHTML = '<div class="phase">' +
        '<div class="phase-head"><h3>' + esc(firstPhase.name) + "</h3>" +
        (firstPhase.weeks ? '<span class="pill pill--primary">' + esc(firstPhase.weeks) + "</span>" : "") + "</div>" +
        '<p class="focus">' + esc(firstPhase.focus) + "</p>" +
        previewExs + lockGate + "</div>";

      var edu = (p.education && p.education.length)
        ? '<div class="callout"><h4>Savipriežiūros patarimai</h4>' + list(p.education) + "</div>" : "";
      return '<div class="prog-pane" id="' + id + '">' +
        '<p class="muted">' + esc(p.goal || "") + "</p>" +
        '<div class="pcard-meta" style="margin:8px 0 20px">' + meta.map(function (m) { return "<span>" + m + "</span>"; }).join("") + "</div>" +
        phasesHTML + edu + "</div>";
    }

    var seeDoc = (c.seeADoctorIf && c.seeADoctorIf.length)
      ? '<div class="callout warn"><h4>⚠️ Pirmiausia kreipkitės į specialistą, jei…</h4>' + list(c.seeADoctorIf, "warn") + "</div>" : "";
    var safetyNote = saf.safetyNote
      ? '<div class="callout warn"><h4>Saugumo pastaba</h4><p>' + esc(saf.safetyNote) + "</p></div>" : "";

    root.innerHTML =
      '<section class="detail-hero"><div class="container">' +
        '<div class="breadcrumb"><a href="index.html">Pradžia</a> / <a href="index.html#programs">Programos</a> / ' + esc(c.name) + "</div>" +
        '<div class="detail-grid">' +
          "<div>" +
            '<span class="eyebrow">Reabilitacijos programa</span>' +
            "<h1>" + esc(c.name) + "</h1>" +
            "<p style=\"font-size:1.08rem;color:var(--muted)\">" + esc(c.overview) + "</p>" +
            (c.whoIsThisFor ? '<div class="callout"><h4>Kam tai skirta</h4>' + list(c.whoIsThisFor) + "</div>" : "") +
            seeDoc +
          "</div>" +
          buyBox(c, sp, lp) +
        "</div>" +
      "</div></section>" +

      '<section class="section"><div class="container">' +
        '<div class="tabs" id="progTabs">' +
          '<button class="tab active" data-pane="paneShort">' + esc(sp.name || "Palengvinimas ir atstatymas") + " · " + money(P.shortUSD) + "</button>" +
          '<button class="tab" data-pane="paneLong">' + esc(lp.name || "Pilna reabilitacija") + " · " + money(P.longUSD) + "</button>" +
        "</div>" +
        '<div id="paneShort">' + programHTML(sp, "sp") + "</div>" +
        '<div id="paneLong" hidden>' + programHTML(lp, "lp") + "</div>" +

        safetyNote +
        (c.expectedOutcomes ? '<div class="callout"><h4>Ko tikėtis</h4>' + list(c.expectedOutcomes) + "</div>" : "") +

        (c.faqs && c.faqs.length ? '<h2 style="margin-top:48px">Klausimai apie šią programą</h2><div class="accordion">' + c.faqs.map(faqItem).join("") + "</div>" : "") +
      "</div></section>";

    // tabs
    root.querySelectorAll(".tab").forEach(function (tab) {
      tab.addEventListener("click", function () {
        root.querySelectorAll(".tab").forEach(function (t) { t.classList.remove("active"); });
        tab.classList.add("active");
        el("paneShort").hidden = tab.getAttribute("data-pane") !== "paneShort";
        el("paneLong").hidden = tab.getAttribute("data-pane") !== "paneLong";
      });
    });

    wireAccordions(root);
  }

  function buyBox(c, sp, lp) {
    return '<div class="buy-box" id="buy">' +
      "<h3 style=\"margin-bottom:14px\">Įsigykite šią programą</h3>" +
      '<div class="buy-option sel" data-sku="' + esc(shortSku(c.slug)) + '">' +
        '<div class="bo-top"><span class="bo-name">' + esc(sp.name || "Palengvinimas ir atstatymas") + '</span><span class="bo-price">' + money(P.shortUSD) + "</span></div>" +
        '<div class="bo-meta">' + esc(sp.durationWeeks || "3–4 savaitės") + " · nuraminti paūmėjimą</div></div>" +
      '<div class="buy-option" data-sku="' + esc(longSku(c.slug)) + '">' +
        '<div class="bo-top"><span class="bo-name">' + esc(lp.name || "Pilna reabilitacija ir atsparumas") + '</span><span class="bo-price">' + money(P.longUSD) + "</span></div>" +
        '<div class="bo-meta">' + esc(lp.durationWeeks || "8–12 savaičių") + " · visiškas atstatymas</div></div>" +
      '<button class="btn btn-primary btn-block" id="addSelected" style="margin-top:8px">Į krepšelį</button>' +
      '<div class="guarantee" style="text-align:center;font-size:.8rem;color:var(--muted);margin-top:10px">30 dienų pinigų grąžinimo garantija · atsisiuntimas iškart</div>' +
      "</div>";
  }

  // select buy option + add
  document.addEventListener("click", function (e) {
    var opt = e.target.closest(".buy-option");
    if (opt) {
      document.querySelectorAll(".buy-option").forEach(function (o) { o.classList.remove("sel"); });
      opt.classList.add("sel");
    }
    if (e.target.id === "addSelected") {
      var sel = document.querySelector(".buy-option.sel");
      if (sel) addToCart(sel.getAttribute("data-sku"));
    }
  });

  // ---- boot ----
  document.addEventListener("DOMContentLoaded", function () {
    wireChrome();
    if (el("catalog")) renderIndex();
    if (el("programRoot")) renderProgram();
    wireReveal();
  });
})();
