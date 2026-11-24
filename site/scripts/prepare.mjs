// Stages the workshop Markdown (root README.md + doc/**) into site/src so VitePress can build it.
// The source files are never modified: create-workshop-issues.yml reads them by path.
//
//   doc/<dir>/README.md  -> src/<dir>/index.md      (page at /<dir>/)
//   README.md            -> src/overview.md         (page at /overview)
//   doc/**/<asset>       -> src/**/<asset>          (images etc. referenced by pages)
//   links to repo files outside the site (.tf, .ps1, folders, ...) -> GitHub blob/tree URLs
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const SITE_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const REPO_ROOT = path.resolve(SITE_DIR, '..')
const SRC = path.join(SITE_DIR, 'src')
const REPO_URL = 'https://github.com/mjendza/workshop-entra-as-code-interactive'
const BRANCH = 'main'

// Sidebar order mirrors .github/workflows/create-workshop-issues.yml and the README roadmap.
const paths = [
  {
    key: 'workforce',
    text: '🏢 Path 1: Workforce',
    groups: [
      { text: 'Foundations & Identities', items: [['stage-00', '00 · Prerequisites'], ['stage-01', '01 · SSO Application'], ['stage-02', '02 · Service Principal'], ['stage-03', '03 · Workload Identity Federation']] },
      { text: 'Access Governance & Zero Trust', items: [['stage-04', '04 · Conditional Access'], ['stage-05', '05 · Access Package'], ['stage-06', '06 · PIM']] },
      { text: 'Tenant Hardening & Modern Identities', items: [['stage-07', '07 · Tenant Security Hardening'], ['stage-08', '08 · Agent Identity (Preview)']] },
      { text: 'Security Posture & AI Operations', items: [['stage-09', '09 · Maester'], ['stage-10', '10 · EntraExporter'], ['stage-11', '11 · Zero Trust Assessment'], ['stage-12', '12 · Configuration Drift'], ['stage-13', '13 · Lokka MCP']] },
      { text: 'Application Security & Automation', items: [['stage-14', '14 · SPA SSO'], ['stage-15', '15 · App Roles'], ['stage-16', '16 · Certificate Auth'], ['stage-17', '17 · CI/CD Pipelines']] },
      { text: 'Advanced Operations & High Assurance', items: [['stage-18', '18 · Secret Monitoring'], ['stage-19', '19 · Temporary Access Pass'], ['stage-20', '20 · High Assurance (Preview)'], ['stage-21', '21 · App Role PIM (Private Preview)']] },
      { text: 'Disassembly & Bonus', items: [['stage-cleanup', 'Cleanup'], ['stage-next', 'Next Steps: Enterprise Scale']] }
    ]
  },
  {
    key: 'external',
    text: '👥 Path 2: External ID',
    groups: [
      { text: 'External ID (CIAM)', items: [['external-00', 'Ext-00 · Prerequisites'], ['external-01', 'Ext-01 · Native Authentication'], ['external-02', 'Ext-02 · SSO for CustomerHelpdesk'], ['external-03', 'Ext-03 · Passwordless + MFA (SMS)'], ['external-04', 'Ext-04 · Sign-up Attributes'], ['external-05', 'Ext-05 · Profile Sync + Token Enrichment']] }
    ]
  },
  {
    key: 'verified-id',
    text: '🪪 Path 3: Verified ID',
    groups: [
      { text: 'Verified ID', items: [['vc-00', 'VC-00 · Tenant Onboarding'], ['vc-01', 'VC-01 · Register VC Contract']] }
    ]
  }
]

const pageDirs = new Set(paths.flatMap(p => p.groups.flatMap(g => g.items.map(([dir]) => dir))))
const warnings = []
const IMAGE = /\.(png|jpe?g|gif|svg|webp)$/i

function readmeIn(absDir) {
  if (!fs.existsSync(absDir) || !fs.statSync(absDir).isDirectory()) return null
  return fs.readdirSync(absDir).find(f => /^readme\.md$/i.test(f)) ?? null
}

// Repo-relative posix path (e.g. "doc/stage-01/plan.png") -> URL/path to use from a page.
function mapTarget(repoRel, pageRepoDir, pageSrcDir) {
  const abs = path.join(REPO_ROOT, repoRel)
  const exists = fs.existsSync(abs)
  const isDir = exists && fs.statSync(abs).isDirectory()
  const m = repoRel.match(/^doc\/([^/]+)(?:\/(readme\.md))?\/?$/i)

  // A stage page: doc/<dir>, doc/<dir>/, doc/<dir>/README.md
  if (m && pageDirs.has(m[1]) && (m[2] || isDir)) return `/${m[1]}/`

  // Images are copied next to the pages; code and other files (.tf, .ps1, .http, ...) link to GitHub.
  if (repoRel.startsWith('doc/') && exists && !isDir && IMAGE.test(repoRel)) {
    const srcAbs = path.join(SRC, repoRel.slice('doc/'.length))
    let rel = path.posix.relative(pageSrcDir, path.relative(SRC, srcAbs).split(path.sep).join('/'))
    if (!rel.startsWith('.')) rel = `./${rel}`
    return { asset: rel }
  }

  if (repoRel === 'README.md') return '/overview'
  if (!exists) warnings.push(`missing link target "${repoRel}" (from ${pageRepoDir || '/'}) -> linked to GitHub`)
  return `${REPO_URL}/${isDir ? 'tree' : 'blob'}/${BRANCH}/${repoRel.replace(/\/$/, '')}`
}

