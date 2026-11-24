# Workshop website (GitHub Pages)

Source for https://mjendza.github.io/workshop-entra-as-code-interactive/ , built with [VitePress](https://vitepress.dev/).

The content is **not** duplicated here. `scripts/prepare.mjs` stages the root `README.md` and `doc/**`
into `site/src/` (git-ignored) at build time, so the Markdown files stay the single source for both
the website and the GitHub Issues created by `create-workshop-issues.yml`.

| What | Where |
|---|---|
| Stage order, phases, per-stage badges (license, preview, tenant-wide) | `workshop.mjs` (keep in sync with `create-workshop-issues.yml`) |
| Site config, sidebar, nav, search, task-list checkboxes | `.vitepress/config.mts` |
| Design tokens + all styling | `.vitepress/theme/custom.css` |
| Stage header + "Copy the template" banner | `.vitepress/theme/StageHeader.vue` |
| Home page, path roadmap pages | `.vitepress/theme/HomePage.vue`, `Flow.vue`, `PathPage.vue` |
| Home page entry, logo | `pages/` |

The design comes from the "Entra as Code Workshop Site" design canvas (Geist / Geist Mono, dark default,
path accents sky / purple / green). Each stage's H1 and "Estimated Time" heading are lifted out of the
Markdown at build time and rendered by the stage header.

Link rules applied by `prepare.mjs`: `doc/<stage>/README.md` → `/<stage>/`, images are copied, and any
other repo file (`.tf`, `.ps1`, folders, ...) links to GitHub. Missing targets are printed as warnings,
and the VitePress build fails on dead internal links.

```shell
cd site
npm ci
npm run dev      # http://localhost:5173/workshop-entra-as-code-interactive/
npm run build    # output in site/.vitepress/dist
```

Deployment: `.github/workflows/pages.yml` runs on pushes to `main` that touch `README.md`, `doc/**` or `site/**`.
It runs **only** in `mjendza/workshop-entra-as-code-interactive`; copies made from the template skip it.
