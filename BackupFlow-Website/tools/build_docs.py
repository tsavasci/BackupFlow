#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the localized Help pages in docs/ for all 12 supported languages.

Usage:
    python3 tools/build_docs.py
"""

import html
import json
import subprocess
from pathlib import Path

from docs_data_1 import DOCS_PART_1
from docs_data_2 import DOCS_PART_2

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs"
SITE_URL = "https://tsavasci.github.io/BackupFlowWeb"

DOCS_DATA = {**DOCS_PART_1, **DOCS_PART_2}

SECTION_SCREENS = {
    "backup-hub": ["1.jpg"],
    "first-backup": ["6.jpg", "9.jpg"],
    "task-details": ["5.jpg"],
    "history": ["3.jpg"],
    "settings": ["10.jpg"],
}


def load_site_strings():
    """Read languages and labels from translations.js using macOS JavaScriptCore or Node."""
    jsc = "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc"
    js_path = (ROOT / "translations.js").as_posix()
    script = (
        f"var window={{}}; load({json.dumps(js_path)});"
        "var o={languages:window.BF_LANGUAGES,t:{}};"
        "for(var i=0;i<window.BF_LANGUAGES.length;i++){var l=window.BF_LANGUAGES[i];var t=window.BF_TRANSLATIONS[l.code];"
        "o.t[l.code]={nav:t.nav,footer:t.footer,misc:t.misc};}"
        "print(JSON.stringify(o));"
    )
    raw = subprocess.check_output([jsc, "-e", script], cwd=ROOT)
    return json.loads(raw.decode("utf-8").strip())


def indent(block, spaces):
    pad = " " * spaces
    return "\n".join(pad + line if line.strip() else "" for line in block.splitlines())


def render_screens(lang, sid, h2_title):
    files = SECTION_SCREENS.get(sid)
    if not files:
        return ""
    imgs = "\n".join(
        f'                            <figure class="docs-screen-card">'
        f'<img src="../../assets/screens/{lang}/{fname}" width="300" height="649" loading="lazy" decoding="async" alt="{html.escape(h2_title)}" />'
        f"</figure>"
        for fname in files
    )
    multi = " docs-screens-pair" if len(files) > 1 else ""
    return f'\n                        <div class="docs-screens{multi}">\n{imgs}\n                        </div>'


def render_page(lang, meta, strings, languages):
    doc = DOCS_DATA[lang]
    title = html.escape(doc["title"])
    description = html.escape(doc["description"])
    h1 = html.escape(doc["h1"])
    lead = html.escape(doc["lead"])
    toc_title = html.escape(doc["toc_title"])
    sections = doc["sections"]

    nav, footer = strings["nav"], strings["footer"]
    home = "../../index.html"

    def lang_option(l):
        current = l["code"] == lang
        active = " active" if current else ""
        selected = 'aria-selected="true"' if current else 'aria-selected="false"'
        return (
            f'                            <li role="presentation"><a role="option" class="lang-option{active}" {selected} '
            f'href="../{l["code"]}/" hreflang="{l["code"]}" lang="{l["code"]}" data-lang-code="{l["code"]}">'
            f'<span class="lang-flag">{l["flag"]}</span><span class="lang-name">{l["name"]}</span></a></li>'
        )

    lang_options = "\n".join(lang_option(l) for l in languages)
    alternates = "\n".join(
        f'        <link rel="alternate" hreflang="{l["code"]}" href="{SITE_URL}/docs/{l["code"]}/" />'
        for l in languages
    )
    toc = "\n".join(
        f'                        <li><a href="#{sid}">{html.escape(h2)}</a></li>'
        for sid, h2, _ in sections
    )

    rendered_sections = []
    for sid, h2, content in sections:
        screens_html = render_screens(lang, sid, h2)
        section_html = (
            f'                    <section id="{sid}" class="docs-section">\n'
            f"                        <h2>{html.escape(h2)}</h2>\n"
            f"{indent(content.strip(), 24)}"
            f"{screens_html}\n"
            f"                    </section>"
        )
        rendered_sections.append(section_html)

    body = "\n\n".join(rendered_sections)

    return f"""<!doctype html>
