// 构建期常量：版本号、下载地址、更新日志。
//
// 唯一数据来源是仓库根的 appcast.xml 与 notes/*.html，页面代码不硬编码任何版本条目。
// dev 服务（vite.config.js）与发布构建（scripts/build.mjs）共用本模块，避免两套口径漂移。

import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')
const appcastPath = resolve(repoRoot, 'appcast.xml')
const notesDir = resolve(repoRoot, 'notes')
const repoSlug = 'feint123/botChat'
// notes 页面由发版流程写进仓库根 notes/，由 GitHub Pages 托管；落地页只链接，不复制正文。
const NOTES_BASE = 'https://feint123.github.io/botChat/notes/'

function readAppcast () {
  const xml = readFileSync(appcastPath, 'utf8')
  const items = [...xml.matchAll(/<item>([\s\S]*?)<\/item>/g)].map((m) => m[1])
  if (!items.length) throw new Error('appcast.xml 里没有 <item>，无法确定版本号')

  return items.map((item) => {
    const version = /<sparkle:shortVersionString>([^<]+)<\/sparkle:shortVersionString>/.exec(item)?.[1]?.trim()
    const build = /<sparkle:version>([^<]+)<\/sparkle:version>/.exec(item)?.[1]?.trim() ?? ''
    const date = /<pubDate>([^<]+)<\/pubDate>/.exec(item)?.[1]?.trim() ?? ''
    if (!version) throw new Error('appcast.xml 的 <item> 缺少 sparkle:shortVersionString')
    return { version, build, date }
  })
}

// 语义版本降序；同版本按 build 兜底，避免 appcast 条目顺序变化时拿到旧版本
function byVersionDesc (a, b) {
  const pa = a.version.split('.').map(Number)
  const pb = b.version.split('.').map(Number)
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pb[i] ?? 0) - (pa[i] ?? 0)
    if (d) return d
  }
  return Number(b.build || 0) - Number(a.build || 0)
}

function plain (html) {
  return html
    .replace(/<[^>]+>/g, '')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim()
}

// 从 notes/botChat-<版本>.html 抽出「主线一句 + 分组条目」。解析失败不抛错，
// 该版本退化为「只有版本号与详情链接」，不至于让整次构建失败。
function parseNote (html) {
  const headlineMatch = /<h1[^>]*>[\s\S]*?<\/h1>\s*<p[^>]*>([\s\S]*?)<\/p>/i.exec(html)
  const headline = headlineMatch ? plain(headlineMatch[1]) : ''

  const sections = []
  const sectionRe = /<h3[^>]*>([\s\S]*?)<\/h3>\s*<ul[^>]*>([\s\S]*?)<\/ul>/gi
  let m
  while ((m = sectionRe.exec(html))) {
    const title = plain(m[1])
    const items = [...m[2].matchAll(/<li[^>]*>([\s\S]*?)<\/li>/gi)].map((x) => plain(x[1])).filter(Boolean)
    if (title && items.length) sections.push({ title, items })
  }
  return { headline, sections }
}

function readChangelog (releases) {
  const byVersion = new Map(releases.map((r) => [r.version, r]))
  const files = existsSync(notesDir)
    ? readdirSync(notesDir).filter((f) => /^botChat-.+\.html$/.test(f))
    : []

  const notes = files.map((f) => {
    const version = f.replace(/^botChat-/, '').replace(/\.html$/, '')
    const { headline, sections } = parseNote(readFileSync(resolve(notesDir, f), 'utf8'))
    return { version, build: byVersion.get(version)?.build ?? '', date: byVersion.get(version)?.date ?? '', headline, sections }
  })
  notes.sort(byVersionDesc)

  // 主页只展开最近 4 个版本；更早的版本收进归档索引，避免页面变成长列表
  const recent = notes.slice(0, 4).map((n) => ({
    version: n.version,
    date: n.date,
    url: `${NOTES_BASE}botChat-${n.version}.html`,
    headline: n.headline,
    sections: n.sections.map((s) => ({ title: s.title, items: s.items.slice(0, 3), more: Math.max(0, s.items.length - 3) }))
  }))
  const archive = notes.slice(4).map((n) => ({
    version: n.version,
    date: n.date,
    url: `${NOTES_BASE}botChat-${n.version}.html`
  }))

  // notes/ 缺失时为最近版本兜底一条链接，保证更新区块不空转
  if (!recent.length) {
    const fallback = releases.slice().sort(byVersionDesc)[0]
    if (fallback) {
      recent.push({ version: fallback.version, date: fallback.date, url: `${NOTES_BASE}botChat-${fallback.version}.html`, headline: '', sections: [] })
    }
  }
  return { recent, archive }
}

const releases = readAppcast()
const latest = releases.slice().sort(byVersionDesc)[0]
const changelog = readChangelog(releases)

const define = {
  __APP_VERSION__: JSON.stringify(latest.version),
  __APP_BUILD__: JSON.stringify(latest.build),
  __DMG_URL__: JSON.stringify(`https://github.com/${repoSlug}/releases/download/v${latest.version}/botChat-${latest.version}.dmg`),
  __RELEASES__: JSON.stringify(changelog.recent),
  __RELEASE_ARCHIVE__: JSON.stringify(changelog.archive)
}

export { define, latest, changelog }
export default define
