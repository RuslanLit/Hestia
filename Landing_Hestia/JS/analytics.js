(function () {
  const release = window.HestiaReleaseConfig || {};
  const config = release.analytics || {};
  const platforms = release.platforms || {};
  const allowedEvents = new Set([
    "page_view",
    "platform_detected",
    "download_android",
    "download_macos",
    "download_linux",
    "open_web",
    "open_server_setup",
    "open_privacy",
    "open_faq",
    "open_comparison",
    "language_change",
  ]);

  function currentPage() {
    return window.location.pathname.split("/").pop() || "index.html";
  }

  function currentLanguage() {
    return document.documentElement.lang || window.HestiaLang || "en";
  }

  function detectedPlatform() {
    return typeof window.detectPlatform === "function"
      ? window.detectPlatform() || "unknown"
      : "unknown";
  }

  function sanitizeProps(props) {
    const clean = {};
    Object.entries(props || {}).forEach(([key, value]) => {
      if (value === undefined || value === null) return;
      clean[key] = String(value).slice(0, 120);
    });
    return clean;
  }

  function send(payload) {
    if (!config.enabled || !config.endpoint) return;

    const body = JSON.stringify(payload);
    if (navigator.sendBeacon) {
      const blob = new Blob([body], { type: "application/json" });
      navigator.sendBeacon(config.endpoint, blob);
      return;
    }

    fetch(config.endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      keepalive: true,
      credentials: "omit",
    }).catch(() => {});
  }

  function track(eventName, props) {
    if (!allowedEvents.has(eventName)) return;

    send({
      event: eventName,
      site: config.siteId || "hestia-site",
      page: currentPage(),
      language: currentLanguage(),
      platform: detectedPlatform(),
      props: sanitizeProps(props),
    });
  }

  function eventFromLink(link) {
    const href = link.getAttribute("href") || "";
    const absoluteHref = link.href || "";

    if (absoluteHref === platforms.android?.url || href === platforms.android?.url) return "download_android";
    if (absoluteHref === platforms.macos?.url || href === platforms.macos?.url) return "download_macos";
    if (absoluteHref === platforms.linux?.url || href === platforms.linux?.url) return "download_linux";
    if (absoluteHref === platforms.web?.url || href === platforms.web?.url) return "open_web";
    if (href.includes("server-setup.html")) return "open_server_setup";
    if (href.includes("privacy.html")) return "open_privacy";
    if (href.includes("faq.html")) return "open_faq";
    if (href.includes("comparison.html")) return "open_comparison";

    return null;
  }

  function bindClicks() {
    document.addEventListener("click", (event) => {
      const link = event.target.closest("a");
      if (!link) return;

      const eventName = eventFromLink(link);
      if (!eventName) return;

      track(eventName, {
        target: link.getAttribute("href") || "",
      });
    });
  }

  function renderNotice() {
    if (!config.noticeEnabled) return;
    const noticeText = {
      en: "We use privacy-friendly analytics without tracking personal data.",
      uk: "We use privacy-friendly analytics without tracking personal data.",
      ru: "We use privacy-friendly analytics without tracking personal data.",
      pl: "Uzywamy prywatnosciowej analityki bez sledzenia danych osobowych.",
      es: "Usamos analitica respetuosa con la privacidad sin rastrear datos personales.",
      cs: "Pouzivame soukromi respektujici analytiku bez sledovani osobnich udaju.",
      de: "Wir nutzen datenschutzfreundliche Analytik ohne Tracking personenbezogener Daten.",
    };

    const existing = document.querySelector("[data-analytics-notice]");
    if (existing) {
      existing.textContent = noticeText[currentLanguage()] || noticeText.en;
      return;
    }

    document.querySelectorAll(".site-footer").forEach((footer) => {
      const notice = document.createElement("p");
      notice.className = "analytics-notice";
      notice.dataset.analyticsNotice = "true";
      notice.textContent = noticeText[currentLanguage()] || noticeText.en;
      footer.firstElementChild?.append(notice);
    });
  }

  function init() {
    bindClicks();
    renderNotice();

    track("page_view");
    track("platform_detected", { detected: detectedPlatform() });

    document.addEventListener("hestia:language-change", (event) => {
      track("language_change", {
        language: event.detail?.language || currentLanguage(),
      });
    });

    document.addEventListener("hestia:render", renderNotice);
  }

  window.HestiaAnalytics = { track };
  document.addEventListener("DOMContentLoaded", init);
})();
