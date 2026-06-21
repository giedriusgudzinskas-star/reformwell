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
    // "low-back-pain__short": "",
    // "low-back-pain__long": "",
    // "all-access": ""
  };

  // ---- helpers ----
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }
  function $(sel, root) { return (root || document).querySelector(sel); }
  function el(id) { return document.getElementById(id); }
  function money(n) { return "$" + n; }
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
  function exImage(name) {
    var src = "assets/exercises/" + exSlug(name) + ".jpg";
    return '<div class="ex-media">' +
      '<img class="ex-img" loading="lazy" alt="' + esc(name) + ' exercise illustration" src="' + esc(src) + '" ' +
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
            '<button class="cl-remove" data-remove="' + esc(s) + '">Remove</button>' +
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
      var guide = biz.paymentSetupGuide || "Connect Stripe Payment Links or Gumroad to start accepting payments.";
      openModal(
        '<h3>Connect payments to go live</h3>' +
        '<p class="muted">This is a fully built storefront. To take real money, connect a payment provider — no server or code required. Paste each product’s payment link into <b>PAYMENT_LINKS</b> in <code>main.js</code>.</p>' +
        '<pre>' + esc(guide) + '</pre>'
      );
      return;
    }
    if (items.length === 1) {
      window.location.href = PAYMENT_LINKS[items[0]];
    } else {
      openModal(
        '<h3>Complete your purchase</h3>' +
        '<p class="muted">Each program is a separate digital product. Click to pay for each:</p>' +
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
    el("heroHeadline").textContent = biz.heroHeadline || "Clinician-designed rehab programs";
    el("heroSub").textContent = biz.heroSub || "";
    if (biz.heroCta) el("heroCta").textContent = biz.heroCta;
    el("footerTagline").textContent = design.tagline || "";

    // value props
    el("valueProps").innerHTML = (biz.valueProps || []).map(function (v) {
      return '<div class="feature reveal"><div class="ficon">' + esc(v.icon || "✓") + "</div>" +
        "<h3>" + esc(v.title) + "</h3><p>" + esc(v.body) + "</p></div>";
    }).join("");

    // catalog
    el("catalog").innerHTML = conditions.map(function (c) {
      var sp = c.shortProgram || {}, lp = c.longProgram || {};
      var overview = (c.overview || "").slice(0, 130);
      return '<a class="pcard reveal" href="program.html?slug=' + encodeURIComponent(c.slug) + '">' +
        '<div class="pcard-banner">' + bodyIcon(c.slug) + "</div>" +
        '<div class="pcard-body">' +
          '<div class="pcard-tags"><span class="pill pill--primary">' + esc(sp.durationWeeks || "Short") + "</span>" +
          '<span class="pill">' + esc(lp.durationWeeks || "Full") + "</span></div>" +
          "<h3>" + esc(c.name) + "</h3>" +
          '<p class="desc">' + esc(overview) + (c.overview && c.overview.length > 130 ? "…" : "") + "</p>" +
          '<div class="pcard-meta"><span>📋 2 versions</span><span>🏠 Home-friendly</span></div>' +
          '<div class="pcard-foot"><span><span class="from">from </span><span class="price">' + money(P.shortUSD) + "</span></span>" +
          '<span class="btn btn-outline" style="min-height:36px;padding:0 14px">View →</span></div>' +
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
        name: "Relief & Reset", price: P.shortUSD, sub: "/program",
        desc: "A focused 3–4 week plan to calm a recent flare-up and get moving again.",
        feats: ["One short program of your choice", "Week-by-week plan (PDF)", "Clear cues + progressions", "Green/amber/red symptom guide", "Keep it forever"],
        popular: false, cta: "Browse programs", href: "#programs"
      },
      {
        name: "Full Rehab & Resilience", price: P.longUSD, sub: "/program",
        desc: "An 8–12 week program to rebuild strength and reduce the chance it returns.",
        feats: ["One full rehab program of your choice", "Progressive phases to return-to-activity", "Printable progress tracker + self-tests", "Everything in Relief & Reset", "Free updates for life"],
        popular: true, cta: "Browse programs", href: "#programs"
      }
    ];
    if (P.bundleUSD) tiers.push({
      name: "All-Access", price: P.bundleUSD, sub: "one-time",
      desc: "Every short and full program, for the whole body. Best value for ongoing care.",
      feats: ["Every program in the library", "Both short + full versions", "All future programs included", "Ideal for recurring or multiple issues"],
      popular: false, cta: "Add bundle", href: "", sku: "all-access"
    });

    el("tiers").innerHTML = tiers.map(function (t) {
      var btn = t.sku
        ? '<a class="btn btn-primary btn-block" href="#" data-add="' + esc(t.sku) + '">' + esc(t.cta) + "</a>"
        : '<a class="btn ' + (t.popular ? "btn-primary" : "btn-outline") + ' btn-block" href="' + esc(t.href) + '">' + esc(t.cta) + "</a>";
      return '<div class="tier ' + (t.popular ? "popular" : "") + ' reveal">' +
        (t.popular ? '<span class="pill pill--accent pop-badge">Most popular</span>' : "") +
        "<h3>" + esc(t.name) + "</h3>" +
        '<div class="price">' + money(t.price) + " <small>" + esc(t.sub) + "</small></div>" +
        '<p class="tdesc">' + esc(t.desc) + "</p>" +
        "<ul>" + t.feats.map(function (f) { return "<li>" + esc(f) + "</li>"; }).join("") + "</ul>" +
        btn +
        '<div class="guarantee">30-day money-back guarantee</div></div>';
    }).join("");

    // testimonials
    el("testimonials").innerHTML = (biz.testimonialsPlaceholder || []).map(function (q) {
      return '<div class="quote reveal"><div class="stars">★★★★★</div>' +
        "<blockquote>" + esc(q.quote) + "</blockquote>" +
        '<div class="who"><b>' + esc(q.name) + "</b>" + esc(q.detail || "") + "</div></div>";
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
      openModal("<h3>Refund policy</h3><p>" + esc(biz.refundPolicy || "") + "</p>");
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
      root.innerHTML = '<div class="container section"><h2>Program not found</h2><p><a href="index.html">← Back to all programs</a></p></div>';
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
      var phases = p.phases.map(function (ph) {
        var exs = (ph.exercises || []).map(function (e) {
          var dose = [e.sets ? e.sets + " sets" : "", e.reps ? e.reps : "", e.tempoOrHold ? "· " + e.tempoOrHold : ""].filter(Boolean).join(" × ").replace("× ·", "·");
          return '<div class="ex">' + exImage(e.name) +
            '<div class="ex-body"><div class="ex-head"><span class="ex-name">' + esc(e.name) + "</span>" +
            '<span class="ex-dose">' + esc(dose) + "</span></div>" +
            '<div class="ex-row"><b>How:</b> ' + esc(e.cues) + "</div>" +
            (e.progression ? '<div class="ex-row"><b>Progress:</b> ' + esc(e.progression) + "</div>" : "") +
            (e.why ? '<div class="ex-row why"><b>Why:</b> ' + esc(e.why) + "</div>" : "") +
            "</div></div>";
        }).join("");
        return '<div class="phase"><div class="phase-head"><h3>' + esc(ph.name) + "</h3>" +
          (ph.weeks ? '<span class="pill pill--primary">' + esc(ph.weeks) + "</span>" : "") + "</div>" +
          '<p class="focus">' + esc(ph.focus) + "</p>" + exs + "</div>";
      }).join("");
      var edu = (p.education && p.education.length)
        ? '<div class="callout"><h4>Self-care tips</h4>' + list(p.education) + "</div>" : "";
      return '<div class="prog-pane" id="' + id + '">' +
        '<p class="muted">' + esc(p.goal || "") + "</p>" +
        '<div class="pcard-meta" style="margin:8px 0 20px">' + meta.map(function (m) { return "<span>" + m + "</span>"; }).join("") + "</div>" +
        phases + edu + "</div>";
    }

    var seeDoc = (c.seeADoctorIf && c.seeADoctorIf.length)
      ? '<div class="callout warn"><h4>⚠️ See a clinician first if…</h4>' + list(c.seeADoctorIf, "warn") + "</div>" : "";
    var safetyNote = saf.safetyNote
      ? '<div class="callout warn"><h4>Safety note</h4><p>' + esc(saf.safetyNote) + "</p></div>" : "";

    root.innerHTML =
      '<section class="detail-hero"><div class="container">' +
        '<div class="breadcrumb"><a href="index.html">Home</a> / <a href="index.html#programs">Programs</a> / ' + esc(c.name) + "</div>" +
        '<div class="detail-grid">' +
          "<div>" +
            '<span class="eyebrow">Rehab program</span>' +
            "<h1>" + esc(c.name) + "</h1>" +
            "<p style=\"font-size:1.08rem;color:var(--muted)\">" + esc(c.overview) + "</p>" +
            (c.whoIsThisFor ? '<div class="callout"><h4>Who this is for</h4>' + list(c.whoIsThisFor) + "</div>" : "") +
            seeDoc +
          "</div>" +
          buyBox(c, sp, lp) +
        "</div>" +
      "</div></section>" +

      '<section class="section"><div class="container">' +
        '<div class="tabs" id="progTabs">' +
          '<button class="tab active" data-pane="paneShort">' + esc(sp.name || "Relief & Reset") + " · " + money(P.shortUSD) + "</button>" +
          '<button class="tab" data-pane="paneLong">' + esc(lp.name || "Full Rehab") + " · " + money(P.longUSD) + "</button>" +
        "</div>" +
        '<div id="paneShort">' + programHTML(sp, "sp") + "</div>" +
        '<div id="paneLong" hidden>' + programHTML(lp, "lp") + "</div>" +

        safetyNote +
        (c.expectedOutcomes ? '<div class="callout"><h4>What to expect</h4>' + list(c.expectedOutcomes) + "</div>" : "") +

        (c.faqs && c.faqs.length ? '<h2 style="margin-top:48px">Questions about this program</h2><div class="accordion">' + c.faqs.map(faqItem).join("") + "</div>" : "") +
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
    return '<div class="buy-box">' +
      "<h3 style=\"margin-bottom:14px\">Get this program</h3>" +
      '<div class="buy-option sel" data-sku="' + esc(shortSku(c.slug)) + '">' +
        '<div class="bo-top"><span class="bo-name">' + esc(sp.name || "Relief & Reset") + '</span><span class="bo-price">' + money(P.shortUSD) + "</span></div>" +
        '<div class="bo-meta">' + esc(sp.durationWeeks || "3–4 weeks") + " · calm a flare-up</div></div>" +
      '<div class="buy-option" data-sku="' + esc(longSku(c.slug)) + '">' +
        '<div class="bo-top"><span class="bo-name">' + esc(lp.name || "Full Rehab & Resilience") + '</span><span class="bo-price">' + money(P.longUSD) + "</span></div>" +
        '<div class="bo-meta">' + esc(lp.durationWeeks || "8–12 weeks") + " · full rebuild</div></div>" +
      '<button class="btn btn-primary btn-block" id="addSelected" style="margin-top:8px">Add to cart</button>' +
      '<div class="guarantee" style="text-align:center;font-size:.8rem;color:var(--muted);margin-top:10px">30-day money-back guarantee · instant download</div>' +
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
