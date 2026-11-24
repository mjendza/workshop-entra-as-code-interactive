# Design brief: Microsoft Entra as Code Workshop website

You are designing the public website for an open-source, hands-on workshop. Design a modern, polished docs and workshop site that we will build on **VitePress 1.6** by extending its default theme. Everything below describes what exists today and what must stay true.

---

## 1. The project in one paragraph

**Microsoft Entra as Code** is a free workshop that teaches engineers to manage Microsoft cloud identity declaratively with **Terraform** and **Microsoft Graph**. It has **three independent paths**: participants can do any one of them, in any order.

| Path | Tenant | Stages | Topics |
|---|---|---|---|
| 🏢 **Path 1: Workforce** | Microsoft Entra ID (enterprise) | 00 – 21 + Cleanup + Next Steps (24 pages, 7 phases) | SSO, service principals, workload identity federation, Conditional Access, Access Packages, PIM, tenant hardening, Agent Identity, Maester, EntraExporter, Zero Trust Assessment, drift detection, Lokka MCP, SPA SSO, app roles, certificate auth, CI/CD, secret monitoring, TAP, Verified ID step-up, App Role PIM |
| 👥 **Path 2: External ID** | Entra External ID (CIAM) | Ext-00 – 05 (6 pages) | Native Authentication API, Pester tests, SPA + API SSO with user flows, passwordless + SMS MFA, sign-up attributes, token enrichment via custom auth extensions |
| 🪪 **Path 3: Verified ID** | Entra ID + Azure subscription | VC-00 – 01 (2 pages) | DID authority onboarding, Key Vault signing keys, W3C Verifiable Credential contracts via a custom Terraform provider |

**Repository:** https://github.com/mjendza/workshop-entra-as-code-interactive
**Site URL:** https://mjendza.github.io/workshop-entra-as-code-interactive/ (the base path `/workshop-entra-as-code-interactive/` is mandatory)

### The site's main job: interactive mode

The repo is a **GitHub template**. When a participant clicks **"Copy the Workshop"**, GitHub creates a copy of the repo in their account, and a GitHub Action creates **one GitHub Issue per stage**. Each issue holds the stage's checklist, and stage-to-stage links point at the participant's own issues. Participants then work through the issues, tick the checkboxes and close each one.

The website is therefore **not the place where people do the workshop**. It is where they:
1. **Discover and evaluate** the workshop: what it is, which path fits them, and what tenant or licenses they need.
2. **Get converted** into clicking "Copy the Workshop".
3. **Read and reference** stage content comfortably: search, deep links, and reading on a second screen while they work in the terminal.

Make the primary call to action, **Copy the Workshop**, prominent without being pushy. It must appear on the home page and on every stage page (today that is a slim banner above the content).

Template URL (use it as-is):
`https://github.com/new?template_owner=mjendza&template_name=workshop-entra-as-code-interactive&owner=%40me&name=workshop-entra-as-code&description=Workshop:+Entra+ID+as+Code&visibility=public`

---

## 2. Audience

- Cloud engineers, identity architects, SecOps and DevOps engineers (Path 1)
- App developers, CIAM engineers and product teams (Path 2)
- Trust architects and decentralized identity engineers (Path 3)

Technical, impatient, skeptical of marketing. They value clarity, density done well, and real code. They often read the site while running `terraform apply` in a split window, so it must work at narrow widths, around 600–900 px.

---

## 3. Hard technical constraints

The design must be achievable inside these limits:

- **Content is Markdown, generated at build time.** The source is the repo's root `README.md` and `doc/<stage>/README.md`, the same files used to create the GitHub Issues. **We will not hand-write or restructure the stage content for the site.** The design must style whatever standard Markdown produces.
- **Framework:** VitePress default theme, extended with CSS variables, custom CSS, layout slots (`doc-before`, `home-hero-after`, `sidebar-nav-before`, and others) and small Vue components. A custom home layout is fine. Do not design anything that requires replacing the whole docs layout.
- **Static hosting** on GitHub Pages: no backend, no auth, no analytics requirement. Search is VitePress local search.
- **Light and dark themes** are both required. Dark is the default today.
- **No heavy client-side frameworks** beyond Vue. Keep web fonts to at most 2 families.
- **Accessibility:** WCAG 2.1 AA contrast in both themes, visible focus states, and no information conveyed by color alone (the paths are color-coded, so pair each color with an icon and a label).

---

## 4. Content elements the stage pages contain (design every one)

Stage pages are long-form technical tutorials. A typical page has a Rationale, an Estimated Time, Goals, Documentation & References, Implementation & Code, step-by-step instructions with screenshots, a Verification Checklist, and Navigation.

Design the treatment for:

1. **Headings h1–h4.** The h1 is the stage title, e.g. "Stage 6: Privileged Identity Management (PIM)". Consider a stage header with the stage number, path badge, estimated time and requirements, such as "Entra ID P2" or "Sandbox tenant".
2. **Code blocks:** HCL (Terraform), PowerShell, bash, HTTP and JSON. They are long, so they need language labels and copy buttons (built in).
3. **Inline code**, which is used heavily for resource names such as `TF.Demo.<name>-CustomerHelpdesk.Spa.Application`.
4. **GitHub-style alerts:** `NOTE`, `TIP`, `IMPORTANT`, `WARNING` and `CAUTION`. They carry real safety meaning, such as "this modifies tenant-wide policy".
5. **Tables**, including wide 4–6 column roadmap tables. They must scroll horizontally on mobile.
6. **Screenshots:** Azure portal and terminal captures of varying sizes, and some diagrams (PNG, PlantUML exports).
7. **Mermaid diagrams**, mainly flowcharts and graphs.
8. **Task-list checkboxes** (`- [ ]`) for the Verification Checklist. They are read-only on the site; a nice touch is to hint that they become interactive in the participant's own GitHub Issue.
9. **Links to repo source files** (`.tf`, `.ps1` on GitHub) versus internal stage links. External links should be visibly distinct.
10. **Badges** (shields.io) in the overview.

