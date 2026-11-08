import { defineConfig } from 'vite'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { viteSingleFile } from 'vite-plugin-singlefile'

const here = dirname(fileURLToPath(import.meta.url))
const appcastPath = resolve(here, '..', 'appcast.xml')
const repoSlug = 'feint123/botChat'

// 版本号唯一来源：仓库根 appcast.xml（Sparkle 升级源）。落地页只读它，避免文案与升级源脱节。
function readLatestRelease () {
  const xml = readFileSync(appcastPath, 'utf8')
  const items = [...xml.matchAll(/<item>([\s\S]*?)<\/item>/g)].map((m) => m[1])
  if (!items.length) throw new Error('appcast.xml 里没有 <item>，无法确定版本号')

  const parsed = items.map((item) => {
    const version = /<sparkle:shortVersionString>([^<]+)<\/sparkle:shortVersionString>/.exec(item)?.[1]?.trim()
    const build = /<sparkle:version>([^<]+)<\/sparkle:version>/.exec(item)?.[1]?.trim() ?? ''
    if (!version) throw new Error('appcast.xml 的 <item> 缺少 sparkle:shortVersionString')
    return { version, build }
  })

  // 取语义版本最大的一条，避免 appcast 条目顺序变化时拿到旧版本
  parsed.sort((a, b) => {
    const pa = a.version.split('.').map(Number)
    const pb = b.version.split('.').map(Number)
    for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
      const d = (pb[i] ?? 0) - (pa[i] ?? 0)
      if (d) return d
    }
    return 0
  })
  return parsed[0]
}

const latest = readLatestRelease()
const dmgUrl = `https://github.com/${repoSlug}/releases/download/v${latest.version}/botChat-${latest.version}.dmg`

export default defineConfig({
  base: './',
  plugins: [vue(), viteSingleFile()],
  define: {
    __APP_VERSION__: JSON.stringify(latest.version),
    __APP_BUILD__: JSON.stringify(latest.build),
    __DMG_URL__: JSON.stringify(dmgUrl)
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    assetsInlineLimit: 100000000
  }
})
