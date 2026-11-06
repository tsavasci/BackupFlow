#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build privacy-translations.js and privacy-policy.html for all 12 languages."""

import html
import json
from pathlib import Path

from privacy_data_1 import PRIVACY_PART_1
from privacy_data_2 import PRIVACY_PART_2

ROOT = Path(__file__).resolve().parent.parent
SITE_URL = "https://tsavasci.github.io/BackupFlowWeb"
PRIVACY_DATA = {**PRIVACY_PART_1, **PRIVACY_PART_2}


def indent(block, spaces):
    pad = " " * spaces
    return "\n".join(pad + line if line.strip() else "" for line in block.splitlines())


def build_privacy_js():
    js_content = (
        "/* Localized Privacy Policy content for all 12 supported languages. */\n"
        "window.BF_PRIVACY = "
        + json.dumps(PRIVACY_DATA, ensure_ascii=False, indent=2)
        + ";\n"
    )
    (ROOT / "privacy-translations.js").write_text(js_content, encoding="utf-8")


def build_privacy_html():
    en = PRIVACY_DATA["en"]
    toc_items = "\n".join(
        f'                        <li><a href="#{sid}">{html.escape(h2)}</a></li>'
        for sid, h2, _ in en["sections"]
    )
    section_blocks = "\n\n".join(
        f'                    <section id="{sid}" class="docs-section">\n'
        f"                        <h2>{html.escape(h2)}</h2>\n"
        f"{indent(content.strip(), 24)}\n"
        f"                    </section>"
        for sid, h2, content in en["sections"]
    )

    page_html = f"""<!doctype html>
<html lang="en" dir="ltr">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>{html.escape(en["title"])}</title>
        <meta
            name="description"
            id="privacy-meta-desc"
            content="{html.escape(en["description"])}"
        />
        <meta name="robots" content="index, follow" />
        <meta name="theme-color" content="#3B82F6" />
        <meta name="apple-itunes-app" content="app-id=6753620051" />

        <!-- Open Graph / Facebook -->
        <meta property="og:type" content="website" />
        <meta property="og:url" content="{SITE_URL}/privacy-policy.html" />
        <meta property="og:title" content="{html.escape(en["title"])}" />
        <meta property="og:description" content="{html.escape(en["description"])}" />
        <link rel="canonical" href="{SITE_URL}/privacy-policy.html" />

        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link
            href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap"
            rel="stylesheet"
        />
        <link rel="stylesheet" href="styles.css" />
        <link rel="stylesheet" href="docs/docs.css" />
        <link rel="icon" href="favicon.svg" type="image/svg+xml" />
    </head>
    <body class="docs-body">
        <a href="#privacy-main" class="skip-link" data-i18n="misc.skipLink">Skip to content</a>

        <!-- Navigation -->
        <nav class="navbar">
            <div class="nav-container">
                <a class="nav-logo" href="index.html">
                    <span class="logo-icon">
                        <img src="web_logo.png" alt="BackupFlow Logo" class="logo-image" />
                    </span>
                    <span class="logo-text">BackupFlow</span>
                </a>
                <div class="nav-menu" id="nav-menu">
                    <a class="nav-link" href="index.html#features" data-i18n="nav.features">Features</a>
                    <a class="nav-link" href="index.html#pricing" data-i18n="nav.pricing">Pricing</a>
                    <a class="nav-link" href="index.html#support" data-i18n="nav.support">Support</a>
                    <div class="lang-switcher" id="lang-switcher">
                        <button
                            type="button"
                            class="lang-toggle"
                            id="lang-toggle"
                            aria-haspopup="listbox"
                            aria-expanded="false"
                            aria-controls="lang-menu"
                        >
                            <span class="lang-flag" id="lang-current-flag">🇬🇧</span>
                            <span class="lang-code" id="lang-current-code">EN</span>
                            <svg class="lang-caret" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M6 9l6 6 6-6" />
                            </svg>
                        </button>
                        <ul class="lang-menu" id="lang-menu" role="listbox" aria-label="Language"></ul>
                    </div>
                    <a class="nav-link download-btn" href="https://apps.apple.com/app/backupflow/id6753620051" target="_blank" rel="noopener noreferrer" data-i18n="nav.download">Download</a>
                </div>
                <button
                    type="button"
                    class="nav-toggle"
                    aria-label="Toggle navigation"
                    data-i18n-attr="aria-label:misc.toggleNav"
                    aria-controls="nav-menu"
                    aria-expanded="false"
                >
                    <span></span>
                    <span></span>
                    <span></span>
                </button>
            </div>
        </nav>

        <!-- Privacy Policy Content -->
        <main id="privacy-main" class="docs-page">
            <div class="container">
                <header class="docs-hero">
                    <h1 id="privacy-h1">{html.escape(en["h1"])}</h1>
                    <p class="docs-updated" id="privacy-updated">{html.escape(en["updated"])}</p>
                    <p class="docs-lead" id="privacy-lead">{html.escape(en["lead"])}</p>
                </header>

                <div class="docs-layout">
                    <aside class="docs-toc" aria-labelledby="privacy-toc-title">
                        <p class="docs-toc-title" id="privacy-toc-title">{html.escape(en["toc_title"])}</p>
                        <ol id="privacy-toc-list">
{toc_items}
                        </ol>
                    </aside>

                    <article class="docs-content" id="privacy-article">
{section_blocks}

                    <div class="privacy-summary-card" id="privacy-summary">
                        <h2 id="privacy-summary-title">{html.escape(en["summary_title"])}</h2>
                        <p id="privacy-summary-text">{html.escape(en["summary_text"])}</p>
                    </div>
                    </article>
                </div>
            </div>
        </main>

        <!-- Footer -->
        <footer class="footer">
            <div class="container">
                <div class="footer-content">
                    <div class="footer-brand">
                        <div class="footer-logo">
                            <div class="logo-icon">
                                <img src="web_logo.png" alt="BackupFlow Logo" class="logo-image" />
                            </div>
                            <span class="logo-text">BackupFlow</span>
                        </div>
                        <p class="footer-description" data-i18n="footer.desc">
                            Professional iOS backup with local-first privacy and smart automation.
                        </p>
                    </div>
                    <div class="footer-links">
                        <div class="footer-column">
                            <h4 data-i18n="footer.supportHeading">Support</h4>
                            <a href="docs/" data-docs-link data-i18n="footer.docs">Documentation</a>
                            <a href="privacy-policy.html" data-i18n="footer.privacy">Privacy Policy</a>
                            <a href="mailto:tamersavasci@icloud.com" data-i18n="footer.contact">Contact</a>
                        </div>
                        <div class="footer-column">
                            <h4 data-i18n="footer.companyHeading">Company</h4>
                            <a href="index.html#features" data-i18n="footer.about">About</a>
                        </div>
                    </div>
                </div>
                <div class="footer-bottom">
                    <p>
                        &copy; 2026 BackupFlow. <span data-i18n="footer.copyright">All rights reserved.</span>
                    </p>
                </div>
            </div>
        </footer>

        <script src="translations.js"></script>
        <script src="privacy-translations.js"></script>
        <script>
            (function () {{
                var tocObserver = null;

                function bindTocHighlight() {{
                    if (tocObserver) {{
                        tocObserver.disconnect();
                    }}
                    var tocLinks = new Map();
                    document.querySelectorAll("#privacy-toc-list a[href^='#']").forEach(function (link) {{
                        tocLinks.set(link.getAttribute("href").slice(1), link);
                    }});
                    if ("IntersectionObserver" in window && tocLinks.size > 0) {{
                        tocObserver = new IntersectionObserver(
                            function (entries) {{
                                entries.forEach(function (entry) {{
                                    if (!entry.isIntersecting) return;
                                    tocLinks.forEach(function (l) {{ l.classList.remove("active"); }});
                                    var active = tocLinks.get(entry.target.id);
                                    if (active) active.classList.add("active");
                                }});
                            }},
                            {{ rootMargin: "-20% 0px -70% 0px" }}
                        );
                        document.querySelectorAll("#privacy-article .docs-section[id]").forEach(function (sec) {{
                            tocObserver.observe(sec);
                        }});
                    }}
                }}

                window.onBfLanguageChange = function (code) {{
                    var dict = (window.BF_PRIVACY && (window.BF_PRIVACY[code] || window.BF_PRIVACY.en)) || null;
                    if (!dict) return;

                    document.title = dict.title;
                    var metaDesc = document.getElementById("privacy-meta-desc");
                    if (metaDesc) metaDesc.setAttribute("content", dict.description);

                    var h1 = document.getElementById("privacy-h1");
                    if (h1) h1.textContent = dict.h1;

                    var updated = document.getElementById("privacy-updated");
                    if (updated) updated.textContent = dict.updated;

                    var lead = document.getElementById("privacy-lead");
                    if (lead) lead.textContent = dict.lead;

                    var tocTitle = document.getElementById("privacy-toc-title");
                    if (tocTitle) tocTitle.textContent = dict.toc_title;

                    var tocList = document.getElementById("privacy-toc-list");
                    var article = document.getElementById("privacy-article");
                    if (tocList && article && Array.isArray(dict.sections)) {{
                        tocList.innerHTML = dict.sections
                            .map(function (s) {{
                                return '<li><a href="#' + s[0] + '">' + s[1] + "</a></li>";
                            }})
                            .join("");

                        var sectionsHtml = dict.sections
                            .map(function (s) {{
                                return (
                                    '<section id="' + s[0] + '" class="docs-section">' +
                                    "<h2>" + s[1] + "</h2>" +
                                    s[2] +
                                    "</section>"
                                );
                            }})
                            .join("");

                        var summaryHtml =
                            '<div class="privacy-summary-card" id="privacy-summary">' +
                            '<h2 id="privacy-summary-title">' + dict.summary_title + "</h2>" +
                            '<p id="privacy-summary-text">' + dict.summary_text + "</p>" +
                            "</div>";

                        article.innerHTML = sectionsHtml + summaryHtml;
                        bindTocHighlight();
                    }}
                }};
            }})();
        </script>
        <script src="script.js"></script>
    </body>
</html>
"""
    (ROOT / "privacy-policy.html").write_text(page_html, encoding="utf-8")


if __name__ == "__main__":
    build_privacy_js()
    build_privacy_html()
    print("Built privacy-translations.js and privacy-policy.html for 12 languages.")
