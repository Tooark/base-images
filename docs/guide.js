/* =============================================================================
   base-images :: catalog
   -----------------------------------------------------------------------------
   This lives in its own file rather than inline because the site is served
   behind a Content Security Policy of `script-src 'self'`. An inline <script>
   is blocked outright there; a same-origin file is not.

   It is loaded from <head> without `defer` on purpose: the theme, the language
   and the CI platform have to be stamped on <html> before the first paint, or
   the page flashes the wrong one. Everything that touches the DOM waits for
   DOMContentLoaded instead.

   No human-readable string lives here. Button labels come from data attributes
   in the HTML, so every piece of translated text sits next to the rest of the
   translations.

   The theme and language keys are the same as the other Tooark guides, so a
   reader's choice follows them across tooark.com.
   =========================================================================== */
(function () {
  "use strict";

  var root = document.documentElement;

  /* --- before the first paint ---------------------------------------------- */

  try {
    var storedTheme = localStorage.getItem("ark-theme");
    if (storedTheme === "dark" || storedTheme === "light") {
      root.setAttribute("data-theme", storedTheme);
      root.style.colorScheme = storedTheme;
    }
  } catch (e) {}

  try {
    var storedLang = localStorage.getItem("ark-lang");
    if (storedLang !== "pt" && storedLang !== "en") {
      // No stored preference: follow the browser. The HTML already ships
      // data-lang="pt", which is what a reader without JavaScript gets.
      storedLang =
        (navigator.language || "pt").toLowerCase().indexOf("pt") === 0 ? "pt" : "en";
    }
    root.setAttribute("data-lang", storedLang);
    root.lang = storedLang === "pt" ? "pt-BR" : "en";
  } catch (e) {}

  // CI platform of the example tabs. Without JavaScript data-ci never gets set,
  // and the CSS then shows every panel and hides the tab bars.
  var storedCi = "gh";
  try {
    if (localStorage.getItem("ark-ci") === "gl") storedCi = "gl";
  } catch (e) {}
  root.setAttribute("data-ci", storedCi);

  /* --- state --------------------------------------------------------------- */

  function currentLang() {
    return root.getAttribute("data-lang") === "en" ? "en" : "pt";
  }

  function currentTheme() {
    var attr = root.getAttribute("data-theme");
    if (attr === "dark" || attr === "light") return attr;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }

  function store(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch (e) {}
  }

  function ready(fn) {
    if (document.readyState !== "loading") fn();
    else document.addEventListener("DOMContentLoaded", fn);
  }

  ready(function () {
    var langBtn = document.getElementById("lang-toggle");
    var themeBtn = document.getElementById("theme-toggle");
    var body = document.body;
    var copyButtons = [];

    /* --- toggles ----------------------------------------------------------- */

    function paint() {
      var lang = currentLang();
      var theme = currentTheme();

      root.lang = lang === "pt" ? "pt-BR" : "en";
      root.style.colorScheme = theme;

      if (langBtn) {
        langBtn.textContent = langBtn.getAttribute("data-label-" + lang) || "";
        langBtn.setAttribute("aria-label", langBtn.getAttribute("data-aria-" + lang) || "");
      }

      if (themeBtn) {
        // The label names the mode the click would switch to.
        var target = theme === "dark" ? "light" : "dark";
        themeBtn.textContent = themeBtn.getAttribute("data-" + lang + "-" + target) || "";
      }

      copyButtons.forEach(function (btn) {
        if (!btn.classList.contains("is-done")) {
          btn.textContent = body.getAttribute("data-copy-" + lang) || "";
        }
      });

      var ci = root.getAttribute("data-ci");
      Array.prototype.forEach.call(document.querySelectorAll("[data-tab]"), function (tab) {
        tab.setAttribute("aria-selected", tab.getAttribute("data-tab") === ci ? "true" : "false");
      });
    }

    if (langBtn) {
      langBtn.addEventListener("click", function () {
        var next = currentLang() === "en" ? "pt" : "en";
        root.setAttribute("data-lang", next);
        store("ark-lang", next);
        paint();
      });
    }

    if (themeBtn) {
      themeBtn.addEventListener("click", function () {
        var next = currentTheme() === "dark" ? "light" : "dark";
        root.setAttribute("data-theme", next);
        store("ark-theme", next);
        paint();
      });
    }

    /* --- CI tabs ----------------------------------------------------------- */

    // One choice drives every tab bar on the page: whoever runs GitLab wants the
    // GitLab example in every section. Switching changes the height of every
    // block above the clicked one, so the clicked tab is pinned where it was.
    Array.prototype.forEach.call(document.querySelectorAll("[data-tab]"), function (tab) {
      tab.addEventListener("click", function () {
        var before = tab.getBoundingClientRect().top;
        var next = tab.getAttribute("data-tab");
        root.setAttribute("data-ci", next);
        store("ark-ci", next);
        paint();
        window.scrollBy(0, tab.getBoundingClientRect().top - before);
      });
    });

    /* --- copy buttons ------------------------------------------------------ */

    if (navigator.clipboard && window.isSecureContext) {
      Array.prototype.forEach.call(document.querySelectorAll("main pre"), function (pre) {
        var wrap = document.createElement("div");
        wrap.className = "code";
        pre.parentNode.insertBefore(wrap, pre);
        wrap.appendChild(pre);

        var btn = document.createElement("button");
        btn.type = "button";
        btn.className = "copy-btn";
        wrap.appendChild(btn);
        copyButtons.push(btn);

        btn.addEventListener("click", function () {
          navigator.clipboard.writeText(pre.innerText.replace(/\s+$/, "") + "\n").then(function () {
            btn.classList.add("is-done");
            btn.textContent = body.getAttribute("data-copied-" + currentLang()) || "";
            setTimeout(function () {
              btn.classList.remove("is-done");
              paint();
            }, 1600);
          });
        });
      });
    }

    paint();

    /* --- nav: mark the section being read ---------------------------------- */

    // Both language lists are in the DOM and several links share an href, so the
    // active class is applied to every link pointing at the current section; CSS
    // hides whichever list is not in use.
    var links = Array.prototype.slice.call(document.querySelectorAll("nav a"));
    var byId = {};
    var sections = [];

    links.forEach(function (a) {
      var id = a.getAttribute("href").slice(1);
      var el = document.getElementById(id);
      if (!el) return;
      (byId[id] = byId[id] || []).push(a);
      if (sections.indexOf(el) === -1) sections.push(el);
    });

    function setActive(id) {
      links.forEach(function (a) {
        a.classList.remove("is-active");
      });
      (byId[id] || []).forEach(function (a) {
        a.classList.add("is-active");
      });
    }

    if ("IntersectionObserver" in window) {
      var visible = {};
      var observer = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            visible[entry.target.id] = entry.isIntersecting;
          });
          for (var i = 0; i < sections.length; i++) {
            if (visible[sections[i].id]) {
              setActive(sections[i].id);
              return;
            }
          }
        },
        { rootMargin: "-15% 0px -70% 0px", threshold: 0 }
      );
      sections.forEach(function (section) {
        observer.observe(section);
      });
    }

    setActive(sections.length ? sections[0].id : "");
  });
})();
