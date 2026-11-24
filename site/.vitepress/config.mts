import { readFileSync } from 'node:fs'
import { slug } from 'github-slugger'
import { withMermaid } from 'vitepress-plugin-mermaid'
import type { DefaultTheme } from 'vitepress'

const REPO = 'mjendza/workshop-entra-as-code-interactive'
const REPO_URL = `https://github.com/${REPO}`
export const TEMPLATE_URL =
  `https://github.com/new?template_owner=mjendza&template_name=workshop-entra-as-code-interactive&owner=%40me&name=workshop-entra-as-code&description=Workshop:+Entra+ID+as+Code&visibility=public`

// Written by scripts/prepare.mjs (same order as the issue-creation workflow).
type Path = { key: string; text: string; groups: { text: string; items: [string, string][] }[] }
const paths: Path[] = JSON.parse(readFileSync(new URL('./paths.generated.json', import.meta.url), 'utf8'))

const sidebar: DefaultTheme.SidebarItem[] = [
  { text: 'Workshop Overview', link: '/overview' },
  ...paths.map(p => ({
    text: p.text,
    collapsed: false,
    items: p.groups.length === 1
      ? p.groups[0].items.map(([dir, text]) => ({ text, link: `/${dir}/` }))
      : p.groups.map(g => ({
          text: g.text,
          collapsed: true,
          items: g.items.map(([dir, text]) => ({ text, link: `/${dir}/` }))
        }))
  }))
]

export default withMermaid({
  title: 'Entra as Code',
  titleTemplate: ':title · Entra as Code Workshop',
  description: 'Hands-on workshop: manage Microsoft Entra ID, External ID and Verified ID declaratively with Terraform and Microsoft Graph.',
  lang: 'en-US',
  base: '/workshop-entra-as-code-interactive/',
  srcDir: 'src',
  cleanUrls: true,
  lastUpdated: false,
  appearance: 'dark',
  sitemap: { hostname: `https://mjendza.github.io/workshop-entra-as-code-interactive/` },
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/workshop-entra-as-code-interactive/logo.svg' }],
    ['meta', { name: 'theme-color', content: '#0078d4' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'Microsoft Entra as Code Workshop' }],
    ['meta', { property: 'og:description', content: 'Workforce, External ID and Verified ID as code with Terraform.' }]
  ],
  markdown: {
    // Match GitHub's heading anchors so links written for GitHub (e.g. "#path-1-workforce-tenant-stages-0--21") keep working.
    anchor: { slugify: slug },
    headers: { slugify: slug },
    lineNumbers: false,
    theme: { light: 'github-light', dark: 'github-dark' }
  },
  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'Entra as Code',
    nav: [
      { text: 'Overview', link: '/overview' },
      {
        text: 'Paths',
        items: [
          { text: '🏢 Workforce (Stages 00–21)', link: '/stage-00/' },
          { text: '👥 External ID (Ext-00–05)', link: '/external-00/' },
          { text: '🪪 Verified ID (VC-00–01)', link: '/vc-00/' }
        ]
      },
      { text: 'Copy Workshop ↗', link: TEMPLATE_URL }
    ],
    sidebar,
    outline: { level: [2, 3], label: 'On this page' },
    search: { provider: 'local' },
    socialLinks: [{ icon: 'github', link: REPO_URL }],
    editLink: {
      // prepare.mjs records the original file in frontmatter ("doc/stage-01/README.md").
      // This function is serialized to the client, so it must not reference outer variables.
      pattern: ({ frontmatter, filePath }) =>
        'https://github.com/mjendza/workshop-entra-as-code-interactive/edit/main/' +
        (frontmatter.source ?? `site/pages/${filePath}`),
      text: 'Edit this page on GitHub'
    },
    docFooter: { prev: 'Previous stage', next: 'Next stage' },
    footer: {
      message: 'Released under the MIT License. Copy the template to get one GitHub Issue per stage.',
      copyright: '© Mateusz Jendza'
    }
  },
  mermaid: { theme: 'dark' }
})