<html lang="{lang}" dir="{meta["dir"]}">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>{title}</title>
        <meta name="description" content="{description}" />
        <meta name="theme-color" content="#3B82F6" />
        <meta name="apple-itunes-app" content="app-id=6753620051" />
        <meta property="og:type" content="article" />
        <meta property="og:title" content="{title}" />
        <meta property="og:description" content="{description}" />
        <meta property="og:url" content="{SITE_URL}/docs/{lang}/" />
        <meta property="og:image" content="{SITE_URL}/assets/og-image.jpg" />
        <link rel="canonical" href="{SITE_URL}/docs/{lang}/" />
{alternates}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link
            href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap"
            rel="stylesheet"
        />
        <link rel="stylesheet" href="../../styles.css" />
        <link rel="stylesheet" href="../docs.css" />
        <link rel="icon" type="image/svg+xml" href="../../favicon.svg" />
    </head>
    <body class="docs-body">
        <a href="#docs-content" class="skip-link">{html.escape(strings["misc"]["skipLink"])}</a>
        <nav class="navbar">
            <div class="nav-container">
                <a class="nav-logo" href="{home}">
                    <span class="logo-icon">
                        <img src="../../web_logo.png" alt="" class="logo-image" />
                    </span>
                    <span class="logo-text">BackupFlow</span>
                </a>
                <div class="nav-menu" id="nav-menu">
                    <a class="nav-link" href="{home}#features">{nav["features"]}</a>
                    <a class="nav-link" href="{home}#pricing">{nav["pricing"]}</a>
                    <a class="nav-link" href="{home}#support">{nav["support"]}</a>
                    <div class="lang-switcher" id="lang-switcher">
                        <button
                            type="button"
                            class="lang-toggle"
                            id="lang-toggle"
                            aria-haspopup="listbox"
                            aria-expanded="false"
                            aria-controls="lang-menu"
                        >
                            <span class="lang-flag">{meta["flag"]}</span>
                            <span class="lang-code">{lang.upper()}</span>
                            <svg class="lang-caret" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M6 9l6 6 6-6" />
                            </svg>
                        </button>
                        <ul class="lang-menu" id="lang-menu" role="listbox" aria-label="{html.escape(strings["misc"]["langLabel"])}">
{lang_options}
                        </ul>
                    </div>
                    <a class="nav-link download-btn" href="https://apps.apple.com/app/backupflow/id6753620051" target="_blank" rel="noopener noreferrer">{nav["download"]}</a>
                </div>
                <button
                    type="button"
                    class="nav-toggle"
                    aria-label="{html.escape(strings["misc"]["toggleNav"])}"
                    aria-controls="nav-menu"
                    aria-expanded="false"
                >
                    <span></span>
                    <span></span>
                    <span></span>
                </button>
            </div>
        </nav>

        <main id="docs-content" class="docs-page">
            <div class="container">
                <header class="docs-hero">
                    <h1>{h1}</h1>
                    <p class="docs-lead">{lead}</p>
                </header>

                <div class="docs-layout">
                    <aside class="docs-toc" aria-labelledby="docs-toc-title">
                        <p class="docs-toc-title" id="docs-toc-title">{toc_title}</p>
                        <ol>
{toc}
                        </ol>
                    </aside>

                    <article class="docs-content">
{body}
                    </article>
                </div>
            </div>
        </main>

        <footer class="footer">
            <div class="container">
                <div class="footer-content">
                    <div class="footer-brand">
                        <div class="footer-logo">
                            <div class="logo-icon">
                                <img src="../../web_logo.png" alt="" class="logo-image" />
                            </div>
                            <span class="logo-text">BackupFlow</span>
                        </div>
                        <p class="footer-description">{footer["desc"]}</p>
                    </div>
                    <div class="footer-links">
                        <div class="footer-column">
                            <h4>{footer["supportHeading"]}</h4>
                            <a href="./">{footer["docs"]}</a>
                            <a href="../../privacy-policy.html?lang={lang}">{footer["privacy"]}</a>
                            <a href="mailto:tamersavasci@icloud.com">{footer["contact"]}</a>
                        </div>
                    </div>
                </div>
                <div class="footer-bottom">
                    <p>&copy; 2026 BackupFlow. {footer["copyright"]}</p>
                </div>
            </div>
        </footer>

        <script src="../docs.js"></script>
    </body>
</html>
"""


def render_index(languages):
    picker = "\n".join(
        f'                <li><a href="{l["code"]}/" lang="{l["code"]}" hreflang="{l["code"]}">'
        f'<span class="lang-flag">{l["flag"]}</span> {l["name"]}</a></li>'
        for l in languages
    )
    codes = json.dumps([l["code"] for l in languages])
    return f"""<!doctype html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>BackupFlow Help</title>
        <link rel="canonical" href="{SITE_URL}/docs/" />
        <script>
            // Open the Help page in the language chosen on the main site, else the browser language.
            (function () {{
                var supported = {codes};
                var langs = [];
                try {{
                    langs.push(localStorage.getItem("bf_lang") || "");
                }} catch (e) {{
                    /* localStorage unavailable */
                }}
                langs = langs.concat(navigator.languages || [navigator.language || "en"]);
                for (var i = 0; i < langs.length; i++) {{
                    var code = (langs[i] || "").toLowerCase().split("-")[0];
                    if (supported.indexOf(code) !== -1) {{
                        location.replace(code + "/");
                        return;
                    }}
                }}
            }})();
        </script>
        <link rel="stylesheet" href="../styles.css" />
        <link rel="stylesheet" href="docs.css" />
        <link rel="icon" type="image/svg+xml" href="../favicon.svg" />
    </head>
    <body class="docs-body">
        <main class="docs-page">
            <div class="container">
                <header class="docs-hero">
                    <h1>BackupFlow Help</h1>
                    <p class="docs-lead">Choose your language</p>
                </header>
                <ul class="docs-picker">
{picker}
                </ul>
            </div>
        </main>
    </body>
</html>
"""


def main():
    data = load_site_strings()
    languages = data["languages"]
    for meta in languages:
        lang = meta["code"]
        target = OUT / lang / "index.html"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(render_page(lang, meta, data["t"][lang], languages), encoding="utf-8")
    (OUT / "index.html").write_text(render_index(languages), encoding="utf-8")
    print(f"Built {len(languages)} help pages in {OUT.relative_to(ROOT)}/")


if __name__ == "__main__":
    main()
