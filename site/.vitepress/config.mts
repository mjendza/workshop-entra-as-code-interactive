import { slug } from 'github-slugger'
import { withMermaid } from 'vitepress-plugin-mermaid'
import type { DefaultTheme } from 'vitepress'
import type MarkdownIt from 'markdown-it'
import { paths, phaseRange, REPO_URL } from '../workshop.mjs'
import { icons } from './theme/icons.mjs'

const BASE = '/workshop-entra-as-code-interactive/'

// ---- sidebar ---------------------------------------------------------------------------------
const esc = (t: string) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;')

function stageLabel(it: { num: string; short: string; tenantWide?: boolean; preview?: string }) {
  const num = it.num === '—' ? '' : `<span class="ec-num">${it.num}</span>`
  const badges = [
    it.tenantWide ? `<span class="ec-tw" role="img" aria-label="Changes tenant-wide policy" title="Changes tenant-wide policy">${icons.shieldAlert}</span>` : '',
    it.preview === 'preview' ? '<span class="ec-badge ec-badge--preview">Preview</span>' : '',
    it.preview === 'private' ? '<span class="ec-badge ec-badge--private">Private</span>' : ''
  ].join('')
  return `${num}<span class="ec-label">${esc(it.short)}</span>${badges}`
}

const overviewItem = { text: `<span class="ec-side-top">${icons.book}<span>Overview</span></span>`, link: '/overview' }

const pathGroups: DefaultTheme.SidebarItem[] = paths.map(p => {
    const count = p.groups.reduce((n, g) => n + g.items.length, 0)
    const toItem = (it: any) => ({ text: stageLabel(it), link: `/${it.dir}/` })
    const head = `<span class="ec-side-path ec-c-${p.accent}">${icons[p.accent]}<span class="ec-side-path__name">${p.name}</span><span class="ec-count">${count}</span></span>`
    return {
      text: head,
      collapsed: false,
      items: [
        { text: `<span class="ec-side-roadmap">Roadmap</span>`, link: `/paths/${p.key}` },
        ...(p.groups.length === 1
          ? p.groups[0].items.map(toItem)
          : p.groups.map(g => ({
              text: `<span class="ec-side-phase"><span>${esc(g.name)}</span>${g.items.some(i => i.tenantWide) ? `<span class="ec-tw" aria-hidden="true">${icons.shieldAlert}</span>` : ''}<span class="ec-count">${phaseRange(g)}</span></span>`,
              collapsed: true,
              items: g.items.map(toItem)
            })))
      ]
    }
  })

// One sidebar per path: a stage page shows only its own path. Keys are URL prefixes
// (VitePress picks the key the page path starts with): /stage-, /external-, /vc-.
// The overview keeps all three paths.
const sidebar: DefaultTheme.SidebarMulti = {
  '/overview': [overviewItem, ...pathGroups],
  ...Object.fromEntries(paths.map((p, i) => {
    const prefix = '/' + p.groups[0].items[0].dir.replace(/[^-]+$/, '') // "stage-00" -> "/stage-"
    return [prefix, [overviewItem, pathGroups[i]]]
  }))
}

// ---- markdown: GitHub task lists ("- [ ] item") as read-only checkboxes -----------------------
function taskLists(md: MarkdownIt) {
  md.core.ruler.after('inline', 'ec-task-lists', state => {
    const t = state.tokens
    for (let i = 2; i < t.length; i++) {
      if (t[i].type !== 'inline' || t[i - 1].type !== 'paragraph_open' || t[i - 2].type !== 'list_item_open') continue
      const m = t[i].content.match(/^\[([ xX])\]\s/)
      if (!m) continue
      const first = t[i].children?.[0]
      if (!first || first.type !== 'text') continue
      first.content = first.content.replace(/^\[[ xX]\]\s/, '')
      t[i].content = t[i].content.slice(m[0].length)
      const box = new state.Token('html_inline', '', 0)
      const done = m[1] !== ' '
      box.content = `<input class="ec-task" type="checkbox" disabled${done ? ' checked' : ''} aria-label="${done ? 'Done' : 'To do'}"> `
      t[i].children!.unshift(box)
      t[i - 2].attrJoin('class', 'ec-task-item')
      // mark the enclosing list once
      for (let j = i - 3; j >= 0; j--) {
        if (t[j].type === 'bullet_list_open' && t[j].level === t[i - 2].level - 1) { t[j].attrSet('class', 'ec-task-list'); break }
      }
    }
  })
}

export default withMermaid({
  title: 'Entra as Code',
  titleTemplate: ':title · Entra as Code',
  description: 'Hands-on workshop: manage Microsoft Entra ID, External ID and Verified ID declaratively with Terraform and Microsoft Graph.',
  lang: 'en-US',
  base: BASE,
  srcDir: 'src',
  cleanUrls: true,
  appearance: 'dark',
  sitemap: { hostname: `https://mjendza.github.io${BASE}` },
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${BASE}logo.svg` }],
    ['link', { rel: 'preconnect', href: 'https://fonts.googleapis.com' }],
    ['link', { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' }],
    ['link', { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600;700&family=Geist+Mono:wght@400;500;600&display=swap' }],
    ['meta', { name: 'theme-color', content: '#0f172a' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'Entra as Code · Identity, declared in Terraform' }],
    ['meta', { property: 'og:description', content: 'A hands-on workshop: Workforce, External ID and Verified ID as code with Terraform and Microsoft Graph.' }]
  ],
  vite: {
    // mermaid imports the CommonJS package "fastdom" (+ its promised extension), which vitepress-plugin-mermaid does not
    // pre-bundle. Without this the dev server serves it raw and the whole app fails to boot (white page).
    optimizeDeps: { include: ['fastdom', 'fastdom/extensions/fastdom-promised.js'] }
  },
  markdown: {
    // Match GitHub's heading anchors so links written for GitHub keep working.
    anchor: { slugify: slug },
    headers: { slugify: slug },
    theme: { light: 'github-light', dark: 'github-dark' },
    config: md => { md.use(taskLists) }
  },
  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'Entra as Code',
    nav: [
      { text: 'Overview', link: '/overview' },
      { text: `<span class="ec-nav ec-c-wf">${icons.wf}<span>Workforce</span></span>`, link: '/paths/workforce', activeMatch: '^/(stage-|paths/workforce)' },
      { text: `<span class="ec-nav ec-c-ext">${icons.ext}<span>External ID</span></span>`, link: '/paths/external', activeMatch: '^/(external-|paths/external)' },
      { text: `<span class="ec-nav ec-c-vc">${icons.vc}<span>Verified ID</span></span>`, link: '/paths/verified-id', activeMatch: '^/(vc-|paths/verified-id)' }
    ],
    sidebar,
    outline: { level: [2, 3], label: 'On this page' },
    search: { provider: 'local' },
    socialLinks: [{ icon: 'github', link: REPO_URL }],
    externalLinkIcon: true,
    editLink: {
      // prepare.mjs records the original file in frontmatter ("doc/stage-01/README.md").
      // This function is serialized to the client, so it must not reference outer variables.
      pattern: ({ frontmatter, filePath }) =>
        'https://github.com/mjendza/workshop-entra-as-code-interactive/edit/main/' +
        (frontmatter.source ?? `site/pages/${filePath}`),
      text: 'Edit this page on GitHub'
    },
    docFooter: { prev: '← Previous', next: 'Next →' },
    returnToTopLabel: 'Back to top'
  }
})
