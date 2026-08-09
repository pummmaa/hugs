---
title: "custom-fonts-for-hugo-book-site"
date: 2026-08-09T05:56:31Z
lastmod: 2026-08-09T05:56:31Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Custom Fonts for Hugo Book Site

Fonts similar to Liberation (clean, readable, metric-compatible with Arial/Times).

---

## Fonts Similar to Liberation

| Font | Style | Source | Notes |
|------|-------|--------|-------|
| **Inter** | Sans-serif | Google Fonts | Very popular for web, excellent readability |
| **Source Sans 3** | Sans-serif | Google Fonts | Adobe's open font, clean and neutral |
| **Noto Sans** | Sans-serif | Google Fonts | Google's universal font, similar to Liberation Sans |
| **IBM Plex Sans** | Sans-serif | Google Fonts | Modern, technical feel |
| **Roboto** | Sans-serif | Google Fonts | Android default, very readable |
| **Open Sans** | Sans-serif | Google Fonts | One of the most popular web fonts |
| **Fira Sans** | Sans-serif | Google Fonts | Mozilla's font, great for technical content |

### Monospace (for code blocks)

| Font | Source |
|------|--------|
| **JetBrains Mono** | Google Fonts |
| **Fira Code** | Google Fonts |
| **Source Code Pro** | Google Fonts |
| **IBM Plex Mono** | Google Fonts |

---

## Option A: Use Google Fonts (Simplest)

Add to `layouts/partials/docs/inject/head.html`:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700&family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/css/gruvbox.css">
```

Then add to `static/css/gruvbox.css`:

```css
body, .markdown {
  font-family: 'Inter', sans-serif !important;
}

code, pre, pre code {
  font-family: 'JetBrains Mono', monospace !important;
}
```

---

## Option B: Self-Host Fonts (No External Requests — Better for Privacy/CSP)

### Download fonts

Get `.woff2` files from [google-webfonts-helper](https://gwfh.mranftl.com/fonts) or [fontsource.org](https://fontsource.org/).

### Place in static directory

```bash
mkdir -p /home/debian/hugs/static/fonts
# Copy .woff2 files into this directory
```

### Add to `static/css/gruvbox.css`

```css
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url('/fonts/inter-v13-latin-regular.woff2') format('woff2');
}

@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 700;
  font-display: swap;
  src: url('/fonts/inter-v13-latin-700.woff2') format('woff2');
}

@font-face {
  font-family: 'JetBrains Mono';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url('/fonts/jetbrains-mono-v18-latin-regular.woff2') format('woff2');
}

body, .markdown {
  font-family: 'Inter', sans-serif !important;
}

code, pre, pre code {
  font-family: 'JetBrains Mono', monospace !important;
}
```

---

## Option C: System Font Stack (No Downloads at All)

Uses whatever Liberation/similar font the visitor already has installed.

Add to `static/css/gruvbox.css`:

```css
body, .markdown {
  font-family: 'Liberation Sans', 'Nimbus Sans', Arial, Helvetica, sans-serif !important;
}

code, pre, pre code {
  font-family: 'Liberation Mono', 'Nimbus Mono', 'Courier New', monospace !important;
}
```

---

## After Any Change

Rebuild the site:

```bash
~/hugs/rebuild.sh
```

Hard refresh your browser: `Ctrl+Shift+R`

