import { readFileSync, writeFileSync, copyFileSync, renameSync, existsSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const webDir = resolve(here, '..')
const repoRoot = resolve(webDir, '..')
const distHtml = resolve(webDir, 'dist', 'index.html')
const targetHtml = resolve(repoRoot, 'index.html')
// 只读备份区（supervisor）：本轮只允许 --dry，不写盘；真实发布时先备份再原子替换
const baselinePrev = '/Users/feint/Temp/botChat-Release/.supervisor/baseline/index.prev.html'

const dry = process.argv.includes('--dry')

function fail (msg) {
  console.error(`publish: FAIL — ${msg}`)
  process.exit(1)
}

if (!existsSync(distHtml)) fail(`找不到构建产物 ${distHtml}，请先跑 npm run build`)

const html = readFileSync(distHtml, 'utf8')

// 写盘前校验（dry 与真实发布共用同一套）
if (!html.includes('id="app"')) fail('产物缺少 id="app"')
if (html.includes('<script type="module" src=')) fail('产物含外链 <script type="module" src=')
if (html.includes('href="/assets/') || html.includes('src="/assets/')) fail('产物含 /assets/ 外链引用')
const linkCss = /<link[^>]+href="[^"]*\.css"/.test(html)
if (linkCss) fail('产物含外链 .css')
const scriptSrc = /<script[^>]+src=/.test(html)
if (scriptSrc) fail('产物含外链 script src')

console.log('publish: 校验通过（id="app" 存在；无外链 module script；无 /assets/；无外链 css/js）')

if (dry) {
  console.log('publish: --dry 模式，只校验不写盘')
  process.exit(0)
}

// 真实写盘：先备份现有根 index.html，再原子替换
const prev = readFileSync(targetHtml, 'utf8')
mkdirSync(dirname(baselinePrev), { recursive: true })
writeFileSync(baselinePrev, prev)
const tmp = targetHtml + '.tmp.publish'
writeFileSync(tmp, html)
renameSync(tmp, targetHtml)
console.log(`publish: 已备份根 index.html → ${baselinePrev}，并原子替换完成`)
