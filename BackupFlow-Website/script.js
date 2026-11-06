function throttle(func, limit) {
  let inThrottle = false;
  return function throttled(...args) {
    if (inThrottle) {
      return;
    }

    func.apply(this, args);
    inThrottle = true;
    setTimeout(() => {
      inThrottle = false;
    }, limit);
  };
}

function resolveI18nValue(dict, path) {
  return path
    .split(".")
    .reduce((acc, key) => (acc == null ? undefined : acc[key]), dict);
}

function initI18n() {
  const languages = window.BF_LANGUAGES || [];
  const translations = window.BF_TRANSLATIONS || {};
  if (!languages.length || !Object.keys(translations).length) {
    return;
  }

  const STORAGE_KEY = "bf_lang";
  const codes = languages.map((l) => l.code);

  const detectInitialLanguage = () => {
    try {
      const urlLang = new URLSearchParams(window.location.search)
        .get("lang")
        ?.slice(0, 2)
        .toLowerCase();
      if (urlLang && codes.includes(urlLang)) {
        return urlLang;
      }
    } catch (e) {
      /* URLSearchParams unavailable */
    }

    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved && codes.includes(saved)) {
        return saved;
      }
    } catch (e) {
      /* localStorage unavailable */
    }

    const browserLangs = navigator.languages || [navigator.language || "en"];
    for (const bl of browserLangs) {
      const short = bl.slice(0, 2).toLowerCase();
      if (codes.includes(short)) {
        return short;
      }
    }
    return "en";
  };

  const applyTranslations = (code) => {
    const dict = translations[code] || translations.en;

    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const value = resolveI18nValue(dict, el.getAttribute("data-i18n"));
      if (typeof value === "string") {
        el.textContent = value;
      }
    });

    document.querySelectorAll("[data-i18n-html]").forEach((el) => {
      const value = resolveI18nValue(dict, el.getAttribute("data-i18n-html"));
      if (typeof value === "string") {
        el.innerHTML = value.replace(
          "{iOS}",
          '<span class="gradient-text">iOS</span>',
        );
      }
    });

    // Swap localized screenshots and banners: "{lang}" in the template becomes the language code.
    document.querySelectorAll("[data-lang-src]").forEach((el) => {
      const srcset = el.getAttribute("data-lang-srcset");
      if (srcset) {
        el.srcset = srcset.replaceAll("{lang}", code);
      }
      el.src = el.getAttribute("data-lang-src").replaceAll("{lang}", code);
    });

    document.querySelectorAll("[data-i18n-attr]").forEach((el) => {
      el.getAttribute("data-i18n-attr")
        .split(";")
        .forEach((pair) => {
          const [attr, key] = pair.split(":").map((part) => part.trim());
          if (!attr || !key) {
            return;
          }
          const value = resolveI18nValue(dict, key);
          if (typeof value === "string") {
            el.setAttribute(attr, value);
          }
        });
    });
  };

  const langToggle = document.getElementById("lang-toggle");
  const langMenu = document.getElementById("lang-menu");
  const langSwitcher = document.getElementById("lang-switcher");
  const currentFlag = document.getElementById("lang-current-flag");
  const currentCode = document.getElementById("lang-current-code");

  const closeLangMenu = () => {
    if (!langMenu || !langToggle) return;
    langMenu.classList.remove("open");
    langToggle.setAttribute("aria-expanded", "false");
  };

  const setLanguage = (code) => {
    const meta = languages.find((l) => l.code === code) || languages[0];
    document.documentElement.lang = meta.code;
    document.documentElement.dir = meta.dir || "ltr";
    applyTranslations(meta.code);

    if (currentFlag) currentFlag.textContent = meta.flag;
    if (currentCode) currentCode.textContent = meta.code.toUpperCase();

    langMenu?.querySelectorAll("[data-lang-code]").forEach((btn) => {
      const isActive = btn.getAttribute("data-lang-code") === meta.code;
      btn.setAttribute("aria-selected", String(isActive));
      btn.classList.toggle("active", isActive);
    });

    // Point Documentation links at the Help page in the current language.
    document.querySelectorAll("[data-docs-link]").forEach((link) => {
      link.setAttribute("href", `docs/${meta.code}/`);
    });

    try {
      localStorage.setItem(STORAGE_KEY, meta.code);
    } catch (e) {
      /* localStorage unavailable */
    }

    if (typeof window.onBfLanguageChange === "function") {
      window.onBfLanguageChange(meta.code, meta);
    }
  };

  if (langMenu) {
    languages.forEach((lang) => {
      const li = document.createElement("li");
      li.setAttribute("role", "presentation");

      const button = document.createElement("button");
      button.type = "button";
      button.setAttribute("role", "option");
      button.setAttribute("data-lang-code", lang.code);
      button.className = "lang-option";
      button.innerHTML = `<span class="lang-flag">${lang.flag}</span><span class="lang-name">${lang.name}</span>`;
      button.addEventListener("click", () => {
        setLanguage(lang.code);
        closeLangMenu();
        langToggle?.focus();
      });

      li.appendChild(button);
      langMenu.appendChild(li);
    });
  }

  if (langToggle && langMenu) {
    langToggle.addEventListener("click", (event) => {
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
  }

  setLanguage(detectInitialLanguage());
}

document.addEventListener("DOMContentLoaded", () => {
  initI18n();

  const navbar = document.querySelector(".navbar");
  const navToggle = document.querySelector(".nav-toggle");
  const navMenu = document.querySelector(".nav-menu");

  const setNavbarState = () => {
    if (!navbar) {
      return;
    }

    navbar.classList.toggle("scrolled", window.scrollY > 50);
  };

  setNavbarState();
  window.addEventListener("scroll", throttle(setNavbarState, 50));

  const closeMobileMenu = () => {
    if (!navMenu || !navToggle) {
      return;
    }

    navMenu.classList.remove("active");
    navToggle.classList.remove("active");
    navToggle.setAttribute("aria-expanded", "false");
  };

  if (navToggle && navMenu) {
    navToggle.addEventListener("click", () => {
      const isOpen = navMenu.classList.toggle("active");
      navToggle.classList.toggle("active", isOpen);
      navToggle.setAttribute("aria-expanded", String(isOpen));
    });
  }

  const sectionLinks = document.querySelectorAll('a[href^="#"]');
  sectionLinks.forEach((link) => {
    const href = link.getAttribute("href");
    if (!href || href.length <= 1) {
      return;
    }

    const target = document.querySelector(href);
    if (!target) {
      return;
    }

    link.addEventListener("click", (event) => {
      event.preventDefault();
      target.scrollIntoView({ behavior: "smooth", block: "start" });
      closeMobileMenu();
    });
  });

  const animatedElements = document.querySelectorAll(
    ".feature-card, .screenshot-card, .use-case-card, .support-card",
  );

  if ("IntersectionObserver" in window && animatedElements.length > 0) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) {
            return;
          }

          entry.target.style.opacity = "1";
          entry.target.style.transform = "translateY(0)";
          observer.unobserve(entry.target);
        });
      },
      {
        threshold: 0.1,
        rootMargin: "0px 0px -50px 0px",
      },
    );

    animatedElements.forEach((el) => {
      el.style.opacity = "0";
      el.style.transform = "translateY(24px)";
      el.style.transition = "opacity 0.45s ease, transform 0.45s ease";
      observer.observe(el);
    });
  }

  const featureCards = document.querySelectorAll(".feature-card");
  featureCards.forEach((card) => {
    card.addEventListener("mouseenter", () => {
      const icon = card.querySelector(".feature-icon");
      if (icon) {
        icon.style.transform = "scale(1.08) rotate(4deg)";
      }
    });

    card.addEventListener("mouseleave", () => {
      const icon = card.querySelector(".feature-icon");
      if (icon) {
        icon.style.transform = "scale(1) rotate(0deg)";
      }
    });
  });

  const buttons = document.querySelectorAll(".btn");
  buttons.forEach((button) => {
    button.addEventListener("click", (event) => {
      const ripple = document.createElement("span");
      const rect = button.getBoundingClientRect();
      const size = Math.max(rect.width, rect.height);
      const x = event.clientX - rect.left - size / 2;
      const y = event.clientY - rect.top - size / 2;

      ripple.style.width = `${size}px`;
      ripple.style.height = `${size}px`;
      ripple.style.left = `${x}px`;
      ripple.style.top = `${y}px`;
      ripple.classList.add("ripple");

      button.appendChild(ripple);
      setTimeout(() => {
        ripple.remove();
      }, 600);
    });
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeMobileMenu();
    }
  });

  window.addEventListener("load", () => {
    document.body.classList.add("loaded");
  });

  const style = document.createElement("style");
  style.textContent = `
        .btn {
            position: relative;
            overflow: hidden;
        }

        .ripple {
            position: absolute;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.3);
            transform: scale(0);
            animation: ripple-animation 0.6s linear;
            pointer-events: none;
        }

        @keyframes ripple-animation {
            to {
                transform: scale(4);
                opacity: 0;
            }
        }

        .feature-icon {
            transition: transform 0.3s ease;
        }
    `;
  document.head.appendChild(style);
});