---

## 5. Pages and templates to design

### 5.1 Home (`/`)
- **Hero:** name "Entra as Code", a tagline (current: *"Identity, declared in Terraform"*), a short description, and the primary CTA **Copy the Workshop**. Secondary actions: **Read the Overview** and **Start with Stage 0**.
- **A "Pick your path" section:** three path cards (Workforce, External ID, Verified ID) showing stage count, target tenant, who it's for, and a "Start" link. This is the most important block after the hero.
- **"How interactive mode works":** a 4–6 step visual (Copy template → Actions creates issues → Open a stage issue → Write Terraform and apply → Tick checkboxes and close → Next stage).
- **Prerequisites at a glance:** tenant and license needs per path (P1/P2, Security Defaults disabled, Azure subscription for Verified ID). Tools needed: Terraform ≥ 1.0, Git, PowerShell 7+, VS Code.
- **Safety callout:** use a sandbox or dev tenant, never production, because some stages change tenant-wide singleton policies.
- **Footer:** MIT license, GitHub link, author (Mateusz Jendza).

### 5.2 Overview (`/overview`)
The full root README: path comparison table, detailed roadmaps per phase, risks, prerequisites, FAQ and changelog. Very long, so it needs good outline navigation.

### 5.3 Stage page template (`/stage-00/` … `/stage-21/`, `/external-00/` … `/external-05/`, `/vc-00/`, `/vc-01/`)
- **Sidebar:** three collapsible path groups, with Path 1 further grouped into 7 phases (Foundations & Identities, Access Governance & Zero Trust, Tenant Hardening & Modern Identities, Security Posture & AI Operations, Application Security & Automation, Advanced Operations & High Assurance, Disassembly & Bonus). Stage labels look like "06 · PIM" and "Ext-02 · SSO for CustomerHelpdesk".
- **The current path should be obvious**, for example through path color, a breadcrumb, or a "Stage 6 of 21" progress indicator.
- **Badges for preview and private-preview stages:** Stage 8 Agent Identity (Preview), Stage 20 High Assurance (Preview) and Stage 21 App Role PIM (Private Preview). Visually mark stages that change tenant-wide policy: 7, 19 and 20.
- **"Copy the template" banner or callout** at the top.
- **Right-hand outline** ("On this page").
- **Prev/next stage navigation** that stays within the same path.
- **"Edit this page on GitHub"** link.

### 5.4 Optional: path landing pages
One page per path, e.g. `/paths/workforce`, showing its phases and stages as a visual roadmap or timeline with requirements per stage. Propose this if you think it adds value; it would be a new hand-written page.

---

## 6. Brand and visual direction

- **No official Microsoft branding.** This is a community project, not a Microsoft product, so don't use Microsoft logos, the Entra logo or Fluent product marks. Echoing the Microsoft blue family is fine.
- **Current palette and tokens:**
  - Primary: Microsoft-ish blue `#0078d4`, with `#4cc2ff` in dark mode
  - Path accents (already used in the README's mermaid diagrams and overview SVG): **Workforce `#38bdf8`** (sky), **External ID `#c084fc`** (purple), **Verified ID `#34d399`** (green)
  - Dark surfaces: slate `#0f172a` / `#1e293b`
- **Current logo:** a shield containing `</>` with a sky → blue → purple gradient. Feel free to refine or replace it with an original mark that works as a favicon at 16 px.
- **Tone:** engineering-grade, calm and confident. Think Terraform docs, Vercel or Stripe docs, and the Astro Starlight polish, not a marketing landing page. Emojis appear in the source content (🏢 👥 🪪 ⚠️). The design can embrace them as path icons or replace them with a consistent icon set.
- **Existing asset:** `doc/workshop-overview.svg` is an overview illustration of the 3 paths. You may restyle it or keep it consistent with it.

---

## 7. Deliverables we need from you

1. **Design tokens:** color (light and dark), typography scale, spacing, radius and shadows, mapped where possible to **VitePress CSS variables** (`--vp-c-brand-1`, `--vp-c-bg`, `--vp-c-bg-soft`, `--vp-c-text-1`, `--vp-font-family-base`, `--vp-code-block-bg`, `--vp-custom-block-*`, `--vp-home-hero-*`, and so on).
2. **High-fidelity mockups**, desktop (1440 px) and mobile (390 px), in both themes:
   - Home
   - Stage page (use Stage 6 PIM or External-02 as the sample; it should have code, alerts, a table, screenshots and a checklist)
   - Overview (top section + a long table)
   - Optional: a path landing page
3. **Component specs:** path card, stage header (number, path, time, requirements, preview badge), template CTA banner, alert variants, sidebar item states (default, hover, active, preview-badged), prev/next navigation, checklist styling and external-link indicator.
4. **The "How interactive mode works" illustration**, as an SVG or a design that can be built in HTML/CSS.
5. **Logo and favicon** (SVG), plus an **Open Graph image** (1200×630) for link previews.
6. A short **rationale** for the key decisions, especially how path identity and the template CTA are handled.

---

## 8. Success criteria

- A first-time visitor understands within 10 seconds **what this is, that there are 3 independent paths, and that copying the template gives them tracked GitHub Issues**.
- A participant mid-workshop can find any stage in 2 clicks or by search, and read long HCL and PowerShell comfortably beside a terminal.
- Both themes look intentional, not like a default-theme recolor.
- Everything can be implemented by extending VitePress's default theme while keeping the Markdown content untouched.
