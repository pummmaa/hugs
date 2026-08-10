---
title: "deploying-markdoc-on-gitlab-pages"
date: 2026-08-10T19:55:20Z
lastmod: 2026-08-10T19:55:20Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Deploying Markdoc on GitLab Pages

A complete guide to deploying a Markdown-based documentation site using [Markdoc](https://markdoc.dev/) with Next.js on GitLab Pages.

---

## Prerequisites

- Node.js 18+ installed
- A GitLab repository
- A custom domain with DNS access
- Firewall rules configured

---

## 1. Project Setup

### Initialize the project

```bash
npx create-next-app my-docs --typescript
cd my-docs
npm install @markdoc/markdoc @markdoc/next.js
```

### Project structure

```
my-docs/
├── pages/              # Markdown content files (each becomes a route)
│   ├── index.md
│   ├── getting-started.md
│   └── guides/
│       └── setup.md
├── markdoc/            # Markdoc schema (custom tags, nodes, functions)
│   ├── tags/
│   └── nodes/
├── components/         # React components for custom Markdoc tags
├── public/             # Static assets (images, favicons)
├── next.config.js
├── package.json
└── .gitlab-ci.yml
```

---

## 2. Configure Next.js for Markdoc + Static Export

Create or update `next.config.js`:

```js
const withMarkdoc = require('@markdoc/next.js');

module.exports = withMarkdoc()({
  output: 'export',
  pageExtensions: ['md', 'mdoc', 'js', 'jsx', 'ts', 'tsx'],
  images: {
    unoptimized: true, // Required for static export
  },
});
```

> **Note:** If deploying to a subpath (e.g., `username.gitlab.io/repo-name`),
> add `basePath: '/repo-name'` to the config.
> 

---

## 3. Add Build Script

In `package.json`, ensure you have:

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  }
}
```

The `next build` command with `output: 'export'` generates static HTML into the `out/` directory.

---

## 4. Create `.gitlab-ci.yml`

This is the core of the GitLab Pages deployment. The output **must** land in a `public/` artifact from a job named `pages`:

```yaml
image: node:20-alpine

stages:
  - build
  - deploy

build:
  stage: build
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - out/
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

pages:
  stage: deploy
  script:
    - rm -rf public
    - mv out public
  artifacts:
    paths:
      - public
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

---

## 5. Custom Domain Configuration

### In GitLab

1. Navigate to **Settings → Pages → New Domain**
2. Enter your domain (e.g., `docs.yourdomain.com`)
3. Note the verification code provided

### DNS Records

For a **subdomain** (e.g., `docs.yourdomain.com`):

| Type | Name | Value |
| --- | --- | --- |
| CNAME | `docs` | `your-namespace.gitlab.io` |
| TXT | `_gitlab-pages-verification-code.docs` | *(code from GitLab UI)* |

For an **apex domain** (e.g., `yourdomain.com`):

| Type | Name | Value |
| --- | --- | --- |
| A | `@` | `35.185.44.232` |

> Verify GitLab's current IP addresses in their
> [official documentation](https://docs.gitlab.com/ee/user/project/pages/custom_domains_ssl_tls_certification/).
> 

### TLS/SSL

- Check **"Force HTTPS"** in the GitLab Pages settings
- GitLab automatically provisions a Let's Encrypt certificate once DNS propagates

---

## 6. Handle 404 Pages

Next.js static export auto-generates a `404.html`. Create a custom one:

```md
<!-- pages/404.md -->
---
title: Page Not Found
---

# 404 — Page Not Found

The page you're looking for doesn't exist.

[← Back to Home](/)
```

GitLab Pages automatically serves `404.html` for missing paths.

---

## 7. Optional Enhancements

### Cache headers

Create `public/_headers` in your source `public/` directory:

```
/_next/static/*
  Cache-Control: public, max-age=31536000, immutable

/*.html
  Cache-Control: public, max-age=0, must-revalidate
```

### Redirects

Create `public/_redirects`:

```
https://www.yourdomain.com/* https://yourdomain.com/:splat 301
```

### Robots and sitemap

Add `public/robots.txt`:

```
User-agent: *
Allow: /
Sitemap: https://yourdomain.com/sitemap.xml
```

Generate a sitemap during build using a package like `next-sitemap`.

---

## 8. Deploy

Push to your default branch and the pipeline handles everything:

```bash
git add .
git commit -m "Initial Markdoc site"
git push origin main
```

### Verify deployment

1. **Build → Pipelines** — Confirm the `pages` job passes (green checkmark)
2. **Deploy → Pages** — Your site URL should appear as active
3. **Custom domain** — Visit your domain; HTTPS should be active

---

## Deployment Flow

```
git push origin main
  → GitLab CI triggers pipeline
  → `build` job: runs `npm ci && npm run build` → produces `out/`
  → `pages` job: moves `out/` → `public/`
  → GitLab Pages serves `public/` at your custom domain
  → Let's Encrypt TLS provisioned automatically
```

---

## Troubleshooting

| Issue | Solution |
| --- | --- |
| 404 on all pages | Ensure `pages` job artifact path is exactly `public` |
| CSS/JS not loading | Check `basePath` in `next.config.js` matches your deploy path |
| Domain not verified | Wait for DNS propagation (up to 24h); verify TXT record is correct |
| Images broken | Confirm `images.unoptimized: true` is set in config |
| Build fails on GitLab | Test locally with `npm run build` first; check Node version matches CI image |
