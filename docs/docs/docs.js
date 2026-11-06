document.addEventListener("DOMContentLoaded", () => {
  const navbar = document.querySelector(".navbar");
  const navToggle = document.querySelector(".nav-toggle");
  const navMenu = document.querySelector(".nav-menu");
  const langToggle = document.getElementById("lang-toggle");
  const langMenu = document.getElementById("lang-menu");
  const langSwitcher = document.getElementById("lang-switcher");

  const setNavbarState = () => {
    navbar?.classList.toggle("scrolled", window.scrollY > 50);
  };
  setNavbarState();
  window.addEventListener("scroll", setNavbarState, { passive: true });

  navToggle?.addEventListener("click", () => {
    const isOpen = navMenu.classList.toggle("active");
    navToggle.classList.toggle("active", isOpen);
    navToggle.setAttribute("aria-expanded", String(isOpen));
  });

  const closeLangMenu = () => {
    langMenu?.classList.remove("open");
    langToggle?.setAttribute("aria-expanded", "false");
  };

  langToggle?.addEventListener("click", (event) => {
    event.stopPropagation();
    const isOpen = langMenu.classList.toggle("open");
    langToggle.setAttribute("aria-expanded", String(isOpen));
  });

  document.addEventListener("click", (event) => {
    if (langSwitcher && !langSwitcher.contains(event.target)) {
      closeLangMenu();
    }
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeLangMenu();
    }
  });

  // Remember the language so the main site opens in the same one.
  langMenu?.querySelectorAll("[data-lang-code]").forEach((link) => {
    link.addEventListener("click", () => {
      try {
        localStorage.setItem("bf_lang", link.getAttribute("data-lang-code"));
      } catch (e) {
        /* localStorage unavailable */
      }
    });
  });

  try {
    localStorage.setItem("bf_lang", document.documentElement.lang);
  } catch (e) {
    /* localStorage unavailable */
  }

  // Highlight the table-of-contents entry for the section currently in view.
  const tocLinks = new Map();
  document.querySelectorAll(".docs-toc a[href^='#']").forEach((link) => {
    tocLinks.set(link.getAttribute("href").slice(1), link);
  });

  if ("IntersectionObserver" in window && tocLinks.size > 0) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) {
            return;
          }
          tocLinks.forEach((link) => link.classList.remove("active"));
          tocLinks.get(entry.target.id)?.classList.add("active");
        });
      },
      { rootMargin: "-20% 0px -70% 0px" },
    );

    document.querySelectorAll(".docs-section[id]").forEach((section) => {
      observer.observe(section);
    });
  }
});
