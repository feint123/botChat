import { defineConfig } from 'vite'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { viteSingleFile } from 'vite-plugin-singlefile'
import define from './vite.define.js'

const here = dirname(fileURLToPath(import.meta.url))

// dev 服务器配置。发布构建走 scripts/build.mjs（两次单入口构建，见该文件注释），
// 两者共用 vite.define.js 的常量，避免版本号与更新日志两套口径。
export default defineConfig({
  base: './',
  plugins: [vue(), viteSingleFile()],
  define,
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    assetsInlineLimit: 100000000
  }
})
