# Workshop website (GitHub Pages)

Source for https://mjendza.github.io/workshop-entra-as-code-interactive/ , built with [VitePress](https://vitepress.dev/).

The content is **not** duplicated here. `scripts/prepare.mjs` stages the root `README.md` and `doc/**`
into `site/src/` (git-ignored) at build time, so the Markdown files stay the single source for both
the website and the GitHub Issues created by `create-workshop-issues.yml`.

| What | Where |
|---|---|
| Sidebar / stage order | `paths` in `scripts/prepare.mjs` (keep in sync with `create-workshop-issues.yml`) |
| Site config, nav, search | `.vitepress/config.mts` |
| Theme, colors, "Copy the template" banner | `.vitepress/theme/` |
| Home page, logo | `pages/` |

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
