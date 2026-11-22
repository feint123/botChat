// 双页构建：两次独立的 vite build，各自单入口。
//
// 为什么不用 Rollup 多入口：两个入口会共享 chunk（如 vue 的 export helper），
// vite-plugin-singlefile 无法把共享 chunk 内联进各自的 HTML，产物里会残留
// <link rel="modulepreload" href="./_plugin-vue_export-helper-*.js"> 这种外链，
// 用 file:// 打开或被单独拷贝时脚本加载失败、Vue 根本不挂载（实测渲染只剩 9 个节点）。
// 单入口构建时 singlefile 能把 JS/CSS/图片全部内联，产物真正自包含。

import { build } from 'vite'
import { resolve, dirname } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { rmSync, existsSync } from 'node:fs'
import vue from '@vitejs/plugin-vue'
import { viteSingleFile } from 'vite-plugin-singlefile'

const here = dirname(fileURLToPath(import.meta.url))
const webDir = resolve(here, '..')
// 与 dev 配置共用的构建期常量（版本号 / 下载地址 / 更新日志）
const { default: define } = await import(pathToFileURL(resolve(webDir, 'vite.define.js')).href)

const pages = [
  { name: 'index', outDir: resolve(webDir, 'dist/index') },
  { name: 'plugins', outDir: resolve(webDir, 'dist/plugins') }
]

for (const page of pages) {
  await build({
    root: webDir,
    configFile: false,
    base: './',
    plugins: [vue(), viteSingleFile()],
    define,
    build: {
      // 单入口：不产生共享 chunk，singlefile 才能把 JS/CSS/图片完整内联
      rollupOptions: {
        input: resolve(webDir, `${page.name}.html`),
        output: { inlineDynamicImports: true }
      },
      outDir: page.outDir,
      emptyOutDir: true,
      assetsInlineLimit: 100000000
    }
  })
  console.log(`build: ${page.name}.html → ${resolve(page.outDir, `${page.name}.html`)}`)
}
