import { readFileSync, writeFileSync, renameSync, existsSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const webDir = resolve(here, '..')
const repoRoot = resolve(webDir, '..')
// 两次单入口构建各自的产物目录（见 scripts/build.mjs）
const baselineDir = '/Users/feint/Temp/botChat-Release/.supervisor/baseline'

// 构建产物 → 仓库根目标文件。两个页面都是自包含单文件，Pages 直接托管。
const targets = [
  { name: 'index.html', from: resolve(webDir, 'dist/index/index.html'), out: resolve(repoRoot, 'index.html'), backup: resolve(baselineDir, 'index.prev.html') },
  { name: 'plugins.html', from: resolve(webDir, 'dist/plugins/plugins.html'), out: resolve(repoRoot, 'plugins.html'), backup: resolve(baselineDir, 'plugins.prev.html') }
]

const dry = process.argv.includes('--dry')

function fail (msg) {
  console.error(`publish: FAIL — ${msg}`)
  process.exit(1)
}

// 单文件产物校验：任一条不满足即中止，不写盘
function validate (html, name) {
  if (!html.includes('id="app"')) fail(`${name} 缺少 id="app"`)

  // 外链是单文件产物的致命问题：被单独拷贝或用 file:// 打开时会加载失败
  if (/<link[^>]+rel="modulepreload"[^>]*href="\.\//.test(html)) fail(`${name} 残留 modulepreload 外链`)
  if (/<link[^>]+href="[^"]*\.css"/.test(html)) fail(`${name} 含外链 .css`)
  if (/<script[^>]+src=/.test(html)) fail(`${name} 含外链 script src`)
  if (html.includes('href="/assets/') || html.includes('src="/assets/')) fail(`${name} 含 /assets/ 外链引用`)

  // 入口串页检查：两个页面共用同一份源码树，内联错入口会静默产出错误页面
  const foreign = name === 'index.html' ? 'src/plugins/main.js' : 'src/main.js'
  if (html.includes(foreign)) fail(`${name} 内联了另一页面的入口脚本`)
}

const jobs = []
for (const t of targets) {
  if (!existsSync(t.from)) fail(`找不到构建产物 ${t.from}，请先跑 npm run build`)
  const html = readFileSync(t.from, 'utf8')
  validate(html, t.name)
  jobs.push({ ...t, html })
}

// 交叉引用检查：两页必须互链，否则文档页会成为无法从主页到达的孤立页面
const indexHtml = jobs.find((j) => j.name === 'index.html').html
const pluginsHtml = jobs.find((j) => j.name === 'plugins.html').html
if (!indexHtml.includes('plugins.html')) fail('主页没有指向 plugins.html 的链接')
if (!pluginsHtml.includes('./index.html')) fail('文档页没有以相对路径回链主页')

console.log(`publish: 校验通过（${jobs.map((j) => j.name).join(' + ')}；id="app" 存在；无外链 script/css/modulepreload/assets；双页互链成立）`)

if (dry) {
  console.log('publish: --dry 模式，只校验不写盘')
  process.exit(0)
}

// 真实写盘：先备份两页旧版，再逐页原子替换
mkdirSync(baselineDir, { recursive: true })
for (const job of jobs) {
  if (existsSync(job.out)) writeFileSync(job.backup, readFileSync(job.out, 'utf8'))
  const tmp = job.out + '.tmp.publish'
  writeFileSync(tmp, job.html)
  renameSync(tmp, job.out)
  console.log(`publish: ${job.name} → ${job.out}（旧版备份 ${job.backup}）`)
}
console.log('publish: 完成')
