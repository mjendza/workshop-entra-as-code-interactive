// Stages the workshop Markdown (root README.md + doc/**) into site/src so VitePress can build it.
// The source files are never modified: create-workshop-issues.yml reads them by path.
//
//   doc/<dir>/README.md  -> src/<dir>/index.md      (page at /<dir>/)
//   README.md            -> src/overview.md         (page at /overview)
//   doc/notes/README.md  -> src/notes.md            (page at /notes)
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

// The workshop structure (order, phases, per-stage metadata) lives in ../workshop.mjs.
import { paths, allStages } from '../workshop.mjs'

const stages = allStages()
const pageDirs = new Set(stages.map(st => st.dir))
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
  if (/^doc\/notes(\/readme\.md)?\/?$/i.test(repoRel)) return '/notes'
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

for (const st of stages) {
  const dir = st.dir
  const readme = readmeIn(path.join(REPO_ROOT, 'doc', dir))
  if (!readme) throw new Error(`doc/${dir} has no README.md`)
  const sourceRel = `doc/${dir}/${readme}`
  let md = fs.readFileSync(path.join(REPO_ROOT, sourceRel), 'utf8').replace(/\r\n?/g, '\n')

  // The stage header component renders the H1 and the estimated time, so take them out of the body.
  const title = md.match(/^# (.+)$/m)?.[1].trim() ?? st.short
  md = md.replace(/^# .+\n/m, '')
  const time = md.match(/^#{2,3}\s*(?:⏱️\s*)?Estimated Time:\s*(.+)$/m)?.[1].trim()
  md = md.replace(/^#{2,3}\s*(?:⏱️\s*)?Estimated Time:.*\n/m, '')

  const { dir: _d, ...meta } = st
  const fm = {
    title,
    source: sourceRel,
    stage: { ...meta, ...(time && { time }) },
    // No prev/next link crossing into another path.
    ...(st.index === 0 && { prev: false }),
    ...(st.index === st.total - 1 && { next: false })
  }
  fs.mkdirSync(path.join(SRC, dir), { recursive: true })
  fs.writeFileSync(path.join(SRC, dir, 'index.md'), frontmatter(fm) + transform(md, `doc/${dir}`, dir))
}

// One landing page per path (/paths/<key>), rendered by the PathPage component.
fs.mkdirSync(path.join(SRC, 'paths'), { recursive: true })
for (const p of paths) {
  fs.writeFileSync(path.join(SRC, 'paths', `${p.key}.md`),
    frontmatter({ title: `Path ${p.n}: ${p.name}`, layout: 'page', pageClass: 'ec-landing', sidebar: false, aside: false }) + `<PathPage path-key="${p.key}" />\n`)
}

// Root README -> overview page. Drop the H1 + badge block (the home hero covers it).
let readme = fs.readFileSync(path.join(REPO_ROOT, 'README.md'), 'utf8').replace(/\r\n?/g, '\n')
readme = readme.replace(/^# .*\n(?:\s*\n|\[!\[.*\n)*/, '# Workshop Overview\n\n')
fs.writeFileSync(path.join(SRC, 'overview.md'),
  frontmatter({ source: 'README.md' }) + transform(readme, '', ''))

// Cross-cutting notes (not a stage) -> /notes.
const NOTES = 'doc/notes/README.md'
fs.writeFileSync(path.join(SRC, 'notes.md'),
  frontmatter({ source: NOTES }) + transform(fs.readFileSync(path.join(REPO_ROOT, NOTES), 'utf8'), 'doc/notes', ''))

// Hand-written pages (home page, public assets) live in site/pages.
fs.cpSync(path.join(SITE_DIR, 'pages'), SRC, { recursive: true })


for (const w of warnings) console.warn(`⚠️  ${w}`)
console.log(`Staged ${pageDirs.size + paths.length + 2} pages into ${path.relative(REPO_ROOT, SRC)}`)