function rewriteUrl(url, pageRepoDir, pageSrcDir) {
  if (/^([a-z][a-z0-9+.-]*:|#|\/\/|\$\{)/i.test(url)) return url
  const hashIdx = url.indexOf('#')
  const target = hashIdx >= 0 ? url.slice(0, hashIdx) : url
  const hash = hashIdx >= 0 ? url.slice(hashIdx) : ''
  if (!target) return url
  const repoRel = path.posix.normalize(path.posix.join(pageRepoDir, decodeURI(target)))
  const mapped = mapTarget(repoRel, pageRepoDir, pageSrcDir)
  return (typeof mapped === 'string' ? mapped : mapped.asset) + hash
}

// GitHub renders README.md raw HTML/markdown; VitePress compiles pages as Vue templates.
// Escape mustache braces in prose so "{{your-tenant-domain}}" is not evaluated.
function escapeProse(text) {
  return text.replace(/\{\{/g, '&#123;&#123;').replace(/\}\}/g, '&#125;&#125;')
}

function transform(markdown, pageRepoDir, pageSrcDir) {
  markdown = markdown.replace(/\r\n?/g, '\n') // sources use CRLF; the regexes below expect LF
  // Split on fenced code blocks so code is left untouched.
  const parts = markdown.split(/(^[ \t]*(?:```|~~~)[\s\S]*?^[ \t]*(?:```|~~~)[ \t]*$)/m)
  return parts.map((part, i) => {
    if (i % 2 === 1) return part
    // Link text often contains inline code ([`main.tf`](../../x/main.tf)), so rewrite links on the
    // whole prose part, then escape mustaches outside inline code only.
    // Match on "](" so nested links like [![badge](img.svg)](LICENSE.md) are handled too.
    part = part.replace(/(\]\()(<[^>]+>|[^)\s]+)((?:\s+"[^"]*")?\))/g,
      (_, pre, url, post) => pre + rewriteUrl(url.replace(/^<|>$/g, ''), pageRepoDir, pageSrcDir) + post)
    part = part.replace(/(<(?:img|a|source)\b[^>]*?\s(?:src|href)=")([^"]+)(")/gi,
      (_, pre, url, post) => pre + rewriteUrl(url, pageRepoDir, pageSrcDir) + post)
    return part.split(/(`+[^`\n]*?`+)/).map((seg, j) => (j % 2 === 1 ? seg : escapeProse(seg))).join('')
  }).join('')
}

function frontmatter(obj) {
  return `---\n${Object.entries(obj).map(([k, v]) => `${k}: ${JSON.stringify(v)}`).join('\n')}\n---\n\n`
}

function copyAssets(fromDir, toDir) {
  for (const entry of fs.readdirSync(fromDir, { withFileTypes: true })) {
    const from = path.join(fromDir, entry.name)
    const to = path.join(toDir, entry.name)
    if (entry.isDirectory()) {
      copyAssets(from, to)
    } else if (IMAGE.test(entry.name)) {
      fs.mkdirSync(toDir, { recursive: true })
      fs.copyFileSync(from, to)
    }
  }
}

// ---- build ---------------------------------------------------------------------------------
fs.rmSync(SRC, { recursive: true, force: true })
fs.mkdirSync(SRC, { recursive: true })
copyAssets(path.join(REPO_ROOT, 'doc'), SRC)

// First/last stage of each path: no prev/next link crossing into another path.
const firstOfPath = new Set(paths.map(p => p.groups[0].items[0][0]))
const lastOfPath = new Set(paths.map(p => p.groups.at(-1).items.at(-1)[0]))

for (const dir of pageDirs) {
  const readme = readmeIn(path.join(REPO_ROOT, 'doc', dir))
  if (!readme) throw new Error(`doc/${dir} has no README.md`)
  const sourceRel = `doc/${dir}/${readme}`
  const md = fs.readFileSync(path.join(REPO_ROOT, sourceRel), 'utf8')
  fs.mkdirSync(path.join(SRC, dir), { recursive: true })
  fs.writeFileSync(path.join(SRC, dir, 'index.md'),
    frontmatter({ source: sourceRel, ...(firstOfPath.has(dir) && { prev: false }), ...(lastOfPath.has(dir) && { next: false }) }) + transform(md, `doc/${dir}`, dir))
}

// Root README -> overview page. Drop the H1 + badge block (the home hero covers it).
let readme = fs.readFileSync(path.join(REPO_ROOT, 'README.md'), 'utf8').replace(/\r\n?/g, '\n')
readme = readme.replace(/^# .*\n(?:\s*\n|\[!\[.*\n)*/, '# Workshop Overview\n\n')
fs.writeFileSync(path.join(SRC, 'overview.md'),
  frontmatter({ source: 'README.md' }) + transform(readme, '', ''))

// Hand-written pages (home page, public assets) live in site/pages.
fs.cpSync(path.join(SITE_DIR, 'pages'), SRC, { recursive: true })

fs.writeFileSync(path.join(SITE_DIR, '.vitepress', 'paths.generated.json'), JSON.stringify(paths, null, 2))

for (const w of warnings) console.warn(`⚠️  ${w}`)
console.log(`Staged ${pageDirs.size + 1} pages into ${path.relative(REPO_ROOT, SRC)}`)
